# Dragon Warrior Legacy — Original Game Structure

**Source:** `Markdowns/OGStringTable.txt` — the complete string table extracted from the original
`Dragon Warrior Legacy.dmb` (world bin v341, 4450 strings, offsets `0xc8e7..0x2129c`, XORJUMP9 cipher).
Filed in-repo 2026-08-25; it was previously only a loose `strings.txt` on the author's Desktop, so every
citation below now resolves against a file that actually travels with the project. Its companion extract
is `Markdowns/OGMonsterBaseStats.tsv` (77 monsters' base stats), read up in `Markdowns/MonsterBaseStats.md`.

**What this document is:** a reconstruction of how the original game was built, derived entirely from
the names of its variables, procs, types, and text literals. No bytecode has been disassembled yet, so
this describes *shape and structure*, not exact formulas.

---

## 0. How to read this

### Confidence markers

| Mark | Meaning |
|------|---------|
| **[CONFIRMED]** | The string itself proves it. A literal like `"You have lost 5% of your EXP as penalty for respawn."` is the game telling us directly. |
| **[STRONG]** | A named variable or type whose meaning is unambiguous in context — e.g. `str_max` on `/mob/player` is a Strength cap. |
| **[INFERRED]** | A reasonable reading of a name, but the code could be doing something else. |
| **[GUESS]** | Speculation flagged as such. Do not build on these without verification. |

### How the string table encodes structure

Three properties of the table make it readable as an architecture document:

1. **Strings are deduplicated and stored once, in first-use order.** A variable name appears at the point
   the compiler first encountered it. This means *clusters of adjacent strings usually belong to the same
   proc or the same type definition*, and the whole table roughly follows the source-file order of the
   original `.dme`.

2. **The type-path table is dumped at the end (ids ~3359–4388), in reverse declaration order.** Every
   type in the game is listed. Reading a subtree backwards recovers the order the author declared its
   children in — which, for things like skill-unlock lists, is very likely the intended progression order.

3. **`\xff\xNN` bytes are BYOND string-interpolation markers.** A literal like
   `"<\xff\x01(\xff\x01) whispers:> \xff\x02"` is the compiled form of `"<[name]([key]) whispers:> [msg]"`.
   The count of markers tells you how many values a message takes.

**A caution baked into the game itself:** the in-game help file (string 1333) opens with Tarq's own note —
*"The following is outdated. Some information may be incorrect."* Where the help text and the variable
names disagree, trust the variable names.

---

## 1. Engine and third-party libraries

DWL was not written from scratch on bare BYOND. The string table shows at least four external libraries
compiled in, which explains a lot of the game's unusual-for-2005 sophistication.

| Library | Evidence | What it provided |
|---------|----------|------------------|
| **BaseCamp** (Deadron) | `/BaseCamp`, `/BaseCamp/GameController`, `base_Initialize`, `base_EventCycle`, `_event_cycle_receivers`, `base_is_game_creator`, `"BaseCamp: Illegal attempt to write GameController to savefile!"` | Character login/selection flow, a central `GameController` singleton, and a global event-cycle scheduler that objects subscribe to (`AddEventCycleReceiver` / `RemoveEventCycleReceiver`). This is the game's heartbeat. |
| **sd_ library** (Shadowdarke) | `/proc/sd_replacetext`, `typesfrom`, `typesend`, `iswhole` | Text and type-tree utilities. |
| **Cardinal movement lib** | `c_dir`, `c_step_rand`, `c_step_to`, `c_step_away`, `c_step_towards`, `c_step_from`, `get_c_dir`, `get_c_dist`, `c_walk`, `c_walk_towards`, `c_dirs`, `c_dirs_text` | Forces movement onto 4 cardinal directions only. DWL is a 4-way game despite BYOND's 8-way default. |
| **Geometry/AoE lib** | `getring`, `getcircle`, `getblock`, `getline`, `getsline`, `xrange`, `midpoint`, `distance`, `cardinal`, `cardinals`, `allclear`, `densecheck`, `fulldensecheck`, `emptycheck` | Area-of-effect shapes and line-of-fire checks. This is what makes DWL's spells *positional* rather than menu-driven. |

**Custom BYOND icon manipulation** is also present (`SwapColor`, `Blend`, `SetIntensity`, `Turn`, `Flip`,
`Shift`, `DrawBox`, `IconStates`) — this is the machinery behind the two-color character customization.

---

## 2. The type tree — the game's skeleton

DWL declares **twelve custom root types** rather than hanging everything off BYOND's `/obj` and `/mob`.
This is the single most important structural fact about the game.

```
/mob
  /mob/player          — a live player character
    /mob/player/hero  soldier  fighter  goofoff  pilgrim  wizard  sage  child
    /mob/player/GM    (+ /GM/tarq  /GM/masterg  /GM/blazer)
  /mob/monster         — a live monster
    /mob/monster/boss  — 13 boss subtypes
  /mob/ChoosingCharacter — the pre-login shell mob

/obj
  /obj/menu            — the stat-allocation and skill-slot UI objects
  /obj/hud  /obj/hud/text  /obj/hud/char  /obj/hud/black
  /obj/fade  /obj/map  /obj/slots  /obj/battle  /obj/boulder  /obj/GlobalRespawn

/turf                  — floor, wall, water, grass, table, tree, bridge, sky, stairs, warp, iceslider
/area                  — town, bar, temple, castle, wilderness, rave, cave, old, jail,
                         dungeon, casino, forest, boss, underwater, ceiling

--- custom roots ---
/stat                  — interactive scenery (NOT BYOND's stat panel; a confusing name choice)
/item                  — everything carryable
/skill                 — a live, usable skill instance owned by a player
/proj                  — a travelling projectile
/burn                  — a lingering ground hazard

--- pure data trees (types used as records, never instantiated) ---
/playerclass           — per-class stat template
/playerlearn           — the skill-unlock table, /playerlearn/<class>/<skill>
/playerskill           — the master skill definition list
/playericon            — the selectable icon roster, /playericon/<class>/<icon>

--- singletons ---
/BaseCamp/GameController
/RolePlayManager
/PagerBanManager
```

### The data-tree pattern

`/playerclass`, `/playerlearn`, `/playerskill`, and `/playericon` are the architectural centerpiece.
Rather than storing class definitions in lists or text files, Tarq declared each one as a **type**, set
default values on its vars, and read them back with `typesfrom()`. For example:

- `/playerlearn/hero/heal` — a record meaning "the Hero class learns Heal", with a `level` var holding *when*.
- `/playerclass/wizard` — a record holding the Wizard's `HPfactor`, `MPfactor`, `str_max`, `agi_max`, etc.
- `/playericon/soldier/dw3msoldier` — a record for one selectable icon, with its default main/side colors.

**This matters enormously for data recovery:** these var defaults live in the compiled type table, the
exact same place the 77 monster base stats were already successfully extracted from. See §15.

### `/stat` — the buildable world

`/stat` is the base type for every interactive, GM-placeable, world-persistent scenery object. Its
subtypes are the entire town-building kit:

| Subtree | Members |
|---------|---------|
| `/stat/sign` | wooden, inn, snowwooden, snowinn, church, weapon, armor, grave, item |
| `/stat/door` | wooden, silver, snow, ice, gold, jail, bookcase, dw1 |
| `/stat/switchdoor` | timed door opened by a pressure plate |
| `/stat/drawers` | wooden, snow |
| `/stat/pot` | stone, wooden, ice |
| `/stat/chest` | wooden, ice |
| `/stat/fooddrawers` | dispenses food |
| `/stat/npc` | man, richman, strongman, guard, oldman, scholar, priest, woman, oldwoman, dancer + a full "cold" variant set (coldman, coldrichman, coldstrongman, iceguard, frozenoldman, coldscholar, coldpriest, coldwoman, coldoldwoman, icedancer) + friendly monsters (slime, drakee, hoimislime, waterimp, evilwizard, iceknight) |
| `/stat/merchant` | itemmerchant, amuletmerchant, greateramuletmerchant, greatestamuletmerchant, foodmerchant, drinkmerchant |
| `/stat/bookcase` | player-writable shared book storage |
| `/stat/musicalbookcase` | plays a player-uploaded song in a named area |
| `/stat/warppoint` | named teleport pair with an exit facing |
| `/stat/respawn` | monster spawn marker with a level range |
| `/stat/levelbarrier` | level-gated passage |
| `/stat/boulderspawn` | spawns rolling boulders on a timer |
| `/stat/playerspawn`, `/stat/playerstart` | player spawn points |

> Note the `hoimislime` NPC — "Hoimi" is the Japanese name for the Heal spell. A Dragon Quest name
> survived into an otherwise Dragon Warrior-localised game.

---

## 3. Character system

### Creation flow

`/mob/ChoosingCharacter` handles everything before you exist in the world. Its procs give the exact
sequence: `ChooseCharacter` → `NewName` → `NewClass` → `NewIcon` (→ `CustomIcon` / `ResetIcon`) →
`AssignStats` → `Finish`.

**Name rules [CONFIRMED]:**
- 3–28 characters (`"Names must be between 3 and 28 characters long."`)
- No `'`, `<` or `>` (`"Names cannot contain the ', < or > symbols."`)
- Must contain at least one letter or number
- Globally unique (`"The name \"X\" is already taken."`)

**Multiple characters per key [CONFIRMED].** Savefiles are `players/<ckey>/<charname>.sav`, and the
selection menu offers "Create New Character" / "Delete Character" / "Quit".

**One login per key [CONFIRMED].** `"You can't be logged in as two different players at the same time."`
Double-login attempts are logged (`"X/Y attempted double login at Z."`). The GM verb
`GMmultipleplayers` toggles whether two accounts may share one computer.

### Classes

Eight `/mob/player` subtypes: **Hero, Soldier, Fighter, Goof Off, Pilgrim, Wizard, Sage, Child.**

`Child` has a `/playerclass` and a `/playericon` entry (dw4malechild, dw4femalechild) but **no
`/playerlearn/child` subtree** — it learns nothing. [STRONG] It is a cosmetic/NPC/GM class, not playable
in the normal sense.

`Sage` is not chosen at creation. The `/skill/classchange` skill belongs to Goof Off
(`/playerlearn/goofoff/classchange`), and the confirmation text reads:

> *"Are you sure you want to change your class to Sage? (You will keep all your items and gold, but you
> will be set back to level 1.)"*

