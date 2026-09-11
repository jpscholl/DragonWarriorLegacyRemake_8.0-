// -----------------------------
// Debug Verbs — gated to Builder+. Visible-to-everyone-but-rejected-on-click, same
// convention every other GM/Debug verb in this codebase uses.
// -----------------------------
mob
	verb
		DebugMovement()
			set category = "Debug"
			if(!usr.RequireBuilder()) return
			if(!usr.RequireCanAct()) return
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
			if(!usr.RequireCanAct()) return
			usr.ApplyStatusEffect(/datum/status_effect/poison)

		FullRestore()
			set category = "Debug"
			if(!usr.RequireBuilder()) return
			if(!usr.RequireCanAct()) return
			usr.HP = usr.MaxHP
			usr.MP = usr.MaxMP
			usr.ShowInfo("Fully restored: [usr.HP]/[usr.MaxHP] HP, [usr.MP]/[usr.MaxMP] MP.")

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

// Samples a chosen class icon's raw "world" pixel data directly via GetPixel() and
// reports every distinct color found, most-common first. This is the actual tool for
// figuring out what colors to hand-author into an icon's zoneDefaults
// (PlayerIconColorPalette.dm) for art that doesn't have zones wired up yet — reading a
// character's own colors back (the old version of this verb) is useless for that: those
// only ever reflect colors ALREADY wired up, never new ones. Reuses GetClassIcons()
// (LoginMenu.dm) so every icon already in character creation is pickable here without
// needing to actually be wearing it first.
mob
    verb
        Debug_ShowZoneColors()
            set category = "Debug"
            if(!usr.RequireBuilder()) return
            if(!usr.RequireCanAct()) return

            var/list/classes = list("Hero", "Soldier", "Wizard", "Fighter", "Pilgrim", "Goof-off", "Sage")
            var/pickedClass = input(usr, "Which class's icon?", "Debug_ShowZoneColors") in classes
            if(!pickedClass) return

            var/list/iconChoices = GetClassIcons(usr, pickedClass)
            iconChoices -= "Back"
            var/pickedLabel = input(usr, "Which icon?", "Debug_ShowZoneColors") in iconChoices
            if(!pickedLabel) return

            var/iconFile = iconChoices[pickedLabel]
            var/icon/I = icon(iconFile, "world")
            var/w = I.Width()
            var/h = I.Height()
            var/list/colorCounts = list()

            for(var/x = 0 to w - 1)
                for(var/y = 0 to h - 1)
                    var/pixelColor = I.GetPixel(x, y)
                    if(!length(pixelColor)) continue  // skip transparent
                    colorCounts[pixelColor] = (colorCounts[pixelColor] ? colorCounts[pixelColor] : 0) + 1

            var/list/sortedColors = list()
            for(var/c in colorCounts)
                sortedColors += c
            sortedColors = sortByCount(sortedColors, colorCounts)

            usr.ShowInfo("<b>[pickedLabel] ([iconFile]) — [sortedColors.len] distinct colors:</b>")
            for(var/c in sortedColors)
                usr.ShowInfo("[HexToRGBString(c)]  x[colorCounts[c]]")

// GetPixel() returns "#rrggbb" (or "#rrggbbaa") — zoneDefaults (PlayerIconColorPalette.dm)
// entries are written as rgb(r,g,b) literals, so this converts to that exact format,
// copy-pasteable straight into an icon's zoneDefaults with no manual hex math.
mob/proc/HexToRGBString(hex)
    var/r = text2num(copytext(hex, 2, 4), 16)
    var/g = text2num(copytext(hex, 4, 6), 16)
    var/b = text2num(copytext(hex, 6, 8), 16)
    return "rgb([r],[g],[b])"
