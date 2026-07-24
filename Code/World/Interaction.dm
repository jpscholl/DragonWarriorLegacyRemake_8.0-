// -----------------------------
// Interaction Hook
// -----------------------------
// Anything (obj, turf, and later mob) that wants to respond to a player
// pressing the interact key overrides this and returns TRUE after handling it.
// The base does nothing and returns FALSE, meaning "not interactable" — no
// separate marker var to keep in sync, the override itself is the marker.
// See Code/Player/Commands/PlayerVerbs.dm's Interact() verb for the caller.
atom/proc/OnInteract(mob/user)
    return FALSE
