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
//    Last Update: 12/14/2025
//
//    Known Issues:
//    - Attacks break when targeting off screen
//    - Movement still feels janky
//
//    To do list:
//    - Clean and refactor code as needed(for developer purposes)
//    - Complete combat - players, enemies with AI, involving all the things below
//    - Class templates - default player template and class specific skills and stat growth
//    - Skills and abilities - so players can do cool battle stuff
//    - Level up - figuring out character stat growth
//    - Interact system - the basic .center interact with npcs, picking up items, open doors, etc.
//    - Party System
//    - Tweak roof controls
//    - respawn at church
//    - custom doors, custom keys that will unlock/lock doors or open when you interact while carrying the key
*/

// -------------------- Global Settings --------------------
var/global/world_volume = 30   // I'm not going to have one of those games that deafens people on startup
var/list/players = list()

world
    name      = "Dragon Warrior Legacy Remake"
    fps       = 60
    tick_lag  = 0.16
    icon_size = 32
    turf      = /turf/ground/grass
    mob       = /mob/player_tmp
    view      = "13x13"

client
    var/datum/SaveManager/save_mgr   // declare the variable
    New()
        ..()                         // call parent constructor
        save_mgr = new(ckey)         // attach SaveManager to this client
        var/zoom = 5.6
        winset(src, "GamePlay", "size=[world.view*world.icon_size*zoom]x[world.view*world.icon_size*zoom]")
        perspective = EDGE_PERSPECTIVE

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
        DisableCommands()
        client << sound('dw3conti.mid', repeat = 1, volume = world_volume, channel = 1)
        src << output("Welcome to DWL Remake!!", "Info")

        if(client && client.save_mgr)
            if(client.save_mgr.load_character(src, 1))
                src << output("Character loaded from save slot 1.", "Info")
                finalize_player(src)   // turn tmp into real mob
            else
                src << output("No saved character found, please create one.", "Info")
                show_login_menu(src)   // <-- call your menu here
        else
            // If no SaveManager at all, fall back to menu
            show_login_menu(src)

        EnableCommands()
        players << output("[src.name] has joined the world!!", "Messages")

    Logout()
        if(client && client.save_mgr)
            client.save_mgr.save_character(src, 1)
        players -= client
        src.loc = null

// -------------------- Command Control --------------------
// Disable all verbs until login is complete
mob/proc/DisableCommands()
   src.verbs -= typesof(/mob/verb)

// Enable verbs once the player has joined the world
mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)