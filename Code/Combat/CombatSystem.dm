// -----------------------------
// MOB COMBAT PROCS
// -----------------------------
// Shared by players AND enemies — every proc here is a plain mob/proc, not split by
// type, so the same code path handles "player attacks enemy" and "enemy attacks
// player" identically.
//
// Attack pipeline: UseSkillSlot()/AILoop() decides to attack -> PlayAttackAnimation()
// (visual/audio only) -> PerformMeleeHit()/ApplySpellDamage() finds who's hit and
// calls TakeDamage() -> TakeDamage() rolls dodge, applies damage, calls Die() +
// CleanUpDead() at 0 HP -> Die() credits the attacker's Exp/LevelCheck() and branches
// player-respawn vs. enemy-cleanup. See Markdowns/CodeNotes.md for OG-confirmation
// status of the numbers below.
#define DEATH_EXP_LOSS_PERCENT 5
#define DEATH_GOLD_LOSS_PERCENT 50
#define RESPAWN_AUTO_DELAY 600  // world.time units (60 real seconds)

mob/var/isDead = FALSE
mob/var/deathTime = 0

// Whoever landed the FIRST hit on this mob — Die() credits them, not whoever landed
// the killing blow, so a fight can't be sniped at the last moment.
mob/var/mob/firstAttacker = null

// Toggled by datum/skill/Defend (SkillDatum.dm) — TRUE while holding up a shield.
mob/var/isDefending = FALSE
#define DEFEND_DAMAGE_REDUCTION_PERCENT 50

// TRUE mid-Jump (SkillCatalog.dm) -- attacks miss and ground fire can't reach.
mob/var/tmp/isAirborne = FALSE

// Hide (SkillCatalog.dm). Invisibility sits at the same tier as GM ghost form, above
// the roof-reveal trick's level 1 (Area.dm), so no ordinary player or monster sees a
// hidden mob indoors or out. A client always renders its OWN mob regardless, so the
// hider just sees themselves faded to HIDE_ALPHA as the "you're hidden" cue.
#define HIDE_INVISIBILITY 2
#define HIDE_ALPHA 110
mob/var/tmp/isHidden = FALSE

mob/proc
    Hide()
        isHidden = TRUE
        invisibility = HIDE_INVISIBILITY
        alpha = HIDE_ALPHA
        ShowInfo("You vanish from sight.")

    // Called from every reveal trigger: a step (Step(), SmoothMovement.dm), using any
    // other ability (UseSkillSlot(), PlayerTemplate.dm), a landed hit (TakeDamage()),
    // and every direct-damage path -- poison, burn, hazard fields, hazard terrain.
    // No-op when not hidden, so callers don't need to check first.
    Unhide()
        if(!isHidden) return
        isHidden = FALSE
        if(!isGhostform) invisibility = 0  // ghost form keeps its own, higher, invisibility
        alpha = 255
        ShowInfo("You reappear!")

    // Whether monsters' AI and single-target skills may pick this mob as a target at
    // all. Area hits (AoE blasts, projectiles, a swing at a tile) can still land on a
    // hidden mob -- and that hit reveals them.
    IsTargetable()
        return !isHidden && !isGhostform

// Invented, not OG -- chance each LANDED hit (dodges don't count) wakes a mob out of
// the Sleep spell (StatusEffects.dm). 100 = any hit wakes, 0 = sleeps the full duration.
// Defined here, not beside SLEEP_DURATION, because this file compiles first.
#define SLEEP_WAKE_ON_HIT_PERCENT 50

// CombatSide() return values -- see CanHarm() below TakeDamage().
#define COMBAT_SIDE_PLAYERS  "players"
#define COMBAT_SIDE_MONSTERS "monsters"

// Bumped whenever isDefending is toggled BY THE PLAYER (Defend.OnUse()) — lets
// Attack.OnUse() auto-restore a defend stance it dropped mid-swing without stomping a
// manual toggle that happened in the meantime.
mob/var/defendToggleSession = 0

mob/proc
    // Drops an active defend stance for an attack/cast. Returns whether it was
    // actually defending, which the caller passes to RestoreDefendIfUntouched().
    DropDefendForAction()
        if(!isDefending) return FALSE
        isDefending = FALSE
        icon_state = "world"
        return TRUE

    // Re-raises the stance DropDefendForAction() dropped, unless the player toggled
    // Defend themselves in the meantime (mySession = defendToggleSession at drop time).
    RestoreDefendIfUntouched(wasDefending, mySession)
        if(wasDefending && defendToggleSession == mySession)
            isDefending = TRUE
            icon_state = "defend"

    // Ends the stance for good (lying down in a bed) -- unlike DropDefendForAction(),
    // nothing auto-resumes it; the player re-raises it with Defend after waking. Bumps
    // the session even when not currently defending, so an Attack that dropped the
    // stance mid-swing can't re-raise it on the sleeping mob when its recovery ends.
    CancelDefend()
        defendToggleSession++
        isDefending = FALSE

