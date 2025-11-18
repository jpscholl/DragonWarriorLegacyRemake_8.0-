var/list/players = list()

mob
    var/obj/preview_obj
    var/selected_class
    var/selected_icon
    var/selected_color
    var/datum/PaletteManager/palette

// Entry point
proc/show_login_menu(mob/M)
    var/list/options = list("New Character","Load Character","Quit")
    var/choice = input(M,"Select an option:","Login Menu") in options

    switch(choice)
        if("New Character")
            M << "Starting a new game..."
            new_character(M)
        if("Load Character")
            M << "Loading characters not yet implemented..."
            show_login_menu(M)
        if("Quit")
            M << "[M] has logged out"
            del M

// Character creation
proc/new_character(mob/player_tmp/M)
    M.name = prompt_for_name(M)
    if(!M.name) return

    M.selected_class = prompt_for_class(M)
    if(!M.selected_class) return

    M.selected_icon = prompt_for_icon(M, M.selected_class)
    if(M.selected_icon == "Set Zone") return

    // Apply preview + color customization
    icon_customization(M, M.selected_icon)

    var/mob/player/new_player = create_player_mob(M.selected_class)
    if(!new_player) return

    new_player.name = M.name
    new_player.icon = M.icon   // already customized
    var/turf/start = locate(26,8,4)
    if(start)
        new_player.loc = start
    else
        world.log << "Start location invalid!"

    M.client.mob = new_player
    new_player.client.eye = new_player
    del M

    new_player << sound(null)
    new_player << sound('dw4town.mid', repeat=1, volume = world_volume)
    new_player << "Welcome, [new_player.name] the [new_player.class]!"
    players += new_player


// Prompt for name
proc/prompt_for_name(mob/M)
    var/name
    while(!name || !length(trimtext(name)))
        name = input(M,"Enter your name:","New Character") as text|null
        if(isnull(name))
            show_login_menu(M)
            return null
    return trimtext(name)

// Prompt for class
proc/prompt_for_class(mob/M)
    var/list/classes = list("Hero","Soldier","Wizard","Back")
    var/class_choice = input(M,"Choose your class:","Class Selection") in classes
    if(class_choice == "Back")
        if(M.preview_obj) del M.preview_obj
        show_login_menu(M)
        return null
    return class_choice

// Create mob by class
proc/create_player_mob(class_choice)
    switch(class_choice)
        if("Hero") return new /mob/player/hero
        if("Soldier") return new /mob/player/soldier
        if("Wizard") return new /mob/player/wizard
    return null

// Prompt for icon
proc/prompt_for_icon(mob/M,class_choice)
    var/list/icons = get_class_icons(class_choice)
    var/icon_choice = input(M,"Choose your appearance:","Icon Selection") in icons
    if(isnull(icon_choice) || icon_choice=="Back") return "Back"
    return icons[icon_choice]

// Icon lists
proc/get_class_icons(class_choice)
    switch(class_choice)
        if("Hero") return list("DW1 Hero"='dw1hero.dmi',"DW2 Hero"='dw2hero.dmi',"DW3 Hero"='dw3hero.dmi',"Back"=null)
        if("Soldier") return list("DW1 Soldier"='dw1soldier.dmi',"DW2 Soldier"='dw2soldier.dmi',"DW3 Guard"='dw3guard.dmi',"Back"=null)
        if("Wizard") return list("DW1 Wizard"='dw1wizard.dmi',"DW2 Wizard"='dw2wizard.dmi',"DW3 Wizard"='dw3malewizard.dmi',"Back"=null)
    return list()

// Customization
proc/icon_customization(mob/M,icon_choice)
    show_icon_preview(M,icon_choice)
    prompt_for_icon_color(M,icon_choice)

//preview custom icon
proc/show_icon_preview(mob/M,icon_choice)
    if(M.preview_obj) del M.preview_obj
    var/obj/preview = new /obj
    preview.icon = icon_choice
    preview.icon_state = "world"
    preview.loc = locate(3,3,2)
    M.preview_obj = preview
    M.client.eye = preview

//color menu
proc/prompt_for_icon_color(mob/M,icon_choice)
    if(!M || !M.client) return
    var/list/colors = list("Red","Blue","Green","Yellow","Purple","Black","White", "Set Zone")
    var/color_choice = input(M,"Choose your icon color:","Color Selection") in colors
    if(color_choice) get_icon_color(M,icon_choice,color_choice)

//adds color blend but will be replaced
proc/get_icon_color(mob/M,icon_choice,color_choice)
    var/icon/base_icon = icon(icon_choice)
    var/icon/colored_icon = base_icon
    colored_icon.Blend(color_choice,ICON_MULTIPLY)
    M.icon = colored_icon
    M.selected_color = color_choice