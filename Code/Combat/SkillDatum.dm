datum/Skill
    var
        name = "Unnamed Skill"
        description = "No description."
        icon_state = null
        cooldown = 0
        mana_cost = 0
        cast_time = 0
        is_melee = FALSE

    proc/Activate(mob/user, mob/target) return
    // To be overridden by specific skills
datum/skill/Attack
    parent_type = /datum/Skill

    New()
        ..()
        name = "Attack"
        description = "A basic melee strike."
        icon_state = "weapon"
        is_melee = TRUE

    Activate(mob/user, mob/target)
        if (!user.can_move) return
        user.can_move = FALSE

        flick("attack", user)
        user << sound('attack.wav', volume = 60)

        var/turf/target_tile = get_step(user, user.dir)
        if (!target_tile) return

        flick("attack", target_tile)

        var/icon/weapon_icon = icon(user.icon, icon_state, user.dir)
        target_tile.overlays += weapon_icon
        spawn(2) target_tile.overlays -= weapon_icon

        for (var/mob/M in target_tile.contents)
            if (M != user && M.HP > 0)
                M.overlays += weapon_icon
                spawn(2) M.overlays -= weapon_icon
                M.TakeDamage(user.Strength)

        spawn(3) user.can_move = TRUE
