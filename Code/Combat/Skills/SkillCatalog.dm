// -----------------------------
// Skill Catalog — generic framework + every named skill from ClassReference.md
// -----------------------------
// Every named skill below is a thin subtype of GenericPhysical or GenericSpell,
// setting only name/icon_state/cost/multiplier. A few skills (status effects, Rest/
// Return/Meditate, Revive, Classchange, Thornwhip) have a genuinely different shape
// and get their own OnUse(). Attack/Defend/Fireball/Blaze live in SkillDatum.dm, not
// here. See Markdowns/CodeNotes.md for placeholder/OG-confirmation history on the
// numbers below — every damage_multiplier/heal_amount/mana_cost is a tunable guess
// unless that doc says otherwise.

// -----------------------------
// Generic Physical — melee weapon/martial skills (Str or Agi gated)
// -----------------------------
datum/skill/GenericPhysical
    parent_type = /datum/skill
    isMelee = TRUE
    icon_state = "weapon"
    cast_time = 2

    var
        isRanged = FALSE

    // Hook for how contact is actually resolved — override this alone (e.g.
    // Thornwhip's line attack below) to change what a swing hits without
    // duplicating the whole windup/recovery sequence in OnUse().
    proc/PerformHit(mob/user, mob/target)
        user.PerformMeleeHit(src, target)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        user.PlayAttackAnimation(user, src, target)
        // The skill's spells.dmi art (SkillFX.dm), on top of the portrait's own swing
        // pose that PlayAttackAnimation() just played. Drawn on the target when there is
        // one, otherwise on the tile being swung at — same placement as the weapon
        // overlay. PlayAttackAnimation() flips animAlternate first, so a handed FX pair
        // ("leftclaw"/"rightclaw") always agrees with the hand in the pose.
        user.PlaySkillFX(src, target || get_step(user, user.dir))

        spawn(cast_time)
            PerformHit(user, target)
            if(!user.isDead) user.attackRecoveryOnly = TRUE

        spawn(atkDelay)
            if(user.isDead) return
            user.canAct = TRUE
            user.attackRecoveryOnly = FALSE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Generic Spell — offensive or healing magic (Int gated). isHealing picks the branch;
// damage spells scale off Intelligence via damage_multiplier, heals use heal_amount.
// -----------------------------
datum/skill/GenericSpell
    parent_type = /datum/skill
    isSpell = TRUE
    icon_state = "weapon"
    cast_time = 6

    var
        isHealing = FALSE
        heal_amount = 0
        // TRUE only for heal-tier skills with real spells.dmi art (Heal/Healmore/
        // Healmost) — routes through PlayHealCastSequence() (CombatSystem.dm) instead
        // of the generic spawn(cast_time) below.
        hasHealAnimation = FALSE

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Healing is allowed outside battle areas; damage spells are not.
        if(!isHealing && !user.InBattleArea()) return

        var/mob/actualTarget = isHealing ? (target || user) : target

        if(isHealing && actualTarget && actualTarget.HP >= actualTarget.MaxHP)
            user.ShowInfo("[actualTarget == user ? "You are" : "[actualTarget] is"] already at full HP.")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        if(isHealing && hasHealAnimation)
            user.PlayHealCastSequence(src, actualTarget, heal_amount, wasDefending, mySession)
            return

        user.PlayAttackAnimation(user, src, actualTarget)
        user.PlaySkillFX(src, actualTarget)  // spells.dmi effect art (SkillFX.dm)

        spawn(cast_time)
            if(isHealing)
                user.ApplyHeal(actualTarget, heal_amount)
            else
                // Base number from ComputeSpellDamage() (DamageFormula.dm), which owns
                // every offensive coefficient. The impact burst is gated on the hit
                // actually landing — a dodged spell shouldn't visibly detonate on the
                // target (same rule obj/projectile/Impact() follows).
                if(user.ApplySpellDamage(target, user.ComputeSpellDamage(damage_multiplier), src.element))
                    user.PlaySkillImpactFX(src, target)

        spawn(user.GetAttackDelay(src, wasDefending))
            if(user.isDead) return
            user.canAct = TRUE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// AoE Spell — hits everything in a blob instead of one target, and optionally leaves a
