# DWLR Remake — Structure and Gap Analysis vs. the Original

**Companion to:** [OGGameStructure.md](OGGameStructure.md), which reconstructs the original game from its
compiled string table.

**Method:** the same treatment applied to the remake's own source — 36 `.dm` files, 8,454 lines under
`Code/` — then a system-by-system comparison against the OG.

---

## ⚠️ STATUS UPDATE — 2026-08-25

**The tables and rankings below are as of the original 2026-08-24 audit and are now partly stale.**
A build pass on 2026-08-25 closed a large share of it. Read this section first; treat any row below
that contradicts it as out of date rather than current.

**Closed since the audit** (all compile-verified, none playtested):

| Was ranked | Item | Now |
|---|---|---|
| Tier 1.1 | No defense in the remake | Built — `GetDefense()` / `GetMagicDefense()` |
| Tier 1.2 | No critical hits | Built — `RollCrit()`, Spirit-driven |
| Tier 1.3 | `TESTING_CHEAP_SPELLS` on | Off — real MP costs active |
| Tier 1.4 | No `HPfactor`/`MPfactor` | Built, per class |
| Tier 2.5 | No economy | Merchants with Buy/Sell |
| Tier 2.6 | No amulets | 15 of 23, max 2 worn |
| Tier 2.7 | No item drops | Built (`dropType`/`dropChance`) |
| Tier 2.8 | No monster spellcasting / healer AI | Built, incl. `TryHeal()` |
| Tier 2.9 | Real monster stats not applied | Applied |
| Tier 3.10 | No day/night cycle | Real clock, drives the turf swap |
| Tier 4.16 | No quick-cast / quick item | Both built |
| Tier 4.17 | No whisper/shout, no worldsay limit or toggle | All three built |
| Tier 4.18 | Hard mute instead of shadow mute | Shadow mute |
| Tier 4.19 | No player click menu | Built |
| Part 5.1 | Death EXP penalty 25% | 5%, per string 605 |
| Part 5.3 | Respawn 10s manual | 60s auto + numpad 5, per string 887 |
| Part 5.6 | Classchange had no gate | Level 25 gate + level-1 reset |
| Part 5.7 | Mute announced itself | Silent |
| Part 5.8 | No worldsay rate limit | 1s, per the OG's own message |

Also closed, though not separately ranked above: HP/MP regeneration, first-hit kill credit
(`first_hit`), sleep breaking on hit, real buff effects for Upper/Increase/Barrier (they were
stand-ins that quietly healed HP), and hazard terrain (lava/swamp).

**Still open, and the highest-value remaining work:**

1. **No item art.** Every consumable and amulet borrows `key.dmi`. They are functionally complete
   and visually indistinguishable — the single most visible unfinished thing in the game right now.
2. **No HUD.** Still zero `screen_loc` usage anywhere. This also blocks the drag-to-slot half of
   quick items that the OG's help file describes.
3. **No survival layer** — hunger, thirst, sleepiness, temperature, weather, drowning.
4. **No `/stat` scenery kit or NPC dialogue.** Still the largest single volume gap.
5. **No storage containers, no world serializer.**
6. **The `delay` column** in `OGMonsterBaseStats.tsv` is extracted but unapplied — its units are
   unknown, and mapping it onto `attackCooldown`'s deciseconds would roughly double every monster's
   attack rate on an unverified conversion.
7. **The data ask in Part 6.7 below is still the highest value-per-effort item on the board** — a
   var-defaults dump for `/playerclass/*`, `/playerlearn/*/*`, `/skill/*`, and `/item/amulet/*` would
   replace placeholder numbers across all of it, including everything this pass just built.

**Everything built in this pass used placeholder numbers wherever the OG's own values aren't
recovered.** The mechanisms are the OG's; the tuning is invented and wants playtesting.

---

## Part 1 — The remake as it stands today

### Type tree

