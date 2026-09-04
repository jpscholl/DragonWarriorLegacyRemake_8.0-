// -----------------------------
// Enemy NPCs
// -----------------------------
// Basic AI: see a player in range, lock onto them, chase, attack when adjacent, flee
// once low on HP. Melee only for now — no ranged/spell attacks except the monster
// spellcasting below (deferred otherwise, TODOList.md Phase 6).
//
// Two independent loops, started once in New(): AILoop() is the "brain" — runs every
// aiTickDelay (slow), decides WHAT to do (acquire/drop target, set moveIntent to
// NONE/CHASE/FLEE plus moveTowardAtom) and throws the actual melee swing when already
// adjacent, but never moves anything itself. MovementLoop() is the "body" — runs every
// world.tick_lag (fast, same cadence as a player's client/MoveLoop()), and just steps
// toward whatever AILoop() last set via StepRelativeTo(). Splitting brain/body this
// way is what makes movement flow continuously instead of one visible glide-step per
// (much slower) AI decision. See Markdowns/CodeNotes.md for the full pet-system design
// note.
#define ENEMY_MOVE_NONE 0
#define ENEMY_MOVE_CHASE 1
#define ENEMY_MOVE_FLEE 2

// Pet behavior modes (ShowPetOwnerMenu()'s "Set Mode") — what HandlePetTick()
// branches on every AILoop() tick once a mob/enemy has an owner.
#define PET_MODE_AGGRESSIVE 1  // hunts nearby unowned mob/enemy while in battle mode
#define PET_MODE_SIT 2          // stays put, doesn't act
#define PET_MODE_WANDER 3       // reverts to plain wild-monster behavior, including
                                 // targeting players
#define PET_MODE_FOLLOW 4       // keeps pace with owner, never fights — default mode

#define PET_FOLLOW_DISTANCE 3  // tiles — how far a Follow/Aggressive-idle pet lets its
                                 // owner get before catching up

