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
        var/dodgeChance = min(DODGE_MAX_PERCENT, DODGE_BASE_PERCENT + Agility * DODGE_AGILITY_SCALE)
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
    GetDefense()
        return round((Agility + Vitality) / PHYSICAL_DEFENSE_DIVISOR)

    GetMagicDefense()
        return round((Vitality + Intelligence) / MAGIC_DEFENSE_DIVISOR)

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
        var/critChance = min(CRIT_MAX_PERCENT, CRIT_BASE_PERCENT + Spirit * CRIT_SPIRIT_SCALE)
        return prob(critChance)

mob/proc
    // Apply damage to this mob. isMagic picks which defense stat mitigates it
    // (ApplySpellDamage() below passes TRUE; melee's default FALSE is correct as-is).
    // isCrit only affects the message shown — the damage number itself is expected to
    // already include the crit multiplier by the time it gets here (see
    // PerformMeleeHit()/ApplySpellDamage()), same division of labor as isDefending's
    // reduction happening in here while the crit roll happens at the source.
    TakeDamage(damage, mob/attacker, isMagic = FALSE, isCrit = FALSE)
        if(HP <= 0) return

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
            return

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

        HP -= damage
        view(src) << output(isCrit ? "[src] takes a critical hit for [damage] damage! (HP: [max(HP,0)])" : "[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

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
            if(attacker.Party && attacker.Party.shareExp)
                // Split evenly among the party (Code/Player/Party.dm) — no
                // solo-vs-group penalty yet, that formula isn't confirmed (TODOList.md).
                // Gold splits on the same shareExp flag rather than getting its own
                // toggle — one "we're sharing spoils" switch, not two.
                var/memberCount = attacker.Party.members.len
                var/share = max(1, round(reward / memberCount))
                var/goldShare = goldDrop ? max(1, round(goldDrop / memberCount)) : 0
                for(var/mob/player/M in attacker.Party.members)
                    M.Exp += share
                    M.Gold += goldShare
                    M.LevelCheck()
            else
                attacker.Exp += reward
                attacker.Gold += goldDrop
                attacker.LevelCheck()

            if(goldDrop)
                attacker << output("You gain [goldDrop] Gold.", "Info")

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
            src.StatPoints += 5
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
    // Melee hit detection
    PerformMeleeHit(datum/skill/S)
        var/turf/T = get_step(src, dir)
        if(!T) return

        for(var/mob/M in T.contents)
            if(M == src) continue
            if(M.HP <= 0) continue

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
            var/mult = S ? S.damage_multiplier : 1
            var/damage = round(Strength * mult)
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
    // Spell damage helper
    ApplySpellDamage(mob/target, damage, element)
        if(!target) return

        if(element)
            if(target.elementalWeakness == element)
                damage = round(damage * (100 + ELEMENTAL_WEAKNESS_BONUS_PERCENT) / 100)
            else if(target.elementalResistance == element)
                damage = round(damage * (100 - ELEMENTAL_RESISTANCE_REDUCTION_PERCENT) / 100)

        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        target.TakeDamage(damage, src, isMagic = TRUE, isCrit = isCrit)
        // Can later add AoE and more elaborate elemental effects (status ailments tied
        // to an element, etc.) — this proc just handles the damage-modifier half.

mob/proc
    // Heal helper — symmetric to ApplySpellDamage() above but restores HP instead,
    // capped at MaxHP. No dodge/elemental interaction (can't dodge or resist being
    // healed). Used by GenericSpell's healing branch (SkillCatalog.dm) and Rest.
    ApplyHeal(mob/target, amount)
        if(!target) return
        target.HP = min(target.MaxHP, target.HP + amount)
        target << output("You are healed for [amount] HP! (HP: [target.HP]/[target.MaxHP])", "Info")

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
            var/meleeSpeedStat = sqrt(Agility * max(Vitality, Intelligence))
            delay = max(MELEE_ATK_MIN_DELAY, MELEE_ATK_BASE_DELAY - meleeSpeedStat)
        else if(S.isSpell)
            // Intelligence alone already gets a caster reasonably fast on its own;
            // Agility adds a small standalone bonus that only really grows once paired
            // with real Intelligence (see SPELL_AGI_SYNERGY_DIVISOR above).
            var/spellSpeedStat = Intelligence + (Agility * Intelligence / SPELL_AGI_SYNERGY_DIVISOR)
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
    // Play animations for skills
    PlayAttackAnimation(mob/user, datum/skill/S, mob/target = null)
        if(S.isMelee)
            // One flip per swing (not per state lookup) so the swing animation and its
            // weapon overlay below always agree on which hand is being used.
            user.animAlternate = !user.animAlternate

            var/attackState = user.ResolveAnimState("attack")
            if(attackState) flick(attackState, user)
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
                spawn(2)
                    target.overlays -= weaponOverlay
            else
                // Swinging at an empty tile (nobody in front) — fall back to the turf,
                // matched to the ATTACKER's own offset since there's no target mob.
                var/turf/targetTile = get_step(user, user.dir)
                if(targetTile)
                    var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                    weaponOverlay.pixel_y = user.pixel_y
                    targetTile.overlays += weaponOverlay
                    spawn(2)
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
