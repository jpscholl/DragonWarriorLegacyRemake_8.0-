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
//    Last Update: 7/25/2026
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
var/global/baseVolume = 10   // I'm not going to have one of those games that deafens people on startup
var/list/players = list()

// How many save slots each player gets, and where a new/loaded character spawns.
// Shared across LoginMenu.dm and SaveSystem.dm so both stay in sync.
#define MAX_CHARACTERS 4
#define PLAYER_SPAWN locate(26, 8, 4)

// Longest a character name can be.
#define MAX_NAME_LENGTH 24

// SPRITE_PIXEL_Y_OFFSET (shared vertical sprite offset, used by both mob/player and
// mob/enemy) is defined in the .dme file itself, not here — Combat/NPCs/EnemyNPCs.dm
// compiles before this file alphabetically, so a #define here wouldn't be visible yet
// when it's needed. Same reason TILE_WIDTH/TILE_HEIGHT live in the .dme too.

// Server mode for the text filter (Code/Core/TextFilter.dm). FALSE = general audience,
// enforces both the always-banned list and the general-profanity list. TRUE = adult
// server, only the always-banned list (slurs/hate speech) applies. Real var (not a
// #define) so it can be toggled at runtime — see GMToggleProfanityFilter() in
// Code/Admin/Commands/GMCommands.dm.
var/global/adultServer = FALSE

// Day/night state — toggled by GMdaynight() in Code/Admin/Commands/GMCommands.dm.
// World icons only (turfs/objs), not mobs — the OG has no night sprites for those.
var/global/isNight = FALSE

// Global battle-mode override — toggled by GMbattlemode() in
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

client
    var/datum/SaveManager/saveManager   // declare the variable
    New()
        . = ..()                        // call parent constructor
        saveManager = new(ckey)         // attach SaveManager to this client

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
        client << sound('dw3conti.mid', repeat = 1, volume = baseVolume, channel = 1)
        src << output("Welcome to DWL Remake!!", "Info")

        // Always show the login menu first
        spawn(1)
            ShowLoginMenu(src)

        EnableCommands() //now you can cause trouble in the world
        players << output("[src.name] has joined the world!!", "Messages")


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
    players << output("[src.name] has left the world!!", "Messages")
    if(client && client.saveManager)
        client.saveManager.SaveCharacter(src, saveSlot || 1)
    players -= src
    src.loc = null

// -------------------- Command Control --------------------
// Disable all verbs until login is complete
mob/proc/DisableCommands()
   src.verbs -= typesof(/mob/verb)

// Enable verbs once the player has joined the world
mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)
