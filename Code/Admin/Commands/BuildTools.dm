// -----------------------------
// GM Building System — three pickers (GM_MakeTurf/GM_MakeMob/GM_MakeArea) choose WHAT
// to place; GM_MakeTool separately chooses HOW (one of 7 modes). The two are
// independent — buildMode defaults to "Click" so a GM who's never touched
// GM_MakeTool still gets sane single-click placement. Placement is driven by
// client-level MouseDown()/MouseUp()/MouseDrag()/MouseMove() overrides (BYOND's
// standard drag/hold mechanism), not atom/Click() — one central dispatch point
// regardless of what's under the cursor. Every override calls ..() first — skipping
// that would silently break default click handling for EVERY client, not just GMs
// mid-build.
// -----------------------------

#define BUILD_MODE_CLICK "Click"
#define BUILD_MODE_DRAG "Drag"
#define BUILD_MODE_BLOCK "Block"
#define BUILD_MODE_LINE "Line"
#define BUILD_MODE_MOVE "Move"
#define BUILD_MODE_FLOOD "Flood"
#define BUILD_MODE_DELETE "Delete"

// Safety cap for Block/Flood — not an OG-confirmed number, just a guard so a huge drag
// or misclicked Flood region can't freeze the server processing thousands of tiles.
#define MAX_BUILD_FILL_TILES 2000

