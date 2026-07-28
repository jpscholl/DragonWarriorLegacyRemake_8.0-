// -----------------------------
// Spell Projectiles
// -----------------------------
// Base moving-projectile entity for ranged spells (confirmed design, see
// TODOList.md's "Real spell system" entry). A projectile is spawned already facing
// its travel direction (see datum/skill/Blaze, SkillDatum.dm) and Launch()es itself:
// steps forward one tile at a time, checking for a valid target (opposing side only —
// player-fired hits enemies, enemy-fired hits players, never same-side, matching the
// confirmed no-friendly-fire coop-area rule) or a dense obstacle, stopping and showing
// an impact icon_state either way. Falls off the edge of the map cleanly if it never
// hits anything.

// Shows a short-lived impact effect on a turf. Deliberately a FREE-STANDING proc, not
// a proc on /obj/projectile — that was a real bug: the cleanup used to run in a
// spawn() block owned by the projectile, and Launch()'s `del src` immediately after
// impact killed that pending block before it could fire, so the "blazehit" overlay
// stayed on the turf forever (confirmed in playtest against walls). A global proc has
// no src to delete, so its cleanup always runs. Precedent for free-standing procs in
// this codebase: IsCardinallyAdjacent() in CombatSystem.dm.
proc/FlashTurfEffect(turf/T, iconFile, iconState, duration = 3)
	set waitfor = 0
	if(!T || !iconFile || !iconState) return

	var/image/fx = image(iconFile, T, iconState)
	fx.layer = 6  // just above /obj/projectile's own layer (5, below) so the burst
	               // draws over anything on the tile rather than behind it
	T.overlays += fx
	sleep(duration)
	T.overlays -= fx

obj/projectile
	icon = 'spells.dmi'
	density = FALSE  // shouldn't physically block movement/collide like a wall
	layer = 5

	var/mob/caster
	var/element = null
	var/damage = 0
	var/travelDir = SOUTH
	var/stepDelay = 0.65  // deciseconds between tile-steps. MUST stay well below the
	                       // player's own step_delay (1.36, SmoothMovement.dm) or the
	                       // spell can literally be outrun — which is exactly what
	                       // happened in the first playtest, when this was ~3. Lower =
	                       // faster. Set per-launch by whatever skill spawns this.
	var/pierces = FALSE  // confirmed per-skill, not universal — Blaze stops on its
	                       // first hit; a future skill like Thornwhip would set this
	                       // TRUE instead of needing a whole separate projectile type
	var/impactIconState = null

	// A dense turf blocks on its own (walls), but dense OBJS sitting on a non-dense
	// turf — closed doors, signs — didn't stop anything, since only turf.density was
	// ever checked. Doors also toggle density at runtime (open/close), so this has to
	// check live obj state each pass rather than anything static.
	proc/IsTileBlocked(turf/T)
		if(T.density) return TRUE
		for(var/obj/O in T.contents)
			if(O.density) return TRUE
		return FALSE

	proc/Launch()
		set waitfor = 0
		dir = travelDir
		while(src)
			var/turf/currentTurf = loc
			if(!currentTurf)
				del src
				return

			// Point-blank into a wall/door/sign — only reachable on the very first
			// iteration, since the look-ahead below stops us before entering a
			// blocked tile otherwise.
			if(IsTileBlocked(currentTurf))
				FlashTurfEffect(currentTurf, icon, impactIconState)
				del src
				return

			// Check the tile we're STANDING ON before moving. This is what makes an
			// adjacent target work: the projectile spawns on the tile directly in
			// front of the caster, so if an enemy is right there it has to be caught
			// here — the look-ahead below would skip straight past them. That was a
			// real bug (projectile spawned under an adjacent monster and flew through
			// it) found in the first playtest.
			var/mob/hitTarget = FindTarget(currentTurf)
			if(hitTarget)
				Impact(currentTurf, hitTarget)
				if(!pierces)
					del src
					return

			var/turf/nextTurf = get_step(src, travelDir)
			if(!nextTurf)
				del src  // ran off the edge of the map — no impact effect
				return

			// Safety valve: if we somehow aren't actually advancing (e.g. travelDir
			// ended up 0/invalid), bail instead of looping forever on one tile as an
			// undeletable object. Shouldn't happen — travelDir comes from a mob's dir —
			// but a stuck immortal projectile would be a nasty thing to track down.
			if(nextTurf == currentTurf)
				del src
				return

			// Look ahead for walls/doors/signs so the projectile visually stops AT
			// the obstacle rather than briefly drawing on top of it.
			if(IsTileBlocked(nextTurf))
				FlashTurfEffect(nextTurf, icon, impactIconState)
				del src
				return

			loc = nextTurf
			sleep(stepDelay)

	// Opposing side only — player-fired hits enemies, enemy-fired hits players, never
	// the same side as the caster (no friendly fire, matches confirmed coop-by-default,
	// Area.dm). Skips anything already dead so a projectile doesn't "hit" a corpse
	// that's just lingering before CleanUpDead() removes it.
	proc/FindTarget(turf/T)
		var/casterIsEnemy = istype(caster, /mob/enemy)
		for(var/mob/M in T.contents)
			if(M.HP <= 0) continue
			if(istype(M, /mob/enemy) == casterIsEnemy) continue
			return M
		return null

	proc/Impact(turf/T, mob/target = null)
		FlashTurfEffect(T, icon, impactIconState)

		// ApplySpellDamage() (CombatSystem.dm) already handles the elemental
		// weakness/resistance modifier and routes into TakeDamage() (dodge, hit
		// sound, death) — this reuses that whole pipeline rather than duplicating it.
		if(target && caster)
			caster.ApplySpellDamage(target, damage, element)

	// Blaze's own projectile — icon_state "blaze" for the traveling sprite, "blazehit"
	// for the impact effect (both in spells.dmi, confirmed to already exist).
	blaze
		icon_state = "blaze"
		impactIconState = "blazehit"
