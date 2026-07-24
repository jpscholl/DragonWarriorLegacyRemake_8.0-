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

---

## Phase 1 — Login & Character Creation (mostly done, polish remains)

- [x] Character select menu, 4 save slots, load/create/delete (`Code/UI/LoginMenu.dm`)
- [x] Create Character flow: Name → Class → Icon → Colors → Stats (`LoginMenu.dm`)
- [x] Class list: Hero, Soldier, Wizard (icons + palettes)
- [x] Zone-based recoloring (Main/Accent/Hair/Eyes) via `PaletteManager`/`ColorSwap.dm`
- [x] Stat allocation on creation (14 points, cap 10 per stat) via `ClickableStats.dm`
- [ ] Add remaining starting classes: Fighter, Pilgrim, Goof-off (6 playable classes total
      at launch: Hero, Soldier, Wizard, Fighter, Pilgrim, Goof-off)
- [ ] Sage is normally NOT a creation-time class choice — it's what any class becomes by
      changing into it (DW3-style), see `ClassReference.md`. Two paths: Goof-off learns
      `Classchange` as a built-in leveled skill; every other class needs to use a
      **Dharma Scroll** item instead (not yet built — no such item exists in our code).
      Needs its own mid-game class-swap flow covering both paths. Exception:
      sufficiently-permissioned GMs CAN pick Sage directly at creation, skipping both.
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
- [ ] "Master" class tier — GM-only, one Master variant per base class (Master Hero,
      Master Sage, etc., per-GM), higher stat caps and stronger moves than the normal
      version of that class. Generalizes/replaces the single "GM_Custom" class from the
      original design notes — it's a family, not one catch-all class.
- [ ] Merchant and Thief classes — these were added in later OG DWL versions you don't
      have access to, so there's no reference data to recover; stats/moves/unlock
      criteria for these two need to be designed from scratch, not documented from play
