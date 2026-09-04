// -----------------------------
// Skill Granting — starting kits + leveled unlocks, one mechanism for both
// -----------------------------
// EquipSkill() below is the single place any mob/player ever gains a skill, whether
// that's its starting kit (GetStartingKit(), granted at creation/load) or something
// learned later by leveling (GetSkillUnlocks(), checked via CheckSkillUnlocks()). Only
// 2 of ~90 skill-unlock entries (Hero's Heal/Thornwhip) are OG-confirmed; every other
// level/stat threshold is invented per the 2026-08-04 placeholder policy — see
// Markdowns/ClassReference.md for the human-readable version of every table below. A
// class can never gain a skill that isn't in its own list, by construction.
datum/skillUnlock
    var
        skillType             // typepath to instantiate, e.g. /datum/skill/Fireball
        requiredLevel = 1
        requiredStat = null   // "Strength"/"Vitality"/"Agility"/"Intelligence"/"Spirit", or null for no stat gate
        requiredStatValue = 0

    New(type, level = 1, stat = null, statValue = 0)
        ..()
        skillType = type
        requiredLevel = level
        requiredStat = stat
        requiredStatValue = statValue

mob/player
    // Grants skillType if not already known, optionally equipping it to a numpad slot
    // (null slotNum = learned but unequipped, sits in the "Free Skills" list).
    proc/EquipSkill(skillType, slotNum = null)
        if(HasSkillType(skillType)) return

        var/datum/skill/S = new skillType
        skills += S
        if(slotNum != null)
            skillSlots[slotNum] = S
        return S

    proc/HasSkillType(type)
        return GetSkillByType(type) != null

    // Also used by ApplySkillSlots() (SaveData.dm) to resolve a saved slot
    // arrangement's type paths back into this mob's actual skill instances on load.
    proc/GetSkillByType(type)
        for(var/datum/skill/S in skills)
            if(S.type == type) return S
        return null

    // Granted once at creation/load. Base: nothing — each class overrides
    // GetStartingKit() with its own list of list(skillType, slotNum).
    proc/GetStartingKit()
        return list()

    proc/EquipStartingKit()
        for(var/list/entry in GetStartingKit())
            EquipSkill(entry[1], entry[2])

    // Checked on every level-up (LevelCheck(), CombatSystem.dm) and every stat point
    // spend (StatLink/Click(), ClickableStats.dm), since a stat-gated skill can unlock
    // without a level-up too. Base: nothing; each class overrides GetSkillUnlocks().
    proc/GetSkillUnlocks()
        return list()

    // Per-instance cache — GetSkillUnlocks() only depends on class, which never
    // changes, but CheckSkillUnlocks() runs on every stat-point click as well as every
    // level-up, so rebuilding a 10-22-entry list of fresh datums every click was
    // needless. Cached lazily on first use, same reasoning as GetClassStatCaps()'s
    // cache (PlayerTemplate.dm).
    var/list/cachedSkillUnlocks = null

    // silent = TRUE re-syncs already-earned unlocks (e.g. after loading a save, since
    // `skills` isn't part of the save blob) without spamming "You learned X!" for
    // something the player already knew before disconnecting.
    proc/CheckSkillUnlocks(silent = FALSE)
        if(!cachedSkillUnlocks)
            cachedSkillUnlocks = GetSkillUnlocks()
        for(var/datum/skillUnlock/U in cachedSkillUnlocks)
            if(HasSkillType(U.skillType)) continue
            if(Level < U.requiredLevel) continue
            if(U.requiredStat && vars[U.requiredStat] < U.requiredStatValue) continue

            var/datum/skill/S = EquipSkill(U.skillType)
            if(!silent)
                src.ShowInfo("You learned [S.skillName]!")

// -----------------------------
// Per-class starting kits — confirmed: Attack always, Defend for Hero/Soldier, Blaze
// for Hero/Wizard. Slot numbers match the confirmed OG numpad layout.
// -----------------------------
mob/player/Hero/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Defend, 7),
        list(/datum/skill/Blaze, 3),
    )

