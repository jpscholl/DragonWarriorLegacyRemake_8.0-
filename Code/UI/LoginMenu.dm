// -----------------------------
// Character Creation Pipeline
// -----------------------------

// Step constants for the creation flow
#define STEP_NAME   1
#define STEP_CLASS  2
#define STEP_ICON   3
#define STEP_CUSTOM 4
#define STEP_STATS  5


// Temporary mob used during character creation
mob
    var
        obj/newCharPreview             // preview object for icon customization
        icon/baseIconPreview           // for recoloring just in case
        selectedName                   // chosen character name
        selectedClass                  // chosen class (Hero, Soldier, Wizard)
        selectedIcon                   // chosen icon file (/icon resource)
        selectedIconName               // that icon's bare filename, e.g. "dw3hero.dmi" (for palette color lookups)
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
        var/label = "Load [slots[slot]] (Slot [slot])"
        if(M.client.saveManager.IsCharacterBanned(text2num(slot)))
            label += " \[BANNED\]"
        options += label

    options += "Create New Character"

    if(slots.len)
        options += "Delete Character"

    options += "Quit"

    var/choice = input(M, "Welcome to Dragon Warrior Legacy", "Login Menu v[GAME_VERSION]") in options

    if(findtext(choice, "Load "))
        var/slot = text2num(copytext(choice, findtext(choice, "Slot ") + 5))
        if(M.client.saveManager.IsCharacterBanned(slot))
            M << output("This character has been banned and can't be loaded.", "Info")
            ShowLoginMenu(M)
            return
        if(!M.client.saveManager.LoadCharacter(M, slot))
            // LoadCharacter() failed (missing/corrupt save data, unresolvable class,
            // etc.) — M was never handed a real character or relocated off of
            // mob/playerTemp's default spot, which is BYOND's (1,1,1) origin (nothing
            // ever gives playerTemp its own spawn — world.mob = /mob/playerTemp,
            // Main.dm, with no loc override). Previously this failed completely
            // silently, leaving the player stuck controlling that temp mob at (1,1,1)
            // forever with no menu and no explanation.
            M << output("Something went wrong loading that character.", "Info")
            ShowLoginMenu(M)
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
    var/prompt = "Enter your name:"
    while(TRUE)
        selectedName = input(M, prompt, "New Character") as text|null
        if(isnull(selectedName))
            ShowLoginMenu(M)
            return null

        selectedName = trimtext(selectedName)

        if(!length(selectedName))
            prompt = "Enter your name:"
            continue

        if(length(selectedName) > MAX_NAME_LENGTH)
            prompt = "Name is too long (max [MAX_NAME_LENGTH] characters). Enter your name:"
            continue

        if(IsTextFiltered(selectedName))
            prompt = "That name isn't allowed. Enter your name:"
            continue

        return selectedName
//Class
proc/PromptForClass(mob/M)
    // Sage deliberately excluded — GM-only direct pick per existing design
    // (TODOList.md), not a creation-time choice for normal players.
    var/list/classes = list("Hero", "Soldier", "Wizard", "Fighter", "Pilgrim", "Goof-off", "Back")
    return input(M, "Choose your class:", "Class Selection") in classes