```
mob
  mob/player        — Hero, Soldier, Wizard, Fighter, Pilgrim, Goofoff, Sage
  mob/playerTemp    — pre-login shell (OG equivalent: /mob/ChoosingCharacter)
  mob/enemy         — 10 monsters + pet behavior
  mob/npc           — one bare placeholder type, no behavior

obj
  obj/item          — base carryable; obj/item/key
  obj/door
  obj/ceiling
  obj/projectile
  obj/spawnMarker
  obj/StatLink      — clickable stat-allocation link (Battle panel)
  obj/SkillLink     — draggable skill link (Battle panel)

turf
  turf/ground  turf/floor  turf/tree  turf/stairs
  turf/furniture  (+ bedhead / bedleft / woodbedleft / counter)

area                — casino, dungeon, boss, forest, town, townrain, battle, castle, …

datum
  datum/skill       — ~58 skill definitions (SkillCatalog.dm)
  datum/status_effect — poison, sleep, sleep/more, silence
  datum/party
  datum/CharacterSaveData
  datum/SaveManager
```

### Core systems present

| System | File | Notes |
|--------|------|-------|
| Combat pipeline | `CombatSystem.dm` | `TakeDamage` → `RollDodge` → defend reduction → `Die` → `CleanUpDead` |
| Attack speed | `CombatSystem.dm` | `GetAttackDelay()` — melee uses `sqrt(Agility × max(Vitality, Intelligence))`; spells use Intelligence + an Agility synergy term |
| Damage | `CombatSystem.dm` | `PerformMeleeHit()` = `round(Strength × skill.damage_multiplier)` |
| Vitals | `StatsDatum.dm` | `MaxHP = 30 + Vit×5 + Level×3`; `MaxMP = 10 + Int×4 + Spirit×2 + Level×2` |
| EXP curve | `CombatSystem.dm` | `Nexp = 15 × Level²`, cap 50, +5 stat points per level |
| Stat caps | `PlayerTemplate.dm` | Per-class `capStrength`…`capSpirit`, memoized via `GetClassStatCaps()` |
| Skills | `SkillCatalog.dm`, `SkillDatum.dm` | 58 datums under `GenericPhysical` / `GenericSpell` / `StatusSpell` |
| Skill slots | `PlayerTemplate.dm`, `SkillLink.dm` | Numpad 9/7/3/1/0, drag-and-drop |
| Skill unlocks | `SkillUnlocks.dm` | `GetStartingKit()` + `GetSkillUnlocks()` per class |
| Enemy AI | `EnemyNPCs.dm` | `AILoop` / `MovementLoop` / `Wander`, sight range, flee below 10% HP, cardinal-only adjacency |
| Pets | `EnemyNPCs.dm` | Assign/rename/mode (Aggressive/Sit/Wander/Follow)/release |
| Status effects | `StatusEffects.dm` | Poison, Sleep, Sleepmore, Silence |
| Party | `Party.dm`, `PartyVerbs.dm` | Create/Kick/Leave/Recruit/Say/Share/Who; EXP + Gold split on one `shareExp` flag |
| Chat | `SocialVerbs.dm` | Say, Emote, Tell, Who, WorldSay, WorldEmote |
| Save | `SaveSystem.dm`, `SaveData.dm` | 4 slots per key, `datum/CharacterSaveData` snapshot, volume prefs |
| Character creation | `LoginMenu.dm` | Class → icon → 4-zone recolor → stat allocation |
| Recoloring | `ColorSwap.dm`, `PaletteManager.dm`, `PlayerIconColorPalette.dm` | hair / eye / main / accent |
| GM tools | `GMCommands.dm`, `BuildTools.dm`, `AdminLevels.dm` | 14 GM verbs + 4 build verbs, 3 permission tiers |
| Areas | `Area.dm` | `battleModeOn`, `battleAllowsPvP`, `indestructibleMode`, `weather`, `areaMusic` |
| Terrain | `Turfs.dm` | Stairs (directional + named-partner warp), beds with HP/MP restore, counters |
| Inventory | `Inventory.dm` | `mob.contents`, count-based capacity `9 + Strength/5`, Drop/Give, named keys |
| Text filter | `TextFilter.dm` | Profanity censor, toggleable by GM |