// hazard field on the ground afterwards (HazardFields.dm).
// -----------------------------
// Needs its own OnUse() rather than a PerformHit()-style hook because GenericSpell's
// whole shape assumes a single target (the heal branch, the "already at full HP" check,
// the one ApplySpellDamage() call).
datum/skill/AoESpell
    parent_type = /datum/skill/GenericSpell

    var
        aoe_radius = 1   // Manhattan radius of the blast
        aoe_range = 3    // how far ahead the blast centers when nothing is being faced

        // Residual ground hazard left behind. null = none.
        hazardFieldType = null
        hazard_radius = 1
        hazard_duration = 60
        // The field's power is scaled off the damage this cast actually rolled rather
        // than being a flat number, so residual fire from a high-Intelligence caster
        // keeps pace with the spell that made it.
        hazard_power_multiplier = 0.5

    // The target's own tile when facing something, otherwise the furthest unblocked
    // tile up to aoe_range ahead — so casting into open ground puts the blast out in
    // front of the caster instead of on top of them.
    proc/FindBlastCenter(mob/user, mob/target)
        if(target && target.loc) return target.loc

        var/turf/T = user.loc
        for(var/i = 1 to aoe_range)
            var/turf/next = get_step(T, user.dir)
            if(!next || IsTurfBlocked(next)) break
            T = next
        return T

    // One damage roll shared by everyone caught in the blast, not a separate roll per
    // victim — an explosion should read as a single event.
    proc/ApplyBlast(mob/user, turf/center, damage)
        var/fxState = ResolveSkillFXState(fx_state, user.dir, user.animAlternate)

        for(var/turf/T in GetDiamondTurfs(center, aoe_radius))
            if(fxState) FlashSkillFX(T, fxState)

            for(var/mob/M in T)
                // Coop mode / friendly fire (CanHarm(), CombatSystem.dm) -- also
                // excludes the caster itself.
                if(!user.CanHarm(M)) continue
                if(M.HP <= 0) continue
                user.ApplySpellDamage(M, damage, element)

        if(hazardFieldType)
            SpawnHazardBlob(center, hazardFieldType, hazard_radius, user,
                            round(damage * hazard_power_multiplier), element, hazard_duration)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        user.PlayAttackAnimation(user, src, target)

        // Aim locks now, at cast start — the blast shouldn't re-aim itself if the
        // caster turns during the windup.
        var/turf/center = FindBlastCenter(user, target)

        spawn(cast_time)
            if(user.isDead) return
            ApplyBlast(user, center, user.ComputeSpellDamage(damage_multiplier))

        spawn(user.GetAttackDelay(src, wasDefending))
            if(user.isDead) return
            user.canAct = TRUE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// =============================================================================
// PHYSICAL SKILLS (Str/Agi gated) — damage_multiplier scales Strength
// =============================================================================
// fx_state names a state in spells.dmi (SkillFX.dm). Most of these are unambiguous —
// spells.dmi literally contains "club", "thornwhip", "battleaxe" and so on, and they
// went unused for a long time only because every skill inherited the generic "weapon".
// Where a skill has NO matching art, fx_state is still set to the name the art would
// have: nothing is drawn today, and dropping a state by that name into spells.dmi is the
// only step needed to light it up. Those are marked "no art yet".
//
// "claw"/"fireclaw"/"goldclaw" have no bare state at all — the art ships as
// "leftclaw"/"rightclaw" pairs, which ResolveSkillFXState() picks between using the same
// swing alternation as the portrait's pose.
datum/skill/Punch
    parent_type = /datum/skill/GenericPhysical
    skillName = "Punch"
    damage_multiplier = 1.0
    // Deliberately null, not a placeholder name: a bare-fisted punch is fully
    // described by the portrait's own swing pose and wants no spells.dmi overlay.

datum/skill/Club
    parent_type = /datum/skill/GenericPhysical
    skillName = "Club"
    fx_state = "club"
    damage_multiplier = 1.1

datum/skill/IronClaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iron Claw"
    fx_state = "claw"  // -> leftclaw/rightclaw
    damage_multiplier = 1.2

datum/skill/Jump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Jump"
    fx_state = "jump"  // no art yet
    damage_multiplier = 1.1

