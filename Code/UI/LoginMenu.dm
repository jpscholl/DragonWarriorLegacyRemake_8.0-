// -----------------------------
// Character Creation Pipeline
// -----------------------------

// Step constants for the creation flow
#define STEP_NAME   1
#define STEP_CLASS  2
#define STEP_ICON   3
#define STEP_CUSTOM 4
#define STEP_STATS  5

// Global list of active players
//var/list/players = list()
#define SAVE_PATH "players"
#define MAX_CHARACTERS 4


// Temporary mob used during character creation
mob
    var
        obj/newCharPreview             // preview object for icon customization
        icon/baseIconPreview           // for recoloring just in case
        selectedName                   // chosen character name
        selectedClass                  // chosen class (Hero, Soldier, Wizard)
        selectedIcon                   // chosen icon file
        selectedIconName               // chosen icon attributeName
        datum/PaletteManager/palette   // palette manager for recoloring


mob/playerTemp   // placeholder mob type for login/creation

// -----------------------------
// Entry Point: Login Menu
// -----------------------------
proc/ShowLoginMenu(mob/playerTemp/M)
    if(!M || !M.client || !M.client.saveManager)
        return

    var/list/slots = M.client.saveManager.GetCharacterSlots()
    if(!slots)
        slots = list()

    var/list/options = list()

    for(var/slot in slots)
        options += "Load [slots[slot]] (Slot [slot])"

    options += "Create New Character"

    if(slots.len)
        options += "Delete Character"

    options += "Quit"

    var/choice = input(M, "Welcome to Dragon Warrior Legacy", "Login Menu") in options

    if(findtext(choice, "Load "))
        var/slot = text2num(copytext(choice, findtext(choice, "Slot ") + 5))
        M.client.saveManager.LoadCharacter(M, slot)
        return

    switch(choice)
        if("Create New Character")
            NewCharacterMenu(M)

        if("Delete Character")
            DeleteCharacterMenu(M)

        if("Quit")
            del M

// -----------------------------
// Character Creation Flow
// -----------------------------
proc/NewCharacterMenu(mob/playerTemp/M)
    var/step = STEP_NAME

    while(step)
        switch(step)
            if(STEP_NAME)
                // Prompt for name
                M.selectedName = PromptForName(M)
                if(!M.selectedName) return
                M << output("[M.selectedName] is your chosen name", "Info")
                step = STEP_CLASS

            if(STEP_CLASS)
                // Prompt for class
                var/selectedClass = PromptForClass(M)
                M.selectedClass = ApplyClassSelection(M, selectedClass)
                if(!M.selectedClass) { step = STEP_NAME; continue }
                M << output("[M.selectedClass] is your chosen class", "Info")
                step = STEP_ICON

            if(STEP_ICON)
                M.palette = null
                step = IconSelect(M)
                continue

            if(STEP_CUSTOM)
                // Icon customization
                M.IconPreview()
                step = M.CustomizeColors()  // must return STEP_STATS or STEP_ICON

            if(STEP_STATS)
                // Stat allocation
                M << output("Allocate Stats","Info")
                step = StatAllocation(M)     // must return STEP_STATS when done
                if(step == STEP_STATS)
                    if(M && M.client)
                        FinalizePlayer(M)
                    return


proc/DeleteCharacterMenu(mob/playerTemp/M)
    var/list/slots = M.client.saveManager.GetCharacterSlots()
    if(!slots.len)
        ShowLoginMenu(M)
        return

    var/list/options = list()
    for(var/slot in slots)
        options += "Delete [slots[slot]] (Slot [slot])"

    options += "Cancel"

    var/choice = input(M, "Delete which character?") in options
    if(choice == "Cancel")
        ShowLoginMenu(M)
        return

    var/slot = text2num(copytext(choice, findtext(choice, "Slot ") + 5))

    var/confirm = alert(M, "Are you sure?", "Confirm Delete", "Yes", "No")
    if(confirm != "Yes")
        ShowLoginMenu(M)
        return

    if(!M.client.saveManager.DeleteCharacter(slot))
        alert(M, "Delete failed.")

    ShowLoginMenu(M)

// -----------------------------
// Prompts
// -----------------------------

