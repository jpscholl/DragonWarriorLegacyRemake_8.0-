// -----------------------------
// Monster Roster — every mob/enemy subtype in the game
// -----------------------------
// Same shape as the AI base type they all inherit (mob/enemy, EnemyNPCs.dm): icon,
// icon_state, and a stat block. icon_state = "world" confirmed for every monster
// sampled here (bat/cyclops/dragonlord/metalslime/kingslime/wraith/squid/acolyte, all
// old-format DMI — read via raw printable-string dump, not PNG zTXt, same technique
// already used for castmeter.dmi) — all 88 files share the exact same state set
// (world/hit/sleep/attack/weapon), so "world" is safe for the rest without checking
// each individually.
//
// PLACEHOLDER stat tiers: grouped by naming cues per your "use them all, best
// judgement" call — common-animal names (bat, cat, wolf...) = Tier 1, humanoid/
// elemental names (acolyte, skeleton, wizard...) = Tier 2, named/knight/dragon-type
// names (archbishop, iceknight, kingslime...) = Tier 3, boss-sounding names (cyclops,
// dragonlord, leviathan, manticore, wraith) = Tier 4. Each tier is one flat stat block
// — no ranged/spellcasting AI this pass (TODOList.md Phase 6), every monster stays
// melee-only via the shared AILoop()/PerformMeleeHit() pipeline (EnemyNPCs.dm/
// CombatSystem.dm), regardless of tier or name.
//
// `name` is set per-monster (capitalized filename) — combat messages ("[src] has been
// defeated!", CombatSystem.dm) read this directly, and leaving the roster all sharing
// one default name would make the whole point of a varied roster invisible in play.
//
// 2026-08-18: TRIMMED DOWN to just the first real OG difficulty-ordering data set
// (CombatDataSheet.md's "Monster difficulty ordering" section) — cat, dog, redslime,
// bat, fox, babble, skeleton, drakee, healer, plus slime. The other ~77 speculative
// Tier 1-3 subtypes are cut for now per your request, matching the "5-6 monster types
// for training cages, not the full ~86-roster" call from the 2026-08-14 session recap.
// Tier 3/Tier 4 blocks are gone entirely since nothing in the trimmed roster used them —
// re-add both the tier(s) and any cut monster block below (unchanged shape, still in git
// history if you want the old values back) once you're validating further up the roster.
// "Healer" is the proper OG name for what earlier notes called "healslime"/"healer
// slime" (confirmed 2026-08-18, see its own block below and CombatDataSheet.md) — same
// monster, not a separate gap.
//
// Each tier is a real abstract base type below and every monster inherits its whole stat
// block via parent_type, rather than each monster re-listing the same 10 values. The
// tiers used to be #define blocks copy-pasted into every single monster; a tier retune
// is now one edit in one place. Both bases are excluded from GM_MakeMob's placement
// picker (GetTypeChoices()'s exclude list, BuildTools.dm) — they're stat templates, not
// monsters anyone should be able to spawn.

// =============================================================================
// TIER BASE TYPES — stat blocks only, never placed directly
// =============================================================================
// PLACEHOLDER exp/gold rewards, roughly tracking each tier's own Level against the
// convex exp curve (BASE_EXP * Level^2, LevelCheck() in CombatSystem.dm) so a tier stays
// worth farming while it's level-appropriate and falls off once you outgrow it. Rough
// feel at these numbers: ~35 same-tier kills per level-up early, ~70 late. Tune by feel —
// the whole curve is placeholder until there's real playtesting behind it.

// Tier 1 — common animals/weak basics
mob/enemy/tier1
    icon_state = "world"
    Level = 2
    HP = 20
    MaxHP = 20
    Strength = 4
    Agility = 3
    Vitality = 3
    Intelligence = 1
    Spirit = 2
    expReward = 10
    goldReward = 6

// Tier 2 — humanoid/elemental basics
mob/enemy/tier2
    icon_state = "world"
    Level = 10
    HP = 50
    MaxHP = 50
    Strength = 9
    Agility = 7
    Vitality = 8
    Intelligence = 4
    Spirit = 5
    expReward = 45
    goldReward = 25

// =============================================================================
// TIER 1 MONSTERS
// =============================================================================
mob/enemy/babble
    parent_type = /mob/enemy/tier1
    name = "Babble"
    icon = 'babble.dmi'

mob/enemy/bat
    parent_type = /mob/enemy/tier1
    name = "Bat"
    icon = 'bat.dmi'

mob/enemy/cat
    parent_type = /mob/enemy/tier1
    name = "Cat"
    icon = 'cat.dmi'

mob/enemy/dog
    parent_type = /mob/enemy/tier1
    name = "Dog"
    icon = 'dog.dmi'

mob/enemy/drakee
    parent_type = /mob/enemy/tier1
    name = "Drakee"
    icon = 'drakee.dmi'

mob/enemy/fox
    parent_type = /mob/enemy/tier1
    name = "Fox"
    icon = 'fox.dmi'

mob/enemy/redslime
    parent_type = /mob/enemy/tier1
    name = "Redslime"
    icon = 'redslime.dmi'

// The one Tier 1 monster that isn't a plain tier clone: Level 1 rather than the tier's
// 2, deliberately kept as the single weakest thing in the game (it predates the roster
// as the original hand-written example enemy, and was the only monster in the game for
// a long stretch). Every other stat is the tier default.
mob/enemy/slime
    parent_type = /mob/enemy/tier1
    name = "Slime"
    icon = 'slime.dmi'
    Level = 1

// =============================================================================
// TIER 2 MONSTERS
// =============================================================================
// CONFIRMED 2026-08-18: this is the "healslime"/"healer slime" from the difficulty
// ordering + AI-behavior findings (CombatDataSheet.md, SpellRequirementDataSheet.md) —
// "Healer" is the proper OG name, not a new/separate monster. Self/ally-heal behavior
// (casts heal on itself or a weakened nearby monster) is NOT implemented — AILoop()/
// HandlePetTick() (EnemyNPCs.dm) are melee-only for every mob/enemy right now, no
// monster-side spellcasting exists at all yet (TODOList.md Phase 6).
mob/enemy/healer
    parent_type = /mob/enemy/tier2
    name = "Healer"
    icon = 'healer.dmi'

mob/enemy/skeleton
    parent_type = /mob/enemy/tier2
    name = "Skeleton"
    icon = 'skeleton.dmi'
