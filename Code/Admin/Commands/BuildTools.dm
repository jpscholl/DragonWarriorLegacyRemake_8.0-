// -----------------------------
// GM Building System (Phase 10)
// -----------------------------
// Three pickers (GMmaketurf/GMmakemob/GMmakearea) choose WHAT to place — "pick from
// list, 'None' cancels, picking a real type enters build mode" per the exact pattern
// GMbattlemode (GMCommands.dm) already established. GMmaketool separately chooses HOW
// to place it (one of 7 modes). The two are independent: changing the selection
// doesn't reset the current tool mode and vice versa — buildMode defaults to "Click"
// so a GM who's never touched GMmaketool still gets sane single-click placement the
// moment they pick something.
//
// Placement itself is driven by client-level MouseDown()/MouseUp()/MouseDrag()/
// MouseMove() overrides (BYOND's standard mechanism for drag/hold tools) rather than
// atom/Click() — one central dispatch point regardless of what's actually under the
// cursor (turf/obj/mob), matching the plan's explicit call for this approach. Every
// override calls ..() first — skipping that would silently break default click
// handling (item-use clicks, etc.) for EVERY client, not just GMs mid-build.
//
// GMmakemob correcting the design doc's /mob/monster/* — actual base type built in
// Stage 3 is /mob/enemy (MonsterRoster.dm).

#define BUILD_MODE_CLICK "Click"
#define BUILD_MODE_DRAG "Drag"
#define BUILD_MODE_BLOCK "Block"
#define BUILD_MODE_LINE "Line"
#define BUILD_MODE_MOVE "Move"
#define BUILD_MODE_FLOOD "Flood"
#define BUILD_MODE_DELETE "Delete"

// Safety cap for Block/Flood (not an OG-confirmed number — just a guard so a huge drag
// or a misclicked wide-open Flood region can't freeze the server processing thousands
// of tiles in one proc call).
#define MAX_BUILD_FILL_TILES 2000

// Interface.dmf's map element name — the mouse overrides below need to ignore clicks
// on any OTHER control (StatsCommands' inventory/stat links, etc.), or e.g. clicking an
// inventory item to use it resolves (via GetTurfOf()'s loc-walk, since obj/item lives
// at loc = the carrying mob) straight back to the GM's own tile and silently triggers
// placement/flood/delete there too.
//
// IsMapControl() checks with findtext() (substring), not exact equality — BYOND's
// exact runtime format for the control param isn't something a compile-only check can
// verify (some skins report the bare elem id "Gameplay", others prefix it with the
// containing window, e.g. "Main.Gameplay"). An exact-match miss here doesn't error, it
// just silently no-ops every click — worth being permissive about rather than exact.
#define BUILD_MAP_CONTROL "Gameplay"

proc/IsMapControl(control)
    return control && findtext(control, BUILD_MAP_CONTROL)

// get_turf() isn't a builtin in this DM version — walks an atom's loc chain up to the
// turf it's standing on (or returns it directly if it's already a turf). Reading .loc
// is unrestricted regardless of static type (only ASSIGNING it is, see
// PlaceBuildSelection's area branch below), so this is safe on any atom.
proc/GetTurfOf(atom/A)
    if(!A) return null
    var/atom/cur = A
    while(cur && !isturf(cur))
        cur = cur.loc
    return cur

