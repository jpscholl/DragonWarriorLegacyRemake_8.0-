# OG Combat Formulas — Decoded vs. Current Implementation

**Status: partially applied.** Everything marked **Applied** below is now live in the
codebase. Sections 1-3 and the exp-curve half of §7 are still blocked on missing data
(spell roster reconciliation, per-class `exp_start`, monster `elementType`) exactly as
described in each section — not applied. §6 has no current system to attach it to.
`hit()`/`cast()`'s core damage-vs-defense resolution (dodge chance aside) remains
un-recovered raw bytecode — see "Not yet decoded" at the bottom; that's the one
genuinely open gap in the combat formula, not just an unapplied data table.

Source: two files a collaborator extracted/decompiled from the original Wizdragon/Tarq
game's compiled `.dmb`, currently sitting in `C:\Users\jpsch\Downloads\`:

- `types.dm` (~6,300 lines) — the OG's full type/class hierarchy. Clean and directly
  readable except for `// vars_values = Chunk([...])` / `// vars_overrides = Chunk([...])`
  comments, which are untranslated raw bytecode operand indices the decompiler couldn't
  resolve back to source syntax with this tool version — not chased further in this pass,
  but see the update note below on why these may not be a permanent dead end.
- `unsorted.dm` (~30,000 lines, 763 indexed procs) — raw bytecode disassembly of actual
  proc *bodies*. Some procs decoded to fully readable pseudocode; many others show
  `[Omitted long matching line]` or a raw `Iter([...])` opcode dump the decompiler gave up
  on entirely — those need someone to manually walk the stack-machine trace by hand.

This doc is a **pure reference/comparison pass — nothing in the actual codebase has been
changed.** It exists so a future session can execute the replacements below without
re-deriving them. Line numbers cite `unsorted.dm` for the OG side and the real DWLR repo
for the current side.

**Status of this pass:** this covers the highest-value, most-flagged-as-placeholder
formulas. It is not exhaustive — see "Not yet decoded" at the bottom for what's left.

**Update 2026-09-21:** the collaborator who ran this decompiler said the version used
for this export isn't fully up to speed, and offered to improve it and re-run. Every
"unrecoverable" item in this doc — the raw `hit()`/`cast()` bytecode below, and likely
the `Chunk([...])` blobs in `types.dm` too, since both look like the same root cause
(the tool hitting an instruction or reference it doesn't have a name for and giving up on
everything downstream) — may turn out to just need a better export, not permanent dead
ends. Worth prioritizing `hit()`/`cast()` specifically (unsorted.dm:625/688) if he does
another pass — see "Not yet decoded" for the rest of the wishlist.

**Update 2026-09-21 (second):** a separate write-up, `C:\Users\jpsch\Downloads\DWL_damage_reverse_engineering.md`
(ChatGPT-authored), proposed the damage system is architecturally distributed — `hit()`/
`cast()` receive an already-computed damage value rather than building it — and that the
real formula should be found by tracing backward from `TakeDamage()` call sites. Verified
that thesis directly against `unsorted.dm` — see §11 below. Most of that write-up
duplicates formulas already in this doc (dodge, elemental matrix, `castburn()`); its one
genuinely new claim (a detailed player `TakeDamage()` barrier/MP mechanic) turned out to
NOT be supported by this export — `TakeDamage()` here is a one-line stub. Treat that
specific section as unconfirmed until it's clear which decompiled file it was actually
read from.

---

## 1. Spell mana costs — `SpellCost()`, unsorted.dm:1056

Fully decoded: a clean switch on spell name returning a flat integer. Real OG values:

| Spell | MP | Spell | MP | Spell | MP | Spell | MP |
|---|---|---|---|---|---|---|---|
| Heal | 6 | Sleep | 3 | Blazemost | 10 | Icespears | 5 |
| Healmore | 15 | Sleepmore | 7 | Firebal | 4 | Blizzard | 10 |
| Healmost | 40 | Stopspell | 6 | Firebane | 7 | Snowstorm | 16 |
| Healus | 20 | Infernos | 5 | Firevolt | 10 | Zap | 3 |
| Healusmore | 60 | Infermore | 8 | Bang | 6 | Lightning | 4 |
| Vivify | 20 | Blaze | 4 | Boom | 12 | Thordain | 7 |
| Revive | 50 | Blazemore | 7 | Explodet | 16 | Return | 12 |
| Upper | 10 | | | Icebolt | 3 | Flamespears | 16 |
| Increase | 22 | | | | | Defeat | 20 |
| Barrier | 20 | | | | | | |

