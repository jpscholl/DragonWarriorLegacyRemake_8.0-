// NGL...Idk wtf to make of most of this code. I tried to learn from Ter13's snippet post, but I still don't get it
client
    tick_lag = 0.47 // how often the client updates (smaller = faster ticks)
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
                // Just move in the held direction
                step(src.mob, move_dir)
                sleep(src.mob.step_delay)   // wait before next step
            else
                sleep(world.tick_lag * world.fps)   // idle tick

    verb/onMoveKey(dir as num, state as num)
        set instant = 1
        set hidden = 1
        if(state)
            move_dir = dir   // key pressed → set direction
        else if(move_dir == dir)
            move_dir = 0     // key released → stop moving

mob
    icon_state = "world"
    var/step_delay = 3   // ticks between steps
// Movement is handled entirely by the client’s MoveLoop.
