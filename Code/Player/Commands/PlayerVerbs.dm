// -----------------------------
// Help — placeholder popup, wired to the File menu (Interface.dmf). Real content is
// still TODOList.md Phase 4 work ("even the OG's own doc admits it's outdated") — this
// just makes the menu item functional in the meantime, matching the confirmed OG
// presentation (a browse() popup with a title bar/close button, not the output pane or
// a stat panel). Hidden from the verb panel since File > Help is the only entry point.
// -----------------------------
mob/verb/Help()
    set hidden = 1

    src << browse("<h3>Dragon Warrior Legacy Remake</h3><p>Help content coming soon.</p>", "window=help;size=400x300")

// -----------------------------
// Self-click dispatch
// -----------------------------
// Standing on the stairs and double-clicking your own tile hits your own mob sprite —
// the topmost atom at that screen position — not the turf beneath it, so
// turf/stairs/DblClick() (Code/World/Turfs.dm) never sees that click. This catches
// exactly that case (clicking yourself while on a stairs tile) and hands off to the
// same ToggleStairJump() the turf's own DblClick() uses for the "clicked a stairs tile
// you're NOT standing on" case, so both paths land in one place. Falls through to ..()
// for every other double-click (e.g. mob/enemy/DblClick()'s pet menu, EnemyNPCs.dm).
mob/DblClick()
    if(usr == src && istype(loc, /turf/stairs))
        var/turf/stairs/S = loc
        S.ToggleStairJump(src)
        return
    ..()

// -----------------------------
// Player click menu
// -----------------------------
// CONFIRMED OG feature (strings: "What shall you do?", "Give Gold", "Give Item",
// "Cast Magic"). Clicking another player opens a small action menu — the OG's own way
// of doing player-to-player trading and targeted support casting, and the only route it
// had for casting a spell on someone who isn't directly in front of you.
//
// Range-gated to PLAYER_MENU_RANGE so this can't be used across the map. Falls through
// to ..() for anything out of range or non-player, which keeps every existing Click()
// behavior (inventory items, stat-panel links) working untouched.
#define PLAYER_MENU_RANGE 5

mob/player/Click()
    // Only another player clicking us, in range, opens the menu. usr is reliable here —
    // Click() is always driven directly by a real client action.
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
            src << output("You have no gold to give.", "Info")
            return

        var/amount = input(src, "How much gold? (You have [Gold].)", "Give Gold", 0) as num
        if(isnull(amount)) return
        amount = round(amount)
        // Clamped rather than rejected — a typo shouldn't cost a prompt, and a negative
        // amount must never become a way to TAKE gold from someone else.
        if(amount <= 0) return
        if(amount > Gold)
            src << output("You don't have that much gold.", "Info")
            return

        Gold -= amount
        target.Gold += amount
        src << output("You give [amount] gold to [target.name].", "Info")
        target << output("[src.name] gives you [amount] gold.", "Info")

    proc/GivePlayerItem(mob/player/target)
        var/list/items = list()
        for(var/obj/item/I in contents)
            items[I.name] = I

        if(!items.len)
            src << output("You have nothing to give.", "Info")
            return

        var/choice = input(src, "Give which item?", "Give Item") in items + "Cancel"
        if(!choice || choice == "Cancel") return

        var/obj/item/I = items[choice]
        if(!I) return

        if(!target.PickUpItem(I))
            src << output("[target.name]'s inventory is full.", "Info")
            return

        src << output("You give [I.name] to [target.name].", "Info")
        target << output("[src.name] gives you [I.name].", "Info")

    // Casts one of this player's known skills directly at the clicked player, bypassing
    // the "whoever is on the tile in front of me" targeting that UseSkillSlot()
    // (PlayerTemplate.dm) uses. This is what makes party healing practical — you can
    // reach an ally standing beside or behind you.
    proc/CastAtPlayer(mob/player/target)
        var/list/castable = list()
        for(var/datum/skill/S in skills)
            if(S.isSpell) castable[S.skillName] = S

        if(!castable.len)
            src << output("You have no spells to cast.", "Info")
            return

        var/choice = input(src, "Cast which spell on [target.name]?", "Cast Magic") in castable + "Cancel"
        if(!choice || choice == "Cancel") return

        var/datum/skill/S = castable[choice]
        if(!S) return

        // Same central silence gate UseSkillSlot() enforces — this is a second entry
        // point into casting, so it needs the check too or Stopspell would be bypassable
        // just by clicking a player instead of using a numpad slot.
        if(isSilenced)
            src << output("You are silenced and cannot cast!", "Info")
            return

        S.OnUse(src, target)

