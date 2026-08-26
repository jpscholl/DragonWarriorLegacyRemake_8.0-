// -----------------------------
// GM Building System (Phase 10)
// -----------------------------
// Three pickers (GM_MakeTurf/GM_MakeMob/GM_MakeArea) choose WHAT to place — "pick from
// list, 'None' cancels, picking a real type enters build mode" per the exact pattern
// GM_BattleMode (GMCommands.dm) already established. GM_MakeTool separately chooses HOW
// to place it (one of 7 modes). The two are independent: changing the selection
// doesn't reset the current tool mode and vice versa — buildMode defaults to "Click"
// so a GM who's never touched GM_MakeTool still gets sane single-click placement the
// moment they pick something.
//
// Placement itself is driven by client-level MouseDown()/MouseUp()/MouseDrag()/
// MouseMove() overrides (BYOND's standard mechanism for drag/hold tools) rather than
// atom/Click() — one central dispatch point regardless of what's actually under the
// cursor (turf/obj/mob), matching the plan's explicit call for this approach. Every
// override calls ..() first — skipping that would silently break default click
// handling (item-use clicks, etc.) for EVERY client, not just GMs mid-build.
//
// GM_MakeMob correcting the design doc's /mob/monster/* — actual base type built in
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

    // -----------------------------
    // Cursor overlay — same screen-overlay-via-client.images shape GM_SeeAreas's area
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
                // turf/loc isn't directly assignable (unlike a movable atom's) —
                // adding the turf to the area's own contents is the real mechanism
                // for reparenting it to a different area.
                target.contents += T

    // Areas are placed by reassigning a turf to a single REAL instance per type — the
    // first one found (same enumeration style GM_BattleMode already uses), or a freshly
    // created one if that type has no instance anywhere in the world yet (see
    // PlaceBuildSelection's area branch above).
    proc/FindAreaInstance(typepath)
        for(var/area/A in world)
            if(A.type == typepath) return A
        return null

    // First non-turf atom on the tile — players included, so a GM can drag any player
    // (or themselves) around same as any obj/monster. Delete mode's own player
    // exclusion below is separate and unaffected: never deleting a real player is a
    // different rule than being allowed to relocate one.
    //
    // World login/respawn markers (obj/spawnMarker, Area.dm) are invisible during
    // normal play, and GM_CreateObj places a freshly-created one right under the GM's
    // own feet — meaning without this, grabbing it here would almost always find the
    // GM's own mob first instead (whatever else was on the tile before the marker
    // existed), making a just-placed marker impossible to reposition. Only prioritize
    // the marker while GM_SeeAreas (seeingAreas, GMCommands.dm) is actually on, so
    // this doesn't change Move's normal behavior the rest of the time — you shouldn't
    // grab something you can't even see.
    proc/FindMovableAtom(turf/T)
        if(!T) return null
        if(mob && mob.seeingAreas)
            for(var/obj/spawnMarker/M in T.contents)
                return M
        for(var/atom/movable/A in T.contents)
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

    // Same-icon/icon_state contiguous BFS fill. The region itself is always bounded by
    // the clicked turf's own icon/icon_state — that's the only clean "same type" notion
    // there is — but what happens to each matched tile depends on buildKind, same as
    // every other mode: turf replaces the tile, mob spawns buildSelection ON it (leaving
    // the turf itself alone), area reassigns it. Routed through the shared
    // PlaceBuildSelection() so all three stay in sync with Click/Drag/Block/Line instead
    // of duplicating the per-kind logic a second time here.
    proc/FloodFillBuild(turf/start)
        if(!start) return
        if(!buildKind)
            if(mob) mob << output("Pick something to place first (GM_MakeTurf/GM_MakeMob/GM_MakeArea).", "Info")
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

            PlaceBuildSelection(T)
            filled++

            for(var/d in list(NORTH, SOUTH, EAST, WEST))
                var/turf/N = get_step(T, d)
                if(!N || visited[N]) continue
                if(N.icon != matchIcon || N.icon_state != matchState) continue
                visited[N] = TRUE
                queue += N

    // GM_SeeAreas' overlay (GMCommands.dm) only rebuilds when the GM steps to a new tile
    // (AreaOverlayLoop's loc check) — a GM standing still while using the build tool
    // would keep watching a stale overlay. Not just buildKind == "area": Move mode
    // relocating a spawn marker (obj/spawnMarker, Area.dm) doesn't set buildKind to
    // "area" at all (it ignores buildKind/buildSelection entirely — see MouseDown's
    // comment above), so gating on that specifically left Move-mode marker relocation
    // never refreshing the overlay. Any watched action refreshes now. Called once per
    // discrete mouse action below (not per-tile inside PlaceBuildRect/PlaceBuildLine/
    // FloodFillBuild's loops) so a big Block reassign doesn't rebuild the overlay
    // hundreds of times over.
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
                    mob << output("Nothing to move here.", "Info")
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

// -----------------------------
// Shared picker apply logic — GM_MakeTurf/GM_MakeMob/GM_MakeArea below all follow the
// exact same "check access, show the list, None clears the selection, anything else
// sets buildSelection/buildKind and reminds about GM_MakeTool" shape; this is that
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
    src << output("[choice] selected. Use GM_MakeTool to pick a placement mode, then click the map.", "Info")

