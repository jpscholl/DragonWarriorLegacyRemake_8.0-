# Changelog

Version numbers are this remake's own (`GAME_VERSION`, [Code/Core/Main.dm](../Code/Core/Main.dm)),
independent of the "8.0" naming in the project's filenames, which refers to the
*original* game version being remade. Pre-1.0 SemVer: the middle number bumps for a
build pass that adds a feature set, the last number for a fix-only pass in between.
1.0.0 is reserved for "playable start to finish."

## [Unreleased]

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
- A real day/night clock driving the existing turf-swap machinery, plus the
  Status panel's Time line.
- Hazard terrain (lava, swamp).
- Whisper/Shout chat tiers, the player click menu (give gold/item/cast magic),
  quick item (numpad `*`/`-`), and quick-cast hotkeys (F5/F6/F7).

**Known gaps this pass did not close:** no item art (every consumable and amulet
borrows `key.dmi`), no HUD (still zero `screen_loc` usage), no hunger/thirst/
temperature/weather, no storage containers, and the monster `delay` column is
extracted but unapplied because its units are unknown.

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
