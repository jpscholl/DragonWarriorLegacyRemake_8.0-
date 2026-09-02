// -----------------------------
// Clickable Stat Link
// -----------------------------
obj/StatLink
    // attributeName doubles as the actual mob var name (e.g. "Strength") — every
    // construction site below (StatPanels.dm) passes one of the five real stat var
    // names directly, so there's no separate display-name-to-var-name mapping needed.
    var/attributeName
    var/mob/player/P         // Reference to owning player
    // Padding between the "+bonus" and "points to increase" text. A plain compile-time
    // default here, overridden per stat by the subtypes below — no runtime plumbing,
    // just edit the literal string for whichever row needs more or less room to line up.
    var/spacer = "    "

    // -----------------------------
    // Constructor
    // -----------------------------
    New(attributeName, mob/player/P)
        src.attributeName = attributeName
        src.P = P
        UpdateName()

    // -----------------------------
    // Update the display text
    // -----------------------------
    proc/UpdateName()
        if(!P) return

        var/currentStat = P.vars[attributeName]
        // Equipment bonus (amulets, Code/Player/Inventory.dm) — "equip" + attributeName
        // matches its mob var exactly (equipStrength, equipAgility, ...), same naming
        // trick already used for P.vars[attributeName] above. Matches the confirmed OG
        // Battle-tab format ("Strength: 14+0").
        var/equipBonus = P.vars["equip[attributeName]"]
        name = "[attributeName]: [currentStat] +[equipBonus][spacer][GetCost(currentStat)] points to increase"

    // Confirmed OG cost formula (ClassReference.md): 2 base, +1 per 5 points already
    // invested. round(x) with one argument floors in DM.
    proc/GetCost(currentStat)
        return 2 + round(currentStat / 5)

    // -----------------------------
    // Handle clicks
    // -----------------------------
    Click()
        if(!P || !ismob(P)) return

        var/currentStat = P.vars[attributeName]
        var/cost = GetCost(currentStat)

        // Per-class ceiling (PlayerTemplate.dm's GetClassStatCaps()) — this level-up
        // spend path had no cap check at all before, unlike creation-time
        // StatAllocation() (LoginMenu.dm), so a stat could be pushed arbitrarily high
        // past its class's intended max.
        var/list/caps = GetClassStatCaps(P.class)
        if(caps && currentStat >= caps[attributeName])
            P.ShowInfo("[attributeName] is already at its class cap ([caps[attributeName]])!")
            return

        if(P.StatPoints < cost)
            P.ShowInfo("Not enough stat points! (need [cost])")
            return

        P.vars[attributeName]++   // Increment the actual stat
        P.StatPoints -= cost       // Reduce available points by the real cost

        P.RecalculateVitals()  // Vitality/Intelligence changes affect MaxHP/MaxMP —
                                // see Code/Player/StatsDatum.dm
        P.CheckSkillUnlocks()  // a stat-gated skill can unlock without a level-up too
                                // (Code/Player/SkillUnlocks.dm)
        UpdateName()

// -----------------------------
// Per-stat spacing
// -----------------------------
// One subtype per Battle-tab row so each can carry its own literal spacer — edit these
// directly to nudge alignment, no formula to fight with.
obj/StatLink/strength
    spacer = "               "

obj/StatLink/agility
    spacer = "                    "

obj/StatLink/vitality
    spacer = "                   "

obj/StatLink/intelligence
    spacer = "           "

obj/StatLink/spirit
    spacer = "                       "