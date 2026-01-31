datum/Skill
    var
        skillName = "Unnamed Skill"
        description = "No description."
        icon_state = null
        cooldown = 0
        mana_cost = 0
        cast_time = 0
        isMelee = FALSE

    proc/Activate(mob/user, mob/target) return
    // To be overridden by specific skills
datum/skill/Attack
    parent_type = /datum/Skill

    New()
        ..()
        skillName = "Attack"
        description = "A basic melee strike."
        icon_state = "weapon"
        isMelee = TRUE

    Activate(mob/user, mob/target)
        if (!user.canMove) return
        user.canMove = FALSE

        flick("attack", user)
        user << sound('attack.wav', volume = 60)

        var/turf/target_tile = get_step(user, user.dir)
        if (!target_tile) return

        flick("attack", target_tile)

        var/icon/weaponIcon = icon(user.icon, icon_state, user.dir)
        target_tile.overlays += weaponIcon
        spawn(2) target_tile.overlays -= weaponIcon

        for (var/mob/M in target_tile.contents)
            if (M != user && M.HP > 0)
                M.overlays += weaponIcon
                spawn(2) M.overlays -= weaponIcon
                M.TakeDamage(user.Strength)

        spawn(3) user.canMove = TRUE