mob/player/Soldier/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Defend, 7),
        list(/datum/skill/Club, 3),  // ClassReference.md's confirmed Soldier kit
    )

mob/player/Wizard/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Blaze, 3),
    )

mob/player/Fighter/GetStartingKit()
    return list(
        list(/datum/skill/Punch, 9),  // ClassReference.md's confirmed Fighter kit
    )

mob/player/Pilgrim/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Heal, 7),  // ClassReference.md's confirmed Pilgrim kit
    )

mob/player/Goofoff/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),  // ClassReference.md's confirmed Goof-off kit
    )

// Sage's starting kit was explicitly left undecided in ClassReference.md — this is a
// rounded caster pick (damage/heal/MP-restore/escape). See Markdowns/CodeNotes.md.
mob/player/Sage/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Blaze, 3),
        list(/datum/skill/Heal, 7),
        list(/datum/skill/Meditate, 1),
        list(/datum/skill/Return, 0),
    )

// Archsage's whole point is testing every skill/spell on one character — every real
// skill is granted here at creation, no level/stat gating (GetSkillUnlocks() stays
// empty). Only the 5 numpad slots get a starting equip; the rest land in Free Skills.
// Classchange is excluded — it would turn this character into a Sage.
mob/player/Archsage/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Defend, 7),
        list(/datum/skill/Blaze, 3),
        list(/datum/skill/Heal, 1),
        list(/datum/skill/Return, 0),

        list(/datum/skill/Fireball, null),
        list(/datum/skill/Punch, null),
        list(/datum/skill/Club, null),
        list(/datum/skill/IronClaw, null),
        list(/datum/skill/Jump, null),
        list(/datum/skill/Hide, null),
        list(/datum/skill/Magicknife, null),
        list(/datum/skill/Boomerang, null),
        list(/datum/skill/Morningstar, null),
        list(/datum/skill/Dash, null),
        list(/datum/skill/Quakejump, null),
        list(/datum/skill/Fireclaw, null),
        list(/datum/skill/Iceclaw, null),
        list(/datum/skill/Thornwhip, null),
        list(/datum/skill/Lightsword, null),
        list(/datum/skill/Battleaxe, null),
        list(/datum/skill/Flamesword, null),
        list(/datum/skill/Falconsword, null),
        list(/datum/skill/Goldclaw, null),
        list(/datum/skill/Chainsickle, null),
        list(/datum/skill/SwordOfLethargy, null),
        list(/datum/skill/IceSaber, null),
        list(/datum/skill/Demonhammer, null),
        list(/datum/skill/DragonKiller, null),
        list(/datum/skill/ThunderSword, null),
        list(/datum/skill/Icebolt, null),
        list(/datum/skill/Lightning, null),
        list(/datum/skill/Infernos, null),
        list(/datum/skill/Icespears, null),
        list(/datum/skill/Blazemore, null),
        list(/datum/skill/Blizzard, null),
        list(/datum/skill/Boom, null),
        list(/datum/skill/Bang, null),
        list(/datum/skill/Infermore, null),
        list(/datum/skill/Thordain, null),
        list(/datum/skill/Firevolt, null),
        list(/datum/skill/Firebane, null),
        list(/datum/skill/Snowstorm, null),
        list(/datum/skill/Blazemost, null),
        list(/datum/skill/Explodet, null),
        list(/datum/skill/Healmore, null),
        list(/datum/skill/Healus, null),
        list(/datum/skill/Healmost, null),
        list(/datum/skill/Healusmore, null),
        list(/datum/skill/Vivify, null),
        list(/datum/skill/Upper, null),
        list(/datum/skill/Increase, null),
        list(/datum/skill/Barrier, null),
        list(/datum/skill/Sleep, null),
        list(/datum/skill/Sleepmore, null),
        list(/datum/skill/Stopspell, null),
        list(/datum/skill/Rest, null),
        list(/datum/skill/Meditate, null),
        list(/datum/skill/Revive, null),
    )