### The 14 GM verbs

`GM_Announce` · `GM_GhostForm` · `GM_ToggleProfanityFilter` · `GM_ToggleMultiLogin` · `GM_Ban` ·
`GM_Boot` · `GM_Mute` · `GM_Pwipe` · `GM_NameChange` · `GM_CreateObj` · `GM_DayNight` ·
`GM_ToggleLog` · `GM_LevelIncrease` · `GM_BattleMode` · `GM_KillMonsters` · `GM_WorldReboot` ·
`GM_SeeAreas`

Plus build verbs: `GM_MakeTurf` · `GM_MakeMob` · `GM_MakeArea` · `GM_MakeTool`

---

## Part 2 — System-by-system comparison

Legend: **✅ Built** · **🟡 Partial / scaffolded** · **❌ Missing**

### Character & progression

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Classes | 8 (incl. Child) | 7 (no Child) | ✅ |
| All stats start at 1 | Yes | Yes | ✅ |
| Five stats (STR/AGI/VIT/INT/SPR) | Yes | Yes | ✅ |
| Per-class stat caps | `str_max`…`spr_max` | `capStrength`…`capSpirit` | ✅ mechanism, ❌ real values |
| Escalating stat-point cost | `required_points` | `obj/StatLink/GetCost()`, /5 divisor | 🟡 shape right, numbers invented |
| Equipment stat bonus display | `bonus`, `"STR+N"` | none | ❌ |
| **`HPfactor` / `MPfactor` per class** | Yes | **none — one formula for all classes** | ❌ |
| HP/MP regeneration | `HPregen`/`MPregen` + `cur_*` timers | bed-sleep restore only | ❌ |
| Rest / Meditate skills | Yes | Yes (in catalog) | ✅ |
| EXP curve | unknown (recoverable) | `15 × Level²`, invented | 🟡 |
| Level cap | 99 | 50 (temporary) | 🟡 |
| Death penalty | **5% EXP** | **25% EXP + 50% Gold** | ⚠️ **diverges — see Part 5** |
| Respawn | 60s auto, numpad 5 early | 10s manual Interact | ⚠️ diverges |
| Goof Off → Sage | level 25, must unequip, reset to L1 | `BecomeSage()`, **no gate, no reset** | 🟡 |
| Multiple characters per key | unlimited, named savefiles | 4 slots | ✅ |
| Name rules 3–28, no `'<>` | Yes | check `LoginMenu.dm` | 🟡 |

### Combat

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Shared player/monster damage path | `/proc/hit` | `mob/proc/TakeDamage` | ✅ |
| Defense from stats | `/proc/base_def` (AGI+VIT) | **none — raw Strength damage, no defense term at all** | ❌ |
| Magic defense (VIT+INT) | Yes | none | ❌ |
| **Critical hits** | `crit_rate` on every hit, driven by Spirit | **nothing — zero occurrences of "crit" in the codebase** | ❌ |
| Hit / miss roll | `miss`, `chance` | `RollDodge()` (Agility, invented) | 🟡 different model |
| Defend stance | `defend` flag | `isDefending`, 50% reduction | ✅ confirmed match |
| Positional dodge | `jumpable` + Jump skill | Jump exists as a damage skill only | ❌ |
| Barrier blocks damage | `blockable` | Barrier is a skill; no `blockable` channel | 🟡 |
| Elements | fixed 10-type table + `/proc/Element(off/def)` | free-form strings, **inert — nothing sets weakness/resistance** | 🟡 |
| Attack delay from stats | `AttackDelay` (Agility) | `GetAttackDelay()` (invented formula) | 🟡 |
| Floating damage numbers | `numbericon` + 5 colors | text output only | ❌ |
| Hit animations | `hitstate` / `showhitstate` | `flick("hit")` + weapon overlays | ✅ |
| Projectiles | 27 `/proj` subtypes, Step/Collide/owner | `obj/projectile` + `FlashTurfEffect()` | 🟡 |
| Burn / DoT ground hazards | `/burn` (firebane, explodet, snowstorm) | none (poison status only) | ❌ |
| Buff timers (Upper/Barrier) | `*_time` + `*on` overlay | skills exist, `StatusEffects` has no buff subtypes | 🟡 |

