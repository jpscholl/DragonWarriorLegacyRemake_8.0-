// -----------------------------
// Base Skill
// -----------------------------
datum/skill
    var
        skillName = "Unnamed Skill"
        description = "No description."
        icon_state = null
        cast_time = 0          // time before effect happens (animations/projectiles)
        mana_cost = 0
        isMelee = FALSE
        isSpell = FALSE

    proc/OnUse(mob/user, mob/target = null)
        // Base skill does nothing
        return

// -----------------------------
// Melee Attack Skill
// -----------------------------
datum/skill/Attack
    parent_type = /datum/skill

    New()
        ..()
        skillName = "Attack"
        icon_state = "weapon"
        isMelee = TRUE
        cast_time = 2

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        // Play melee animation & sound
        user.PlayAttackAnimation(user, target)

        // Apply damage after cast_time
        spawn(cast_time)
            user.PerformMeleeHit(target)

        // Re-enable action based on stats
        spawn(user.GetAttackDelay(user))
            user.canAct = TRUE

// -----------------------------
// Fireball Spell Skill
// -----------------------------
datum/skill/Fireball
    parent_type = /datum/skill

    New()
        ..()
        skillName = "Fireball"
        icon_state = "fireball"
        isSpell = TRUE
        cast_time = 6

    OnUse(mob/user, mob/target)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!target) return

        user.canAct = FALSE

        // Play spell animation & sound
        user.PlayAttackAnimation(user, target)

        // Apply damage after cast_time
        spawn(cast_time)
            user.ApplySpellDamage(target, 10, "fire")

        // Re-enable action based on stats
        spawn(user.GetAttackDelay(user))
            user.canAct = TRUE