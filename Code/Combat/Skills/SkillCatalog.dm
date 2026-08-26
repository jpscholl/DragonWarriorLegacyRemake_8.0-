// -----------------------------
// Skill Catalog — generic framework + every named skill from ClassReference.md
// -----------------------------
// Building a bespoke OnUse() for ~90 individual skills is out of scope for "mechanics
// working, tune later" — instead every named skill below is a thin subtype of one of
// the two generic bases (GenericPhysical/GenericSpell), setting only name/icon_state/
// cost/multiplier, same shape ClassReference.md itself already reduced these to ("which
// stat governs it"). A handful of genuinely special-shaped skills (status effects,
// Rest/Return/Meditate's own resource, Revive, Classchange) get their own small
// override instead — still fully built, not stubbed.
//
// Attack/Defend/Fireball/Blaze (SkillDatum.dm) are NOT duplicated here — those already
// have real hand-written implementations and stay as-is.
//
// PLACEHOLDER POLICY: every damage_multiplier/heal_amount/mana_cost/element choice
// below is invented, not OG-derived (ClassReference.md only ever confirmed WHICH stat
// gates a skill, never its numbers) — all tunable later once there's real playtesting
// to feel them against.

// -----------------------------
// Generic Physical — melee weapon/martial skills (Str or Agi gated)
// -----------------------------
datum/skill/GenericPhysical
    parent_type = /datum/skill
    isMelee = TRUE
    icon_state = "weapon"  // PLACEHOLDER: reuses Attack's sprite state — real
                             // per-skill animation states aren't designed yet, and
                             // Fighter's own icons don't even have a "weapon" state
                             // (see PlayerTemplate.dm's Fighter comment), so this is
                             // already a known-imperfect visual, not a new gap
    cast_time = 2  // PLACEHOLDER: matches Attack's windup

    var
        isRanged = FALSE  // PLACEHOLDER flag only — no actual ranged/thrown behavior
                            // built yet (e.g. Boomerang), still resolves as a normal
                            // melee hit via PerformMeleeHit() like everything else here

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        user.PlayAttackAnimation(user, src, target)

        spawn(cast_time)
            user.PerformMeleeHit(src)

        spawn(user.GetAttackDelay(src, wasDefending))
            if(user.isDead) return
            user.canAct = TRUE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Generic Spell — offensive or healing magic (Int gated). isHealing picks the branch;
// damage spells scale off Intelligence via damage_multiplier, heals currently use a
// flat heal_amount with NO scaling term.
// OVERTURNED 2026-08-10: live OG testing showed Heal's amount going 60->63 as Int and
// Spirit both climbed +1 — heals DO scale with a stat (Int, Spirit, or both; not yet
// isolated since they moved together). heal_amount needs a scaling term added once
// the governing stat is confirmed — don't treat it as flat anymore. See
// CombatDataSheet.md's Heal amounts table.
// -----------------------------
datum/skill/GenericSpell
    parent_type = /datum/skill
    isSpell = TRUE
    icon_state = "weapon"  // PLACEHOLDER: see GenericPhysical's identical note —
                             // no per-spell sprite states exist on the player icons
                             // (confirmed via direct .dmi inspection), so this is a
                             // pre-existing gap already true of Blaze/Fireball too
    cast_time = 6  // PLACEHOLDER: matches Fireball's windup

    var
        isHealing = FALSE
        heal_amount = 0

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        // Silence is enforced centrally now (UseSkillSlot(), PlayerTemplate.dm) —
        // every skill funnels through there before OnUse() ever runs.

        var/cost = GetManaCost()
        if(user.MP < cost)
            user << output("Not enough MP to cast [skillName]! (need [cost])", "Info")
            return

        user.MP -= cost
        user.canAct = FALSE
        user << output("You cast [skillName]!", "Info")

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        var/mob/actualTarget = isHealing ? (target || user) : target

        user.PlayAttackAnimation(user, src, actualTarget)

        spawn(cast_time)
            if(isHealing)
                user.ApplyHeal(actualTarget, heal_amount)
            else
                user.ApplySpellDamage(target, round(user.GetEffectiveIntelligence() * damage_multiplier), src.element)

        spawn(user.GetAttackDelay(src, wasDefending))
            if(user.isDead) return
            user.canAct = TRUE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// =============================================================================
