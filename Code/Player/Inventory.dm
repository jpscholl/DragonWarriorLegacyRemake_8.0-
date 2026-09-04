// -----------------------------
// Items & Inventory
// -----------------------------
// Strength-scaled capacity, tuned so a fresh level-1 character lands on the one
// confirmed real data point: capacity 9. See Markdowns/CodeNotes.md for the full
// derivation.
#define BASE_INVENTORY_CAPACITY 9
#define STR_PER_CAPACITY 5

// Base type for anything a player can carry. Items just live in mob.contents (BYOND's
// built-in containment) — no separate inventory list to keep in sync.
obj/item
    var/description = ""

    // maxStack = 1 means "never merges" — the default for everything except
    // obj/item/consumable, since keys/amulets are meaningfully distinct per-instance.
    var/amount = 1
    var/maxStack = 1

    // Called whenever `amount` changes on a stackable item, so the displayed name
    // picks up "x[amount]". No-op on the base type; consumable overrides it.
    proc/UpdateStackName()
        return

    // Click() on the Inventory tab (StatPanels.dm) routes here via BYOND's own
    // stat-panel-click-to-Click() behavior.
    proc/UseItem(mob/user)
        return

    Click()
        if(ismob(loc))
            var/mob/M = loc
            UseItem(M)

    // Standing on a loose item and pressing Interact picks it up.
    OnInteract(mob/user)
        user.PickUpItem(src)
        return TRUE

    // "set src in usr" scopes this to only show up for items you're carrying.
    verb/Drop()
        set src in usr
        set name = "Drop"
        set category = "Action"

        if(!ismob(loc)) return
        var/mob/M = loc
        loc = M.loc   // falls on the turf you're standing on
        M.ShowInfo("You drop [src.name].")

    // "in view(5, usr)" restricts the target picker to players within 5 tiles.
    verb/Give(mob/player/target in view(5, usr))
        set src in usr
        set name = "Give"
        set category = "Action"

        if(!ismob(loc)) return
        var/mob/M = loc
        if(target == M)
            M.ShowInfo("You can't give an item to yourself.")
            return

        if(!target.PickUpItem(src))
            M.ShowInfo("[target.name]'s inventory is full.")
            return

        M.ShowInfo("You give [src.name] to [target.name].")
        target.ShowInfo("[M.name] gives you [src.name].")

// A named key. Grants access to any lockable object whose own name matches keyName —
// see obj/door's OnInteract() override in Code/World/Obj.dm.
obj/item/key
    name = "Key"
    icon = 'key.dmi'
    icon_state = "key"
    var/keyName

    // Double-clicking a key while facing a matching-named door toggles its lock.
    DblClick()
        if(!ismob(loc)) return
        var/mob/user = loc

        var/turf/facingTile = get_step(user, user.dir)
        if(!facingTile)
            return

        for(var/obj/door/D in facingTile.contents)
            if(D.name != keyName)
                user.ShowInfo("This key doesn't match [D.name].")
                return
            D.is_locked = !D.is_locked
            user.ShowInfo("[D.name] is now [D.is_locked ? "locked" : "unlocked"].")
            return

        user.ShowInfo("You're not facing a door.")

// -----------------------------
// Consumables
// -----------------------------
// ART PLACEHOLDER: World Icons/Items/ currently contains only key.dmi, so every
// consumable below borrows the key sprite — functionally complete but visually
// indistinguishable from each other and from an actual key.
obj/item/consumable
    icon = 'key.dmi'
    icon_state = "key"
    maxStack = 99

    // Subtypes return TRUE if the item was actually consumed; FALSE (e.g. already at
    // full HP) leaves it in the inventory instead of wasting it.
    proc/OnConsume(mob/user)
        return TRUE

    // "x[amount]" only shows once there's more than one.
    UpdateStackName()
        name = amount > 1 ? "[initial(name)] x[amount]" : initial(name)

    UseItem(mob/user)
        if(!OnConsume(user)) return
        amount--
        if(amount <= 0)
            del src
        else
            UpdateStackName()

obj/item/consumable/herb
    name = "medical herb"
    description = "Restores a small amount of HP."
    var/healAmount = 30

    OnConsume(mob/user)
        if(user.HP >= user.MaxHP)
            user.ShowInfo("You are not hurt!")
            return FALSE
        user.ApplyHeal(user, healAmount)
        return TRUE

