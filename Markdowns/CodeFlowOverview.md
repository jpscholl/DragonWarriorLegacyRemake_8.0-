# DWLR Code Flow Overview

A guided tour of how the codebase actually fits together, written after a full read-through
of every `.dm` file in `Code/` (2026-09-09). Meant as an orientation document — "where do I
start reading if I want to understand system X" — not a replacement for the file-level
comments, which go into far more depth on any one mechanic.

See the bottom of this doc for the bugs found and fixed during that read-through.

---

## 1. File Map

```
Code/
  Admin/
    AdminLevels.dm          -- permission tiers, SyncGMVerbs()
    Commands/
      BuildTools.dm         -- GM map-building tools (GM_MakeTurf/Mob/Area/Tool)
      GMCommands.dm          -- every other GM verb (ban/mute/announce/spawn/...)
    Debug/
      DebugTools.dm          -- Builder-tier diagnostic verbs
  Combat/
    CombatSystem.dm          -- the shared damage/animation/death pipeline
    NPCs/
      EnemyNPCs.dm           -- monster AI (wild + pet modes)
      MonsterRoster.dm       -- every mob/enemy subtype's stat block
    Projectiles.dm           -- ranged spell projectile (Blaze)
    Skills/
      SkillDatum.dm          -- Attack/Defend/Blaze/Fireball (the "different shape" skills)
      SkillCatalog.dm        -- every other named skill, generic-templated
    StatusEffects.dm         -- poison/sleep/buffs/silence
  Core/
    Main.dm                  -- world/client/New(), day/night clock, login/logout
    SmoothMovement.dm        -- movement glide + camera
    TextFilter.dm            -- profanity/slur filter, chat log
  Player/
    PlayerTemplate.dm        -- base mob vars, class overrides, Sage reclass flow
    ClickableStats.dm        -- Battle-tab stat-point spend links
    Inventory.dm             -- items, amulets, capacity
    Party.dm                 -- party datum
    SkillLink.dm              -- draggable numpad-slot skill links
    SkillUnlocks.dm           -- starting kits + leveled unlocks per class
    StatPanels.dm              -- the whole Stat() panel layout
    StatsDatum.dm               -- MaxHP/MaxMP formulas, regen
    Commands/
      PlayerVerbs.dm          -- Action-tab verbs (Interact, Logout, volume, ...)
      PartyVerbs.dm            -- Party-tab verbs
      SocialVerbs.dm            -- Say/Emote/Whisper/Shout/Tell/WorldSay
    Customization/
      ColorSwap.dm              -- the color-picker UI + swatch list
      PlayerIconColorPalette.dm -- per-class-per-icon default zone colors
  Save/
    SaveData.dm                -- CharacterSaveData snapshot datum
    SaveSystem.dm                -- SaveManager (save/load/delete/ban)
  UI/
    HUD.dm                      -- bottom HP/MP/Level bar, floating combat numbers
    LoginMenu.dm                -- character select/creation flow
    PaletteManager.dm             -- per-character recolor state
  World/
    Area.dm                      -- area subtypes, spawn markers, music
    Interaction.dm                 -- OnInteract() base definition
    NPCs.dm                        -- friendly NPCs + merchants
    Obj.dm                          -- doors, storage, signs, bookcases
    Turfs.dm                         -- ground/beds/stairs/warps/hazards
```

The `.dme` file's own `#define` block (top of `DragonWarriorLegacyRemake_8.0+.dme`) holds
every constant that's needed by a file which compiles *before* the file that would normally
own it, alphabetically — `TILE_WIDTH`, `SFX_CHANNEL`, `PLAYER_SPAWN`, `STEP_NAME`/etc, and
`CREATION_PREVIEW_TURF` all live there for exactly that reason. If you're hunting for where a
constant is defined and it's not in the file that obviously should own it, check the `.dme`.

---

## 2. Startup & Connection Flow

```
world/New()                          Main.dm
  -> players = list()
  -> LoadPersistentAdminLists()
  -> log = file("server.log")

client/New()                         Main.dm
  -> saveManager = new(ckey)                    -- opens Player SaveFiles/<ckey>.sav
  -> saveManager.LoadVolumeSettings(src)
  -> ApplyAdminLevel()                          -- AdminLevels.dm: resolves tier, calls SyncGMVerbs()
  -> MoveLoop() started                          -- SmoothMovement.dm, drives held-key movement

mob/playerTemp/Login()               Main.dm
  -> plays dw3conti.mid
  -> spawn(1) ShowLoginMenu(src)                -- LoginMenu.dm
```