// PHYSICAL SKILLS (Str/Agi gated) — damage_multiplier scales Strength
// =============================================================================
datum/skill/Punch
    parent_type = /datum/skill/GenericPhysical
    skillName = "Punch"
    damage_multiplier = 1.0  // PLACEHOLDER — Fighter's starting-kit basic attack

datum/skill/Club
    parent_type = /datum/skill/GenericPhysical
    skillName = "Club"
    damage_multiplier = 1.1  // PLACEHOLDER

datum/skill/IronClaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iron Claw"
    damage_multiplier = 1.2  // PLACEHOLDER

datum/skill/Jump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Jump"
    damage_multiplier = 1.1  // PLACEHOLDER — mechanically just a strike for now,
                               // real leap/gap-close movement not modeled this pass
datum/skill/Hide
    parent_type = /datum/skill/GenericPhysical
    skillName = "Hide"
    damage_multiplier = 1.0  // PLACEHOLDER — mechanically just a strike for now,
                               // real stealth/evasion not modeled this pass
datum/skill/Magicknife
    parent_type = /datum/skill/GenericPhysical
    skillName = "Magicknife"
    damage_multiplier = 1.2  // PLACEHOLDER — governing stat unconfirmed
                               // (ClassReference.md), assumed Strength
datum/skill/Boomerang
    parent_type = /datum/skill/GenericPhysical
    skillName = "Boomerang"
    damage_multiplier = 1.3  // PLACEHOLDER
    isRanged = TRUE

datum/skill/Morningstar
    parent_type = /datum/skill/GenericPhysical
    skillName = "Morningstar"
    damage_multiplier = 1.3  // PLACEHOLDER

datum/skill/Dash
    parent_type = /datum/skill/GenericPhysical
    skillName = "Dash"
    damage_multiplier = 1.3  // PLACEHOLDER — mechanically just a strike for now,
                               // real dash movement not modeled this pass
datum/skill/Quakejump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Quakejump"
    damage_multiplier = 1.4  // PLACEHOLDER — mechanically just a strike for now,
                               // real ground-slam AoE not modeled this pass
datum/skill/Fireclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Fireclaw"
    damage_multiplier = 1.4  // PLACEHOLDER — Str-scaled only, no elemental bonus

datum/skill/Iceclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iceclaw"
    damage_multiplier = 1.4  // PLACEHOLDER — Str-scaled only, no elemental bonus

datum/skill/Thornwhip
    parent_type = /datum/skill/GenericPhysical
    skillName = "Thornwhip"
    damage_multiplier = 1.4  // PLACEHOLDER — WRONG DIRECTION, confirmed gate is 8 Str
                               // (ClassReference.md). CONFIRMED 2026-08-18 (live OG
                               // test, CombatDataSheet.md): real damage is ~80% of a
                               // plain hit (trades power for reach), not 140% —
                               // retune to roughly 0.8 once compiling is possible again.
                               // CONFIRMED 2026-08-10 (live OG test): 3-tile line attack
                               // in the direction the caster is facing, stops on the
                               // first enemy hit — does NOT pierce through multiple
                               // targets (user recalled it piercing previously, but
                               // current live behavior is single-target-stop; treat the
                               // pierce memory as outdated/superseded). CONFIRMED
                               // 2026-08-18: hits whichever enemy is closest within
                               // that line — 1, 2, or 3 tiles out, not always the full
                               // 3 — stopping on the first one found, same as the
                               // no-pierce finding above just stated more precisely.
                               // Still plain melee (single target, no line/reach
                               // mechanic) in this code — needs a real
                               // 3-tile-in-facing-direction hit check built (scan tile
                               // 1, then 2, then 3, stop at the first mob found), the
                               // Projectiles.dm pierces flag is NOT what OG actually
                               // does here, don't use it for Thornwhip.
datum/skill/Lightsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Lightsword"
    damage_multiplier = 1.5  // PLACEHOLDER

datum/skill/Battleaxe
    parent_type = /datum/skill/GenericPhysical
    skillName = "Battleaxe"
    damage_multiplier = 1.5  // PLACEHOLDER

datum/skill/Flamesword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Flamesword"
    damage_multiplier = 1.6  // PLACEHOLDER — Str-scaled only, no elemental bonus

