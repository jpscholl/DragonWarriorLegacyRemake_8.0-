mob/player
    var
        // -----------------------------
        // Clickable stat link objects
        // -----------------------------
        obj/StatLink/strStatPanel
        obj/StatLink/vitStatPanel
        obj/StatLink/agiStatPanel
        obj/StatLink/intStatPanel
        obj/StatLink/luckStatPanel

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
        if(!strStatPanel)  strStatPanel  = new /obj/StatLink("Strength", src)
        if(!vitStatPanel)  vitStatPanel  = new /obj/StatLink("Vitality", src)
        if(!agiStatPanel)  agiStatPanel  = new /obj/StatLink("Agility", src)
        if(!intStatPanel)  intStatPanel  = new /obj/StatLink("Intelligence", src)
        if(!luckStatPanel) luckStatPanel = new /obj/StatLink("Luck", src)

        // Header panel for combat-related stats
        statpanel("Battle")

        // Display clickable stat links for allocation
        stat(strStatPanel)
        stat(vitStatPanel)
        stat(agiStatPanel)
        stat(intStatPanel)
        stat(luckStatPanel)

        // Show remaining stat points available for allocation
        stat("Stat Points: [StatPoints]")