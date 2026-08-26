// -----------------------------
// Friendly NPCs
// -----------------------------
// Bare-bones placeholder — no dialogue/AI/movement yet, just a standing, non-hostile
// mob a GM can dress a town with (GM_CreateObj, Code/Admin/Commands/GMCommands.dm).
// One base type, not a hardcoded subtype per appearance — same "real behavior gets a
// subtype, a different sprite doesn't" convention Turfs.dm/Obj.dm already established.
// icon_state is picked at creation time from npc.dmi's real sprite set (merchant/
// guard/priest/etc.) via GetCachedIconStates() (Code/Combat/CombatSystem.dm), so a new
// sprite added to npc.dmi is selectable immediately, no code change needed here.
// Real dialogue/interaction/quest logic is a future system — this only exists so a GM
// has someone to place while that's being built.
mob/npc
    icon = 'npc.dmi'
    icon_state = "man"
    density = 1

// -----------------------------
// Merchants
// -----------------------------
// The remake's first economy sink: until this, Gold was earned from kills and lost on
// death with nothing anywhere to spend it on. Every player-facing string below is
// verbatim from the OG string table — the shop greeting, the Buy/Sell prompts with
// their running gold total, the "Come again." exit, the two refusals.
//
// The OG had six shop types (Item / Amulet / Food / Drink / weapons / armor). Only the
// ones whose goods actually exist in the remake are wired up: Item sells the
// consumables (Code/Player/Inventory.dm), and the rest are left for when their item
// categories get built — amulets in particular are an entire missing character-building
// axis (RemakeVsOGStructure.md Part 3.6), not just missing stock.
//
// PLACEHOLDER prices. The OG stored a `value` per item; that field isn't recovered yet.
// Chosen so a fresh player's early kills (3-10 gold each) make a herb a real but
// reachable purchase, rather than from any confirmed number.
mob/npc/merchant
    icon_state = "merchant"
    var/shopType = "Item"

    // typepath -> price in gold. A merchant with an empty stock list still works — it
    // just can only buy FROM the player, which is a legitimate shop shape.
    var/list/stock = list(
        /obj/item/consumable/herb = 10,
        /obj/item/consumable/tea = 15,
        /obj/item/consumable/wyvernwing = 40,
        /obj/item/consumable/leaf = 100,
    )

    // What the shop pays when buying an item back, as a percent of its own sale price.
    // PLACEHOLDER — a standard "shops buy low" spread, no OG number recovered.
    var/buybackPercent = 50

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
            else       P << output("Come again.", "Info")

    proc/DoBuy(mob/player/P)
        if(!stock.len)
            P << output("I have nothing to sell you. Sorry.", "Info")
            return

        // Labels carry the price so the player can compare without a second prompt —
        // the OG's own "<item>: <n> gold" line format.
        var/list/options = list()
        for(var/itemType in stock)
            var/label = "[initial(itemType:name)]: [stock[itemType]] gold"
            options[label] = itemType

        var/choice = input(P, "What would you like to buy? (You have [P.Gold] gold.)", "Buy") in options + "Cancel"
        if(!choice || choice == "Cancel")
            P << output("Come again.", "Info")
            return

        var/pickedType = options[choice]
        var/price = stock[pickedType]

        if(P.Gold < price)
            P << output("You don't have enough money to buy [initial(pickedType:name)]!", "Info")
            return

        // Create the item first and hand it over through PickUpItem() so the inventory
        // cap is enforced — charging for an item that then can't be carried would be a
        // silent theft. Only deduct gold once it's actually in hand.
        var/obj/item/I = new pickedType
        if(!P.PickUpItem(I))
            del I
            return

        P.Gold -= price
        P << output("Thank you for shopping. Please come again soon!", "Info")

    proc/DoSell(mob/player/P)
        var/list/sellable = list()
        for(var/obj/item/I in P.contents)
            // Only buy back things this shop actually deals in, and never a key — a
            // player selling off a door key would strand themselves.
            if(istype(I, /obj/item/key)) continue
            if(!stock[I.type]) continue
            sellable["[I.name] ([round(stock[I.type] * buybackPercent / 100)] gold)"] = I

        if(!sellable.len)
            P << output("You have nothing to sell me. Sorry.", "Info")
            return

        var/choice = input(P, "What would you like to sell? (You have [P.Gold] gold.)", "Sell") in sellable + "Cancel"
        if(!choice || choice == "Cancel")
            P << output("Come again.", "Info")
            return

        var/obj/item/I = sellable[choice]
        if(!I) return

        P.Gold += round(stock[I.type] * buybackPercent / 100)
        del I
        P << output("Thank you for shopping. Please come again soon!", "Info")
