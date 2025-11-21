/*
	Game: Dragon Warrior Legacy Remake
	Description: This game is a remake of Wizdragon(Tarq)'s Dragon Warrior action rpg from
	The game is based on version 8.0. There were later versions, but this is the only version available for
	reference. This version is aimed to replicate that version to the best of my ability while also adding
	some QoL changes...so 8.0+ so to speak.
	Author: Cerebella (Shorin88)
	Last Update: 11/19/2025

	Notes: Having issues combining all the crap I've done into one cohesive game...
*/
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
		client << sound('dw3conti.mid', repeat = 1, volume = world_volume, channel = 1) //add a way to adjust sounds volume later
		usr << output("Welcome to DWL Remake!!", "Info")
		show_login_menu(usr)
		world << output("[usr.name] has joined the world!!", "Messages")

	Logout()
		players -= client
		src.loc -= null