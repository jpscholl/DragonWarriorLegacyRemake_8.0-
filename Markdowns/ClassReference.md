# Class & Skill Reference — from original Dragon Warrior Legacy

Recovered from an old planning text file, cross-checked while playing the OG game
(BYOND 475.1080). Marked `[x]` = confirmed in-game, `[ ]` = still needs verification.
This is raw source data from the OG game, not final remake design — the remake's combat
is real-time (Zelda-style), not turn-based, so numbers may need rebalancing even once
they're all confirmed.

**Naming note:** the OG game calls the 5th stat "Spirit" (`spt`/`spr` in the raw notes
below). This remake renamed it to `Luck` (see `TODOList.md` Open Questions — Luck is the
period-correct name going back to Dragon Quest III/IV, whereas "Spirit" isn't a real
Dragon Warrior/Quest stat at any point). Every `Spirit`/`spt`/`spr` reference below should
be read as `Luck` when this gets implemented.

---

## Stat effects (confirmed)

- **Strength** — physical damage, carry capacity
- **Agility** — attack speed, casting speed, physical defense
- **Vitality** — max HP, HP regen rate, physical defense, magic defense
- **Intelligence** — max MP, MP regen rate, magic power, magic defense
- **Luck** (OG: Spirit) — critical hit rate, monster item-drop chance

