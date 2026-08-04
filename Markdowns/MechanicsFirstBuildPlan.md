# Mechanics-First Build Pass — Approved Plan (2026-08-04)

**Status when this file was written: approved, not yet started.** This is the working
plan for a large coordinated build pass across classes, skills, monsters, and the GM
Building System. Written to survive a context/session reset — if you're picking this up
in a new chat, read this file first, then `TODOList.md` and `ClassReference.md` for the
underlying design decisions this plan executes against.

## Context

The remake's design docs (`ClassReference.md`, `TODOList.md`) are far ahead of the code:
3 of 7 classes don't exist, no class actually has a real skill-unlock table (every
`GetSkillUnlocks()` still returns placeholder Fireball-only test data), stat caps aren't
enforced anywhere, 88 monster icons have zero stat blocks behind them, and the GM
Building System (Phase 10) is fully unbuilt. The user decided to close this gap in one
coordinated pass: get every mechanic *working* end-to-end with clearly-marked
placeholder numbers, defer all UI polish to a later "Big Beautiful Update" pass, and
defer Guilds/Master-tier/Merchant-Thief/weapon-gating/Mounts/TM-scrolls to a future
version (already logged in `TODOList.md`, 2026-08-04 decisions).

**Non-negotiable convention across every stage**: every invented/placeholder number,
formula, or stub gets an explicit `// PLACEHOLDER:` comment saying what it represents
and that it needs real tuning later. User's exact words: "This should go without
saying, but mark all placeholders in the code period!" This applies even to things
that already exist today without one (e.g. existing skill unlock stubs) if this pass
touches them.

Order below is dependency-driven (user's "interleave as needed" call): classes before
their skill tables, skill tables before monsters need them (monsters don't depend on
player skills, but come after classes since both touch combat plumbing), area/
inventory/exp/verb work is independent and can slot in anywhere, Building System last
since it depends on the monster roster existing (`GMmakemob` needs something to place)
and areas being complete (`GMmakearea` needs the night-variant subtypes).

---

## Stage 1 — Fighter, Pilgrim, Goof-off, Sage classes

Follow the exact pattern Hero/Soldier/Wizard already use:

- **`Code/Player/PlayerTemplate.dm`**: add `mob/player/Fighter`, `/Pilgrim`, `/Goofoff`,
  `/Sage` subtypes (`class = "..."`, `hasMana` where the class is a caster). Add
  per-class stat-cap vars on each subtype (`capStrength`/`capAgility`/`capVitality`/
  `capIntelligence`/`capLuck`) for **all 7 classes**, not just the new 4 — using
  `ClassReference.md`'s confirmed numbers where known, `// PLACEHOLDER:` invented ones
  elsewhere (every class has at least one `?` gap today).
- **`Code/UI/LoginMenu.dm`**: add to `PromptForClass()`'s list; add `GetClassIcons()`
  branches using the icon files that actually exist (`Mob Icons/Player/`):
  Fighter → `dw1fighter`/`dw2fighter`/`dw3malefighter`/`dw3femalefighter`; Pilgrim →
  `dw2pilgrim`/`dw3malepilgrim`/`dw3femalepilgrim`; Goof-off →
  `dw3malegoofoff`/`dw3femalegoofoff`; Sage → `dw3malesage`/`dw3femalesage` (Sage won't
  appear in `PromptForClass()`'s normal list — GM-only direct pick per existing design,
  but still needs a `GetClassIcons()` entry for that path). Uncomment/finish the
  already-stubbed `ApplyPlayerClass()` switch branches.
- **`Code/Save/SaveSystem.dm`** `LoadCharacter()`: mirror the same switch (flagged
  gotcha — currently duplicated independently of `LoginMenu.dm`, easy to miss).
- **`Code/Player/Customization/PlayerIconColorPalette.dm`**: add empty
  `colors_by_class["Fighter"] = list()` (etc.) entries so nothing crashes; real
  per-class palettes stay a follow-up.
- **Stat-cap enforcement**: both `StatAllocation()` (`LoginMenu.dm`, creation-time) and
  the level-up stat spend path (`ClickableStats.dm`) currently use one flat
  `statCap = 10` for every stat/class. Replace with a lookup against the mob's own
  `capStrength` (etc.) vars added above, for all 7 classes.
- **Sage's skill list** = union of Hero + Wizard + Pilgrim's tables (user's explicit
  call, `ClassReference.md`).

## Stage 2 — Real skill-unlock tables + a generic skill framework (all 7 classes)

`GetStartingKit()`/`GetSkillUnlocks()` exist as the right hook (`Code/Player/
SkillUnlocks.dm`) but every class's `GetSkillUnlocks()` today is Fireball-only
placeholder test data, and only 4 skills (`Attack`/`Defend`/`Fireball`/`Blaze`) have
any real `datum/skill` implementation at all — the other ~85 named skills across
`ClassReference.md` don't exist as code, just names.

Building a bespoke, fully-designed `OnUse()` for ~90 individual skills is out of scope
for "mechanics working, tune later" — instead, add **two generic, configurable base
skill types** in `Code/Combat/Skills/SkillDatum.dm`:

- `datum/skill/GenericSpell` — configurable `mana_cost`, `damage_multiplier`,
  `element`, single-target-damage or heal-amount vars; `OnUse()` reuses the existing
  `ApplySpellDamage()`/heal plumbing already proven by Blaze/Heal-equivalent code paths.
- `datum/skill/GenericPhysical` — configurable `damage_multiplier`, melee vs. ranged
  flag; `OnUse()` reuses `TakeDamage()`/`PerformMeleeHit()`'s existing pipeline.

Every named skill in `ClassReference.md` (Heal, Icebolt, Thornwhip, Lightning, Sleep,
Rest, Meditate, etc. — including all of Soldier/Fighter/Goof-off/Pilgrim/Wizard's
currently-unlisted-level skills) becomes a **thin one-line subtype** of one of these two
bases, setting name/icon_state/cost/multiplier only — same shape as how
`ClassReference.md` itself already reduced ~90 entries to "which stat governs it."
`// PLACEHOLDER:` every multiplier/cost. Skills that are genuinely special-shaped
(status-effect skills like Sleep, utility skills like Return/Rest) get their own small
override but still built now, not stubbed out — matches the user's "just have the
framework/placeholders" instruction; nothing gets left non-functional.

Fill in `GetSkillUnlocks()` for all 7 classes using `ClassReference.md`'s tables,
Hero's 2 confirmed data points (Heal@lvl3/6Int, Thornwhip@lvl5/8Str) as the calibration
anchor for spacing on every unconfirmed entry — `// PLACEHOLDER:` on every invented
level/threshold.

Goof-off's `Classchange` becomes a real skill (`datum/skill/Classchange` or similar)
whose `OnUse()` calls the new Sage-reclass proc built in Stage 1's Sage work — this is
the "Full mechanic" the user confirmed: a proc that `new`s a `/mob/player/Sage`, copies
over stats/level/inventory/skills/client, transfers `loc`, and deletes the old mob —
same vars-transfer shape `FinalizePlayer()`/`LoadCharacter()` already use to spawn a
typed mob, just applied mid-game instead of at creation/load.

## Stage 3 — Monster roster (88 subtypes)

Add `mob/enemy/[name]` for every file in `Mob Icons/Monsters/*.dmi`, following the one
existing example (`EnemyNPCs.dm`'s `slime` subtype: `icon = 'X.dmi'`, `icon_state`,
`Level`, `HP`/`MaxHP`). Before writing all 88, read a small sample of the actual `.dmi`
files' icon_states directly (same binary-string-dump approach already used for
`castmeter.dmi`, per the BYOND-quirks memory) to confirm the real `icon_state` value
per monster rather than guessing "world" for all of them.