// -----------------------------
// Client build state
// -----------------------------
client
    var/buildMode = BUILD_MODE_CLICK  // HOW to place — independent of WHAT (below)
    var/buildKind = null              // "turf" / "mob" / "area" — null = no selection, build mode inactive
    var/buildSelection = null         // typepath to place (turf/mob) or assign (area)
    var/turf/buildDownTurf = null     // captured on MouseDown, consumed by Block/Line/Move on MouseUp
    var/atom/movable/buildGrabbedAtom = null  // captured on MouseDown for Move mode —
                                                // /atom/movable specifically (not bare
                                                // /atom): only movable atoms have a
                                                // freely-assignable loc, see MouseUp's
                                                // buildGrabbedAtom.loc = T below
    var/image/buildCursorImage = null // single square tracking the hovered tile

    // -----------------------------
    // Cursor overlay — same screen-overlay-via-client.images shape GMseeareas's area
    // grid (GMCommands.dm) already uses, just one square instead of a grid. Uses the
    // real confirmed asset for this ('meter.dmi', icon_state "select" — the actual OG
    // build-target cursor), not a procedurally-drawn stand-in.
    // -----------------------------
    proc/UpdateBuildCursor(turf/T)
        if(!T) return
        if(!buildCursorImage)
            buildCursorImage = image('meter.dmi', T, "select")
            buildCursorImage.layer = 100  // high enough to draw over turfs/objs/mobs
            images += buildCursorImage
        else if(buildCursorImage.loc != T)
            // BYOND fires MouseMove on sub-tile pixel movement, not just tile changes —
            // skip the reassignment (and the client-side overlay resync it triggers)
            // when the mouse is still hovering the same tile as last time.
            buildCursorImage.loc = T

    proc/ClearBuildCursor()
        if(buildCursorImage)
            images -= buildCursorImage
            buildCursorImage = null

    // Called whenever a picker's list returns "None", or a GM otherwise cancels —
    // drops the current selection entirely (buildMode/its own choice is left alone,
    // see file header).
    proc/StopBuildSelection()
        buildSelection = null
        buildKind = null
        buildDownTurf = null
        buildGrabbedAtom = null
        ClearBuildCursor()

    // -----------------------------
    // Placement helpers — shared by every mode below
    // -----------------------------
    proc/PlaceBuildSelection(turf/T)
        if(!T || !buildSelection) return
        switch(buildKind)
            if("turf", "mob")
                new buildSelection(T)
            if("area")
                var/area/target = FindAreaInstance(buildSelection)
                if(target)
                    // turf/loc isn't directly assignable (unlike a movable atom's) —
                    // adding the turf to the area's own contents is the real mechanism
                    // for reparenting it to a different area.
                    target.contents += T
                else if(mob)
                    mob << output("No existing instance of that area type found in the world.", "Info")

    // Areas aren't placed as fresh instances per tile — a turf gets reassigned to
    // whichever REAL instance of that area type already exists in the world (same
    // enumeration style GMbattlemode already uses to build its own area picker list).
    proc/FindAreaInstance(typepath)
        for(var/area/A in world)
            if(A.type == typepath) return A
        return null

    // First non-turf, non-player atom on the tile — Move never grabs a real character.
    proc/FindMovableAtom(turf/T)
        if(!T) return null
        for(var/atom/movable/A in T.contents)
            if(istype(A, /mob/player)) continue
            return A
        return null

    // Delete mode: clears whatever's on the tile (never a real player) THEN places the
    // current selection — confirmed "clear-and-replace" semantics per the build plan,
    // not a plain removal. This is the one spot in Stage 8 where the plan's own
    // wording was genuinely ambiguous (a "Delete" tool that ends by placing something
    // reads oddly at first) — this is the most literal reading of "clears the clicked
    // tile then immediately places the current selection," and the practical
    // difference from Click mode is that Delete removes any existing occupant first
    // instead of placing on top of it.
    proc/ClearAndPlace(turf/T)
        if(!T) return
        for(var/atom/movable/A in T.contents)
            if(istype(A, /mob/player)) continue
            del A
        PlaceBuildSelection(T)

    proc/PlaceBuildRect(turf/T1, turf/T2)
        if(!T1 || !T2 || T1.z != T2.z) return
        var/x1 = min(T1.x, T2.x)
        var/x2 = max(T1.x, T2.x)
        var/y1 = min(T1.y, T2.y)
        var/y2 = max(T1.y, T2.y)

        var/placed = 0
        for(var/xx = x1 to x2)
            for(var/yy = y1 to y2)
                if(placed >= MAX_BUILD_FILL_TILES)
                    if(mob) mob << output("Block hit the [MAX_BUILD_FILL_TILES]-tile safety cap — stopped early.", "Info")
                    return
                var/turf/T = locate(xx, yy, T1.z)
                if(T)
                    PlaceBuildSelection(T)
                    placed++

    // Cardinal-only, matching this game's 4-directional movement (same "pick whichever
    // axis has the bigger gap" idea as StepRelativeTo(), EnemyNPCs.dm) — draws straight
    // along whichever axis moved more between the down/up points, at the down-point's
    // fixed coordinate on the other axis, ignoring the smaller axis entirely.
    proc/PlaceBuildLine(turf/T1, turf/T2)
        if(!T1 || !T2 || T1.z != T2.z) return
        var/dx = T2.x - T1.x
        var/dy = T2.y - T1.y

        if(abs(dx) >= abs(dy))
            var/x1 = min(T1.x, T2.x)
            var/x2 = max(T1.x, T2.x)
            for(var/xx = x1 to x2)
                var/turf/T = locate(xx, T1.y, T1.z)
                if(T) PlaceBuildSelection(T)
        else
            var/y1 = min(T1.y, T2.y)
            var/y2 = max(T1.y, T2.y)
            for(var/yy = y1 to y2)
                var/turf/T = locate(T1.x, yy, T1.z)
                if(T) PlaceBuildSelection(T)

    // Same-icon/icon_state contiguous BFS fill, turf-only (a "flood" of mobs or area
    // reassignment doesn't have a clean same-icon/icon_state notion to bound itself
    // by — restricted here rather than guessed at, the one spot flagged rougher per
    // the build plan's own allowance for Move/Flood).
    proc/FloodFillBuild(turf/start)
        if(!start) return
        if(buildKind != "turf")
            if(mob) mob << output("Flood only works with a turf selection.", "Info")
            return

        var/matchIcon = start.icon
        var/matchState = start.icon_state

        // Read cursor instead of queue.Cut()-ing the front off on every pop (which
        // shifts the whole remaining list down one slot each time — O(n) per pop, so
        // O(n^2) overall as a fill approaches the tile cap), and an associative list
        // as a hash set for `visited` instead of a plain list scanned with `in` (O(n)
        // per membership check, up to 4x per tile) — both matter here since this is
        // exactly the "large contiguous region" case MAX_BUILD_FILL_TILES exists to
        // keep bounded in the first place.
        var/list/queue = list(start)
        var/queueIndex = 1
        var/list/visited = list()
        visited[start] = TRUE
        var/filled = 0

        while(queueIndex <= queue.len)
            var/turf/T = queue[queueIndex]
            queueIndex++

            if(filled >= MAX_BUILD_FILL_TILES)
                if(mob) mob << output("Flood hit the [MAX_BUILD_FILL_TILES]-tile safety cap — stopped early.", "Info")
                return

            new buildSelection(T)
            filled++

            for(var/d in list(NORTH, SOUTH, EAST, WEST))
                var/turf/N = get_step(T, d)
                if(!N || visited[N]) continue
                if(N.icon != matchIcon || N.icon_state != matchState) continue
                visited[N] = TRUE
                queue += N

    // -----------------------------
    // Mouse dispatch
    // -----------------------------
    MouseDown(atom/object, location, control, params)
        ..()
        if(!IsMapControl(control)) return
        if(!mob || !canBuild || !buildSelection) return
        var/turf/T = GetTurfOf(object)
        if(!T) return

        buildDownTurf = T

        switch(buildMode)
            if(BUILD_MODE_CLICK, BUILD_MODE_DRAG)
                PlaceBuildSelection(T)
            if(BUILD_MODE_MOVE)
                buildGrabbedAtom = FindMovableAtom(T)
                if(!buildGrabbedAtom)
                    mob << output("Nothing to move here.", "Info")
            if(BUILD_MODE_FLOOD)
                FloodFillBuild(T)
            if(BUILD_MODE_DELETE)
                ClearAndPlace(T)
            // Block/Line just record buildDownTurf above — the actual placement
            // happens on MouseUp once the second point is known.

    MouseUp(atom/object, location, control, params)
        ..()
        // Always clear grabbed/down state on any mouse-up, even one that lands off the
        // map (a drag released over the inventory panel, say) — otherwise a stale
        // buildDownTurf/buildGrabbedAtom would carry into the next interaction.
        if(!mob || !canBuild || !buildSelection)
            buildDownTurf = null
            buildGrabbedAtom = null
            return

        if(IsMapControl(control))
            var/turf/T = GetTurfOf(object)
            if(T)
                switch(buildMode)
                    if(BUILD_MODE_BLOCK)
                        if(buildDownTurf) PlaceBuildRect(buildDownTurf, T)
                    if(BUILD_MODE_LINE)
                        if(buildDownTurf) PlaceBuildLine(buildDownTurf, T)
                    if(BUILD_MODE_MOVE)
                        if(buildGrabbedAtom) buildGrabbedAtom.loc = T

        buildDownTurf = null
        buildGrabbedAtom = null

    MouseDrag(atom/src_object, atom/over_object, src_location, over_location, src_control, over_control, params)
        ..()
        if(!IsMapControl(src_control) || !IsMapControl(over_control)) return
        if(!mob || !canBuild || !buildSelection) return
        if(buildMode != BUILD_MODE_DRAG) return
        var/turf/T = GetTurfOf(over_object)
        if(T) PlaceBuildSelection(T)

    MouseMove(atom/object, location, control, params)
        ..()
        if(!IsMapControl(control)) return
        if(!buildSelection) return
        var/turf/T = GetTurfOf(object)
        if(T) UpdateBuildCursor(T)

