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
            // Deliberately the RAW stat, not GetEffective*() — unlike every combat
            // formula, which reads the effective value so amulets count. Learning a
            // skill is permanent and unequipping isn't unlearning, so gating it on a
            // value equipment can inflate would let a player borrow an amulet, clear
            // the threshold, hand it back and keep the skill.
            if(U.requiredStat && vars[U.requiredStat] < U.requiredStatValue) continue

            var/datum/skill/S = EquipSkill(U.skillType)
            if(!silent)
                src.ShowInfo("You learned [S.skillName]!")

// -----------------------------
// Per-class starting kits — confirmed: Attack always, Defend for Hero/Soldier, Zap for
// Hero, Fireball + Icebolt for Wizard. Slot numbers match the confirmed OG numpad
// layout where one is known (Hero's).
// -----------------------------
mob/player/Hero/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Defend, 7),
        list(/datum/skill/Zap, 3),  // the Hero's default spell (user; ClassReference.md)
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
        list(/datum/skill/Fireball, 3),  // ClassReference.md's confirmed Wizard kit
        list(/datum/skill/Icebolt, 7),   // slot invented -- Hero's Defend slot, which Wizard lacks
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
// empty). Built from the skill types themselves, so a new skill needs no entry here.
// Only the 5 numpad slots get a starting equip; the rest land in Free Skills.
// Classchange is excluded — it would turn this character into a Sage.
mob/player/Archsage/GetStartingKit()
    var/list/kit = list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Defend, 7),
        list(/datum/skill/Blaze, 3),
        list(/datum/skill/Heal, 1),
        list(/datum/skill/Return, 0),
    )
    var/list/skip = list(/datum/skill/Attack, /datum/skill/Defend, /datum/skill/Blaze,
                         /datum/skill/Heal, /datum/skill/Return, /datum/skill/Classchange)
    for(var/skillType in typesof(/datum/skill))
        if(skillType in skip) continue
        if(!IsLearnableSkillType(skillType)) continue
        kit[++kit.len] = list(skillType, null)
    return kit

// Every concrete skill, as opposed to a framework (GenericPhysical, SpellBolt, Recover...)
// -- those never set a skillName. Archsage's kit and Test_LearnSkill (DebugTools.dm).
proc/IsLearnableSkillType(skillType)
    var/datum/skill/S = skillType
    return initial(S.skillName) != "Unnamed Skill"

// -----------------------------
// Per-class leveled unlocks — tables built from ClassReference.md. Every class's
// unlocks are spread evenly from level 1 to 50 (user, 2026-09-25), keeping the order
// ClassReference.md gave them. The only levels held in place are the OG's: Hero's
// Heal (3) and Thornwhip (5), and Goof-off's Classchange (25, the OG help file's).
// Stat thresholds are unchanged; a later level only makes them easier to reach. A
// skill shared across multiple classes' tables keeps the same stat threshold
// class-to-class, only the unlock LEVEL differs. A skill a class already starts with
// is left out of its table (a leveled unlock for a skill already known is a silent
// no-op via HasSkillType()).
// -----------------------------
// Hero/Wizard/Pilgrim's tables are each factored into their own building proc so
// Sage/GetSkillUnlocks() below can compose the same three lists instead of a
// hand-copied duplicate.
proc/BuildHeroSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Heal, 3, "Intelligence", 6),          // confirmed
        new /datum/skillUnlock(/datum/skill/Icebolt, 4, "Intelligence", 7),
        new /datum/skillUnlock(/datum/skill/Thornwhip, 5, "Strength", 8),         // confirmed
        new /datum/skillUnlock(/datum/skill/Lightning, 9, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Blaze, 11, "Intelligence", 9),
        new /datum/skillUnlock(/datum/skill/Fireball, 13, "Intelligence", 8),  // after Blaze: it's the faster, harder Blaze
        new /datum/skillUnlock(/datum/skill/Sleep, 15, "Intelligence", 9),
        new /datum/skillUnlock(/datum/skill/Upper, 17, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Healmore, 20, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Return, 22, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Icespears, 24, "Intelligence", 13),
        new /datum/skillUnlock(/datum/skill/Chainsickle, 26, "Strength", 19),
        new /datum/skillUnlock(/datum/skill/Thordain, 28, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Bang, 30, "Intelligence", 18),
        new /datum/skillUnlock(/datum/skill/Meditate, 33, "Spirit", 15),
        new /datum/skillUnlock(/datum/skill/SwordOfLethargy, 35, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/Healus, 37, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/Stopspell, 39, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Firebane, 41, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/IceSaber, 43, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/DragonKiller, 46, "Strength", 30),
        new /datum/skillUnlock(/datum/skill/Vivify, 48, "Intelligence", 22),
        new /datum/skillUnlock(/datum/skill/ThunderSword, 50, "Strength", 35),
    )

mob/player/Hero/GetSkillUnlocks()
    return BuildHeroSkillUnlocks()