obj/item/consumable/tea
    name = "herbal tea"
    description = "Restores a small amount of MP."
    var/restoreAmount = 20

    OnConsume(mob/user)
        if(!user.hasMana || user.MaxMP <= 0)
            user.ShowInfo("You have no magic to restore.")
            return FALSE
        if(user.MP >= user.MaxMP)
            user.ShowInfo("You are at full MP!")
            return FALSE
        user.MP = min(user.MaxMP, user.MP + restoreAmount)
        user.ShowInfo("You restore [restoreAmount] MP! (MP: [user.MP]/[user.MaxMP])")
        return TRUE

// OG usage note, verbatim: "Face another player to use this item, or give it to them
// while they are dead." Only the facing case is implemented — give-to-a-dead-player
// already works, since a dead player can just use it themselves once it's theirs.
obj/item/consumable/leaf
    name = "leaf of the world tree"
    description = "Revives a fallen ally."

    OnConsume(mob/user)
        if(user.isDead)
            user.RespawnPlayer()
            return TRUE

        var/turf/facing = get_step(user, user.dir)
        if(facing)
            for(var/mob/player/P in facing.contents)
                if(!P.isDead) continue
                P.RespawnPlayer()
                user.ShowInfo("You revive [P.name] with [src.name].")
                return TRUE

        user.ShowInfo("Face another player to use this item, or give it to them while they are dead.")
        return FALSE

// The item equivalent of the Return spell (SkillCatalog.dm) — same spawn-point lookup.
obj/item/consumable/wyvernwing
    name = "wing of wyvern"
    description = "Returns you to town."

    OnConsume(mob/user)
        if(user.isDead)
            user.ShowInfo("But the strange force contains the wing's powers!")
            return FALSE
        user.loc = GetPlayerSpawnTurf()
        user.ShowInfo("You return to town!")
        return TRUE

// The non-Goof-off path to Sage — reuses the same RunSageReclassFlow()/BecomeSage()
// (PlayerTemplate.dm) Classchange itself calls.
obj/item/consumable/dharmaScroll
    name = "Dharma Scroll"
    description = "A mystical scroll said to transform its reader into a Sage."
    icon = 'key.dmi'   // ART PLACEHOLDER — no dedicated sprite exists yet
    icon_state = "key"

    OnConsume(mob/user)
        if(!istype(user, /mob/player)) return FALSE
        var/mob/player/P = user

        if(istype(P, /mob/player/Sage))
            P.ShowInfo("You are already a Sage.")
            return FALSE

        if(P.Level < CLASSCHANGE_MIN_LEVEL)
            P.ShowInfo("You must be at least level [CLASSCHANGE_MIN_LEVEL] to change your class.")
            return FALSE

        for(var/obj/item/amulet/A in P.contents)
            if(A.worn)
                P.ShowInfo("You must unequip everything before you can change your class.")
                return FALSE

        var/confirm = alert(P, "Read the Dharma Scroll and change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Dharma Scroll", "Yes", "No")
        if(confirm != "Yes") return FALSE

        if(!RunSageReclassFlow(P)) return FALSE  // backed out at the icon step

        P.BecomeSage()
        return TRUE

// -----------------------------
// Amulets — see Markdowns/CodeNotes.md for the OG-confirmation status of this system.
// Bonuses apply to separate equip* vars (never mutate the underlying stat directly),
// same approach StatusEffects.dm uses for buffs — so unequipping is just subtraction,
// with no risk of a bonus getting saved-in permanently.
// -----------------------------
#define MAX_WORN_AMULETS 2

mob
    var
        equipStrength = 0
        equipAgility = 0
        equipVitality = 0
        equipIntelligence = 0
        equipSpirit = 0
        equipDefenseBonus = 0        // Amulet of Protection
        equipMagicDefenseBonus = 0   // Amulet of Barrier
        equipHazardImmune = 0        // Amulet of Safe Passage — counter, not bool, in
                                      // case a future amulet ever stacks with it
        equipSleepImmune = 0         // Amulet of Wakefulness
        equipGoldBonusPercent = 0    // Amulet of Wealth
        equipExpBonusPercent = 0     // Amulet of Experience
        equipDropRateBonus = 0       // Amulet of Luck — flat percentage points added
                                      // to a monster's own dropChance roll

