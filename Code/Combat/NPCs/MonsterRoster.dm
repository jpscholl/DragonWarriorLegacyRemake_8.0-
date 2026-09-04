// -----------------------------
// Monster Roster — every mob/enemy subtype in the game
// -----------------------------
// Stat blocks are REAL OG DATA (Markdowns/OGMonsterBaseStats.tsv), not placeholders —
// see Markdowns/CodeNotes.md for provenance, confidence levels, and which two TSV
// columns (delay, flee) were deliberately left unapplied and why. dropType/dropChance
// are the exception — not in the TSV, chosen loosely.

// =============================================================================
// TIER 1-equivalent — the low end of the real difficulty ordering (Levels 1-3)
// =============================================================================
mob/enemy/cat
    name = "Cat"
    icon = 'cat.dmi'
    icon_state = "world"
    Level = 1
    HP = 30
    MaxHP = 30
    Strength = 3
    Agility = 8
    Vitality = 2
    Intelligence = 1
    Spirit = 1
    expReward = 3
    goldReward = 3
    fleeHealthPercent = 20
    dropType = /obj/item/consumable/herb
    dropChance = 8

mob/enemy/slime
    name = "Slime"
    icon = 'slime.dmi'
    icon_state = "world"
    Level = 1
    HP = 40
    MaxHP = 40
    Strength = 4
    Agility = 2
    Vitality = 4
    Intelligence = 1
    Spirit = 1
    mobElement = "Water"
    expReward = 3
    goldReward = 3
    fleeHealthPercent = 15
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/dog
    name = "Dog"
    icon = 'dog.dmi'
    icon_state = "world"
    Level = 2
    HP = 45
    MaxHP = 45
    Strength = 4
    Agility = 4
    Vitality = 5
    Intelligence = 1
    Spirit = 1
    expReward = 4
    goldReward = 4
    fleeHealthPercent = 10
    dropType = /obj/item/consumable/herb
    dropChance = 8

mob/enemy/redslime
    name = "Red Slime"
    icon = 'redslime.dmi'
    icon_state = "world"
    Level = 2
    HP = 45
    MaxHP = 45
    Strength = 5
    Agility = 2
    Vitality = 5
    Intelligence = 4
    Spirit = 1
    mobElement = "Fire"
    expReward = 4
    goldReward = 4
    fleeHealthPercent = 15
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/bat
    name = "Bat"
    icon = 'bat.dmi'
    icon_state = "world"
    Level = 3
    HP = 45
    MaxHP = 45
    Strength = 5
    Agility = 10
    Vitality = 3
    Intelligence = 2
    Spirit = 1
    mobElement = "Air"
    expReward = 5
    goldReward = 5
    fleeHealthPercent = 25
    dropType = /obj/item/consumable/herb
    dropChance = 8

mob/enemy/fox
    name = "Fox"
    icon = 'fox.dmi'
    icon_state = "world"
    Level = 3
    HP = 55
    MaxHP = 55
    Strength = 6
    Agility = 9
    Vitality = 4
    Intelligence = 4
    Spirit = 1
    expReward = 6
    goldReward = 6
    fleeHealthPercent = 25
    dropType = /obj/item/consumable/herb
    dropChance = 10

// =============================================================================
// TIER 2-equivalent — Levels 4-5. Note these are NOT a separate power band: they sit
// directly on top of the above, which is exactly what the old tier2 block got wrong
// (it had Skeleton and Healer at Level 10 with 50 HP).
// =============================================================================
mob/enemy/babble
    name = "Babble"
    icon = 'babble.dmi'
    icon_state = "world"
    Level = 4
    HP = 60
    MaxHP = 60
    Strength = 6
    Agility = 1
    Vitality = 6
    Intelligence = 8
    Spirit = 1
    mobElement = "Plant"
    expReward = 7
    goldReward = 7
    fleeHealthPercent = 10
    dropType = /obj/item/consumable/tea
    dropChance = 8

