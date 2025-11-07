mob/player
	var
		obj/stat_link/str_display
		obj/stat_link/vit_display
		obj/stat_link/agi_display
		obj/stat_link/int_display
		obj/stat_link/luck_display

	Stat()

//player stats
		//stats update without stat points
		statpanel("Stats")
		stat("Name: [src]")
		stat("Class: [class]")
		stat("Level: [Level]")
		stat("EXP: [Exp]/[Nexp]")
		stat("HP: [HP]/[MaxHP]")
		stat("MP: [MP]/[MaxMP]")

		if(!str_display)str_display = new /obj/stat_link("Strength", Strength)
		if(!vit_display)vit_display = new /obj/stat_link("Vitality", Vitality)
		if(!agi_display)agi_display = new /obj/stat_link("Agility", Agility)
		if(!int_display)int_display = new /obj/stat_link("Intelligence", Intelligence)
		if(!luck_display)luck_display = new /obj/stat_link("Luck", Luck)

		//update values
		str_display.name = "Strength: [Strength]"
		vit_display.name = "Vitality: [Vitality]"
		agi_display.name = "Agility: [Agility]"
		int_display.name = "Intelligence: [Intelligence]"
		luck_display.name = "Luck: [Luck]"


//Battle Panel
		statpanel("Battle")
		//these should be clickable to add stats
		stat(str_display)
		stat(vit_display)
		stat(agi_display)
		stat(int_display)
		stat(luck_display)
		stat("Stat Points: [StatPoints]")