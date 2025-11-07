/*
	Game: Dragon Warrior Legacy Remake
	Description: This game is a remake of Wizdragon(Tarq)'s Dragon Warrior action rpg
	The game is based on version 8.0. There were later versions, but this is the only version available for
	reference. This version is aimed to replicate that version to the best of my ability while also adding
	some QoL changes...so 8.0+ so to speak.
	Author: Cerebella (Shorin88)
	Last Update: 11/6/2025

	Notes: Having issues combining all the crap I've done into one cohesive game...
*/

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

// Make objects move 8 pixels per tick when walking

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
		usr << output("Welcome to DWL Remake!!", "Info")
		world << output("[usr] has joined the world!!", "Messages")
		show_login_menu(src)
		loc = locate(26,8,4)

	Logout()
		players -= src
		src.loc -= null