// Turns a class choice into either the class name or null (on "Back")
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
            return list("Dragon Warrior 1 Hero"='Mob Icons/Player/dw1hero.dmi',
                        "Dragon Warrior 2 Hero"='Mob Icons/Player/dw2hero.dmi',
                        "Dragon Warrior 3 Hero"='Mob Icons/Player/dw3hero.dmi',
                        "Back")
        if("Soldier")
            return list("Dragon Warrior 1 Soldier"='Mob Icons/Player/dw1soldier.dmi',
                        "Dragon Warrior 2 Soldier"='Mob Icons/Player/dw2soldier.dmi',
                        "Dragon Warrior 3 Guard"='Mob Icons/Player/dw3guard.dmi',
                        "Back")
        if("Wizard")
            return list("Dragon Warrior 1 Wizard"='Mob Icons/Player/dw1wizard.dmi',
                        "Dragon Warrior 2 Wizard"='Mob Icons/Player/dw2wizard.dmi',
                        "Dragon Warrior 3 Wizard"='Mob Icons/Player/dw3malewizard.dmi',
                        "Back")
        if("Fighter")
            return list("Dragon Warrior 1 Fighter"='Mob Icons/Player/dw1fighter.dmi',
                        "Dragon Warrior 2 Fighter"='Mob Icons/Player/dw2fighter.dmi',
                        "Dragon Warrior 3 Fighter (Male)"='Mob Icons/Player/dw3malefighter.dmi',
                        "Dragon Warrior 3 Fighter (Female)"='Mob Icons/Player/dw3femalefighter.dmi',
                        "Back")
        if("Pilgrim")
            return list("Dragon Warrior 2 Pilgrim"='Mob Icons/Player/dw2pilgrim.dmi',
                        "Dragon Warrior 3 Pilgrim (Male)"='Mob Icons/Player/dw3malepilgrim.dmi',
                        "Dragon Warrior 3 Pilgrim (Female)"='Mob Icons/Player/dw3femalepilgrim.dmi',
                        "Back")
        if("Goof-off")
            return list("Dragon Warrior 3 Goof-off (Male)"='Mob Icons/Player/dw3malegoofoff.dmi',
                        "Dragon Warrior 3 Goof-off (Female)"='Mob Icons/Player/dw3femalegoofoff.dmi',
                        "Back")
        if("Sage")
            return list("Dragon Warrior 3 Sage (Male)"='Mob Icons/Player/dw3malesage.dmi',
                        "Dragon Warrior 3 Sage (Female)"='Mob Icons/Player/dw3femalesage.dmi',
                        "Back")
    return list()

//icon selection and storage
proc/IconSelect(mob/playerTemp/M)
    var/list/iconChoices = GetClassIcons(M, M.selectedClass)
    var/iconChoice = input(M, "Choose your icon:", "Icon Selection") in iconChoices

    if(iconChoice == "Back")
        return STEP_CLASS

    M.selectedIcon = iconChoices[iconChoice]
    M.selectedIconName = GetIconFilename(M.selectedIcon)

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
    palette = new /datum/PaletteManager(selectedClass, selectedIconName, src)

    while(TRUE)
        var/list/options = list("Main", "Accent", "Hair", "Eyes", "Finish", "Back")
        var/zone_choice = input(src, "Choose a zone to change or Finish", "Color Customization") in options

        switch(zone_choice)
            if("Main")   SetZoneColorPrompt("Main")
            if("Accent") SetZoneColorPrompt("Accent")
            if("Hair")   SetZoneColorPrompt("Hair")
            if("Eyes")   SetZoneColorPrompt("Eyes")
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

    // Derive MaxHP/MaxMP from the stats just applied, then top both off — a fresh
    // character should never start below full. This also retires the static
    // per-class MaxMP literals (PlayerTemplate.dm), which RecalculateVitals()
    // silently overwrote the moment any stat point was later spent anyway.
    newPlayer.RecalculateVitals()
    newPlayer.HP = newPlayer.MaxHP
    newPlayer.MP = newPlayer.MaxMP

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
    newPlayer.saveSlot = slot
    newPlayer.saveManager = C.saveManager

    // Save character BEFORE login commit
    C.saveManager.SaveCharacter(newPlayer, slot)

    // -----------------------------
    // Transfer control
    // -----------------------------
    M << output("Player finalized", "Info")
    M << sound(null, channel = 1)

    C.mob = newPlayer
    // The new mob's own verb list starts fresh from its type declaration (includes
    // GM-only verbs like GM_ToggleLog by default) — re-sync (AdminLevels.dm) so a
    // non-GM's removal carries over from the old temp mob.
    C.SyncGMVerbs()
    newPlayer.loc = GetPlayerSpawnTurf()

    // Start whatever music belongs to the spawn area (mob -> turf -> area)
    // right away, rather than waiting for the player's first step to trigger it.
    var/area/spawnArea = newPlayer.loc?.loc
    if(spawnArea && spawnArea.areaMusic)
        newPlayer.PlayAreaMusic(spawnArea.areaMusic)

    players += newPlayer

    // Remove temp mob LAST
    del M

    // Announce login
    players << output("[newPlayer.name] has joined the world!", "Messages")


