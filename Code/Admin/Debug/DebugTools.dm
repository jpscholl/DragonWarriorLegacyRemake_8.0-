// -----------------------------
// Debug Verbs
// -----------------------------
// Also unrestricted for now, same caveat as GMCommands.dm.
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

		// Spawns a placeholder /mob/enemy/slime (Code/Combat/NPCs/EnemyNPCs.dm) on
		// the tile in front of you, for testing AI/combat without a real monster
		// placement tool yet (TODOList.md Phase 10, GMmakemob).
		Test_SpawnSlime()
			set category = "Debug"
			var/turf/T = get_step(usr, usr.dir)
			if(!T) T = usr.loc
			new /mob/enemy/slime(T)
			usr << output("Spawned a test slime.", "Info")

		// Nothing inflicts poison in-game yet (no monster attack, trap, or spell
		// applies it) — this is the only way to trigger it for now. See
		// Code/Combat/StatusEffects.dm.
		Test_PoisonSelf()
			set category = "Debug"
			usr.ApplyStatusEffect(/datum/status_effect/poison)

		// Tops HP/MP back up to max, for testing (e.g. after taking hits, or
		// spending mana on Blaze).
		FullRestore()
			set category = "Debug"
			usr.HP = usr.MaxHP
			usr.MP = usr.MaxMP
			usr << output("Fully restored: [usr.HP]/[usr.MaxHP] HP, [usr.MP]/[usr.MaxMP] MP.", "Info")

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

// Prints each color zone's default vs. currently-applied color — handy for
// checking whether an icon actually has DefaultIconColors data wired up.
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
