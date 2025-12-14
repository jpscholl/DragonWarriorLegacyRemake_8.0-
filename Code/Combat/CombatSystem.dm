mob/proc
	TakeDamage(damage)
		flick("hit", src)
		view() << sound("hit.wav", channel = 1, volume = world_volume)
		view(src) << output("[src] takes [usr.Strength] damage! (HP: [HP])", "Info")
		HP -= usr.Strength
		if (HP <= 0)
			Die(usr)
			CleanUpDead()

mob/proc
	CleanUpDead()
		spawn(100)	//async call that doesn't block future use of attacking
		del src

mob/proc
	Die(mob/M)
		view(src) << output("[src] has been defeated!", "Info")
		M.Exp += 10
		M.LevelCheck()
		src.density = 0
		src.icon_state = "sleep"

mob/proc
    LevelCheck()
        if(src.Exp >= src.Nexp)
            src.Exp = 0
            src.Nexp += 10
            src.Level += 1
            src.StatPoints += 5
            src << output("You are now Level [src.Level]", "Info")
            src << sound('levelup.wav', channel = 2, volume = world_volume)