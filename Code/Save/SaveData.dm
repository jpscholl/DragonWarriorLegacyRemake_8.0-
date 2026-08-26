// ------------------------------------
// Character Save Snapshot Datum
// ------------------------------------
datum/CharacterSaveData
    var/save_version = 1   // bump if the save format changes, to gate future migrations
    var/name

    // Basic character info
    var/class
    var/Level
    var/Exp
    var/Nexp
    var/Gold

    // Health & Mana
    var/HP
    var/MaxHP
    var/MP
    var/MaxMP

    // Core stats
    var/Strength
    var/Vitality
    var/Agility
    var/Intelligence
    var/Spirit
    var/StatPoints

    // Appearance
    var/baseIcon         // the actual /icon resource (template sprite)
    var/basePlayerIcon   // that icon's bare filename, e.g. "dw3hero.dmi" — used to look up default zone colors
    var/hairColor
    var/eyeColor
    var/mainColor
    var/accentColor

    // Skills — WHICH skills are known isn't saved here at all: it's fully derivable
    // from Level/stats (GetSkillUnlocks(), Code/Player/SkillUnlocks.dm) plus the fixed
    // starting kit, both re-applied on load (LoadCharacter(), SaveSystem.dm). WHICH
    // numpad slot each known skill sits in, though, is the player's own drag-and-drop
    // customization (Code/Player/SkillLink.dm) — not derivable from anything else, so
    // that's what this actually stores: a slotNum -> skill typepath snapshot (or null
    // for an empty slot).
    var/list/equippedSkillTypes

// ------------------------------------
// Build snapshot from runtime player
// ------------------------------------
datum/CharacterSaveData/proc/BuildFromCharacter(mob/player/P)
    name = P.name
    class = P.class
    Level = P.Level
    Exp = P.Exp
    Nexp = P.Nexp
    Gold = P.Gold

    HP = P.HP
    MaxHP = P.MaxHP
    MP = P.MP
    MaxMP = P.MaxMP

    Strength = P.Strength
    Vitality = P.Vitality
    Agility = P.Agility
    Intelligence = P.Intelligence
    Spirit = P.Spirit
    StatPoints = P.StatPoints

    baseIcon = P.baseIcon        // <- save the base icon here
    basePlayerIcon = P.basePlayerIcon
    hairColor = P.hairColor
    eyeColor = P.eyeColor
    mainColor = P.mainColor
    accentColor = P.accentColor

    equippedSkillTypes = alist(9 = null, 7 = null, 3 = null, 1 = null, 0 = null)
    for(var/slotNum in P.skillSlots)
        var/datum/skill/S = P.skillSlots[slotNum]
        equippedSkillTypes[slotNum] = S ? S.type : null

// Apply snapshot to runtime player
datum/CharacterSaveData/proc/ApplyToCharacter(mob/player/P)
    P.name = name
    P.Level = Level
    P.Exp = Exp
    P.Nexp = Nexp
    P.Gold = Gold

    P.HP = HP
    P.MaxHP = MaxHP
    P.MP = MP
    P.MaxMP = MaxMP

    P.Strength = Strength
    P.Vitality = Vitality
    P.Agility = Agility
    P.Intelligence = Intelligence
    P.Spirit = Spirit
    P.StatPoints = StatPoints

    P.baseIcon = baseIcon       // <- restore the base icon
    P.basePlayerIcon = basePlayerIcon
    P.hairColor = hairColor
    P.eyeColor = eyeColor
    P.mainColor = mainColor
    P.accentColor = accentColor
    // Icon is rebuilt by LoadCharacter() once the palette is set up (see SaveSystem.dm)

// Restores the saved numpad slot arrangement — separate from ApplyToCharacter() above
// because it has to run LAST in LoadCharacter() (SaveSystem.dm), after every skill the
// slots could reference has actually been (re-)granted: the fixed starting kit
// (EquipStartingKit()) AND any leveled unlocks (CheckSkillUnlocks()). Falls back to
// leaving a slot as whatever EquipStartingKit() already put there if the saved type
// can't be resolved (e.g. P doesn't know that skill for some reason) rather than
// silently clearing it.
datum/CharacterSaveData/proc/ApplySkillSlots(mob/player/P)
    if(!equippedSkillTypes) return   // no snapshot (e.g. an old save from before this existed)

    for(var/slotNum in equippedSkillTypes)
        var/skillType = equippedSkillTypes[slotNum]
        if(!skillType)
            P.skillSlots[slotNum] = null
            continue

        var/datum/skill/S = P.GetSkillByType(skillType)
        if(S) P.skillSlots[slotNum] = S
        // else: leave whatever EquipStartingKit() already put in this slot
