//for music transitions...or skipping them
mob/var
		current_music = null

area
	icon = 'environment.dmi'

	casino
		icon_state = "casino"

	dungeon
		icon_state = "dungeon"

	boss
		icon_state = "boss"

	forest
		icon_state = "forest"

	townrain
		icon_state = "townrain"
		Entered(atom/movable/O)
			..()
			if(ismob(O))
				var/mob/M = O
				if(M.client)
					if(M.current_music != 'dw4town.mid')
						M.client << sound('dw4town.mid', repeat = 1, volume = worldVolume, channel = 1)
						M.current_music = 'dw4town.mid'


	town
		icon_state = "town"
		Entered(atom/movable/O)
			..()
			if(ismob(O))
				var/mob/M = O
				if(M.client)
					if(M.current_music != 'dw4town.mid')
						M.client << sound('dw4town.mid', repeat = 1, volume = worldVolume, channel = 1)
						M.current_music = 'dw4town.mid'


	battle
		icon_state = "battle"

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
		Entered(atom/movable/O)
			..()
			if(ismob(O))
				var/mob/M = O
				if(M.client)
					if(M.current_music != 'dw3town.mid')
						M.client << sound('dw3town.mid', repeat = 1, volume = worldVolume, channel = 1)
						M.current_music = 'dw3town.mid'

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