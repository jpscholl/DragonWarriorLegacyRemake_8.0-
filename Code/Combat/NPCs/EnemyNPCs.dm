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
//   moveIntent to one of ENEMY_MOVE_NONE/CHASE/FLEE plus moveTowardAtom (the thing to
//   actually walk toward — not always the same as target, see pets below) — but never
//   moves anything itself. This is also where an actual melee swing happens, when
//   already adjacent.
//
//   MovementLoop() — the "body." Runs every world.tick_lag (fast, same cadence as a
//   player's own client/MoveLoop(), SmoothMovement.dm). Each tick it just looks at
//   whatever moveIntent/moveTowardAtom AILoop() last set and takes one step
//   accordingly, via StepRelativeTo(). Splitting brain/body this way is what makes
//   movement flow continuously instead of one visible glide-step per (much slower) AI
//   decision — see MovementLoop()'s own comment for the whole story on why that split
//   exists.
//
// Everything else in the file is a helper called by one of those two loops:
// StepRelativeTo() (single-step movement + wall-hugging obstacle avoidance) and
// Wander() (idle random movement, called directly from AILoop() since it doesn't need
// MovementLoop()'s fast cadence).
//
// PETS (your idea, 2026-08-01): any mob/enemy can become a pet — there's no separate
// pet type. A GM double-clicking a wild (unowned) one gets an "Assign Pet" option
// (ShowAssignPetMenu() below); picking a nearby player sets owner on that same mob
// instance, in place — same stats, same icon, no leveling system yet. Once owned,
// AILoop() routes every tick through HandlePetTick() instead of the wild logic below,
// branching on petMode (see PET_MODE_* below and ShowPetOwnerMenu()). Only one pet per
// owner for now (enforced in ShowAssignPetMenu()) — no roster/stable system yet.
#define ENEMY_MOVE_NONE 0
#define ENEMY_MOVE_CHASE 1
#define ENEMY_MOVE_FLEE 2

// Pet behavior modes (ShowPetOwnerMenu()'s "Set Mode" option) — what HandlePetTick()
// branches on every AILoop() tick once a mob/enemy has an owner.
#define PET_MODE_AGGRESSIVE 1  // hunts nearby unowned mob/enemy while the area's in
                                 // battle mode — the "helps you fight" mode
#define PET_MODE_SIT 2          // stays put, doesn't act
#define PET_MODE_WANDER 3       // reverts to plain wild-monster behavior, including
                                 // targeting players — a pet in this mode is not
                                 // guaranteed safe to be around, by design
#define PET_MODE_FOLLOW 4       // keeps pace with owner, never fights — default mode
                                 // a freshly-assigned pet starts in

#define PET_FOLLOW_DISTANCE 3  // tiles — how far a Follow/Aggressive-idle pet lets its
                                 // owner get before catching up

