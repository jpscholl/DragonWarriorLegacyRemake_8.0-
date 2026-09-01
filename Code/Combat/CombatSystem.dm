// -----------------------------
// MOB COMBAT PROCS
// -----------------------------
// Shared by players AND enemies — every proc here is a plain mob/proc (or a free-
// standing proc for the two-argument helpers), not split by type, so the same code
// path handles "player attacks enemy" and "enemy attacks player" identically.
//
// THE ATTACK PIPELINE, start to finish:
//   1. Something decides to attack — a player pressing a numpad skill key
//      (UseSkillSlot(), PlayerTemplate.dm) or an enemy's AILoop() (EnemyNPCs.dm) once
//      adjacent to its target.
//   2. PlayAttackAnimation() plays the flick/sound/weapon-or-spell overlay — purely
//      visual/audio, does no damage itself.
//   3. PerformMeleeHit() (melee) or ApplySpellDamage() (spells) finds who's actually
//      getting hit and calls TakeDamage() on them.
//   4. TakeDamage() is where the actual outcome happens: RollDodge() first (a miss
//      just plays a sound and stops there), then damage is applied, then Die() +
//      CleanUpDead() if that brought HP to 0.
//   5. Die() credits the ATTACKER's Exp/LevelCheck(), then branches: a player goes
//      into the isDead/respawn-via-Interact() flow, an enemy just gets flagged for
//      CleanUpDead() to delete a few seconds later.
//
// GetAttackDelay()/IsCardinallyAdjacent()/InBattleArea() are standalone helpers the
// pipeline above and EnemyNPCs.dm both lean on — attack speed, "am I actually next to
// my target" (not just Chebyshev-close), and "is combat even allowed here."

// CONFIRMED 2026-08-25 (OG string table, string 605): "You have lost 5% of your EXP as
// penalty for respawn." — 5%, verbatim. Was 25%, an invented number.
#define DEATH_EXP_LOSS_PERCENT 5

// UNCONFIRMED — remake-only, deliberately left in place. The old comment here claimed
// this matched a "lose half gold" original design note, but the full 4450-string OG table
// contains no gold-loss message and no gold-loss variable anywhere (see
// RemakeVsOGStructure.md Part 5.2). The OG's only stated respawn penalty is the 5% EXP
// line above. Kept at 50 rather than silently zeroed since removing a penalty is a
// balance decision, not a correction — but treat it as a remake addition, not OG-derived.
#define DEATH_GOLD_LOSS_PERCENT 50

// CONFIRMED 2026-08-25 (OG string table, string 887): "You will auto-respawn in 60
// seconds.  You may press 5 on your numpad to respawn before then." Both halves are now
// implemented: RespawnPlayer() fires automatically after this delay (scheduled in Die()
// below), and numpad 5 — the "Center" macro, bound to Interact() in Interface.dmf —
// respawns immediately with NO minimum wait. The old model was the reverse of the OG's:
// a 10-second minimum before a manual press was even allowed, and no auto-respawn at all.
#define RESPAWN_AUTO_DELAY 600  // world.time units (60 real seconds at the default tick rate)

mob/var/isDead = FALSE
mob/var/deathTime = 0

// Whoever landed the FIRST hit on this mob — the OG's first_hit. Die() credits this
// mob's exp/gold to them rather than to whoever happened to land the killing blow, so a
// fight can't be sniped at the last moment. Cleared nowhere: a mob only dies once, and
// enemies are deleted shortly after (CleanUpDead()).
mob/var/mob/firstAttacker = null

// Toggled by datum/skill/Defend (SkillDatum.dm) — TRUE while a mob is holding up its
// shield (icon_state = "defend"), reducing incoming damage. No duration/cooldown, just
// an on/off stance the player controls directly.
mob/var/isDefending = FALSE
// CONFIRMED 2026-08-10: live OG testing shows Defend literally halves incoming
// physical damage while held — this 50% guess matches exactly, no longer a
// placeholder. OG also drops the stance on attack, same as DropDefendForAction()
// below already does. User's preference, same finding: keep the remake's own
// attack-speed-penalty-on-drop addition (DEFEND_ATTACK_SPEED_PENALTY below) on top of
// this — it's not in the OG, but explicitly liked better than OG's plain drop.
#define DEFEND_DAMAGE_REDUCTION_PERCENT 50

// Bumped every time isDefending is toggled BY THE PLAYER (Defend.OnUse(), SkillDatum.dm)
// — lets Attack.OnUse() auto-restore a defend stance it dropped mid-swing without
// stomping an explicit manual toggle that happened in the meantime (e.g. the player
// lowered their shield themselves while an attack was still resolving).
mob/var/defendToggleSession = 0

mob/proc
    // Drops an active defend stance for the duration of an attack/cast (a mob can't
    // hold a steady shield and swing/gesture at the same instant) — shared by
    // Attack/Blaze (SkillDatum.dm), both of which had this exact drop-then-restore
    // dance duplicated inline. Returns whether it was actually defending, which the
    // caller must hold onto and pass to RestoreDefendIfUntouched() afterward.
    DropDefendForAction()
        if(!isDefending) return FALSE
        isDefending = FALSE
        icon_state = "world"
        return TRUE

    // Re-raises the defend stance dropped by DropDefendForAction(), but only if the
    // player hasn't manually toggled Defend themselves in the meantime — mySession
    // should be defendToggleSession as captured right before the drop.
    RestoreDefendIfUntouched(wasDefending, mySession)
        if(wasDefending && defendToggleSession == mySession)
            isDefending = TRUE
            icon_state = "defend"

