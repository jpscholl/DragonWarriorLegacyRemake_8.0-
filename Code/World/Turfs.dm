//these are the collections of turf stuff that makes da world that you play in

// ------------------------------------------------------
// Convention: don't hardcode purely-visual turf variants
// ------------------------------------------------------
// A new type belongs here ONLY if it has different BEHAVIOR (a proc override, a var
// that actually does something — see turf/stairs, turf/furniture/bed* below for real
// examples). A tile that's just a different sprite of something that already exists
// should be painted as a map-editor INSTANCE instead (right click the type in the
// object tree -> New Instance... -> set icon_state), not a new hardcoded subtype. See
// Markdowns/CodeNotes.md for the 2026-07-21 turf collapse this convention came from.

// Sleeping state, used by the bedhead turf below. Moving at all wakes the player back
// up automatically — see Step() in Code/Core/SmoothMovement.dm.
mob/var/isSleeping = FALSE

// Named-pair teleport link — shared by turf/warp (its whole purpose) and any
// turf/stairs instance whose icon_state has no inferable up/down direction. Defaults
// to a coordinate string at creation so two freshly-placed, not-yet-linked points
// never accidentally match each other; a GM renames one (or both) via DblClick() to
// link them — same name = same pair.
turf/var/warpName = null

// Tracks whichever visible-to-everyone area decoration (area/AddedTurf(), Area.dm) is
// currently applied to this tile, if any — lets PlaceBuildSelection() (BuildTools.dm)
// cleanly remove the old one before a GM repaints the tile into a different area.
turf/var/image/areaVisualOverlay = null

// Areas always render on top of turfs — this is the one choke point that guarantees
// every brand-new turf (not just a repainted existing one) gets its owning area's
// decoration applied the instant it exists. See Markdowns/CodeNotes.md for why this
// matters (a freshly created turf instance starts with empty overlays regardless of
// what area already owns that cell).
turf/New()
	. = ..()
	var/area/A = loc
	if(A) A.AddedTurf(src)

turf/proc/EnsureWarpName()
	if(!warpName) warpName = "[x],[y],[z]"

// Finds another turf of the given family (istype-checked against baseType) sharing
// T's warpName — the other end of the pair. Doesn't cross families: a warp only links
// to another warp, a stairs warp-point only links to another stairs tile.
proc/FindWarpPartner(turf/T, baseType)
	if(!T || !T.warpName) return null
	for(var/turf/O in world)
		if(O == T) continue
		if(!istype(O, baseType)) continue
		if(O.warpName == T.warpName) return O
	return null

// Shared rename-prompt for any warp-linked turf — GM-only. Defaults the input to the
// current name so re-running it without typing anything new is a no-op.
proc/RenameWarpTurf(turf/T, mob/M)
	if(!T || !M || !M.client || !M.client.canBuild) return
	var/newName = input(M, "Name this warp point (give the other end the SAME name to link them):", "Name Warp", T.warpName) as text|null
	if(isnull(newName) || !length(trimtext(newName))) return
	T.warpName = trimtext(newName)
	M.ShowInfo("This is now named \"[T.warpName]\".")

// TEMPORARY VALUES — restore 1 of each per half second for a BED, expected to be
// retuned later.
#define BED_RESTORE_INTERVAL 5  // deciseconds — 0.5s
#define BED_RESTORE_AMOUNT 1    // HP and MP each, per interval

// Measured straight from the actual warp.wav file (44100Hz mono 8-bit PCM,
// 551235-byte data chunk / 44100 = ~12.502s) — turf/warp/Entered() below doesn't
// teleport the mob until the sound finishes, so this has to match the real clip
// length. Re-measure if warp.wav is ever replaced.
#define WARP_SOUND_DURATION 125  // deciseconds, ~12.5s

// Guards against two restore loops running at once (waking and immediately
// re-sleeping would otherwise double the heal rate) — same session-counter pattern as
// open_session (Obj.dm), pendingSession (SmoothMovement.dm), defendToggleSession
// (CombatSystem.dm).
mob/var/sleepSession = 0

// Guards turf/warp's Entered() against immediately re-triggering on arrival: moving
// M.loc to the partner tile fires THAT tile's Entered() synchronously, which would
// otherwise find its own partner (the tile you just left) and bounce you straight back.
mob/var/warpCooldown = FALSE

mob/proc/WakeUp()
	if(isSleeping)
		isSleeping = FALSE
		sleepSession++  // invalidates any in-flight SleepRestoreLoop()
		icon_state = "world"

// Started by bedhead's OnInteract() when a mob lies down. Self-terminates on wake.
// Takes its rate as arguments so the planned Rest skill can reuse it directly for
// slower on-the-ground recovery. Defaults are the bed rate.
mob/proc/SleepRestoreLoop(interval = BED_RESTORE_INTERVAL, amount = BED_RESTORE_AMOUNT)
	set waitfor = 0
	sleepSession++
	var/mySession = sleepSession

	while(src && isSleeping && sleepSession == mySession)
		sleep(interval)
		// Re-check after the sleep — may have woken/died/started a fresh session.
		if(!isSleeping || sleepSession != mySession) return
		if(isDead) return

		HP = min(MaxHP, HP + amount)
		MP = min(MaxMP, MP + amount)
		ShowFloatingHPBar()
		ShowFloatingMPBar()

