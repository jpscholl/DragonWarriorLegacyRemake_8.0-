// -----------------------------
// Monster Roster — mob/enemy/[name] for every file in Mob Icons/Monsters/*.dmi
// -----------------------------
// Same shape as the one pre-existing example, mob/enemy/slime (EnemyNPCs.dm): icon,
// icon_state, Level, HP/MaxHP. icon_state = "world" confirmed for every monster
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
// (HP/Strength/Agility/Vitality/Intelligence/Luck/Level) — no ranged/spellcasting AI
// this pass (TODOList.md Phase 6), every monster stays melee-only via the shared
// AILoop()/PerformMeleeHit() pipeline (EnemyNPCs.dm/CombatSystem.dm), regardless of
// tier or name.
//
// `name` is set per-monster (capitalized filename) even though slime's own block never
// set one — combat messages ("[src] has been defeated!", CombatSystem.dm) read this
// directly, and leaving 87 more enemies all sharing one default name would make the
// whole point of a varied roster invisible in play.

// PLACEHOLDER exp rewards, roughly tracking each tier's own Level against the convex
// exp curve (BASE_EXP * Level^2, LevelCheck() in CombatSystem.dm) so a tier stays worth
// farming while it's level-appropriate and falls off once you outgrow it. Rough feel at
// these numbers: ~35 same-tier kills per level-up early, ~70 late. Tune by feel — the
// whole curve is placeholder until there's real playtesting behind it.
#define TIER1_LEVEL 2
#define TIER1_HP 20
#define TIER1_STR 4
#define TIER1_AGI 3
#define TIER1_VIT 3
#define TIER1_INT 1
#define TIER1_LUCK 2
#define TIER1_EXP 10
#define TIER1_GOLD 6

#define TIER2_LEVEL 10
#define TIER2_HP 50
#define TIER2_STR 9
#define TIER2_AGI 7
#define TIER2_VIT 8
#define TIER2_INT 4
#define TIER2_LUCK 5
#define TIER2_EXP 45
#define TIER2_GOLD 25

#define TIER3_LEVEL 25
#define TIER3_HP 110
#define TIER3_STR 18
#define TIER3_AGI 14
#define TIER3_VIT 16
#define TIER3_INT 8
#define TIER3_LUCK 10
#define TIER3_EXP 160
#define TIER3_GOLD 90

#define TIER4_LEVEL 50
#define TIER4_HP 220
#define TIER4_STR 32
#define TIER4_AGI 22
#define TIER4_VIT 28
#define TIER4_INT 14
#define TIER4_LUCK 18
#define TIER4_EXP 520
#define TIER4_GOLD 300

// =============================================================================
// TIER 1 — common animals/weak basics
// =============================================================================
mob/enemy/arcticfox
    name = "Arcticfox"
    icon = 'arcticfox.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/babble
    name = "Babble"
    icon = 'babble.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/bat
    name = "Bat"
    icon = 'bat.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/bengal
    name = "Bengal"
    icon = 'bengal.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/bloodhound
    name = "Bloodhound"
    icon = 'bloodhound.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/cat
    name = "Cat"
    icon = 'cat.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/chameleon
    name = "Chameleon"
    icon = 'chameleon.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/dog
    name = "Dog"
    icon = 'dog.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/drakee
    name = "Drakee"
    icon = 'drakee.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/familiar
    name = "Familiar"
    icon = 'familiar.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/fox
    name = "Fox"
    icon = 'fox.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/ghost
    name = "Ghost"
    icon = 'ghost.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/panther
    name = "Panther"
    icon = 'panther.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/redslime
    name = "Redslime"
    icon = 'redslime.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/reptile
    name = "Reptile"
    icon = 'reptile.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/silverfox
    name = "Silverfox"
    icon = 'silverfox.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/snailslime
    name = "Snailslime"
    icon = 'snailslime.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/squid
    name = "Squid"
    icon = 'squid.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/tiger
    name = "Tiger"
    icon = 'tiger.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/vulpes
    name = "Vulpes"
    icon = 'vulpes.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/wolf
    name = "Wolf"
    icon = 'wolf.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

