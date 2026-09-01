// -----------------------------
// Status Effects
// -----------------------------
// Minimal framework for timed conditions on a mob (poison, and eventually Sleep and
// whatever else). Deliberately built as a small real system rather than a one-off per
// effect — there are already at least two planned (Poison, Sleep), so the second one
// shouldn't require reworking the first.
//
// HOW IT WORKS:
//   mob.ApplyStatusEffect(/datum/status_effect/poison) creates the effect, attaches it
//   to that mob's statusEffects list, and starts its own polling loop (same shape as
//   AILoop()/MoveLoop()/SleepRestoreLoop() elsewhere in this codebase). The loop calls
//   OnTick() every tickInterval until either the duration runs out, the mob dies, or
//   something removes it explicitly — then OnExpire() fires and it detaches itself.
//
// Applying an effect a mob already has REFRESHES its duration rather than stacking a
// second copy (so standing in poison repeatedly doesn't multiply the damage rate).
// Stacking rules beyond that (intensity levels, multiple different effects at once)
// aren't designed yet — multiple *different* effects coexist fine, that's all.

datum/status_effect
	var
		effectName = "Unnamed Effect"
		mob/holder            // who this is attached to
		duration = 0          // total deciseconds; 0 = lasts until removed explicitly
		tickInterval = 10     // deciseconds between OnTick() calls
		expiresAt = 0         // world.time when this ends; 0 = never (see duration)
		active = FALSE

	// Override these per effect — base versions do nothing.
	proc/OnApply()
		return
	proc/OnTick()
		return
	proc/OnExpire()
		return

	proc/Start(mob/M)
		if(!M) return
		holder = M
		active = TRUE
		expiresAt = duration ? world.time + duration : 0
		OnApply()
		EffectLoop()

	// Re-applying an effect that's already running just resets its clock.
	proc/Refresh()
		if(duration)
			expiresAt = world.time + duration

	proc/EffectLoop()
		set waitfor = 0
		while(active && holder)
			sleep(tickInterval)

			// Re-check everything after the sleep — the holder may have died, been
			// deleted, or had the effect cleared while this was waiting.
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

// Applies an effect, or refreshes its duration if it's already active. Returns the
// effect datum either way.
mob/proc/ApplyStatusEffect(effectType)
	// Amulet of Wakefulness (obj/item/amulet/awake, Inventory.dm) — covers both
	// Sleep and Sleepmore, since ispath() matches subtypes too.
	if(ispath(effectType, /datum/status_effect/sleep) && equipSleepImmune)
		src << output("<font color='purple'>You resist falling asleep!</font>", "Info")
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

// Called on death and on respawn (CombatSystem.dm / PlayerVerbs.dm) so effects never
// survive across those. Iterates a copy since Stop() mutates the real list.
mob/proc/ClearStatusEffects()
	for(var/datum/status_effect/E in statusEffects.Copy())
		E.Stop()
	statusEffects = list()

// -----------------------------
// Poison
// -----------------------------
// Chips away a small percentage of MaxHP on a timer. All placeholder numbers.
#define POISON_DURATION 300         // deciseconds — 30 seconds total
#define POISON_TICK_INTERVAL 20     // deciseconds — damage every 2 seconds
#define POISON_DAMAGE_PERCENT 2     // % of MaxHP per tick (so ~30% over full duration)

// Whether poison can actually finish someone off. FALSE floors it at 1 HP, matching
// classic Dragon Warrior (poison never kills outright) and avoiding "died to a ticking
// number I couldn't respond to." Flip to TRUE if poison should be genuinely lethal —
// the death path below is already wired for it either way.
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
			holder << output("<font color='green'>You've been poisoned!</font>", "Info")

	OnTick()
		if(!holder) return

		// Percentage of MAX HP, not current — percent-of-current would shrink every
		// tick and asymptotically never do much, which makes poison feel pointless.
		var/dmg = max(1, round(holder.MaxHP * POISON_DAMAGE_PERCENT / 100))

		if(!POISON_CAN_KILL)
			dmg = min(dmg, max(0, holder.HP - 1))  // never drops below 1 HP
			if(dmg <= 0) return                     // already at 1 HP, nothing to do

		// Direct HP change rather than TakeDamage() on purpose: TakeDamage() would roll
		// RollDodge(), and you shouldn't be able to dodge poison already in your veins.
		// The hit SOUND is still wanted every tick though (confirmed), so it's played
		// explicitly below — same player/enemy split and SFX_CHANNEL that TakeDamage()
		// uses, so it doesn't stomp area music. Death handling below likewise mirrors
		// TakeDamage() so nothing gets skipped by going around it.
		holder.HP -= dmg

		// Same hit flick + sound TakeDamage() plays, just triggered explicitly here
		// since we're deliberately going around that proc (see note above).
		flick("hit", holder)
		var/isEnemy = istype(holder, /mob/enemy)
		PlaySFXAt(holder, isEnemy ? 'enemyhit.wav' : 'hit.wav')

		holder << output("<font color='green'>The poison burns! (-[dmg] HP)</font>", "Info")
		ShowCombatNumber(holder, "[dmg]", "#ff0000")
		holder.ShowFloatingHPBar()

		if(holder.HP <= 0)
			var/mob/dying = holder
			dying.Die(null)        // no attacker to credit — poison isn't a mob
			dying.CleanUpDead()

	OnExpire()
		if(holder && !holder.isDead)
			holder << output("<font color='green'>The poison wears off.</font>", "Info")

