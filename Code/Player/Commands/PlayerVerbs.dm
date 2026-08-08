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
// General Player Verbs
// -----------------------------
mob/verb/Interact()
    set hidden = 1   // don’t clutter verb panel

    // Dead players use Interact() to respawn instead of the normal interact flow —
    // see Die()'s player branch in Code/Combat/CombatSystem.dm for where isDead/
    // deathTime get set and RESPAWN_DELAY is defined.
    if(isDead)
        if(world.time - deathTime < RESPAWN_DELAY)
            var/secondsLeft = round((RESPAWN_DELAY - (world.time - deathTime)) / 10)
            src << output("You can't respawn yet — [secondsLeft] more second[secondsLeft == 1 ? "" : "s"].", "Info")
            return

        isDead = FALSE
        HP = MaxHP
        MP = MaxMP
        density = 1
        icon_state = "world"
        isDefending = FALSE  // clear a stale defend stance from before death — icon_state
                               // above already resets visually, this resets the actual
                               // damage-reduction flag (Defend, SkillDatum.dm) to match
        ClearStatusEffects()  // don't respawn still poisoned (StatusEffects.dm)
        loc = GetRespawnTurf()
        canAct = TRUE  // re-enable movement — see Die()'s player branch in
                        // Code/Combat/CombatSystem.dm for where this gets locked
        src << output("You respawn.", "Info")
        return

    // Get the turf one step in the direction the mob is facing
    var/turf/target = get_step(src, src.dir)
    if(!target) return

    // If the first turf is a counter, skip ahead one more space
    if(istype(target, /turf/furniture/counter))
        target = get_step(target, src.dir)
        if(!target) return

    // Objs on the tile get first chance to handle it, then the turf itself.
    // Whatever's actually interactable overrides OnInteract() (see
    // Code/World/Interaction.dm) and returns TRUE; nothing else responds.
    for(var/obj/O in target.contents)
        if(O.OnInteract(src))
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
