// -----------------------------
// Spell Projectiles
// -----------------------------
// Base moving-projectile entity for ranged spells (confirmed design, see
// TODOList.md's "Real spell system" entry). A projectile is spawned already facing
// its travel direction (see datum/skill/SpellBolt, SkillCatalog.dm) and Launch()es itself:
// steps forward one tile at a time, checking for a valid target (whoever the caster
// may hurt — CanHarm(), CombatSystem.dm, which applies coop mode and friendly fire) or
// a dense obstacle, stopping and showing an impact icon_state either way. Falls off the
// edge of the map cleanly if it never hits anything.

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
	var/flashOnWall = TRUE  // FALSE = the impact art is for mobs only; a wall just
	                        // swallows the shot (ThunderSword's bolt)
	var/blockedByMobs = FALSE  // TRUE = any solid mob it can't hurt (an ally) stops it
	                           // too, with no impact art -- a dodger still lets it by
	var/maxRange = 0  // tiles it may travel past its spawn tile; 0 = until it hits something
	var/list/alreadyHit  // piercing shots: each mob is hit at most once per shot

	// Shared with SpawnHazardBlob() (HazardFields.dm) — the real check lives in
	// IsTurfBlocked() (CombatSystem.dm) so "what stops a spell" is defined once.
	proc/IsTileBlocked(turf/T)
		return IsTurfBlocked(T)

	// Called once, on the open tile where the shot ends -- a landed hit, the tile in
	// front of a wall or blocking mob, the end of its range, or the map edge. Not called
	// when it spawns point-blank inside a wall. A burst spell detonates here.
	proc/Finish(turf/T)
		return

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
			if(IsTileBlocked(currentTurf))
				if(flashOnWall) FlashTurfEffect(currentTurf, icon, impactIconState)
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
				// A dodge (landed == FALSE) never stops the shot, pierces or not —
				// nothing actually hit, so there's no reason for it to stop here.
				// Only a landed, non-piercing hit consumes the projectile; a landed
				// piercing hit or a dodge both fall through and keep flying, giving
				// it a real chance at whoever's standing beyond this target.
				var/landed = Impact(currentTurf, hitTarget)
				if(landed && pierces)
					if(!alreadyHit) alreadyHit = list()
					alreadyHit += hitTarget
				if(landed && !pierces)
					Finish(currentTurf)
					del src
					return
			else if(blockedByMobs && HasSolidMob(currentTurf))
				Finish(currentTurf)
				del src
				return

			if(maxRange && traveled >= maxRange)
				Finish(currentTurf)
				del src
				return

			var/turf/nextTurf = get_step(src, travelDir)
			if(!nextTurf)
				Finish(currentTurf)
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
				if(flashOnWall) FlashTurfEffect(nextTurf, icon, impactIconState)
				Finish(currentTurf)
				del src
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

	// Returns whether the shot actually landed (see TakeDamage()'s own note,
	// CombatSystem.dm) — Launch() uses this to decide whether to stop here or keep
	// flying. A dodged target doesn't get an impact flash either: nothing was hit,
	// so nothing should visibly explode on their tile while the projectile flies on
	// past them.
	proc/Impact(turf/T, mob/target = null)
		// ApplySpellDamage() (CombatSystem.dm) already handles the elemental
		// weakness/resistance modifier and routes into TakeDamage() (dodge, hit
		// sound, death) — this reuses that whole pipeline rather than duplicating it.
		var/landed = (target && caster) ? caster.ApplySpellDamage(target, damage, element) : FALSE
		if(landed)
			FlashTurfEffect(T, icon, impactIconState)
		return landed
