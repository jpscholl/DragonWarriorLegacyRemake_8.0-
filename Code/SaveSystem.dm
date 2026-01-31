// -----------------------------
// SaveManager datum
// Handles saving/loading/deleting up to 4 characters per player
// -----------------------------
datum/SaveManager
    var/savefile/F  // BYOND savefile object

    // -----------------------------
    // Constructor: Open or create savefile for a given player key
    // -----------------------------
    New(ckey)
        // Ensure the directory exists in your project: "Player SaveFiles/"
        F = new("Player SaveFiles/[ckey].sav")

    // -----------------------------
    // Save a player's data to a specific slot (1-4)
    // -----------------------------
    proc/saveCharacter(mob/player/M, slot)
        if(slot < 1 || slot > 4) return 0
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
        F["[key].baseIcon"]     << M.baseIcon
        F["[key].hairColor"]    << M.hairColor
        F["[key].eyeColor"]     << M.eyeColor
        F["[key].mainColor"]    << M.mainColor
        F["[key].accentColor"]  << M.accentColor

        return 1

    // -----------------------------
    // Load a player's data from a specific slot (1-4)
    // Returns 1 on success, 0 on failure
    // -----------------------------
    proc/loadCharacter(mob/playerTemp/M, slot)
        if(slot < 1 || slot > 4) return 0
        var/key = "char[slot]"

        // Read class first to spawn correct template
        var/selectedClass
        F["[key].class"] >> selectedClass
        if(!selectedClass) return 0

        var/mob/player/newPlayer
        switch(selectedClass)
            if("Hero")    newPlayer = new /mob/player/Hero
            if("Soldier") newPlayer = new /mob/player/Soldier
            if("Wizard")  newPlayer = new /mob/player/Wizard
        if(!newPlayer) return 0

        // -----------------------------
        // Restore core stats
        // -----------------------------
        F["[key].name"]         >> newPlayer.name
        F["[key].level"]        >> newPlayer.Level
        F["[key].exp"]          >> newPlayer.Exp
        F["[key].statpoints"]   >> newPlayer.StatPoints
        F["[key].strength"]     >> newPlayer.Strength
        F["[key].vitality"]     >> newPlayer.Vitality
        F["[key].agility"]      >> newPlayer.Agility
        F["[key].intelligence"] >> newPlayer.Intelligence
        F["[key].luck"]         >> newPlayer.Luck
        F["[key].gold"]         >> newPlayer.Gold

        // -----------------------------
        // Restore appearance
        // -----------------------------
        F["[key].baseIcon"]    >> newPlayer.baseIcon
        F["[key].hairColor"]   >> newPlayer.hairColor
        F["[key].eyeColor"]    >> newPlayer.eyeColor
        F["[key].mainColor"]   >> newPlayer.mainColor
        F["[key].accentColor"] >> newPlayer.accentColor

        // Rebuild palette & apply saved colors
        newPlayer.palette = new /datum/PaletteManager(
            newPlayer.class,
            newPlayer.baseIcon
        )
        if(newPlayer.hairColor)   newPlayer.palette.SetZoneColor("Hair", newPlayer.hairColor)
        if(newPlayer.eyeColor)    newPlayer.palette.SetZoneColor("Eyes", newPlayer.eyeColor)
        if(newPlayer.mainColor)   newPlayer.palette.SetZoneColor("Main", newPlayer.mainColor)
        if(newPlayer.accentColor) newPlayer.palette.SetZoneColor("Accent", newPlayer.accentColor)

        newPlayer.RebuildIcon()

        // -----------------------------
        // Transfer client control
        // -----------------------------
        M.client.mob = newPlayer
        newPlayer.loc = locate(26,8,4)
        players += newPlayer
        del M

        return 1

    // -----------------------------
    // Delete a character slot
    // -----------------------------
    proc/delete_character(slot)
        if(slot < 1 || slot > 4) return 0

        var/key_prefix = "char[slot]"
        var/list/subkeys = list(
            "name","class","level","exp","statpoints",
            "strength","vitality","agility","intelligence",
            "luck","gold","baseIcon","hairColor","eyeColor",
            "mainColor","accentColor"
        )

        for(var/subkey in subkeys)
            F["[key_prefix].[subkey]"] = null

        F.Flush()
        return 1

    // -----------------------------
    // Return a list of filled character slots with names
    // -----------------------------
    proc/GetCharacterSlots()
        var/list/out = list()
        for(var/i = 1 to 4)
            var/name
            F["char[i].name"] >> name
            if(name)
                out["[i]"] = name
        return out

// -----------------------------
// Rebuild the player's icon after loading or recoloring
// -----------------------------
mob/player/proc/RebuildIcon()
    if(!baseIcon) return src

    var/icon/my_icon = icon("Mob Icons/Player/" + baseIcon)
    if(!my_icon)
        src << output("ERROR: Failed to load icon [baseIcon]", "Info")
        return src

    var/list/zones = list("Hair","Eyes","Main","Accent")
    for(var/zone in zones)
        var/orig_color = palette?.originalColors[zone]
        var/new_color  = null
        switch(zone)
            if("Hair")   new_color = hairColor
            if("Eyes")   new_color = eyeColor
            if("Main")   new_color = mainColor
            if("Accent") new_color = accentColor

        if(orig_color && new_color)
            my_icon.SwapColor(orig_color, new_color)

    icon = my_icon
    UpdateAppearance()
    return src