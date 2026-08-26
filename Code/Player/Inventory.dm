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
// Consumables
// -----------------------------
// Names and behavior are OG-confirmed (they appear verbatim in the extracted string
// table): "medical herb", "herbal tea", "leaf of the world tree", "wing of wyvern".
// Amounts are PLACEHOLDER — the OG stored a heal_amount per item but that value isn't
// recovered yet.
//
// ART PLACEHOLDER: World Icons/Items/ currently contains only key.dmi, so every
// consumable below borrows the key sprite. They are functionally complete but visually
// indistinguishable from each other and from an actual key — this needs real item art
// before it's playable, and is the single most visible unfinished thing about them.
obj/item/consumable
    icon = 'key.dmi'
    icon_state = "key"

    // Subtypes return TRUE if the item was actually consumed. Returning FALSE (e.g.
    // already at full HP) leaves the item in the inventory rather than wasting it —
    // matching the OG's own "You are not hurt!" refusal.
    proc/OnConsume(mob/user)
        return TRUE

    UseItem(mob/user)
        if(!OnConsume(user)) return
        del src

obj/item/consumable/herb
    name = "medical herb"
    description = "Restores a small amount of HP."
    var/healAmount = 30  // PLACEHOLDER

    OnConsume(mob/user)
        if(user.HP >= user.MaxHP)
            user << output("You are not hurt!", "Info")  // OG wording, verbatim
            return FALSE
        user.ApplyHeal(user, healAmount)
        return TRUE

obj/item/consumable/tea
    name = "herbal tea"
    description = "Restores a small amount of MP."
    var/restoreAmount = 20  // PLACEHOLDER

    OnConsume(mob/user)
        if(!user.hasMana || user.MaxMP <= 0)
            user << output("You have no magic to restore.", "Info")
            return FALSE
        if(user.MP >= user.MaxMP)
            user << output("You are at full MP!", "Info")  // OG wording, verbatim
            return FALSE
        user.MP = min(user.MaxMP, user.MP + restoreAmount)
        user << output("You restore [restoreAmount] MP! (MP: [user.MP]/[user.MaxMP])", "Info")
        return TRUE

// Revives a fallen ally. OG usage note, verbatim: "Face another player to use this item,
// or give it to them while they are dead." Only the facing case is implemented here —
// the give-to-a-dead-player case works already, since a dead player can just use it
// themselves once it's in their inventory.
obj/item/consumable/leaf
    name = "leaf of the world tree"
    description = "Revives a fallen ally."

    OnConsume(mob/user)
        // Self-use while dead is the "give it to them while they are dead" half.
        if(user.isDead)
            user.RespawnPlayer()
            return TRUE

        var/turf/facing = get_step(user, user.dir)
        if(facing)
            for(var/mob/player/P in facing.contents)
                if(!P.isDead) continue
                P.RespawnPlayer()
                user << output("You revive [P.name] with [src.name].", "Info")
                return TRUE

        user << output("Face another player to use this item, or give it to them while they are dead.", "Info")
        return FALSE

// Teleports the user back to the world spawn point — the item equivalent of the Return
// spell (SkillCatalog.dm), and it reuses the same GetPlayerSpawnTurf() lookup.
obj/item/consumable/wyvernwing
    name = "wing of wyvern"
    description = "Returns you to town."

    OnConsume(mob/user)
        if(user.isDead)
            user << output("But the strange force contains the wing's powers!", "Info")  // OG wording
            return FALSE
        user.loc = GetPlayerSpawnTurf()
        user << output("You return to town!", "Info")
        return TRUE

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
