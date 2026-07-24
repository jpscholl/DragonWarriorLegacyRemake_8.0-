//these are the collections of turf stuff that makes da world that you play in

// ------------------------------------------------------
// Convention: don't hardcode purely-visual turf variants
// ------------------------------------------------------
// The turf collapse described here is DONE as of 2026-07-21: every purely-visual
// variant (differed from a sibling ONLY by icon_state/name, no real behavior) has been
// removed from this file. What used to be e.g. turf/floor/cobble, turf/floor/carpet,
// etc. are now just turf/floor, painted as different map-editor INSTANCES (icon_state
// override) instead of separate hardcoded types. Source:
// https://www.byond.com/forum/post/1620724
// ("Snippet Sunday #2: Learning to love the map editor" — polymorphism isn't a database).
//
// THE MAP WILL NOT COMPILE until every placed tile that used one of the removed types
// (see the list this change shipped with) gets repainted in the map editor as an
// instance of the surviving base type. This is expected, not a bug.
//
// Going forward: a new type belongs here ONLY if it has different BEHAVIOR (a proc
// override, a var that actually does something — see turf/stairs, turf/furniture/bed*
// below for real examples). A tile that's just a different sprite of something that
// already exists should be painted as a map-editor INSTANCE instead (right click the
// type in the object tree -> New Instance... -> set icon_state), not a new hardcoded
// subtype.

// Sleeping state, used by the bedhead turf below. Moving at all wakes the player back up
// automatically — see Step() in Code/Core/SmoothMovement.dm.
mob/var/isSleeping = FALSE

mob/proc/WakeUp()
	if(isSleeping)
		isSleeping = FALSE
		icon_state = "world"

//grass: dis is ground...you walk on it
//was: grass, brush, flowers, farmland, cavedirt, sand — all now instances of this type
// Default icon_state is "grass" — ground should never render as blank space. Any
// instance without an explicit override (including world.turf's fallback in Main.dm)
// falls back to this.
turf
	ground
		icon = 'grass.dmi'
		icon_state = "grass"
		density = 0

//floor: this is what you get on after you open the door and before you walk the dinosaur
//also you walk on it like ground
//was: cobble, burntcobble, carpet, woodfloor, stool, woodchair, path — now instances
	floor
		icon = 'floor.dmi'
		density = 0

//tables: don't flip these please

//where the hell did it go???
/*
turf/table/longtablecenter
	name = "table"
	icon = 'table.dmi'
	icon_state= "woodcenter"
	density = 1
*/

//was: table, woodtable, stonetable, woodtableleft, woodtableright, plant, stove,
//curtains, statue, tub, bedright, woodbedright, throneright, throneleft, thronecenter,
//thronearm, evilthrone — now instances. bedhead/bedleft/woodbedleft/counter stay
//hardcoded below since they have real behavior (or are checked for by type elsewhere).
//Only the LEFT (head/pillow) side of a bed is sleepable, by design — bedright/
//woodbedright are just the foot-of-bed visual, no interaction of their own.
	furniture
		icon = 'table.dmi'
		density = 1
//interaction on a stove causes prompt to cook food (if in inventory) — not built yet
//interaction on a tub grabs glasses of water — not built yet

// -----------------------------
// Sleeping (beds)
// -----------------------------
// Interacting with the head/pillow side of a bed (bedleft/woodbedleft below) moves the
// player onto it and puts them in the "sleep" icon_state. Moving at all wakes them back
// up automatically (see Step() in Code/Core/SmoothMovement.dm).
// TODO: gradually restore HP/MP while sleeping — interval not decided yet, not built.
		bedhead
			// Not meant to be placed directly on a map — bedleft/woodbedleft below point
			// to this via parent_type so both share the same behavior without duplicating it.
			OnInteract(mob/user)
				if(user.isSleeping)
					return TRUE   // already sleeping here, nothing more to do

				user.loc = src
				user.icon_state = "sleep"
				user.isSleeping = TRUE
				return TRUE

		bedleft
			name = "bed"
			icon_state= "bedleft"
			parent_type = /turf/furniture/bedhead

		woodbedleft
			name = "bed"
			icon_state= "woodbedleft"
			parent_type = /turf/furniture/bedhead

		// Kept as a real type (not collapsed to an instance) — PlayerVerbs.dm's
		// Interact() checks for this exact type path to skip an extra tile ahead.
		counter
			name = "counter"
			icon_state = "counter"
//able to interact with npcs behind it (extra space away)

//Trees: the leafy things that provide oxygen
//was: tree — now an instance of this type
	tree
		icon = 'tree.dmi'
		density = 1