// -----------------------------
// Shared picker apply logic — GMmaketurf/GMmakemob/GMmakearea below all follow the
// exact same "check access, show the list, None clears the selection, anything else
// sets buildSelection/buildKind and reminds about GMmaketool" shape; this is that
// shape, written once instead of three times.
// -----------------------------
mob/proc/PickBuildSelection(list/choices, prompt, title, kind)
    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    var/choice = input(src, prompt, title) in choices
    var/picked = choices[choice]

    if(!picked)
        client.StopBuildSelection()
        src << output("Build selection cleared.", "Info")
        return

    client.buildSelection = picked
    client.buildKind = kind
    src << output("[choice] selected. Use GMmaketool to pick a placement mode, then click the map.", "Info")

// -----------------------------
// GMmaketurf — see Code/World/Turfs.dm's own header comment: most visual turf variants
// are deliberately collapsed into a handful of base types (painted as map-editor
// INSTANCES with a custom icon_state, not separate hardcoded subtypes) — this list is
// necessarily just those base types, same limitation that comment already describes.
// bedhead itself excluded (its own comment: "Not meant to be placed directly on a map").
// -----------------------------
mob/verb/GMmaketurf()
    set category = "GM"
    set desc = "Pick a turf type for the build tool to place"

    var/list/choices = list(
        "Ground" = /turf/ground,
        "Floor" = /turf/floor,
        "Furniture" = /turf/furniture,
        "Bed (left)" = /turf/furniture/bedleft,
        "Wood Bed (left)" = /turf/furniture/woodbedleft,
        "Counter" = /turf/furniture/counter,
        "Tree" = /turf/tree,
        "Stairs" = /turf/stairs,
        "Stairs Up" = /turf/stairs/stairsup,
        "Stairs Down" = /turf/stairs/stairsdown,
        "Wall" = /turf/wall,
        "Fence" = /turf/fence,
        "Sky" = /turf/sky,
        "Bridge" = /turf/bridge,
        "Water" = /turf/water,
        "Warp" = /turf/warp,
        "None" = null,
    )

    PickBuildSelection(choices, "Choose a turf type to place (or None to cancel):", "GMmaketurf", "turf")

