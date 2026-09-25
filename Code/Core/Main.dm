 /*
//    Game: Dragon Warrior Legacy Remake
//
//    Description:
//    Remake of Wizdragon (Tarq)'s Dragon Warrior action RPG, based on version 8.0.
//    Later versions existed, but 8.0 is the only one available for reference.
//
//    Goal: Replicate 8.0 faithfully while adding QoL improvements ("8.0+").
//
//    Author: Cerebella (Shorin88)
//
//    Last Update: 8/4/2026
//
//    Known Issues: see Known Issues.txt (currently empty — nothing outstanding logged)
//
//    To do list: see Markdowns/TODOList.md, the actual maintained planning doc.
*/

// -------------------- Global Settings --------------------

// Remake's own version, independent of the "8.0" in the OG this is based on — pre-1.0
// SemVer. Shown on the login menu (ShowLoginMenu(), LoginMenu.dm) and logged in
// CHANGELOG.md alongside what each bump actually changed.
#define GAME_VERSION "0.7.0"

var/list/players = list()

// Volume slider fallbacks for a player who's never touched them
// (SaveManager.LoadVolumeSettings(), SaveSystem.dm).
#define DEFAULT_MASTER_VOLUME 50
#define DEFAULT_CHANNEL_VOLUME 100

// Server mode for the text filter (TextFilter.dm). FALSE = general audience, enforces
// both the always-banned list and the general-profanity list. TRUE = adult server,
// only the always-banned list (slurs/hate speech) applies. Real var so it can be
// toggled at runtime (GM_ToggleProfanityFilter(), GMCommands.dm).
var/global/adultServer = FALSE

// Toggled by GM_ToggleMultiLogin() — when TRUE, the address-based double-login block
// below (client/New()) is skipped, so a GM can open a second client from the same
// machine to test multiplayer-facing verbs without a real second player.
var/global/allowMultiLogin = FALSE

// Day/night state — driven by the world clock below, still toggleable on demand by
// GM_DayNight(). Turfs/objs swap to their confirmed-OG "night" icon_state variant;
// mobs have no such variant in the OG, so they're darkened with a color tint instead
// (ApplyNightTint() below) — a remake-only idea, not OG behavior.
var/global/isNight = FALSE

// TRUE only on a night where the curse easter egg (NIGHT_CURSE_EASTEREGG_PERCENT below)
// rolled — HUD.dm's GetHUDHealthColor() checks this to swap the HUD text red instead of
// the usual night blue. Cleared the moment day breaks (SetWorldNight() below).
var/global/isCurseNight = FALSE

// Multiplied against a mob's sprite at night — darkens and slightly blue-shifts it
// without going fully black. Doesn't touch player palette recoloring (RebuildIcon(),
// SaveSystem.dm bakes colors into the icon itself, not the color var) or the glyph/
// name-tag objects in HUD.dm that use color for their own unrelated purposes.
#define NIGHT_TINT_COLOR rgb(130,130,170)

// Easter egg (Castlevania's "What a horrible night to have a curse") — 1-in-20 odds
// each time night actually falls (SetWorldNight() below), not every sunset, so it stays
// a rare surprise rather than a flavor line players learn to expect.
#define NIGHT_CURSE_EASTEREGG_PERCENT 5

// Replaces the player's normal area music for the length of a curse night — takes over
// channel 1 like PlayAreaMusic() (Area.dm) does, so area/Entered() below has to check
// isCurseNight itself to avoid stomping this the moment someone walks into a new area.
#define CURSE_NIGHT_MUSIC 'cursenight.wav'

mob/proc/ApplyNightTint(toNight)
    color = toNight ? NIGHT_TINT_COLOR : null

// Base hook so every mob — player or enemy, however it's created — starts out
// matching whatever isNight already is, not just mobs present at the last toggle.
mob/New()
    . = ..()
    ApplyNightTint(isNight)

