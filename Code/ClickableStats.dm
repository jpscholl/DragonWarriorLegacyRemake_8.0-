obj/stat_link
    var/label        // e.g. "Strength"
    var/mob/player/P // reference to the owning player
    New(label, mob/player/P)
        src.label = label
        src.P = P
        update_name()   // set initial display
    proc/update_name()
        if(!P) return
        switch(label)
            if("Strength")     name = "Strength: [P.Strength]"
            if("Vitality")     name = "Vitality: [P.Vitality]"
            if("Agility")      name = "Agility: [P.Agility]"
            if("Intelligence") name = "Intelligence: [P.Intelligence]"
            if("Luck")         name = "Luck: [P.Luck]"

    Click()
        if(!P || !ismob(P)) return
        if(P.StatPoints <= 0)
            P << "No stat points left!"
            return

        switch(label)
            if("Strength")     P.Strength++
            if("Vitality")     P.Vitality++
            if("Agility")      P.Agility++
            if("Intelligence") P.Intelligence++
            if("Luck")         P.Luck++

        P.StatPoints--
        update_name()   // refresh this object’s display