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

    // Stacking (Phase 5's "Item stacking" gap). maxStack = 1 means "never merges" —
    // the default for everything except obj/item/consumable below, since keys (each
    // carries its own keyName/name) and amulets (each carries its own worn state) are
    // meaningfully distinct per-instance and shouldn't silently combine.
    var/amount = 1
    var/maxStack = 1

    // Called whenever `amount` changes on a stackable item, so the displayed name
    // picks up "x[amount]" — no-op on the base type (and on any item that never
    // stacks); obj/item/consumable below is the real override.
    proc/UpdateStackName()
        return

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
    maxStack = 99  // PLACEHOLDER — no OG stack-limit number recovered

    // Subtypes return TRUE if the item was actually consumed. Returning FALSE (e.g.
    // already at full HP) leaves the item in the inventory rather than wasting it —
    // matching the OG's own "You are not hurt!" refusal.
    proc/OnConsume(mob/user)
        return TRUE

    // "x[amount]" only shows once there's more than one — a single herb still just
    // reads "medical herb", not "medical herb x1".
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

// CONFIRMED OG item (ClassReference.md/TODOList.md Phase 1): the non-Goof-off path to
// Sage. Goof-off learns Classchange as a free leveled skill (datum/skill/Classchange,
// SkillCatalog.dm); every other class needs this scroll instead. Reuses the exact same
// reclass flow (RunSageReclassFlow()/BecomeSage(), PlayerTemplate.dm) Classchange
// already calls — there's only one real "become a Sage" implementation in the
// codebase, this is just a second door into it. PLACEHOLDER: applies the same
// level-25/unequip-everything gates as Classchange for consistency — no OG
// confirmation either way whether the scroll path shares them.
obj/item/consumable/dharmaScroll
    name = "Dharma Scroll"
    description = "A mystical scroll said to transform its reader into a Sage."
    icon = 'key.dmi'   // ART PLACEHOLDER — no dedicated sprite exists yet
    icon_state = "key"

    OnConsume(mob/user)
        if(!istype(user, /mob/player)) return FALSE
        var/mob/player/P = user

        if(istype(P, /mob/player/Sage))
            P << output("You are already a Sage.", "Info")
            return FALSE

        if(P.Level < CLASSCHANGE_MIN_LEVEL)
            P << output("You must be at least level [CLASSCHANGE_MIN_LEVEL] to change your class.", "Info")
            return FALSE

        for(var/obj/item/amulet/A in P.contents)
            if(A.worn)
                P << output("You must unequip everything before you can change your class.", "Info")
                return FALSE

        var/confirm = alert(P, "Read the Dharma Scroll and change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Dharma Scroll", "Yes", "No")
        if(confirm != "Yes") return FALSE

        if(!RunSageReclassFlow(P)) return FALSE  // backed out at the icon step

        P.BecomeSage()
        return TRUE

// -----------------------------
// Amulets
// -----------------------------
// CONFIRMED OG system: 23 named amulets, a max of 2 worn at once ("You cannot wear more
// than 2 amulets at the same time!" is verbatim), each with an /item/amulet/<x>/equip
// override. This was an entire character-building axis with no remake equivalent at all
// (RemakeVsOGStructure.md Part 3.6).
//
// The OG's own naming splits cleanly into two families, which is preserved here:
//   "Amulet of <Stat>"  — raw stat bonuses (Strength, Agility, Vitality, Intelligence,
//                         Spirit)
//   "Amulet of <Power>" — derived bonuses (Power, Speed, Health, Magic, Light, ...)
// Bonuses are applied the same way buffs are (StatusEffects.dm): to separate bonus vars,
// never by mutating the underlying stat. Mutating would show in the Battle panel, trip
// stat-cap checks, and — worst — could be persisted permanently by a save taken while
// equipped, since SaveData.dm snapshots raw stats. Unequipping is then just subtraction,
// with no risk of the bonus getting baked in.
//
// PLACEHOLDER bonus values — the OG stored a per-amulet `bonus` and that field isn't
// recovered yet.
#define MAX_WORN_AMULETS 2

