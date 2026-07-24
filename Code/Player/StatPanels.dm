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

        // Display clickable stat links for allocation — order matches the confirmed OG
        // Battle tab layout (Str, Agi, Vit, Int, Luck).
        stat(strStatPanel)
        stat(agiStatPanel)
        stat(vitStatPanel)
        stat(intStatPanel)
        stat(luckStatPanel)

        // Show remaining stat points available for allocation
        stat("Stat Points: [StatPoints]")

        // ---------------- Skills (numpad slots + Free Skills) ----------------
        // Text-only readout matching the confirmed OG layout — no drag-and-drop
        // equip/unequip yet, see TODOList.md.
        stat("Numpad 9: [GetEquippedSkillName(9)]")
        stat("Numpad 7: [GetEquippedSkillName(7)]")
        stat("Numpad 3: [GetEquippedSkillName(3)]")
        stat("Numpad 1: [GetEquippedSkillName(1)]")
        stat("Numpad 0: [GetEquippedSkillName(0)]")
        stat("Free Skills -")
        stat("")
        for(var/datum/skill/S in skills)
            if(IsSkillEquipped(S)) continue
            stat(S.skillName)

        // ---------------- Inventory Panel ----------------
        // Header panel for carried items
        statpanel("Inventory")

        stat("Capacity: [GetInventoryCount()]/[GetInventoryCapacity()]")

        // Each item shows its own icon+name and routes clicks to its own Click()
        // (Code/Player/Inventory.dm) — same mechanism as the Battle tab's StatLinks above.
        for(var/obj/item/I in contents)
            stat(I)