**Current DWLR values** (`Code/Combat/Skills/SkillCatalog.dm`, file's own header comment:
*"every damage_multiplier/heal_amount/mana_cost is a tunable guess"*) — spot check on the
ones this project already names the same:

- Blaze: DWLR `mana_cost = 5` vs. OG `4`
- Healmore-tier (60 heal_amount): DWLR `mana_cost = 4` vs. OG Healmore `15` — way off
- Sleep: DWLR `mana_cost = 5` vs. OG `3`

DWLR's spell roster doesn't map 1:1 onto OG spell names yet (fewer spells, some renamed/
merged) — **before applying this table, the spell roster itself needs reconciling against
the full name list above**, not just swapping numbers in place.

**Plan:** once each DWLR skill is matched to its real OG name, replace its `mana_cost`
literal with the table value above.

---

## 2. Spell cast times — `SpellTime()`, unsorted.dm:1234

Same switch structure and spell order as `SpellCost()`. Real OG values (deciseconds):

| Spell | Time | Spell | Time | Spell | Time | Spell | Time |
|---|---|---|---|---|---|---|---|
| Heal | 15 | Sleep | 6 | Blazemost | 25 | Icespears | 8 |
| Healmore | 25 | Sleepmore | 8 | Firebal | 6 | Blizzard | 12 |
| Healmost | 35 | Stopspell | 6 | Firebane | 10 | Snowstorm | 20 |
| Healus | 40 | Infernos | 8 | Firevolt | 14 | Zap | 6 |
| Healusmore | 60 | Infermore | 10 | Bang | 8 | Lightning | 8 |
| Vivify | 40 | Blaze | 15 | Boom | 12 | Thordain | 12 |
| Revive | 60 | Blazemore | 20 | Explodet | 20 | Return | 20 |
| Upper | 20 | | | Icebolt | 6 | Flamespears | 8 |
| Increase | 40 | | | | | Defeat | 10 |
| Barrier | 30 | | | | | | |

**Current DWLR:** `cast_time` values in `SkillCatalog.dm` are similarly guessed (e.g.
Blaze/generic spells at `cast_time = 6`, buffs at `4`) — same reconciliation-then-replace
plan as mana costs.

---

## 3. Elemental damage matrix — `Element()`, unsorted.dm:1412

**This is a structural finding, not just numbers.** The OG's elemental system isn't a flat
"weak = +50% / resist = -50%" like DWLR's current one — it's a real multiplier matrix
between the spell's element and the **target's elemental type**, and targets have one of
**8** types, not a single optional weakness/resistance string:

| Spell element ↓ / Target type → | Normal | Fire | Water | Ice | Air | Iron | Plant | Darkness |
|---|---|---|---|---|---|---|---|---|
| Physical | 1 (flat — no target-type check at all) |||||||
| Fire | 1 | 0.5 | 0.5 | **1.5** | 1 | 1 | **1.5** | 1 |
| Ice | 1 | **1.5** | 1 | 0.5 | **1.5** | 0.5 | 1 | 1 |
| Lightning | 1 | 1 | **1.5** | 1 | 0.5 | **1.5** | 0.5 | 1 |
| Holy | 1 | 1 | 1 | 1 | 1 | 1 | 1 | **1.5** |

**Current DWLR** (`Code/Combat/CombatSystem.dm:322-358`): a single `elementalWeakness` /
`elementalResistance` string per mob, flat `±50%`
(`ELEMENTAL_WEAKNESS_BONUS_PERCENT`/`ELEMENTAL_RESISTANCE_REDUCTION_PERCENT = 50`), and the
comment there already says this is "real, working code, but currently inert — nothing
yet sets elementalWeakness/elementalResistance." So nothing plays with this today; the
question is what to build instead.

