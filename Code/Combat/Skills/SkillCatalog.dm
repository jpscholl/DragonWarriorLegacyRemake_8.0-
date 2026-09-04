// -----------------------------
// Skill Catalog — generic framework + every named skill from ClassReference.md
// -----------------------------
// Every named skill below is a thin subtype of GenericPhysical or GenericSpell,
// setting only name/icon_state/cost/multiplier. A few skills (status effects, Rest/
// Return/Meditate, Revive, Classchange, Thornwhip) have a genuinely different shape
// and get their own OnUse(). Attack/Defend/Fireball/Blaze live in SkillDatum.dm, not
// here. See Markdowns/CodeNotes.md for placeholder/OG-confirmation history on the
// numbers below — every damage_multiplier/heal_amount/mana_cost is a tunable guess
// unless that doc says otherwise.

// -----------------------------
// Generic Physical — melee weapon/martial skills (Str or Agi gated)
// -----------------------------
datum/skill/GenericPhysical
    parent_type = /datum/skill
    isMelee = TRUE
    icon_state = "weapon"
    cast_time = 2

    var
        isRanged = FALSE

    // Hook for how contact is actually resolved — override this alone (e.g.
    // Thornwhip's line attack below) to change what a swing hits without
    // duplicating the whole windup/recovery sequence in OnUse().
    proc/PerformHit(mob/user, mob/target)
        user.PerformMeleeHit(src, target)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        user.PlayAttackAnimation(user, src, target)

        spawn(cast_time)
            PerformHit(user, target)
            if(!user.isDead) user.attackRecoveryOnly = TRUE

        spawn(atkDelay)
            if(user.isDead) return
            user.canAct = TRUE
            user.attackRecoveryOnly = FALSE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Generic Spell — offensive or healing magic (Int gated). isHealing picks the branch;
// damage spells scale off Intelligence via damage_multiplier, heals use heal_amount.
// -----------------------------
datum/skill/GenericSpell
    parent_type = /datum/skill
    isSpell = TRUE
    icon_state = "weapon"
    cast_time = 6

    var
        isHealing = FALSE
        heal_amount = 0
        // TRUE only for heal-tier skills with real spells.dmi art (Heal/Healmore/
        // Healmost) — routes through PlayHealCastSequence() (CombatSystem.dm) instead
        // of the generic spawn(cast_time) below.
        hasHealAnimation = FALSE

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Healing is allowed outside battle areas; damage spells are not.
        if(!isHealing && !user.InBattleArea()) return

        var/mob/actualTarget = isHealing ? (target || user) : target

        if(isHealing && actualTarget && actualTarget.HP >= actualTarget.MaxHP)
            user.ShowInfo("[actualTarget == user ? "You are" : "[actualTarget] is"] already at full HP.")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        if(isHealing && hasHealAnimation)
            user.PlayHealCastSequence(src, actualTarget, heal_amount, wasDefending, mySession)
            return

        user.PlayAttackAnimation(user, src, actualTarget)

        spawn(cast_time)
            if(isHealing)
                user.ApplyHeal(actualTarget, heal_amount)
            else
                user.ApplySpellDamage(target, round(user.GetEffectiveIntelligence() * damage_multiplier), src.element)

        spawn(user.GetAttackDelay(src, wasDefending))
            if(user.isDead) return
            user.canAct = TRUE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// =============================================================================
// PHYSICAL SKILLS (Str/Agi gated) — damage_multiplier scales Strength
// =============================================================================
datum/skill/Punch
    parent_type = /datum/skill/GenericPhysical
    skillName = "Punch"
    damage_multiplier = 1.0

datum/skill/Club
    parent_type = /datum/skill/GenericPhysical
    skillName = "Club"
    damage_multiplier = 1.1

datum/skill/IronClaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iron Claw"
    damage_multiplier = 1.2

datum/skill/Jump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Jump"
    damage_multiplier = 1.1

