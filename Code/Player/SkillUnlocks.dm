// -----------------------------
// Skill Granting — starting kits + leveled unlocks, one mechanism for both
// -----------------------------
// "Everything is a skill" (Attack/Defend/spells alike, Code/Combat/Skills/SkillDatum.dm)
// — EquipSkill() below is the single place any mob/player ever gains a skill, whether
// that's its starting kit (GetStartingKit(), granted at creation/load) or something
// learned later by leveling (GetSkillUnlocks(), checked via CheckSkillUnlocks()). Real
// per-class data for the unlock side is mostly unconfirmed against the actual OG — only
// 2 of ~90 skill-unlock entries (Hero's Heal/Thornwhip) are confirmed — but every
// class's GetSkillUnlocks() below is a real, filled-in table now, not placeholder test
// data: every unconfirmed level/stat threshold was invented per the 2026-08-04
// placeholder policy, mirroring Hero's own confirmed spacing where reasonable. See
// Markdowns/ClassReference.md (synced against these tables 2026-08-28) for the
// human-readable version of every table below. A class can never gain a skill that
// isn't in its own list, by construction.
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
    // (null slotNum = learned but unequipped, i.e. sits in the "Free Skills" list —
    // ClassReference.md's "Skills vs. equipped skills" note). Used for both starting
    // kits (EquipStartingKit() below) and leveled unlocks (CheckSkillUnlocks() below).
    proc/EquipSkill(skillType, slotNum = null)
        if(HasSkillType(skillType)) return

        var/datum/skill/S = new skillType
        skills += S
        if(slotNum != null)
            skillSlots[slotNum] = S
        return S

    proc/HasSkillType(type)
        return GetSkillByType(type) != null

    // Used by EquipSkill()/HasSkillType() above, and by ApplySkillSlots()
    // (SaveData.dm) to resolve a saved slot arrangement's type paths back into this
    // mob's actual skill instances on load.
    proc/GetSkillByType(type)
        for(var/datum/skill/S in skills)
            if(S.type == type) return S
        return null

    // -----------------------------
    // Starting kit — granted once at creation/load (FinalizePlayer(), LoginMenu.dm;
    // LoadCharacter(), SaveSystem.dm). Base: nothing: each class overrides
    // GetStartingKit() with its own list of list(skillType, slotNum).
    // -----------------------------
    proc/GetStartingKit()
        return list()

    proc/EquipStartingKit()
        for(var/list/entry in GetStartingKit())
            EquipSkill(entry[1], entry[2])

    // -----------------------------
    // Leveled unlocks — checked on every level-up (LevelCheck(), CombatSystem.dm) and
    // every stat point spend (StatLink/Click(), ClickableStats.dm), since a stat-gated
    // skill can unlock without a level-up too. Base: nothing; each class overrides
    // GetSkillUnlocks() with its own list — see the PLACEHOLDER TEST DATA note above.
    // -----------------------------
    proc/GetSkillUnlocks()
        return list()

    // Per-instance cache — GetSkillUnlocks() returns the same data for the lifetime of
    // a mob (it only depends on class, which never changes), but CheckSkillUnlocks()
    // runs on every stat-point click as well as every level-up, so rebuilding a
    // 10-22-entry list of fresh /datum/skillUnlock objects on every single click was
    // needless repeat work. Cached lazily on first use rather than in New(), same
    // reasoning as GetClassStatCaps()'s cache (PlayerTemplate.dm) — no benefit to
    // paying the cost before it's ever actually needed.
    var/list/cachedSkillUnlocks = null

    // silent = TRUE re-syncs already-earned unlocks (e.g. after loading a save, since
    // `skills` isn't part of the save blob — see LoadCharacter(), SaveSystem.dm)
    // without spamming "You learned X!" for something the player already knew before
    // disconnecting.
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
// Per-class starting kits — confirmed (see EquipBasicAttack/Defend/Blaze's old
// comments, now folded in here): Attack always, Defend for Hero/Soldier, Blaze for
// Hero/Wizard. Slot numbers match the confirmed OG numpad layout.
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
                                       // (Attack/Defend/Club) — Club itself didn't exist
                                       // as a real skill datum until this pass
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