### Skills & spells

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Skill count | 34 spells + ~30 physical | 58 datums | ✅ near-parity |
| Numpad slots 9/7/3/1/0 | Yes | Yes | ✅ exact match |
| Drag-to-assign | Yes | Yes (`SkillLink`) | ✅ |
| Free Skills pool | Yes | Yes | ✅ |
| **Quick-cast F5/F6/F7** | `quick_5/6/7`, `QuickSpellSet` | none | ❌ |
| **Quick item (numpad `-` / `*`)** | `quickitem`, `ScrollItem` | none | ❌ |
| Per-spell MP cost table | `/proc/SpellCost` | `mana_cost` per skill — **but `TESTING_CHEAP_SPELLS` is `TRUE`, forcing every spell to 1 MP** | ⚠️ see Part 5 |
| Per-spell cast time table | `/proc/SpellTime` | `cast_time` per skill | ✅ |
| Skill unlock levels per class | `/playerlearn/<class>/<skill>` | `GetSkillUnlocks()` — **flagged PLACEHOLDER TEST DATA** | 🟡 |
| Underwater skill gating | `underwater` flag | none | ❌ |
| `zenithiansword` | exists, unlearnable | not implemented | — |

### Monsters

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Roster size | 77 + 13 bosses | **10** (deliberately trimmed) | 🟡 by design |
| Real base stats | recovered → `OGMonsterBaseStats.tsv` | 2 flat placeholder tiers | 🟡 data exists, not applied |
| Flee at low HP | `run_percentage` | `fleeHealthPercent = 10` | ✅ |
| **Monster spellcasting** | 33 attack/spell procs | **none — every enemy is melee-only** | ❌ |
| **Healer AI** | `HealCheck`, heals wounded allies | none (Healer monster exists, behaves as melee) | ❌ |
| **Caster AI** | 20+ monsters override `Fight` | none | ❌ |
| Line/cardinal targeting for monsters | `CardCheck` / `LineCheck` | `IsCardinallyAdjacent()` | ✅ |
| Kill-credit to first attacker | `first_hit` | attacker-on-death only | 🟡 |
| Item drops | `drop_type` / `drop_rate` | none | ❌ |
| Gold drops | implied | `goldReward` | ✅ (remake addition) |
| Spawn markers | `/stat/respawn` with level range | `obj/spawnMarker` | 🟡 |
| Global area respawner + `boss_chance` | Yes | none | ❌ |

