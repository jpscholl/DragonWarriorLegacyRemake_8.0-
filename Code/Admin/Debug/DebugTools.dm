mob
	verb
		DebugMovement()
			set category = "Debug"
			usr << output("<b>Current Server Stats<b/>", "Info")
			usr << output("FPS: [world.fps]", "Info")
			usr << output("Tick Lag: [world.tick_lag]", "Info")
			usr << output("Step Delay: [step_delay]", "Info")
			usr << output("Glide Size: [glide_size]", "Info")
			usr << output("Frames per Step: [round(step_delay / (1 / world.fps))]", "Info")

		Test_Leveling()
			usr.Exp+=100000
			spawn() usr.LevelCheck()

		S_World()
			set category = "Debug"
			icon_state = "world"

		S_Sleep()
			set category = "Debug"
			icon_state = "sleep"

		S_Attack()
			set category = "Debug"
			icon_state = "attack"

		S_Defend()
			set category = "Debug"
			icon_state = "defend"

mob
    verb
        Debug_ShowZoneColors()
            set category = "Debug"
            // Zones to check
            var/list/zones = list("Hair", "Eyes", "Main", "Accent")

            for(var/zone in zones)
                var/baseColor = palette?.originalColors[zone]
                var/current_color = null
                switch(zone)
                    if("Hair")   current_color = hairColor
                    if("Eyes")   current_color = eyeColor
                    if("Main")   current_color = mainColor
                    if("Accent") current_color = accentColor

                usr << output("[zone]: Original=[baseColor]  Current=[current_color]", "Info")