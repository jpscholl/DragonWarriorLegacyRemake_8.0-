// -----------------------------
// Debug Verbs — gated to Builder+. Visible-to-everyone-but-rejected-on-click, same
// convention every other GM/Debug verb in this codebase uses.
// -----------------------------
mob
	verb
		DebugMovement()
			set category = "Debug"
			if(!usr.RequireBuilder()) return
			usr.ShowInfo("<b>Current Server Stats<b/>")
			usr.ShowInfo("FPS: [world.fps]")
			usr.ShowInfo("Tick Lag: [world.tick_lag]")
			usr.ShowInfo("Step Delay: [step_delay]")
			usr.ShowInfo("Glide Size: [glide_size]")
			usr.ShowInfo("Frames per Step: [round(step_delay / (1 / world.fps))]")

		// Nothing inflicts poison in-game yet (no monster attack, trap, or spell
		// applies it) — this is the only way to trigger it for now.
		Test_PoisonSelf()
			set category = "Debug"
			if(!usr.RequireBuilder()) return
			usr.ApplyStatusEffect(/datum/status_effect/poison)

		FullRestore()
			set category = "Debug"
			if(!usr.RequireBuilder()) return
			usr.HP = usr.MaxHP
			usr.MP = usr.MaxMP
			usr.ShowInfo("Fully restored: [usr.HP]/[usr.MaxHP] HP, [usr.MP]/[usr.MaxMP] MP.")

// Measures the real visible "ink" bounding box of sample glyphs in text.dmi/
// numbers.dmi, pixel by pixel — icon.Width()/Height() report the full 32x32 canvas,
// not the actual drawn character, which is what HUD.dm needs to space characters
// without overlapping. See Markdowns/CodeNotes.md for how this fed HUD_GLYPH_SPACING.
mob
    verb
        Debug_MeasureFont()
            set category = "Debug"
            if(!usr.RequireBuilder()) return

            usr.ShowInfo("<b>--- text.dmi ---</b>")
            for(var/ch in list("l", "e", "0", "8", ":", "%"))
                MeasureGlyph('text.dmi', ch)

            usr.ShowInfo("<b>--- numbers.dmi ---</b>")
            for(var/ch in list("0", "8", "m"))
                MeasureGlyph('numbers.dmi', ch)

// Scans every pixel of one icon_state. Ink = "GetPixel() returned a non-empty
// string" — see Markdowns/CodeNotes.md for why alpha- and near-black-based detection
// both failed first.
mob/proc/MeasureGlyph(fontFile, ch)
    var/icon/I = icon(fontFile, ch)
    var/w = I.Width()
    var/h = I.Height()
    var/minX = w
    var/maxX = -1
    var/minY = h
    var/maxY = -1
    var/list/colorCounts = list()

    for(var/x = 0 to w - 1)
        for(var/y = 0 to h - 1)
            var/pixelColor = I.GetPixel(x, y)
            var/label = length(pixelColor) ? pixelColor : "(blank)"
            colorCounts[label] = (colorCounts[label] ? colorCounts[label] : 0) + 1

            if(length(pixelColor))
                if(x < minX) minX = x
                if(x > maxX) maxX = x
                if(y < minY) minY = y
                if(y > maxY) maxY = y

    // Report the (up to) 4 most common colors seen, with counts.
    var/list/sortedColors = list()
    for(var/c in colorCounts)
        sortedColors += c
    sortedColors = sortByCount(sortedColors, colorCounts)
    var/colorSummary = ""
    for(var/i = 1 to min(4, sortedColors.len))
        var/c = sortedColors[i]
        colorSummary += "[c]x[colorCounts[c]] "

    if(maxX < minX)
        usr.ShowInfo("'[ch]': entirely blank (canvas [w]x[h]) — colors: [colorSummary]")
    else
        usr.ShowInfo("'[ch]': ink box x=[minX]-[maxX] (w=[maxX-minX+1]), y=[minY]-[maxY] (h=[maxY-minY+1]) — canvas [w]x[h] — colors: [colorSummary]")

// Simple descending sort of `keys` by colorCounts[key] — DM has no built-in sort-by-
// custom-key, and this list is at most a few dozen entries, so a plain bubble sort is
// more than fast enough.
mob/proc/sortByCount(list/keys, list/counts)
    var/list/result = keys.Copy()
    for(var/i = 1 to result.len - 1)
        for(var/j = 1 to result.len - i)
            if(counts[result[j]] < counts[result[j + 1]])
                var/tmp = result[j]
                result[j] = result[j + 1]
                result[j + 1] = tmp
    return result

// Prints each color zone's default vs. currently-applied color — handy for checking
// whether an icon actually has DefaultIconColors data wired up.
mob
    verb
        Debug_ShowZoneColors()
            set category = "Debug"
            if(!usr.RequireBuilder()) return
            var/list/zones = list("Hair", "Eyes", "Main", "Accent")

            for(var/zone in zones)
                var/baseColor = palette?.originalColors[zone]
                var/current_color = null
                switch(zone)
                    if("Hair")   current_color = hairColor
                    if("Eyes")   current_color = eyeColor
                    if("Main")   current_color = mainColor
                    if("Accent") current_color = accentColor

                usr.ShowInfo("[zone]: Original=[baseColor]  Current=[current_color]")
