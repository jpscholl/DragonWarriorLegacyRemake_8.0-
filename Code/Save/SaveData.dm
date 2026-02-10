// ------------------------------------
// Character Save Snapshot Datum
// ------------------------------------
datum/CharacterSaveData
    var/save_version = 1
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
    var/Luck
    var/StatPoints

    // Appearance
    var/baseIcon
    var/hairColor
    var/eyeColor
    var/mainColor
    var/accentColor

    // Skills
    var/list/skill_ids

// ------------------------------------
// Build snapshot from runtime player
// ------------------------------------
// Build snapshot from runtime player
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
    Luck = P.Luck
    StatPoints = P.StatPoints

    baseIcon = P.baseIcon        // <- save the base icon here
    hairColor = P.hairColor
    eyeColor = P.eyeColor
    mainColor = P.mainColor
    accentColor = P.accentColor

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
    P.Luck = Luck
    P.StatPoints = StatPoints

    P.baseIcon = baseIcon       // <- restore the base icon
    P.hairColor = hairColor
    P.eyeColor = eyeColor
    P.mainColor = mainColor
    P.accentColor = accentColor

    P.RebuildIcon()             // <- make sure icon is rebuilt
