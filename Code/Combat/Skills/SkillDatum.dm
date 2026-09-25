// ***** TEMPORARY TESTING FLAG — REMEMBER TO TURN THIS OFF *****
// While TRUE, every spell costs 1 MP regardless of its real mana_cost. Flip to FALSE
// to restore real per-spell costs — nothing else needs changing (GetManaCost() below
// is the single place any spell should ever read a cost from).
#define TESTING_CHEAP_SPELLS FALSE

// -----------------------------
// datum/skill — the base every skill hangs off. The frameworks (GenericPhysical,
// GenericSpell, SpellBolt, ...) and every named skill live in SkillCatalog.dm; this file
// keeps the base plus the two skills every class has, Attack and Defend.
// -----------------------------
datum/skill
    var
        skillName = "Unnamed Skill"
        description = "No description."
        icon_state = null      // a state on the USER'S portrait .dmi (the held weapon pose)
        cast_time = 0          // melee windup before the hit lands; Rest/Meditate's delay
        mana_cost = 0
        isMelee = FALSE
        isSpell = FALSE
        // Multiplies Strength (physical) or Intelligence (spells) -- lives on the base
        // type so every damage path can read S.damage_multiplier safely.
        damage_multiplier = 1
        // null = "no element" (physical). A spell sets "fire"/"ice"/"lightning" so the
        // element lives on the skill rather than at the ApplySpellDamage() call site.
        element = null

        // spells.dmi effect art — the spell burst, the swung axe, the whip. A SEPARATE
        // layer from icon_state above. Resolved by ResolveSkillFXState() (SkillFX.dm),
        // which supports the directional ("thordainns"/"thordainew") and handed
        // ("leftclaw"/"rightclaw") variant pairs spells.dmi already uses, and draws
        // nothing at all when the named state doesn't exist — so fx_state can be filled
        // in before the art is.
        fx_state = null
        // The burst drawn where a hit lands, when the art ships as a matched pair
        // ("blaze"/"blazehit"). null = no hit art.
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

    // The opening every spell shares: take the MP, lock the caster, announce the cast.
    // FALSE (with a message, nothing spent) when they can't afford it.
    proc/PayToCast(mob/user)
        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return FALSE
        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")
        return TRUE

    // Every spells.dmi state this skill can draw -- for Debug_SkillFXReport()
    // (DebugTools.dm). Skills with extra art (bolts, whips, blasts) add theirs.
    proc/GetArtStates()
        return list(fx_state, impact_fx_state)

// The plain swing: the portrait's own swing pose plus its "weapon" overlay, no spells.dmi
// art. Everything it does is GenericPhysical's (SkillCatalog.dm). See
// Markdowns/CodeNotes.md for the Defend-interaction and animation-timing history.
datum/skill/Attack
    parent_type = /datum/skill/GenericPhysical
    skillName = "Attack"

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
        // Marks this as a real manual toggle — an attack's auto-resume
        // (RestoreDefendIfUntouched()) checks this so it never overrides an explicit
        // toggle made mid-swing.
        user.defendToggleSession++

        user.isDefending = !user.isDefending  // actual damage reduction lives in TakeDamage()
        if(user.isDefending)
            user.icon_state = "defend"
            user.ShowInfo("You raise your shield, bracing for incoming attacks.")
        else
            user.icon_state = "world"
            user.ShowInfo("You lower your shield.")