mob/enemy
	pixel_y = SPRITE_PIXEL_Y_OFFSET  // Main.dm — same vertical offset as players, so
	                                  // attack overlays/animations line up correctly

	// step_delay (base mob var, SmoothMovement.dm) controls both glide speed and how
	// often Step() actually allows a step — inherited default (1.36) matched a
	// player's own walking speed exactly, which felt too fast for a slime. Bigger
	// number = slower. Tune per-species later if some monster should be quicker.
	step_delay = 2.8

	var/mob/player/target
	var/mob/enemy/huntTarget  // PET_MODE_AGGRESSIVE's equivalent of target — separate
	                           // var because target is typed mob/player (wild AI only
	                           // ever chases players) and DM checks member access
	                           // against a var's declared type at compile time, so an
	                           // Aggressive pet's monster-hunting can't reuse it
	var/atom/moveTowardAtom  // what MovementLoop() actually steps toward this tick —
	                          // usually == target, but a Follow/idle-Aggressive pet
	                          // walks toward its owner while target stays null, so
	                          // these two needed to split apart (see pets, file header)
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
	                          // their own flat cooldown rather than GetAttackDelay()'s
	                          // stat-derived timing, deliberately: monster attack speed
	                          // is meant to be tuned per-species, not fall out of the
	                          // same Agility formula players use
	var/wanderChance = 20  // % chance per idle tick (no target, or area isn't in battle
	                         // mode, checked every aiTickDelay) to take one random step —
	                         // averages roughly one step every ~5 seconds at the default
	                         // aiTickDelay, tune by feel. Simple placeholder "wandering"
	                         // idle behavior, not real pathfinding.
	var/fleeHealthPercent = 10  // HP% (of MaxHP) at or below which this enemy runs
	                              // instead of attacking — placeholder guess, tune later
	var/datum/skill/Attack/attackSkill  // never driven through OnUse() (enemies use their
	                                      // own attackCooldown above instead of the skill's
	                                      // own timing), but it IS the skill datum passed to
	                                      // both PlayAttackAnimation() and PerformMeleeHit()
	                                      // (CombatSystem.dm) — the former reads isMelee/
	                                      // icon_state off it, the latter damage_multiplier.
	                                      // Those calls used to pass null for the hit, which
	                                      // became a hard runtime error the moment
	                                      // PerformMeleeHit() started reading a var off it.
	var/avoidDir = 0  // 0 = not currently routing around an obstacle; else a cardinal
	                    // dir — see StepRelativeTo() below. Kept as instance state (not
	                    // recomputed fresh each tick) so an enemy commits to one side
	                    // once it starts skirting a wall instead of flip-flopping
	                    // between left/right every tick as the target's angle shifts.

	// -----------------------------
	// Monster spellcasting
	// -----------------------------
	// The OG gave 20+ monsters their own Fight override and 33 distinct attack/spell
	// procs; every enemy here was melee-only until this. Rather than reproduce 33 bespoke
	// procs, a monster declares WHICH skills it can cast and the shared logic below picks
	// one — the same "everything is a skill" model players already use, pointed at the
	// existing datum/skill catalog (SkillCatalog.dm) instead of a parallel monster-only
	// implementation.
	//
	// castableSkills: typepaths this monster may cast offensively at its target.
	// healSkills:     typepaths it may cast to heal itself or a wounded ally.
	// Both are instantiated once in New() and reused, same as attackSkill.
	var/list/castableSkills = list()
	var/list/healSkills = list()
	var/list/datum/skill/spellInstances  // built in New() from the two lists above

	var/castChance = 35      // % chance per AI tick, when in range and off cooldown, to
	                           // cast instead of stepping/swinging. PLACEHOLDER — the OG's
	                           // own cast frequency isn't recovered yet.
	var/spellCooldown = 30   // deciseconds between casts. Separate from attackCooldown so
	                           // a caster can't chain spells at melee swing rate.
	var/lastCastTime = 0
	var/castRange = 5        // tiles it will cast from — deliberately longer than
	                           // attackRange, which is the whole point of a caster.
	// Below this HP fraction (of MaxHP) a monster is considered "wounded" and becomes a
	// valid heal target for itself or a nearby Healer. CONFIRMED the OG had a HealCheck;
	// this threshold is a PLACEHOLDER.
	var/healThresholdPercent = 60

	// -----------------------------
	// Item drops (the OG's drop_type / drop_rate)
	// -----------------------------
	// dropType is a single obj/item typepath; dropChance is a percent rolled once on
	// death. The OG stored exactly this pair per monster. The real per-monster values
	// aren't recovered (the monster extract's columns stop before them), so what's
	// assigned in MonsterRoster.dm is PLACEHOLDER — the mechanism is the OG's, the
	// numbers are ours.
	var/dropType = null
	var/dropChance = 0

	// Drops on the corpse's own tile, not the killer's, so loot has a real position in
	// the world and the killer has to actually walk over and pick it up (Interact(),
	// PlayerVerbs.dm). Fires before CleanUpDead() deletes the body, so loc is still valid.
	DropLoot(mob/killer)
		// Amulet of Luck (obj/item/amulet/luck, Inventory.dm) — flat percentage points
		// added to this monster's own dropChance roll.
		var/effectiveDropChance = dropChance + (killer ? killer.equipDropRateBonus : 0)
		if(!dropType || !prob(min(100, effectiveDropChance))) return
		var/turf/T = loc
		if(!T) return
		var/obj/item/I = new dropType(T)
		if(killer)
			killer << output("[src] dropped [I.name]!", "Info")

	// Pet state — null/PET_MODE_FOLLOW until a GM assigns this mob via
	// ShowAssignPetMenu() below. See file header for the overall design.
	var/mob/player/owner
	var/petName
	var/petMode = PET_MODE_FOLLOW

	New()
		..()
		attackSkill = new
		ResolveElementalDefense()  // CombatSystem.dm — turns this monster's real OG
		                            // mobElement (MonsterRoster.dm) into an actual
		                            // elementalResistance instead of leaving it inert
		BuildSpellInstances()
		AILoop()
		MovementLoop()

	// Instantiates every declared castable/heal skill once, so casting doesn't allocate a
	// fresh datum per cast. Keyed by typepath so TryCastAt()/TryHeal() below can ask for
	// a specific one.
	proc/BuildSpellInstances()
		spellInstances = list()
		for(var/skillType in castableSkills + healSkills)
			if(spellInstances[skillType]) continue
			spellInstances[skillType] = new skillType

	// Whether this monster casts at all — cheap guard so the overwhelming majority of the
	// roster (pure melee) skips every casting check below entirely.
	proc/IsCaster()
		return castableSkills.len || healSkills.len

	proc/SpellReady()
		return world.time - lastCastTime >= spellCooldown

	// Offensive cast at M. Returns TRUE if a spell actually went off, so the caller knows
	// not to also take a melee swing this tick.
	proc/TryCastAt(mob/M)
		if(!castableSkills.len || !SpellReady() || !canAct) return FALSE
		if(get_dist(src, M) > castRange) return FALSE
		if(!prob(castChance)) return FALSE

		var/datum/skill/S = spellInstances[pick(castableSkills)]
		if(!S) return FALSE

		// Monsters pay MP like players do — a Healer with an empty pool stops casting
		// and falls back to melee, which is what makes its 20 MaxMP meaningful.
		var/cost = S.GetManaCost()
		if(MP < cost) return FALSE
		MP -= cost
		ShowFloatingMPBar()

		lastCastTime = world.time
		dir = get_dir(src, M)
		canAct = FALSE
		view(src) << output("[src] casts [S.skillName]!", "Info")
		PlayAttackAnimation(src, S, M)
		ApplySpellDamage(M, round(Intelligence * S.damage_multiplier), S.element)
		spawn(spellCooldown)
			canAct = TRUE
		return TRUE

	// The OG's HealCheck: heal yourself if hurt, otherwise heal the most wounded nearby
	// ally. Returns TRUE if a heal went off. This is what makes the Healer monster
	// actually a healer rather than a reskinned melee enemy.
	proc/TryHeal()
		if(!healSkills.len || !SpellReady() || !canAct) return FALSE

		// Typed as GenericSpell, not the base datum/skill, so heal_amount is a real
		// compile-checked member rather than a runtime `:` access — a healSkills list
		// that accidentally names a non-healing skill fails safe here instead of
		// throwing mid-cast.
		var/datum/skill/GenericSpell/S = spellInstances[pick(healSkills)]
		if(!istype(S)) return FALSE
		var/cost = S.GetManaCost()
		if(MP < cost) return FALSE

		// Prefer self when hurt, else the worst-off ally in range. Only unowned monsters
		// count as allies — a wild Healer shouldn't patch up somebody's pet.
		var/mob/enemy/patient = null
		if(HP <= MaxHP * healThresholdPercent / 100)
			patient = src
		else
			var/worstFraction = healThresholdPercent / 100
			for(var/mob/enemy/E in range(castRange, src))
				if(E == src || E.HP <= 0 || E.owner) continue
				var/fraction = E.HP / E.MaxHP
				if(fraction < worstFraction)
					worstFraction = fraction
					patient = E

		if(!patient) return FALSE

		MP -= cost
		ShowFloatingMPBar()
		lastCastTime = world.time
		canAct = FALSE
		view(src) << output("[src] casts [S.skillName] on [patient == src ? "itself" : "[patient]"]!", "Info")
		PlayAttackAnimation(src, S, patient)
		ApplyHeal(patient, S.heal_amount)
		spawn(spellCooldown)
			canAct = TRUE
		return TRUE

	// Runs forever once this enemy exists in the world — same polling-loop shape as
	// client/MoveLoop() in Code/Core/SmoothMovement.dm. Each tick: stop entirely once
	// dead (so a corpse just sits still until CombatSystem.dm's CleanUpDead() deletes
	// it), then hand off to HandlePetTick() if owned, or RunWildAI() if not. Both of
	// those only ever set moveIntent/moveTowardAtom — the actual stepping happens
	// continuously in MovementLoop() below, decoupled from this slower decision cadence.
	proc/AILoop()
		set waitfor = 0
		while(src)
			if(HP <= 0)
				moveIntent = ENEMY_MOVE_NONE
				return  // dead — CleanUpDead() (CombatSystem.dm) handles deletion

			if(owner)
				HandlePetTick()
			else
				RunWildAI()

			sleep(aiTickDelay)

	// One decision tick of wild-monster behavior: drop a stale target, acquire a new one
	// if the area is actually in battle mode (Code/World/Area.dm's battleModeOn), then
	// flee/attack/chase it — or wander when there's nobody to fight. Outside a battle
	// area enemies stay peaceful and just wander regardless of nearby players.
	//
	// Shared by genuinely wild enemies (AILoop() above) and by PET_MODE_WANDER pets,
	// which are DEFINED as behaving exactly like a wild monster (see PET_MODE_WANDER up
	// top). Those two used to be separate verbatim copies of this logic, and had already
	// drifted apart: the pet copy nulled and re-acquired its target from scratch on every
	// single tick instead of running the stale-target checks below, so a Wander-mode pet
	// could never hold aggro on one player the way a wild monster does. Now there is one
	// copy and "acts exactly like a wild monster" is literally true.
	proc/RunWildAI()
		// Drop a dead target, or one that turned ghost mid-fight (GM_GhostForm,
		// GMCommands.dm) — a GM shouldn't be able to get stuck fighting an enemy just
		// because it locked on before they ghosted.
		if(target && (target.HP <= 0 || target.isGhostform))
			target = null

		// Give up the chase once the target flees past sightRange — without this, a
		// locked-on target was kept forever regardless of distance, so a slime would
		// chase clear across the map, making detection feel unbounded even though
		// initial acquisition below is capped at sightRange. Also doubles as how a
		// fleeing enemy "escapes" below.
		if(target && get_dist(src, target) > sightRange)
			target = null

		if(!InBattleArea())
			target = null  // area isn't in battle mode — drop aggro entirely
			moveIntent = ENEMY_MOVE_NONE
			Wander()
			return

		if(!target)
			for(var/mob/player/P in range(sightRange, src))
				if(P.HP <= 0 || P.isDead || P.isGhostform) continue
				// This proc is shared by genuinely wild monsters AND PET_MODE_WANDER
				// pets (see the proc's own header comment) — for a wild monster,
				// owner is null and this never matches. For a pet, it stops it from
				// picking its own owner up as a hostile target and attacking them.
				if(P == owner) continue
				target = P
				break

		if(!target)
			moveIntent = ENEMY_MOVE_NONE
			Wander()
			return

		moveTowardAtom = target

		// Casters get first refusal every tick, before the flee/melee/chase decision.
		// A monster that can heal tries that first (patching itself up is strictly
		// better than fleeing), which is also why the flee branch below is no longer
		// the only escape from low HP.
		if(IsCaster())
			if(TryHeal()) return
			if(TryCastAt(target))
				moveIntent = ENEMY_MOVE_NONE
				return

		if(HP <= MaxHP * fleeHealthPercent / 100)
			// Low HP — run instead of fighting. For a non-caster the only way this ends
			// is death or breaking sightRange (the leash check above then drops target
			// and this falls back to wandering, i.e. successfully escaped); a healer
			// will have already tried to heal itself above instead of reaching here.
			moveIntent = ENEMY_MOVE_FLEE
		else if(IsCardinallyAdjacent(src, target, attackRange))
			moveIntent = ENEMY_MOVE_NONE
			TryMeleeAttack(target)
		else
			moveIntent = ENEMY_MOVE_CHASE

	// Face M and take one swing at it, if this enemy is off cooldown. The "we're adjacent,
	// so hit it" half of every AI branch in this file — wild, Wander-mode pet and
	// Aggressive pet all had this same block written out longhand, differing only in
	// which var held the victim. Enemies gate on their own flat attackCooldown here
	// rather than GetAttackDelay()'s stat-derived timing, deliberately — see
	// attackCooldown's own note up top.
	proc/TryMeleeAttack(mob/M)
		dir = get_dir(src, M)
		if(!canAct) return
		canAct = FALSE
		PlayAttackAnimation(src, attackSkill, M)
		PerformMeleeHit(attackSkill, M)
		spawn(attackCooldown)
			canAct = TRUE

	// Pet AI — runs instead of RunWildAI() above once this mob has an owner, branching
	// on petMode (PET_MODE_* above, set via ShowPetOwnerMenu()'s "Set Mode"). Reuses the
	// same target/moveIntent/moveTowardAtom/canAct/attackSkill/attackCooldown vars, the
	// same TryMeleeAttack() above, and the same MovementLoop()/StepRelativeTo() below —
	// only the decision logic differs.
	proc/HandlePetTick()
		if(!owner || !owner.client || owner.HP <= 0)
			// Ownerless-mid-tick edge case (owner disconnected/died) — no despawn/
			// drop-item behavior decided yet, so just hold still rather than guess.
			target = null
			moveIntent = ENEMY_MOVE_NONE
			return

		switch(petMode)
			if(PET_MODE_SIT)
				target = null
				moveIntent = ENEMY_MOVE_NONE

			if(PET_MODE_WANDER)
				// Runs the exact same proc a wild monster runs, owner and all — see
				// PET_MODE_WANDER's definition up top for why, and RunWildAI()'s own
				// comment for what this branch used to be.
				RunWildAI()

			if(PET_MODE_FOLLOW)
				target = null
				if(get_dist(src, owner) > PET_FOLLOW_DISTANCE)
					moveTowardAtom = owner
					moveIntent = ENEMY_MOVE_CHASE
				else
					moveIntent = ENEMY_MOVE_NONE

			if(PET_MODE_AGGRESSIVE)
				if(!InBattleArea())
					huntTarget = null
					moveIntent = ENEMY_MOVE_NONE
					return

				// Drop the target if it died, wandered off, or got tamed by someone
				// else mid-fight (an owned mob/enemy is fair game for a different
				// GM's Assign Pet just like a wild one, so re-check .owner here too).
				if(huntTarget && (huntTarget.HP <= 0 || huntTarget.owner || get_dist(src, huntTarget) > sightRange))
					huntTarget = null

				if(!huntTarget)
					for(var/mob/enemy/E in range(sightRange, src))
						if(E == src || E.owner || E.HP <= 0) continue
						huntTarget = E
						break

				if(huntTarget)
					moveTowardAtom = huntTarget
					if(IsCardinallyAdjacent(src, huntTarget, attackRange))
						moveIntent = ENEMY_MOVE_NONE
						TryMeleeAttack(huntTarget)
					else
						moveIntent = ENEMY_MOVE_CHASE
				else if(get_dist(src, owner) > PET_FOLLOW_DISTANCE)
					moveTowardAtom = owner
					moveIntent = ENEMY_MOVE_CHASE
				else
					moveIntent = ENEMY_MOVE_NONE

	// Continuously steps toward moveTowardAtom every tick, same cadence as the
	// player's client/MoveLoop() — this is what actually makes movement flow smoothly
	// instead of taking one glide-step per (much slower) AI decision tick.
	proc/MovementLoop()
		set waitfor = 0
		while(src)
			// AILoop() also stops itself on death, but only checks once per
			// aiTickDelay (up to a full second) — death happens asynchronously
			// (TakeDamage()/Die(), CombatSystem.dm), not synced to that slower cadence,
			// so a freshly-killed enemy could keep sliding for up to a second before
			// AILoop() ever noticed and cleared moveIntent. Checking HP here too, every
			// tick, stops the corpse immediately instead of waiting on that.
			if(HP <= 0)
				return
			if(moveTowardAtom && moveIntent != ENEMY_MOVE_NONE)
				// Hard leash, checked every tick rather than only on the next AI
				// decision (RunWildAI()'s own leash check runs on aiTickDelay's much
				// slower ~1s cadence) — a fleeing enemy steps continuously in
				// MovementLoop() the whole second in between, so it could run well
				// past sightRange before the slower check ever caught it. This stops
				// it the instant it crosses the line instead.
				if(get_dist(src, moveTowardAtom) > sightRange)
					moveIntent = ENEMY_MOVE_NONE
				else
					StepRelativeTo(moveTowardAtom, away = (moveIntent == ENEMY_MOVE_FLEE))
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

	// GM double-click → "Assign Pet" (unowned mobs only; more options may join this
	// list later, per your spec). Owner double-click → rename/mode/release menu
	// (ShowPetOwnerMenu()). Anyone else (including a GM clicking an already-owned
	// pet) falls through to the default click behavior.
	DblClick()
		if(owner == usr)
			ShowPetOwnerMenu(usr)
			return

		if(!owner && usr.client && usr.client.canAdmin)
			ShowAssignPetMenu(usr)
			return

		..()

	// GM-facing: offers to assign this wild mob as a pet to a nearby player. Player
	// list is scoped to view(src) (near the monster being assigned), not the GM's own
	// view, since the GM could be observing from anywhere (e.g. ghosted).
	proc/ShowAssignPetMenu(mob/GM)
		var/choice = input(GM, "What do you want to do with this [name]?", "Monster Options") in list("Assign Pet", "Cancel")
		if(choice != "Assign Pet") return

		var/list/nearby = list()
		for(var/mob/player/P in view(src))
			nearby[P.name] = P

		if(!nearby.len)
			GM << output("No players in view to assign this pet to.", "Info")
			return

		var/pick = input(GM, "Assign this [name] to which player?", "Assign Pet") in nearby
		if(!pick) return

		// One pet at a time for now (file header) — a new assignment replaces
		// whatever this player already owned, reverting the old one to wild.
		var/mob/player/newOwner = nearby[pick]
		if(newOwner.pet)
			newOwner.pet.ReleaseToWild()

		owner = newOwner
		petMode = PET_MODE_FOLLOW
		newOwner.pet = src
		GM << output("[name] assigned to [newOwner.name] as a pet.", "Info")
		newOwner << output("You've been given a pet [name]! Double-click it to name it.", "Info")

	// Owner-facing: first double-click after being assigned prompts for a name; every
	// double-click after that opens the Rename/Set Mode/Release menu.
	proc/ShowPetOwnerMenu(mob/player/M)
		if(!petName)
			var/newName = input(M, "Name your new pet:", "Name Pet") as text|null
			if(!newName || !trimtext(newName)) return
			petName = CensorText(trimtext(newName))
			name = petName
			M << output("Your pet is now named [petName].", "Info")
			return

		var/choice = input(M, "[petName]", "Pet Options") in list("Rename", "Set Mode", "Release", "Cancel")
		switch(choice)
			if("Rename")
				var/newName = input(M, "Rename your pet:", "Rename Pet", petName) as text|null
				if(!newName || !trimtext(newName)) return
				petName = CensorText(trimtext(newName))
				name = petName
				M << output("Your pet is now named [petName].", "Info")

			if("Set Mode")
				var/modeChoice = input(M, "Set [petName]'s behavior:", "Pet Mode") in list("Aggressive", "Sit", "Wander", "Follow", "Cancel")
				switch(modeChoice)
					if("Aggressive") petMode = PET_MODE_AGGRESSIVE
					if("Sit")        petMode = PET_MODE_SIT
					if("Wander")     petMode = PET_MODE_WANDER
					if("Follow")     petMode = PET_MODE_FOLLOW
					else return
				M << output("[petName] is now set to [modeChoice].", "Info")

			if("Release")
				var/confirm = alert(M, "Release [petName]? It will become a wild monster again.", "Release Pet", "Yes", "No")
				if(confirm != "Yes") return
				M << output("You released [petName].", "Info")
				ReleaseToWild()

	// Drops ownership and reverts this mob to a normal wild monster — shared by the
	// owner's own "Release" choice above and by ShowAssignPetMenu() bumping a player's
	// prior pet when they're given a new one.
	proc/ReleaseToWild()
		if(owner && owner.pet == src)
			owner.pet = null
		owner = null
		petName = null
		petMode = PET_MODE_FOLLOW
		name = initial(name)
		target = null
		huntTarget = null
		moveTowardAtom = null

// Every concrete monster (slime included) lives in Code/Combat/NPCs/MonsterRoster.dm —
// this file is the shared AI/pet behavior they all inherit, nothing more. Slime used to
// be declared here instead, hand-copying MonsterRoster.dm's Tier 1 numbers with a
// comment promising they matched; it's a plain mob/enemy/tier1 subtype over there now,
// so there's nothing left to keep in sync by hand.