// OG-confirmed (unsorted.dm:625, hit()): dodgeChance = min(75, round(agility * 0.75)).
// Only the dodge-chance roll itself is confirmed — hit()'s trace falls into
// un-reconstructed bytecode right after this, so whether anything downstream still
// modifies the roll (e.g. a class or status-effect adjustment) is unknown.
#define DODGE_BASE_PERCENT 0
#define DODGE_AGILITY_SCALE 0.75
#define DODGE_MAX_PERCENT 75

mob/proc
    RollDodge()
        var/dodgeChance = min(DODGE_MAX_PERCENT, round(DODGE_BASE_PERCENT + GetEffectiveAgility() * DODGE_AGILITY_SCALE))
        return prob(dodgeChance)

// How the two defense stats are derived. The mitigation STEP that consumes them lives
// in MitigateDamage() (DamageFormula.dm) with the rest of the damage pipeline.
#define PHYSICAL_DEFENSE_DIVISOR 4
#define MAGIC_DEFENSE_DIVISOR 4

mob/proc
    // defenseBonus/magicDefenseBonus are Increase/Barrier buffs (StatusEffects.dm);
    // equipDefenseBonus/equipMagicDefenseBonus are their amulet equivalents
    // (Inventory.dm) — added here rather than to the stats so neither trips a
    // stat-cap check or gets baked into a mid-buff/mid-equip save.
    GetDefense()
        return round((GetEffectiveAgility() + GetEffectiveVitality()) / PHYSICAL_DEFENSE_DIVISOR) + defenseBonus + equipDefenseBonus

    GetMagicDefense()
        return round((GetEffectiveVitality() + GetEffectiveIntelligence()) / MAGIC_DEFENSE_DIVISOR) + magicDefenseBonus + equipMagicDefenseBonus

// Rolled by the ATTACKER (reads src's own Spirit). Applies to both melee and spell
// damage — nothing says crit is melee-only.
#define CRIT_BASE_PERCENT 0
#define CRIT_SPIRIT_SCALE 1
#define CRIT_MAX_PERCENT 50
#define CRIT_DAMAGE_PERCENT 150

mob/proc
    RollCrit()
        var/critChance = min(CRIT_MAX_PERCENT, CRIT_BASE_PERCENT + GetEffectiveSpirit() * CRIT_SPIRIT_SCALE)
        return prob(critChance)

mob/proc
    // isMagic picks which defense stat mitigates the hit. isCrit only affects the
    // message shown — the damage number is expected to already include the crit
    // multiplier by the time it gets here. Returns whether the hit actually landed
    // (FALSE for already-dead/blocked/dodged) — Projectiles.dm's Launch() uses this to
    // decide whether a projectile stops here or keeps flying.
    TakeDamage(damage, mob/attacker, isMagic = FALSE, isCrit = FALSE)
        if(HP <= 0) return FALSE
        if(isGhostform) return FALSE  // also covers attacker-less damage; CanHarm() handles the rest

        // Friendly fire / coop mode -- see CanHarm() below. Only a direct melee swing
        // normally gets this far blocked; projectiles, blasts and fire fields already
        // skip targets CanHarm() rejects before calling in here.
        if(attacker && !attacker.CanHarm(src))
            if(istype(attacker, /mob/player) && CombatSide() == COMBAT_SIDE_PLAYERS)
                attacker.ShowInfo("Coop mode is active here — you cannot attack other players or their pets.")
            return FALSE

        // Mid-Jump: the attack passes underneath. Returns FALSE like a dodge, so a
        // projectile keeps flying past instead of stopping here.
        if(isAirborne)
            ShowCombatNumber(src, "miss", "#ffffff")
            return FALSE

        var/isEnemy = istype(src, /mob/enemy)

        if(RollDodge())
            // view(src), not bare view() — bare view() centers on usr, which is
            // unreliable outside a code path triggered directly by a verb (e.g. an
            // enemy's AILoop() calling this via PerformMeleeHit()).
            PlaySFXAt(src, isEnemy ? 'enemydodge.wav' : 'dodge.wav')
            view(src) << output("[src] dodges the attack!", "Info")
            ShowCombatNumber(src, "miss", "#ffffff")
            return FALSE

        flick("hit", src)
        PlaySFXAt(src, isEnemy ? 'enemyhit.wav' : 'hit.wav')

        damage = MitigateDamage(damage, isMagic)  // DamageFormula.dm

        if(!firstAttacker && attacker && attacker != src)
            firstAttacker = attacker

        HP -= damage
        Unhide()  // a landed hit reveals a hidden mob (Hide, SkillCatalog.dm)
        view(src) << output(isCrit ? "[src] takes a critical hit for [damage] damage! (HP: [max(HP,0)])" : "[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")
        ShowCombatNumber(src, "[damage]", isCrit ? "#ffff00" : DAMAGE_NUMBER_COLOR)
        ShowFloatingHPBar()

        // Being hit MIGHT break the Sleep spell (SLEEP_WAKE_ON_HIT_PERCENT, above) --
        // a guaranteed wake made Sleep worth one free hit and nothing more, a
        // guaranteed hold made it a free beating for the whole duration. Bed sleep
        // always breaks (not OG -- a remake call: nobody naps through a monster
        // hitting them).
        if(prob(SLEEP_WAKE_ON_HIT_PERCENT))
            RemoveStatusEffect(/datum/status_effect/sleep)
        WakeUp()

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

        return TRUE

