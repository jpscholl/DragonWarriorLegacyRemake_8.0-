// ***** TEMPORARY TESTING FLAG — REMEMBER TO TURN THIS OFF *****
// While TRUE, every spell costs 1 MP regardless of its real mana_cost. Flip to FALSE
// to restore real per-spell costs — nothing else needs changing (GetManaCost() below
// is the single place any spell should ever read a cost from).
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
        // Multiplies Strength in PerformMeleeHit() — lives on the base type so that
        // proc can always read S.damage_multiplier safely regardless of skill type.
        // Defaults to 1 so Attack's existing flat-Strength damage is unchanged.
        damage_multiplier = 1
        // null = "no element" (Attack/Defend stay null; physical). A spell sets this
        // to a string like "fire"/"ice" so the element lives on the skill itself
        // rather than being hardcoded at the ApplySpellDamage() call site.
        element = null

    proc/OnUse(mob/user, mob/target = null)
        return

    // Every spell should read its cost through here rather than touching mana_cost
    // directly, so TESTING_CHEAP_SPELLS works for any future spell automatically.
    proc/GetManaCost()
        if(TESTING_CHEAP_SPELLS && mana_cost > 0)
            return 1
        return mana_cost

// See Markdowns/CodeNotes.md for the Defend-interaction and animation-timing history
// behind this OnUse().
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

        // Drop the defend stance for the swing+recovery — auto-resumes below, but
        // only if the player hasn't manually toggled Defend themselves in the
        // meantime (defendToggleSession changing means they did).
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        user.PlayAttackAnimation(user, src, target)

        // Pass the target captured at swing-start (UseSkillSlot()) rather than
        // letting PerformMeleeHit() re-scan the tile ahead once the windup's elapsed.
        spawn(cast_time)
            user.PerformMeleeHit(src, target)
            // Swing landed — let the player move again even though they can't attack
            // again until the full recovery ends (canAct stays FALSE that whole time).
            if(!user.isDead) user.attackRecoveryOnly = TRUE

        // Passing wasDefending (captured above, before the drop), not
        // user.isDefending (already FALSE by now), so the speed penalty still
        // applies for an attack thrown out of a defensive stance.
        spawn(atkDelay)
            // Died while this recovery was pending — Die() already locked canAct
            // intentionally as part of the death/respawn flow; without this check,
            // this deferred callback would silently undo that lock.
            if(user.isDead) return
            user.canAct = TRUE
            user.attackRecoveryOnly = FALSE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// Not melee or spell — a toggled stance. Confirmed OG default for Hero and Soldier
// (Numpad 7), not Wizard. Deliberately NOT gated on canAct — a passive stance toggle,
// not a wind-up action.
#define DEFEND_TOGGLE_COOLDOWN 3  // deciseconds — debounces OS key-repeat on the
                                    // numpad key, see Markdowns/CodeNotes.md
datum/skill/Defend
    parent_type = /datum/skill
    var/lastToggleTime = 0  // per-player — each player gets their own Defend datum instance

    skillName = "Defend"
    icon_state = "defend"  // player holding up their shield

    OnUse(mob/user, mob/target = null)
        if(!user.InBattleArea()) return
        if(world.time - lastToggleTime < DEFEND_TOGGLE_COOLDOWN) return
        lastToggleTime = world.time
        // Marks this as a real manual toggle — Attack.OnUse()'s auto-resume checks
        // this so it never overrides an explicit toggle made mid-swing.
        user.defendToggleSession++

        user.isDefending = !user.isDefending  // actual damage reduction lives in TakeDamage()
        if(user.isDefending)
            user.icon_state = "defend"
            user.ShowInfo("You raise your shield, bracing for incoming attacks.")
        else
            user.icon_state = "world"
            user.ShowInfo("You lower your shield.")

// The real projectile spell system — Fireball below is the old placeholder
// (instant-hit, melee-range only); Blaze is the first spell built against the real
// thing. See Markdowns/CodeNotes.md for the cast-meter and projectile-speed history.
#define PROJECTILE_SPEED_DIVISOR 20
#define PROJECTILE_MIN_STEP_DELAY 0.3

datum/skill/Blaze
    parent_type = /datum/skill

    skillName = "Blaze"
    icon_state = "blaze"  // spells.dmi — also the projectile's own sprite
    isSpell = TRUE
    element = "fire"
    mana_cost = 5  // low, placeholder — tune once seen in action

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Blaze! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE

        // Facing locks the instant the cast starts, captured now rather than re-read
        // at launch time — turning itself isn't blocked by canAct.
        var/castDir = user.dir

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        PlaySFXAt(user, 'spell.wav', base = 70)

        // Cast windup and projectile flight are BOTH driven by GetAttackDelay(), but
        // scaled separately — a windup wants to feel like real commitment, while the
        // projectile just needs to outpace a running player.
        var/atkDelay = user.GetAttackDelay(src, wasDefending)
        var/frameDelay = max(CAST_METER_MIN_FRAME_DELAY, atkDelay / CAST_METER_SPEED_DIVISOR)

        // Cast meter: 10 frames. A fresh image is built per frame and the previous
        // one removed, rather than mutating one image's icon_state in place — BYOND's
        // overlays list stores an immutable snapshot at add-time.
        var/image/prevFrame = null
        for(var/i = 1 to 10)
            var/image/meterFrame = image('castmeter.dmi', user, "[i]")
            meterFrame.layer = user.layer + 0.1  // draw over the caster, not behind
            if(prevFrame)
                user.overlays -= prevFrame
            user.overlays += meterFrame
            prevFrame = meterFrame
            sleep(frameDelay)
        if(prevFrame)
            user.overlays -= prevFrame

        if(user.isDead)
            return  // died mid-cast — don't launch from a corpse or stomp Die()'s canAct lock

        // Launch now that the cast meter has fully played out — never before.
        var/turf/spawnTurf = get_step(user, castDir)
        if(spawnTurf)
            var/obj/projectile/blaze/P = new(spawnTurf)
            P.caster = user
            P.travelDir = castDir
            P.stepDelay = max(PROJECTILE_MIN_STEP_DELAY, atkDelay / PROJECTILE_SPEED_DIVISOR)
            P.damage = 5  // low, placeholder — same as mana_cost above
            P.element = element

            // pierces stays FALSE — confirmed Blaze stops on its first hit.
            P.Launch()

        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

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
        // No hard target requirement — castable at an empty tile, same as Attack.
        // ApplySpellDamage() below already no-ops on a null target.

        user.canAct = FALSE
        user.ShowInfo("You cast Fireball!")

        user.PlayAttackAnimation(user, src, target)

        spawn(cast_time)
            user.ApplySpellDamage(target, 10, src.element)

        // Fireball doesn't drop isDefending the way Attack does — no class currently
        // has both Defend and Fireball equipped — so user.isDefending is still
        // accurate here; it still picks up the speed penalty, just without the
        // auto-drop/resume dance.
        spawn(user.GetAttackDelay(src, user.isDefending))
            if(user.isDead) return
            user.canAct = TRUE
