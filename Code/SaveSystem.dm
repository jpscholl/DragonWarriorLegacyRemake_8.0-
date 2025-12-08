// -----------------------------
//SaveManager

// -----------------------------
datum/SaveManager
    var/savefile/F

    New(ckey)
        F = new("playersaves/[ckey].sav")

    proc/save_character(mob/player/M, slot)
        var/key = "char[slot]"

        // Core identity/progression
        F["[key].name"]        << M.name
        F["[key].class"]       << M.class
        F["[key].level"]       << M.Level
        F["[key].exp"]         << M.Exp
        F["[key].nexp"]        << M.Nexp
        F["[key].statpoints"]  << M.StatPoints

        // Vitals
        F["[key].hp"]          << M.HP
        F["[key].maxhp"]       << M.MaxHP
        F["[key].mp"]          << M.MP
        F["[key].maxmp"]       << M.MaxMP

        // Stats
        F["[key].strength"]    << M.Strength
        F["[key].vitality"]    << M.Vitality
        F["[key].agility"]     << M.Agility
        F["[key].intelligence"]<< M.Intelligence
        F["[key].luck"]        << M.Luck

        // Economy
        F["[key].gold"]        << M.Gold

        // Appearance
        F["[key].base_icon"]   << M.base_icon
        F["[key].colors"]      << list(
            "hair"   = M.hair_color,
            "eyes"   = M.eye_color,
            "main"   = M.main_color,
            "accent" = M.accent_color
        )

        // Skills/inventory (optional)
        F["[key].skills"]      << M.skills

    proc/load_character(mob/player_tmp/M, slot)
        var/key = "char[slot]"

        // Guard: if no character exists in this slot, bail
        var/class_choice
        F["[key].class"] >> class_choice
        if(!class_choice) return 0

        // Create correct mob type from saved class
        var/mob/player/newplayer
        switch(class_choice)
            if("Hero")    newplayer = new /mob/player/hero
            if("Soldier") newplayer = new /mob/player/soldier
            if("Wizard")  newplayer = new /mob/player/wizard

        if(!newplayer) return 0

        // Core identity/progression
        F["[key].name"]        >> newplayer.name
        F["[key].level"]       >> newplayer.Level
        F["[key].exp"]         >> newplayer.Exp
        F["[key].nexp"]        >> newplayer.Nexp
        F["[key].statpoints"]  >> newplayer.StatPoints

        // Vitals
        F["[key].hp"]          >> newplayer.HP
        F["[key].maxhp"]       >> newplayer.MaxHP
        F["[key].mp"]          >> newplayer.MP
        F["[key].maxmp"]       >> newplayer.MaxMP

        // Stats
        F["[key].strength"]    >> newplayer.Strength
        F["[key].vitality"]    >> newplayer.Vitality
        F["[key].agility"]     >> newplayer.Agility
        F["[key].intelligence"]>> newplayer.Intelligence
        F["[key].luck"]        >> newplayer.Luck

        // Economy
        F["[key].gold"]        >> newplayer.Gold

        // Appearance
        F["[key].base_icon"]   >> newplayer.base_icon
        var/list/colors
        F["[key].colors"] >> colors
        if(colors)
            newplayer.hair_color   = colors["hair"]
            newplayer.eye_color    = colors["eyes"]
            newplayer.main_color   = colors["main"]
            newplayer.accent_color = colors["accent"]

        // Skills/inventory (optional)
        F["[key].skills"] >> newplayer.skills

        // Transfer control
        M.client.mob = newplayer
        newplayer.loc = locate(26,8,4)   // spawn location
        players += newplayer
        del M

        return 1