// -----------------------------
// Clickable Stat Link
// -----------------------------
obj/StatLink
    // attributeName doubles as the actual mob var name (e.g. "Strength") — every
    // construction site below (StatPanels.dm) passes one of the five real stat var
    // names directly, so there's no separate display-name-to-var-name mapping needed.
    var/attributeName
    var/mob/player/P         // Reference to owning player

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
        // "+0" is a placeholder for a future equipment/buff stat-bonus system (no such
        // system exists yet — see TODOList.md Phase 5) — matches the confirmed OG
        // Battle-tab format ("Strength: 14+0") even though the bonus is always 0 for now.
        name = "[attributeName]: [currentStat]+0    [GetCost(currentStat)] points to increase"

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

        if(P.StatPoints < cost)
            P << output("Not enough stat points! (need [cost])", "Info")
            return

        P.vars[attributeName]++   // Increment the actual stat
        P.StatPoints -= cost       // Reduce available points by the real cost

        P.RecalculateVitals()  // Vitality/Intelligence changes affect MaxHP/MaxMP —
                                // see Code/Player/StatsDatum.dm
        UpdateName()