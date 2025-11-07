client
	tick_lag = 0.16
	var
		next_move = 0
		move_delay = 1
	proc Move()
		if(src.next_move < world.time)
			src.next_move = world.time+src.move_delay
			return ..()

// Make objects move 8 pixels per tick when walking

mob
	icon = 'dw3hero.dmi'
	icon_state = "world"
	glide_size = 3
	var
		step_delay = 1
		tmp
			last_step = -1#INF
			next_step = -1#INF


	proc
		Step(dir, delay = step_delay)
			if(world.time < next_step)
				return 0

			glide_size = round(TILE_WIDTH / delay * world.tick_lag)

			if(step(src, dir))
				last_step = world.time
				next_step = last_step + delay
				return 1

			return 0

client
	var
		move_dir = 0

	proc New()
		. = ..()
		if(.)
			MoveLoop()

	proc
		MoveLoop()
			set waitfor = 0
			while(src)
				if(move_dir)
					Move(null, move_dir)
				sleep(round(world.tick_lag * world.fps))  // sleep for ~10 frames


	proc Move(atom/loc,dir)
		//world.log << world.tick_lag
		walk(usr,0)
		return mob.Step(dir)

	verb
		onMoveKey(dir as num,state as num)
			set instant = 1
			set hidden = 1
			if(state)
				move_dir = dir
			else if(move_dir==dir)
				move_dir = 0