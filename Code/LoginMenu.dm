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

// Temporary mob used during character creation
mob
    var
        obj/preview_obj                // preview object for icon customization
        icon/base_preview_icon         // for recoloring just in case
        selected_name                  // chosen character name
        selected_class                 // chosen class (Hero, Soldier, Wizard)
        selected_icon                  // chosen icon file
        selected_icon_name             // chosen icon label
        datum/PaletteManager/palette   // palette manager for recoloring

mob/player_tmp   // placeholder mob type for login/creation

// -----------------------------
// Entry Point: Login Menu
// -----------------------------
proc/show_login_menu(mob/player_tmp/M)
    var/list/options = list("Continue", "Create New Character", "Quit")
    var/choice = input(M, "Welcome to Dragon Warrior Legacy", "Login Menu") in options

    switch(choice)
        if("Continue")
            if(M.client && M.client.save_mgr)
                if(M.client.save_mgr.load_character(M, 1))
                    M << output("Character loaded from save slot 1.", "Info")
                    return
                else
                    M << "No saved character found."
                    new_character(M)

        if("Create New Character")
            M << output("Starting a new game...", "Info")
            new_character(M)

        if("Quit")
            players << output("[M] has logged out", "Messages")
            del M


// -----------------------------
// Character Creation Flow
// -----------------------------
proc/new_character(mob/player_tmp/M)
    var/step = STEP_NAME

    while(step)
        switch(step)
            if(STEP_NAME)
                // Prompt for name
                M.selected_name = prompt_for_name(M)
                if(!M.selected_name) return
                M << output("[M.selected_name] is your chosen name", "Info")
                step = STEP_CLASS

            if(STEP_CLASS)
                // Prompt for class
                var/class_choice = prompt_for_class(M)
                M.selected_class = handle_class_selection(M, class_choice)
                if(!M.selected_class) { step = STEP_NAME; continue }
                M << output("[M.selected_class] is your chosen class", "Info")
                step = STEP_ICON

            if(STEP_ICON)
                M.palette = null
                step = select_icon(M)
                continue

            if(STEP_CUSTOM)
                // Icon customization
                M.IconPreview()
                step = M.customize_colors()  // must return STEP_STATS or STEP_ICON

            if(STEP_STATS)
                // Stat allocation
                M << output("Allocate Stats","Info")
                step = allocate_stats(M)     // must return STEP_STATS when done
                if(step == STEP_STATS)
                    finalize_player(M)
                    return

// -----------------------------
// Prompts
// -----------------------------

//Name
proc/prompt_for_name(mob/M)
    var/selected_name
    while(!selected_name || !length(trimtext(selected_name)))
        selected_name = input(M, "Enter your name:", "New Character") as text|null
        if(isnull(selected_name))
            show_login_menu(M)
            return null
    return trimtext(selected_name)
//Class
proc/prompt_for_class(mob/M)
    var/list/classes = list("Hero", "Soldier", "Wizard", "Back")
    return input(M, "Choose your class:", "Class Selection") in classes

//idk why this is in with prompts section but ok?
proc/handle_class_selection(mob/M, class_choice)
    if(class_choice == "Back")
        if(M.preview_obj) del M.preview_obj
        return null
    return class_choice

// -----------------------------
// Icon Handling
// -----------------------------

//fetch list based on the class player chooses
proc/get_class_icon_list(mob/M, class_choice)
    switch(class_choice)
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
proc/select_icon(mob/player_tmp/M)
    var/list/iconChoices = get_class_icon_list(M, M.selected_class)
    var/iconChoice = input(M, "Choose your icon:", "Icon Selection") in iconChoices

    if(iconChoice == "Back")
        return STEP_CLASS

    M.selected_icon      = iconChoices[iconChoice]
    M.selected_icon_name = "[iconChoices[iconChoice]]"

    M << output("You've selected [M.selected_icon_name]", "Info")
    return STEP_CUSTOM

//---------------------------------
// Preview icon in a separate area
//---------------------------------
mob/proc/IconPreview(turf/T = locate(3,3,2))
    if(preview_obj)
        del preview_obj

    if(!selected_icon)
        return

    var/obj/preview = new /obj
    preview.icon = icon(selected_icon)
    preview.icon_state = "world"
    preview.loc = T

    preview_obj = preview

    //Store pristine base icon ONCE
    base_preview_icon = icon(selected_icon)

    client.eye = preview

    UpdateAppearance()

