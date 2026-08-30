# Changelog

Version numbers are this remake's own (`GAME_VERSION`, [Code/Core/Main.dm](../Code/Core/Main.dm)),
independent of the "8.0" naming in the project's filenames, which refers to the
*original* game version being remade. Pre-1.0 SemVer: the middle number bumps for a
build pass that adds a feature set, the last number for a fix-only pass in between.
1.0.0 is reserved for "playable start to finish."

## [Unreleased]

### 0.9.0 build pass — 2026-08-28
Autonomous pass closing gaps flagged in `RemakeVsOGStructure.md`/`TODOList.md`. All of
it is compile-verified (DM 516.1687) and **none of it is playtested**.

**Combat feedback HUD — the top-ranked remaining gap, now closed**
- Bottom-of-screen Level/HP/MP/EXP display (`Code/UI/HUD.dm`, new file), built from
  art that already existed but had zero screen-object code behind it
  (`meter.dmi`/`magicmeter.dmi`/`expmeter.dmi`/`text.dmi`).
- Floating combat numbers on hit/dodge/heal (`numbers.dmi`): red damage, yellow crit,
  green heal, "miss" on a dodge.
- Floating HP/MP bars above any mob in view, players and enemies alike.
- Every pixel offset/glyph width is a placeholder — compiles and runs, not pixel-tuned.

**Items**
- Item stacking: consumables merge into an existing stack (cap 99, placeholder)
  instead of eating a new inventory slot each pickup; display picks up "x[amount]".
- Carried items (consumables, amulets — including worn state, keys — including their
  engraved name) now survive a save/load round-trip; previously only stats/skills did.
- 7 new utility amulets (Safe Passage, Protection, Barrier, Wakefulness, Wealth,
  Experience, Luck) wired to real mechanics — hazard immunity, permanent defense/magic
  defense, Sleep immunity, gold/EXP % bonus, drop-rate bonus.
- Amulets wired to real art (`amulets.dmi`) instead of borrowing the key sprite; bonus
  values dialed down after a design pass (stat points matter a lot in this system).
- New GM_MakeItem command: spawns any consumable/amulet directly into inventory.

**Corrected against confirmed OG data**
- StatPoints per level-up: 6, not 5 (Hero1 test data).
- Experience Points now shows the OG's confirmed "X/Y (Z.Z%)" format, one decimal —
  previously no percent at all.
- Status panel gained GM Level and CPU fields in the confirmed OG position (between
  Magic Points and Experience Points).
- Bookcase is now a real player-writable shared message board (OG string 1687), not
  an inert placeholder — write or read messages left by anyone who's interacted with
  that bookcase. Session-only, same as chest/drawer/pot contents.

**Character creation**
- Duplicate-name check across a ckey's own save slots.
- "Lock in this character?" confirmation before the save actually commits.
- Soldier (`dw3guard.dmi`) and Wizard (`dw3malewizard.dmi`) now have real default
  recolor data, sampled by extracting actual pixel colors from the sprite files —
  each only has ONE genuine customizable color in the source art (unlike Hero's
  sprite, which encodes Hair/Eyes/Main as three distinct-but-similar shades), so only
  "Main" is populated for these two; Hair/Eyes/Accent are honestly absent rather than
  invented.

**Monster roster — 10 → 24**
- Added every monster name confirmed to exist in the OG (via the GM type pickers)
  that wasn't already built: Magician, Snail Slime, Ghost, Wolf, Magidrakee, Reptile,
  Arctic Fox, Panther, Acolyte, Gremlin, Blazeghost, Tiger, Man O' War, Yeti — all
  real OG stat data from `OGMonsterBaseStats.tsv`, same confidence level as the
  original 10, not placeholders. `GM_MakeMob`/`GM_KillMonsters`/`GM_GlobalRespawn`
  all enumerate `/mob/enemy` subtypes dynamically, so no picker wiring was needed.
- Two confirmed-but-still-unbuilt AI behaviors flagged in-line rather than faked:
  Acolyte's self-buff-on-aggro and casters (Magician/Magidrakee/Gremlin) kiting
  instead of closing to melee — both need a real `AILoop()` redesign, logged as
  still open.
- Also gated GM/Debug tools that had zero access control, fixed a `GM_LevelIncrease`
  StatPoints mismatch (5→6, same fix as `LevelCheck()`), and confirmed the entire
  Phase 10 GM Building System (all 7 tool modes) and the 6 night-variant areas were
  already built in a prior pass — `TODOList.md` had gone stale on both.

