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

    // Exp/Gold granted to whoever kills this mob (Die(), CombatSystem.dm). Live on the
    // base mob rather than mob/enemy so a PvP kill has defined values too; real per-tier
    // numbers are set on the monster subtypes (Code/Combat/NPCs/MonsterRoster.dm).
    // PLACEHOLDER: expReward's 10 was the old hardcoded flat reward for every kill.
    // goldReward is new — nothing in the game granted Gold at all before this (it was
    // display-only, saved and halved on death with no way to ever earn any).
    var/expReward = 10
    var/goldReward = 0

    // Muted — session-only, not saved. Enforced in the chat verbs
    // (SocialVerbs.dm/PartyVerbs.dm); set by GM_Mute (GMCommands.dm).
    var
        isMuted = FALSE

    // Set right before forcibly disconnecting a client (GM_Ban/GM_Boot,
    // GMCommands.dm) — tells SaveAndLogout() (Main.dm) to skip its normal save, so
    // the disconnect doesn't immediately overwrite the ban flag / undo the lost
    // progress with a fresh save on the way out.
    var
        skipSaveOnLogout = FALSE

    // Party — session-only, not saved (Code/Player/Party.dm). Declared at base mob
    // level (not mob/player) so Die()'s attacker.Party check in CombatSystem.dm
    // doesn't need an istype guard for non-player attackers.
    var
        datum/party/Party = null
        isPartyLeader = FALSE

    // Owned pet — session-only, not saved, one at a time for now (Code/Combat/NPCs/
    // EnemyNPCs.dm's owner/petName/petMode vars, ShowAssignPetMenu()/
    // ShowPetOwnerMenu()). Declared at base mob level, same reasoning as Party above.
    var
        mob/enemy/pet = null

    // Health & Mana
    var
        HP = 30
        MaxHP = 30
        MP = 0
        MaxMP = 0
        hasMana = TRUE  // FALSE keeps MaxMP at 0 regardless of Intelligence — see
                         // RecalculateVitals() in Code/Player/StatsDatum.dm. Overridden
                         // per-class below (Soldier has none).

    // Per-class HP/MP multipliers, applied in RecalculateVitals() (StatsDatum.dm) —
    // the OG confirms these existed (HPfactor/MPfactor vars, OGGameStructure.md §4) but
    // not their real values, so a Soldier and a Wizard at equal Vitality no longer come
    // out with identical HP. PLACEHOLDER numbers, grounded in the OG help file's own
    // class flavor text ("Soldiers are the best class at taking damage", "Wizard: very
    // weak in physical combat... most powerful offensive magic", etc.) rather than
    // invented from nothing — tune by feel per class below.
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
    // ClickableStats.dm) via GetClassStatCaps() below. Confirmed numbers pulled from
    // ClassReference.md; every gap it marks `?` gets a `// PLACEHOLDER:` value here,
    // set per-class further down.
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
        RegenLoop()  // passive HP/MP regeneration (Code/Player/StatsDatum.dm)

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

        // Centralized here rather than duplicated in every spell's own OnUse() (which
        // is how Fireball/Blaze ended up missing it entirely, and Sleep/Sleepmore/
        // Stopspell/Return/Revive/GenericSpell each had their own copy of the same
        // check — SkillCatalog.dm) — every skill funnels through this one proc, so
        // this is the single place silence actually needs to be enforced.
        if(S.isSpell && isSilenced)
            src << output("You are silenced and cannot cast!", "Info")
            return

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
    HPfactor = 1.0  // PLACEHOLDER: "balanced in all areas" (help file)
    MPfactor = 1.0
    capStrength = 60       // confirmed (ClassReference.md)
    capAgility = 60        // PLACEHOLDER: unconfirmed, mirrored off Strength cap
    capVitality = 80       // PLACEHOLDER: unconfirmed
    capIntelligence = 150  // confirmed
    capSpirit = 60           // PLACEHOLDER: unconfirmed

