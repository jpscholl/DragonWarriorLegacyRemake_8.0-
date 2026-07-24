// -----------------------------
// Enemy NPCs
// -----------------------------
// Basic AI: see a player in range, lock onto them, chase, attack when adjacent, flee
// once low on HP. Un-locks when the target dies or flees out of sight range. Melee
// only for now — no ranged/spell attacks yet (deferred, see TODOList.md Phase 6).
//
// HOW THIS FILE FITS TOGETHER — two independent loops, started once in New():
//
//   AILoop() — the "brain." Runs every aiTickDelay (slow, currently 1s). Each tick it
//   decides WHAT the enemy should be doing right now — acquire/drop a target, and set
//   moveIntent to one of ENEMY_MOVE_NONE/CHASE/FLEE — but never moves anything itself.
//   This is also where an actual melee swing happens, when already adjacent.
//
//   MovementLoop() — the "body." Runs every world.tick_lag (fast, same cadence as a
//   player's own client/MoveLoop(), SmoothMovement.dm). Each tick it just looks at
//   whatever moveIntent/target AILoop() last set and takes one step accordingly, via
//   StepRelativeTo(). Splitting brain/body this way is what makes movement flow
//   continuously instead of one visible glide-step per (much slower) AI decision —
//   see MovementLoop()'s own comment for the whole story on why that split exists.
//
// Everything else in the file is a helper called by one of those two loops:
// StepRelativeTo() (single-step movement + wall-hugging obstacle avoidance) and
// Wander() (idle random movement, called directly from AILoop() since it doesn't need
// MovementLoop()'s fast cadence).
#define ENEMY_MOVE_NONE 0
#define ENEMY_MOVE_CHASE 1
#define ENEMY_MOVE_FLEE 2