// -----------------------------
// World clock — see Markdowns/CodeNotes.md for OG confirmation and cadence rationale.
// -----------------------------
#define GAME_MINUTES_PER_TICK 10
#define REAL_DECISECONDS_PER_TICK 10   // one tick per real second

#define SUNRISE_HOUR 6
#define SUNSET_HOUR 18

var/global/gameMinuteOfDay = 720  // minutes since midnight; OG's documented start (12:00 PM)

// Human-readable clock, e.g. "6:00 PM". Unused while the auto day/night clock is off
// (RP-mode only, commit bdff599); kept for when it comes back to the Status panel.
proc/GetGameTimeString()
    var/hour24 = round(gameMinuteOfDay / 60)
    var/minute = gameMinuteOfDay % 60
    var/period = hour24 >= 12 ? "PM" : "AM"
    var/hour12 = hour24 % 12
    if(!hour12) hour12 = 12
    return "[hour12]:[minute < 10 ? "0" : ""][minute] [period]"

// Shares GM_DayNight()'s own ToggleNightIconState() sweep (GMCommands.dm) rather than
// reimplementing the turf/obj walk, so a clock-driven sunset and a GM-forced one
// produce identical results.
proc/SetWorldNight(toNight, message)
    if(isNight == toNight) return
    isNight = toNight

    // Rolled up front (rather than alongside the announcement below) so the HUD sweep
    // just below already knows whether to color text curse-red vs. the normal night
    // blue, instead of lagging a tick behind like the announcement doesn't need to.
    // Cleared the instant day breaks — the curse is a one-night-only effect. wasCurseNight
    // remembers the outgoing state so the mob loop below knows to restore normal area
    // music on the sunrise that ends a curse night.
    var/wasCurseNight = isCurseNight
    isCurseNight = toNight && prob(NIGHT_CURSE_EASTEREGG_PERCENT)

    for(var/turf/T in world)
        ToggleNightIconState(T, isNight)
    for(var/obj/O in world)
        if(istype(O, /obj/StatLink)) continue
        // `in world` walks every instantiated /obj regardless of loc, so this was also
        // sweeping client.screen HUD objects (hudBackdrop/hudGlyph, HUD.dm) — appending
        // "night" to a glyph's icon_state (e.g. "0" -> "0night") isn't a real text.dmi
        // state, blanking the character until the next UpdateHUD() tick overwrote it
        // back. That gap was the reported HUD flicker on every day/night toggle.
        if(istype(O, /obj/screen)) continue
        ToggleNightIconState(O, isNight)
    for(var/mob/M in world)
        M.ApplyNightTint(isNight)
        // Without this, the HUD's white->NIGHT_HUD_TEXT_COLOR swap (GetHUDHealthColor(),
        // HUD.dm) only takes effect on that player's next Stat() tick — a noticeable lag
        // behind the world's own tint/icon swap above, which applies immediately.
        if(istype(M, /mob/player))
            var/mob/player/P = M
            P.UpdateHUD()

            // Curse night takes over channel 1 in place of the area's normal music
            // (area/Entered(), Area.dm, checks isCurseNight too so walking into a new
            // area mid-curse-night doesn't stomp this). Restored the moment the curse
            // night ends — falls back to silence if the player's current area has no
            // music of its own to return to.
            if(isCurseNight)
                P.PlayAreaMusic(CURSE_NIGHT_MUSIC)
            else if(wasCurseNight)
                var/area/currentArea = P.loc?.loc
                if(currentArea && currentArea.areaMusic)
                    P.PlayAreaMusic(currentArea.areaMusic)
                else if(P.client)
                    P.client << sound(null, channel = 1)
                    P.current_music = null

    // Rare easter egg (isCurseNight rolled above) — same big red banner styling as
    // GM_Announce() (GMCommands.dm), minus the "so-and-so announces:" line since this
    // isn't coming from a GM. Takes over FROM the normal flavor `message` on the nights
    // it fires, rather than showing alongside it.
    if(isCurseNight)
        players << output("<font color='red' size='5'><b>What a horrible night to have a curse.</b></font>", "Messages")
    else if(message)
        players << output("<center><b>[message]</b></center>", "Messages")

