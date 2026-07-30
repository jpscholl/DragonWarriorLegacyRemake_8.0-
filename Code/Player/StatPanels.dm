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
        stat("Party: [Party ? "[Party.name][isPartyLeader ? " Leader" : ""]" : "None"]")

        // Core stats
        stat("Hit Points: [HP]/[MaxHP]")  // Current/max HP
        stat("Magic Points: [MP]/[MaxMP]")// Current/max MP
        stat("Experience Points: [Exp]/[Nexp]") // Current/next level XP
        stat("Gold: [Gold]")              // Currency
        stat("Players online: [length(players)]") // Total players online

        // Active status effects (Code/Combat/StatusEffects.dm) — only shown when
        // there's actually something to report, so the panel isn't cluttered with an
        // empty line the rest of the time.
        if(length(statusEffects))
            var/effectNames = ""
            for(var/datum/status_effect/E in statusEffects)
                effectNames += (effectNames ? ", " : "") + E.effectName
            stat("Status: [effectNames]")

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
        // Real draggable objs (obj/SkillLink, Code/Player/SkillLink.dm) — drag a known
        // skill from Free Skills onto a numpad slot to equip it (swaps out whatever
        // was already there), or drag an equipped skill onto the Free Skills area
        // (a real drop target below, not plain text — needed even when Free Skills is
        // empty) to unequip it. Double-clicking an equipped skill also unequips it.
        stat(GetNumpadSkillLink(9))
        stat(GetNumpadSkillLink(7))
        stat(GetNumpadSkillLink(3))
        stat(GetNumpadSkillLink(1))
        stat(GetNumpadSkillLink(0))
        stat(GetFreeSkillsAreaLink())
        stat("")
        for(var/obj/SkillLink/L in GetFreeSkillLinks())
            stat(L)

        // ---------------- Inventory Panel ----------------
        // Header panel for carried items
        statpanel("Inventory")

        stat("Capacity: [GetInventoryCount()]/[GetInventoryCapacity()]")

        // Each item shows its own icon+name and routes clicks to its own Click()
        // (Code/Player/Inventory.dm) — same mechanism as the Battle tab's StatLinks above.
        for(var/obj/item/I in contents)
            stat(I)