// Dodge chance is new — no such mechanic existed before, so this is a placeholder
// formula, not OG-derived. Agility-based, capped so it's never a sure thing even at
// high Agility. Tune by feel.
#define DODGE_BASE_PERCENT 0
#define DODGE_AGILITY_SCALE 1  // % dodge chance per point of Agility
#define DODGE_MAX_PERCENT 30

mob/proc
    // Returns TRUE if this mob (the one about to take a hit) dodges it.
    RollDodge()
        var/dodgeChance = min(DODGE_MAX_PERCENT, DODGE_BASE_PERCENT + GetEffectiveAgility() * DODGE_AGILITY_SCALE)
        return prob(dodgeChance)

// Defense — new, no OG numeric formula exists to confirm this against (only the OG
// help file's plain-language claim that Agility+Vitality drive physical defense and
// Vitality+Intelligence drive magic defense, ClassReference.md/OGGameStructure.md).
// Divisors are placeholders, tune by feel. Flat subtraction rather than a percentage
// reduction — keeps a heavily-invested tank able to shrug off weak hits entirely
// without needing a separate armor stat, same spirit as DEFEND_DAMAGE_REDUCTION_PERCENT
// being a flat stance bonus rather than scaling off anything.
#define PHYSICAL_DEFENSE_DIVISOR 4
#define MAGIC_DEFENSE_DIVISOR 4
// A defended hit is never fully negated — always at least this much gets through, so
// stacking defense can't turn combat into a stalemate.
#define MIN_DAMAGE 1

mob/proc
    // defenseBonus/magicDefenseBonus are the Increase/Barrier buffs (StatusEffects.dm);
    // equipDefenseBonus/equipMagicDefenseBonus are their amulet equivalents
    // (obj/item/amulet/increase and /barrier, Inventory.dm). All added here rather than
    // to the underlying stats so neither can be caught by a stat-cap check or
    // accidentally persisted by a mid-buff/mid-equip save.
    GetDefense()
        return round((GetEffectiveAgility() + GetEffectiveVitality()) / PHYSICAL_DEFENSE_DIVISOR) + defenseBonus + equipDefenseBonus

    GetMagicDefense()
        return round((GetEffectiveVitality() + GetEffectiveIntelligence()) / MAGIC_DEFENSE_DIVISOR) + magicDefenseBonus + equipMagicDefenseBonus

// Critical hits — new, no OG numeric formula exists either, only the help file's claim
// that Spirit drives crit rate. Rolled by the ATTACKER (RollCrit() reads src's own
// Spirit), same shape as RollDodge() above but on the other side of the hit. Applies to
// both melee (PerformMeleeHit()) and spell damage (ApplySpellDamage()) — the help file
// doesn't say Spirit is melee-only, and there's no reason a caster's crit investment
// should do nothing.
#define CRIT_BASE_PERCENT 0
#define CRIT_SPIRIT_SCALE 1  // % crit chance per point of Spirit
#define CRIT_MAX_PERCENT 50
#define CRIT_DAMAGE_PERCENT 150  // damage dealt on a crit, as % of normal

mob/proc
    RollCrit()
        var/critChance = min(CRIT_MAX_PERCENT, CRIT_BASE_PERCENT + GetEffectiveSpirit() * CRIT_SPIRIT_SCALE)
        return prob(critChance)