mob/player/Soldier
    class = "Soldier"
    hasMana = FALSE
    HPfactor = 1.3  // PLACEHOLDER: "the best class at taking damage" (help file)
    capStrength = 100      // confirmed (ClassReference.md)
    capAgility = 60        // PLACEHOLDER: unconfirmed
    capVitality = 100      // confirmed
    capIntelligence = 20   // PLACEHOLDER: unconfirmed, kept low — Soldier has no
                            // Intelligence-gated skills in ClassReference.md
    capSpirit = 40           // PLACEHOLDER: unconfirmed

mob/player/Wizard
    class = "Wizard"
    HPfactor = 0.7  // PLACEHOLDER: "very weak in physical combat" (help file)
    MPfactor = 1.3  // PLACEHOLDER: "the most powerful offensive magic of any class"
    capStrength = 40       // confirmed (ClassReference.md)
    capAgility = 40        // confirmed
    capVitality = 60       // confirmed
    capIntelligence = 100  // confirmed
    capSpirit = 60           // PLACEHOLDER: unconfirmed

mob/player/Fighter
    class = "Fighter"
    hasMana = FALSE        // PLACEHOLDER: no Intelligence-gated skill in
                            // ClassReference.md's Fighter table — assumed non-caster
    HPfactor = 0.85  // PLACEHOLDER: "not so good at taking damage" (help file)
    capStrength = 100      // confirmed (ClassReference.md)
    capAgility = 100       // confirmed
    capVitality = 80       // confirmed
    capIntelligence = 40   // confirmed
    capSpirit = 40           // confirmed

mob/player/Pilgrim
    class = "Pilgrim"
    MPfactor = 1.1  // PLACEHOLDER: "specializes in healing and defensive magic" (help file)
    capStrength = 80       // confirmed (ClassReference.md)
    capAgility = 60        // confirmed
    capVitality = 60       // PLACEHOLDER: unconfirmed
    capIntelligence = 100  // confirmed
    capSpirit = 60           // PLACEHOLDER: unconfirmed

mob/player/Goofoff
    class = "Goof-off"
    hasMana = FALSE        // PLACEHOLDER: no Intelligence-gated skill in
                            // ClassReference.md's Goof-off table — assumed non-caster
                            // (Magicknife's governing stat is itself unconfirmed)
    HPfactor = 0.9  // PLACEHOLDER: "weaker than the rest" (help file)
    capStrength = 80       // confirmed (ClassReference.md)
    capAgility = 60        // PLACEHOLDER: unconfirmed
    capVitality = 60       // confirmed
    capIntelligence = 40   // confirmed
    capSpirit = 40           // confirmed

mob/player/Sage
    class = "Sage"
    HPfactor = 0.7  // PLACEHOLDER: "horrible in physical combat" (help file)
    MPfactor = 1.3  // matches Wizard — Sage's spell list is a strict superset of it
    // Every cap here is PLACEHOLDER: (ClassReference.md has no Sage numbers at all)
    // — kept in confirmed caster territory per the doc's explicit call ("horrible in
    // physical combat"), Intelligence matched to Hero's since Sage's skill list is the
    // Hero+Wizard+Pilgrim union.
    capStrength = 40
    capAgility = 40
    capVitality = 60
    capIntelligence = 150
    capSpirit = 60

// -----------------------------
// Class name -> type lookup — the one place this switch exists. ApplyPlayerClass()
// (LoginMenu.dm), LoadCharacter() (SaveSystem.dm), and GetClassStatCaps() below all
// need to turn a class NAME string (mob/playerTemp.selectedClass, or a save file's
// stored mob/player.class) into its concrete mob/player/X type — previously each had
// its own copy of this same switch.
// -----------------------------
proc/GetPlayerClassType(class_name)
    switch(class_name)
        if("Hero")     return /mob/player/Hero
        if("Soldier")  return /mob/player/Soldier
        if("Wizard")   return /mob/player/Wizard
        if("Fighter")  return /mob/player/Fighter
        if("Pilgrim")  return /mob/player/Pilgrim
        if("Goof-off") return /mob/player/Goofoff
        if("Sage")     return /mob/player/Sage
    return null

