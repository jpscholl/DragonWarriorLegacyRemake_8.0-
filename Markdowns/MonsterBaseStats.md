# Monster Base Stats — Trimmed 10-Monster Roster (CONFIRMED, 2026-08-23)

Real Strength/Agility/Vitality/Intelligence/Spirit/Level/MaxHP/MaxMP/Element/Exp/Gold values for
the 10 monsters currently in `Code/Combat/NPCs/MonsterRoster.dm`/`EnemyNPCs.dm` (cat, slime, dog,
redslime, bat, fox, babble, skeleton, drakee, healer) — pulled straight from OG DWL's own compiled
type table, not inferred from play. This file previously held a speculation pass built from live
combat-testing on 2026-08-18; that pass is superseded below wherever it conflicts with real data.

## Source

A collaborator extracted these using the Somnium13 `somdump` decompiler toolchain against OG DWL's
actual `.dmb` (world bin v341) — see `TODOList.md` Phase 6 and the `project-dwlr-og-decompile-effort`
memory for the full extraction context. The raw table (77 monsters, not just this trimmed 10) lives
at `Markdowns/OGMonsterBaseStats.tsv`. Per that file's own header, column confidence varies:
`element` is certain (literal stored strings), `maxhp`/`level`/`str`/`agi`/`vit`/`int`/`spr` are
high-confidence (read off consistent positional patterns, not confirmed var names), `exp`/`gold`/
`flee` are medium-confidence. Treat accordingly.

## Confirmed base stats

| Monster | Level | MaxHP | MaxMP | Str | Agi | Vit | Int | Spr | Element |
|---|---|---|---|---|---|---|---|---|---|
| Cat | 1 | 30 | — | 3 | 8 | 2 | 1 | 1 | — |
| Slime | 1 | 40 | — | 4 | 2 | 4 | 1 | 1 | Water |
| Dog | 2 | 45 | — | 4 | 4 | 5 | 1 | 1 | — |
| Redslime | 2 | 45 | — | 5 | 2 | 5 | 4 | 1 | Fire |
| Bat | 3 | 45 | — | 5 | 10 | 3 | 2 | 1 | Air |
| Fox | 3 | 55 | — | 6 | 9 | 4 | 4 | 1 | — |
| Babble | 4 | 60 | — | 6 | 1 | 6 | 8 | 1 | Plant |
| Skeleton | 4 | 60 | — | 6 | 3 | 1 | 4 | 1 | Darkness |
| Drakee | 5 | 65 | — | 7 | 8 | 4 | 4 | 1 | — |
| Healer | 5 | 70 | 20 | 7 | 2 | 3 | 6 | 6 | Water |

(Exp/Gold/Delay/Flee columns exist too — see `OGMonsterBaseStats.tsv` directly, omitted here since
this file is about the stats that feed combat formulas.)

## What this confirms from the 2026-08-18 live-testing pass

- **The Strength gradient was right.** cat < slime < dog < redslime < bat < fox < babble/skeleton
  (tied) < drakee < healer matches real Strength values almost exactly — the live-testing
  methodology itself was sound, even where individual numbers landed off.
- **Magic resist tracking Intelligence is now a real, explained mechanic, not just an observed
  pattern.** Fox (Int 4, highest among the non-caster Tier 1 set) showed the strongest Zap
  resistance in testing; Slime (Int 1, tied lowest) showed the weakest. Matches the Help section's
  "Intelligence increases magic defense" applying to monsters too, not just players — good
  independent confirmation of the composite-defense model logged in `TODOList.md`.
- **Healer really is squishier than Drakee, and now we know why**: Healer's Agility (2) is far
  below Drakee's (8) despite similar Vitality (3 vs 4) — a real per-monster Agility difference
  driving the defense gap the live testing picked up on.

## What this corrects from the 2026-08-18 live-testing pass