// -----------------------------
// GM_MakeTurf — see Code/World/Turfs.dm's own header comment: most visual turf variants
// are deliberately collapsed into a handful of base types (painted as map-editor
// INSTANCES with a custom icon_state, not separate hardcoded subtypes), so typesof(/turf)
// only ever surfaces those base types (Ground, Floor, Wall, ...) — none of grass's
// brush/flowers/sand/farmland/etc, or floor's cobble/carpet/wood/etc, exist as real
// types to enumerate. A second step picks the actual sprite: GetCachedIconStates()
// (Code/Combat/CombatSystem.dm) reads every icon_state baked into that category's icon
// file. Floor in particular has NO bare default state at all (every real OG floor is a
// named variant) — leaving buildIconState null for it placed a blank/black tile, hence
// this step being mandatory rather than skippable. bedhead excluded from the category
// list (its own comment: "Not meant to be placed directly on a map" — bedleft/
// woodbedleft point to it via parent_type instead of being placed directly).
// -----------------------------
mob/verb/GM_MakeTurf()
    set category = "GM"
    set desc = "Pick a turf type and sprite variant for the build tool to place"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    var/list/choices = GetTypeChoices(/turf, list(/turf/furniture/bedhead))
    var/choice = input(src, "Choose a turf category to place (or None to cancel):", "GM_MakeTurf") in choices
    var/picked = choices[choice]

    if(!picked)
        client.StopBuildSelection()
        src << output("Build selection cleared.", "Info")
        return

    var/list/states = GetCachedIconStates(initial(picked:icon))
    if(!states.len)
        src << output("[choice] has no readable sprite variants — can't place it.", "Info")
        return

    // Night variants (GM_DayNight auto-toggles these in place, GMCommands.dm) get their
    // own list rather than cluttering the day list — a GM who deliberately wants a
    // permanently-dark tile (e.g. an indoor cave room) can still reach them via Night.
    var/list/dayStates = list()
    var/list/nightStates = list()
    for(var/s in states)
        if(IsNightVariant(s)) nightStates += s
        else dayStates += s

    var/list/finalStates = dayStates
    if(nightStates.len)
        var/period = input(src, "Day or Night variant of [choice]?", "GM_MakeTurf") in list("Day", "Night")
        finalStates = (period == "Night") ? nightStates : dayStates

    if(!finalStates.len)
        src << output("[choice] has no variants in that set.", "Info")
        return

    var/stateChoice = input(src, "Choose a [choice] variant to place:", "GM_MakeTurf") in finalStates

    client.buildSelection = picked
    client.buildIconState = stateChoice
    client.buildKind = "turf"
    src << output("[choice] ([stateChoice]) selected. Use GM_MakeTool to pick a placement mode, then click the map.", "Info")

// -----------------------------
// Shared type-list builder — every picker below wants the same thing: every real
// (non-abstract) subtype of some base, minus a few that don't make sense to place
// directly, with a capitalized bare-name label. Building this off typesof() instead of
// a hand-maintained list means a new turf/area/monster type shows up in the build tool
// automatically the moment it's added to its own file — no separate list to remember to
// update here. GetIconFilename() (Code/Core/Main.dm) does the "stringify, split on /,
// take the last segment" work; it's a generic string util, not icon-specific, despite
// the name/original home in LoginMenu.dm.
// -----------------------------
mob/proc/GetTypeChoices(baseType, list/exclude = list())
    var/list/choices = list("None" = null)
    for(var/type in typesof(baseType))
        if(type == baseType) continue  // abstract base, not a real placeable instance
        if(type in exclude) continue
        var/displayName = Capitalize(GetIconFilename(type))
        choices[displayName] = type
    return choices

// -----------------------------
// GM_MakeMob — built from the real Stage 3 monster roster (MonsterRoster.dm), stays in
// sync automatically.
// -----------------------------
mob/verb/GM_MakeMob()
    set category = "GM"
    set desc = "Pick a monster type for the build tool to place"

    // tier1/tier2 excluded — they're the roster's shared stat-block base types
    // (MonsterRoster.dm), not monsters in their own right. Same reason GM_MakeTurf
    // excludes /turf/furniture/bedhead below.
    PickBuildSelection(GetTypeChoices(/mob/enemy, list(/mob/enemy/tier1, /mob/enemy/tier2)), "Choose a monster to place (or None to cancel):", "GM_MakeMob", "mob")

// -----------------------------
// GM_MakeArea — placing "an area" means reassigning a turf to an EXISTING instance of
// that area type (FindAreaInstance() above), not spawning a fresh one — same
// enumeration style GM_BattleMode (GMCommands.dm) already uses to build its own list of
// real area instances. The world login/respawn points (playerStart/playerSpawn) are
// NOT area types (Area.dm) — they're plain objects placed via GM_CreateObj instead,
// specifically so marking one doesn't strip a tile of whatever real area (Town,
// Dungeon, ...) it already belongs to.
// -----------------------------
mob/verb/GM_MakeArea()
    set category = "GM"
    set desc = "Pick an area type for the build tool to assign"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

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

    var/choice = input(src, "Choose a build tool mode:", "GM_MakeTool") in modes
    if(choice == "None") return  // just closes — there's always a current mode
                                   // (defaults to Click), nothing to "cancel" to

    client.buildMode = choice
    src << output("[choice] tool selected.", "Info")
