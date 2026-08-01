// -----------------------------
// GM Ghost Form
// -----------------------------
// GHOST_INVISIBILITY is deliberately its own tier, ABOVE obj/ceiling's
// invisibility = 1 (Obj.dm — the roof-hiding system). A regular player's
// see_invisible fluctuates between 0 (indoors) and 1 (outdoors, so the roof itself
// becomes visible) via area/ceiling's Entered()/Exited() (Area.dm) — it never
// reaches 2, so this keeps ghosts hidden from ordinary players regardless of whether
// they're currently indoors or outdoors. Previously both systems used invisibility/
// see_invisible = 1, which meant any player standing outdoors (i.e. most of the map,
// most of the time) could actually see a "hidden" ghosted GM. If anything else ever
// needs its own invisibility tier, keep it below this value or update this comment.
#define GHOST_INVISIBILITY 2

mob
    var/image/ghostIcon
    var/isGhostform = FALSE
    var/icon/ghostFormIcon   // remembers appearance while ghosted, unrelated to the character's baseIcon

// Toggle ghostIcon form on/off
mob/proc/ToggleGhostForm()
    // Play the spell sound for everyone nearby. channel = SFX_CHANNEL (.dme), not
    // left unspecified — turns out an unspecified channel still interrupts channel 1
    // area music (PlayAreaMusic(), Area.dm) in this BYOND version, same issue found
    // and fixed for attack/hit/dodge sounds (CombatSystem.dm).
    PlaySFXAt(src, 'spell.WAV')

    if(isGhostform)
        // --- Exit ghostIcon form ---
        isGhostform = FALSE
        invisibility = 0
        density = 1
        overlays -= ghostIcon
        if(client) client.images -= ghostIcon
        ghostIcon = null
        icon = ghostFormIcon
        icon_state = "world"
        // Recompute the mundane see_invisible instead of hardcoding — matches
        // whatever the roof system (area/ceiling, Area.dm) would have set for a
        // normal mob standing here: 0 indoors (under a roof), 1 outdoors (so the
        // roof itself is visible). Ghost form had bumped this to GHOST_INVISIBILITY.
        // get_area() isn't available in this BYOND environment (confirmed earlier) —
        // T.loc (turf -> area) is the proven pattern used elsewhere (SaveSystem.dm,
        // InBattleArea() in CombatSystem.dm).
        var/turf/T = loc
        var/area/A = T ? T.loc : null
        see_invisible = istype(A, /area/ceiling) ? 0 : 1
        src << output("You reappear!", "Info")
    else
        // --- Enter ghostIcon form ---
        isGhostform = TRUE
        ghostFormIcon = icon
        icon = null
        invisibility = GHOST_INVISIBILITY
        // Bumping see_invisible to match (not just invisibility) means a ghosted mob
        // can also see OTHER ghosted mobs — builders can follow each other around
        // while both are ghosted, requested alongside this fix.
        see_invisible = GHOST_INVISIBILITY
        density = 0
        ghostIcon = image('phase.dmi', src)
        if(client) client.images += ghostIcon
        src << output("You disappear!", "Info")

// GM verb to toggle ghostIcon form — Admin-category power (Code/Admin/AdminLevels.dm)
mob/verb/GMghostIconform()
    set category = "Admin"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    ToggleGhostForm()

// -----------------------------
// GM Profanity Filter Toggle
// -----------------------------
// Flips adultServer (Code/Core/Main.dm) — TRUE disables the general-profanity list,
// leaving only banned_words_always (slurs/hate speech) enforced. Admin-category power.
mob/verb/GMToggleProfanityFilter()
    set category = "Admin"
    set desc = "Turns the general-profanity filter (names/chat) on or off"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    adultServer = !adultServer
    src << output("Profanity filter is now [adultServer ? "OFF" : "ON"] (adultServer = [adultServer]).", "Info")