### World systems

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| **Day/night clock** | `Minute()`/`Hour()`, 6AM/6PM, tick buckets | `isNight` global + `IsNightVariant()` helper | 🟡 scaffolding only |
| **Day/night turf swap** | `dstate`/`nstate` on every turf & object | none | ❌ |
| **Weather (rain/snow/puddles)** | full system + messages | `area.weather` var, unused | ❌ |
| **Temperature (9 steps)** | `/proc/Temperature`, per-player `temp` | none | ❌ |
| **Hunger / Thirst / Sleepiness** | Yes, 0–100 | none | ❌ |
| **Air / drowning / swimming** | `air`, `AirCheck`, swim meter | none | ❌ |
| **Food, cooking, farming** | full loop (stove, tub, farmland) | stove/tub noted "not built yet" | ❌ |
| Areas with music | `area_music` | `areaMusic` | ✅ |
| Battle Mode per area | `dangerous`/`peaceful` | `battleModeOn` | ✅ |
| Coop mode | `CoopArea()` | none | ❌ |
| PvP toggle | world status | `battleAllowsPvP` | 🟡 |
| Indestructible mode | `indes` | `indestructibleMode` | 🟡 |
| Multi-level stairs | Yes | Yes (+ GM 2-level toggle) | ✅ |
| Named warp pairs | `/turf/warp`, `/stat/warppoint` | `warpName` + `FindWarpPartner()` | ✅ |
| Sky / Z-travel | `/turf/sky/upsky` | none | ❌ |
| Ice sliders | 4 directional types | none | ❌ |
| Breaking ice / fall-through | `fall_loc` | none | ❌ |
| Pressure plates → timed doors | `/turf/floor/switchtile` | none | ❌ |
| Rolling boulders | `/obj/boulder` 4-quadrant, `Roll`, `Hit` | none | ❌ |
| Level barriers | `/stat/levelbarrier` | none | ❌ |
| Lava / swamp step damage | Yes | none | ❌ |
| Burnable terrain | `BurnTurf`, `burned` | `indestructibleMode` var only | ❌ |
| Casino / slot machine | Yes | `area/casino` exists, empty | ❌ |
| Ceilings hiding interiors | `/area/ceiling`, `ceiling_images` | `obj/ceiling` | 🟡 |

### Items & economy

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Items in `contents` | Yes | Yes | ✅ |
| Drop / Give | Yes | Yes | ✅ |
| Named keys unlock same-named doors | Yes | Yes | ✅ exact match |
| **Item stacking (`xN`)** | `StackUp`/`StackDown` | none | ❌ |
| **Carry limit model** | **weight-based** (`weight`/`max_weight`) | **count-based** (9 + STR/5) | ⚠️ diverges |
| **Encumbrance blocks skill use** | Yes, hard block | blocks pickup only | ❌ |
| **Amulets (23, max 2 worn)** | Yes | **none at all** | ❌ |
| Consumables (herb, tea, leaf) | Yes | none | ❌ |
| Gems / rings / crown | Yes | none | ❌ |
| Wing of wyvern | Yes | none | ❌ |
| Bombs | Yes | none | ❌ |
| Player-written paper/books | Yes | none | ❌ |
| **Merchants / shops** | 6 types, 3 amulet tiers, Buy/Sell | **none — Gold has nothing to buy** | ❌ |
| **Daily paycheck** | Yes | none | ❌ |
| Storage (drawers, pots, chests) | Yes | none | ❌ |

### Social & moderation

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Say / Emote | Yes | Yes | ✅ |
| World say / World emote | Yes, 1s rate limit | Yes, **no rate limit** | 🟡 |
| Tell | Yes | Yes | ✅ |
| **Whisper / Shout** | Yes (view-range tiers) | none | ❌ |
| Who / Look | Yes | Who ✅, Look ✅ | ✅ |
| Toggle worldsay | Yes | none | ❌ |
| Parties | named, disk-persistent, share toggle | session-only, share toggle | 🟡 |
| Party invite prompt (Yes/No/Wait) | Yes | check `PartyRecruit` | 🟡 |
| **Shadow-mute** | muted player sees own message; GMs see `(Muted)` copy | **hard mute — "You are muted and cannot speak."** | ⚠️ diverges |
| Ban | BYOND pager, account-wide | local savefile flag | 🟡 |
| Boot / Pwipe / Ghost form | Yes | Yes | ✅ |
| Player click menu (give gold/item/cast) | Yes | none | ❌ |
| Role Play Mode | Yes | none | ❌ |
| Arena + spectating | Yes | none | ❌ |

