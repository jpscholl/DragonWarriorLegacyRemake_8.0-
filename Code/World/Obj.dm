//turfs and objects where interactions and special things. The category given to them was "stat" according to original game.
//meant to be creatable with a GM "makestat" verb — not implemented yet (see Main.dm's GM/Admin systems to-do item)

// -----------------------------
// Convention: don't hardcode purely-visual obj variants
// -----------------------------
// The obj collapse described here is DONE as of the map repaint session following the
// Turfs.dm collapse: every purely-visual variant (differed from a sibling only by
// icon_state/name/message — data, not code) has been removed. What used to be e.g.
// obj/stat/sign/inn, obj/stat/sign/church, etc. are now just obj/stat/sign, painted as
// different map-editor INSTANCES instead of separate hardcoded types. Source:
// https://www.byond.com/forum/post/1620724
//
// THE MAP WILL NOT COMPILE until every placed obj that used one of the removed types
// gets repainted in the map editor as an instance of the surviving base type.
//
// Going forward: a new type belongs here ONLY if it has different BEHAVIOR (a proc
// override — see obj/door, obj/stat/sign below for real examples). A purely visual/data
// variant (icon_state, name, or a content var like sign's message) should be painted as
// a map-editor INSTANCE instead, not a new hardcoded subtype.

obj/door
    icon = 'door.dmi'
    icon_state = "wooden"
    density = 1
    var/is_open = FALSE
    var/closed_icon_state = "wooden"   // sprite to restore on close() — override per instance (e.g. "jail")
    var/open_session = 0   // bumped each open(), so a stale auto-close timer can tell it's been reopened since
    var/mob/opener   // whoever's interaction is currently holding this door open
    var/is_locked = FALSE   // if TRUE, OnInteract() requires a key whose keyName matches this door's name

    proc/open(mob/user)
        if(!is_open)
            is_open = TRUE
            icon_state = "open"
            density = 0
            open_session++
            var/my_session = open_session
            opener = user

            for(var/mob/M in view(7, src))
                if(M.client)
                    // channel = SFX_CHANNEL (.dme) — an unspecified channel still
                    // interrupts channel 1 area music (PlayAreaMusic(), Area.dm) in
                    // this BYOND version, same issue found in CombatSystem.dm.
                    M << sound('door.wav', channel = SFX_CHANNEL, volume = M.client.ScaledVolume(100))

            // Auto-close after 5 seconds regardless of what's standing on/around the
            // door (covers the opener just parking on the tile and never leaving).
            // Guarded by open_session so this doesn't slam the door shut early if
            // it's been closed and reopened again before this timer fires.
            spawn(50)
                if(open_session == my_session)
                    close()

    proc/close()
        if(is_open)
            is_open = FALSE
            icon_state = closed_icon_state
            density = 1
            opener = null


    // Close the instant the mob who opened it walks off the tile — not whenever the
    // tile happens to be empty, so someone following close behind can't slip through
    // on the opener's interaction; they need to interact with the door themselves.
    Uncrossed(atom/movable/O)
        ..()
        if(is_open && O == opener)
            close()

    OnInteract(mob/user)
        // Checked fresh every interaction — the key just needs to be in your inventory
        // right now, it doesn't auto-unlock the door for anyone else afterward.
        if(is_locked && !user.HasMatchingKey(name))
            user << output("This is locked.", "Info")
            return TRUE

        if(is_open)
            close()
        else
            open(user)
        return TRUE


obj
	stat
		door
			// Kept under /obj/stat (for the future GM "makestat" menu) but actually
			// reuses /obj/door's real is_open/open()/close()/OnInteract() logic via
			// parent_type, same pattern as datum/skill/Attack in SkillDatum.dm.
			// was: jail, wooden — now instances (jail sets icon_state="jail" AND
			// closed_icon_state="jail"; wooden was identical to this base's own
			// inherited defaults, so it needs no instance at all).
			parent_type = /obj/door
			name = "door"
			icon = 'door.dmi'
			density = 1

		// was: drawers/wooden — collapsed, this is now the only drawers type
		drawers
			name = "drawers"
			icon = 'table.dmi'
			icon_state = "drawers"
			density = 1
//interaction stores and takes items

		// was: bookcase/bookcase — collapsed, this is now the only bookcase type
		bookcase
			name = "bookcase"
			icon = 'table.dmi'
			icon_state = "bookcase"
			density = 1

//interaction makes this store messages and read messages

		// was: chest/wooden — collapsed, this is now the only chest type
		chest
			name = "chest"
			icon = 'table.dmi'
			icon_state = "chestclosed"
			density = 1
//interaction makes this store/give items (copy-pasted comment below was wrong — chests hold items, not messages)

		// was: inn, church, wooden, grave — now instances (set icon_state, name, and
		// message per-instance; message is just a var like any other, no behavior
		// difference between any of them).
		sign
			icon = 'sign.dmi'
			density = 1
			var/message = "..."   // shown to whoever reads the sign

			// World-placed signs get their message set per-instance via the map
			// editor. GM-placed signs (GM_CreateObj's CreateSign(), GMCommands.dm) set
			// this per-instance too — this proc doesn't care which happened.
			OnInteract(mob/user)
				user << output("<b>[name]</b><br>[message]", "Messages")
				return TRUE

		// was: woodpot, pot — collapsed, this is now the only pot type
		pot
			icon = 'pots.dmi'
			density = 1


// Ceiling object
obj/ceiling
    icon = 'wall.dmi'
    icon_state = "ceiling"
    layer = 100
    invisibility = 1   // hidden unless mob.see_invisible >= 1 — keep this below
                         // GHOST_INVISIBILITY (GMCommands.dm, currently 2) or GM
                         // ghost form stops being hidden from regular players again

    Crossed(mob/M)
        if(ismob(M) && M.client)
            // Loop through adjacent turfs
            for(var/turf/T in oview(3, src))
                // Skip walls and ceilings
                if(istype(T, /turf/wall))
                    T.opacity = 1
