// -----------------------------
// Clickable Stats Links
// -----------------------------
// This object represents a clickable stat display for a player.
// Clicking it allocates a point to the corresponding stat and updates the display.

// A stat link object (Strength, Vitality, etc.)
obj/stat_link
    var/label        // The name of the stat this link represents, e.g., "Strength"
    var/mob/player/P // Reference to the owning player

    // -----------------------------
    // Constructor
    // -----------------------------
    New(label, mob/player/P)
        // Initialize the label and player reference
        src.label = label
        src.P = P

        // Set the initial displayed text
        update_name()

    // ---------------------------------------------------
    // Updates the display name to show the current value
    // ---------------------------------------------------
    proc/update_name()
        if(!P) return  // safety check if the player reference is missing

        // Show the current stat value next to the label
        switch(label)
            if("Strength")     name = "Strength: [P.Strength]"
            if("Vitality")     name = "Vitality: [P.Vitality]"
            if("Agility")      name = "Agility: [P.Agility]"
            if("Intelligence") name = "Intelligence: [P.Intelligence]"
            if("Luck")         name = "Luck: [P.Luck]"

    // -----------------------------
    // Handle clicks on this stat link
    // -----------------------------
    Click()
        if(!P || !ismob(P)) return  // safety check

        // Check if player has stat points available
        if(P.StatPoints <= 0)
            P << "No stat points left!"
            return

        // Allocate a point to the chosen stat
        switch(label)
            if("Strength")     P.Strength++
            if("Vitality")     P.Vitality++
            if("Agility")      P.Agility++
            if("Intelligence") P.Intelligence++
            if("Luck")         P.Luck++

        // Reduce the remaining stat points
        P.StatPoints--

        // Refresh the display to show updated value
        update_name()