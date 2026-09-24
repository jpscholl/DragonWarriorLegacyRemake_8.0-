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
		tickInterval = 10     // deciseconds between OnTick() calls
		expiresAt = 0         // world.time when this ends; 0 = never (see duration)
		active = FALSE

		// A spells.dmi state drawn on the holder for as long as the effect is active —
		// the standing indicator, as opposed to the one-shot burst the casting spell
		// draws. spells.dmi already ships these for several effects ("upperon",
		// "barrieron", "asleep"), which is what they're clearly for. Leave null for an
		// effect with no such art and nothing is drawn. Resolved through
		// ResolveSkillFXState() (SkillFX.dm), so naming a state that doesn't exist yet
		// is safe and starts working the moment the art is added.
		activeFXState = null
		image/activeFXImage = null

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
		ShowActiveFX()
		EffectLoop()

	proc/Refresh()
		if(duration)
			expiresAt = world.time + duration

	proc/EffectLoop()
		set waitfor = 0
		while(active && holder)
			sleep(tickInterval)

			// Re-check after the sleep — the holder may have died, been deleted, or
			// had the effect cleared while this was waiting.
			if(!active || !holder) return
			if(holder.isDead) break
			if(expiresAt && world.time >= expiresAt) break

			OnTick()

		Stop()

	// Safe to call from anywhere (expiry, death cleanup, a future cure item/spell) —
	// the active guard makes double-calls harmless.
	proc/Stop()
		if(!active) return
		active = FALSE
		HideActiveFX()  // before holder is nulled below, or the overlay is stranded
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

		// Direct HP change, not TakeDamage() — you shouldn't be able to dodge poison
		// already in your veins. Death handling below mirrors TakeDamage() so nothing
		// gets skipped by going around it.
		holder.HP -= dmg

		flick("hit", holder)
		var/isEnemy = istype(holder, /mob/enemy)
		PlaySFXAt(holder, isEnemy ? 'enemyhit.wav' : 'hit.wav')

		holder.ShowInfo("<font color='green'>The poison burns! (-[dmg] HP)</font>")
		ShowCombatNumber(holder, "[dmg]", DAMAGE_NUMBER_COLOR)
		holder.ShowFloatingHPBar()

		if(holder.HP <= 0)
			var/mob/dying = holder
			dying.Die(null)        // no attacker to credit — poison isn't a mob
			dying.CleanUpDead()

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
// obj/hazard_field/flame (HazardFields.dm), spawned by datum/skill/Explodet
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

		// Direct HP change, not TakeDamage() — same reasoning as Poison above, fire
		// already caught you, dodging isn't in the picture anymore.
		holder.HP -= dmg

		flick("hit", holder)
		var/isEnemy = istype(holder, /mob/enemy)
		PlaySFXAt(holder, isEnemy ? 'enemyhit.wav' : 'hit.wav')

		holder.ShowInfo("<font color='orange'>The burn sears you! (-[dmg] HP)</font>")
		ShowCombatNumber(holder, "[dmg]", DAMAGE_NUMBER_COLOR)
		holder.ShowFloatingHPBar()

		if(holder.HP <= 0)
			var/mob/dying = holder
			dying.Die(null)        // no attacker to credit — burn isn't a mob
			dying.CleanUpDead()

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
// -----------------------------
#define SLEEP_DURATION 100       // deciseconds
#define SLEEP_DURATION_MORE 200  // Sleepmore's stronger version

datum/status_effect/sleep
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Sleep"
		duration = SLEEP_DURATION
		tickInterval = SLEEP_DURATION  // no ticking — just OnApply/OnExpire
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
		effectName = "Sleep"
		duration = SLEEP_DURATION_MORE
		tickInterval = SLEEP_DURATION_MORE
		// activeFXState inherited from /sleep — same visual, longer nap.

// -----------------------------
// Buffs — Upper (attack), Increase (defense), Barrier (magic defense). Applied
// additively to a separate bonus var rather than mutating the stat itself, so it can't
// show in the Battle panel, trip stat-cap checks, or get saved-in permanently.
// -----------------------------
#define BUFF_DURATION 300              // deciseconds
#define UPPER_ATTACK_BONUS 5           // flat added to Strength for damage purposes
#define INCREASE_DEFENSE_BONUS 4       // flat added to physical defense
#define BARRIER_MAGIC_DEFENSE_BONUS 6  // flat added to magic defense

mob/var/attackBonus = 0
mob/var/defenseBonus = 0
mob/var/magicDefenseBonus = 0

// Upper/Increase/Barrier only ever differed by which bonus var they touch, the
// amount, the color, and the two messages — factored into one parametrized base
// (vars[] dynamic access, same pattern StatLink already uses for stat names) so
// OnApply()/OnExpire() exist once instead of three times.
datum/status_effect/buff
	parent_type = /datum/status_effect
	var/bonusVar        // mob var name this buff adds to, e.g. "attackBonus"
	var/bonusAmount = 0
	var/buffColor = "orange"
	var/applyMsg
	var/expireMsg

	New()
		..()
		duration = BUFF_DURATION
		tickInterval = BUFF_DURATION  // no ticking — OnApply/OnExpire only

	OnApply()
		if(holder)
			holder.vars[bonusVar] += bonusAmount
			holder.ShowInfo("<font color='[buffColor]'>[applyMsg]</font>")

	OnExpire()
		if(holder)
			holder.vars[bonusVar] = max(0, holder.vars[bonusVar] - bonusAmount)
			if(!holder.isDead)
				holder.ShowInfo("<font color='[buffColor]'>[expireMsg]</font>")

// The "...on" states in spells.dmi are the buff-is-active indicators, paired with the
// plain state the spell itself flashes on cast ("upper" -> "upperon").
datum/status_effect/buff/upper
	New()
		..()
		effectName = "Upper"
		bonusVar = "attackBonus"
		bonusAmount = UPPER_ATTACK_BONUS
		activeFXState = "upperon"
		applyMsg = "Your attack power rises!"
		expireMsg = "Your attack power returns to normal."

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
		bonusVar = "magicDefenseBonus"
		bonusAmount = BARRIER_MAGIC_DEFENSE_BONUS
		activeFXState = "barrieron"
		buffColor = "cyan"
		applyMsg = "A magical barrier surrounds you!"
		expireMsg = "Your barrier fades."

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
		tickInterval = SILENCE_DURATION

	OnApply()
		if(holder)
			holder.isSilenced = TRUE
			holder.ShowInfo("<font color='gray'>You've been silenced!</font>")

	OnExpire()
		if(holder)
			holder.isSilenced = FALSE
			if(!holder.isDead)
				holder.ShowInfo("<font color='gray'>The silence fades.</font>")
