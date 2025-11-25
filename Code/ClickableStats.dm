obj/stat_link
    var/label        // e.g. "Strength"
    var/mob/player/P // reference to the owning player

    New(label, mob/player/P)
        src.label = label
        src.P = P
        name = "[label]: [P.vars[label]]"  // initial display

    // When clicked in the stat panel
    Click()
        if(!P || !ismob(P)) return
        if(P.StatPoints <= 0)
            P << "No stat points left!"
            return

        // Increment the correct stat
        switch(label)
            if("Strength")     P.Strength++
            if("Vitality")     P.Vitality++
            if("Agility")      P.Agility++
            if("Intelligence") P.Intelligence++
            if("Luck")         P.Luck++

        P.StatPoints--
        P.Stat()   // refresh the stat panel