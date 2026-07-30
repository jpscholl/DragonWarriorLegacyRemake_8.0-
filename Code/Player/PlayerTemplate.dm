// -----------------------------
// Base Mob
// -----------------------------
mob
    see_invisible = 0

    // Shared "can this mob currently move or act" gate, checked by mob/proc/Step()
    // (Code/Core/SmoothMovement.dm) so a single flag roots a mob in place regardless
    // of WHY: mid-attack swing/cast (SkillDatum.dm), dead (Die(), CombatSystem.dm),
    // falling through a turf/sky (Code/World/Turfs.dm). Enemies (EnemyNPCs.dm) reuse
    // it the same way for their own attack cooldown, and since their movement also
    // goes through Step(), an attacking enemy is naturally rooted mid-swing too.
    var/canAct = 1


    // Basic character info
    var
        class = null
        Level = 1
        Exp = 0
        Nexp = 100
        Gold = 30

    // Muted — session-only, not saved. Enforced in the chat verbs
    // (SocialVerbs.dm/PartyVerbs.dm); GMmute verb itself not built yet (TODOList.md).
    var
        isMuted = FALSE

    // Party — session-only, not saved (Code/Player/Party.dm). Declared at base mob
    // level (not mob/player) so Die()'s attacker.Party check in CombatSystem.dm
    // doesn't need an istype guard for non-player attackers.
    var
        datum/party/Party = null
        isPartyLeader = FALSE

    // Health & Mana
    var
        HP = 30
        MaxHP = 30
        MP = 0
        MaxMP = 0
        hasMana = TRUE  // FALSE keeps MaxMP at 0 regardless of Intelligence — see
                         // RecalculateVitals() in Code/Player/StatsDatum.dm. Overridden
                         // per-class below (Soldier has none).

    // Core stats
    var
        Strength = 1
        Vitality = 1
        Agility = 1
        Intelligence = 1
        Luck = 1
        StatPoints = 0

// Appearance
mob
    var
        icon/baseIcon        // template sprite used for save/load recoloring
        basePlayerIcon
        hairColor
        eyeColor
        mainColor
        accentColor

// Save slot this character occupies (1-4)
mob
    var
        saveSlot = 0

// The mob's own reference to the SaveManager that created/loaded it (set once in
// FinalizePlayer()/LoadCharacter(), both LoginMenu.dm/SaveSystem.dm) — SaveAndLogout()
// (Main.dm) uses this instead of going through client.saveManager, because on an
// abrupt disconnect (closing the window, vs a graceful quit) client can already be
// null by the time Logout() fires, which silently skipped the save with no error.
mob/player
    var/datum/SaveManager/saveManager