mob/player/Soldier/GetSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Thornwhip, 5, "Strength", 8),
        new /datum/skillUnlock(/datum/skill/Rest, 9, "Vitality", 8),
        new /datum/skillUnlock(/datum/skill/Morningstar, 14, "Strength", 12),
        new /datum/skillUnlock(/datum/skill/Battleaxe, 18, "Strength", 16),
        new /datum/skillUnlock(/datum/skill/Flamesword, 23, "Strength", 18),
        new /datum/skillUnlock(/datum/skill/Falconsword, 27, "Strength", 20),
        new /datum/skillUnlock(/datum/skill/Chainsickle, 32, "Strength", 19),
        new /datum/skillUnlock(/datum/skill/IceSaber, 36, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/SwordOfLethargy, 41, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/Demonhammer, 45, "Strength", 26),
        new /datum/skillUnlock(/datum/skill/DragonKiller, 50, "Strength", 30),
    )

mob/player/Fighter/GetSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Jump, 5, "Agility", 7),
        new /datum/skillUnlock(/datum/skill/Hide, 10, "Agility", 8),
        new /datum/skillUnlock(/datum/skill/Rest, 15, "Vitality", 8),
        new /datum/skillUnlock(/datum/skill/SandToss, 20, "Agility", 9),  // not OG -- user's design, 2026-09-25
        new /datum/skillUnlock(/datum/skill/IronClaw, 25, "Strength", 9),
        new /datum/skillUnlock(/datum/skill/Dash, 30, "Agility", 11),
        new /datum/skillUnlock(/datum/skill/Quakejump, 35, "Agility", 12),
        new /datum/skillUnlock(/datum/skill/Fireclaw, 40, "Strength", 13),
        new /datum/skillUnlock(/datum/skill/Iceclaw, 45, "Strength", 13),
        new /datum/skillUnlock(/datum/skill/Goldclaw, 50, "Strength", 19),
    )

mob/player/Goofoff/GetSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Club, 6, "Strength", 6),
        new /datum/skillUnlock(/datum/skill/Jump, 13, "Agility", 7),
        new /datum/skillUnlock(/datum/skill/SandToss, 19, "Agility", 8),  // not OG -- user's design, 2026-09-25
        new /datum/skillUnlock(/datum/skill/Magicknife, 25, "Strength", 8),
        new /datum/skillUnlock(/datum/skill/Classchange, 25),  // the OG help file's level -- held, not spread
        new /datum/skillUnlock(/datum/skill/Thornwhip, 31, "Strength", 8),
        new /datum/skillUnlock(/datum/skill/Boomerang, 38, "Strength", 10),
        new /datum/skillUnlock(/datum/skill/Rest, 44, "Vitality", 8),
        new /datum/skillUnlock(/datum/skill/Quakejump, 50, "Agility", 12),
    )

proc/BuildPilgrimSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Sleep, 2, "Intelligence", 9),
        new /datum/skillUnlock(/datum/skill/Club, 5, "Strength", 6),  // OG /playerlearn/pilgrim/club -- was missing
        new /datum/skillUnlock(/datum/skill/Upper, 7, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Increase, 10, "Intelligence", 11),
        new /datum/skillUnlock(/datum/skill/Infernos, 12, "Intelligence", 12),
        new /datum/skillUnlock(/datum/skill/Morningstar, 14, "Strength", 12),
        new /datum/skillUnlock(/datum/skill/Meditate, 17, "Spirit", 15),
        new /datum/skillUnlock(/datum/skill/Lightsword, 19, "Strength", 14),
        new /datum/skillUnlock(/datum/skill/Healmore, 21, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Return, 24, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Battleaxe, 26, "Strength", 16),
        new /datum/skillUnlock(/datum/skill/Sleepmore, 29, "Intelligence", 16),
        new /datum/skillUnlock(/datum/skill/Infermore, 31, "Intelligence", 19),
        new /datum/skillUnlock(/datum/skill/SwordOfLethargy, 33, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/Healmost, 36, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Stopspell, 38, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Healus, 40, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/Vivify, 43, "Intelligence", 22),
        new /datum/skillUnlock(/datum/skill/Infermost, 45, "Intelligence", 23),  // user: "30+"; Int invented
        new /datum/skillUnlock(/datum/skill/Revive, 48, "Intelligence", 24),
        new /datum/skillUnlock(/datum/skill/Healusmore, 50, "Intelligence", 26),
    )

mob/player/Pilgrim/GetSkillUnlocks()
    return BuildPilgrimSkillUnlocks()