**Stat display notation**: the `base+X` format seen throughout (Battle tab, `GMplayerstatus`)
is base stat + bonus points from equipped items — confirmed OG UI behavior. **Your own
design choice for this remake, not confirmed OG behavior**: equipment bonuses can push a
stat *past* its normal class cap (e.g. Hero's Strength cap of 60), where the base stats
themselves cannot exceed the cap on their own.

**Decision**: only *what each stat affects* is recoverable from play (the list above).
The exact numeric scaling — how much attack/defense/HP/MP/crit% one point of a stat is
actually worth — is hidden internal math, same problem as the damage formula in
`TODOList.md` Phase 6. Not going to chase reverse-engineering this from the OG; it needs
to be designed from scratch alongside our own damage formula, tuned together by feel
once combat exists to test against (same bucket as Merchant/Thief stats and the monster
roster's stats — recoverable *names*, not recoverable *numbers*).

## Stat point allocation cost — LIKELY FORMULA (mostly confirmed)

`cost to raise a stat by 1 = 2 + floor(currentStat / 5)`

Backed by 5 real data points from a level 1 Hero's Battle tab: Str 10→4, Agi 4→2, Vit 4→2,
Int 1→2, Luck 1→2 — all fit the formula exactly. Still need one data point in the 5–9
range to fully confirm the bracket boundary, but this is a working formula now, not just
a guess.

## Skills vs. equipped skills — IMPORTANT DISTINCTION

A class's "default skills" (see per-class tables below) are what's **known** at that
level; some of those are also pre-equipped into the 5 Numpad slots (9/7/3/1/0) by
default, and any known skill can be dragged out to/from the **"Free Skills"** list on the
Battle tab to change what's equipped (drag-and-drop confirmed working — see TODOList.md).
The earlier "Zap sitting in Free Skills" example was staged on purpose to demo where
unequipped skills show up, not Zap's real default state — see corrected Hero row below.

---

## Hero

- Level cap: 99
- Stat caps: Strength 60, Intelligence 150, Agility ?, Vitality ?, Luck ?
- Default equipped slots (confirmed): Numpad 9 = Attack, Numpad 7 = Defend,
  Numpad 3 = Zap, Numpad 1 = Nothing, Numpad 0 = Nothing. Note this doesn't line up
  position-for-position with the "Attack, Defend, Nothing, Zap, Nothing" list from the
  original notes (which would put Zap at slot 1, not slot 3) — trust this confirmed
  mapping over that list's ordering.

| | Level | Skill | Requirement | Status |
|---|---|---|---|---|
| [x] | 3  | Heal | 6 Int | confirmed |
| [ ] | 4  | Icebolt | 7 Int | unconfirmed |
| [x] | 5  | Thornwhip | 8 Str | confirmed |
| [ ] | 7  | Lightning | 10 Int | unconfirmed |
| [ ] | 8  | Fireball | 8 Int | unconfirmed |
| [ ] | 10 | Blaze | 9 Int | unconfirmed |
| [ ] | 12 | Sleep | 9 Int | unconfirmed |
| [ ] | 14 | Upper | 10 Int | unconfirmed |
| [ ] | 16 | Healmore | 14 Int | unconfirmed |
| [ ] | 17 | Return | 14 Int | unconfirmed |
| [ ] | 18 | Icespears | 13 Int | unconfirmed |
| [ ] | 20 | Chainsickle | 19 Str | unconfirmed |
| [ ] | 21 | Thordain | 20 Int | unconfirmed |
| [ ] | 23 | Bang | 18 Int | unconfirmed |
| [ ] | 24 | Meditate | 15 Luck | unconfirmed |
| [ ] | 25 | SwordOfLethargy | 23 Str | unconfirmed |
| [ ] | 25 | Healus | 21 Int | unconfirmed |
| [ ] | 28 | Stopspell | 17–23 Int | unconfirmed (range?) |
| [ ] | 30 | Firebane | 18–24 Int | unconfirmed (range?) |
| [ ] | 32 | Ice Saber | 23 Str | unconfirmed |
| [ ] | 35 | DragonKiller | 30 Str | unconfirmed |
| [ ] | 38 | Vivify | 21–24 Int | unconfirmed (range?) |
| [ ] | 40 | ThunderSword | 35 Str | unconfirmed |

---

## Soldier

- Level cap: 99
- Stat caps: Strength 100, Vitality 100, Agility ?, Intelligence ?, Luck ?
- Default skills: Attack, Defend, Club

| Skill | Requirement | Level |
|---|---|---|
| Thornwhip | Str | ? |
| Rest | Vit | ? |
| Chainsickle | Str | ? |
| Morningstar | Str | ? |
| SwordOfLethargy | Str | ? |
| Battleaxe | Str | ? |
| IceSaber | Str | ? |
| DragonKiller | Str | ? |
| Flamesword | Str | ? |
| Falconsword | Str | ? |
| Demonhammer | Str | ? |

All levels/exact stat thresholds unconfirmed — only the governing stat is known so far.

---

## Fighter

- Level cap: 99
- Stat caps: Strength 100, Agility 100, Vitality 80, Intelligence 40, Luck 40
- Default skills: Punch

| Skill | Requirement | Level |
|---|---|---|
| Iron Claw | Str | ? |
| Fireclaw | Str | ? |
| Iceclaw | Str | ? |
| Goldclaw | Str | ? |
| Quakejump | Agi | ? |
| Jump | Agi | ? |
| Hide | Agi | ? |
| Dash | Agi | ? |
| Rest | Vit | ? |

---

## Goof-off

- Level cap: 99
- Stat caps: Strength 80, Vitality 60, Intelligence 40, Luck 40, Agility ?
- Default skills: Attack

Learning `Classchange` transforms this character into a Sage (DW3-style) — not a
character-creation option. Goof-off is the only class that learns `Classchange` as a
built-in leveled skill; **any other class** can reach Sage too, but needs to use a
**Dharma Scroll** item instead of learning the skill naturally. Sage gets its own skill
list (not yet documented).

| Skill | Requirement | Level |
|---|---|---|
| Classchange | ? | ? |
| Magicknife | ? | ? |
| Boomerang | Str | ? |
| Quakejump | Agi | ? |
| Jump | Agi | ? |
| Thornwhip | Str | ? |
| Club | Str | ? |
| Rest | Vit | ? |

---

## Pilgrim

- Level cap: 99
- Stat caps: Strength 80, Agility 60, Intelligence 100, Vitality ?, Luck ?
- Default skills: Attack, Heal

| Skill | Requirement | Level |
|---|---|---|
| Sleep | Int | ? |
| Upper | Int | ? |
| Infernos | Int | ? |
| Healmore | Int | ? |
| Return | Int | ? |
| Stopspell | Int | ? |
| Healus | Int | ? |
| Sleepmore | Int | ? |
| Vivify | Int | ? |
| Infermore | Int | ? |
| Increase | Int | ? |
| Healmost | Int | ? |
| Revive | Int | ? |
| Healusmore | Int | ? |
| Club | Str | ? |
| Morningstar | Str | ? |
| SwordOfLethargy | Str | ? |
| Lightsword | Str | ? |
| Battleaxe | Str | ? |
| Meditate | Luck | ? |

---

## Wizard

- Level cap: 99
- Stat caps: Strength 40, Agility 40, Vitality 60, Intelligence 100, Luck ?
- Default skills: Attack, Fireball, Icebolt

| Skill | Requirement | Level |
|---|---|---|
| Blaze | Int | ? |
| Lightning | Int | ? |
| Icespears | Int | ? |
| Bang | Int | ? |
| Blazemore | Int | ? |
| Firebane | Int | ? |
| Thordain | Int | ? |
| Blizzard | Int | ? |
| Boom | Int | ? |
| Firevolt | Int | ? |
| Blazemost | Int | ? |
| Snowstorm | Int | ? |
| Barrier | Int | ? |
| Explodet | Int | ? |
| Meditate | Luck | ? |

---

## Still needed

- Every class: full Agility/Vitality/Intelligence/Luck stat caps where marked `?` above
- Soldier/Fighter/Goof-off/Pilgrim/Wizard: exact level + exact stat threshold per skill
  (currently only know *which* stat governs each skill, not the level or the number)
- Confirmation on whether Stopspell/Firebane/Vivify (Hero) are genuinely stat *ranges*
  or a copy-paste error in the source notes
- Sage's own skill list — normally reached only via Goof-off's Classchange, but
  sufficiently-permissioned GMs can pick Sage directly at character creation; needs its
  own research pass either way
- "Master" class tier — GM-only, one Master variant per base class (Master Hero, Master
  Sage, etc.), each with higher stat caps and stronger moves than the normal version.
  Replaces the single "GM_Custom" class from the original design notes with a per-class
  family instead — not documented here yet
- Merchant and Thief classes — added in later OG DWL versions you don't have access to,
  so there's no source data to recover here. These need to be designed from scratch
  (stats, default skills, unlock tables) rather than documented from play, unlike every
  other class in this file.
- Skill effects/damage/MP cost — not covered by this doc at all, only unlock conditions