mob/enemy/skeleton
    name = "Skeleton"
    icon = 'skeleton.dmi'
    icon_state = "world"
    Level = 4
    HP = 60
    MaxHP = 60
    Strength = 6
    Agility = 3
    Vitality = 1
    Intelligence = 4
    Spirit = 1
    mobElement = "Darkness"
    expReward = 8
    goldReward = 8
    fleeHealthPercent = 0  // never flees
    dropType = /obj/item/consumable/herb
    dropChance = 12

mob/enemy/drakee
    name = "Drakee"
    icon = 'drakee.dmi'
    icon_state = "world"
    Level = 5
    HP = 65
    MaxHP = 65
    Strength = 7
    Agility = 8
    Vitality = 4
    Intelligence = 4
    Spirit = 1
    expReward = 9
    goldReward = 9
    fleeHealthPercent = 20
    dropType = /obj/item/consumable/tea
    dropChance = 10

// Its self/ally-heal AI is TryHeal() (EnemyNPCs.dm) — see Markdowns/CodeNotes.md for
// the "Healer" naming confirmation.
mob/enemy/healer
    name = "Healer"
    icon = 'healer.dmi'
    icon_state = "world"
    Level = 5
    HP = 70
    MaxHP = 70
    MP = 20
    MaxMP = 20
    Strength = 7
    Agility = 2
    Vitality = 3
    Intelligence = 6
    Spirit = 6
    mobElement = "Water"
    expReward = 10
    goldReward = 10
    fleeHealthPercent = 20
    dropType = /obj/item/consumable/tea
    dropChance = 15
    healSkills = list(/datum/skill/Heal)

mob/enemy/magician
    name = "Magician"
    icon = 'magician.dmi'
    icon_state = "world"
    Level = 6
    HP = 70
    MaxHP = 70
    MP = 35
    MaxMP = 35
    Strength = 3
    Agility = 2
    Vitality = 3
    Intelligence = 7
    Spirit = 6
    expReward = 12
    goldReward = 12
    fleeHealthPercent = 15
    dropType = /obj/item/consumable/tea
    dropChance = 12
    // Has a real MP pool but no castableSkills wired — caster AI isn't built yet
    // (see Markdowns/CodeNotes.md).

mob/enemy/snailslime
    name = "Snail Slime"
    icon = 'snailslime.dmi'
    icon_state = "world"
    Level = 6
    HP = 100
    MaxHP = 100
    Strength = 6
    Agility = 1
    Vitality = 9
    Intelligence = 3
    Spirit = 1
    mobElement = "Plant"
    expReward = 11
    goldReward = 11
    fleeHealthPercent = 10
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/ghost
    name = "Ghost"
    icon = 'ghost.dmi'
    icon_state = "world"
    Level = 8
    HP = 90
    MaxHP = 90
    Strength = 8
    Agility = 2
    Vitality = 1
    Intelligence = 12
    Spirit = 1
    mobElement = "Darkness"
    expReward = 20
    goldReward = 20
    fleeHealthPercent = 0   // never flees
    dropType = /obj/item/consumable/tea
    dropChance = 12

mob/enemy/wolf
    name = "Wolf"
    icon = 'wolf.dmi'
    icon_state = "world"
    Level = 9
    HP = 95
    MaxHP = 95
    Strength = 9
    Agility = 8
    Vitality = 8
    Intelligence = 2
    Spirit = 1
    expReward = 24
    goldReward = 24
    fleeHealthPercent = 10
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/magidrakee
    name = "Magidrakee"
    icon = 'magidrakee.dmi'
    icon_state = "world"
    Level = 10
    HP = 90
    MaxHP = 90
    MP = 20
    MaxMP = 20
    Strength = 5
    Agility = 7
    Vitality = 6
    Intelligence = 10
    Spirit = 6
    mobElement = "Fire"
    expReward = 27
    goldReward = 27
    fleeHealthPercent = 15
    dropType = /obj/item/consumable/tea
    dropChance = 12
    // Has a real MP pool but no castableSkills wired — caster AI isn't built yet.