// -----------------------------
// Friendly fire / coop mode
// -----------------------------
// Two sides: players plus their pets, and wild monsters. Coop mode is per area
// (Area.dm's battleAllowsPvP, toggled by GM_CoopMode) and judged by the TARGET's area:
//   Coop ON  (default) -- a side can only hurt the other side.
//   Coop OFF           -- anyone can hurt anyone: player vs player, pet vs pet, etc.
// Standing exceptions either way: wild monsters never hurt each other (their spells
// would otherwise shred their own pack), and a pet and its own owner never hurt each
// other.
//
// Staff on GM rules (UsesGodRules(), AdminLevels.dm) ignore coop completely, in both
// directions: they can hurt anyone but themselves, and anything can hurt them. Only
// ghost form protects them. That's for DAMAGE -- AI picking who to chase passes
// forAI = TRUE and judges a GM like any player, so monsters and pets hit a GM with
// stray attacks but pets don't go hunting GMs across a coop town.
//
// Every damage path asks this one proc -- TakeDamage() here, projectiles
// (Projectiles.dm), AoE blasts and Sleep/Stopspell (SkillCatalog.dm), and fire fields
// (HazardFields.dm) -- so the rule can't drift between them the way the old per-file
// "is it an enemy?" checks did. (COMBAT_SIDE_* are defined at the top of this file.)

mob/proc
    CombatSide()
        if(istype(src, /mob/enemy))
            var/mob/enemy/E = src
            return E.owner ? COMBAT_SIDE_PLAYERS : COMBAT_SIDE_MONSTERS
        return COMBAT_SIDE_PLAYERS

    CanHarm(mob/target, forAI = FALSE)
        if(!target || target == src) return FALSE
        // GM_GhostForm: untouchable by everything, GM or not, coop or not.
        if(target.isGhostform) return FALSE

        if(istype(src, /mob/enemy))
            var/mob/enemy/E = src
            if(E.owner && E.owner == target) return FALSE
        if(istype(target, /mob/enemy))
            var/mob/enemy/T = target
            if(T.owner && T.owner == src) return FALSE

        if(!forAI && (UsesGodRules() || target.UsesGodRules()))
            return TRUE

        var/mySide = CombatSide()
        var/theirSide = target.CombatSide()
        if(mySide == COMBAT_SIDE_MONSTERS && theirSide == COMBAT_SIDE_MONSTERS)
            return FALSE
        if(mySide != theirSide)
            return TRUE

        // Same side (player/pet vs player/pet) -- only where coop is off.
        var/turf/T = target.loc
        var/area/A = istype(T) ? T.loc : null
        return A && A.battleAllowsPvP

mob/proc
    // Base drops nothing; mob/enemy overrides with the real drop roll (EnemyNPCs.dm).
    // Declared on the base so Die() can call it unconditionally.
    DropLoot(mob/killer)
        return

mob/proc
    // Never applies to players, who go through the isDead/respawn flow in Die() instead.
    CleanUpDead()
        if(istype(src, /mob/player)) return
        spawn(100)  // lets the corpse linger briefly before it disappears
            del src