// -----------------------------
// Per-class leveled unlocks — real tables built from ClassReference.md. Hero's table
// has real level+stat numbers throughout (unconfirmed against the OG, but not
// invented spacing); every other class's table had no level numbers in the doc, only
// which stat gates each skill — those levels are invented here, spaced using Hero's
// own curve as the calibration anchor. A skill shared across multiple classes' tables
// keeps the same stat threshold class-to-class, only the unlock LEVEL differs.
// Fireball/Blaze are excluded from every class that already starts with them (a
// leveled unlock for a skill already known is a silent no-op via HasSkillType()).
// -----------------------------
// Hero/Wizard/Pilgrim's tables are each factored into their own building proc so
// Sage/GetSkillUnlocks() below can compose the same three lists instead of a
// hand-copied duplicate.
proc/BuildHeroSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Heal, 3, "Intelligence", 6),          // confirmed
        new /datum/skillUnlock(/datum/skill/Icebolt, 4, "Intelligence", 7),
        new /datum/skillUnlock(/datum/skill/Thornwhip, 5, "Strength", 8),         // confirmed
        new /datum/skillUnlock(/datum/skill/Lightning, 7, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Fireball, 8, "Intelligence", 8),
        new /datum/skillUnlock(/datum/skill/Sleep, 12, "Intelligence", 9),
        new /datum/skillUnlock(/datum/skill/Upper, 14, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Healmore, 16, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Return, 17, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Icespears, 18, "Intelligence", 13),
        new /datum/skillUnlock(/datum/skill/Chainsickle, 20, "Strength", 19),
        new /datum/skillUnlock(/datum/skill/Thordain, 21, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Bang, 23, "Intelligence", 18),
        new /datum/skillUnlock(/datum/skill/Meditate, 24, "Spirit", 15),
        new /datum/skillUnlock(/datum/skill/SwordOfLethargy, 25, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/Healus, 25, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/Stopspell, 28, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Firebane, 30, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/IceSaber, 32, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/DragonKiller, 35, "Strength", 30),
        new /datum/skillUnlock(/datum/skill/Vivify, 38, "Intelligence", 22),
        new /datum/skillUnlock(/datum/skill/ThunderSword, 40, "Strength", 35),
    )

mob/player/Hero/GetSkillUnlocks()
    return BuildHeroSkillUnlocks()

mob/player/Soldier/GetSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Thornwhip, 4, "Strength", 8),
        new /datum/skillUnlock(/datum/skill/Rest, 5, "Vitality", 8),
        new /datum/skillUnlock(/datum/skill/Morningstar, 8, "Strength", 12),
        new /datum/skillUnlock(/datum/skill/Battleaxe, 12, "Strength", 16),
        new /datum/skillUnlock(/datum/skill/Flamesword, 15, "Strength", 18),
        new /datum/skillUnlock(/datum/skill/Falconsword, 17, "Strength", 20),
        new /datum/skillUnlock(/datum/skill/Chainsickle, 19, "Strength", 19),
        new /datum/skillUnlock(/datum/skill/IceSaber, 22, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/SwordOfLethargy, 23, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/Demonhammer, 27, "Strength", 26),
        new /datum/skillUnlock(/datum/skill/DragonKiller, 32, "Strength", 30),
    )

mob/player/Fighter/GetSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Jump, 3, "Agility", 7),
        new /datum/skillUnlock(/datum/skill/Hide, 4, "Agility", 8),
        new /datum/skillUnlock(/datum/skill/Rest, 5, "Vitality", 8),
        new /datum/skillUnlock(/datum/skill/IronClaw, 7, "Strength", 9),
        new /datum/skillUnlock(/datum/skill/Dash, 9, "Agility", 11),
        new /datum/skillUnlock(/datum/skill/Quakejump, 12, "Agility", 12),
        new /datum/skillUnlock(/datum/skill/Fireclaw, 15, "Strength", 13),
        new /datum/skillUnlock(/datum/skill/Iceclaw, 17, "Strength", 13),
        new /datum/skillUnlock(/datum/skill/Goldclaw, 22, "Strength", 19),
    )

