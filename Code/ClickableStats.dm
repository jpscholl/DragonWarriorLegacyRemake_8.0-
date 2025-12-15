// -----------------------------
// Clickable Stat Link
// -----------------------------
obj/stat_link
    var/label        // Name of the stat, e.g., "Strength"
    var/mob/player/P // Reference to owning player
    var/stat_map     // Maps labels to actual player vars

    // -----------------------------
    // Constructor
    // -----------------------------
    New(label, mob/player/P)
        src.label = label
        src.P = P

        // Map labels to player vars
        stat_map = list(
            "Strength"     = "Strength",
            "Vitality"     = "Vitality",
            "Agility"      = "Agility",
            "Intelligence" = "Intelligence",
            "Luck"         = "Luck"
        )

        update_name()

    // -----------------------------
    // Update the display text
    // -----------------------------
    proc/update_name()
        if(!P) return
        if(!(label in stat_map)) return

        var/stat_var = stat_map[label]
        name = "[label]: [P.vars[stat_var]]"

    // -----------------------------
    // Handle clicks
    // -----------------------------
    Click()
        if(!P || !ismob(P)) return

        if(P.StatPoints <= 0)
            P << output("No stat points left!", "Info")
            return

        if(!(label in stat_map)) return

        var/stat_var = stat_map[label]
        P.vars[stat_var]++   // Increment the actual stat
        P.StatPoints--       // Reduce available points

        update_name()