// Forces the curse night event right now, bypassing NIGHT_CURSE_EASTEREGG_PERCENT's odds
// entirely — GM_HorribleNight() (GMCommands.dm), a temp test verb so this doesn't need
// dozens of GM_DayNight() toggles to see. First ensures the world is actually dark
// (SetWorldNight() no-ops if it's already night, so isCurseNight is forced separately
// afterward either way), then redoes the per-player HUD/music step and announcement.
proc/TriggerCurseNight()
    SetWorldNight(TRUE)
    // SetWorldNight() rolls the easter egg itself when it actually transitions to night,
    // and announces it if the roll won — so skip the rest rather than forcing a state
    // that's already set and banner-ing it a second time.
    if(isCurseNight) return

    isCurseNight = TRUE
    for(var/mob/player/P in world)
        P.UpdateHUD()
        P.PlayAreaMusic(CURSE_NIGHT_MUSIC)
    players << output("<font color='red' size='5'><b>What a horrible night to have a curse.</b></font>", "Messages")

// Advances the clock one tick and fires sunrise/sunset transitions as they're crossed.
proc/WorldClockLoop()
    set waitfor = 0
    while(TRUE)
        sleep(REAL_DECISECONDS_PER_TICK)

        gameMinuteOfDay = (gameMinuteOfDay + GAME_MINUTES_PER_TICK) % 1440
        var/hour24 = round(gameMinuteOfDay / 60)

        // Flavor lines are the OG's own, verbatim.
        if(hour24 >= SUNSET_HOUR || hour24 < SUNRISE_HOUR)
            SetWorldNight(TRUE, "The sun sinks below the horizon and night falls over the land.")
        else
            SetWorldNight(FALSE, "The sun rises in the east and a new day is born.")

// Sends `filename` to every client-having mob visible from `center`, personalized to
// each listener's own client/ScaledVolume() instead of one shared volume for everyone
// — a bare view() << sound() can only carry one volume value. `base` is this clip's
// own mix level (most sounds are fine at 100; some combat sounds sit louder/quieter).
proc/PlaySFXAt(atom/center, filename, channel = SFX_CHANNEL, base = 100)
    for(var/mob/M in view(center))
        if(!M.client) continue
        M.client << sound(filename, channel = channel, volume = M.client.ScaledVolume(base))

// -----------------------------
// Screen fade transition — masks the instant z-level teleport stairs/sky-fall
// (Turfs.dm) already did. See Markdowns/CodeNotes.md for the confirmed fade.dmi state
// details behind FADE_STATES.
// -----------------------------
var/list/FADE_STATES = list("0", "12.5", "25", "37.5", "50", "62.5", "75", "87.5", "100")
#define FADE_STEP_DELAY 1  // deciseconds per frame
#define FADE_STEP_INCREMENT 2
#define FADE_STEP_DECREMENT -2

client/var/obj/fadeOverlay

client/proc/GetFadeOverlay()
    if(!fadeOverlay)
        var/obj/F = new
        F.icon = 'fade.dmi'
        F.icon_state = "0"
        // Tiles one icon across the whole 13x13 view (world.view) rather than
        // stretching a single image — screen_loc ranges repeat the icon per tile.
        F.screen_loc = "1,1 to 13,13"
        F.layer = FLOAT_LAYER  // above everything, including other screen objects
        fadeOverlay = F
    return fadeOverlay