mob/enemy/yellowslime
    name = "Yellowslime"
    icon = 'yellowslime.dmi'
    icon_state = "world"
    Level = TIER1_LEVEL
    HP = TIER1_HP
    MaxHP = TIER1_HP
    Strength = TIER1_STR
    Agility = TIER1_AGI
    Vitality = TIER1_VIT
    Intelligence = TIER1_INT
    Luck = TIER1_LUCK
    expReward = TIER1_EXP
    goldReward = TIER1_GOLD

// =============================================================================
// TIER 2 — humanoid/elemental basics
// =============================================================================
mob/enemy/acolyte
    name = "Acolyte"
    icon = 'acolyte.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/cloudpuff
    name = "Cloudpuff"
    icon = 'cloudpuff.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/crystalslime
    name = "Crystalslime"
    icon = 'crystalslime.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/curer
    name = "Curer"
    icon = 'curer.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/drakeema
    name = "Drakeema"
    icon = 'drakeema.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/ferocial
    name = "Ferocial"
    icon = 'ferocial.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/flarecat
    name = "Flarecat"
    icon = 'flarecat.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/frostcat
    name = "Frostcat"
    icon = 'frostcat.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/frozenbones
    name = "Frozenbones"
    icon = 'frozenbones.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/gremlin
    name = "Gremlin"
    icon = 'gremlin.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/healer
    name = "Healer"
    icon = 'healer.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/icesloth
    name = "Icesloth"
    icon = 'icesloth.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/iroid
    name = "Iroid"
    icon = 'iroid.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/madclown
    name = "Madclown"
    icon = 'madclown.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/magician
    name = "Magician"
    icon = 'magician.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/magidrakee
    name = "Magidrakee"
    icon = 'magidrakee.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/metalbabble
    name = "Metalbabble"
    icon = 'metalbabble.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/metalslime
    name = "Metalslime"
    icon = 'metalslime.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/minidemon
    name = "Minidemon"
    icon = 'minidemon.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/ozwarg
    name = "Ozwarg"
    icon = 'ozwarg.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/roguewhisper
    name = "Roguewhisper"
    icon = 'roguewhisper.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/skeleton
    name = "Skeleton"
    icon = 'skeleton.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/specter
    name = "Specter"
    icon = 'specter.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/steelbones
    name = "Steelbones"
    icon = 'steelbones.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/waterimp
    name = "Waterimp"
    icon = 'waterimp.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

mob/enemy/wizard
    name = "Wizard"
    icon = 'wizard.dmi'
    icon_state = "world"
    Level = TIER2_LEVEL
    HP = TIER2_HP
    MaxHP = TIER2_HP
    Strength = TIER2_STR
    Agility = TIER2_AGI
    Vitality = TIER2_VIT
    Intelligence = TIER2_INT
    Luck = TIER2_LUCK
    expReward = TIER2_EXP
    goldReward = TIER2_GOLD

// =============================================================================
// TIER 3 — named humanoid/elemental/knight/dragon types
// =============================================================================
mob/enemy/archbishop
    name = "Archbishop"
    icon = 'archbishop.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/blacklion
    name = "Blacklion"
    icon = 'blacklion.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/blazeghost
    name = "Blazeghost"
    icon = 'blazeghost.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/bluedragon
    name = "Bluedragon"
    icon = 'bluedragon.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/bluelion
    name = "Bluelion"
    icon = 'bluelion.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/cloudknight
    name = "Cloudknight"
    icon = 'cloudknight.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/colddevil
    name = "Colddevil"
    icon = 'colddevil.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/darkpriest
    name = "Darkpriest"
    icon = 'darkpriest.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/devil
    name = "Devil"
    icon = 'devil.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/fairydragon
    name = "Fairydragon"
    icon = 'fairydragon.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/fenrir
    name = "Fenrir"
    icon = 'fenrir.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/gianteyeball
    name = "Gianteyeball"
    icon = 'gianteyeball.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/greendragon
    name = "Greendragon"
    icon = 'greendragon.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/iceknight
    name = "Iceknight"
    icon = 'iceknight.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/infurnusknight
    name = "Infurnusknight"
    icon = 'infurnusknight.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/kinghealer
    name = "Kinghealer"
    icon = 'kinghealer.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/kingmetal
    name = "Kingmetal"
    icon = 'kingmetal.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/kingslime
    name = "Kingslime"
    icon = 'kingslime.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/leaonar
    name = "Leaonar"
    icon = 'leaonar.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/lethalarmor
    name = "Lethalarmor"
    icon = 'lethalarmor.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/magmaknight
    name = "Magmaknight"
    icon = 'magmaknight.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/manowar
    name = "Manowar"
    icon = 'manowar.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/metalhealer
    name = "Metalhealer"
    icon = 'metalhealer.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/necrodain
    name = "Necrodain"
    icon = 'necrodain.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/reddragon
    name = "Reddragon"
    icon = 'reddragon.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/rogueknight
    name = "Rogueknight"
    icon = 'rogueknight.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/saroshadow
    name = "Saroshadow"
    icon = 'saroshadow.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/sizarmage
    name = "Sizarmage"
    icon = 'sizarmage.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/warlock
    name = "Warlock"
    icon = 'warlock.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/weretiger
    name = "Weretiger"
    icon = 'weretiger.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/werewolf
    name = "Werewolf"
    icon = 'werewolf.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/whitewolf
    name = "Whitewolf"
    icon = 'whitewolf.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/wolflord
    name = "Wolflord"
    icon = 'wolflord.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

