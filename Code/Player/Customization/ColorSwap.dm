// -----------------------------
// Character Color Customization
// -----------------------------

//In depth list of colors
var/list/color_swatches = list(
		"Red" = rgb(255,0,0),
		"Light Red" = rgb(255,102,102),
		"Dark Red" = rgb(139,0,0),

		"Green" = rgb(0,140,0),
		"Light Green" = rgb(144,238,144),
		"Dark Green" = rgb(0,80,0),

		"Cyan" = rgb(0,255,255),
		"Light Cyan" = rgb(153,255,255),
		"Dark Cyan" = rgb(0,139,139),

		"Blue" = rgb(0,0,255),
		"Light Blue" = rgb(135,206,250),
		"Dark Blue" = rgb(0,0,139),

		"Yellow" = rgb(255,255,0),
		"Light Yellow" = rgb(255,255,153),
		"Dark Yellow" = rgb(204,204,0),

		"Orange" = rgb(255,128,0),
		"Light Orange" = rgb(255,178,102),
		"Dark Orange" = rgb(204,85,0),

		"Magenta" = rgb(255,0,255),
		"Light Magenta" = rgb(255,153,255),
		"Dark Magenta" = rgb(139,0,139),

		"Purple" = rgb(128,0,128),
		"Light Purple" = rgb(186,85,211),
		"Dark Purple" = rgb(75,0,130),

		"White" = rgb(255,255,255),
		"Dark White" = rgb(224,224,224),

		"Gray" = rgb(128,128,128),
		"Light Gray" = rgb(192,192,192),
		"Dark Gray" = rgb(64,64,64),

		"Black" = rgb(0,0,0),
		"Light Black" = rgb(40,40,40),

		"Brown" = rgb(88,57,39),
		"Light Brown" = rgb(150,111,80),
		"Dark Brown" = rgb(59,38,26),

		"Pink" = rgb(255,175,200),
		"Light Pink" = rgb(255,214,228),
		"Dark Pink" = rgb(199,90,130),

		"Teal" = rgb(0,128,128),
		"Light Teal" = rgb(102,205,205),
		"Dark Teal" = rgb(0,77,77),

		"Navy" = rgb(0,0,128),
		"Light Navy" = rgb(70,70,160),
		"Dark Navy" = rgb(0,0,80),

		"Maroon" = rgb(128,0,32),
		"Light Maroon" = rgb(176,82,109),
		"Dark Maroon" = rgb(80,0,20),

		"Tan" = rgb(210,180,140),
		"Light Tan" = rgb(235,216,190),
		"Dark Tan" = rgb(150,121,90),

		"Gold" = rgb(255,215,0),
		"Light Gold" = rgb(255,236,140),
		"Dark Gold" = rgb(184,134,11),

		"Silver" = rgb(210,210,220),
		"Light Silver" = rgb(235,235,240),
		"Dark Silver" = rgb(140,140,150))

// Paints a portrait: for every zone the player explicitly chose a color for, swap that
// zone's as-drawn color for the chosen one. A zone with no chosen color is left
// untouched, so it keeps whatever the art itself says — that's what lets a repainted
// .dmi reach characters who never customized that zone.
//
// Shared by the creation preview (UpdateAppearance(), below) and the real login repaint
// (RebuildIcon(), SaveSystem.dm) so a character can never look different in the preview
// than they do in the world.
proc/ApplyZoneColors(icon/target, datum/PlayerIcon/entry, list/overrides)
    if(!target || !entry || !overrides)
        return

    for(var/zone in overrides)
        var/baseColor = entry.zoneDefaults[zone]
        var/newColor  = overrides[zone]
        if(baseColor && newColor)
            target.SwapColor(baseColor, newColor)

// Repaints the LIVE character-creation preview object (newCharPreview) using the
// current palette. Only meaningful during creation — a loaded/finalized character
// never has newCharPreview/baseIconPreview set, so this is a no-op for them; their
// icon is rebuilt separately by RebuildIcon() in Code/Save/SaveSystem.dm.
mob/proc/UpdateAppearance()
    if(!palette || !newCharPreview || !baseIconPreview)
        return

    // ALWAYS start from pristine base icon
    var/icon/base = icon(baseIconPreview)
    ApplyZoneColors(base, palette.entry, palette.overrides)

    newCharPreview.icon = base

// Prompts for a color and applies it to the given palette zone — whichever zones this
// icon declares (PlayerIconColorPalette.dm), commonly Main/Accent/Hair/Eyes. Was four
// separate, otherwise-identical Set_Main()/Set_Accent()/Set_Eyes()/Set_Hair() procs
// differing only by that zone name.
//
// Stays on this zone (previewing each pick live) until the player explicitly
// confirms or cancels, instead of returning to the zone-select menu after a
// single pick. Cancel reverts to whatever this zone was when the menu was
// entered — a previously-confirmed custom color if there is one, otherwise back
// to following the art.
mob/proc/SetZoneColorPrompt(zone)
    var/revertColor = palette.GetZoneColor(zone)   // null = currently following the art

    var/list/options = list()
    for(var/swatchName in color_swatches)
        options += swatchName
    options += list("Default Color", "Confirm", "Cancel")

    // Re-highlights whichever swatch matches the color currently previewing —
    // same lastStat/defaultLabel idea as StatAllocation() (LoginMenu.dm), one
    // level deeper. A zone still following the art has no color of its own to
    // match, so this stays null and the dialog just opens with nothing
    // pre-highlighted.
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
                // Clears the override instead of storing the default's current color,
                // so this zone goes back to tracking the art rather than freezing at
                // whatever the default happens to be today.
                palette.SetZoneColor(zone, null, src)
                UpdateAppearance()
                lastSwatch = null
            else
                palette.SetZoneColor(zone, color_swatches[choice], src)
                UpdateAppearance()
                lastSwatch = choice