// -----------------------------
// Character Color Customization
// -----------------------------

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

// Repaints the LIVE character-creation preview object (newCharPreview) using the
// current palette. Only meaningful during creation — a loaded/finalized character
// never has newCharPreview/baseIconPreview set, so this is a no-op for them; their
// icon is rebuilt separately by RebuildIcon() in Code/Save/SaveSystem.dm.
mob/proc/UpdateAppearance()
    if(!palette || !newCharPreview || !baseIconPreview)
        return

    // ALWAYS start from pristine base icon
    var/icon/base = icon(baseIconPreview)

    for(var/zone in palette.colors)
        var/original = palette.originalColors[zone]
        var/custom   = palette.colors[zone]
        if(original && custom)
            base.SwapColor(original, custom)

    newCharPreview.icon = base

// Prompts for a color and applies it to the given palette zone ("Main"/"Accent"/
// "Hair"/"Eyes") — was four separate, otherwise-identical Set_Main()/Set_Accent()/
// Set_Eyes()/Set_Hair() procs differing only by that zone name.
mob/proc/SetZoneColorPrompt(zone)
    var/choice = input(src, "Pick a color") in color_swatches
    if(choice)
        palette.SetZoneColor(zone, color_swatches[choice], src)
        UpdateAppearance()   // push change to preview