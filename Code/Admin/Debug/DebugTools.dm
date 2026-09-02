// -----------------------------
// Debug Verbs
// -----------------------------
// Gated to Builder+ (TODOList.md Phase 9: "currently unrestricted, no permission check
// at all — worth gating... before this is ever run on a shared server"). Visible-to-
// everyone-but-rejected-on-click, same convention every other GM/Debug verb in this
// codebase already uses (GMtogglelog is the sole exception that's actually hidden from
// the verb list — see its own comment in GMCommands.dm) — not retrofitting that here,
// just closing the "anyone can click it" gap.
mob
	verb
		DebugMovement()
			set category = "Debug"
			if(!usr.client || !usr.client.canBuild)
				usr.ShowInfo("You don't have Builder access.")
				return
			usr.ShowInfo("<b>Current Server Stats<b/>")
			usr.ShowInfo("FPS: [world.fps]")
			usr.ShowInfo("Tick Lag: [world.tick_lag]")
			usr.ShowInfo("Step Delay: [step_delay]")
			usr.ShowInfo("Glide Size: [glide_size]")
			usr.ShowInfo("Frames per Step: [round(step_delay / (1 / world.fps))]")

		// Nothing inflicts poison in-game yet (no monster attack, trap, or spell
		// applies it) — this is the only way to trigger it for now. See
		// Code/Combat/StatusEffects.dm.
		Test_PoisonSelf()
			set category = "Debug"
			if(!usr.client || !usr.client.canBuild)
				usr.ShowInfo("You don't have Builder access.")
				return
			usr.ApplyStatusEffect(/datum/status_effect/poison)

		// Tops HP/MP back up to max, for testing (e.g. after taking hits, or
		// spending mana on Blaze).
		FullRestore()
			set category = "Debug"
			if(!usr.client || !usr.client.canBuild)
				usr.ShowInfo("You don't have Builder access.")
				return
			usr.HP = usr.MaxHP
			usr.MP = usr.MaxMP
			usr.ShowInfo("Fully restored: [usr.HP]/[usr.MaxHP] HP, [usr.MP]/[usr.MaxMP] MP.")

// Measures the real visible "ink" bounding box of a handful of sample glyphs in
// text.dmi/numbers.dmi, pixel by pixel — added 2026-08-29 because icon.Width()/
// Height() report the full icon canvas (32x32, matching the whole project's
// icon_size), not the actual drawn character inside it, which is what Code/UI/HUD.dm
// actually needs to space characters without overlapping. Two guesses at that spacing
// already failed (too narrow, then too wide) before resorting to this — real
// measurement beats a third guess. Report the output back so HUD_GLYPH_SPACING/
// HUD_ROW_TOP/HUD_ROW_BOTTOM (HUD.dm) can be set from real numbers instead.
mob
    verb
        Debug_MeasureFont()
            set category = "Debug"
            if(!usr.client || !usr.client.canBuild)
                usr.ShowInfo("You don't have Builder access.")
                return

            usr.ShowInfo("<b>--- text.dmi ---</b>")
            for(var/ch in list("l", "e", "0", "8", ":", "%"))
                MeasureGlyph('text.dmi', ch)

            usr.ShowInfo("<b>--- numbers.dmi ---</b>")
            for(var/ch in list("0", "8", "m"))
                MeasureGlyph('numbers.dmi', ch)

// Scans every pixel of one icon_state. Two failed attempts before this: alpha-based
// detection (this icon format reports every pixel fully opaque, no usable alpha at
// all) and a near-black color check (transparent pixels turned out to report as an
// EMPTY STRING from GetPixel(), not a color — text2num("") comes back 0, so "R/G/B all
// under 60" accidentally matched blank pixels too, same bug as the alpha attempt in a
// new shape). CONFIRMED 2026-08-29 via the color tally this proc already printed:
// e.g. 'l' was 940 blank pixels + 84 real #000000 pixels, adding up to the full 1024
// (32x32) — blank IS the transparent background, a real color is ink, no darkness
// threshold needed at all. Ink = "GetPixel() returned a non-empty string," full stop.
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
// custom-key, and this list is at most a few dozen entries (one 32x32 glyph's worth of
// distinct colors), so a plain bubble sort is more than fast enough.
mob/proc/sortByCount(list/keys, list/counts)
    var/list/result = keys.Copy()
    for(var/i = 1 to result.len - 1)
        for(var/j = 1 to result.len - i)
            if(counts[result[j]] < counts[result[j + 1]])
                var/tmp = result[j]
                result[j] = result[j + 1]
                result[j + 1] = tmp
    return result

// Prints each color zone's default vs. currently-applied color — handy for
// checking whether an icon actually has DefaultIconColors data wired up.
mob
    verb
        Debug_ShowZoneColors()
            set category = "Debug"
            if(!usr.client || !usr.client.canBuild)
                usr.ShowInfo("You don't have Builder access.")
                return
            // Zones to check
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
