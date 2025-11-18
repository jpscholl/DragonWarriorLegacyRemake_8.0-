//stores current base icon
mob
	var/selectedIcon
	var/selectedClass

//checks the colors of the current icon
mob/verb/checkIcon()
    if(!selectedClass || !selectedIcon)
        usr << "No icon selected."
        return

    var/list/colors = baseIconColors[selectedClass][selectedIcon]
    if(!islist(colors))
        usr << "No color data found for [selectedIcon]"
        return

    for(var/zone in colors)
        var/color = colors[zone]
        usr << "[zone]: [color]"


//change icons
mob/verb/chooseIcon()
    var/list/classChoices = list()
    for(var/class in baseIconColors)
        classChoices += class

    var/classChoice = input("Choose your class:") in classChoices
    if(!classChoice)
        return
    selectedClass = classChoice

    var/list/iconChoices = list()
    for(var/icon_id in baseIconColors[selectedClass])
        iconChoices += icon_id

    var/iconChoice = input("Choose your icon:") in iconChoices
    if(!iconChoice)
        return
    selectedIcon = iconChoice

    src.palette = new /datum/PaletteManager(selectedClass, selectedIcon)

    src.icon = icon(selectedIcon)
    usr << "Your icon has been changed to [selectedClass] → [selectedIcon]."

//change icon states for testing
mob/verb/world_state()
	set name = "S_Normal"
	set category = "Icon States"
	src.icon_state = "world"

mob/verb/attack_state()
	set name = "S_Attack"
	set category = "Icon States"
	src.icon_state = "attack"

mob/verb/sleep_state()
	set name = "S_Sleep"
	set category = "Icon States"
	src.icon_state = "sleep"

mob/verb/defend_state()
	set name = "S_Defend"
	set category = "Icon States"
	src.icon_state = "defend"

mob/verb/reset_icon()
	set name = "Reset Icon"
	set category = "Reset"
	src.icon = icon(selectedIcon, "world")

mob/verb/checkPalette()
    if(!src.palette)
        src << "No palette assigned."
        return

    var/list/zones = src.palette.GetAllZones()
    for(var/zone in zones)
        src << "[zone]: [zones[zone]]"