datum/skill/Hide
    parent_type = /datum/skill/GenericPhysical
    skillName = "Hide"
    damage_multiplier = 1.0

datum/skill/Magicknife
    parent_type = /datum/skill/GenericPhysical
    skillName = "Magicknife"
    damage_multiplier = 1.2

datum/skill/Boomerang
    parent_type = /datum/skill/GenericPhysical
    skillName = "Boomerang"
    damage_multiplier = 1.3
    isRanged = TRUE

datum/skill/Morningstar
    parent_type = /datum/skill/GenericPhysical
    skillName = "Morningstar"
    damage_multiplier = 1.3

datum/skill/Dash
    parent_type = /datum/skill/GenericPhysical
    skillName = "Dash"
    damage_multiplier = 1.3

datum/skill/Quakejump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Quakejump"
    damage_multiplier = 1.4

datum/skill/Fireclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Fireclaw"
    damage_multiplier = 1.4

datum/skill/Iceclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iceclaw"
    damage_multiplier = 1.4

// A 3-tile line attack in the facing direction, not a single-tile hit — overrides
// only PerformHit(), inheriting the rest of GenericPhysical's swing sequence as-is.
datum/skill/Thornwhip
    parent_type = /datum/skill/GenericPhysical
    skillName = "Thornwhip"
    damage_multiplier = 0.8
    var/reach = 3

    PerformHit(mob/user, mob/target)
        user.PerformLineHit(src, reach)

datum/skill/Lightsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Lightsword"
    damage_multiplier = 1.5

datum/skill/Battleaxe
    parent_type = /datum/skill/GenericPhysical
    skillName = "Battleaxe"
    damage_multiplier = 1.5

datum/skill/Flamesword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Flamesword"
    damage_multiplier = 1.6

datum/skill/Falconsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Falconsword"
    damage_multiplier = 1.7

datum/skill/Goldclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Goldclaw"
    damage_multiplier = 1.7

datum/skill/Chainsickle
    parent_type = /datum/skill/GenericPhysical
    skillName = "Chainsickle"
    damage_multiplier = 1.8

datum/skill/SwordOfLethargy
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sword Of Lethargy"
    damage_multiplier = 1.9

datum/skill/IceSaber
    parent_type = /datum/skill/GenericPhysical
    skillName = "Ice Saber"
    damage_multiplier = 1.9

datum/skill/Demonhammer
    parent_type = /datum/skill/GenericPhysical
    skillName = "Demonhammer"
    damage_multiplier = 2.0

datum/skill/DragonKiller
    parent_type = /datum/skill/GenericPhysical
    skillName = "DragonKiller"
    damage_multiplier = 2.3

datum/skill/ThunderSword
    parent_type = /datum/skill/GenericPhysical
    skillName = "ThunderSword"
    damage_multiplier = 2.6

// =============================================================================
// OFFENSIVE SPELLS (Int gated) — damage_multiplier scales Intelligence
// =============================================================================
datum/skill/Icebolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Icebolt"
    element = "ice"
    damage_multiplier = 0.7
    mana_cost = 4

datum/skill/Lightning
    parent_type = /datum/skill/GenericSpell
    skillName = "Lightning"
    element = "lightning"
    damage_multiplier = 0.9
    mana_cost = 5

datum/skill/Infernos
    parent_type = /datum/skill/GenericSpell
    skillName = "Infernos"
    element = "fire"
    damage_multiplier = 1.0
    mana_cost = 5

datum/skill/Icespears
    parent_type = /datum/skill/GenericSpell
    skillName = "Icespears"
    element = "ice"
    damage_multiplier = 1.1
    mana_cost = 6

datum/skill/Blazemore
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemore"
    element = "fire"
    damage_multiplier = 1.2
    mana_cost = 7

datum/skill/Blizzard
    parent_type = /datum/skill/GenericSpell
    skillName = "Blizzard"
    element = "ice"
    damage_multiplier = 1.3
    mana_cost = 8