datum/skill/Falconsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Falconsword"
    damage_multiplier = 1.7  // PLACEHOLDER

datum/skill/Goldclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Goldclaw"
    damage_multiplier = 1.7  // PLACEHOLDER — Str-scaled only, no elemental bonus

datum/skill/Chainsickle
    parent_type = /datum/skill/GenericPhysical
    skillName = "Chainsickle"
    damage_multiplier = 1.8  // PLACEHOLDER — confirmed gate is 19 Str (Hero's table)

datum/skill/SwordOfLethargy
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sword Of Lethargy"
    damage_multiplier = 1.9  // PLACEHOLDER — no slow/debuff effect modeled this pass

datum/skill/IceSaber
    parent_type = /datum/skill/GenericPhysical
    skillName = "Ice Saber"
    damage_multiplier = 1.9  // PLACEHOLDER — Str-scaled only, no elemental bonus

datum/skill/Demonhammer
    parent_type = /datum/skill/GenericPhysical
    skillName = "Demonhammer"
    damage_multiplier = 2.0  // PLACEHOLDER

datum/skill/DragonKiller
    parent_type = /datum/skill/GenericPhysical
    skillName = "DragonKiller"
    damage_multiplier = 2.3  // PLACEHOLDER — confirmed gate is 30 Str (Hero's table)

datum/skill/ThunderSword
    parent_type = /datum/skill/GenericPhysical
    skillName = "ThunderSword"
    damage_multiplier = 2.6  // PLACEHOLDER — confirmed gate is 35 Str (Hero's top skill)
// =============================================================================
// OFFENSIVE SPELLS (Int gated) — damage_multiplier scales Intelligence
// =============================================================================
datum/skill/Icebolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Icebolt"
    element = "ice"
    damage_multiplier = 0.7  // PLACEHOLDER — confirmed gate is 7 Int (Hero's table)
    mana_cost = 4  // PLACEHOLDER

datum/skill/Lightning
    parent_type = /datum/skill/GenericSpell
    skillName = "Lightning"
    element = "lightning"
    damage_multiplier = 0.9  // PLACEHOLDER — confirmed gate is 10 Int (Hero's table)
    mana_cost = 5  // PLACEHOLDER

datum/skill/Infernos
    parent_type = /datum/skill/GenericSpell
    skillName = "Infernos"
    element = "fire"
    damage_multiplier = 1.0  // PLACEHOLDER
    mana_cost = 5  // PLACEHOLDER

datum/skill/Icespears
    parent_type = /datum/skill/GenericSpell
    skillName = "Icespears"
    element = "ice"
    damage_multiplier = 1.1  // PLACEHOLDER — confirmed gate is 13 Int (Hero's table)
    mana_cost = 6  // PLACEHOLDER

datum/skill/Blazemore
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemore"
    element = "fire"
    damage_multiplier = 1.2  // PLACEHOLDER — Blaze's real projectile system stays
                               // the actual Blaze skill; this is the next tier up,
                               // generic-framework damage only for now
    mana_cost = 7  // PLACEHOLDER

datum/skill/Blizzard
    parent_type = /datum/skill/GenericSpell
    skillName = "Blizzard"
    element = "ice"
    damage_multiplier = 1.3  // PLACEHOLDER
    mana_cost = 8  // PLACEHOLDER

datum/skill/Boom
    parent_type = /datum/skill/GenericSpell
    skillName = "Boom"
    element = "fire"
    damage_multiplier = 1.5  // PLACEHOLDER
    mana_cost = 9  // PLACEHOLDER

datum/skill/Bang
    parent_type = /datum/skill/GenericSpell
    skillName = "Bang"
    element = "fire"
    damage_multiplier = 1.5  // PLACEHOLDER — confirmed gate is 18 Int (Hero's table)
    mana_cost = 9  // PLACEHOLDER

datum/skill/Infermore
    parent_type = /datum/skill/GenericSpell
    skillName = "Infermore"
    element = "fire"
    damage_multiplier = 1.5  // PLACEHOLDER
    mana_cost = 9  // PLACEHOLDER

