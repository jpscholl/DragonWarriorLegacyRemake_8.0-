//turfs and objects where interactions and special things. The category given to them was "stat" according to original game.
//meant to be creatable with a GM "makestat" verb — not implemented yet

// -----------------------------
// Convention: don't hardcode purely-visual obj variants
// -----------------------------
// A new type belongs here ONLY if it has different BEHAVIOR (a proc override — see
// obj/door, obj/stat/sign below for real examples). A purely visual/data variant
// (icon_state, name, or a content var like sign's message) should be painted as a
// map-editor INSTANCE instead, not a new hardcoded subtype. See Markdowns/CodeNotes.md
// for the obj-collapse history this convention came from.

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
                    M << sound('door.wav', channel = SFX_CHANNEL, volume = M.client.ScaledVolume(100))

            // Auto-close after 5 seconds regardless of what's standing around the door.
            // Guarded by open_session so this doesn't slam shut early if it's been
            // closed and reopened again before this timer fires.
            spawn(50)
                if(open_session == my_session)
                    close()

    proc/close()
        if(is_open)
            is_open = FALSE
            // ApplyNightSuffix() (Main.dm), not closed_icon_state directly — see
            // Markdowns/CodeNotes.md for why the stored value alone isn't enough.
            icon_state = ApplyNightSuffix(closed_icon_state)
            density = 1
            opener = null

    // Close the instant the mob who opened it walks off the tile — not whenever the
    // tile happens to be empty, so someone following close behind can't slip through.
    Uncrossed(atom/movable/O)
        ..()
        if(is_open && O == opener)
            close()

    OnInteract(mob/user)
        // Checked fresh every interaction — the key just needs to be in your
        // inventory right now, it doesn't auto-unlock the door for anyone else after.
        if(is_locked && !user.HasMatchingKey(name))
            user.ShowInfo("This is locked.")
            return TRUE

        if(is_open)
            close()
        else
            open(user)
        return TRUE


obj
	stat
		door
			// Kept under /obj/stat (for the future GM "makestat" menu) but reuses
			// /obj/door's real is_open/open()/close()/OnInteract() via parent_type.
			parent_type = /obj/door
			name = "door"
			icon = 'door.dmi'
			density = 1

		drawers
			parent_type = /obj/storage
			name = "drawers"
			icon = 'table.dmi'
			icon_state = "drawers"
			density = 1
// Storage behavior lives in /obj/storage at the bottom of this file (parent_type above).

		// CONFIRMED OG mechanic (OGGameStructure.md, string 1687): "player-writable
		// shared book storage" — any player can add a message and read what everyone
		// else has written to THIS bookcase. Session-only, like obj/storage's
		// contents below — no world serializer yet, so a reboot empties every bookcase.
		bookcase
			name = "bookcase"
			icon = 'table.dmi'
			icon_state = "bookcase"
			density = 1
			var/list/messages = list()

			OnInteract(mob/user)
				var/choice = input(user, "The bookcase is full of scribbled notes.", "Bookcase") in list("Write a message", "Read messages", "Cancel")
				if(!choice || choice == "Cancel") return TRUE

				if(choice == "Write a message")
					var/msg = input(user, "What would you like to write?", "Bookcase") as text|null
					if(isnull(msg) || !length(trimtext(msg))) return TRUE
					messages += "[user.name]: [CensorText(trimtext(msg))]"
					user.ShowInfo("You add your message to the bookcase.")
					return TRUE

				// "Read messages"
				if(!messages.len)
					user.ShowInfo("The bookcase is empty.")
					return TRUE
				var/pageText = "<b>[name]</b><br>"
				for(var/line in messages)
					pageText += "[line]<br>"
				user << browse(pageText, "window=bookcase;size=400x300")
				return TRUE

		chest
			parent_type = /obj/storage
			name = "chest"
			icon = 'table.dmi'
			icon_state = "chestclosed"
			density = 1
// Storage behavior lives in /obj/storage at the bottom of this file (parent_type above).

		// Message is just a var like any other — no behavior difference between any
		// instance. World-placed signs get it set per-instance via the map editor;
		// GM-placed signs (GM_CreateObj's CreateSign(), GMCommands.dm) the same way.
		sign
			icon = 'sign.dmi'
			density = 1
			var/message = "..."   // shown to whoever reads the sign

			OnInteract(mob/user)
				user << output("<b>[name]</b><br>[message]", "Messages")
				return TRUE

		pot
			parent_type = /obj/storage
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
            for(var/turf/T in oview(3, src))
                if(istype(T, /turf/wall))
                    T.opacity = 1

// -----------------------------
// Storage containers — see Markdowns/CodeNotes.md for OG-confirmation of the shape.
// Items live in the container's own contents, same as a player's inventory
// (Inventory.dm) — no parallel list to keep in sync. Contents persist for the world's
// lifetime but are NOT saved (no world serializer yet, RemakeVsOGStructure.md Part
// 3.20) — anything stored is lost on reboot. Locking reuses the existing named-key
// system wholesale (obj/door / obj/item/key).
// -----------------------------
obj/storage
    density = 1
    var/capacity = 10
    var/lockName = null   // null = unlocked, always openable

    proc/GetCount()
        var/count = 0
        for(var/obj/item/I in contents)
            count++
        return count

    OnInteract(mob/user)
        if(lockName && !user.HasMatchingKey(lockName))
            user.ShowInfo("[name] is locked.")
            return TRUE

        var/choice = input(user, "What would you like to do?", "[name]") in list("Store", "Take", "Leave")
        switch(choice)
            if("Store") StoreItem(user)
            if("Take")  TakeItem(user)
        return TRUE

    proc/StoreItem(mob/user)
        var/list/items = list()
        for(var/obj/item/I in user.contents)
            items[I.name] = I

        if(!items.len)
            user.ShowInfo("You have nothing to store.")
            return

        if(GetCount() >= capacity)
            user.ShowInfo("[name] is full.")
            return

        var/choice = input(user, "Store which item?", "[name]") in items + "Cancel"
        if(!choice || choice == "Cancel") return

        var/obj/item/I = items[choice]
        if(!I) return

        // A worn amulet has to come off before it's stored, or its stat bonus stays
        // applied to a player who no longer carries it.
        if(istype(I, /obj/item/amulet))
            var/obj/item/amulet/A = I
            if(A.worn) A.Unequip(user)

        I.loc = src
        user.ShowInfo("You put [I.name] in [name].")

    proc/TakeItem(mob/user)
        var/list/items = list()
        for(var/obj/item/I in contents)
            items[I.name] = I

        if(!items.len)
            user.ShowInfo("[name] is empty.")
            return

        var/choice = input(user, "Take which item?", "[name]") in items + "Cancel"
        if(!choice || choice == "Cancel") return

        var/obj/item/I = items[choice]
        if(!I) return

        if(!user.PickUpItem(I))
            return  // PickUpItem() already explained why (inventory full)

        user.ShowInfo("You take [I.name] from [name].")