Stats: `// PLACEHOLDER:` tiered stat blocks — group the 88 names into a handful of
tiers by obvious naming cues (common-animal names like bat/cat/dog = weak; humanoid/
elemental names = mid; named/boss-sounding entries like `dragonlord`, `cyclops`,
`devil` = strong), each tier just a multiplier on one base stat block (HP/Strength/
Agility/Vitality/Intelligence/Luck), per the user's "use them all, best judgement"
call. No ranged/spellcasting AI this pass (already deferred in `TODOList.md` Phase 6 —
every monster stays melee-only for now, personal MP pools for casters are a confirmed
future addition).

## Stage 4 — Area night variants

`Code/World/Area.dm`: add `snownight`/`rainnight`/`waternight1`/`waternight`/
`deepwaternight1`/`deepwaternight` subtypes, mirroring their existing day counterparts
exactly (same shape as `snow`/`rain`/`water1`/`water`/`deepwater1`/`deepwater` already
there). Completes the area roster confirmed against a real screenshot of the OG's own
area-type list.

## Stage 5 — Verb category reorg

Retag every verb's `set category` across `PlayerVerbs.dm`, `Inventory.dm`,
`SocialVerbs.dm`, `PartyVerbs.dm`, `GMCommands.dm`, `AdminLevels.dm`, `DebugTools.dm`
into: **Combat**, **Inventory/Action** (current `"Action"` verbs), **Social**
(unchanged), **Party** (kept separate, per user's call), **Settings** (unchanged),
**GM** (merges current `"Admin"`/`"Builder"`/`"GM"` — 10 verbs total across
`GMCommands.dm`/`AdminLevels.dm`), **Debug** (unchanged, admin-only).

While merging into one GM tab, also extend the existing `SyncGMVerbs()` dynamic
add/remove pattern (currently only retrofitted to `GMtogglelog`) to the rest of the
consolidated GM verbs, so a player without sufficient `adminLevel`/`canAdmin`/
`canBuild` doesn't see verbs they can't use at all, rather than seeing them and
getting rejected on click. This directly serves the "fullproof GM system" QoL note
from the user's old notes.

## Stage 6 — Inventory capacity formula

`Code/Player/Inventory.dm`'s `GetInventoryCapacity()`: replace the flat
`BASE_INVENTORY_SLOTS` return with `// PLACEHOLDER:` `base + floor(Strength /
STR_PER_CAPACITY)`, coefficients chosen so a level-1 Hero's starting Strength lands
at capacity 9 (the one confirmed real data point) — exact starting Strength pulled
from the actual creation defaults in code, not assumed.

## Stage 7 — Exp curve

`Code/Combat/CombatSystem.dm`'s `LevelCheck()`: replace the flat `Nexp += 10` with a
`// PLACEHOLDER:` convex curve (something like `Nexp = round(BASE_EXP *
Level^EXP_CURVE_EXPONENT)`) so early levels come cheap and the requirement grows
faster at high levels — matches the user's "fast at first, slows down" description.
Exact constants are placeholder, tune once there's real playtesting to feel it against.

## Stage 8 — GM Building System (Phase 10, biggest chunk)

New code (likely a new `Code/Admin/Commands/BuildTools.dm`, added to the `.dme`):

- `GMmaketurf`/`GMmakemob`/`GMmakearea` — same "pick from list, 'None' cancels, picking
  a real type enters build mode" pattern already proven by `GMbattlemode`
  (`GMCommands.dm`). `GMmakemob` picks from the Stage 3 monster roster (correcting the
  design doc's `/mob/monster/*` — actual base type is `/mob/enemy`).
- `GMmaketool` — picks one of the 7 confirmed modes (Click/Drag/Block/Line/Move/Flood/
  Delete) into a `client/var/buildMode`; confirms with "[Mode] tool selected." per the
  confirmed OG text.
- Click handling while build mode is active: `client/MouseDown()`/`MouseDrag()`/
  `MouseUp()` (BYOND's standard mechanism for drag/hold tools) dispatching per
  `buildMode` — Click places once, Drag places continuously while held, Block computes
  a rectangle between down/up points and fills it, Line constrains to a straight line
  between down/up, Move relocates whatever atom was clicked on mouse-down to the
  mouse-up tile, Flood does a same-icon/icon_state contiguous-tile fill (BFS), Delete
  clears the clicked tile then immediately places the current selection (confirmed
  "clear-and-replace" semantics, not a plain delete).
- A white cursor-square screen overlay tracks the current build target — same
  `screen`-object-overlay shape `GMseeareas`'s existing area-grid overlay already uses,
  just a single square instead of a grid.
- All three placement tools + `GMmaketool` go in the new consolidated **GM** category
  from Stage 5, gated the same way (`canBuild`/`adminLevel` per existing patterns).

Build all 7 modes together per the user's call — Move/Flood are the two genuinely
tricky ones; if either needs to ship as a rougher first cut, it'll be called out and
marked `// PLACEHOLDER:`/commented at the specific spot that's rough, not silently.

---

## Verification

- Compile after each stage (not just at the very end) with:
  `& "C:\Program Files (x86)\BYOND\bin\dm.exe" "C:\Users\jpsch\Desktop\DWLR
  Test\DragonWarriorLegacyRemake_8.0+.dme"` — confirm "0 errors, 0 warnings" before
  moving to the next stage.
- Claude can't drive the actual BYOND client (mouse drag, live combat, character
  creation flow) — after each stage compiles clean, the user needs to playtest it
  (especially Stage 8's build tools, Stage 1's Sage class-change, and Stage 3's
  monster stat feel).
- After the pass, update `TODOList.md`/`ClassReference.md`/`GMCommandsReference.md`
  checkboxes and notes to match what actually got built, same style as existing
  entries (including anything that shipped rougher than planned).

---

## How to resume this in a new chat

1. Point Claude at this file (`Markdowns/MechanicsFirstBuildPlan.md`) plus
   `Markdowns/TODOList.md` and `Markdowns/ClassReference.md`.
2. Confirm which stage to start on (this plan hadn't started execution yet as of
   writing — check `git log`/`git status` and the TODOList's checkboxes to see if a
   later session already made progress before assuming Stage 1 is still first).
3. The **mark every placeholder with `// PLACEHOLDER:`** rule is non-negotiable per
   explicit user instruction — carry it into the new session regardless of what else
   carries over.