mob/enemy
	pixel_y = SPRITE_PIXEL_Y_OFFSET  // Main.dm — same vertical offset as players, so
	                                  // attack overlays/animations line up correctly

	// step_delay (base mob var, SmoothMovement.dm) controls both glide speed and how
	// often Step() actually allows a step — inherited default (1.36) matched a
	// player's own walking speed exactly, which felt too fast for a slime. Bigger
	// number = slower. Tune per-species later if some monster should be quicker.
	step_delay = 2.8

	var/mob/player/target
	var/moveIntent = ENEMY_MOVE_NONE  // set by AILoop() (slow "decision" cadence),
	                                    // consumed every tick by MovementLoop() (fast
	                                    // "execution" cadence) — same split as the
	                                    // player's move_dir + client/MoveLoop()
	                                    // (SmoothMovement.dm), which is what actually
	                                    // gives players their continuous glide instead
	                                    // of one step per decision.
	var/sightRange = 7    // tiles — placeholder, tune later. Detection below uses
	                        // range(), not view(), so this sees through walls/obstacles
	                        // on purpose rather than requiring line of sight.
	var/attackRange = 1   // tiles — must be CARDINALLY adjacent to attack (see
	                        // IsCardinallyAdjacent(), CombatSystem.dm) — plain
	                        // get_dist()/Chebyshev distance would also count a
	                        // diagonal neighbor as "adjacent," which this 4-directional
	                        // game doesn't want.
	var/aiTickDelay = 10   // deciseconds between AI decision ticks (targeting, threat
	                         // eval, chase-vs-flee-vs-attack choice) — NOT how often it
	                         // actually steps (see MovementLoop() below, which runs
	                         // every world.tick_lag regardless, for smooth continuous
	                         // movement); this is just how often it reconsiders WHAT to
	                         // do. Was 5 (0.5s) — felt too twitchy/reactive.
	var/attackCooldown = 10  // deciseconds between attacks once adjacent — enemies use
	                          // their own flat cooldown rather than GetAttackDelay(),
	                          // which needs a real datum/skill and enemies don't use one
	var/wanderChance = 20  // % chance per idle tick (no target, or area isn't in battle
	                         // mode, checked every aiTickDelay) to take one random step —
	                         // averages roughly one step every ~5 seconds at the default
	                         // aiTickDelay, tune by feel. Simple placeholder "wandering"
	                         // idle behavior, not real pathfinding.
	var/fleeHealthPercent = 10  // HP% (of MaxHP) at or below which this enemy runs
	                              // instead of attacking — placeholder guess, tune later
	var/datum/skill/Attack/attackSkill  // not used for OnUse()/cooldown (enemies use
	                                      // their own attackCooldown var below) — this
	                                      // exists purely so PlayAttackAnimation()
	                                      // (CombatSystem.dm) has an isMelee/icon_state
	                                      // ("weapon") to read, same as a player's Attack
	var/avoidDir = 0  // 0 = not currently routing around an obstacle; else a cardinal
	                    // dir — see StepRelativeTo() below. Kept as instance state (not
	                    // recomputed fresh each tick) so an enemy commits to one side
	                    // once it starts skirting a wall instead of flip-flopping
	                    // between left/right every tick as the target's angle shifts.

	New()
		..()
		attackSkill = new
		AILoop()
		MovementLoop()

	// Runs forever once this enemy exists in the world — same polling-loop shape as
	// client/MoveLoop() in Code/Core/SmoothMovement.dm. Each tick: stop entirely once
	// dead (so a corpse just sits still until CombatSystem.dm's CleanUpDead() deletes
	// it), verify the current target is still alive and still in range (the
	// "deathcheck"/leash checks that clear a stale target), then decide whether to
	// flee/attack/chase a target or wander — but only while the area is actually in
	// battle mode (Code/World/Area.dm's battleModeOn); otherwise enemies stay peaceful
	// and just wander regardless of nearby players. This only sets moveIntent/target —
	// the actual stepping happens continuously in MovementLoop() below, decoupled from
	// this slower decision cadence.
	proc/AILoop()
		set waitfor = 0
		while(src)
			if(HP <= 0)
				moveIntent = ENEMY_MOVE_NONE
				return  // dead — CleanUpDead() (CombatSystem.dm) handles deletion

			if(target && target.HP <= 0)
				target = null

			// Drop target if they turn ghost mid-fight (GMghostIconform, GMCommands.dm)
			// — a GM shouldn't be able to get stuck fighting an enemy just because it
			// locked on before they ghosted.
			if(target && target.isGhostform)
				target = null

			// Give up the chase once the target flees past sightRange — without this,
			// a locked-on target was kept forever regardless of distance, so a slime
			// would chase clear across the map, making detection feel unbounded even
			// though initial acquisition below is capped at sightRange. Also doubles
			// as how a fleeing enemy "escapes" below.
			if(target && get_dist(src, target) > sightRange)
				target = null

			if(InBattleArea())
				if(!target)
					for(var/mob/player/P in range(sightRange, src))
						if(P.HP <= 0 || P.isDead || P.isGhostform) continue
						target = P
						break

				if(target)
					if(HP <= MaxHP * fleeHealthPercent / 100)
						// Low HP — run instead of fighting. No healing exists yet, so
						// the only way this ends is death or breaking sightRange (the
						// leash check above then drops target and this falls back to
						// wandering, i.e. successfully escaped).
						moveIntent = ENEMY_MOVE_FLEE
					else if(IsCardinallyAdjacent(src, target, attackRange))
						moveIntent = ENEMY_MOVE_NONE
						dir = get_dir(src, target)
						if(canAct)
							canAct = FALSE
							PlayAttackAnimation(src, attackSkill, target)
							PerformMeleeHit(null)
							spawn(attackCooldown)
								canAct = TRUE
					else
						moveIntent = ENEMY_MOVE_CHASE
				else
					moveIntent = ENEMY_MOVE_NONE
					Wander()
			else
				target = null  // area isn't in battle mode — drop aggro entirely
				moveIntent = ENEMY_MOVE_NONE
				Wander()

			sleep(aiTickDelay)

	// Continuously steps toward/away from target every tick, same cadence as the
	// player's client/MoveLoop() — this is what actually makes movement flow smoothly
	// instead of taking one glide-step per (much slower) AI decision tick.
	proc/MovementLoop()
		set waitfor = 0
		while(src)
			if(target && moveIntent != ENEMY_MOVE_NONE)
				StepRelativeTo(target, away = (moveIntent == ENEMY_MOVE_FLEE))
			sleep(world.tick_lag)

	// Takes one cardinal step toward Trg (or, if away = TRUE, directly away from it —
	// used for fleeing at low HP). NOT step_to() — BYOND's built-in tries a diagonal
	// step first whenever Trg isn't aligned on either axis, and Main.dm's mob/Move()
	// override silently blocks any diagonal dir (this game has no diagonal movement at
	// all), which left step_to() stuck rather than falling back to a cardinal step —
	// exactly why chasing only worked when already lined up N/S/E/W. This picks
	// whichever axis has the bigger gap and steps that way; if that step fails
	// (wall/obstacle), it falls back to the other axis the same tick. Uses the mob's
	// own Step() (SmoothMovement.dm), not the raw step() builtin — Step() sets
	// glide_size so movement animates smoothly between tiles like a player's, instead
	// of teleporting tile-to-tile. Also means an enemy mid-attack (canAct == FALSE,
	// same gate Step() already checks for players) stays rooted for its swing too.
	//
	// Obstacle handling: if both the direct route AND the secondary axis are blocked
	// (e.g. Trg is straight ahead behind a wall, so there IS no secondary axis to try),
	// picks a perpendicular direction and commits to it (avoidDir) — one sidestep per
	// tick, straight after — until the direct route opens up again. Simple wall-hugging,
	// not real pathfinding: it can still get stuck in a genuine dead end, but handles
	// the common case (a wall between the enemy and its target) without oscillating
	// side to side every tick the way recomputing fresh each time would.
	proc/StepRelativeTo(atom/Trg, away = FALSE)
		var/dx = Trg.x - x
		var/dy = Trg.y - y
		if(away)
			dx = -dx
			dy = -dy

		if(!dx && !dy)
			Step(pick(NORTH, SOUTH, EAST, WEST))  // standing exactly on Trg's tile
			                                        // (fleeing case only) — just pick
			                                        // a direction to break away
			return

		var/primaryDir
		var/secondaryDir
		if(abs(dx) >= abs(dy))
			if(dx) primaryDir = dx > 0 ? EAST : WEST
			if(dy) secondaryDir = dy > 0 ? NORTH : SOUTH
		else
			if(dy) primaryDir = dy > 0 ? NORTH : SOUTH
			if(dx) secondaryDir = dx > 0 ? EAST : WEST

		// Already committed to skirting an obstacle — keep re-trying the direct route
		// first (in case it's opened up), otherwise keep stepping the same way around
		// instead of re-picking a side every tick.
		if(avoidDir)
			if(primaryDir && Step(primaryDir))
				avoidDir = 0  // direct route is clear again
				return
			if(Step(avoidDir)) return
			avoidDir = 0  // even the avoid direction is blocked now — drop it, fall
			               // through to re-evaluate from scratch below

		if(primaryDir && Step(primaryDir)) return
		if(secondaryDir && Step(secondaryDir)) return

		// Direct route and secondary axis both blocked — start skirting. Perpendicular
		// to primaryDir: sidestep vertically around a horizontal obstacle, or
		// horizontally around a vertical one.
		if(primaryDir == EAST || primaryDir == WEST)
			avoidDir = pick(NORTH, SOUTH)
		else
			avoidDir = pick(EAST, WEST)
		Step(avoidDir)

	// Simple random idle movement — one cardinal step, occasionally. No real
	// pathfinding: bumping into a wall just fails the step silently and it tries again
	// on a later tick. Uses Step() (see StepRelativeTo() above) for the same
	// smooth-glide animation as the rest of enemy movement. Stays on the slower
	// AILoop() cadence, not MovementLoop() — wandering is meant to be occasional idle
	// steps, not continuous movement, so it doesn't need the fast tick.
	proc/Wander()
		if(prob(wanderChance))
			Step(pick(NORTH, SOUTH, EAST, WEST))

	slime
		icon = 'slime.dmi'
		icon_state = "world"
		Level = 1
		HP = 20
		MaxHP = 20
