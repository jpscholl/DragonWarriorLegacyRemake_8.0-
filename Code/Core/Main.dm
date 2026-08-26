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
//    To do list: see Markdowns/TODOList.md, the actual maintained planning doc — this
//    used to be an inline list here, but it's badly out of date (combat/enemy AI/most
//    of GM tooling it references as not-started are now built) and TODOList.md is
//    kept current instead, so this header just points there rather than duplicating
//    (and inevitably drifting from) it.
*/

// -------------------- Global Settings --------------------

// Remake's own version, independent of the "8.0" in the OG this is based on (see
// header above) — pre-1.0 SemVer. Bump the middle number for a build pass that adds
// a feature set (a commit like "Mechanics-first build pass" or "GM moderation tools"),
// the last number for a fix-only commit in between, and land on 1.0.0 once the game is
// playable start to finish. Shown on the login menu (ShowLoginMenu(), LoginMenu.dm) and
// logged in CHANGELOG.md alongside what each bump actually changed.
#define GAME_VERSION "0.7.0"

var/list/players = list()

// Volume slider fallbacks for a player who's never touched them (SaveManager.
// LoadVolumeSettings(), SaveSystem.dm). Master is the one that actually keeps login
// from being a blast; Music/SFX default to 100 = full relative to whatever Master is
// set to, since they're multipliers on Master, not independent absolute levels.
#define DEFAULT_MASTER_VOLUME 50
#define DEFAULT_CHANNEL_VOLUME 100

// MAX_CHARACTERS used to live here too — moved to the .dme itself (same
// #include-order reason as PLAYER_SPAWN/SPRITE_PIXEL_Y_OFFSET/SFX_CHANNEL there)
// once Admin/Commands/GMCommands.dm needed it before this file compiles.

// Longest a character name can be.
#define MAX_NAME_LENGTH 24

// SPRITE_PIXEL_Y_OFFSET (shared vertical sprite offset, used by both mob/player and
// mob/enemy) is defined in the .dme file itself, not here — Combat/NPCs/EnemyNPCs.dm
// compiles before this file alphabetically, so a #define here wouldn't be visible yet
// when it's needed. Same reason TILE_WIDTH/TILE_HEIGHT live in the .dme too.

// Server mode for the text filter (Code/Core/TextFilter.dm). FALSE = general audience,
// enforces both the always-banned list and the general-profanity list. TRUE = adult
// server, only the always-banned list (slurs/hate speech) applies. Real var (not a
// #define) so it can be toggled at runtime — see GM_ToggleProfanityFilter() in
// Code/Admin/Commands/GMCommands.dm.
var/global/adultServer = FALSE

// Toggled by GM_ToggleMultiLogin() in Code/Admin/Commands/GMCommands.dm — when TRUE,
// the address-based double-login block below (client/New()) is skipped entirely, so
// a GM can open a second client from the same machine to test multiplayer-facing
// verbs (GM_Ban/GM_Boot) without needing an actual second player. Off by default —
// this is a dev/testing escape hatch, not something a live server should leave on.
var/global/allowMultiLogin = FALSE

// Day/night state — driven automatically by the world clock below, and still toggleable
// on demand by GM_DayNight() in Code/Admin/Commands/GMCommands.dm.
// World icons only (turfs/objs), not mobs — the OG has no night sprites for those.
var/global/isNight = FALSE

// -----------------------------
// World clock
// -----------------------------
// CONFIRMED OG shape (string table): a running clock with per-minute/per-hour ticks,
// sunrise at 6:00 AM and sunset at 6:00 PM, a 12:00 PM start, and a distinct flavor
// message for each transition. The remake had `isNight` and IsNightVariant() as helpers
// with nothing driving them — day/night only ever changed if a GM typed the verb. This
// is the missing clock.
//
// PLACEHOLDER cadence: the OG's real-time-to-game-time ratio isn't recovered, so one
// game hour per real minute is chosen here — a full day/night cycle every 24 real
// minutes, which keeps both halves visible in a normal play session. Tune freely; every
// other part of the clock is derived from these two numbers.
#define GAME_MINUTES_PER_TICK 10
#define REAL_DECISECONDS_PER_TICK 10   // one tick per real second

#define SUNRISE_HOUR 6
#define SUNSET_HOUR 18

// Minutes since midnight. Starts at 12:00 PM, matching the OG's own documented start.
var/global/gameMinuteOfDay = 720

