mob/player
    var
        obj/stat_link/str_display
        obj/stat_link/vit_display
        obj/stat_link/agi_display
        obj/stat_link/int_display
        obj/stat_link/luck_display

    Stat()
        // ---------------- Stats Panel ----------------
        statpanel("Stats")
        stat("[src.name]")
        stat("Class: [class]")
        stat("Level: [Level]")
        //stat("Party: [Party ? Party.name : "None"]")
        stat("Hit Points: [HP]/[MaxHP]")
        stat("Magic Points: [MP]/[MaxMP]")
        stat("Experience Points: [Exp]/[Nexp]")
        stat("Gold: [Gold]")
        stat("Players online: [length(players)]")

        // Initialize stat links once
        if(!str_display)  str_display  = new /obj/stat_link("Strength", src)
        if(!vit_display)  vit_display  = new /obj/stat_link("Vitality", src)
        if(!agi_display)  agi_display  = new /obj/stat_link("Agility", src)
        if(!int_display)  int_display  = new /obj/stat_link("Intelligence", src)
        if(!luck_display) luck_display = new /obj/stat_link("Luck", src)

        // ---------------- Battle Panel ----------------
        statpanel("Battle")
        stat(str_display)
        stat(vit_display)
        stat(agi_display)
        stat(int_display)
        stat(luck_display)
        stat("Stat Points: [StatPoints]")