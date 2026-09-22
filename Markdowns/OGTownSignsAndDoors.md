# OG Town — Sign & Door Flavor Text

**Status: Applied to `Maps/OGDWLv8.0.dmm`.** Everything in the tables below has been
written into the map file directly (new per-instance map keys for anything that needed
unique text, in-place edits for anything that was already unique to its own key). This
doc is now a record of what was done, not a to-do list.

Source: `C:\Users\jpsch\Downloads\map.dmm`, a clean (non-decompiled, directly readable)
DMM export of the OG starting town. Verified programmatically (not just visually) that
it's coordinate-identical to `Maps/OGDWLv8.0.dmm` — same x/y grid, same z-order offset
by exactly 1 — so every door/sign below was matched to its real DWLR tile by direct
coordinate lookup, not guesswork.

## Notes from applying this

- Several OG-named doors (Room 22/23/21/24/13/14/11/12, Inn, House 3, Silk's Mansion,
  Eatery, House 1, Bar, Room 3/1/2, Wood House 1/2, Apartment 1/2/3, Jail) were sitting
  on a handful of **shared generic door tiles** in DWLR's map (e.g. one map key used for
  10 different plain doors across the inn building). Editing those keys in place would
  have named every door sharing that key identically, so each of those got a fresh
  per-instance map key instead — only that one tile changed, every other door using the
  old shared key is still a plain unnamed door.
- DWLR's door locking model is simpler than the OG's: a door's own `name` var doubles as
  the required key name (`HasMatchingKey(name)` in `Code/World/Obj.dm`), so there's no
  separate `lock = "X key"` field to carry over — just `name` and `is_locked`.
- The "Bar" door duplicate flagged below turned out to be real: OG's source has two
  separate physical door tiles both named "Bar" (one in the woodfloor town area, one in
  `/area/bar`), both now named/locked to match.
- The two `/area/castle` apartment/jail doors used DWLR's jail-icon door object even for
  the (non-jail) apartments — left the icon as-is since this doc is text-only in scope,
  but flagging it as a possible visual follow-up.
- The warp pair (below) was already fully wired up in DWLR — no map change needed there.

## Signs

| Location | Sign type | Name | Message |
|---|---|---|---|
| Town (rain area) | `/stat/sign/wooden` | Grunge Cafe | "Stop by and mess around with us!" |
| Town (rain area) | `/stat/sign/inn` | *(default)* | "Wood N. Inn" |
| Town (rain area) | `/stat/sign/wooden` | Church | "Welcome to the Church" |
| Town (rain area) | `/stat/sign/wooden` | *(plain, no override — bare sign)* | — |
| Town (rain area) | `/stat/sign/inn` | *(plain, no override — bare sign)* | — |
| Wilderness | `/stat/sign/grave` | *(plain — no name/message override in source)* | — |
| Town | `/stat/sign/church` | *(plain — no name/message override in source)* | — |

## Doors — name + lock/key pairing

Every door below is `/stat/door/wooden` unless noted. `locked = 1` means it starts
locked; omitted `locked` in the source means it defaults to whatever `/stat/door`'s own
base default is (worth double-checking DWLR's own door default rather than assuming).

### Town (redcobble area — the inn/rooms building)
| Door name | Lock (key name) | Starts locked? |
|---|---|---|
| Room 22 | Room 22 key | (default) |
| Room 23 | Room 23 key | (default) |
| Room 21 | Room 21 key | (default) |
| Room 24 | Room 24 key | (default) |
| Room 13 | Room 13 key | (default) |
| Church door | Church key | (default) |
| Room 14 | Room 14 key | (default) |
| Room 11 | Room 11 key | (default) |
| Room 12 | Room 12 key | (default) |
| Inn | Inn key | **locked = 1** |
| House 3 | House 3 key | (default) |
| Silk's Mansion | Silk's Mansion key | (default) |
| Eatery | Eatery key | **locked = 1** |
| *(unnamed door)* | — | (default) — plain door, no override |

### Town (woodfloor area)
| Door name | Lock (key name) | Starts locked? |
|---|---|---|
| House 1 | House 1 key | **explicitly locked = 0** (starts unlocked — deliberate) |
| Bar | Bar key | **locked = 1** |
| Room 3 | Room 3 key | **locked = 1** |
| Room 1 | Room 1 key | **locked = 1** |
| Room 2 | Room 2 key | **locked = 1** |
| Wood House 1 | Wood House 1 key | **locked = 1** |
| Wood House 2 | Wood House 2 key | **locked = 1** |
| *(unnamed door)* | — | (default) — plain door, no override |

### `/area/bar`
| Door name | Lock (key name) | Starts locked? |
|---|---|---|
| Bar | Bar key | **locked = 1** — same name/key as the woodfloor Bar door above; check whether that's a real second entrance or a duplicate that should stay in sync |

### `/area/castle`
| Door name | Lock (key name) | Starts locked? | Door type |
|---|---|---|---|---|
| Apartment 3 | Apartment 3 key | **locked = 1** | wooden |
| Apartment 2 | Apartment 2 key | **locked = 1** | wooden |
| Apartment 1 | Apartment 1 key | **locked = 1** | wooden |
| Jail | Jail key | **locked = 1** | `/stat/door/jail` |
| Battle arena | Battle arena key | **locked = 1** | `/stat/door/jail` |
| *(unnamed door)* | — | (default) — plain door, no override |

### `/area/cave`
| Door name | Lock (key name) | Starts locked? |
|---|---|---|
| old door | old door key | **locked = 1** |

### `/area/ceiling`
| Door name | Lock (key name) | Starts locked? |
|---|---|---|
| House 2 | House 2 key | (default) |

## Warp points (bonus find — turned out to be already done)

OG's source has two linked warp tiles pointing at each other by name (`name = "old
warp"; warpto = "cave warp"` and its mirror). DWLR's `/turf/warp` (`Code/World/Turfs.dm`)
uses a different but equivalent mechanism — two warp tiles link automatically when they
share the same `warpName` (`FindWarpPartner()`, matched at runtime, no explicit
`warpto` pointer). Checked the actual matching tiles in `Maps/OGDWLv8.0.dmm`
(coordinate-matched from the OG source) and **they already share `warpName =
"cave-townrain"`** — this pair is already fully linked. No map change needed.

## Not covered here

This file only catalogs signs, doors, and warps per the user's specific ask. The source
map also has real placement for `playerstart`/`playerspawn`, `bookcase`, `chest`,
`drawers`, `pot`, `fooddrawers`, and NPC stat placements (`/stat/npc/*`) with real
per-area variants (e.g. `coldman`/`icedancer` reskins for snow regions) — worth a separate
pass if those also need restoring, not pulled into this doc.
