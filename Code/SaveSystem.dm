datum/SaveManager
    var/savefile/F

    New(ckey)
        F = new("Player SaveFiles/[ckey].sav")

    proc/save_character(mob/player/M, slot)
        var/key = "char[slot]"

        // Core identity/stats
        F["[key].name"]          << M.name
        F["[key].class"]         << M.class
        F["[key].level"]         << M.Level
        F["[key].exp"]           << M.Exp
        F["[key].statpoints"]    << M.StatPoints
        F["[key].strength"]      << M.Strength
        F["[key].vitality"]      << M.Vitality
        F["[key].agility"]       << M.Agility
        F["[key].intelligence"]  << M.Intelligence
        F["[key].luck"]          << M.Luck
        F["[key].gold"]          << M.Gold

        // Appearance
        F["[key].base_icon"]     << M.base_icon
        F["[key].hair_color"]    << M.hair_color
        F["[key].eye_color"]     << M.eye_color
        F["[key].main_color"]    << M.main_color
        F["[key].accent_color"]  << M.accent_color

    proc/load_character(mob/player_tmp/M, slot)
        var/key = "char[slot]"

        var/class_choice
        F["[key].class"] >> class_choice
        if(!class_choice) return 0

        var/mob/player/newplayer
        switch(class_choice)
            if("Hero")    newplayer = new /mob/player/hero
            if("Soldier") newplayer = new /mob/player/soldier
            if("Wizard")  newplayer = new /mob/player/wizard
        if(!newplayer) return 0

        // Core identity/stats
        F["[key].name"]         >> newplayer.name
        F["[key].level"]        >> newplayer.Level
        F["[key].exp"]          >> newplayer.Exp
        F["[key].statpoints"]   >> newplayer.StatPoints
        F["[key].strength"]     >> newplayer.Strength
        F["[key].vitality"]     >> newplayer.Vitality
        F["[key].agility"]      >> newplayer.Agility
        F["[key].intelligence"] >> newplayer.Intelligence
        F["[key].luck"]         >> newplayer.Luck
        F["[key].gold"]         >> newplayer.Gold

        // Appearance
        F["[key].base_icon"]    >> newplayer.base_icon
        F["[key].hair_color"]   >> newplayer.hair_color
        F["[key].eye_color"]    >> newplayer.eye_color
        F["[key].main_color"]   >> newplayer.main_color
        F["[key].accent_color"] >> newplayer.accent_color

        // Build palette and push saved colors
        newplayer.palette = new /datum/PaletteManager(
            newplayer.class,
            newplayer.base_icon
        )
        if(newplayer.hair_color)   newplayer.palette.SetZoneColor("Hair", newplayer.hair_color)
        if(newplayer.eye_color)    newplayer.palette.SetZoneColor("Eyes", newplayer.eye_color)
        if(newplayer.main_color)   newplayer.palette.SetZoneColor("Main", newplayer.main_color)
        if(newplayer.accent_color) newplayer.palette.SetZoneColor("Accent", newplayer.accent_color)


        // Rebuild final icon
        newplayer.RebuildIcon()

        M.client.mob = newplayer
        newplayer.loc = locate(26,8,4)
        players += newplayer
        del M

        return 1

mob/player/proc/RebuildIcon()
    if(!base_icon) return src

    var/icon/my_icon = icon("Mob Icons/Player/" + base_icon)
    if(!my_icon)
        world << "ERROR: Failed to load icon [base_icon]"
        return src

    var/list/zones = list("Hair","Eyes","Main","Accent")
    for(var/zone in zones)
        var/orig_color = palette?.originalColors[zone]
        var/new_color  = null
        switch(zone)
            if("Hair")   new_color = hair_color
            if("Eyes")   new_color = eye_color
            if("Main")   new_color = main_color
            if("Accent") new_color = accent_color

        if(orig_color && new_color)
            my_icon.SwapColor(orig_color, new_color)

    icon = my_icon
    UpdateAppearance()
    return src