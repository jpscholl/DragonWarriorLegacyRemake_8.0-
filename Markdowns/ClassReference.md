# Class & Skill Reference — from original Dragon Warrior Legacy

Recovered from an old planning text file, cross-checked while playing the OG game
(BYOND 475.1080). Marked `[x]` = confirmed in-game, `[ ]` = still needs verification.
This is raw source data from the OG game, not final remake design — the remake's combat
is real-time (Zelda-style), not turn-based, so numbers may need rebalancing even once
they're all confirmed.

**Naming note (reversed 2026-08-09):** the OG game calls the 5th stat "Spirit" (`spt`/`spr`
in the raw notes below). This remake originally renamed it to `Luck` for period-correctness
(Luck is real Dragon Quest III/IV lineage, whereas "Spirit" isn't a real Dragon Warrior/Quest
stat at any point — see `TODOList.md` Open Questions for that original reasoning). **Reversed
back to `Spirit`** once testing found it also drives MaxMP in combination with Level (see
Stat effects below) — Spirit reads better than Luck for a stat that's now partly a magic
stat, not just crit/drop chance. The stat still keeps its crit-rate/item-drop role too, it's
not purely "Spirit" flavored even now. Code (`var/Spirit` and all its usages) already
updated to match.

**2026-08-23 — confirmed straight from OG DWL's own compiled files, not just play
testing.** A collaborator extracted the real string table from the OG's `.dmb` (world bin
v341, 4450 strings). Internal stat vars really are `str`/`agi`/`vit`/`int`/`spr` — but the
"Amulet of Spirit" item's own internal keyword is `luck`, sitting right next to it in the
data. The OG itself never fully settled this naming: the Help section text recovered in
this same dump literally includes its own disclaimer, word for word, "Note: the following
is outdated. Some information may be incorrect." So "go off the Help section" is right as
a priority call, but treat any single term in it (like "Luck") as one data point, not the
final word, when other OG data disagrees with it.

---

## Stat effects (confirmed)

- **Strength** — physical damage, carry capacity
- **Agility** — attack speed, casting speed, physical defense
- **Vitality** — max HP, HP regen rate, physical defense, magic defense
- **Intelligence** — max MP, MP regen rate, magic power, magic defense
- **Spirit** (was renamed `Luck` in this remake, reversed back — see Naming note above) —
  critical hit rate, **and max MP in combination with Level** (confirmed from the OG's
  own — self-admitted outdated — Help section; not yet cross-checked by actual play
  testing). Exact relationship to Intelligence's own MaxMP contribution unclear — likely
  both feed the same MaxMP formula rather than one overriding the other, needs
  confirming. Implemented as a placeholder `MP_PER_SPIRIT` coefficient in
  `RecalculateVitals()` (`Code/Player/StatsDatum.dm`), tune once confirmed.

**2026-08-23 — two of the lines above now have real data-file backing, not just the Help
section's word.** Straight from the OG's own extracted `.dmb` string table (see
`TODOList.md` Phase 6 for the full extraction context):
- No dedicated "Defense"/"def"-style stat variable exists anywhere in the OG's data.
  Real support for physical/magic defense being genuinely *derived* from Agility+Vitality
  and Vitality+Intelligence (per the bullets above), not a stat this list is missing.
- `crit_rate` is a real, separately tracked variable — not just something computed inline
  each hit — consistent with Spirit driving it as its own line item above.
- `HPfactor`/`MPfactor`/`HPregen`/`cur_HPregen`/`MPregen`/`cur_MPregen` all exist as real
  vars too, confirming "HP/MP regen rate" above is a genuine mechanic with real state
  behind it, not just flavor text. Not built anywhere in the remake yet — see `TODOList.md`
  Phase 6's new regen entry.