mob/enemy
	pixel_y = SPRITE_PIXEL_Y_OFFSET  // same vertical offset as players (Main.dm), so
	                                  // attack overlays/animations line up correctly
	step_delay = 2.8  // slower than a player's default (1.36) — felt too fast for a slime

	var/mob/player/target
	// PET_MODE_AGGRESSIVE's equivalent of target — separate var because target is
	// typed mob/player and DM checks member access against a var's declared type.
	var/mob/enemy/huntTarget
	// What MovementLoop() actually steps toward this tick — usually == target, but a
	// Follow/idle-Aggressive pet walks toward its owner while target stays null.
	var/atom/moveTowardAtom
	// Set by AILoop() (slow cadence), consumed by MovementLoop() (fast cadence) — same
	// split as the player's move_dir + client/MoveLoop() (SmoothMovement.dm).
	var/moveIntent = ENEMY_MOVE_NONE
	// Detection uses range(), not view(), so this sees through walls on purpose.
	var/sightRange = 7
	// Must be CARDINALLY adjacent (IsCardinallyAdjacent(), CombatSystem.dm) — plain
	// get_dist()/Chebyshev distance would also count a diagonal neighbor.
	var/attackRange = 1
	// Deciseconds between AI decision ticks — NOT how often it steps (MovementLoop()
	// runs every world.tick_lag regardless). Was 5 (0.5s) — felt too twitchy.
	var/aiTickDelay = 10
	// Enemies use their own flat cooldown rather than GetAttackDelay()'s stat-derived
	// timing — monster attack speed is tuned per-species, not the player Agility formula.
	var/attackCooldown = 10
	// % chance per idle tick to take one random step — averages ~1 step/5s at the
	// default aiTickDelay. Placeholder "wandering," not real pathfinding.
	var/wanderChance = 20
	var/fleeHealthPercent = 10  // HP% at or below which this enemy flees instead of attacking
	// Never driven through OnUse() (enemies use attackCooldown instead), but IS the
	// skill datum passed to PlayAttackAnimation()/PerformMeleeHit() (CombatSystem.dm)
	// — those read isMelee/icon_state/damage_multiplier off it and hard-error on null.
	var/datum/skill/Attack/attackSkill
	// 0 = not routing around an obstacle; else a cardinal dir (StepRelativeTo() below).
	// Kept as instance state so an enemy commits to one side once it starts skirting a
	// wall instead of flip-flopping every tick as the target's angle shifts.
	var/avoidDir = 0

	// -----------------------------
	// Monster spellcasting — a monster declares WHICH skills it can cast and the
	// shared logic below picks one, pointed at the existing datum/skill catalog
	// (SkillCatalog.dm) rather than a parallel monster-only implementation.
	// -----------------------------
	var/list/castableSkills = list()  // typepaths this monster may cast offensively
	var/list/healSkills = list()      // typepaths it may cast to heal itself/an ally
	var/list/datum/skill/spellInstances  // built in New(), keyed by typepath

	var/castChance = 35      // % chance per AI tick, in range and off cooldown, to
	                           // cast instead of stepping/swinging
	var/spellCooldown = 30   // separate from attackCooldown so a caster can't chain
	                           // spells at melee swing rate
	var/lastCastTime = 0
	var/castRange = 5        // longer than attackRange — the whole point of a caster
	var/healThresholdPercent = 60  // HP fraction below which a monster is "wounded"

	// -----------------------------
	// Item drops (the OG's drop_type / drop_rate)
	// -----------------------------
	var/dropType = null
	var/dropChance = 0

	// Drops on the corpse's own tile, not the killer's. Fires before CleanUpDead()
	// deletes the body, so loc is still valid.
	DropLoot(mob/killer)
		var/effectiveDropChance = dropChance + (killer ? killer.equipDropRateBonus : 0)
		if(!dropType || !prob(min(100, effectiveDropChance))) return
		var/turf/T = loc
		if(!T) return
		var/obj/item/I = new dropType(T)
		if(killer)
			killer.ShowInfo("[src] dropped [I.name]!")

	// Pet state — null/PET_MODE_FOLLOW until a GM assigns this mob via
	// ShowAssignPetMenu() below.
	var/mob/player/owner
	var/petName
	var/petMode = PET_MODE_FOLLOW

	New()
		..()
		attackSkill = new
		ResolveElementalDefense()  // turns real OG mobElement (MonsterRoster.dm) into
		                           // an actual elementalResistance (CombatSystem.dm)
		BuildSpellInstances()
		AILoop()
		MovementLoop()

	proc/BuildSpellInstances()
		spellInstances = list()
		for(var/skillType in castableSkills + healSkills)
			if(spellInstances[skillType]) continue
			spellInstances[skillType] = new skillType

	proc/IsCaster()
		return castableSkills.len || healSkills.len

	proc/SpellReady()
		return world.time - lastCastTime >= spellCooldown

	// Offensive cast at M. Returns TRUE if a spell went off, so the caller skips a
	// melee swing this tick.
	proc/TryCastAt(mob/M)
		if(!castableSkills.len || !SpellReady() || !canAct) return FALSE
		if(get_dist(src, M) > castRange) return FALSE
		if(!prob(castChance)) return FALSE

		var/datum/skill/S = spellInstances[pick(castableSkills)]
		if(!S) return FALSE

		// Monsters pay MP like players do — a Healer with an empty pool falls back to melee.
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

	// Heal self if hurt, else the most wounded nearby ally. Returns TRUE if a heal went off.
	proc/TryHeal()
		if(!healSkills.len || !SpellReady() || !canAct) return FALSE

		// Typed as GenericSpell so heal_amount is compile-checked — a healSkills list
		// that accidentally names a non-healing skill fails safe here.
		var/datum/skill/GenericSpell/S = spellInstances[pick(healSkills)]
		if(!istype(S)) return FALSE
		var/cost = S.GetManaCost()
		if(MP < cost) return FALSE

		// Prefer self when hurt, else the worst-off ally in range. Only unowned
		// monsters count as allies — a wild Healer shouldn't patch up someone's pet.
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

	// Stops entirely once dead (a corpse sits still until CleanUpDead() deletes it),
	// then hands off to HandlePetTick() if owned, RunWildAI() if not.
	proc/AILoop()
		set waitfor = 0
		while(src)
			if(HP <= 0)
				moveIntent = ENEMY_MOVE_NONE
				return

			if(owner)
				HandlePetTick()
			else
				RunWildAI()

			sleep(aiTickDelay)

	// One decision tick of wild-monster behavior. Also shared by PET_MODE_WANDER pets
	// (defined as "behaves exactly like a wild monster") — owner is null for a
	// genuinely wild monster, so the owner-skip check below never matches there.
	proc/RunWildAI()
		// Drop a dead target, or one that ghosted mid-fight (GM_GhostForm).
		if(target && (target.HP <= 0 || target.isGhostform))
			target = null

		// Give up the chase once the target flees past sightRange.
		if(target && get_dist(src, target) > sightRange)
			target = null

		if(!InBattleArea())
			target = null
			moveIntent = ENEMY_MOVE_NONE
			Wander()
			return

		if(!target)
			for(var/mob/player/P in range(sightRange, src))
				if(P.HP <= 0 || P.isDead || P.isGhostform) continue
				if(P == owner) continue  // pet-mode-wander guard against its own owner
				target = P
				break

		if(!target)
			moveIntent = ENEMY_MOVE_NONE
			Wander()
			return

		moveTowardAtom = target

		// Casters get first refusal every tick, before flee/melee/chase.
		if(IsCaster())
			if(TryHeal()) return
			if(TryCastAt(target))
				moveIntent = ENEMY_MOVE_NONE
				return

		if(HP <= MaxHP * fleeHealthPercent / 100)
			moveIntent = ENEMY_MOVE_FLEE
		else if(IsCardinallyAdjacent(src, target, attackRange))
			moveIntent = ENEMY_MOVE_NONE
			TryMeleeAttack(target)
		else
			moveIntent = ENEMY_MOVE_CHASE

	// Face M and take one swing at it, if off cooldown.
	proc/TryMeleeAttack(mob/M)
		dir = get_dir(src, M)
		if(!canAct) return
		canAct = FALSE
		PlayAttackAnimation(src, attackSkill, M)
		PerformMeleeHit(attackSkill, M)
		spawn(attackCooldown)
			canAct = TRUE

	// Pet AI — runs instead of RunWildAI() once this mob has an owner, branching on
	// petMode. Reuses the same target/moveIntent/moveTowardAtom/TryMeleeAttack()/
	// MovementLoop() as wild AI — only the decision logic differs.
	proc/HandlePetTick()
		if(!owner || !owner.client || owner.HP <= 0)
			target = null
			moveIntent = ENEMY_MOVE_NONE
			return

		switch(petMode)
			if(PET_MODE_SIT)
				target = null
				moveIntent = ENEMY_MOVE_NONE

			if(PET_MODE_WANDER)
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
				// else mid-fight.
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
	// player's client/MoveLoop() — this is what makes movement flow smoothly instead
	// of one glide-step per (much slower) AI decision tick.
	proc/MovementLoop()
		set waitfor = 0
		while(src)
			// AILoop() also stops on death, but only checks once per aiTickDelay (up
			// to a full second) — checking HP here too stops the corpse immediately.
			if(HP <= 0)
				return
			if(moveTowardAtom && moveIntent != ENEMY_MOVE_NONE)
				// Hard leash, checked every tick (not just on the next slower AI
				// decision) — a fleeing enemy steps continuously here the whole second
				// in between, so it could run well past sightRange otherwise.
				if(get_dist(src, moveTowardAtom) > sightRange)
					moveIntent = ENEMY_MOVE_NONE
				else
					StepRelativeTo(moveTowardAtom, away = (moveIntent == ENEMY_MOVE_FLEE))
			sleep(world.tick_lag)

	// Takes one cardinal step toward Trg (or directly away, if away = TRUE — used for
	// fleeing). NOT step_to() — see Markdowns/CodeNotes.md for why BYOND's builtin
	// doesn't work in a 4-directional-only game. Picks whichever axis has the bigger
	// gap and steps that way; falls back to the other axis the same tick if blocked.
	// Uses the mob's own Step() (SmoothMovement.dm), not the raw step() builtin, for
	// the same smooth glide as a player and the same canAct-mid-attack rooting.
	//
	// Obstacle handling: if both axes are blocked, picks a perpendicular direction and
	// commits to it (avoidDir) until the direct route opens up again — simple
	// wall-hugging, not real pathfinding, but avoids oscillating side to side every tick.
	proc/StepRelativeTo(atom/Trg, away = FALSE)
		var/dx = Trg.x - x
		var/dy = Trg.y - y
		if(away)
			dx = -dx
			dy = -dy

		if(!dx && !dy)
			Step(pick(NORTH, SOUTH, EAST, WEST))  // standing exactly on Trg's tile
			return

		var/primaryDir
		var/secondaryDir
		if(abs(dx) >= abs(dy))
			if(dx) primaryDir = dx > 0 ? EAST : WEST
			if(dy) secondaryDir = dy > 0 ? NORTH : SOUTH
		else
			if(dy) primaryDir = dy > 0 ? NORTH : SOUTH
			if(dx) secondaryDir = dx > 0 ? EAST : WEST

		// Already skirting an obstacle — keep retrying the direct route first, else
		// keep stepping the same way around instead of re-picking a side every tick.
		if(avoidDir)
			if(primaryDir && Step(primaryDir))
				avoidDir = 0
				return
			if(Step(avoidDir)) return
			avoidDir = 0

		if(primaryDir && Step(primaryDir)) return
		if(secondaryDir && Step(secondaryDir)) return

		// Direct route and secondary axis both blocked — start skirting,
		// perpendicular to primaryDir.
		if(primaryDir == EAST || primaryDir == WEST)
			avoidDir = pick(NORTH, SOUTH)
		else
			avoidDir = pick(EAST, WEST)
		Step(avoidDir)

	// Simple random idle movement. Stays on the slower AILoop() cadence, not
	// MovementLoop() — wandering is occasional idle steps, not continuous movement.
	proc/Wander()
		if(prob(wanderChance))
			Step(pick(NORTH, SOUTH, EAST, WEST))

	// GM double-click on an unowned mob offers "Assign Pet"; owner double-click opens
	// the rename/mode/release menu. Anyone else falls through to default click behavior.
	DblClick()
		if(owner == usr)
			ShowPetOwnerMenu(usr)
			return

		if(!owner && usr.client && usr.client.canAdmin)
			ShowAssignPetMenu(usr)
			return

		..()

	// GM-facing: offers to assign this wild mob as a pet to a nearby player.
	proc/ShowAssignPetMenu(mob/GM)
		var/choice = input(GM, "What do you want to do with this [name]?", "Monster Options") in list("Assign Pet", "Cancel")
		if(choice != "Assign Pet") return

		var/list/nearby = list()
		for(var/mob/player/P in view(src))
			nearby[P.name] = P

		if(!nearby.len)
			GM.ShowInfo("No players in view to assign this pet to.")
			return

		var/pick = input(GM, "Assign this [name] to which player?", "Assign Pet") in nearby
		if(!pick) return

		// One pet at a time — a new assignment replaces whatever this player already
		// owned, reverting the old one to wild.
		var/mob/player/newOwner = nearby[pick]
		if(newOwner.pet)
			newOwner.pet.ReleaseToWild()

		owner = newOwner
		petMode = PET_MODE_FOLLOW
		newOwner.pet = src
		GM.ShowInfo("[name] assigned to [newOwner.name] as a pet.")
		newOwner.ShowInfo("You've been given a pet [name]! Double-click it to name it.")

	// Owner-facing: first double-click after being assigned prompts for a name; every
	// double-click after that opens the Rename/Set Mode/Release menu.
	proc/ShowPetOwnerMenu(mob/player/M)
		if(!petName)
			var/newName = input(M, "Name your new pet:", "Name Pet") as text|null
			if(!newName || !trimtext(newName)) return
			petName = CensorText(trimtext(newName))
			name = petName
			M.ShowInfo("Your pet is now named [petName].")
			return

		var/choice = input(M, "[petName]", "Pet Options") in list("Rename", "Set Mode", "Release", "Cancel")
		switch(choice)
			if("Rename")
				var/newName = input(M, "Rename your pet:", "Rename Pet", petName) as text|null
				if(!newName || !trimtext(newName)) return
				petName = CensorText(trimtext(newName))
				name = petName
				M.ShowInfo("Your pet is now named [petName].")

			if("Set Mode")
				var/modeChoice = input(M, "Set [petName]'s behavior:", "Pet Mode") in list("Aggressive", "Sit", "Wander", "Follow", "Cancel")
				switch(modeChoice)
					if("Aggressive") petMode = PET_MODE_AGGRESSIVE
					if("Sit")        petMode = PET_MODE_SIT
					if("Wander")     petMode = PET_MODE_WANDER
					if("Follow")     petMode = PET_MODE_FOLLOW
					else return
				M.ShowInfo("[petName] is now set to [modeChoice].")

			if("Release")
				var/confirm = alert(M, "Release [petName]? It will become a wild monster again.", "Release Pet", "Yes", "No")
				if(confirm != "Yes") return
				M.ShowInfo("You released [petName].")
				ReleaseToWild()

	// Drops ownership and reverts to a normal wild monster.
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

// Every concrete monster lives in MonsterRoster.dm — this file is only the shared
// AI/pet behavior they all inherit.
