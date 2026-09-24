// -----------------------------
// Character Color Customization
// -----------------------------

// Two-tier palette: 16 color FAMILIES (the 12-hue Red/Yellow/Blue artist color wheel,
// plus Grayscale/Brown/Silver/Gold), most holding 3 SHADES (Light/Base/Dark). Not OG
// data -- purely a remake-side simplification of what used to be one flat 59-entry
// dropdown, so picking a color is "what hue, then how light/dark" instead of scanning
// one long list. Picking a shade applies it immediately and drops back to the family
// list (SetZoneColorPrompt()'s own loop), so comparing two families is just picking
// each in turn rather than a separate confirm step per family.
//
// Tertiary hues (Red-Orange, Yellow-Orange, etc) are named for the two wheel neighbors
// they sit between, standard color-wheel convention. Their Base RGB is a straight
// midpoint of those two neighbors' own Base values EXCEPT Blue-Green, which is a
// hand-picked teal -- the raw midpoint of Green and Blue reads more navy than green
// once you actually look at it, so it is overridden below.
//
// Every hue family's Light/Dark shades follow one formula, not eyeballed per-color:
//     Light = Base + (255 - Base) * 0.55      (per channel)
//     Dark  = Base * 0.45                      (per channel)
// Grayscale is the one exception -- see its own comment below for why it's a flat
// 5-stop ramp instead of that formula.
var/list/color_families = list(
		"Red" = list(
			"Light Red" = rgb(255,140,140),
			"Red"       = rgb(255,0,0),
			"Dark Red"  = rgb(115,0,0)),

		"Red-Orange" = list(
			"Light Red-Orange" = rgb(255,169,140),
			"Red-Orange"       = rgb(255,64,0),
			"Dark Red-Orange"  = rgb(115,29,0)),

		"Orange" = list(
			"Light Orange" = rgb(255,198,140),
			"Orange"       = rgb(255,128,0),
			"Dark Orange"  = rgb(115,58,0)),

		"Yellow-Orange" = list(
			"Light Yellow-Orange" = rgb(255,226,140),
			"Yellow-Orange"       = rgb(255,191,0),
			"Dark Yellow-Orange"  = rgb(115,86,0)),

		"Yellow" = list(
			"Light Yellow" = rgb(255,255,140),
			"Yellow"       = rgb(255,255,0),
			"Dark Yellow"  = rgb(115,115,0)),

		"Yellow-Green" = list(
			"Light Yellow-Green" = rgb(197,229,140),
			"Yellow-Green"       = rgb(127,197,0),
			"Dark Yellow-Green"  = rgb(57,89,0)),

		"Green" = list(
			"Light Green" = rgb(140,203,140),
			"Green"       = rgb(0,140,0),
			"Dark Green"  = rgb(0,63,0)),

		// Hand-picked teal, not the raw Green/Blue midpoint -- see the file header.
		"Blue-Green" = list(
			"Light Blue-Green" = rgb(140,198,198),
			"Blue-Green"       = rgb(0,128,128),
			"Dark Blue-Green"  = rgb(0,58,58)),

		"Blue" = list(
			"Light Blue" = rgb(140,140,255),
			"Blue"       = rgb(0,0,255),
			"Dark Blue"  = rgb(0,0,115)),

		"Blue-Purple" = list(
			"Light Blue-Purple" = rgb(169,140,226),
			"Blue-Purple"       = rgb(64,0,191),
			"Dark Blue-Purple"  = rgb(29,0,86)),

		"Purple" = list(
			"Light Purple" = rgb(198,140,198),
			"Purple"       = rgb(128,0,128),
			"Dark Purple"  = rgb(58,0,58)),

		"Red-Purple" = list(
			"Light Red-Purple" = rgb(226,140,169),
			"Red-Purple"       = rgb(191,0,64),
			"Dark Red-Purple"  = rgb(86,0,29)),

		// White/Gray/Black started as three separate 3-shade families, same as every
		// hue above -- but they're all the same axis (zero saturation), and splitting
		// them up put two DIFFERENT families' shades close enough to be visually
		// indistinguishable (Black's lightest charcoal landed 4 units from Gray's
		// darkest). One evenly-spaced ramp fixes that structurally rather than
		// patching the one collision: 5 stops, 64 units apart, White down to Black.
		// This is also the one family that doesn't hold exactly 3 shades -- the picker
		// code just iterates whatever's here, so that's not a real constraint anywhere.
		"Grayscale" = list(
			"White"      = rgb(255,255,255),
			"Light Gray" = rgb(192,192,192),
			"Gray"       = rgb(128,128,128),
			"Dark Gray"  = rgb(64,64,64),
			"Black"      = rgb(0,0,0)),

		"Brown" = list(
			"Light Brown" = rgb(150,111,80),
			"Brown"       = rgb(88,57,39),
			"Dark Brown"  = rgb(59,38,26)),

		"Silver" = list(
			"Light Silver" = rgb(235,235,240),
			"Silver"       = rgb(210,210,220),
			"Dark Silver"  = rgb(140,140,150)),

		"Gold" = list(
			"Light Gold" = rgb(255,236,140),
			"Gold"       = rgb(255,215,0),
			"Dark Gold"  = rgb(184,134,11)))

