// -----------------------------
// Status Effects
// -----------------------------
// mob.ApplyStatusEffect(/datum/status_effect/poison) creates the effect, attaches it
// to that mob's statusEffects list, and starts its own polling loop (same shape as
// AILoop()/MoveLoop()/SleepRestoreLoop() elsewhere). The loop calls OnTick() every
// tickInterval until duration runs out, the mob dies, or something removes it
// explicitly — then OnExpire() fires and it detaches itself. Applying an effect a mob
// already has REFRESHES its duration rather than stacking a second copy.

datum/status_effect
	var
		effectName = "Unnamed Effect"
		mob/holder            // who this is attached to
		duration = 0          // total deciseconds; 0 = lasts until removed explicitly
		// Deciseconds between OnTick() calls (Poison, Burn). 0 = no ticking at all: the
		// effect only does OnApply()/OnExpire(), and the loop just waits for expiry.
		tickInterval = 0
		expiresAt = 0         // world.time when this ends; 0 = never (see duration)
		active = FALSE

		// A spells.dmi state drawn on the holder for as long as the effect is active —
		// the standing indicator, as opposed to the one-shot burst the casting spell
		// draws ("upper", "barrier", "asleep"). Leave null for an
		// effect with no such art and nothing is drawn. Resolved through
		// ResolveSkillFXState() (SkillFX.dm), so naming a state that doesn't exist yet
		// is safe and starts working the moment the art is added.
		activeFXState = null
		image/activeFXImage = null

		// Slows everything the holder does by this factor while active (Lethargy,
		// Chill) -- see UpdateSlowFactor() below. 1 = no slow.
		slowsBy = 1

	// Override these per effect — base versions do nothing.
	proc/OnApply()
		return
	proc/OnTick()
		return
	proc/OnExpire()
		return

	// Held as a real /image (not a bare icon) so it carries its own layer — without
	// that it renders behind the holder's own sprite.
	proc/ShowActiveFX()
		if(!holder || !activeFXState || activeFXImage) return
		var/state = ResolveSkillFXState(activeFXState)
		if(!state) return
		activeFXImage = image(SKILL_FX_FILE, holder, state)
		activeFXImage.layer = holder.layer + 0.05
		holder.overlays += activeFXImage

	proc/HideActiveFX()
		if(activeFXImage && holder)
			holder.overlays -= activeFXImage
		activeFXImage = null

	proc/Start(mob/M)
		if(!M) return
		holder = M
		active = TRUE
		expiresAt = duration ? world.time + duration : 0
		OnApply()
		if(slowsBy != 1) holder.UpdateSlowFactor()
		ShowActiveFX()
		EffectLoop()

	proc/Refresh()
		if(duration)
			expiresAt = world.time + duration

	proc/EffectLoop()
		set waitfor = 0
		while(active && holder)
			// A non-ticking effect sleeps straight to its expiry -- re-read every pass,
			// so a Refresh() mid-effect extends it exactly instead of overshooting by a
			// whole extra duration.
			if(tickInterval) sleep(tickInterval)
			else if(expiresAt) sleep(max(world.tick_lag, expiresAt - world.time))
			else sleep(10)  // permanent and non-ticking: just watch for death/removal

			// Re-check after the sleep — the holder may have died, been deleted, or
			// had the effect cleared while this was waiting.
			if(!active || !holder) return
			if(holder.isDead) break
			if(expiresAt && world.time >= expiresAt) break

			if(tickInterval) OnTick()

		Stop()

	// Safe to call from anywhere (expiry, death cleanup, a future cure item/spell) —
	// the active guard makes double-calls harmless.
	proc/Stop()
		if(!active) return
		active = FALSE
		HideActiveFX()  // before holder is nulled below, or the overlay is stranded
		if(slowsBy != 1 && holder) holder.UpdateSlowFactor()  // skips this one: inactive now
		OnExpire()
		if(holder)
			holder.statusEffects -= src
			holder = null

// -----------------------------
// Mob-side interface
// -----------------------------
mob/var/list/statusEffects = list()

mob/proc/GetStatusEffect(effectType)
	for(var/datum/status_effect/E in statusEffects)
		if(istype(E, effectType))
			return E
	return null

mob/proc/HasStatusEffect(effectType)
	return GetStatusEffect(effectType) ? TRUE : FALSE

// Applies an effect, or refreshes its duration if already active. Returns the effect
// datum either way.
mob/proc/ApplyStatusEffect(effectType)
	// Amulet of Wakefulness covers both Sleep and Sleepmore, since ispath() matches
	// subtypes too.
	if(ispath(effectType, /datum/status_effect/sleep) && equipSleepImmune)
		src.ShowInfo("<font color='purple'>You resist falling asleep!</font>")
		return null

	var/datum/status_effect/existing = GetStatusEffect(effectType)
	if(existing)
		existing.Refresh()
		return existing

	var/datum/status_effect/E = new effectType
	statusEffects += E
	E.Start(src)
	return E