datum/skill/Thordain
    parent_type = /datum/skill/GenericSpell
    skillName = "Thordain"
    element = "lightning"
    damage_multiplier = 1.6  // PLACEHOLDER — confirmed gate is 20 Int (Hero's table)
    mana_cost = 10  // PLACEHOLDER

datum/skill/Firevolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Firevolt"
    element = "fire"
    damage_multiplier = 1.6  // PLACEHOLDER
    mana_cost = 10  // PLACEHOLDER

datum/skill/Firebane
    parent_type = /datum/skill/GenericSpell
    skillName = "Firebane"
    element = "fire"
    damage_multiplier = 1.7  // PLACEHOLDER — confirmed gate ~21 Int (Hero's table,
                               // originally listed as an 18-24 range)
    mana_cost = 11  // PLACEHOLDER

datum/skill/Snowstorm
    parent_type = /datum/skill/GenericSpell
    skillName = "Snowstorm"
    element = "ice"
    damage_multiplier = 1.8  // PLACEHOLDER
    mana_cost = 12  // PLACEHOLDER

datum/skill/Blazemost
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemost"
    element = "fire"
    damage_multiplier = 1.9  // PLACEHOLDER
    mana_cost = 13  // PLACEHOLDER

datum/skill/Explodet
    parent_type = /datum/skill/GenericSpell
    skillName = "Explodet"
    element = "fire"
    damage_multiplier = 2.2  // PLACEHOLDER
    mana_cost = 16  // PLACEHOLDER
// =============================================================================
// HEALING SPELLS (Int gated) — heal_amount is flat, not stat-scaled
// =============================================================================
datum/skill/Heal
    parent_type = /datum/skill/GenericSpell
    skillName = "Heal"
    isHealing = TRUE
    heal_amount = 60  // CONFIRMED 2026-08-10 (Hero1 live test, single sample —
                      // heals on animation completion, not instantly on cast).
                      // Gate is 6 Int (Hero's table), also confirmed this session.
    mana_cost = 4  // PLACEHOLDER

datum/skill/Healmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmore"
    isHealing = TRUE
    heal_amount = 30  // PLACEHOLDER — confirmed gate is 14 Int (Hero's table)
    mana_cost = 8  // PLACEHOLDER

datum/skill/Healus
    parent_type = /datum/skill/GenericSpell
    skillName = "Healus"
    isHealing = TRUE
    heal_amount = 40  // PLACEHOLDER — confirmed gate is 21 Int (Hero's table)
    mana_cost = 10  // PLACEHOLDER

datum/skill/Healmost
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmost"
    isHealing = TRUE
    heal_amount = 55  // PLACEHOLDER
    mana_cost = 12  // PLACEHOLDER

datum/skill/Healusmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healusmore"
    isHealing = TRUE
    heal_amount = 75  // PLACEHOLDER
    mana_cost = 15  // PLACEHOLDER

datum/skill/Vivify
    parent_type = /datum/skill/GenericSpell
    skillName = "Vivify"
    isHealing = TRUE
    heal_amount = 90  // PLACEHOLDER — confirmed gate ~22 Int (Hero's table,
                        // originally listed as a 21-24 range)
    mana_cost = 16  // PLACEHOLDER
// Buff spells (Upper/Increase/Barrier) — real timed buffs as of 2026-08-25
// (datum/status_effect/buff/*, StatusEffects.dm). These used to be stand-ins that
// quietly healed a few HP instead, which was worse than not existing: the skill list
// advertised a buff and the code did something unrelated, with no way for a player to
// tell. They target self by default (a buff with no target is a self-buff) but can be
// cast on an ally by facing them, same targeting rule as every other skill.
datum/skill/BuffSpell
    parent_type = /datum/skill/StatusSpell
    // Unlike Sleep/Stopspell (which need an enemy), a buff with no target is a self-cast
    // rather than an error — this is what makes noTargetMessage unnecessary here.
    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user << output("Not enough MP to cast [skillName]! (need [cost])", "Info")
            return

        var/mob/actualTarget = target || user

        user.MP -= cost
        user.canAct = FALSE
        user << output("You cast [skillName]!", "Info")

        user.PlayAttackAnimation(user, src, actualTarget)

        spawn(cast_time)
            actualTarget.ApplyStatusEffect(statusEffectType)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

