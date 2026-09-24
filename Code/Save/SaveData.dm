// ------------------------------------
// Character Save Snapshot Datum
// ------------------------------------
datum/CharacterSaveData
    // 1 -> 2: appearance stopped storing a painted sprite and now stores the icon's
    // registry id plus only the zone colors the player explicitly picked.
    // MigrateLegacyAppearance() below converts a version-1 blob on load.
    var/save_version = 2
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

    // Appearance — the sprite itself is never stored, only which registered portrait
    // this character wears and which zones they explicitly recolored. RebuildIcon()
    // (SaveSystem.dm) repaints from the live art every login, so repainting a .dmi or
    // correcting a zone's color reaches characters that already exist.
    var/basePlayerIcon   // registry id, e.g. "dw3hero.dmi" (PlayerIconColorPalette.dm)
    var/list/zoneColors  // zone -> explicitly chosen color; a zone absent here uses the art as drawn

    // Legacy (save_version 1) — read by MigrateLegacyAppearance() below, never written
    // again. baseIcon is the reason for this whole rework: it held a frozen COPY of the
    // sprite's pixels, so a character kept whatever the art looked like the day they were
    // made no matter how the .dmi changed afterward. Kept declared so an existing save
    // still loads; new saves leave all five null.
    var/icon/baseIcon
    var/hairColor
    var/eyeColor
    var/mainColor
    var/accentColor

    // WHICH skills are known isn't saved here — it's fully derivable from
    // Level/stats plus the fixed starting kit, both re-applied on load. WHICH numpad
    // slot each known skill sits in IS the player's own drag-and-drop customization,
    // not derivable from anything else — that's what this stores: slotNum -> skill
    // typepath (or null for an empty slot).
    var/list/equippedSkillTypes

    // One entry per obj/item in contents: a plain type + the couple of bits of
    // per-instance state that would otherwise be lost (a worn amulet's equip bonus, a
    // key's engraved name) — not a full var dump of each item.
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

    basePlayerIcon = P.basePlayerIcon
    zoneColors = P.zoneColors ? P.zoneColors.Copy() : null

    equippedSkillTypes = alist(9 = null, 7 = null, 3 = null, 1 = null, 0 = null)
    for(var/slotNum in P.skillSlots)
        var/datum/skill/S = P.skillSlots[slotNum]
        equippedSkillTypes[slotNum] = S ? S.type : null

    inventorySnapshot = list()
    for(var/obj/item/I in P.contents)
        var/list/entry = list("type" = I.type)
        // Stack size, for anything stackable (obj/item/consumable, Inventory.dm).
        // Without this a stack of 20 herbs came back as a single herb on the next
        // login — the snapshot recorded the type and nothing else, and ApplyInventory()
        // rebuilt it with the type's default amount of 1.
        if(I.maxStack > 1)
            entry["amount"] = I.amount
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

    P.basePlayerIcon = basePlayerIcon
    P.zoneColors = zoneColors ? zoneColors.Copy() : null
    if(save_version < 2)
        MigrateLegacyAppearance(P)
    // Icon is rebuilt by LoadCharacter() once the palette is set up (see SaveSystem.dm)

// Converts a save_version 1 appearance to the current one.
//
// Version 1 wrote a color for every zone unconditionally, including zones the player
// never touched — for those it captured whatever that icon's default happened to be the
// day the character was made. Those baked-in defaults are precisely what stopped a
// corrected zone color (or repainted art) from ever reaching an existing character, so
// carrying them forward verbatim would preserve the bug rather than fix it.
//
// They can be told apart: a color the player actually PICKED always came from
// color_families (ColorSwap.dm), while "Default Color" wrote the icon's own sampled art
// color, which is never one of those named swatches. So a saved color matching a swatch
// is a real choice and is kept; anything else was a default, and dropping it hands that
// zone back to the art — which is what makes an existing character pick up a fixed color
// on their next login instead of needing to be recreated.
//
// NOTE: color_families was simplified 2026-09-23 from a flat 59-swatch list to an
// 18-family/3-shade one, and several old swatches (Cyan, Magenta, Pink, Navy, Maroon,
// Tan, and most of the old Light/Dark values) no longer have an exact match at all. A
// legacy color that used to match now just falls through to "was a default" and hands
// that zone back to the art on migration — same outcome as if the player had never
// picked a custom color there. Acceptable: this whole proc only ever runs once, on a
// save_version 1 character's first login after this rework, and reverting a since-
// removed swatch to the art's own default is a reasonable fallback, not data loss.
datum/CharacterSaveData/proc/MigrateLegacyAppearance(mob/player/P)
    var/list/legacy = list("Main" = mainColor, "Accent" = accentColor, "Hair" = hairColor, "Eyes" = eyeColor)
    var/list/migrated = list()

    for(var/zone in legacy)
        var/color = legacy[zone]
        if(!color) continue
        if(FindSwatchLocation(color))  // ColorSwap.dm — non-null means a real prior pick
            migrated[zone] = color

    P.zoneColors = migrated.len ? migrated : null

    // Last resort for a save whose icon id doesn't resolve at all (an icon renamed or
    // dropped from the registry since): the frozen sprite is the only thing left to
    // render them with, and a visible character beats an invisible one. RebuildIcon()
    // only falls back to this when the lookup fails.
    if(!GetPlayerIcon(P.basePlayerIcon) && baseIcon)
        P.baseIcon = baseIcon

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

        // Restore a saved stack size, clamped to the type's current maxStack in case
        // that value has been lowered since the save was written. A pre-existing save
        // from before amount was recorded has no entry here and keeps the default of 1.
        if(I.maxStack > 1 && entry["amount"])
            I.amount = min(entry["amount"], I.maxStack)
            I.UpdateStackName()

        if(istype(I, /obj/item/amulet) && entry["worn"])
            var/obj/item/amulet/A = I
            A.Equip(P, TRUE)
        else if(istype(I, /obj/item/key))
            var/obj/item/key/K = I
            if(entry["name"]) K.name = entry["name"]
            K.keyName = entry["keyName"]
