mob/proc
	TakeDamage(damage)
		flick("hit", src)
		view() << sound('hit.wav', volume = 10)
		world << "[src] takes [usr.Strength] damage! (HP: [HP])"
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
		M << "[src] has been defeated!"
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
            src << "You are now Level [src.Level]"
            src << sound('levelup.wav', volume = world_volume)