// Human-readable clock, e.g. "6:00 PM" — the format the OG's own strings use. Shown in
// the Status panel (Code/Player/StatPanels.dm).
proc/GetGameTimeString()
    var/hour24 = round(gameMinuteOfDay / 60)
    var/minute = gameMinuteOfDay % 60
    var/period = hour24 >= 12 ? "PM" : "AM"
    var/hour12 = hour24 % 12
    if(!hour12) hour12 = 12
    return "[hour12]:[minute < 10 ? "0" : ""][minute] [period]"

// Applies a day/night transition to the whole world. Shares GM_DayNight()'s own
// ToggleNightIconState() sweep (GMCommands.dm) rather than reimplementing the turf/obj
// walk, so a clock-driven sunset and a GM-forced one produce identical results.
proc/SetWorldNight(toNight, message)
    if(isNight == toNight) return
    isNight = toNight

    for(var/turf/T in world)
        ToggleNightIconState(T, isNight)
    for(var/obj/O in world)
        if(istype(O, /obj/StatLink)) continue
        ToggleNightIconState(O, isNight)

    if(message)
        players << output("<center><b>[message]</b></center>", "Messages")

// Advances the clock one tick and fires the sunrise/sunset transitions as they're
// crossed. Started once from world/New().
proc/WorldClockLoop()
    set waitfor = 0
    while(TRUE)
        sleep(REAL_DECISECONDS_PER_TICK)

        gameMinuteOfDay = (gameMinuteOfDay + GAME_MINUTES_PER_TICK) % 1440
        var/hour24 = round(gameMinuteOfDay / 60)

        // Flavor lines are the OG's own, verbatim from the string table.
        if(hour24 >= SUNSET_HOUR || hour24 < SUNRISE_HOUR)
            SetWorldNight(TRUE, "The sun sinks below the horizon and night falls over the land.")
        else
            SetWorldNight(FALSE, "The sun rises in the east and a new day is born.")

// Sends `filename` to every client-having mob visible from `center` — same audience a
// bare `view(center) << sound(...)` broadcast would reach, except personalized to each
// listener's own client/ScaledVolume() (Main.dm) instead of one shared volume for
// everyone. A single view() << sound() can only carry one volume value, which would
// ignore individual players' Master/SFX sliders entirely. `base` = this particular
// clip's own mix level (most sounds are fine at the 100 default; a few combat sounds
// like attack/spell pass a custom base to sit louder or quieter than the rest) — not
// to be confused with the Master/Music/SFX sliders, which scale on top of it.
proc/PlaySFXAt(atom/center, filename, channel = SFX_CHANNEL, base = 100)
    for(var/mob/M in view(center))
        if(!M.client) continue
        M.client << sound(filename, channel = channel, volume = M.client.ScaledVolume(base))

// Bare last path segment of a typepath or icon path, e.g. /mob/enemy/slime -> "slime".
// Generic string util (not UI- or icon-specific) — used by LoginMenu.dm for icon
// selection and by BuildTools.dm's typesof()-driven pickers for display names.
proc/GetIconFilename(icon_path)
    var/list/parts = splittext("[icon_path]", "/")
    return parts[parts.len]

// First-letter-uppercase, rest untouched, e.g. "bedleft" -> "Bedleft". Generic string
// util — used wherever a raw type/icon_state name needs to become a display label
// (BuildTools.dm's GetTypeChoices(), GMCommands.dm's GM_CreateObj NPC naming).
proc/Capitalize(text)
    if(!text) return text
    return uppertext(copytext(text, 1, 2)) + copytext(text, 2)

// True if text ends with the confirmed OG night-suffix convention ("redcobble" ->
// "redcobblenight", no separator). Shared by GM_DayNight's ToggleNightIconState
// (Code/Admin/Commands/GMCommands.dm — the actual runtime day/night swap) and
// BuildTools.dm's turf-variant picker (Code/Admin/Commands/BuildTools.dm — so "Day"
// only ever offers variants GM_DayNight can actually toggle in place).
proc/IsNightVariant(text)
    if(!text) return FALSE
    var/len = length(text)
    return len > 5 && copytext(text, len - 4, len + 1) == "night"

// Global battle-mode override — toggled by GM_BattleMode() in
// Code/Admin/Commands/GMCommands.dm. Forces every area's battleModeOn to the same
// value, disregarding each area type's own default (Code/World/Area.dm).
var/global/battleModeGlobalOn = FALSE