// toBlack TRUE fades 0->100 (transparent to black); FALSE reverses it and removes the
// overlay from client.screen. Blocks the calling proc for the sequence's duration
// (sleep(), not `set waitfor = 0`) — callers that need this alongside other logic
// (e.g. a teleport between the two halves) should call it from within their own spawn().
mob/proc/PlayScreenFade(toBlack = TRUE)
    if(!client) return
    var/obj/F = client.GetFadeOverlay()
    if(!(F in client.screen)) client.screen += F

    if(toBlack)
        for(var/i = 1 to FADE_STATES.len step FADE_STEP_INCREMENT)
            F.icon_state = FADE_STATES[i]
            sleep(FADE_STEP_DELAY)
    else
        for(var/i = FADE_STATES.len to 1 step FADE_STEP_DECREMENT)
            F.icon_state = FADE_STATES[i]
            sleep(FADE_STEP_DELAY)
        client.screen -= F

// Repeated verb calls (a hotkey held down) used to spam the exact same line into the
// Info pane once per call — this throttles the identical-text case specifically: the
// same message shown again within INFO_REPEAT_THROTTLE is dropped, a DIFFERENT
// message always gets through immediately. Per-mob, not global.
#define INFO_REPEAT_THROTTLE 5  // deciseconds — 0.5s
mob/var/lastInfoText = null
mob/var/lastInfoTime = 0

mob/proc/ShowInfo(text)
    if(!client) return
    if(text == lastInfoText && (world.time - lastInfoTime) < INFO_REPEAT_THROTTLE) return
    lastInfoText = text
    lastInfoTime = world.time
    src << output(text, "Info")

// Bare last path segment of a typepath or icon path, e.g. /mob/enemy/slime -> "slime".
proc/GetIconFilename(icon_path)
    var/list/parts = splittext("[icon_path]", "/")
    return parts[parts.len]

// First-letter-uppercase, rest untouched, e.g. "bedleft" -> "Bedleft".
proc/Capitalize(text)
    if(!text) return text
    return uppertext(copytext(text, 1, 2)) + copytext(text, 2)

// True if text ends with the confirmed OG night-suffix convention ("redcobble" ->
// "redcobblenight", no separator).
proc/IsNightVariant(text)
    if(!text) return FALSE
    var/len = length(text)
    return len > 5 && copytext(text, len - 4, len + 1) == "night"

// Given ANY icon_state (day or night form), returns the version matching the CURRENT
// global isNight — stripping an existing "night" suffix first, so it's safe to pass
// either. See Markdowns/CodeNotes.md for why this recomputes fresh rather than
// trusting a stored baseline.
proc/ApplyNightSuffix(baseState)
    if(!baseState) return baseState
    var/state = baseState
    if(IsNightVariant(state))
        state = copytext(state, 1, length(state) - 4)
    if(isNight) state += "night"
    return state

// Toggled by GM_BattleMode() — forces every area's battleModeOn to the same value,
// disregarding each area type's own default (Area.dm).
var/global/battleModeGlobalOn = FALSE

// Same shape as battleModeGlobalOn, but for GM_CoopMode()'s "All Areas" option.
// Starts TRUE to match reality -- every area defaults to coop (Area.dm's
// battleAllowsPvP = FALSE). It used to start FALSE, so the first "All Areas" toggle
// announced coop turning ON while changing nothing.
var/global/coopModeGlobalOn = TRUE

// Toggled by GM_SaveLocation() — when TRUE, a returning character's saved (x,y,z) is
// used instead of GetPlayerSpawnTurf() at load time. World-wide, matching the
// confirmed OG scope.
var/global/saveLocationEnabled = FALSE