// Interface.dmf's map element name — the mouse overrides need to ignore clicks on any
// OTHER control, or e.g. clicking an inventory item resolves (via GetTurfOf()'s
// loc-walk) straight back to the GM's own tile and triggers placement there too.
// findtext() (substring), not exact equality — some skins prefix the control param
// with the containing window (e.g. "Main.Gameplay") — an exact-match miss here
// silently no-ops every click, so it's worth being permissive.
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
    var/buildIconState = null         // turf only — specific sprite variant within
                                        // buildSelection's icon file (e.g. "brush" vs.
                                        // "grass" on /turf/ground); null = type's own
                                        // compiled-in default icon_state
    var/turf/buildDownTurf = null     // captured on MouseDown, consumed by Block/Line/Move on MouseUp
    var/atom/movable/buildGrabbedAtom = null  // captured on MouseDown for Move mode —
                                                // /atom/movable specifically (not bare
                                                // /atom): only movable atoms have a
                                                // freely-assignable loc, see MouseUp's
                                                // buildGrabbedAtom.loc = T below
    var/image/buildCursorImage = null // single square tracking the hovered tile

    // Cursor overlay — same screen-overlay-via-client.images shape GM_SeeAreas uses,
    // just one square. Uses the real confirmed asset ('meter.dmi', icon_state
    // "select" — the actual OG build-target cursor), not a procedurally-drawn stand-in.
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
        buildIconState = null
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
            if("turf")
                var/turf/newT = new buildSelection(T)
                if(buildIconState) newT.icon_state = buildIconState
            if("mob")
                new buildSelection(T)
            if("area")
                var/area/target = FindAreaInstance(buildSelection)
                if(!target)
                    // No tile anywhere is currently that area type, so it has no
                    // instance yet (BYOND only auto-creates one when the compiled map
                    // itself places it) — materialize one so a GM can build an area
                    // type into existence rather than being limited to ones the
                    // original map already used somewhere.
                    target = new buildSelection()
                // Clear whatever visible-to-everyone decoration the OLD area may have
                // applied (area/AddedTurf(), Area.dm) before repainting — otherwise a
                // tile repainted away from e.g. Rave would keep showing its old area's
                // decoration forever.
                if(T.areaVisualOverlay)
                    T.overlays -= T.areaVisualOverlay
                    T.areaVisualOverlay = null
                // turf/loc isn't directly assignable (unlike a movable atom's) —
                // adding the turf to the area's own contents is the real mechanism
                // for reparenting it to a different area.
                target.contents += T
                target.AddedTurf(T)

    // Areas are placed by reassigning a turf to a single REAL instance per type — the
    // first one found (same enumeration style GM_BattleMode already uses), or a freshly
    // created one if that type has no instance anywhere in the world yet (see
    // PlaceBuildSelection's area branch above).
    proc/FindAreaInstance(typepath)
        for(var/area/A in world)
            if(A.type == typepath) return A
        return null

    // First non-turf atom on the tile — players included, so a GM can drag any player
    // around same as any obj/monster (Delete mode's player exclusion is a separate,
    // unrelated rule). World login/respawn markers are invisible during normal play,
    // and GM_CreateObj places a fresh one right under the GM's own feet — without
    // this, grabbing here would almost always find the GM's own mob instead, making a
    // just-placed marker impossible to reposition. Only prioritized while GM_SeeAreas
    // is on — you shouldn't grab something you can't even see.
    proc/FindMovableAtom(turf/T)
        if(!T) return null
        if(mob && mob.seeingAreas)
            for(var/obj/spawnMarker/M in T.contents)
                return M
        for(var/atom/movable/A in T.contents)
            return A
        return null

    // Delete mode: clears whatever's on the tile (never a real player) THEN places the
    // current selection — "clear-and-replace" semantics, not a plain removal. The
    // practical difference from Click mode is that Delete removes any existing
    // occupant first instead of placing on top of it.
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
                    if(mob) mob.ShowInfo("Block hit the [MAX_BUILD_FILL_TILES]-tile safety cap — stopped early.")
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

    // Same-icon/icon_state contiguous BFS fill — the region is bounded by the clicked
    // turf's own icon/icon_state (the only clean "same type" notion there is), routed
    // through the shared PlaceBuildSelection() so turf/mob/area all stay in sync with
    // Click/Drag/Block/Line instead of duplicating per-kind logic here.
    proc/FloodFillBuild(turf/start)
        if(!start) return
        if(!buildKind)
            if(mob) mob.ShowInfo("Pick something to place first (GM_MakeTurf/GM_MakeMob/GM_MakeArea).")
            return

        var/matchIcon = start.icon
        var/matchState = start.icon_state

        // Read cursor instead of queue.Cut()-ing the front off every pop (O(n) per pop
        // otherwise), and an associative list as a hash set for `visited` instead of
        // `in` on a plain list (O(n) per check) — both matter for the large
        // contiguous regions MAX_BUILD_FILL_TILES exists to bound.
        var/list/queue = list(start)
        var/queueIndex = 1
        var/list/visited = list()
        visited[start] = TRUE
        var/filled = 0

        while(queueIndex <= queue.len)
            var/turf/T = queue[queueIndex]
            queueIndex++

            if(filled >= MAX_BUILD_FILL_TILES)
                if(mob) mob.ShowInfo("Flood hit the [MAX_BUILD_FILL_TILES]-tile safety cap — stopped early.")
                return

            PlaceBuildSelection(T)
            filled++

            for(var/d in list(NORTH, SOUTH, EAST, WEST))
                var/turf/N = get_step(T, d)
                if(!N || visited[N]) continue
                if(N.icon != matchIcon || N.icon_state != matchState) continue
                visited[N] = TRUE
                queue += N

    // GM_SeeAreas' overlay only rebuilds when the GM steps to a new tile — a GM
    // standing still while building would otherwise watch a stale overlay. Any
    // watched action refreshes now (not just buildKind == "area", since Move mode
    // relocating a spawn marker never sets buildKind at all). Called once per discrete
    // mouse action, not per-tile inside the fill loops, so a big Block doesn't rebuild
    // the overlay hundreds of times.
    proc/RefreshAreaOverlayIfWatching()
        if(mob && mob.seeingAreas)
            mob.RefreshAreaOverlay()

    // -----------------------------
    // Mouse dispatch
    // -----------------------------
    MouseDown(atom/object, location, control, params)
        ..()
        if(!IsMapControl(control)) return
        if(!mob || !canBuild) return
        // Move isn't really a placement tool like the other 6 modes — it relocates
        // whatever's already on the tile and never reads buildSelection, so (unlike
        // Click/Drag/Block/Line/Flood/Delete) it shouldn't require a turf/mob/area to
        // be picked first via GM_MakeTurf/GM_MakeMob/GM_MakeArea.
        if(buildMode != BUILD_MODE_MOVE && !buildSelection) return
        var/turf/T = GetTurfOf(object)
        if(!T) return

        buildDownTurf = T

        switch(buildMode)
            if(BUILD_MODE_CLICK, BUILD_MODE_DRAG)
                PlaceBuildSelection(T)
            if(BUILD_MODE_MOVE)
                buildGrabbedAtom = FindMovableAtom(T)
                if(!buildGrabbedAtom)
                    mob.ShowInfo("Nothing to move here.")
            if(BUILD_MODE_FLOOD)
                FloodFillBuild(T)
            if(BUILD_MODE_DELETE)
                ClearAndPlace(T)
            // Block/Line just record buildDownTurf above — the actual placement
            // happens on MouseUp once the second point is known.
        RefreshAreaOverlayIfWatching()

    MouseUp(atom/object, location, control, params)
        ..()
        // Always clear grabbed/down state on any mouse-up, even one that lands off the
        // map (a drag released over the inventory panel, say) — otherwise a stale
        // buildDownTurf/buildGrabbedAtom would carry into the next interaction.
        if(!mob || !canBuild || (buildMode != BUILD_MODE_MOVE && !buildSelection))
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
                RefreshAreaOverlayIfWatching()

        buildDownTurf = null
        buildGrabbedAtom = null

    MouseDrag(atom/src_object, atom/over_object, src_location, over_location, src_control, over_control, params)
        ..()
        if(!IsMapControl(src_control) || !IsMapControl(over_control)) return
        if(!mob || !canBuild || !buildSelection) return
        if(buildMode != BUILD_MODE_DRAG) return
        var/turf/T = GetTurfOf(over_object)
        if(T)
            PlaceBuildSelection(T)
            RefreshAreaOverlayIfWatching()

    MouseMove(atom/object, location, control, params)
        ..()
        if(!IsMapControl(control)) return
        if(!buildSelection) return
        var/turf/T = GetTurfOf(object)
        if(T) UpdateBuildCursor(T)

