datum/stats
    var
        Strength = 1
        Vitality = 1
        Agility = 1
        Intelligence = 1
        Luck = 1
        StatPoints = 0

    proc/Allocate(choice)
        if(StatPoints <= 0) return
        switch(choice)
            if("Strength")     Strength++
            if("Vitality")     Vitality++
            if("Agility")      Agility++
            if("Intelligence") Intelligence++
            if("Luck")         Luck++
        StatPoints--

    proc/RecalculateVitals(mob/M)
        M.MaxHP = 20 + (Vitality * 2)
        M.MaxMP = 10 + (Intelligence * 2)