datum/skill/Upper
    parent_type = /datum/skill/BuffSpell
    skillName = "Upper"
    statusEffectType = /datum/status_effect/buff/upper
    mana_cost = 3  // PLACEHOLDER — confirmed gate is 10 Int (Hero's table)

datum/skill/Increase
    parent_type = /datum/skill/BuffSpell
    skillName = "Increase"
    statusEffectType = /datum/status_effect/buff/increase
    mana_cost = 3  // PLACEHOLDER

datum/skill/Barrier
    parent_type = /datum/skill/BuffSpell
    skillName = "Barrier"
    statusEffectType = /datum/status_effect/buff/barrier
    mana_cost = 4  // PLACEHOLDER
// =============================================================================
// STATUS-EFFECT SKILLS — apply a datum/status_effect (StatusEffects.dm) to the target.
// Sleep/Sleepmore/Stopspell share this one shape (canAct/battle/target/mana-check,
// then apply statusEffectType after cast_time) — a third generic base alongside
// GenericPhysical/GenericSpell above, same reasoning: these three skills only ever
// differed in skillName/mana_cost/which status effect gets applied.
// =============================================================================
datum/skill/StatusSpell
    parent_type = /datum/skill
    icon_state = "weapon"  // PLACEHOLDER, see GenericSpell's note
    isSpell = TRUE
    cast_time = 4  // PLACEHOLDER

    var
        statusEffectType = null  // set by each subtype below
        noTargetMessage = "No target."

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        // Silence is enforced centrally now (UseSkillSlot(), PlayerTemplate.dm).
        if(!target)
            user << output(noTargetMessage, "Info")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user << output("Not enough MP to cast [skillName]! (need [cost])", "Info")
            return

        user.MP -= cost
        user.canAct = FALSE
        user << output("You cast [skillName]!", "Info")

        spawn(cast_time)
            target.ApplyStatusEffect(statusEffectType)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

datum/skill/Sleep
    parent_type = /datum/skill/StatusSpell
    skillName = "Sleep"
    statusEffectType = /datum/status_effect/sleep
    noTargetMessage = "No target to put to sleep."
    mana_cost = 5  // PLACEHOLDER — confirmed gate is 9 Int (Hero's table)

datum/skill/Sleepmore
    parent_type = /datum/skill/Sleep
    skillName = "Sleepmore"
    statusEffectType = /datum/status_effect/sleep/more
    mana_cost = 9  // PLACEHOLDER — stronger, later-tier version of Sleep

datum/skill/Stopspell
    parent_type = /datum/skill/StatusSpell
    skillName = "Stopspell"
    statusEffectType = /datum/status_effect/silence
    noTargetMessage = "No target to silence."
    mana_cost = 7  // PLACEHOLDER — confirmed gate ~20 Int (Hero's table, originally
                     // listed as a 17-23 range)

// =============================================================================
// UTILITY SKILLS — own resource/effect shape, not a plain damage/heal spell
// =============================================================================

// Vitality-gated self-heal, no mana cost (Fighter/Soldier/Goof-off can all learn this
// despite having no mana pool — see PlayerTemplate.dm's hasMana overrides).
datum/skill/Rest
    parent_type = /datum/skill
    skillName = "Rest"
    icon_state = "weapon"  // PLACEHOLDER, see GenericSpell's note
    cast_time = 4  // PLACEHOLDER

    var/heal_percent = 30  // PLACEHOLDER: % of MaxHP restored

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        user << output("You sit down to rest...", "Info")

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
    icon_state = "weapon"  // PLACEHOLDER, see GenericSpell's note
    cast_time = 4  // PLACEHOLDER

    var/restore_percent = 30  // PLACEHOLDER: % of MaxMP restored

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        user << output("You begin to meditate...", "Info")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxMP * restore_percent / 100))
            user.MP = min(user.MaxMP, user.MP + amount)
            user << output("You restore [amount] MP! (MP: [user.MP]/[user.MaxMP])", "Info")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Teleports the caster back to the spawn point — the confirmed Dragon Warrior "return
