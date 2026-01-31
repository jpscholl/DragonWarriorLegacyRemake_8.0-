// -----------------------------
// Base Mob
// -----------------------------
mob
    see_invisible = 0

    var/datum/stats/Stats
    var/canMove = 1

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
        baseIcon
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

    pixel_y = 5

    // Skills
    var/list/skills = list()
    var/datum/Skill/activeSkill

    // -----------------------------
    // Skill Methods
    // -----------------------------
    verb/UseSkill()
        set hidden = 1
        if(!activeSkill) return
        activeSkill.Activate(src, null)

    verb/EquipBasicAttack()
        set hidden = 1
        var/datum/skill/Attack/atk = new
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