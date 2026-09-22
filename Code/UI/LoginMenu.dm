// -----------------------------
// Character Creation Pipeline
// -----------------------------
// Step constants for the creation flow now live in the .dme itself — see its own
// comment for why (Code/Player/PlayerTemplate.dm's RunSageReclassFlow() needs them too
// and compiles first).

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
            M.ShowInfo("This character has been banned and can't be loaded.")
            ShowLoginMenu(M)
            return
        if(!M.client.saveManager.LoadCharacter(M, slot))
            // Previously failed silently, leaving the player stuck controlling the
            // temp mob at BYOND's (1,1,1) origin forever with no menu or explanation.
            M.ShowInfo("Something went wrong loading that character.")
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
                M.ShowInfo("[M.selectedName] is your chosen name")
                step = STEP_CLASS

            if(STEP_CLASS)
                // Prompt for class
                var/selectedClass = PromptForClass(M)
                M.selectedClass = ApplyClassSelection(M, selectedClass)
                if(!M.selectedClass) { step = STEP_NAME; continue }
                M.ShowInfo("[M.selectedClass] is your chosen class")
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
                // Archsage starts maxed (Level/stats set in FinalizePlayer() below) —
                // nothing to interactively allocate, so skip straight to confirmation.
                if(M.selectedClass == "Archsage")
                    step = STEP_STATS
                else
                    // Stat allocation
                    M.ShowInfo("Allocate Stats")
                    step = StatAllocation(M)     // must return STEP_STATS when done
                if(step == STEP_STATS)
                    if(M && M.client)
                        // Confirmation before the character is actually saved
                        // (TODOList.md Phase 1) — "No" loops back to stat allocation
                        // rather than discarding everything back to STEP_NAME, since
                        // stats are the thing most likely to prompt a change of mind.
                        var/confirm = alert(M, "Lock in [M.selectedName], the [M.selectedClass]?", "Confirm Character", "Yes", "No")
                        if(confirm != "Yes")
                            step = STEP_STATS
                            continue
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

        // Duplicate-name check across this ckey's OWN save slots only (TODOList.md
        // Phase 1) — this isn't a global uniqueness rule (two different accounts can
        // both have a "Hero"), just a guard against a player confusing two of their
        // own characters with matching names. Case-insensitive so "Hero"/"hero" still
        // counts as a clash.
        if(M.client && M.client.saveManager)
            var/list/existingSlots = M.client.saveManager.GetCharacterSlots()
            var/isDuplicate = FALSE
            for(var/slot in existingSlots)
                if(lowertext(existingSlots[slot]) == lowertext(selectedName))
                    isDuplicate = TRUE
                    break
            if(isDuplicate)
                prompt = "You already have a character named [selectedName]. Enter your name:"
                continue

        return selectedName
//Class
proc/PromptForClass(mob/M)
    // Sage deliberately excluded — GM-only direct pick per existing design
    // (TODOList.md), not a creation-time choice for normal players.
    var/list/classes = list("Hero", "Soldier", "Wizard", "Fighter", "Pilgrim", "Goof-off")

    // Archsage (PlayerTemplate.dm) is Cerebella's own personal test-all-skills class —
    // gated on AEON_CKEY (AdminLevels.dm, her own hardcoded ckey) so it only ever shows
    // up in HER class list, never a real player's.
    if(M.ckey == AEON_CKEY)
        classes += "Archsage"

    classes += "Back"
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
// Built straight from the icon registry (PlayerIconColorPalette.dm) rather than a
// hand-written list per class. The registry already has to name every icon file in order
// to carry its zone colors, and keeping a second copy of that here is exactly what let
// Archsage's picker (which offers every other class's portraits) drift out of sync with
// the per-class ones — it used to carry a "keep in sync by hand" warning. Archsage sees
// every entry, its own precolored portrait included; every other class sees only its own.
proc/GetClassIcons(mob/M, selectedClass)
    var/list/out = list()

    for(var/id in playerIconRegistry)
        var/datum/PlayerIcon/entry = playerIconRegistry[id]
        if(selectedClass == "Archsage" || entry.class == selectedClass)
            out[entry.label] = entry.file

    out += "Back"
    return out

