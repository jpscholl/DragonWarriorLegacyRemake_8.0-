mob/player
    var
        // -----------------------------
        // Clickable stat link objects
        // -----------------------------
        obj/stat_link/str_display
        obj/stat_link/vit_display
        obj/stat_link/agi_display
        obj/stat_link/int_display
        obj/stat_link/luck_display

    // -----------------------------
    // Display player stats
    // -----------------------------
    Stat()
        // ---------------- Stats Panel ----------------
        // Header panel for general stats
        statpanel("Stats")

        // Identity & class info
        stat("[src.name]")               // Player name
        stat("Class: [class]")           // Player class
        stat("Level: [Level]")           // Player level
        //stat("Party: [Party ? Party.name : "None"]") // Optional party info

        // Core stats
        stat("Hit Points: [HP]/[MaxHP]")  // Current/max HP
        stat("Magic Points: [MP]/[MaxMP]")// Current/max MP
        stat("Experience Points: [Exp]/[Nexp]") // Current/next level XP
        stat("Gold: [Gold]")              // Currency
        stat("Players online: [length(players)]") // Total players online

        // ---------------- Battle Panel ----------------
        // Initialize clickable stat links once per player
        if(!str_display)  str_display  = new /obj/stat_link("Strength", src)
        if(!vit_display)  vit_display  = new /obj/stat_link("Vitality", src)
        if(!agi_display)  agi_display  = new /obj/stat_link("Agility", src)
        if(!int_display)  int_display  = new /obj/stat_link("Intelligence", src)
        if(!luck_display) luck_display = new /obj/stat_link("Luck", src)

        // Header panel for combat-related stats
        statpanel("Battle")

        // Display clickable stat links for allocation
        stat(str_display)
        stat(vit_display)
        stat(agi_display)
        stat(int_display)
        stat(luck_display)

        // Show remaining stat points available for allocation
        stat("Stat Points: [StatPoints]")
