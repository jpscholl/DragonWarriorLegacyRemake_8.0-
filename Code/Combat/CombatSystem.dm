mob/proc
    TakeDamage(damage, mob/attacker)
        if(HP <= 0) return

        flick("hit", src)
        view() << sound("hit.wav", channel = 1, volume = baseVolume)

        HP -= damage
        view(src) << output("[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

    CleanUpDead()
        spawn(100)//async call that doesn't block future use of attacking
        del src

    Die(mob/M)
        view(src) << output("[src] has been defeated!", "Info")
        M.Exp += 10
        M.LevelCheck()
        src.density = 0
        src.icon_state = "sleep"

    LevelCheck()
        if(src.Exp >= src.Nexp)
            src.Exp = 0
            src.Nexp += 10
            src.Level += 1
            src.StatPoints += 5
            src << output("You are now Level [src.Level]", "Info")
            src << sound('levelup.wav', channel = 2, volume = baseVolume)