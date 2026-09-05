// -----------------------------
// Base Mob
// -----------------------------
mob
    see_invisible = 0

    // Gates whether a mob can move or start a new action — checked by mob/proc/Step()
    // (Code/Core/SmoothMovement.dm). See Markdowns/CodeNotes.md for the full set of
    // cases this covers and how it interacts with attackRecoveryOnly below.
    var/canAct = 1

    // TRUE for the recovery tail of a melee swing only: canAct stays FALSE (can't
    // attack again yet) but movement is allowed again. FALSE for every other
    // canAct=FALSE case, which fully roots the mob.
    var/attackRecoveryOnly = 0

    // Basic character info
    var
        class = null
        Level = 1
        Exp = 0
        Nexp = 100
        Gold = 30

    // Exp/Gold granted to whoever kills this mob (Die(), CombatSystem.dm). Live on the
    // base mob (not mob/enemy) so PvP kills have defined values too; real per-tier
    // numbers are set on monster subtypes (Code/Combat/NPCs/MonsterRoster.dm).
    var/expReward = 10
    var/goldReward = 0

    // Session-only, not saved. Enforced in the chat verbs (SocialVerbs.dm/
    // PartyVerbs.dm); set by GM_Mute (GMCommands.dm).
    var
        isMuted = FALSE

    // Set right before forcibly disconnecting a client (GM_Ban/GM_Boot, GMCommands.dm)
    // so SaveAndLogout() (Main.dm) skips its normal save on the way out.
    var
        skipSaveOnLogout = FALSE

    // Session-only, not saved (Party.dm). Declared at base mob level so Die()'s
    // attacker.Party check (CombatSystem.dm) doesn't need an istype guard.
    var
        datum/party/Party = null
        isPartyLeader = FALSE

    // Session-only, not saved, one at a time (EnemyNPCs.dm's owner/petName/petMode).
    var
        mob/enemy/pet = null

    // Health & Mana
    var
        HP = 30
        MaxHP = 30
        MP = 0
        MaxMP = 0
        hasMana = TRUE  // FALSE keeps MaxMP at 0 regardless of Intelligence — see
                         // RecalculateVitals() (StatsDatum.dm).

    // Per-class HP/MP multipliers, applied in RecalculateVitals() (StatsDatum.dm).
    var
        HPfactor = 1.0
        MPfactor = 1.0

    // Core stats
    var
        Strength = 1
        Vitality = 1
        Agility = 1
        Intelligence = 1
        Spirit = 1
        StatPoints = 0

    // Per-class stat ceilings — enforced at both creation-time allocation
    // (StatAllocation(), LoginMenu.dm) and level-up stat spend (obj/StatLink/Click(),
    // ClickableStats.dm) via GetClassStatCaps() below.
    var
        capStrength = 10
        capAgility = 10
        capVitality = 10
        capIntelligence = 10
        capSpirit = 10

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

// SaveAndLogout() (Main.dm) uses this instead of client.saveManager, since client can
// already be null by the time Logout() fires on an abrupt disconnect.
mob/player
    var/datum/SaveManager/saveManager

// -----------------------------
// Player Mob
// -----------------------------
mob/player
    New()
        ..()
        HidePartyVerbs()
        RegenLoop()  // passive HP/MP regeneration (StatsDatum.dm)

    pixel_y = SPRITE_PIXEL_Y_OFFSET

    // Party tab (partykick/leave/recruit/say/share/who) only shown while in a party.
    proc/ShowPartyVerbs()
        src.verbs += PARTY_VERBS

    proc/HidePartyVerbs()
        src.verbs -= PARTY_VERBS

    // skills = everything this character KNOWS (the "Free Skills" pool);
    // skillSlots = what's equipped to each numpad key.
    var/list/skills = list()
    var/list/skillSlots = alist(9 = null, 7 = null, 3 = null, 1 = null, 0 = null)

    // Triggered by the Numpad9/7/3/1/0 macros (Interface.dmf) via
    // client/verb/UseSkillKey (SmoothMovement.dm).
    proc/UseSkillSlot(slotNum)
        var/datum/skill/S = skillSlots[slotNum]
        if(!S) return

        // Every skill funnels through here, so this is the one place silence needs
        // enforcing (not duplicated in each skill's own OnUse()).
        if(S.isSpell && isSilenced)
            src.ShowInfo("You are silenced and cannot cast!")
            return

        // Only the tile directly in front — a melee swing should only threaten what
        // you're actually facing.
        var/mob/target = null
        var/turf/stepTile = get_step(src, src.dir)
        if(stepTile)
            for(var/mob/M in stepTile.contents)
                if(M == src) continue
                if(M.HP <= 0) continue
                target = M
                break

        S.OnUse(src, target)

    // Starting-kit granting and leveled unlocks both live in SkillUnlocks.dm.

    proc/IsSkillEquipped(datum/skill/S)
        for(var/slotNum in skillSlots)
            if(skillSlots[slotNum] == S) return TRUE
        return FALSE

    // Battle-tab skill display (StatPanels.dm) — real draggable objs (obj/SkillLink,
    // SkillLink.dm), cached per slot/skill and refreshed rather than recreated.
    var/list/numpadSkillLinks = alist(9 = null, 7 = null, 3 = null, 1 = null, 0 = null)
    var/list/freeSkillLinks = list()  // assoc: datum/skill -> obj/SkillLink
    var/obj/SkillLink/freeSkillsAreaLink  // drop target for unequipping

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

        // Prune entries for skills no longer unequipped, so this can't grow unbounded.
        for(var/datum/skill/cached in freeSkillLinks)
            if(!(cached in stillKnown))
                freeSkillLinks -= cached

        return result