mob/enemy/yeti
    name = "Yeti"
    icon = 'yeti.dmi'
    icon_state = "world"
    Level = TIER3_LEVEL
    HP = TIER3_HP
    MaxHP = TIER3_HP
    Strength = TIER3_STR
    Agility = TIER3_AGI
    Vitality = TIER3_VIT
    Intelligence = TIER3_INT
    Luck = TIER3_LUCK
    expReward = TIER3_EXP
    goldReward = TIER3_GOLD

// =============================================================================
// TIER 4 — bosses
// =============================================================================
mob/enemy/cyclops
    name = "Cyclops"
    icon = 'cyclops.dmi'
    icon_state = "world"
    Level = TIER4_LEVEL
    HP = TIER4_HP
    MaxHP = TIER4_HP
    Strength = TIER4_STR
    Agility = TIER4_AGI
    Vitality = TIER4_VIT
    Intelligence = TIER4_INT
    Luck = TIER4_LUCK
    expReward = TIER4_EXP
    goldReward = TIER4_GOLD

mob/enemy/dragonlord
    name = "Dragonlord"
    icon = 'dragonlord.dmi'
    icon_state = "world"
    Level = TIER4_LEVEL
    HP = TIER4_HP
    MaxHP = TIER4_HP
    Strength = TIER4_STR
    Agility = TIER4_AGI
    Vitality = TIER4_VIT
    Intelligence = TIER4_INT
    Luck = TIER4_LUCK
    expReward = TIER4_EXP
    goldReward = TIER4_GOLD

mob/enemy/leviathan
    name = "Leviathan"
    icon = 'leviathan.dmi'
    icon_state = "world"
    Level = TIER4_LEVEL
    HP = TIER4_HP
    MaxHP = TIER4_HP
    Strength = TIER4_STR
    Agility = TIER4_AGI
    Vitality = TIER4_VIT
    Intelligence = TIER4_INT
    Luck = TIER4_LUCK
    expReward = TIER4_EXP
    goldReward = TIER4_GOLD

mob/enemy/manticore
    name = "Manticore"
    icon = 'manticore.dmi'
    icon_state = "world"
    Level = TIER4_LEVEL
    HP = TIER4_HP
    MaxHP = TIER4_HP
    Strength = TIER4_STR
    Agility = TIER4_AGI
    Vitality = TIER4_VIT
    Intelligence = TIER4_INT
    Luck = TIER4_LUCK
    expReward = TIER4_EXP
    goldReward = TIER4_GOLD

mob/enemy/wraith
    name = "Wraith"
    icon = 'wraith.dmi'
    icon_state = "world"
    Level = TIER4_LEVEL
    HP = TIER4_HP
    MaxHP = TIER4_HP
    Strength = TIER4_STR
    Agility = TIER4_AGI
    Vitality = TIER4_VIT
    Intelligence = TIER4_INT
    Luck = TIER4_LUCK
    expReward = TIER4_EXP
    goldReward = TIER4_GOLD