### Interface

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| Stat panels | Status / Inventory / Battle | Stats / Battle / Inventory | ✅ |
| Status panel contents | + Hunger, Thirst, Sleepiness, Temperature, Paycheck, Time, Players online | core stats only | 🟡 |
| **On-screen HUD bar** | 13-tile screen-object bar, 4 meters in 25% steps | **none — zero `screen_loc` usage in the codebase** | ❌ |
| Clickable stat allocation | `/obj/menu` | `obj/StatLink` | ✅ |
| Item "Action" tab verbs | Yes | Yes | ✅ |
| Popup windows (reader, GM status) | Yes | none | ❌ |
| Icon recolor at creation | 2 zones (main + side) | **4 zones (hair, eye, main, accent)** | ✅ **richer than OG** |
| Named color palette | 18 hex, 14 names | `PaletteManager.dm` | 🟡 — OG's exact hex list is now available |

### Building & persistence

| System | OG | Remake | Status |
|--------|-----|--------|--------|
| In-game turf/mob/area painting | Yes | `GM_MakeTurf/MakeMob/MakeArea/MakeTool` | ✅ |
| Selection tools (Line/Block/Drag/Flood) | Yes | check `BuildTools.dm` | 🟡 |
| `Customize()` on placed objects | ~25 object types | doors, stairs, warps | 🟡 |
| **`/stat` scenery kit** | ~60 subtypes | doors + a few furniture turfs | ❌ |
| **NPCs with day/night dialogue** | full (`daymsg`/`nightmsg`, walk/stand, facing) | `mob/npc` — bare placeholder, no dialogue | ❌ |
| **Save world back to `.dmp`** | `SaveWorld`/`SaveInstance` | none | ❌ |
| Character savefiles | per-name `.sav` | 4-slot `.sav` | ✅ |
| Global data files | `DWLdata/*.sav`, `party.sav` | none | ❌ |
| Chat/action log | `DWLlog.txt` | `LogChat()` + `GM_ToggleLog` | ✅ |

---

## Part 3 — The gaps, ranked

### Tier 1 — combat correctness (fix before any balance tuning)

1. **There is no defense in the remake.** `PerformMeleeHit()` is `round(Strength × multiplier)` and
   `TakeDamage()` subtracts it directly. The OG has a dedicated `/proc/base_def` and a `tmp_damage`
   working value inside `hit()`. Every balance number in the remake is currently being tuned against a
   pipeline that's missing a whole term.
2. **There are no critical hits.** Zero occurrences of "crit" anywhere in `Code/`. The OG's `hit()` takes
   a `crit_rate` argument on *every* attack, and Spirit's entire documented purpose is crit rate — which
   means **Spirit currently does almost nothing in the remake** except add 2 MaxMP per point.
3. **`TESTING_CHEAP_SPELLS` is `TRUE`.** Every spell costs 1 MP right now regardless of its authored
   `mana_cost`. This is flagged in the file as temporary, but it silently invalidates any MP-economy
   observation made while it's on.
4. **No `HPfactor` / `MPfactor`.** One HP formula for every class means a Soldier and a Wizard with equal
   Vitality have identical HP. The OG explicitly did not work that way.

### Tier 2 — the missing half of the game loop

5. **No economy.** Gold is earned (`goldReward`) and lost on death, but there is nothing to spend it on.
   No merchants, no shops, no consumables, no amulets.
6. **No amulets.** 23 amulets with a clean raw/derived design pattern, max 2 equipped — an entire
   character-building axis, completely absent.
7. **No item drops.** `drop_type` / `drop_rate` have no remake equivalent, so monsters yield only EXP and
   Gold.
8. **No monster spellcasting or AI archetypes.** Every enemy is melee-only. The OG had healers that heal
   allies, casters that keep distance, and 33 distinct monster attack procs. The `Healer` monster is in
   the remake's roster right now behaving as a plain melee enemy.