mob/proc
    // Apply damage to this mob. isMagic picks which defense stat mitigates it
    // (ApplySpellDamage() below passes TRUE; melee's default FALSE is correct as-is).
    // isCrit only affects the message shown — the damage number itself is expected to
    // already include the crit multiplier by the time it gets here (see
    // PerformMeleeHit()/ApplySpellDamage()), same division of labor as isDefending's
    // reduction happening in here while the crit roll happens at the source.
    // Returns whether the hit actually landed (FALSE for already-dead, a blocked
    // friendly-fire-on-pet hit, or a dodge) — Projectiles.dm's Launch() uses this to
    // decide whether a spell projectile stops at this target or keeps flying past it
    // toward whatever's beyond (a dodge shouldn't consume the shot).
    TakeDamage(damage, mob/attacker, isMagic = FALSE, isCrit = FALSE)
        if(HP <= 0) return FALSE

        // No friendly fire on your own pet (mob/enemy/owner, EnemyNPCs.dm) — covers
        // melee (PerformMeleeHit()/PerformLineHit()) and spells (ApplySpellDamage())
        // both, since everything funnels through here. Other players' pets and wild
        // monsters are still fair game; only YOUR OWN pet is protected.
        if(istype(src, /mob/enemy))
            var/mob/enemy/E = src
            if(E.owner && E.owner == attacker) return FALSE

        // Mirror of the above: a pet can't hurt its own owner either. RunWildAI()
        // (EnemyNPCs.dm) already stops a pet from picking its owner as a target in
        // the first place — this is the belt-and-braces backstop for any other path
        // (e.g. a stray AoE) that might still route damage from a pet to its owner.
        if(istype(attacker, /mob/enemy))
            var/mob/enemy/A = attacker
            if(A.owner && A.owner == src) return FALSE

        // Coop mode (GM_CoopMode, GMCommands.dm) — blocks player-vs-player damage
        // unless the target's current area allows PvP (Area.dm's battleAllowsPvP,
        // default FALSE everywhere). Separate from GM_BattleMode's monster-aggro/
        // skill-use gate (InBattleArea()) — the two never affect each other
        // (GMCommandsReference.md). GM-tier targets are exempt from the protection
        // ("players can still hurt a GM regardless of coop mode") — this only ever
        // narrows what a GM's own mob/player can take, never what they can dish out.
        if(istype(src, /mob/player) && istype(attacker, /mob/player))
            var/mob/player/targetP = src
            if(!(targetP.client && targetP.client.adminLevel >= LEVEL_GM_HOST))
                var/turf/pvpTurf = src.loc
                var/area/pvpArea = pvpTurf ? pvpTurf.loc : null
                if(!pvpArea || !pvpArea.battleAllowsPvP)
                    attacker << output("Coop mode is active here — you cannot attack other players.", "Info")
                    return FALSE

        // "src" here is a /mob/enemy check because enemies and players use different
        // sound files for the same events (attack/hit/dodge) — see PlayAttackAnimation()
        // below for the attack.wav/enemyattack.wav split.
        var/isEnemy = istype(src, /mob/enemy)

        if(RollDodge())
            // view(src), not bare view() — bare view() centers on usr, which is
            // unreliable (often stale/unset) outside of code paths triggered directly
            // by a verb. TakeDamage() also runs from background procs like an enemy's
            // AILoop() calling PerformMeleeHit(), where usr isn't the mob taking the
            // hit — that silently broke this exact sound for player-vs-enemy combat.
            PlaySFXAt(src, isEnemy ? 'enemydodge.wav' : 'dodge.wav')
            view(src) << output("[src] dodges the attack!", "Info")
            ShowCombatNumber(src, "miss", "#ffffff")
            return FALSE

        flick("hit", src)
        // channel = SFX_CHANNEL (defined in the .dme, see its comment), not 1 —
        // channel 1 is area background music (PlayAreaMusic(), Area.dm), and this
        // used to interrupt/kill it every hit.
        PlaySFXAt(src, isEnemy ? 'enemyhit.wav' : 'hit.wav')  // see usr note above

        // Defense subtracted before the defend-stance percentage, then floored — stops
        // a heavily-defended mob from ever taking a true zero, and stops the two
        // mitigation layers from compounding into an unhittable wall.
        var/defense = isMagic ? GetMagicDefense() : GetDefense()
        damage = max(MIN_DAMAGE, damage - defense)

        // Applied after the dodge roll (a dodge avoids damage entirely, unrelated to
        // defending) but before HP is reduced.
        if(isDefending)
            damage = round(damage * (100 - DEFEND_DAMAGE_REDUCTION_PERCENT) / 100)
        damage = max(MIN_DAMAGE, damage)

        // Kill credit goes to whoever struck FIRST, not whoever struck last (the OG's
        // first_hit). Its own rules text is explicit about this: "You won't get any EXP
        // or gold from it unless you hit it first, anyway." Without it, anyone could
        // wait out someone else's fight and steal the reward with a finishing blow.
        // Recorded here rather than in Die() because by then the first attacker is long
        // gone from the call chain.
        if(!firstAttacker && attacker && attacker != src)
            firstAttacker = attacker

        HP -= damage
        view(src) << output(isCrit ? "[src] takes a critical hit for [damage] damage! (HP: [max(HP,0)])" : "[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")
        ShowCombatNumber(src, "[damage]", isCrit ? "#ffff00" : "#ff0000")
        ShowFloatingHPBar()

        // Being hit wakes you up — classic Dragon Warrior behavior, and previously
        // flagged as a known gap in datum/status_effect/sleep's own comment
        // (StatusEffects.dm). Without this, Sleep was an unbreakable stun for its full
        // duration, which is far stronger than intended.
        RemoveStatusEffect(/datum/status_effect/sleep)

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

        return TRUE

mob/proc
    // Spawns this mob's item drop, if it has one. Base mob drops nothing — mob/enemy
    // overrides this with the real dropType/dropChance roll (EnemyNPCs.dm). Declared on
    // the base so Die() can call it unconditionally without an istype guard, same
    // reasoning as expReward/goldReward living on the base mob.
    DropLoot(mob/killer)
        return

mob/proc
    // Remove this mob asynchronously — never applies to players, who go through the
    // isDead/respawn flow in Die() instead of being deleted.
    CleanUpDead()
        if(istype(src, /mob/player)) return
        spawn(100)  // lets the corpse linger in place (EnemyNPCs.dm's AILoop() already
                     // stops acting entirely on death) before it disappears
            del src