// -----------------------------
// GMmakemob — built from the real Stage 3 monster roster (MonsterRoster.dm) via
// typesof(), not a hardcoded duplicate list, so it stays in sync automatically. Display
// names derived from each type's own bare path segment (same capitalize-first-letter
// convention MonsterRoster.dm already used for its `name` var), reusing
// GetIconFilename() (LoginMenu.dm) for that split — it's already exactly "stringify,
// split on /, take the last segment," it just usually gets an icon resource rather
// than a typepath.
// -----------------------------
mob/proc/GetMonsterChoices()
    var/list/choices = list("None" = null)
    for(var/type in typesof(/mob/enemy))
        if(type == /mob/enemy) continue  // abstract base, not a real placeable monster
        var/bareName = GetIconFilename(type)
        var/displayName = uppertext(copytext(bareName, 1, 2)) + copytext(bareName, 2)
        choices[displayName] = type
    return choices

mob/verb/GMmakemob()
    set category = "GM"
    set desc = "Pick a monster type for the build tool to place"

    PickBuildSelection(GetMonsterChoices(), "Choose a monster to place (or None to cancel):", "GMmakemob", "mob")

// -----------------------------
// GMmakearea — placing "an area" means reassigning a turf to an EXISTING instance of
// that area type (FindAreaInstance() above), not spawning a fresh one — same
// enumeration style GMbattlemode (GMCommands.dm) already uses to build its own list of
// real area instances. playerStart excluded (special spawn marker, not a normal
// paintable area type — its own icon/icon_state don't even match the rest of Area.dm's
// environment.dmi convention).
// -----------------------------
mob/verb/GMmakearea()
    set category = "GM"
    set desc = "Pick an area type for the build tool to assign"

    var/list/choices = list(
        "Casino" = /area/casino,
        "Dungeon" = /area/dungeon,
        "Boss" = /area/boss,
        "Forest" = /area/forest,
        "Town (Rain)" = /area/townrain,
        "Town" = /area/town,
        "Battle" = /area/battle,
        "Castle" = /area/castle,
        "Cave" = /area/cave,
        "Old" = /area/old,
        "Snow" = /area/snow,
        "Snow (Night)" = /area/snownight,
        "Bar" = /area/bar,
        "Jail" = /area/jail,
        "Rain" = /area/rain,
        "Rain (Night)" = /area/rainnight,
        "Ceiling" = /area/ceiling,
        "Visible" = /area/visible,
        "Wilderness" = /area/wilderness,
        "Temple" = /area/temple,
        "Deep Water 1" = /area/deepwater1,
        "Deep Water 1 (Night)" = /area/deepwaternight1,
        "Deep Water" = /area/deepwater,
        "Deep Water (Night)" = /area/deepwaternight,
        "Water 1" = /area/water1,
        "Water 1 (Night)" = /area/waternight1,
        "Water" = /area/water,
        "Water (Night)" = /area/waternight,
        "Rave" = /area/rave,
        "None" = null,
    )

    PickBuildSelection(choices, "Choose an area type to assign (or None to cancel):", "GMmakearea", "area")

// -----------------------------
// GMmaketool — confirmed OG text ("[Mode] tool selected.") per the build plan.
// -----------------------------
mob/verb/GMmaketool()
    set category = "GM"
    set desc = "Pick how the build tool places things (Click/Drag/Block/Line/Move/Flood/Delete)"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    var/list/modes = list(
        BUILD_MODE_CLICK,
        BUILD_MODE_DRAG,
        BUILD_MODE_BLOCK,
        BUILD_MODE_LINE,
        BUILD_MODE_MOVE,
        BUILD_MODE_FLOOD,
        BUILD_MODE_DELETE,
        "None",
    )

    var/choice = input(src, "Choose a build tool mode:", "GMmaketool") in modes
    if(choice == "None") return  // just closes — there's always a current mode
                                   // (defaults to Click), nothing to "cancel" to

    client.buildMode = choice
    src << output("[choice] tool selected.", "Info")