`world.mob = /mob/playerTemp` (`Main.dm`), so every fresh connection is handed a
`mob/playerTemp` automatically — this is the type that owns the character-select flow before
a real `mob/player` character exists.

---

## 3. Character Creation & Login Flow

`LoginMenu.dm` is the single owner of the whole flow. It's built as a small state machine over
one `step` variable, using constants from the `.dme` (`STEP_NAME`, `STEP_CLASS`, `STEP_ICON`,
`STEP_CUSTOM`, `STEP_STATS`):

```dm
proc/NewCharacterMenu(mob/playerTemp/M)
    var/step = STEP_NAME
    while(step)
        switch(step)
            if(STEP_NAME)
                M.selectedName = PromptForName(M)
                if(!M.selectedName) return
                step = STEP_CLASS
            if(STEP_CLASS)
                var/selectedClass = PromptForClass(M)
                M.selectedClass = ApplyClassSelection(M, selectedClass)
                if(!M.selectedClass) { step = STEP_NAME; continue }
                step = STEP_ICON
            if(STEP_ICON)
                M.palette = null
                step = IconSelect(M)
                continue
            if(STEP_CUSTOM)
                M.IconPreview()
                step = M.CustomizeColors()
            if(STEP_STATS)
                ...
                step = StatAllocation(M)
                ...
```

This exact loop shape is reused for the **Sage reclass flow** (Classchange skill / Dharma
Scroll item) — `RunSageReclassFlow()` in `PlayerTemplate.dm` drives the identical
`IconSelect()` -> `CustomizeColors()` -> `StatAllocation()` sequence on an *already-playing*
mob instead of a fresh `mob/playerTemp`. Two things needed generalizing to make that safe:

- **`StatAllocation(mob/M, resetFromZero = FALSE)`** — a reclassing character's real stats are
  whatever they earned while leveled up, which would immediately hit the creation screen's
  flat 10-point cap. `resetFromZero = TRUE` seeds the *scratch* allocation list from 1 instead
  of `M`'s real stats, without ever touching the real vars until "Finish" — so backing out of
  a reclass still can't corrupt anything.
- **`EnterReclassPreview()`/`ExitReclassPreview()`** (`PlayerTemplate.dm`) — hide the
  reclassing mob's own body while it's relocated into the icon-preview room
  (`CREATION_PREVIEW_TURF`). This blanks `icon`/`icon_state` outright rather than raising
  `invisibility`, because a client still renders its own `client.mob`'s sprite regardless of
  invisibility level as long as `client.mob` is still that mob (confirmed by testing during
  this session).

```
Icon/color/stat flow, shared:
  IconSelect()        LoginMenu.dm  -- picks from GetClassIcons(class)
  CustomizeColors()   LoginMenu.dm  -- Main/Accent/Hair/Eyes zone picker
  StatAllocation()    LoginMenu.dm  -- 12 points, cap 10/stat

Fresh character:        FinalizePlayer()      LoginMenu.dm
Sage reclass:            RunSageReclassFlow() + BecomeSage()   PlayerTemplate.dm
```

---

## 4. Save/Load System

One `datum/SaveManager` per client, holding one `savefile/F` open on
`Player SaveFiles/<ckey>.sav` for the life of the connection. Up to `MAX_CHARACTERS` slots,
each stored as three keys: `char<N>.name`, `char<N>.data` (a serialized
`datum/CharacterSaveData`), and `char<N>.banned`.

```dm
proc/SaveCharacter(mob/player/M, slot)
    var/datum/CharacterSaveData/D = new
    D.BuildFromCharacter(M)
    F["[key].name"] << M.name
    F["[key].data"] << D
    F.Flush()
```

