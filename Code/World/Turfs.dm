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

// GM-only stair travel toggles — independent per direction (see turf/stairs/
// ToggleStairJump() below), so a GM can e.g. jump 2 levels going up while still
// stepping 1 at a time going down. Everyone else always moves 1 level per stairway
// regardless of these (TakeStairs() only reads them for mobs with canBuild).
mob/var/stairJumpLevelsUp = 1
mob/var/stairJumpLevelsDown = 1

// Named-pair teleport link — shared by turf/warp (its whole purpose) and any turf/stairs
// instance whose icon_state has no inferable up/down direction (castle/icecastle/black —
// see turf/stairs' own header comment below). Defaults to a coordinate string at
// creation so two freshly-placed, not-yet-linked points never accidentally match each
// other; a GM renames one (or both) via DblClick() to link them — same name = same pair.
turf/var/warpName = null

turf/proc/EnsureWarpName()
	if(!warpName) warpName = "[x],[y],[z]"

// Finds another turf of the given family (istype-checked against baseType, e.g.
// /turf/warp or /turf/stairs) sharing T's warpName — the other end of the pair. Doesn't
// cross families: a warp only links to another warp, a stairs warp-point only links to
// another stairs tile, even if a name collides across the two by coincidence.
proc/FindWarpPartner(turf/T, baseType)
	if(!T || !T.warpName) return null
	for(var/turf/O in world)
		if(O == T) continue
		if(!istype(O, baseType)) continue
		if(O.warpName == T.warpName) return O
	return null

// Shared rename-prompt for any warp-linked turf (turf/warp, or a non-directional
// turf/stairs skin) — GM-only. Defaults the input to the current name so re-running it
// without typing anything new is a no-op instead of clearing it.
proc/RenameWarpTurf(turf/T, mob/M)
	if(!T || !M || !M.client || !M.client.canBuild) return
	var/newName = input(M, "Name this warp point (give the other end the SAME name to link them):", "Name Warp", T.warpName) as text|null
	if(isnull(newName) || !length(trimtext(newName))) return
	T.warpName = trimtext(newName)
	M << output("This is now named \"[T.warpName]\".", "Info")

// TEMPORARY VALUES — confirmed as "restore 1 of each per half second" for a BED,
// explicitly expected to be retuned later. Real resting balance (rate, whether it
// should scale with anything, whether an inn bed differs from one found in the world)
// is still an open design question.
#define BED_RESTORE_INTERVAL 5  // deciseconds — 0.5s
#define BED_RESTORE_AMOUNT 1    // HP and MP each, per interval

// The confirmed-planned **Rest** skill (sleep in place, anywhere) should recover
// SLOWER than a bed — it's sleeping on the ground, not in an actual bed. That's why
// SleepRestoreLoop() below takes its rate as arguments instead of reading the defines
// directly: Rest just calls it with a longer interval (and/or smaller amount) rather
// than needing its own duplicate loop. Numbers for that aren't decided yet.

// Guards against two restore loops running at once, which would silently double the
// heal rate: waking and immediately re-sleeping starts a second loop while the first
// is still mid-sleep(), and that first loop's `isSleeping` check would pass again by
// the time it wakes. Same session-counter pattern used by open_session (Obj.dm),
// pendingSession (SmoothMovement.dm), and defendToggleSession (CombatSystem.dm).
mob/var/sleepSession = 0

// Guards turf/warp's Entered() against immediately re-triggering on arrival: moving
// M.loc to the partner tile fires THAT tile's Entered() synchronously, which would
// otherwise find its own partner (the tile you just left) and bounce you straight
// back. Same short-lived guard shape as sleepSession above / pendingSession
// (SmoothMovement.dm) / defendToggleSession (CombatSystem.dm).
mob/var/warpCooldown = FALSE

mob/proc/WakeUp()
	if(isSleeping)
		isSleeping = FALSE
		sleepSession++  // invalidates any in-flight SleepRestoreLoop()
		icon_state = "world"