//grass: dis is ground...you walk on it
// Default icon_state is "grass" — ground should never render as blank space. Any
// instance without an explicit override (including world.turf's fallback in Main.dm)
// falls back to this.
turf
	ground
		icon = 'grass.dmi'
		icon_state = "grass"
		density = 0

//floor: this is what you get on after you open the door and before you walk the dinosaur
	floor
		icon = 'floor.dmi'
		density = 0

//tables: don't flip these please
	furniture
		icon = 'table.dmi'
		density = 1
//interaction on a stove causes prompt to cook food (if in inventory) — not built yet
//interaction on a tub grabs glasses of water — not built yet

// -----------------------------
// Sleeping (beds) — only the LEFT (head/pillow) side is sleepable, by design;
// bedright/woodbedright are just the foot-of-bed visual.
// -----------------------------
		bedhead
			// Not meant to be placed directly on a map — bedleft/woodbedleft below
			// point to this via parent_type so both share the same behavior.
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

		// Kept as a real type — PlayerVerbs.dm's Interact() checks for this exact
		// type path to skip an extra tile ahead (able to interact with NPCs behind it).
		counter
			name = "counter"
			icon_state = "counter"

//Trees: the leafy things that provide oxygen
	tree
		icon = 'tree.dmi'
		density = 1

//stairs: no these aren't stairways to heaven just up or down a level
// Direction is inferred from icon_state itself (GetStairDirection() below) so every
// skin works regardless of which of the three types (stairs/stairsup/stairsdown) it's
// actually painted as an instance of.
	stairs
		icon = 'stairs.dmi'
		density = 0

		// GM-only per-TILE jump toggle (ToggleStairJump() below) — each stairs
		// instance remembers its own setting independently. Everyone else always
		// moves 1 level regardless.
		var/jumpLevels = 1

		New()
			..()
			EnsureWarpName()

		// +1/-1 for any skin whose icon_state names a direction (stoneup, wooddown,
		// icecaveup, etc). 0 for the ones that don't (castle/icecastle/black) — those
		// link by name instead, same mechanism as turf/warp.
		proc/GetStairDirection()
			if(findtext(icon_state, "up")) return 1
			if(findtext(icon_state, "down")) return -1
			return 0

		// M << sound(...), not view() — view()'s visibility filtering can exclude M
		// itself in edge cases (e.g. GM_GhostForm sets invisibility/icon = null),
		// silently swallowing the sound for exactly the mob it's meant for.
		proc/PlayStairSound(mob/M)
			M << sound('stairs.wav', repeat = 0, channel = SFX_CHANNEL, volume = M.client ? M.client.ScaledVolume() : 100)

		// Screen fade masks a teleport: fade to black, move while nothing's visible,
		// fade back in. Spawned so the caller's dispatch returns immediately instead
		// of blocking on the fade's sleep()s. Shared by both stairs paths below
		// (directional and name-linked) — they only differ in how `destination` is
		// found. Area/Entered() already plays new area music if it's a DIFFERENT area
		// instance — but stairs commonly land on a new z-level that's still the SAME
		// area instance, which never re-fires Entered(); this explicit re-check
		// covers that case (PlayAreaMusic() no-ops if already playing).
		proc/TeleportWithFade(mob/M, turf/destination)
			M.canAct = FALSE
			spawn(0)
				M.PlayScreenFade(TRUE)
				M.loc = destination
				var/area/newArea = destination.loc
				if(istype(newArea) && newArea.areaMusic)
					M.PlayAreaMusic(newArea.areaMusic)
				M.PlayScreenFade(FALSE)
				M.canAct = TRUE

		// Levels defaults to a plain walk-over (1); GMs can toggle THIS tile's own
		// jumpLevels via DblClick() below.
		proc/TakeStairs(mob/M, direction)
			if(!M) return
			var/levels = 1
			if(M.client && M.client.canBuild)
				levels = jumpLevels
			PlayStairSound(M)  // must fire BEFORE M.loc changes below
			var/turf/new_loc = locate(M.x, M.y, M.z + (direction * levels))
			if(!new_loc) return
			TeleportWithFade(M, new_loc)

		// GM-only: double-clicking a directional stairs tile flips THIS SPECIFIC
		// TILE's jumpLevels between 1 and 2 — every other stairs tile keeps its own
		// independent setting. Silent no-op for anyone without Builder access, since
		// this fires on every double-click of an ordinary world object. Reached two
		// ways: DblClick() below, and mob/DblClick() (PlayerVerbs.dm) for standing
		// directly on the stairs, where your own sprite is the topmost atom and the
		// click hits yourself instead of the turf underneath.
		proc/ToggleStairJump(mob/M)
			if(!M || !M.client || !M.client.canBuild) return
			jumpLevels = (jumpLevels == 1) ? 2 : 1
			var/dirWord = (GetStairDirection() > 0) ? "up" : "down"
			M.ShowInfo("This staircase will now move you [jumpLevels] level[jumpLevels == 1 ? "" : "s"] [dirWord] at a time.")

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
					TeleportWithFade(M, partner)
				else
					M.ShowInfo("This staircase doesn't lead anywhere yet.")

		// Directional skins toggle jump-levels; castle/icecastle/black have no
		// direction to toggle, so they get the rename prompt instead.
		DblClick()
			if(!usr) return
			var/direction = GetStairDirection()
			if(direction)
				ToggleStairJump(usr)
			else
				RenameWarpTurf(src, usr)

		stairsup
			name = "stairs"
			icon_state = "stoneup"

		stairsdown
			name = "stairs"
			icon_state = "stonedown"

