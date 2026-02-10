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
//    Last Update: 2/8/2026
//
//    Known Issues:
//    - Attacks break when targeting off screen
//    - Movement still feels slightly janky, but I don't think I can solve that one
//
//    To do list:
//    - Complete combat - players, enemies with AI, involving all the things below
//    - Class templates - default player template and class specific skills
//    - Skills and abilities - so players can do cool battle stuff
//    - Interact system - the basic .center interact with npcs, picking up items, open doors, etc. *partially functional
//    - Party System
//    - Tweak roof controls
//    - respawn at church after death
//    - custom doors, custom keys that will unlock/lock doors or open when you interact while carrying the key
//    - GM/Admin systems - building system
*/

// -------------------- Global Settings --------------------
var/global/baseVolume = 10   // I'm not going to have one of those games that deafens people on startup
var/list/players = list()

world
    name      = "Dragon Warrior Legacy Remake"
    fps       = 60
    icon_size = 32
    turf      = /turf/ground/grass
    mob       = /mob/playerTemp
    view      = "13x13"

client
    var/datum/SaveManager/saveManager   // declare the variable
    New()
        ..()                            // call parent constructor
        saveManager = new(ckey)         // attach SaveManager to this client
        var/zoom = 5.6
        winset(src, "GamePlay", "size=[world.view*world.icon_size*zoom]x[world.view*world.icon_size*zoom]")
        perspective = EDGE_PERSPECTIVE

// -------------------- Movement Rules --------------------
obj
    step_size = 32

mob
    var/isCharacter = FALSE

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


    Logout() //well fine...just leave then. See if I care!
        players << output("[src.name] has left the world!!", "Messages")
        if(client && client.saveManager)
            client.saveManager.SaveCharacter(src, 1)
        players -= client
        src.loc = null

// -------------------- Command Control --------------------
// Disable all verbs until login is complete
mob/proc/DisableCommands()
   src.verbs -= typesof(/mob/verb)

// Enable verbs once the player has joined the world
mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)

client/proc/SaveFile()
    // Each client has ONE savefile:
    // players/[ckey].sav
    return new /savefile("players/" + ckey + ".sav")