// One-decimal percent as a string ("10.3", not "10.333333") — DM's string
// interpolation of a raw float prints far too many decimals for the OG's confirmed
// "X.X%" format (StatPanels.dm's Experience Points line). Integer-only math throughout
// since DM has no format-string precision specifier: scale to tenths, round() with one
// arg floors (see its own convention note elsewhere), then split whole/fractional.
proc/FormatPercent(numerator, denominator)
    if(!denominator) return "0.0"
    var/tenths = round(numerator / denominator * 1000)
    var/whole = round(tenths / 10)
    var/frac = tenths - whole * 10
    return "[whole].[frac]"

mob/player
    var
        // -----------------------------
        // Clickable stat link objects
        // -----------------------------
        obj/StatLink/strStatPanel
        obj/StatLink/vitStatPanel
        obj/StatLink/agiStatPanel
        obj/StatLink/intStatPanel
        obj/StatLink/spiritStatPanel

    // -----------------------------
    // Display player stats
    // -----------------------------
    Stat()
        // Bottom-of-screen HUD (Code/UI/HUD.dm) — lazily built on first tick, then
        // refreshed every tick after, same pattern as the Battle-tab StatLinks below.
        UpdateHUD()

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
        // Confirmed OG field order places these two here, between Magic Points and
        // Experience Points — shown to everyone rather than staff-only, matching that
        // confirmed order (TODOList.md Phase 3; "staff-only?" was an open question,
        // going with the OG-faithful behavior since this pass targets matching the OG
        // as closely as possible).
        stat("GM Level: [client ? client.adminLevel : 0]")
        stat("CPU: [world.cpu]")
        // Percent is progress within the CURRENT level's band (Exp resets to 0 on
        // every level-up, LevelCheck() above, so Exp/Nexp already IS that fraction —
        // no separate floor/threshold tracking needed), one decimal place, matching
        // the OG's own confirmed format ("10882/14011 (10.3%)"), not a whole-number
        // percent of the raw total.
        stat("Experience Points: [Exp]/[Nexp] ([FormatPercent(Exp, Nexp)]%)")
        stat("Gold: [Gold]")              // Currency
        // World clock (GetGameTimeString(), Code/Core/Main.dm) — the OG's Status panel
        // carried a Time line too. Now that a real day/night clock drives the world,
        // this is what tells a player how long until sunset.
        stat("Time: [GetGameTimeString()]")
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
        // Each uses its own StatLink subtype (ClickableStats.dm) so its column spacing
        // is a plain compile-time default, not a value passed around at runtime.
        if(!strStatPanel)  strStatPanel  = new /obj/StatLink/strength("Strength", src)
        if(!vitStatPanel)  vitStatPanel  = new /obj/StatLink/vitality("Vitality", src)
        if(!agiStatPanel)  agiStatPanel  = new /obj/StatLink/agility("Agility", src)
        if(!intStatPanel)  intStatPanel  = new /obj/StatLink/intelligence("Intelligence", src)
        if(!spiritStatPanel) spiritStatPanel = new /obj/StatLink/spirit("Spirit", src)

        // Refresh the +bonus shown in each label every tick, so equipping/unequipping
        // an amulet (Inventory.dm) is reflected immediately rather than only after the
        // next stat-point click (ClickableStats.dm's UpdateName()).
        strStatPanel.UpdateName()
        vitStatPanel.UpdateName()
        agiStatPanel.UpdateName()
        intStatPanel.UpdateName()
        spiritStatPanel.UpdateName()

        // Header panel for combat-related stats
        statpanel("Battle")

        // Display clickable stat links for allocation — order matches the confirmed OG
        // Battle tab layout (Str, Agi, Vit, Int, Spirit).
        stat(strStatPanel)
        stat(agiStatPanel)
        stat(vitStatPanel)
        stat(intStatPanel)
        stat(spiritStatPanel)

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
        // The OG's Inventory tab carried a "Quick Item:" line too — numpad * cycles it,
        // numpad - uses it (Code/Player/Commands/PlayerVerbs.dm).
        stat("Quick Item: [quickItem ? quickItem.name : "None"]")

        // Each item shows its own icon+name and routes clicks to its own Click()
        // (Code/Player/Inventory.dm) — same mechanism as the Battle tab's StatLinks above.
        for(var/obj/item/I in contents)
            stat(I)