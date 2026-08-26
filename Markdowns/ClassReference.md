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
- Stat caps: Strength 60, Intelligence 150, Agility ?, Vitality ?, Spirit ?
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
- Stat caps: Strength 100, Vitality 100, Agility ?, Intelligence ?, Spirit ?
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
- Stat caps: Strength 100, Agility 100, Vitality 80, Intelligence 40, Spirit 40
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
- Stat caps: Strength 80, Vitality 60, Intelligence 40, Spirit 40, Agility ?
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
- Stat caps: Strength 80, Agility 60, Intelligence 100, Vitality ?, Spirit ?
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
| Meditate | Spirit | ? |

---

## Wizard

- Level cap: 99
- Stat caps: Strength 40, Agility 40, Vitality 60, Intelligence 100, Spirit ?
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
| Meditate | Spirit | ? |

---

## Sage

- Level cap: 99 (same as every other class)
- Reached via: Goof-off's `Classchange` skill, or any other class using a **Dharma
  Scroll** item (not yet built), or direct GM pick at creation
- **Skill list decided (2026-08-04, your call, no OG data recoverable)**: union of
  Hero + Wizard + Pilgrim's skill tables above — matches the OG help file's own
  flavor text ("A combination of Wizard and Pilgrim... learns both offensive and
  defensive magic, but is horrible in physical combat"), extended to include Hero's
  list too per your explicit decision. Stat caps/growth: placeholder, tune later —
  should land squarely in caster territory (low Str/Agi, high Int, since "horrible in
  physical combat" is confirmed OG flavor text).
- Default equipped skills: not decided yet, pick 5 from the combined pool once the
  combined skill table actually exists in code.

## Still needed

- Every class: full Agility/Vitality/Intelligence/Spirit stat caps where marked `?` above
  — **placeholder policy (2026-08-04)**: invent reasonable numbers now, all tunable
  later, don't block building on these.
- Soldier/Fighter/Goof-off/Pilgrim/Wizard/Sage: exact level + exact stat threshold per
  skill — **same placeholder policy**: assign a sane level/stat curve now (mirroring
  Hero's confirmed spacing/scaling where reasonable), revise once/if more OG data
  surfaces.
- Confirmation on whether Stopspell/Firebane/Vivify (Hero) are genuinely stat *ranges*
  or a copy-paste error in the source notes — treat as a range for now (placeholder)
- "Master" class tier, Merchant/Thief classes, weapon-gated skills — **all explicitly
  deferred to a later version (2026-08-04 decision)**, not part of the current
  mechanics-first build pass. See `TODOList.md` Open Questions.
- Skill effects/damage/MP cost — not covered by this doc at all, only unlock conditions;
  same placeholder policy as everything else — real numbers come after mechanics work
  end-to-end and playtesting starts.