// Started by bedhead's OnInteract() (below) when a mob lies down. Self-terminates on
// wake — no need for anything to stop it explicitly. Deliberately a mob proc (rather
// than something owned by the bed turf) that takes its rate as arguments, so the
// confirmed-planned **Rest** skill can reuse it directly for slower on-the-ground
// recovery: set isSleeping/icon_state, call this with a longer interval, done.
// Defaults are the bed rate.
mob/proc/SleepRestoreLoop(interval = BED_RESTORE_INTERVAL, amount = BED_RESTORE_AMOUNT)
	set waitfor = 0
	sleepSession++
	var/mySession = sleepSession

	while(src && isSleeping && sleepSession == mySession)
		sleep(interval)
		// Re-check after the sleep — the mob may have woken (or died, or started a
		// fresh sleep session) while this was waiting.
		if(!isSleeping || sleepSession != mySession) return
		if(isDead) return

		HP = min(MaxHP, HP + amount)
		MP = min(MaxMP, MP + amount)
		// Both bars stay up for the whole rest (it's healing); fade 5s after waking (HUD.dm)
		ShowFloatingHPBar()
		ShowFloatingMPBar()

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
// up automatically (see Step() in Code/Core/SmoothMovement.dm). Sleeping gradually
// restores HP/MP — see SleepRestoreLoop() above (temporary rate, expected to be retuned).
		bedhead
			// Not meant to be placed directly on a map — bedleft/woodbedleft below point
			// to this via parent_type so both share the same behavior without duplicating it.
			OnInteract(mob/user)
				if(user.isSleeping)
					return TRUE   // already sleeping here, nothing more to do

				user.loc = src
				user.icon_state = "sleep"
				user.isSleeping = TRUE
				user.SleepRestoreLoop()
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
//was: cavestairsup — now an instance. This used to be non-functional (see git history)
//because "up"/"down" behavior lived on the stairsup/stairsdown SUBTYPES only — any skin
//painted on the bare base type (which is what the collapse above produces) inherited no
//Entered() at all. Direction is now inferred from icon_state itself (GetStairDirection()
//below) so EVERY skin works regardless of which of the three types (stairs/stairsup/
//stairsdown) it's actually painted as an instance of.
	stairs
		icon = 'stairs.dmi'
		density = 0

		New()
			..()
			EnsureWarpName()

		// +1/-1 for any skin whose icon_state names a direction (stoneup, wooddown,
		// icecaveup, etc. — every real skin in stairs.dmi except castle/icecastle/black,
		// confirmed against the actual icon_states() dump, not guessed). 0 for the ones
		// that don't — those link by name instead, same mechanism as turf/warp (see
		// FindWarpPartner()/RenameWarpTurf() near the top of this file).
		proc/GetStairDirection()
			if(findtext(icon_state, "up")) return 1
			if(findtext(icon_state, "down")) return -1
			return 0

		// M << sound(...), not view() — view() filters by visibility rules
		// (opacity/invisibility/see_invisible), and it turns out that filter can
		// exclude M itself in edge cases (e.g. GM_GhostForm sets invisibility = 1
		// and icon = null, GMCommands.dm), so the sound silently never played for a
		// ghosted GM taking the stairs. Sending straight to M sidesteps visibility
		// rules entirely and guarantees the mob actually taking the stairs always
		// hears it.
		proc/PlayStairSound(mob/M)
			M << sound('stairs.wav', repeat = 0, channel = SFX_CHANNEL, volume = M.client ? M.client.ScaledVolume() : 100)  // SFX_CHANNEL: .dme — not channel 1 (area music), so this doesn't interrupt it

		// direction levels defaults to a plain walk-over (1); GMs can toggle their own
		// stairJumpLevelsUp/Down between 1 and 2 via DblClick() below, which then
		// applies to every future walk-over of that direction until toggled back.
		proc/TakeStairs(mob/M, direction)
			if(!M) return
			var/levels = 1
			if(M.client && M.client.canBuild)
				levels = (direction > 0) ? M.stairJumpLevelsUp : M.stairJumpLevelsDown
			PlayStairSound(M)  // has to fire BEFORE M.loc changes below, same reasoning as the comment above
			var/turf/new_loc = locate(M.x, M.y, M.z + (direction * levels))
			if(!new_loc) return

			// Screen fade (PlayScreenFade(), Main.dm) masks the teleport: fade to black,
			// move while nothing's visible, fade back in on the other side. canAct locks
			// movement for the duration, same mechanism the sky-fall below already used —
			// spawned so Entered()'s own dispatch (which called this) returns immediately
			// instead of blocking on the fade's sleep()s.
			M.canAct = FALSE
			spawn(0)
				M.PlayScreenFade(TRUE)
				M.loc = new_loc
				// Area/Entered() (Area.dm) already fires on this loc change and plays
				// the new area's music if it's actually a DIFFERENT area instance — but
				// stairs commonly land on a new z-level that's still the SAME area
				// instance (e.g. one dungeon area spanning every floor), which never
				// re-fires Entered(). Explicit re-check here so a floor transition
				// always reflects whatever area you actually land in, regardless of
				// whether BYOND considered it a "new" area. PlayAreaMusic() itself
				// already no-ops if that track is already playing.
				var/area/newArea = new_loc.loc
				if(istype(newArea) && newArea.areaMusic)
					M.PlayAreaMusic(newArea.areaMusic)
				M.PlayScreenFade(FALSE)
				M.canAct = TRUE

		// GM-only toggle: double-clicking ANY directional stairs tile (no need to stand
		// on it) flips stairJumpLevelsUp between 1 (normal) and 2 for EVERY stairs-up
		// tile in the world at once — stairs-down has its own independent toggle the
		// same way, so a GM can e.g. climb 2 levels at a time while still descending 1
		// at a time. Handy for quickly crossing several Z-levels while building/testing
		// without switching tools. Silent no-op for anyone without Builder access — this
		// fires on every double-click of a completely ordinary, everyone-can-see world
		// object, so no rejection message either.
		//
		// Reached two ways: DblClick() below (clicking a stairs tile from anywhere —
		// atom click dispatch resolves normally there), and mob/DblClick() (Code/Player/
		// Commands/PlayerVerbs.dm) for the case of standing directly ON the stairs,
		// where your own mob sprite is the topmost atom at that screen position and the
		// click hits yourself instead of the turf underneath — this proc is what that
		// self-click path calls into as well.
		proc/ToggleStairJump(mob/M, direction)
			if(!M || !M.client || !M.client.canBuild) return
			if(direction > 0)
				M.stairJumpLevelsUp = (M.stairJumpLevelsUp == 1) ? 2 : 1
				M << output("Stairs up will now move you [M.stairJumpLevelsUp] level[M.stairJumpLevelsUp == 1 ? "" : "s"] at a time.", "Info")
			else
				M.stairJumpLevelsDown = (M.stairJumpLevelsDown == 1) ? 2 : 1
				M << output("Stairs down will now move you [M.stairJumpLevelsDown] level[M.stairJumpLevelsDown == 1 ? "" : "s"] at a time.", "Info")

		Entered(atom/movable/A)
			if(!ismob(A)) return
			var/mob/M = A
			var/direction = GetStairDirection()
			if(direction)
				TakeStairs(M, direction)
			else
				var/turf/partner = FindWarpPartner(src, /turf/stairs)
				if(partner)
					PlayStairSound(M)
					// Same fade-mask treatment as the directional branch above
					// (TakeStairs()) — castle/icecastle/black skins link by name
					// instead of direction, but they're still stairs to the player.
					M.canAct = FALSE
					spawn(0)
						M.PlayScreenFade(TRUE)
						M.loc = partner
						// Same explicit re-check as TakeStairs() above — a same-area
						// floor transition wouldn't otherwise re-fire Entered()/music.
						var/area/newArea = partner.loc
						if(istype(newArea) && newArea.areaMusic)
							M.PlayAreaMusic(newArea.areaMusic)
						M.PlayScreenFade(FALSE)
						M.canAct = TRUE
				else
					M << output("This staircase doesn't lead anywhere yet.", "Info")
