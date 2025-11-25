#define STEP_NAME   1
#define STEP_CLASS  2
#define STEP_ICON   3
#define STEP_CUSTOM 4
#define STEP_STATS  5

var/list/players = list()

mob
    var
        obj/preview_obj
        selected_name
        selected_class
        selected_icon
        selected_icon_name
        datum/PaletteManager/palette

mob/player_tmp


// Entry point
proc/show_login_menu(mob/player_tmp/M)
    var/list/options = list("New Character", "Load Character", "Quit")
    var/choice = input(M, "Select an option:", "Login Menu") in options

    switch(choice)
        if("New Character")
            M << output("Starting a new game...", "Info")
            new_character(M)

        if("Load Character")
            M << output("Loading characters not yet implemented...", "Info")
            show_login_menu(M)

        if("Quit")
            world << output("[M] has logged out", "Messages")
            del M

// Start character creation
proc/new_character(mob/player_tmp/M)
    var/step = STEP_NAME

    while(step)
        switch(step)
            if(STEP_NAME)
                M.selected_name = prompt_for_name(M)
                if(!M.selected_name) return
                M << output("[M.selected_name] is your chosen name", "Info")
                step = STEP_CLASS

            if(STEP_CLASS)
                var/class_choice = prompt_for_class(M)
                M.selected_class = handle_class_selection(M, class_choice)
                if(!M.selected_class) { step = STEP_NAME; continue }
                M << output("[M.selected_class] is your chosen class", "Info")
                step = STEP_ICON

            if(STEP_ICON)
                var/list/iconChoices = get_class_icon_list(M, M.selected_class)
                var/iconChoice = input(M, "Choose your icon:", "Icon Selection") in iconChoices
                if(iconChoice == "Back") { step = STEP_CLASS; continue }
                M.selected_icon      = iconChoices[iconChoice]
                M.selected_icon_name = iconChoice
                step = STEP_CUSTOM

			//icon customization
            if(STEP_CUSTOM)
                InitializeIconBaseColors()
                M.IconPreview()
                step = M.customize_colors()  // must return STEP_STATS or STEP_ICON

            if(STEP_STATS)
                M << output("Allocate Stats","Info")
                step = allocate_stats(M)     // must return STEP_STATS when done
                if(step == STEP_STATS)
                    finalize_player(M)
                    return

// Prompt user for valid name
proc/prompt_for_name(mob/M)
    var/selected_name
    while(!selected_name || !length(trimtext(selected_name)))
        selected_name = input(M, "Enter your name:", "New Character") as text|null
        if(isnull(selected_name))
            show_login_menu(M)
            return null
        return trimtext(selected_name)

// Class prompt
proc/prompt_for_class(mob/M)
    var/list/classes = list("Hero", "Soldier", "Wizard", "Back")
    var/class_choice = input(M, "Choose your class:", "Class Selection") in classes
    return class_choice

// Class selection logic
proc/handle_class_selection(mob/M, class_choice)
    if(class_choice == "Back")
        if(M.preview_obj)
            del M.preview_obj
        return null
    return class_choice

// Retrieve class icon lists
proc/get_class_icon_list(mob/M, class_choice)
    switch(class_choice)
        if("Hero")
            return list("DW1 Hero"='dw1hero.dmi', "DW2 Hero"='dw2hero.dmi', "DW3 Hero"='dw3hero.dmi', "Back")
        if("Soldier")
            return list("DW1 Soldier"='dw1soldier.dmi', "DW2 Soldier"='dw2soldier.dmi', "DW3 Guard"='dw3guard.dmi', "Back")
        if("Wizard")
            return list("DW1 Wizard"='dw1wizard.dmi', "DW2 Wizard"='dw2wizard.dmi', "DW3 Wizard"='dw3malewizard.dmi', "Back")
    return list()

// Icon selection prompt
proc/prompt_for_icon(mob/M, class_choice)
    var/list/icons = get_class_icon_list(M, class_choice)
    var/icon_choice = input(M, "Choose your appearance:", "Icon Selection") in icons
    return icon_choice