mob/proc
    // Handle death: credit the attacker (not the mob that died), then branch on
    // whether this was a player or an enemy.
    Die(mob/attacker)
        view(src) << output("[src] has been defeated!", "Info")

        // Reward the first attacker (the OG's first_hit, recorded in TakeDamage() above)
        // rather than whoever landed the finishing blow. Falls back to the killer when
        // there's no recorded first hit — a death from poison, a GM_KillMonsters sweep,
        // or any other path that skips TakeDamage() entirely. The `firstAttacker` guard
        // also drops a stale reference if that mob has since been deleted.
        if(firstAttacker)
            attacker = firstAttacker

        // Poison etc. shouldn't keep ticking on a corpse, or survive a player's
        // respawn (Interact() clears them again there too, belt and braces).
        ClearStatusEffects()

        if(attacker)
            // expReward is per-mob (base mob default, overridden per monster tier in
            // MonsterRoster.dm) — this used to be a flat literal 10 for every kill,
            // which meant a Tier 4 Dragonlord paid exactly what a Tier 1 Bat did.
            // That was survivable against the old flat "Nexp += 10" curve, but not
            // against the convex one (LevelCheck() below): level 49->50 alone needs
            // 15 * 49^2 = 36,015 exp, i.e. ~3,600 kills of ANY monster at a flat 10.
            var/reward = src.expReward
            var/goldDrop = src.goldReward
            // What the attacker personally receives, after their own amulet bonus —
            // tracked separately from goldDrop/reward so the message below (and the
            // party case) reports the real credited amount, not the pre-bonus one.
            var/attackerGoldGained = 0
            if(attacker.Party && attacker.Party.shareExp)
                // Split evenly among the party (Code/Player/Party.dm) — no
                // solo-vs-group penalty yet, that formula isn't confirmed (TODOList.md).
                // Gold splits on the same shareExp flag rather than getting its own
                // toggle — one "we're sharing spoils" switch, not two.
                var/memberCount = attacker.Party.members.len
                var/share = max(1, round(reward / memberCount))
                var/goldShare = goldDrop ? max(1, round(goldDrop / memberCount)) : 0
                for(var/mob/player/M in attacker.Party.members)
                    // Amulet of Experience/Wealth (obj/item/amulet/exp, /gold,
                    // Inventory.dm) — each member's own amulet boosts only their own
                    // share, not the shared pool before split.
                    var/expGained = round(share * (100 + M.equipExpBonusPercent) / 100)
                    var/goldGained = round(goldShare * (100 + M.equipGoldBonusPercent) / 100)
                    M.Exp += expGained
                    M.Gold += goldGained
                    M.LevelCheck()
                    if(M == attacker) attackerGoldGained = goldGained
            else
                attackerGoldGained = round(goldDrop * (100 + attacker.equipGoldBonusPercent) / 100)
                attacker.Exp += round(reward * (100 + attacker.equipExpBonusPercent) / 100)
                attacker.Gold += attackerGoldGained
                attacker.LevelCheck()

            if(attackerGoldGained)
                attacker << output("You gain [attackerGoldGained] Gold.", "Info")

            // Item drops (the OG's drop_type/drop_rate). Rolled here, inside the
            // attacker branch, so an unattributed death (a GM_KillMonsters sweep with no
            // credited killer, a scripted despawn) doesn't scatter loot with nobody
            // around to claim it.
            DropLoot(attacker)

        if(istype(src, /mob/player))
            // Player death: no deletion. Respawn happens either automatically after
            // RESPAWN_AUTO_DELAY or immediately on numpad 5 (Interact(), PlayerVerbs.dm),
            // matching the OG exactly. Lose a percentage of Exp/Gold as a penalty.
            isDead = TRUE
            deathTime = world.time
            // Exp is per-level progress here (LevelCheck() resets it to 0 on every
            // level-up), so flooring at 0 already gives the OG's exp_min behavior for
            // free: a death penalty can never de-level you.
            Exp = max(0, Exp - round(Exp * DEATH_EXP_LOSS_PERCENT / 100))
            Gold = max(0, Gold - round(Gold * DEATH_GOLD_LOSS_PERCENT / 100))
            density = 0
            icon_state = "sleep"
            // Locks movement via mob/proc/Step()'s existing canAct gate
            // (SmoothMovement.dm) — same mechanism already used to root a player
            // mid-attack. Reset on respawn, see RespawnPlayer() below.
            canAct = FALSE
            // Also clear this even though the attack's own recovery spawn() already
            // guards on isDead before setting it — a mob killed by a SECOND hit that
            // lands during their own swing's post-windup "moving but can't attack yet"
            // window would otherwise still have this TRUE, letting Step() wave the
            // death lock through (PlayerTemplate.dm's attackRecoveryOnly).
            attackRecoveryOnly = FALSE
            src << output("You will auto-respawn in [RESPAWN_AUTO_DELAY / 10] seconds. You may press 5 on your numpad to respawn before then.", "Info")

            // Auto-respawn timer. Captures deathTime so a player who respawned early
            // (numpad 5), died again, and is now on a NEW death doesn't get yanked by
            // this older timer firing late — RespawnPlayer() no-ops unless this is still
            // the same death it was scheduled for.
            var/thisDeath = deathTime
            spawn(RESPAWN_AUTO_DELAY)
                if(isDead && deathTime == thisDeath)
                    RespawnPlayer()
        else
            // Enemy death: CleanUpDead() (called from TakeDamage right after this)
            // handles the actual deletion.
            density = 0
            icon_state = "sleep"