**Applied 2026-09-21.** Turned out step 3 was already done: `MonsterRoster.dm`'s
`mobElement` var already carries real OG data for every monster (CodeNotes.md rates it
CERTAIN confidence — this was missed in the original pass above). `GetElementalMultiplier()`
(`CombatSystem.dm`) now does the real matrix lookup keyed by `(spell.element,
target.mobElement)`, and `ApplySpellDamage()` uses it directly. The old flat ±50%
`elementalWeakness`/`elementalResistance` scaffolding and `ResolveElementalDefense()` are
gone — no longer needed once the real per-monster data was wired straight in.

---

## 4. Attack delay — `AttackDelay()`, unsorted.dm:5302

**Applied 2026-09-21** (`Code/Combat/CombatSystem.dm`'s `GetAttackDelay()`).

Fully decoded:

```
AttackDelay(baseDelay, minDelay = 0):
    sleep( max(minDelay, baseDelay - round(agility / 10, step=0.5)) )
```

i.e. one flat term: `agility ÷ 10`, rounded to the nearest 0.5, subtracted from a base.
**No Vitality/Intelligence blending, no melee-vs-spell split, no sqrt/geometric-mean** —
one formula for everyone, driven by Agility alone.

**Current DWLR** (`Code/Combat/CombatSystem.dm:381-401`, `GetAttackDelay()`): materially
more complex —
- Melee: `delay = max(MIN, BASE - sqrt(agi * max(vit, int)))` (geometric mean of Agility
  and whichever of Vitality/Intelligence is higher)
- Spell: `delay = max(MIN, BASE - (int + agi*int/40))`
- Both fed by class-differentiated base/min constants

**Plan:** this is the single cleanest "just replace it" candidate in this whole doc — the
OG formula is short, fully recovered, and structurally simpler than what's there now.
Replace `GetAttackDelay()` with the one-line OG formula; drop the melee/spell split and
the secondary-stat blending entirely, since the OG doesn't have them. Needs a real
`BASE_DELAY` constant per skill — not yet located, likely lives in `hit()`/`cast()`
(unsorted.dm:625/688), which are only partially decoded (see below).

---

## 5. Dodge chance — from `hit()`, unsorted.dm:625 (partial)

Only decoded as far as:

```
dodgeChance = min(75, round(target.agility * 0.75))
```

before the trace falls into raw, un-reconstructed bytecode — right at a single unresolved
instruction (almost certainly BYOND's `prob()`, which is its own dedicated VM opcode
rather than a generic proc call, unlike every other named call in this file). Confirms two
concrete facts: **cap is 75%** (not DWLR's 30%) and **scale is 0.75 per Agility point**
(not DWLR's flat 1:1). The rest of `hit()` — the actual damage-vs-defense resolution — is
not recovered with this export (see the update note at the top of this doc).

**Applied 2026-09-21**: `DODGE_AGILITY_SCALE → 0.75`, `DODGE_MAX_PERCENT → 75` in
`Code/Combat/CombatSystem.dm`'s `RollDodge()` (was `DODGE_BASE_PERCENT=0`,
`DODGE_AGILITY_SCALE=1`, `DODGE_MAX_PERCENT=30`). Still flagged **provisional** in a code
comment there — the two confirmed constants are live, but whether anything downstream in
the un-recovered rest of `hit()` further modifies this roll is still unknown.

---

## 6. DOT/burn tick damage — `castburn()`, unsorted.dm:625 area (fully decoded)

This is the recurring damage-over-time tick (used by fire/poison-style burn effects):

```
castburn(target, attacker, power, ...):
    defenseStat = target.intelligence
    if target is a real mob:
        defenseStat += 18 per worn Amulet of Barrier
    reduction = RandRange( round(defenseStat/3), round(defenseStat*2/3) )   // random roll, not flat
    damage = round(power * elementMultiplier) - reduction
    damage = max(damage, 1)
    target.TakeDamage(damage, attacker, ...)
```

Two real findings: **burn damage is mitigated by Intelligence, not Vitality/Defense**, and
the mitigation is a **random roll between defenseStat/3 and defenseStat*2/3**, not a flat
subtraction. DWLR currently has no burn/DOT system at all (poison in `StatusEffects.dm`
uses a flat `%` of MaxHP per tick instead, unrelated mechanism).

**Applied 2026-09-21**: `datum/status_effect/burn` (`StatusEffects.dm`), formula exact —
target's Intelligence (+18 per worn Amulet of Barrier), `rand(B/3, B*2/3)` mitigation,
reuses `GetElementalMultiplier()` (§3) for the elemental term.

**Trigger built 2026-09-22 — no longer dormant.** The first pass wired this to fire on
every fire-element hit landing (invented trigger, flagged as such at the time), but the
user recalled the real OG mechanic directly: Explodet does impact damage, then leaves a
residual "circle" of flame on the ground, and standing in THAT is what causes the DOT —
not getting hit by the spell itself. That direct-hit trigger was pulled as confirmed
wrong-shaped rather than merely unconfirmed.

The residual-flame feature now exists as `obj/hazard_field` (`Code/Combat/HazardFields.dm`):
a runtime-spawned, self-expiring ground hazard that ticks on whoever is *standing* in it,
laid down in a diamond blob by `SpawnHazardBlob()`. Built as an `/obj` layered over the
ground rather than by swapping turf types — turf replacement would have to snapshot and
restore every var on the original, and the map is full of turfs whose identity is
load-bearing (warp pairs, doors that toggle density, ceiling boundaries).
`obj/hazard_field/flame` re-applies `ApplyBurn()` every tick, so the burn refreshes while
you stand in the fire and runs out shortly after you step clear.

`datum/skill/Explodet` is now an `AoESpell` (it was never single-target in the original)
that deals its blast damage and then spawns that blob. Art for both halves already
existed unused in `spells.dmi`: `"explodet"` for the blast, `"explodetflame"` for the
residual fire.

Still invented, for tuning: the field's duration (80 deciseconds), its radius (1), and
`hazard_power_multiplier` (0.5 — the burn's power is scaled off the damage the cast
actually rolled, so residual fire from a strong caster keeps pace with the spell that
made it). Only the burn formula itself is OG.

---

## 7. Exp curve & stat points per level — `LevelCheck()`, unsorted.dm:6777

Decoded almost completely (falls into an irrelevant sound-effect call at the end):

```
LevelCheck():
    if exp < exp_needed: return
    if level >= 99: return          // matches DWLR's own MAX_LEVEL = 99
    level += 1
    exp_needed += round( (level³/15 + level*14/15) * exp_start )
    stat_points += round(level / 2) + 5
```

`exp_start` is a **per-class** multiplier (a var on the player, not a global constant) —
the exp curve's steepness differs by class in the OG, not universal.

**Current DWLR** (`Code/Combat/CombatSystem.dm:264-289`):
`Nexp = BASE_EXP * Level * Level` — a flat quadratic, one constant (`BASE_EXP = 15`) for
every class. And `StatPoints += 6` flat every level-up.

**This directly contradicts an existing in-code claim.** `Code/Admin/Commands/GMCommands.dm:922`
has the comment *"StatPoints += 6 // matches LevelCheck()'s confirmed OG value"* — that's
only true for the very first level-up (level 1→2: `round(2/2)+5 = 6`). From there it
climbs: level 10→11 gives `round(11/2)+5 = 11`, level 50→51 gives `30`. The flat-6 claim
is wrong past the first level and should be corrected regardless of when the fuller
change lands.

**Applied 2026-09-21** (parts 2 and 3): `StatPoints` now reads
`round(Level/2) + 5` in both `LevelCheck()` and `GMCommands.dm`'s `GM_LevelIncrease()`;
the stale "confirmed" comment on the latter is corrected.

**Applied 2026-09-22** (part 1), with an invented constant: the curve's real shape is now
in `GetNexpForLevel()` (`CombatSystem.dm`), and `exp_start` is a per-class var on the
player (`PlayerTemplate.dm`). The OG's own `exp_start` values remain unrecoverable, so
the per-class numbers are guesses — Hero/Soldier 15, Fighter 14, Pilgrim 16, Wizard 17,
Sage 20, Goof-off 12 (deliberately the fastest, since reaching Classchange's level 25
gate is the whole point of the class), Archsage 1 (test-bed pace).

Two things make these easy to tune by feel rather than by arithmetic. The formula
collapses to exactly `exp_start` at level 1 — `(1 + 14)/15 = 1` — so the number is
literally "exp needed for level 2". And because the OG tracks exp cumulatively while
DWLR resets `Exp` on every level-up, the OG's per-level *increment* maps onto DWLR's
`Nexp` with no conversion at all.

⚠️ This is a **much steeper** curve than the old `Nexp = 15 × Level²` past the low
levels — level 50 wants ~126k for that level instead of ~37k — and has never been
balanced against DWLR's actual monster exp values. It is the original's shape, but the
pacing is untested.

---

## 8. Kill reward: exp/gold, amulets, and party split — `KillReward()`, unsorted.dm:6899

Fully decoded:

```
KillReward(baseExp, baseGold):
    baseExp *= 5
    baseGold *= 5
    baseExp += round(baseExp/4)  per worn Amulet of Experience   // +25% each, compounding
    baseGold += round(baseGold/2) per worn Amulet of Gold        // +50% each, compounding

    if not party_share:
        killer gets it all; LevelCheck(); return

    // party_share path:
    eligible = party members alive AND within 8 levels of killer AND same party
    if eligible.len == 1:
        killer gets it all (same as solo path)
    else:
        n = eligible.len
        perMemberShare = round( baseExp * ((n-1)*0.25 + 1) / n + 0.99 )   // rounds up
        (same formula for gold)
        every eligible member gets perMemberShare (not divided again — same value to each)
```

Two structural differences from what's implemented:

1. **The party bonus GROWS the total pool**, it doesn't just split it evenly. The
   multiplier `((n-1)*0.25+1)` means: solo = 100% of the pool, a 2-person party shares
   125% of it, a 3-person party shares 150%, a 4-person party shares 175% — and then
   **each** member gets that inflated pool's per-member share (not a further split), so a
   full party earns substantially more total exp than one person killing alone, not just
   the same total redistributed.
2. **Only the killer's own Amulet of Experience/Gold apply**, before the split — not each
   individual party member's own amulets. DWLR currently applies each member's own
   `equipExpBonusPercent`/`equipGoldBonusPercent` individually inside the split loop
   (`Code/Combat/CombatSystem.dm:196-205`) — structurally the opposite of the OG.
3. Party eligibility filters on **level difference ≤ 8** and **alive** — DWLR's current
   split (`Code/Combat/CombatSystem.dm:191-205`) includes every party member unconditionally.

**Current DWLR amulet bonuses** (`Code/Player/Inventory.dm:479,485`):
Amulet of Wealth `bonusGoldPercent = 10`, Amulet of Experience `bonusExpPercent = 10` — OG
is **25% (exp) and 50% (gold)**, both much stronger, and the OG amulet is literally named
`amulet/gold` and `amulet/exp` (matches DWLR's items closely enough to be confident these
are the same items).

**Applied 2026-09-21**, all three parts, in `Code/Combat/CombatSystem.dm`'s `Die()`:
1. Base reward ×5 before amulet/party math. Resolved the "already baked in?" question
   from `CodeNotes.md`: monster `expReward`/`goldReward` are confirmed real OG values
   pulled straight from the `.dmb`'s own type table (MEDIUM confidence, not placeholders)
   — i.e. exactly the raw `baseExp`/`baseGold` `KillReward()` takes as input, not a
   pre-multiplied result. The ×5 is additional, not double-counted.
2. Amulet of Experience → 25%, Amulet of Gold → 50% (`Inventory.dm`).
3. Party split rewritten to the growing-pool formula, gated on `alive AND |levelDiff| <=
   8`, using only the killer's own amulet bonuses.

**One simplification kept**: the OG compounds each worn amulet multiplicatively (two
Amulets of Wealth = ×1.5×1.5); the implementation reuses the existing
`equipGoldBonusPercent`/`equipExpBonusPercent` totals instead, which sum rather than
compound. Identical result unless a player wears two of the exact literal same amulet
type at once (DWLR allows up to 2 worn) — not worth new bookkeeping just for that edge
case, flagged in a code comment at the point it matters.

---

## 9. Max HP formula — `SetMaxHP()`, unsorted.dm:7061

Core formula decoded:

```
MaxHP = round( HPfactor * (level^1.65 + vitality^1.55 + 30) )
capped at 9999
```

**This is a structurally different curve from what's implemented** — power-law growth
(exponents 1.65 and 1.55) on both Level and Vitality, not linear terms.

**Current DWLR** (`Code/Player/StatsDatum.dm:23-39`):
`MaxHP = round((30 + Vitality*5 + Level*3) * HPfactor) + equipMaxHP` — fully linear.

Both use a `+30` base and a per-class `HPfactor` multiplier, so those two pieces already
match conceptually — the difference is entirely in how Level and Vitality scale.

`SetMaxMP()` immediately follows in the source (starts with `MPfactor`, same shape
expected) but wasn't traced this pass — same formula shape is a safe bet, needs
confirming before use.

**Applied 2026-09-21** (MaxHP only): `RecalculateVitals()` now uses
`Level ** MAXHP_LEVEL_EXPONENT` (1.65) and `GetEffectiveVitality() ** MAXHP_VITALITY_EXPONENT`
(1.55) via DM's `**` binary operator, capped at 9999. This project's other exp-curve
comment claims DM has no exponentiation operator at all — that's true only for constant-
folding literal integers at compile time; `**` as a runtime binary operator on a
non-integer exponent is a real, long-supported BYOND operator, consistent with the OG
trace's own `Pow` opcode. **Could not test-compile this session** (no DreamMaker `dm.exe`
available in this environment, only the BYOND client) — worth a real compile check before
trusting this in play. **MaxMP left untouched**, per the "not confirmed" note above.

---

## 10. Skill-unlock structure — `SkillCheck()`, unsorted.dm:6836

Mostly decoded. **This one is good news: DWLR's existing design already matches.** The OG
checks, per candidate unlock: same class, `unlock.level <= player.level`, not already
known, AND a stat check — `player.vars[statName] - equipmentBonus >= threshold`. That's
exactly `datum/skillUnlock`'s shape in `Code/Player/SkillUnlocks.dm`
(`requiredLevel`/`requiredStat`/`requiredStatValue`).

**What's still missing:** the actual per-skill threshold numbers. Those live in
`types.dm`'s `/playerlearn/<class>/<skill>` entries as `vars_values = Chunk([...])` —
unfortunately one of the genuinely unrecoverable pieces (see intro). `SkillUnlocks.dm`'s
own header comment already says only 2 of ~90 entries are OG-confirmed (Hero's Heal/
Thornwhip); this file doesn't change that, but it does confirm the *shape* of the system
was reconstructed correctly from scratch, which is worth knowing.

---

## 11. Damage architecture — traced backward from `TakeDamage()`/`proj/New()` call sites (2026-09-21)

A collaborator handed over a separate write-up (`DWL_damage_reverse_engineering.md`,
ChatGPT-authored) proposing that `hit()`/`cast()` receive damage as an argument rather
than computing it, and that the real formula should be found by tracing backward from
`TakeDamage()` call sites. Cross-checked that thesis directly against `unsorted.dm` by
grepping every real `TakeDamage()`/`proj/New()` call site (not GM-command cheats like
`TakeDamage(9999)` on `GM_KillMonsters`/despawn cleanup, which don't count).

**Confirmed real, independent of that write-up:**
- `/proj/New(loc, target, dir, damage)` (unsorted.dm:18137) — `damage` is a plain 4th
  constructor argument, computed nowhere inside `New()`. Same pattern in `/proj/sickle/New()`
  and `/burn/New()` (unsorted.dm:19620, its own `damage` var set from Arg(2)).
- `/proj/xxx/Collide()` (e.g. unsorted.dm:18089) reads `src.damage` directly off the
  projectile and forwards it into a 6-arg global proc call shaped exactly like `hit()`'s
  own signature (target, attacker, damage, arg, hitstate, element) — confirms damage really
  does flow in from whoever fired the projectile, not from `hit()`/`Collide()` itself. This
  independently confirms the backward-tracing thesis is structurally correct.
- `castburn()`'s and `proj/defeat/Collide()`'s 3rd `TakeDamage()` argument is the same
  unresolved global (`Unknown1(-37, 673)`) in both places — consistent with DWLR's own
  existing `TakeDamage(damage, attacker, isMagic, isCrit)` shape already being right
  structurally, independent confirmation rather than a coincidence.
- **One real number recovered**: `proj/defeat/Collide()` (unsorted.dm:19581) — the Defeat
  spell deals a flat `9999` damage, no formula, no random component. Not applicable to
  DWLR yet — there's no "Defeat" skill in `SkillCatalog.dm`'s current roster.
- Minor/non-combat: `/turf/floor/barrier/Entered()` (unsorted.dm:27421, and two duplicate
  hazard-turf variants at 27678/28291) — a flat 15-damage-per-step hazard floor, full
  immunity from `/item/amulet/stepguard`. Environmental hazard, not the melee/spell formula.

**The write-up's Section 8 (player `TakeDamage()` barrier: MP absorption,
`ceil(damage/2)` on break) is NOT supported by this `unsorted.dm` export** — see the
corrected "Not yet decoded" bullet above. Either it was written against a different/newer
decompiled export than what's in `Downloads`, or it's fabricated. **Ask the collaborator
which file ChatGPT actually read** before trusting that section for anything.

**Where the trail actually dies**: attempted the same backward trace into the procs that
*construct* the damage value in the first place — `hit()`, `cast()`, and every monster
attack proc checked (`Attack()`, `Punch()`, `Dash()`, `Quakejump()`, `Fireclaw()`,
`Thornwhip()`, `Chainsickle()`, all unsorted.dm ~12600-12665) — every single one falls into
an unresolved opcode within roughly the first 15 instructions, before any STR/INT-based
math appears. Consistent failure across every attack-construction proc checked, not one
unlucky proc — confirms this decompiler version has a real, systemic blind spot on
whatever instruction actually builds combat damage. Backward-tracing the *delivery* layer
(`hit()`/`cast()`/`Collide()`/`TakeDamage()`) is confirmed correct and was worth doing, but
it cannot recover the base formula with this export — that still needs the collaborator's
promised improved decompiler pass.

---

## Not yet decoded — wishlist if the collaborator re-runs an improved decompiler

- **`hit()`/`cast()` (unsorted.dm:625/688) — top priority.** The actual damage-vs-defense
  resolution falls into raw, un-reconstructed bytecode partway through. This is the single
  most valuable remaining target in the whole file — it's the real melee/spell damage
  formula, and everything else in this doc is downstream of not having it (e.g. §4's
  `BASE_DELAY` constant per skill likely lives here too).
- **`types.dm`'s `Chunk([...])` blobs** — if the tool's improvement also resolves these
  (same likely root cause as `hit()`/`cast()`), this unlocks: every class's `exp_start`
  multiplier (§7), monster `elementType` values (§3), and every `/playerlearn/*` skill's
  real level/stat unlock threshold (§10) — currently the single biggest gap in
  `SkillUnlocks.dm`, which only has 2 of ~90 entries OG-confirmed.
- `SetMaxMP()` (unsorted.dm:7108) — cut off after confirming it starts with `MPfactor`,
  same shape as `SetMaxHP()` expected but not confirmed.
- `TakeDamage()` — **confirmed** (2026-09-21, grepped the whole file) there is only ONE
  `TakeDamage()` definition anywhere in `unsorted.dm`, and it's the stub at line 5108
  (`Return`, one line). Not "not yet located" — genuinely not in this export at all. The
  real damage-application logic must live in an override this decompiler pass never
  reached the definition of, or gets patched onto mobs some other way not visible here.
- Individual monster spell-cast procs (`/mob/monster/proc/Chainsickle()`,
  `Bang()`, `Icebolt()`, etc., unsorted.dm ~12600-13400) — real per-monster spell damage
  values, mostly not yet read.
- `GetWeight()` (unsorted.dm:7702) — inventory capacity formula, not yet read (DWLR has
  its own `GetInventoryCapacity()` placeholder in `Inventory.dm`).
- Amulet `equip()` procs (unsorted.dm ~20892-21406) — exact per-amulet bonus values for
  every amulet, not yet read.
- Class `exp_start` multipliers and per-skill unlock thresholds — live only in `types.dm`'s
  unrecoverable `Chunk(...)` blobs; would need a from-scratch bytecode read of the
  relevant `.dmb` region if ever pursued, not just re-reading these two files.