// Handle icon selection
proc/handle_icon_selection(mob/M, icon_choice, class_choice)
    if(icon_choice == "Back")
        if(M.preview_obj)
            del M.preview_obj
        return null
    return get_class_icon_list(M, icon_choice)

// Custom colors
mob/proc/customize_colors()
	palette = new /datum/PaletteManager(selected_class, selected_icon)
	src << "selected_icon = [selected_icon]"

	while(TRUE)
		var/list/options = list("Main", "Accent", "Hair", "Eyes", "Finish", "Back")
		var/zone_choice = input(src, "Choose another zone or Finish", "Color Customization") in options

		switch(zone_choice)
			if("Main")       Set_Main()
			if("Accent")     Set_Accent()
			if("Hair")       Set_Hair()
			if("Eyes")       Set_Eyes()
			if("Finish")
				if(preview_obj)
					icon = preview_obj.icon
				client.eye = src
				src << output("Finished", "Info")
				return STEP_STATS
			if("Back")
				if(preview_obj)
					del preview_obj
				client.eye = src   // or M, or a black turf
				src << output("Back", "Info")
				return STEP_ICON


// Show preview of icon
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
    client.eye = preview

    UpdateAppearance(preview_obj)



// Finalize player
proc/finalize_player(mob/player_tmp/M)
    var/mob/player/newplayer

    switch(M.selected_class)
        if("Hero")    newplayer = new /mob/player/hero
        if("Soldier") newplayer = new /mob/player/soldier
        if("Wizard")  newplayer = new /mob/player/wizard

    if(!newplayer) return

    // Copy name and icon
    newplayer.name = M.selected_name
    if(M.preview_obj)
        newplayer.icon = icon(M.preview_obj.icon)
        newplayer.icon_state = M.preview_obj.icon_state
    else
        newplayer.icon = icon(M.selected_icon)
        newplayer.icon_state = "world"

    // Copy stats from the temporary mob
    newplayer.Strength     = M.Strength
    newplayer.Vitality     = M.Vitality
    newplayer.Agility      = M.Agility
    newplayer.Intelligence = M.Intelligence
    newplayer.Luck         = M.Luck

    // Transfer control
    M << sound(null, channel=1)
    newplayer << sound('dw4town.mid', repeat=1, channel=1, volume=world_volume)
    M.client.mob = newplayer
    newplayer.loc = locate(26,8,4)
    players += newplayer
    del M

// Stat allocation
proc/allocate_stats(mob/player_tmp/M)
    var/local_points = 10   // give each player 10 points to spend
    while(TRUE)
        // Show current stats and remaining points
        var/list/options = list(
            "Strength [M.Strength]"     = "Strength",
            "Vitality [M.Vitality]"     = "Vitality",
            "Agility [M.Agility]"       = "Agility",
            "Intelligence [M.Intelligence]" = "Intelligence",
            "Luck [M.Luck]"             = "Luck",
            "Back"                      = "Back",
            "Finish"                    = "Finish"
        )

        var/choice = input(M, "Allocate your stat points. Points left ([local_points])", "Stats") in options
        choice = options[choice]

        switch(choice)
            if("Strength","Vitality","Agility","Intelligence","Luck")
                local_points = increment_stat(M, choice, local_points)
                if(local_points > 0) M << output("You increased [choice] by 1", "Info")
            if("Back")
                return STEP_ICON
            if("Finish")
                if(local_points > 0)
                    return
                else
                    return STEP_STATS   // signal completion


proc/increment_stat(mob/player_tmp/M, stat, local_points)
	if(local_points <= 0)
		M << "No points left!"
		return local_points

	switch(stat)
		if("Strength")     M.Strength++
		if("Vitality")     M.Vitality++
		if("Agility")      M.Agility++
		if("Intelligence") M.Intelligence++
		if("Luck")         M.Luck++

	return local_points - 1