world
    name      = "Dragon Warrior Legacy Remake"
    // Setting world.fps directly rounds tick_lag UP (fps=60 -> tick_lag=0.17 -> an actual
    // ~59fps), which is the documented source of persistent jank at "clean" framerates
    // like 60 (Ter13, BYOND forum post 2481387). Setting tick_lag directly and rounding
    // DOWN instead (floor(1000/60)/100 = 0.16) lands north of 60fps (~62.5) rather than
    // south of it.
    tick_lag  = 0.16
    icon_size = 32
    turf      = /turf/ground
    mob       = /mob/playerTemp
    view      = "13x13"

    New()
        . = ..()
        // Reset on every New() — including the one world.Reboot() triggers internally,
        // not just the initial boot. Left alone, a post-reboot `players` list would
        // keep referencing mobs the reboot's own object wipe just deleted.
        players = list()
        LoadPersistentAdminLists()
        log = file("server.log")
        // Day/night clock DISABLED 2026-08-26 (user call) — see Markdowns/CodeNotes.md.
        // WorldClockLoop()

    // world.Reboot() itself only wipes/reinitializes world state — it does NOT
    // automatically give already-connected clients a fresh mob or call Login() on it,
    // so existing clients need to be walked through login again explicitly here. See
    // Markdowns/CodeNotes.md for the confirmed OG bug this fixes and the Dream
    // Daemon-only environment quirk around testing it.
    Reboot()
        . = ..()
        for(var/client/C)
            if(C.mob) del(C.mob)  // clear anything the engine's own wipe may have auto-assigned
            var/mob/playerTemp/M = new()
            C.mob = M
            M.Login()

client
    var/datum/SaveManager/saveManager

    // -------------------- Volume Control --------------------
    // Master/Music/SFX sliders, percentages (0-100). Master is the actual base
    // loudness; Music/SFX are multipliers layered on top. Persisted per-ckey
    // (SaveManager.LoadVolumeSettings()/SaveVolumeSettings(), SaveSystem.dm).
    var/masterVolume = DEFAULT_MASTER_VOLUME
    var/musicVolume = DEFAULT_CHANNEL_VOLUME
    var/sfxVolume = DEFAULT_CHANNEL_VOLUME

    // Scales `base` (a call site's own mix level, default 100) by this client's
    // Master + the relevant channel slider.
    proc/ScaledVolume(base = 100, isMusic = FALSE)
        var/channelPct = isMusic ? musicVolume : sfxVolume
        return round(base * (channelPct / 100) * (masterVolume / 100))

    New()
        . = ..()
        saveManager = new(ckey)
        saveManager.LoadVolumeSettings(src)   // must run before Login()'s login-music sound() call

        // The view centers exactly on whatever client.eye is. During real gameplay
        // that's CameraEye (SmoothMovement.dm), which already replicates
        // EDGE_PERSPECTIVE's box-in-the-map behavior on its own — MOB_PERSPECTIVE
        // here just means "follow eye directly," not "follow the raw player mob."
        perspective = MOB_PERSPECTIVE

        // client.tick_lag is separate from world.tick_lag — it controls how often THIS
        // client re-renders/interpolates glides, independent of the server's own tick
        // rate. Set north of common high-refresh monitors (floor(1000/144)/100 = 0.06,
        // ~167fps) so gliding isn't capped below the display's own refresh rate. Per
        // Ter13 (BYOND forum post 2481387): "you want your client.tick_lag to give you
        // an FPS that is north of your user's refresh rate."
        tick_lag = 0.06

        if(.) MoveLoop()  // smooth-movement loop (SmoothMovement.dm)

        ApplyAdminLevel()

        // Reject a second simultaneous connection from an IP that already has one.
        // GMs are exempt. See Markdowns/CodeNotes.md for the confirmed OG server log
        // this behavior is drawn from.
        if(!allowMultiLogin && adminLevel < LEVEL_GM_HOST)
            for(var/client/C)
                if(C != src && C.address == address)
                    LogChat("[key]/[C.key] attempted double login at [address].")
                    del(src)
                    return

// -------------------- Movement Rules --------------------
obj
    step_size = 32

// This game is 4-directional only (see SmoothMovement.dm). Hoisted to a global instead of
// being rebuilt inline on every Move(): enemy pathing runs on step_to(), which produces
// diagonals constantly, so this check sits on essentially every mob step in the world.
var/list/DIAGONAL_DIRS = list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)