with the precondition `"You must unequip everything before you can change your class."` The help file
puts the class change at **level 25**.

### Icon customization

Two colors per character — `main_color` and `side_color` — applied over a base icon with BYOND's
`SwapColor`. The prompts are `"What will your first color be?"` / `"What will your second color be?"`,
with a live `preview_icon`.

**The palette [CONFIRMED]** — 18 hex values stored as `main_colors` / `side_colors`:

| Dark set | Bright set |
|----------|------------|
| `#960000` `#009600` `#000096` `#640064` | `#ff0000` `#00ff00` `#0000ff` `#ff00ff` |
| `#969600` `#009696` `#966432` `#4b4b4b` | `#00ffff` `#ffff00` `#c8c8c8` `#ff9600` |
| `#000000` | `#7d7d7d` |

Display names in the menu: Default, Red, Green, Blue, Purple, Golden, Cyan, Brown, Grey, Black, Yellow,
Light Grey, Orange, Dark Grey, plus "Color 1" / "Color 2" / "Done".

### Icon roster

`/playericon` holds every selectable sprite, grouped by class, each with default main/side colors
recorded next to its display name in the string table:

- **Hero:** DW1, DW2, DW3, DW4 Male, DW4 Female, DW4 Elf
- **Soldier:** DW1, DW2, DW3 Male, DW3 Female, DW3 Guard, DW4 Ragnar, DW4 Male Guard, DW4 Female Guard, DW4 Adventurer
- **Fighter:** DW1, DW2, DW3 Male, DW3 Female, DW4 Alena
- **Goof Off:** DW3 Male, DW3 Female, DW3 Bard, DW4 Bard
- **Pilgrim:** DW2 Prince, DW3 Male, DW3 Female, DW4 Cristo, DW4 Nara
- **Wizard:** DW1, DW2 Princess, DW2 Wizard, DW3 Male, DW3 Female, DW4 Brey, DW4 Mara
- **Sage:** DW3 Male, DW3 Female
- **Child:** DW4 Male Child, DW4 Female Child
- **Other:** DW4 Horse, DW4 Wagon

**Key-locked special icons [CONFIRMED].** `/playericon/special` and the GM icon trees are gated by a
`lock` var holding a `&`-delimited key list:

| Icon set | Unlock keys |
|----------|-------------|
| Tarq (Shiny, Wizard, Police, Lego, King, Water, Forest) | `wizdragon&darklink&tarq` |
| MasterG (+ Shiny, Evil, Ghost) | `masterg&mstrg` |
| Blazer (+ Snow, Dark, Angel) | `blazor07&hiryuu` |
| DeathWyvern, XxXDeathWyvernxXx, Saro, Foobar Master, Knucks, Judecca21, Robin, L33t Robin | (individual keys, not in the table) |

> The internal path for "Police Tarq" is `/playericon/tarq/pilgrim` — the pilgrim robe recolored reads as
> a police uniform.

---

## 4. Stats and progression

### The five stats

**Strength, Agility, Vitality, Intelligence, Spirit.** Internal names `str`, `agi`, `vit`, `int`, `spr`.

**The Spirit/Luck ambiguity is original, not a remake artifact [CONFIRMED].** The stat panel label is
`"Spirit:"` (string 928) and the menu type is `/obj/menu/spirit`, but the help file describes it as
*"Luck"*, and the amulet that boosts it — "Amulet of Spirit" — has the internal name `luck`
(`/item/amulet/spirit` with `name` var `luck`). Tarq used both words for the same stat.

**All stats start at 1 [CONFIRMED].** The creation menu literally contains the strings
`"Strength: 1"`, `"Agility: 1"`, `"Vitality: 1"`, `"Intelligence: 1"`, `"Spirit: 1"`, followed by
`"Choose a stat to increase.  (N points remaining)"`.

### What each stat does (help file, string 1333) [CONFIRMED as authorial intent]

| Stat | Effects |
|------|---------|
| Strength | physical damage, **carry capacity** |
| Agility | attack speed, casting speed, **physical defense** |
| Vitality | max HP, **HP regeneration rate**, physical defense, magic defense |
| Intelligence | max MP, **MP regeneration rate**, magic power, magic defense |
| Spirit ("Luck") | **critical hit rate**, monster item drop rate |

So: physical defense = Agility + Vitality; magic defense = Vitality + Intelligence; crit = Spirit.
No dedicated Defense stat exists anywhere in the string table.

