// -----------------------------
// General Player Verbs
// -----------------------------
mob/verb/Interact()
    set hidden = 1   // don’t clutter verb panel

    // Dead players use Interact() to respawn instead of the normal interact flow —
    // see Die()'s player branch in Code/Combat/CombatSystem.dm for where isDead/
    // deathTime get set and RESPAWN_DELAY is defined.
    if(isDead)
        if(world.time - deathTime < RESPAWN_DELAY)
            var/secondsLeft = round((RESPAWN_DELAY - (world.time - deathTime)) / 10)
            src << output("You can't respawn yet — [secondsLeft] more second[secondsLeft == 1 ? "" : "s"].", "Info")
            return

        isDead = FALSE
        HP = MaxHP
        MP = MaxMP
        density = 1
        icon_state = "world"
        isDefending = FALSE  // clear a stale defend stance from before death — icon_state
                               // above already resets visually, this resets the actual
                               // damage-reduction flag (Defend, SkillDatum.dm) to match
        ClearStatusEffects()  // don't respawn still poisoned (StatusEffects.dm)
        loc = PLAYER_SPAWN
        canAct = TRUE  // re-enable movement — see Die()'s player branch in
                        // Code/Combat/CombatSystem.dm for where this gets locked
        src << output("You respawn.", "Info")
        return

    // Get the turf one step in the direction the mob is facing
    var/turf/target = get_step(src, src.dir)
    if(!target) return

    // If the first turf is a counter, skip ahead one more space
    if(istype(target, /turf/furniture/counter))
        target = get_step(target, src.dir)
        if(!target) return

    // Objs on the tile get first chance to handle it, then the turf itself.
    // Whatever's actually interactable overrides OnInteract() (see
    // Code/World/Interaction.dm) and returns TRUE; nothing else responds.
    for(var/obj/O in target.contents)
        if(O.OnInteract(src))
            return

    if(target.OnInteract(src))
        return

    // Nothing in front responded — check for loose items on our own tile (e.g.
    // something just dropped, see DropItem() in Code/Player/Inventory.dm)
    if(isturf(loc))
        for(var/obj/item/I in loc.contents)
            if(I.OnInteract(src))
                return

// -----------------------------
// Look — like Who() (Code/Player/Commands/SocialVerbs.dm) but restricted to players
// actually in view, not everyone online. Same hardcoded Class/Level/Party stub as Who()
// until the real data (TODOList.md Phase 2/4) exists.
// -----------------------------
mob/verb/Look()
    set category = "Action"
    set desc = "Shows players in view and their basic info"

    src << output("<b>Players in view:</b>", "Info")

    var/found = FALSE
    for(var/mob/M in view(src))
        if(M == src) continue
        if(!M.client) continue
        found = TRUE
        src << output("<font color='blue'> \icon[M] [M.name]([M.key]) <b>Class:</b> Hero <b>Level:</b> 1 <b>Party:</b> None</font>", "Info")

    if(!found)
        src << output("No other players in view.", "Info")

// -----------------------------
// Turn Walk — toggle checked in mob/proc/Step() (Code/Core/SmoothMovement.dm). While on,
// pressing a direction you're not already facing just turns you first; only a
// direction you're already facing actually steps.
// -----------------------------
mob/verb/TurnWalk()
    set category = "Action"
    set desc = "Toggle: face a new direction before walking that way, instead of moving instantly"

    turnWalkMode = !turnWalkMode
    src << output("Turn-then-walk is now [turnWalkMode ? "ON" : "OFF"].", "Info")
