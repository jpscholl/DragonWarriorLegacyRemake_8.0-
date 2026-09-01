//for music transitions...or skipping them
mob/var
		current_music = null

// Plays background music for this mob if it isn't already playing, used by
// area/Entered() below so area subtypes only need to set their areaMusic var.
mob/proc/PlayAreaMusic(music_file)
	if(!client) return
	if(current_music == music_file) return
	client << sound(music_file, repeat = 1, volume = client.ScaledVolume(isMusic = TRUE), channel = 1)
	current_music = music_file

area
	icon = 'environment.dmi'
	var/areaMusic   // set on a subtype to auto-play music when a mob enters

	// Scaffolding for the GM_BattleMode/GM_CoopMode/GM_IndestructibleMode/GM_Weather GM
	// verbs -- each toggles one of these per specific area instance, not globally.
	// GM_BattleMode (GMCommands.dm) can still flip battleModeOn at runtime per instance;
	// this is just each type's starting value on compile.
	var/battleModeOn = FALSE       // FALSE = peaceful area, no attacks/skills allowed --
	                                // overridden TRUE below on battle/dungeon/boss/temple
	var/battleAllowsPvP = FALSE    // TRUE = players can hurt each other here (OG: only the Arena defaults TRUE -- which area that maps to isn't confirmed yet)
	var/indestructibleMode = TRUE  // FALSE = fire/ice attacks damage terrain here
	var/weather = null             // GM-set weather state, outside areas only

	Entered(atom/movable/O)
		..()
		if(areaMusic && ismob(O))
			var/mob/M = O
			M.PlayAreaMusic(areaMusic)

	casino
		icon_state = "casino"

	dungeon
		icon_state = "dungeon"
		battleModeOn = TRUE

	boss
		icon_state = "boss"
		battleModeOn = TRUE

	forest
		icon_state = "forest"

	townrain
		icon_state = "townrain"
		areaMusic = 'dw4town.mid'

	town
		icon_state = "town"
		areaMusic = 'dw4town.mid'

	battle
		icon_state = "battle"
		battleModeOn = TRUE
		areaMusic = 'dq5battle.mid'

	castle
		icon_state = "castle"
		areaMusic = 'Dw4cast.mid'

	cave
		icon_state = "cave"
		areaMusic = 'cave.mid'

	old
		icon_state = "old"

	snow
		icon_state = "snow"

	snownight
		icon_state = "snownight"

	bar
		icon_state = "bar"
		areaMusic = 'dw3town.mid'

		Exited(atom/movable/O)
			..()
			if(ismob(O))
				var/mob/M = O
				if(M.client)
					M.client << sound(null, channel = 1)

	jail
		icon_state = "jail"

	rain
		icon_state = "rain"

	rainnight
		icon_state = "rainnight"

	ceiling
		icon_state = "ceiling"
		var
			has_ceiling = 1

		Entered(mob/M) //when you enter the house you will not see the roof any more
			if(ismob(M)) //if your a mob
				M.see_invisible = 0 //keep these variables here or this will not work

		Exited(mob/M) //when you exit the house you will see the roof
			if(ismob(M)) //if your a mob
				M.see_invisible = 1 //keep these variables here or this will not work

	visible
		icon_state = "visible"

	wilderness
		icon_state = "wilderness"

	temple
		icon_state = "temple"
		battleModeOn = TRUE

	deepwater1
		icon_state = "deepwater1"

	deepwaternight1
		icon_state = "deepwaternight1"

	deepwater
		icon_state = "deepwater"

	deepwaternight
		icon_state = "deepwaternight"

	water1
		icon_state = "water1"

	waternight1
		icon_state = "waternight1"

	water
		icon_state = "water"

	waternight
		icon_state = "waternight"

	rave
		icon_state = "rave"
		areaMusic = 'jellyfish jam.mid'


// -----------------------------
// World spawn markers — confirmed OG names "playerstart" (login) / "playerspawn"
// (after-death respawn), confirmed distinct from each other (GMCommandsReference.md's
// Builder tier section: GMseeareas shows login spawns and death/respawn spawns as
// separately-marked types). Built as plain OBJECTS, not areas — a turf only ever
// belongs to ONE area, so an area-based marker painted onto an existing Town/Dungeon/
// etc. tile would silently strip that tile of its real area's music/battle-mode/
// everything else. An object sitting on top of a tile doesn't touch its area at all.
// Also matches the OG closer than an area would have: GMmakestat (the OG's stat-object
// placement tool) lists both of these among its stat types, not among area types.
//
// invisibility this high keeps them unseen by every normal client regardless of
// indoor/outdoor see_invisible swings (area/ceiling's Entered()/Exited() above only
// ever sets 0 or 1) — "can only be seen as an area for GMs" means GM_SeeAreas'
// overlay specifically, not merely being a GM; nothing renders these directly, ever.
#define SPAWN_MARKER_INVISIBILITY 100

obj/spawnMarker
	density = 0
	invisibility = SPAWN_MARKER_INVISIBILITY

	playerStart
		icon = 'door.dmi'
		icon_state = "wooden"

	playerSpawn
		icon = 'sign.dmi'
		icon_state = "church"

// Finds a random tile with a marker of the given type on it — lets a host building
// their own map just place the marker wherever they want (playerStart for the world
// login point, playerSpawn for after-death respawn) instead of a hardcoded coordinate
// baked into the code. Multiple markers of the same type are all pooled together so a
// host can lay down more than one without extra work. Falls back to PLAYER_SPAWN (the
// old hardcoded coordinate, .dme) with a log line if the map has no such marker at
// all yet, so a map that hasn't been updated for this system (or is just missing the
// marker by mistake) doesn't strand a spawning/respawning player.
proc/FindSpawnTurf(markerType, markerLabel)
	var/list/candidates = list()
	for(var/obj/spawnMarker/M in world)
		if(!istype(M, markerType)) continue
		if(M.loc) candidates += M.loc

	if(candidates.len) return pick(candidates)

	world.log << "WARNING: no [markerLabel] marker found on this map — falling back to PLAYER_SPAWN."
	return PLAYER_SPAWN

// World login point — character creation (FinalizePlayer(), LoginMenu.dm), character
// load (LoadCharacter(), SaveSystem.dm), and the Return spell (SkillCatalog.dm) all
// use this same spot.
proc/GetPlayerSpawnTurf()
	return FindSpawnTurf(/obj/spawnMarker/playerStart, "playerStart (world login point)")

// After-death respawn — Respawn verb (PlayerVerbs.dm) only. Deliberately separate
// from GetPlayerSpawnTurf() above: confirmed OG design ("playerspawn", distinct from
// "playerstart") uses a different marker (church sign vs. wooden door) for this, not
// the same spot as the world login point.
proc/GetRespawnTurf()
	return FindSpawnTurf(/obj/spawnMarker/playerSpawn, "playerSpawn (after-death respawn)")