// -----------------------------
// Class stat-cap lookup — single source of truth stays the per-class vars above; this
// just resolves a class NAME to its type's cap values. initial(type:var) reads a
// type's compile-time default without instantiating it — no throwaway mob spawn/delete
// (and no running that class's whole New(), e.g. HidePartyVerbs()) just to read 5
// numbers. Still memoized since building the 5-entry list per class is needless to
// repeat on every stat click even though the read itself is now cheap.
// -----------------------------
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

// -----------------------------
// Sage reclass flow — Classchange (SkillCatalog.dm) calls this BEFORE BecomeSage()
// below. CONFIRMED 2026-08-25 via live OG testing (screenshot): classchange re-runs the
// actual character creation flow — icon selection ("Who will you look like?", the exact
// OG-confirmed prompt IconSelect() now shows), color customization, and stat allocation
// — not a straight carry-over of the old character's appearance/stats. This was missed
// entirely in the first pass at Classchange, which just copied the old mob's icon/colors/
// stats onto the new Sage outright.
//
// Reuses IconSelect()/CustomizeColors()/StatAllocation() (LoginMenu.dm) directly on the
// EXISTING player mob P, rather than duplicating that flow — those three procs already
// only touch vars declared at plain `mob` scope (selectedIcon, hairColor, Strength, ...),
// so they work identically whether P is a fresh mob/playerTemp or a live mob/player
// mid-game; IconSelect()/StatAllocation() only needed their parameter type loosened from
// mob/playerTemp to plain mob to allow the call.
//
// Returns TRUE once the player finishes (icon + colors + all stat points spent), FALSE
// if they back out at the icon step — mirrors STEP_ICON's "Back" meaning "abort" in
// NewCharacterMenu(). Backing out anywhere doesn't touch P's REAL stats: StatAllocation()
// only commits into P.Strength/etc on its own "Finish" branch, which is also the only
// path that reaches this proc's own `return TRUE` — so a player who navigates back and
// forth several times before committing can't leave P half-mutated, and one who cancels
// outright is left completely unchanged.
proc/RunSageReclassFlow(mob/player/P)
    P.selectedClass = "Sage"  // scratch var read by GetClassIcons()/IconSelect() —
                                // restricts the icon picker to Sage's own two portraits

    var/step = STEP_ICON
    while(step)
        switch(step)
            if(STEP_ICON)
                step = IconSelect(P)
                if(step == STEP_CLASS)
                    return FALSE  // "Back" at the icon step = cancel the whole reclass

            if(STEP_CUSTOM)
                P.IconPreview()      // live preview while picking colors, same as creation
                step = P.CustomizeColors()

            if(STEP_STATS)
                step = StatAllocation(P)
                if(step == STEP_STATS)
                    return TRUE  // all points spent, Finish pressed — P.Strength/etc are
                                  // already the fresh values, committed in place

