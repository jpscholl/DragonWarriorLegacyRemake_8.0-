// -----------------------------
// Base Skill
// -----------------------------
// ***** TEMPORARY TESTING FLAG — REMEMBER TO TURN THIS OFF *****
// While TRUE, every spell costs 1 MP regardless of its real mana_cost, so spells can
// be cast repeatedly while tuning them. Flip to FALSE to restore real per-spell costs;
// nothing else needs changing (see GetManaCost() below, which is the single place any
// spell should ever read a cost from).
#define TESTING_CHEAP_SPELLS FALSE

datum/skill
    var
        skillName = "Unnamed Skill"
        description = "No description."
        icon_state = null
        cast_time = 0          // time before effect happens (animations/projectiles)
        mana_cost = 0
        isMelee = FALSE
        isSpell = FALSE
        // Multiplies Strength in PerformMeleeHit() (CombatSystem.dm) — lives on the
        // base type (not just GenericPhysical, SkillCatalog.dm) so that proc can always
        // read S.damage_multiplier safely regardless of skill type. Defaults to 1 so
        // Attack's existing flat-Strength damage is unchanged.
        damage_multiplier = 1
        // Elemental scaffolding — null means "no element" (Attack/Defend stay null;
        // physical). A spell sets this to a string like "fire"/"ice" instead of
        // hardcoding it at the ApplySpellDamage() call site, so the element lives on
        // the skill itself. See CombatSystem.dm's ApplySpellDamage() and the
        // elementalWeakness/elementalResistance mob vars for the other half of this.
        element = null

    proc/OnUse(mob/user, mob/target = null)
        // Base skill does nothing
        return

    // Every spell should read its cost through here rather than touching mana_cost
    // directly — that keeps the TESTING_CHEAP_SPELLS override (above) working for any
    // future spell automatically, instead of needing each one edited by hand. Skills
    // with no cost at all (mana_cost 0, e.g. Attack/Defend) stay free either way.
    proc/GetManaCost()
        if(TESTING_CHEAP_SPELLS && mana_cost > 0)
            return 1
        return mana_cost

// -----------------------------
// Melee Attack Skill
// -----------------------------
datum/skill/Attack
    parent_type = /datum/skill

    skillName = "Attack"
    icon_state = "weapon"
    isMelee = TRUE
    cast_time = 2

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        // Can't hold a steady shield and swing a sword through it at the same instant
        // — drop the defend stance for the swing+recovery, same window canAct already
        // covers. Auto-resumes below, but only if the player hasn't manually toggled
        // Defend themselves in the meantime (defendToggleSession changing means they
        // did — e.g. deliberately lowered their shield mid-swing), so this can't
        // stomp an explicit toggle. This dropped window is the main balance lever for
        // Defend: attack a lot while defending and you spend most of your time
        // unshielded (faster kills, less mitigation); attack rarely and you stay
        // shielded most of the time (slower kills, more mitigation). On top of that,
        // GetAttackDelay() (CombatSystem.dm) also applies a small flat speed penalty
        // when wasDefending — attacking out of a braced stance is a little slower to
        // throw regardless, not just less protected.
        var/mySession = user.defendToggleSession  // captured before the drop below, so
                                                     // the restore can tell whether the
                                                     // player manually toggled Defend
                                                     // themselves while this was resolving
        var/wasDefending = user.DropDefendForAction()

        // Play melee animation & sound (src is this skill datum, matching
        // PlayAttackAnimation's real signature: mob/user, datum/skill/S, mob/target)
        user.PlayAttackAnimation(user, src, target)

        // Apply damage after cast_time (PerformMeleeHit expects a skill datum, not a
        // target mob — it already finds whoever's on the tile in front of user itself)
        spawn(cast_time)
            user.PerformMeleeHit(src)

        // Re-enable action based on stats (src is this skill datum, which is what
        // GetAttackDelay actually needs to check isMelee/isSpell against). Passing
        // wasDefending (captured above, before the drop) — not user.isDefending,
        // which is already FALSE by now — so the speed penalty still applies for an
        // attack thrown out of a defensive stance.
        spawn(user.GetAttackDelay(src, wasDefending))
            // Died while this recovery was still pending (e.g. the enemy who's about
            // to eat this hit gets a hit in first) — Die() (CombatSystem.dm) already
            // locked canAct intentionally as part of the death/respawn flow; without
            // this check, this deferred callback would silently undo that lock and
            // let a "dead" player move again before actually respawning. Pre-existing
            // gap, found while adding the Defend auto-resume logic above.
            if(user.isDead) return
            user.canAct = TRUE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Defend Skill
