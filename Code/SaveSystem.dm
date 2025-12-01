// SaveManager handles saving/loading player data
datum/SaveManager
    var/savefile/F

    New(ckey)
        F = new("players/[ckey].sav")

    proc/save_character(mob/player/M, slot)
        // Core identity/progression
        F["char[slot].class"] << M.class
        F["char[slot].level"] << M.Level
        F["char[slot].exp"] << M.Exp
        F["char[slot].nexp"] << M.Nexp
        F["char[slot].statpoints"] << M.StatPoints

        // Vitals
        F["char[slot].hp"] << M.HP
        F["char[slot].maxhp"] << M.MaxHP
        F["char[slot].mp"] << M.MP
        F["char[slot].maxmp"] << M.MaxMP

        // Stats
        F["char[slot].strength"] << M.Strength
        F["char[slot].vitality"] << M.Vitality
        F["char[slot].agility"] << M.Agility
        F["char[slot].intelligence"] << M.Intelligence
        F["char[slot].luck"] << M.Luck

        // Economy
        F["char[slot].gold"] << M.Gold

        // Appearance
        F["char[slot].base_icon"] << M.base_icon
        F["char[slot].colors"] << list(
            "hair" = M.hair_color,
            "eyes" = M.eye_color,
            "main" = M.main_color,
            "accent" = M.accent_color
        )

    proc/load_character(mob/player_tmp/M, slot)
        F["char[slot].class"] >> M.class
        F["char[slot].level"] >> M.Level
        F["char[slot].exp"] >> M.Exp
        F["char[slot].nexp"] >> M.Nexp
        F["char[slot].statpoints"] >> M.StatPoints

        F["char[slot].hp"] >> M.HP
        F["char[slot].maxhp"] >> M.MaxHP
        F["char[slot].mp"] >> M.MP
        F["char[slot].maxmp"] >> M.MaxMP

        F["char[slot].strength"] >> M.Strength
        F["char[slot].vitality"] >> M.Vitality
        F["char[slot].agility"] >> M.Agility
        F["char[slot].intelligence"] >> M.Intelligence
        F["char[slot].luck"] >> M.Luck

        F["char[slot].gold"] >> M.Gold

        F["char[slot].base_icon"] >> M.base_icon
        var/list/colors
        F["char[slot].colors"] >> colors
        if(colors)
            M.hair_color   = colors["hair"]
            M.eye_color    = colors["eyes"]
            M.main_color   = colors["main"]
            M.accent_color = colors["accent"]