datum/skill/Hide
    parent_type = /datum/skill/GenericPhysical
    skillName = "Hide"
    damage_multiplier = 1.0
    // No fx_state — Hide isn't a strike, so there's nothing to flash.

datum/skill/Magicknife
    parent_type = /datum/skill/GenericPhysical
    skillName = "Magicknife"
    fx_state = "magicknife"
    damage_multiplier = 1.2

datum/skill/Boomerang
    parent_type = /datum/skill/GenericPhysical
    skillName = "Boomerang"
    fx_state = "boomerang"
    damage_multiplier = 1.3
    isRanged = TRUE

datum/skill/Morningstar
    parent_type = /datum/skill/GenericPhysical
    skillName = "Morningstar"
    fx_state = "morningstar"
    damage_multiplier = 1.3

datum/skill/Dash
    parent_type = /datum/skill/GenericPhysical
    skillName = "Dash"
    fx_state = "dash"
    damage_multiplier = 1.3

datum/skill/Quakejump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Quakejump"
    fx_state = "quakejump"
    damage_multiplier = 1.4

datum/skill/Fireclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Fireclaw"
    fx_state = "fireclaw"  // -> leftfireclaw/rightfireclaw
    damage_multiplier = 1.4

datum/skill/Iceclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iceclaw"
    fx_state = "iceclaw"  // no art yet — a left/right pair would resolve automatically
    damage_multiplier = 1.4

// A 3-tile line attack in the facing direction, not a single-tile hit — overrides
// only PerformHit(), inheriting the rest of GenericPhysical's swing sequence as-is.
// The FX still draws on the tile directly ahead rather than along the whole line;
// worth revisiting once the art is seen in motion.
datum/skill/Thornwhip
    parent_type = /datum/skill/GenericPhysical
    skillName = "Thornwhip"
    fx_state = "thornwhip"
    damage_multiplier = 0.8
    var/reach = 3

    PerformHit(mob/user, mob/target)
        user.PerformLineHit(src, reach)

datum/skill/Lightsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Lightsword"
    fx_state = "lightsword"
    impact_fx_state = "lightswordblast"
    damage_multiplier = 1.5

datum/skill/Battleaxe
    parent_type = /datum/skill/GenericPhysical
    skillName = "Battleaxe"
    fx_state = "battleaxe"
    damage_multiplier = 1.5

datum/skill/Flamesword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Flamesword"
    fx_state = "flamesword"
    damage_multiplier = 1.6

datum/skill/Falconsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Falconsword"
    fx_state = "falconsword"
    damage_multiplier = 1.7

datum/skill/Goldclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Goldclaw"
    fx_state = "goldclaw"  // -> leftgoldclaw/rightgoldclaw
    damage_multiplier = 1.7

// spells.dmi has BOTH "chain" and "sickle" for this one skill. Which is the swing and
// which is the trailing half is a guess — swap them if it looks wrong in motion.
datum/skill/Chainsickle
    parent_type = /datum/skill/GenericPhysical
    skillName = "Chainsickle"
    fx_state = "sickle"
    impact_fx_state = "chain"
    damage_multiplier = 1.8

datum/skill/SwordOfLethargy
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sword Of Lethargy"
    fx_state = "swordoflethargy"
    damage_multiplier = 1.9

datum/skill/IceSaber
    parent_type = /datum/skill/GenericPhysical
    skillName = "Ice Saber"
    fx_state = "icesaber"
    damage_multiplier = 1.9

datum/skill/Demonhammer
    parent_type = /datum/skill/GenericPhysical
    skillName = "Demonhammer"
    fx_state = "demonhammer"
    damage_multiplier = 2.0

datum/skill/DragonKiller
    parent_type = /datum/skill/GenericPhysical
    skillName = "DragonKiller"
    fx_state = "dragonkiller"
    damage_multiplier = 2.3

datum/skill/ThunderSword
    parent_type = /datum/skill/GenericPhysical
    skillName = "ThunderSword"
    fx_state = "thundersword"
    damage_multiplier = 2.6