### Stat allocation has caps and escalating cost [STRONG]

`/mob/player` carries `str_max`, `agi_max`, `vit_max`, `int_max`, `spr_max` — per-character (almost
certainly per-class, set from `/playerclass`) **hard caps**. The `/obj/menu` code confirms the UI:

- `stat_value`, `max_value`, `"<stat>_max"` — reads the cap
- `"Maxed"` — displayed when the cap is reached
- `required_points` — **the number of points one increase costs**, i.e. cost scales
- `"How many points will you add?"`, `"<N> points to increase"`
- `bonus` and the format string `"<stat>+<bonus>"` — equipment bonuses display separately from base

The GM status readout confirms the base+bonus split:
`"Strength: X+Y  Agility: X+Y  Vitality: X+Y  Intelligence: X+Y  Spirit: X+Y"`.

> Curiosity: only `strength`, `vitality`, and `spirit` override the menu's `Update` proc. `agility` and
> `intelligence` use the base implementation. [GUESS] Those three refresh a derived display (carry
> weight, MaxHP, crit rate) that the other two don't.

### Derived HP and MP

`/mob/player` carries **`HPfactor`** and **`MPfactor`**, consumed by `SetMaxHP` and `SetMaxMP`. [STRONG]
These are the per-class multipliers — the reason a Soldier and a Wizard at the same Vitality have
different HP. Recovering their values per class is high-priority (see §15).

### Regeneration is real

`HPregen` / `cur_HPregen` / `MPregen` / `cur_MPregen` on `/mob/player`, plus a `regen` var, `cur_regen`
used inside the `SetMaxHP` neighbourhood, and the `resting` flag. The `rest` and `meditate` skills exist
as real `/playerskill` entries learned by multiple classes.

[STRONG] The `cur_*` pairs are countdown timers against the `*regen` rates — this is a periodic tick, not
a one-shot. Combined with the help file's "Vitality increases HP regeneration rate", passive regen was
implemented, with Rest/Meditate as accelerators.

> This revises the earlier read that regen was an unbuilt mechanic. The variable pairing pattern
> (rate + current countdown) is what an implemented tick looks like, not a stub.

### EXP and leveling

Vars: `exp`, `total_exp`, `exp_needed`, `exp_min`, `exp_start`, `exp_percent`, `stat_points`, `level`.

- `exp_start` — EXP value at the beginning of the current level
- `exp_needed` — EXP required for the next level
- `exp_percent` — progress, shown on the HUD as a percentage
- `exp_min` — **a floor**; the death penalty cannot push you below it [INFERRED]
- `total_exp`, `total_gold` — lifetime counters, never spent

Procs: `LevelCheck` (level-up), `SkillCheck` (learn new skills), `KillReward` (EXP/gold payout,
party-aware via `party_members`). On level up: `"You have gained a level!"`, then HP/MP rise, possibly
`"You learn <skill>!"`, and stat points are granted.

### Death and respawn [CONFIRMED]

- `"You have lost 5% of your EXP as penalty for respawn."` — **flat 5% EXP loss**
- `"You will auto-respawn in 60 seconds.  You may press 5 on your numpad to respawn before then."`
- Vars: `dead`, `respawn`, `respawn_time`, `original_invisibility`, `original_dense`
- Procs: `Respawn`, `RespawnCheck`

---

## 5. The combat pipeline

### Three global damage entry points [CONFIRMED]

```
/proc/hit       — physical / projectile damage
/proc/cast      — spell damage
/proc/castburn  — lingering burn damage
```

### The `hit()` argument list — the most valuable find in the table

Strings 259–272 form one contiguous cluster of names belonging to the damage routine:

```
damage  element  jumpable  crit_rate  X  miss  tmp_damage
defend  hitstate  blockable  showhitstate  chance  delay
```

Reading each:

| Name | Meaning |
|------|---------|
| `damage` | incoming base damage before defense |
| `element` | damage type; **defaults to `"Physical"`** (the literal sits immediately beside it) |
| `jumpable` | whether the `jump` skill can evade this attack — DWL has *positional* dodging |
| `crit_rate` | per-attack critical chance, modifiable by the attack itself |
| `miss` | miss result flag |
| `tmp_damage` | the working value after defense is subtracted |
| `defend` | whether the target's `defend` skill state applies |
| `hitstate` | which hit-animation icon_state to display |
| `blockable` | whether Barrier / defending can null this |
| `showhitstate` | whether to draw the hit animation at all |
| `chance` | hit chance |
| `delay` | attack delay imposed after the hit |

The presence of both `blockable` *and* `jumpable` *and* `defend` means DWL had **three separate
mitigation channels** — a magic shield, a positional dodge, and a defensive stance.

### Elements [CONFIRMED]

`/proc/Element` takes an `off` / `def` mode and works over ten types:

**Physical, Normal, Fire, Water, Ice, Air, Iron, Plant, Darkness, Holy**

[INFERRED] `Iron` covers the metal-slime archetype's extreme physical resistance; `Plant` is the
thornwhip line; `Air` is Infernos (a wind spell in the DQ line); `Holy`/`Darkness` cover Vivify/Defeat.

### Defense [STRONG]

A global `/proc/base_def` exists. It is not a variable on any mob, so defense is *computed on demand*
from stats rather than stored. This matches the help file's "no Defense stat" model.

### Attack speed

`/mob/proc/AttackDelay` plus `move_speed`, `action_limit`, `atck`, and `delay`. Agility feeds this per
the help file.

### Buffs and status

| Effect | Vars | Notes |
|--------|------|-------|
| Upper (defense up) | `upper`, `upper_time`, `upperon`, `upper_on`, `upper_amt` | `upper_amt` means the magnitude is **variable** — it scales with something, probably caster Intelligence |
| Barrier (magic defense) | `barrier`, `barrier_time`, `barrieron`, `barrier_on` | Same rate+timer+overlay pattern |
| Sleep | `slep`, `asleep`, `wake_up`, `/proc/fallasleep` | Overlay `/image/overlay/asleep` |
| Stopspell | `/proj/stopspell`, `/skill/stopspell` | Silences casting |
| Burning | `burning`, `burned`, `/burn`, `/burn/proc/Burn` | Damage over time on both mobs and turfs |

Overlays confirming visible buff state: `/image/overlay/upper`, `/upperon`, `/barrier`, `/barrieron`,
`/heal`, `/healmore`, `/healmost`, `/blazehit`, `/icespearhit`, `/lightninghit`, `/flamespearhit`,
`/thordainns`, `/thordainew`, `/bang`, `/asleep`.

### Floating combat numbers [CONFIRMED]

`/proc/numbericon` plus five color variants: `rednum`, `bluenum`, `greennum`, `purplenum`, `yellownum`.
Text colors `whitetext`, `bluetext`, `greentext`, `redtext` also exist. Damage numbers were color-coded
by type or by who took the hit.

### Projectiles

`/proj` is a first-class root type with `New`, `Step`, `Collide`, `Del`, `Get_Step`, and an `owner`.
Subtypes: `sickle`, `chain`, `thorn`, `whip`, `boomerang`, `fireclawblast`, `flameswordblast`,
`icesaberblast`, `thunderswordblast`, `lightswordblast`, `sleep`, `stopspell`, `infernos`, `infermore`,
`blaze`, `blazemore`, `firebal`, `firebane`, `bang`, `boom`, `explodet`, `icespear`, `blizzard`, `zap`,
`lightning`, `flamespear`, `defeat`.