**Five more confirmed GM verbs built** (`GMCommandsReference.md`'s specs)
- `GM_CoopMode` — per-area/global player-vs-player damage toggle, enforced in
  `TakeDamage()`; GM-tier targets stay exempt from the protection.
- `GM_PlayerStatus` — full character-sheet dump (stats with equip bonus, inventory,
  every known skill), one player or all at once.
- `GM_PlayMusic` — sets an area's (or every area's) background music at runtime,
  pushed live to whoever's already standing there.
- `GM_SaveLocation` — world-wide toggle to spawn returning characters at their exact
  last-saved position instead of the normal spawn point.
- `GM_SwitchIcon` — cosmetic-only icon switching from the `Mob Icons/Custom GM`
  files that already existed with nothing pointing at them.
- `GM_GlobalRespawn` — a full named monster-spawn management system
  (`datum/RespawnDefinition`): Name/Area/Monster type/Z level/Count, Modify/Delete on
  an existing definition. Both confirmed quirks preserved: one-shot spawn (never
  replenishes), and a non-matching Area+Z level combo silently spawns nothing.
  Session-only, same as every other piece of world-editing state — no serializer
  exists yet to survive a reboot.
- Also confirmed Phase 10 (the entire GM map/building tool system — all 7 placement
  modes, mouse-driven) and the 6 night-variant areas were already fully built in an
  earlier pass; `TODOList.md` had just never been updated to say so.

**Dharma Scroll** — the confirmed non-Goof-off path to Sage
(`obj/item/consumable/dharmaScroll`, `Inventory.dm`). Reuses the exact same
`RunSageReclassFlow()`/`BecomeSage()` flow Goof-off's `Classchange` skill already
calls, same level-25/unequip-everything gates. No drop source or merchant sells it
yet — spawn via `GM_MakeItem` for testing.

**Documentation sync pass** — a lot of `TODOList.md`/`ClassReference.md` had drifted
out of date across earlier sessions (its own stated risk: "a planning aid, not a
source of truth"). Corrected against the actual code rather than assumed:
- `ClassReference.md`'s every stat-cap and skill-unlock `?`/"unconfirmed" turned out
  to already be filled with real placeholder numbers in code (`PlayerTemplate.dm`,
  `SkillUnlocks.dm`) — the doc had just never been synced back up. All 7 classes'
  tables now show the real in-code values. `SkillUnlocks.dm`'s own header comment
  (still claiming Fireball-only placeholder data) corrected too.
- `TODOList.md`: ~15 checkboxes flipped from stale `[ ]` to `[x]` for features already
  built in earlier sessions — Fighter/Pilgrim/Goof-off classes, inventory capacity
  formula, HP/MP regeneration, Sleep status effect, level cap, per-class skill-unlock
  tables, Quick Item slot, Give/storage interactions, skill equip UI, `ToggleWorldSay`,
  chat logging. None of these needed new code, just an accurate checkbox.

**Known gaps this pass did not close:** item art for consumables/lava (no matching
assets exist), the `/stat` scenery kit, a world serializer, the monster `delay`
column's unknown units, caster AI (kiting/self-buff), `GMblaze`/`GMroleplaymode`/
`GMweather`, `Help()`'s real content, `ToggleMusic()` — all still open per
`RemakeVsOGStructure.md`/`TODOList.md`.

### 0.8.0 build pass — 2026-08-25
The first pass driven by real data from the original `.dmb` rather than inference.
All of it is compile-verified (DM 516.1687) and **none of it is playtested**.

**Corrected against confirmed OG strings**
- Death EXP penalty 25% → 5%. The gold penalty stays but is now labelled a remake
  addition — the 4450-string table has no gold-loss message or variable at all.
- Respawn inverted to match the OG: automatic after 60s, numpad 5 for immediate
  respawn with no minimum wait (previously a 10s minimum and no auto-respawn).
- Mute is now a shadow mute — the target is never told, keeps seeing their own
  chat, and GMs get a `(Muted)` copy.
- WorldSay/WorldEmote gained the OG's 1-second rate limit, plus a worldsay toggle.
- Classchange gained its level 25 gate and now resets to level 1 as the OG's own
  confirmation prompt promises.

**Combat**
- Real per-monster stats replace the two flat placeholder tiers. Monster elements
  now feed the previously-inert elemental system.
- Monster spellcasting and the Healer's ally-heal AI (the OG's `HealCheck`).
- Real buffs: Upper/Increase/Barrier were stand-ins that quietly healed HP; they
  are timed status effects now.
