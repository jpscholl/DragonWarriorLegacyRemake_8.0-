// -----------------------------
// Player Icon Registry
// -----------------------------
// One entry per selectable player portrait: the art file itself, the class whose picker
// offers it, and the exact color each recolorable zone is DRAWN in.
//
// This is the single source of truth for player appearance. A character's save file
// stores only an entry's id (the bare filename, e.g. "dw1hero.dmi") plus whatever zone
// colors that player explicitly chose -- never the painted sprite itself. RebuildIcon()
// (SaveSystem.dm) looks the id up here on every login and repaints from the LIVE art, so
// repainting a .dmi, or correcting a zone color below, reaches every existing character
// on their next login instead of only brand-new ones. Before this, the save blob carried
// a frozen COPY of the sprite's pixels, which is why edits never showed up without
// deleting and recreating the character.
//
// zoneDefaults maps a zone name to the color that zone's pixels actually are in the art.
// Those colors are what SwapColor() searches for, so they have to match the .dmi exactly
// -- Debug_ShowZoneColors() (DebugTools.dm) samples an icon and prints them in
// copy-pasteable rgb() form. Zone ORDER here is the order character creation offers them.
// Adding a zone to an icon means adding one line to its list below and nothing else:
// the customization menu, the save format, and the repaint all read this.
//
// An icon with no zones listed simply isn't recolorable yet -- it wears its art as drawn
// and creation skips the color step for it, rather than offering zones that can't paint
// anything.

datum/PlayerIcon
    var/id                  // bare filename, e.g. "dw1hero.dmi" -- the key save files store
    var/label               // how it reads in the "Who will you look like?" picker
    var/class               // class whose picker offers it (Archsage's offers every entry)
    var/icon/file           // the live art resource
    var/list/zoneDefaults   // zone name -> the color that zone is drawn in, in menu order
    var/precolored          // finished art -- never run it through the recolor step

    New(_label, _class, _file, list/_zoneDefaults, _precolored = FALSE)
        label = _label
        class = _class
        file = _file
        zoneDefaults = _zoneDefaults || list()
        precolored = _precolored
        id = GetIconFilename(_file)   // (Main.dm) same bare-filename form save files store

    // Worth showing the color menu for only if this icon has zones AND isn't art that's
    // already finished.
    proc/IsRecolorable()
        return !precolored && zoneDefaults.len

// id -> /datum/PlayerIcon, in picker order.
var/list/playerIconRegistry = BuildPlayerIconRegistry()

proc/AddPlayerIcon(list/reg, label, class, file, list/zoneDefaults = list(), precolored = FALSE)
    var/datum/PlayerIcon/entry = new /datum/PlayerIcon(label, class, file, zoneDefaults, precolored)
    reg[entry.id] = entry

// Resolves the id a save file stores (or a live mob's basePlayerIcon) back to its entry.
// Returns null for an id that isn't registered -- a save predating an icon's removal or
// rename, which RebuildIcon() handles rather than leaving the character sprite-less.
proc/GetPlayerIcon(icon_id)
    if(!icon_id) return null
    return playerIconRegistry[icon_id]