//walking over causes player to warp levels (directional skins) or teleport to a
//matching-named partner (castle/icecastle/black — see GetStairDirection() above)

		// Directional skins toggle jump-levels (ToggleStairJump()); castle/icecastle/
		// black have no direction to toggle, so they get the rename prompt instead
		// (RenameWarpTurf(), top of file) — same double-click, different result
		// depending on which skin is currently painted on this instance.
		DblClick()
			if(!usr) return
			var/direction = GetStairDirection()
			if(direction)
				ToggleStairJump(usr, direction)
			else
				RenameWarpTurf(src, usr)

		stairsup
			name = "stairs"
			icon_state = "stoneup"

		stairsdown
			name = "stairs"
			icon_state = "stonedown"

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
			// (e.g. GM_GhostForm), silently swallowing the sound for exactly the
			// mob it's meant for. Also has to fire before the z-level change
			// below, same reasoning as stairsup/stairsdown.
			M << sound('fall.wav', repeat = 0, channel = SFX_CHANNEL, volume = M.client ? M.client.ScaledVolume() : 100)
			// Real falling animation (PlayScreenFade(), Main.dm) — fills the "placeholder
			// gap for a real falling animation later (not built yet)" this comment used to
			// flag. Same fade-to-black / teleport / fade-back-in shape as stairs
			// (TakeStairs(), above), replacing the old flat spawn(8) delay rather than
			// stacking on top of it — the fade sequence's own ~1.6s round trip already IS
			// the pause.
			spawn(0)
				M.PlayScreenFade(TRUE)
				var/turf/new_loc = locate(M.x, M.y, M.z - 1)
				if(new_loc)
					M.loc = new_loc
				M.PlayScreenFade(FALSE)
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