// -----------------------------
// Icon Customization
// -----------------------------
mob/proc/customize_colors()
    // Build palette ONCE
    palette = new /datum/PaletteManager(selected_class, selected_icon_name)

    while(TRUE)
        var/list/options = list("Main", "Accent", "Hair", "Eyes", "Finish", "Back")
        var/zone_choice = input(src, "Choose a zone to change or Finish", "Color Customization") in options

        switch(zone_choice)
            if("Main")   Set_Main()
            if("Accent") Set_Accent()
            if("Hair")   Set_Hair()
            if("Eyes")   Set_Eyes()
            if("Finish")
                src.hair_color   = palette.GetZoneColor("Hair")
                src.eye_color    = palette.GetZoneColor("Eyes")
                src.main_color   = palette.GetZoneColor("Main")
                src.accent_color = palette.GetZoneColor("Accent")

                client.eye = src
                src << output("Icon colors applied!", "Info")

                return STEP_STATS

            if("Back")
                // CLEANUP PREVIEW STATE
                base_preview_icon = null
                if(preview_obj)
                    del preview_obj
                preview_obj = null

                return STEP_ICON

// -----------------------------
// Finalize Player
// -----------------------------
proc/finalize_player(mob/player_tmp/M)
    if(!M || !M.client) return

    var/mob/player/newplayer = create_player_from_class(M.selected_class)
    if(!newplayer) return

    // Identity
    newplayer.name = M.selected_name

    // Appearance & stats
    copy_appearance(M, newplayer)
    copy_stats(M, newplayer)

    // Transfer control
    M << output("Player finalized", "Info")
    M << sound(null, channel=1)

    newplayer << sound('dw4town.mid', repeat=1, channel=1, volume=world_volume)

    M.client.mob = newplayer
    newplayer.loc = locate(26, 8, 4)

    players += newplayer

    // Save immediately
    if(M.client && M.client.save_mgr)
        M.client.save_mgr.save_character(newplayer, 1)

    del M
    players << output("[newplayer.name] has joined the world!", "Messages")

//selects proper template based on class templates
proc/create_player_from_class(class_name)
    switch(class_name)
        if("Hero")    return new /mob/player/hero
        if("Soldier") return new /mob/player/soldier
        if("Wizard")  return new /mob/player/wizard

        // Future classes
        // if("Fighter") return new /mob/player/fighter
        // if("Pilgrim") return new /mob/player/pilgrim
        // if("Goof-off") return new /mob/player/goofoff
        // if("Sage")     return new /mob/player/sage
        // if("Custom")   return new /mob/player/GM

    return null

//copy temp stats to player stats
proc/copy_stats(mob/player_tmp/src, mob/player/dst)
    dst.Strength     = src.Strength
    dst.Vitality     = src.Vitality
    dst.Agility      = src.Agility
    dst.Intelligence = src.Intelligence
    dst.Luck         = src.Luck

//copy player appearance from preview
proc/copy_appearance(mob/player_tmp/src, mob/player/dst)
    if(src.preview_obj)
        dst.icon = icon(src.preview_obj.icon)
        dst.icon_state = src.preview_obj.icon_state
    else
        dst.icon = icon(src.selected_icon)
        dst.icon_state = "world"

    dst.base_icon    = "[src.selected_icon]"
    dst.hair_color   = "[src.hair_color]"
    dst.eye_color    = "[src.eye_color]"
    dst.main_color   = "[src.main_color]"
    dst.accent_color = "[src.accent_color]"



// -----------------------------
// Stat Allocation
// -----------------------------
proc/allocate_stats(mob/player_tmp/M)
    var/local_points = 14
    var/stat_cap = 10

    // Temporary stat storage
    var/list/tmp_stats = list(
        "Strength"     = M.Strength,
        "Vitality"     = M.Vitality,
        "Agility"      = M.Agility,
        "Intelligence" = M.Intelligence,
        "Luck"         = M.Luck
    )

    while(TRUE)
        var/list/options = list()

        // Build menu dynamically
        for(var/stat in tmp_stats)
            if(tmp_stats[stat] < stat_cap)
                options["[stat] [tmp_stats[stat]]"] = stat

        options["Back"]   = "Back"
        options["Finish"] = "Finish"

        var/choice = input(
            M,
            "Allocate your stat points. Points left ([local_points])",
            "Stats"
        ) in options

        choice = options[choice]

        switch(choice)
            if("Back")
                return STEP_ICON

            if("Finish")
                if(local_points > 0)
                    M << output("You must spend all points before finishing.", "Info")
                else
                    // Commit changes
                    for(var/stat in tmp_stats)
                        M.vars[stat] = tmp_stats[stat]
                    return STEP_STATS

            else
                if(local_points <= 0)
                    M << output("You have no points left.", "Info")
                else if(tmp_stats[choice] >= stat_cap)
                    M << output("Starter stats are capped at [stat_cap]!", "Info")
                else
                    tmp_stats[choice]++
                    local_points--
                    M << output("You increased [choice] by 1", "Info")