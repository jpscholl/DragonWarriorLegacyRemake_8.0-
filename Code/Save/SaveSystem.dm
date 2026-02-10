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
    proc/SaveCharacter(mob/player/M, slot)
        if(slot < 1 || slot > 4) return 0
        var/key = "char[slot]"

        var/datum/CharacterSaveData/D = new
        D.BuildFromCharacter(M)

        // Save metadata separately (optional but nice)
        F["[key].name"] << M.name

        // Save whole blob
        F["[key].data"] << D

        F.Flush()
        return 1


// -----------------------------
// Load a player's data from a specific slot (1-4)
// Returns 1 on success, 0 on failure
// -----------------------------
    proc/LoadCharacter(mob/playerTemp/M, slot)
        if(slot < 1 || slot > 4) return 0
        var/key = "char[slot]"

        // Load the saved snapshot
        var/datum/CharacterSaveData/D
        F["[key].data"] >> D
        if(!D) return 0

        // Spawn the correct player mob
        var/mob/player/newPlayer
        switch(D.class)
            if("Hero")    newPlayer = new /mob/player/Hero
            if("Soldier") newPlayer = new /mob/player/Soldier
            if("Wizard")  newPlayer = new /mob/player/Wizard
        if(!newPlayer) return 0

        // Apply saved snapshot to the mob
        D.ApplyToCharacter(newPlayer)

        // Make sure baseIcon is assigned
        if(!newPlayer.baseIcon && newPlayer.basePlayerIcon)
            newPlayer.baseIcon = newPlayer.basePlayerIcon

        // Rebuild palette & apply saved colors
        newPlayer.palette = new /datum/PaletteManager(
            newPlayer.class,
            newPlayer.baseIcon
        )

        if(newPlayer.hairColor)   newPlayer.palette.SetZoneColor("Hair", newPlayer.hairColor)
        if(newPlayer.eyeColor)    newPlayer.palette.SetZoneColor("Eyes", newPlayer.eyeColor)
        if(newPlayer.mainColor)   newPlayer.palette.SetZoneColor("Main", newPlayer.mainColor)
        if(newPlayer.accentColor) newPlayer.palette.SetZoneColor("Accent", newPlayer.accentColor)

        // Finally, rebuild the icon with applied palette/colors
        newPlayer.RebuildIcon()

        // Transfer client control
        M.client.mob = newPlayer
        newPlayer.loc = locate(26,8,4)
        players += newPlayer
        del M

        return 1

    // -----------------------------
    // Delete a character slot
    // -----------------------------
    proc/DeleteCharacter(slot)
        if(slot < 1 || slot > 4) return 0

        var/prefix = "char[slot]."

        for(var/key in F.dir)
            if(findtext(key, prefix) == 1)
                F[key] = null

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

    var/icon/playerIcon = icon("Mob Icons/Player/" + baseIcon)
    if(!playerIcon)
        src << output("ERROR: Failed to load icon [baseIcon]", "Info")
        return src

    var/list/zones = list("Hair","Eyes","Main","Accent")
    for(var/zone in zones)
        var/baseColor = palette?.originalColors[zone]
        var/replaceColor  = null
        switch(zone)
            if("Hair")   replaceColor = hairColor
            if("Eyes")   replaceColor = eyeColor
            if("Main")   replaceColor = mainColor
            if("Accent") replaceColor = accentColor

        if(baseColor && replaceColor)
            playerIcon.SwapColor(baseColor, replaceColor)

    icon = playerIcon
    UpdateAppearance()
    return src