mob/proc
    // Credit the attacker (not whoever landed the finishing blow), then branch on
    // player vs. enemy.
    Die(mob/attacker)
        view(src) << output("[src] has been defeated!", "Info")

        // Reward the first attacker (TakeDamage()'s firstAttacker), falling back to
        // the killer when there's no recorded first hit (poison, GM_KillMonsters, etc).
        if(firstAttacker)
            attacker = firstAttacker

        ClearStatusEffects()

        if(attacker)
            // OG-confirmed (unsorted.dm:6899, KillReward()). Three structural
            // differences from the old split-evenly version, all real findings, not
            // just number tweaks:
            //   1. ×5 base multiplier before anything else. (expReward/goldReward on
            //      MonsterRoster.dm are small placeholder guesses, not pre-scaled — a
            //      Level-1 monster's 3 exp × 5 = 15 = exactly Nexp's level-1 threshold,
            //      which lines up with "one kill dings you to level 2" as an intended
            //      early beat, not a coincidence.)
            //   2. Only the KILLER's own amulets apply, to the pool BEFORE any split —
            //      not each member's own amulets applied to their own share.
            //   3. A party's shared pool GROWS (doesn't just redivide the solo total),
            //      and each eligible member gets that inflated pool's per-member share.
            // Reuses the existing equipExpBonusPercent/equipGoldBonusPercent totals
            // (Inventory.dm's ApplyAmuletBonuses) as an approximation of the OG's true
            // per-amulet compounding — identical when 0 or 1 relevant amulet is worn,
            // slightly low only in the rare case of two of the exact same amulet type
            // (e.g. two Amulets of Wealth: +100% summed here vs. OG's ×1.5×1.5 = +125%
            // compounded). Not worth new bookkeeping just for that edge case.
            var/baseExp = round(src.expReward * 5 * (100 + attacker.equipExpBonusPercent) / 100)
            var/baseGold = round(src.goldReward * 5 * (100 + attacker.equipGoldBonusPercent) / 100)

            var/attackerGoldGained = 0

            if(attacker.Party && attacker.Party.shareExp)
                // Eligible = same party, alive, within 8 levels of the killer.
                var/list/mob/player/eligible = list()
                for(var/mob/player/M in attacker.Party.members)
                    if(M.isDead) continue
                    if(abs(M.Level - attacker.Level) > 8) continue
                    eligible += M

                if(eligible.len <= 1)
                    attackerGoldGained = baseGold
                    attacker.Exp += baseExp
                    attacker.Gold += baseGold
                    attacker.LevelCheck()
                else
                    var/n = eligible.len
                    // (n-1)*0.25 + 1: solo pool = 100%, a 2-person party shares 125% of
                    // it, 3-person 150%, etc — and each member gets that share, not a
                    // further split. "+ 0.99" rounds the per-member share UP.
                    var/expShare = round(baseExp * ((n - 1) * 0.25 + 1) / n + 0.99)
                    var/goldShare = round(baseGold * ((n - 1) * 0.25 + 1) / n + 0.99)
                    for(var/mob/player/M in eligible)
                        M.Exp += expShare
                        M.Gold += goldShare
                        M.LevelCheck()
                        if(M == attacker) attackerGoldGained = goldShare
            else
                attackerGoldGained = baseGold
                attacker.Exp += baseExp
                attacker.Gold += baseGold
                attacker.LevelCheck()

            if(attackerGoldGained)
                attacker.ShowInfo("You gain [attackerGoldGained] Gold.")

            // Rolled inside the attacker branch so an unattributed death doesn't
            // scatter loot with nobody around to claim it.
            DropLoot(attacker)

        if(istype(src, /mob/player))
            isDead = TRUE
            deathTime = world.time
            // Exp is per-level progress (LevelCheck() resets it on every level-up), so
            // flooring at 0 already means a death penalty can never de-level you.
            Exp = max(0, Exp - round(Exp * DEATH_EXP_LOSS_PERCENT / 100))
            Gold = max(0, Gold - round(Gold * DEATH_GOLD_LOSS_PERCENT / 100))
            density = 0
            icon_state = "sleep"
            canAct = FALSE
            // Also cleared here (not just relied on from the attack's own recovery
            // spawn()) — a second hit landing during the "moving but can't attack yet"
            // window would otherwise leave this TRUE, letting Step() wave the death
            // lock through.
            attackRecoveryOnly = FALSE
            src.ShowInfo("You will auto-respawn in [RESPAWN_AUTO_DELAY / 10] seconds. You may press 5 on your numpad to respawn before then.")

            // Captures deathTime so an early respawn (numpad 5) followed by a second
            // death doesn't get yanked by this older timer firing late.
            var/thisDeath = deathTime
            spawn(RESPAWN_AUTO_DELAY)
                if(isDead && deathTime == thisDeath)
                    RespawnPlayer()
        else
            // CleanUpDead() (called from TakeDamage right after this) does the deletion.
            density = 0
            icon_state = "sleep"

mob/proc
    // The single respawn path — reached by Die()'s auto-timer or immediately via
    // numpad 5 (Interact(), PlayerVerbs.dm).
    RespawnPlayer()
        if(!isDead) return

        isDead = FALSE
        HP = MaxHP
        MP = MaxMP
        density = 1
        icon_state = "world"
        isDefending = FALSE
        // Cleared with the rest of the death state — it's only meaningful for the fight
        // that just ended. Left set, Die() would keep crediting whoever opened THAT
        // fight for every later death, handing a second killer's exp to the first one.
        firstAttacker = null
        ClearStatusEffects()
        loc = GetRespawnTurf()
        canAct = TRUE
        src.ShowInfo("You respawn.")

// Exp curve. OG-CONFIRMED SHAPE (unsorted.dm:6777, LevelCheck()):
//
//     exp_needed += round( (level**3 / 15 + level * 14 / 15) * exp_start )
//
// evaluated with the level just incremented TO. The OG tracks exp cumulatively while
// DWLR's Exp resets on every level-up, so the OG's per-level INCREMENT maps directly
// onto DWLR's Nexp with no conversion.
//
// `exp_start` is a per-CLASS multiplier, not a global — the exp curve's steepness
// differs by class in the original. Its real per-class values live only in types.dm's
// unrecoverable Chunk() blobs, so the numbers on each class (PlayerTemplate.dm) are
// invented. The shape is real; the steepness is a guess.
//
// The formula collapses to exactly exp_start at level 1 — (1 + 14)/15 = 1 — so
// exp_start IS the level 1->2 threshold. BASE_EXP stays 15 as the baseline so that
// still matches both the old quadratic's first level and the intended early beat of a
// Level-1 monster's 3 exp x 5 kill multiplier = 15 = one kill dings you to level 2.
//
// This is a much steeper curve than the old Nexp = 15 x Level**2 past the low levels
// (level 50 wants ~126k for the level instead of ~37k), which is the OG's own shape but
// has never been balanced against DWLR's monster exp values. Tune via exp_start.
#define BASE_EXP 15

