// -----------------------------
// GM Announce
// -----------------------------
// Confirmed OG presentation (real screenshot): a plain "[GM] has an announcement" line,
// then the message itself on its own line — big, bold, red, centered. `players`
// (Code/Core/Main.dm), not `world <<`, matches the broadcast convention every other
// server-wide message in this codebase already uses (SocialVerbs.dm's Broadcast()).
// GM-tier power — this reaches every connected player at once.
mob/verb/GM_Announce()
    set category = "GM"
    set desc = "Broadcasts a big red announcement to every connected player"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/msg = input(src, "Announcement:", "GM_Announce") as text|null
    if(isnull(msg) || !length(trimtext(msg))) return
    msg = trimtext(msg)

    players << output("<center>[src.name] has an announcement</center>", "Messages")
    players << output("<center><font color='red' size='5'><b>[msg]</b></font></center>", "Messages")

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
mob/verb/GM_GhostIconform()
    set category = "GM"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    ToggleGhostForm()

// -----------------------------
// GM Profanity Filter Toggle
// -----------------------------
// Flips adultServer (Code/Core/Main.dm) — TRUE disables the general-profanity list,
// leaving only banned_words_always (slurs/hate speech) enforced. Admin-category power.
mob/verb/GM_ToggleProfanityFilter()
    set category = "GM"
    set desc = "Turns the general-profanity filter (names/chat) on or off"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    adultServer = !adultServer
    src << output("Profanity filter is now [adultServer ? "OFF" : "ON"] (adultServer = [adultServer]).", "Info")

// -----------------------------
// GM Create Obj
// -----------------------------
// Creates any of the game's functional world objects at the GM's own location — not
// mouse-placed like GM_MakeTurf/GM_MakeMob/GM_MakeArea, since several of these need a
// per-instance text prompt right at creation (a lockable's name, a sign's message) that
// doesn't fit a click-to-place flow. Builder-category power (world content creation),
// not Admin. NPC included per its own comment (Code/World/NPCs.dm) — no dialogue/AI
// yet, just a placeable placeholder body for now.
mob/verb/GM_CreateObj()
    set category = "GM"
    set desc = "Creates a functional obj (or a placeholder NPC) at your location"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    var/list/choices = list(
        "Door" = /obj/door,
        "Bookcase" = /obj/stat/bookcase,
        "Pot" = /obj/stat/pot,
        "Drawers" = /obj/stat/drawers,
        "Sign" = /obj/stat/sign,
        "NPC" = /mob/npc,
    )

    var/choice = input(src, "Choose what to create:", "GM_CreateObj") in choices
    if(!choice) return
    var/pickedType = choices[choice]

    if(pickedType == /mob/npc)
        CreateNPC()
    else if(pickedType == /obj/door)
        // Only doors exist as a lockable type for now — add more here once other
        // lockable types exist (each needs its own is_locked var + OnInteract() check,
        // same as obj/door's in Code/World/Obj.dm).
        CreateDoor(pickedType, choice)
    else if(pickedType == /obj/stat/sign)
        CreateSign()
    else
        new pickedType(loc)
        src << output("Created [choice].", "Info")

// Door skins (wooden/jail/dw1/silver/gold/snow/ice, each with a night variant) are all
// one real type (obj/door, Code/World/Obj.dm) painted as different icon_state
// instances — same collapse convention as turfs, so GetCachedIconStates()
// (Code/Combat/CombatSystem.dm) reads door.dmi directly instead of a hardcoded list.
// "open" excluded — that's the shared mid-interaction sprite every skin swaps to on
// open() (Obj.dm), not a selectable skin. Night split matches GM_MakeTurf's.
mob/proc/CreateDoor(doorType, choiceLabel)
    var/list/states = GetCachedIconStates(initial(doorType:icon))
    states -= "open"

    var/list/dayStates = list()
    var/list/nightStates = list()
    for(var/s in states)
        if(IsNightVariant(s)) nightStates += s
        else dayStates += s

    var/list/finalStates = dayStates
    if(nightStates.len)
        var/period = input(src, "Day or Night door skin?", "GM_CreateObj") in list("Day", "Night")
        finalStates = (period == "Night") ? nightStates : dayStates

    var/skin = input(src, "Choose a door skin:", "GM_CreateObj") in finalStates
    CreateLockable(doorType, choiceLabel, skin)

// Creates a lockable object and its matching key together in one step, so they can't
// get out of sync. lockableType is only known at runtime (chosen from GM_CreateObj's
// input), so the compiler can't statically verify "name"/"is_locked"/"closed_icon_state"
// exist on it — set them dynamically via vars[] instead, same pattern already used in
// StatAllocation() in Code/UI/LoginMenu.dm. Typed as /atom (not left bare) so the
// compiler knows it has a vars[] list at all — every future lockable type will still be
// some kind of atom. icon_state itself IS a builtin /atom var (unlike the other two),
// so that one's set directly rather than through vars[].
mob/proc/CreateLockable(lockableType, choiceLabel, skin = null)
    var/lockName = input(src, "Name this [choiceLabel] (a matching key will be created too):", "Name It") as text|null
    if(isnull(lockName) || !length(trimtext(lockName)))
        src << output("Cancelled — no name given.", "Info")
        return
    lockName = trimtext(lockName)

    var/atom/newLockable = new lockableType(loc)
    newLockable.vars["name"] = lockName
    newLockable.vars["is_locked"] = TRUE
    if(skin)
        // Sets both the sprite AND the sprite close() restores to (Obj.dm) — without
        // the latter, opening then closing a freshly-skinned door would snap back to
        // the type's compiled-in default ("wooden") instead of staying jail/silver/etc.
        newLockable.icon_state = skin
        newLockable.vars["closed_icon_state"] = skin

    var/obj/item/key/newKey = new
    newKey.keyName = lockName
    newKey.name = "[lockName] Key"

    if(!PickUpItem(newKey))
        del newKey
        src << output("Created [lockName], but your inventory was full — no key was given!", "Info")
        return

    src << output("Created a locked [lockName] and put its key in your inventory.", "Info")