//Name
proc/PromptForName(mob/M)
    var/selectedName
    while(!selectedName || !length(trimtext(selectedName)))
        selectedName = input(M, "Enter your name:", "New Character") as text|null
        if(isnull(selectedName))
            ShowLoginMenu(M)
            return null
    return trimtext(selectedName)
//Class
proc/PromptForClass(mob/M)
    var/list/classes = list("Hero", "Soldier", "Wizard", "Back")
    return input(M, "Choose your class:", "Class Selection") in classes

//idk why this is in with prompts section but ok?
proc/ApplyClassSelection(mob/M, selectedClass)
    if(selectedClass == "Back")
        if(M.newCharPreview) del M.newCharPreview
        return null
    return selectedClass

// -----------------------------
// Icon Handling
// -----------------------------

//fetch list based on the class player chooses
proc/GetClassIcons(mob/M, selectedClass)
    switch(selectedClass)
        if("Hero")
            return list("Dragon Warrior 1 Hero"='dw1hero.dmi',
                        "Dragon Warrior 2 Hero"='dw2hero.dmi',
                        "Dragon Warrior 3 Hero"='dw3hero.dmi',
                        "Back")
        if("Soldier")
            return list("Dragon Warrior 1 Soldier"='dw1soldier.dmi',
                        "Dragon Warrior 2 Soldier"='dw2soldier.dmi',
                        "Dragon Warrior 3 Guard"='dw3guard.dmi',
                        "Back")
        if("Wizard")
            return list("Dragon Warrior 1 Wizard"='dw1wizard.dmi',
                        "Dragon Warrior 2 Wizard"='dw2wizard.dmi',
                        "Dragon Warrior 3 Wizard"='dw3malewizard.dmi',
                        "Back")
    return list()

//icon selection and storage
proc/IconSelect(mob/playerTemp/M)
    var/list/iconChoices = GetClassIcons(M, M.selectedClass)
    var/iconChoice = input(M, "Choose your icon:", "Icon Selection") in iconChoices

    if(iconChoice == "Back")
        return STEP_CLASS

    M.selectedIcon      = iconChoices[iconChoice]
    M.selectedIconName = "[iconChoices[iconChoice]]"

    M << output("You've selected [M.selectedIconName]", "Info")
    return STEP_CUSTOM

//---------------------------------
// Preview icon in a separate area
//---------------------------------
mob/proc/IconPreview(turf/T = locate(3,3,2))
    if(newCharPreview)
        del newCharPreview

    if(!selectedIcon)
        return

    var/obj/preview = new /obj
    preview.icon = icon(selectedIcon)
    preview.icon_state = "world"
    preview.loc = T

    newCharPreview = preview

    //Store pristine base icon ONCE
    baseIconPreview = icon(selectedIcon)

    client.eye = preview

    UpdateAppearance()

// -----------------------------
// Icon Customization
// -----------------------------
mob/proc/CustomizeColors()
    // Build palette ONCE
    palette = new /datum/PaletteManager(selectedClass, selectedIconName)

    while(TRUE)
        var/list/options = list("Main", "Accent", "Hair", "Eyes", "Finish", "Back")
        var/zone_choice = input(src, "Choose a zone to change or Finish", "Color Customization") in options

        switch(zone_choice)
            if("Main")   Set_Main()
            if("Accent") Set_Accent()
            if("Hair")   Set_Hair()
            if("Eyes")   Set_Eyes()
            if("Finish")
                src.hairColor   = palette.GetZoneColor("Hair")
                src.eyeColor    = palette.GetZoneColor("Eyes")
                src.mainColor   = palette.GetZoneColor("Main")
                src.accentColor = palette.GetZoneColor("Accent")

                client.eye = src
                src << output("Icon colors applied!", "Info")

                return STEP_STATS

            if("Back")
                // CLEANUP PREVIEW STATE
                baseIconPreview = null
                if(newCharPreview)
                    del newCharPreview
                newCharPreview = null

                return STEP_ICON

