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
        TestSave()
            set category = "Debug"

            if(client && client.save_mgr)
                client.save_mgr.save_character(src, 1)
                src << output("Saved character [name] with Strength=[Strength], Level=[Level]", "Info")

        Debug_ShowZoneColors()
            set category = "Debug"
            // Zones to check
            var/list/zones = list("Hair", "Eyes", "Main", "Accent")

            for(var/zone in zones)
                var/orig_color = palette?.originalColors[zone]
                var/current_color = null
                switch(zone)
                    if("Hair")   current_color = hair_color
                    if("Eyes")   current_color = eye_color
                    if("Main")   current_color = main_color
                    if("Accent") current_color = accent_color

                src << "[zone]: Original=[orig_color]  Current=[current_color]"