// -----------------------------
// Not melee or spell — a toggled stance, not a one-shot action. Confirmed OG default
// for Hero and Soldier (equipped to Numpad 7), not Wizard — see GetStartingKit()
// (Code/Player/SkillUnlocks.dm). Deliberately NOT gated on canAct (unlike Attack/Fireball) —
// it's a passive stance toggle, not a wind-up action, so there's no reason to block it
// mid-swing.
#define DEFEND_TOGGLE_COOLDOWN 3  // deciseconds — holding the numpad key down fires
                                    // UseSkillKey repeatedly (same OS key-repeat that
                                    // lets you hold-to-attack), and Attack's own
                                    // canAct cooldown happens to swallow those repeats
                                    // silently. Defend has nothing gating it the same
                                    // way, so every repeat flipped the toggle again —
                                    // rapid on/off/on/off while held instead of one
                                    // clean toggle. This debounces it: short enough not
                                    // to feel laggy on a deliberate press, long enough
                                    // to eat the OS repeat rate.
datum/skill/Defend
    parent_type = /datum/skill
    var/lastToggleTime = 0  // per-player — each player gets their own Defend datum
                              // instance (EquipSkill(), SkillUnlocks.dm), so this can't
                              // leak between players

    skillName = "Defend"
    icon_state = "defend"  // player holding up their shield

    OnUse(mob/user, mob/target = null)
        if(!user.InBattleArea()) return
        if(world.time - lastToggleTime < DEFEND_TOGGLE_COOLDOWN) return
        lastToggleTime = world.time
        // Marks this as a real manual toggle — Attack.OnUse()'s auto-resume checks
        // this so it never overrides an explicit toggle made mid-swing.
        user.defendToggleSession++

        user.isDefending = !user.isDefending  // actual damage reduction lives in
                                                // TakeDamage(), CombatSystem.dm
        if(user.isDefending)
            user.icon_state = "defend"
            user << output("You raise your shield, bracing for incoming attacks.", "Info")
        else
            user.icon_state = "world"
            user << output("You lower your shield.", "Info")

// -----------------------------
// Blaze Spell Skill
// -----------------------------
// The real projectile spell system (confirmed design, see TODOList.md's "Real spell
// system" entry) — Fireball above is the old placeholder (instant-hit, melee-range
// only); Blaze is the first spell actually built against the real thing.

// Cast windup speed. Total windup = 10 frames * frameDelay, so at the divisor below a
// fresh level-1 caster winds up in a bit over a second, and a high-Intelligence one
// noticeably faster. Bigger divisor = snappier cast.
#define CAST_METER_SPEED_DIVISOR 10
#define CAST_METER_MIN_FRAME_DELAY 0.5

// Projectile flight speed, scaled separately from the windup above. For reference, a
// player moves one tile per 1.36 deciseconds (step_delay, SmoothMovement.dm) — anything
// at or above that number here means the spell can be outrun on foot, which is exactly
// what the first playtest hit. These values put it roughly 2-4x player speed.
#define PROJECTILE_SPEED_DIVISOR 20
#define PROJECTILE_MIN_STEP_DELAY 0.3