// =============================================================================
// OFFENSIVE SPELLS (Int gated) — damage_multiplier scales Intelligence
// =============================================================================
// Same fx_state rules as the physical block above. A few of these assignments are
// GUESSES where spells.dmi's state names don't map one-to-one onto the skill roster —
// marked inline. The "flameblast"/"iceblast"/"thunderblast" trio in particular looks
// like one matched set of big elemental bursts, so they're handed to the top tier of
// each element, but which exact skill each belongs to isn't established.
datum/skill/Icebolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Icebolt"
    element = "ice"
    fx_state = "icespear"
    impact_fx_state = "icespearhit"
    damage_multiplier = 0.7
    mana_cost = 4

datum/skill/Lightning
    parent_type = /datum/skill/GenericSpell
    skillName = "Lightning"
    element = "lightning"
    fx_state = "lightning"
    impact_fx_state = "lightninghit"
    damage_multiplier = 0.9
    mana_cost = 5

datum/skill/Infernos
    parent_type = /datum/skill/GenericSpell
    skillName = "Infernos"
    element = "fire"
    fx_state = "infernos"
    damage_multiplier = 1.0
    mana_cost = 5

datum/skill/Icespears
    parent_type = /datum/skill/GenericSpell
    skillName = "Icespears"
    element = "ice"
    fx_state = "iceblast"  // GUESS — "icespear" is taken by Icebolt above
    damage_multiplier = 1.1
    mana_cost = 6

datum/skill/Blazemore
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemore"
    element = "fire"
    fx_state = "blazemore"
    impact_fx_state = "blazemorehit"
    damage_multiplier = 1.2
    mana_cost = 7

datum/skill/Blizzard
    parent_type = /datum/skill/GenericSpell
    skillName = "Blizzard"
    element = "ice"
    fx_state = "blizzard"
    damage_multiplier = 1.3
    mana_cost = 8

datum/skill/Boom
    parent_type = /datum/skill/GenericSpell
    skillName = "Boom"
    element = "fire"
    fx_state = "boom"  // no art yet — "bang" belongs to Bang, "explodet" to Explodet
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Bang
    parent_type = /datum/skill/GenericSpell
    skillName = "Bang"
    element = "fire"
    fx_state = "bang"
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Infermore
    parent_type = /datum/skill/GenericSpell
    skillName = "Infermore"
    element = "fire"
    fx_state = "infermore"
    damage_multiplier = 1.5
    mana_cost = 9

// spells.dmi also ships "thordainns"/"thordainew" — ResolveSkillFXState() prefers the
// directional pair over the bare state automatically, so a vertical cast draws the
// vertical beam with no extra wiring. ("darkthordain" and "darklightning" exist too,
// presumably a monster-cast variant; no skill uses them yet.)
datum/skill/Thordain
    parent_type = /datum/skill/GenericSpell
    skillName = "Thordain"
    element = "lightning"
    fx_state = "thordain"
    damage_multiplier = 1.6
    mana_cost = 10

datum/skill/Firevolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Firevolt"
    element = "fire"
    fx_state = "flamespear"  // GUESS — unused fire-projectile art, fits a "volt"
    impact_fx_state = "flamespearhit"
    damage_multiplier = 1.6
    mana_cost = 10

datum/skill/Firebane
    parent_type = /datum/skill/GenericSpell
    skillName = "Firebane"
    element = "fire"
    fx_state = "firebane"
    damage_multiplier = 1.7
    mana_cost = 11

datum/skill/Snowstorm
    parent_type = /datum/skill/GenericSpell
    skillName = "Snowstorm"
    element = "ice"
    fx_state = "snowstorm"
    damage_multiplier = 1.8
    mana_cost = 12

datum/skill/Blazemost
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemost"
    element = "fire"
    fx_state = "flameblast"  // GUESS — no "blazemost" state exists
    damage_multiplier = 1.9
    mana_cost = 13

// The one skill that makes datum/status_effect/burn reachable. Recalled OG behavior:
// Explodet deals its impact damage and leaves a circle of flame on the ground, and
// standing in THAT circle is what burns you — the direct hit doesn't ignite anyone.
// spells.dmi ships both halves of the art: "explodet" for the blast, "explodetflame"
// for the residual fire (obj/hazard_field/flame's own icon_state, HazardFields.dm).
//
// Now an AoESpell rather than a single-target GenericSpell, which is the other half of
// matching the original — it was never a one-target spell.
datum/skill/Explodet
    parent_type = /datum/skill/AoESpell
    skillName = "Explodet"
    element = "fire"
    fx_state = "explodet"
    damage_multiplier = 2.2
    mana_cost = 16
    aoe_radius = 1
    hazardFieldType = /obj/hazard_field/flame
    hazard_radius = 1
    hazard_duration = 80  // deciseconds the fire stays on the ground

