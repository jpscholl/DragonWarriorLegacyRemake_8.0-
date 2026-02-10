// -----------------------------
// Clickable Stat Link
// -----------------------------
obj/StatLink
    var/attributeName        // Name of the stat, e.g., "Strength"
    var/mob/player/P         // Reference to owning player
    var/statMap              // Maps attributeNames to actual player vars

    // -----------------------------
    // Constructor
    // -----------------------------
    New(attributeName, mob/player/P)
        src.attributeName = attributeName
        src.P = P

        // Map attributeNames to player vars
        statMap = list(
            "Strength"     = "Strength",
            "Vitality"     = "Vitality",
            "Agility"      = "Agility",
            "Intelligence" = "Intelligence",
            "Luck"         = "Luck"
        )
        UpdateName()

    // -----------------------------
    // Update the display text
    // -----------------------------
    proc/UpdateName()
        if(!P) return
        if(!(attributeName in statMap)) return

        var/statVar = statMap[attributeName]
        name = "[attributeName]: [P.vars[statVar]]"

    // -----------------------------
    // Handle clicks
    // -----------------------------
    Click()
        if(!P || !ismob(P)) return

        if(P.StatPoints <= 0)
            P << output("No stat points left!", "Info")
            return

        if(!(attributeName in statMap)) return

        var/statVar = statMap[attributeName]
        P.vars[statVar]++   // Increment the actual stat
        P.StatPoints--       // Reduce available points

        UpdateName()