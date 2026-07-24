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

**Vitality held at:** ______

| Level | MaxHP |
|---|---|
|   |   |
|   |   |
|   |   |
|   |   |
|   |   |

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

**Intelligence held at:** ______

| Level | MaxMP |
|---|---|
|   |   |
|   |   |
|   |   |
|   |   |
|   |   |

## Table 5 — Outgoing damage vs. Strength (hold enemy + weapon fixed)

Pick ONE enemy type via `GMmakemob` and use it for the whole table (note which one).
Use the same weapon/no weapon the whole time. At each Strength value, hit the enemy
5-10 times with a normal attack (Numpad 9) and record the **lowest, highest, and a few
typical** damage numbers you see — note separately if any hits were criticals, and how
much those did.

**Enemy type used:** ______ **Weapon equipped:** ______

| Strength | Lowest hit | Highest (non-crit) | A few typical hits | Crit damage seen |
|---|---|---|---|---|
|   |   |   |   |   |
|   |   |   |   |   |
|   |   |   |   |   |
|   |   |   |   |   |
|   |   |   |   |   |

## Table 6 — Incoming damage vs. Agility (hold enemy fixed, optional but useful)

Same enemy as Table 5. At each Agility value, let the enemy hit you 5-10 times and
record the range of damage taken (misses count as 0 — note how many misses out of how
many attempts too, if you can, since that might relate to Agility as well).

**Enemy type used:** ______

| Agility | Lowest hit taken | Highest hit taken | Misses / attempts |
|---|---|---|---|
|   |   |   |   |
|   |   |   |   |
|   |   |   |   |
|   |   |   |   |
|   |   |   |   |

---

Once you've got some of these filled in, send them back over (screenshot, typed, however
is easiest) and I'll look for the pattern.
