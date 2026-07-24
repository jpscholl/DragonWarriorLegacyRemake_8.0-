# Obj Repaint Reference

Same purpose as `TurfRepaintReference.md` — exact `icon_state`/`name`/`message` values
every collapsed `obj/stat/*` type used to have, pulled from `Obj.dm` right before the
collapse. Use this while going through the map editor's "Pending Map Errors" dialog and
the instance tool.

`obj/door` itself (the real top-level type, created by `GM_Create_Lockable()`) and
`obj/ceiling` were never touched — nothing to repaint there.

---

## `/obj/stat/door` (base: `door.dmi`, name "door", density 1, reuses `/obj/door`'s behavior)

| Old type | icon_state | closed_icon_state | Needs repainting? |
|---|---|---|---|
| jail | `jail` | `jail` | Yes — set **both** vars on the instance |
| wooden | `wooden` | `wooden` | **No** — identical to the base's own defaults, remap straight to `/obj/stat/door` with no instance override needed |

## `/obj/stat/drawers` (now a single type, no sub-nesting)

| Old type | icon_state | Needs repainting? |
|---|---|---|
| wooden | `drawers` | **No** — this is now the base type's own default |

## `/obj/stat/bookcase` (now a single type, no sub-nesting)

| Old type | icon_state | Needs repainting? |
|---|---|---|
| bookcase | `bookcase` | **No** — this is now the base type's own default |

## `/obj/stat/chest` (now a single type, no sub-nesting)

| Old type | icon_state | Needs repainting? |
|---|---|---|
| wooden | `chestclosed` | **No** — this is now the base type's own default |

## `/obj/stat/sign` (base: `sign.dmi`, density 1, keeps its real `OnInteract()`)

All four need repainting — the base has no default icon_state/name/message at all.

| Old type | icon_state | name | message |
|---|---|---|---|
| inn | `inn` | inn | "Welcome, traveler! Rooms are available inside — rest here to restore your HP and MP." |
| church | `church` | church | "This is a place of healing and hope. The priests within can cure ailments and lift curses." |
| wooden | `sign` (not "wooden") | wooden | "PLACEHOLDER: edit this sign's message to whatever this one should actually say." |
| grave | `grave` | grave | "He gawn!" |

## `/obj/stat/pot` (base: `pots.dmi`, density 1 — no default icon_state at all)

Both need repainting — unlike drawers/bookcase/chest, the base was never given either
child's look as a default, so it renders blank until you set one.

| Old type | icon_state |
|---|---|
| woodpot | `woodpot` |
| pot | `pot` |
