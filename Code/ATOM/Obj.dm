//turfs and objects where interactions and special things. The category given to them was "stat" according to orginal game.
//can be created with GMmakestat verb

obj/door
    icon = 'door.dmi'
    icon_state = "wooden"
    density = 1
    var/is_open = FALSE

    proc/open()
        if(!is_open)
            is_open = TRUE
            icon_state = "open"
            density = 0

            for(var/mob/M in view(7, src))
                if(M.client)
                    M << sound('door.wav')

    proc/close()
        if(is_open)
            is_open = FALSE
            icon_state = "wooden"
            density = 1

            for(var/mob/M in view(7, src))
                if(M.client)
                    M << sound('door.wav')


obj
	stat
		door
			name = "door"
			icon = 'door.dmi'
			density = 1

			jail
				icon_state= "jail"

			wooden
				icon_state= "wooden"
//will work on open and closing doors


		drawers
			wooden
				name = "drawers"
				icon = 'table.dmi'
				icon_state= "drawers"
				density = 1
//interaction stores and takes items

		bookcase
			name = "bookcase"
			icon = 'table.dmi'
			density = 1

			bookcase
				icon_state= "bookcase"

//interaction makes this store messages and read messages

		chest
			wooden
				name = "chest"
				icon = 'table.dmi'
				icon_state= "chestclosed"
				density = 1
//interaction makes this store messages and read messages

		sign
			icon = 'sign.dmi'
			density = 1

			inn
				name = "inn"
				icon_state = "inn"

			church
				name = "church"
				icon_state = "church"

			wooden
				name = "wooden"
				icon_state = "sign"

			grave
				name = "grave"
				icon_state = "grave"

//gms can create signs with different names and messages
//interacting causes message to display in text

		pot
			icon = 'pots.dmi'
			density = 1

			woodpot
				icon_state = "woodpot"

			pot
				icon_state = "pot"


// Ceiling object
obj/ceiling
    icon = 'wall.dmi'
    icon_state = "ceiling"
    layer = 100
    invisibility = 1   // hidden unless mob.see_invisible >= 1

    Crossed(mob/M)
        if(ismob(M) && M.client)
            // Loop through adjacent turfs
            for(var/turf/T in oview(3, src))
                // Skip walls and ceilings
                if(istype(T, /turf/wall))
                    T.opacity = 1