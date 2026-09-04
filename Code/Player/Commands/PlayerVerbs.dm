// Placeholder popup, wired to the File menu (Interface.dmf) — real content is still
// future work. Hidden from the verb panel since File > Help is the only entry point.
mob/verb/Help()
    set hidden = 1

    src << browse("<h3>Dragon Warrior Legacy Remake</h3><p>Help content coming soon.</p>", "window=help;size=400x300")

// Standing on the stairs and double-clicking your own tile hits your own mob sprite
// (the topmost atom there), not the turf beneath it — turf/stairs/DblClick() never
// sees that click. This catches exactly that case and hands off to the same
// ToggleStairJump() the turf's own DblClick() uses. Falls through to ..() for every
// other double-click (e.g. mob/enemy/DblClick()'s pet menu).
mob/DblClick()
    if(usr == src && istype(loc, /turf/stairs))
        var/turf/stairs/S = loc
        S.ToggleStairJump(src)
        return
    ..()

// -----------------------------
// Quick item — numpad * cycles, numpad - uses. The drag-onto-a-slot half of the OG
// feature needs a screen-object HUD that doesn't exist yet — see Markdowns/CodeNotes.md.
// -----------------------------
mob/var/obj/item/quickItem = null

mob/verb/ScrollQuickItem()
    set hidden = 1

    var/list/items = list()
    for(var/obj/item/I in contents)
        items += I

    if(!items.len)
        src.ShowInfo("You have no items.")
        quickItem = null
        return

    // Advance to the next item after the current one, wrapping around. A quick item
    // used up or dropped since isn't in the list, so this falls through to the first entry.
    var/index = items.Find(quickItem)
    index = (index >= items.len) ? 1 : index + 1

    quickItem = items[index]
    src.ShowInfo("Quick Item: [quickItem.name]")

mob/verb/UseQuickItem()
    set hidden = 1

    if(!quickItem)
        src.ShowInfo("No quick item selected. Press * on your numpad to choose one.")
        return

    // The item may have been dropped, given away, or consumed since it was picked.
    if(quickItem.loc != src)
        quickItem = null
        src.ShowInfo("You no longer have that item.")
        return

    quickItem.UseItem(src)

// -----------------------------
// Quick cast — F5 / F6 / F7. Three spell hotkeys separate from the five numpad skill
// slots, so a caster can keep utility spells reachable without spending a combat slot.
// -----------------------------
mob/var/list/quickSpells = alist(5 = null, 6 = null, 7 = null)

mob/player/verb/SetQuickCast()
    set category = "Action"
    set desc = "Assign a spell to one of the F5/F6/F7 hotkeys"
    set hidden = 1   // stays functional, just not shown in the Action tab

    var/list/castable = list()
    for(var/datum/skill/S in skills)
        if(S.isSpell) castable[S.skillName] = S

    if(!castable.len)
        src.ShowInfo("You have no spells that can be hotkeyed.")
        return

    var/keyChoice = input(src, "Which hotkey will you change?", "Quick Cast Hotkeys") in list("F5", "F6", "F7", "Cancel")
    if(!keyChoice || keyChoice == "Cancel") return

    var/slot = text2num(copytext(keyChoice, 2))

    var/spellChoice = input(src, "Which spell for [keyChoice]?", "Quick Cast Hotkeys") in castable + "Clear"
    if(!spellChoice) return

    if(spellChoice == "Clear")
        quickSpells[slot] = null
        src.ShowInfo("[keyChoice] cleared.")
        return

    quickSpells[slot] = castable[spellChoice]
    src.ShowInfo("[keyChoice] set to [spellChoice].")