// -----------------------------
// Sage reclass — Goof-off's Classchange skill (SkillCatalog.dm) and, eventually, a
// Dharma Scroll item (not yet built, any class) both hand off to this, AFTER
// RunSageReclassFlow() above has already walked the player through icon/color/stat
// selection and staged the results directly on P's own vars. News a fresh
// mob/player/Sage, transplants those freshly-chosen values (not the old character's),
// transfers control, and deletes the old mob — same vars-transfer shape FinalizePlayer()/
// LoadCharacter() (LoginMenu.dm/SaveSystem.dm) already use to stand up a typed mob, just
// applied mid-game instead of at creation/load.
// -----------------------------
mob/player/proc/BecomeSage()
    if(!client) return

    var/client/C = client
    var/mob/player/Sage/newMob = new /mob/player/Sage
    var/turf/T = loc

    // Identity & appearance — sourced from the FRESH picks RunSageReclassFlow() just
    // staged on P (selectedIcon/selectedIconName via IconSelect(), hairColor/eyeColor/
    // mainColor/accentColor/palette via CustomizeColors()), not the old character's own
    // icon/baseIcon/basePlayerIcon. Same fields ApplyCustomColors() (LoginMenu.dm) sets
    // for a brand-new character — this is the reclass equivalent of that.
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
    if(newCharPreview) del newCharPreview  // preview obj RunSageReclassFlow()'s
                                             // IconPreview() created — only needed during
                                             // selection, would otherwise sit orphaned in
                                             // the preview area forever

    // Progress. CONFIRMED OG behavior, both from the classchange confirmation prompt
    // ("You will keep all your items and gold, but you will be set back to level 1") and
    // from the reclass flow above being confirmed as a real re-run of character creation:
    // the five stats and StatPoints reset the same way Level does, matching a genuinely
    // fresh character rather than a partial carry-over. Nexp is recomputed off the reset
    // Level, matching how LevelCheck() (CombatSystem.dm) derives it on a normal level-up.
    newMob.Level = 1
    newMob.Exp = 0
    newMob.Nexp = BASE_EXP
    newMob.Gold = Gold
    // Strength/Vitality/Agility/Intelligence/Spirit: NOT copied here — P's own vars were
    // already overwritten in place by StatAllocation() inside RunSageReclassFlow(), so
    // reading them off P (unqualified below) already gives the fresh creation-time
    // allocation, same as ApplyCustomStats() does for a brand-new character.
    newMob.Strength = Strength
    newMob.Vitality = Vitality
    newMob.Agility = Agility
    newMob.Intelligence = Intelligence
    newMob.Spirit = Spirit
    // Always 0 here: StatAllocation() enforces "spend every point before Finish", so
    // there is never a leftover to carry — any UNSPENT level-up points the old character
    // still had are deliberately not preserved either, since carrying those forward would
    // let this "start over" reclass end up with more allocated stats than a real fresh
    // Sage, right after already spending a full fresh 12-point pool.
    newMob.StatPoints = 0

    // Skills — every currently-known skill carries over as-is (including anything the
    // old class could learn that Sage's own table never would), same numpad
    // arrangement too. You don't unlearn things by changing class.
    newMob.skills = skills
    newMob.skillSlots = skillSlots

    // Inventory — items live directly in mob.contents (Inventory.dm), not a separate
    // list, so this IS the inventory transfer.
    for(var/obj/item/I in contents)
        I.loc = newMob

    // Save identity — same slot, same manager
    newMob.isCharacter = isCharacter
    newMob.saveSlot = saveSlot
    newMob.saveManager = saveManager

    // Vitals — recomputed fresh off the reset Level/stats, then topped off to full,
    // exactly like FinalizePlayer() does for a brand-new character (RecalculateVitals(),
    // then HP = MaxHP / MP = MaxMP). Carrying the OLD HP/MP number and clamping it down
    // (the previous behavior) doesn't fit a reclass that's now confirmed to be a genuine
    // restart — a level-25 character's leftover 400 HP clamped to a level-1 Sage's ~35
    // max isn't meaningfully different from just starting full, and starting full is what
    // every other "new character" path in this codebase does.
    newMob.RecalculateVitals()
    newMob.HP = newMob.MaxHP
    newMob.MP = newMob.MaxMP

    newMob.loc = T

    C.mob = newMob
    // Fresh mob's verb list starts from its type declaration again — re-sync same as
    // every other mob-swap in this codebase (FinalizePlayer()/LoadCharacter()).
    C.SyncGMVerbs()

    // Unlike FinalizePlayer()/LoadCharacter() (which only ever ADD to players, since
    // the old mob there was a temp mob that was never in the list), this swap replaces
    // an EXISTING real character already in players — without this, the old (about to
    // be deleted) mob stays a stale reference in players forever, and the new Sage
    // never shows up in Who()/world broadcasts (SocialVerbs.dm), which both iterate it.
    players -= src
    players += newMob

    newMob << output("You feel your form shift... you have become a Sage!", "Info")

    del src