mob/proc
    // Brings a dead player back at the respawn point, full HP/MP. The single respawn
    // path — reached automatically by Die()'s RESPAWN_AUTO_DELAY timer above, or
    // immediately when the player presses numpad 5 (Interact(), PlayerVerbs.dm). Both
    // routes used to be one inline block inside Interact(); the auto-respawn timer needed
    // the same work, so it lives here rather than being written twice.
    RespawnPlayer()
        if(!isDead) return

        isDead = FALSE
        HP = MaxHP
        MP = MaxMP
        density = 1
        icon_state = "world"
        isDefending = FALSE  // clear a stale defend stance from before death — icon_state
                               // above already resets visually, this resets the actual
                               // damage-reduction flag (Defend, SkillDatum.dm) to match
        ClearStatusEffects()  // don't respawn still poisoned (StatusEffects.dm)
        loc = GetRespawnTurf()
        canAct = TRUE  // re-enable movement — Die() above locks this as part of the
                        // death flow
        src << output("You respawn.", "Info")

// PLACEHOLDER exp curve — convex on purpose ("fast at first, slows down" per your own
// description): cheap early on, requirement balloons at high levels. Quadratic
// (Level^2), not a fractional exponent — DM has no exponentiation operator and no
// pow()/exp()/ln() builtins to fall back on either, so plain integer multiplication is
// the safe way to get a convex curve. BASE_EXP is invented, no OG data exists for
// this — tune once there's real playtesting to feel the pacing against.
#define BASE_EXP 15

// Temporary level cap while class content/skill curricula are only tuned up through
// here — ClassReference.md's stated cap is 99, this doesn't change that number, it's a
// deliberate override for the time being. Raise/remove once there's more to level into.
#define MAX_LEVEL 50

mob/proc
    // Level up check
    LevelCheck()
        if(src.Level >= MAX_LEVEL) return

        if(src.Exp >= src.Nexp)
            src.Exp = 0
            src.Level += 1
            // Recomputed fresh off the new Level (not incremented off the old
            // threshold like the flat +10 this replaced).
            src.Nexp = BASE_EXP * src.Level * src.Level
            // CONFIRMED 2026-08-10: Hero1 sat on 12 unspent points after 2 level-ups
            // (1->2->3) with none spent along the way — 6 per level, not the old
            // placeholder 5 (TODOList.md Phase 7).
            src.StatPoints += 6
            src.RecalculateVitals()  // Code/Player/StatsDatum.dm — Level affects MaxHP/MaxMP too
            src << output("You are now Level [src.Level]", "Info")
            src << sound('levelup.wav', channel = 2, volume = client ? client.ScaledVolume() : 100)

            // Leveled skill/spell learning (Code/Player/SkillUnlocks.dm) — enemies
            // also route through this shared LevelCheck() (Die()'s attacker.LevelCheck()
            // call, above), so guard to players only.
            if(istype(src, /mob/player))
                var/mob/player/P = src
                P.CheckSkillUnlocks()

mob/proc
    // Melee hit detection. M, when passed, is the target captured the INSTANT the
    // swing started (UseSkillSlot(), PlayerTemplate.dm — already resolved from the
    // tile-ahead at keypress time; RunWildAI()/HandlePetTick(), EnemyNPCs.dm, pass
    // their locked target/huntTarget the same way, only after their own adjacency
    // check). This proc runs after cast_time's windup though — an earlier version of
    // this re-checked M's range AGAIN here, at resolve time, which meant a target that
    // was legitimately adjacent when the swing started but then took one step (fleeing
    // or just repositioning) during the windup made the swing whiff anyway. That's not
    // a real dodge, just bad timing luck. A swing you already committed to, against a
    // target that WAS in range, should land — RollDodge() below is the only thing that
    // should be able to turn it into a miss. So M's range is trusted from capture time
    // and never re-validated here; only re-check that it's still alive. Falls back to
    // scanning the tile ahead only when no target was captured up front (defensive —
    // every current caller passes one) — that fallback is inherently "checked right
    // now," so it needs no separate range check either.
    PerformMeleeHit(datum/skill/S, mob/M = null)
        if(!M)
            var/turf/T = get_step(src, dir)
            if(!T) return
            for(var/mob/X in T.contents)
                if(X == src) continue
                if(X.HP <= 0) continue
                M = X
                break

        if(!M || M.HP <= 0) return

        // S.damage_multiplier (base /datum/skill, SkillDatum.dm) defaults to 1, so
        // this stays flat-Strength for Attack exactly like before — only a skill
        // that actually sets a different multiplier (GenericPhysical subtypes,
        // SkillCatalog.dm) changes the number.
        //
        // S may legitimately be null — reading .damage_multiplier off null is a
        // hard runtime error in DM, which would abort the whole hit. Every caller
        // in the codebase now passes a real skill (enemies pass their own
        // attackSkill, EnemyNPCs.dm), but this stays defensive so a future
        // "just deal a plain hit" caller can't silently break all melee again.
        // attackBonus is the Upper buff (StatusEffects.dm) — added to Strength for
        // damage purposes only, never to the stat itself.
        var/mult = S ? S.damage_multiplier : 1
        var/damage = round((GetEffectiveStrength() + attackBonus) * mult)
        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        M.TakeDamage(damage, src, isMagic = FALSE, isCrit = isCrit)