obj/item/amulet
    icon = 'amulets.dmi'
    var/worn = FALSE

    var
        bonusStrength = 0
        bonusAgility = 0
        bonusVitality = 0
        bonusIntelligence = 0
        bonusSpirit = 0
        bonusMaxHP = 0
        bonusMaxMP = 0
        bonusDefense = 0
        bonusMagicDefense = 0
        bonusHazardImmune = 0
        bonusSleepImmune = 0
        bonusGoldPercent = 0
        bonusExpPercent = 0
        bonusDropRate = 0

    UseItem(mob/user)
        if(worn) Unequip(user)
        else     Equip(user)

    proc/CountWornAmulets(mob/user)
        var/count = 0
        for(var/obj/item/amulet/A in user.contents)
            if(A.worn) count++
        return count

    // Equip()/Unequip() are otherwise mirror images of each other (add vs. subtract
    // the same eleven fields) — factored into one signed helper so the field list
    // only exists once. sign = 1 to apply, -1 to remove. MaxHP/MaxMP go through
    // RecalculateVitals() rather than touching the maxima directly, so they compose
    // correctly with level-ups and class factors.
    proc/ApplyAmuletBonuses(mob/user, sign)
        user.equipStrength += sign * bonusStrength
        user.equipAgility += sign * bonusAgility
        user.equipVitality += sign * bonusVitality
        user.equipIntelligence += sign * bonusIntelligence
        user.equipSpirit += sign * bonusSpirit
        user.equipDefenseBonus += sign * bonusDefense
        user.equipMagicDefenseBonus += sign * bonusMagicDefense
        user.equipHazardImmune += sign * bonusHazardImmune
        user.equipSleepImmune += sign * bonusSleepImmune
        user.equipGoldBonusPercent += sign * bonusGoldPercent
        user.equipExpBonusPercent += sign * bonusExpPercent
        user.equipDropRateBonus += sign * bonusDropRate
        user.equipMaxHP += sign * bonusMaxHP
        user.equipMaxMP += sign * bonusMaxMP
        user.RecalculateVitals()

    // silent skips the messages — used when re-equipping a saved amulet on login
    // (SaveData.dm's ApplyInventory()), where there's no fresh player action to narrate.
    proc/Equip(mob/user, silent = FALSE)
        if(CountWornAmulets(user) >= MAX_WORN_AMULETS)
            if(!silent) user.ShowInfo("You cannot wear more than [MAX_WORN_AMULETS] amulets at the same time!")
            return

        worn = TRUE
        name = "[initial(name)] (Equipped)"
        ApplyAmuletBonuses(user, 1)

        if(!silent) user.ShowInfo("You equip [initial(name)].")

    proc/Unequip(mob/user)
        worn = FALSE
        name = initial(name)
        ApplyAmuletBonuses(user, -1)

        user.ShowInfo("You remove [initial(name)].")

    // A worn amulet has to strip its bonus before leaving, or the stats stay behind on
    // a player who no longer owns it.
    Drop()
        if(worn && ismob(loc)) Unequip(loc)
        ..()

    Give(mob/player/target in view(5, usr))
        if(worn && ismob(loc)) Unequip(loc)
        ..()

// --- Raw stat amulets -------------------------------------------------------
obj/item/amulet/strength
    name = "Amulet of Strength"
    description = "Raises Strength."
    icon_state = "strength"
    bonusStrength = 1

obj/item/amulet/agility
    name = "Amulet of Agility"
    description = "Raises Agility."
    icon_state = "agility"
    bonusAgility = 1

obj/item/amulet/vitality
    name = "Amulet of Vitality"
    description = "Raises Vitality."
    icon_state = "vitality"
    bonusVitality = 1

obj/item/amulet/intelligence
    name = "Amulet of Intelligence"
    description = "Raises Intelligence."
    icon_state = "intelligence"
    bonusIntelligence = 1

// No "spirit" state exists in amulets.dmi — "sage" is the closest thematic fit.
obj/item/amulet/spirit
    name = "Amulet of Spirit"
    description = "Raises Spirit."
    icon_state = "sage"
    bonusSpirit = 1

// --- Derived / themed amulets ----------------------------------------------
obj/item/amulet/power
    name = "Amulet of Power"
    description = "Greatly raises Strength."
    icon_state = "power"
    bonusStrength = 2

obj/item/amulet/speed
    name = "Amulet of Speed"
    description = "Greatly raises Agility."
    icon_state = "speed"
    bonusAgility = 2

obj/item/amulet/health
    name = "Amulet of Health"
    description = "Raises maximum HP."
    icon_state = "health"
    bonusMaxHP = 15

obj/item/amulet/magic
    name = "Amulet of Magic"
    description = "Raises maximum MP."
    icon_state = "magic"
    bonusMaxMP = 10

