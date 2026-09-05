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

            // Throttle stepping: only allow step if enough time has passed. The >= tick_lag/10
            // slack (not a plain world.time < next_step check) matters because world.time is a
            // float — comparing it for exact equality is fragile, and at "clean" framerates like
            // 30/60fps that imprecision compounds over a long-running world into missed/late
            // frames. This is the documented fix (Ter13, BYOND forum post 2481387, endorsed by
            // Lummox JR) for exactly that class of jitter.
            if(next_step - world.time >= world.tick_lag / 10)
                return 0

            // Marries glide_size to the step delay so the visual glide finishes exactly when
            // the next step is allowed, instead of the two drifting out of sync.
            glide_size = TILE_WIDTH / delay * world.tick_lag

            // Attempt to step in the given direction
            if(step(src, dir))
                last_step = world.time  // record last step time
                next_step = last_step + delay  // schedule next allowed step
                WakeUp()  // moving at all cancels sleeping (Code/World/Turfs.dm), no-op otherwise
                return 1
            return 0  // step failed

// -----------------------------
// CAMERA
// -----------------------------
// Replaces EDGE_PERSPECTIVE's screen-snap-at-the-edge behavior with a camera that
// glides continuously in lockstep with the player, while staying boxed inside the
// map the same way EDGE_PERSPECTIVE did — the box-in feel is confirmed OG behavior
// (Markdowns/OGStringTable.txt has the literal EDGE_PERSPECTIVE string), but the
// player's own glide combined with the screen only moving in edge-triggered snaps
// made the environment look jittery relative to a player who was otherwise moving
// smoothly. This object is the client's eye instead of the mob itself, so the view
// follows IT, not the raw mob position.
obj/CameraEye
    icon = null
    density = FALSE
    opacity = FALSE
    mouse_opacity = 0
    invisibility = 101

    proc
        // Keeps the view from ever showing past the map edge, same box-in point
        // EDGE_PERSPECTIVE enforced.
        ClampAxis(value, mapMax)
            return min(max(value, CAMERA_VIEW_HALF + 1), mapMax - CAMERA_VIEW_HALF)

        // Jump straight to target's (clamped) position with no glide — for spawn-in
        // and stair teleports, where a smooth pan would be wrong.
        SnapTo(mob/target)
            if(!target) return
            glide_size = 0
            loc = locate(ClampAxis(target.x, world.maxx), ClampAxis(target.y, world.maxy), target.z)

        // Follow target's latest step smoothly, staying boxed inside the map. Sets
        // loc directly rather than step()/step_to() — this is a pure camera anchor,
        // not a physical object, and its clamped tile is often NOT the tile the
        // player is standing on (that's the whole point near an edge), so it must
        // never be collision-checked against whatever's on that tile.
        TrackTarget(mob/target)
            if(!target) return
            if(z != target.z)
                SnapTo(target)
                return
            var/desiredX = ClampAxis(target.x, world.maxx)
            var/desiredY = ClampAxis(target.y, world.maxy)
            if(desiredX == x && desiredY == y)
                return
            glide_size = target.glide_size
            loc = locate(desiredX, desiredY, z)

// -----------------------------
// CLIENT MOVEMENT
// -----------------------------
client
    var
        move_dir = 0  // current movement direction from input
        pendingDir = 0  // direction currently mid turn-pause (see onMoveKey), 0 = none
        pendingSession = 0  // invalidates a stale spawn() timer for pendingDir specifically
        obj/CameraEye/camera  // set by AttachCamera() once gameplay actually starts (LoginMenu.dm)

    proc
        // Called once from FinalizePlayer() (LoginMenu.dm) when a character enters
        // the world for real — not during character-creation previews, which manage
        // client.eye themselves.
        AttachCamera(mob/target)
            if(!camera) camera = new()
            camera.SnapTo(target)
            eye = camera

    Del()
        if(camera)
            del camera
        ..()

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
        var/moved = mob.Step(dir)  // call the mob's Step proc
        if(moved && camera)
            camera.TrackTarget(mob)
        return moved

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