mob/proc/RemoveStatusEffect(effectType)
	var/datum/status_effect/E = GetStatusEffect(effectType)
	if(E)
		E.Stop()

// Called on death and on respawn so effects never survive across those. Iterates a
// copy since Stop() mutates the real list.
mob/proc/ClearStatusEffects()
	for(var/datum/status_effect/E in statusEffects.Copy())
		E.Stop()
	statusEffects = list()

// -----------------------------
// Poison — chips away a percentage of MaxHP on a timer.
// -----------------------------
#define POISON_DURATION 300         // deciseconds — 30 seconds total
#define POISON_TICK_INTERVAL 20     // deciseconds — damage every 2 seconds
#define POISON_DAMAGE_PERCENT 2     // % of MaxHP per tick (so ~30% over full duration)
#define POISON_CAN_KILL FALSE

datum/status_effect/poison
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Poison"
		duration = POISON_DURATION
		tickInterval = POISON_TICK_INTERVAL

	OnApply()
		if(holder)
			holder.ShowInfo("<font color='green'>You've been poisoned!</font>")

	OnTick()
		if(!holder) return

		// % of MAX HP, not current — percent-of-current shrinks every tick and
		// asymptotically never does much.
		var/dmg = max(1, round(holder.MaxHP * POISON_DAMAGE_PERCENT / 100))

		if(!POISON_CAN_KILL)
			dmg = min(dmg, max(0, holder.HP - 1))  // never drops below 1 HP
			if(dmg <= 0) return

		// Not TakeDamage() — you can't dodge poison already in your veins.
		holder.TakeDirectDamage(dmg, null, "<font color='green'>The poison burns! (-[dmg] HP)</font>")

	OnExpire()
		if(holder && !holder.isDead)
			holder.ShowInfo("<font color='green'>The poison wears off.</font>")

// -----------------------------
// Burn — OG-confirmed formula (unsorted.dm:625, castburn()): mitigated by the TARGET's
// own Intelligence (not Vitality/Defense or the flat GetDefense()/GetMagicDefense()
// math everything else uses), and the mitigation is a RANDOM roll between B/3 and
// B*2/3, not a flat subtraction. power/element aren't set here — the base
// datum/status_effect framework only takes a type, so a caller uses ApplyBurn() below
// to grab the created datum and set them. Reuses GetElementalMultiplier() (CombatSystem.dm)
// so a burn reacts to the same real elemental matrix a direct spell hit does.
//
// LIVE as of the hazard-field pass. The trigger is deliberately NOT "any fire spell
// hit" — an earlier attempt wired it that way and it was wrong. The real OG mechanic is
// that Explodet deals its impact damage and leaves a circle of flame on the ground, and
// standing in THAT is what burns you. So the only thing that applies this is
// obj/hazard_field/flame (HazardFields.dm), spawned by datum/skill/Explodet and Firebane
// (SkillCatalog.dm), re-applying it every tick to whoever is standing in the fire.
// -----------------------------
#define BURN_TICK_INTERVAL 20         // deciseconds between ticks — same cadence as Poison
#define BURN_DURATION 60              // deciseconds — a handful of ticks per application
#define BURN_BARRIER_AMULET_BONUS 18  // OG-confirmed: added to the mitigation stat per worn Amulet of Barrier

datum/status_effect/burn
	parent_type = /datum/status_effect
	var/power = 0       // D0 in the OG formula — the "supplied" damage this burn hits for
	var/element = null  // fed into the same elemental matrix a direct hit uses

	New()
		..()
		effectName = "Burn"
		duration = BURN_DURATION
		tickInterval = BURN_TICK_INTERVAL

	OnApply()
		if(holder)
			holder.ShowInfo("<font color='orange'>You catch fire!</font>")

	OnTick()
		if(!holder) return

		var/B = holder.GetEffectiveIntelligence()
		for(var/obj/item/amulet/barrier/A in holder.contents)
			if(A.worn) B += BURN_BARRIER_AMULET_BONUS

		var/reduction = rand(round(B / 3), round(B * 2 / 3))
		var/dmg = max(1, round(power * GetElementalMultiplier(element, holder.mobElement)) - reduction)

		// Not TakeDamage() — same as Poison: the fire already caught you.
		holder.TakeDirectDamage(dmg, null, "<font color='orange'>The burn sears you! (-[dmg] HP)</font>")

	OnExpire()
		if(holder && !holder.isDead)
			holder.ShowInfo("<font color='orange'>The burning stops.</font>")