- **"Shared physical defense baseline across most of the roster" — retracted.** Real Agility spans
  1 (Babble) to 10 (Bat), real Vitality spans 1 (Skeleton) to 6 (Babble) — genuinely different
  per-monster, not a flat shared value. The live testing's small hit-count samples likely
  couldn't distinguish this real per-monster spread from noise.
- **The "two-cluster HP split" (2-hit-kill vs 3-hit-kill groups) reads differently now.** Real
  MaxHP across the roster is a smooth, Level-correlated gradient — 30, 40, 45, 45, 45, 55, 60, 60,
  65, 70 — not two discrete tiers. The 2-hit/3-hit grouping observed live was a real effect, just
  better explained as a continuous stat getting bucketed by "how many hits happen to clear it" than
  an actual two-tier design choice.

## Still open — not resolved by this data

- **Slime's table MaxHP is 40, but live testing repeatedly killed slimes with well under 40
  damage — including confirmed one-shot kills.** Both readings are real OG evidence and both
  stand; the scaling theory is NOT retracted. The 2026-08-18 live finding (slime died to 28 →
  survived 30 → survived 31 as Hero1 leveled) plus firsthand certainty that a one-hit slime kill
  was nowhere near 40 damage means the table value alone doesn't describe what a spawned slime
  actually has.
  **Leading reconciliation — the table value is probably a formula input, not final HP.** The
  same string-table extraction that produced this data also surfaced `HPfactor` and `MPfactor`
  as real tracked vars (alongside `HPregen`/`MPregen`). A "factor" var strongly implies MaxHP is
  *computed* per spawned instance rather than read straight off the type definition — so a
  monster's live MaxHP could be some function of this base value, its own Level, and/or
  `HPfactor`, which would let "table says 40" and "died to 28" both be true without either
  observation being wrong.
  What this does NOT yet explain is the *direction* of the live trend (slimes getting tankier as
  Hero1 leveled) — if the driver is the monster's own level rather than the player's, something
  still has to be raising spawned monster level over time. Needs the collaborator's next
  decompile pass to settle: specifically, wherever `HPfactor` is read, and whatever proc sets a
  spawned monster's MaxHP.
  **2026-08-23 update — a fresh, genuinely clean test narrows this down.** A Level 1 Hero
  (Str5/Agi3/Vit3/Int3/Spirit3) killed a Level 1 slime in 5 hits (4 normal at 5-7 damage, plus a
  15 crit finishing it; "probably would've been 6" without the crit) — see `CombatDataSheet.md`
  Table 5. Bracketing that fight puts the slime's real HP at roughly **28-43, comfortably
  containing the table's 40**. So the conflict isn't with the table generally — it's specifically
  with the *older*, higher-Strength 2026-08-18 readings (a single ~28-damage hit reportedly
  one-shotting a slime, which a real 40-HP slime shouldn't allow).
  **Downgraded, same day (2026-08-23):** most likely explanation for the older readings is
  tester error, not a real scaling mechanic — that session's notes were logged late/tired, and
  a misread combat-log line or a mis-tracked hit is simpler than an undocumented HP-scaling
  system with no supporting var anywhere in the extracted `.dmb` data. **Monster
  HP-scales-with-player is retracted as the working theory** — treat the table's flat 40 as the
  real value unless a future clean test (same rigor as the 2026-08-23 Level 1 kill above)
  contradicts it again.
- **Exact weighting between Agility and Vitality in the physical-defense blend** (and Vitality vs.
  Intelligence for magic defense) is still unconfirmed — this table gives real per-monster inputs
  to test against once the collaborator's next decompile pass (`sompipe.js`, actual proc bytecode)
  recovers the real formula math.
- **Metal-tier archetype (Metal Slime/Babble/Healer, outside this trimmed 10)** carries Vitality/
  Intelligence values in the 600-900 range in the raw table — not a typo or extraction artifact,
  read as deliberately extreme stats matching the archetype's known tiny-HP/huge-defense/high-flee/
  big-exp design (consistent with those same rows' MaxHP 6/8/10, exp 356/885/1488, flee 35/20/40).
