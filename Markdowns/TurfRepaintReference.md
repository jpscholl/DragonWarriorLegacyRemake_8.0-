# Turf Repaint Reference

Exact `icon_state`/`name` values every collapsed type used to have, pulled straight from
`Turfs.dm` as it was right before the collapse. Use this while going through the map
editor's "Pending Map Errors" dialog and the instance tool — for each original type path,
set the instance's `icon_state` (and `name`, only where noted) to match.

Base type only needs the `icon` override if a row says so (curtains is the only one that
used a different icon file than its group).

---

## `/turf/ground` (base: `grass.dmi`, density 0)

| Old type | icon_state | name |
|---|---|---|
| grass | `grass` | grass |
| brush | `brush` | brush |
| flowers | `flowers` | flowers |
| farmland | `farmland` | farmland |
| cavedirt | `cavedirt` | dirt |
| sand | `sand` | sand |

## `/turf/floor` (base: `floor.dmi`, density 0)

| Old type | icon_state | name |
|---|---|---|
| cobble | `redcobble` | cobble |
| burntcobble | `burntcobble` | cobble |
| carpet | `carpet` | floor |
| woodfloor | `woodfloor` | floor |
| stool | `stool` | stool |
| woodchair | `chair` | chair |
| path | `path` | path |

## `/turf/furniture` (base: `table.dmi`, density 1)

`bedhead`/`bedleft`/`woodbedleft`/`counter` are still real types — don't repaint those,
they already work. Everything else below is now a plain instance.

| Old type | icon_state | name |
|---|---|---|
| table | `table` | table |
| woodtable | `woodtable` | table |
| stonetable | `stonetable` | table |
| woodtableleft | `woodtableleft` | table |
| woodtableright | `woodtableright` | table |
| plant | `plant` | plant |
| stove | `stove` | stove |
| curtains | `curtains` | curtains (**also set icon to `wall.dmi`** — this one used a different icon file than the rest of the furniture group) |
| statue | `statue` | statue |
| tub | `tub` | tub |
| bedright | `bedright` | bed |
| woodbedright | `woodbedright` | bed |
| throneright | `throneright` | throne |
| throneleft | `throneleft` | throne |
| thronecenter | `thronecenter` | throne |
| thronearm | `thronedown` (**not "thronearm" — the type name and icon_state didn't match originally**) | throne |
| evilthrone | `evilthrone` | throne |

## `/turf/tree` (base: `tree.dmi`, density 1)

| Old type | icon_state | name |
|---|---|---|
| tree | `tree` | tree |

## `/turf/stairs` (base: `stairs.dmi`, density 0)

`stairsup`/`stairsdown` are still real types — don't repaint those. Only this one collapsed:

| Old type | icon_state | name |
|---|---|---|
| cavestairsup | `caveup` | stairs |

## `/turf/wall` (base: `wall.dmi`, name "wall", density 1)

| Old type | icon_state |
|---|---|
| stonewall | `stone` |
| stonewalledge | `stoneedge` |
| cobblewall | `cobble` |
| cobblewalledge | `cobbleedge` |
| cavewall | `cavewall` |
| cavewalledge | `cavewalledge` |
| logwall | `log` |
| pillartop | `pillarup` (name: pillar) |
| pillarbottom | `pillardown` (name: pillar) |
| voidwall | `void` (name: void) |
| woodwall | `wood` |
| woodwalledge | `woodedge` |
| wooddownleftcorner | `wooddownleft` |
| wooddownrightcorner | `wooddownright` |
| woodupleftcorner | `woodupleft` |
| wooduprightcorner | `woodupright` |

## `/turf/fence` (base: `wall.dmi`, name "fence", density 1)

| Old type | icon_state |
|---|---|
| fence | `fence` |
| sandfence | `sandfence` |

## `/turf/sky` (base: `sky.dmi`, name "sky", density 0)

| Old type | icon_state |
|---|---|
| sky | `sky` |

## `/turf/bridge` (base: `bridge.dmi`, name "bridge", density 0)

| Old type | icon_state |
|---|---|
| bridgev | `bridge` (not "bridgev") |
| bridgeh | `bridgeh` |
| stonebridge | `stonebridge` |

## `/turf/water` (base: `water.dmi`, name "water", density 1)

| Old type | icon_state | name |
|---|---|---|
| water | `water` | water |
| upedge | `upedge` | wall |
| downedge | `downedge` | water temple |
| rightedge | `rightedge` | water temple |
| leftedge | `leftedge` | water temple |
| upleftedge | `upleftedge` | water temple |
| uprightedge | `uprightedge` | wall |
| downleftedge | `downleftedge` | wall |
| downrightedge | `downrightedge` | wall |

## `/turf/warp` (base: `warp.dmi`, name "warp")

| Old type | icon_state |
|---|---|
| warp | `warp` |