// Applies Burn with a specific power/element — set after creation since the base
// ApplyStatusEffect() only takes a type. On a re-application to an already-burning
// target, ApplyStatusEffect() refreshes the duration (see its own comment) and the
// STRONGER power wins here: a weak ignition landing on top of a strong burn must not
// downgrade it, which matters now that obj/hazard_field (HazardFields.dm) re-applies
// this every tick for as long as the target stands in the flames.
mob/proc/ApplyBurn(power, element)
	var/datum/status_effect/burn/B = ApplyStatusEffect(/datum/status_effect/burn)
	if(B && power > B.power)
		B.power = power
		B.element = element
	return B

// -----------------------------
// Sleep — locks canAct until it expires, or until a landed hit wakes the sleeper
// (a SLEEP_WAKE_ON_HIT_PERCENT roll per hit, CombatSystem.dm's TakeDamage()).
// Each nap rolls its own length (user, from the OG, 2026-09-25: Sleep lasted
// 2-8 seconds). Sleepmore's range is invented -- the OG gave it a bigger base value.
#define SLEEP_DURATION_MIN 20        // deciseconds
#define SLEEP_DURATION_MAX 80
#define SLEEP_MORE_DURATION_MIN 40   // invented
#define SLEEP_MORE_DURATION_MAX 100  // invented

datum/status_effect/sleep
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Sleep"
		duration = rand(SLEEP_DURATION_MIN, SLEEP_DURATION_MAX)  // no ticking — OnApply/OnExpire only
		activeFXState = "asleep"       // spells.dmi; "sleep" is the cast burst instead

	OnApply()
		if(holder)
			holder.canAct = FALSE
			holder.ShowInfo("<font color='purple'>You fall asleep!</font>")

	OnExpire()
		if(holder)
			// Only hand movement back if not dead — Die() locks canAct as part of the
			// death/respawn flow, and an unconditional unlock here would undo that.
			if(!holder.isDead)
				holder.canAct = TRUE
				holder.ShowInfo("<font color='purple'>You wake up.</font>")

datum/status_effect/sleep/more
	New()
		..()
		duration = rand(SLEEP_MORE_DURATION_MIN, SLEEP_MORE_DURATION_MAX)

// -----------------------------
// Buffs — Upper and Increase (physical defense), Barrier (magic defense). Applied
// additively to a separate bonus var rather than mutating the stat itself, so it can't
// show in the Battle panel, trip stat-cap checks, or get saved-in permanently.
// -----------------------------
#define BUFF_DURATION 300              // deciseconds
#define UPPER_DEFENSE_BONUS 5          // flat added to physical defense (user, 2026-09-25: Upper cuts physical damage)
#define INCREASE_DEFENSE_BONUS 4       // flat added to physical defense
#define BARRIER_MAGIC_DEFENSE_BONUS 6  // flat added to magic defense

mob/var/defenseBonus = 0
mob/var/magicDefenseBonus = 0

// Upper/Increase/Barrier only ever differed by which bonus var they touch, the
// amount, the color, and the two messages — factored into one parametrized base
// (vars[] dynamic access, same pattern StatLink already uses for stat names) so
// OnApply()/OnExpire() exist once instead of three times.
datum/status_effect/buff
	parent_type = /datum/status_effect
	var/bonusVar        // mob var name this buff adds to, e.g. "defenseBonus"
	var/bonusAmount = 0
	var/buffColor = "orange"
	var/applyMsg
	var/expireMsg

	New()
		..()
		duration = BUFF_DURATION

	OnApply()
		if(holder)
			holder.vars[bonusVar] += bonusAmount
			holder.ShowInfo("<font color='[buffColor]'>[applyMsg]</font>")

	OnExpire()
		if(holder)
			holder.vars[bonusVar] = max(0, holder.vars[bonusVar] - bonusAmount)
			if(!holder.isDead)
				holder.ShowInfo("<font color='[buffColor]'>[expireMsg]</font>")

// Upper and Barrier (user, from the OG, 2026-09-25): the "...on" state is the cast
// flash, the bare name the overlay that stays -- and they last about a minute, not
// BUFF_DURATION.
#define UPPER_DURATION 600    // deciseconds
#define BARRIER_DURATION 600  // deciseconds

datum/status_effect/buff/upper
	New()
		..()
		effectName = "Upper"
		duration = UPPER_DURATION
		bonusVar = "defenseBonus"
		bonusAmount = UPPER_DEFENSE_BONUS
		activeFXState = "upper"
		applyMsg = "Your defense rises!"
		expireMsg = "Your defense returns to normal."

datum/status_effect/buff/increase
	New()
		..()
		effectName = "Increase"
		bonusVar = "defenseBonus"
		bonusAmount = INCREASE_DEFENSE_BONUS
		// No "increaseon" art exists yet — named anyway, so adding that state to
		// spells.dmi is the only step needed to light this up.
		activeFXState = "increaseon"
		applyMsg = "Your defense rises!"
		expireMsg = "Your defense returns to normal."