// -----------------------------
// GM Create Lockable
// -----------------------------
// Creates a lockable object and its matching key together in one step, so they can't
// get out of sync. Builder-category power (world content creation), not Admin.
mob/verb/GM_Create_Lockable()
    set category = "Builder"
    set desc = "Creates a lockable object (e.g. a door) and its matching key"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    // Only doors exist as a lockable type for now — add more here once other lockable
    // types exist (each needs its own is_locked var + OnInteract() check, same as
    // obj/door's in Code/World/Obj.dm).
    var/list/lockableTypes = list("Door" = /obj/door)
    var/choice = input(src, "Choose a lockable object type:", "Create Lockable") in lockableTypes
    var/lockableType = lockableTypes[choice]

    var/lockName = input(src, "Name this [choice] (a matching key will be created too):", "Name It") as text|null
    if(isnull(lockName) || !length(trimtext(lockName)))
        src << output("Cancelled — no name given.", "Info")
        return
    lockName = trimtext(lockName)

    // lockableType is only known at runtime (chosen from input), so the compiler can't
    // statically verify "name"/"is_locked" exist on it — set them dynamically via vars[]
    // instead, same pattern already used in StatAllocation() in Code/UI/LoginMenu.dm.
    // Typed as /atom (not left bare) so the compiler knows it has a vars[] list at all —
    // every future lockable type will still be some kind of atom.
    var/atom/newLockable = new lockableType(loc)
    newLockable.vars["name"] = lockName
    newLockable.vars["is_locked"] = TRUE

    var/obj/item/key/newKey = new
    newKey.keyName = lockName
    newKey.name = "[lockName] Key"

    if(!PickUpItem(newKey))
        del newKey
        src << output("Created [lockName], but your inventory was full — no key was given!", "Info")
        return

    src << output("Created a locked [lockName] and put its key in your inventory.", "Info")

// -----------------------------
// GM Day/Night Toggle
// -----------------------------
// Appends/strips the "night" suffix on one atom's icon_state — shared by both the
// turf and obj loops below, which used to each duplicate this logic once per
// direction (4 near-identical blocks total).
proc/ToggleNightIconState(atom/A, toNight)
    if(!A.icon_state) return
    if(toNight)
        A.icon_state += "night"
    else
        var/len = length(A.icon_state)
        if(len > 5 && copytext(A.icon_state, len - 4, len + 1) == "night")
            A.icon_state = copytext(A.icon_state, 1, len - 4)

// Swaps every turf/obj's icon_state to its night variant and back. Confirmed OG
// convention: night states are just the day icon_state with "night" appended directly
// (e.g. "redcobble" -> "redcobblenight"), no separator, and it's world-icons only —
// mobs don't have night sprites. GM-tier power (both Builder+Admin combined), not
// Admin or Builder alone.
mob/verb/GMdaynight()
    set category = "GM"
    set desc = "Toggles day/night for every turf and obj in the world"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    isNight = !isNight

    for(var/turf/T in world)
        ToggleNightIconState(T, isNight)
    for(var/obj/O in world)
        if(istype(O, /obj/StatLink)) continue
        ToggleNightIconState(O, isNight)

    world << output("[src] has turned it to [isNight ? "night" : "day"].", "Info")

// -----------------------------
// GM Log Toggle
// -----------------------------
// Flips loggingEnabled (Code/Core/TextFilter.dm) — gates LogChat()'s own lines (chat,
// login/logout, double-login) only. world.log's automatic connect/disconnect/host
// events keep writing to server.log regardless — that's the engine, not this. GM-tier
// power, not Admin, since it's about who can talk without being logged, not general
// server admin — players never see this verb at all (not just gated on use).
mob/verb/GMtogglelog()
    set category = "GM"
    set desc = "Turns chat/login logging (server.log) on or off"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    loggingEnabled = !loggingEnabled
    src << output("Chat/login logging is now [loggingEnabled ? "ON" : "OFF"].", "Info")

// -----------------------------
// GM Level Increase
// -----------------------------
// Was Test_Leveling() (DebugTools.dm) — added a huge pile of Exp and hoped
// LevelCheck() (CombatSystem.dm) would trigger. Directly applies the same
// side effects LevelCheck() does on a real level-up (StatPoints, RecalculateVitals())
// instead, so this actually increases Level rather than just being a shortcut to it.
// GM-tier power, matching the confirmed OG command name.
mob/verb/GMlevelincrease()
    set category = "GM"
    set desc = "Increases your level by a chosen amount, same as leveling up normally"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/amount = input(src, "How many levels to add?", "GMlevelincrease", 1) as num
    if(isnull(amount) || amount < 1) return
    amount = round(amount)

    // Same per-level side effects as a real level-up, just repeated — RecalculateVitals()
    // (Code/Player/StatsDatum.dm) tops up HP/MP by however much Max just grew each time,
    // so looping it is equivalent to a real level-up chain, not a single jump.
    for(var/i = 1 to amount)
        Level += 1
        StatPoints += 5
        RecalculateVitals()

    src << output("You are now Level [Level] (+[amount])", "Info")
    src << sound('levelup.wav', channel = 2, volume = client.ScaledVolume())