// -----------------------------
// Class Overrides — see Markdowns/CodeNotes.md for which cap numbers are OG-confirmed
// vs. placeholder guesses.
// -----------------------------
mob/player/Hero
    class = "Hero"
    HPfactor = 1.0
    MPfactor = 1.0
    capStrength = 60
    capAgility = 60
    capVitality = 80
    capIntelligence = 150
    capSpirit = 60

mob/player/Soldier
    class = "Soldier"
    hasMana = FALSE
    HPfactor = 1.3
    capStrength = 100
    capAgility = 60
    capVitality = 100
    capIntelligence = 20
    capSpirit = 40

mob/player/Wizard
    class = "Wizard"
    HPfactor = 0.7
    MPfactor = 1.3
    capStrength = 40
    capAgility = 40
    capVitality = 60
    capIntelligence = 100
    capSpirit = 60

mob/player/Fighter
    class = "Fighter"
    hasMana = FALSE
    HPfactor = 0.85
    capStrength = 100
    capAgility = 100
    capVitality = 80
    capIntelligence = 40
    capSpirit = 40

mob/player/Pilgrim
    class = "Pilgrim"
    MPfactor = 1.1
    capStrength = 80
    capAgility = 60
    capVitality = 60
    capIntelligence = 100
    capSpirit = 60

mob/player/Goofoff
    class = "Goof-off"
    hasMana = FALSE
    HPfactor = 0.9
    capStrength = 80
    capAgility = 60
    capVitality = 60
    capIntelligence = 40
    capSpirit = 40

mob/player/Sage
    class = "Sage"
    HPfactor = 0.7
    MPfactor = 1.3
    capStrength = 40
    capAgility = 40
    capVitality = 60
    capIntelligence = 150
    capSpirit = 60

// Personal test-bed class (Cerebella-only — see PromptForClass()'s AEON_CKEY gate,
// LoginMenu.dm; never offered to a normal player). Every stat capped at 300 and
// HP/MP hardcoded flat at 10,000 (RecalculateVitals() override below) so testing a
// skill/spell is never gated by stats, level, or running out of mana.
mob/player/Archsage
    class = "Archsage"
    capStrength = 300
    capAgility = 300
    capVitality = 300
    capIntelligence = 300
    capSpirit = 300

mob/player/Archsage/RecalculateVitals()
    var/oldMaxHP = MaxHP
    var/oldMaxMP = MaxMP

    MaxHP = 10000
    HP += max(0, MaxHP - oldMaxHP)

    MaxMP = 10000
    MP += max(0, MaxMP - oldMaxMP)

// Class name -> type lookup — the one place this switch exists.
proc/GetPlayerClassType(class_name)
    switch(class_name)
        if("Hero")     return /mob/player/Hero
        if("Soldier")  return /mob/player/Soldier
        if("Wizard")   return /mob/player/Wizard
        if("Fighter")  return /mob/player/Fighter
        if("Pilgrim")  return /mob/player/Pilgrim
        if("Goof-off") return /mob/player/Goofoff
        if("Sage")     return /mob/player/Sage
        if("Archsage") return /mob/player/Archsage
    return null

// Resolves a class NAME to its type's cap values via initial(type:var) — no throwaway
// mob spawn/delete just to read 5 numbers. Memoized since this gets called on every
// stat-point click.
var/list/classStatCapCache = list()