// Shared picker apply logic — GM_MakeTurf/GM_MakeMob/GM_MakeArea all follow the same
// "check access, show the list, None clears the selection, anything else sets
// buildSelection/buildKind" shape; this is that shape, written once.
mob/proc/PickBuildSelection(list/choices, prompt, title, kind)
    if(!RequireBuilder()) return

    var/choice = input(src, prompt, title) in choices
    var/picked = choices[choice]

    if(!picked)
        client.StopBuildSelection()
        src.ShowInfo("Build selection cleared.")
        return

    client.buildSelection = picked
    client.buildKind = kind
    src.ShowInfo("[choice] selected. Use GM_MakeTool to pick a placement mode, then click the map.")

// Splits `states` into day/night variants (IsNightVariant(), Main.dm) and, if any
// night variants exist, prompts to pick one set — shared by GM_MakeTurf below and
// CreateDoor (GMCommands.dm), which both offered the exact same day/night split.
// Returns the day list untouched when there are no night variants to choose between.
mob/proc/PickDayNightState(list/states, promptText, promptTitle)
    var/list/dayStates = list()
    var/list/nightStates = list()
    for(var/s in states)
        if(IsNightVariant(s)) nightStates += s
        else dayStates += s

    if(!nightStates.len) return dayStates

    var/period = input(src, promptText, promptTitle) in list("Day", "Night")
    return (period == "Night") ? nightStates : dayStates