`CharacterSaveData` (`SaveData.dm`) is a deliberately partial snapshot — it does NOT store
which skills a character knows (that's re-derived every load from `Level`/stats plus the
class's fixed starting kit via `EquipStartingKit()`/`CheckSkillUnlocks()`); it DOES store which
numpad slot each skill is dragged onto, since that's pure player customization with no other
source of truth.

**Deleting a slot compacts the rest.** `DeleteCharacter(slot)` cascades every later slot down
by one instead of leaving a gap:

```dm
proc/DeleteCharacter(slot)
    for(var/i = slot to MAX_CHARACTERS - 1)
        MoveCharacterSlot(i + 1, i)
    // clear the now-vacated tail slot (MAX_CHARACTERS) explicitly
```

`MoveCharacterSlot()` reads each sub-key into its *actual* type (`datum/CharacterSaveData/D`,
not a generic untyped var) — an earlier version that round-tripped `.data` through an untyped
var silently dropped the `/icon` nested inside it. It also deliberately does **not**
self-clear the slot it read from: DeleteCharacter()'s cascade means every slot but the true
tail gets overwritten by the *next* call in the chain anyway, and self-clearing turned out to
corrupt the very next slot in a 3+ character chain (root cause not fully pinned down — some
`savefile` quirk around immediately rewriting a just-nulled key).

---

## 5. Movement & Camera

Two independent per-tick loops drive movement, mirrored between players and enemies:

| | Player | Enemy |
|---|---|---|
| Body (executes steps) | `client/MoveLoop()` — every `world.tick_lag` | `mob/enemy/MovementLoop()` — every `world.tick_lag` |
| Brain (decides direction) | held key via `onMoveKey()` | `mob/enemy/AILoop()` — every `aiTickDelay` (slow) |

Splitting brain/body this way is what makes an enemy's movement look continuous instead of
one visible glide-step per (much slower) AI decision.

```dm
mob/proc/Step(dir, delay = step_delay)
    if(!canAct && !attackRecoveryOnly) return 0
    if(next_step - world.time >= world.tick_lag / 10) return 0   // throttle
    glide_size = TILE_WIDTH / delay * world.tick_lag             // ties glide to step_delay
    if(step(src, dir)) { ...; return 1 }
    return 0
```

The camera (`obj/CameraEye`, `SmoothMovement.dm`) is the client's `eye`, not the mob itself —
this is what lets the view glide continuously and clamp at the map edge
(`CAMERA_VIEW_HALF`/`ClampAxis()`) instead of EDGE_PERSPECTIVE's old snap-at-the-edge behavior.
Anything that changes a mob's `.loc` directly (stairs, warps, `Return`, beds, Wing of Wyvern)
has to explicitly call `client.camera.SnapTo(mob)` afterward, since direct `.loc` writes bypass
`client/Move()` — the only place the camera normally re-tracks.

---

## 6. Combat System

### The attack pipeline

```
UseSkillSlot()/AILoop()
  -> decides to act, resolves a target
  -> datum/skill/X.OnUse(user, target)
       -> PlayAttackAnimation()            (visual/audio only)
       -> PerformMeleeHit()/ApplySpellDamage()
            -> TakeDamage()
                 -> rolls dodge, applies defense, applies damage
                 -> Die() + CleanUpDead() at 0 HP
```

Every skill funnels through `OnUse(mob/user, mob/target)`. Most named skills in
`SkillCatalog.dm` are one-line subtypes of two generic templates:

```dm
datum/skill/Punch
    parent_type = /datum/skill/GenericPhysical
    skillName = "Punch"
    damage_multiplier = 1.0

datum/skill/Icebolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Icebolt"
    element = "ice"
    damage_multiplier = 0.7
    mana_cost = 4
```

`GenericPhysical.OnUse()`/`GenericSpell.OnUse()` own the entire windup/cast/recovery
sequence — a new physical or offensive/healing spell needs *zero* new code, just var
overrides. Only skills with a genuinely different shape (Thornwhip's line attack, Rest,
Meditate, Return, Revive, Classchange, the three status-effect/buff bases) get their own
`OnUse()`.

### Damage math

```dm
GetDefense()      = round((Agility + Vitality) / 4) + defenseBonus + equipDefenseBonus
GetMagicDefense() = round((Vitality + Intelligence) / 4) + magicDefenseBonus + equipMagicDefenseBonus
RollDodge()       = prob(min(30, Agility))
RollCrit()        = prob(min(50, Spirit)), x1.5 damage
```

All four `GetEffective*()` stat readers (`StatsDatum.dm`) fold in equipment bonuses and floor
at 1, so a formula never needs to separately add `equipStrength` etc — and a debuffing amulet
(Wizard's Amulet: `-1 Vitality`) can never drive a stat to 0 and start producing negative HP.

### Status effects

One base `datum/status_effect` with `OnApply()`/`OnTick()`/`OnExpire()` hooks and its own
polling loop (`EffectLoop()`), same shape as every other loop in the codebase. Re-applying an
already-active effect refreshes its duration rather than stacking a second instance:

```dm
mob/proc/ApplyStatusEffect(effectType)
    var/datum/status_effect/existing = GetStatusEffect(effectType)
    if(existing) { existing.Refresh(); return existing }
    var/datum/status_effect/E = new effectType
    statusEffects += E
    E.Start(src)
    return E
```

Upper/Increase/Barrier buffs are one parametrized `datum/status_effect/buff` base
(`bonusVar`/`bonusAmount` set per-subtype) rather than three near-identical copies of
`OnApply()`/`OnExpire()`.

### Enemy AI

`mob/enemy/AILoop()` ticks every `aiTickDelay` and branches on whether the mob has an
`owner` (pet) or not (wild):

```dm
proc/RunWildAI()
    if(target && (target.HP <= 0 || out of sightRange)) target = null
    if(!InBattleArea()) { target = null; Wander(); return }
    if(!target) target = <nearest visible player>
    if(IsCaster()) { TryHeal(); TryCastAt(target); }
    if(HP <= fleeHealthPercent%) moveIntent = FLEE
    else if(adjacent) TryMeleeAttack(target)
    else moveIntent = CHASE
```

Pets (`ShowAssignPetMenu()`/`ShowPetOwnerMenu()`) reuse this exact same target/moveIntent/
`TryMeleeAttack()`/`MovementLoop()` machinery — only `HandlePetTick()`'s branch on `petMode`
(Aggressive/Sit/Wander/Follow) differs from wild-monster decision logic.

---

## 7. Player Progression

### Stats & vitals

`RecalculateVitals()` (`StatsDatum.dm`) is the one place `MaxHP`/`MaxMP` get (re)computed —
called on every level-up and every stat-point spend, always topping current HP/MP up by
however much the max just grew so a level-up never leaves the bar looking emptier:

```dm
MaxHP = round((BASE_MAX_HP + Vitality*HP_PER_VITALITY + Level*HP_PER_LEVEL) * HPfactor) + equipMaxHP
HP += max(0, MaxHP - oldMaxHP)
```

Each class sets its own `HPfactor`/`MPfactor` and per-stat caps (`PlayerTemplate.dm`) —
Soldier is `HPfactor = 1.3` (tanky), Wizard is `HPfactor = 0.7, MPfactor = 1.3` (glass
cannon caster), etc.

### Skills known vs. equipped

```dm
mob/player/var/list/skills = list()                                    -- everything known
mob/player/var/list/skillSlots = alist(9=null, 7=null, 3=null, 1=null, 0=null)  -- numpad
```

`EquipSkill()` (`SkillUnlocks.dm`) is the single place a skill is ever granted — starting
kits (`GetStartingKit()`) and leveled unlocks (`GetSkillUnlocks()` + `CheckSkillUnlocks()`,
checked on every level-up AND every stat-point spend) both route through it. Draggable
`obj/SkillLink`s (`SkillLink.dm`) mirror `skillSlots`/`skills` for the Battle-tab UI, cached
per slot/skill rather than rebuilt from scratch every `Stat()` tick.

### Customization / recoloring

`datum/PaletteManager` (`PaletteManager.dm`) holds `originalColors`/`colors` per zone
(Main/Accent/Hair/Eyes), sourced from `DefaultIconColors.colors_by_class[class][icon]`
(`PlayerIconColorPalette.dm`). **This table is incomplete** — only Hero's `dw3hero.dmi` has
all four zones; Soldier/Wizard have only "Main" (a real property of those sprites, not a
shortcut); Fighter/Pilgrim/Goof-off/Sage have no entries at all yet, which means
`SetZoneColor()` currently rejects every color pick for those classes with "Invalid zone."
`Debug_ShowZoneColors()` (`DebugTools.dm`) exists specifically to sample a class icon's raw
pixel colors (via `GetPixel()`) and print them as `rgb(r,g,b)` literals, ready to paste into
`colors_by_class`, to close this gap.

---

## 8. World Systems

### Turfs & areas

Convention (stated at the top of both `Turfs.dm` and `Obj.dm`): a new hardcoded subtype only
belongs in code if it has real **behavior** (a proc override, a var that does something) —
anything purely visual is a map-editor instance of an existing type, not new code. This keeps
the turf/obj type list from bloating with one subtype per sprite variant.

Real behavior examples: `turf/stairs` (direction-inferred-from-icon_state teleport, or
named-pair link for skins with no inferable direction), `turf/warp` (named-pair teleport),
`turf/furniture/bedhead` (sleep + `SleepRestoreLoop()`), `turf/hazard` (lava/swamp step
damage).

### Day/night cycle

`WorldClockLoop()` (`Main.dm`) advances a virtual clock and calls `SetWorldNight()` at
sunrise/sunset; `GM_DayNight()` calls the same proc on demand. `SetWorldNight()` sweeps every
turf/obj (skipping `/obj/screen` — the HUD lives there and would otherwise get its icon_states
corrupted by the "append night suffix" sweep) to their night icon_state variant, tints every
mob's sprite (`ApplyNightTint()`), and — new this session — forces an immediate HUD text-color
refresh per player rather than waiting for their next `Stat()` tick.

A hidden 1-in-20 "curse night" easter egg (`TriggerCurseNight()`, forceable via the hidden
`GM_HorribleNight()` verb) turns the HUD text red, broadcasts a big red banner, and swaps
`CURSE_NIGHT_MUSIC` in as every area's music for the night — persisting through normal
movement, stairs, warps, and even the bar area's usual "cut music on exit" behavior, all of
which needed their own `isCurseNight` check to not stomp it.

### GM building tools

`BuildTools.dm` splits "what to place" (turf/mob/area picker,
`client.buildSelection`/`buildKind`) from "how to place it" (Click/Drag/Block/Line/Move/
Flood/Delete, `client.buildMode`) — independent axes, so switching placement mode never
clears the current selection. All seven modes funnel through one shared
`PlaceBuildSelection(turf/T)` so turf/mob/area placement logic only exists once.

---

## 9. Known Placeholders / Temp Flags

Grouped here (also tracked in `TODOList.md`) so none of these quietly become permanent:

- **`FullRestore()`** (`DebugTools.dm`) — debug verb working around a real 0-MP bug.
- **`TESTING_CHEAP_SPELLS`** (`SkillDatum.dm`, currently `FALSE`) — forces every spell to 1 MP.
- **Bed restore rate** (`BED_RESTORE_INTERVAL`/`AMOUNT`, `Turfs.dm`) — untuned placeholder.
- **`GM_HorribleNight`** (`GMCommands.dm`) — hidden test verb for the curse night easter egg,
  meant to come out once that's been confirmed working live.
- **Reclass stat treatment** (`RunSageReclassFlow()`, `PlayerTemplate.dm`) — currently resets
  to a fresh 12-point allocation; the real target (per a 2026-09-09 decision) is DW3's own
  Dharma Shrine behavior of halving existing stats, once that fuller system gets built.
- **`colors_by_class`** (`PlayerIconColorPalette.dm`) — only Hero/Soldier/Wizard populated;
  Fighter/Pilgrim/Goof-off/Sage still need real sampled zone colors.
- **`GMblaze`** — the one OG GM verb explicitly dropped from the roadmap (2026-09-07);
  `GM_KillMonsters` already covers its whole use case.

---

## 10. This Session's Deep-Dive Findings

A full read-through of every file in `Code/` turned up three real, previously-unreported
issues, now fixed:

1. **Amulet-sell dupe** (`World/NPCs.dm`, `DoSell()`) — selling a *worn* amulet to a merchant
   deleted it without unequipping it first, permanently keeping its stat bonus while also
   paying out gold for it. `Drop()`/`Give()` (`Inventory.dm`) already had this guard; `DoSell()`
   was missing it. Fixed by unequipping before the sale, matching those two call sites.
2. **Dead code**: `CheckMuted()` (`SocialVerbs.dm`) was fully vestigial — declared, documented
   as "retained so existing callers keep compiling," and never actually called anywhere.
   Removed, along with a stale comment reference to it in `TextFilter.dm`.
3. **Vestigial argument**: every chat verb (`Say`/`Emote`/`Whisper`/`Shout`/`Tell`/`WorldSay`/
   `WorldEmote`/`PartySay`) called `LogChat(line, src)`, but `LogChat(line)` only ever declared
   one parameter — DM silently drops the extra argument, so this was harmless but meaningless.
   Stripped down to `LogChat(line)` everywhere for clarity.

Beyond that, the codebase is unusually consistent and well-documented for its size — shared
helpers are reused rather than duplicated (one `GenericPhysical`/`GenericSpell` template for
~40 named skills, one `PlaceBuildSelection()` for 7 build modes, one `datum/status_effect/buff`
base for 3 buffs), and nearly every non-obvious decision has an inline comment explaining the
*why*, often with a live-testing date attached. No broad refactor looked warranted beyond the
three fixes above — the main outstanding *content* gaps are the ones already tracked in
`TODOList.md` (animations, the color-palette table, weather, etc.), not structural debt.