//walls: all and all we're just another brick in the wall
	wall
		icon = 'wall.dmi'
		name = "wall"
		density = 1

//Fence: I'm still on the fence about this
	fence
		name = "fence"
		icon = 'wall.dmi'
		density = 1

//something about sky here idk I got nothing
	sky
		name = "sky"
		icon = 'sky.dmi'
		density = 0
		Entered(atom/movable/A)
			if(!ismob(A)) return
			var/mob/M = A
			// Already mid-fall — without this, walking across multiple sky tiles
			// during the delay re-triggered Entered() on each one, stacking falls.
			if(!M.canAct) return
			M.canAct = FALSE
			M << sound('fall.wav', repeat = 0, channel = SFX_CHANNEL, volume = M.client ? M.client.ScaledVolume() : 100)
			spawn(0)
				M.PlayScreenFade(TRUE)
				var/turf/new_loc = locate(M.x, M.y, M.z - 1)
				if(new_loc)
					M.loc = new_loc
				M.PlayScreenFade(FALSE)
				M.canAct = TRUE

//don't go burning these...how else you supposed to get across water?
	bridge
		name = "bridge"
		icon = 'bridge.dmi'
		density = 0

//that's some high quality h20
	water
		name = "water"
		icon = 'water.dmi'
		density = 1

//it teleports you duh — named-pair link (FindWarpPartner()/RenameWarpTurf(), top of
//file): a GM double-clicks two warp tiles and gives them the SAME name to link them.
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
			if(!partner)
				M.ShowInfo("This warp doesn't lead anywhere yet.")
				return

			M.warpCooldown = TRUE
			M.canAct = FALSE
			// Passable for the whole transition so other players can walk through a
			// mob mid-warp instead of queuing behind them.
			var/oldDensity = M.density
			M.density = 0
			spawn(0)
				M.PlayScreenFade(TRUE)
				// Cut the current area music so warp.wav plays alone.
				if(M.client) M.client << sound(null, channel = 1)
				M.current_music = null
				M << sound('warp.wav', repeat = 0, channel = SFX_CHANNEL, volume = M.client ? M.client.ScaledVolume() : 100)
				sleep(WARP_SOUND_DURATION)  // the teleport waits for the sound to finish
				M.loc = partner
				M.warpCooldown = FALSE
				M.PlayScreenFade(FALSE)
				var/area/newArea = partner.loc
				if(istype(newArea) && newArea.areaMusic)
					M.PlayAreaMusic(newArea.areaMusic)
				M.density = oldDensity
				M.canAct = TRUE

		DblClick()
			if(usr) RenameWarpTurf(src, usr)

// ------------------------------------------------------
// Hazard terrain — damage on step. See Markdowns/CodeNotes.md for OG-confirmation and
// design rationale (why per-step, not per-tick).
// ------------------------------------------------------
turf/hazard
	var/stepDamage = 5
	var/hazardMessage = "The ground burns!"
	var/poisonChance = 0  // % chance per step to also inflict poison; swamps use this, lava doesn't

	Entered(atom/movable/A)
		..()
		if(!ismob(A)) return
		var/mob/M = A
		if(M.HP <= 0 || M.isDead) return
		if(M.isGhostform) return
		if(M.equipHazardImmune) return

		// Direct HP change, not TakeDamage() — terrain isn't something you dodge.
		M.HP -= stepDamage
		flick("hit", M)
		PlaySFXAt(M, istype(M, /mob/enemy) ? 'enemyhit.wav' : 'hit.wav')
		M.ShowInfo("<font color='red'>[hazardMessage] (-[stepDamage] HP)</font>")
		ShowCombatNumber(M, "[stepDamage]", DAMAGE_NUMBER_COLOR)
		M.ShowFloatingHPBar()

		if(poisonChance && prob(poisonChance))
			M.ApplyStatusEffect(/datum/status_effect/poison)

		if(M.HP <= 0)
			M.Die(null)  // no attacker to credit — terrain isn't a mob
			M.CleanUpDead()

turf/hazard/lava
	name = "lava"
	icon = 'floor.dmi'
	icon_state = "burntcobble"  // ART PLACEHOLDER — no lava sprite exists yet
	stepDamage = 15
	hazardMessage = "The lava scorches you!"

turf/hazard/swamp
	name = "swamp"
	icon = 'grass.dmi'
	icon_state = "swamp"
	stepDamage = 3
	hazardMessage = "The swamp saps your strength!"
	poisonChance = 15