// Driven by the F5/F6/F7 macros (Interface.dmf). Targets whoever is on the tile in
// front, same as UseSkillSlot() — a quick-cast spell is still a normal cast.
mob/verb/UseQuickSpell(slot as num)
    set hidden = 1

    var/datum/skill/S = quickSpells[slot]
    if(!S)
        src.ShowInfo("No spell assigned to F[slot].")
        return

    if(isSilenced)
        src.ShowInfo("You are silenced and cannot cast!")
        return

    var/mob/target = null
    var/turf/stepTile = get_step(src, src.dir)
    if(stepTile)
        for(var/mob/M in stepTile.contents)
            if(M == src) continue
            target = M
            break

    S.OnUse(src, target)

// -----------------------------
// Player click menu — clicking another player opens a small action menu, the only
// route for trading or casting a spell on someone who isn't directly in front of you.
// Range-gated so this can't be used across the map.
// -----------------------------
#define PLAYER_MENU_RANGE 5

mob/player/Click()
    // Only another player clicking us, in range, opens the menu. usr is reliable here
    // — Click() is always driven directly by a real client action.
    if(usr == src || !istype(usr, /mob/player) || get_dist(usr, src) > PLAYER_MENU_RANGE)
        return ..()

    var/mob/player/actor = usr
    var/choice = input(actor, "What shall you do?", "[src.name]") in list("Give Gold", "Give Item", "Cast Magic", "Cancel")
    switch(choice)
        if("Give Gold")  actor.GivePlayerGold(src)
        if("Give Item")  actor.GivePlayerItem(src)
        if("Cast Magic") actor.CastAtPlayer(src)

mob/player
    proc/GivePlayerGold(mob/player/target)
        if(Gold <= 0)
            src.ShowInfo("You have no gold to give.")
            return

        var/amount = input(src, "How much gold? (You have [Gold].)", "Give Gold", 0) as num
        if(isnull(amount)) return
        amount = round(amount)
        // Clamped rather than rejected — a negative amount must never become a way to
        // TAKE gold from someone else.
        if(amount <= 0) return
        if(amount > Gold)
            src.ShowInfo("You don't have that much gold.")
            return

        Gold -= amount
        target.Gold += amount
        src.ShowInfo("You give [amount] gold to [target.name].")
        target.ShowInfo("[src.name] gives you [amount] gold.")

    proc/GivePlayerItem(mob/player/target)
        var/list/items = list()
        for(var/obj/item/I in contents)
            items[I.name] = I

        if(!items.len)
            src.ShowInfo("You have nothing to give.")
            return

        var/choice = input(src, "Give which item?", "Give Item") in items + "Cancel"
        if(!choice || choice == "Cancel") return

        var/obj/item/I = items[choice]
        if(!I) return

        if(!target.PickUpItem(I))
            src.ShowInfo("[target.name]'s inventory is full.")
            return

        src.ShowInfo("You give [I.name] to [target.name].")
        target.ShowInfo("[src.name] gives you [I.name].")

    // Casts one of this player's known skills directly at the clicked player,
    // bypassing UseSkillSlot()'s "whoever is on the tile in front of me" targeting —
    // this is what makes party healing practical.
    proc/CastAtPlayer(mob/player/target)
        var/list/castable = list()
        for(var/datum/skill/S in skills)
            if(S.isSpell) castable[S.skillName] = S

        if(!castable.len)
            src.ShowInfo("You have no spells to cast.")
            return

        var/choice = input(src, "Cast which spell on [target.name]?", "Cast Magic") in castable + "Cancel"
        if(!choice || choice == "Cancel") return

        var/datum/skill/S = castable[choice]
        if(!S) return

        // Same central silence gate UseSkillSlot() enforces — a second casting entry
        // point, so Stopspell shouldn't be bypassable just by clicking a player.
        if(isSilenced)
            src.ShowInfo("You are silenced and cannot cast!")
            return

        S.OnUse(src, target)