world
    name      = "Dragon Warrior Legacy Remake"
    fps       = 60
    icon_size = 32
    turf      = /turf/ground
    mob       = /mob/playerTemp
    view      = "13x13"

    New()
        . = ..()
        // Reset on every New() — including the one world.Reboot() (GM_WorldReboot(),
        // GMCommands.dm) triggers internally, not just the initial boot. Left alone,
        // a post-reboot `players` list would keep referencing mobs the reboot's own
        // object wipe just deleted.
        players = list()
        // Redirects world.log to a persistent file — BYOND auto-timestamps every
        // line and auto-logs connect/disconnect/host events into the same stream.
        // Chat verbs write into this same log via LogChat() (Code/Core/TextFilter.dm).
        log = file("server.log")
        // Starts the day/night clock (above). Runs here rather than at a global scope
        // so a world.Reboot() restarts it cleanly along with everything else — the
        // reboot's object wipe kills the old loop.
        WorldClockLoop()

    // world.Reboot() itself only wipes/reinitializes world state — it does NOT
    // automatically give already-connected clients a fresh mob or call Login() on
    // it (confirmed broken in the OG's own version, GMCommandsReference.md: everyone
    // stuck on a black screen after reboot). ..() does the actual engine-level wipe
    // (deletes every object, re-runs world/New() above) and re-parents `mob` (already
    // /mob/playerTemp — see this datum's own vars above) as world.mob's default for
    // any brand-new connection, but existing clients need to be walked through login
    // again explicitly, same as a fresh connect: a new mob/playerTemp, assigned to
    // the client, with Login() called by hand since nothing else will call it now.
    //
    // CONFIRMED ENVIRONMENT QUIRK (not a bug in this override): world.Reboot() only
    // completes properly when the server is actually running under Dream Daemon.
    // Testing straight from Dream Seeker/DM without a real Dream Daemon process
    // hosting the session just freezes on the call — there's no server process
    // wrapping the world to relaunch. GM_WorldReboot (GMCommands.dm) needs a real
    // hosted (Dream Daemon) session to test end-to-end, not a local DM.exe run.
    Reboot()
        . = ..()
        for(var/client/C)
            if(C.mob) del(C.mob)  // clear anything the engine's own wipe may have auto-assigned
            var/mob/playerTemp/M = new()
            C.mob = M
            M.Login()

client
    var/datum/SaveManager/saveManager   // declare the variable

    // -------------------- Volume Control --------------------
    // Master/Music/SFX sliders (TODOList.md, Phase 4) — percentages (0-100). Master is
    // the actual base loudness (default 50, so login isn't a blast); Music/SFX are
    // multipliers layered on top of Master (default 100 = full, no attenuation beyond
    // whatever Master is set to). A `base` param can still be passed into
    // ScaledVolume()/PlaySFXAt() per call site for a specific clip's own mix level
    // (e.g. attack/spell sit louder than most SFX) — that's independent of these three
    // sliders. Persisted per-ckey (SaveManager/SaveSystem.dm, LoadVolumeSettings()/
    // SaveVolumeSettings()) — these vars live on /client, so they're already scoped to
    // one player, never global.
    var/masterVolume = DEFAULT_MASTER_VOLUME
    var/musicVolume = DEFAULT_CHANNEL_VOLUME
    var/sfxVolume = DEFAULT_CHANNEL_VOLUME

    // Scales `base` (a call site's own mix level for this clip, default 100) by this
    // client's Master + the relevant channel slider. isMusic picks musicVolume vs
    // sfxVolume — Music (channel 1, PlayAreaMusic()/Area.dm) and everything else
    // (SFX_CHANNEL/levelup's channel 2) are the only two channel categories that exist
    // right now.
    proc/ScaledVolume(base = 100, isMusic = FALSE)
        var/channelPct = isMusic ? musicVolume : sfxVolume
        return round(base * (channelPct / 100) * (masterVolume / 100))

    New()
        . = ..()                        // call parent constructor
        saveManager = new(ckey)         // attach SaveManager to this client
        saveManager.LoadVolumeSettings(src)   // must run before Login()'s login-music sound() call

        // Map panel sizing/zoom is now handled declaratively in Interface.dmf's
        // "Gameplay" elem (fixed 832x832, zoom=0/zoom-mode=normal) — this used to
        // force-resize it at runtime with a hardcoded zoom multiplier, which was
        // silently overriding every .dmf change on every single connection.
        perspective = EDGE_PERSPECTIVE

        // Start the smooth-movement loop (Code/Core/SmoothMovement.dm). This used to
        // live in a second client/New() override there — DM doesn't merge duplicate
        // proc definitions across files, so that override was silently never running.
        if(.) MoveLoop()

        // Resolve admin level fresh from hardcoded data every connection (Code/Admin/AdminLevels.dm)
        ApplyAdminLevel()

        // Reject a second simultaneous connection from an IP that already has one —
        // confirmed from a real OG server log excerpt: two different ckeys
        // ("D-FORCE"/"Supersayion5") from the same address, the new one logged as an
        // "attempted double login" and immediately disconnected while the original
        // session kept running unaffected. GMs are exempt (confirmed) — e.g. testing
        // with a second window from the same machine.
        if(!allowMultiLogin && adminLevel < LEVEL_GM_HOST)
            for(var/client/C)
                if(C != src && C.address == address)
                    LogChat("[key]/[C.key] attempted double login at [address].")
                    del(src)
                    return