mob
    var/isCharacter = FALSE   // TRUE once a mob is a real, finalized/loaded character (vs. a temp/GM mob)

    step_size = 32

    // The one exception to the no-diagonals rule: a forced shove (KnockBack(),
    // SkillCatalog.dm -- Quakejump's ring pushes its corner tiles diagonally). Set for
    // that single Move() only; nothing a player or monster does on its own sets it.
    var/tmp/allowDiagonalMove = FALSE

    // Set by PerformHop() (SkillCatalog.dm) while a jumper is lifted above other mobs;
    // null otherwise. The first real move after landing puts the layer back.
    var/tmp/layerBeforeHop = null

    Move(loc, dir = 0)
        if((dir in DIAGONAL_DIRS) && !allowDiagonalMove)
            return
        . = ..()
        // Not while still in the air -- the hop's own glide steps come through here.
        if(. && !isAirborne && !isnull(layerBeforeHop))
            layer = layerBeforeHop
            layerBeforeHop = null

// -------------------- Temporary Player (Login Phase) --------------------
mob/playerTemp
    Login()
        DisableCommands()
        client << sound('dw3conti.mid', repeat = 1, volume = client.ScaledVolume(isMusic = TRUE), channel = 1)
        src.ShowInfo("Welcome to DWL Remake!!")

        spawn(1)
            ShowLoginMenu(src)

        EnableCommands()
        // EnableCommands() just added every /mob/verb-typed verb wholesale, including
        // GM-only ones — re-run the GM verb sync so that removal actually sticks for
        // non-GMs.
        client.SyncGMVerbs()
        players << output("[src.name] has joined the world!!", "Messages")
        LogChat("[src.name]([src.key]) logs in at [client.address].")

    Logout()  // covers disconnects during character select/creation only
        SaveAndLogout()

// -------------------- Real Player (Gameplay) --------------------
// mob/playerTemp's Logout() above only covers disconnects during character
// select/creation — mob/playerTemp and mob/player are siblings, not parent/child, so
// this needs its own override to save progress on disconnect during real gameplay.
mob/player
    Logout()
        SaveAndLogout()

mob/proc/SaveAndLogout()
    // Save comes first — if LogChat()/world.log ever runtime-errors, that aborts the
    // rest of this proc, and a save that happened after would never run.
    //
    // Uses the mob's own saveManager, not client.saveManager — on an abrupt
    // disconnect, client can already be null by the time Logout() fires.
    if(istype(src, /mob/player))
        var/mob/player/P = src
        if(P.saveManager)
            if(!P.skipSaveOnLogout)
                P.saveManager.SaveCharacter(P, P.saveSlot || 1)
            P.saveManager.Close()
        P.LeavePartyIfAny()  // before the del() below — see the proc's own note (Party.dm)

    players << output("[src.name] has left the world!!", "Messages")
    LogChat("[src.name]([src.key]) logs out at [client ? client.address : "unknown"].")
    players -= src
    src.loc = null

    // Actually destroy the mob, not just remove it from `players`/clear its loc — a
    // mob left undeleted here keeps its .key forever, so reconnecting silently
    // reattaches the new client to this stale mob instead of running Login() at all.
    // Must be the LAST statement — src is invalid after.
    del(src)

// -------------------- Command Control --------------------
mob/proc/DisableCommands()
   src.verbs -= typesof(/mob/verb)

mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)

// Shared lock/unlock pair for any fade-and-teleport transition (stairs, falling
// through sky, warp — Turfs.dm). SUPERSEDED the DisableCommands()/EnableCommands()
// approach (2026-09-09): removing verbs from .verbs visibly blinked the whole menu
// away and back for the transition's duration, most noticeable on the ~12.5s warp.
// canAct alone already covers this now that every verb checks RequireCanAct()
// (PlayerTemplate.dm) at its own top — verbs stay visible and just silently no-op
// instead of disappearing.
mob/proc/LockForTransition()
    canAct = FALSE

mob/proc/UnlockAfterTransition()
    canAct = TRUE
