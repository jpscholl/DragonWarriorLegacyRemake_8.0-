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

// Entry point
proc/show_login_menu(mob/player_tmp/M)
	var/list/options = list("New Character","Load Character","Quit")
	var/choice = input(M,"Select an option:","Login Menu") in options

	switch(choice)
		if("New Character")
			M << output("Starting a new game...", "Info")
			new_character(M)
		if("Load Character")
			M << "Loading characters not yet implemented..."
			show_login_menu(M)
		if("Quit")
			world << output("[M] has logged out", "Messages")
			del M

//start character creation
proc/new_character(mob/player_tmp/M)
	var/step = STEP_NAME

	while(step)
		switch(step)
            // Name
			if(STEP_NAME)
				M.selected_name = prompt_for_name(M)
				if(M.selected_name)
					M << output("[M.selected_name] is your chosen name", "Info")
					step = STEP_CLASS // move to next step
				else
					return // Go back to start menu

            // Class
			if(STEP_CLASS)
				var/class_choice = prompt_for_class(M)
				M.selected_class = handle_class_selection(M, class_choice)
				if(M.selected_class)
					M << output("[M.selected_class] is your chosen class", "Info")
					step = STEP_ICON // Move to icon select
				else
					step = STEP_NAME  // Go back to name select

			// Icon
			if(STEP_ICON)
				var/list/iconChoices = get_class_icon_list(M, M.selected_class)
				var/iconChoice = input(M, "Choose your icon:", "Icon Selection") in iconChoices

				if(iconChoice == "Back")
					step = STEP_CLASS
				else
					M.selected_icon      = iconChoices[iconChoice]   // file reference
					M.selected_icon_name = iconChoice                // name reference
					// Move to customizationn
					step = STEP_CUSTOM

			// Icon Customize
			if(STEP_CUSTOM)
				InitializeIconBaseColors()
				IconPreview(M)
				step = M.customize_colors()

			if(STEP_STATS)
				M << output("Allocate Stats","Info")
				break

			//Stat Allocation

//Send player to start location

//prompt user for valid name and return it
proc/prompt_for_name(mob/M)
	var/selected_name
	while(!selected_name || !length(trimtext(selected_name)))
		selected_name = input(M,"Enter your name:","New Character") as text|null
		if(isnull(selected_name))
			show_login_menu(M)
			return null
	return trimtext(selected_name)

// Handles just the class prompt
proc/prompt_for_class(mob/M)
	var/list/classes = list("Hero","Soldier","Wizard","Back")
	var/class_choice = input(M, "Choose your class:", "Class Selection") in classes
	return class_choice

// Handles the class selection logic
proc/handle_class_selection(mob/M, class_choice)
	if(class_choice == "Back")
		if(M.preview_obj)
			del M.preview_obj
		return null   // signal caller to restart name selection
	return class_choice

//Handles retrieval of class lists
proc/get_class_icon_list(mob/M, class_choice)
	switch(class_choice)
		if("Hero") return list("DW1 Hero"='dw1hero.dmi',"DW2 Hero"='dw2hero.dmi',"DW3 Hero"='dw3hero.dmi',"Back")
		if("Soldier") return list("DW1 Soldier"='dw1soldier.dmi',"DW2 Soldier"='dw2soldier.dmi',"DW3 Guard"='dw3guard.dmi',"Back")
		if("Wizard") return list("DW1 Wizard"='dw1wizard.dmi',"DW2 Wizard"='dw2wizard.dmi',"DW3 Wizard"='dw3malewizard.dmi',"Back")
	return list()

//handles the icon selection prompt
proc/prompt_for_icon(mob/M, class_choice)
	var/list/icons = get_class_icon_list(M, class_choice)
	var/icon_choice = input(M,"Choose your appearance:","Icon Selection") in icons
	return icon_choice

//handles icon selection from list
proc/handle_icon_selection(mob/M, icon_choice, class_choice)
	if(icon_choice == "Back")
		if(M.preview_obj)
			del M.preview_obj
		return null   // signal caller to restart class selection
	return get_class_icon_list(M, icon_choice)

//handles custom_colors
mob/proc/customize_colors()
    palette = new /datum/PaletteManager(selected_class, selected_icon)
    src << "selected_icon = [selected_icon]"

    var/done = FALSE
    while(!done)
        var/list/options = list("Main","Accent","Hair","Eyes","Finish","Back")
        var/zone_choice = input(src,"Choose another zone or Finish","Color Customization") in options

        switch(zone_choice)
            if("Main")   Set_Main()
            if("Accent") Set_Accent()
            if("Hair")   Set_Hair()
            if("Eyes")   Set_Eyes()
            if("Finish")
                icon = preview_obj.icon
                client.eye = src
                src << output("Finished","Info")
                return STEP_STATS
            if("Back")
                src << output("Back","Info")
                return STEP_ICON

//show preview of icon when updated
proc/IconPreview(mob/M)
	if(M.preview_obj) del M.preview_obj
	var/obj/preview = new /obj
	preview.icon = icon(M.selected_icon)
	preview.icon_state = "world"
	preview.loc = locate(3,3,2)
	M.preview_obj = preview
	M.client.eye = preview

// Create mob by class
proc/create_player_mob(class_choice)
    switch(class_choice)
        if("Hero") return new /mob/player/hero
        if("Soldier") return new /mob/player/soldier
        if("Wizard") return new /mob/player/wizard
    return null