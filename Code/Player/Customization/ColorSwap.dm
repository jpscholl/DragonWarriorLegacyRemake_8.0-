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
//
// Stays on this zone (previewing each pick live) until the player explicitly
// confirms or cancels, instead of returning to the zone-select menu after a
// single pick. Cancel reverts to whatever this zone's color was when the menu
// was entered — a previously-confirmed custom color if there is one, the class
// default otherwise — not necessarily the icon's default.
mob/proc/SetZoneColorPrompt(zone)
    var/revertColor = palette.GetZoneColor(zone)
    var/defaultColor = palette.originalColors[zone]

    var/list/options = list()
    for(var/swatchName in color_swatches)
        options += swatchName
    options += list("Default Color", "Confirm", "Cancel")

    // Re-highlights whichever swatch matches the color currently previewing —
    // same lastStat/defaultLabel idea as StatAllocation() (LoginMenu.dm), one
    // level deeper. Only meaningful if the current color happens to BE one of
    // the named swatches; a color reached via "Default Color" (or a save file
    // predating color_swatches) usually won't match any name, so this stays
    // null and the dialog just opens with nothing pre-highlighted.
    var/lastSwatch = null
    for(var/swatchName in color_swatches)
        if(color_swatches[swatchName] == palette.GetZoneColor(zone))
            lastSwatch = swatchName
            break

    while(TRUE)
        var/choice = input(src, "Pick a color for [zone]", "Color Customization: [zone]", lastSwatch) in options

        switch(choice)
            if("Confirm")
                return
            if("Cancel", null) // closing the dialog (no choice) behaves like Cancel
                palette.SetZoneColor(zone, revertColor, src)
                UpdateAppearance()
                return
            if("Default Color")
                palette.SetZoneColor(zone, defaultColor, src)
                UpdateAppearance()
                lastSwatch = null
            else
                palette.SetZoneColor(zone, color_swatches[choice], src)
                UpdateAppearance()
                lastSwatch = choice