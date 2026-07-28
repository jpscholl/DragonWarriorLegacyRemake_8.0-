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

    // Health & Mana
    var
        HP = 30
        MaxHP = 30
        MP = 0
        MaxMP = 0
        hasMana = TRUE  // FALSE keeps MaxMP at 0 regardless of Intelligence — see
                         // RecalculateVitals() in Code/Player/StatsDatum.dm. Overridden
                         // per-class below (Soldier has none).

    // Core stats
    var
        Strength = 1
        Vitality = 1
        Agility = 1
        Intelligence = 1
        Luck = 1
        StatPoints = 0

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

// -----------------------------
// Player Mob
// -----------------------------
mob/player
    New()
        ..()  // call base constructor

    pixel_y = SPRITE_PIXEL_Y_OFFSET

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

        var/mob/target = null
        var/turf/stepTile = get_step(src, src.dir)
        if(stepTile)
            // Pick the first other mob standing on the tile in front of us
            for(var/mob/M in stepTile.contents)
                if(M == src) continue
                target = M
                break

        S.OnUse(src, target)

    // Grants the base Attack skill and equips it to Numpad 9, matching the confirmed
    // OG default for Hero (see ClassReference.md).
    verb/EquipBasicAttack()
        set hidden = 1
        var/datum/skill/atk = new /datum/skill/Attack
        skills += atk
        skillSlots[9] = atk

    // Grants Defend and equips it to Numpad 7 — Hero and Soldier only, confirmed
    // default kit difference (Wizard doesn't get it). class is already set by the
    // time this runs (class overrides below apply at instantiation, before New()'s
    // body finishes), so this check is safe to run right after EquipBasicAttack().
    verb/EquipBasicDefend()
        set hidden = 1
        if(class != "Hero" && class != "Soldier") return
        var/datum/skill/defend = new /datum/skill/Defend
        skills += defend
        skillSlots[7] = defend

    // Grants Blaze and equips it to Numpad 3 — Hero and Wizard, confirmed default kit
    // (not Soldier). Exact slot number isn't important (confirmed) as long as it's
    // equipped somewhere.
    verb/EquipBasicBlaze()
        set hidden = 1
        if(class != "Hero" && class != "Wizard") return
        var/datum/skill/blaze = new /datum/skill/Blaze
        skills += blaze
        skillSlots[3] = blaze

    // Battle-tab display helpers (StatPanels.dm) — text-only readout of the numpad
    // slots + "Free Skills" list, matching the confirmed OG layout. Real drag-and-drop
    // equip/unequip UI is still TODOList.md future work.
    proc/GetEquippedSkillName(slotNum)
        var/datum/skill/S = skillSlots[slotNum]
        return S ? S.skillName : "Nothing"

    proc/IsSkillEquipped(datum/skill/S)
        for(var/slotNum in skillSlots)
            if(skillSlots[slotNum] == S) return TRUE
        return FALSE

// -----------------------------
// Class Overrides
// -----------------------------
mob/player/Hero
    class = "Hero"

mob/player/Soldier
    class = "Soldier"
    hasMana = FALSE

mob/player/Wizard
    class = "Wizard"