// =============================================================================
// HEALING SPELLS (Int gated) — heal_amount is flat, not stat-scaled
// =============================================================================
// These four were the only skills in the game already using real spells.dmi art, and
// they named it through icon_state — the var that everywhere else means "a state on the
// caster's own portrait". Moved onto fx_state with the rest of the roster;
// PlayHealCastSequence() (CombatSystem.dm) reads it from there now.
datum/skill/Heal
    parent_type = /datum/skill/GenericSpell
    skillName = "Heal"
    fx_state = "heal"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 60
    mana_cost = 4

datum/skill/Healmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmore"
    fx_state = "healmore"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 30
    mana_cost = 8

// No dedicated "healus" art — reuses Healmore's.
datum/skill/Healus
    parent_type = /datum/skill/GenericSpell
    skillName = "Healus"
    fx_state = "healmore"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 40
    mana_cost = 10

datum/skill/Healmost
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmost"
    fx_state = "healmost"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 55
    mana_cost = 12

// No dedicated "healusmore" art — reuses Healmost's.
datum/skill/Healusmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healusmore"
    fx_state = "healmost"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 75
    mana_cost = 15

datum/skill/Vivify
    parent_type = /datum/skill/GenericSpell
    skillName = "Vivify"
    fx_state = "vivify"  // no art yet
    isHealing = TRUE
    heal_amount = 90
    mana_cost = 16

// Buff spells target self by default; facing an ally casts it on them instead.
datum/skill/BuffSpell
    parent_type = /datum/skill/StatusSpell

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        var/mob/actualTarget = target || user

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        user.PlayAttackAnimation(user, src, actualTarget)
        user.PlaySkillFX(src, actualTarget)  // the cast burst; the buff's own standing
                                              // indicator is activeFXState on the status
                                              // effect (StatusEffects.dm)

        spawn(cast_time)
            actualTarget.ApplyStatusEffect(statusEffectType)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

datum/skill/Upper
    parent_type = /datum/skill/BuffSpell
    skillName = "Upper"
    fx_state = "upper"
    statusEffectType = /datum/status_effect/buff/upper
    mana_cost = 3

datum/skill/Increase
    parent_type = /datum/skill/BuffSpell
    skillName = "Increase"
    fx_state = "increase"  // no art yet
    statusEffectType = /datum/status_effect/buff/increase
    mana_cost = 3

datum/skill/Barrier
    parent_type = /datum/skill/BuffSpell
    skillName = "Barrier"
    fx_state = "barrier"
    statusEffectType = /datum/status_effect/buff/barrier
    mana_cost = 4

// =============================================================================
// STATUS-EFFECT SKILLS — apply a datum/status_effect (StatusEffects.dm) to the target.
// =============================================================================
datum/skill/StatusSpell
    parent_type = /datum/skill
    icon_state = "weapon"
    isSpell = TRUE
    cast_time = 4

    var
        statusEffectType = null
        noTargetMessage = "No target."

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        // Hostile effects obey the same coop / friendly-fire / ghost rule as damage
        // (CanHarm(), CombatSystem.dm) -- this path never touches TakeDamage(), so it
        // used to let a player Sleep another player in a coop area, or a ghosted GM.
        if(!target || !user.CanHarm(target))
            user.ShowInfo(noTargetMessage)
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        user.PlayAttackAnimation(user, src, target)
        user.PlaySkillFX(src, target)  // was drawing nothing at all before

        spawn(cast_time)
            // Re-checked: the target may have ghosted, or coop flipped, mid-cast.
            if(target && user.CanHarm(target))
                target.ApplyStatusEffect(statusEffectType)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// "sleep" is the cast burst; the sleeping target's own standing overlay is "asleep",
// set as activeFXState on the status effect (StatusEffects.dm).
datum/skill/Sleep
    parent_type = /datum/skill/StatusSpell
    skillName = "Sleep"
    fx_state = "sleep"
    statusEffectType = /datum/status_effect/sleep
    noTargetMessage = "No target to put to sleep."
    mana_cost = 5