**Design decision (2026-08-09, your call, not OG behavior):** monster item-drop chance is
NOT tied to any player stat (OG's own drop mechanic, if any, not confirmed either way) —
instead it's a hidden flat rate defined per monster type, independent of the dropper's
Spirit/Luck. Not built yet; when it is, the rate lives on the monster definition
(`Code/Combat/NPCs/MonsterRoster.dm`), not derived from any player stat.

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
Int 1→2, Spirit 1→2 — all fit the formula exactly. Still need one data point in the 5–9
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
- Stat caps: Strength 60 (confirmed), Intelligence 150 (confirmed), Agility 60
  (placeholder), Vitality 80 (placeholder), Spirit 60 (placeholder) — real numbers
  now in code (`PlayerTemplate.dm`), filled in 2026-08-28 per the placeholder policy
  below
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
| [ ] | 24 | Meditate | 15 Spirit | unconfirmed |
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
- Stat caps: Strength 100 (confirmed), Vitality 100 (confirmed), Agility 60
  (placeholder), Intelligence 20 (placeholder, kept low — no Intelligence-gated
  skill anywhere in this table), Spirit 40 (placeholder)
- Default skills: Attack, Defend, Club

| Skill | Requirement | Level |
|---|---|---|
| Thornwhip | 8 Str | 4 |
| Rest | 8 Vit | 5 |
| Morningstar | 12 Str | 8 |
| Battleaxe | 16 Str | 12 |
| Flamesword | 18 Str | 15 |
| Falconsword | 20 Str | 17 |
| Chainsickle | 19 Str | 19 |
| IceSaber | 23 Str | 22 |
| SwordOfLethargy | 23 Str | 23 |
| Demonhammer | 26 Str | 27 |
| DragonKiller | 30 Str | 32 |

All levels/exact stat thresholds are placeholder (`SkillUnlocks.dm`, filled 2026-08-28
per the policy below) — only the governing stat was ever confirmed from the OG.

---

## Fighter

- Level cap: 99
- Stat caps: Strength 100, Agility 100, Vitality 80, Intelligence 40, Spirit 40
  (all confirmed)
- Default skills: Punch

| Skill | Requirement | Level |
|---|---|---|
| Jump | 7 Agi | 3 |
| Hide | 8 Agi | 4 |
| Rest | 8 Vit | 5 |
| Iron Claw | 9 Str | 7 |
| Dash | 11 Agi | 9 |
| Quakejump | 12 Agi | 12 |
| Fireclaw | 13 Str | 15 |
| Iceclaw | 13 Str | 17 |
| Goldclaw | 19 Str | 22 |

All levels/exact stat thresholds are placeholder (`SkillUnlocks.dm`, filled 2026-08-28
per the policy below) — only the governing stat was ever confirmed from the OG.

---

## Goof-off

- Level cap: 99
- Stat caps: Strength 80, Vitality 60, Intelligence 40, Spirit 40 (all confirmed),
  Agility 60 (placeholder)
- Default skills: Attack

Learning `Classchange` transforms this character into a Sage (DW3-style) — not a
character-creation option. Goof-off is the only class that learns `Classchange` as a
built-in leveled skill; **any other class** can reach Sage too, but needs to use a
**Dharma Scroll** item instead of learning the skill naturally. Sage gets its own skill
list — see the Sage section below.

| Skill | Requirement | Level |
|---|---|---|
| Club | 6 Str | 3 |
| Jump | 7 Agi | 4 |
| Magicknife | 8 Str | 6 |
| Thornwhip | 8 Str | 8 |
| Boomerang | 10 Str | 10 |
| Rest | 8 Vit | 12 |
| Quakejump | 12 Agi | 15 |
| Classchange | (none) | 25 (confirmed — the one real data point recovered for this class) |

All levels/exact stat thresholds besides Classchange's level are placeholder
(`SkillUnlocks.dm`, filled 2026-08-28) — Magicknife's own governing stat is itself an
educated guess (Strength), not confirmed.

---

## Pilgrim

- Level cap: 99
- Stat caps: Strength 80 (confirmed), Agility 60 (confirmed), Intelligence 100
  (confirmed), Vitality 60 (placeholder), Spirit 60 (placeholder)
- Default skills: Attack, Heal

| Skill | Requirement | Level |
|---|---|---|
| Club | 6 Str | 3 |
| Sleep | 9 Int | 5 |
| Upper | 10 Int | 6 |
| Increase | 11 Int | 7 |
| Infernos | 12 Int | 9 |
| Morningstar | 12 Str | 10 |
| Meditate | 15 Spirit | 12 |
| Lightsword | 14 Str | 13 |
| Healmore | 14 Int | 14 |
| Return | 14 Int | 15 |
| Battleaxe | 16 Str | 16 |
| Sleepmore | 16 Int | 17 |
| Infermore | 19 Int | 18 |
| SwordOfLethargy | 23 Str | 20 |
| Healmost | 20 Int | 22 |
| Stopspell | 20 Int | 24 |
| Healus | 21 Int | 26 |
| Vivify | 22 Int | 28 |
| Revive | 24 Int | 32 |
| Healusmore | 26 Int | 36 |

All levels/exact stat thresholds are placeholder (`SkillUnlocks.dm`, filled 2026-08-28
per the policy below) — only the governing stat was ever confirmed from the OG.

---

## Wizard

- Level cap: 99
- Stat caps: Strength 40, Agility 40, Vitality 60, Intelligence 100 (all confirmed),
  Spirit 60 (placeholder)
- Default skills: Attack, Fireball, Icebolt (Fireball/Blaze granted at creation —
  `GetStartingKit()`, `SkillUnlocks.dm` — so neither appears as a leveled unlock below)

| Skill | Requirement | Level |
|---|---|---|
| Lightning | 10 Int | 5 |
| Blazemore | 14 Int | 8 |
| Barrier | 17 Int | 10 |
| Meditate | 15 Spirit | 12 |
| Blizzard | 16 Int | 14 |
| Icespears | 13 Int | 16 |
| Boom | 18 Int | 18 |
| Thordain | 20 Int | 20 |
| Bang | 18 Int | 22 |
| Firevolt | 20 Int | 24 |
| Snowstorm | 23 Int | 27 |
| Firebane | 21 Int | 30 |
| Blazemost | 24 Int | 34 |
| Explodet | 28 Int | 38 |

All levels/exact stat thresholds are placeholder (`SkillUnlocks.dm`, filled 2026-08-28
per the policy below) — only the governing stat was ever confirmed from the OG.

---

## Sage

- Level cap: 99 (same as every other class)
- Reached via: Goof-off's `Classchange` skill, or any other class using a **Dharma
  Scroll** item (not yet built), or direct GM pick at creation
- **Skill list decided (2026-08-04, your call, no OG data recoverable)**: union of
  Hero + Wizard + Pilgrim's skill tables above — matches the OG help file's own
  flavor text ("A combination of Wizard and Pilgrim... learns both offensive and
  defensive magic, but is horrible in physical combat"), extended to include Hero's
  list too per your explicit decision. Built as a real merge in code
  (`mob/player/Sage/GetSkillUnlocks()`, `SkillUnlocks.dm`) rather than a hand-copied
  table, so it can never drift from whichever of the three source classes a shared
  skill (e.g. Meditate) actually comes from — ties keep the first source encountered,
  in Hero/Wizard/Pilgrim order. Unlike Hero/Wizard, Sage doesn't start with Fireball
  or Blaze, so both get their own added unlock entries (level 8/10 Intelligence,
  matching Hero's own numbers for each).
- Stat caps (all placeholder, filled 2026-08-28): Strength 40, Agility 40, Vitality
  60, Intelligence 150, Spirit 60 — squarely caster territory (low Str/Agi, high Int)
  per the confirmed "horrible in physical combat" flavor text; Intelligence matched
  to Hero's own 150 since Sage's list is a superset of Hero's.
- Default equipped skills (chosen 2026-08-28, `GetStartingKit()`): Attack (9), Blaze
  (3), Heal (7), Meditate (1), Return (0) — a rounded caster kit (damage, heal,
  MP-restore, escape), resolving what this doc used to leave as an open "pick 5 from
  the combined pool" decision.

## Still needed

- **Resolved 2026-08-28**: every stat cap and every skill's exact level/stat threshold
  that used to be marked `?` in this doc turned out to already be filled in with real
  placeholder numbers in code (`PlayerTemplate.dm`'s `capStrength`/etc.,
  `SkillUnlocks.dm`'s per-class `GetSkillUnlocks()` tables) — this doc had just never
  been synced back up after that placeholder-policy pass actually happened. All tables
  above now reflect the real in-code values; `SkillUnlocks.dm`'s own header comment
  (which still claimed everything was untouched Fireball-only test data) was corrected
  to match too. Still genuinely tunable, just not *missing* anymore.
- Confirmation on whether Stopspell/Firebane/Vivify (Hero) are genuinely stat *ranges*
  or a copy-paste error in the source notes — treated as a single value for now
  (`SkillUnlocks.dm` picked one number from each original range)
- "Master" class tier, Merchant/Thief classes, weapon-gated skills — **all explicitly
  deferred to a later version (2026-08-04 decision)**, not part of the current
  mechanics-first build pass. See `TODOList.md` Open Questions.
- Skill effects/damage/MP cost — not covered by this doc at all, only unlock conditions;
  same placeholder policy as everything else — real numbers come after mechanics work
  end-to-end and playtesting starts.