// -----------------------------
// GM Battle Mode Toggle
// -----------------------------
// Toggles whether attacks/skills are allowed in a specific area instance — see
// battleModeOn on the base area type (Code/World/Area.dm) and InBattleArea()
// (Code/Combat/CombatSystem.dm), which checks it. GM-tier power, matching the
// original design notes.
mob/verb/GMbattlemode()
    set category = "GM"
    set desc = "Toggles battle mode for one area, or every area at once"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/list/areaChoices = list("None" = null, "All Areas" = "ALL")
    for(var/area/A in world)
        areaChoices["[A.name] ([A.type])"] = A

    var/choice = input(src, "Choose an area to toggle battle mode (or All Areas):", "GMbattlemode") in areaChoices
    var/selection = areaChoices[choice]
    if(!selection) return  // "None" selected, cancel

    if(selection == "ALL")
        // Global override, same shape as GMdaynight() above — disregards each area
        // type's own default (Area.dm) while active.
        battleModeGlobalOn = !battleModeGlobalOn
        for(var/area/A in world)
            A.battleModeOn = battleModeGlobalOn
        world << output("[src] has turned battle mode [battleModeGlobalOn ? "ON" : "OFF"] everywhere.", "Info")
    else
        var/area/target = selection
        target.battleModeOn = !target.battleModeOn
        src << output("[target.name] is now [target.battleModeOn ? "a dangerous area" : "a peaceful area"].", "Info")

// -----------------------------
// GM See Areas Toggle
// -----------------------------
// Overlays each turf CURRENTLY IN VIEW with its own area's icon/icon_state from
// Code/World/Area.dm (e.g. "town", "townrain", "bar") so a GM can see area
// boundaries at a glance — reuses the icon/icon_state areas already have, no
// separate grid asset needed. Builder-tier power, matching the original design notes.
// Originally snapshotted every turf in the WHOLE WORLD once on toggle — even batched
// across ticks to avoid a one-time freeze, that still left potentially thousands of
// persistent /image objects permanently tracked on one client, which the renderer has
// to composite every single frame regardless of whether they're on-screen. That's the
// actual ongoing lag source, not just the build loop. Now only builds images for a
// small area around the GM (see AREA_OVERLAY_RADIUS below) and refreshes via a
// polling loop (AreaOverlayLoop(), same shape as other loops in this codebase —
// client/MoveLoop() etc.) whenever they actually move to a new tile, so the image
// count stays small and bounded instead of scaling with map size.

// The GM's own view is 13x13 (world.view, Main.dm) — 6 tiles out from center each
// way. Padded a few tiles past that so the overlay is already built for tiles just
// off-screen before the GM actually walks into view of them — masks
// AreaOverlayLoop()'s up-to-half-second refresh delay behind a buffer instead of
// visible pop-in right at the screen edge. Update if world.view's size ever changes.
#define AREA_OVERLAY_BUFFER 3
#define AREA_OVERLAY_RADIUS (6 + AREA_OVERLAY_BUFFER)

mob/var/list/areaOverlayImages
mob/var/seeingAreas = FALSE
mob/var/turf/areaOverlayLastLoc

mob/verb/GMseeareas()
    set category = "GM"
    set desc = "Toggles a visual overlay showing which area each tile belongs to"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    seeingAreas = !seeingAreas

    if(seeingAreas)
        areaOverlayLastLoc = null  // force RefreshAreaOverlay() to build on the first tick
        AreaOverlayLoop()
        src << output("Area overlay is now ON.", "Info")
    else
        if(areaOverlayImages)
            client.images -= areaOverlayImages
            areaOverlayImages = null
        src << output("Area overlay is now OFF.", "Info")

// Polls while seeingAreas is on, rebuilding the overlay only when the GM has actually
// moved to a new tile — skips redundant rebuilds while standing still.
mob/proc/AreaOverlayLoop()
    set waitfor = 0
    while(seeingAreas && client)
        if(loc != areaOverlayLastLoc)
            areaOverlayLastLoc = loc
            RefreshAreaOverlay()
        sleep(5)  // check twice a second — cheap since each rebuild is viewport-sized

// Rebuilds areaOverlayImages for a small padded area around the GM (AREA_OVERLAY_RADIUS
// above — deliberately bigger than the actual viewport), swapping out the old set for
// the new one on the client in one shot. range(), not view() — this intentionally
// covers tiles beyond what's currently on-screen, and view() would cap at the client's
// actual visible/line-of-sight area instead.
mob/proc/RefreshAreaOverlay()
    if(!client) return

    var/list/newImages = list()
    for(var/turf/T in range(AREA_OVERLAY_RADIUS, src))
        var/area/A = T.loc
        if(!A || !A.icon_state) continue
        var/image/I = image('environment.dmi', T, A.icon_state)
        newImages += I

    if(areaOverlayImages)
        client.images -= areaOverlayImages
    client.images += newImages
    areaOverlayImages = newImages