datum/skill/Sleepmore
    parent_type = /datum/skill/Sleep
    skillName = "Sleepmore"
    statusEffectType = /datum/status_effect/sleep/more
    mana_cost = 9

datum/skill/Stopspell
    parent_type = /datum/skill/StatusSpell
    skillName = "Stopspell"
    fx_state = "stopspell"
    statusEffectType = /datum/status_effect/silence
    noTargetMessage = "No target to silence."
    mana_cost = 7

// =============================================================================
// UTILITY SKILLS — own resource/effect shape, not a plain damage/heal spell
// =============================================================================

// Vitality-gated self-heal, no mana cost (works for Fighter/Soldier/Goof-off too).
datum/skill/Rest
    parent_type = /datum/skill
    skillName = "Rest"
    icon_state = "weapon"
    cast_time = 4

    var/heal_percent = 30

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        user.ShowInfo("You sit down to rest...")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxHP * heal_percent / 100))
            user.ApplyHeal(user, amount)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Spirit-gated MP restore — the mana-side equivalent of Rest.
datum/skill/Meditate
    parent_type = /datum/skill
    skillName = "Meditate"
    icon_state = "weapon"
    cast_time = 4

    var/restore_percent = 30

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        user.ShowInfo("You begin to meditate...")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxMP * restore_percent / 100))
            user.MP = min(user.MaxMP, user.MP + amount)
            user.ShowInfo("You restore [amount] MP! (MP: [user.MP]/[user.MaxMP])")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Teleports the caster back to the spawn point (GetPlayerSpawnTurf(), Area.dm).
datum/skill/Return
    parent_type = /datum/skill
    skillName = "Return"
    icon_state = "weapon"
    isSpell = TRUE
    mana_cost = 8
    cast_time = 6

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Return! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast Return!")

        spawn(cast_time)
            if(!user.isDead)
                user.loc = GetPlayerSpawnTurf()
                if(user.client && user.client.camera)
                    user.client.camera.SnapTo(user)  // direct .loc change bypasses client/Move(), the only place the camera normally tracks
                user.ShowInfo("You return to town!")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Resurrects a fallen ally, bypassing their RESPAWN_DELAY wait (Die(), CombatSystem.dm).
datum/skill/Revive
    parent_type = /datum/skill
    skillName = "Revive"
    icon_state = "weapon"
    isSpell = TRUE
    mana_cost = 12
    cast_time = 6

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!target || !istype(target, /mob/player))
            user.ShowInfo("Revive only works on a fallen ally.")
            return

        var/mob/player/P = target
        if(!P.isDead)
            user.ShowInfo("[P.name] isn't in need of reviving.")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Revive! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast Revive!")

        spawn(cast_time)
            if(P.isDead)
                P.isDead = FALSE
                P.density = 1
                P.icon_state = "world"
                P.canAct = TRUE
                P.HP = max(1, round(P.MaxHP * 0.5))
                P.ShowInfo("You have been revived by [user.name]!")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Goof-off's signature unlock — transforms this character into a Sage (DW3-style).
#define CLASSCHANGE_MIN_LEVEL 25
datum/skill/Classchange
    parent_type = /datum/skill
    skillName = "Classchange"
    icon_state = "weapon"

    OnUse(mob/user, mob/target = null)
        if(!istype(user, /mob/player)) return
        var/mob/player/P = user
        if(!P.canAct) return
        if(istype(P, /mob/player/Sage))
            P.ShowInfo("You are already a Sage.")
            return

        if(P.Level < CLASSCHANGE_MIN_LEVEL)
            P.ShowInfo("You must be at least level [CLASSCHANGE_MIN_LEVEL] to change your class.")
            return

        for(var/obj/item/amulet/A in P.contents)
            if(A.worn)
                P.ShowInfo("You must unequip everything before you can change your class.")
                return

        var/confirm = alert(P, "Are you sure you want to change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Classchange", "Yes", "No")
        if(confirm != "Yes") return

        if(!RunSageReclassFlow(P))
            return  // backed out at the icon step — nothing has changed, still the old class

        P.BecomeSage()