proc/GetClassStatCaps(class_name)
    if(class_name in classStatCapCache)
        return classStatCapCache[class_name]

    var/type = GetPlayerClassType(class_name)
    if(!type)
        return null

    var/list/caps = list(
        "Strength"     = initial(type:capStrength),
        "Vitality"     = initial(type:capVitality),
        "Agility"      = initial(type:capAgility),
        "Intelligence" = initial(type:capIntelligence),
        "Spirit"         = initial(type:capSpirit)
    )

    classStatCapCache[class_name] = caps
    return caps

// Sage reclass flow — Classchange (SkillCatalog.dm) calls this BEFORE BecomeSage()
// below. Re-runs the real character creation flow (icon, colors, stats) on the
// EXISTING player mob P via IconSelect()/CustomizeColors()/StatAllocation()
// (LoginMenu.dm), rather than a straight carry-over of the old appearance/stats.
// Returns TRUE once finished (icon + colors + all stat points spent), FALSE if the
// player backs out at the icon step — backing out never touches P's real stats, since
// StatAllocation() only commits on its "Finish" branch.
proc/RunSageReclassFlow(mob/player/P)
    P.selectedClass = "Sage"  // restricts IconSelect()'s picker to Sage's own portraits

    var/step = STEP_ICON
    while(step)
        switch(step)
            if(STEP_ICON)
                step = IconSelect(P)
                if(step == STEP_CLASS)
                    return FALSE  // "Back" at the icon step = cancel the whole reclass

            if(STEP_CUSTOM)
                P.IconPreview()
                step = P.CustomizeColors()

            if(STEP_STATS)
                step = StatAllocation(P)
                if(step == STEP_STATS)
                    return TRUE

// Sage reclass — Goof-off's Classchange skill (SkillCatalog.dm) hands off here after
// RunSageReclassFlow() has staged fresh icon/color/stat picks directly on P's own
// vars. Spawns a fresh mob/player/Sage, transplants those freshly-chosen values (not
// the old character's), transfers control, and deletes the old mob.
mob/player/proc/BecomeSage()
    if(!client) return

    var/client/C = client
    var/mob/player/Sage/newMob = new /mob/player/Sage
    var/turf/T = loc

    // Appearance from the FRESH picks RunSageReclassFlow() just staged on P, not the
    // old character's own icon/baseIcon/basePlayerIcon.
    newMob.name = name
    newMob.icon = icon(selectedIcon)
    newMob.icon_state = "world"
    newMob.baseIcon = selectedIcon
    newMob.basePlayerIcon = selectedIconName
    newMob.hairColor = hairColor
    newMob.eyeColor = eyeColor
    newMob.mainColor = mainColor
    newMob.accentColor = accentColor
    newMob.palette = palette
    if(newCharPreview) del newCharPreview  // would otherwise sit orphaned forever

    // Progress resets like a genuinely fresh character (CONFIRMED OG behavior — the
    // classchange prompt itself says "you will be set back to level 1").
    newMob.Level = 1
    newMob.Exp = 0
    newMob.Nexp = BASE_EXP
    newMob.Gold = Gold
    // Not copied from the OLD character — P's own Strength/etc were already
    // overwritten in place by StatAllocation() inside RunSageReclassFlow(), so reading
    // them off P here already gives the fresh allocation.
    newMob.Strength = Strength
    newMob.Vitality = Vitality
    newMob.Agility = Agility
    newMob.Intelligence = Intelligence
    newMob.Spirit = Spirit
    newMob.StatPoints = 0  // StatAllocation() enforces spending every point first

    // Skills carry over as-is, including anything the old class could learn that
    // Sage's own table never would — you don't unlearn things by changing class.
    newMob.skills = skills
    newMob.skillSlots = skillSlots

    // Items live directly in mob.contents (Inventory.dm) — this IS the transfer.
    for(var/obj/item/I in contents)
        I.loc = newMob

    newMob.isCharacter = isCharacter
    newMob.saveSlot = saveSlot
    newMob.saveManager = saveManager

    // Recomputed fresh and topped off to full, same as any new character
    // (FinalizePlayer()) — not carried over and clamped down from the old HP/MP.
    newMob.RecalculateVitals()
    newMob.HP = newMob.MaxHP
    newMob.MP = newMob.MaxMP

    newMob.loc = T

    C.mob = newMob
    C.SyncGMVerbs()
    C.AttachCamera(newMob)  // camera (SmoothMovement.dm) — reassigning .mob alone leaves eye on the old, about-to-be-deleted mob

    // This swap replaces an EXISTING character already in players (unlike
    // FinalizePlayer()/LoadCharacter(), which only ever add a new one).
    players -= src
    players += newMob

    newMob.ShowInfo("You feel your form shift... you have become a Sage!")

    del src
