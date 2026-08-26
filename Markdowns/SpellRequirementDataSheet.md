# Spell/Skill Requirement Control Test — Data Collection Sheet

Goal: 5 OG characters per class, each given a **different stat allocation strategy**
(e.g. dump-Int, dump-Str, balanced, dump-secondary-stat, etc.), leveled up while
watching the skill list. Varying the spread across 5 characters is what lets you tell
whether a skill's requirement is really Level-only, Stat-only, or Level+Stat combined
— a single character can't distinguish those (both climb together).

For each new skill that appears, log: which character, what Level they were, and what
the *governing stat's* current value was (the "Requirement" column in
`ClassReference.md` already names which stat that is for most skills, even where the
threshold is still `?`). Note anything that unlocked out of the expected order too —
that's a sign the real requirement is different from what's predicted below.

**Predicted** columns below are pulled straight from `ClassReference.md`/
`GMCommandsReference.md`'s design-notes source — treat them as a hypothesis to confirm
or overturn, not ground truth.

---

## Hero

Predicted (from `ClassReference.md`, most already have exact numbers from prior testing):

Level 3 Heal (6 Int) · Level 4 Icebolt (7 Int) · Level 5 Thornwhip (8 Str) ·
Level 7 Lightning (10 Int) · Level 8 Fireball (8 Int) · Level 10 Blaze (9 Int) ·
Level 12 Sleep (9 Int) · Level 14 Upper (10 Int) · Level 16 Healmore (14 Int) ·
Level 17 Return (14 Int) · Level 18 Icespears (13 Int) · Level 20 Chainsickle (19 Str) ·
Level 21 Thordain (20 Int) · Level 23 Bang (18 Int) · Level 24 Meditate (15 Spirit) ·
Level 25 SwordOfLethargy (23 Str) · Level 25 Healus (21 Int) ·
Level 28 Stopspell (17–23 Int, range unconfirmed) ·
Level 30 Firebane (18–24 Int, range unconfirmed) · Level 32 Ice Saber (23 Str) ·
Level 35 DragonKiller (30 Str) · Level 38 Vivify (21–24 Int, range unconfirmed) ·
Level 40 ThunderSword (35 Str)

### Test characters

| Char | Stat strategy | Str | Agi | Vit | Int | Spirit |
|---|---|---|---|---|---|---|
| 1 | dump-Str | 10 | 4 | 1 | 1 | 1 |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |

Char 1 baseline, Level 1: HP 57, MP 19. Default moveset at Level 1: Attack, Defend,
Zap (Zap present at Level 1 before any predicted skill unlock — likely a universal
starter move, not a class-gated skill; watch whether other classes/chars also start
with it).

Char 1, Level 5 snapshot: HP 84, MP 29, Gold 440, Exp 389/637 (13.3% — see `TODOList.md`
Status panel note, the % doesn't match the raw ratio, still unsolved). Current stats
10/4/2/9/3 (Str/Agi/Vit/Int/Spirit) — no longer matches the creation row above since
stat points have been spent since (started dumping into Int for the spell-unlock test,
some into Vit/Spirit too). Creation row above stays as the build's starting point;
this is where it's actually at now.

### Unlock log

| Char | Level | Skill unlocked | Governing stat value at unlock | Matches prediction? |
|---|---|---|---|---|
| 1 | 4 (seen at, exact unlock level not pinned down) | Heal — **possible, not confirmed** | Int 6 | Int value matches prediction (6 Int) exactly; Level seen at (4) is one later than predicted (3) — could be the real threshold, or Heal already unlocked at Level 3 and just wasn't checked till Level 4. Needs a char that checks the skill list level-by-level to pin down which. |
| 1 | 4 | Icebolt | Int 8 | Level matches prediction exactly (4). Int is 8 vs. predicted 7 — close but not exact; same "wasn't checked earlier" caveat as Heal above could explain the 1-off, or 8 is the real threshold. Both Heal and Icebolt landing at the same checked level (4) with Int climbing 6→8 in between makes it hard to tell if they unlock at genuinely different levels or the same one — needs a char checked every level, not just spot-checked. |
| 1 | 5 | Thornwhip | Str 10 (unchanged since creation, dump-Str build) | Level matches prediction exactly (5). Str's been sitting at 10 since Level 1 — well above the predicted 8 Str gate — so this data point alone can't confirm 8 Str is the real threshold, only that 10 Str + Level 5 is sufficient. Genuine level-gate confirmation this time though, since unlike Heal/Icebolt this char has been checked level-by-level and Thornwhip wasn't available before Level 5. Still need a lower-Str char to pin the actual Str threshold down between 8 and 10. |
| 1 | 5 | Thornwhip (2nd confirmation, 2026-08-18) | Str 13 | Second run, same Level 5 gate, this time at Str 13 rather than 10 — still well clear of the predicted 8 Str threshold, so still can't pin the exact Str gate, but reinforces Level 5 as the real gate regardless of exactly how high Str is above it. This run has been logged level-by-level too (see `CombatDataSheet.md`'s combat-log session, same date) — Level 1 (Str 10/Agi 4) → Level 2 (Str 11/Agi 5) → Level 3 (Str 12/Agi 5) → Level 5 (Str 13), Thornwhip confirmed present by Level 5, still needs a Level 4 check to see if it's actually available one level earlier. |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## Soldier

Predicted: only the governing stat is known, no level/threshold data yet — Thornwhip,
Chainsickle, Morningstar, SwordOfLethargy, Battleaxe, IceSaber, DragonKiller,
Flamesword, Falconsword, Demonhammer (all Str) · Rest (Vit).

### Test characters

| Char | Stat strategy | Str | Agi | Vit | Int | Spirit |
|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |

