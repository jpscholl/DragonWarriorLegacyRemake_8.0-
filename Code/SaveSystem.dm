// -----------------------------
//SaveManager
// -----------------------------
datum/SaveManager
    var/savefile/F

    New(ckey)
        F = new("Player SaveFiles/[ckey].sav")

    proc/save_character(mob/player/M, slot)
        var/key = "char[slot]"

        // Core identity/progression
        F["[key].name"]          << M.name
        F["[key].class"]         << M.class
        F["[key].level"]         << M.Level
        F["[key].exp"]           << M.Exp
        F["[key].nexp"]          << M.Nexp
        F["[key].statpoints"]    << M.StatPoints

        // Vitals
        F["[key].hp"]            << M.HP
        F["[key].maxhp"]         << M.MaxHP
        F["[key].mp"]            << M.MP
        F["[key].maxmp"]         << M.MaxMP

        // Stats
        F["[key].strength"]      << M.Strength
        F["[key].vitality"]      << M.Vitality
        F["[key].agility"]       << M.Agility
        F["[key].intelligence"]  << M.Intelligence
        F["[key].luck"]          << M.Luck

        // Economy
        F["[key].gold"]          << M.Gold

        // Appearance
        F["[key].base_icon"]     << "[M.base_icon]"

        F["[key].hair_color"]    << "[M.hair_color]"
        F["[key].eye_color"]     << "[M.eye_color]"
        F["[key].main_color"]    << "[M.main_color]"
        F["[key].accent_color"]  << "[M.accent_color]"

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
        F["[key].name"]         >> newplayer.name
        F["[key].level"]        >> newplayer.Level
        F["[key].exp"]          >> newplayer.Exp
        F["[key].nexp"]         >> newplayer.Nexp
        F["[key].statpoints"]   >> newplayer.StatPoints

        // Vitals
        F["[key].hp"]           >> newplayer.HP
        F["[key].maxhp"]        >> newplayer.MaxHP
        F["[key].mp"]           >> newplayer.MP
        F["[key].maxmp"]        >> newplayer.MaxMP

        // Stats
        F["[key].strength"]     >> newplayer.Strength
        F["[key].vitality"]     >> newplayer.Vitality
        F["[key].agility"]      >> newplayer.Agility
        F["[key].intelligence"] >> newplayer.Intelligence
        F["[key].luck"]         >> newplayer.Luck

        // Economy
        F["[key].gold"]         >> newplayer.Gold

        // Appearance
        F["[key].base_icon"]    >> newplayer.base_icon
        var/hair_choice
        F["[key].hair_color"]   >> hair_choice
        var/eye_choice
        F["[key].eye_color"]    >> eye_choice
        var/main_choice
        F["[key].main_color"]   >> main_choice
        var/accent_choice
        F["[key].accent_color"] >> accent_choice

        newplayer.hair_color = hair_choice
        newplayer.eye_color = eye_choice
        newplayer.main_color = main_choice
        newplayer.accent_color = accent_choice

       // Apply appearance
        newplayer.RebuildIcon()
        newplayer.UpdateAppearance()

        // Transfer control
        M.client.mob = newplayer
        newplayer.loc = locate(26,8,4)   // spawn location
        players += newplayer
        del M

        return 1

mob/player/proc/RebuildIcon()
    // Reset visuals
    icon = null

    if(base_icon)
        // base_icon is something like "dw3hero.dmi"
        var/path = "Mob Icons/Player/" + base_icon
        icon = file(path)


    return src