// Most visual turf variants are collapsed into a handful of base types (Turfs.dm), so
// typesof(/turf) only surfaces those — a second step picks the actual sprite via
// GetCachedIconStates(). Floor has NO bare default state (every real OG floor is a
// named variant) — leaving buildIconState null placed a blank/black tile, hence this
// step being mandatory. bedhead is excluded — not meant to be placed directly.
mob/verb/GM_MakeTurf()
    set category = "GM"
    set desc = "Pick a turf type and sprite variant for the build tool to place"

    if(!RequireBuilder()) return

    var/list/choices = GetTypeChoices(/turf, list(/turf/furniture/bedhead))
    var/choice = input(src, "Choose a turf category to place (or None to cancel):", "GM_MakeTurf") in choices
    var/picked = choices[choice]

    if(!picked)
        client.StopBuildSelection()
        src.ShowInfo("Build selection cleared.")
        return

    var/list/states = GetCachedIconStates(initial(picked:icon))
    if(!states.len)
        src.ShowInfo("[choice] has no readable sprite variants — can't place it.")
        return

    // Night variants (GM_DayNight auto-toggles these in place, GMCommands.dm) get
    // their own list rather than cluttering the day list — a GM who deliberately
    // wants a permanently-dark tile (e.g. an indoor cave room) can still reach them
    // via Night.
    var/list/finalStates = PickDayNightState(states, "Day or Night variant of [choice]?", "GM_MakeTurf")

    if(!finalStates.len)
        src.ShowInfo("[choice] has no variants in that set.")
        return

    var/stateChoice = input(src, "Choose a [choice] variant to place:", "GM_MakeTurf") in finalStates

    client.buildSelection = picked
    client.buildIconState = stateChoice
    client.buildKind = "turf"
    src.ShowInfo("[choice] ([stateChoice]) selected. Use GM_MakeTool to pick a placement mode, then click the map.")

// Shared type-list builder — every real (non-abstract) subtype of some base, minus a
// few that don't make sense to place directly, with a capitalized bare-name label.
// Built off typesof() rather than a hand-maintained list, so a new turf/area/monster
// type shows up automatically the moment it's added.
mob/proc/GetTypeChoices(baseType, list/exclude = list())
    var/list/choices = list("None" = null)
    for(var/type in typesof(baseType))
        if(type == baseType) continue  // abstract base, not a real placeable instance
        if(type in exclude) continue
        var/displayName = Capitalize(GetIconFilename(type))
        choices[displayName] = type
    return choices

// Built from the real monster roster (MonsterRoster.dm), stays in sync automatically.
mob/verb/GM_MakeMob()
    set category = "GM"
    set desc = "Pick a monster type for the build tool to place"

    PickBuildSelection(GetTypeChoices(/mob/enemy), "Choose a monster to place (or None to cancel):", "GM_MakeMob", "mob")

// Placing "an area" means reassigning a turf to an EXISTING instance of that area type
// (FindAreaInstance() above), not spawning a fresh one. World login/respawn points are
// NOT area types — they're plain objects placed via GM_CreateObj instead, specifically
// so marking one doesn't strip a tile of whatever real area it already belongs to.
mob/verb/GM_MakeArea()
    set category = "GM"
    set desc = "Pick an area type for the build tool to assign"

    if(!RequireBuilder()) return

    var/list/choices = GetTypeChoices(/area)

    // Night areas (snownight, rainnight, waternight1, deepwaternight, ...) are their
    // own separate area TYPES, not a toggleable icon_state like turfs — split into their
    // own list rather than mixed alphabetically with the day ones. Substring match
    // (not IsNightVariant's exact suffix) since some of these end in a digit after
    // "night" (e.g. "Deepwaternight1").
    var/list/dayChoices = list()
    var/list/nightChoices = list()
    for(var/label in choices)
        if(label == "None") continue
        if(findtext(label, "night")) nightChoices[label] = choices[label]
        else dayChoices[label] = choices[label]

    var/list/finalChoices = dayChoices
    if(nightChoices.len)
        var/period = input(src, "Day or Night area?", "GM_MakeArea") in list("Day", "Night")
        finalChoices = (period == "Night") ? nightChoices : dayChoices
    finalChoices["None"] = null

    PickBuildSelection(finalChoices, "Choose an area type to assign (or None to cancel):", "GM_MakeArea", "area")

// -----------------------------
// GM_MakeTool — confirmed OG text ("[Mode] tool selected.") per the build plan.
// -----------------------------
mob/verb/GM_MakeTool()
    set category = "GM"
    set desc = "Pick how the build tool places things (Click/Drag/Block/Line/Move/Flood/Delete)"

    if(!RequireBuilder()) return

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

    var/choice = input(src, "Choose a build tool mode:", "GM_MakeTool") in modes
    if(choice == "None") return  // just closes — there's always a current mode
                                   // (defaults to Click), nothing to "cancel" to

    client.buildMode = choice
    src.ShowInfo("[choice] tool selected.")
