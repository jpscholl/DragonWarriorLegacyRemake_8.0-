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
var/list/players = list()

// Temporary mob used during character creation
mob
    var
        obj/preview_obj                // preview object for icon customization
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
                    M << "Character loaded from save slot 1."
                    return
                else
                    M << "No saved character found."
                    new_character(M)

        if("Create New Character")
            M << output("Starting a new game...", "Info")
            new_character(M)

        if("Quit")
            world << output("[M] has logged out", "Messages")
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
                step = select_icon(M)
                continue

            if(STEP_CUSTOM)
                // Icon customization
                InitializeIconBaseColors()
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
            return list("Dragon Warrior 1 Hero"='dw1hero.dmi', "Dragon Warrior 2 Hero"='dw2hero.dmi', "Dragon Warrior 3 Hero"='dw3hero.dmi', "Back")
        if("Soldier")
            return list("Dragon Warrior 1 Soldier"='dw1soldier.dmi', "Dragon Warrior 2 Soldier"='dw2soldier.dmi', "Dragon Warrior 3 Guard"='dw3guard.dmi', "Back")
        if("Wizard")
            return list("Dragon Warrior 1 Wizard"='dw1wizard.dmi', "Dragon Warrior 2 Wizard"='dw2wizard.dmi', "Dragon Warrior 3 Wizard"='dw3malewizard.dmi', "Back")
    return list()

//icon selection and storage
proc/select_icon(mob/player_tmp/M)
    var/list/iconChoices = get_class_icon_list(M, M.selected_class)
    var/iconChoice = input(M, "Choose your icon:", "Icon Selection") in iconChoices

    if(iconChoice == "Back")
        return STEP_CLASS

    M.selected_icon      = iconChoices[iconChoice]
    M.selected_icon_name = iconChoice

    M << output("You've selected [M.selected_icon_name]", "Info")
    return STEP_CUSTOM

//---------------------------------
// Preview icon in a separate area
//---------------------------------
mob/proc/IconPreview(turf/T = locate(3,3,2))
    if(preview_obj) del preview_obj
    if(!selected_icon) return

    var/obj/preview = new /obj
    preview.icon = icon(selected_icon)
    preview.icon_state = "world"
    preview.loc = T

    preview_obj = preview
    client.eye = preview

    UpdateAppearance(preview_obj)

// -----------------------------
// Icon Customization
// -----------------------------
mob/proc/customize_colors()
    palette = new /datum/PaletteManager(selected_class, selected_icon)

    while(TRUE)
        var/list/options = list("Main", "Accent", "Hair", "Eyes", "Finish", "Back")
        var/zone_choice = input(src, "Choose another zone or Finish", "Color Customization") in options

        switch(zone_choice)
            if("Main")       Set_Main()
            if("Accent")     Set_Accent()
            if("Hair")       Set_Hair()
            if("Eyes")       Set_Eyes()
            if("Finish")
                if(preview_obj) icon = preview_obj.icon
                src.hair_color   = "[palette.colors["Hair"]]"
                src.eye_color    = "[palette.colors["Eyes"]]"
                src.main_color   = "[palette.colors["Main"]]"
                src.accent_color = "[palette.colors["Accent"]]"
                client.eye = src
                src << output("Icon looking sharp!", "Info")
                return STEP_STATS
            if("Back")
                if(preview_obj) del preview_obj
                client.eye = src
                return STEP_ICON

// -----------------------------
// Finalize Player
// -----------------------------
proc/finalize_player(mob/player_tmp/M)
    var/mob/player/newplayer

    // Create new mob based on class
    switch(M.selected_class)
        if("Hero")    newplayer = new /mob/player/hero
        if("Soldier") newplayer = new /mob/player/soldier
        if("Wizard")  newplayer = new /mob/player/wizard
        //implement these classes later
        //if("Fighter") newplayer = new /mob/player/fighter
        //if("Pilgrim") newplayer = new /mob/player/pilgrim
        //if("Goof-off) newplayer = new /mob/player/goofoff

    if(!newplayer) return

    // Copy name and icon
    newplayer.name = M.selected_name
    if(M.preview_obj)
        newplayer.icon = icon(M.preview_obj.icon)
        newplayer.icon_state = M.preview_obj.icon_state
    else
        newplayer.icon = icon(M.selected_icon)
        newplayer.icon_state = "world"

    // Copy stats
    newplayer.Strength     = M.Strength
    newplayer.Vitality     = M.Vitality
    newplayer.Agility      = M.Agility
    newplayer.Intelligence = M.Intelligence
    newplayer.Luck         = M.Luck

    //save icon and zone colors
    newplayer.base_icon    = "[M.selected_icon]";
    newplayer.hair_color   = "[M.hair_color]"
    newplayer.eye_color    = "[M.eye_color]"
    newplayer.main_color   = "[M.main_color]"
    newplayer.accent_color = "[M.accent_color]"

    // Transfer control to new mob
    M << output("Player finalized", "Info")
    M << sound(null, channel=1)
    newplayer << sound('dw4town.mid', repeat=1, channel=1, volume=world_volume)
    M.client.mob = newplayer
    newplayer.loc = locate(26,8,4)
    players += newplayer


    // Save immediately
    if(M.client && M.client.save_mgr)
        M.client.save_mgr.save_character(newplayer, 1)
    del M
    players << output("[newplayer.name] has joined the world!", "Messages")

// -----------------------------
// Stat Allocation
// -----------------------------
proc/allocate_stats(mob/player_tmp/M)
    var/local_points = 12
    var/tmp_strength = M.Strength
    var/tmp_vitality = M.Vitality
    var/tmp_agility = M.Agility
    var/tmp_intelligence = M.Intelligence
    var/tmp_luck = M.Luck

    while(TRUE)
        var/list/options = list(
            "Strength [tmp_strength]" = "Strength",
            "Vitality [tmp_vitality]" = "Vitality",
            "Agility [tmp_agility]" = "Agility",
            "Intelligence [tmp_intelligence]" = "Intelligence",
            "Luck [tmp_luck]" = "Luck",
            "Back" = "Back",
            "Finish" = "Finish"
        )

        var/choice = input(M, "Allocate your stat points. Points left ([local_points])", "Stats") in options
        choice = options[choice]

        switch(choice)
            if("Strength")
                if(local_points > 0 && tmp_strength < 10) { tmp_strength++; local_points--; M << "You increased Strength by 1" }
                else M << "No points left!"
            if("Vitality")
                if(local_points > 0) { tmp_vitality++; local_points--; M << "You increased Vitality by 1" }
                else M << "No points left!"
            if("Agility")
                if(local_points > 0) { tmp_agility++; local_points--; M << "You increased Agility by 1" }
                else M << "No points left!"
            if("Intelligence")
                if(local_points > 0) { tmp_intelligence++; local_points--; M << "You increased Intelligence by 1" }
                else M << "No points left!"
            if("Luck")
                if(local_points > 0) { tmp_luck++; local_points--; M << "You increased Luck by 1" }
                else M << "No points left!"

            if("Back")
                return STEP_ICON   // discard changes
            if("Finish")
                if(local_points > 0)
                    M << "You must spend all points before finishing."
                else
                    // commit changes
                    M.Strength     = tmp_strength
                    M.Vitality     = tmp_vitality
                    M.Agility      = tmp_agility
                    M.Intelligence = tmp_intelligence
                    M.Luck         = tmp_luck
                    return STEP_STATS