// Signs are otherwise plain (Code/World/Obj.dm) except for their per-instance message
// var — set it right at creation instead of leaving it at the default "..." (its own
// comment already called out a GM-creation verb setting this per-instance).
mob/proc/CreateSign()
    var/message = input(src, "What should this sign say?", "Sign Message") as text|null
    if(isnull(message) || !length(trimtext(message))) message = "..."
    else message = trimtext(message)

    var/obj/stat/sign/newSign = new(loc)
    newSign.message = message
    src << output("Created a sign.", "Info")

// icon_state offered here comes straight from npc.dmi's own real sprite set
// (GetCachedIconStates(), Code/Combat/CombatSystem.dm) — merchant/guard/priest/etc. —
// not hardcoded, so a new sprite added to the file is selectable immediately.
mob/proc/CreateNPC()
    var/list/states = GetCachedIconStates('npc.dmi')
    if(!states.len)
        src << output("No NPC sprites found.", "Info")
        return
    var/stateChoice = input(src, "Choose an NPC appearance:", "GM_CreateObj") in states

    var/npcName = input(src, "Name this NPC:", "Name It") as text|null
    npcName = (isnull(npcName) || !length(trimtext(npcName))) ? Capitalize(stateChoice) : trimtext(npcName)

    var/mob/npc/newNPC = new(loc)
    newNPC.icon_state = stateChoice
    newNPC.name = npcName

    src << output("Created [npcName] the NPC.", "Info")

// -----------------------------
// GM Day/Night Toggle
// -----------------------------
// Appends/strips the "night" suffix on one atom's icon_state — shared by both the
// turf and obj loops below, which used to each duplicate this logic once per
// direction (4 near-identical blocks total). IsNightVariant() (Code/Core/Main.dm) is
// the shared "does this end in the night suffix" check.
proc/ToggleNightIconState(atom/A, toNight)
    if(!A.icon_state) return
    if(toNight)
        A.icon_state += "night"
    else if(IsNightVariant(A.icon_state))
        A.icon_state = copytext(A.icon_state, 1, length(A.icon_state) - 4)

// Swaps every turf/obj's icon_state to its night variant and back. Confirmed OG
// convention: night states are just the day icon_state with "night" appended directly
// (e.g. "redcobble" -> "redcobblenight"), no separator, and it's world-icons only —
// mobs don't have night sprites. GM-tier power (both Builder+Admin combined), not
// Admin or Builder alone.
mob/verb/GM_DayNight()
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
mob/verb/GM_ToggleLog()
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
mob/verb/GM_LevelIncrease()
    set category = "GM"
    set desc = "Increases your level by a chosen amount, same as leveling up normally"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/amount = input(src, "How many levels to add?", "GM_LevelIncrease", 1) as num
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
mob/verb/GM_BattleMode()
    set category = "GM"
    set desc = "Toggles battle mode for one area, or every area at once"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/list/areaChoices = list("None" = null, "All Areas" = "ALL")
    for(var/area/A in world)
        areaChoices["[A.name] ([A.type])"] = A

    var/choice = input(src, "Choose an area to toggle battle mode (or All Areas):", "GM_BattleMode") in areaChoices
    var/selection = areaChoices[choice]
    if(!selection) return  // "None" selected, cancel

    if(selection == "ALL")
        // Global override, same shape as GM_DayNight() above — disregards each area
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
// GM Kill Monsters
// -----------------------------
// Kills monsters through the real death pipeline (Die()/CleanUpDead(), CombatSystem.dm)
// instead of a raw del() — so they play the actual hit sound, get the "sleep" icon_state
// knockout pose Die() sets on every enemy death, credit src with exp/gold same as a real
// kill, and linger as a corpse for CleanUpDead()'s normal delay before disappearing,
// exactly like dying in combat. Deliberately skips TakeDamage()'s RollDodge()/damage
// math though — this is meant to always land ("Overpowered attack that instant kills"),
// not be a normal attack that can whiff or get reduced by defending.
//
// "All option at the top, then every real type" shape matches GM_BattleMode's own area
// list above. Monster type entries reuse GetTypeChoices(/mob/enemy)
// (Code/Admin/Commands/BuildTools.dm) — the same typesof()-driven list GM_MakeMob
// builds its picker from — rather than re-deriving the type/display-name list here.
// Destructive world-wide action, so GM-tier power like GM_DayNight/GM_BattleMode, not
// just Builder-tier.
mob/verb/GM_KillMonsters()
    set category = "GM"
    set desc = "Instantly kills monsters through the real death process, by type or all at once"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/list/choices = list("All" = "all")
    var/list/monsterChoices = GetTypeChoices(/mob/enemy)
    monsterChoices -= "None"
    choices += monsterChoices

    var/choice = input(src, "Kill which monsters?", "GM_KillMonsters") in choices
    if(!choice) return
    var/picked = choices[choice]

    var/killed = 0
    for(var/mob/enemy/E in world)
        if(E.HP <= 0) continue  // already dead and lingering through CleanUpDead()'s delay
        if(picked != "all" && E.type != picked) continue

        flick("hit", E)
        PlaySFXAt(E, 'enemyhit.wav')
        E.HP = 0
        E.Die(src)
        E.CleanUpDead()
        killed++

    world << output("[src] killed [killed] monster[killed == 1 ? "" : "s"][picked == "all" ? "" : " ([choice])"].", "Info")

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

mob/verb/GM_SeeAreas()
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