// Scans every family/shade for an exact RGB match -- used to preselect the family/shade
// a zone's CURRENT color belongs to when reopening the picker (so it reopens showing
// what is already chosen, not blank), and by MigrateLegacyAppearance() (SaveData.dm) to
// tell a real prior pick apart from an unrelated sampled default. Returns
// list(familyName, shadeName) or null if the color does not match any swatch (e.g.
// still following the art's own default, or a color from before this palette existed).
proc/FindSwatchLocation(color)
	if(!color) return null
	for(var/familyName in color_families)
		var/list/shades = color_families[familyName]
		for(var/shadeName in shades)
			if(shades[shadeName] == color)
				return list(familyName, shadeName)
	return null

// Paints a portrait: for every zone the player explicitly chose a color for, swap that
// zone's as-drawn color for the chosen one. A zone with no chosen color is left
// untouched, so it keeps whatever the art itself says -- that's what lets a repainted
// .dmi reach characters who never customized that zone.
//
// Shared by the creation preview (UpdateAppearance(), below) and the real login repaint
// (RebuildIcon(), SaveSystem.dm) so a character can never look different in the preview
// than they do in the world.
//
// Two passes, not one straight swap per zone: a chosen color can equal ANOTHER zone's
// as-drawn color (pick White for Main on a sprite whose Accent is drawn white), and a
// one-pass swap would then let Accent's later swap grab the just-painted Main pixels
// too. Pass 1 parks every overridden zone on its own placeholder color, pass 2 paints
// the placeholders, so no zone's swap can ever see another zone's result.
proc/ApplyZoneColors(icon/target, datum/PlayerIcon/entry, list/overrides)
    if(!target || !entry || !overrides)
        return

    // Placeholder -> chosen color. rgb(1,2,n) is near-black, which no player portrait
    // or palette swatch uses.
    var/list/parked = list()
    for(var/zone in overrides)
        var/baseColor = entry.zoneDefaults[zone]
        var/newColor  = overrides[zone]
        if(baseColor && newColor)
            var/placeholder = rgb(1, 2, parked.len + 1)
            target.SwapColor(baseColor, placeholder)
            parked[placeholder] = newColor

    for(var/placeholder in parked)
        target.SwapColor(placeholder, parked[placeholder])

// Repaints the LIVE character-creation preview object (newCharPreview) using the
// current palette. Only meaningful during creation -- a loaded/finalized character
// never has newCharPreview/baseIconPreview set, so this is a no-op for them; their
// icon is rebuilt separately by RebuildIcon() in Code/Save/SaveSystem.dm.
mob/proc/UpdateAppearance()
    if(!palette || !newCharPreview || !baseIconPreview)
        return

    // ALWAYS start from pristine base icon
    var/icon/base = icon(baseIconPreview)
    ApplyZoneColors(base, palette.entry, palette.overrides)

    newCharPreview.icon = base

// Top-level picker for one zone: a list of the 16 color FAMILIES. Picking one opens
// PickShadeForFamily() below; picking a shade there applies it and drops straight back
// to this same family list, so switching families to compare is just picking each in
// turn. Stays open until the player explicitly Confirms or Cancels -- Cancel reverts to
// whatever this zone was when the menu was entered (a previously-confirmed custom
// color, or back to following the art if there wasn't one).
mob/proc/SetZoneColorPrompt(zone)
    var/revertColor = palette.GetZoneColor(zone)   // null = currently following the art

    var/list/familyOptions = list()
    for(var/familyName in color_families)
        familyOptions += familyName
    familyOptions += list("Default Color", "Confirm", "Cancel")

    while(TRUE)
        // Re-highlights whichever family the zone's CURRENT color belongs to, so
        // reopening the menu (after picking a shade) shows where you already are
        // instead of resetting to the top of the list every time.
        var/list/loc = FindSwatchLocation(palette.GetZoneColor(zone))
        var/lastFamily = loc ? loc[1] : null

        var/choice = input(src, "Pick a color family for [zone]", "Color Customization: [zone]", lastFamily) in familyOptions

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
            else
                PickShadeForFamily(zone, choice)
                // Falls through -- loop re-shows the family list above.

// Shade sub-list for one family (Light/Base/Dark). Picking a shade applies it and
// previews live, then returns immediately -- SetZoneColorPrompt()'s own loop is what
// shows the family list again, not this proc.
mob/proc/PickShadeForFamily(zone, familyName)
    var/list/shades = color_families[familyName]

    var/list/loc = FindSwatchLocation(palette.GetZoneColor(zone))
    var/lastShade = (loc && loc[1] == familyName) ? loc[2] : null

    var/list/options = list()
    for(var/shadeName in shades)
        options += shadeName
    options += "Back"

    var/choice = input(src, "Pick a shade of [familyName] for [zone]", "Color Customization: [zone]", lastShade) in options
    if(choice && choice != "Back")
        palette.SetZoneColor(zone, shades[choice], src)
        UpdateAppearance()