//selects proper template based on class templates
proc/ApplyPlayerClass(class_name)
    var/mob/player/newPlayer

    // GetPlayerClassType() (PlayerTemplate.dm) is the one place the name->type switch
    // lives now — Custom/GM isn't in it yet since /mob/player/GM doesn't exist as a
    // real type.
    var/type = GetPlayerClassType(class_name)
    if(type) newPlayer = new type

    // Skills aren't persisted in save data (Code/Save/SaveData.dm) — every fresh
    // character needs its starting kit equipped from scratch, per its own
    // GetStartingKit() (Code/Player/SkillUnlocks.dm).
    if(newPlayer)
        newPlayer.EquipStartingKit()
        newPlayer.CheckSkillUnlocks(silent = TRUE)  // no-op at Level 1 today, but stays
                                                       // correct if a class ever gets a
                                                       // Level 1 stat-only unlock later
    return newPlayer

//copy temp stats into player stats
proc/ApplyCustomStats(mob/playerTemp/src, mob/player/dst)
    dst.Strength     = src.Strength
    dst.Vitality     = src.Vitality
    dst.Agility      = src.Agility
    dst.Intelligence = src.Intelligence
    dst.Spirit       = src.Spirit


//copy player appearance from preview
proc/ApplyCustomColors(mob/playerTemp/src, mob/player/dst)
    if(src.newCharPreview)
        dst.icon = icon(src.newCharPreview.icon)
        dst.icon_state = src.newCharPreview.icon_state
    else
        dst.icon = icon(src.selectedIcon)
        dst.icon_state = "world"

    dst.baseIcon        = src.selectedIcon
    dst.basePlayerIcon  = src.selectedIconName
    dst.hairColor   = "[src.hairColor]"
    dst.eyeColor    = "[src.eyeColor]"
    dst.mainColor   = "[src.mainColor]"
    dst.accentColor = "[src.accentColor]"

// -----------------------------
// Stat Allocation
// -----------------------------
// Confirmed 2026-08-10: creation starts every stat at 1 (base mob default,
// PlayerTemplate.dm) with 12 points to allocate, each stat capped at 10 for this
// screen specifically — the much higher per-class ceilings (GetClassStatCaps(),
// PlayerTemplate.dm) still govern level-up spend (ClickableStats.dm), just not
// reachable at creation anymore.
#define CREATION_STAT_POINTS 12
#define CREATION_STAT_CAP 10

proc/StatAllocation(mob/playerTemp/M)
    var/remainingStatPoints = CREATION_STAT_POINTS
    var/list/statCaps = list(
        "Strength"     = CREATION_STAT_CAP,
        "Vitality"     = CREATION_STAT_CAP,
        "Agility"      = CREATION_STAT_CAP,
        "Intelligence" = CREATION_STAT_CAP,
        "Spirit"       = CREATION_STAT_CAP
    )
    var/lastStat = null   // which stat was picked last, so the dialog can re-highlight it

    // Temporary stat storage
    var/list/tempStatPoints = list(
        "Strength"     = M.Strength,
        "Vitality"     = M.Vitality,
        "Agility"      = M.Agility,
        "Intelligence" = M.Intelligence,
        "Spirit"       = M.Spirit
    )

    while(TRUE)
        var/list/options = list()
        var/defaultLabel = null

        // Build menu dynamically. Labels include the current point count, so they
        // change every allocation — look up lastStat's current label instead of
        // remembering the old (now-stale) label text.
        for(var/stat in tempStatPoints)
            if(tempStatPoints[stat] < statCaps[stat])
                var/label = "[stat] [tempStatPoints[stat]]"
                options[label] = stat
                if(stat == lastStat)
                    defaultLabel = label

        options["Back"]   = "Back"
        options["Finish"] = "Finish"

        var/choice = input(
            M,
            "Allocate your stat points. Points left ([remainingStatPoints])",
            "Stats",
            defaultLabel
        ) in options

        choice = options[choice]

        switch(choice)
            if("Back")
                return STEP_ICON

            if("Finish")
                if(remainingStatPoints > 0)
                    M << output("You must spend all points before finishing.", "Info")
                else
                    // Commit changes (dynamic lookup: "Strength" etc. match mob var names directly)
                    for(var/stat in tempStatPoints)
                        M.vars[stat] = tempStatPoints[stat]
                    return STEP_STATS

            else
                lastStat = choice   // keep this stat highlighted next time regardless of outcome
                if(remainingStatPoints <= 0)
                    M << output("You have no points left.", "Info")
                else if(tempStatPoints[choice] >= statCaps[choice])
                    M << output("[choice] is capped at [statCaps[choice]] for this class!", "Info")
                else
                    tempStatPoints[choice]++
                    remainingStatPoints--
                    M << output("You increased [choice] by 1", "Info")