// Elemental scaffolding — real, working code, but currently inert: nothing anywhere
// yet actually sets elementalWeakness/elementalResistance on a player or monster, so
// these checks never trigger in practice until something does. Same pattern as
// Area.dm's battleModeOn/weather vars before GM_BattleMode wired them up — the
// plumbing exists now, behavior gets populated later. Confirmed remake idea (not
// OG-derived) — see TODOList.md Phase 6 for the bigger open questions this doesn't
// answer yet (how many elements, whether player affinity is a creation-time choice).
mob/var/elementalWeakness = null    // e.g. "ice" — takes bonus damage from that element
mob/var/elementalResistance = null  // e.g. "fire" — takes reduced damage from that element
#define ELEMENTAL_WEAKNESS_BONUS_PERCENT 50
#define ELEMENTAL_RESISTANCE_REDUCTION_PERCENT 50

// A mob's OWN elemental affinity, distinct from what it's weak/resistant TO. This is
// real OG data for monsters — the .dmb type table stores an element name string per
// monster and it extracted CERTAIN (the stored values are literally "Fire"/"Water"/
// "Ice"/"Air"/"Iron"/"Plant"/"Darkness"/"Holy"/"Normal"/"Physical"), so every monster in
// MonsterRoster.dm now carries its real one. Players leave this null; no creation-time
// affinity choice exists (TODOList.md Phase 6 has that as an open question).
//
// The OG resolved attacker-element vs. defender-element through a single /proc/Element(off, def)
// lookup whose actual multiplier table lives in bytecode we haven't disassembled. Until
// that's recovered, ResolveElementalDefense() below derives the two existing
// weakness/resistance vars from this one affinity using the one rule that's safe to
// assume — a creature of an element resists that element — and deliberately does NOT
// invent an opposition table (fire-beats-ice etc.), which would be pure guesswork.
mob/var/mobElement = null

mob/proc
    // Called from New() on every mob that has an affinity. Sets elementalResistance from
    // mobElement unless something already set it explicitly, so the real extracted data
    // actually reaches ApplySpellDamage() instead of sitting inert on the type.
    // PLACEHOLDER RULE, clearly flagged: self-element resistance only. Weakness stays
    // null on purpose — see mobElement's comment above.
    ResolveElementalDefense()
        if(!mobElement) return
        if(isnull(elementalResistance))
            elementalResistance = mobElement

mob/proc
    // Spell damage helper. Returns TakeDamage()'s landed/dodged result (see its own
    // note) — Projectiles.dm's Impact() passes this back up to Launch() so a dodged
    // shot keeps flying instead of stopping.
    ApplySpellDamage(mob/target, damage, element)
        if(!target) return FALSE

        if(element)
            if(target.elementalWeakness == element)
                damage = round(damage * (100 + ELEMENTAL_WEAKNESS_BONUS_PERCENT) / 100)
            else if(target.elementalResistance == element)
                damage = round(damage * (100 - ELEMENTAL_RESISTANCE_REDUCTION_PERCENT) / 100)

        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        return target.TakeDamage(damage, src, isMagic = TRUE, isCrit = isCrit)
        // Can later add AoE and more elaborate elemental effects (status ailments tied
        // to an element, etc.) — this proc just handles the damage-modifier half.

mob/proc
    // Heal helper — symmetric to ApplySpellDamage() above but restores HP instead,
    // capped at MaxHP. No dodge/elemental interaction (can't dodge or resist being
    // healed). Used by GenericSpell's healing branch (SkillCatalog.dm) and Rest.
    ApplyHeal(mob/target, amount)
        if(!target) return
        var/oldHP = target.HP
        target.HP = min(target.MaxHP, target.HP + amount)
        var/actualHealed = target.HP - oldHP
        target << output("You are healed for [amount] HP! (HP: [target.HP]/[target.MaxHP])", "Info")
        if(actualHealed > 0) ShowCombatNumber(target, "[actualHealed]", "#00ff00")
        target.ShowFloatingHPBar()

#define MELEE_ATK_BASE_DELAY 12
#define MELEE_ATK_MIN_DELAY 4
#define SPELL_ATK_BASE_DELAY 14
#define SPELL_ATK_MIN_DELAY 6
// Agility's magic-speed bonus is (Agility * Intelligence / this) — scales WITH
// Intelligence rather than being a flat add, so Agility barely helps a low-INT
// character's cast speed but meaningfully helps a high-INT one. Tune by feel.
#define SPELL_AGI_SYNERGY_DIVISOR 40

// Extra deciseconds added on top of the normal formula when the mob WAS defending at
// the moment it attacked (datum/skill/Attack/Fireball's OnUse(), SkillDatum.dm, both
// pass their captured wasDefending here) — on top of the auto-drop mechanic itself
// (dropping mitigation for the swing), attacking from a defensive stance is also
// slightly slower to throw. Placeholder, tune by feel.
#define DEFEND_ATTACK_SPEED_PENALTY 3