- First-hit kill credit (`first_hit`) — rewards go to whoever struck first.
- Sleep now breaks when the sleeper is hit.
- Passive HP/MP regeneration, driven by Vitality/Intelligence per the help file.

**The missing half of the game loop**
- Monster item drops, and consumables to drop (medical herb, herbal tea, leaf of
  the world tree, wing of wyvern).
- Merchants with Buy/Sell — Gold finally has somewhere to go.
- Amulets (15 of 23, max 2 worn), and effective-stat plumbing so equipment
  contributes without ever mutating the underlying stats.

**World and interface**
- A day/night clock driving the existing turf-swap machinery, plus the Status
  panel's Time line. **Flagged after this pass**: its only real payoff is RP
  mode, which is explicitly out of scope right now (see the priorities note
  below), and its cadence (one game hour per real minute — a full cycle every
  24 real minutes) is too fast even setting that aside. Shipped and compiling,
  but should not be treated as tuned, and a future RP-mode pass is the more
  natural place for this system than a standalone build item.
- Hazard terrain (lava, swamp).
- Storage containers (drawers, chest, pot) — Store/Take/Leave, using the OG's
  own prompts. Contents are not saved; there's no world serializer yet.
- NPC dialogue: Day/Night Speech, Stand/Walk, and facing, set at creation.
- Thornwhip's real 3-tile line attack (was a plain single-tile hit at the wrong
  damage multiplier — see its own file comment for the two live-OG-test
  confirmations this corrects).
- Whisper/Shout chat tiers, the player click menu (give gold/item/cast magic),
  quick item (numpad `*`/`-`), and quick-cast hotkeys (F5/F6/F7).

**Known gaps this pass did not close:**
- **Item art** for consumables and amulets — they still borrow `key.dmi` and
  are visually indistinguishable from each other and from a key. **Correction**:
  an earlier draft of this note claimed the HUD/meter/damage-number/paper art
  was ALSO missing — it exists (`meter.dmi`/`expmeter.dmi`/`magicmeter.dmi`/
  `swimmeter.dmi`, `numbers.dmi`, `paper.dmi`, all under `UI & Effects/`), just
  not yet wired to code. Item/amulet/lava art is the real, still-open gap.
- No HUD wired up (still zero `screen_loc` usage) — art for it exists (above),
  the screen-object code doesn't.
- No hunger/thirst/temperature/weather — and per the priorities note above,
  these are RP-mode-specific too, so likely belong with the day/night clock in
  a future RP-mode pass rather than as standalone items.
- The monster `delay` column is extracted but unapplied because its units are
  unknown.

## 0.7.0 — 2026-08-08
GM moderation tools and area-based spawn markers.
- `GM_Ban`/`GM_Boot`: combined ban+unban target picker, per-character-slot bans,
  boot-without-saving. `GM_ToggleMultiLogin` for testing with two clients.
- Profanity filter now wired into every verb that sends text to other players (signs,
  lockable names, NPC names), not just chat.
- Replaced the hardcoded spawn coordinate with placeable World Login Point / Respawn
  Point markers (`GM_CreateObj`), visible only through `GM_SeeAreas`' overlay.
- Fixed a bug where disconnecting never deleted the mob object, letting a reconnect
  silently reattach to a stale mob instead of running the login flow.

## 0.6.1 — GM Tools & Interface pass
Verb renames, expanded `GM_CreateObj`, build tool fixes, rebuilt stairs.

## 0.6.0 — Mechanics-first build pass
Classes, skills, monsters, areas, and GM build tools.

## 0.5.0 — Pet system
GM-assignable pets with Follow/Sit/Wander/Aggressive modes.

## 0.4.1 — Audio and filter pass
Persistent per-player Master/Music/SFX volume control, plus leetspeak-folding for the
profanity filter.

## 0.4.0 — Skills and party groundwork
Skill-learning framework, drag-and-drop equip UI, party stub, GM log toggle, and a
spawn-crash fix.

## 0.3.0 — Combat system rebuild
Combat system rebuilt end-to-end: skills, enemy AI, GM tooling, and a pile of bugfixes.

## 0.2.0 — Project documentation
Initial README for the game remake project.

## 0.1.0 — Login and character creation prototype
Login menu, icon customization, stat allocation, and the early refactors that got
naming and structure into shape.
