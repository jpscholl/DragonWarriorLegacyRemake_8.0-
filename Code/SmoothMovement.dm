// -----------------------------
// MOB MOVEMENT
// -----------------------------
mob
    icon_state = "world"  // default icon state
    var
        step_delay = 1.36  // default delay between steps
        tmp
            last_step = -1#INF  // timestamp of last step
            next_step = -1#INF  // timestamp allowed for next step

    // Step the mob in a direction
    proc
        Step(dir, delay = step_delay)
            // Throttle stepping: only allow step if enough time has passed
            if(next_step - world.time >= world.tick_lag / 10)
                return 0

            // Calculate glide size for smoother movement
            glide_size = TILE_WIDTH / delay * world.tick_lag

            // Attempt to step in the given direction
            if(step(src, dir))
                last_step = world.time  // record last step time
                next_step = last_step + delay  // schedule next allowed step
                return 1
            return 0  // step failed

// -----------------------------
// CLIENT MOVEMENT
// -----------------------------
client
    var
        move_dir = 0  // current movement direction from input

    New()
        . = ..()  // call base constructor
        if(.) MoveLoop()  // start movement loop

    // Continuously move mob while a direction is pressed
    proc
        MoveLoop()
            set waitfor = 0  // reset wait state
            while(src)  // keep looping as long as client exists
                if(move_dir)
                    Move(null, move_dir)  // move mob in current direction
                sleep(world.tick_lag)  // wait until next tick

    // Move the mob in a direction
    Move(atom/loc, dir)
        walk(usr, 0)  // cancel current walk (stops animation)
        return mob.Step(dir)  // call the mob's Step proc

    // Key input for movement
    verb
        onMoveKey(dir as num, state as num)
            set instant = 1  // instant execution
            set hidden = 1   // hide the verb from user list

            if(state)  // key pressed
                move_dir = dir
            else if(move_dir == dir)  // key released
                move_dir = 0  // stop moving in that direction
