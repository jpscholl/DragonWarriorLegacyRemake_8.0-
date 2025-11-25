/*
	Game: Dragon Warrior Legacy Remake
	Description: This game is a remake of Wizdragon(Tarq)'s Dragon Warrior action rpg from
	The game is based on version 8.0. There were later versions, but this is the only version available for
	reference. This version is aimed to replicate that version to the best of my ability while also adding
	some QoL changes...so 8.0+ so to speak.
	Author: Cerebella (Shorin88)
	Last Update: 11/24/2025

	Known Issues:
	-attack breaks when attacking off screen
	-movement still janky as all hell, but I'm not big brained enough to even know where to begin with that
	-make menus not accessible during login
*/

//lower volume because I refuse to have one of the games that destroys ear drums on launch
var/global
	world_volume = 20

world
	name = "Dragon Warrior Legacy Remake"
	fps = 63
	tick_lag = 0.16
	icon_size = 32
	turf = /turf/ground/grass
	mob = /mob/player_tmp
	view = "13x13"

client/New()
	..()
	winset(src, "GamePlay", "zoom=2.6")
	perspective = EDGE_PERSPECTIVE
	view = "13x13"

obj
	step_size = 32
mob
	step_size = 32

	Move(loc, dir = 0)
		if (dir in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
			return  // Block diagonal movement
		return ..()

mob/player_tmp
	Login()
		DisableCommands()
		client << sound('dw3conti.mid', repeat = 1, volume = world_volume, channel = 1) //add a way to adjust sounds volume later
		usr << output("Welcome to DWL Remake!!", "Info")
		show_login_menu(usr)
		EnableCommands()
		world << output("[usr.name] has joined the world!!", "Messages")

	Logout()
		players -= client
		src.loc = null

//We don't want players messing around with controls before they're logged in
mob/proc/DisableCommands()
    for(var/v in src.verbs)
        src.verbs -= v

//We'll give them access after they join the world
mob/proc/EnableCommands()
    src.verbs += typesof(/mob/verb)