// -----------------------------
// Finalize Player
// -----------------------------
proc/FinalizePlayer(mob/playerTemp/M)
    if(!M || !M.client)
        return

    var/client/C = M.client

    var/mob/player/newPlayer = ApplyPlayerClass(M.selectedClass)
    if(!newPlayer)
        return

    // Identity
    newPlayer.name = M.selectedName

    // Appearance & stats
    ApplyCustomColors(M, newPlayer)
    ApplyCustomStats(M, newPlayer)

    // -----------------------------
    // Find first free character slot
    // -----------------------------
    var/slot = null

    if(C.saveManager)
        var/list/slots = C.saveManager.GetCharacterSlots()
        if(!slots)
            slots = list()

        slot = 1
        while(slot <= MAX_CHARACTERS && slots["[slot]"])
            slot++

    if(!slot || slot > MAX_CHARACTERS)
        M << "No free character slots available."
        del newPlayer
        return

    // Mark this mob as a real character
    newPlayer.isCharacter = TRUE

    // Save character BEFORE login commit
    C.saveManager.SaveCharacter(newPlayer, slot)

    // -----------------------------
    // Transfer control
    // -----------------------------
    M << output("Player finalized", "Info")
    M << sound(null, channel = 1)

    C.mob = newPlayer
    newPlayer.loc = locate(26, 8, 4)

    newPlayer << sound('dw4town.mid', repeat = 1, channel = 1, volume = baseVolume)

    players += newPlayer

    // Remove temp mob LAST
    del M

    // Announce login
    players << output("[newPlayer.name] has joined the world!", "Messages")


//selects proper template based on class templates
proc/ApplyPlayerClass(class_name)
    switch(class_name)
        if("Hero")    return new /mob/player/Hero
        if("Soldier") return new /mob/player/Soldier
        if("Wizard")  return new /mob/player/Wizard

        // Future classes
        // if("Fighter") return new /mob/player/fighter
        // if("Pilgrim") return new /mob/player/pilgrim
        // if("Goof-off") return new /mob/player/goofoff
        // if("Sage")     return new /mob/player/sage
        // if("Custom")   return new /mob/player/GM

    return null

//copy temp stats into player stats
proc/ApplyCustomStats(mob/playerTemp/src, mob/player/dst)
    dst.Strength     = src.Strength
    dst.Vitality     = src.Vitality
    dst.Agility      = src.Agility
    dst.Intelligence = src.Intelligence
    dst.Luck         = src.Luck


//copy player appearance from preview
proc/ApplyCustomColors(mob/playerTemp/src, mob/player/dst)
    if(src.newCharPreview)
        dst.icon = icon(src.newCharPreview.icon)
        dst.icon_state = src.newCharPreview.icon_state
    else
        dst.icon = icon(src.selectedIcon)
        dst.icon_state = "world"

    dst.baseIcon    = src.selectedIconName
    dst.hairColor   = "[src.hairColor]"
    dst.eyeColor    = "[src.eyeColor]"
    dst.mainColor   = "[src.mainColor]"
    dst.accentColor = "[src.accentColor]"


// -----------------------------
// Stat Allocation
// -----------------------------
proc/StatAllocation(mob/playerTemp/M)
    var/remainingStatPoints = 14
    var/statCap = 10

    // Temporary stat storage
    var/list/tempStatPoints = list(
        "Strength"     = M.Strength,
        "Vitality"     = M.Vitality,
        "Agility"      = M.Agility,
        "Intelligence" = M.Intelligence,
        "Luck"         = M.Luck
    )

    while(TRUE)
        var/list/options = list()

        // Build menu dynamically
        for(var/stat in tempStatPoints)
            if(tempStatPoints[stat] < statCap)
                options["[stat] [tempStatPoints[stat]]"] = stat

        options["Back"]   = "Back"
        options["Finish"] = "Finish"

        var/choice = input(
            M,
            "Allocate your stat points. Points left ([remainingStatPoints])",
            "Stats"
        ) in options

        choice = options[choice]

        switch(choice)
            if("Back")
                return STEP_ICON

            if("Finish")
                if(remainingStatPoints > 0)
                    M << output("You must spend all points before finishing.", "Info")
                else
                    // Commit changes
                    for(var/stat in tempStatPoints)
                        M.vars[stat] = tempStatPoints[stat]
                    return STEP_STATS

            else
                if(remainingStatPoints <= 0)
                    M << output("You have no points left.", "Info")
                else if(tempStatPoints[choice] >= statCap)
                    M << output("Starter stats are capped at [statCap]!", "Info")
                else
                    tempStatPoints[choice]++
                    remainingStatPoints--
                    M << output("You increased [choice] by 1", "Info")