mob/player/Goofoff/GetSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Club, 3, "Strength", 6),
        new /datum/skillUnlock(/datum/skill/Jump, 4, "Agility", 7),
        new /datum/skillUnlock(/datum/skill/Magicknife, 6, "Strength", 8),
        new /datum/skillUnlock(/datum/skill/Thornwhip, 8, "Strength", 8),
        new /datum/skillUnlock(/datum/skill/Boomerang, 10, "Strength", 10),
        new /datum/skillUnlock(/datum/skill/Rest, 12, "Vitality", 8),
        new /datum/skillUnlock(/datum/skill/Quakejump, 15, "Agility", 12),
        new /datum/skillUnlock(/datum/skill/Classchange, 25),  // TODOList.md's own confirmed placeholder
    )

proc/BuildPilgrimSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Sleep, 5, "Intelligence", 9),
        new /datum/skillUnlock(/datum/skill/Upper, 6, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Increase, 7, "Intelligence", 11),
        new /datum/skillUnlock(/datum/skill/Infernos, 9, "Intelligence", 12),
        new /datum/skillUnlock(/datum/skill/Morningstar, 10, "Strength", 12),
        new /datum/skillUnlock(/datum/skill/Meditate, 12, "Spirit", 15),
        new /datum/skillUnlock(/datum/skill/Lightsword, 13, "Strength", 14),
        new /datum/skillUnlock(/datum/skill/Healmore, 14, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Return, 15, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Battleaxe, 16, "Strength", 16),
        new /datum/skillUnlock(/datum/skill/Sleepmore, 17, "Intelligence", 16),
        new /datum/skillUnlock(/datum/skill/Infermore, 18, "Intelligence", 19),
        new /datum/skillUnlock(/datum/skill/SwordOfLethargy, 20, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/Healmost, 22, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Stopspell, 24, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Healus, 26, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/Vivify, 28, "Intelligence", 22),
        new /datum/skillUnlock(/datum/skill/Revive, 32, "Intelligence", 24),
        new /datum/skillUnlock(/datum/skill/Healusmore, 36, "Intelligence", 26),
    )

mob/player/Pilgrim/GetSkillUnlocks()
    return BuildPilgrimSkillUnlocks()

proc/BuildWizardSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Lightning, 5, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Blazemore, 8, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Barrier, 10, "Intelligence", 17),
        new /datum/skillUnlock(/datum/skill/Meditate, 12, "Spirit", 15),
        new /datum/skillUnlock(/datum/skill/Blizzard, 14, "Intelligence", 16),
        new /datum/skillUnlock(/datum/skill/Icespears, 16, "Intelligence", 13),
        new /datum/skillUnlock(/datum/skill/Boom, 18, "Intelligence", 18),
        new /datum/skillUnlock(/datum/skill/Thordain, 20, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Bang, 22, "Intelligence", 18),
        new /datum/skillUnlock(/datum/skill/Firevolt, 24, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Snowstorm, 27, "Intelligence", 23),
        new /datum/skillUnlock(/datum/skill/Firebane, 30, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/Blazemost, 34, "Intelligence", 24),
        new /datum/skillUnlock(/datum/skill/Explodet, 38, "Intelligence", 28),
    )

mob/player/Wizard/GetSkillUnlocks()
    return BuildWizardSkillUnlocks()

// Sage's list = union of Hero+Wizard+Pilgrim's tables — composed from the same three
// building procs above so there's no way for Sage's numbers to drift from whichever
// class a skill is "from." A skill listed in more than one source table keeps
// whichever source's entry is encountered FIRST — Hero, then Wizard, then Pilgrim.
// Unlike Hero/Wizard, Sage doesn't start with Fireball/Blaze, so both need their own
// unlock entries here.
mob/player/Sage/GetSkillUnlocks()
    var/list/merged = list()
    var/list/seenTypes = list()

    for(var/datum/skillUnlock/U in BuildHeroSkillUnlocks() + BuildWizardSkillUnlocks() + BuildPilgrimSkillUnlocks())
        if(U.skillType in seenTypes) continue
        seenTypes[U.skillType] = TRUE
        merged += U

    merged += new /datum/skillUnlock(/datum/skill/Fireball, 8, "Intelligence", 8)
    merged += new /datum/skillUnlock(/datum/skill/Blaze, 10, "Intelligence", 9)

    return merged