// No "light" state exists in amulets.dmi — "sun" is the closest thematic fit.
obj/item/amulet/light
    name = "Amulet of Light"
    description = "Raises Intelligence and Spirit."
    icon_state = "sun"
    bonusIntelligence = 1
    bonusSpirit = 1

obj/item/amulet/warrior
    name = "Warrior's Amulet"
    description = "Raises Strength and Vitality."
    icon_state = "warrior"
    bonusStrength = 2
    bonusVitality = 1

obj/item/amulet/wizard
    name = "Wizard's Amulet"
    description = "Raises Intelligence, at the cost of Vitality."
    icon_state = "wizard"
    bonusIntelligence = 2
    bonusVitality = -1

obj/item/amulet/sky
    name = "Amulet of the Sky"
    description = "Raises Agility and Intelligence."
    icon_state = "sky"
    bonusAgility = 1
    bonusIntelligence = 1

obj/item/amulet/stars
    name = "Amulet of the Stars"
    description = "Raises every stat slightly."
    icon_state = "stars"
    bonusStrength = 1
    bonusAgility = 1
    bonusVitality = 1
    bonusIntelligence = 1
    bonusSpirit = 1

obj/item/amulet/erdrick
    name = "Erdrick's Amulet"
    description = "The legendary amulet. Raises every stat."
    icon_state = "erdrick"
    bonusStrength = 2
    bonusAgility = 2
    bonusVitality = 2
    bonusIntelligence = 2
    bonusSpirit = 2

// --- Utility amulets ---------------------------------------------------------
obj/item/amulet/stepguard
    name = "Amulet of Safe Passage"
    description = "Protects against damage from lava and swamp terrain."
    icon_state = "stepguard"
    bonusHazardImmune = 1

obj/item/amulet/increase
    name = "Amulet of Protection"
    description = "Reduces physical damage taken."
    icon_state = "increase"
    bonusDefense = 2

obj/item/amulet/barrier
    name = "Amulet of Barrier"
    description = "Reduces magic damage taken."
    icon_state = "barrier"
    bonusMagicDefense = 3

obj/item/amulet/awake
    name = "Amulet of Wakefulness"
    description = "Prevents Sleep."
    icon_state = "awake"
    bonusSleepImmune = 1

obj/item/amulet/gold
    name = "Amulet of Wealth"
    description = "Increases Gold gained from kills."
    icon_state = "gold"
    bonusGoldPercent = 10

obj/item/amulet/exp
    name = "Amulet of Experience"
    description = "Increases EXP gained from kills."
    icon_state = "exp"
    bonusExpPercent = 10

obj/item/amulet/luck
    name = "Amulet of Luck"
    description = "Increases item drop rate."
    icon_state = "luck"
    bonusDropRate = 10  // flat percentage points added to dropChance

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

// Stackable items (maxStack > 1) merge into an existing same-type stack first — that's
// not a new slot, so it can succeed even at capacity.
mob/proc/PickUpItem(obj/item/I)
    if(I.maxStack > 1)
        for(var/obj/item/existing in contents)
            if(existing.type != I.type || existing == I) continue
            if(existing.amount >= existing.maxStack) continue

            var/room = existing.maxStack - existing.amount
            var/moveAmount = min(room, I.amount)
            existing.amount += moveAmount
            I.amount -= moveAmount
            existing.UpdateStackName()

            if(I.amount <= 0)
                del I
                return TRUE
            // Still some left over — keep looking for another same-type stack with
            // room, then fall through to the capacity check below for what's left.

    if(GetInventoryCount() >= GetInventoryCapacity())
        src.ShowInfo("Your inventory is full.")
        return FALSE

    I.loc = src
    I.UpdateStackName()
    return TRUE

// TRUE if this mob is carrying a key whose keyName matches lockName.
mob/proc/HasMatchingKey(lockName)
    for(var/obj/item/key/K in contents)
        if(K.keyName == lockName)
            return TRUE
    return FALSE

// Legacy menu-based fallback — superseded by obj/item/verb/Drop() above (right-click
// the item directly). Kept, just hidden.
mob/verb/DropItem()
    set hidden = 1
    set desc = "Drop an item from your inventory onto the ground"

    var/list/items = list()
    for(var/obj/item/I in contents)
        items[I.name] = I

    if(!items.len)
        src.ShowInfo("You have nothing to drop.")
        return

    var/choice = input(src, "Drop which item?", "Drop Item") in items
    var/obj/item/toDrop = items[choice]

    toDrop.loc = loc   // falls on the turf you're standing on
    src.ShowInfo("You drop [toDrop.name].")