datum/skill/Boom
    parent_type = /datum/skill/GenericSpell
    skillName = "Boom"
    element = "fire"
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Bang
    parent_type = /datum/skill/GenericSpell
    skillName = "Bang"
    element = "fire"
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Infermore
    parent_type = /datum/skill/GenericSpell
    skillName = "Infermore"
    element = "fire"
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Thordain
    parent_type = /datum/skill/GenericSpell
    skillName = "Thordain"
    element = "lightning"
    damage_multiplier = 1.6
    mana_cost = 10

datum/skill/Firevolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Firevolt"
    element = "fire"
    damage_multiplier = 1.6
    mana_cost = 10

datum/skill/Firebane
    parent_type = /datum/skill/GenericSpell
    skillName = "Firebane"
    element = "fire"
    damage_multiplier = 1.7
    mana_cost = 11

datum/skill/Snowstorm
    parent_type = /datum/skill/GenericSpell
    skillName = "Snowstorm"
    element = "ice"
    damage_multiplier = 1.8
    mana_cost = 12

datum/skill/Blazemost
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemost"
    element = "fire"
    damage_multiplier = 1.9
    mana_cost = 13

datum/skill/Explodet
    parent_type = /datum/skill/GenericSpell
    skillName = "Explodet"
    element = "fire"
    damage_multiplier = 2.2
    mana_cost = 16

// =============================================================================
// HEALING SPELLS (Int gated) — heal_amount is flat, not stat-scaled
// =============================================================================
datum/skill/Heal
    parent_type = /datum/skill/GenericSpell
    skillName = "Heal"
    icon_state = "heal"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 60
    mana_cost = 4

datum/skill/Healmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmore"
    icon_state = "healmore"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 30
    mana_cost = 8

// No dedicated "healus" art — reuses Healmore's icon_state.
datum/skill/Healus
    parent_type = /datum/skill/GenericSpell
    skillName = "Healus"
    icon_state = "healmore"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 40
    mana_cost = 10

datum/skill/Healmost
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmost"
    icon_state = "healmost"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 55
    mana_cost = 12

// No dedicated "healusmore" art — reuses Healmost's icon_state.
datum/skill/Healusmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healusmore"
    icon_state = "healmost"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 75
    mana_cost = 15

datum/skill/Vivify
    parent_type = /datum/skill/GenericSpell
    skillName = "Vivify"
    isHealing = TRUE
    heal_amount = 90
    mana_cost = 16

// Buff spells target self by default; facing an ally casts it on them instead.
datum/skill/BuffSpell
    parent_type = /datum/skill/StatusSpell

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        var/mob/actualTarget = target || user

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        user.PlayAttackAnimation(user, src, actualTarget)

        spawn(cast_time)
            actualTarget.ApplyStatusEffect(statusEffectType)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

datum/skill/Upper
    parent_type = /datum/skill/BuffSpell
    skillName = "Upper"
    statusEffectType = /datum/status_effect/buff/upper
    mana_cost = 3

datum/skill/Increase
    parent_type = /datum/skill/BuffSpell
    skillName = "Increase"
    statusEffectType = /datum/status_effect/buff/increase
    mana_cost = 3

datum/skill/Barrier
    parent_type = /datum/skill/BuffSpell
    skillName = "Barrier"
    statusEffectType = /datum/status_effect/buff/barrier
    mana_cost = 4

// =============================================================================
// STATUS-EFFECT SKILLS — apply a datum/status_effect (StatusEffects.dm) to the target.
// =============================================================================
datum/skill/StatusSpell
    parent_type = /datum/skill
    icon_state = "weapon"
    isSpell = TRUE
    cast_time = 4

    var
        statusEffectType = null
        noTargetMessage = "No target."

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!target)
            user.ShowInfo(noTargetMessage)
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        spawn(cast_time)
            target.ApplyStatusEffect(statusEffectType)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

datum/skill/Sleep
    parent_type = /datum/skill/StatusSpell
    skillName = "Sleep"
    statusEffectType = /datum/status_effect/sleep
    noTargetMessage = "No target to put to sleep."
    mana_cost = 5

