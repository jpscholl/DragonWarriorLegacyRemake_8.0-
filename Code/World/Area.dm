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

	// Scaffolding for the GMbattlemode/GMcoopmode/GMindestructablemode/GMweather GM
	// verbs -- each toggles one of these per specific area instance, not globally.
	// GMbattlemode (GMCommands.dm) can still flip battleModeOn at runtime per instance;
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

	castle
		icon_state = "castle"

	cave
		icon_state = "cave"

	old
		icon_state = "old"

	snow
		icon_state = "snow"

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

	deepwater
		icon_state = "deepwater"

	water1
		icon_state = "water1"

	water
		icon_state = "water"

	rave
		icon_state = "rave"


	playerStart
		icon = 'door.dmi'
		icon_state = "wooden"
