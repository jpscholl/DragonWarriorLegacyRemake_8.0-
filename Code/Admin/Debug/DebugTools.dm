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

// -----------------------------
// Skill FX audit — which skills have art, which don't, and what art nothing claims
// -----------------------------
// The counterpart to Debug_ShowZoneColors() above, for the spells.dmi side. Every skill
// names its effect art in fx_state (SkillCatalog.dm) and ResolveSkillFXState()
// (SkillFX.dm) draws nothing when that state doesn't exist, which is deliberate but
// means a typo or a wrong guess is invisible in play — it just silently looks like a
// plain swing. This prints the whole mapping so it can be checked without hunting.
//
// The UNCLAIMED list is the useful half in the other direction: spells.dmi holds art
// for things the skill roster doesn't cover at all, which is a list of skills that could
// exist.
mob
    verb
        Debug_SkillFXReport()
            set category = "Debug"
            if(!usr.RequireBuilder()) return

            var/list/states = GetCachedIconStates(SKILL_FX_FILE)
            var/list/wired = list()
            var/list/missing = list()
            var/list/claimed = list()
            var/unnamed = 0

            for(var/skillType in typesof(/datum/skill))
                var/fxState = initial(skillType:fx_state)
                var/sName = initial(skillType:skillName)
                if(!fxState)
                    unnamed++
                    continue

                var/resolved = ResolveSkillFXState(fxState)
                if(resolved)
                    wired += "[sName] — [fxState] &rarr; [resolved]"
                    claimed[resolved] = TRUE
                    // Record the variant siblings too, so a skill using the handed or
                    // directional form doesn't leave its partners looking unclaimed.
                    for(var/variant in list("[fxState]", "left[fxState]", "right[fxState]", "[fxState]ns", "[fxState]ew"))
                        if(variant in states) claimed[variant] = TRUE
                else
                    missing += "[sName] — [fxState]"

                var/impactState = initial(skillType:impact_fx_state)
                if(impactState)
                    var/resolvedImpact = ResolveSkillFXState(impactState)
                    if(resolvedImpact) claimed[resolvedImpact] = TRUE
                    else missing += "[sName] (impact) — [impactState]"

            usr.ShowInfo("<b>Skill FX report — [states.len] states in spells.dmi</b>")

            usr.ShowInfo("<b>Wired ([wired.len]):</b>")
            for(var/line in wired)
                usr.ShowInfo(line)

            usr.ShowInfo("<b>Named but no art yet ([missing.len]):</b>")
            for(var/line in missing)
                usr.ShowInfo(line)

            var/list/unclaimed = list()
            for(var/s in states)
                if(!claimed[s]) unclaimed += s
            usr.ShowInfo("<b>Art nothing claims ([unclaimed.len]):</b> [jointext(unclaimed, ", ")]")
            usr.ShowInfo("Skills with no fx_state at all: [unnamed]")

        // obj/hazard_field (HazardFields.dm) is only reachable in play by casting
        // Explodet, which needs the level and MP for it. This drops the same flame blob
        // at your feet so the field, its expiry, and the burn it applies can be tested
        // directly. Unowned, so it burns whoever stands in it — including you.
        Test_SpawnFlame()
            set category = "Debug"
            if(!usr.RequireBuilder()) return
            if(!usr.RequireCanAct()) return

            var/placed = SpawnHazardBlob(usr.loc, /obj/hazard_field/flame, 1, null, 20, "fire", 80)
            usr.ShowInfo("Spawned [placed] flame tile(s). Stand in one to take burn damage.")

        // Lays out training dummies for testing Quakejump: one on the tile in front of
        // you (where a plain Quakejump lands) and one on every tile around it except the
        // one you're standing on -- 8 in all, so a single landing hits and shoves the
        // whole ring. Occupied/blocked tiles are skipped. Leave room behind the ring,
        // or the shoves have nowhere to go.
        Test_SpawnDummyRing()
            set category = "Debug"
            if(!usr.RequireBuilder()) return
            if(!usr.RequireCanAct()) return

            var/turf/center = get_step(usr, usr.dir)
            if(!center)
                usr.ShowInfo("No room in front of you.")
                return
            var/placed = 0
            for(var/turf/T in list(center) + GetRingTurfs(center))
                if(T == usr.loc || IsTileOccupied(T)) continue
                new /mob/enemy/training_dummy(T)
                placed++
            usr.ShowInfo("Spawned [placed] training dummies. Test_ClearDummies removes them.")

        // Learns any skill regardless of class, level or stats, into the Free Skills
        // list -- for testing skills no class unlocks yet (Zap). Not saved; relog clears.
        Test_LearnSkill()
            set category = "Debug"
            if(!usr.RequireBuilder()) return
            var/mob/player/P = usr
            if(!istype(P)) return

            var/list/choices = list()
            for(var/T in typesof(/datum/skill) - /datum/skill)
                var/datum/skill/S = T
                var/name = initial(S.skillName)
                if(name == "Unnamed Skill") continue  // abstract bases (GenericSpell, BoltSword...)
                if(P.HasSkillType(T)) continue
                choices[name] = T
            if(!choices.len)
                P.ShowInfo("You already know every skill.")
                return

            var/pick = input(P, "Learn which skill?", "Test_LearnSkill") as null|anything in choices
            if(!pick) return
            P.EquipSkill(choices[pick])
            P.ShowInfo("Learned [pick]. Equip it from Free Skills.")

        Test_ClearDummies()
            set category = "Debug"
            if(!usr.RequireBuilder()) return
            var/removed = 0
            for(var/mob/enemy/training_dummy/D in world)
                del D
                removed++
            usr.ShowInfo("Removed [removed] training dummies.")

// The 8 tiles around T (null edges of the map dropped).
proc/GetRingTurfs(turf/T)
    var/list/ring = list()
    for(var/d in list(NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST))
        var/turf/R = get_step(T, d)
        if(R) ring += R
    return ring

// A punching bag for testing skills (Quakejump's shove especially) against something
// that survives more than one hit. Never acts on its own -- no AI at all, so it can't
// wander off, chase, flee or fight back; it only moves when something shoves it. Never
// dodges (0 Agility), shrugs off nothing (0 Vitality), and pays out nothing, so it
// can't be farmed. Also spawnable from GM_MakeMob.
mob/enemy/training_dummy
    name = "Training Dummy"
    icon = 'slime.dmi'
    icon_state = "world"
    Level = 1
    HP = 99999
    MaxHP = 99999
    Strength = 0
    Agility = 0
    Vitality = 0
    Intelligence = 0
    Spirit = 0
    expReward = 0
    goldReward = 0
    fleeHealthPercent = 0
    wanderChance = 0

    RunWildAI()
        return  // no brain -- stays exactly where it's put (or shoved)

// GetPixel() returns "#rrggbb" (or "#rrggbbaa") — zoneDefaults (PlayerIconColorPalette.dm)
// entries are written as rgb(r,g,b) literals, so this converts to that exact format,
// copy-pasteable straight into an icon's zoneDefaults with no manual hex math.
mob/proc/HexToRGBString(hex)
    var/r = text2num(copytext(hex, 2, 4), 16)
    var/g = text2num(copytext(hex, 4, 6), 16)
    var/b = text2num(copytext(hex, 6, 8), 16)
    return "rgb([r],[g],[b])"