// Stat bonuses granted by worn equipment. Kept separate from the buff bonus vars so a
// buff expiring can never strip an amulet's contribution and vice versa.
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

    // Per-amulet stat contributions — subtypes set whichever they grant.
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

    // silent skips the "you cannot wear more"/"you equip" messages — used when
    // re-equipping a saved amulet on login (SaveData.dm's ApplyInventory()), where
    // there's no fresh action from the player to narrate.
    proc/Equip(mob/user, silent = FALSE)
        if(CountWornAmulets(user) >= MAX_WORN_AMULETS)
            if(!silent) user << output("You cannot wear more than [MAX_WORN_AMULETS] amulets at the same time!", "Info")
            return

        worn = TRUE
        name = "[initial(name)] (Equipped)"

        user.equipStrength += bonusStrength
        user.equipAgility += bonusAgility
        user.equipVitality += bonusVitality
        user.equipIntelligence += bonusIntelligence
        user.equipSpirit += bonusSpirit
        user.equipDefenseBonus += bonusDefense
        user.equipMagicDefenseBonus += bonusMagicDefense
        user.equipHazardImmune += bonusHazardImmune
        user.equipSleepImmune += bonusSleepImmune
        user.equipGoldBonusPercent += bonusGoldPercent
        user.equipExpBonusPercent += bonusExpPercent
        user.equipDropRateBonus += bonusDropRate

        // MaxHP/MaxMP amulets work through RecalculateVitals() rather than touching the
        // maxima directly, so they compose correctly with level-ups and class factors.
        user.equipMaxHP += bonusMaxHP
        user.equipMaxMP += bonusMaxMP
        user.RecalculateVitals()

        if(!silent) user << output("You equip [initial(name)].", "Info")

    proc/Unequip(mob/user)
        worn = FALSE
        name = initial(name)

        user.equipStrength -= bonusStrength
        user.equipAgility -= bonusAgility
        user.equipVitality -= bonusVitality
        user.equipIntelligence -= bonusIntelligence
        user.equipSpirit -= bonusSpirit
        user.equipDefenseBonus -= bonusDefense
        user.equipMagicDefenseBonus -= bonusMagicDefense
        user.equipHazardImmune -= bonusHazardImmune
        user.equipSleepImmune -= bonusSleepImmune
        user.equipGoldBonusPercent -= bonusGoldPercent
        user.equipExpBonusPercent -= bonusExpPercent
        user.equipDropRateBonus -= bonusDropRate
        user.equipMaxHP -= bonusMaxHP
        user.equipMaxMP -= bonusMaxMP
        user.RecalculateVitals()

        user << output("You remove [initial(name)].", "Info")

    // Dropping or giving away a worn amulet has to strip its bonus first, or the
    // stats stay behind on a player who no longer owns it.
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
// Confirmed by the user from memory of the OG (no string-table/monster-table data
// recovered for these, unlike the stat amulets above — functionally these are as
// solid as anything else in this file, just sourced differently).
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
    bonusGoldPercent = 10  // PLACEHOLDER

obj/item/amulet/exp
    name = "Amulet of Experience"
    description = "Increases EXP gained from kills."
    icon_state = "exp"
    bonusExpPercent = 10  // PLACEHOLDER

obj/item/amulet/luck
    name = "Amulet of Luck"
    description = "Increases item drop rate."
    icon_state = "luck"
    bonusDropRate = 10  // PLACEHOLDER — flat percentage points added to dropChance

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
// Stackable items (maxStack > 1, Phase 5) merge into an existing same-type stack
// first — that's not a new slot, so it can succeed even at capacity. Only the
// leftover that doesn't fit in any existing stack needs a fresh slot of its own.
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
            // Still some left over (rare — would need a stack bigger than maxStack to
            // begin with) — keep looking for another same-type stack with room, then
            // fall through to the capacity check below for whatever's still left.

    if(GetInventoryCount() >= GetInventoryCapacity())
        src << output("Your inventory is full.", "Info")
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