// -------------------- Movement Rules --------------------
obj
    step_size = 32

mob
    var/isCharacter = FALSE   // TRUE once a mob is a real, finalized/loaded character (vs. a temp/GM mob)

    step_size = 32

    Move(loc, dir = 0)
        // Block diagonal movement
        if(dir in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
            return
        return ..()

// -------------------- Temporary Player (Login Phase) --------------------
mob/playerTemp
    Login()
        DisableCommands() //make sure you troublemakers can't do something while in the login menu
        client << sound('dw3conti.mid', repeat = 1, volume = client.ScaledVolume(isMusic = TRUE), channel = 1)
        src << output("Welcome to DWL Remake!!", "Info")

        // Always show the login menu first
        spawn(1)
            ShowLoginMenu(src)

        EnableCommands() //now you can cause trouble in the world
        // EnableCommands() just added every /mob/verb-typed verb wholesale, including
        // GM-only ones like GM_ToggleLog — re-run the GM verb sync (AdminLevels.dm) so
        // that removal actually sticks for non-GMs.
        client.SyncGMVerbs()
        players << output("[src.name] has joined the world!!", "Messages")
        LogChat("[src.name]([src.key]) logs in at [client.address].")


    Logout() //well fine...just leave then. See if I care! (covers disconnects during character select/creation only — see mob/player/Logout() below for real gameplay)
        SaveAndLogout()

// -------------------- Real Player (Gameplay) --------------------
// mob/playerTemp's Logout() above only covers disconnects during character
// select/creation. Once FinalizePlayer()/LoadCharacter() hand control to a
// /mob/player, that's a sibling type with no Logout() of its own, so it
// needs this override to actually save progress on disconnect.
mob/player
    Logout()
        SaveAndLogout()

// Shared by both Logout() overrides above (mob/playerTemp and mob/player are siblings,
// not parent/child, so neither inherits the other's) — announces departure, saves if
// there's a real character to save, and removes the mob from the world.
mob/proc/SaveAndLogout()
    // Save comes first, before anything else — if LogChat()/world.log ever runtime-
    // errors (bad path, permissions, whatever), that aborts the rest of this proc, and
    // a save that happened after the log call would never run. Saving before logging
    // means that failure mode can only ever cost a missing log line, never a lost save.
    //
    // Uses the mob's own saveManager (PlayerTemplate.dm), not client.saveManager — on
    // an abrupt disconnect (closing the window/hitting X, vs a graceful quit) client
    // can already be null by the time Logout() fires, which silently skipped the save
    // with no error. mob/playerTemp never has saveManager set (only real /mob/player
    // characters do, in FinalizePlayer()/LoadCharacter()), so this naturally still
    // skips saving during character select — nothing to save yet at that point anyway.
    if(istype(src, /mob/player))
        var/mob/player/P = src
        if(P.saveManager)
            if(!P.skipSaveOnLogout)
                P.saveManager.SaveCharacter(P, P.saveSlot || 1)
            // Release the file handle now that this session is over (see Close()'s
            // own comment, SaveSystem.dm, for why this matters).
            P.saveManager.Close()

    players << output("[src.name] has left the world!!", "Messages")
    LogChat("[src.name]([src.key]) logs out at [client ? client.address : "unknown"].")
    players -= src
    src.loc = null

    // Actually destroy the mob, not just remove it from `players`/clear its loc.
    // BYOND matches a newly-connecting client to any EXISTING mob whose .key still
    // matches theirs — a mob left undeleted here keeps its key forever, so
    // reconnecting (whether after a normal disconnect or a GM_Boot/GM_Ban) silently
    // reattaches the new client straight to this same stale mob instead of running
    // mob/playerTemp's Login()/ShowLoginMenu() at all. Confirmed bug: that stale
    // mob's loc was just nulled above and never gets reset, so the "skipped the
    // login menu, logged in at 1,1,1" symptom is BYOND's fallback placement once a
    // client is watching it again. Must be the LAST statement — src is invalid after.
    del(src)

// -------------------- Command Control --------------------
// Disable all verbs until login is complete
mob/proc/DisableCommands()
   src.verbs -= typesof(/mob/verb)

// Enable verbs once the player has joined the world
mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)