datum/skill/Sleepmore
    parent_type = /datum/skill/Sleep
    skillName = "Sleepmore"
    statusEffectType = /datum/status_effect/sleep/more
    mana_cost = 9

datum/skill/Stopspell
    parent_type = /datum/skill/StatusSpell
    skillName = "Stopspell"
    statusEffectType = /datum/status_effect/silence
    noTargetMessage = "No target to silence."
    mana_cost = 7

// =============================================================================
// UTILITY SKILLS — own resource/effect shape, not a plain damage/heal spell
// =============================================================================

// Vitality-gated self-heal, no mana cost (works for Fighter/Soldier/Goof-off too).
datum/skill/Rest
    parent_type = /datum/skill
    skillName = "Rest"
    icon_state = "weapon"
    cast_time = 4

    var/heal_percent = 30

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        user.ShowInfo("You sit down to rest...")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxHP * heal_percent / 100))
            user.ApplyHeal(user, amount)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Spirit-gated MP restore — the mana-side equivalent of Rest.
datum/skill/Meditate
    parent_type = /datum/skill
    skillName = "Meditate"
    icon_state = "weapon"
    cast_time = 4

    var/restore_percent = 30

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        user.ShowInfo("You begin to meditate...")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxMP * restore_percent / 100))
            user.MP = min(user.MaxMP, user.MP + amount)
            user.ShowInfo("You restore [amount] MP! (MP: [user.MP]/[user.MaxMP])")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Teleports the caster back to the spawn point (GetPlayerSpawnTurf(), Area.dm).
datum/skill/Return
    parent_type = /datum/skill
    skillName = "Return"
    icon_state = "weapon"
    isSpell = TRUE
    mana_cost = 8
    cast_time = 6

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Return! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast Return!")

        spawn(cast_time)
            if(!user.isDead)
                user.loc = GetPlayerSpawnTurf()
                user.ShowInfo("You return to town!")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Resurrects a fallen ally, bypassing their RESPAWN_DELAY wait (Die(), CombatSystem.dm).
datum/skill/Revive
    parent_type = /datum/skill
    skillName = "Revive"
    icon_state = "weapon"
    isSpell = TRUE
    mana_cost = 12
    cast_time = 6

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!target || !istype(target, /mob/player))
            user.ShowInfo("Revive only works on a fallen ally.")
            return

        var/mob/player/P = target
        if(!P.isDead)
            user.ShowInfo("[P.name] isn't in need of reviving.")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Revive! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast Revive!")

        spawn(cast_time)
            if(P.isDead)
                P.isDead = FALSE
                P.density = 1
                P.icon_state = "world"
                P.canAct = TRUE
                P.HP = max(1, round(P.MaxHP * 0.5))
                P.ShowInfo("You have been revived by [user.name]!")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Goof-off's signature unlock — transforms this character into a Sage (DW3-style).
#define CLASSCHANGE_MIN_LEVEL 25
datum/skill/Classchange
    parent_type = /datum/skill
    skillName = "Classchange"
    icon_state = "weapon"

    OnUse(mob/user, mob/target = null)
        if(!istype(user, /mob/player)) return
        var/mob/player/P = user
        if(!P.canAct) return
        if(istype(P, /mob/player/Sage))
            P.ShowInfo("You are already a Sage.")
            return

        if(P.Level < CLASSCHANGE_MIN_LEVEL)
            P.ShowInfo("You must be at least level [CLASSCHANGE_MIN_LEVEL] to change your class.")
            return

        for(var/obj/item/amulet/A in P.contents)
            if(A.worn)
                P.ShowInfo("You must unequip everything before you can change your class.")
                return

        var/confirm = alert(P, "Are you sure you want to change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Classchange", "Yes", "No")
        if(confirm != "Yes") return

        if(!RunSageReclassFlow(P))
            return  // backed out at the icon step — nothing has changed, still the old class

        P.BecomeSage()