// -----------------------------
// Sleep — locks canAct until it expires. PLACEHOLDER: no wake-on-hit yet (classic
// Dragon Warrior sleep breaks when the sleeper is attacked) — worth adding once this
// gets tuned against real combat, deliberately left simple for now.
// -----------------------------
#define SLEEP_DURATION 100       // deciseconds — 10 seconds, PLACEHOLDER
#define SLEEP_DURATION_MORE 200  // Sleepmore's stronger version — PLACEHOLDER

datum/status_effect/sleep
	parent_type = /datum/status_effect

	New()
		..()
		effectName = "Sleep"
		duration = SLEEP_DURATION
		tickInterval = SLEEP_DURATION  // no ticking — just OnApply/OnExpire

	OnApply()
		if(holder)
			holder.canAct = FALSE
			holder << output("<font color='purple'>You fall asleep!</font>", "Info")

	OnExpire()
		if(holder)
			// Only hand movement back if the holder isn't dead — Die()
			// (CombatSystem.dm) locks canAct deliberately as part of the death/respawn
			// flow, and an unconditional unlock here would quietly undo that and let a
			// "dead" mob walk before respawning. Same guard Attack/Blaze's own deferred
			// recovery spawns already use for the identical reason.
			if(!holder.isDead)
				holder.canAct = TRUE
				holder << output("<font color='purple'>You wake up.</font>", "Info")

datum/status_effect/sleep/more
	New()
		..()
		effectName = "Sleep"
		duration = SLEEP_DURATION_MORE
		tickInterval = SLEEP_DURATION_MORE

// -----------------------------
// Buffs — Upper (attack), Increase (defense), Barrier (magic defense)
// -----------------------------
// CONFIRMED the OG had these as real timed buffs: upper/upper_time/upperon and
// barrier/barrier_time/barrieron are all real vars in the extracted string table, with
// the *on flag driving a visual overlay.
//
// Until now these three skills were stand-ins that quietly healed a few HP instead
// (SkillCatalog.dm's "no real buff system exists yet" note) — they claimed to buff and
// did something unrelated, which is worse than not existing, since a player reading the
// skill list has no way to know. They're real effects now.
//
// The bonus is applied additively to the stat's derived output rather than by mutating
// the stat itself: mutating Strength directly would be visible in the Battle panel, get
// caught up in stat-cap checks (ClickableStats.dm), and — worst — could be made
// permanent by any code path that saves mid-buff (SaveData.dm snapshots raw stats).
// Keeping the bonus in its own var sidesteps all three.
//
// PLACEHOLDER amounts and durations throughout; the OG's own values aren't recovered.
#define BUFF_DURATION 300          // deciseconds — 30 seconds
#define UPPER_ATTACK_BONUS 5       // flat added to Strength for damage purposes
#define INCREASE_DEFENSE_BONUS 4   // flat added to physical defense
#define BARRIER_MAGIC_DEFENSE_BONUS 6  // flat added to magic defense

mob/var/attackBonus = 0
mob/var/defenseBonus = 0
mob/var/magicDefenseBonus = 0

datum/status_effect/buff
	parent_type = /datum/status_effect

	New()
		..()
		duration = BUFF_DURATION
		tickInterval = BUFF_DURATION  // no ticking — OnApply/OnExpire only

datum/status_effect/buff/upper
	New()
		..()
		effectName = "Upper"

	OnApply()
		if(holder)
			holder.attackBonus += UPPER_ATTACK_BONUS
			holder << output("<font color='orange'>Your attack power rises!</font>", "Info")

	OnExpire()
		if(holder)
			holder.attackBonus = max(0, holder.attackBonus - UPPER_ATTACK_BONUS)
			if(!holder.isDead)
				holder << output("<font color='orange'>Your attack power returns to normal.</font>", "Info")

datum/status_effect/buff/increase
	New()
		..()
		effectName = "Increase"

	OnApply()
		if(holder)
			holder.defenseBonus += INCREASE_DEFENSE_BONUS
			holder << output("<font color='orange'>Your defense rises!</font>", "Info")

	OnExpire()
		if(holder)
			holder.defenseBonus = max(0, holder.defenseBonus - INCREASE_DEFENSE_BONUS)
			if(!holder.isDead)
				holder << output("<font color='orange'>Your defense returns to normal.</font>", "Info")

datum/status_effect/buff/barrier
	New()
		..()
		effectName = "Barrier"

	OnApply()
		if(holder)
			holder.magicDefenseBonus += BARRIER_MAGIC_DEFENSE_BONUS
			holder << output("<font color='cyan'>A magical barrier surrounds you!</font>", "Info")

	OnExpire()
		if(holder)
			holder.magicDefenseBonus = max(0, holder.magicDefenseBonus - BARRIER_MAGIC_DEFENSE_BONUS)
			if(!holder.isDead)
				holder << output("<font color='cyan'>Your barrier fades.</font>", "Info")

// -----------------------------
// Silence — blocks spell casting. Enforced centrally in UseSkillSlot()
// (PlayerTemplate.dm), the one place every skill use funnels through, rather than each
// spell's own OnUse() checking isSilenced itself — covers Fireball/Blaze too, not just
// the SkillCatalog.dm generic framework.
// -----------------------------
#define SILENCE_DURATION 150  // deciseconds — 15 seconds, PLACEHOLDER

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
			holder << output("<font color='gray'>You've been silenced!</font>", "Info")

	OnExpire()
		if(holder)
			holder.isSilenced = FALSE
			if(!holder.isDead)
				holder << output("<font color='gray'>The silence fades.</font>", "Info")