`/burn` subtypes — `firebane`, `explodet`, `snowstorm` — are **persistent ground hazards** left behind by
the three biggest spells. [STRONG]

---

## 6. Skills and spells

### Two parallel trees

- **`/playerskill/<name>`** — the master definition of a skill (name, cost, power, element, etc.)
- **`/skill/<name>`** — a live instance the player owns, with a `use()` proc, an `atk` power var, an
  `eqp` equipped-slot var, a `quickcast` flag, and an `underwater` usability flag
- **`/playerlearn/<class>/<skill>`** — the unlock record joining a class to a skill at a level

### Spell cost and cast time are lookup tables, not formulas [CONFIRMED]

`/proc/SpellCost(spell)` and `/proc/SpellTime(spell)` both switch over the full spell-name list
(strings 279–313). MP cost and cast time are authored per spell. Agility/Intelligence presumably modify
the *result*, but the base numbers are hand-set.

Insufficient-MP message: `"You need at least <N> MP to cast <spell>!"`

### The 34 spells, in table order

```
Heal  Healmore  Healmost  Healus  Healusmore  Vivify  Revive
Upper  Increase  Barrier
Sleep  Sleepmore  Stopspell
Infernos  Infermore
Blaze  Blazemore  Blazemost
Firebal  Firebane  Firevolt
Bang  Boom  Explodet
Icebolt  Icespears  Blizzard  Snowstorm
Zap  Lightning  Thordain
Return  Flamespears  Defeat
```

`Vivify` can fail (`"Vivify fails."`); `Revive` has no failure string — [STRONG] Revive is the guaranteed
upgrade. `Return` is blocked in some areas: `"But the strange force contains Return!"` (and the wyvern
wing gets the parallel `"But the strange force contains the wing's powers!"`).

### Weapon and physical skills

```
attack  defend  punch
ironclaw  fireclaw  goldclaw
thornwhip  chainsickle  club  morningstar  boomerang  magicknife
flamesword  thundersword  lightsword  icesaber  falconsword
battleaxe  swordoflethargy  dragonkiller  demonhammer  zenithiansword
jump  dash  quakejump  hide
rest  meditate  classchange
```