### Unlock log

| Char | Level | Skill unlocked | Governing stat value at unlock | Notes |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## Wizard

Predicted (Int-governed unless noted): Blaze, Lightning, Icespears, Bang, Blazemore,
Firebane, Thordain, Blizzard, Boom, Firevolt, Blazemost, Snowstorm, Barrier, Explodet
(all Int) · Meditate (Spirit). No level/threshold numbers yet.

### Test characters

| Char | Stat strategy | Str | Agi | Vit | Int | Spirit |
|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |

### Unlock log

| Char | Level | Skill unlocked | Governing stat value at unlock | Notes |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## Fighter

Predicted: Iron Claw, Fireclaw, Iceclaw, Goldclaw (Str) · Quakejump, Jump, Hide, Dash
(Agi) · Rest (Vit). No level/threshold numbers yet.

### Test characters

| Char | Stat strategy | Str | Agi | Vit | Int | Spirit |
|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |

### Unlock log

| Char | Level | Skill unlocked | Governing stat value at unlock | Notes |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## Pilgrim

Predicted: Sleep, Upper, Infernos, Healmore, Return, Stopspell, Healus, Sleepmore,
Vivify, Infermore, Increase, Healmost, Revive, Healusmore (Int) · Club, Morningstar,
SwordOfLethargy, Lightsword, Battleaxe (Str) · Meditate (Spirit). No level/threshold
numbers yet.

### Test characters

| Char | Stat strategy | Str | Agi | Vit | Int | Spirit |
|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |

### Unlock log

| Char | Level | Skill unlocked | Governing stat value at unlock | Notes |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## Goof-off

Predicted: Classchange (?, becomes Sage), Magicknife (?) · Boomerang (Str) ·
Quakejump, Jump (Agi) · Thornwhip, Club (Str) · Rest (Vit). No level/threshold numbers
yet — Classchange/Magicknife's governing stat isn't even known.

### Test characters

| Char | Stat strategy | Str | Agi | Vit | Int | Spirit |
|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |

### Unlock log

| Char | Level | Skill unlocked | Governing stat value at unlock | Notes |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## Monster AI observations (separate from spell requirements, log here anyway)

Space for anything like the healer-slime-heals-healer-slime finding — what monster
type, what triggered it (ally HP%? proximity? both nearby?), whether it happened more
than once, whether other spellcasting monster types (magician, acolyte, ghost,
blazeghost per the roster) show equivalent behavior for damage spells instead of
healing. See `TODOList.md` Phase 6 for the open item this feeds into.

| Monster type | Observed behavior | Trigger (if known) | Notes |
|---|---|---|---|
| Healer (OG proper name, confirmed 2026-08-18 — was called "healer slime"/"healslime" in earlier notes) | Cast heal on itself or a wounded monster in sight, for **52 HP** (amount confirmed 2026-08-18, `CombatDataSheet.md`) | confirmed — self OR nearby-wounded-ally, not just self | first sighting, 2026-08-10, no numbers yet. Amount now confirmed: 52. Same monster as the strong-end entry in `CombatDataSheet.md`'s difficulty-ordering list. Already has a real mob type + icon (`mob/enemy/healer`, `healer.dmi`) and is back in the trimmed roster. The self/ally-heal behavior itself is still unimplemented in code (no monster spellcasting exists yet) — this is real OG data waiting for that system to get built. |
| Acolyte | Casts `Increase` (physical defense buff) on itself | on sighting the player | 2026-08-10 — self-buff on aggro, not ally-targeted like the healer slime case; confirms monster spellcasting covers at least 2 different patterns (ally-heal, self-buff-on-aggro) |
| Magician (and other casters, per user recollection, unconfirmed by fresh testing yet) | Has a real MP pool, no in-combat regen — once drained, falls back to physical attacks for the rest of the fight | MP hits 0 | 2026-08-10 — from memory of OG play, not yet re-confirmed this session; also recalled: caster-type monsters prefer to keep range and cast rather than close to melee, when they have a projectile spell available |
| Varies by species (which ones, TBD) | Some monsters noticeably more "hyperactive and aggressive" than others — faster to act, more relentless | species-based, not yet isolated to a specific stat/flag | 2026-08-10 — general impression from live testing, can't yet name which species or pin down exactly what's different (reaction speed? aggro range? attack frequency? all of the above?); needs a side-by-side comparison to characterize |
|  |  |  |  |

---

## Special monster archetypes

Not AI behavior — stat/defense archetypes that need their own mechanics, not just a
different stat block. Log findings here.

| Archetype | Traits | Notes |
|---|---|---|
| Metal monsters (metal slime etc., DQ-series-famous) | Very low HP, high dodge rate, heavy flat damage reduction — but a **critical hit bypasses both** (ignores the dodge roll and the damage reduction), so a crit probably one-shots them | 2026-08-10, from memory, unconfirmed by fresh testing. Two things this needs that don't exist in code yet: (1) no crit mechanic exists anywhere currently — `RollDodge()`/`TakeDamage()` (`CombatSystem.dm`) have no crit roll or crit-bonus-damage path at all (the "crit ~42" number in `TODOList.md`'s Phase 6 is an OG *sample data point*, not something the remake calculates); (2) no per-monster dodge-rate or damage-reduction override — `RollDodge()` is Agility-based for every mob uniformly, and there's no flat "% damage reduction" stat on `mob/enemy` the way `isDefending` gives players one. Metal-monster behavior needs both to exist before it's buildable, and a crit path would need an explicit "bypasses dodge and reduction" flag/branch, not just extra damage. |
|  |  |  |

---

Send data back over as you collect it (even partial tables/a couple rows are useful)
and I'll look for the pattern — same process as `CombatDataSheet.md`.
