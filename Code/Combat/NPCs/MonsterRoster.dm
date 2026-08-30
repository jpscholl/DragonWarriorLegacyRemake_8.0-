// -----------------------------
// Monster Roster — every mob/enemy subtype in the game
// -----------------------------
// Stat blocks are REAL OG DATA as of 2026-08-25, not placeholders: every Level/MaxHP/
// MaxMP/Strength/Agility/Vitality/Intelligence/Spirit/element/exp/gold value below is
// read straight out of the original Dragon Warrior Legacy .dmb's own type table (see
// Markdowns/OGMonsterBaseStats.tsv for the raw extract and Markdowns/MonsterBaseStats.md
// for the confidence notes). The two flat placeholder tiers this file used to carry
// (TIER1_*/TIER2_* defines, then mob/enemy/tier1 and /tier2 base types) are gone —
// they were never a real OG concept. Real monsters differ per-stat, most sharply in
// Agility, which spans 1 (Babble) to 10 (Bat) across just these ten.
//
// Per that TSV's own header, confidence varies by column: element is CERTAIN (the stored
// values are literally element name strings), Level/MaxHP/MaxMP and the five stats are
// HIGH, exp/gold are MEDIUM. Nothing here is a guess of ours; where a column was too
// uncertain to apply, it's called out below rather than used.
//
// Originally trimmed to ten monsters (cat, slime, dog, redslime, bat, fox, babble,
// skeleton, drakee, healer) per the "5-6 monster types for training cages, not the
// full ~86 roster" call from the 2026-08-14 session. Expanded 2026-08-28 to all 24
// monster names actually CONFIRMED to exist in the OG (via GMglobalrespawn/
// GMkillallmonsters's type pickers, GMCommandsReference.md) — the other 53 rows in the
// TSV belong to icons with no confirmed real name, so they're left out rather than
// guessed at. The TSV holds real stats for all 77; adding one more back is just a
// block below with its row's numbers, no tier to pick.
//
// TWO COLUMNS DELIBERATELY NOT APPLIED:
//   delay — real and high-confidence (inversely monotonic with Agility across the whole
//     roster), but its UNITS are unknown. Values run 4-8; attackCooldown (EnemyNPCs.dm)
//     is in deciseconds and currently defaults to 10, so mapping delay straight across
//     would roughly double every monster's attack rate on an unverified unit conversion.
//     Left alone until the collaborator's bytecode pass recovers how delay is consumed.
//   flee — applied below as fleeHealthPercent, but flagged MEDIUM confidence in the TSV
//     ("name is a guess"). The values behave exactly like a percent — 0 on every boss and
//     on Skeleton, highest on the metal monsters — which is what fleeHealthPercent already
//     means, so the mapping is safe even if the name turns out wrong.

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
    Agility = 10   // fastest thing in the trimmed roster — the stat the old flat tiers erased
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
    Agility = 1    // slowest in the roster
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
    fleeHealthPercent = 0  // never flees — real value, matches every boss in the TSV
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

// The only monster in the trimmed roster with an MP pool. CONFIRMED 2026-08-18: "Healer"
// is the proper OG name for what earlier notes called "healslime"/"healer slime" — same
// monster, not a separate gap. Its self/ally-heal AI is TryHeal() (EnemyNPCs.dm), the
// remake's equivalent of the OG's HealCheck; the real MaxMP below is what pays for it.
// With only 20 MP and Heal costing 4, it gets roughly five casts before it's dry and
// drops to melee — which is what makes killing it first actually matter.
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

// =============================================================================
// 2026-08-28 roster expansion — same real OG data source as the ten above
// (Markdowns/OGMonsterBaseStats.tsv), extending from the trimmed 10-monster training
// cage out to all 24 monster names actually confirmed to exist in the OG (via the
// GMglobalrespawn/GMkillallmonsters type pickers, GMCommandsReference.md). Same
// confidence notes apply (element CERTAIN, level/HP/MP/stats HIGH, exp/gold MEDIUM,
// delay/flee left out of scope — see this file's header). dropType/dropChance aren't
// in the TSV at all (no drop data was extractable) — chosen in the same loose style as
// the original 10's own drop fields, not sourced from anything.
// =============================================================================
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
    // Has a real MP pool per the TSV, but no castableSkills wired — the confirmed OG
    // caster AI (kiting, MP-drain-then-fallback-to-melee, TODOList.md Phase 6) isn't
    // built yet, so this is melee-only for now despite the name/MP.

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
    fleeHealthPercent = 0   // never flees — real TSV value, same as Skeleton
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
    // Same "has MP, no caster AI yet" note as Magician above.

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

// CONFIRMED OG AI (TODOList.md Phase 6, live-tested 2026-08-10): Acolytes self-cast
// Increase (physical defense buff) the instant they spot the player. Not built here —
// EnemyNPCs.dm has no "self-buff on aggro" hook at all yet (only castableSkills/
// healSkills, both offense/heal-shaped) — so this is melee-only for now despite the
// real MP pool below. Worth its own AILoop() pass alongside the other confirmed-but-
// unbuilt caster behaviors (TODOList.md), not bolted on here.
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
    // Same "has MP, no caster AI yet" note as Magician above.

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
    fleeHealthPercent = 0   // never flees — real TSV value, same as Skeleton/Ghost
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
    fleeHealthPercent = 0   // never flees — real TSV value, same as Skeleton/Ghost/Blazeghost
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