// Matches ClassReference.md's stated cap for every class.
#define MAX_LEVEL 99

proc/GetNexpForLevel(level, exp_start = BASE_EXP)
    if(level < 1) level = 1
    if(exp_start <= 0) exp_start = BASE_EXP
    return max(1, round((level ** 3 / 15 + level * 14 / 15) * exp_start))

mob/proc
    // Loops rather than leveling at most once per call, and carries the leftover into
    // the next level instead of zeroing it. Awarding a lump of exp worth several levels
    // (a high-value monster at low level, or a shared party kill) used to grant exactly
    // one level and silently bin the entire remainder.
    LevelCheck()
        while(src.Level < MAX_LEVEL && src.Exp >= src.Nexp)
            src.Exp -= src.Nexp
            src.Level += 1
            src.Nexp = GetNexpForLevel(src.Level, src.exp_start)
            // OG-confirmed (unsorted.dm:6777, LevelCheck()): round(level/2) + 5, using
            // the level just incremented to above — NOT a flat +6 past the very first
            // level-up (that's only true for level 1->2: round(2/2)+5 = 6).
            src.StatPoints += round(src.Level / 2) + 5
            src.RecalculateVitals()  // Level affects MaxHP/MaxMP too
            src.ShowInfo("You are now Level [src.Level]")
            src << sound('levelup.wav', channel = 2, volume = client ? client.ScaledVolume() : 100)

            // Enemies also route through this (Die()'s attacker.LevelCheck() call
            // above), so guard skill-learning to players only.
            if(istype(src, /mob/player))
                var/mob/player/P = src
                P.CheckSkillUnlocks()

mob/proc
    // M, when passed, is the target captured at the INSTANT the swing started
    // (UseSkillSlot()/AILoop()) — trusted from capture time and never re-validated
    // here (only re-checked for still being alive). A target legitimately in range at
    // swing-start that steps away during the windup still gets hit; RollDodge() above
    // is the only thing that should turn a committed swing into a miss. Falls back to
    // scanning the tile ahead only when no target was captured up front.
    PerformMeleeHit(datum/skill/S, mob/M = null)
        if(!M)
            var/turf/T = get_step(src, dir)
            if(!T) return
            for(var/mob/X in T.contents)
                if(X.HP <= 0) continue
                if(!CanHarm(X)) continue  // skip self, ghosts, allies -- not swallow the swing
                M = X
                break

        if(!M || M.HP <= 0) return
        // A normal swing can't reach a mob sharing your tile (stacked after a Jump/
        // Quakejump landing) -- including a locked target that moved underneath you
        // mid-windup. Area attacks (AoE spells, Club's spin, Quakejump's ring) don't
        // come through here and still hit.
        if(M.loc == loc) return

        var/mult = S ? S.damage_multiplier : 1
        ResolvePhysicalHit(M, mult)

    // Shared by PerformMeleeHit()/PerformLineHit() — builds a physical hit and applies
    // it. The base number comes from ComputePhysicalDamage() (DamageFormula.dm), which
    // owns every coefficient; only the crit step is applied here.
    ResolvePhysicalHit(mob/target, mult)
        var/damage = ComputePhysicalDamage(mult)
        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        return target.TakeDamage(damage, src, isMagic = FALSE, isCrit = isCrit)

// OG-confirmed (unsorted.dm:1412, Element()): a real multiplier matrix between the
// spell's element and the TARGET's own elemental type — not a flat single-string
// weakness/resistance. Target types are the same 8 the OG uses; spell elements are
// whatever SkillDatum.dm/SkillCatalog.dm already assign ("fire"/"ice"/"lightning"/null
// for physical). "holy" is unused by any current DWLR spell but kept for a future one.
// Every number here is the real OG value, not a guess — see Markdowns/OGCombatFormulas.md §3/§11.
proc/GetElementalMultiplier(spellElement, targetType)
    if(!spellElement) return 1  // physical — OG: flat 1, no target-type check at all
    if(!targetType) targetType = "Normal"

    var/static/list/matrix = list(
        "fire" = list("Normal" = 1, "Fire" = 0.5, "Water" = 0.5, "Ice" = 1.5, "Air" = 1, "Iron" = 1, "Plant" = 1.5, "Darkness" = 1),
        "ice" = list("Normal" = 1, "Fire" = 1.5, "Water" = 1, "Ice" = 0.5, "Air" = 1.5, "Iron" = 0.5, "Plant" = 1, "Darkness" = 1),
        "lightning" = list("Normal" = 1, "Fire" = 1, "Water" = 1.5, "Ice" = 1, "Air" = 0.5, "Iron" = 1.5, "Plant" = 0.5, "Darkness" = 1),
        "holy" = list("Normal" = 1, "Fire" = 1, "Water" = 1, "Ice" = 1, "Air" = 1, "Iron" = 1, "Plant" = 1, "Darkness" = 1.5),
    )

    var/list/row = matrix[spellElement]
    if(!row) return 1
    return row[targetType] || 1