//icon selection and storage
// Untyped mob (not mob/playerTemp) — the vars this touches (selectedClass/selectedIcon/
// selectedIconName) are declared at plain `mob` scope specifically so this same proc can
// run on an existing mob/player mid-game, not just a fresh mob/playerTemp at login. See
// RunSageReclassFlow() (PlayerTemplate.dm), which reuses this exact flow for Classchange.
proc/IconSelect(mob/M)
    var/list/iconChoices = GetClassIcons(M, M.selectedClass)
    // CONFIRMED OG wording: "Who will you look like?", title "Icon".
    var/iconChoice = input(M, "Who will you look like?", "Icon") in iconChoices

    if(iconChoice == "Back")
        return STEP_CLASS

    M.selectedIcon = iconChoices[iconChoice]
    M.selectedIconName = GetIconFilename(M.selectedIcon)

    M.ShowInfo("You've selected [M.selectedIconName]")

    // Nothing to customize — skip the color loop entirely and go straight to stats.
    // That's either art that's already finished (Archsage's own portrait: running it
    // through the palette would just break it) or an icon whose zone colors aren't
    // authored yet, which used to reach the color menu and answer every pick with
    // "Invalid zone" instead of saying so up front.
    //
    // Runs IconPreview() itself (STEP_CUSTOM's own call never happens otherwise) and
    // resets client.eye back to M immediately after — skipping CustomizeColors() means
    // its "Finish" branch (which normally does that reset) never runs, and IconPreview()
    // leaves eye on the temporary preview object, which would otherwise leave the new
    // character never rendering in-world until the next relog forces a fresh eye. See
    // Markdowns/CodeNotes.md.
    var/datum/PlayerIcon/entry = GetPlayerIcon(M.selectedIconName)
    if(!entry || !entry.IsRecolorable())
        // Reclass reuses this flow on an already-playing mob, so clear any colors the
        // old portrait had rather than carrying them onto art that can't use them.
        M.zoneColors = null
        M.IconPreview()
        M.client.eye = M
        return STEP_STATS

    return STEP_CUSTOM

//---------------------------------
// Preview icon in a separate area
//---------------------------------
mob/proc/IconPreview(turf/T = CREATION_PREVIEW_TURF)
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
    // Build palette ONCE. Deliberately NOT seeded from this mob's existing zoneColors:
    // reclass runs this same flow on an already-playing character who is picking a whole
    // new portrait, and starting that from the new art's own colors (rather than the old
    // character's picks) is the behavior this has always had.
    palette = new /datum/PaletteManager(selectedIconName, null, src)

    var/lastZone = null // which zone was picked last, so the dialog re-highlights it (same pattern as StatAllocation()'s lastStat)

    while(TRUE)
        // Zones come from the icon's own registry entry (PlayerIconColorPalette.dm), so
        // an icon that only has a costume color offers only that, and adding a zone to
        // an icon needs no change here.
        var/list/options = list()
        for(var/zone in palette.Zones())
            options += zone
        options += list("Reset All to Default", "Finish", "Back")

        var/zone_choice = input(src, "Choose a zone to change or Finish", "Color Customization", lastZone) in options
        if(isnull(zone_choice))
            continue
        lastZone = zone_choice // harmless for "Finish"/"Back"/"Reset All to Default" too, see below

        switch(zone_choice)
            if("Reset All to Default")
                // Drops every override at once — same thing each zone's own "Default
                // Color" option does, just applied to all of them.
                palette.ClearAll()
                UpdateAppearance()
                src.ShowInfo("All zones reset to default colors.")

            if("Finish")
                // Only the zones actually picked. A zone left alone stays absent, which
                // is what keeps it following the art instead of pinning today's default.
                src.zoneColors = palette.overrides.len ? palette.overrides.Copy() : null

                client.eye = src
                src.ShowInfo("Icon colors applied!")

                return STEP_STATS

            if("Back")
                // CLEANUP PREVIEW STATE
                baseIconPreview = null
                if(newCharPreview)
                    del newCharPreview
                newCharPreview = null

                return STEP_ICON

            else
                // Anything else in the list is one of this icon's own zone names.
                SetZoneColorPrompt(zone_choice)

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

    // Archsage skips creation-time stat allocation entirely (STEP_STATS, above) — it
    // starts at max level with every stat already at this class's own cap, overwriting
    // whatever ApplyCustomStats() just copied off the (never-shown) allocation screen.
    if(istype(newPlayer, /mob/player/Archsage))
        newPlayer.Level        = MAX_LEVEL
        newPlayer.Strength     = newPlayer.capStrength
        newPlayer.Vitality     = newPlayer.capVitality
        newPlayer.Agility      = newPlayer.capAgility
        newPlayer.Intelligence = newPlayer.capIntelligence
        newPlayer.Spirit       = newPlayer.capSpirit

    // Set from the class's own exp curve (GetNexpForLevel(), CombatSystem.dm) at
    // whatever level this character actually starts at, rather than leaving the base
    // mob's default — that default is the Hero-baseline number and is wrong both for a
    // class with its own exp_start and for the max-level Archsage above.
    newPlayer.Nexp = GetNexpForLevel(newPlayer.Level, newPlayer.exp_start)

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
    M.ShowInfo("Player finalized")
    M << sound(null, channel = 1)

    // Would otherwise sit orphaned at CREATION_PREVIEW_TURF forever -- BecomeSage()
    // (PlayerTemplate.dm) already does this same cleanup for the reclass path; this
    // path (fresh character creation) was missing it. `del M` below doesn't cascade to
    // this -- it's a separate /obj only ever REFERENCED by M's own var, not a child of
    // it. Confirmed real leak 2026-09-09: repeated Logout -> Create Character cycles
    // (each using a brand-new mob/playerTemp, so IconPreview()'s own "delete my
    // previous preview" self-cleanup never sees the PRIOR cycle's mob's preview) left
    // one orphaned preview icon behind per character created this way.
    if(M.newCharPreview) del M.newCharPreview

    C.mob = newPlayer
    // The new mob's own verb list starts fresh from its type declaration (includes
    // GM-only verbs like GM_ToggleLog by default) — re-sync (AdminLevels.dm) so a
    // non-GM's removal carries over from the old temp mob.
    C.SyncGMVerbs()
    newPlayer.loc = GetPlayerSpawnTurf()
    C.AttachCamera(newPlayer)  // camera (SmoothMovement.dm) takes over as eye from here on

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
// Records the two things a character's look is actually made of — which registry icon
// they picked and which zones they chose a color for — then repaints through the exact
// same RebuildIcon() a login uses, instead of copying the preview object's already-
// painted pixels onto the mob. Those copied pixels were what got written into the save
// blob, freezing the sprite at creation time.
proc/ApplyCustomColors(mob/playerTemp/src, mob/player/dst)
    dst.basePlayerIcon = src.selectedIconName
    dst.zoneColors     = src.zoneColors ? src.zoneColors.Copy() : null
    dst.icon_state     = "world"
    dst.RebuildIcon()