// PLACEHOLDER: Sage's starting kit was explicitly left undecided in ClassReference.md
// ("pick 5 from the combined pool once the combined skill table actually exists in
// code") — this is that pick: a rounded caster kit (damage/heal/MP-restore/escape).
// Attack isn't technically part of the Hero+Wizard+Pilgrim skill pool (it's the
// universal baseline every other class's kit also includes), kept for the same reason.
mob/player/Sage/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Blaze, 3),
        list(/datum/skill/Heal, 7),
        list(/datum/skill/Meditate, 1),
        list(/datum/skill/Return, 0),
    )

// -----------------------------
// Per-class leveled unlocks — real tables built from ClassReference.md. Hero's is
// taken directly from its own fully-specified table (the doc already has real level +
// stat numbers for every entry, just flagged "unconfirmed" against the OG). Every other
// class's table had no level numbers at all in the doc (only which stat gates each
// skill) — those levels are invented here, spaced using Hero's own curve as the
// calibration anchor per the build plan, and the STAT THRESHOLD for any skill shared
// across multiple classes' tables (e.g. Thornwhip, Rest, Club) is kept identical
// class-to-class, only the unlock LEVEL differs — same skill should mean the same
// stat requirement regardless of who's learning it.
//
// Fireball/Blaze are deliberately excluded from every class that already starts with
// them (Hero/Wizard both grant Blaze at creation) — a "leveled unlock" for a skill
// already known is a silent no-op (CheckSkillUnlocks()'s HasSkillType() guard), so
// listing it again here would just be dead data.
// -----------------------------
// Hero/Wizard/Pilgrim's tables are each factored into their own building proc, not
// written directly inside GetSkillUnlocks(), so Sage/GetSkillUnlocks() (below) can
// compose the exact same three lists instead of hand-copying ~40 lines from them —
// that copy used to be the only place drift could sneak in between what Sage grants
// and what its "source" classes actually have.
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
        new /datum/skillUnlock(/datum/skill/Stopspell, 28, "Intelligence", 20),   // originally a 17-23 range
        new /datum/skillUnlock(/datum/skill/Firebane, 30, "Intelligence", 21),    // originally an 18-24 range
        new /datum/skillUnlock(/datum/skill/IceSaber, 32, "Strength", 23),
        new /datum/skillUnlock(/datum/skill/DragonKiller, 35, "Strength", 30),
        new /datum/skillUnlock(/datum/skill/Vivify, 38, "Intelligence", 22),      // originally a 21-24 range
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
        // Level 25 is TODOList.md's own confirmed placeholder for this ("the first
        // real data point for it") — not invented fresh here, carried over from there.
        new /datum/skillUnlock(/datum/skill/Classchange, 25),
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

// Sage's list = union of Hero+Wizard+Pilgrim's tables (ClassReference.md, your explicit
// call) — composed straight from the same three building procs above instead of a
// hand-copied ~40-line duplicate, so there's no way for Sage's numbers to drift from
// whichever class a skill is "from." A skill listed in more than one source table
// (e.g. Meditate: Hero has it at level 24, Wizard at level 12) keeps whichever
// source's entry is encountered FIRST — Hero, then Wizard, then Pilgrim, matching the
// tie-break this list already used by hand before. Unlike Hero/Wizard, Sage doesn't
// start with Fireball/Blaze (see GetStartingKit() above), so both need their own
// unlock entries here (added on top of Hero's list, which excludes them since Hero
// already starts with Blaze).
mob/player/Sage/GetSkillUnlocks()
    var/list/merged = list()
    var/list/seenTypes = list()

    for(var/datum/skillUnlock/U in BuildHeroSkillUnlocks() + BuildWizardSkillUnlocks() + BuildPilgrimSkillUnlocks())
        if(U.skillType in seenTypes) continue
        seenTypes[U.skillType] = TRUE
        merged += U

    // Hero's own table excludes Fireball/Blaze (already in Hero's starting kit) — Sage
    // needs them as real gated unlocks since neither is in Sage's starting kit.
    merged += new /datum/skillUnlock(/datum/skill/Fireball, 8, "Intelligence", 8)
    merged += new /datum/skillUnlock(/datum/skill/Blaze, 10, "Intelligence", 9)

    return merged
