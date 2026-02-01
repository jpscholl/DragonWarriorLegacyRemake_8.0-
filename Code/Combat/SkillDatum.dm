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

        var/turf/targetTile = get_step(user, user.dir)
        if (!targetTile) return

        flick("attack", targetTile)

        var/icon/weaponIcon = icon(user.icon, icon_state, user.dir)
        targetTile.overlays += weaponIcon
        spawn(2) targetTile.overlays -= weaponIcon

        for (var/mob/M in targetTile.contents)
            if (M != user && M.HP > 0)
                M.overlays += weaponIcon
                spawn(2) M.overlays -= weaponIcon
                M.TakeDamage(user.Strength)

        spawn(3) user.canMove = TRUE