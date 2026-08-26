# Combat/Stat Formula Data Collection Sheet

Goal: get enough **controlled** samples (only one thing changing at a time) to estimate
real formulas for MaxHP, MaxMP, and damage, the same way the stat-point-cost formula got
nailed down earlier from 5 clean data points. Fill in the tables below as you test — you
don't need to fill in every row, more data = a better estimate, but even 3-4 points per
table is usually enough to spot a pattern.

Use `GMlevelincrease` to control level, and the Battle tab's stat allocation to control
individual stats. Use `GMmakemob` to spawn a consistent test enemy, and `GMkillallmonsters`
to reset between tests if needed.

---

## Table 1 — MaxHP vs. Vitality (hold Level fixed)

Pick one level and stay at it for this whole table. Before spending any stat points,
record your baseline MaxHP. Then allocate points **into Vitality only**, one raw point at
a time if you can, recording MaxHP after each.

**Level held at:** ______

| Vitality | MaxHP |
|---|---|
|   |   |
|   |   |
|   |   |
|   |   |
|   |   |

## Table 2 — MaxHP vs. Level (hold Vitality fixed)

Use `GMlevelincrease` to gain levels but **don't spend** the stat points you receive
(leave "Stat Points" banked/unspent so Vitality doesn't change). Record MaxHP after each
level gained.

**Vitality held at:** 1 (Hero1, dump-Str build, see `SpellRequirementDataSheet.md`)

| Level | MaxHP |
|---|---|
| 1 | 57 |
| 2 | 61 |
| 3 | 66 |
|   |   |
|   |   |

**Level 5 snapshot, 2026-08-18 — NOT a clean fit for this table (Vitality moved too):**
Str 13 (confirmed, matches the Thornwhip message — the 12 first reported here was a
typo), Agi 6, Vit 2, Int 2, Spirit 2, HP 84, MP 28. Vitality went from the 1 held
throughout Table 2 above up to 2 here, so this isn't isolating Level the way the rest
of the table does — logging it anyway since it's real data, just noting why it's not a
plain row addition.

**Level 6 snapshot, 2026-08-18:** Str 15, Agi 7, HP 93, MP 31. Vit/Int/Spirit not
restated — assumed still 2 each unless a new number comes in. Same non-clean-fit
caveat as the Level 5 snapshot above (Vitality isn't held at 1 for this run).

**Level 7, 2026-08-18:** Str 16 (Hero1 leveled up partway through the hits-to-kill
batch above, this is the new baseline). Agi/Vit/Int/Spirit/HP/MP not restated yet —
assume unchanged from Level 6 until a fresh snapshot comes in.

**Level 8, 2026-08-18:** Str 17. Agi/Vit/Int/Spirit/HP/MP not restated — assume
unchanged from Level 7 until a fresh snapshot comes in.

## Table 3 — MaxMP vs. Intelligence (hold Level fixed)

Same method as Table 1, but allocate into Intelligence only and record MaxMP.

**Level held at:** ______

| Intelligence | MaxMP |
|---|---|
|   |   |
|   |   |
|   |   |
|   |   |
|   |   |

## Table 4 — MaxMP vs. Level (hold Intelligence fixed)

Same method as Table 2, but record MaxMP.

**Intelligence held at:** 1 (Hero1, Spirit also held at 1 — OG formula unknown, logging
both since remake's placeholder MaxMP formula includes both Int and Spirit)

| Level | MaxMP |
|---|---|
| 1 | 19 |
| 2 | 20 |
| 3 | 22 |
|   |   |
|   |   |

## Table 5 — Outgoing damage vs. Strength (hold enemy + weapon fixed)

Pick ONE enemy type via `GMmakemob` and use it for the whole table (note which one).
Use the same weapon/no weapon the whole time. At each Strength value, hit the enemy
5-10 times with a normal attack (Numpad 9) and record the **lowest, highest, and a few
typical** damage numbers you see — note separately if any hits were criticals, and how
much those did.

**Enemy type used:** slime **Weapon equipped:** none (unarmed, not stated otherwise)

| Strength | Lowest hit | Highest (non-crit) | A few typical hits | Crit damage seen |
|---|---|---|---|---|
| 5 | 5 | 7 | 5-7, fresh Level 1 Hero (Str5/Agi3/Vit3/Int3/Spirit3) vs. real Level 1 Slime (Str4/Agi2/Vit4/Int1/Spirit1), 2026-08-23 | none seen |
| 10 | 16 | 18 | 16-18 every hit so far | none seen |
| 11 | 17 | 20 | 17-20, Hero1 Level 2, Agi 5 (2026-08-18) | none seen |
| 12 | 19 | 21 | 19-21 vs. slime AND redslime both, Hero1 Level 3 (2026-08-18) | none seen |
|   |   |   |   |   |

**2026-08-23 — first-ever clean Level 1 baseline, and it breaks a simple linear Str-only fit.**
Every other row in this table was logged at Level 2+ (Hero1 had already leveled by the time Str10
was recorded), so Level's own contribution was always riding along with Str's. Fitting the Str
10-12 rows alone suggests roughly `damage ≈ 1.5×Str + 2` — which predicts ~9.5 damage at Str5, well
above the 5-7 actually observed at a genuinely unleveled Level 1 Hero. Reads as real evidence that
Level itself adds to melee damage on top of Strength, not just through the stat points it grants —
worth deliberately holding Level fixed while varying Str (or vice versa) in future tests instead of
letting both drift together. Also notable: incoming damage from the slime (Str4) came out
symmetric with outgoing (also 5-7) despite Hero's higher stats across the board — at this low a
stat tier, defense doesn't look like it's doing much yet, consistent with a formula where a
DEF-based subtraction term rounds down to ~0 for small Agility/Vitality values (e.g. integer
division on a `DEF/4`-style term, per the NES-shaped formula already logged in `TODOList.md`).

**Kill confirmed, same fight: 5 hits (4 normal + a 15 crit on the last hit; "probably would've been
6" without the crit).** Bracketing this slime's real HP: 4 normal hits at 5-7 each sum to 20-28,
plus whatever HP remained going into the 5th hit — high enough that a normal 5-7 hit likely
wouldn't have finished it (hence "probably 6 hits"), but low enough that the 15 crit did. That
puts total HP roughly in the **28-43 range, comfortably containing the table's 40** — unlike the
2026-08-18 readings, **this test does NOT contradict `OGMonsterBaseStats.tsv`'s flat MaxHP 40.**
The unresolved conflict is specifically with the *older*, higher-Strength one-shot-kill data
(Str15+ hits killing a slime outright) — this new low-Str data point is consistent with a real,
un-scaled 40 HP slime. Worth a repeat test at a mid-range Strength (say 8-10, still Level 1 if
possible) to see whether hits-to-kill keeps tracking a flat 40 or starts drifting.

**2026-08-23, same build, Level 2 now (no stat points spent — Str/Agi/Vit/Int/Spirit unchanged
from the Level 1 test above): outgoing damage 6-8 vs. slime.** Cleanest possible isolation of
Level's effect — identical stats, only Level moved, and damage shifted by exactly +1 on both ends
(5-7 → 6-8). Directly confirms the "Level adds to melee damage on top of Strength" reading above,
now with a controlled test instead of an inferred gap. Two data points isn't enough to fit a real
curve, but a flat "+1 damage per Level" on top of the Strength-driven base is the simplest model
that fits so far — worth checking at Level 3+ to see if it stays linear or accelerates.

**SUPERSEDED 2026-08-23 by real extracted data — see `MonsterBaseStats.md`.** OG DWL's own
compiled type table gives slime a base MaxHP of **40** (and real base stats for all 10 monsters
in the trimmed roster, plus 67 more). The hits-to-kill and damage-range reverse-engineering
throughout this section is no longer the best source for monster stats — but it is NOT wrong or
discarded: live testing repeatedly killed slimes with well under 40 damage, which the table alone
can't explain. Leading theory is that the table value is a base input to a computed MaxHP (real
`HPfactor` var exists in the same extraction), not the final per-instance value. Read everything
below as live-observed behavior that still needs reconciling against the table, not as superseded
guesswork.

**Slime HP — RETRACTED "confirmed exact," 2026-08-18 same-day contradiction found: a
30-damage hit did NOT kill a slime, after an earlier 28-damage hit had.** The original
27 reading (28 killed it, 26 didn't) can't have been a fixed universal value if a
LARGER hit (30) later failed to kill a different slime instance. **Confirmed 2026-08-18: both were the plain "blue" slime, not a misidentification** —
rules out the species-mixup explanation.

**CONFIRMED 2026-08-18, your own theory, third data point in a row: monster HP scales
with the player.** A 31-damage hit at Level 8/Str 17 also failed to kill a slime —
that's now three consecutive readings moving the same direction as Hero1 leveled:
died to 28 dmg (~Str 15) → survived 30 dmg (Str 16) → survived 31 dmg (Str 17).
Monotonic, tracking level/Str directly, not just noisy variance — a random-per-instance
model wouldn't produce a clean upward trend like this across three separate fights.
Scaling is the real mechanic here, not per-instance randomness (that theory's now
effectively ruled out by this pattern, no need for the matched-stats tiebreaker test
originally proposed). **Open follow-up**: still don't know exactly what slime HP scales
off (Level directly? Hero1's Strength specifically? something else entirely?) or the
rate — only have a loose lower-bound trend (27ish → >30 → >31), not a formula. Also
still unconfirmed whether this is a MELEE-only illusion (scaling could be on Hero1's
side — e.g. a hidden damage-reduction term tied to level rather than the slime's HP
itself going up) vs. genuinely the slime's MaxHP increasing — both would look identical
from hit-to-kill data alone. **This also means every hits-to-kill data point earlier in
this file needs to be read as "true at that moment's Hero1 level," not a comparable
snapshot across the whole roster** — the low/high HP cluster split (cat/slime/dog/
redslime/bat/skeleton vs. fox/babble/drakee/healer) was gathered across a range of
Hero1 levels (6-8), so some of that split could be scaling-timing rather than a real
species difference. The split still looked clean, but treat it as weaker evidence than
it seemed before this confirmation.

**Cat HP — 2026-08-18: one-shot at 29 damage, so HP ≤ 29.** Consistent with cat sharing
slime's exact HP (27) — a 29-damage hit would one-shot a 27 HP cat too, and every other
stat (attack, defense) has read identical to slime all session. Working assumption:
cat's HP is also 27, pending a same-precision bracket test (a hit in the 26-27 range
that doesn't quite kill it, or an exact 27 that does) to confirm rather than infer.

**Drakee/Healer, Hero1 Level 7/Str 16, 2026-08-18: drakee 3 hits at ~28 dmg each,
healer 3 hits at 29-30 dmg each.** Both join the higher-HP 3-hit cluster with fox/
babble, not the low-HP 2-hit cluster (cat/slime/dog/redslime/bat/skeleton) — bounds
drakee's HP above ~56 (2x28) and healer's above ~58-60 (2x29-30). Notable: healer took
slightly MORE damage per hit than drakee here (29-30 vs. ~28), consistent with its
already-confirmed lower defense, yet still needed the same 3 hits — means healer's raw
HP is likely at or above drakee's despite being squishier on defense, not a case of
"less defense AND less HP." With this, every monster in the roster now has at least a
cluster-level HP read: low cluster (cat/slime/dog/redslime/bat/skeleton, ~27-64ish) vs.
high cluster (fox/babble/drakee/healer, notably tankier).

**Skeleton, Hero1 Level 7/Str 16, 2026-08-18: 32 outgoing damage per hit, 2 hits to
kill.** Bounds skeleton's HP between 33 and 64 (2 hits needed, so >32; 2 hits sufficed,
so ≤64) — joins the low-HP 2-hit cluster (cat/slime/dog/redslime/bat), not the
higher-HP fox/babble cluster. Your own read: "possibly less vitality/def" than
expected — consistent with every other skeleton data point this session (attack,
defense both reading as ordinary Tier 1, not the stronger Tier 2 the code currently
assigns it). Not precise enough yet for an exact value the way slime's 27 is — would
need the same bracket-test approach to pin down further.

**Hits-to-kill batch, Hero1 Level 6/Str 15, 2026-08-18: dog 2, redslime 2, bat 2, fox 3,
babble 3.** Dog needing only 2 hits here (vs. the 3 hits logged earlier this same
session at Str 10) isn't a contradiction — that earlier reading was at a lower attacker
Strength, so fewer/more hits to kill the same monster is expected as Str climbs.
**Real signal instead: fox and babble both took 3 hits while dog/redslime/bat/slime/cat
all took 2, at the same attacker Str (15).** First sign of a genuine two-cluster HP
split in this roster — a low-HP cluster (cat/slime/dog/redslime/bat, ~27ish based on
slime's confirmed exact value) and a higher-HP cluster (fox, babble). Not exact numbers
yet, just relative grouping — a bracket test on fox or babble (same method as slime's
27) would pin the actual value down. Hero1 leveled to 7 partway through this batch
(accidental) — exact new Str/Agi not reported yet, so treat any damage numbers after
this point as a new, not-yet-baselined attacker state until a fresh snapshot comes in.

**Extra, not in the original table shape — logging anyway:** Hero1 vs slime, ~2 hits to
kill, 15 exp + 15 gold per kill, leveled 1→2 fast at this kill rate. Ties into the
Phase 7 exp-pacing question in `TODOList.md` — 15 exp/kill against a 0/22 Level-1→2
threshold (see the exp-loss finding logged there) means ~2 slime kills to level, which
is the "too fast" feel already flagged. Useful as a concrete kills-to-level data point
once more monster tiers get tested.

**Zap damage vs slime, Str 10/Agi 4/Vit 1/Spirit 1 held fixed, Int varying —
correction, Zap IS Int-scaled:**

| Int | Spirit | Target | Zap dmg |
|---|---|---|---|
| 1 | 1 | slime | 7-8 |
| 1 | 1 | slime | 8-9 (Hero1 Level 2, Str 11/Agi 5, 2026-08-18 — same Int/Spirit as row above, close range, good consistency check) |
| 1 | 1 | dog | 5-6 (Hero1 Level 3, Str 12/Agi 5, 2026-08-18) |
| 1 | 1 | bat | 4-5 (Hero1 Level 3, Str 12/Agi 5, 2026-08-18) |
| 1 | 1 | fox | 2-3 (Hero1 Level 3, Str 12/Agi 5, 2026-08-18) |
| 8 | 1 | slime | 28-30 |
| 8 | 2 | slime | 20 |
| 8 | 2 | cat | 20 |
| 9 | 2 | slime | 32 |
| 9 | 2 | cat | 21 |

Earlier note below (from the Int-1 data point alone) guessed Zap wasn't Str-or-Int
scaled — wrong, retracted now that Int actually moved: 1→8 Int roughly quadrupled Zap
damage while melee (still Str 10, untouched) stayed flat at 16-18 the whole time. Reads
as a real Int-scaling formula, not flat/fixed. Worth enough data points to fit a curve
(linear vs. quadratic vs. per-point-jump) once more Int values get tested — same
method as Table 5 above but with Zap as the attack instead of melee, and Int as the
varying stat instead of Strength. Original Cat data point (Int still 1 at the time, 5-6
dmg) stands as-is, just re-read now as "Int 1 vs cat" rather than evidence of no
scaling.

**Unresolved wrinkle, same session:** Zap vs slime dropped from 28-30 to 20 between two
hits both at Int 8, the only stat change in between being +1 Spirit (1→2, see the
MP-per-Spirit confirmation above). Spirit driving MaxMP is confirmed, but Zap damage
dropping when Spirit went up (not Int) doesn't fit a clean Int-only scaling model —
could be normal hit-to-hit variance (only a couple samples per Int value so far, not
enough to call a range yet), a Spirit-vs-Zap interaction nobody's flagged yet, or
something else (crit/no-crit variance, since no crit mechanic exists to explain outlier
hits either way). Don't treat the Int-scaling formula above as locked until more Zap
samples come in at repeated Int/Spirit combos to see if 20 or 28-30 is the outlier.

**Cat vs slime at matched stats (Int 8, Spirit 2):** Zap did 20 to both — no gap yet at
this data point.

**Cat vs slime at Int 9/Spirit 2, though: 21 vs 32, a real 11-point gap.** This time the
"cats resist electric" read holds up — matches the Cat vs Slime melee/Icebolt notes
above, which also showed a real cat-specific dip. So the Int 8 pair (20/20, no gap) now
reads as the outlier, not the Int 9 pair — consistent with the note right above about
Zap needing multiple hits per combo to separate signal from noise; the Int 8 "tie" may
just not have had enough samples to show the resistance that's clearly present at Int 9.
Tentatively treat "cat resists electric/Zap-type damage" as the working hypothesis
until the Int 8 case gets re-tested with more hits.

**Int 8→9 (Spirit held 2, target slime): 20→32, a +12 jump for +1 Int.** Way bigger
than the ~3/point average implied by the Int 1→8 climb (7-8→28-30 over 7 points). Two
readings now (this one and the 28-30→20 drop when Spirit went 1→2 above) that don't
fit a single clean linear-in-Int formula — starting to look less like isolated
variance and more like Zap's real formula has another input besides Int (Spirit
itself doing something non-monotonic to it, a level-based term, or genuine high
hit-to-hit variance that a single sample per data point can't average out). Recommend
multiple hits logged per Int/Spirit combo from here instead of one-off numbers, so a
real range can separate signal from noise.

**Icebolt damage, Hero1, Int 8, vs Cat:** 20. First data point for Icebolt (learned
this same session, see `SpellRequirementDataSheet.md`'s unlock log) — noticeably
weaker than Zap's 28-30 at the same Int 8 despite presumably being the "better" spell
Icebolt unlocks after Zap's baseline availability. Could mean Icebolt scales off a
different stat, has a different base/coefficient than Zap, or this single point isn't
representative yet (only one hit logged). Needs more samples, ideally against the same
enemy (slime) Zap was measured against, to compare apples-to-apples.

**Dog, Hero1, Str 10 (same as slime/cat tests):** melee 16-18, same range as slime/cat —
physical defense reads the same across all three so far. But 3 hits to kill, not 2 —
more HP than slime/cat while defense matches, so dog isn't just a reskin, it's a real
tankier Tier 1 (or a Tier boundary case). Worth checking exp/gold per kill too, not
logged yet for dog.

**Dog, Hero1 Str 11 (Level 2, same stats as the Str-11 slime/Zap readings above):**
melee 17-20 — 2026-08-18. Matches the Str-11 slime reading (also 17-20) exactly, further
confirming dog's physical defense reads the same as slime/cat's, just with more HP
behind it. Reported alongside a level-up (now Level 3, +1 more Strength → Str 12,
Agi 5, Vit/Int/Spirit still 1) — next damage numbers should be read as Str 12 unless
noted otherwise.

**Cat, same Hero1/Level 3 stats:** melee 18 (in line with the 16-18 vs slime, cat's
physical defense reads as roughly the same as slime's), but Zap dropped to 5-6 (vs 7-8
on slime) — same attacker stats both times, so the drop is on the *cat's* side, not
Hero1's. Means Zap is sensitive to per-monster defense (magic defense specifically,
maybe higher on cat than slime) even though melee barely moved — worth keeping an eye
on whether physical and magic defense are tracked as separate per-monster values once
`MonsterRoster.dm` gets real stat blocks, rather than one shared "defense" number. 2
melee hits to kill, 15 exp per kill — both identical to slime, so cat and slime are
reading as near-identical Tier 1 stat blocks so far, not just similar-feeling.

**Zap spread across Tier 1 at Int 1, same attacker (Hero1): slime 7-9, cat 5-6, dog
5-6, bat 4-5, fox 2-3.** 2026-08-18 — real range across the tier (7-9 down to 2-3,
more than a 2x gap) even though melee against these same monsters has been reading as
one shared defense value (see the bat/redslime notes above). Together these say Tier 1
monsters do NOT share a single flat "defense" number — physical and magic defense are
tracked separately per monster, physical mostly flat across the tier so far, magic
varying a lot (fox resists hard, slime barely resists at all). Matches the cat-resists-
electric hypothesis already floated below, just now with more monsters showing the same
kind of per-species magic-defense spread, not just cat as an outlier.

**Your working theory, 2026-08-18:** the magic-defense spread is either flat per-
monster (each species just has its own resist value, no grouping) or a group/elemental
typing system like later Dragon Quest games use (beast/bird/material/etc., each type
resisting or being weak to certain spell elements). Not distinguishable yet from this
data alone — both would produce the same "some monsters resist Zap more than others"
pattern. Telling them apart needs either (a) enough monsters tested to see resist
values cluster into a handful of discrete groups rather than being continuously spread
out, or (b) testing a second element (e.g. Icebolt/fire-type spells) against the same
monsters — if fox resists Zap but not Icebolt, that's a real typing signal; if it
resists everything proportionally, that points back to a flat per-monster stat instead.

**Cat, Hero1 Level 2, Str 11/Agi 5 (Int/Vit/Spirit still 1):** melee 18, Zap 6 —
2026-08-18. Matches the Level 3/Str 10/Int 1 cat readings above (melee 18, Zap 5-6)
almost exactly despite a different level and a point higher Str/Agi each. Useful as a
level-comparison point: Level 2 vs. Level 3 produced the same damage at roughly the
same stats, no sign yet that Level itself adds anything on top of the stats driving
melee/Zap — consistent with the formulas being purely stat-derived so far, though still
a thin sample.

## Table 6 — Incoming damage vs. Agility (hold enemy fixed, optional but useful)

Same enemy as Table 5. At each Agility value, let the enemy hit you 5-10 times and
record the range of damage taken (misses count as 0 — note how many misses out of how
many attempts too, if you can, since that might relate to Agility as well).

**Enemy type used:** dog (row 1), slime (row 2)

| Agility | Lowest hit taken | Highest hit taken | Misses / attempts |
|---|---|---|---|
| 4 | 6 | 8 | 0 misses seen, exact attempt count not tracked |
| 4 | (not logged) | (not logged) | 1 miss / 14 attacks (~7.1%), fight ended in Hero1's death |
| 4 (cat row) | (not logged) | (not logged) | 0 miss / 18 attacks, but 2 of the 18 were crits (~11.1% crit rate), 16 normal |
| 5 (cat row) | 5 | 6 | not tracked — 2026-08-18, Hero1 Level 3 |
| 5 (slime row) | 7 | 9 | not tracked — 2026-08-18, Hero1 Level 3 |
| 5 (dog row) | 7 | 8 | not tracked — 2026-08-18, Hero1 Level 3. One crit seen for 12 during this session (source monster not specified — likely one of the three above, not pinned to a specific enemy) |
| 5 (redslime row) | 9 | 10 | not tracked — 2026-08-18, Hero1 Level 3. A step up from plain slime's 7-9 at the same Agility — first sign redslime hits harder than its base-slime reskin, not just a palette swap |
| 6 (babble row) | 10 | 11 | not tracked — 2026-08-18, Hero1 Level 5, Str 13/Agi 6/Vit 2/Int 2/Spirit 2. No poison effect triggered across multiple fights/hits — see the babble row note in the "Monster difficulty ordering" table above, now a working conclusion that poison isn't real OG behavior for this monster |
| 6 (skeleton row) | 10 | 11 | not tracked — 2026-08-18, same Hero1 stats. Corrected from an earlier reversed reading — matches babble's incoming almost exactly, no sign of Tier 2 hitting harder here |

**Babble, outgoing at Str 13: 20-22.** 2026-08-18 — in line with the rest of Tier 1
(19-22 range at this Str), consistent with the "one shared Tier 1 defense value" pattern
holding up. Incoming from babble: 10-11 (already logged in Table 6), no poison
triggered — see the babble notes elsewhere in this file.

**Skeleton (first real Tier 2 combat data), Str 13 — corrected 2026-08-18:** outgoing
21-24, incoming 10-11 (numbers were reported reversed from these in an earlier pass of
this note, now fixed). **Actual read: not much different from Tier 1.** Hero1's melee
(21-24) is in line with the usual Tier 1 outgoing range (19-22ish), no real added
defense showing up here, and skeleton's own attack (10-11) matches babble's incoming
almost exactly. So the Tier 2 label isn't showing a mechanical jump yet, at least not
at this data point — retracts the "Tier 2 hits harder and defends better" read from the
previous version of this note.

**Drakee/Healer outgoing, Str 15, 2026-08-18:** drakee took 26-27 from Hero1's melee —
in line with the roster's incoming-damage gradient above (drakee near the top).
Healer took noticeably more than drakee (exact number not given, just "more") — reads
as a real squishy-healer archetype: hits about as hard as drakee on the incoming side
(11-13, tied) but has less physical defense, consistent with a support-type monster
rather than a frontline one.

**Healer's self/ally-heal ability — finally quantified, 2026-08-18:** casts on itself
or a wounded monster in sight, healing for **52**. Resolves the open gap flagged in
`SpellRequirementDataSheet.md`'s Monster AI table (2026-08-10 sighting, no numbers at
the time) and in this file's earlier Healer note. Worth a rough comparison once
convenient: 52 is close to Hero1's own confirmed Heal amount (60, same file's "Heal
amounts" section) — could mean monster Heal-type spells and player Heal share the same
formula/base, or it's coincidence at a single sample. Not confirmed either way yet.

**Your working read, same date: this whole 10-monster set is probably all Tier 1, not
split across Tier 1/Tier 2 the way `MonsterRoster.dm` currently codes skeleton and
healer.** Consistent with skeleton's numbers above reading identical to the rest of the
roster. Not changing the code on this yet — drakee and healer are still untested, and
this is your working belief from the data so far, not a full confirmation across all
10. Worth a final check once those two are in: if drakee/healer also read like Tier 1,
that's the point to actually flatten `MonsterRoster.dm`'s Tier 1/Tier 2 split for this
roster into one tier.
Tier 1 monster reading the same physical defense as slime/cat/dog/redslime so far;
the roster keeps looking like one shared defense value across the whole tier, with
individual monsters differentiating on HP, attack, or special behavior (redslime's
attack bump, babble's poison, Healer's heal) rather than defense.

**Redslime vs. slime, outgoing at Str 12: 19-21 both — identical.** Combined with
redslime's higher incoming damage above (9-10 vs. slime's 7-9), this narrows it down:
redslime's **Strength/attack** is higher than plain slime's, but its **defense** reads
the same (outgoing damage to it is unchanged) — not a flat "redslime is just tougher
overall" bump, specifically an attack-side difference. Your own read, confirmed by the
data.
|   |   |   |   |

---

## Heal amounts (flat, not stat-scaled per current design — confirm/overturn as data comes in)

| Spell | Amount | Int | Spirit | Notes |
|---|---|---|---|---|
| Heal | 60 | 8 | 2 | 2026-08-10, Hero1, first reading. Heals apply on completion of the cast animation, not instantly on cast — matches `GenericSpell`'s existing `spawn(cast_time)` delay pattern (`SkillCatalog.dm`), good sign the timing model was already right. |
| Heal | 63 | 9 | 3 | 2026-08-10, same session, later. **Overturns the "flat, not stat-scaled" design assumption** — Heal amount moved (+3) when Int and Spirit both ticked up by 1 each. Can't yet tell which stat is driving it (or both) since they changed together, not in isolation — needs a test where only one of Int/Spirit moves between two Heal casts to isolate it. `GenericSpell`'s heal branch (`SkillCatalog.dm`) currently uses a flat `heal_amount` per skill with zero stat scaling — that's now confirmed wrong and needs a scaling term added once the governing stat is identified. |

## Thornwhip damage vs slime, Str 10 (unchanged since creation)

| Attack | Damage | Notes |
|---|---|---|
| Plain melee | 16-18 | Baseline, same Str, logged earlier this session |
| Thornwhip | 11-14 | 2026-08-10 — lower than plain melee at the same Str, plausibly a range/reach tradeoff (3-tile line vs. melee's adjacent-only) rather than Thornwhip just being a weaker attack outright. `damage_multiplier` in `SkillCatalog.dm` is currently 1.4 (placeholder, same as plain `GenericPhysical`'s pattern) — real OG multiplier reads closer to ~0.65-0.8x a plain hit at this single data point, worth more samples before retuning the placeholder. |
| Thornwhip — **confirmed 2026-08-18** | ~80% of a normal hit | Confirmed as a deliberate design ratio, not just this session's sample variance: Thornwhip trades damage for reach, landing around 80% of a plain attack's damage. Matches the 0.65-0.8x range estimated from the single 2026-08-10 sample above — now a real confirmation, not just an estimate. **Directly contradicts the current code**: `SkillCatalog.dm`'s Thornwhip `damage_multiplier` is 1.4 (i.e. 140%, MORE than a plain hit), the opposite direction from confirmed OG behavior — needs retuning to roughly 0.8 once compiling is back on the table. |

## Monster difficulty ordering (OG-confirmed, weakest → strongest)

Real OG ordering for the first ten monsters, pasted directly from your own memory of
the original game (not a stat comparison from live testing — treat as a difficulty
*ranking*, not exact stat values). Also names two special abilities not previously
logged anywhere. This is the first real OG validation the `MonsterRoster.dm` Tier
1-4 grouping has gotten — that grouping was an AI guess from an earlier session, per
`TODOList.md`'s note, and this data already contradicts part of it.

**2026-08-18 ordering:** cat < slime < dog < red slime < bat < fox < babble (poison-
capable) < skeleton < drakee < Healer (self/ally heal). **"Healer" is the proper OG
name** — earlier notes here and in `SpellRequirementDataSheet.md` called this monster
"healslime"/"healer slime" before the correct name was confirmed; same monster
throughout, just renamed.

Current code placement for comparison (`Code/Combat/NPCs/MonsterRoster.dm` /
`Code/Combat/NPCs/EnemyNPCs.dm`):

| Monster | Current tier/location | Matches this ordering? |
|---|---|---|
| cat | Tier 1 | consistent (weakest end) |
| slime | Tier 1 (`EnemyNPCs.dm`, separate file) | consistent |
| dog | Tier 1 | consistent |
| redslime | Tier 1 | consistent |
| bat | Tier 1 | consistent |
| fox | Tier 1 | consistent |
| babble | Tier 1 | consistent; poison ability not implemented anywhere in code yet (no status-effect system exists). **2026-08-18 — working conclusion: probably not a real OG mechanic.** Multiple hits taken across more than one fight, poison never triggered once. Your read: babble likely doesn't actually poison in the OG at all — "poison-capable" from the original difficulty-ordering message was probably misremembered or was always a from-scratch idea for the remake, not something to port. Not fully ruled out (could still be a low proc chance), but treat "babble has no poison" as the working assumption rather than something still pending confirmation. |
| skeleton | **Tier 2** | ordering places skeleton *below* drakee, but code has skeleton in the stronger tier while drakee is still Tier 1 — direct contradiction, worth a closer look once tiers are revisited |
| drakee | Tier 1 | per this ordering drakee should be stronger than skeleton, but it's currently the weaker-tier one of the two |
| Healer | Tier 2, `Code/Combat/NPCs/MonsterRoster.dm` (`healer.dmi`) | **Confirmed 2026-08-18: "Healer" is the proper OG name** for the monster earlier notes called "healslime"/"healer slime" (2026-08-10 AI observation, `SpellRequirementDataSheet.md`) — same monster, not a separate gap, and it already had a real mob type + icon in code (`mob/enemy/healer`) the whole time, just under the older working name. Re-added to the trimmed roster under its correct name. Self/ally-heal behavior itself is still NOT implemented — no monster-side spellcasting exists anywhere yet (`TODOList.md` Phase 6), it's melee-only like everything else. |

Not acting on the skeleton/drakee contradiction or the missing healslime type right
now (no compiling this session) — just logging it so it's not lost.

## Full roster incoming-damage sweep — 2026-08-18 (confirms the original ordering)

Complete pass, all 10 monsters, same Hero1 stats held fixed the whole time (Level 6,
Str 15/Agi 7/Vit 2/Int 2/Spirit 2 — see the Level 6 snapshot above). This is the
cleanest data set collected so far since every monster was tested back-to-back at
identical attacker stats, no confounding level/stat changes between readings.

| Monster | Incoming damage |
|---|---|
| cat | 4-5 |
| slime | 5-6 |
| dog | 6-7 |
| redslime | 8-9 |
| bat | 8-9 (same as redslime) |
| fox | 9-10 |
| babble | 10-11 |
| skeleton | 10-11 (tied with babble) |
| drakee | 11-13 |
| healer | 11-13 (tied with drakee) |

**This is a clean, smooth gradient — and it lines up exactly with the original
difficulty ordering from the very first message of this session** (cat < slime < dog <
redslime < bat < fox < babble < skeleton < drakee < healer). Every step either goes up
or ties with the previous monster, no monster reads weaker than one earlier in the
list. Also bears on the Tier 1/Tier 2 question raised above: the climb is continuous,
no sudden jump between skeleton (currently coded Tier 2) and its neighbors — supports
the "these all read as one continuous tier, not two" read, now with the full roster
in, not just skeleton in isolation.

## Session checkpoint — 2026-08-18

**All 10 monsters in the trimmed roster now have at least one incoming-damage data
point** (see the full sweep table just above) — cat, slime, dog, redslime, bat, fox,
babble, skeleton, drakee, healer. Outgoing/Zap coverage is uneven (some monsters only
have incoming logged, not outgoing melee/Zap) — worth filling in outgoing hits against
drakee/healer specifically if you want full symmetric coverage, but the core "how does
the roster's difficulty actually order" question this session set out to answer is now
answered.

**Hero1 current baseline:** Level 6, Str 15 / Agi 7 / Vit 2 / Int 2 / Spirit 2 (assumed
unchanged), HP 93, MP 31. Use this as the assumed context for the next batch of data
unless a new snapshot gets reported.

Once you've got some of these filled in, send them back over (screenshot, typed, however
is easiest) and I'll look for the pattern.