// A mob's own elemental type — REAL OG data for monsters (MonsterRoster.dm's
// mobElement column, CERTAIN confidence per Markdowns/CodeNotes.md), fed straight into
// GetElementalMultiplier() as the target side. Players leave this null (= "Normal").
mob/var/mobElement = null

mob/proc
    // Returns TakeDamage()'s landed/dodged result — Projectiles.dm's Impact() passes
    // this back up to Launch() so a dodged shot keeps flying instead of stopping.
    ApplySpellDamage(mob/target, damage, element)
        if(!target) return FALSE

        damage = round(damage * GetElementalMultiplier(element, target.mobElement))

        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        return target.TakeDamage(damage, src, isMagic = TRUE, isCrit = isCrit)

mob/proc
    // Symmetric to ApplySpellDamage() but restores HP, capped at MaxHP. No dodge/
    // elemental interaction.
    ApplyHeal(mob/target, amount)
        if(!target) return
        // Number shown is the spell's full rated power, not whatever actually landed
        // after the MaxHP cap — confirmed real-game behavior.
        target.HP = min(target.MaxHP, target.HP + amount)
        target.ShowInfo("You are healed for [amount] HP! (HP: [target.HP]/[target.MaxHP])")
        ShowCombatNumber(target, "[amount]", "#00ff00")
        target.ShowFloatingHPBar()

#define MELEE_ATK_BASE_DELAY 12
#define MELEE_ATK_MIN_DELAY 4
#define SPELL_ATK_BASE_DELAY 14
#define SPELL_ATK_MIN_DELAY 6
#define DEFEND_ATTACK_SPEED_PENALTY 3

mob/proc
    // OG-confirmed (unsorted.dm:5302, AttackDelay()): one flat term — Agility ÷ 10,
    // rounded to the nearest 0.5 — subtracted from a base delay. No Vitality/
    // Intelligence blending and no melee-vs-spell split in the OG; BASE/MIN still
    // differ per skill type since those constants aren't OG-recovered, just the shape
    // of the formula applied to them is.
    GetAttackDelay(datum/skill/S, wasDefending = FALSE)
        var/delay
        var/agiTerm = round(GetEffectiveAgility() / 10, 0.5)
        if(S.isMelee)
            delay = max(MELEE_ATK_MIN_DELAY, MELEE_ATK_BASE_DELAY - agiTerm)
        else if(S.isSpell)
            delay = max(SPELL_ATK_MIN_DELAY, SPELL_ATK_BASE_DELAY - agiTerm)
        else
            delay = 10

        if(wasDefending)
            delay += DEFEND_ATTACK_SPEED_PENALTY

        return delay

// get_dist()/step_to() use Chebyshev distance (diagonal counts as adjacent), but this
// game is 4-directional only — true only when exactly one axis differs. The SAME tile
// doesn't count: a mob stacked on another (a Jump/Quakejump landing) isn't in melee
// range of it, so the AI moves off instead of swinging from underneath.
proc/IsCardinallyAdjacent(atom/A, atom/B, range=1)
    var/dx = abs(A.x - B.x)
    var/dy = abs(A.y - B.y)
    if(!dx && !dy) return FALSE
    return (dx <= range && dy == 0) || (dx == 0 && dy <= range)

// Whether a tile stops a spell/hazard from occupying it. A dense turf blocks on its own
// (walls), but so do dense OBJS standing on a passable turf — closed doors and signs.
// Doors toggle density at runtime, so this reads live state every call rather than
// anything cached. obj/projectile/IsTileBlocked() (Projectiles.dm) and
// SpawnHazardBlob() (HazardFields.dm) both route through here so the two can't drift.
proc/IsTurfBlocked(turf/T)
    if(!T) return TRUE
    if(T.density) return TRUE
    for(var/obj/O in T.contents)
        if(O.density) return TRUE
    return FALSE

// Every turf within a Manhattan radius of center — a DIAMOND, not a square. Movement
// and facing in this game are 4-directional, so a diamond is both the natural shape and
// what reads on screen as a circle: radius 1 is a 5-tile plus, radius 2 is 13 tiles.
// Shared by AoE spells (SkillCatalog.dm) and hazard-field blobs (HazardFields.dm) so
// the two can't disagree about what an area actually covers.
proc/GetDiamondTurfs(turf/center, radius = 1, skipBlocked = TRUE)
    var/list/turfs = list()
    if(!center) return turfs

    for(var/dx = -radius to radius)
        for(var/dy = -radius to radius)
            if(abs(dx) + abs(dy) > radius) continue
            var/turf/T = locate(center.x + dx, center.y + dy, center.z)
            if(!T) continue
            if(skipBlocked && IsTurfBlocked(T)) continue
            turfs += T

    return turfs

