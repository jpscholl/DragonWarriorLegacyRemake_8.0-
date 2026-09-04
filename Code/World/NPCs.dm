// -----------------------------
// Friendly NPCs
// -----------------------------
// Bare-bones placeholder — no dialogue/AI/movement beyond what's here, just a
// standing, non-hostile mob a GM can dress a town with (GM_CreateObj, GMCommands.dm).
// One base type, not a hardcoded subtype per appearance, same convention Turfs.dm/
// Obj.dm use. icon_state is picked at creation time from npc.dmi's real sprite set via
// GetCachedIconStates() (CombatSystem.dm), so a new sprite added to npc.dmi is
// selectable immediately, no code change needed.
mob/npc
    icon = 'npc.dmi'
    icon_state = "man"
    density = 1

    // Which line gets spoken keys off the world clock's isNight (Main.dm) — the same
    // flag that drives the day/night turf swap.
    var/daymsg = "..."
    var/nightmsg = null   // falls back to daymsg when unset

    // "Stand" holds position and facing; "Walk" wanders like a peaceful monster does.
    var/action = "Stand"
    var/wanderChance = 15   // % chance per idle tick to take a step, when action is Walk
    var/idleTickDelay = 20  // deciseconds between idle ticks

    New()
        ..()
        if(action == "Walk") IdleLoop()

    proc/IdleLoop()
        set waitfor = 0
        while(src)
            sleep(idleTickDelay)
            if(action != "Walk") continue
            if(prob(wanderChance))
                Step(pick(NORTH, SOUTH, EAST, WEST))

    // Turns to face whoever spoke to it first — an NPC that answers with its back
    // turned reads as broken.
    OnInteract(mob/user)
        if(!istype(user, /mob/player)) return FALSE

        dir = get_dir(src, user)

        var/line = (isNight && nightmsg) ? nightmsg : daymsg
        if(!line || line == "...")
            view(src) << output("<font color='black'> \icon[src]&lt;[src.name]&gt; ...</font>", "Messages")
            return TRUE

        view(src) << output("<font color='black'> \icon[src]&lt;[src.name] says:&gt; [line]</font>", "Messages")
        return TRUE

// -----------------------------
// Merchants — see Markdowns/CodeNotes.md for OG-confirmation status of the shop
// strings and shape.
// -----------------------------
mob/npc/merchant
    icon_state = "merchant"
    var/shopType = "Item"

    // typepath -> price in gold. An empty stock list still works — it just can only
    // buy FROM the player, which is a legitimate shop shape.
    var/list/stock = list(
        /obj/item/consumable/herb = 10,
        /obj/item/consumable/tea = 15,
        /obj/item/consumable/wyvernwing = 40,
        /obj/item/consumable/leaf = 100,
    )

    var/buybackPercent = 50  // % of sale price paid when buying an item back

    New()
        ..()
        if(!name || name == "Merchant")
            name = "[shopType] Merchant"  // OG naming convention: "<type> Merchant"

    OnInteract(mob/user)
        if(!istype(user, /mob/player)) return FALSE
        OpenShop(user)
        return TRUE

    proc/OpenShop(mob/player/P)
        var/choice = input(P, "Welcome to the [shopType] shop! What would you like to do?", "[shopType] Shop") in list("Buy", "Sell", "Cancel")
        switch(choice)
            if("Buy")  DoBuy(P)
            if("Sell") DoSell(P)
            else       P.ShowInfo("Come again.")

    proc/DoBuy(mob/player/P)
        if(!stock.len)
            P.ShowInfo("I have nothing to sell you. Sorry.")
            return

        var/list/options = list()
        for(var/itemType in stock)
            var/label = "[initial(itemType:name)]: [stock[itemType]] gold"
            options[label] = itemType

        var/choice = input(P, "What would you like to buy? (You have [P.Gold] gold.)", "Buy") in options + "Cancel"
        if(!choice || choice == "Cancel")
            P.ShowInfo("Come again.")
            return

        var/pickedType = options[choice]
        var/price = stock[pickedType]

        if(P.Gold < price)
            P.ShowInfo("You don't have enough money to buy [initial(pickedType:name)]!")
            return

        // Create the item first and hand it over through PickUpItem() so the
        // inventory cap is enforced — charging for an item that can't be carried
        // would be a silent theft.
        var/obj/item/I = new pickedType
        if(!P.PickUpItem(I))
            del I
            return

        P.Gold -= price
        P.ShowInfo("Thank you for shopping. Please come again soon!")

    proc/DoSell(mob/player/P)
        var/list/sellable = list()
        for(var/obj/item/I in P.contents)
            // Never buy back a key — a player selling one off would strand themselves.
            if(istype(I, /obj/item/key)) continue
            if(!stock[I.type]) continue
            sellable["[I.name] ([round(stock[I.type] * buybackPercent / 100)] gold)"] = I

        if(!sellable.len)
            P.ShowInfo("You have nothing to sell me. Sorry.")
            return

        var/choice = input(P, "What would you like to sell? (You have [P.Gold] gold.)", "Sell") in sellable + "Cancel"
        if(!choice || choice == "Cancel")
            P.ShowInfo("Come again.")
            return

        var/obj/item/I = sellable[choice]
        if(!I) return

        P.Gold += round(stock[I.type] * buybackPercent / 100)
        del I
        P.ShowInfo("Thank you for shopping. Please come again soon!")