mob/proc
    // Stat-based delay for skill usage. Deliberately NOT gated by class or an
    // isSpellcaster flag — physical vs. magic speed falls out purely from how a player
    // allocates stat points (ClickableStats.dm), so e.g. a Hero/Pilgrim can freely lean
    // physical, magic, or a hybrid of both through their own stat choices.
    GetAttackDelay(datum/skill/S, wasDefending = FALSE)
        var/delay
        if(S.isMelee)
            // Geometric mean of Agility and whichever of Vitality/Intelligence is
            // higher: needs Agility PLUS a real secondary investment to get fast, but
            // deliberately doesn't force that secondary investment to be Vitality
            // specifically — a Wizard who leans Intelligence instead of Vitality still
            // has a legitimate path to a competent physical attack (Agility+Intelligence),
            // same as a Fighter's Agility+Vitality path. Neither stat alone is enough
            // (sqrt(A*x) gets dragged down hard by whichever side is low), but which
            // *second* stat gets you there is the player's choice, not a fixed pairing.
            var/meleeSpeedStat = sqrt(GetEffectiveAgility() * max(GetEffectiveVitality(), GetEffectiveIntelligence()))
            delay = max(MELEE_ATK_MIN_DELAY, MELEE_ATK_BASE_DELAY - meleeSpeedStat)
        else if(S.isSpell)
            // Intelligence alone already gets a caster reasonably fast on its own;
            // Agility adds a small standalone bonus that only really grows once paired
            // with real Intelligence (see SPELL_AGI_SYNERGY_DIVISOR above).
            var/spellSpeedStat = GetEffectiveIntelligence() + (GetEffectiveAgility() * GetEffectiveIntelligence() / SPELL_AGI_SYNERGY_DIVISOR)
            delay = max(SPELL_ATK_MIN_DELAY, SPELL_ATK_BASE_DELAY - spellSpeedStat)
        else
            delay = 10

        if(wasDefending)
            delay += DEFEND_ATTACK_SPEED_PENALTY

        return delay

// get_dist()/step_to() use Chebyshev (king-move) distance, which treats a
// diagonally-adjacent tile the same as a cardinally-adjacent one — but this game is
// 4-directional only (no diagonal movement, Main.dm's mob/Move() override), so combat
// adjacency needs its own check: true only when exactly one axis differs, not both.
// Used by EnemyNPCs.dm's AILoop() so enemies can't attack (or face) diagonally.
proc/IsCardinallyAdjacent(atom/A, atom/B, range=1)
    var/dx = abs(A.x - B.x)
    var/dy = abs(A.y - B.y)
    return (dx <= range && dy == 0) || (dx == 0 && dy <= range)

mob/proc
    // Check if the mob is in a battle-enabled area — checks the real per-area
    // battleModeOn var (Code/World/Area.dm), set via GM_BattleMode
    // (Code/Admin/Commands/GMCommands.dm).
    InBattleArea()
        var/turf/T = src.loc
        var/area/A = T ? T.loc : null
        return A && A.battleModeOn

// -----------------------------
// Animation state resolution
// -----------------------------
// Not every mob icon uses the same icon_state names for the same action. Confirmed by
// reading the actual .dmi files: Hero/Soldier/Wizard/Pilgrim/Goof-off/Sage all use
// "attack"/"weapon", but ALL FOUR Fighter icons (dw1fighter/dw2fighter/dw3malefighter/
// dw3femalefighter) instead split them per hand — "rightattack"/"leftattack" and
// "rightweapon"/"leftweapon", with no plain "attack"/"weapon" state at all. Asking
// flick() for a state an icon doesn't have silently plays nothing, which is why a
// Fighter had no swing animation and no weapon overlay whatsoever.
//
// ResolveAnimState() picks whatever the mob's icon actually HAS: the plain name when
// present, otherwise the right/left pair (alternating per swing, which is the whole
// point of a split-hand sprite set — a Fighter punches with alternating fists).
// Returns null when the icon has none of them, so callers can skip cleanly instead of
// flicking a nonexistent state.
mob/var/animAlternate = FALSE  // flipped once per swing by PlayAttackAnimation()

// icon_states() builds a fresh list per call, and this runs on every single swing in
// combat — cached per icon instead. Keyed by the icon itself; the same handful of
// class/monster icons are shared across every mob using them, so this stays tiny.
var/list/iconStateCache = list()

proc/GetCachedIconStates(icon_ref)
    if(!icon_ref) return list()
    var/key = "[icon_ref]"
    if(key in iconStateCache)
        return iconStateCache[key]
    var/list/states = icon_states(icon_ref)
    iconStateCache[key] = states
    return states

mob/proc/ResolveAnimState(baseName)
    var/list/states = GetCachedIconStates(icon)
    if(!states.len) return baseName  // no readable states — let the caller try anyway
    if(baseName in states) return baseName

    var/rightName = "right[baseName]"
    var/leftName = "left[baseName]"
    var/hasRight = (rightName in states)
    var/hasLeft = (leftName in states)

    if(hasRight && hasLeft)
        return animAlternate ? leftName : rightName
    if(hasRight) return rightName
    if(hasLeft) return leftName
    return null

