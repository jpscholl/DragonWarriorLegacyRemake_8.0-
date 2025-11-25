mob
	verb
		Emote(msg as text)
			set category = "Social"
			set desc = "Chat to players in view"
			if (trimtext(msg) == "") return
			view() << output("<font color = black> \icon[usr]<[usr.name] *[msg]*<font>>", "Messages")

		Say(msg as text)
			set category = "Social"
			set desc = "Talk to players in view"
			if (trimtext(msg) == "") return
			view() << output("<font color = blue> \icon[usr]<[usr.name] says:> [msg]<font>", "Messages")

		Tell(mob/m, msg as text)
			set category = "Social"
			set desc = "Directly talk to another player"
			var/mob/M = players[players]
			if (trimtext(msg) == "") return
			if (m != src)
				M << output("<font color = navy> \icon[m]<[src] tells you:> [msg]<font>", "Messages")
				usr << output("<font color = navy> \icon[usr]<You tell [m]:> [msg]<font>", "Messages")

		Who()
			set category = "Social"
			set desc = "Shows all players logged in and basic info"
			usr << output("<b>Players currently online:</b>", "Info")
			for(var/mob/M in players)
				usr << output("<font color='blue'>\icon[M] [M.name] ([M.key]) Class: Hero Level: 1 Party: None</font>", "Info")

		WorldEmote(msg as text)
			set category = "Social"
			set desc = "Emote to all players in the world"
			if (trimtext(msg) == "") return
			players << output("<font color = maroon> \icon[usr]<[usr.name] [msg]<font>>", "Messages")

		WorldSay(msg as text)
			set category = "Social"
			set desc = "Chat to all players in the world"
			if (trimtext(msg) == "") return
			players << output("<font color = purple> \icon[usr]<[usr.name] says:> [msg]<font>", "Messages")