// -----------------------------
// Stat Allocation — confirmed 2026-08-10: 12 points to allocate, each capped at 10 for
// this screen (the higher per-class ceilings, GetClassStatCaps(), still govern
// level-up spend but aren't reachable at creation).
// -----------------------------
#define CREATION_STAT_POINTS 12
#define CREATION_STAT_CAP 10

// Untyped mob, same reasoning as IconSelect() above — reused for reclass, not just
// fresh creation. resetFromZero = TRUE (RunSageReclassFlow(), PlayerTemplate.dm) seeds
// the scratch allocation from the base-1 starting stats a brand-new mob/player has
// instead of M's own current (likely already-leveled, possibly already-capped) stats —
// without it, a real character's stats block this screen's 10-cap almost immediately
// and can leave every stat too full to spend the fresh CREATION_STAT_POINTS at all.
// M's real vars are still untouched until "Finish" either way, so backing out
// (returns STEP_ICON) never mutates them regardless of resetFromZero.
proc/StatAllocation(mob/M, resetFromZero = FALSE)
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
        "Strength"     = resetFromZero ? 1 : M.Strength,
        "Vitality"     = resetFromZero ? 1 : M.Vitality,
        "Agility"      = resetFromZero ? 1 : M.Agility,
        "Intelligence" = resetFromZero ? 1 : M.Intelligence,
        "Spirit"       = resetFromZero ? 1 : M.Spirit
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
                    M.ShowInfo("You must spend all points before finishing.")
                else
                    // Commit changes (dynamic lookup: "Strength" etc. match mob var names directly)
                    for(var/stat in tempStatPoints)
                        M.vars[stat] = tempStatPoints[stat]
                    return STEP_STATS

            else
                lastStat = choice   // keep this stat highlighted next time regardless of outcome
                if(remainingStatPoints <= 0)
                    M.ShowInfo("You have no points left.")
                else if(tempStatPoints[choice] >= statCaps[choice])
                    M.ShowInfo("[choice] is capped at [statCaps[choice]] for this class!")
                else
                    tempStatPoints[choice]++
                    remainingStatPoints--
                    M.ShowInfo("You increased [choice] by 1")