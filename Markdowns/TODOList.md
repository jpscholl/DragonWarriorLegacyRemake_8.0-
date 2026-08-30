# Dragon Warrior Legacy Remake — TODO List

Reference checklist derived from the original design notes. Grouped by system, roughly in
build order (top of list = do first). `[x]` = already exists in the codebase as of this
writing; `[ ]` = not built yet. Re-check this file periodically since it'll go stale as
work lands — it's a planning aid, not a source of truth about current code (the code is).

## V1 Scope Note

**UI is explicitly out of scope for the first edition.** Menus, panels, and any player-
facing screens should be built as the most bare-bones text/`input()`/`stat()`-based
interface that gets the underlying system working — no visual polish, no custom skin
work, no "make it pretty" passes. That's an intentional later-edition pass once the
systems themselves (classes, combat, world tools, etc.) are functionally complete. Don't
gold-plate menus while implementing phases below; get them working, move on.

## Turf/Obj Convention (adopted 2026-07-21)

**Stop hardcoding purely-visual turf/obj variants as new types.** Source:
[BYOND forum — "Snippet Sunday #2: Learning to love the map editor"](https://www.byond.com/forum/post/1620724).
A new `turf`/`obj` type belongs in code only if it has different **behavior** (a proc
override, a var that does something). A tile/object that's just a different sprite of
something that already exists (e.g. `cobble`/`burntcobble`/`carpet` in `Turfs.dm`, which
today are three hardcoded types differing only by `icon_state`) should instead be painted
as a **map-editor instance** of one generic type (right-click the type in the object tree
→ New Instance... → override `icon_state`), no new code needed at all.
- **Both sweeps are now done.** `Turfs.dm` was collapsed first (~46 purely-visual types
  across ground/floor/furniture/wall/fence), followed by `Obj.dm` (door/drawers/
  bookcase/chest/sign/pot variants — see `ObjRepaintReference.md` for exact values).
  `turf/furniture/counter` stays a real type (checked by exact path in
  `PlayerVerbs.dm`'s `Interact()`); `obj/door`, `obj/ceiling`, `obj/stat/sign`'s
  `OnInteract()` and `obj/stat/door`'s `parent_type` reuse all stay real too since they
  have actual behavior. Both maps needed a repaint pass after — see
  `TurfRepaintReference.md`/`ObjRepaintReference.md` for the lookup tables used.
- **Applies going forward**: any new turf/obj variant that's purely visual should be
  added via the map editor's instance tool, not a new
  `Code/World/Turfs.dm`/`Obj.dm` type block — no reason to start the pile again.
- Confirmed no interaction with the `GMdaynight` toggle either way — it operates on
  live `icon_state` values at runtime, which look identical whether they came from a
  hardcoded type default or an instance override.
- Reminder comments left at the top of both `Turfs.dm` and `Obj.dm`.

## Code Cleanup Pass (2026-07-28)

Full-codebase sweep for duplication/dead code, at your request. All behavior-preserving
(clean recompile after each change), nothing here changes gameplay:
- `GMdaynight()` (`GMCommands.dm`) — the 4 near-identical night-suffix
  add/strip blocks (turf x2 directions, obj x2 directions) collapsed into one
  `ToggleNightIconState()` helper.
- Attack/Blaze's identical "drop defend stance for the swing/cast, restore it after
  unless manually toggled" dance (`SkillDatum.dm`) extracted into two shared mob procs,
  `DropDefendForAction()`/`RestoreDefendIfUntouched()` (`CombatSystem.dm`) — was
  duplicated inline in both skills, now a single implementation either can call
  (Fireball still applies the same restore check without the drop, unchanged).
- `mob/playerTemp/Logout()` and `mob/player/Logout()` (`Main.dm`) had byte-identical
  bodies (they're sibling types, neither inherits the other) — both now just call a
  shared `SaveAndLogout()`.
- `ColorSwap.dm`'s `Set_Main()`/`Set_Accent()`/`Set_Hair()`/`Set_Eyes()` — four
  otherwise-identical procs differing only by which palette zone string they passed —
  collapsed into one `SetZoneColorPrompt(zone)`; call sites in `LoginMenu.dm` updated.
  Also removed `appearance_updating` (declared but never read/set anywhere, already
  flagged dead in its own comment) and `IsColorUsed()` (never called anywhere).
- `ClickableStats.dm`'s `obj/StatLink` had a `statMap` list mapping each attribute name
  to itself (`"Strength" = "Strength"`, etc.) — pure identity mapping, since every
  construction site (`StatPanels.dm`) already passes a real mob var name. Removed the
  indirection entirely; `attributeName` is used directly as the var name now.
- `PaletteManager.dm`'s `GetAllZones()` — never called anywhere, removed.
Left alone on purpose: `AdminLevels.dm`'s `TestBuilderVerb()`/`TestAdminVerb()` (still
useful for confirming permission tiers, not accidental bloat) and the bug-history
comments throughout every file (load-bearing context from real playtest fixes, not
fluff — see this file's own intro about that).

---

## Mechanics-First Build Philosophy (adopted 2026-08-04)

**Get every system's actual mechanics working correctly first, with placeholder
numbers everywhere they're needed — tune the numbers later, once there's something
real to playtest.** This is an explicit sequencing decision covering the whole next
build pass, not just one phase:

- **Modularity over accuracy**: every system below should be built so its placeholder
  values (damage numbers, stat caps, level thresholds, costs, timers, etc.) are easy to
  retune later without restructuring the system itself — same pattern already used for
  `TESTING_CHEAP_SPELLS`/`GetManaCost()` (one flag + one accessor) and
  `SleepRestoreLoop()` (interval/amount as parameters). Don't chase real/authentic
  numbers now; chase a working, swappable framework.
- **No UI work until mechanics are done.** Every player-facing screen stays the
  bare-bones text/`input()`/`stat()` interface from the v1 Scope Note at the top of
  this file — no exceptions — for this entire pass, including systems built brand new
  in it (e.g. the building/map-editor tools in Phase 10).
- **"The Big Beautiful Update" (your joke name for it, riffing on a certain bill)** is
  the explicitly-planned *next* major pass after this one: menu/character-select
  polish, the graphical build-mode picker, the splashscreen/title screen — see the
  Quality of Life section below for the full list. Nothing in that bucket starts
  before this mechanics pass is actually done.
  **2026-08-13 carve-out — combat feedback UI is IN SCOPE NOW, not BBU:** the bottom
  HUD (Level/HP/XP/MP) and floating combat numbers (red damage/miss, yellow crit,
  green heal-with-animation) plus HP/MP meters floating above each player/mob are
  needed for this pass, not deferred — combat isn't really playable/testable without
  them. Everything else in the v1 bare-bones-`stat()`-interface rule above still
  applies (no menu polish, no splash/title screen, no graphical build-mode picker
  yet) — this is a narrow, explicit carve-out for combat legibility specifically, not
  a general "UI work is fine now" reversal. See the Map-overlay HUD and Floating
  damage numbers entries below (Phase 3) for the full spec.
  **Also clarified, same date — overall release sequencing:** phase 1 (this pass)
  targets matching the OG as closely as possible; once done, that faithful version
  ships as its own standalone release in honor of the OG DWL; the Big Beautiful
  Update (graphics/modernization) is a separate pass that comes after that release,
  not a continuation blended into it.
  **2026-08-10, joke floated, not committed**: a possible BBU easter-egg NPC caricature
  in the same "certain bill" spirit as the nickname itself. Purely a bit at this point
  — no design, no scheduling, not something to start building unprompted.
- **Deferred out of this pass entirely** (revisit in a future version, not this one):
  Guilds, "Master" class tier, Merchant/Thief classes, weapon/tome-gated skills,
  Mounts, TM/HM-style spell scrolls. Each is still logged in its normal phase below,
  just explicitly not in scope right now.

## OG Help File — Recovered Mechanics (found 2026-08-04)

You pasted the original game's actual in-game `Help()` text (by Tarq/WizDragon,
labelled "outdated" even by its own author, so treat details as directionally right,
not gospel). New confirmed mechanics not previously in this file:

- **Quick Item slot** (Phase 5's "Quick Item" entry above, previously undesigned) —
  confirmed OG mechanic: drag an item onto the dedicated Quick Item slot (separate from
  the general inventory list) to select it; Numpad `*` **cycles through** carried items
  in that slot; Numpad `-` **uses** whatever's currently selected. Matches the OG
  Inventory tab's "Quick Item: Nothing" label already noted in Phase 5.
- **Skill targeting model** — not yet built at all in our code (current skills are all
  self-cast/melee-range only). Confirmed OG flow: click the target player, choose
  "Cast Spell" from their interaction menu; alternatively, click **yourself** to arm a
  "quick spell," then click any subsequent target to fire it at them without reopening
  the menu. Relevant once any targeted (non-self, non-melee) player-vs-player or
  player-vs-ally skill gets built — nothing currently needs this, but Blaze/future
  spells aimed at other players eventually will.
- **Unequipped skills are still usable** — double-clicking a known skill that isn't
  assigned to a numpad slot casts/uses it directly, no need to equip it first. Numpad
  slots are a convenience binding, not a requirement to act. Confirms equip/known
  distinction already in `ClassReference.md` extends to actual usability, not just
  display.
- **Numlock must be off** for the numpad skill keys to register (OG quirk, worth
  keeping in mind if slot keys ever seem unresponsive during testing — not something to
  code around, just a player-side gotcha).
- **Class flavor text** (confirms/refines existing docs, no contradictions):
  - Hero: "Balanced in all areas... if you plan on soloing"
  - Soldier: "best class at taking damage" (physical power/defense/HP)
  - Fighter: "attacks extremely quickly," huge physical damage, "not so good at taking
    damage" — glass cannon, consistent with its Phase 6 dual-stat delay design once
    weapon-speed-vs-bulk tradeoffs get tuned
  - Goof-off: "weaker than the rest" but becomes Sage at (per this doc) level 25 —
    **note**: `ClassReference.md` doesn't have a confirmed level for `Classchange`
    yet; this "25" is the first real data point for it, worth using as the placeholder
    if none exists already
  - Pilgrim: healing/defensive magic, "fair in physical combat"
  - Wizard: "very weak in physical combat," most powerful offensive magic
  - Sage: "combination of Wizard and Pilgrim... learns both offensive and defensive
    magic, but is horrible in physical combat" — informed the Sage skill-list decision
    above (`ClassReference.md`), though your explicit call was to also fold in Hero's
    list, going beyond just Wizard+Pilgrim
- **Posted community rules** (useful if a `Help()` rewrite or a rules/MOTD feature ever
  gets built): no harassment, listen to GMs ("anyone with a fancier icon than normal"),
  no spam, don't steal kills/loot (directly confirms the first-hit-tag decision above —
  "you won't get any EXP or gold from it unless you hit it first, anyway"), general
  courtesy.
- **Help() content itself**: still just a placeholder in our code (Phase 4). This
  recovered text is a reasonable starting draft for the real content once that's
  written, though it'd need updating for our actual mechanics (real-time Zelda-style
  combat instead of the OG's own combat model, current class roster, etc.) rather than
  copied verbatim — the OG's own author already flagged parts of it as outdated.

---

## Phase 1 — Login & Character Creation (mostly done, polish remains)

- [x] Character select menu, 4 save slots, load/create/delete (`Code/UI/LoginMenu.dm`)
- [x] Create Character flow: Name → Class → Icon → Colors → Stats (`LoginMenu.dm`)
- [x] Class list: Hero, Soldier, Wizard (icons + palettes)
- [x] Zone-based recoloring (Main/Accent/Hair/Eyes) via `PaletteManager`/`ColorSwap.dm`
- [x] Stat allocation on creation (12 points, cap 10 per stat, `StatAllocation()` in
      `LoginMenu.dm`) — creation cap is flat 10 regardless of class; the much higher
      per-class ceilings (`GetClassStatCaps()`, `PlayerTemplate.dm`) only apply to
      later level-up spend (`ClickableStats.dm`). Confirmed 2026-08-10; all 5 stats
      also start at 1 (base mob default) instead of any higher baseline.
- [x] Add remaining starting classes: Fighter, Pilgrim, Goof-off — already built
      (`PlayerTemplate.dm`/`LoginMenu.dm`/`SkillUnlocks.dm`, the mechanics-first build
      pass), this checkbox was just stale. All 6 playable classes exist.
- [x] Sage is normally NOT a creation-time class choice — it's what any class becomes by
      changing into it (DW3-style), see `ClassReference.md`. Two paths, both built:
      Goof-off learns `Classchange` as a built-in leveled skill (level 25); every other
      class uses a **Dharma Scroll** item instead (`obj/item/consumable/dharmaScroll`,
      `Inventory.dm`, built 2026-08-28) — same level-25/unequip-everything gates,
      reuses the exact same `RunSageReclassFlow()`/`BecomeSage()` mid-game class-swap
      flow Classchange already calls, so there's one real implementation behind both
      doors. No drop source or merchant sells it yet — spawn via `GM_MakeItem` for
      testing. GMs can still pick Sage directly at creation, skipping both paths.
- [ ] **Expanded class-change system — your own idea, "eventually."** The OG's own
      system is actually already broader than a single hardcoded path — any class can
      reach Sage via the Dharma Scroll, not just Goof-off (confirmed above) — but it
      only ever leads to one destination (Sage). You want to build on that concept
      further: not fully scoped yet, but the seed idea is more class-change
      destinations, not just the one endpoint. Needs its own design pass once the base
      class/skill systems are further along: which classes can change into what beyond
      Sage, whether new destinations are item-gated (more Dharma-Scroll-like items) or
      skill-gated, and whether it's one-way or reversible.
- [ ] **Move tutor — your own idea, not OG-derived, "eventually."** An NPC that teaches
      skills/spells outside a class's normal kit — lets a player cross-train into
      abilities they wouldn't otherwise unlock by leveling their own class. Related to
      but distinct from the class-change idea above (this teaches individual moves
      without changing your class entirely). Not scoped yet: which skills are
      tutor-eligible vs. class-locked, whether it costs Gold/an item/a quest, and how it
      interacts with the confirmed weapon/tome-gating idea (Phase 5) if that gets built.
- [ ] "Master" class tier — **deferred to a later version (2026-08-04 decision)**.
      GM-only, one Master variant per base class (Master Hero,
      Master Sage, etc., per-GM), higher stat caps and stronger moves than the normal
      version of that class. Generalizes/replaces the single "GM_Custom" class from the
      original design notes — it's a family, not one catch-all class.
- [ ] Merchant and Thief classes — **deferred to a later version (2026-08-04
      decision)**. These were added in later OG DWL versions you don't
      have access to, so there's no reference data to recover; stats/moves/unlock
      criteria for these two need to be designed from scratch, not documented from play
- [x] Populate `DefaultIconColors` for Soldier/Wizard icons — 2026-08-28: sampled real
      pixel colors from `dw3guard.dmi`/`dw3malewizard.dmi` (PowerShell + System.Drawing,
      not eyeballed). Both sprites only have ONE genuine costume color in the actual
      pixel data (unlike `dw3hero.dmi`, which encodes Hair/Eyes/Main as three distinct
      near-identical blues) — so only "Main" is populated for each; Hair/Eyes/Accent are
      honestly absent, not invented. `PaletteManager.dm` already handles a partial zone
      list safely.
- [x] Add a "lock in this character?" confirmation screen before `SaveCharacter()` —
      2026-08-28: `alert()` Yes/No in `NewCharacterMenu()` (`LoginMenu.dm`); "No" loops
      back to stat allocation rather than discarding everything.
- [x] Duplicate-name check across a ckey's own save slots — 2026-08-28: case-insensitive
      check in `PromptForName()` (`LoginMenu.dm`) against `GetCharacterSlots()`.

## Phase 2 — Core Player Data Model

- [x] Base stats on mob: STR/VIT/AGI/INT/Spirit (named `Luck` originally, reversed back
      to `Spirit` 2026-08-09 once MaxMP tie-in was confirmed — see Open Questions below
      and `ClassReference.md`'s Naming note)
- [x] Class, Level, Exp/Nexp, Gold, HP/MaxHP, MP/MaxMP, StatPoints (`PlayerTemplate.dm`)
- [x] Admin/Builder resolution on `client` (not mob) — hardcoded ckey lists, fresh every
      connect, savefile-tamper-proof by design (`AdminLevels.dm`)
- [x] `isMuted` var + mute enforcement in chat verbs — mob-level `isMuted` var
      (`PlayerTemplate.dm`), `CheckMuted()` gate (`SocialVerbs.dm`) blocks `Say`/`Tell`/
      `WorldSay`/`Emote`/`WorldEmote`, plus `PartySay` (`PartyVerbs.dm`, not in the
      original confirmed list but the same category of verb). Var is session-only, no
      persistence. `GM_Mute` verb now sets it on other players — see Admin verbs list below.
- [x] Chat + login/logout logging — new discovery, not in the original design notes, but
      a confirmed real excerpt from the OG's own server log showed connect/disconnect/
      host events and chat lines (`<Name(ckey) says:> msg`) all sharing one
      auto-timestamped stream. Reproduced the same way: `world.log` redirected to
      `server.log` (`world/New()`, `Main.dm`), chat verbs write their exact
      display-matching bracketed line via `LogChat()` (`Code/Core/TextFilter.dm`).
      Logged unconditionally — even a muted player's blocked attempt still lands in
      the log (`CheckMuted()` runs after `LogChat()`, not before). Custom
      `"[Name]([key]) logs in/out at [IP]."` lines added at `mob/playerTemp/Login()`
      and `SaveAndLogout()` (`Main.dm`) — the OG excerpt's connect/disconnect lines are
      BYOND's own automatic ones, but the "logs in" moment itself needed its own line.
      Every `LogChat()` line is prefixed with a full date+time (`YYYY-MM-DD hh:mm:ss`),
      written explicitly rather than relying on BYOND's own auto-stamp (time-only) —
      the OG excerpt only had a full date on the session-start/-end banner lines, not
      per-message. No IP on chat lines (confirmed — not in the OG excerpt), only on
      login/logout, which spell it into their own sentence. `server.log` gitignored.
- [x] Anti-double-login (`client/New()`, `Main.dm`) — confirmed from the same OG log
      excerpt: two different ckeys connecting from the same IP got logged as
      `"[newKey]/[existingKey] attempted double login at [IP]."` and the new one was
      immediately disconnected while the original session kept running. `adminLevel <
      LEVEL_GM_HOST` gates it — GMs are exempt (confirmed), e.g. testing with a second
      window from the same machine.
- [x] Real party data model (`Party.dm`, `PartyVerbs.dm`) — `datum/party` with
      name/leader/members/shareExp. `CreateParty()` prompts for a name (Social tab);
      the six confirmed verbs (`PartyKick`, `PartyLeave`, `PartyRecruit`, `PartySay`,
      `PartyShare`, `PartyWho`) live on a dedicated Party tab that's only added to
      `src.verbs` once you're actually in a party (`ShowPartyVerbs()`/`HidePartyVerbs()`,
      `PlayerTemplate.dm`). `isPartyLeader` surfaces as "Party: [name] Leader" in
      `StatPanels.dm` and `PartyWho()`. `PartyShare` splits kill Exp evenly across
      `Party.members` (`Die()`, `CombatSystem.dm`) — no solo-vs-group XP penalty yet,
      that formula was never confirmed from OG testing. Party is session-only, not
      saved/loaded.
- [ ] **Guilds** — **deferred to a later version (2026-08-04 decision)**. (your own
      idea, 2026-07-31) — a persistent, saved counterpart to the
      session-only Party above: where Party is a temporary in-the-moment group,
      a Guild would be a standing, cross-session member list (likely its own save data,
      not tied to any one character's slot). Not scoped yet: creation cost/requirements,
      guild-specific perks or shared features (bank? chat channel? tag next to your
      name?), rank structure (leader/officer/member), and whether Party and Guild
      membership are independent or a Guild is just a pool you draw Parties from.
- [x] Persistent Builder/Admin promotion — 2026-08-28: `GM_PromoteBuilder`/
      `GM_PromoteAdmin` (`GMCommands.dm`, GM-Host tier), toggle verbs backed by their own
      `Server Data/admin_promotions.sav` (`AdminLevels.dm`) — deliberately NOT under
      `Player SaveFiles/`, since this project's own Save File Editor tool makes that a
      real self-promotion vector. Takes effect immediately via `ApplyAdminLevel()`, no
      relog needed. Hardcoded test lists stay as-is for solo-dev testing.
- [x] `StatsDatum.dm` resolved: not a dead stub anymore — holds `RecalculateVitals()`,
      called from `ClickableStats.dm` (after a stat point spend) and `LevelCheck()`
      (`CombatSystem.dm`, after a level-up). Derives `MaxHP`/`MaxMP` from Vitality/
      Intelligence + Level via placeholder `#define`d coefficients (tune later); a
      `hasMana` flag keeps 0-MP classes (Soldier) at 0 regardless of Intelligence.
- [x] **Fixed — full HP/MP on login, every login.** `FinalizePlayer()` (`LoginMenu.dm`)
      now calls `RecalculateVitals()` once right after stats are applied, then tops
      `HP`/`MP` to their new max — this also resolved the deeper inconsistency where
      the static per-class `MaxMP` literals (`PlayerTemplate.dm`, 15/30) were silently
      overwritten the moment any stat point was later spent anyway; those literals are
      now deleted, `RecalculateVitals()`'s formula is the single source of truth from
      creation onward. `LoadCharacter()` (`SaveSystem.dm`) also now sets `MP = MaxMP`
      after restoring the save snapshot, so a returning character logs in with full
      mana too, not just whatever was saved. `FullRestore()` debug verb kept (still
      useful for general testing), comment trimmed since the bug it was working around
      is gone.
- [ ] **TEMPORARY TESTING STATE — three things currently in the code that are NOT
      meant to ship as-is.** Grouped here so none of them quietly become permanent:
      1. `FullRestore()` debug verb (`DebugTools.dm`) — tops HP/MP to max. Exists to
         work around the 0-MP bug above; remove once that's actually fixed.
      2. `TESTING_CHEAP_SPELLS` (`SkillDatum.dm`, currently `TRUE`) — forces **every**
         spell to cost 1 MP regardless of its real `mana_cost`, so spells can be spammed
         while tuning. Flip to `FALSE` to restore real costs; deliberately built as one
         flag + one `GetManaCost()` accessor rather than editing each spell's number, so
         reverting is a one-line change and future spells inherit the behavior for free.
      3. Bed restore rate (`BED_RESTORE_INTERVAL`/`BED_RESTORE_AMOUNT`, `Turfs.dm`) —
         currently 1 HP + 1 MP per 0.5s, confirmed as a placeholder explicitly expected
         to be retuned. Open questions when it is: should the rate scale with anything
         (Vitality? level? inn quality?), and should an inn bed differ from a random bed
         found in the world?
- [ ] **Rest skill — confirmed planned, not built.** Lets a player sleep in place
      anywhere (no bed required) to recover HP/MP. **Confirmed design point**: it
      should recover *slower* than a bed, since it's sleeping on the ground rather
      than in an actual bed — exact numbers not decided. The groundwork is already
      in place for this: `SleepRestoreLoop()` (`Turfs.dm`) is a mob proc that takes
      its interval/amount as arguments (defaulting to the bed rate), so Rest just
      needs to set `isSleeping`/`icon_state` and call it with a longer interval —
      no duplicate loop, and it inherits the existing wake-on-move behavior
      (`Step()`, `SmoothMovement.dm`) and double-loop session guard for free.

## Phase 3 — Stat Panels & UI

- [x] Status/Battle/Inventory statpanel tabs (`StatPanels.dm`)
- [x] Clickable stat allocation post-creation (`ClickableStats.dm`)
- [x] Inventory panel: capacity display, item icons, click-to-use, right-click Drop
      (`Inventory.dm`) — Drop sits in its own "Action" tab per original-game behavior
- [x] Numpad skill slots (9/7/3/1/0) — **key execution wired**: `mob/player/skillSlots`
      (`PlayerTemplate.dm`) + `client/verb/UseSkillKey()` (`SmoothMovement.dm`) +
      `Interface.dmf` macros bound to the physical Numpad9/7/3/1/0 keys. This repurposed
      what used to be diagonal-movement macros — confirmed this game has no diagonal
      movement at all (classic Dragon Warrior, 4-directional only; diagonal motion may
      only ever happen as a skill's own effect, e.g. a dash, never as direct key input;
      `mob/Move()` in `Main.dm:91` already hard-blocks diagonal `dir` values regardless).
      `EquipBasicAttack()`/`EquipStartingKit()` now runs on every character
      creation/load path so slot 9 always has Attack. **Display + equip UI now both
      exist** (`StatPanels.dm`'s Battle tab, `obj/SkillLink` in
      `Code/Player/SkillLink.dm`): equipped skill per numpad slot + a "Free Skills -"
      list of known-but-unequipped skills, matching the confirmed OG layout from a
      real screenshot, and real drag-and-drop from Free Skills onto a numpad slot to
      equip (swaps out whatever was already there — the displaced skill just falls
      back to Free Skills, since `skills`/known and `skillSlots`/equipped are tracked
      separately). Confirms BYOND `stat()`-panel atoms do support drag-and-drop (the
      earlier open question here, at least on 475.1080). See `ClassReference.md`'s
      "Skills vs. equipped skills" note for the full mechanic.
- [x] **Status panel field order/content** — confirmed complete from OG testing.
      `StatPanels.dm` now matches: Name → Class → Level → Party → Hit Points → Magic
      Points → **GM Level** → **CPU** → Experience Points (with percent) → Gold →
      Players online. Specifics:
      - [x] Party: real party system now wired in (`StatPanels.dm`, see Phase 2 note)
      - [x] GM Level / CPU — 2026-08-28: added, shown to everyone rather than
        staff-only (the open question below), matching the confirmed OG field order
        and this pass's "match the OG as closely as possible" sequencing goal. Easy
        to gate behind `client.canBuild`/`canAdmin` later if that turns out wrong.
      - [x] Experience Points: OG format is `current/next (X.X%)` **with one decimal
        place** (e.g. "10882/14011 (10.3%)") — 2026-08-28: `FormatPercent()`
        (`StatPanels.dm`) added. Turns out to be a non-issue in our own system: `Exp`
        already resets to 0 on every level-up (`LevelCheck()`), so `Exp/Nexp` already
        IS progress-within-the-current-level's-band, no separate floor/threshold
        tracking needed — the OG's own raw-ratio mismatch this section spent two
        findings puzzling over doesn't apply to our curve.
        **2026-08-10 real finding, live-confirmed with a second data point:** the shown
        percentage is **not** `current/next` as a raw ratio. Hero1 at Level 5 showed
        `389/637 (13.3%)` — 389/637 is actually 61.1%, nowhere near the displayed 13.3%.
        Same mismatch pattern as the original 10882/14011 (10.3%) reference example
        above (10882/14011 = 77.7% raw, not 10.3%), so this isn't a one-off glitch, it's
        consistently how the OG computes the percentage. Working theory: it's progress
        *within the current level's band* — `(currentExp - thisLevelFloor) /
        (nextThreshold - thisLevelFloor)`, not progress against the raw total — but
        this level's floor value isn't known yet for either sample, so the theory is
        unconfirmed. Also separately noted: the percentage appears to visually update
        on a short delay relative to the exp number itself (UI-refresh quirk, not a
        data problem). Needs the floor/threshold value at the moment each sample was
        taken to actually solve the formula — capture "exp at the exact moment this
        level was reached" going forward, not just current exp mid-level.
- [x] Players-online count in Status panel — already present (`stat("Players online:
      [length(players)]")`, `StatPanels.dm`); this checkbox was just stale.
- [x] **Map-overlay HUD** (Level/HP/XP/MP along the bottom of the game view) —
      2026-08-28: `Code/UI/HUD.dm` (new file). Bottom-left bars (`meter.dmi`/
      `magicmeter.dmi`/`expmeter.dmi`, 13-step fill) plus bitmap-text labels/numbers
      built from `text.dmi`, lazily built and refreshed every `Stat()` tick. Every
      pixel offset/glyph width is a placeholder — compiles and runs, not pixel-tuned
      (Claude can't drive the actual client to check alignment).
- [x] **HP/MP meters floating above each player/mob** — 2026-08-28 (`Code/UI/HUD.dm`):
      world-space `/image` overlays added directly to the mob (so they move with it
      for free), works for any mob — players AND enemies. Rebuilt fresh each update
      rather than mutating in place, avoiding the exact overlay-snapshot bug already
      found and fixed once for the Blaze cast meter. Refreshed on every HP/MP-changing
      event: damage, heal, poison tick, hazard tick, regen tick.
- [x] **Floating combat numbers** — 2026-08-28 (`Code/UI/HUD.dm`'s `ShowCombatNumber()`,
      `numbers.dmi`'s digit + "m"/"i"/"s" glyphs). Red damage, yellow crit (`RollCrit()`
      already exists — the crit-mechanic blocker this entry originally noted is closed,
      see Phase 6), green heal, "miss" on a dodge. Wired into `TakeDamage()`/
      `ApplyHeal()`/poison/hazard ticks. Font glyph width and animation timing are
      placeholders.

## Phase 4 — Actions & Social Panels

- [x] Emote, Say, Tell, Who, WorldEmote, WorldSay (`SocialVerbs.dm`) — message formatting
      now matches the OG exactly: brackets wrap the full `Name verb:` (not just the name
      — an earlier deliberate divergence, now reverted per your request), WorldEmote adds
      "to the world", WorldSay uses a distinct "wsays:" label instead of reusing "says:",
      Who's field labels are bolded. Self-tell (`Tell` targeting yourself) stays removed
      — that was an intentional divergence from the OG you'd already made, not reverted.
- [x] Interact (context-sensitive: doors, items, signs) (`PlayerVerbs.dm`)
- [x] Right-click `Drop()` with `category = "Action"` (`Inventory.dm`) — **confirmed
      correct pattern**: OG's Actions tab only shows Drop/Give when a droppable/giveable
      item is actually in inventory, exactly matching how `set src in usr` scoping works
- [x] `CreateParty()` — implemented in `PartyVerbs.dm`. Text-input prompt for the
      party name, prints "[name] has been successfully created.", switches the
      creator into the new Party tab (see Phase 2 for the full data model).
- [x] `Give()` — implemented in `Inventory.dm`, same pattern as `Drop()` (item-level verb,
      `category = "Action"`, `src in usr`). Target picker uses `mob/player in view(5, usr)`
      to restrict to nearby players; reuses `PickUpItem()` so the "inventory full" check
      is shared with pickup/GM item creation.
- [ ] `Help()` — **placeholder built (2026-07-31)**: `browse()` popup with a title bar/
      close button (`PlayerVerbs.dm`, hidden verb, wired to File > Help,
      `Interface.dmf`), matching the confirmed OG presentation. Currently just says
      "Help content coming soon." — the actual content still needs to be written fresh,
      even the OG's own doc admits it's outdated
- [x] `Look()` — implemented in `PlayerVerbs.dm`, like `Who()` but iterates `view(src)`
      instead of the global `players` list. Same hardcoded Class/Level/Party stub as
      `Who()` until real data exists (see Phase 2's party model / class tracking).
- [x] `TurnWalk()` toggle — implemented: `turnWalkMode` var (`SmoothMovement.dm`) +
      verb (`PlayerVerbs.dm`). Took three attempts to get the feel right:
      1. Checking the toggle inside `Step()` — `MoveLoop()` calls `Step()` many times a
         second while a key's held, so it turned and moved again within the same
         imperceptible instant, looked like the toggle did nothing.
      2. Moving the decision into `onMoveKey()` but gating `move_dir` behind a second
         press — technically worked but required an actual release-and-press-again,
         not the intended feel.
      3. Snapping `dir` and setting `move_dir` together in the same press — same
         imperceptible-gap problem as attempt 1, just via a different path.
      **Final behavior**: `onMoveKey()` snaps `mob.dir` immediately on press (if not
      already facing that direction), then `spawn(2)` (0.2s) before setting `move_dir` —
      an actual deliberate pause so the turn is visible before walking starts. Guarded
      by a `turnSession` counter (same pattern as the door auto-close timer in
      `Obj.dm`) so a stale delayed move can't fire after the key's released or a
      different direction gets pressed during that window. **One follow-up bug**: the
      key-release branch originally only bumped `turnSession` when `move_dir` already
      equalled the released direction — but during the `spawn(2)` pause, `move_dir` is
      still 0, so a quick tap-and-release (faster than the pause) never cancelled the
      pending timer, and the character started walking on its own once it fired. Fixed
      by always bumping `turnSession` on release regardless of `move_dir`'s current
      value. **Second follow-up bug** (the intermittent "works half the time" one):
      redirecting while ALREADY moving updated `mob.dir` immediately but left the old
      `move_dir` untouched, so the character kept sliding the old direction while
      visually facing the new one for the whole pause — inconsistent-looking because it
      depended on whether you were already moving when you pressed. Fixed by clearing
      `move_dir` immediately whenever a turn starts. **Third follow-up bug**: clearing
      `move_dir` stopped the *logical* movement, but never cancelled the in-progress
      **glide animation** — `Move()` always calls `walk(mob, 0)` before a normal step for
      exactly this reason, but the turn branch bypassed `Move()` entirely, so `mob.dir`
      could change mid-glide while the sprite was still visually sliding in the old
      direction. Fixed by adding the same `walk(mob, 0)` call before turning.
      **Fourth follow-up bug** (the real one — "works half the time"): the original
      `turnSession` was a single global counter bumped by *any* key event. Releasing an
      unrelated key (e.g. letting go of the direction you were previously walking, while
      a different direction's turn was still pending) cancelled that unrelated pending
      turn too — leaving the still-held new direction stuck doing nothing, since these
      macros only fire once per physical press, not repeatedly. Fixed by tracking the
      pause per-direction instead (`pendingDir`/`pendingSession`): only releasing *that
      specific* direction's key, or pressing yet another new direction, cancels it.
      Confirmed working (~95%) after this fix. Tried reducing an unnecessary
      `walk(mob, 0)` call (only cancel the glide if `mob.next_step` shows a step is
      actually still in flight) — partial improvement at best.
      **Known minor cosmetic quirk, not worth chasing further right now**: turns
      occasionally "snap" visually if you change direction before the previous step's
      glide animation finishes catching up — `walk(mob, 0)` cuts the
      glide short rather than letting it finish, though the logical position was always
      correct. Candidate for the later visual-polish pass, not a functional bug. Tune the
      `spawn(2)` value if the pause feels too slow/fast — it's in tenths of a second.
      **Bigger open question, not solved here**: `MoveLoop()` is a custom hand-rolled
      polling loop (re-calling `Move()` every tick while a key's held) because the
      movement macros deliberately skip BYOND's native `+REP` key-repeat. The OG likely
      predates this project's custom skin work and may just rely on BYOND's own native
      key-repeat + default movement handling instead — which could explain why its
      turn-walk feels smoother without any of the snap tradeoffs above. Worth
      reconsidering whether `MoveLoop()` should exist at all during a real movement-
      system pass, rather than continuing to patch around it — but that's a bigger
      change than fits here.
- [x] `ToggleWorldSay()` — already built (`worldChatEnabled`, `SocialVerbs.dm`), this
      checkbox was just stale.
- [ ] `ToggleMusic()` — new discovery, not in the original design notes at all. Likely a
      simple on/off for area background music, behavior not yet detailed. Largely
      overlaps with `SetMusicVolume(0)` (the volume-control feature below), which
      already gives a full mute — worth deciding if a separate toggle earns its keep
      before building it.
- [x] **Volume control — Master/Music/SFX, three separate sliders** (your own idea,
      2026-07-31, built same day; reworked 2026-08-01). Supersedes the flatter
      `MusicVolume()` idea above. `client/masterVolume`/`musicVolume`/`sfxVolume`
      (0-100 each, `Main.dm`) — persisted per-ckey in the player's own savefile
      (`SaveManager.LoadVolumeSettings()`/`SaveVolumeSettings()`, `SaveSystem.dm`), not
      global. `client/proc/ScaledVolume(base = 100, isMusic)` treats Master as the
      actual base loudness and Music/SFX as multipliers layered on top of it: `round(base
      * channelPct/100 * masterPct/100)`. Defaults are Master 50 / Music 100 / SFX 100 —
      Master alone keeps login from being a blast, and Music/SFX at 100 mean "full,
      relative to whatever Master is." The old standalone `baseVolume` global (a flat
      pre-attenuation hack, separate from all this) is gone — Master now does that job.
      `base` is still a per-call-site param for a specific clip's own mix level (e.g.
      attack/spell pass 60/70 to sit louder than most SFX), independent of the sliders.
      - **Music** (`isMusic = TRUE`) — `PlayAreaMusic()` (`Area.dm`) and the login
        jingle (`Main.dm`), both on `channel = 1`
      - **Sound Effects** (`isMusic = FALSE`, the default) — everything else: attack/
        hit/dodge/spell (`SFX_CHANNEL`), door/stairs/fall, and `levelup.wav`
        (`channel = 2`, still counted as SFX)
      - **Master** — scales both together, layered on top of whichever channel slider
        applies
      Two call shapes needed different handling: single-recipient sounds (`M << sound
      (...)`, e.g. stairs/fall/login music) call `client.ScaledVolume()` directly; the
      several `view(x) << sound(...)` broadcasts (dodge/hit/attack/spell/GM ghost-form)
      couldn't — a single broadcast can only carry one shared volume for every listener,
      which would ignore each player's own sliders. Global `proc/PlaySFXAt(atom/center,
      filename, channel = SFX_CHANNEL, base = 100)` (`Main.dm`) replaces those: loops
      `view(center)` and sends each client-having mob its own personalized volume.
      `SetMasterVolume()`/`SetMusicVolume()`/`SetSFXVolume()` (`PlayerVerbs.dm`,
      "Settings" category) are bare `input()` 0-100 prompts, clamped, saving to disk on
      each change — matches the v1 "no UI polish" rule already in place for everything
      else. `SetMusicVolume()` re-applies the currently-playing track immediately (via
      `current_music`, `Area.dm`) so the change is audible without needing to walk into a
      new area. Loaded on `client/New()`, right after `saveManager` is created and before
      the login jingle plays. Compile: 0 errors, 0 warnings. Not playtested yet.
- [x] Wire real class/level/party into `Who()`/`Look()` (`SocialVerbs.dm`, `PlayerVerbs.dm`)

## Phase 5 — Inventory & Items (core loop mostly done)

- [x] Pickup via Interact, right-click Drop, key/lock system (`Inventory.dm`, `Obj.dm`)
- [x] Fixed capacity placeholder (`BASE_INVENTORY_SLOTS = 8`)
- [x] Real capacity formula — already built (`BASE_INVENTORY_CAPACITY + round(Strength /
      STR_PER_CAPACITY)`, `Inventory.dm`, the mechanics-first pass's Stage 6), landing on
      capacity 9 at a fresh level-1 Hero's starting Strength as intended. Coefficients
      still placeholder, this checkbox was just stale.
- [x] "Quick Item" slot — already built (0.8.0 pass: numpad `*` cycles, `-` uses;
      `StatPanels.dm`'s "Quick Item:" line), this checkbox was just stale.
- [x] Item stacking — 2026-08-28: `obj/item/maxStack`/`amount` (`Inventory.dm`),
      consumables stack to 99 (placeholder cap); `PickUpItem()` merges into an existing
      stack before consuming a new slot. Keys/amulets stay non-stacking (maxStack = 1
      default) since each carries meaningful per-instance state.
- [x] Equipment system — **confirmed the OG has no weapon/armor equipment at all, only
      amulets** (stat boosts + some unspecified additional effects you don't remember —
      worth digging up if you run across them again). "Equip slots (weapon/armor/
      accessory)" was our own generic-RPG assumption, not something to port from the OG.
      **The committed v1 scope — "build basic equip slots (stat bonuses only)"
      (2026-08-04 decision, below) — is done**: 23 real amulets exist (`Inventory.dm`),
      max 2 worn, real effective-stat plumbing so equipment never mutates the
      underlying stat. `GMmakeitem` surfaced a partial item roster worth a dedicated
      reference doc eventually (same pattern as `ClassReference.md`/
      `GMCommandsReference.md`): key, paper, gems (red/green/blue/ring/drop/crown),
      amulets (strength/power/agility/speed), and more below the visible scroll — see
      `GMCommandsReference.md`'s `GMmakeitem` entry.
      **Your own expansion idea for the remake, not OG-derived, still open**: add real weapons and
      armor as equipment (the OG never had them), and tie certain skills to owning/
      equipping a specific weapon — e.g. the "Ice Saber" skill would require actually
      having an Ice Saber weapon, possibly equipped, before it's usable. Could extend to
      weapon-general move sets, and unique/rare weapons as lootable rewards with their
      own exclusive skills. Parallel idea for casters: **spells could require purchasing
      a tome** before they're usable, same gating concept as weapon-locked skills but for
      Wizard/magic-focused classes instead of physical ones. This is a bigger design
      decision than the rest of Phase 5 — worth its own pass once basic equip slots exist
      at all. **Weapon/tome gating specifically deferred (2026-08-04 decision)**: build
      basic equip slots (stat bonuses only) now, skip the gating mechanic for this pass.
- [x] "Give" right-click option — already built (`obj/item/verb/Give()`,
      `Inventory.dm`, see Phase 4), this checkbox was just stale.
- [x] Chest/drawer/pot storage interactions — already built (0.8.0 pass, Store/Take/
      Leave via `obj/storage`, `Obj.dm`), this checkbox was just stale.

## Phase 6 — Combat System

- [x] **Attack/spell delay — deliberately diverged from the OG's straight-Agility
      design.** `GetAttackDelay()` (`CombatSystem.dm`) now uses dual-stat combos instead
      of a single stat each, specifically so physical-vs-magic speed emerges from how a
      player allocates points rather than a class flag (Hero/Pilgrim can freely go
      physical, magic, or hybrid, with real freedom in *which* secondary stat gets them
      there — see below): melee delay uses `sqrt(Agility * max(Vitality, Intelligence))`
      (a geometric mean — Agility alone isn't enough, you need a real secondary stat
      too, but that secondary stat can be *either* Vitality (a Fighter's path) *or*
      Intelligence (a Wizard's path), not forced into Vitality specifically — so a
      Wizard leaning Intelligence still has a legitimate, if different, route to a
      competent physical attack instead of being locked out of it); spell delay uses
      `Intelligence + (Agility * Intelligence / 40)` (Intelligence alone already gets a
      caster reasonably fast, and Agility's bonus scales up only once paired with real
      Intelligence, rather than helping flatly on its own). Both are placeholder
      constants, same as the rest of Phase 6 — tune by feel.
- [x] Damage calc, `TakeDamage`/`Die`/melee hit/attack delay (`CombatSystem.dm`) —
      current formula is a placeholder (`damage = Strength`, flat, no defense/
      randomness). **Decision**: don't reverse-engineer the OG DWL's exact formula (too
      hard without source access, and it was tuned for turn-based combat, not our
      real-time system anyway) — instead base it on the classic Dragon Warrior 1 formula
      as a starting point: `damage = random(attack/2, attack) - defense`, roughly
      `attack ≈ Strength (+weapon)`, `defense ≈ Agility/2 (+armor)`. Tune by feel once
      enemies exist to fight.
      **Real sample data point** (level 13, Str 14/Agi 9/Vit 11/Int 9/Luck 9): outgoing
      normal hits ~23-26 damage, crit ~42; incoming from the enemy fought ranged
      miss-to-3 damage. Note the outgoing number is way higher than raw Strength (14)
      would produce under the plain DW1 formula above — confirms the OG's real formula
      involves more than just Strength alone (weapon bonus, level scaling, or a
      skill-specific multiplier on the "Attack" ability), consistent with the decision
      not to chase it exactly — the "crit ~42" part of that same data point also means
      **no crit mechanic exists in the remake's code at all yet**: that number is from
      the OG, not something `TakeDamage()`/`PerformMeleeHit()` currently calculates.
      Needed before "metal monster" archetypes (see `SpellRequirementDataSheet.md`'s
      Special Monster Archetypes table, 2026-08-10 finding: very low HP, high dodge,
      heavy flat damage reduction, but a crit bypasses both dodge and reduction —
      probably a one-shot) are buildable, along with a per-monster dodge-rate/
      damage-reduction override (`RollDodge()` is flat Agility-based for every mob
      right now, no per-species knob).
      **2026-08-10 addition — crits confirmed on the incoming side too, not just
      outgoing:** a cat fight logged 18 monster attacks against Hero1: 2 crits (~11.1%
      crit rate), 16 normal, 0 misses (`CombatDataSheet.md`). The original "crit ~42"
      sample above was the player critting an enemy; this is a monster critting the
      player, so crit isn't a one-sided player-only mechanic in the OG — reinforces
      that a real crit system (still nonexistent in `TakeDamage()`/`PerformMeleeHit()`)
      needs to apply uniformly to both attacker directions, not be bolted on as a
      player-only bonus. ~11% is a single small sample, not a rate to lock in yet.
      The sample data point itself is still just a
      rough feel/scale reference for tuning our own numbers, not a value to match
      exactly.
      **2026-08-22 revision — supersedes the "don't chase OG's formula" decision
      above.** Two new sources changed the plan: (1) the plain Dragon Warrior 1 (NES)
      formula pulled from a public disassembly on GitHub —
      `damage = (ATK/2) - (DEF/4) + random(0,4)`, floored at 0, same shape for both
      attack directions (`ATK`/`DEF` swap sides) — and (2) a clean re-read of OG DWL's
      own in-game Help section (`ClassReference.md`'s Stat effects list, originally
      recovered 2026-08-09). The Help section wins on **what each stat does** every
      time it conflicts with the NES formula, since it's the actual target game's own
      documentation, not just same-genre inspiration — the NES formula only supplies
      the **shape** (a subtractive ATK-vs-DEF term plus small random variance, a real
      crit mechanic) where DWL's own exact coefficients aren't recoverable. Confirmed
      conflict: the NES formula computes crit off `PlayerAGI/64`, but the Help section
      says crit rate is a Spirit effect, not Agility — going with Spirit, per OG's own
      docs. Synthesized model to build against once compiling resumes:
      - **Physical defense** = blend of Agility + Vitality (both confirmed contributors
        per the Help section; exact weighting between them unconfirmed — start at an
        even split, tune from data)
      - **Magic defense** = blend of Vitality + Intelligence (same caveat)
      - **Crit chance** = Spirit-driven, coefficient unknown (Spirit isn't a real DW
        stat, so no NES-equivalent number exists — has to come from OG playtesting,
        e.g. the ~11% incoming crit sample above, once more samples exist at known
        Spirit values)
      - **Crit damage multiplier** — NES uses a flat 2x; the one real OG sample (crit
        ~42 vs normal ~23-26, same Level-13 fight above) reads closer to ~1.6-1.8x, but
        that could include a weapon/skill bonus riding along — not a clean multiplier
        yet, needs isolating
      Not implemented in `CombatSystem.dm` yet — `ApplySpellDamage()` in particular has
      zero magic-defense mitigation coded (elemental weak/resist only), and no
      Agility+Vitality physical-defense blend exists anywhere. This entry stays open
      until that gets built.
      **2026-08-23 addition — real `.dmb` string-table extraction supports the
      composite model and names real targets for the next disassembly pass.** Same
      source as the Spirit/Luck finding above (Somnium13 `somdump` against the actual
      OG DWL host files). Searched all 4450 recovered strings for any dedicated
      "Defense"/"def"-style stat variable — **none exists**, which is real evidence
      for the Agility+Vitality composite model above rather than a single missing
      stat. Also surfaced real local variable names that almost certainly belong to
      the actual attack/damage procs: `atk` (sitting directly next to
      `/skill/attack/use`), plus `tmp_damage`, `hitstate`, `showhitstate`, `blockable`,
      `chance`, and `delay` clustered together near `/mob/proc/TakeDamage`. These are
      the names worth asking the collaborator to prioritize once they move to the next
      stage (`sompipe.js`, turning bytecode into pseudo-assembly) — that's where the
      real ATK/DEF divisors and crit coefficient would actually show up as numbers.
      One false lead ruled out: `getblock`/`blocker` looked like a mitigation proc at
      a glance, but is grouped with `getring`/`getcircle`/`px`/`py`/`line` in the
      string table — a map/geometry helper, unrelated to combat.
- [x] **HP/MP regeneration** — built in the 0.8.0 pass (`RegenLoop()`,
      `StatsDatum.dm`, `GetHPRegen()`/`GetMPRegen()` driven by Vitality/Intelligence
      per the Help section). Real mechanic confirmed via the 2026-08-23 string-table
      extraction (`HPfactor`/`MPfactor`/`HPregen`/`cur_HPregen`/`MPregen`/
      `cur_MPregen` all real tracked vars in the OG) — this checkbox was just stale.
      Coefficients are still placeholder.
- [x] Dodge mechanic (`CombatSystem.dm`'s `RollDodge()`, called from `TakeDamage()`) —
      new, not OG-derived (no such mechanic existed anywhere before). Agility-based
      chance to avoid a hit entirely, capped at `DODGE_MAX_PERCENT` (30%) so it's never
      guaranteed even at high Agility — all placeholder constants, tune by feel.
      **2026-08-10 OG finding, relevant even though dodge itself is invented:** OG
      monsters do miss, but not consistently — dog landed every hit in one full fight
      (0 misses), then a slime missed 1 of 14 attacks (~7.1%) in the fight that killed
      Hero1 (`CombatDataSheet.md`). Both at the same Agility (4), so ~7% (or lower,
      still a small sample) looks like a reasonable ballpark for Tier 1 monster miss
      rate at low player Agility. Since the remake's dodge chance is invented wholesale
      (no OG mechanic to directly match, this is the target being avoided not
      matched — dodge is the PLAYER avoiding monster hits, this data is the reverse),
      use this as a rough ceiling: don't let monster-side hit consistency in the remake
      feel wildly more miss-prone than ~7% at low Agility. Still needs more
      fights/monsters logged before treating 7.1% as more than a single data point.
      Also
      split several combat sounds between players and enemies, since they turned out
      to need different files: `hit.wav`/`enemyhit.wav`, `attack.wav`/`enemyattack.wav`,
      `dodge.wav`/`enemydodge.wav` (`istype(mob, /mob/enemy)` picks which). Along the
      way, fixed `attack.wav`/`spell.wav` (`PlayAttackAnimation()`) silently never
      playing for enemies at all — they used `user << sound(...)`, which only reaches
      the attacker's own client, and enemies don't have one; switched to
      `view(user) << sound(...)`. **Second, separate bug** in `TakeDamage()` itself:
      its `hit.wav`/`dodge.wav` lines used bare `view()`, not `view(src)` — bare
      `view()` centers on `usr`, and `usr` is unreliable outside code paths triggered
      directly by a verb. `TakeDamage()` runs from both kinds: a player attacking (verb
      path, `usr` happens to be nearby so it mostly worked) and an enemy's `AILoop()`
      calling `PerformMeleeHit()` (a background proc, no real `usr` at all) — so a
      player taking a hit *from an enemy* specifically never got the sound. Made every
      `view()` in `TakeDamage()` explicit (`view(src)`), matching the `output()` calls
      right next to them, which were already doing this correctly. **Third bug**,
      found via live testing: attack/hit/dodge sounds were cutting off area background
      music entirely. `PlayAreaMusic()` (`Area.dm`) loops music on `channel = 1`; only
      `hit.wav` explicitly used that same channel (now obviously wrong), but it turned
      out **leaving the channel unspecified isn't safe either** — `attack.wav`/
      `dodge.wav` had no explicit channel at all and were *also* killing the music.
      Added a dedicated `SFX_CHANNEL` (3, defined in the `.dme` itself for the same
      #include-order reason as `SPRITE_PIXEL_Y_OFFSET`) and put every one-shot
      combat/event sound on it explicitly: `attack`/`enemyattack`/`hit`/`enemyhit`/
      `dodge`/`enemydodge`/`spell.wav` (`CombatSystem.dm`), `stairs.wav`/`fall.wav`
      (`Turfs.dm`), `door.wav` (`Obj.dm`), and `GM_GhostForm`'s `spell.WAV`
      (`GMCommands.dm`). `levelup.wav` already had its own channel (2), so it was
      never part of this bug and was left alone.
- [x] Skill datum base + 2 skills (Attack, Fireball) (`SkillDatum.dm`) — **both are
      placeholder stubs, not the real spell system** (see the real spell design
      below). Fireball specifically isn't equipped to any class by default yet, so
      nothing in-game can currently cast it either way.
- [ ] **Minor visual bug, found during an end-of-night code review, not yet tested**:
      Fireball's spell overlay (`PlayAttackAnimation()`, `CombatSystem.dm`) still uses
      a plain `/icon` added to `target.overlays`, unlike the melee weapon overlay right
      above it, which was switched to an `/image` with an explicit `.layer` earlier
      tonight specifically so it renders on top of the mob being hit instead of behind
      it. `/icon` has no `.layer` property, so the spell overlay likely has the same
      "renders behind the target" bug the melee one had before that fix — just
      unconfirmed, since no enemy casts spells yet and it hasn't come up in player
      testing. Give it the same `/image` treatment once it does — though this whole
      concern may be moot once the real projectile spell system below replaces the
      current instant-hit placeholder entirely.
- [x] **Real spell system — built.** `datum/skill/Fireball` stays as the old
      placeholder (instant-hit, melee-range only, never equipped to any class by
      default) — `datum/skill/Blaze` (`SkillDatum.dm`) is the first spell actually
      built against the real projectile system:
      1. **On use**: checks MP against `mana_cost` (5, low placeholder), fails with a
         message if insufficient, otherwise deducts it and proceeds.
      2. `spell.wav` plays (`SFX_CHANNEL`, same as everything else combat-related).
      3. Movement locks for the whole cast (`canAct = FALSE`, same gate as everything
         else).
      4. A **cast meter** overlay (`castmeter.dmi`, icon_states `"1"`-`"10"`) animates
         on the caster via a `for` loop with `sleep()` between frames — the projectile
         never launches before all 10 finish.
      5. Both the cast-meter frame delay AND the projectile's own travel speed
         (`stepDelay`) reuse the same `GetAttackDelay()` Agility+Intelligence formula
         (`CombatSystem.dm`), scaled by a made-up `/5` divisor — no reference point
         for how this should feel yet, so treat this scaling factor as the first
         thing to retune once you've actually watched it fly.
      6. **Facing locks the instant the cast starts** — captured into a local
         `castDir` before the windup, not re-read at launch, since turning itself
         isn't blocked by `canAct` (only stepping is). Confirmed default; may change
         to let the caster keep redirecting aim during the windup later.
      7. The projectile is a new `/obj/projectile` base type (`Code/Combat/
         Projectiles.dm`, added to the `.dme`), with `/obj/projectile/blaze` as
         Blaze's specific instance (`icon_state = "blaze"`, impact icon_state
         `"blazehit"`, both in `spells.dmi`). `Launch()` steps it forward one tile at
         a time (`stepDelay` between steps) until: it finds a mob on the opposing
         side from its caster (`FindTarget()` — player-fired hits enemies, enemy-
         fired hits players, same-side mobs are skipped entirely so it passes
         harmlessly through friendlies, matching the confirmed coop-by-default rule),
         it hits a dense turf, or `get_step()` returns null (fell off the edge of the
         map) — the last case just deletes it silently, no impact effect.
      8. On impact (mob or wall), `Impact()` shows the `"blazehit"` overlay at the
         point of impact, then — for a mob hit — calls the CASTER's own
         `ApplySpellDamage()` (`CombatSystem.dm`), which already runs the full
         existing pipeline for free: the elemental weakness/resistance modifier
         (Blaze sets `element = "fire"`), `RollDodge()`, `TakeDamage()`'s hit sound
         split, and death/`Die()` handling. No new damage-application code needed —
         this reuses everything already built.
      9. **Piercing is per-skill, via `/obj/projectile`'s `pierces` var** (`FALSE` by
         default) — Blaze leaves it `FALSE` (stops on first hit). **Correction,
         2026-08-10 live OG test:** Thornwhip was assumed to be the go-to
         `pierces = TRUE` example here, but live testing shows it does NOT pierce —
         it's a 3-tile line in the caster's facing direction that stops on the first
         enemy hit, same as Blaze's default. No confirmed piercing skill exists yet;
         don't build Thornwhip as the `pierces = TRUE` reference case. See
         `SkillCatalog.dm`'s `Thornwhip` entry for the full finding.
      10. **Cast interruption**: not implemented — taking damage mid-cast doesn't
          cancel the spell. `if(user.isDead) return` after the windup at least stops
          a dead caster from launching a projectile or stomping `Die()`'s own
          `canAct` lock (same class of bug found and fixed in Attack/Fireball's
          recovery callbacks earlier), but there's no broader interruption system.
      11. **Defend interaction**: Blaze uses the exact same auto-drop/resume dance as
          Attack (`wasDefending`/`defendToggleSession`) — relevant because Hero can
          have both Defend and Blaze equipped, unlike Wizard/Fireball. Fireball
          doesn't get this (no class currently has both it and Defend).
      12. **Starting kits wired up** (`EquipBasicBlaze()`, `PlayerTemplate.dm`, called
          alongside `EquipBasicAttack()`/`EquipBasicDefend()` from both character
          creation and load): Hero gets Attack/Defend/Blaze (Numpad 9/7/3). Wizard
          gets Attack/Blaze (Numpad 9/3) — **IceSpear is not built**, just a
          confirmed name for later; Wizard doesn't have a third skill yet.
      **Still open**: IceSpear itself (no code at all yet, just the name and that
      Wizard gets it by default), whether cast interruption ever gets added, whether
      facing-lock-at-cast-start changes to allow redirecting during the windup, and
      retuning the remaining placeholder numbers (mana cost, damage) once this has
      actually been played with.
      **First playtest found 4 bugs — all four now have fixes written. Compile
      verified clean (0 errors/warnings, BYOND 516.1685) and castmeter.dmi confirmed
      to contain icon_states "1"-"10" (it's an old-format binary DMI, not a PNG —
      which is why the earlier zlib/PNG-chunk read failed; strings dumped directly
      from the binary instead). Still needs an actual in-game playtest to confirm
      the fixes behave:**
      1. **Projectile too slow — fixed.** Confirmed with real numbers: a player moves
         one tile per 1.36 deciseconds (~7.4 tiles/sec, `step_delay` in
         `SmoothMovement.dm`) while the projectile was running ~3 deciseconds/tile
         (~3.3 tiles/sec) — less than half player speed, hence outrunnable. Root cause
         was that the cast windup and the projectile flight shared ONE derived number.
         Split into separate constants (`CAST_METER_SPEED_DIVISOR` vs
         `PROJECTILE_SPEED_DIVISOR`/`PROJECTILE_MIN_STEP_DELAY`), putting flight at
         roughly 2-4x player speed. Also dropped the `round()` that was forcing whole
         deciseconds, since `sleep()` handles fractions fine.
      2. **Cast meter invisible — fixed, and the cause was NOT the layer guess.** The
         real problem: BYOND's `overlays` list stores an immutable *snapshot* of an
         appearance at the moment you add it. The old code added one image (with no
         icon_state set at all, so it rendered nothing) and then mutated
         `meter.icon_state` in the animation loop — updating an object the overlay list
         no longer had any connection to. Now builds a fresh image per frame and
         removes the previous one, never mutating an image after it's been added (which
         also matters for removal: `overlays -=` matches on appearance, so a mutated
         image can fail to match and silently strand itself). An explicit `.layer` was
         added too, since that guess was cheap insurance regardless.
         **Resolved**: `castmeter.dmi` confirmed to contain icon_states `"1"`-`"10"`
         (see the note above — old-format binary DMI, states read straight from the
         file's strings).
      3. **Lingering `"blazehit"` overlay — fixed.** The earlier "code looks correct on
         inspection" read was wrong; there IS a real ownership bug. The cleanup ran in
         a `spawn(3)` block inside `Impact()`, whose `src` is the projectile — and
         `Launch()` calls `del src` immediately after impact, which kills that object's
         pending spawned blocks before they can fire. Moved the whole effect into a
         free-standing `FlashTurfEffect()` proc (`Projectiles.dm`), which has no `src`
         to delete, so its cleanup always runs. This also explains why it was seen on
         wall hits — mob hits had the identical bug, just less noticeable.
      4. **Adjacent-target passthrough — fixed** as described: `Launch()` now checks the
         tile it's standing on at the top of each iteration (catching a target on the
         spawn tile, i.e. directly adjacent to the caster) before looking ahead to the
         next tile. Point-blank-into-a-wall is handled too, and a same-tile safety
         guard prevents a stuck projectile from looping forever as an undeletable
         object if `travelDir` were ever invalid.
      **Playtest #2 found a 5th bug — fixed**: Blaze flew straight through closed doors
      and signs. `Launch()`'s obstacle check only ever looked at `turf.density` — but
      doors/signs are dense **objs** sitting on a non-dense floor turf (`Obj.dm`), never
      dense turfs themselves, so they were invisible to that check. Doors also toggle
      `density` at runtime (open/close), so a static check wouldn't have been safe
      anyway. New `IsTileBlocked(turf/T)` helper (`Projectiles.dm`) checks the turf
      itself AND scans for any dense obj on it, used at both the point-blank and
      look-ahead check sites.
- [x] **Status effect framework — built** (`Code/Combat/StatusEffects.dm`), with
      **Poison** as the first effect. Built as a small real system rather than a
      one-off, since there are already two effects planned (Poison, Sleep) and more
      expected. `datum/status_effect` base handles duration, tick interval, and
      expiry; each effect overrides `OnApply()`/`OnTick()`/`OnExpire()` and runs its
      own polling loop (same shape as `AILoop()`/`SleepRestoreLoop()` elsewhere).
      Mob-side interface: `ApplyStatusEffect()`, `RemoveStatusEffect()`,
      `HasStatusEffect()`, `GetStatusEffect()`, `ClearStatusEffects()`. Re-applying an
      active effect **refreshes its duration rather than stacking** a second copy.
      Cleared on both death (`Die()`) and respawn (`Interact()`) so nothing survives
      either. Active effects show on the Status tab (`StatPanels.dm`) only when
      present.
      **Poison specifics** (all placeholder numbers): 2% of MaxHP per tick, every 2
      seconds, for 30 seconds (~30% total). Percent of **MaxHP, not current HP** —
      percent-of-current shrinks every tick and asymptotically does nothing, which
      makes poison feel pointless. Damage is applied directly rather than through
      `TakeDamage()` on purpose: that would roll `RollDodge()`, and you shouldn't be
      able to dodge poison already in you. The hit flick **and**
      `hit.wav`/`enemyhit.wav` **are** played every tick though (confirmed wanted),
      just triggered explicitly rather than as a side effect of `TakeDamage()`. Death
      handling likewise mirrors `TakeDamage()` so nothing is skipped by going around
      it.
      **Decision worth revisiting**: `POISON_CAN_KILL` is `FALSE` — poison floors at 1
      HP instead of killing, matching classic Dragon Warrior and avoiding death by a
      ticking number you can't respond to. The lethal path is already wired if you flip
      it. **Nothing inflicts poison yet** — no monster attack, trap, or spell applies
      it; `Test_PoisonSelf()` (`DebugTools.dm`) is currently the only trigger.
      **Still open**: stacking rules beyond refresh-don't-stack (intensity tiers?),
      and any cure item/spell (nothing can remove an effect early right now except
      code calling `RemoveStatusEffect()` directly).
- [x] **Sleep** as a status effect — built (`datum/status_effect/sleep`/`sleep/more`,
      `StatusEffects.dm`; the `Sleep` skill, `SkillCatalog.dm`, gated to Hero/Pilgrim/
      Wizard per this doc). Shipped shape diverges from the spec below in one way,
      deliberately: it **does** wake on hit ("classic Dragon Warrior behavior," per
      the code's own comment) rather than the "does not wake immediately" behavior
      envisioned when this entry was written — a later, intentional revision, not an
      oversight. The healing-while-asleep tie-in this spec also describes (sleep as a
      variant of Rest's regen) was never actually built — the shipped version is a
      plain `canAct` lock for a duration, no bonus regen — so the "is Sleep a net
      benefit to the victim" open question below never became live. Worth a look if
      that regen tie-in is still wanted.
      **Confirmed OG scope**: Sleep is the *only* status effect in the OG — no burn,
      freeze, or shock/paralysis despite fire/ice/lightning-named spells existing
      (Fireball, Icebolt, Lightning, etc. are just damage, no elemental ailment attached).
      Sleep itself is a timed state: target is incapacitated until a duration expires.
      **Confirmed design for the Sleep spell specifically** — it's a third variant of
      the same underlying "asleep" state that beds and the planned Rest skill use, not
      a separate system:
      - Behaves *like Rest*, but the target **does not wake immediately** — unlike
        bed/Rest sleep, where any movement wakes you (`Step()` calling `WakeUp()`,
        `SmoothMovement.dm`). This is the key architectural difference: the existing
        sleep state is *voluntary* (wake-on-move), while spell-inflicted sleep is
        *forced* (timed, movement-locked via `canAct` rather than wake-on-move). Both
        the sleep state and `SleepRestoreLoop()` will need to distinguish the two.
      - Target is **susceptible to damage** while asleep (can be attacked freely).
      - Target **recovers slowly** while asleep — slower than a bed, presumably in the
        same ballpark as Rest.
      - Likely a **short initial grace period before any healing starts**, so putting
        something to sleep isn't instantly rewarding it with HP.
      **Open question worth deciding before building**: since a slept target heals,
      Sleep is a net *benefit* to the victim unless the attacker out-damages the regen
      during the window. That may be exactly the intent (Sleep as a utility/escape or
      burst-window tool rather than free damage), but it's worth confirming — the grace
      period above is presumably the main lever for tuning that balance.
- [x] Enemy AI (`EnemyNPCs.dm`): sees through walls (`range()`, not `view()`), locks
      onto the nearest player, chases, attacks once cardinally adjacent, and flees
      instead of attacking at/below `fleeHealthPercent` (10%, placeholder) of MaxHP —
      escaping successfully if it puts `sightRange` between itself and the target (the
      same leash check that also drops a target who's simply wandered too far away).
      Never targets a player in ghost form (`isGhostform`, `GMCommands.dm`) — excluded
      from acquisition, and dropped as a target if they ghost mid-fight. Only aggros
      in battle-mode areas (`InBattleArea()`); otherwise wanders
      (`Wander()`) instead of standing idle, and drops any target entirely if the area
      stops being in battle mode mid-fight. A dead enemy (`HP <= 0`) stops acting
      immediately so its corpse sits still until `CleanUpDead()`'s deletion timer
      fires. Movement is cardinal-only (matches this game's no-diagonal-movement rule —
      BYOND's built-in `step_to()` doesn't work here since it tries diagonal steps
      first) and animates with the same smooth continuous glide as players, via a
      decision/execution loop split mirroring the player's `move_dir` +
      `client/MoveLoop()` pattern; enemies also get their own (slower) `step_delay`
      instead of inheriting the player's pace. Melee adjacency uses
      `IsCardinallyAdjacent()` (`CombatSystem.dm`), not plain `get_dist()`, so enemies
      can't attack (or face) diagonally. Attacks now play the same flick/sound/weapon-
      overlay animation as a player's Attack skill (`PlayAttackAnimation()`, via a
      `datum/skill/Attack` instance kept purely for its `icon_state`/`isMelee` —
      enemies still use their own `attackCooldown`, not the skill's own timing),
      layered directly on the mob actually being hit rather than the turf in front of
      the attacker. Picked up the shared `SPRITE_PIXEL_Y_OFFSET` sprite offset
      (`Main.dm`, previously player-only) so enemy sprites line up with their own
      attack overlays too. Also never targets a player in ghost form (`isGhostform`,
      `GMCommands.dm`) — excluded from acquisition, and dropped as a target if they
      ghost mid-fight. Basic obstacle-avoidance while chasing/fleeing: if a wall blocks
      both the direct route toward the target and the secondary axis, commits to a
      perpendicular side (`avoidDir`, kept as instance state so it doesn't flip-flop
      between left/right every tick) and keeps sidestepping until the direct route
      opens up again — simple wall-hugging, not real pathfinding, so a genuine dead
      end can still trap it. See in-file comments for the full reasoning behind each of
      these (they came from real bugs found by playtesting, not speculative design).
      **Deferred** (confirmed scope for this pass): ranged/spellcasting enemies.
      Confirmed design for when spellcasters get built: every monster keeps a melee
      fallback, and casters additionally get their own personal MP pool that gates
      spellcasting once it runs out.
- [x] **Defend** (`datum/skill/Defend`, `SkillDatum.dm`) — a toggle, not a one-shot
      action: flips `icon_state` to "defend" (player holding up their shield) and sets
      `isDefending = TRUE`, which `TakeDamage()` (`CombatSystem.dm`) checks to reduce
      incoming damage by `DEFEND_DAMAGE_REDUCTION_PERCENT` (50%, placeholder — you
      weren't sure of the real number either, no OG data for it). Equipped to Numpad 7
      by default for Hero and Soldier only (confirmed kit difference, not Wizard) via
      `EquipBasicDefend()` (`PlayerTemplate.dm`), same creation/load wiring as
      `EquipBasicAttack()`. Not gated on `canAct` like Attack/Fireball are — it's a
      passive stance, not a wind-up action, so nothing stops you toggling it mid-swing.
      **Found and fixed a real bug**: holding the Numpad 7 key fires `UseSkillKey`
      repeatedly (the same OS key-repeat behavior that lets you hold-to-attack), and
      unlike Attack (whose `canAct` cooldown happens to swallow those repeats),
      nothing gated Defend the same way — every repeat flipped the toggle again,
      so holding the key looked like rapid on/off/on/off instead of one clean toggle.
      Fixed with a short `DEFEND_TOGGLE_COOLDOWN` (0.3s) debounce.
      **Attacking while defending** — decided you can (sword-and-shield is
      plausible), but not for free: `Attack.OnUse()` drops the defend stance for the
      swing+recovery window (`canAct`'s window), then auto-resumes it afterward
      *unless* the player manually toggled Defend themselves in the meantime
      (`defendToggleSession`, bumped only by a real manual toggle, guards against the
      auto-resume stomping a deliberate mid-swing toggle-off). This is the actual
      balance lever, not a separate speed/damage penalty number: attack a lot while
      defending and you spend most of your time in the dropped window (faster kills,
      less mitigation); attack rarely and you stay shielded most of the time (slower
      kills, more mitigation) — falls out of the interaction itself. On top of that,
      `GetAttackDelay()` (`CombatSystem.dm`) now also takes a `wasDefending` param and
      adds a small flat `DEFEND_ATTACK_SPEED_PENALTY` (3 deciseconds, placeholder) when
      true — attacking out of a braced stance is a little slower to throw regardless,
      not just less protected. Fireball picks this up too (`user.isDefending` directly,
      since it doesn't auto-drop/resume the stance the way Attack does — no class
      currently has both Defend and Fireball equipped anyway, and a spellcaster
      gesturing one-handed with a shield up is more plausible than swinging a sword
      through one). While fixing
      this, also found and fixed a **pre-existing, unrelated bug** in the exact same
      recovery callback (both Attack and Fireball): if a player died while an
      attack's cooldown timer was still pending, the callback unconditionally set
      `canAct = TRUE` afterward, silently undoing `Die()`'s intentional death-lock —
      a "dead" player could move again before actually respawning. Guarded both with
      an `if(user.isDead) return`.
      **"Flee" is not a player action** — this is real-time action combat, not
      turn-based, so a player just runs away using normal movement; there's no verb to
      build here. (Enemies fleeing at low HP, EnemyNPCs.dm, is a separate, already-
      built AI behavior — see Phase 6's Enemy AI entry.)
- [x] Skill/spell equip UI — already built (`obj/SkillLink`, `Code/Player/SkillLink.dm`,
      see Phase 3/7's own entries), this checkbox was just stale.
- [x] **Elemental weakness/resistance — basic scaffolding built** (expanded remake
      idea, not OG-derived — the OG's elemental spells like Fireball/Icebolt/Lightning
      are just flavored damage with no elemental interaction at all). `datum/skill`
      now has an `element` var (`SkillDatum.dm`, e.g. Fireball sets `"fire"`), and
      every mob has `elementalWeakness`/`elementalResistance` vars plus a real damage
      modifier in `ApplySpellDamage()` (`CombatSystem.dm`,
      `ELEMENTAL_WEAKNESS_BONUS_PERCENT`/`ELEMENTAL_RESISTANCE_REDUCTION_PERCENT`,
      both 50%, placeholder). **This is genuinely working code, just currently
      inert** — nothing anywhere yet actually assigns a weakness/resistance to any
      player or monster, so the modifier never triggers in practice until something
      does; same "plumbing now, behavior later" pattern as `Area.dm`'s
      `battleModeOn`/`weather` vars before `GMbattlemode` wired them up.
      **Still open, bigger design questions this scaffolding doesn't answer**:
      - Per-enemy weaknesses/strengths against specific elements (the "per enemy"
        half of this was already planned, just not populated yet)
      - **Your idea**: players could also have an elemental affinity — floated
        choosing a strong/weak element pair at character creation, not confirmed as
        final, just an idea to weigh against simplicity for v1
      - How many elements exist, whether player affinity is a creation-time choice or
        something earned/changed later, and how it interacts with the class/skill
        system — the scaffolding doesn't force any of these answers, it just needed
        somewhere for the eventual data to live.
- [ ] **OG monster AI is not melee-only — several findings from live OG testing,
      2026-08-10, none built yet.** Current remake AI (`EnemyNPCs.dm`'s `AILoop()`) is
      melee-only against a single locked `target` (always a player) — no
      ally-targeting, no spellcasting at all, no MP pool on `mob/enemy`, no
      keep-distance behavior. Confirmed-by-fresh-testing this session:
      - Healer slimes cast a heal spell on OTHER injured healer slimes, not just fight
        the player — not characterized yet (HP% trigger? proximity? does it require
        the healer itself to be safe first?).
      - Acolytes self-cast `Increase` (physical defense buff) the instant they spot the
        player — a self-buff-on-aggro pattern, distinct from the healer slime's
        ally-targeting.

      Recalled from memory (not yet re-confirmed this session, treat as a hypothesis
      to verify, same as everything else in this doc without a live-test source):
      - Caster-type monsters (magician, etc.) have a real MP pool with **no in-combat
        regen** — once drained, they fall back to physical attacks for the rest of the
        fight. Remake's `mob/enemy` currently has no MP tracking or a physical-attack
        fallback path at all.
      - Caster-type monsters with a projectile spell available prefer to keep their
        distance and cast rather than close to melee range — the opposite of
        `AILoop()`'s current behavior, which always chases straight to
        `attackRange`/1 regardless of what the monster can cast.

      - Some species feel noticeably more "hyperactive and aggressive" than others —
        general impression from testing, not yet pinned to a specific cause (reaction
        speed? aggro range? attack frequency? some combo). Unlike the MP/kiting items
        above, this one may need NO new mechanism — `aiTickDelay`/`wanderChance`/
        `attackCooldown`/`sightRange` (`EnemyNPCs.dm`) are already per-instance vars
        meant to be overridden per species, just nothing overrides them yet since only
        `slime` exists as a built subtype. Likely just a per-species tuning pass once
        the roster (see below) actually has multiple subtypes to tune differently —
        confirm what's actually driving the "hyperactive" feel first, though, before
        assuming it's fully covered by these existing knobs.

      Building the spellcasting/MP/kiting pieces is a real `AILoop()`/`EnemyNPCs.dm`
      redesign — worth its own pass once `SpellRequirementDataSheet.md`'s
      AI-observations table has more data points to design against, not a quick patch
      onto the current wild-monster block.
- [x] Monster roster — 2026-08-28: all 24 confirmed names (`GMglobalrespawn`/
      `GMkillallmonsters`'s pickers, `GMCommandsReference.md`) now exist as real
      `mob/enemy` subtypes in `MonsterRoster.dm`, up from the original 10 — real OG
      stat data from `OGMonsterBaseStats.tsv`, not invented. The other 53 rows in that
      TSV belong to icons with no confirmed real name, so they're left out rather than
      guessed at. cat, slime, dog, redslime, bat, fox, babble, skeleton, drakee, healer,
      snailslime, magician, ghost, wolf, magidrakee, reptile, arcticfox, panther,
      gremlin, acolyte, blazeghost, tiger, yeti, manowar — see `GMCommandsReference.md`.
      **Correction, 2026-08-10 — not fully recoverable, but not "design from scratch"
      either.** Exact source stat values are still out of reach (no source access), but
      this session's `CombatDataSheet.md` testing already pulled real bounded data for
      slime/cat/dog from live combat alone — damage taken/dealt (bounds attack/
      defense), hits-to-kill (bounds HP), exp/gold per kill, even a resistance hint
      (cat's partial electric resistance vs. Zap). Enough controlled samples per
      monster should let a fitted approximation (closest-plausible curve, not the OG's
      literal number) stand in for a from-scratch design — same spirit as the DW1
      formula approximation already used for player damage. Worth treating monster
      stat recovery as "get close via data + fitting," not "impossible, invent freely."
      **Scoped next phase, same date**: once the current Hero1
      skill-unlock control test wraps (caps at "all of Hero's skills learned," not a
      fixed level), the bulk of remaining OG-research work shifts to this kind of
      monster-by-monster combat data collection instead of more skill-unlock testing —
      monsters don't carry anywhere near the skill/level-gate complexity a class does,
      so this phase should move faster per-monster than the skill-unlock control test
      did per-character.
- [ ] **Munching Moler** — original boss idea (a big mole), named after the auto-generated
      codename of the combat-system planning session's plan file. Not from the OG, purely
      a remake original. No design details yet beyond "big mole boss."
- [ ] More skills per class (currently only 2 exist total)
- [x] Party combat shared XP — `PartyShare` toggle splits kill Exp evenly across
      `Party.members` (`Die()`, `CombatSystem.dm`). No solo-vs-group penalty yet.
- [x] "HP reaches 0" flow (`CombatSystem.dm`'s `Die()` player branch +
      `PlayerVerbs.dm`'s `Interact()`): loses 50% Gold (matches confirmed OG "lose half
      gold") and a placeholder 25% Exp (new, no OG number, tunable), `isDead`/
      `deathTime` set, density/icon swapped to a "downed" look, movement locked
      (`canAct = FALSE`, reusing the same gate `mob/proc/Step()` already uses to root a
      player mid-attack — without this a dead player could still walk around), no
      auto-respawn. Numpad-5 (bound to `Interact()` via `Interface.dmf`'s "Center"
      macro, unchanged by the numpad-skill rework above) respawns after a 10s
      `RESPAWN_DELAY` (resetting `canAct = TRUE` too), printing a "wait N more seconds"
      message if pressed early.
      **2026-08-10 OG finding, real behavior differs:** respawn is **automatic after
      60 seconds**, no manual input needed at all — not a manual Numpad-5 press after a
      10s wait like the remake currently does. `RESPAWN_DELAY` needs to change from a
      manual-trigger minimum wait to a real auto-fire timer (60s).
      **2026-08-14 follow-up, resolves the "unclear which" question above** — confirmed
      via a real drowning-death log/message screenshot: Numpad-5 **does** still work as
      an early-respawn option on top of the 60s auto-timer, exact confirmed message is
      "You will auto-respawn in 60 seconds. You may press 5 on your numpad to respawn
      before then." So the target behavior is both: auto-fire at 60s AND a manual
      Numpad-5 override any time before that fires, not an either/or.
      **2026-08-10 OG finding, real number confirmed:** exp loss on death is **5%**, not
      the remake's placeholder 25% — retune to match once the placeholder-policy owner
      is ready to lock it in. Also confirmed: **level can never be lost to death exp
      loss.** If the loss would drop exp below the current level's floor, the level
      stays put and exp effectively bottoms out — leveling up only ever raises the next
      threshold, it doesn't reset exp to 0, so it's possible to be sitting on *less*
      exp than you had right when you hit the current level (e.g. level up at the
      threshold, then lose some to a death, without ever dropping the level itself).
      Remake's `Die()` needs an explicit floor clamp for this, not just a flat
      percentage subtraction — a naive `exp -= exp*0.05` with no floor could still let
      exp go negative or under the level's minimum if it happens repeatedly near a
      threshold.

## Phase 7 — Leveling System

- [x] Exp/Nexp/Level/StatPoints tracked. **2026-08-10 OG finding, applied 2026-08-28:**
      real number is **6 StatPoints per level**, not the old placeholder 5 — confirmed
      via Hero1 sitting on 12 unspent points after 2 level-ups (1→2→3), no points spent
      along the way. `LevelCheck()` (`CombatSystem.dm`) and `GM_LevelIncrease`
      (`GMCommands.dm`) both updated to 6.
- [ ] Real exp curve (currently flat, not scaling). **Balance goal**: the OG's leveling
      felt too fast, so aim slower than it — but explicitly not into grind territory
      either. The target is a middle ground (not too easy, not too grindy), not just
      "slower is better." Worth playtesting/tuning rather than picking a curve shape
      once and assuming it's right.
      **2026-08-10 re-confirmation, unresolved which side is the cause:** current
      remake pacing feels too fast too, same complaint as the OG — but it's unclear
      whether that's the exp curve itself (`BASE_EXP` = 15, quadratic, `CombatSystem.dm`
      — placeholder, no OG data behind it), the per-monster reward values (`TIER1_EXP`
      10 / `TIER2_EXP` 45 / `TIER3_EXP` 160 / `TIER4_EXP` 520, `MonsterRoster.dm` — also
      placeholder), or both compounding. Both sides are unconfirmed guesses right now,
      so don't retune just one without checking whether the other also needs it —
      worth isolating via actual kill-count-to-level data once there's real monster
      variety to test against (currently only `slime`, Tier 1, exists as a built
      subtype). **Stated preference, same date**: lean toward longer/harder rather than
      easier when tuning either side — explicitly doesn't want the game to feel too
      easy, wants playtime on the longer side. Still bounded by the existing
      "not into grind territory" goal above — longer/harder, not tedious.
      **2026-08-10 clarification**: the OG's fast pace wasn't an accident to preserve —
      it was built like a one-shot D&D-style session (everyone hits ~level 25-30 and
      basically knows all their spells within a couple hours). The remake is
      deliberately NOT aiming for that; it wants real longer-term progression instead.
      So don't treat "aim slower than the OG" as a small nudge — the OG's curve is the
      wrong shape entirely for what this game is going for, not just slightly too
      generous.
      **2026-08-18 — the kill-count-to-level data this was waiting on now exists.**
      Live-playtesting the trimmed Tier 1/2 roster (`CombatDataSheet.md`'s combat-log
      session, same date), Hero1 went Level 1→3 in roughly the number of kills it took
      to test damage against cat/slime/dog/redslime/bat/fox — about 6 kills total. Math
      checks out against the current placeholder numbers: `Nexp = BASE_EXP * Level^2`
      (`CombatSystem.dm`) means 15 cumulative exp to hit Level 2 and 60 to hit Level 3;
      at `TIER1_EXP` = 10 per kill (`MonsterRoster.dm`), that's 2 kills to Level 2 and
      ~6 total to Level 3 — matches what actually happened. Directly reproduces the
      "leveling is too fast" complaint flagged as unresolved above, and resolves which
      side is at fault (or at least confirms both current placeholder values combine
      into the too-fast pace, whether or not one alone would suffice) — this is real
      data, not the guess this section was working from before. Not retuning
      `BASE_EXP`/`TIER1_EXP` right now (can't compile/playtest this session to check the
      fix), but this is the concrete "too fast, felt it directly" confirmation to act on
      next time numbers get tuned — lean toward the longer/harder side per the stated
      preference above, not a small bump.
- [x] Level cap — already built (`MAX_LEVEL 50`, `CombatSystem.dm`, a deliberate
      temporary override below `ClassReference.md`'s stated 99 while class content is
      only tuned up through here), this checkbox was just stale.
- [ ] Class-specific stat growth on level-up (right now growth is generic across classes)
- [x] Skill/spell unlocks by level + stat threshold — **built out for real 2026-08-28**
      (was placeholder test data as of when this entry was written; synced against
      `ClassReference.md` the same day). Framework: `datum/skillUnlock` (skill type +
      level + optional stat/threshold), each class overrides `GetSkillUnlocks()` with
      its own list, `CheckSkillUnlocks()` runs on level-up (`LevelCheck()`,
      `CombatSystem.dm`) and stat point spend (`StatLink/Click()`, `ClickableStats.dm`).
      By construction a class can only ever learn what's in its own list. Every class
      (`Code/Player/SkillUnlocks.dm`) now has a real per-skill level/stat table —
      Hero's 2 confirmed entries (Heal/Thornwhip) kept as-is, every other entry across
      all 7 classes is an invented-but-real placeholder number (not a Fireball stand-in
      anymore), spaced using Hero's own confirmed curve as the calibration anchor.
      Equip UI now exists too (`obj/SkillLink`, `Code/Player/SkillLink.dm`): drag a
      Free Skill onto a numpad slot to equip (swaps out whatever was there, both
      directions work, slot-to-slot is a true swap), drag an equipped skill onto the
      Free Skills area (or double-click it) to unequip. **Persistence**: which skills
      are known isn't saved — it's fully re-derived from Level/stats on load — but
      which slot each one occupies (the player's own arrangement) is now saved for
      real (`equippedSkillTypes` on `datum/CharacterSaveData`, `SaveData.dm` —
      slotNum -> skill typepath, restored by `ApplySkillSlots()` which must run last
      in `LoadCharacter()`, after every skill a saved slot could reference is already
      known again).

## Phase 8 — World Systems

- [ ] **Idea pile, 2026-08-10, not scoped, your idea**: overworld areas — the OG never
      had an overworld at all (dungeons/towns only), this would be new. Concept: a
      dedicated area type (or a flag on existing types) for "traveling between places"
      space, distinct from dungeon/town, with player movement deliberately slowed while
      on it — the classic old-RPG "trudging across the overworld map" feel. Technical
      hook already exists and is cheap: `step_delay` (base mob var, default 1.36,
      `Code/Core/SmoothMovement.dm:7`) is exactly how `EnemyNPCs.dm` already gives
      monsters their own pace (2.8, slower than a player) — an overworld area could set
      a player's `step_delay` higher on `Entered()`/restore it on `Exited()`, same
      pattern. Not scoped beyond the concept: exact slowdown amount, whether it's a new
      `area/overworld` type or a bool on the existing `area` base, and how it interacts
      with the existing area roster (`wilderness` already exists — unclear if overworld
      IS wilderness re-purposed, or a separate thing entirely).
- [ ] **"Random Battles DLC" (your name for it), 2026-08-10, not scoped — Dragon
      Warrior Mythology-style random encounters, an optional overworld feature (builds
      on the overworld idea right above).** Reference: DWM (a same-era DWL-like game) had real-time random
      battles — walking the overworld could trigger a small bounded battlefield
      instance where you chase down and fight a monster that's actually moving around
      in real time, rather than combat just happening in-place wherever you were
      standing. Framed as "best of both worlds" (random-encounter pacing + this game's
      already-real-time combat, not a turn-based interruption). Wanted as something
      an overworld's creator can opt into, not a forced global mechanic. Not scoped
      beyond the concept: encounter trigger chance/cadence while walking an overworld
      tile, and the bounded-arena instance itself likely reuses the same dynamic
      area-instancing pattern `GM_MakeArea` and the player-plot idea (`[[project-map-
      persistence-idea]]` idea #1) already lean on, plus the existing per-area
      `battleModeOn` flag (`GMbattlemode`, `Area.dm`) for "combat is allowed here" —
      but the actual spawn-into-instance / return-to-overworld-after flow isn't
      designed at all yet. **Scope note, same date**: explicitly a MUCH LATER item —
      user confirmed this is one big game absorbing all these ideas over time, not
      several separate games, so "idea pile" entries like this one are real roadmap,
      just far out. Don't treat "logged" as "next up."
- [ ] **"DWM DLC" (your name for it), 2026-08-10, not scoped — Dragon Warrior
      Monsters-style taming/training.** Monster taming, training, and fighting alongside the
      player (or having a tamed monster fight FOR the player instead) — same "one big
      game, phased" scope as the "Random Battles DLC" above, all part of one game's
      long roadmap rather than separate games. There's already a real seed of this
      mechanism built and working: `mob/enemy`'s pet system (`EnemyNPCs.dm`) —
      `owner`/`petName`/`petMode` vars, `PET_MODE_FOLLOW`/`SIT`/`WANDER`/`AGGRESSIVE`,
      `HandlePetTick()` branching AI per mode, `ShowAssignPetMenu()`/
      `ShowPetOwnerMenu()`. Current limitation: assigning a pet is **GM-only**
      (double-click by a `client.canAdmin` mob), same stats/no leveling, one pet per
      owner — nothing here lets a PLAYER tame a wild monster themselves through actual
      gameplay (a taming mechanic, catch rate, item, or in-combat action), and there's
      no training/leveling system for an owned pet at all. DWM-style taming/training
      would need both of those built on top of what already exists, not from scratch.
      Not scoped beyond the concept.
- [x] Area types with per-area background music (`Area.dm`)
- [x] Turf library: ground/floor/furniture/wall/water/bridge/stairs/warp (`Turfs.dm`)
- [x] `turf/sky` falls the player 1 Z level down + plays `fall.wav` on `Entered()` —
      same mechanic `turf/stairs/stairsdown` already used (Z-level teleport via
      `locate(M.x, M.y, M.z - 1)`), just triggered by walking onto sky instead of a
      staircase. Was flagged "not built" in a code comment since the turf-collapse
      pass; now wired up, with a brief `spawn(8)` pause before the actual drop
      (placeholder gap for a real falling animation later, not built yet). Fixed a
      real bug along the way, in both this and the pre-existing stairs code it copied:
      the sound was firing *after* `M.loc` already changed to the new Z-level, at
      which point `view()` (centered on the turf, still on the old Z) no longer
      reaches the mob's client — so `stairs.wav`/`fall.wav` silently never played.
      Sound now fires first, while the mob's still physically there. **Second bug**,
      found via `GMghostform`: even after that fix, `view()` still didn't reach a
      ghosted GM specifically, since `view()` filters by visibility rules
      (opacity/invisibility/`see_invisible`) and ghost form sets `invisibility = 1` +
      `icon = null` (`GMCommands.dm`) — enough to exclude the ghost from its own
      turf's `view()` broadcast. Switched to sending the sound straight to the mob
      (`M << sound(...)`) instead of broadcasting via `view()`, which sidesteps
      visibility rules entirely and guarantees whoever's actually taking the stairs/
      falling always hears it, ghost or not. **Third bug**, found via live testing:
      walking across multiple sky tiles during the `spawn(8)` delay re-triggered
      `Entered()` on each one, stacking up multiple falls/sounds instead of one.
      Fixed by locking movement for the duration via the same `canAct` gate
      `mob/proc/Step()` already checks (`SmoothMovement.dm`) — same mechanism used to
      root a mob mid-attack or on death — set the instant the fall starts, reset once
      the delayed Z-level move actually resolves. `Entered()` also now bails
      immediately if `canAct` is already `FALSE`, as a second line of defense.
      **2026-08-13 — the "real falling animation" gap above has a name and an asset:
      a full-screen fade.** User's own idea, not OG-derived. `UI & Effects/fade.dmi`
      already exists in the repo but isn't wired into any code yet (`flick()` for it
      doesn't appear anywhere) — confirmed via search, this is a genuinely unused
      asset sitting ready, not something to create from scratch. Same fade should
      trigger on stairs (`turf/stairs/stairsup`/`stairsdown`, `Turfs.dm`) and warp
      turfs too, not just `turf/sky` — all three are screen transitions and should
      feel consistent. Fits naturally in the `spawn(8)` pause already present for the
      sky-fall case.
      **Asset confirmed, 2026-08-13**: `fade.dmi` has 9 icon_states — 0, 12.5, 25,
      37.5, 50, 62.5, 75, 87.5, 100 — evenly spaced 12.5%-opacity steps, not a single
      animated state. Implementation is a discrete step-through (a `screen`-anchored
      overlay object whose `icon_state` advances through that list with a `sleep()`
      between each, 0→100 to fade out, 100→0 to fade back in) rather than a smooth
      `animate()` tween. Not scoped beyond that: exact per-step delay (total fade
      duration), whether stairs/warp get the same `spawn()` delay treatment sky
      currently has or a shorter one. **Scope, clarified 2026-08-13: this is NOT
      combat feedback UI** (unlike the HUD/floating-numbers carve-out elsewhere in
      this phase) — it's a movement/transition visual, so it stays in the Big
      Beautiful Update bucket, deferred, not in-scope for this pass. Logged here now
      just so the spec/asset info isn't lost by the time that pass starts.
- [x] Doors with open/close/lock; sign/pot/bookcase/chest turfs exist as placeholders
- [x] **Per-area property scaffolding** — `Area.dm`'s base `area` type now has
      `battleModeOn`, `battleAllowsPvP`, `indestructibleMode`, and `weather` vars.
      `GMbattlemode` (`GMCommands.dm`, GM-Host tier) offers both: pick a specific area
      to toggle just that one, or pick "All Areas" to force every area's `battleModeOn`
      to the same value at once, disregarding each area type's own default
      (`battleModeGlobalOn`, `Main.dm`). `CombatSystem.dm`'s `InBattleArea()` actually
      checks it (`Attack`/`Fireball` in `SkillDatum.dm` both gate on it). `GMcoopmode`
      built 2026-08-28 (see Phase 9). Still needed: `GMindestructablemode`/`GMweather`
      verbs and wiring the terrain-damage system (once built) to check
      `indestructibleMode`/`weather`.
- [ ] **Ceiling/border visibility system — real rework needed, not just a tune.**
      You want the OG's indoor/outdoor visibility actually working right, based on how
      you remember it playing: **two separate pieces**, not one.
      1. **Border** (the walls/perimeter of a room or house) — blocks a player standing
         *inside* from seeing *outside* the walls. Not built at all yet — worth
         checking whether `turf/wall` even sets `opacity = 1` currently (BYOND's
         actual line-of-sight blocker; `density` only blocks movement, not sight) —
         suspect it doesn't, meaning walls may not currently block LOS at all. You
         described this as its own "border area," not just per-tile wall opacity,
         which suggests it might need to be area-scoped rather than relying purely on
         perimeter turfs having a gap-free opaque ring (fragile if a map's walls
         aren't a perfectly sealed rectangle).
      2. **Ceiling** (the roof) — an *area* covering the room's footprint that hides
         the interior from anyone standing *outside* looking in; they see the roof
         sprite instead. **This half is already built this way** — `area/ceiling`
         (`Area.dm`) already IS a real area type (not a turf), matching your
         description exactly. Its `Entered()`/`Exited()` toggle a mob's own
         `see_invisible` between 0 (indoors, so `obj/ceiling`'s `invisibility = 1`
         roof sprite, `Obj.dm`, is hidden from them) and 1 (outdoors, roof visible to
         them, covering the interior via its high `layer = 100`). So the ceiling half
         genuinely just needs the border half built alongside it, not a rework.
      Also just fixed a real bug here: `GM_GhostForm` (`GMCommands.dm`) used to
      collide with this exact `invisibility = 1` tier, meaning any outdoor player
      could see a "hidden" ghosted GM — see the `GM_GhostForm` entry in Phase 9.
      Ghost form now uses `GHOST_INVISIBILITY = 2` instead, so it's clear of whatever
      tier(s) the border/ceiling rework ends up using — keep new tiers below 2, or
      update `GMCommands.dm`'s comment on `GHOST_INVISIBILITY` if that no longer holds.
      **Add later, your own idea, explicitly deferred even relative to this**: `Say()`
      (`SocialVerbs.dm`) privacy tied to the same border — players inside a bordered
      room shouldn't see `Say()` messages from players outside it, and vice versa.
      Flavor/immersion feature, not core to getting the visibility rework itself
      working — pick up only once the border/ceiling mechanic above is solid.
- [ ] Day/Night cycle (GM-toggleable) — nothing built yet
- [ ] Weather system — confirmed via `GMweather` (see `GMCommandsReference.md`): three
      parts — Rain/Snow toggle (outside areas only), Puddles (scatters walkable water or
      snow onto random turfs based on the rain/snow choice), and Temperature (9-level
      scale, Blazing to Freezing, set per area instance). The `weather` var already
      scaffolded on `Area.dm` needs to hold all three pieces of state, not just a
      boolean. **Remake idea, not OG behavior**: tie temperature to gameplay (damage over
      time in extremes, or gear needed to stay warm/cool) — not something to build until
      the base weather system exists. **Confirmed via live testing**: while
      `GMroleplaymode` is active, extreme temperatures deal damage over time and passive
      HP regen is disabled entirely — this was originally logged as an untested idea but
      turned out to be real OG behavior. Only happens during roleplay mode, not globally.
- [ ] **Shallow vs. deep water — confirmed real OG mechanic, live-tested 2026-08-14**
      (originally logged 2026-07-31 as a guessed-at idea; that framing was wrong, this is
      genuinely from the OG). Real confirmed structure, different and more specific than
      the original guess:
      - **`swim water`** — a distinct turf (visually water) separate from the plain
        impassable `turf/water` already in `Turfs.dm`. Walkable/standable, and it's the
        turf that dive/surface conditions check for.
      - **Two AREA types involved**: `underwater` and `deepwater` (both already exist as
        area subtypes in `Area.dm`, per the area-type list found 2026-07-31 — previously
        unclear what distinguished them, now confirmed). Both have an overlay visible to
        **all players**, not just the submerged one.
      - **Key finding: oxygen only drains in `deepwater` areas, not `underwater`
        areas** — `underwater` is a submerged zone with no breath mechanic at all. Only
        `deepwater` ticks the oxygen meter down; rate/interval not measured yet, but
        described as "kind of slow." Aside from the oxygen meter overlay itself, nothing
        else about the deepwater view reads as transparent/tinted (per your testing) —
        worth double-checking this on a repeat pass, phrasing was a little uncertain.
      - **Dive conditions** (all three must hold): 1) standing on `swim water`, 2) current
        area is `underwater` or `deepwater` (either qualifies — doesn't matter which for
        the dive check itself, only for whether oxygen drains after), 3) the tile **one Z
        level down** is also `swim water` in an `underwater`/`deepwater` area.
      - **Surface conditions**: identical check, mirrored — same three conditions but
        checking **one Z level up** instead of down.
      **2026-08-14 confirmed via real drowning death log**: zero oxygen causes **instant
      death**, not damage-over-time or a forced surface — message sequence was "You dive
      underwater." → "You return to the surface." → "You have drowned!" → "[Name] has
      died!" → the standard 60s-auto/Numpad-5-early respawn prompt (same as any other
      death, see the Death & Respawn finding above — this is what confirmed that
      Numpad-5 early-respawn is still live too). Note: the log screenshot also showed
      "You can't see areas anymore." — that's **unrelated to water**, just the `GMseeareas`
      debug toggle being switched off in the same window, not a real dive/drown message.
      Still open: exact oxygen drain rate/interval, and whether any deepwater-view
      overlay beyond the meter exists.
      **UX flaws noted in the OG, not to be copied**:
      - The oxygen meter overlay is hard to read in deepwater because of how the
        deepwater screen overlay itself looks (visually competes with/obscures the
        meter). Root cause not pinned down yet — when built for real, keep the meter
        legible against whatever deepwater visual effect we use instead of reproducing
        the OG's version.
      - `swim water` is visually indistinguishable from plain `turf/water` — same
        appearance/name, no visual tell for which tiles are actually diveable. Makes
        exploring for dive points maze-like/guesswork in the OG. Our version should give
        `swim water` its own distinct look (or some other clear indicator) so players can
        actually tell diveable water from plain impassable water on sight.
      Whether specific equipment counters the damage is still unconfirmed.
- [ ] Roleplay Mode toggle — **low priority, not a straight port**. You weren't a big
      fan of how this played in the OG, so this is a candidate for redesign/expansion
      rather than faithful recreation whenever it gets picked up — no rush on it.
      World-wide, not per-area (unlike battlemode/coopmode/indestructiblemode above).
      OG behavior for reference: restricts chat to in-view only, appears to depend on
      Day/Night + Weather both existing, and brings in three survival mechanics not
      previously documented anywhere: Hunger, Thirst, and Sleep. See
      `GMCommandsReference.md`'s `GMroleplaymode` entry for the full OG breakdown.
- [x] Bookcase/chest actual interaction logic — chest/drawer/pot storage was already
      built (0.8.0 pass); bookcase's own real/write-read mechanic added 2026-08-28
      (`Obj.dm`) — OG-confirmed "player-writable shared book storage" (string 1687),
      any player can add a message and read what everyone else left, not GM-set text
      like a sign. Session-only, no world serializer yet.
- [ ] New "stat" (interactable object) types surfaced via `GMmakestat` (see
      `GMCommandsReference.md`) — **not a gap to close now**, our door/sign types were
      only ever built for the minimum the current overworld map needs, not the OG's full
      roster. Add these as the map actually grows to need them, not proactively:
      - Sign variants: snowwooden, snowinn, weapon, armor, item (we only have
        wooden/inn/church/grave today)
      - Door variants: silver, and a `switchdoor` type (switch-activated, not
        interact-to-open like our current door)
      - `musicalbookcase` — confirmed real, this is the paused jukebox feature idea,
        distinct from plain `bookcase`
      - `warppoint` — teleport mechanic, relationship to the existing `turf/warp` type
        in `Turfs.dm` not yet clear (same system or a separate one?)
      - `respawn` — a placeable death-respawn marker, **confirmed distinct from
        `playerstart`** via `GMseeareas` (which shows login spawns, death/respawn spawns,
        and monster spawns as three separately-marked types)
      - `levelbarrier` — likely blocks players below some level threshold from passing
      - [x] `playerstart` — a placeable **login** spawn marker. **Built as a plain
        object** (`obj/spawnMarker/playerStart`, `Code/World/Area.dm`, door.dmi/wooden,
        `invisibility = 100` so it's never seen during normal play), matching
        `GMmakestat`'s own listing — deliberately NOT an area, since a turf only
        belongs to one area and an area-based marker would strip whatever real area
        (Town, Dungeon, ...) the tile already had. Placed via `GM_CreateObj` ("World
        Login Point"); `GetPlayerSpawnTurf()` picks a random tile with one on it.
        `PLAYER_SPAWN` (the old hardcoded coordinate) is now only an emergency
        fallback for a map that has no marker placed yet. Visible only through
        `GMseeareas`' overlay, as an extra layer on top of the tile's normal area
        color.
      - [x] `playerspawn` — **confirmed distinct from `playerstart`**: the post-death
        respawn location specifically, not the initial login point. Same
        object-not-area treatment as above — `obj/spawnMarker/playerSpawn`
        (`Code/World/Area.dm`, sign.dmi/church icon), placed via `GM_CreateObj`
        ("Respawn Point") + `GetRespawnTurf()`, used only by the Respawn verb
        (`PlayerVerbs.dm`).
      - `boulderspawn` — likely a pushable-boulder puzzle mechanic, no equivalent exists
- [ ] Merchant/shop NPC system — `GMmakestat` surfaced `greatestamuletmerchant`,
      `foodmerchant`, `drinkmerchant` as shopkeeper NPC types. Not the Merchant *class*
      (see `ClassReference.md`) — this is a buy/sell vendor system, completely absent
      from our design so far, not just unbuilt

## Phase 9 — GM/Admin Tooling

- [x] 6-tier hierarchy: Player/Builder/Admin/GM-Host/Aeon's Crew/Aeon, resolved fresh
      from hardcoded data every connect (`AdminLevels.dm`)
- [x] `GM_GhostForm`, `GMToggleProfanityFilter`, `GM_Create_Lockable` (`GMCommands.dm`)
      — **found and fixed a real invisibility bug in `GM_GhostForm` while
      investigating whether it actually hides a ghosted GM from regular players.**
      It didn't, reliably: ghost form set `invisibility = 1`, but `obj/ceiling`
      (`Obj.dm`, the roof-hiding system) also uses `invisibility = 1`, and
      `area/ceiling`'s `Entered()`/`Exited()` (`Area.dm`) toggles a player's own
      `see_invisible` to `1` whenever they're standing outdoors (so the roof itself
      becomes visible from outside) — which meant ANY player currently outdoors
      (i.e. most players, most of the time) could actually see a "hidden" ghosted GM,
      since BYOND's rule is `invisible if invisibility > see_invisible`. Gave ghost
      form its own tier instead (`GHOST_INVISIBILITY = 2`, above the roof system's 1)
      so it no longer collides. Also — **new**: ghosted mobs now get their own
      `see_invisible` bumped to match, so builders in ghost form can see (and follow)
      each other, which regular players still can't do.
- [x] Lock down `DebugTools.dm` verbs — 2026-08-28: `DebugMovement`, `Test_PoisonSelf`,
      `FullRestore`, `Debug_ShowZoneColors` (the ones that still exist — `Test_Leveling`/
      `S_World`/`S_Sleep`/`S_Attack`/`S_Defend` from this item's original wording are
      already gone) now gate on `client.canBuild`, same visible-but-rejected-on-click
      convention every GM verb uses.
- [x] `GMtogglelog` — toggles `loggingEnabled` (`Code/Core/TextFilter.dm`), gates
      `LogChat()`'s own lines only (chat/login/logout/double-login) — `world.log`'s
      automatic connect/disconnect/host events keep writing to `server.log` regardless,
      that's the engine, not something this can toggle. **First GM verb that's actually
      hidden from non-GMs**, not just rejected-on-use like every other one here —
      `client/proc/SyncGMVerbs()` (`AdminLevels.dm`) adds/removes it from `mob.verbs`
      dynamically, re-run at every point a mob's own verb list gets reset wholesale
      (`EnableCommands()`, `Main.dm`) or a fresh mob takes over
      (`FinalizePlayer()`/`LoadCharacter()`). Every other GM verb below is still
      visible-to-everyone — this establishes the pattern, doesn't retrofit all of them.
- [x] Admin verbs: `GMannounce`, `GMban`/`GMunban` (combined, `GM_Ban`), `GMboot`
      (`GM_Boot`), `GMmute`/`GMunmute` (combined, `GM_Mute`), `GMpwipe` (`GM_Pwipe`,
      plus a remake-only "All" pwipe gated to `LEVEL_AEON`) — all in `GMCommands.dm`.
- [ ] Builder verbs: `GMdelobjmob`, `GMmakearea`, `GMmaketurf`, `GMmakeitem`, `GMmakestat`,
      `GMtransfer`, `GMmakemob` (some overlap with `GM_Create_Lockable`, which already
      covers a slice of `GMmakeitem`/`GMmakestat`'s job for lockables)
- [x] `GMseeareas` (`GMCommands.dm`, Builder tier) — toggles a `client.images` overlay
      showing each turf's area as a colored tile from `environment.dmi`, using the
      area's own `name` as the `icon_state` (e.g. "bar", "town", "townrain") — no new art
      needed, `environment.dmi` already had these states. Originally snapshotted every
      turf in the *whole world* on toggle, which visibly froze/lagged the
      single-threaded server for a moment, and — the real ongoing cost, not just the
      build loop — left potentially thousands of persistent `/image` objects on one
      client that the renderer had to composite every frame regardless of whether
      they were on-screen. Switched to only building images for a small area around
      the GM, refreshed by a polling loop (`AreaOverlayLoop()`) only when they actually
      move to a new tile — bounded to a small tile count instead of scaling with map
      size, matching how the OG likely does this (unconfirmed, but a whole-map overlay
      with zero lag isn't plausible for BYOND's rendering model). Padded a few tiles
      past the actual 13x13 viewport (`AREA_OVERLAY_RADIUS`/`AREA_OVERLAY_BUFFER`,
      `range()` not `view()` since this deliberately covers past what's on-screen) so
      the overlay is already built for tiles just off-screen before the GM walks into
      view of them — masks the polling loop's up-to-half-second refresh delay behind a
      buffer instead of visible pop-in right at the screen edge.
- [x] `GMdaynight` — implemented, see `GMCommandsReference.md`
- [x] `GMbattlemode` (`GMCommands.dm`, GM-Host tier) — area picker (with a "None" cancel
      entry) toggling that area's `battleModeOn`, **plus** an "All Areas" entry that
      instead does a global toggle (same shape as `GMdaynight`), overriding every area's
      own default while active; see Phase 8's per-area scaffolding note.
- [x] `GMlevelincrease` (`GMCommands.dm`, GM-Host tier) — was `Test_Leveling()`
      (`DebugTools.dm`), an unrestricted debug stub that added a huge pile of Exp and
      hoped `LevelCheck()` would trigger off it. Now directly applies the same
      side effects a real level-up does (`Level += 1`, `StatPoints += 6` — updated
      2026-08-28 to match `LevelCheck()`'s confirmed value, `RecalculateVitals()`),
      not just a roundabout way to reach them.
- [x] `GMcoopmode`, `GMplayerstatus`, `GMplaymusic`, `GMsavelocation`, `GMswitchicon` —
      built 2026-08-28 (`GMCommands.dm`), against the confirmed specs in
      `GMCommandsReference.md`. `GM_CoopMode` mirrors `GM_BattleMode` exactly
      (per-area/global `battleAllowsPvP` toggle, enforced in `TakeDamage()`,
      `CombatSystem.dm`, GM targets exempt). `GM_PlayerStatus` dumps a full character
      sheet (stats with equip bonus, inventory, every known skill). `GM_PlayMusic`
      sets `areaMusic` per-area-or-globally and pushes it live to whoever's already
      standing there. `GM_SaveLocation` is a world-wide toggle backed by new
      `savedX/Y/Z` fields on `CharacterSaveData` (`SaveData.dm`), always recorded on
      save, only consulted at load time. `GM_SwitchIcon` finally points at the
      `"Mob Icons/Custom GM"` files that already existed with nothing using them.
      `GMkillallmonsters`/`GMnamechange` were already built (stale checkbox).
      `GM_GlobalRespawn` also built (`datum/RespawnDefinition`, session-only — no
      world serializer exists to persist it across a reboot): Name/Area/Monster
      type/Z level/Count creation flow, Modify/Delete on an existing definition, both
      confirmed quirks preserved (one-shot spawn, not a maintained population; a
      non-matching Area+Z level combo silently spawns nothing).
      **Still not built** (both explicitly lower-priority or bigger-scoped per their
      own reference-doc notes): `GMblaze` (needs a fire-DoT terrain system first),
      `GMroleplaymode` (low priority, wanted as a redesign not a port), `GMweather`
      (ties into the RP-mode bucket that's explicitly out of scope right now).
- [x] `GMworldreboot` — implemented as `GM_WorldReboot` (`GMCommands.dm`), see
      `GMCommandsReference.md` for the full flow. Fixed the OG's confirmed-broken
      post-reboot black screen via a `world/Reboot()` override (`Main.dm`) rather than
      copying it. Not playtested yet.
- [x] GM ability to designate Builder/Admin status persistently — see Phase 2's entry
      above (`GM_PromoteBuilder`/`GM_PromoteAdmin`, 2026-08-28). GM/Host/Aeon tiers stay
      hardcoded-only by design, not part of this.
- [ ] **Idea pile, 2026-08-10, not scoped**: host-selectable "grand adventure" vs.
      "quick campaign" server mode — grand adventure = world persists across reboot,
      built for real long-term progression; quick campaign = closer to the OG's
      original one-shot-D&D pace (fast leveling, short session, world reset-on-reboot
      probably fine). Full theorycraft in the `project-map-persistence-idea` memory
      (idea #3) — connects to the whole-world persistence idea already scoped there
      (hook points: `GM_WorldReboot` for save, `world/New()` for load) and to this
      same phase's exp-multiplier idea below (quick-campaign mode may want to loosen
      the exp curve back toward OG speed rather than the longer/harder default).
      **2026-08-10 refinement**: grand-adventure saves need to cover NPCs, respawn
      state, and areas, not just static turf/obj — a host's placed NPCs and respawn
      markers should survive a reboot too. Accepted tradeoff: slower/heavier save-load
      than the turf-only version, explicitly fine for the larger-map use case. Open
      question whether quick-campaign mode keeps the cheaper turf-only format instead,
      making the two modes genuinely different save shapes.
- [ ] **Idea pile, 2026-08-10, not scoped**: host-adjustable exp-gain multiplier, so a
      GM can tailor pacing per-server rather than it being locked to whatever the
      shipped curve/monster-reward numbers end up tuned to (see Phase 7's exp-pacing
      discussion, [[project-dwlr-difficulty-preference]]). Not designed yet — global
      flat multiplier applied at `Die()`'s exp award (`CombatSystem.dm`) is the obvious
      shape, same pattern as `GMbattlemode`'s per-area/global toggle, but per-area vs.
      global vs. per-player isn't decided, and neither is whether it persists across
      reboot or resets each session.
- [ ] **Idea pile, 2026-08-14, not scoped**: host-created custom content — let a
      Host/GM define their own monster (stats, weaknesses/elemental resistances, etc.)
      and their own turf types, rather than being limited to the shipped roster. Same
      "eventually" bucket as the grand-adventure/quick-campaign host-mode idea right
      above — both are about giving a host more control over their own server rather
      than a fixed shipped experience. Not designed at all yet:
      - Monster side: would presumably build on `MonsterRoster.dm`'s existing stat-block
        pattern and `GMmakemob`'s placement flow (Phase 10 below), but needs some kind of
        in-game editor UI (stat sliders/inputs, weakness picker) that doesn't exist for
        anything monster-related right now — today's roster is all hardcoded types.
        **Icon constraint, confirmed 2026-08-14**: a host-submitted custom monster icon
        needs **four** required icon_states — `world` (idle default, what every existing
        monster in `MonsterRoster.dm`/`EnemyNPCs.dm` uses today), `attack`/`weapon` (swing
        animation — monsters call the same `PlayAttackAnimation()`/`ResolveAnimState()`
        path players use, `EnemyNPCs.dm:195`, so this isn't optional), and `sleep` (death
        pose — `Die()` in `CombatSystem.dm` sets this on any dying mob, player or
        monster, universally). Missing any of the four would render blank at that moment
        (idle/attacking/dead respectively). Whatever upload/creation flow this idea
        eventually needs should validate all four are present on submission and tell the
        creator up front what's required, rather than failing silently mid-game.
      - Turf side: runs directly into the Turf/Obj Convention adopted 2026-07-21 (top of
        this file) — visual-only variants are supposed to be map-editor instances of a
        generic type, not new hardcoded types, which actually works in this idea's favor
        (a host picking a custom icon for an existing turf type needs no new code at
        all); a host wanting genuinely new *behavior* (not just a new sprite) is the hard
        case and isn't scoped.
      - If this ever gets built, it likely wants to be saved per-world (ties into the
        grand-adventure persistence idea above) rather than per-character, since it's
        server/host content, not something one player carries between servers.

## Phase 10 — Building/Map Tools (biggest net-new subsystem, do last)

**Stale as of 2026-08-28 — this entire phase turns out to already be built**
(`Code/Admin/Commands/BuildTools.dm`, added in a prior pass this file never got
updated for). Checked directly against the code rather than assumed:

- [x] `GMmakearea`/`GM_MakeArea`, `GMmaketurf`/`GM_MakeTurf`, `GMmakemob`/`GM_MakeMob`
      all real, all using the shared "pick from `GetTypeChoices()`, 'None' cancels,
      `PickBuildSelection()` enters build mode" pattern. `GM_MakeMob` reads from the
      real `/mob/enemy` roster (`MonsterRoster.dm`, now 24 monsters — see Phase 6),
      correcting the design doc's `/mob/monster/*`. The 6 night-variant areas
      (snownight/rainnight/waternight1/waternight/deepwaternight1/deepwaternight) this
      section used to flag as the "only gap" are already coded too (`Area.dm`).
- [x] `GMmaketool`/`GM_MakeTool` — all 7 confirmed modes exist (`BUILD_MODE_CLICK/DRAG/
      BLOCK/LINE/MOVE/FLOOD/DELETE`), dispatched from real `client/MouseDown()`/
      `MouseDrag()`/`MouseUp()` overrides in `BuildTools.dm`.
- [x] `SelectTurf()`-equivalent type-select — covered by the `GMmakeX` verbs above,
      same as originally scoped.

Not independently re-verified this session: real in-game mouse-drag testing (Block/
Line/Move/Flood specifically) — Claude can't drive the actual BYOND client, so this is
"the code exists and compiles," not "confirmed pixel-correct in play." Worth an actual
playtest pass if it hasn't had one.
- [ ] Save/upload custom maps (explicitly noted as a "maybe eventually" in your own notes
      — do not start this until the rest of Phase 10 is solid). **Reference found
      (2026-07-31)**: a "SwapMaps" demo project on the BYOND developer hub — host-side
      save/load/share of custom maps, exactly the shape of this feature. Not yet pulled
      into the repo; grab the source and review before building from scratch.

## Open Questions (blockers worth resolving before the phase that needs them)

- [x] **STR/VIT/AGI/INT/Luck vs STR/VIT/AGI/INT/Spirit** — originally resolved: Luck. Not
      a stat in DW1 itself (which only has Strength/Agility/HP/MP), but introduced in
      Dragon Quest III and carried through IV — fits the game's stated DW1-4 range.
      Spirit isn't a Dragon Warrior/Quest stat at any point.
      **Reversed (2026-08-09)**: testing found this stat also drives MaxMP in
      combination with Level (see `ClassReference.md` Stat effects) — Spirit reads
      better than Luck once it's partly a magic stat, not just crit/drop chance. Code
      (`var/Spirit`, `TIER1_SPIRIT`..`TIER4_SPIRIT`, `capSpirit`, etc.) already renamed
      back to match. Also decided alongside this: item-drop chance is no longer tied to
      this stat at all — it's now a flat hidden rate per monster type instead.
      **2026-08-10 confirmation:** live OG testing (Hero1) nailed the actual
      coefficient — +1 Spirit gave exactly +2 MaxMP. Matches the remake's
      `MP_PER_SPIRIT` placeholder exactly by coincidence; that `#define` in
      `StatsDatum.dm` is now marked confirmed instead of placeholder.
      **2026-08-23 — the Spirit/Luck ambiguity turns out to be baked into the OG
      itself, not a remake-side naming slip.** A collaborator extracted the real string
      table straight out of OG DWL's `.dmb` (world bin v341, 4450 strings, via the
      Somnium13 `somdump` toolchain — see `project-dwlr-og-decompile-effort` memory).
      Internal stat vars are confirmed `str`/`agi`/`vit`/`int`/`spr` — but the "Amulet
      of Spirit" item's own internal keyword field reads `luck`, sitting right next to
      it in the data. Same stat, both names, coexisting in the OG's own files — the
      Help section's self-admitted "outdated" note (also recovered verbatim in this
      dump, word for word) wasn't the only inconsistency; the OG devs never fully
      settled this either.
- [x] **Per-class spell/skill lists and their learn requirements (level + stat combo)**
      — resolved (2026-08-04): **placeholder policy**. Real OG data only ever confirmed
      2 of ~90 entries (Hero's Heal/Thornwhip) and no more is coming, so stop waiting on
      it — invent a sane level/stat curve for every unconfirmed entry now (mirroring
      Hero's confirmed spacing where reasonable), all numbers tunable later once
      playtesting starts. Same policy covers Sage's skill list (see `ClassReference.md`
      — union of Hero+Wizard+Pilgrim, your explicit call) and the unconfirmed
      Agility/Vitality/Intelligence/Luck stat caps for every class.
- [x] **Real inventory capacity formula** — resolved (2026-08-04): **Strength-scaled**,
      confirmed by the OG help file's own flavor text ("Strength: increases physical
      damage AND the number of items you can carry"). Exact coefficients are placeholder
      — only real data point is level-1 Hero = capacity 9 (not the current placeholder
      8) — tune later. Not blocking: pick a formula shape now (e.g. `base + floor(Str /
      X)`), revisit once more data points exist.
- [x] Whether text/chat logging is wanted, and if so where it's stored — **already
      answered/built**, see Phase 2's chat+login/logout logging entry (`server.log`,
      gitignored). Leaving this line only because it was never explicitly checked off
      here — no remaining work.
- [x] **Stat point cost formula may not be a flat universal formula** — resolved
      (2026-08-04): **keep the universal formula for now**, tweak later. A real OG
      Battle tab screenshot (level-unknown Hero: Str 14, Agi 9, Vit 11, Int 9,
      Luck("Spirit") 9) shows Vitality/Intelligence/Luck matching `2 + floor(stat/5)`
      exactly (4/3/3 points), but Strength/Agility don't (6/5 shown vs. 4/3 predicted) —
      not enough data to confidently redesign against 5 *other* data points that do fit,
      so leave `ClickableStats.dm` as-is and revisit if/when more screenshots surface.
- [x] **Real exp curve shape** — resolved (2026-08-04): front-loaded, not flat and not
      exponential from level 1. Your words: the OG "gains levels too fast" early on, but
      shouldn't be flat-out grindy either — so **fast early levels, gradually slowing**,
      matching the classic-RPG feel of quick early progress that tapers into a real
      grind by the level-90s. Exact curve (formula/table) is placeholder, tune by feel
      once leveling exists to test against.
- [x] **Loot-stealing prevention** — resolved (2026-08-04): **first-hit tagging**, start
      simple, revisit later. Confirmed by the OG's own posted rules (see "OG Help File"
      section below): "You won't get any EXP or gold from [a kill] unless you hit it
      first" — so the OG already enforced first-hit ownership of both kill-credit and
      loot, just as a social norm reinforced by mechanics, not pure honor system. Build:
      whichever player lands the first hit on a monster owns its Exp/gold/drop; nobody
      else can loot the corpse.
- [x] **Verb category/tab reorganization** — resolved (2026-08-04): consolidate into a
      sensible scheme, your call on exact bucket, one requirement: **collapse
      Admin/Builder/GM into a single "GM" tab** (rank-gated per-verb visibility, not
      separate tabs per rank), and **keep "Debug" as its own separate category**
      (admin-only, not merged into GM). Proposed buckets to implement against: Combat
      (skills/numpad), Inventory/Action (pickup/drop/give/interact), Social (say/tell/
      emote/who/look/party), Settings (volume/turnwalk/toggle verbs), GM (everything
      currently `"Admin"`/`"Builder"`/`"GM"`), Debug (unchanged, admin-only).
- [x] **TM/HM-style spell scrolls vs. Move Tutor NPC** — resolved (2026-08-04):
      **deferred to a later version**, not part of the current mechanics-first pass.
      Keep both ideas logged (Phase 1's Move Tutor entry above) as distinct — not
      merged — decide which (or both) to build once this pass is done.

## Quality of Life (no fixed phase — pull these in wherever they fit)

- [x] Prevent other players from stealing loot drops — see resolved Open Question above
      (first-hit tagging, 2026-08-04)
- [x] Reorganize verb categories/tabs — see resolved Open Question above (2026-08-04):
      Combat/Inventory-Action/Social/Settings/GM(consolidated)/Debug(kept separate)
- [ ] **General interface/UI polish pass — deliberately scheduled as its own later
      milestone, nicknamed "the Big Beautiful Update" (your joke name, 2026-08-04).**
      Explicit sequencing decision: get every mechanic (combat, classes, leveling,
      building tools, GM tooling, etc.) working correctly first, current placeholder
      numbers and all — UI stays bare-bones `input()`/`stat()` per the v1 Scope Note
      throughout this whole pass, **except combat feedback UI (bottom HUD, floating
      combat numbers, HP/MP meters above mobs) — carved out 2026-08-13, see Phase 3
      entries, needed now since combat isn't really testable without them.**
      Once mechanics are otherwise solid, the next major pass adds the rest of the
      UI/visual polish: on-screen meters beyond the combat carve-out,
      character select screen polish, menu polish, the graphical build-mode picker
      (Phase 10 QoL entry below), and the splashscreen entry below. Nothing in this
      remaining bucket should be started before the mechanics pass is actually done.
      **Also clarified 2026-08-13:** once the mechanics-first pass (matching the OG as
      closely as possible) is complete, it ships as its own standalone release in
      honor of the OG — the Big Beautiful Update is a distinct pass that follows that
      release, not something blended into finishing the mechanics pass.
- [ ] Character select screen polish — part of the Big Beautiful Update, see above
- [ ] Menu polish (creation flow, stat allocation, etc.) — part of the Big Beautiful
      Update, see above
- [ ] **Opening splashscreen** (your own idea, 2026-07-31) — shown before the login menu
      (`ShowLoginMenu()`, `mob/playerTemp/Login()`, `Main.dm`). Not detailed yet: art/
      logo, how long it holds, click/key-to-continue vs. timed auto-advance. Part of the
      Big Beautiful Update — no UI work until then (confirmed 2026-08-04).
- [x] **Basic pet system** (your idea, 2026-08-01). No taming mechanic — a GM
      double-clicking a wild, unowned `mob/enemy` gets an "Assign Pet" option
      (`ShowAssignPetMenu()`, `EnemyNPCs.dm`); picking a nearby player sets `owner` on
      that exact mob instance, in place. No separate pet type: any current or future
      monster species can become a pet this way, same stats/icon, no leveling system
      for pets yet. Owner double-clicks it to name it first, then double-click opens a
      Rename/Set Mode/Release menu (`ShowPetOwnerMenu()`). Set Mode picks `petMode`:
      **Aggressive** (hunts nearby unowned monsters while the area's in battle mode —
      the "helps you fight" behavior), **Sit** (stays put), **Wander** (deliberately
      reverts to full wild-monster AI, including targeting players — not guaranteed
      safe, by design), **Follow** (keeps pace with owner, default after assignment,
      never fights). One pet per owner for now (`ReleaseToWild()` bumps an old one if
      a player's given a new one). Compile: 0 errors, 0 warnings. Not playtested yet.
      - **Deferred, explicitly agreed not to build yet**: a Pet Battle tab showing
        stats/battle info; picking up a pet into inventory (if there's room); a dead
        pet not despawning — surviving as a "dead" inventory item you'd have to
        recover somehow (recovery mechanic not designed yet, your words: "need to
        figure out how to make it recover"); pet leveling; multi-pet roster/stable.
- [ ] Mounts (horse, wagon) — **deferred to a later version (2026-08-04 decision)**,
      not part of the current mechanics-first pass. Some concrete ideas dropped mid-conversation
      (2026-08-01), not designed/built yet: riding a horse increases move speed; you
      buy a horse and pick its color; equipping a wagon lets other players ride along
      by entering it, and in the OG this had no seat cap — literally infinite players
      could pile into one wagon ("acted literally like a clown car"). Fun follow-up
      idea (also just dropped, not committed to): make your own personal
      horse-and-wagon literally a tiny clown car, as a deliberate joke on that OG
      behavior, serving as both mount and wagon at once.
- [ ] Amulet/accessory balance pass
- [ ] **Graphical build-mode picker** (depends on Phase 10) — you specifically called
      this out as the area you most want to overhaul: the OG's plain text lists for
      `GMmaketurf`/`GMmakemob`/`GMmakeitem`/`GMmakestat`/`GMmakearea` are a slog to
      scroll through to find the right thing. Replace with something that shows the
      actual icon/sprite for each option instead of just a name. Still text-menu-only for
      v1 per the Scope Note — this is explicitly a later visual-polish target, not v1 work.
- [ ] Darken player/monster sprites at night, eventually dynamic lighting — OG's
      `GMdaynight` only re-skins world icons (turfs/objects), not mobs at all; this is a
      remake-only enhancement idea on top of that, not something to match from the OG
- [x] Language filter — **already done** (`TextFilter.dm`, word-boundary censoring +
      GM-toggleable strictness), can be removed from future QoL lists
- [ ] Player-created custom icons, usable on servers they host — idea floated alongside
      `GMswitchicon` (currently GM-only cosmetic flair), not committed to, see
      `GMCommandsReference.md`