Notable:
- **`swordoflethargy`** — inflicts sleep (DW3's Sword of Lethargy)
- **`dragonkiller`** — bonus damage to dragons [INFERRED]
- **`falconsword`** — multi-hit (the Falcon Sword strikes twice in DW) [INFERRED]
- **`hide`** — Fighter stealth; stores `cur_HP` and `cur_loc`
- **`zenithiansword`** — has a `/skill` type and a `use()` proc but **no `/playerlearn` entry in any
  class**. [STRONG] Unobtainable — GM-only or cut content.

### Skill unlock lists per class

Read out of `/playerlearn`, reversed from type-table order (so first-listed here ≈ first learned).
[STRONG on membership, INFERRED on ordering.]

**Hero (23)** — heal, icebolt, thornwhip, lightning, firebal, blaze, sleep, upper, healmore, Return,
icespears, chainsickle, thordain, bang, meditate, healus, swordoflethargy, stopspell, firebane, icesaber,
dragonkiller, vivify, thundersword

**Soldier (11)** — thornwhip, rest, morningstar, chainsickle, swordoflethargy, battleaxe, icesaber,
dragonkiller, flamesword, demonhammer, falconsword

**Fighter (8)** — rest, dash, jump, ironclaw, hide, quakejump, fireclaw, goldclaw

**Goof Off (7)** — thornwhip, club, rest, boomerang, magicknife, jump, classchange

**Pilgrim (20)** — sleep, club, upper, healmore, infernos, Return, healus, stopspell, morningstar,
sleepmore, meditate, vivify, swordoflethargy, increase, healmost, lightsword, infermore, battleaxe,
revive, healusmore

**Wizard (15)** — blaze, lightning, icespears, bang, blazemore, meditate, firebane, thordain, blizzard,
boom, blazemost, firevolt, snowstorm, barrier, explodet

**Sage (29)** — blaze, sleep, lightning, upper, icespears, healmore, infernos, bang, Return, healus,
blazemore, stopspell, meditate, sleepmore, firebane, vivify, increase, thordain, blizzard, healmost,
boom, blazemost, infermore, firevolt, snowstorm, revive, barrier, healusmore, explodet

**Child** — none.

Observations:
- Wizard learns **zero healing and zero physical skills** — pure offense, matching the help file.
- Sage = Wizard's list ∪ Pilgrim's caster list, minus the weapon skills. It is strictly a superset of
  Wizard (29 vs 15) with the Pilgrim support line folded in.
- Hero is the only class with both a real spell list and real weapon skills.
- Pilgrim gets four weapon skills (club, morningstar, battleaxe, lightsword, swordoflethargy) —
  "fair in physical combat", as the help says.
- `rest` is shared by Soldier, Fighter, Goof Off; `meditate` by Hero, Pilgrim, Wizard, Sage. **The split
  is martial vs. caster.**

### Skill slotting [CONFIRMED]

Five numpad slots stored as `nwskill`, `neskill`, `swskill`, `seskill`, `inskill` (numpad 7/9/1/3/0),
assigned by dragging skills onto them (`assign_skill`, `free_skill`, `MouseDropped`). Plus three
quick-cast function keys: `quick_5`, `quick_6`, `quick_7` → **F5 / F6 / F7**, set via `QuickSpellSet`.
Quick item is on numpad `-`, item cycling on numpad `*`.

Help file confirms: *"Numlock must be off"*, and double-clicking an unassigned skill uses it directly.

---

## 7. Monsters and AI

### The roster — 77 regular + 13 boss

In declaration order (≈ the difficulty ladder):

```
Cat  Slime  Dog  Red Slime  Bat  Fox  Babble  Skeleton  Drakee  Healer
Snail Slime  Magician  Yellow Slime  Sizarmage  Frost Cat  Ghost  Wolf
Magidrakee  Reptile  Arctic Fox  Panther  Gremlin  Acolyte  Blazeghost
Tiger  Yeti  Man O' War  Wolf Lord  Drakeema  Bloodhound  Warlock
Silver Fox  Familiar  Giant Eyeball  White Wolf  Wraith  Curer  Leaonar
Werewolf  Weretiger  Metal Slime  Ozwarg  Water Imp  Vulpes  Rogue Knight
Mini Demon  Ice Sloth  Iroid  Steel Bones  Dark Priest  Fairy Dragon
Bengal  Wizard  Metal Babble  Squid  Frozen Bones  Green Dragon  Cloud Puff
Mad Clown  Magma Knight  Cyclops  Infurnus Knight  Blue Lion  Manticore
Rogue Whisper  Blue Dragon  Specter  Ferocial  Devil  Metal Healer
Necrodain  Ice Knight  Archbishop  Lethal Armor  Black Lion  Necromancer
Red Dragon
```

**Bosses:** King Slime, Floormaster, Flare Cat, Chameleon, Crystal Slime, Saro's Shadow, King Healer,
King Metal, Cold Devil, Leviathan, Fenrir, Cloud Knight, Dragonlord.

> There is a `/mob/monster/wizard` whose display name reuses the existing `"Wizard"` string — a monster
> called simply "Wizard", distinct from the player class.

### AI structure

Base behaviour procs on `/mob/monster`:

```
BattleCheck  BattleEvent  PeacefulEvent  Fight  Walk  Run  Idle  InView
Command  Customize  CardCheck  LineCheck  HealCheck
```

- **`CardCheck` / `LineCheck`** — is the target on a cardinal axis / in a straight line? Monsters use
  the *same positional targeting geometry as players*. [STRONG] This is why DWL feels action-y rather
  than turn-based.
- **`HealCheck`** — scan for a wounded ally worth healing.
- **`Run`** with `run_percentage` — monsters **flee below an HP threshold**, as in the NES games.
- **`PeacefulEvent`** vs **`BattleEvent`** — monsters behave differently in peaceful vs. dangerous areas.

Monster attack repertoire (each a proc on `/mob/monster`):

```
Attack  Punch  Dash  Quakejump  Fireclaw  Thornwhip  Chainsickle  Morningstar
Demonhammer  Icesaber  Flamesword  Thundersword
Heal  Healmore  Healus  MUpper  Sleep  Sleepmore  Stopspell
Infernos  Blaze  Blazemore  Firebal  Firebane  Firevolt  Bang  Boom
Icebolt  Icespears  Blizzard  Snowstorm  Zap  Lightning  Thordain
```

### AI archetypes, read from which procs each monster overrides

| Archetype | Overrides | Members |
|-----------|-----------|---------|
| **Healer/support** | `Walk` + `Run` + `Idle` | healer, acolyte, drakeema, curer, metalhealer, archbishop, darkpriest, fairydragon, boss/kingslime, boss/kinghealer |
| **Caster** | `Fight` + `Walk` | magician, sizarmage, magidrakee, gremlin, blazeghost, warlock, wizard, minidemon, waterimp, ozwarg, madclown, roguewhisper, necromancer, devil, bengal, lethalarmor, boss/saroshadow, boss/colddevil, boss/cloudknight, boss/flarecat |
| **Special attacker** | `Fight` only | frostcat, tiger, rogueknight, ferocial, infurnusknight |
| **Movement-only** | `Walk` only | wolflord, familiar, whitewolf, leaonar, vulpes, steelbones, greendragon, magmaknight, manticore, bluedragon, specter, iceknight, reddragon, boss/chameleon, boss/crystalslime, boss/fenrir, boss/dragonlord |
| **Unique movement** | `Move` | boss/floormaster |

### Monster vars

```
hostile  run_percentage  command  drop_type  drop_rate  first_hit  mob_dist  thick
weapon  attack  punch_side  original_dir  wounded  enemies  targets  blocked
```

- **`first_hit`** — records who struck first. This is the enforcement mechanism for the help file's
  rule: *"You won't get any EXP or gold from it unless you hit it first."* [CONFIRMED]
- **`drop_type` / `drop_rate`** — per-monster loot, with rate modified by Spirit/Luck.
- **`mob_dist`** — aggro / leash range.
- **`thick`** — [GUESS] a size or density flag for large monsters.
- **`command`** — a behaviour mode; one known value is `"Wander Close"`.
- Icon-state convention: `"<name>weapon"` and `"<name>attack"` overlay states.

### Spawning

Two systems:
1. **`/stat/respawn`** — a placed map marker: monster type, `lbound`/`ubound` level range,
   `possible_locs`, `spawn_tile`, `spawn_time`, `spawn_point`.
2. **`/obj/GlobalRespawn`** — a named, GM-created area spawner: `spawn_type`, `monsters`, `Area`,
   Z-level (`"On what Z level will X spawn monsters? (Levels are 1-N; use 0 for all levels.)"`),
   count, `Spawn Rate`, and **`boss_chance`** — a roll to spawn a boss instead. [STRONG]

---

## 8. Items, amulets, and the economy

### Item mechanics

`/item` vars: `value`, `drop`, `stack`, `eqp`, `weight`, `worn`.

- **Stacking [CONFIRMED]** — `StackUp` / `StackDown`, displayed with an `"xN"` suffix.
- **Encumbrance [CONFIRMED]** — `weight` / `max_weight` / `GetWeight`, `" (Encumbered)"` on the inventory
  panel, and a hard block: *"You are carrying too much to use skills. Drop some items from your
  inventory."* Strength raises capacity.
- Equipped items cannot be dropped, given, or stored.

### Amulets — max 2 equipped [CONFIRMED]

*"You cannot wear more than 2 amulets at the same time!"*

| Amulet | Internal name | Effect (from the name) |
|--------|---------------|------------------------|
| Amulet of Strength | `strength` | +Strength |
| Amulet of Power | `power` | +physical damage directly |
| Amulet of Agility | `agility` | +Agility |
| Amulet of Speed | `speed` | +attack speed directly |
| Amulet of Vitality | `vitality` | +Vitality |
| Amulet of Health | `health` | +MaxHP directly |
| Amulet of Intelligence | `intelligence` | +Intelligence |
| Amulet of Magic | `magic` | +MaxMP or magic power directly |
| Amulet of Spirit | `luck` | +Spirit |
| Amulet of Light | `fortune` | +drop rate |
| Amulet of the Sky | `sky` | ? |
| Amulet of the Stars | `stars` | ? |
| Warrior's Amulet | `warrior` | martial bundle |
| Wizard's Amulet | `wizard` | caster bundle |
| Amulet of Stepguard | `stepguard` | blocks step damage / encounters |
| Amulet of Increase | `increase` | auto-Increase |
| Amulet of Barrier | `barrier` | auto-Barrier |
| Amulet of Awakening | `awake` | sleep immunity |
| Erdrick's Amulet | `erdrick` | endgame |
| Golden Amulet | `gold` | +gold find |
| Wanderer's Amulet | `exp` | +EXP gain |
| Amulet of the Sun | `sun` | ? |
| Amulet of the Moon | `moon` | ? |

**The design pattern is a raw/derived pair:** Strength↔Power, Agility↔Speed, Vitality↔Health,
Intelligence↔Magic. One boosts the stat, the sibling boosts what the stat produces. [STRONG]

### Other items

- **Gems of Mesron** — Red, Green, Blue (`/item/gem`), plus **Wizard's Ring** (restores MP,
  `"You are at full MP!"`), **Bubble Drop**, **Crown of Barlow**
- **wing of wyvern** — town teleport, blocked in sealed areas
- **medical herb** (HP), **herbal tea** (MP), **leaf of the world tree** (revive another player:
  *"Face another player to use this item, or give it to them while they are dead."*)
- **key** — named `"<door name> key"`; the naming *is* the lock mechanism [CONFIRMED]
- **paper** — player-written books, titled and signed `"<HR>By name(key)"`, shown in a
  `480x320` popup window
- **bomb** — `/item/bomb/proc/Explode`

### Food, drink, and cooking [CONFIRMED]

A full survival-food loop:

- **Raw drops → cooked meals.** `uncooked` flag, `/turf/table/stove`: *"You put X into the oven..."* →
  *"You remove X from the oven."* → `cooked`. `"X must be cooked to be eaten!"`, `"X does not need to be
  cooked!"`
- **Foods:** slime jello, yellow slime jello, roasted beetle claws, baked raven wing, fried drakee wings,
  rat's tail pasta, escargot, barbequed hound ribs, moth's antennae salad, herb
- **Drinks:** babble soda, red slime juice, water (drawn from `/turf/table/tub`:
  *"You fill a cup of water from X."*, *"X is empty, it will be refilled next morning."*)