mob/proc
    // Play animations for skills. duration (deciseconds) is how long the melee weapon
    // overlay stays visible — callers should pass their real attack-cycle length
    // (GetAttackDelay() for players, attackCooldown for enemies) so a slow attacker's
    // weapon visibly lingers out and a fast attacker's flashes and resets quickly,
    // matching how often they can actually swing again. Left at the old fixed 2
    // (0.2s) by default, which is what every caller used before this scaled — a
    // High-Agility swing and a low-Agility swing looked identical even though one
    // could legitimately swing 3x more often, which read as the weapon being
    // disconnected from the character's actual attack speed.
    PlayAttackAnimation(mob/user, datum/skill/S, mob/target = null, duration = 2)
        if(S.isMelee)
            // One flip per swing (not per state lookup) so the swing animation and its
            // weapon overlay below always agree on which hand is being used.
            user.animAlternate = !user.animAlternate

            var/attackState = user.ResolveAnimState("attack")
            if(attackState)
                // flick()'s own duration comes from the icon file's baked per-frame
                // Delay — apparently too short/single-frame to actually register
                // before it auto-reverts, same root issue the weapon overlay had
                // before that got its own fix above. Holding the pose manually for
                // S.cast_time (the same real windup already driving hit timing) ties
                // it to actual game timing instead of an un-editable .dmi framerate.
                // Only reverts if nothing else changed icon_state in the meantime
                // (death, a second swing already started) — same "don't stomp
                // something that happened after us" guard Attack.OnUse() uses for
                // Defend via defendToggleSession.
                var/priorState = user.icon_state
                user.icon_state = attackState
                spawn(S.cast_time)
                    if(user.icon_state == attackState)
                        user.icon_state = priorState
            // view(user), not "user <<" — the latter only reaches the attacker's own
            // client, so it silently never played at all for enemies (no client to
            // reach). This broadcasts to everyone nearby who can see the attack,
            // attacker included, same pattern TakeDamage() already uses for hit.wav.
            PlaySFXAt(user, istype(user, /mob/enemy) ? 'enemyattack.wav' : 'attack.wav', base = 60)
            if(target)
                // Layered directly on the mob actually being hit, not the turf in
                // front of the attacker. No pixel_y set here (unlike the turf case
                // below) — overlays inherit their parent atom's own pixel_y
                // automatically, so target already renders shifted correctly; setting
                // it again here would double-apply the offset instead of fixing it.
                // layer is nudged just above the target's own so it draws on top.
                var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                weaponOverlay.layer = target.layer + 0.1
                target.overlays += weaponOverlay
                spawn(duration)
                    target.overlays -= weaponOverlay
            else
                // Swinging at an empty tile (nobody in front) — fall back to the turf,
                // matched to the ATTACKER's own offset since there's no target mob.
                var/turf/targetTile = get_step(user, user.dir)
                if(targetTile)
                    var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                    weaponOverlay.pixel_y = user.pixel_y
                    targetTile.overlays += weaponOverlay
                    spawn(duration)
                        targetTile.overlays -= weaponOverlay
        else if(S.isSpell)
            // "cast" isn't a real state on ANY player icon (every one dumped is
            // world/hit/sleep/attack/weapon, plus defend on some) — so this flick has
            // always been a silent no-op. Routed through ResolveAnimState() so it
            // picks up a real "cast" state automatically if one is ever drawn, and
            // falls back to the attack state meanwhile rather than showing nothing.
            var/castState = user.ResolveAnimState("cast") || user.ResolveAnimState("attack")
            if(castState) flick(castState, user)
            PlaySFXAt(user, 'spell.wav', base = 70)  // see attack.wav note above
            if(target)
                // NOTE: unlike the melee weaponOverlay above, this still uses a plain
                // /icon instead of /image with an explicit .layer — /icon has no layer
                // property, so this overlay likely renders BEHIND the target's own
                // sprite rather than on top, the same visual bug the melee overlay had
                // before it was fixed. Left as-is rather than silently changed since
                // it's untested (no enemy casts spells yet, and this hasn't come up in
                // player testing) — worth the same /image treatment once it does.
                var/icon/spellOverlay = icon(user.icon, S.icon_state)
                target.overlays += spellOverlay
                spawn(6)
                    target.overlays -= spellOverlay

// -----------------------------
// Line (reach) melee hits
// -----------------------------
// Scans outward from this mob in the direction it's facing, tile by tile, and hits the
// FIRST mob it finds — stopping there rather than piercing through. Built for Thornwhip
// (SkillCatalog.dm), whose real behavior was confirmed twice by live OG testing:
// a 3-tile line attack in the facing direction that hits whichever enemy is closest
// within that line (1, 2, or 3 tiles out, not always the full 3) and stops on the first
// one found.
//
// Deliberately NOT built on Projectiles.dm's pierces flag — that models a travelling
// projectile that can pass through several targets, which is explicitly not what the OG
// does here. This is an instant reach attack: no travel time, no visible projectile,
// just a longer arm.
//
// Walls don't block it yet. Adding that means deciding what counts as blocking (dense
// turfs only? dense objs too?), which isn't confirmed either way from the OG, and
// guessing would be a real behavior change rather than a gap being filled.
mob/proc
    PerformLineHit(datum/skill/S, reach = 3)
        var/mult = S ? S.damage_multiplier : 1
        var/turf/T = src.loc

        for(var/i = 1 to reach)
            T = get_step(T, dir)
            if(!T) return

            for(var/mob/M in T.contents)
                if(M == src) continue
                if(M.HP <= 0) continue

                var/damage = round((GetEffectiveStrength() + attackBonus) * mult)
                var/isCrit = RollCrit()
                if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
                M.TakeDamage(damage, src, isMagic = FALSE, isCrit = isCrit)
                return  // first mob found ends the scan — no pierce
