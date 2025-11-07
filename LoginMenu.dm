var
	list
		players = list()

// Entry point for login menu
proc/show_login_menu(mob/M)
	var/list/options = list("New Character", "Load Character", "Quit")
	var/choice = input(M, "Select an option:", "Login Menu") in options

	switch(choice)
		if("New Character")
			M << output("Starting a new game...", "Info")
			new_character(M)
		if("Load Character")
			M << output("Loading characters not yet implemented...", "Info")
			show_login_menu(M) // Re-show the menu
			// TODO: Implement character loading
		if("Quit")
			M << "[M] has logged out"
			del M


// Character creation flow
proc/new_character(mob/player_tmp/M)
	var/name = prompt_for_name(M)
	if(!name) return

	M.name = name

	var/class_choice
	var/icon
	var/is_valid_selection = FALSE

	while(!is_valid_selection)
		class_choice = prompt_for_class(M)
		if(!class_choice) return

		while(TRUE)
			icon = prompt_for_icon(M, class_choice)
			if(icon == "Back")
				break
			if(icon)
				is_valid_selection = TRUE
				break

	var/mob/player/new_player = create_player_mob(class_choice)
	if(!new_player) return

	new_player.name = M.name
	new_player.icon = icon
	new_player.loc = locate(26, 8, 4)
	M.client.mob = new_player
	del M

	new_player << "Welcome, [new_player.name] the [new_player.class]!"
	players += new_player


// Prompt for valid name
proc/prompt_for_name(mob/M)
	var/name
	while(!name || !length(trimtext(name)))
		name = input(M, "Enter your name:", "New Character") as text|null
		if(isnull(name))
			show_login_menu(M)
			return null
	return trimtext(name)


// Prompt for class selection
proc/prompt_for_class(mob/M)
	var/list/classes = list("Hero", "Soldier", "Wizard", "Back")
	var/class_choice

	while(TRUE)
		class_choice = input(M, "Choose your class:", "Class Selection") in classes
		if(class_choice == "Back")
			show_login_menu(M)
			return null
		return class_choice


// Prompt for icon selection
proc/prompt_for_icon(mob/M, class_choice)
	var/list/icons = get_class_icons(class_choice)
	var/icon_choice = input(M, "Choose your appearance:", "Icon Selection") in icons
	if(isnull(icon_choice) || icon_choice == "Back")
		return "Back"
	return icons[icon_choice]


// Prompt for color selection
proc/prompt_for_icon_color(mob/M)
	var/list/colors = list("Red", "Blue", "Green", "Yellow", "Purple", "Black", "White")
	var/color_choice = input(M, "Choose your icon color:", "Color Selection") in colors
	get_icon_color(M, color_choice)


// Select colors
proc/get_icon_color(mob/M, color_choice)
	//var/icon/base_icon = icon('base_icon.dmi', "default") // Replace with your actual icon
	//var/icon/colored_icon = base_icon
	//colored_icon.Blend(color_choice, ICON_MULTIPLY)
	//M.icon = colored_icon


// Returns icon list for a given class
proc/get_class_icons(class_choice)
	switch(class_choice)
		if("Hero") return list("DW3 Male" = 'dw3hero.dmi', "DW2 Male" = 'dw2hero.dmi', "Back" = null)
		if("Soldier") return list("DW3 Guard" = 'dw3guard.dmi', "DW2 Soldier" = 'dw2soldier.dmi', "Back" = null)
		if("Wizard") return list("DW3 M Wizard" = 'dw3malewizard.dmi', "DW2 M Wizard" = 'dw2wizard.dmi', "Back" = null)
	return list()


// Creates a new mob instance based on class
proc/create_player_mob(class_choice)
	switch(class_choice)
		if("Hero") return new /mob/player/hero
		if("Soldier") return new /mob/player/soldier
		if("Wizard") return new /mob/player/wizard
	return null