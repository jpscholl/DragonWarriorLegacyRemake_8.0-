# Changelog

Version numbers are this remake's own (`GAME_VERSION`, [Code/Core/Main.dm](../Code/Core/Main.dm)),
independent of the "8.0" naming in the project's filenames, which refers to the
*original* game version being remade. Pre-1.0 SemVer: the middle number bumps for a
build pass that adds a feature set, the last number for a fix-only pass in between.
1.0.0 is reserved for "playable start to finish."

## [Unreleased]

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
