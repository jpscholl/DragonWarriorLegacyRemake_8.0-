// -----------------------------
// Clickable Stat Link
// -----------------------------
obj/StatLink
    var/label        // Name of the stat, e.g., "Strength"
    var/mob/player/P // Reference to owning player
    var/statMap      // Maps labels to actual player vars

    // -----------------------------
    // Constructor
    // -----------------------------
    New(label, mob/player/P)
        src.label = label
        src.P = P

        // Map labels to player vars
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
        if(!(label in statMap)) return

        var/statVar = statMap[label]
        name = "[label]: [P.vars[statVar]]"

    // -----------------------------
    // Handle clicks
    // -----------------------------
    Click()
        if(!P || !ismob(P)) return

        if(P.StatPoints <= 0)
            P << output("No stat points left!", "Info")
            return

        if(!(label in statMap)) return

        var/statVar = statMap[label]
        P.vars[statVar]++   // Increment the actual stat
        P.StatPoints--       // Reduce available points

        UpdateName()