proc/BuildWizardSkillUnlocks()
    return list(
        new /datum/skillUnlock(/datum/skill/Blaze, 3, "Intelligence", 9),  // OG /playerlearn/wizard/blaze -- no longer in the kit
        new /datum/skillUnlock(/datum/skill/Lightning, 6, "Intelligence", 10),
        new /datum/skillUnlock(/datum/skill/Flamespear, 9, "Intelligence", 11),   // user; stat invented
        new /datum/skillUnlock(/datum/skill/Blazemore, 12, "Intelligence", 14),
        new /datum/skillUnlock(/datum/skill/Barrier, 15, "Intelligence", 17),
        new /datum/skillUnlock(/datum/skill/Meditate, 18, "Spirit", 15),
        new /datum/skillUnlock(/datum/skill/Blizzard, 21, "Intelligence", 16),
        new /datum/skillUnlock(/datum/skill/Icespears, 24, "Intelligence", 13),
        new /datum/skillUnlock(/datum/skill/Bang, 26, "Intelligence", 18),
        new /datum/skillUnlock(/datum/skill/Thordain, 29, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Boom, 32, "Intelligence", 18),  // after Bang: it's the bigger Bang
        new /datum/skillUnlock(/datum/skill/Firevolt, 35, "Intelligence", 20),
        new /datum/skillUnlock(/datum/skill/Flamespears, 38, "Intelligence", 22), // user; stat invented
        new /datum/skillUnlock(/datum/skill/Snowstorm, 41, "Intelligence", 23),
        new /datum/skillUnlock(/datum/skill/Firebane, 44, "Intelligence", 21),
        new /datum/skillUnlock(/datum/skill/Blazemost, 47, "Intelligence", 24),
        new /datum/skillUnlock(/datum/skill/Explodet, 50, "Intelligence", 28),
    )

mob/player/Wizard/GetSkillUnlocks()
    return BuildWizardSkillUnlocks()

// Sage learns exactly the OG's /playerlearn/sage spells (Markdowns/types.dm ~1692; user,
// 2026-09-25) -- no weapons, no Fireball or Icebolt -- plus Flamespear and Flamespears
// (user, 2026-09-25; not OG). Each one's stat gate comes from the Hero, Wizard or
// Pilgrim table (the building procs above), so Sage's numbers can't drift from the
// class a spell is "from". A spell in more than one table keeps the FIRST entry found
// -- Hero, then Wizard, then Pilgrim. The spells Sage already starts with (Blaze,
// Meditate, Return) are skipped. The rest keep their source levels' order but are
// re-spread evenly up to SAGE_LAST_UNLOCK_LEVEL (SpreadUnlockLevels()), since three
// tables stacked together bunch up (three spells at 50, nothing below 6).
#define SAGE_LAST_UNLOCK_LEVEL 50

mob/player/Sage/GetSkillUnlocks()
    var/static/list/sageSpells = list(
        /datum/skill/Bang, /datum/skill/Barrier, /datum/skill/Blaze, /datum/skill/Blazemore,
        /datum/skill/Blazemost, /datum/skill/Blizzard, /datum/skill/Boom, /datum/skill/Explodet,
        /datum/skill/Firebane, /datum/skill/Firevolt, /datum/skill/Healmore, /datum/skill/Healmost,
        /datum/skill/Healus, /datum/skill/Healusmore, /datum/skill/Icespears, /datum/skill/Increase,
        /datum/skill/Infermore, /datum/skill/Infernos, /datum/skill/Lightning, /datum/skill/Meditate,
        /datum/skill/Return, /datum/skill/Revive, /datum/skill/Sleep, /datum/skill/Sleepmore,
        /datum/skill/Snowstorm, /datum/skill/Stopspell, /datum/skill/Thordain, /datum/skill/Upper,
        /datum/skill/Vivify, /datum/skill/Flamespear, /datum/skill/Flamespears,
    )

    var/list/merged = list()
    var/list/seenTypes = list()
    for(var/list/entry in GetStartingKit())
        seenTypes[entry[1]] = TRUE

    for(var/datum/skillUnlock/U in BuildHeroSkillUnlocks() + BuildWizardSkillUnlocks() + BuildPilgrimSkillUnlocks())
        if(!(U.skillType in sageSpells)) continue
        if(U.skillType in seenTypes) continue
        seenTypes[U.skillType] = TRUE
        merged += U

    // Sage-only, and its last unlock (user, 2026-09-25) -- above everything else Sage
    // learns. The spread below keeps it last; stat invented.
    merged += new /datum/skillUnlock(/datum/skill/SageSaber, SAGE_LAST_UNLOCK_LEVEL, "Intelligence", 35)

    return SpreadUnlockLevels(merged, SAGE_LAST_UNLOCK_LEVEL)

// Re-levels unlocks evenly from level 1 to `last`, in their current level order (ties
// keep list order): the Nth of M lands on round(last * N / M), so the last one lands on
// `last`. Rewrites the datums' requiredLevel in place -- callers pass fresh ones.
proc/SpreadUnlockLevels(list/unlocks, last)
    var/list/sorted = list()
    for(var/datum/skillUnlock/U in unlocks)
        var/at = sorted.len + 1
        while(at > 1)
            var/datum/skillUnlock/before = sorted[at - 1]
            if(before.requiredLevel <= U.requiredLevel) break
            at--
        sorted.Insert(at, U)

    for(var/i = 1 to sorted.len)
        var/datum/skillUnlock/U = sorted[i]
        U.requiredLevel = round(last * i / sorted.len, 1)
    return sorted