mob/proc
    // Real per-area battleModeOn var (Area.dm), set via GM_BattleMode (GMCommands.dm).
    InBattleArea()
        var/turf/T = src.loc
        var/area/A = T ? T.loc : null
        return A && A.battleModeOn

// -----------------------------
// Animation state resolution — not every mob icon uses the same icon_state names for
// the same action (e.g. Fighter icons split "attack"/"weapon" into per-hand "right"/
// "left" pairs instead). ResolveAnimState() picks whichever the mob's icon actually
// has. See Markdowns/CodeNotes.md for the full confirmed breakdown.
// -----------------------------
mob/var/animAlternate = FALSE  // flipped once per swing by PlayAttackAnimation()

// icon_states() builds a fresh list per call and this runs on every swing — cached per
// icon FILE instead.
//
// The cache key is the icon's path, so the ref handed in has to be file-backed. A
// runtime-built /icon — which is what every player wears, since RebuildIcon() paints a
// fresh copy — stringifies to the bare literal "/icon" regardless of which art it came
// from (verified 2026-09-10). Caching under that key handed the FIRST player's state list
// back for every portrait in the game afterward, so e.g. a Fighter (whose art splits
// "attack" into "rightattack"/"leftattack") resolved against a Hero's states and lost its
// swing animation. An unidentifiable ref is now read fresh rather than cached under a key
// that isn't actually unique.
var/list/iconStateCache = list()

proc/GetCachedIconStates(icon_ref)
    if(!icon_ref) return list()
    var/key = "[icon_ref]"
    if(key == "/icon") return icon_states(icon_ref)
    if(key in iconStateCache)
        return iconStateCache[key]
    var/list/states = icon_states(icon_ref)
    iconStateCache[key] = states
    return states

// Reads states off baseIcon — the registry's source art (PlayerIconColorPalette.dm) —
// rather than `icon`, which for a player is the recolored copy. SwapColor() doesn't
// rename states, so the source lists exactly the same ones, and unlike the copy it's a
// real file that caches correctly per portrait. Enemies have no baseIcon and fall through
// to their own file-backed `icon`.
mob/proc/ResolveAnimState(baseName)
    var/list/states = GetCachedIconStates(baseIcon || icon)
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

// Per-direction pixel nudge for the floating weapon overlay below — it renders on the
// tile ADJACENT to the attacker, not the attacker's own tile, so there's a real 32px
// seam between "hand" and "weapon" that redrawing the sprite itself can't close.
// Scoped to basePlayerIcon so a nudge tuned for one custom icon can't move anyone
// else's weapon — returns (0,0) for every icon not listed. Sign convention: pixel_x
// negative=left/positive=right; pixel_y is BYOND's bottom-up axis, negative=down/
// positive=up. See Markdowns/CodeNotes.md for the full sign-convention writeup.
proc/GetWeaponOverlayNudge(iconFilename, dir)
    if(iconFilename != "Cere.dmi")
        return list(0, 0)

    switch(dir)
        if(EAST)  return list(-10, -9)
        if(WEST)  return list(10, -5)
        if(NORTH) return list(0, 0)
        if(SOUTH) return list(0, 0)
    return list(0, 0)