9. **The real monster stats aren't applied.** `OGMonsterBaseStats.tsv` holds confirmed numbers for 77
   monsters; `MonsterRoster.dm` still uses two flat placeholder tiers.

### Tier 3 — world simulation

10. **No day/night cycle.** `isNight` and `IsNightVariant()` exist as helpers with no clock driving them.
    Meanwhile the art assets almost certainly already carry the `<name>night` states — the OG's entire
    turf set is built in day/night pairs.
11. **No weather, temperature, hunger, thirst, sleepiness, or drowning.** The OG's whole survival layer.
12. **No terrain interaction beyond stairs/warps/beds.** Missing: pressure plates, ice sliders, breaking
    ice, boulders, level barriers, lava, swamp, burnable turf, sky travel.
13. **No `/stat` scenery kit.** The OG had ~60 placeable interactive object types. The remake has doors
    and a few furniture turfs. This is the largest single volume gap.
14. **NPCs have no dialogue.** `mob/npc` is 16 lines and explicitly a placeholder.

### Tier 4 — interface and social

15. **No on-screen HUD.** Zero `screen_loc` usage. The OG's 13-tile bar with four 25%-step meters is
    entirely absent; the remake relies on stat panels.
16. **No quick-cast (F5/F6/F7) or quick item (numpad `-` / `*`).**
17. **No whisper/shout tiers, no worldsay rate limit, no worldsay toggle.**
18. **Mute behaves differently** — hard mute vs. the OG's shadow mute.
19. **No player click menu** (give gold / give item / cast magic on another player).
20. **No world serializer.** Anything a GM builds at runtime is lost on reboot.

---

## Part 4 — What the remake does that the OG didn't

Worth keeping in view so the gap list doesn't read as "the remake is behind on everything."

| Feature | Notes |
|---------|-------|
| **4-zone icon recoloring** | hair / eye / main / accent vs. the OG's 2 (main / side) |
| **Pet system** | Assign, name, 4 behavior modes, release. Nothing like it in the OG string table. |
| **Gold rewards from kills** | The OG's Gold was display-only in the remake before this; kill gold is a remake addition |
| **Structured status-effect datums** | `datum/status_effect` with a clean apply/remove/tick contract; the OG used loose vars |
| **Profanity filter** | Toggleable by GM |
| **Volume controls** | Master / music / SFX, saved per key |
| **Defend attack-speed penalty** | Deliberately kept on top of the OG's plain stance-drop, per your own preference |
| **Split-hand attack animation resolution** | `ResolveAnimState()` handles Fighter icons that have no plain `attack`/`weapon` state |
| **Cardinal adjacency check** | `IsCardinallyAdjacent()` — the OG got this via its cardinal-movement library; the remake reimplements it correctly |
| **Icon-state caching** | `GetCachedIconStates()` — a real performance improvement over per-swing `icon_states()` |

---

## Part 5 — Numbers to correct now, from the string table

These are direct contradictions between remake constants and confirmed OG strings. Each is a small edit.

### 1. Death EXP penalty: 25% → 5%

`Code/Combat/CombatSystem.dm:30`
```
#define DEATH_EXP_LOSS_PERCENT 25
```
OG string 605: `"You have lost 5% of your EXP as penalty for respawn."` — **5%, confirmed verbatim.**

### 2. Death Gold penalty: no OG support

`Code/Combat/CombatSystem.dm:31`
```
#define DEATH_GOLD_LOSS_PERCENT 50
```
The comment claims this "matches 'lose half gold' already documented from the original design notes."
**There is no gold-loss string anywhere in the 4450-string table** — no message, no variable. The OG's
only stated respawn penalty is the 5% EXP line. Either the design note is about a different game, or the
OG dropped gold silently. Worth re-checking the source of that note.

### 3. Respawn: 10s manual → 60s automatic