mob/enemy/reptile
    name = "Reptile"
    icon = 'reptile.dmi'
    icon_state = "world"
    Level = 10
    HP = 105
    MaxHP = 105
    Strength = 10
    Agility = 1
    Vitality = 10
    Intelligence = 1
    Spirit = 1
    mobElement = "Water"
    expReward = 30
    goldReward = 30
    fleeHealthPercent = 10
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/arcticfox
    name = "Arctic Fox"
    icon = 'arcticfox.dmi'
    icon_state = "world"
    Level = 11
    HP = 100
    MaxHP = 100
    Strength = 10
    Agility = 11
    Vitality = 4
    Intelligence = 7
    Spirit = 6
    mobElement = "Ice"
    expReward = 33
    goldReward = 33
    fleeHealthPercent = 20
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/panther
    name = "Panther"
    icon = 'panther.dmi'
    icon_state = "world"
    Level = 11
    HP = 120
    MaxHP = 120
    Strength = 11
    Agility = 8
    Vitality = 8
    Intelligence = 4
    Spirit = 1
    mobElement = "Plant"
    expReward = 36
    goldReward = 36
    fleeHealthPercent = 5
    dropType = /obj/item/consumable/tea
    dropChance = 10

// Confirmed OG AI (self-cast Increase on aggro) not built yet — see
// Markdowns/CodeNotes.md.
mob/enemy/acolyte
    name = "Acolyte"
    icon = 'acolyte.dmi'
    icon_state = "world"
    Level = 12
    HP = 110
    MaxHP = 110
    MP = 45
    MaxMP = 45
    Strength = 10
    Agility = 1
    Vitality = 1
    Intelligence = 9
    Spirit = 12
    mobElement = "Darkness"
    expReward = 43
    goldReward = 43
    fleeHealthPercent = 20
    dropType = /obj/item/consumable/tea
    dropChance = 14

mob/enemy/gremlin
    name = "Gremlin"
    icon = 'gremlin.dmi'
    icon_state = "world"
    Level = 12
    HP = 100
    MaxHP = 100
    MP = 60
    MaxMP = 60
    Strength = 8
    Agility = 12
    Vitality = 1
    Intelligence = 12
    Spirit = 10
    mobElement = "Air"
    expReward = 39
    goldReward = 39
    fleeHealthPercent = 25
    dropType = /obj/item/consumable/tea
    dropChance = 14
    // Has a real MP pool but no castableSkills wired — caster AI isn't built yet.

mob/enemy/blazeghost
    name = "Blazeghost"
    icon = 'blazeghost.dmi'
    icon_state = "world"
    Level = 13
    HP = 90
    MaxHP = 90
    MP = 40
    MaxMP = 40
    Strength = 1
    Agility = 1
    Vitality = 1
    Intelligence = 12
    Spirit = 18
    mobElement = "Fire"
    expReward = 47
    goldReward = 47
    fleeHealthPercent = 0   // never flees
    dropType = /obj/item/consumable/tea
    dropChance = 16

mob/enemy/tiger
    name = "Tiger"
    icon = 'tiger.dmi'
    icon_state = "world"
    Level = 13
    HP = 135
    MaxHP = 135
    Strength = 11
    Agility = 11
    Vitality = 8
    Intelligence = 1
    Spirit = 1
    expReward = 51
    goldReward = 51
    fleeHealthPercent = 10
    dropType = /obj/item/consumable/herb
    dropChance = 10

mob/enemy/manowar
    name = "Man O' War"
    icon = 'manowar.dmi'
    icon_state = "world"
    Level = 14
    HP = 135
    MaxHP = 135
    Strength = 12
    Agility = 15
    Vitality = 8
    Intelligence = 10
    Spirit = 1
    mobElement = "Water"
    expReward = 59
    goldReward = 59
    fleeHealthPercent = 0   // never flees
    dropType = /obj/item/consumable/herb
    dropChance = 12

mob/enemy/yeti
    name = "Yeti"
    icon = 'yeti.dmi'
    icon_state = "world"
    Level = 14
    HP = 140
    MaxHP = 140
    Strength = 14
    Agility = 3
    Vitality = 12
    Intelligence = 4
    Spirit = 1
    mobElement = "Ice"
    expReward = 55
    goldReward = 55
    fleeHealthPercent = 5
    dropType = /obj/item/consumable/herb
    dropChance = 12
