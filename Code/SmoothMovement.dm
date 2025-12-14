mob
    icon_state = "world"
    var
        step_delay = 1.36
        tmp
            last_step = -1#INF
            next_step = -1#INF

    proc
        Step(dir, delay = step_delay)
            if(next_step - world.time >= world.tick_lag / 10)
                return 0

            glide_size = TILE_WIDTH / delay * world.tick_lag

            if(step(src, dir))
                last_step = world.time
                next_step = last_step + delay
                return 1
            return 0

client
    var
        move_dir = 0

    New()
        . = ..()
        if(.)
            MoveLoop()

    proc
        MoveLoop()
            set waitfor = 0
            while(src)
                if(move_dir)
                    Move(null, move_dir)
                sleep(world.tick_lag)

    Move(atom/loc, dir)
        walk(usr, 0)
        return mob.Step(dir)

    verb
        onMoveKey(dir as num, state as num)
            set instant = 1
            set hidden = 1
            if(state)
                move_dir = dir
            else if(move_dir == dir)
                move_dir = 0