// -----------------------------
// MOB MOVEMENT
// -----------------------------
mob
    icon_state = "world"  // default icon state
    var
        step_delay = 1.36  // default delay between steps
        turnWalkMode = FALSE  // toggled by TurnWalk() (Code/Player/Commands/PlayerVerbs.dm)
        tmp
            last_step = -1#INF  // timestamp of last step
            next_step = -1#INF  // timestamp allowed for next step

    // Step the mob in a direction
    proc
        Step(dir, delay = step_delay)
            // Root the mob while canAct is FALSE — mid-attack/cast, dead, or falling
            // through turf/sky. Reached by both players (client/Move() below) and
            // enemies (EnemyNPCs.dm calls this same proc directly), so an attacking
            // enemy gets rooted mid-swing too. attackRecoveryOnly is the one
            // exception: a swing's windup already landed and only the "can't attack
            // again yet" half of canAct's lock is still active.
            if(!canAct && !attackRecoveryOnly)
                return 0

            // Throttle stepping: only allow step if enough time has passed
            if(next_step - world.time >= world.tick_lag / 10)
                return 0

            // Calculate glide size for smoother movement
            glide_size = TILE_WIDTH / delay * world.tick_lag

            // Attempt to step in the given direction
            if(step(src, dir))
                last_step = world.time  // record last step time
                next_step = last_step + delay  // schedule next allowed step
                WakeUp()  // moving at all cancels sleeping (Code/World/Turfs.dm), no-op otherwise
                return 1
            return 0  // step failed

// -----------------------------
// CLIENT MOVEMENT
// -----------------------------
client
    var
        move_dir = 0  // current movement direction from input
        pendingDir = 0  // direction currently mid turn-pause (see onMoveKey), 0 = none
        pendingSession = 0  // invalidates a stale spawn() timer for pendingDir specifically

    // MoveLoop() is started from client/New() in Code/Core/Main.dm — DM doesn't merge
    // duplicate proc definitions across files, so a second New() override here would
    // silently replace (or be replaced by) that one instead of both running.

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
        walk(mob, 0)  // cancel current walk (stops animation) — usr isn't reliable here
                       // since MoveLoop() calls this from a background loop, not a verb trigger
        return mob.Step(dir)  // call the mob's Step proc

    // Key input for movement
    verb
        onMoveKey(dir as num, state as num)
            set instant = 1  // instant execution
            set hidden = 1   // hide the verb from user list

            if(state)  // key pressed
                if(mob && mob.turnWalkMode && dir != mob.dir)
                    // Turn-walk toggle: face the new direction, then wait a brief
                    // deliberate moment before walking — without a pause the turn and
                    // first step happen too close together to perceive. Tracked
                    // per-direction (pendingDir/pendingSession), not a single global
                    // counter — a global counter would let releasing ANY other key
                    // cancel this pending turn too, leaving the newly-pressed
                    // direction stuck doing nothing. Only cancels the glide if a step
                    // is actually still in flight (mob.next_step hasn't passed).
                    if(mob.next_step > world.time)
                        walk(mob, 0)
                    mob.dir = dir
                    move_dir = 0  // stop movement already in progress, or you'd keep
                                  // sliding the OLD direction while facing the NEW one
                    pendingDir = dir
                    pendingSession++
                    var/my_session = pendingSession
                    var/want_dir = dir
                    spawn(2)
                        if(pendingDir == want_dir && pendingSession == my_session)
                            move_dir = want_dir
                            pendingDir = 0
                else
                    move_dir = dir
                    if(pendingDir == dir)
                        pendingDir = 0  // already moving for real now, nothing left pending
            else  // key released
                if(pendingDir == dir)
                    pendingDir = 0  // cancel the pending turn, but only for THIS direction
                    pendingSession++
                if(move_dir == dir)
                    move_dir = 0  // stop moving in that direction

        // Numpad 9/7/3/1/0 skill slots (skillSlots, PlayerTemplate.dm) — repurposes
        // what used to be diagonal-movement macros (Interface.dmf), since this game
        // has no diagonal movement at all.
        UseSkillKey(slotNum as num)
            set instant = 1
            set hidden = 1
            // UseSkillSlot() only exists on /mob/player, but client.mob is statically
            // typed as the base /mob — needs a typed local to resolve the call.
            var/mob/player/P = mob
            if(P) P.UseSkillSlot(slotNum)