//stairs: no these aren't stairways to heaven just up or down a level
//was: cavestairsup — now an instance (NOTE: this one never actually had stairs behavior
//wired up even before the collapse — it had no Entered() override of its own and wasn't
//parent_type'd to stairsup, so it was already non-functional as an up-staircase. Give it
//parent_type = /turf/stairs/stairsup if that was supposed to work.)
	stairs
		icon = 'stairs.dmi'
		density = 0

		stairsup
			name = "stairs"
			icon_state = "stoneup"
			Entered(atom/movable/A)
				if(!ismob(A)) return
				var/mob/M = A
				// M << sound(...), not view() — view() filters by visibility rules
				// (opacity/invisibility/see_invisible), and it turns out that filter
				// can exclude M itself in edge cases (e.g. GMghostform sets
				// invisibility = 1 and icon = null, GMCommands.dm), so the sound
				// silently never played for a ghosted GM taking the stairs. Sending
				// straight to M sidesteps visibility rules entirely and guarantees
				// the mob actually taking the stairs always hears it. Also has to
				// fire BEFORE M.loc changes below, same reasoning as before.
				M << sound('stairs.wav', repeat = 0, channel = SFX_CHANNEL, volume = baseVolume)  // SFX_CHANNEL: .dme — not channel 1 (area music), so this doesn't interrupt it
				var/turf/new_loc = locate(M.x, M.y, M.z + 1)
				if(new_loc)
					M.loc = new_loc
//walking over causes player to warp one Z level up

		stairsdown
			name = "stairs"
			icon_state = "stonedown"
			Entered(atom/movable/A)
				if(!ismob(A)) return
				var/mob/M = A
				M << sound('stairs.wav', repeat = 0, channel = SFX_CHANNEL, volume = baseVolume)  // see stairsup's notes above
				var/turf/new_loc = locate(M.x, M.y, M.z - 1)
				if(new_loc)
					M.loc = new_loc
//walking over causes player to warp one Z level down

//walls: all and all we're just another brick in the wall
//was: stonewall, stonewalledge, cobblewall, cobblewalledge, cavewall, cavewalledge,
//logwall, pillartop, pillarbottom, voidwall, woodwall, woodwalledge,
//wooddownleftcorner, wooddownrightcorner, woodupleftcorner, wooduprightcorner — instances
	wall
		icon = 'wall.dmi'
		name = "wall"
		density = 1

//Fence: I'm still on the fence about this
//was: fence, sandfence — now instances of this type
	fence
		name = "fence"
		icon = 'wall.dmi'
		density = 1

//something about sky here idk I got nothing
//was: sky — now an instance
	sky
		name = "sky"
		icon = 'sky.dmi'
		density = 0
		Entered(atom/movable/A)
			if(!ismob(A)) return
			var/mob/M = A
			// Already mid-fall (canAct locked below) -- without this, walking
			// across multiple sky tiles during the delay re-triggered Entered()
			// on each one, stacking up multiple falls/sounds.
			if(!M.canAct) return
			// Locks movement via mob/proc/Step()'s existing canAct gate
			// (SmoothMovement.dm), same mechanism already used to root a mob
			// mid-attack/on death -- this is what actually stops the repeat
			// trigger above, since M physically can't step onto another sky
			// tile while rooted. Reset once the fall below actually resolves.
			M.canAct = FALSE
			// M << sound(...), not view() -- see stairsup's note (Turfs.dm) on why:
			// view()'s visibility filtering can exclude M itself in edge cases
			// (e.g. GMghostform), silently swallowing the sound for exactly the
			// mob it's meant for. Also has to fire before the z-level change
			// below, same reasoning as stairsup/stairsdown.
			M << sound('fall.wav', repeat = 0, channel = SFX_CHANNEL, volume = baseVolume)
			// Brief pause before actually dropping - placeholder gap for a real
			// falling animation later (not built yet).
			spawn(8)
				var/turf/new_loc = locate(M.x, M.y, M.z - 1)
				if(new_loc)
					M.loc = new_loc
				M.canAct = TRUE
//walking onto this causes the player to fall one Z level down, same mechanic as
//turf/stairs/stairsdown above just triggered by sky instead of a staircase

//don't go burning these...how else you supposed to get across water?
//was: bridgev, bridgeh, stonebridge — now instances of this type
	bridge
		name = "bridge"
		icon = 'bridge.dmi'
		density = 0

//that's some high quality h20
//was: water, upedge, downedge, rightedge, leftedge, upleftedge, uprightedge,
//downleftedge, downrightedge — now instances of this type
	water
		name = "water"
		icon = 'water.dmi'
		density = 1

//it teleports you duh (not actually built yet — no Entered()/teleport logic exists)
//was: warp — now an instance of this type
	warp
		name = "warp"
		icon = 'warp.dmi'
