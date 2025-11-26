// NGL...Idk wtf to make of most of this code. I tried to learn from Ter13's snippet post, but I still don't get it
// AI generated comments
client
    tick_lag = 0.16   // how often the client updates (smaller = faster ticks)
    var
        next_move = 0     // when the client can move again
        move_delay = 1    // delay between moves
    // Override default movement to add a delay
    Move()
        if(src.next_move < world.time)
            src.next_move = world.time + src.move_delay
            return ..()   // call default Move() if allowed

mob
    icon_state = "world"
    // glide_size = round(TILE_WIDTH / delay * world.tick_lag)
    var
        step_delay = 1    // how many ticks between steps
        tmp
            last_step = -1#INF   // last time mob stepped
            next_step = -1#INF   // next time mob can step
    // Custom step function with delay + glide
    proc/Step(dir, delay = step_delay)
        if(world.time < next_step)
            return 0   // too soon to move again
        // glide_size controls smoothness of movement animation
        glide_size = round(TILE_WIDTH / delay * world.tick_lag)

        if(step(src, dir))   // attempt to move in direction
            last_step = world.time
            next_step = last_step + delay
            return 1   // success
        return 0   // failed to move

client
    var
        move_dir = 0   // current direction key being held
    New()
        . = ..()
        if(.)
            MoveLoop()   // start continuous movement loop
    // Background loop that keeps moving while a key is held
    proc/MoveLoop()
        set waitfor = 0
        while(src)
            if(move_dir)
                Move(null, move_dir)   // move in held direction
                sleep(round(world.tick_lag * world.fps))   // wait one tick

    verb/onMoveKey(dir as num, state as num)
        set instant = 1
        set hidden = 1
        if(state)
            move_dir = dir   // key pressed → set direction
        else if(move_dir == dir)
            move_dir = 0     // key released → stop moving
