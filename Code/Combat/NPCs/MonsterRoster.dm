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
// The roster is deliberately trimmed to the ten monsters covered by the OG difficulty
// ordering (CombatDataSheet.md) — cat, slime, dog, redslime, bat, fox, babble, skeleton,
// drakee, healer — per the "5-6 monster types for training cages, not the full ~86
// roster" call from the 2026-08-14 session. The TSV holds real stats for all 77; adding
// one back is now just a block below with its row's numbers, no tier to pick.
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
    healSkills = list(/datum/skill/Heal)
