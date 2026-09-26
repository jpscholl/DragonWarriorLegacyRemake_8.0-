// -----------------------------
// Projectiles
// -----------------------------
// Base moving projectile. Spawned already facing its travel direction by whatever fires
// it (SpellBolt and BoltSword, SkillCatalog.dm), then Launch()es itself: one tile at a
// time, checking each tile for a mob the caster may hurt (CanHarm(), CombatSystem.dm --
// coop mode and friendly fire) and looking ahead for walls. Subtypes decide what a hit
// does (Impact()) and what happens where the flight ends (Finish()).
//
// Hit art only ever shows on a landed hit on a mob -- a wall, an ally or the map edge
// just ends the flight.

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
	                       // faster. Set per-launch by whatever fires it.
	var/pierces = FALSE        // TRUE = a landed hit doesn't stop it (Infernos, Infermore)
	var/impactIconState = null // spells.dmi state flashed by the default Impact()
	var/blockedByMobs = FALSE  // TRUE = any solid mob it can't hurt (an ally) stops it
	                           // too, with no impact art -- a dodger still lets it by
	var/maxRange = 0  // tiles it may travel past its spawn tile; 0 = until it hits something
	var/list/alreadyHit  // piercing shots: each mob is hit at most once per shot

	// Called once, on the open tile where the shot ends -- a landed hit, the tile in
	// front of a wall or blocking mob, the end of its range, or the map edge. Not called
	// when it spawns point-blank inside a wall. A burst spell detonates here.
	proc/Finish(turf/T)
		return

	// Called before every step, so a subtype may change travelDir mid-flight (a homing
	// spell). Base: flies straight.
	proc/Steer()
		return

	proc/End(turf/T)
		Finish(T)
		del src

	proc/Launch()
		set waitfor = 0
		dir = travelDir
		var/traveled = 0
		while(src)
			var/turf/currentTurf = loc
			if(!currentTurf)
				del src
				return

			// Point-blank into a wall/door/sign — only reachable on the very first
			// iteration, since the look-ahead below stops us before entering a
			// blocked tile otherwise.
			if(IsTurfBlocked(currentTurf))
				del src
				return

			// Check the tile we're STANDING ON before moving. The projectile spawns on
			// the tile directly in front of the caster, so an adjacent enemy has to be
			// caught here — the look-ahead below would skip straight past them (a real
			// bug from the first playtest).
			var/mob/hitTarget = FindTarget(currentTurf)
			if(hitTarget)
				// Only a landed, non-piercing hit consumes the projectile. A dodge never
				// stops it, and a piercing hit remembers the victim and flies on.
				var/landed = Impact(currentTurf, hitTarget)
				if(landed && !pierces)
					End(currentTurf)
					return
				if(landed)
					if(!alreadyHit) alreadyHit = list()
					alreadyHit += hitTarget
			else if(blockedByMobs && HasSolidMob(currentTurf))
				End(currentTurf)
				return

			if(maxRange && traveled >= maxRange)
				End(currentTurf)
				return

			Steer()
			var/turf/nextTurf = get_step(src, travelDir)
			// Off the map edge, or (safety valve) not actually advancing because
			// travelDir ended up invalid -- a stuck immortal projectile would be a nasty
			// thing to track down.
			if(!nextTurf || nextTurf == currentTurf)
				End(currentTurf)
				return

			// Look ahead for walls/doors/signs so the projectile visually stops AT
			// the obstacle rather than briefly drawing on top of it.
			if(IsTurfBlocked(nextTurf))
				End(currentTurf)
				return

			loc = nextTurf
			traveled++
			sleep(stepDelay)

	proc/HasSolidMob(turf/T)
		for(var/mob/M in T)
			if(M == caster || M.HP <= 0 || !M.density) continue
			return TRUE
		return FALSE

	// Only mobs the caster is allowed to hurt (CanHarm(), CombatSystem.dm -- coop mode
	// and friendly fire); anyone else, the shot flies past. Skips anything already dead
	// so a projectile doesn't "hit" a corpse that's just lingering before CleanUpDead()
	// removes it.
	proc/FindTarget(turf/T)
		if(!caster) return null
		for(var/mob/M in T.contents)
			if(M.HP <= 0) continue
			if(alreadyHit && (M in alreadyHit)) continue
			if(!caster.CanHarm(M)) continue
			return M
		return null

	// Returns whether the shot actually landed (TakeDamage(), CombatSystem.dm) —
	// Launch() uses this to decide whether to stop here or keep flying. The default is a
	// spell hit; subtypes swap in their own (a sword bolt's physical hit, a SpellBolt's
	// status or burst). A dodged target gets no hit flash -- nothing was hit.
	proc/Impact(turf/T, mob/target = null)
		var/landed = (target && caster) ? caster.ApplySpellDamage(target, damage, element) : FALSE
		if(landed) FlashSkillFX(T, impactIconState, IMPACT_FX_DURATION)
		return landed

// One homing step from `origin` toward `dest`: straight at it, diagonals included, but never
// cutting a wall's corner. A blocked diagonal falls back to the target's longer axis,
// then its shorter one. If every way is blocked it still returns the direct line, so
// the projectile's own look-ahead ends the flight at the wall. 0 = already on its tile.
proc/HomingStepDir(atom/origin, atom/dest)
	var/direct = get_dir(origin, dest)
	if(!direct) return 0

	var/list/tries = list()
	if(direct & (direct - 1))  // diagonal
		var/vert = direct & (NORTH|SOUTH)
		var/horiz = direct & (EAST|WEST)
		if(!IsTurfBlocked(get_step(origin, vert)) && !IsTurfBlocked(get_step(origin, horiz)))
			tries += direct
		if(abs(dest.x - origin.x) >= abs(dest.y - origin.y))
			tries += horiz
			tries += vert
		else
			tries += vert
			tries += horiz
	else
		tries += direct

	for(var/tryDir in tries)
		if(!IsTurfBlocked(get_step(origin, tryDir))) return tryDir
	return direct