// -----------------------------
// General Player Verbs
// -----------------------------
mob/verb/Interact()
    set hidden = 1   // don’t clutter verb panel

    // Dead players use Interact() to respawn instead of the normal interact flow.
    // Interact() is bound to the "Center" macro (Interface.dmf) — i.e. numpad 5 — which
    // is exactly the early-respawn key the OG documents, so this needs no minimum wait:
    // pressing it respawns immediately, and Die()'s own timer (CombatSystem.dm) handles
    // the automatic 60-second case for a player who doesn't press anything.
    if(isDead)
        RespawnPlayer()
        return

    // Get the turf one step in the direction the mob is facing
    var/turf/target = get_step(src, src.dir)
    if(!target) return

    // If the first turf is a counter, skip ahead one more space
    if(istype(target, /turf/furniture/counter))
        target = get_step(target, src.dir)
        if(!target) return

    // Objs on the tile get first chance to handle it, then mobs standing there, then
    // the turf itself. Whatever's actually interactable overrides OnInteract() (see
    // Code/World/Interaction.dm) and returns TRUE; nothing else responds.
    for(var/obj/O in target.contents)
        if(O.OnInteract(src))
            return

    // Mobs were never checked here before, which meant an NPC standing in front of you
    // was unreachable no matter what it implemented — the reason merchants needed this
    // (mob/npc/merchant, Code/World/NPCs.dm). Skips self and anything hostile: walking
    // into a monster should stay a combat interaction, not an interact-key one.
    for(var/mob/M in target.contents)
        if(M == src) continue
        if(istype(M, /mob/enemy)) continue
        if(M.OnInteract(src))
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
    for(var/mob/player/M in view(src))
        if(M == src) continue
        if(!M.client) continue
        found = TRUE
        src << output("<font color='blue'> \icon[M] [M.name]([M.key]) <b>Class:</b> [M.class] <b>Level:</b> [M.Level] <b>Party:</b> [M.Party ? M.Party.name : "None"]</font>", "Info")

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

// -----------------------------
// Volume Control — Master/Music/SFX sliders (client/ScaledVolume(), Main.dm). Per-ckey
// persisted (SaveManager.SaveVolumeSettings()/SaveSystem.dm) — these are /client vars,
// so already scoped to the one player adjusting them, never global. Three separate
// verbs rather than one combined prompt so each can be adjusted independently without
// re-entering the others.
// -----------------------------
mob/verb/SetMasterVolume()
    set category = "Settings"
    set desc = "Overall volume, scales Music and SFX together"
    if(!client) return

    var/v = input(src, "Master volume (0-100):", "Settings", client.masterVolume) as num
    if(isnull(v)) return
    client.masterVolume = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src << output("Master volume set to [client.masterVolume]%.", "Info")
    // Re-apply immediately, same reasoning as SetMusicVolume() below — Master affects
    // the currently-playing track too, not just future sounds.
    // status = SOUND_UPDATE adjusts the volume of whatever's already playing on this
    // channel in place, instead of resending the file and restarting it from the top.
    if(current_music) client << sound(null, channel = 1, volume = client.ScaledVolume(isMusic = TRUE), status = SOUND_UPDATE)

mob/verb/SetMusicVolume()
    set category = "Settings"
    set desc = "Area background music volume"
    if(!client) return

    var/v = input(src, "Music volume (0-100):", "Settings", client.musicVolume) as num
    if(isnull(v)) return
    client.musicVolume = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src << output("Music volume set to [client.musicVolume]%.", "Info")
    // Re-apply immediately so the change is audible without needing to change areas.
    // status = SOUND_UPDATE adjusts the volume of whatever's already playing on this
    // channel in place, instead of resending the file and restarting it from the top.
    if(current_music) client << sound(null, channel = 1, volume = client.ScaledVolume(isMusic = TRUE), status = SOUND_UPDATE)

mob/verb/SetSFXVolume()
    set category = "Settings"
    set desc = "Combat/event sound effect volume"
    if(!client) return

    var/v = input(src, "Sound effects volume (0-100):", "Settings", client.sfxVolume) as num
    if(isnull(v)) return
    client.sfxVolume = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src << output("Sound effects volume set to [client.sfxVolume]%.", "Info")