datum/skill/Blaze
    parent_type = /datum/skill

    skillName = "Blaze"  // no, we are not adding a THC damage-over-time effect,
                          // put the pipe down and finish reviewing the projectile code
    icon_state = "blaze"  // spells.dmi — this is also the projectile's own sprite
    isSpell = TRUE
    element = "fire"
    mana_cost = 5  // low, placeholder per your own guidance — tune once you've
                    // actually seen it in action

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        // GetManaCost(), not mana_cost — respects the TESTING_CHEAP_SPELLS override
        var/cost = GetManaCost()
        if(user.MP < cost)
            user << output("Not enough MP to cast Blaze! (need [cost])", "Info")
            return

        user.MP -= cost
        user.canAct = FALSE

        // Facing locks the instant the cast starts (confirmed default, may change
        // later) — captured now rather than re-read at launch time, since turning
        // itself isn't blocked by canAct (only stepping is), so this cached value is
        // what actually enforces the lock regardless of any turning attempted during
        // the windup below.
        var/castDir = user.dir

        // Same "can't hold a shield up and cast at the same time" logic Attack uses
        // (DropDefendForAction()/RestoreDefendIfUntouched(), CombatSystem.dm) — a Hero
        // can have both Defend and Blaze equipped (PlayerTemplate.dm's confirmed
        // starting kits), unlike Wizard/Fireball.
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        PlaySFXAt(user, 'spell.wav', base = 70)

        // Cast windup and projectile flight are BOTH driven by the same
        // Agility+Intelligence formula (GetAttackDelay(), CombatSystem.dm — wasDefending
        // applies the same flat penalty Attack/Fireball get), but they're deliberately
        // scaled separately now: a windup wants to feel like real commitment, while the
        // projectile just needs to outpace a running player. They used to share one
        // number, which is how the spell ended up slower than walking.
        var/atkDelay = user.GetAttackDelay(src, wasDefending)
        var/frameDelay = max(CAST_METER_MIN_FRAME_DELAY, atkDelay / CAST_METER_SPEED_DIVISOR)

        // Cast meter: 10 frames (castmeter.dmi, icon_states "1" through "10").
        // A fresh image is built per frame and the previous one removed, rather than
        // mutating one image's icon_state in place — BYOND's overlays list stores an
        // immutable *snapshot* of an appearance when you add it, so mutating the
        // original afterward changes nothing on screen. That was the real reason the
        // meter never appeared at all in the first playtest: it was added once with no
        // icon_state set (rendering nothing), and every "[i]" assignment after that
        // updated an object the overlay list no longer cared about.
        var/image/prevFrame = null
        for(var/i = 1 to 10)
            var/image/meterFrame = image('castmeter.dmi', user, "[i]")
            meterFrame.layer = user.layer + 0.1  // draw over the caster, not behind
            if(prevFrame)
                user.overlays -= prevFrame
            user.overlays += meterFrame
            prevFrame = meterFrame  // never mutated after being added, so the removal
                                     // above always matches the exact appearance added
            sleep(frameDelay)
        if(prevFrame)
            user.overlays -= prevFrame

        if(user.isDead)
            return  // died mid-cast — no interruption logic yet (confirmed, subject to
                      // change), but don't launch from a corpse or stomp Die()'s own
                      // canAct lock the way the pre-existing Attack/Fireball bug did

        // Launch now that the cast meter has fully played out — never before, per the
        // confirmed design.
        var/turf/spawnTurf = get_step(user, castDir)
        if(spawnTurf)
            var/obj/projectile/blaze/P = new(spawnTurf)
            P.caster = user
            P.travelDir = castDir
            P.stepDelay = max(PROJECTILE_MIN_STEP_DELAY, atkDelay / PROJECTILE_SPEED_DIVISOR)
            P.damage = 5  // low, placeholder — same as mana_cost above
            P.element = element

            // pierces stays FALSE (the default, Projectiles.dm) — confirmed Blaze
            // stops on its first hit; a future piercing skill like Thornwhip would
            // set this TRUE instead.
            P.Launch()

        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Fireball Spell Skill
// -----------------------------
datum/skill/Fireball
    parent_type = /datum/skill

    skillName = "Fireball"
    icon_state = "fireball"
    isSpell = TRUE
    cast_time = 6
    element = "fire"

    OnUse(mob/user, mob/target)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        // No hard target requirement — castable in a battle area even at an empty
        // tile, same as Attack (PerformMeleeHit() just finds nobody there). Damage
        // only happens if target is actually present: ApplySpellDamage() below
        // already no-ops on a null target, and PlayAttackAnimation() (CombatSystem.dm)
        // already falls back to a turf-based effect instead of an on-target overlay.

        user.canAct = FALSE
        user << output("You cast Fireball!", "Info")

        // Play spell animation & sound (src is this skill datum, matching
        // PlayAttackAnimation's real signature: mob/user, datum/skill/S, mob/target)
        user.PlayAttackAnimation(user, src, target)

        // Apply damage after cast_time — src.element (set above), not a hardcoded
        // "fire" string, so the element lives on the skill datum itself
        spawn(cast_time)
            user.ApplySpellDamage(target, 10, src.element)

        // Re-enable action based on stats (src is this skill datum, which is what
        // GetAttackDelay actually needs to check isMelee/isSpell against). Fireball
        // doesn't drop isDefending the way Attack does (a spellcaster gesturing with
        // a free hand while a shield's up is a lot more plausible than swinging a
        // sword through one — and no class currently has both Defend and Fireball
        // equipped anyway), so user.isDefending is still accurate here; it still
        // picks up the speed penalty below, just without the auto-drop/resume dance.
        spawn(user.GetAttackDelay(src, user.isDefending))
            // See Attack.OnUse()'s identical check above for why this guard exists.
            if(user.isDead) return
            user.canAct = TRUE
