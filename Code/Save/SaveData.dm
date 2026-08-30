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

    // Last known position (GM_SaveLocation, GMCommands.dm) — always recorded on save
    // regardless of whether the toggle is currently on, so flipping it on doesn't lose
    // location history from while it was off. Only ever CONSULTED at load time
    // (LoadCharacter(), SaveSystem.dm), gated on the global saveLocationEnabled flag —
    // otherwise a returning character still spawns at GetPlayerSpawnTurf() as normal.
    var/savedX
    var/savedY
    var/savedZ

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

    // Carried items (Code/Player/Inventory.dm) — one entry per obj/item in contents,
    // as a plain type + the couple of bits of per-instance state that would otherwise
    // be lost: a worn amulet's equip bonus, a key's engraved name. Not a full var dump
    // of each item, same "store the minimum that's actually per-instance" approach as
    // equippedSkillTypes above.
    var/list/inventorySnapshot

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

    savedX = P.x
    savedY = P.y
    savedZ = P.z

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

    inventorySnapshot = list()
    for(var/obj/item/I in P.contents)
        var/list/entry = list("type" = I.type)
        if(istype(I, /obj/item/amulet))
            var/obj/item/amulet/A = I
            entry["worn"] = A.worn
        else if(istype(I, /obj/item/key))
            var/obj/item/key/K = I
            entry["name"] = K.name
            entry["keyName"] = K.keyName
        inventorySnapshot += list(entry)

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

// Recreates each carried item from inventorySnapshot and drops it straight into the
// player's contents — bypasses PickUpItem()'s capacity check deliberately, since these
// are items the player already owned, not a new pickup a shrunk capacity should be
// allowed to refuse. A worn amulet is re-equipped silently (Equip()'s silent param,
// Inventory.dm) so login doesn't spam a "You equip ..." line per worn amulet.
datum/CharacterSaveData/proc/ApplyInventory(mob/player/P)
    if(!inventorySnapshot) return   // no snapshot (an old save from before this existed)

    for(var/list/entry in inventorySnapshot)
        var/itemType = entry["type"]
        if(!itemType) continue

        var/obj/item/I = new itemType
        I.loc = P

        if(istype(I, /obj/item/amulet) && entry["worn"])
            var/obj/item/amulet/A = I
            A.Equip(P, TRUE)
        else if(istype(I, /obj/item/key))
            var/obj/item/key/K = I
            if(entry["name"]) K.name = entry["name"]
            K.keyName = entry["keyName"]
