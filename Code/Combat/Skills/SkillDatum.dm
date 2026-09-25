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

        // spells.dmi effect art — the spell burst, the swung axe, the whip. A SEPARATE
        // layer from icon_state above, which names a state on the user's own portrait
        // .dmi (their held weapon / swing pose). Resolved by ResolveSkillFXState()
        // (SkillFX.dm), which supports the directional ("thordainns"/"thordainew") and
        // handed ("leftclaw"/"rightclaw") variant pairs that spells.dmi already uses,
        // and draws nothing at all when the named state doesn't exist — so fx_state can
        // be filled in before the art is.
        fx_state = null
        // The burst drawn where the hit lands, when the art ships as a matched pair
        // ("blaze"/"blazehit"). Falls back to fx_state when unset.
        impact_fx_state = null
        // Multiplies the cast meter's per-frame delay (PlayCastMeter(), CombatSystem.dm)
        // -- 1.5 = a windup half again as long. For a spell that should feel slow to cast.
        cast_meter_slowness = 1

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
    // No fx_state on purpose. A plain attack is the portrait's own swing pose plus its
    // "weapon" overlay (icon_state above) — there's no spell effect to draw over it.

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
        if(user.isSleeping) return  // can't raise a shield in bed -- wake up first
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

// Blaze was the first real projectile spell; it now runs on SpellBolt (SkillCatalog.dm)
// with every other bolt, so it shares the cast/flight/impact rules instead of owning a
// copy. OG: /proj/blaze, MP 4, same Int*2+4 formula as Zap -- so Zap's multiplier.
datum/skill/Blaze
    parent_type = /datum/skill/SpellBolt

    skillName = "Blaze"
    icon_state = "blaze"
    fx_state = "blaze"
    impact_fx_state = "blazehit"
    element = "fire"
    damage_multiplier = 0.9
    mana_cost = 4  // OG

// Blaze's art and flight, just faster and harder (user, from the OG, 2026-09-25).
// OG: /proj/firebal also flies with "blaze", MP 4, damage round(Int*2.5)+5 vs Blaze's
// Int*2+4 -- so ~1.25x Blaze's multiplier.
#define FIREBALL_SLOWNESS 0.5  // flight step delay vs. Blaze's -- 0.5 = twice as fast; invented

datum/skill/Fireball
    parent_type = /datum/skill/Blaze
    skillName = "Fireball"
    damage_multiplier = 1.1
    bolt_slowness = FIREBALL_SLOWNESS