- `food_amount` / `drink_amount` feed `hunger` / `thirst`
- **Farming:** `food_farmed`, `/turf/grass/farmland`, *"After an hour of farming, you manage to grow X,
  but the farming has tired you out."*, *"You are too tired to farm."*

### Shops and gold

`/stat/merchant` with `shoptype` and four categories — **Item, Amulet, Food, Drink** — across six
merchant subtypes including three tiers of amulet shop (amulet / greater / greatest).

Flow: *"Welcome to the X shop! What would you like to do?"* → Buy / Sell / Cancel, with
`"What would you like to buy? (You have N gold.)"`, `"You don't have enough money to buy X!"`,
`"Thank you for shopping. Please come again soon!"`, `"You have nothing to sell me. Sorry."`

**Passive income [CONFIRMED]:** a `pay` var, an `"Average Paycheck:"` stat-panel line, and a daily
payout — *"You receive your paycheck for the day: <b>N</b> gold."*

**Gambling:** `/turf/table/slots` with `slot1`/`slot2`/`slot3`, a `prizes` list, and
*"X wins N gold from the slots!"* — the `/area/casino`.

---

## 9. World systems

### Day / night cycle [CONFIRMED]

The world runs a clock. `Minute()` and `Hour()` procs, driven by tick buckets `tick3`, `tick4`, `tick6`,
`tick8`, `tick10`, `tick30` on the global event cycle.

- World starts at **12:00 PM**
- **6:00 PM** — night falls
- **12:00 AM** — midnight
- **6:00 AM** — day breaks
- A day-of-week tracker: `days`, `day_position`, Sunday–Saturday

**Every turf and scenery object has a day icon and a night icon.** This is the single largest block of
the string table — hundreds of `<name>` / `<name>night` pairs (`grass`/`grassnight`, `stone`/`stonenight`,
`chestopen`/`chestopennight`, and so on). Vars `dstate` / `nstate` hold the pair; `DayTime()` and
`NightTime()` procs on `/turf`, `/stat`, `/obj`, `/area`, and `/mob/player` swap them.

Seven flavored sunset messages and seven sunrise messages, chosen by current weather:

> *"The sun sinks below the horizon and night falls over the land."*
> *"The last rays of sunlight fade away as the sun sets."*
> *"The sky fades to black as the sun sinks away."*
> *"The sky darkens quickly as the sun sets behind the clouds."*
> *"The rain continues to fall as the sun falls below the horizon."*
> *"Snowflakes tumble down to earth gently as the sun sinks into the west."*
> *"The sky darkens as the sun sets behind the clouds."*

### Weather [CONFIRMED]

Vars `rain_chance`, `end_chance`, `rain_snow`, `weather`, `snow_amount`, `snow_offset`, `snow_image`,
plus `/proc/RainCheck`. Sky turf states cycle `sky` / `skynight` / `skyrain` / `skyrainnight`, and ground
turfs gain snow overlays.

Messages: *"Clouds cover the sky, and rain starts to pour down."* /
*"Clouds cover the sky, and snowflakes fall to the earth."* / *"The clouds fade from the sky."*

`/turf/water/puddle` appears in rain; the GM weather menu offers **Rain, Puddles, Temperature, Snow**.

### Temperature [CONFIRMED]

A nine-step scale driven by `/proc/Temperature` with an area temp (`A_temp`) and a smoothing `diff`:

**Freezing · Very Cold · Cold · Cool · (neutral) · Warm · Hot · Very Hot · Blazing**

Each player carries `temp` and `temp_word`. It shows on the Status panel as `"Temperature:"`. The
existence of an entire "cold" NPC and turf set (snow/ice variants of nearly everything) means there was a
full frozen region.

### Survival stats [CONFIRMED]

`hunger`, `thirst`, plus **Sleepiness** on the status panel, `air` / `swimming` / `swimtime` /
`swimmeter` for breath, and `temp`. All displayed out of 100 (`"<value>/100"`).

- Drowning: `"You have drowned!"`, `AirCheck`, `/turf/water/swimwater`, `"You dive underwater."` /
  `"You return to the surface."`
- `/area/underwater` and `/area/underwater/deepwater` with their own day/night handling
- Skills have an `underwater` usability flag

### Terrain mechanics

| Feature | Types / vars |
|---------|--------------|
| Multi-level stairs | `/turf/stairs` with `stairs_loc`; *"X will now lead N levels up/down"* — **stairs can span more than one Z level** |
| Sky travel | `/turf/sky/upsky` — entering it moves you up a Z level |
| Ice sliding | `/turf/iceslider/north\|south\|east\|west`, vars `isld`, `slid`, `spin` |
| Breaking ice | `/turf/water/ice` with `fall_loc` — you fall through to a location below |
| Lava | `/turf/water/lava`, `/turf/water/swimlava` |
| Pressure plates | `/turf/floor/switchtile`, `/snowswitchtile` → opens a named door for a set duration. *"The tile underneath X lowers down slightly and clicks."* / *"The snow crunches as X steps on the tile, which makes a small click."* |
| Rolling boulders | `/obj/boulder` in four quadrants (ll/lr/ul/ur), `Roll`, `Hit`, `bumped`; `/stat/boulderspawn` with a 6–600 tick delay |
| Level gates | `/stat/levelbarrier` — *"You may only pass if you are level N"* / *"between levels N and M"* |
| Warps | `/turf/warp` and `/stat/warppoint` — named pairs with an exit facing |
| Burning terrain | `burnable`, `burned`, `flammable`, `/proc/BurnTurf` — **fire spells permanently scorch the map** |
| Swamp | `/turf/grass/swamp` with an `Entered` handler — step damage |

### Areas

`/area` subtypes: town (+ rain variant), bar, temple, castle (+ battle), wilderness, rave, cave, old,
jail, dungeon, casino, forest, boss, underwater (+ deepwater), ceiling (+ visible).

Area flags: `area_music`, `magical`, `coop`, `dangerous` / `peaceful` (Battle Mode), `arena_type`
(Desert, Forest, Cave, Farm, Building, Inn), `temps`.

- **`/area/ceiling`** — indoor roofs that hide the interior until you enter, via `ceiling_images` and
  `create_turf_image`.
- **`/area/rave`** with `/turf/floor/dancefloor` — there was a nightclub.
- **CoopArea** — a proc, so cooperative rules (shared kills/EXP) were area-scoped.

---

## 10. World building and persistence

This is the part of DWL that was genuinely ahead of its time.

### An in-game map editor [CONFIRMED]

Build tools: **select, Drag, Block, Line, Flood, Delete**, with `create_mode`, `create_turf_type`,
`create_turf_image`, `create_arenastool`, `used_turfs`, `no_turfs`, `no_stats`, `obj_type`, `turf_type`,
`mob_type`, `area_type`, `tool`, `"<X> tool selected."`

GM verbs: `GMmakestat`, `GMmakeitem`, `GMmaketurf`, `GMmakemob`, `GMmakearea`, `GMmaketool`,
`GMdelobjmob`, `GMseeareas`, and `GMgrantbuildpowers` (a `buildpowers` flag separate from `GM_level`).

### Every placed object is customizable in-game

`Customize()` exists on `/obj/map`, `/turf`, `/mob/monster`, and nearly every `/stat` subtype. Each one
prompts for its own configuration:

| Object | Prompts |
|--------|---------|
| Sign | name, text |
| Door | *"What will X be called? (Use no name for an unlockable door.)"* |
| Drawers / Chest | *"(Use no name for unlockable drawers.)"* |
| NPC | name, day speech, night speech, Stand/Walk, facing direction, always-face-player |
| Merchant | appearance, facing |
| Warp | *"What will you call the warp?"*, *"What is the name of the warp that this warp will lead to?"*, exit direction |
| Respawn | monster type, lowest/highest level |
| Level barrier | lower/upper level limit |
| Boulder spawn | delay 6–600 |
| Stairs | target Z levels |
| Switch tile | which door, how long it stays open |
| Arena stool | *"Click on the turf that you would like X to watch."* |
| Musical bookcase | name, affected area, *"Which song of yours would you like to play for X?"* |

### A runtime world serializer [CONFIRMED]

The game could dump its **live, edited world** back out to compilable BYOND source:

- `/proc/SaveWorld` → `maps/<name>.dmp`, with *"Generating map data...."*, *"Saving X.dmp...."*,
  *"Overwriting X.dmp...."*, *"World X.dmp saved successfully."* / *"World X.dmp was not saved!"*
- `/proc/SaveInstance` → *"Instance save successful."* / *"Instance save failed!"*
- Emits real DM syntax: `"\n(1,1,Z) = {\"\n"`, `"\"}\n"`, `"<var> = list("`, `"<var> = <value>; "`,
  with quote/backslash/newline escaping
- Uses a generated single-letter alphabet (the `a`–`w`, `C`–`Z` block, plus `alpha`, `a1`, `a2`) as tile keys

**This is why §14 exists.** Names typed into Customize prompts on the live server got baked into the
compiled `.dmb`.

### Savefiles

- **Characters:** `players/<ckey>/<charname>.sav` — with a hand-rolled ref-remapping serializer
  (`refs`, `"r<N>"`, `"*r<N>"`, `"<obj>/ref/r<N>"`, `"<obj>/vars/<name>"`, `"/<type>/vars"`). Tarq wrote
  his own object-graph save format rather than using BYOND's default.
- **Global data:** `DWLdata/<name>.sav`, including `DWLdata/party.sav` — **parties survive reboots**
- **Log:** `DWLlog.txt`, format `"[<timestamp>]<message>\n"`, timestamps `hh:mm:ss`
- Read/write tiers: `ReadData`/`WriteData`, `ReadLData`/`WriteLData`, `ReadDData`
- `save_loc` / `GMsavelocation` — a server toggle for whether players resume where they logged out;
  `GMerasesaveloc` wipes it (*"Saved locations erased."*)

---

## 11. Social systems

### Chat channels [CONFIRMED]

| Channel | Verb | Format |
|---------|------|--------|
| Local say | `say` | `<name says:> text` (blue) |
| World say | `worldsay` | `<name wsays:> text` (purple) — **1 second rate limit** |
| Emote | `emote` | `<name action>` |
| World emote | `worldemote` | `<name action>` (`#a04`) — 1 second rate limit |
| Whisper | `whisper` | `<name whispers:> text`, size 1 |
| Shout | `shout` | `<name shouts:> text`, size 3 |
| Tell (private) | `tell` | `<name tells you:> text` (`#00a`) |
| Party say | `partysay` | `<name psays:> text` (`#070`) |
| GM announce | `GMannounce` | red, size 4, centered |

`toggleworldsay` opts out of both world channels. There's a `/DWOchatroom` reference and a
`DWOchatroom.dmb` file — a **separate companion chat program** shipped alongside the game.

### Shadow-muting [CONFIRMED]

Muting is invisible to the muted player. *"You have secretly \[un\]muted X."* Every chat channel has a
paired `(Muted)<...>` variant — the muted player still sees their own message go out, while everyone
except GMs sees nothing. GMs see the `(Muted)` copy.

### Parties [CONFIRMED]

- Named, persistent to `DWLdata/party.sav`
- A `party_leader`, a `members` list, and a **`share` toggle** (`partyshare`, `party_share`,
  `"Party sharing is <on/off>."`) controlling EXP/loot splitting
- Verbs: `create_party`, `partyrecruit`, `partyleave`, `partykick`, `partyshare`, `partywho`
- Invitations are prompted: *"X has invited you to join Y. Will you join?"* → Yes/No/Wait
- `partywho` shows Class, Level, and online/offline/"(Logging in)" status per member
- Name length validated: *"That party name is too short/long."*

### Info verbs

- `who` — everyone online with Class, Level, Party
- `look` — *"You see: name(key) Class: X Level: Y Party: Z"*
- `help` — opens the help file

### Player interaction menu

Clicking another player opens: **Give Gold**, **Give Item**, **Cast Magic** (plus a quick-cast setup by
clicking yourself). Guards: `"X is too far away!"`, `"You don't have N gold!"`,
`"X doesn't have enough room for Y!"`

---

## 12. GM and admin tooling

### A three-tier permission model [CONFIRMED]

1. **`buildpowers`** — map editing only, granted/revoked with `GMgrantbuildpowers`
2. **`GM_level`** — a numeric admin rank, granted with `GMgrantadminpowers`
3. **`base_is_game_creator` / `game_creator_client`** — the host, hardcoded to keys `wizdragon`,
   `darklink`, `tarq`, and the IP `209.6.178.57`

Verb visibility is rebuilt per-player by `setverbs`, `partyverbs`, `buildverbs`, `adminverbs`, `GMverbs`.

### The full GM verb list

**Moderation:** `GMannounce`, `GMboot`, `GMmute`, `GMban`, `GMunban`, `GMpwipe`, `GMtransfer`,
`GMghostform`, `GMnamechange`, `GMaddname`, `GMremovename`, `GMmultipleplayers`

**World control:** `GMdaynight`, `GMweather`, `GMbattlemode`, `GMroleplaymode`, `GMcoopmode`,
`GMindestructablemode`, `GMworldreboot`, `GMworldstatus`, `GMplaymusic`, `GMsavelocation`,
`GMerasesaveloc`, `GMkillserver`

**Building:** `GMmakestat`, `GMmakeitem`, `GMmaketurf`, `GMmakemob`, `GMmakearea`, `GMmaketool`,
`GMdelobjmob`, `GMseeareas`, `GMsavemap`, `GMglobalrespawn`, `GMkillallmonsters`, `GMarenasettings`

**Player editing:** `GMplayerstatus`, `GMlevelincrease`, `GMmakeskillobj`, `GMswitchicon`,
`GMuploadicon`, `GMreverticon`, `GMecho`, `GMblaze`

### Bans go through BYOND's pager service [CONFIRMED]

`/PagerBanManager` posts to BYOND with
`reason=DWL+ban&admin=<gm>&key=<key>&Login=1` and an address variant — the ban is registered
account-wide, not just locally. A local `banlist` and `IsBanned`/`keyban`/`ipban` back it up.

### Role Play Mode

`/RolePlayManager` — a scheduled mode with a start day-of-week. While active, GMs cannot change the
time (*"You can't change the time during Role Play Mode!"*). Announced with
*"Role play mode has been engaged!"* / *"Role play mode has ended."*

### Other server modes

| Mode | Effect |
|------|--------|
| **Battle Mode** | Per-area `dangerous` / `peaceful` toggle. *"X is now a dangerous/peaceful area."* |
| **PvP / non PvP** | Separate world status |
| **Indestructable mode** | `indes` — global invulnerability |
| **Coop mode** | `GMcoopmode` — shared kill credit |
| **Multiple players** | Allow/deny two accounts from one machine |

