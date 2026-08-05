// -----------------------------
// Items & Inventory
// -----------------------------
// Strength-scaled capacity — confirmed shape via the OG help file's own flavor text
// ("Strength: increases physical damage AND the number of items you can carry",
// TODOList.md 2026-08-04 decision). Coefficients are PLACEHOLDER, chosen so a fresh
// level-1 character (Strength = 1, the actual creation default — PlayerTemplate.dm,
// before any stat points are spent) lands exactly on the one confirmed real data
// point: capacity 9. STR_PER_CAPACITY reuses the same /5 divisor already established
// by the stat-point cost formula (obj/StatLink/GetCost(), ClickableStats.dm) for a bit
// of internal consistency, not because it's independently confirmed.
#define BASE_INVENTORY_CAPACITY 9
#define STR_PER_CAPACITY 5

// Base type for anything a player can carry. Items just live in mob.contents (BYOND's
// built-in containment) — no separate inventory list to keep in sync.
obj/item
    var/description = ""

    // Base does nothing; concrete item types override. Called from Click() below, which
    // is how the Inventory tab (Code/Player/StatPanels.dm) wires up "click to use" —
    // BYOND routes a stat()-panel click on an atom straight to that atom's Click().
    proc/UseItem(mob/user)
        return

    Click()
        if(ismob(loc))
            var/mob/M = loc
            UseItem(M)

    // Standing on a loose item and pressing Interact picks it up — see the fallback
    // check in Interact() (Code/Player/Commands/PlayerVerbs.dm). Always returns TRUE
    // once an attempt is made (even if the inventory's full — PickUpItem() already
    // shows that message, no need to fall through and try interacting with the turf too).
    OnInteract(mob/user)
        user.PickUpItem(src)
        return TRUE

    // "set src in usr" scopes this to only show up (in its own "Action" tab, per the
    // original game) for items you're actually carrying — this is what replaces the old
    // menu-based DropItem() verb below (now hidden).
    verb/Drop()
        set src in usr
        set name = "Drop"
        set category = "Action"

        if(!ismob(loc)) return
        var/mob/M = loc
        loc = M.loc   // falls on the turf you're standing on
        M << output("You drop [src.name].", "Info")

    // Hands the item directly to a nearby player instead of dropping it on the ground.
    // "in view(5, usr)" restricts the target picker to players within 5 tiles, matching
    // "give directly to a player in range" from the original design notes.
    verb/Give(mob/player/target in view(5, usr))
        set src in usr
        set name = "Give"
        set category = "Action"

        if(!ismob(loc)) return
        var/mob/M = loc
        if(target == M)
            M << output("You can't give an item to yourself.", "Info")
            return

        if(!target.PickUpItem(src))
            M << output("[target.name]'s inventory is full.", "Info")
            return

        M << output("You give [src.name] to [target.name].", "Info")
        target << output("[M.name] gives you [src.name].", "Info")

// A named key. Grants access to any lockable object whose own name matches keyName —
// see obj/door's OnInteract() override in Code/World/Obj.dm.
obj/item/key
    name = "Key"
    icon = 'key.dmi'
    icon_state = "key"
    var/keyName

    // Double-clicking a key while carrying it and facing a matching-named door toggles
    // that door's lock. Requires a name match, same as OnInteract()'s access check in
    // Code/World/Obj.dm — a key can't lock/unlock a door it doesn't belong to.
    DblClick()
        if(!ismob(loc)) return
        var/mob/user = loc

        var/turf/facingTile = get_step(user, user.dir)
        if(!facingTile)
            return

        for(var/obj/door/D in facingTile.contents)
            if(D.name != keyName)
                user << output("This key doesn't match [D.name].", "Info")
                return
            D.is_locked = !D.is_locked
            user << output("[D.name] is now [D.is_locked ? "locked" : "unlocked"].", "Info")
            return

        user << output("You're not facing a door.", "Info")

// -----------------------------
// Mob-side inventory helpers
// -----------------------------
mob/proc/GetInventoryCapacity()
    return BASE_INVENTORY_CAPACITY + round(Strength / STR_PER_CAPACITY)  // round() with
                                                                            // one arg
                                                                            // floors in DM

mob/proc/GetInventoryCount()
    var/count = 0
    for(var/obj/item/I in contents)
        count++
    return count

// Moves an item into this mob's inventory if there's room. Returns TRUE/FALSE.
mob/proc/PickUpItem(obj/item/I)
    if(GetInventoryCount() >= GetInventoryCapacity())
        src << output("Your inventory is full.", "Info")
        return FALSE

    I.loc = src
    return TRUE

// TRUE if this mob is carrying a key whose keyName matches lockName.
mob/proc/HasMatchingKey(lockName)
    for(var/obj/item/key/K in contents)
        if(K.keyName == lockName)
            return TRUE
    return FALSE

// -----------------------------
// Drop Item (legacy menu-based fallback — superseded by obj/item/verb/Drop() above,
// which right-click gives you directly on the item itself. Kept, just hidden.)
// -----------------------------
mob/verb/DropItem()
    set hidden = 1
    set desc = "Drop an item from your inventory onto the ground"

    var/list/items = list()
    for(var/obj/item/I in contents)
        items[I.name] = I

    if(!items.len)
        src << output("You have nothing to drop.", "Info")
        return

    var/choice = input(src, "Drop which item?", "Drop Item") in items
    var/obj/item/toDrop = items[choice]

    toDrop.loc = loc   // falls on the turf you're standing on
    src << output("You drop [toDrop.name].", "Info")