//it teleports you duh — named-pair link (FindWarpPartner()/RenameWarpTurf(), top of
//file): a GM double-clicks two warp tiles and gives them the SAME name to link them;
//stepping on either one then sends you to the other. Same mechanism turf/stairs' non-
//directional skins (castle/icecastle/black) use.
//was: warp — now an instance of this type
	warp
		name = "warp"
		icon = 'warp.dmi'

		New()
			..()
			EnsureWarpName()

		Entered(atom/movable/A)
			if(!ismob(A)) return
			var/mob/M = A
			if(M.warpCooldown) return
			var/turf/partner = FindWarpPartner(src, /turf/warp)
			if(partner)
				M.warpCooldown = TRUE
				M.loc = partner
				spawn(2) M.warpCooldown = FALSE
			else
				M << output("This warp doesn't lead anywhere yet.", "Info")

		DblClick()
			if(usr) RenameWarpTurf(src, usr)

// ------------------------------------------------------
// Hazard terrain — damage on step
// ------------------------------------------------------
// CONFIRMED the OG had these: its own type list carries /turf/grass/swamp with an
// Entered() override, and lava alongside it. The remake had no damaging terrain at all
// (RemakeVsOGStructure.md Part 3.12), which meant a whole category of level design —
// making a route cost something rather than just blocking it — wasn't available.
//
// Damage is applied per STEP, not on a timer while standing. That's the simpler reading
// of the OG's Entered()-based implementation, and it keeps hazards predictable: crossing
// a five-tile swamp always costs exactly five ticks of damage regardless of how fast the
// player moves. A standing-still drain would also fight with the passive regeneration
// added in StatsDatum.dm in a way that isn't designed yet.
//
// PLACEHOLDER damage values throughout — no OG numbers recovered.
//
// This is a BEHAVIOR type, so it belongs here as a real subtype rather than a repainted
// instance (see this file's own convention note up top): the whole point is the
// Entered() override.
turf/hazard
	// Flat HP lost per step onto this tile.
	var/stepDamage = 5
	// Shown to whoever steps on it. Kept per-type so lava and swamp read differently.
	var/hazardMessage = "The ground burns!"
	// % chance per step to also inflict poison (StatusEffects.dm). Swamps use this;
	// lava doesn't.
	var/poisonChance = 0

	Entered(atom/movable/A)
		..()
		if(!ismob(A)) return
		var/mob/M = A
		if(M.HP <= 0 || M.isDead) return
		// Ghosted GMs pass through the world untouched (GM_GhostForm, GMCommands.dm) —
		// they have no business taking terrain damage while observing.
		if(M.isGhostform) return
		// Amulet of Safe Passage (obj/item/amulet/stepguard, Inventory.dm).
		if(M.equipHazardImmune) return

		// Direct HP change rather than TakeDamage(), for the same reason poison does it
		// (StatusEffects.dm): TakeDamage() would roll RollDodge(), and terrain isn't
		// something you dodge. Death still routes through the real pipeline below so
		// nothing is skipped by going around it.
		M.HP -= stepDamage
		flick("hit", M)
		PlaySFXAt(M, istype(M, /mob/enemy) ? 'enemyhit.wav' : 'hit.wav')
		M << output("<font color='red'>[hazardMessage] (-[stepDamage] HP)</font>", "Info")
		ShowCombatNumber(M, "[stepDamage]", "#ff0000")
		M.ShowFloatingHPBar()

		if(poisonChance && prob(poisonChance))
			M.ApplyStatusEffect(/datum/status_effect/poison)

		if(M.HP <= 0)
			M.Die(null)  // no attacker to credit — terrain isn't a mob
			M.CleanUpDead()

turf/hazard/lava
	name = "lava"
	icon = 'floor.dmi'
	icon_state = "burntcobble"  // ART PLACEHOLDER: no lava sprite exists in World Icons/
	                             // yet, so this borrows the scorched-floor state. Repaint
	                             // as a map instance once real lava art is drawn.
	stepDamage = 15
	hazardMessage = "The lava scorches you!"

turf/hazard/swamp
	name = "swamp"
	icon = 'grass.dmi'
	icon_state = "swamp"
	stepDamage = 3
	hazardMessage = "The swamp saps your strength!"
	poisonChance = 15  // PLACEHOLDER — classic Dragon Warrior swamps poison, and the
	                    // remake already has a poison effect to reach for