- [ ] Populate `DefaultIconColors` for Soldier/Wizard icons (only Hero's is done)
- [ ] Add a "lock in this character?" confirmation screen before `SaveCharacter()`
- [ ] Duplicate-name check across a ckey's own save slots

## Phase 2 — Core Player Data Model

- [x] Base stats on mob: STR/VIT/AGI/INT/Luck (Luck confirmed as the right pick — see
      Open Questions below)
- [x] Class, Level, Exp/Nexp, Gold, HP/MaxHP, MP/MaxMP, StatPoints (`PlayerTemplate.dm`)
- [x] Admin/Builder resolution on `client` (not mob) — hardcoded ckey lists, fresh every
      connect, savefile-tamper-proof by design (`AdminLevels.dm`)
- [ ] `isMuted` var + mute enforcement in chat verbs
- [ ] Real party data model (currently just a "None" stub). Confirmed from OG testing:
      a party has a name (prompted for on creation, e.g. "Aeon's Crew"), a
      sharing on/off toggle (`partyshare` — splits **experience** among the party; likely
      comes with an XP penalty/reduction per kill vs. solo, since fighting as a group
      makes kills easier — exact penalty formula not yet known), and a roster
      each showing icon + `Name(ckey)` + Class + Level. Party gets its own dedicated
      **tab** (`Status | Inventory | Battle | Actions | GM Commands | Party | Social`)
      that only appears once you're actually in a party — it's not a permanent tab.
      Confirmed party verbs (shown inside the Party tab itself, not Actions):
      `partykick`, `partyleave`, `partyrecruit`, `partysay`, `partyshare`, `partywho`.
      Also confirmed via `GMplayerstatus`: a party leader's status shows "Party: [name]
      Leader" (role appended after the party name), so `isPartyLeader` needs to surface
      in status displays, not just gate `partykick`-style permissions internally.
- [ ] Persistent Builder/Admin promotion (today: hardcoded test lists, needs recompile to
      change — fine for solo dev, blocks any real GM handing out Builder status later)
- [x] `StatsDatum.dm` resolved: not a dead stub anymore — holds `RecalculateVitals()`,
      called from `ClickableStats.dm` (after a stat point spend) and `LevelCheck()`
      (`CombatSystem.dm`, after a level-up). Derives `MaxHP`/`MaxMP` from Vitality/
      Intelligence + Level via placeholder `#define`d coefficients (tune later); a
      `hasMana` flag keeps 0-MP classes (Soldier) at 0 regardless of Intelligence.

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
      `EquipBasicAttack()` now runs on every character creation/load path so slot 9
      always has Attack. **Display now exists** (`StatPanels.dm`'s Battle tab): equipped
      skill per numpad slot + a "Free Skills -" list of known-but-unequipped skills
      (`GetEquippedSkillName()`/`IsSkillEquipped()`, `PlayerTemplate.dm`), matching the
      confirmed OG layout from a real screenshot. **Still missing**: the actual equip
      UI — drag-and-drop from Free Skills to a slot, confirmed working in the OG game
      (resolves the earlier open question about whether BYOND `stat()`-panel atoms
      support drag-and-drop at all — they do, at least on 475.1080). See
      `ClassReference.md`'s "Skills vs. equipped skills" note for the full mechanic.
- [ ] **Status panel field order/content** — confirmed complete from OG testing, current
      `StatPanels.dm` is missing several fields entirely: Name → Class → Level → Party →
      Hit Points → Magic Points → **GM Level** → **CPU** → Experience Points → Gold →
      Players online. Specifics:
      - Party: currently commented out in our code, needs the real party system first
      - GM Level / CPU: not in our code at all — CPU is `world.cpu` (tick load), staff
        debug info; still unresolved whether both should be staff-only or shown to
        everyone (question was asked earlier, not yet answered)
      - Experience Points: OG format is `current/next (X.X%)` **with one decimal place**
        (e.g. "10882/14011 (10.3%)"), not a whole-number percent — ours currently has no
        percent shown at all
- [ ] Players-online count in Status panel
- [ ] **Map-overlay HUD** (Level/HP/XP/MP in large pixel font along the bottom of the
      game view) — confirmed this exists in the OG as a `screen`-anchored overlay drawn
      over the map itself, not a stat panel; nothing like it exists in our code at all
      yet (`screen_loc`/HUD search turned up nothing). Spans the full view width and
      about 1 tile tall, exact tile count varies with window/zoom size. **Real UI work —
      out of scope for v1 per the Scope Note at the top of this file**, logged here only
      as reference for the later visual-polish pass.

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
- [ ] `CreateParty()` — **blocked on the party system existing first** (confirmed — no
      point stubbing this verb until party data model exists). Confirmed flow: opens a
      text-input prompt for the party name, then prints "[name] has been successfully
      created." and switches the creator into the new Party tab (see Phase 2 for the
      full data model this depends on).
- [x] `Give()` — implemented in `Inventory.dm`, same pattern as `Drop()` (item-level verb,
      `category = "Action"`, `src in usr`). Target picker uses `mob/player in view(5, usr)`
      to restrict to nearby players; reuses `PickUpItem()` so the "inventory full" check
      is shared with pickup/GM item creation.
- [ ] `Help()` — opens a scrollable popup window via `browse()` (confirmed from OG: title
      bar, close button, formatted HTML text, not the output pane or a stat panel).
      Content needs to be written fresh — even the OG's own doc admits it's outdated
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
- [ ] `ToggleWorldSay()` — mute/unmute world channel independent of using it yourself
- [ ] `ToggleMusic()` — new discovery, not in the original design notes at all. Likely a
      simple on/off for area background music, behavior not yet detailed.
- [ ] `MusicVolume()` — new discovery, not in the original design notes at all. Likely
      a player-side volume control for area background music, behavior not yet detailed.
- [ ] Wire real class/level/party into `Who()` (currently hardcoded stub fields)

## Phase 5 — Inventory & Items (core loop mostly done)

- [x] Pickup via Interact, right-click Drop, key/lock system (`Inventory.dm`, `Obj.dm`)
- [x] Fixed capacity placeholder (`BASE_INVENTORY_SLOTS = 8`)
- [ ] Real capacity formula (base + stat scaling) — **needs checking against the original
      game before implementing**, flagged as an open question in the code itself.
      Confirmed data point: level 1 Hero had capacity 9 (not the placeholder 8) — unclear
      yet whether that's a flat base or already includes stat scaling at level 1.
- [ ] "Quick Item" slot — OG Inventory tab shows a dedicated single-item hotkey slot
      below the item list ("Quick Item: Nothing"), separate from the general inventory.
      Not in our design at all yet — need to figure out how it's selected and what using
      it does (instant-use without opening inventory? tied to a keybind?) before building it.
- [ ] Item stacking
- [ ] Equipment system — **confirmed the OG has no weapon/armor equipment at all, only
      amulets** (stat boosts + some unspecified additional effects you don't remember —
      worth digging up if you run across them again). "Equip slots (weapon/armor/
      accessory)" was our own generic-RPG assumption, not something to port from the OG.
      `GMmakeitem` surfaced a partial item roster worth a dedicated reference doc
      eventually (same pattern as `ClassReference.md`/`GMCommandsReference.md`): key,
      paper, gems (red/green/blue/ring/drop/crown), amulets (strength/power/agility/
      speed), and more below the visible scroll — see `GMCommandsReference.md`'s
      `GMmakeitem` entry.
      **Your own expansion idea for the remake, not OG-derived**: add real weapons and
      armor as equipment (the OG never had them), and tie certain skills to owning/
      equipping a specific weapon — e.g. the "Ice Saber" skill would require actually
      having an Ice Saber weapon, possibly equipped, before it's usable. Could extend to
      weapon-general move sets, and unique/rare weapons as lootable rewards with their
      own exclusive skills. Parallel idea for casters: **spells could require purchasing
      a tome** before they're usable, same gating concept as weapon-locked skills but for
      Wizard/magic-focused classes instead of physical ones. This is a bigger design
      decision than the rest of Phase 5 — worth its own pass once basic equip slots exist
      at all.