mob/proc
    // duration (deciseconds) is how long the melee weapon overlay stays visible —
    // callers pass their real attack-cycle length so it lingers/resets in step with
    // how often the attacker can actually swing again.
    PlayAttackAnimation(mob/user, datum/skill/S, mob/target = null, duration = 2)
        if(S.isMelee)
            // One flip per swing (not per state lookup) so the pose and its weapon
            // overlay always agree on which hand is being used.
            user.animAlternate = !user.animAlternate

            var/attackState = user.ResolveAnimState("attack")
            if(attackState)
                // Held manually for S.cast_time rather than relying on flick()'s own
                // (too-short/single-frame) baked duration. Only reverts if nothing
                // else changed icon_state meanwhile (death, a second swing already
                // started).
                var/priorState = user.icon_state
                user.icon_state = attackState
                spawn(S.cast_time)
                    if(user.icon_state == attackState)
                        user.icon_state = priorState
            // view(user), not "user <<" — the latter only reaches the attacker's own
            // client, so this silently never played for enemies at all.
            PlaySFXAt(user, istype(user, /mob/enemy) ? 'enemyattack.wav' : 'attack.wav', base = 60)
            // A skill with its own spells.dmi art (Club's club, a claw, an axe) shows
            // THAT instead of the portrait's generic "weapon" state -- the caller draws
            // it via PlaySkillFX(). Drawing both stacked the skill's art on top of a
            // plain sword. Only a skill with no art of its own (plain Attack) falls
            // through to the portrait weapon below.
            if(ResolveSkillFXState(S.fx_state, user.dir, user.animAlternate))
                return
            var/list/weaponNudge = GetWeaponOverlayNudge(user.basePlayerIcon, user.dir)
            if(target)
                // Layered on the mob being hit, not the turf. Only the deliberate
                // nudge is added here, not target.pixel_y — overlays already inherit
                // their parent atom's own pixel_y automatically.
                var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                weaponOverlay.pixel_x = weaponNudge[1]
                weaponOverlay.pixel_y = weaponNudge[2]
                weaponOverlay.layer = target.layer + 0.1
                target.overlays += weaponOverlay
                spawn(duration)
                    target.overlays -= weaponOverlay
            else
                // Swinging at an empty tile — layered above the ATTACKER (not
                // targetTile, whose own layer is far below a mob's), since a big
                // enough nudge can pull this visually back onto the attacker's tile;
                // without this it silently renders behind the attacker's sprite.
                var/turf/targetTile = get_step(user, user.dir)
                if(targetTile)
                    var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                    weaponOverlay.pixel_x = weaponNudge[1]
                    weaponOverlay.pixel_y = user.pixel_y + weaponNudge[2]
                    weaponOverlay.layer = user.layer + 0.1
                    targetTile.overlays += weaponOverlay
                    spawn(duration)
                        targetTile.overlays -= weaponOverlay
        else if(S.isSpell)
            // "cast" isn't a real state on any player icon — falls back to "attack".
            var/castState = user.ResolveAnimState("cast") || user.ResolveAnimState("attack")
            if(castState) flick(castState, user)
            PlaySFXAt(user, 'spell.wav', base = 70)
            // The spell's own effect art is NOT drawn here. It used to be — as a plain
            // /icon built from the CASTER'S portrait file, which was wrong twice over: a
            // spell's art lives in spells.dmi, not on the player sprite, and a bare
            // /icon carries no .layer so it rendered behind the target anyway. Both
            // callers now draw it through PlaySkillFX() (SkillFX.dm) instead, which
            // reads the right file and layers correctly.

// The cast windup EVERY player spell plays before it takes effect -- Blaze, heals,
// damage and AoE spells, buffs, Sleep/Stopspell, Return, Revive: 10 castmeter.dmi
// frames over the caster, paced by GetAttackDelay() so a stronger caster winds up
// faster. Blaze was the only spell that had it; the rest fired after a flat delay.
//
// Synchronous -- sleeps through the whole windup. Returns FALSE if the caster died
// mid-cast; the caller must then stop WITHOUT touching canAct (Die() owns it).
mob/proc/PlayCastMeter(datum/skill/S, wasDefending = FALSE)
    PlaySFXAt(src, 'spell.wav', base = 70)

    var/atkDelay = GetAttackDelay(S, wasDefending)
    var/frameDelay = max(CAST_METER_MIN_FRAME_DELAY, atkDelay / CAST_METER_SPEED_DIVISOR)

    // A fresh image per frame, previous one explicitly removed rather than mutated in
    // place -- BYOND's overlays list snapshots appearance at add-time.
    var/image/prevFrame = null
    for(var/i = 1 to 10)
        var/image/meterFrame = image('castmeter.dmi', src, "[i]")
        meterFrame.layer = layer + 0.1  // draw over the caster, not behind
        if(prevFrame) overlays -= prevFrame
        overlays += meterFrame
        prevFrame = meterFrame
        sleep(frameDelay)
    if(prevFrame) overlays -= prevFrame

    return !isDead

// Real 3-stage cast for GenericSpell's healing branch — only for heal-tier skills with
// real spells.dmi art (Heal/Healmore/Healmost). Synchronous (sleep(), not spawn()) so
// nothing downstream can fire out of order relative to what's on screen.
mob/proc/PlayHealCastSequence(datum/skill/S, mob/target, heal_amount, wasDefending, mySession)
    if(!PlayCastMeter(S, wasDefending)) return  // died mid-cast

    // Resolution: the TARGET plays the skill's own spells.dmi state at its own baked
    // frame speed, held for HEAL_ANIM_DURATION before the heal lands and the number pops.
    // Reads S.fx_state through ResolveSkillFXState() (SkillFX.dm) — the heals were the
    // one place that used icon_state to name a spells.dmi state, which is what fx_state
    // is for everywhere else.
    if(target)
        var/healState = ResolveSkillFXState(S.fx_state)
        if(healState)
            var/image/healFx = image(SKILL_FX_FILE, target, healState)
            healFx.layer = target.layer + 0.1
            target.overlays += healFx
            sleep(HEAL_ANIM_DURATION)
            if(target) target.overlays -= healFx

    ApplyHeal(target, heal_amount)

    canAct = TRUE
    RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Line (reach) melee hits — scans outward from this mob tile by tile in its facing
// direction, hitting the FIRST mob found (stops there, no pierce). Built for
// Thornwhip (SkillCatalog.dm). Deliberately NOT built on Projectiles.dm's pierces flag
// — this is an instant reach attack, no travel time or visible projectile. Walls don't
// block it yet (unconfirmed from the OG which turfs/objs should).
// -----------------------------
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

                ResolvePhysicalHit(M, mult)
                return  // first mob found ends the scan — no pierce