### The self-destruct

`GMkillserver` deletes the host's own files after two confirmations
(*"Are you sure you want to delete the hosting files for DWL?"* → *"Wait!"*) then
*"Server files terminated."* The files it removes: **`DWOchatroom.dmb`** and **`DWL80.zip`** —
confirming the original distribution was **version 8.0**.

---

## 13. HUD and interface

### The bottom HUD bar [CONFIRMED]

Built from `/obj/hud` screen objects on a black strip spanning `screen_loc` **`"1,0 to 13,0"`**, i.e.
13 tiles wide on the bottom row. Two half-rows are used — `:16` is the upper half of the tile.

| screen_loc | Content |
|------------|---------|
| `1,0:16` | `"Level:"` |
| `4,0:16` | level value |
| `6,0:16` | `"HP:"` |
| `7:16,0:16` | current HP |
| `9:16,0:16` | `"/"` |
| `10,0:16` | MaxHP |
| `1,0` | `"XP:"` |
| `4:16,0` | exp percent + `"%"` |
| `6,0` | `"MP:"` |
| `7:16,0` | current MP |
| `9:16,0` | `"/"` |
| `10,0` | MaxMP |
| `13,0` | (right edge — quick item slot) |

Four meters: `lifemeter`, `magicmeter`, `expmeter`, `swimmeter`, each with a matching timer
(`lifetime`, `magictime`, `exptime`, `swimtime`) and drawn in 25% steps (icon states `0`, `25`, `50`,
`75`, `100`). Bar colors from `HudColor`: `#3fbfff`, `#5bdb57`, `#8484ff`.

`/proc/HudText` draws arbitrary text with `Screen_Loc`, `X_Offset`, and `Length` for centering.

### Three stat panels [CONFIRMED]

**Status** — Class, Party, Hit Points, Magic Points, GM Level, CPU, Experience Points, Gold,
Average Paycheck, Time, Hunger, Thirst, Sleepiness, Temperature, Players online

**Inventory** — `"Inventory -"`, `" (Encumbered)"`, `"N/M items"`, `"Quick Item:"`

**Battle** — Strength, Agility, Vitality, Intelligence, Spirit, Stat Points, then `"Free Skills -"` and
the assigned numpad slots (`"Numpad 9"`, `"Numpad 7"`, `"Numpad 3"`, `"Numpad 1"`, `"Numpad 0"`)

### Popup windows

- `window=GMplayerstatus&size=640x480&can_resize=0&can_minimize=0` — GM player inspector
- `window=reading&size=480x320&can_resize=0&can_minimize=0` — book/paper reader

### Input

Default click and double-click are suppressed (`/mob/verb/NoClick`, `/mob/verb/NoDblClick` bound to
`.click` / `.dblclick`) so the game can own all mouse input. Movement is verb-driven per direction on
`/client`, with a `turn_walk` toggle: *"You will \[not \]turn to the direction you press."*

---

## 14. The original server's live world data

Strings 4389–4449 are not code. They are **names typed by GMs and players into Customize prompts on the
live server**, captured when the world was serialized back into the compiled game. This is a surviving
fragment of the actual DWL town map.

**Buildings:** Eatery · Bar · Grunge Cafe · Church · Jail · Battle arena · Silk's Mansion ·
Wood House 1 · Wood House 2 · House 1 · House 2 · House 3 · Apartment 1 · Apartment 2 · Apartment 3

**Inns:** Wood N. Inn, with Room 1, Room 2, Room 3 — and a second inn with **Room 11, 12, 13, 14** and
**Room 21, 22, 23, 24**, i.e. a two-floor numbered inn.

**Warps:** `old warp`, `cave warp`, `old door`

**Player content:** `Balzackian Musical key` — a musical bookcase owned by Balzack, who also appears in
the shared bookcase quotes file. `Silk's Mansion` — a player-owned house.

**Signs:** *"Welcome to the Church"*, *"Stop by and mess around with us!"* (Grunge Cafe)

Almost every building name has a matching `"<name> key"` — the key-naming lock system in live use.

The shared bookcase (string 1687) preserves the community's in-jokes, attributed to Makiten, Seige,
Balzack, and Saro. It is the closest thing to a social record of the original server that survives.

---

## 15. Open questions and next extraction targets

### What the string table cannot tell us

Names, not numbers. Everything below needs bytecode disassembly or type-table var extraction.

### Highest value / lowest effort: extract var defaults from the type table

The 77 monster base stats were already recovered this way. **The exact same technique applied to these
type trees would recover most of the remaining unknowns without disassembling a single proc:**

| Target | What it yields |
|--------|----------------|
| `/playerclass/*` | **HPfactor, MPfactor, str_max, agi_max, vit_max, int_max, spr_max, move_speed per class** — the complete class template |
| `/playerlearn/<class>/<skill>` | **The exact level each class learns each skill** |
| `/playerskill/*` and `/skill/*` | **`atk` power, `cost`, `delay`, `element`, `crit_rate`, `jumpable`, `blockable` per skill** |
| `/item/amulet/*` | **The exact bonus each amulet grants** |
| `/item/food/*`, `/item/drink/*` | `food_amount`, `drink_amount`, `heal_amount`, `value`, `weight` |
| `/mob/monster/*` | `run_percentage`, `drop_type`, `drop_rate`, `mob_dist`, `exp`, `gold` (beyond the base stats already pulled) |
| `/stat/merchant/*` | Shop inventories per tier |

### Then: disassemble these procs, in priority order

1. **`/proc/hit`** — the damage formula. Arg list already known (§5).
2. **`/proc/base_def`** — the defense formula. Confirms or refutes AGI+VIT.
3. **`/mob/player/proc/SetMaxHP`** and **`SetMaxMP`** — the HP/MP formulas and how HPfactor applies.
4. **`/mob/player/proc/LevelCheck`** — the EXP curve and stat points per level.
5. **`/mob/player/proc/KillReward`** — EXP/gold payout and how party sharing splits it.
6. **`/proc/SpellCost`** and **`/proc/SpellTime`** — the per-spell MP and cast-time tables.
7. **`/proc/Element`** — the elemental multiplier matrix (10 × 10).
8. **`/mob/proc/AttackDelay`** — how Agility converts to attack speed.
9. **`/proc/cast`** and **`/proc/castburn`** — magic damage and DoT.
10. **`/mob/player/proc/SetQuickItem`, `GetWeight`** — the carry-capacity formula from Strength.

### Specific unresolved questions

- **Does `crit_rate` come from Spirit alone?** The help file says yes; `hit()` takes a per-attack
  `crit_rate` argument, so skills likely modify it.
- **Is `upper_amt` scaled by caster stats?** The variable name implies a computed magnitude.
- **What do Amulet of the Sky / Stars / Sun / Moon do?** Their internal names are their own names,
  giving no hint.
- **Is `thick` on monsters a size flag or something else?**
- **Why do only Strength, Vitality, and Spirit override the stat menu's `Update` proc?**
- **What is `Master Sage` / `Master Hero` / `Master Wizard`?** Three strings sitting next to the GM
  Commands block. [GUESS] The displayed Class name for the three GM characters (Tarq, MasterG, Blazer).
- **Was passive regen active, or gated behind Rest/Meditate?** The `cur_*regen` timer pattern suggests
  passive, but only the bytecode will settle it.