`Code/Combat/CombatSystem.dm:35`
```
#define RESPAWN_DELAY 100  // 10 seconds
```
OG string 887: `"You will auto-respawn in 60 seconds.  You may press 5 on your numpad to respawn before
then."` — the file already carries a note about this from the 2026-08-10 live finding; the string
confirms it exactly, including the numpad-5 early-respawn option.

### 4. `exp_min` — a floor the remake doesn't have

The OG carries `exp_min` alongside `exp_start` / `exp_needed`. The remake's death penalty clamps only at
`max(0, ...)`. [INFERRED] The OG's floor was almost certainly the current level's threshold, i.e. **you
cannot de-level from a death penalty.**

### 5. Carry capacity: count vs. weight

`Code/Player/Inventory.dm` uses a count-based cap (`9 + Strength/5`). The OG uses `weight` and
`max_weight` per item, with `GetWeight()`. The confirmed data point of "capacity 9" the remake anchors on
may well have been an *item count observed at a particular weight*, not a count limit at all.

### 6. Class change needs its gate

`datum/skill/Classchange` currently reclasses immediately. The OG required:
- level 25 (help file)
- `"You must unequip everything before you can change your class."`
- **reset to level 1**, keeping items and gold

`BecomeSage()` currently carries Level, Exp, and stats straight across.

### 7. Mute should be silent

`CheckMuted()` tells the muted player `"You are muted and cannot speak."` The OG never told them —
`"You have secretly [un]muted X."` and the `(Muted)<...>` GM-only copies show the whole design was for the
muted player to keep talking into a void.

### 8. Worldsay needs a rate limit

OG: `"You must wait 1 second between each world say"` / `"You must wait 1 second between each world
emote"`, backed by a `wsay_limit` var.

### 9. The color palette is now exactly known

`PaletteManager.dm` can be seeded with the OG's real 18 hex values (see
[OGGameStructure.md §3](OGGameStructure.md)) rather than approximations — and the per-icon default
main/side colors for every DW1–DW4 sprite are in the string table too.

---

## Part 6 — Recommended next moves

### Immediate (an afternoon each)

1. Fix the five constants in Part 5 — death penalty, respawn, classchange gate, mute, worldsay limit.
2. Turn off `TESTING_CHEAP_SPELLS` and see whether the MP economy holds up.
3. Seed `PaletteManager.dm` with the OG's confirmed hex palette.

### Short term (the biggest correctness win)

4. **Add a defense term and critical hits to `TakeDamage()`.** Until both exist, Agility, Vitality, and
   Spirit are all doing far less than the OG intended, and no balance number can be trusted. Start from
   the OG's own model: physical defense = f(Agility, Vitality); magic defense = f(Vitality, Intelligence);
   crit rate = f(Spirit).
5. **Add `HPfactor` / `MPfactor` to `PlayerTemplate.dm`**, even as placeholders, so class identity shows
   up in HP/MP.
6. **Apply the real monster stats** from `OGMonsterBaseStats.tsv` to `MonsterRoster.dm`.

### The high-leverage data ask

7. **Have the collaborator dump var defaults for `/playerclass/*`, `/playerlearn/*/*`, `/skill/*`, and
   `/item/amulet/*`** — the exact same type-table extraction that already produced the 77 monster stat
   blocks. That single pass would replace, with confirmed numbers:
   - every `// PLACEHOLDER:` stat cap in `PlayerTemplate.dm`
   - the entire `GetSkillUnlocks()` table (currently labelled *PLACEHOLDER TEST DATA*)
   - every skill's power, MP cost, and cast time in `SkillCatalog.dm`
   - `HPfactor` / `MPfactor` per class
   - the amulet bonuses, if amulets get built

   No bytecode disassembly required. This is by far the highest value-per-effort item on the board.

### Medium term

8. Build the day/night clock — the art assets are already paired for it.
9. Build a minimum economy: one merchant type, a handful of consumables, monster item drops.
10. Give monsters spellcasting and the healer/caster AI archetypes.