proc/BuildPlayerIconRegistry()
    var/list/reg = list()

    // Archsage's own precolored portrait, deliberately first in its picker. Running
    // finished art through the Main/Accent/Hair/Eyes loop would just break it, so it
    // carries no zones and IsRecolorable() sends creation straight past the color step.
    AddPlayerIcon(reg, "My Own Portrait (precolored)", "Archsage", 'Mob Icons/Cere.dmi', list(), TRUE)

    // Hero
    AddPlayerIcon(reg, "Dragon Warrior 1 Hero", "Hero", 'Mob Icons/Player/Hero/dw1hero.dmi', list(
        "Main"   = rgb(0,92,255),
        "Accent" = rgb(255,255,255),
        "Hair"   = rgb(0,93,255),   // also covers the headgear pixels -- they share one color
        "Eyes"   = rgb(0,92,254)))
    // "Hair" also covers the headgear pixels on this sprite -- they share one color.
    AddPlayerIcon(reg, "Dragon Warrior 2 Hero", "Hero", 'Mob Icons/Player/Hero/dw2hero.dmi', list(
        "Main"   = rgb(0,124,255),
        "Accent" = rgb(255,255,255),
        "Hair"   = rgb(0,124,254),
        "Eyes"   = rgb(0,123,255)))
    AddPlayerIcon(reg, "Dragon Warrior 3 Hero", "Hero", 'Mob Icons/Player/Hero/dw3hero.dmi', list(
        "Main"   = rgb(0,124,255),
        "Accent" = rgb(255,255,255),
        "Hair"   = rgb(0,124,254),
        "Eyes"   = rgb(0,124,250)))
    // "Accent2" is a second, near-identical green (0,187,0) sitting one value off from
    // Hair/Headgear's own green (0,188,0) -- distinct enough for SwapColor's exact-match
    // to tell apart, but easy to miss without sampling. Female not yet sampled -- may
    // need the same split once it is.
    AddPlayerIcon(reg, "Dragon Warrior 4 Hero (Male)", "Hero", 'Mob Icons/Player/Hero/dw4malehero.dmi', list(
        "Main"    = rgb(0,92,255),
        "Accent"  = rgb(255,255,255),
        "Accent2" = rgb(0,187,0),
        "Hair"    = rgb(0,188,0),   // also covers headgear -- shares one color
        "Eyes"    = rgb(0,90,255)))
    AddPlayerIcon(reg, "Dragon Warrior 4 Hero (Female)", "Hero", 'Mob Icons/Player/Hero/dw4femalehero.dmi')

    // Soldier -- dw3guard is PARTIALLY authored: only "Main" has been sampled so far, so
    // that's the only zone its color menu offers. Not a statement about the art; the rest
    // just isn't done yet. Adding a zone here is all it takes to offer it.
    AddPlayerIcon(reg, "Dragon Warrior 1 Soldier", "Soldier", 'Mob Icons/Player/Soldier/dw1soldier.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 2 Soldier", "Soldier", 'Mob Icons/Player/Soldier/dw2soldier.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Guard", "Soldier", 'Mob Icons/Player/Soldier/dw3guard.dmi', list(
        "Main" = rgb(0,120,248)))
    AddPlayerIcon(reg, "Dragon Warrior 3 Soldier (Male)", "Soldier", 'Mob Icons/Player/Soldier/dw3malesoldier.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Soldier (Female)", "Soldier", 'Mob Icons/Player/Soldier/dw3femalesoldier.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Guard (Female)", "Soldier", 'Mob Icons/Player/Soldier/dw4femaleguard.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Ragnar", "Soldier", 'Mob Icons/Player/Soldier/dw4ragnar.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Adventurer", "Soldier", 'Mob Icons/Player/Soldier/dw4adventurer.dmi')

    // Wizard -- dw3malewizard is partially authored, same as dw3guard above: "Main" only.
    AddPlayerIcon(reg, "Dragon Warrior 1 Wizard", "Wizard", 'Mob Icons/Player/Wizard/dw1wizard.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 2 Wizard", "Wizard", 'Mob Icons/Player/Wizard/dw2wizard.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 2 Princess", "Wizard", 'Mob Icons/Player/Wizard/dw2princess.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Wizard (Male)", "Wizard", 'Mob Icons/Player/Wizard/dw3malewizard.dmi', list(
        "Main" = rgb(0,172,64)))
    AddPlayerIcon(reg, "Dragon Warrior 3 Wizard (Female)", "Wizard", 'Mob Icons/Player/Wizard/dw3femalewizard.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Brey", "Wizard", 'Mob Icons/Player/Wizard/dw4brey.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Mara", "Wizard", 'Mob Icons/Player/Wizard/dw4mara.dmi')
    // Icon states (world, hit, sleep, attack, weapon -- no "defend") match this project's
    // Wizard pattern exactly, not Hero/Soldier's -- confirmed 2026-09-14 via icon_states()
    // on the actual file. Moved out of Hero for that reason. "Hair" also covers the
    // headgear pixels here, and the arms share pixels with Accent -- an Accent recolor
    // visibly tints the arms too, a real property of the art, not a zone-split bug.
    AddPlayerIcon(reg, "Dragon Warrior 4 Elf", "Wizard", 'Mob Icons/Player/Wizard/dw4elf.dmi', list(
        "Main"   = rgb(0,88,248),
        "Accent" = rgb(254,254,254),
        "Hair"   = rgb(0,184,0),
        "Eyes"   = rgb(0,88,249)))

    // Fighter
    AddPlayerIcon(reg, "Dragon Warrior 1 Fighter", "Fighter", 'Mob Icons/Player/Fighter/dw1fighter.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 2 Fighter", "Fighter", 'Mob Icons/Player/Fighter/dw2fighter.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Fighter (Male)", "Fighter", 'Mob Icons/Player/Fighter/dw3malefighter.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Fighter (Female)", "Fighter", 'Mob Icons/Player/Fighter/dw3femalefighter.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Alena", "Fighter", 'Mob Icons/Player/Fighter/dw4alena.dmi')

    // Pilgrim
    AddPlayerIcon(reg, "Dragon Warrior 2 Pilgrim", "Pilgrim", 'Mob Icons/Player/Pilgrim/dw2pilgrim.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Pilgrim (Male)", "Pilgrim", 'Mob Icons/Player/Pilgrim/dw3malepilgrim.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Pilgrim (Female)", "Pilgrim", 'Mob Icons/Player/Pilgrim/dw3femalepilgrim.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Cristo", "Pilgrim", 'Mob Icons/Player/Pilgrim/dw4cristo.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Nara", "Pilgrim", 'Mob Icons/Player/Pilgrim/dw4nara.dmi')

    // Goof-off
    AddPlayerIcon(reg, "Dragon Warrior 3 Goof-off (Male)", "Goof-off", 'Mob Icons/Player/Goof-off/dw3malegoofoff.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Goof-off (Female)", "Goof-off", 'Mob Icons/Player/Goof-off/dw3femalegoofoff.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Bard", "Goof-off", 'Mob Icons/Player/Goof-off/dw3bard.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 4 Bard", "Goof-off", 'Mob Icons/Player/Goof-off/dw4bard.dmi')

    // Sage
    AddPlayerIcon(reg, "Dragon Warrior 3 Sage (Male)", "Sage", 'Mob Icons/Player/Sage/dw3malesage.dmi')
    AddPlayerIcon(reg, "Dragon Warrior 3 Sage (Female)", "Sage", 'Mob Icons/Player/Sage/dw3femalesage.dmi')

    return reg