mob/verb/Interact()
    set hidden = 1

    // Dead players use Interact() (bound to numpad 5) to respawn immediately instead
    // of the normal interact flow — no minimum wait; Die()'s own timer handles the
    // automatic case.
    if(isDead)
        RespawnPlayer()
        return

    var/turf/target = get_step(src, src.dir)
    if(!target) return

    // If the first turf is a counter, skip ahead one more space.
    if(istype(target, /turf/furniture/counter))
        target = get_step(target, src.dir)
        if(!target) return

    // Objs first, then mobs, then the turf itself. Whatever's actually interactable
    // overrides OnInteract() and returns TRUE; nothing else responds.
    for(var/obj/O in target.contents)
        if(O.OnInteract(src))
            return

    // Skips self and anything hostile: walking into a monster stays a combat
    // interaction, not an interact-key one.
    for(var/mob/M in target.contents)
        if(M == src) continue
        if(istype(M, /mob/enemy)) continue
        if(M.OnInteract(src))
            return

    if(target.OnInteract(src))
        return

    // Nothing in front responded — check for loose items on our own tile.
    if(isturf(loc))
        for(var/obj/item/I in loc.contents)
            if(I.OnInteract(src))
                return

// Like Who() (SocialVerbs.dm) but restricted to players actually in view.
mob/verb/Look()
    set category = "Action"
    set desc = "Shows players in view and their basic info"

    src.ShowInfo("<b>Players in view:</b>")

    var/found = FALSE
    for(var/mob/player/M in view(src))
        if(M == src) continue
        if(!M.client) continue
        found = TRUE
        src.ShowInfo("<font color='blue'> \icon[M] [M.name]([M.key]) <b>Class:</b> [M.class] <b>Level:</b> [M.Level] <b>Party:</b> [M.Party ? M.Party.name : "None"]</font>")

    if(!found)
        src.ShowInfo("No other players in view.")

// Toggle checked in mob/proc/Step() (SmoothMovement.dm). While on, pressing a
// direction you're not already facing just turns you first; only a direction you're
// already facing actually steps.
mob/verb/TurnWalk()
    set category = "Action"
    set desc = "Toggle: face a new direction before walking that way, instead of moving instantly"

    turnWalkMode = !turnWalkMode
    src.ShowInfo("Turn-then-walk is now [turnWalkMode ? "ON" : "OFF"].")

// -----------------------------
// Volume Control — Master/Music/SFX sliders (client/ScaledVolume(), Main.dm),
// per-ckey persisted (SaveManager.SaveVolumeSettings()). Three separate verbs so each
// can be adjusted independently without re-entering the others.
// -----------------------------
mob/verb/SetMasterVolume()
    set category = "Settings"
    set desc = "Overall volume, scales Music and SFX together"
    if(!client) return

    var/v = input(src, "Master volume (0-100):", "Settings", client.masterVolume) as num
    if(isnull(v)) return
    client.masterVolume = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src.ShowInfo("Master volume set to [client.masterVolume]%.")
    // Re-apply immediately — Master affects the currently-playing track too, not just
    // future sounds. SOUND_UPDATE adjusts the playing sound's volume in place instead
    // of restarting it from the top.
    if(current_music) client << sound(null, channel = 1, volume = client.ScaledVolume(isMusic = TRUE), status = SOUND_UPDATE)

mob/verb/SetMusicVolume()
    set category = "Settings"
    set desc = "Area background music volume"
    if(!client) return

    var/v = input(src, "Music volume (0-100):", "Settings", client.musicVolume) as num
    if(isnull(v)) return
    client.musicVolume = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src.ShowInfo("Music volume set to [client.musicVolume]%.")
    if(current_music) client << sound(null, channel = 1, volume = client.ScaledVolume(isMusic = TRUE), status = SOUND_UPDATE)

mob/verb/SetSFXVolume()
    set category = "Settings"
    set desc = "Combat/event sound effect volume"
    if(!client) return

    var/v = input(src, "Sound effects volume (0-100):", "Settings", client.sfxVolume) as num
    if(isnull(v)) return
    client.sfxVolume = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src.ShowInfo("Sound effects volume set to [client.sfxVolume]%.")