// -----------------------------
// Player Mob
// -----------------------------
mob/player
    New()
        ..()  // call base constructor
        HidePartyVerbs()  // Party tab only appears once actually in a party — see
                           // ShowPartyVerbs()/HidePartyVerbs() below and Party.dm

    pixel_y = SPRITE_PIXEL_Y_OFFSET

    // -----------------------------
    // Party tab visibility (Code/Player/Commands/PartyVerbs.dm)
    // -----------------------------
    // The Party tab (partykick/leave/recruit/say/share/who) is only meaningful once
    // you're in a party — same idea as EnableCommands()/DisableCommands() (PlayerVerbs.dm)
    // gating the whole verb panel during login, just scoped to this one tab instead.
    proc/ShowPartyVerbs()
        src.verbs += PARTY_VERBS

    proc/HidePartyVerbs()
        src.verbs -= PARTY_VERBS

    // Skills — skills is every skill this character KNOWS (the "Free Skills" pool,
    // see ClassReference.md's "Skills vs. equipped skills" note); skillSlots is what's
    // actually equipped to each numpad key. Numpad 9/7/3/1/0 chosen to match the
    // confirmed OG layout — this repurposes what used to be diagonal-movement macros
    // (Interface.dmf), since this game doesn't use diagonal movement (matches classic
    // Dragon Warrior, 4-directional only).
    var/list/skills = list()
    // Numeric literal keys aren't allowed in a plain list() constructor (BYOND reads
    // "9 = null" as a named-argument pair, which requires an identifier) — alist()
    // is the built-in workaround for exactly this case.
    var/list/skillSlots = alist(9 = null, 7 = null, 3 = null, 1 = null, 0 = null)

    // -----------------------------
    // Skill Methods
    // -----------------------------
    // Triggered by the Numpad9/7/3/1/0 macros (Interface.dmf) via client/verb/UseSkillKey
    // (Code/Core/SmoothMovement.dm).
    proc/UseSkillSlot(slotNum)
        var/datum/skill/S = skillSlots[slotNum]
        if(!S) return

        var/mob/target = null
        var/turf/stepTile = get_step(src, src.dir)
        if(stepTile)
            // Pick the first other mob standing on the tile in front of us
            for(var/mob/M in stepTile.contents)
                if(M == src) continue
                target = M
                break

        S.OnUse(src, target)

    // Starting kit granting (EquipSkill()/EquipStartingKit(), GetStartingKit() per
    // class) and leveled unlocks (GetSkillUnlocks() per class, CheckSkillUnlocks())
    // both live in Code/Player/SkillUnlocks.dm — one shared mechanism for "give this
    // mob this skill", whether that happens at creation or later from leveling.

    proc/IsSkillEquipped(datum/skill/S)
        for(var/slotNum in skillSlots)
            if(skillSlots[slotNum] == S) return TRUE
        return FALSE

    // -----------------------------
    // Battle-tab skill display (StatPanels.dm) — real draggable objs (obj/SkillLink,
    // Code/Player/SkillLink.dm), same caching pattern as the obj/StatLink stat-alloc
    // links (ClickableStats.dm): create once per slot/skill, reuse and just refresh
    // the displayed data on subsequent Stat() calls, rather than leaking a fresh obj
    // instance on every panel refresh.
    // -----------------------------
    var/list/numpadSkillLinks = alist(9 = null, 7 = null, 3 = null, 1 = null, 0 = null)
    var/list/freeSkillLinks = list()  // assoc: datum/skill -> obj/SkillLink
    var/obj/SkillLink/freeSkillsAreaLink  // dedicated drop target for unequipping —
                                            // needed even when Free Skills is empty,
                                            // since there'd otherwise be nothing to
                                            // drop an equipped skill onto

    proc/GetFreeSkillsAreaLink()
        if(!freeSkillsAreaLink)
            freeSkillsAreaLink = new /obj/SkillLink(src, null, null)
        return freeSkillsAreaLink

    proc/GetNumpadSkillLink(slotNum)
        var/obj/SkillLink/L = numpadSkillLinks[slotNum]
        if(!L)
            L = new /obj/SkillLink(src, skillSlots[slotNum], slotNum)
            numpadSkillLinks[slotNum] = L
        else
            L.S = skillSlots[slotNum]
            L.UpdateName()
        return L

    proc/GetFreeSkillLinks()
        var/list/result = list()
        var/list/stillKnown = list()

        for(var/datum/skill/S in skills)
            if(IsSkillEquipped(S)) continue
            stillKnown += S

            var/obj/SkillLink/L = freeSkillLinks[S]
            if(!L)
                L = new /obj/SkillLink(src, S)
                freeSkillLinks[S] = L
            result += L

        // Prune cache entries for skills that are no longer unequipped (either just
        // got equipped, or — not currently possible, but future-proofing — removed
        // outright), so this doesn't grow unbounded over a long session.
        for(var/datum/skill/cached in freeSkillLinks)
            if(!(cached in stillKnown))
                freeSkillLinks -= cached

        return result

// -----------------------------
// Class Overrides
// -----------------------------
mob/player/Hero
    class = "Hero"

mob/player/Soldier
    class = "Soldier"
    hasMana = FALSE

mob/player/Wizard
    class = "Wizard"
