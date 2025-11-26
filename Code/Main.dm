/*
    Game: Dragon Warrior Legacy Remake
    Description:
        Remake of Wizdragon (Tarq)'s Dragon Warrior action RPG, based on version 8.0.
        Later versions existed, but 8.0 is the only one available for reference.
        Goal: replicate 8.0 faithfully while adding QoL improvements ("8.0+").

    Author: Cerebella (Shorin88)
    Last Update: 11/25/2025

    Known Issues:
        - Attacks break when targeting off screen
        - Movement still feels janky

    To do list:
    - Clean and refactor code as needed(for developer purposes)
    - Complete combat - players, enemies with AI, involving all the things below
    - Class templates - default player template and class specific skills and stat growth
    - Skills and abilities - so players can do cool battle stuff
    - Level up - figuring out character stat growth
    - Interact system - the basic .center interact with npcs, picking up items, open doors, etc.
    - Party System
    - Tweak roof controls
    - respawn at church
    - custom doors, custom keys that will unlock/lock doors or open when you interact while carrying the key
*/

// -------------------- Global Settings --------------------
var/global/world_volume = 20   // I'm not going to have one of those games that deafens people on startup
world
    name      = "Dragon Warrior Legacy Remake"
    fps       = 60
    tick_lag  = 0.16
    icon_size = 32
    turf      = /turf/ground/grass
    mob       = /mob/player_tmp
    view      = "13x13"

client/New()
    ..()
    winset(src, "GamePlay", "zoom=2.6")
    perspective = EDGE_PERSPECTIVE
    view = "13x13"

// -------------------- Movement Rules --------------------
obj
    step_size = 32

mob
    step_size = 32

    Move(loc, dir = 0)
        // Block diagonal movement
        if(dir in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
            return
        return ..()

// -------------------- Temporary Player (Login Phase) --------------------
mob/player_tmp
    Login()
        DisableCommands()   // Prevent access to verbs before login completes
        client << sound('dw3conti.mid', repeat = 1, volume = world_volume, channel = 1)
        src << output("Welcome to DWL Remake!!", "Info")
        show_login_menu(src)
        EnableCommands()    // Enable verbs after login
        world << output("[src.name] has joined the world!!", "Messages")

    Logout()
        players -= client
        src.loc = null

// -------------------- Command Control --------------------
// Disable all verbs until login is complete
mob/proc/DisableCommands()
    for(var/v in src.verbs)
        src.verbs -= v

// Enable verbs once the player has joined the world
mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)