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

        // Play melee animation & sound (src is this skill datum, matching
        // PlayAttackAnimation's real signature: mob/user, datum/skill/S, mob/target)
        user.PlayAttackAnimation(user, src, target)

        // Apply damage after cast_time (PerformMeleeHit expects a skill datum, not a
        // target mob — it already finds whoever's on the tile in front of user itself)
        spawn(cast_time)
            user.PerformMeleeHit(src)

        // Re-enable action based on stats (src is this skill datum, which is what
        // GetAttackDelay actually needs to check isMelee/isSpell against)
        spawn(user.GetAttackDelay(src))
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

        // Play spell animation & sound (src is this skill datum, matching
        // PlayAttackAnimation's real signature: mob/user, datum/skill/S, mob/target)
        user.PlayAttackAnimation(user, src, target)

        // Apply damage after cast_time
        spawn(cast_time)
            user.ApplySpellDamage(target, 10, "fire")

        // Re-enable action based on stats (src is this skill datum, which is what
        // GetAttackDelay actually needs to check isMelee/isSpell against)
        spawn(user.GetAttackDelay(src))
            user.canAct = TRUE