// -----------------------------
// Skill Granting — starting kits + leveled unlocks, one mechanism for both
// -----------------------------
// "Everything is a skill" (Attack/Defend/spells alike, Code/Combat/Skills/SkillDatum.dm)
// — EquipSkill() below is the single place any mob/player ever gains a skill, whether
// that's its starting kit (GetStartingKit(), granted at creation/load) or something
// learned later by leveling (GetSkillUnlocks(), checked via CheckSkillUnlocks()). Real
// per-class data for both tables is mostly still unconfirmed for the unlock side — see
// Markdowns/ClassReference.md, only 2 of ~90 skill-unlock entries confirmed so far.
// GetSkillUnlocks()'s per-class lists below are PLACEHOLDER TEST DATA using a skill
// that already exists in code (Fireball, not part of any class's starting kit) purely
// to exercise the unlock half of this system end to end. Swap in real numbers once
// ClassReference.md fills in — nothing else here needs to change to do that, and a
// class can never gain a skill that isn't in its own list, by construction.
datum/skillUnlock
    var
        skillType             // typepath to instantiate, e.g. /datum/skill/Fireball
        requiredLevel = 1
        requiredStat = null   // "Strength"/"Vitality"/"Agility"/"Intelligence"/"Luck", or null for no stat gate
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

    // silent = TRUE re-syncs already-earned unlocks (e.g. after loading a save, since
    // `skills` isn't part of the save blob — see LoadCharacter(), SaveSystem.dm)
    // without spamming "You learned X!" for something the player already knew before
    // disconnecting.
    proc/CheckSkillUnlocks(silent = FALSE)
        for(var/datum/skillUnlock/U in GetSkillUnlocks())
            if(HasSkillType(U.skillType)) continue
            if(Level < U.requiredLevel) continue
            if(U.requiredStat && vars[U.requiredStat] < U.requiredStatValue) continue

            var/datum/skill/S = EquipSkill(U.skillType)
            if(!silent)
                src << output("You learned [S.skillName]!", "Info")

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
    )

mob/player/Wizard/GetStartingKit()
    return list(
        list(/datum/skill/Attack, 9),
        list(/datum/skill/Blaze, 3),
    )

// -----------------------------
// Per-class leveled unlocks — see the PLACEHOLDER TEST DATA note above
// -----------------------------
mob/player/Hero/GetSkillUnlocks()
    return list(new /datum/skillUnlock(/datum/skill/Fireball, 2, "Strength", 3))

mob/player/Soldier/GetSkillUnlocks()
    return list(new /datum/skillUnlock(/datum/skill/Fireball, 2, "Vitality", 3))

mob/player/Wizard/GetSkillUnlocks()
    return list(new /datum/skillUnlock(/datum/skill/Fireball, 2, "Intelligence", 3))
