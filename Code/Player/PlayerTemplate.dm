// -----------------------------
// Base Mob
// -----------------------------
mob
    see_invisible = 0

    var/datum/stats/Stats
    var/canAct = 1
    var/BattleModeEnabled = TRUE


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
        basePlayerIcon
        hairColor
        eyeColor
        mainColor
        accentColor

// -----------------------------
// Player Mob
// -----------------------------
mob/player
    New()
        ..()  // call base constructor

    pixel_y = 7

    // Skills
    var/list/skills = list()
    var/datum/skill/activeSkill

    // -----------------------------
    // Skill Methods
    // -----------------------------
    verb/UseSkill()
        set hidden = 1
        if(!activeSkill) return

        var/mob/target = null
        var/turf/stepTile = get_step(src, src.dir)
        if(stepTile)
            target = stepTile.contents.Find(target)  // pick first mob in front

        activeSkill.OnUse(src, target)


    verb/EquipBasicAttack()
        set hidden = 1
        var/datum/skill/atk = new
        skills += atk
        activeSkill = atk

    verb/Attack()
        set hidden = 1
        set desc = "Use your equipped skill"
        UseSkill()

// -----------------------------
// Class Overrides
// -----------------------------
mob/player/Hero
    class = "Hero"
    MaxMP = 15

mob/player/Soldier
    class = "Soldier"
    MaxMP = 0

mob/player/Wizard
    class = "Wizard"
    MaxMP = 30
