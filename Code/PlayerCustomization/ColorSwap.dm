//In depth list of colors
var/list/color_swatches = list(
		"Red" = rgb(255,0,0),
		"Green" = rgb(0,255,0),
		"Cyan" = rgb(0,255,255),
		"Blue" = rgb(0,0,255),
		"Yellow" = rgb(255,255,0),
		"Orange" = rgb(255,128,0),
		"Magenta" = rgb(255,0,255),
		"Purple" = rgb(128,0,128),
		"White" = rgb(255,255,255),
		"Gray" = rgb(128,128,128),
		"Black" = rgb(0,0,0),
		"Brown" = rgb(88,57,39))

// Apply palette swaps to preview
mob/proc/UpdateAppearance()
    if (!selected_icon || !palette) return

    // Build fresh icon from base
    var/icon/base = new /icon(selected_icon, "world")

    // Apply all palette swaps
    for (var/zone in palette.colors)
        var/original = palette.originalColors[zone]
        var/custom   = palette.colors[zone]
        if(original && custom)
            base.SwapColor(original, custom)

    // Update preview object
    if(preview_obj)
        preview_obj.icon = icon(base)   // duplicate so changes persist
    else
        src.icon = icon(base)



//these verbs bring up the list and allow players to select color
mob/proc/Set_Main()
	var/choice = input(src, "Pick a color") in color_swatches
	var/new_color = color_swatches[choice]
	palette.SetZoneColor("Main", new_color)
	UpdateAppearance()

mob/proc/Set_Accent()
	var/choice = input(src, "Pick a color") in color_swatches
	var/new_color = color_swatches[choice]
	palette.SetZoneColor("Accent", new_color)
	UpdateAppearance()

mob/proc/Set_Hair()
	var/choice = input(src, "Pick a color") in color_swatches
	var/new_color = color_swatches[choice]
	palette.SetZoneColor("Hair", new_color)
	UpdateAppearance()

mob/proc/Set_Eyes()
	var/choice = input(src, "Pick a color") in color_swatches
	var/new_color = color_swatches[choice]
	palette.SetZoneColor("Eyes", new_color)
	UpdateAppearance()

//scan for colors of icons and get rgb value of colors
mob/proc/IsColorUsed(color)
    for(var/zone in palette.colors)
        if(palette.colors[zone] == color)
            return TRUE
    return FALSE