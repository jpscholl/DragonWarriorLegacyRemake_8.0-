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

var/tmp/appearance_updating = FALSE

mob/proc/UpdateAppearance()
    if(!palette || !preview_obj || !base_preview_icon)
        return

    // ALWAYS start from pristine base icon
    var/icon/base = icon(base_preview_icon)

    for(var/zone in palette.colors)
        var/original = palette.originalColors[zone]
        var/custom   = palette.colors[zone]
        if(original && custom)
            base.SwapColor(original, custom)

    preview_obj.icon = base

//these verbs bring up the list and allow players to select color
mob/proc/Set_Main()
    var/choice = input(src, "Pick a color") in color_swatches
    if(choice)
        palette.SetZoneColor("Main", color_swatches[choice])
        UpdateAppearance()   // push change to preview

mob/proc/Set_Accent()
    var/choice = input(src, "Pick a color") in color_swatches
    if(choice)
        palette.SetZoneColor("Accent", color_swatches[choice])
        UpdateAppearance()   // push change to preview

mob/proc/Set_Eyes()
    var/choice = input(src, "Pick a color") in color_swatches
    if(choice)
        palette.SetZoneColor("Eyes", color_swatches[choice])
        UpdateAppearance()   // push change to preview

mob/proc/Set_Hair()
    var/choice = input(src, "Pick a color") in color_swatches
    if(choice)
        palette.SetZoneColor("Hair", color_swatches[choice])
        UpdateAppearance()   // push change to preview

//scan for colors of icons and get rgb value of colors
mob/proc/IsColorUsed(color)
    for(var/zone in palette.colors)
        if(palette.colors[zone] == color)
            return TRUE
    return FALSE