// to town" spell. GetPlayerSpawnTurf() (Area.dm) is the same world-login-point lookup
// FinalizePlayer()/LoadCharacter() (LoginMenu.dm/SaveSystem.dm) already use.
datum/skill/Return
    parent_type = /datum/skill
    skillName = "Return"
    icon_state = "weapon"  // PLACEHOLDER, see GenericSpell's note
    isSpell = TRUE
    mana_cost = 8  // PLACEHOLDER — confirmed gate is 14 Int (Hero's table)
    cast_time = 6  // PLACEHOLDER

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Silence is enforced centrally now (UseSkillSlot(), PlayerTemplate.dm).

        var/cost = GetManaCost()
        if(user.MP < cost)
            user << output("Not enough MP to cast Return! (need [cost])", "Info")
            return

        user.MP -= cost
        user.canAct = FALSE
        user << output("You cast Return!", "Info")

        spawn(cast_time)
            if(!user.isDead)
                user.loc = GetPlayerSpawnTurf()
                user << output("You return to town!", "Info")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Resurrects a fallen ally (a player currently in the isDead/respawn-wait state,
// Die()/CombatSystem.dm) — bypasses their RESPAWN_DELAY wait entirely. Special-shaped
// like Sleep/Rest/Return: this reaches into another mob's death state directly, not a
// plain damage/heal application.
datum/skill/Revive
    parent_type = /datum/skill
    skillName = "Revive"
    icon_state = "weapon"  // PLACEHOLDER, see GenericSpell's note
    isSpell = TRUE
    mana_cost = 12  // PLACEHOLDER
    cast_time = 6  // PLACEHOLDER

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Silence is enforced centrally now (UseSkillSlot(), PlayerTemplate.dm).
        if(!target || !istype(target, /mob/player))
            user << output("Revive only works on a fallen ally.", "Info")
            return

        var/mob/player/P = target
        if(!P.isDead)
            user << output("[P.name] isn't in need of reviving.", "Info")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user << output("Not enough MP to cast Revive! (need [cost])", "Info")
            return

        user.MP -= cost
        user.canAct = FALSE
        user << output("You cast Revive!", "Info")

        spawn(cast_time)
            if(P.isDead)  // still dead when the cast finishes
                P.isDead = FALSE
                P.density = 1
                P.icon_state = "world"
                P.canAct = TRUE
                P.HP = max(1, round(P.MaxHP * 0.5))  // PLACEHOLDER: revives at 50% HP
                P << output("You have been revived by [user.name]!", "Info")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Goof-off's signature unlock — transforms this character into a Sage (DW3-style).
// Level 25, no stat gate — confirmed by the OG help file, and matching the data point
// TODOList.md already carried (2026-08-04 decision notes). OnUse() gates on level and
// confirms, then hands off to BecomeSage() (PlayerTemplate.dm) for the actual mob-swap
// and the level-1 reset the OG's own confirmation prompt promises.
#define CLASSCHANGE_MIN_LEVEL 25
datum/skill/Classchange
    parent_type = /datum/skill
    skillName = "Classchange"
    icon_state = "weapon"  // PLACEHOLDER, see GenericSpell's note

    OnUse(mob/user, mob/target = null)
        if(!istype(user, /mob/player)) return
        var/mob/player/P = user
        if(!P.canAct) return
        if(istype(P, /mob/player/Sage))
            P << output("You are already a Sage.", "Info")
            return

        // CONFIRMED level gate (OG help file: Goof Off "at level 25 they can turn into
        // the very powerful Sage class"). The skill itself is already granted at level 25
        // via Goofoff's unlock table (SkillUnlocks.dm), but that only controls when it's
        // LEARNED — a GM_LevelIncrease down, a future respec, or any other path that
        // moves Level after the fact would otherwise let it fire under-level.
        if(P.Level < CLASSCHANGE_MIN_LEVEL)
            P << output("You must be at least level [CLASSCHANGE_MIN_LEVEL] to change your class.", "Info")
            return

        // CONFIRMED OG requirement (string: "You must unequip everything before you can
        // change your class."). Nothing in the remake is equippable yet — amulets aren't
        // built (RemakeVsOGStructure.md Part 2, Items) — so there is nothing to check
        // and this gate is a no-op today. Wire it here the moment equipment exists;
        // the message is already the OG's own wording.

        var/confirm = alert(P, "Are you sure you want to change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Classchange", "Yes", "No")
        if(confirm != "Yes") return

        P.BecomeSage()
