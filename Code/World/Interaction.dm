// Overridden by anything interactable (obj/turf/mob); returns TRUE once handled.
// Caller: Interact() in Code/Player/Commands/PlayerVerbs.dm.
atom/proc/OnInteract(mob/user)
    return FALSE
