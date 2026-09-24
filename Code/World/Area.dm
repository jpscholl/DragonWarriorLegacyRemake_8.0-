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

	// TRUE = inside this area, each turf's own `opacity` actually controls line of
	// sight. FALSE (the default) = it doesn't, and setting opacity on a turf here does
	// nothing at all.
	//
	// That sounds backwards until you know why SEE_THRU exists. Every mob carries
	// sight = SEE_THRU by default (PlayerTemplate.dm), meaning "ignore opacity" — which
	// the roof trick below depends on, since it needs outdoor viewers to see straight
	// through a building's opaque shell. But SEE_THRU is all-or-nothing per mob: there's
	// no way to ignore a building's walls while still respecting a cave's. So honest
	// per-turf opacity has to be switched on somewhere, and the area a mob is standing
	// in is the only thing that can do it.
	//
	// Entered()/Exited() below strip and restore SEE_THRU accordingly. Set it on any
	// area where you want to place a wall, tick its opacity in the map editor, and have
	// that mean what it says.
	var/respectWallOpacity = FALSE

	// For most areas, icon/icon_state exist purely as debug data for GM_SeeAreas'
	// overlay (GMCommands.dm) -- normal players never see them, since ordinary
	// floor/wall turfs already carry their own real art. A subtype (rave, below) that
	// sets this TRUE is different: its icon_state IS real decoration meant to render
	// for everyone, all the time, with no GM tool required.
	var/showAreaVisual = FALSE

	// 0 (default) means every client sees the decoration, same as before -- rave etc.
	// don't set this. area/ceiling/visible sets it to 1 so the roof art itself
	// respects the same see_invisible split as everything else in the ceiling system:
	// visible outdoors (see_invisible 1), hidden the moment you cross into area/ceiling
	// (see_invisible 0), which is what actually reveals the walls/floor/mobs beneath.
	// MUST be a real standalone /obj (below), not a /image added to turf.overlays --
	// tested 2026-09-09 and confirmed an overlay image's own invisibility is NOT
	// filtered per-viewer against mob.see_invisible the way a real atom's is (the roof
	// kept showing even after see_invisible correctly dropped to 0 on Entered()). A real
	// obj gets the same per-mob invisibility filtering GM_GhostForm/GHOST_INVISIBILITY
	// already rely on elsewhere (GMCommands.dm).
	var/visualInvisibility = 0

	// Applies (or reapplies) this area's own icon/icon_state as a real decoration on
	// one of its turfs -- called for every turf already present when this area instance
	// is created (New() below, covers a compiled map that starts with tiles already
	// assigned) and again whenever a GM paints a new tile into this area at runtime
	// (PlaceBuildSelection()'s "area" branch, BuildTools.dm). No-op unless
	// showAreaVisual is set.
	proc/AddedTurf(turf/T)
		if(!showAreaVisual || !T || !icon_state) return
		if(T.areaVisualOverlay) del T.areaVisualOverlay
		var/obj/AreaVisual/V = new(T)
		V.icon = icon
		V.icon_state = icon_state
		V.layer = AREA_OVERLAY_LAYER
		V.invisibility = visualInvisibility
		T.areaVisualOverlay = V

	New()
		. = ..()
		if(showAreaVisual)
			for(var/turf/T in contents)
				AddedTurf(T)

	Entered(atom/movable/O)
		..()
		if(ismob(O))
			var/mob/M = O
			// See respectWallOpacity's own comment above — strip the viewer's SEE_THRU
			// bypass so this area's turfs' own opacity actually stops their sight,
			// instead of silently doing nothing like it does everywhere else.
			if(respectWallOpacity) M.sight &= ~SEE_THRU

			// Curse night (isCurseNight, Main.dm) overrides every area's own music for
			// its duration — without this check, walking into a new area mid-curse-night
			// would immediately switch back to that area's normal track.
			if(isCurseNight)
				M.PlayAreaMusic(CURSE_NIGHT_MUSIC)
			else if(areaMusic)
				M.PlayAreaMusic(areaMusic)

	// Restores SEE_THRU on the way out of a respectWallOpacity area — but only if the
	// destination isn't ALSO one, same "don't flicker sight on between two adjoining
	// instances of the same kind of area" guard area/ceiling/Exited() below uses for its
	// own opacity mechanism. Two respectWallOpacity areas bordering each other (e.g. a
	// cave that spans multiple area instances) should read as one continuous "opacity is
	// honest here" zone, not toggle a player's sight back and forth at every seam.
	Exited(atom/movable/O, atom/newloc)
		..()
		if(!respectWallOpacity) return
		if(ismob(O))
			var/mob/M = O
			var/turf/T = newloc
			var/area/destArea = T ? T.loc : null
			if(destArea && destArea.respectWallOpacity) return
			M.sight |= SEE_THRU

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
		// The void border wall around cave interiors is painted with opacity = 1 in the
		// map editor — this is what makes that setting actually count (respectWallOpacity's
		// own comment above), so a player standing in a cave can no longer see straight
		// through that wall to whatever's beyond it. Interior cavewall tiles are left at
		// their default (non-opaque), same as an ordinary wall elsewhere in the game.
		respectWallOpacity = TRUE

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
			// Skipped during a curse night (isCurseNight, Main.dm) -- the curse track is
			// meant to play continuously across every area, bar included, so cutting
			// channel 1 here would silence it right before the next area's Entered()
			// (PlayAreaMusic(), above) no-ops anyway since it wants that same track back.
			if(isCurseNight) return
			if(ismob(O))
				var/mob/M = O
				if(M.client)
					M.client << sound(null, channel = 1)
					// Without this, current_music still claims whatever was playing here
					// is still audible, so the next area's Entered() (PlayAreaMusic(),
					// above) silently no-ops if that area happens to want the same
					// track — normally never true outside a curse night (guarded above).
					M.current_music = null

	jail
		icon_state = "jail"

	rain
		icon_state = "rain"

	rainnight
		icon_state = "rainnight"

	// The OG roof trick uses two nested areas: "ceiling" is the outer buffer (painted
	// ~1 tile past the walls, no roof art on it) and "ceiling/visible" is the inner
	// footprint where the roof art actually renders (via showAreaVisual/AddedTurf
	// above). Being a subtype, "visible" inherits Entered()/Exited() below for free —
	// stepping into the outer buffer already flips see_invisible, so every roof overlay
	// still in view (even tiles you haven't physically reached yet) disappears for you
	// at once, revealing the walls/floor/mobs beneath. istype(A, /area/ceiling)
	// elsewhere in the codebase (GMCommands.dm's ghost toggle, DeliverChat's
	// indoor/outdoor chat split) matches both this area and "visible", since istype()
	// includes subtypes.
	ceiling
		icon_state = "ceiling"
		var
			has_ceiling = 1

		// This area IS the building's boundary shell, so every tile of it blocks light
		// (= line of sight) -- walls and the door tile alike. Doing it by area rather
		// than by turf type matters: the door is a turf/ground, and leaving it
		// non-opaque left one gap that you could still see the outside world through.
		// The inner footprint (visible, below) overrides this back to a no-op, since
		// those are the floor tiles you're meant to see across while standing inside.
		//
		// Scoped to this area on purpose -- this FORCES every turf here opaque
		// regardless of what's painted on it, unlike respectWallOpacity (area's own var,
		// used by area/cave) which just lets each turf's own opacity setting count. An
		// ordinary wall outside both mechanisms stays non-opaque by default, or opaque-
		// but-inert if someone paints it that way outside a respectWallOpacity area.
		//
		// Opacity is NOT per-viewer -- an opaque tile blocks light for everyone equally,
		// and there's no way to change that. The one-way behaviour comes from the other
		// side instead: outdoor mobs carry SEE_THRU (PlayerTemplate.dm) and see straight
		// through this shell as though it weren't opaque at all, while Entered() below
		// strips SEE_THRU from whoever is inside -- so the shell stops THEIR view outward
		// and nobody else's. That's why this works on any building shape or size without
		// tuning: it's the real wall geometry doing the work, via BYOND's own LOS.
		proc/ApplyBoundaryOpacity(turf/T)
			if(T) T.opacity = 1

		New()
			. = ..()
			for(var/turf/T in contents)
				ApplyBoundaryOpacity(T)

		// Covers a GM painting a new tile into this area at runtime too --
		// PlaceBuildSelection() (BuildTools.dm) calls AddedTurf() on the target area.
		AddedTurf(turf/T)
			. = ..()
			ApplyBoundaryOpacity(T)

		Entered(mob/M) //when you enter the house you will not see the roof any more
			..()  // area/Entered()'s music handling — without this, walking into any
			      // roofed building skipped the areaMusic/curse-night switch entirely,
			      // since this override replaced it rather than extending it
			if(ismob(M)) //if your a mob
				M.see_invisible = 0 //keep these variables here or this will not work
				M.sight &= ~SEE_THRU  // normal sight: these walls now stop your view outward

		// newloc matters here: the outer buffer (this area) and the inner roof
		// footprint (visible, below) are separate area instances, so walking between
		// them -- e.g. off the interior floor and onto the door tile -- fires this
		// Exited() even though you're still fully inside the building. Only actually
		// treat it as leaving if the destination isn't ceiling territory either.
		Exited(mob/M, atom/newloc)
			..()
			if(ismob(M)) //if your a mob
				var/turf/T = newloc
				var/area/destArea = T ? T.loc : null
				if(istype(destArea, /area/ceiling)) return
				M.see_invisible = 1 //keep these variables here or this will not work
				M.sight |= SEE_THRU   // back outside: roofed walls stop blocking you again

		// The actual roof footprint. showAreaVisual+visualInvisibility (above) paint
		// icon/icon_state's art on every turf here, visible outdoors and hidden the
		// instant a viewer's own see_invisible drops to 0 (Entered() above). icon is
		// overridden to wall.dmi -- environment.dmi (the area default) has no real roof
		// art, it's only ever used as GM_SeeAreas debug data on other area types.
		visible
			icon = 'wall.dmi'
			icon_state = "ceiling"
			showAreaVisual = TRUE
			visualInvisibility = 1

			// Opt out of the boundary opacity inherited from ceiling above -- these are
			// the interior floor tiles, the ones you're supposed to see across while
			// standing inside. Only the outer shell blocks.
			ApplyBoundaryOpacity(turf/T)
				return

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
		showAreaVisual = TRUE  // the rave decoration itself, not debug data — visible to everyone, no GM_SeeAreas needed


// -----------------------------
// World spawn markers — confirmed OG names "playerstart" (login) / "playerspawn"
// (after-death respawn), confirmed distinct from each other. Built as plain OBJECTS,
// not areas — a turf only ever belongs to ONE area, so an area-based marker painted
// onto an existing Town/Dungeon tile would silently strip its real area's music/
// battle-mode/everything else. An object sitting on top of a tile doesn't touch its
// area at all.
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

// Finds a random tile with a marker of the given type on it, instead of a hardcoded
// coordinate baked into the code. Multiple markers of the same type pool together.
// Falls back to PLAYER_SPAWN (the old hardcoded coordinate) with a log line if the map
// has no such marker yet, so it doesn't strand a spawning/respawning player.
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