datum/status_effect/buff/barrier
	New()
		..()
		effectName = "Barrier"
		duration = BARRIER_DURATION
		bonusVar = "magicDefenseBonus"
		bonusAmount = BARRIER_MAGIC_DEFENSE_BONUS
		activeFXState = "barrier"
		buffColor = "cyan"
		applyMsg = "A magical barrier surrounds you!"
		expireMsg = "Your barrier fades."

// -----------------------------
// Lethargy — Sword Of Lethargy (SkillCatalog.dm; user's design, 2026-09-25). Everything
// the holder does takes LETHARGY_SLOW_FACTOR times as long: each step (Step(),
// SmoothMovement.dm), swing recovery and spell windups (GetAttackDelay(), CombatSystem.dm)
// and a monster's attack cooldown (EnemyNPCs.dm). Their spells still fly at full speed.
// -----------------------------
#define LETHARGY_SLOW_FACTOR 1.6  // 1.6 = everything 60% slower -- invented
#define LETHARGY_DURATION 80      // deciseconds -- invented

// Read by every slowed path above. Kept in step by the status effects themselves
// (slowsBy, Start()/Stop()): the strongest active slow wins -- slows don't multiply, so
// a chilled and lethargic mob is only as slow as the worse of the two.
mob/var/tmp/slowFactor = 1

mob/proc/UpdateSlowFactor()
	var/factor = 1
	for(var/datum/status_effect/E in statusEffects)
		if(E.active && E.slowsBy > factor) factor = E.slowsBy
	slowFactor = factor

datum/status_effect/lethargy
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Lethargy"
		duration = LETHARGY_DURATION
		slowsBy = LETHARGY_SLOW_FACTOR

	OnApply()
		if(holder)
			holder.ShowInfo("<font color='#9080c0'>Your body feels heavy...</font>")

	OnExpire()
		if(holder && !holder.isDead)
			holder.ShowInfo("<font color='#9080c0'>The heaviness lifts.</font>")

// -----------------------------
// Chill — any landed ice spell hit may leave it (ICE_CHILL_PERCENT, ApplySpellDamage(),
// CombatSystem.dm; user's design, 2026-09-25). "icespearhit" stays on the target and
// they're slowed the same way Lethargy slows them (slowFactor), just less.
// -----------------------------
#define CHILL_SLOW_FACTOR 1.3  // 1.3 = everything 30% slower -- invented
#define CHILL_DURATION 50      // deciseconds -- invented

datum/status_effect/chill
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Chill"
		duration = CHILL_DURATION
		slowsBy = CHILL_SLOW_FACTOR
		activeFXState = "icespearhit"

	OnApply()
		if(holder)
			holder.ShowInfo("<font color='#80c0ff'>You're chilled to the bone!</font>")

	OnExpire()
		if(holder && !holder.isDead)
			holder.ShowInfo("<font color='#80c0ff'>You thaw out.</font>")

// -----------------------------
// Blind — Sand Toss (SkillCatalog.dm; user's design, 2026-09-25). The blinded mob can
// still act and attack, but misses more (BLIND_MISS_PERCENT, TakeDamage()) and sometimes
// swings at the wrong tile (BLIND_WRONG_TILE_PERCENT, PerformMeleeHit()) -- both in
// CombatSystem.dm. No standing overlay: "sandtoss" is only the throw.
// -----------------------------
#define BLIND_DURATION 100  // deciseconds -- invented

mob/var/tmp/isBlinded = FALSE

datum/status_effect/blind
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Blind"
		duration = BLIND_DURATION

	OnApply()
		if(holder)
			holder.isBlinded = TRUE
			holder.ShowInfo("<font color='#c8a060'>Sand gets in your eyes!</font>")

	OnExpire()
		if(holder)
			holder.isBlinded = FALSE
			if(!holder.isDead)
				holder.ShowInfo("<font color='#c8a060'>You can see again.</font>")

// -----------------------------
// Silence — blocks spell casting. Enforced centrally in UseSkillSlot()
// (PlayerTemplate.dm), the one place every skill use funnels through, rather than each
// spell's own OnUse() checking isSilenced itself.
// -----------------------------
#define SILENCE_DURATION 150  // deciseconds

mob/var/isSilenced = FALSE

datum/status_effect/silence
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Silence"
		duration = SILENCE_DURATION

	OnApply()
		if(holder)
			holder.isSilenced = TRUE
			holder.ShowInfo("<font color='gray'>You've been silenced!</font>")

	OnExpire()
		if(holder)
			holder.isSilenced = FALSE
			if(!holder.isDead)
				holder.ShowInfo("<font color='gray'>The silence fades.</font>")