- [ ] "Give" right-click option (hand an item to a nearby player) — already planned,
      deferred until Drop was solid
- [ ] Chest/drawer/pot storage interactions (turf types exist, `OnInteract()` logic doesn't)

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
      not to chase the exact formula. Useful as a rough feel/scale reference when tuning
      our own numbers, not as a value to match exactly.
- [x] Dodge mechanic (`CombatSystem.dm`'s `RollDodge()`, called from `TakeDamage()`) —
      new, not OG-derived (no such mechanic existed anywhere before). Agility-based
      chance to avoid a hit entirely, capped at `DODGE_MAX_PERCENT` (30%) so it's never
      guaranteed even at high Agility — all placeholder constants, tune by feel. Also
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
      (`Turfs.dm`), `door.wav` (`Obj.dm`), and `GMghostIconform`'s `spell.WAV`
      (`GMCommands.dm`). `levelup.wav` already had its own channel (2), so it was
      never part of this bug and was left alone.
- [x] Skill datum base + 2 skills (Attack, Fireball) (`SkillDatum.dm`)
- [ ] **Minor visual bug, found during an end-of-night code review, not yet tested**:
      Fireball's spell overlay (`PlayAttackAnimation()`, `CombatSystem.dm`) still uses
      a plain `/icon` added to `target.overlays`, unlike the melee weapon overlay right
      above it, which was switched to an `/image` with an explicit `.layer` earlier
      tonight specifically so it renders on top of the mob being hit instead of behind
      it. `/icon` has no `.layer` property, so the spell overlay likely has the same
      "renders behind the target" bug the melee one had before that fix — just
      unconfirmed, since no enemy casts spells yet and it hasn't come up in player
      testing. Give it the same `/image` treatment once it does.
- [ ] Status effects — **confirmed not implemented at all**, no poison/paralysis/buff/
      debuff system exists anywhere in the code. (The only "sleep" references anywhere
      are the unrelated bed-rest mechanic in `Turfs.dm`/`SmoothMovement.dm` — moving
      wakes you up, nothing to do with combat.) Already a confirmed dependency, not just
      a hypothetical: `ClassReference.md` lists a `Sleep` **spell** for Hero/Pilgrim/
      Wizard, presumably meant to inflict this status on enemies once it exists.
      **Confirmed OG scope**: Sleep is the *only* status effect in the OG — no burn,
      freeze, or shock/paralysis despite fire/ice/lightning-named spells existing
      (Fireball, Icebolt, Lightning, etc. are just damage, no elemental ailment attached).
      Sleep itself is a timed state: target is incapacitated until a duration expires.
      You want to eventually expand beyond just this one effect — worth designing as a
      real system (effect list, duration, stacking rules, cleanse/resist) rather than
      one-off hacks per skill, but Sleep alone is the only OG behavior to reference.
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
- [ ] Defend / Flee actions
- [ ] Skill/spell equip UI (drag or double-click to numpad slots — depends on Phase 3)
- [ ] **Elemental weakness/resistance system — expanded remake idea, not OG-derived.**
      The OG's elemental spells (Fireball, Icebolt, Lightning, etc.) are just flavored
      damage with no elemental interaction at all — no weaknesses/resistances tied to
      element on either side. You want elements to actually matter:
      - Per-enemy weaknesses/strengths against specific elements (the "per enemy" half
        of this was already planned)
      - **New idea**: players could also have an elemental affinity — floated choosing a
        strong/weak element pair at character creation, not confirmed as final, just an
        idea to weigh against simplicity for v1
      This is a bigger design question than a simple lookup table — needs deciding how
      many elements exist, whether player affinity is a creation-time choice or something
      earned/changed later, and how it interacts with the class/skill system.
- [ ] Monster roster — the *names* can likely be recovered from playing/documenting the
      OG. Confirmed so far via `GMglobalrespawn`/`GMkillallmonsters`'s monster-type
      pickers: cat, slime, dog, redslime, bat, fox, babble, skeleton, drakee, healer,
      snailslime, magician, ghost, wolf, magidrakee, reptile, arcticfox, panther,
      gremlin, acolyte, blazeghost, tiger, yeti, manowar — see `GMCommandsReference.md`.
      **Stats and balance for each one are not recoverable from play** and will need to
      be designed from scratch, same situation as the Merchant/Thief classes in
      `ClassReference.md`.
- [ ] **Munching Moler** — original boss idea (a big mole), named after the auto-generated
      codename of the combat-system planning session's plan file. Not from the OG, purely
      a remake original. No design details yet beyond "big mole boss."
- [ ] More skills per class (currently only 2 exist total)
- [ ] Party combat (shared XP, can't be fully designed until the party system exists)
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

## Phase 7 — Leveling System

- [x] Exp/Nexp/Level/StatPoints tracked, flat +10 Nexp / +5 StatPoints per level
- [ ] Real exp curve (currently flat, not scaling). **Balance goal**: the OG's leveling
      felt too fast, so aim slower than it — but explicitly not into grind territory
      either. The target is a middle ground (not too easy, not too grindy), not just
      "slower is better." Worth playtesting/tuning rather than picking a curve shape
      once and assuming it's right.
- [ ] Level cap
- [ ] Class-specific stat growth on level-up (right now growth is generic across classes)
- [ ] Skill/spell unlocks by level + stat threshold — **needs the "what does each class
      actually learn and when" data you flagged as still unknown**

## Phase 8 — World Systems

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
- [x] Doors with open/close/lock; sign/pot/bookcase/chest turfs exist as placeholders
- [x] **Per-area property scaffolding** — `Area.dm`'s base `area` type now has
      `battleModeOn`, `battleAllowsPvP`, `indestructibleMode`, and `weather` vars.
      `GMbattlemode` (`GMCommands.dm`, GM-Host tier) offers both: pick a specific area
      to toggle just that one, or pick "All Areas" to force every area's `battleModeOn`
      to the same value at once, disregarding each area type's own default
      (`battleModeGlobalOn`, `Main.dm`). `CombatSystem.dm`'s `InBattleArea()` actually
      checks it (`Attack`/`Fireball` in `SkillDatum.dm` both gate on it). Still needed:
      `GMcoopmode`/
      `GMindestructablemode`/`GMweather` verbs and wiring the terrain-damage system (once
      built) to check `indestructibleMode`/`weather`.
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
      Also just fixed a real bug here: `GMghostIconform` (`GMCommands.dm`) used to
      collide with this exact `invisibility = 1` tier, meaning any outdoor player
      could see a "hidden" ghosted GM — see the `GMghostIconform` entry in Phase 9.
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
      Whether specific equipment counters the damage is still unconfirmed.
- [ ] Roleplay Mode toggle — **low priority, not a straight port**. You weren't a big
      fan of how this played in the OG, so this is a candidate for redesign/expansion
      rather than faithful recreation whenever it gets picked up — no rush on it.
      World-wide, not per-area (unlike battlemode/coopmode/indestructiblemode above).
      OG behavior for reference: restricts chat to in-view only, appears to depend on
      Day/Night + Weather both existing, and brings in three survival mechanics not
      previously documented anywhere: Hunger, Thirst, and Sleep. See
      `GMCommandsReference.md`'s `GMroleplaymode` entry for the full OG breakdown.
- [ ] Bookcase/chest actual interaction logic (read messages / store items)
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
      - `playerstart` — a placeable **login** spawn marker; our `PLAYER_SPAWN` define in
        `Main.dm` is currently a single hardcoded `locate()`, not a placeable/multiple
        stat objects like the OG has
      - `playerspawn` — **confirmed distinct from `playerstart`**: the post-death respawn
        location specifically, not the initial login point
      - `boulderspawn` — likely a pushable-boulder puzzle mechanic, no equivalent exists
- [ ] Merchant/shop NPC system — `GMmakestat` surfaced `greatestamuletmerchant`,
      `foodmerchant`, `drinkmerchant` as shopkeeper NPC types. Not the Merchant *class*
      (see `ClassReference.md`) — this is a buy/sell vendor system, completely absent
      from our design so far, not just unbuilt

## Phase 9 — GM/Admin Tooling

- [x] 6-tier hierarchy: Player/Builder/Admin/GM-Host/Aeon's Crew/Aeon, resolved fresh
      from hardcoded data every connect (`AdminLevels.dm`)
- [x] `GMghostIconform`, `GMToggleProfanityFilter`, `GM_Create_Lockable` (`GMCommands.dm`)
      — **found and fixed a real invisibility bug in `GMghostIconform` while
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
- [ ] Lock down `DebugTools.dm` verbs (`DebugMovement`, `Test_Leveling`,
      `S_World`/`S_Sleep`/`S_Attack`/`S_Defend`, `Debug_ShowZoneColors`) — **currently
      unrestricted, no permission check at all**, worth gating or hiding before this is
      ever run on a shared server
- [ ] Admin verbs: `GMannounce`, `GMban`, `GMboot`, `GMmute`, `GMpwipe`, `GMunban`
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
- [ ] GM verbs: `GMblaze`, `GMcoopmode`, `GMglobalrespawn`,
      `GMkillallmonsters`, `GMlevelincrease`, `GMnamechange`, `GMplayerstatus`,
      `GMplaymusic`, `GMroleplaymode`, `GMsavelocation`, `GMswitchicon`, `GMweather`,
      `GMworldreboot`
- [ ] GM ability to designate Builder/Admin/GM status persistently (needs its own storage
      — separate from the tamper-proof hardcoded core tiers, since this is meant to be
      changeable at runtime by a Host/GM without a recompile)

## Phase 10 — Building/Map Tools (biggest net-new subsystem, do last)

- [ ] Three separate `GMmakeX` placement tools confirmed, all sharing one pattern (pick a
      type from a list, or "None" to exit build mode; picking a real type auto-enters
      build mode) and one shared brush mode (`GMmaketool`, see below) applying to all
      three, not just turfs:
      - `GMmakearea` — paints area instances (pairs with `GMseeareas`'s grid overlay)
      - `GMmaketurf` — paints turfs (the one originally in the design notes)
      - `GMmakemob` — places monsters from the `/mob/monster/*` roster
      **Every one of these build-mode list pickers needs a "None" entry to cancel out of
      build mode** — confirmed as a required pattern across all of them, not just
      incidental to the two we happened to test first.
- [ ] `SelectTurf()`/equivalent type-select — pick a turf/area/mob from a list to "hold"
      (the `GMmakeX` verbs above already cover this selection step)
- [ ] `GMmaketool` mode select — **confirmed 7 modes, not the original design notes' 5**
      (Move and Delete are new; "Fill" is now confirmed called "Block"):
      - Click — one instance per click
      - Drag — continuous placement while the mouse button is held
      - Block — rectangular region between first-click and release points (was "Fill"
        in the original design notes)
      - Line — click-drag constrained to a straight line
      - **Move** (new, not in original notes) — click-and-hold an existing obj/mob/item,
        drag to a new spot, release to relocate. Works on players/enemies too, not just
        scenery
      - Flood — paint-bucket, replaces the clicked tile and all contiguous matches
      - **Delete** (new, not in original notes) — clears the clicked tile, then
        immediately places the current selection there (clear-and-replace, not a plain
        delete)
      A white cursor square shows the current build target; selecting a mode confirms
      with "[Mode] tool selected."
- [ ] Save/upload custom maps (explicitly noted as a "maybe eventually" in your own notes
      — do not start this until the rest of Phase 10 is solid)

## Open Questions (blockers worth resolving before the phase that needs them)

- [x] **STR/VIT/AGI/INT/Luck vs STR/VIT/AGI/INT/Spirit** — resolved: Luck. Not a stat in
      DW1 itself (which only has Strength/Agility/HP/MP), but introduced in Dragon Quest
      III and carried through IV — fits the game's stated DW1-4 range. Spirit isn't a
      Dragon Warrior/Quest stat at any point.
- [ ] Per-class spell/skill lists and their learn requirements (level + stat combo) —
      **in progress, see `ClassReference.md`**: stat effects are confirmed, most
      per-skill level/stat thresholds still aren't (2 of ~90 entries confirmed so far)
- [ ] Real inventory capacity formula (base + stat scaling)
- [ ] Whether text/chat logging is wanted, and if so where it's stored
- [ ] **Stat point cost formula may not be a flat universal formula** — a real OG Battle
      tab screenshot (level-unknown Hero: Str 14, Agi 9, Vit 11, Int 9, Luck("Spirit") 9)
      shows Vitality/Intelligence/Luck matching the confirmed `2 + floor(stat/5)` formula
      exactly (4/3/3 points), but **Strength and Agility don't** — the screenshot shows
      6 and 5 points respectively, where the formula predicts 4 and 3. Currently still
      using the universal formula (`ClickableStats.dm`) since 2 data points against a
      formula already confirmed from 5 *different* data points isn't enough to
      confidently redesign it — but worth investigating whether Hero has higher costs
      specifically for its physical stats (Str/Agi), or whether cost also depends on
      something beyond the raw current stat value (e.g. character level).

## Quality of Life (no fixed phase — pull these in wherever they fit)

- [ ] Prevent other players from stealing loot drops
- [ ] General interface polish pass
- [ ] Character select screen polish
- [ ] Menu polish (creation flow, stat allocation, etc.)
- [ ] Pets
- [ ] Mounts (horse, wagon)
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
- [ ] Language filter — **already done** (`TextFilter.dm`, word-boundary censoring +
      GM-toggleable strictness), can be removed from future QoL lists
- [ ] Player-created custom icons, usable on servers they host — idea floated alongside
      `GMswitchicon` (currently GM-only cosmetic flair), not committed to, see
      `GMCommandsReference.md`
