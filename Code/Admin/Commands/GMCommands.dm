// GM-tier power — reaches every connected player at once. See Markdowns/CodeNotes.md
// for the confirmed OG presentation this matches.
mob/verb/GM_Announce()
    set category = "GM"
    set desc = "Broadcasts a big red announcement to every connected player"

    if(!RequireGMHost()) return

    var/msg = input(src, "Announcement:", "GM_Announce") as text|null
    if(isnull(msg) || !length(trimtext(msg))) return
    msg = CensorText(trimtext(msg))

    players << output("[src.name] announces:", "Messages")
    players << output("<font color='red' size='5'><b>[msg]</b></font>", "Messages")

// Deliberately its own tier, ABOVE obj/ceiling's invisibility = 1 (Obj.dm's
// roof-hiding system) — a regular player's see_invisible never exceeds 1, so this
// keeps ghosts hidden regardless of indoor/outdoor. See Markdowns/CodeNotes.md.
#define GHOST_INVISIBILITY 2

mob
    var/isGhostform = FALSE
    var/icon/ghostFormIcon   // remembers appearance while ghosted, unrelated to the character's baseIcon

// See Markdowns/CodeNotes.md for why see_invisible is recomputed (not hardcoded) on
// exit, and why phase.dmi is set directly on the mob rather than a detached overlay.
mob/proc/ToggleGhostForm()
    PlaySFXAt(src, 'spell.WAV')

    if(isGhostform)
        isGhostform = FALSE
        invisibility = 0
        density = 1
        icon = ghostFormIcon
        icon_state = "world"
        var/turf/T = loc
        var/area/A = T ? T.loc : null
        see_invisible = istype(A, /area/ceiling) ? 0 : 1
        src.ShowInfo("You reappear!")
    else
        isGhostform = TRUE
        ghostFormIcon = icon
        icon = 'phase.dmi'
        icon_state = "world"
        invisibility = GHOST_INVISIBILITY
        // Bumping see_invisible to match (not just invisibility) means a ghosted mob
        // can also see OTHER ghosted mobs.
        see_invisible = GHOST_INVISIBILITY
        density = 0
        src.ShowInfo("You disappear!")

// Purely cosmetic flair, no gameplay effect. "Revert to Normal" restores the mob's own
// baseIcon (RebuildIcon(), SaveSystem.dm) rather than just clearing the override, so a
// GM's real class appearance (with their own recolors) comes back exactly.
mob/verb/GM_SwitchIcon()
    set category = "GM"
    set desc = "Switch your own icon to a custom GM cosmetic, purely for flair"

    if(!RequireAdmin()) return

    var/list/icons = list(
        "Angel Blazer" = 'angelblazer.dmi',
        "Blazer" = 'blazer.dmi',
        "Cristo Knucks" = 'cristoknucks.dmi',
        "Dark Blazer" = 'darkblazer.dmi',
        "Evil G" = 'evilg.dmi',
        "Forest Tarq" = 'foresttarq.dmi',
        "Ghost G" = 'ghostg.dmi',
        "King Tarq" = 'kingtarq.dmi',
        "Lego Tarq" = 'legotarq.dmi',
        "Master G" = 'masterg.dmi',
        "Robin Sivelin" = 'robinsivelin.dmi',
        "Saro" = 'saro.dmi',
        "Shiny Master G" = 'shinymasterg.dmi',
        "Shiny Tarq" = 'shinytarq.dmi',
        "Snow Blazer" = 'snowblazer.dmi',
        "Super DW" = 'superdw.dmi',
        "Tarq Pilly" = 'tarqpilly.dmi',
        "Tarq Wizard" = 'tarqwizard.dmi',
        "Water Tarq" = 'watertarq.dmi',
        "Revert to Normal" = "REVERT",
    )

    var/choice = input(src, "Choose a custom icon:", "GM_SwitchIcon") in icons
    if(!choice) return
    var/picked = icons[choice]

    if(picked == "REVERT")
        if(istype(src, /mob/player))
            var/mob/player/P = src
            P.RebuildIcon()
        else
            icon = initial(icon)
        src.ShowInfo("Icon reverted to normal.")
        return

    icon = picked
    icon_state = "world"
    src.ShowInfo("Icon switched to [choice].")

mob/verb/GM_GhostForm()
    set category = "GM"

    if(!RequireAdmin()) return

    ToggleGhostForm()

// Flips adultServer (Main.dm) — TRUE disables the general-profanity list, leaving only
// banned_words_always (slurs/hate speech) enforced.
mob/verb/GM_ToggleProfanityFilter()
    set category = "GM"
    set desc = "Turns the general-profanity filter (names/chat) on or off"

    if(!RequireAdmin()) return

    adultServer = !adultServer
    src.ShowInfo("Profanity filter is now [adultServer ? "OFF" : "ON"] (adultServer = [adultServer]).")

// Flips allowMultiLogin (Main.dm) — when ON, the address-based double-login block in
// client/New() is skipped, letting a second client from the same machine connect as a
// non-GM (e.g. to be a GM_Ban/GM_Boot target). Not a confirmed OG verb — dev/testing
// convenience only.
mob/verb/GM_ToggleMultiLogin()
    set category = "GM"
    set desc = "Turns the same-IP double-login block on or off (for testing with two clients)"

    if(!RequireAdmin()) return

    allowMultiLogin = !allowMultiLogin
    src.ShowInfo("Multi-login is now [allowMultiLogin ? "ALLOWED" : "BLOCKED"] (allowMultiLogin = [allowMultiLogin]).")

// One combined verb instead of the OG's separate GMban/GMunban — a "Ban List" entry
// sits at the top of the same target picker. Bans are per-CHARACTER (one save slot),
// not per-account — see Markdowns/CodeNotes.md for the confirmed severity ordering
// (boot < pwipe < ban) and how a banned slot stops saving.
mob/verb/GM_Ban()
    set category = "GM"
    set desc = "Ban a connected player's character, or unban one from the ban list"

    if(!RequireAdmin()) return

    var/list/targets = GetModerationTargets()

    var/list/options = list("Ban List")
    options += targets
    options += "Cancel"

    var/choice = input(src, "Select a player to ban, or view the Ban List to unban someone:", "GM_Ban") in options
    if(!choice || choice == "Cancel") return

    if(choice == "Ban List")
        ShowBanList()
        return

    var/mob/player/target = targets[choice]
    if(!target) return

    // Confirmed OG step — reason prompt (its own OK/Cancel) first, then the remake's
    // own extra "are you sure?" as the final gate.
    var/reason = input(src, "Reason for banning [target.name] (shown to them):", "GM_Ban") as text|null
    if(isnull(reason)) return  // Cancel
    reason = length(trimtext(reason)) ? CensorText(trimtext(reason)) : "No reason given."

    var/confirm = alert(src, "Ban [target.name] ([target.key])? They will not be able to log back in with this character until unbanned.", "Confirm Ban", "Yes", "No")
    if(confirm != "Yes") return

    BanCharacter(target, reason)
    src.ShowInfo("Banned [target.name] ([target.key]).")

// Shared "pick another connected player, respecting GM hierarchy" target list —
// confirmed OG rule: a lower (or equal) tier GM can't target someone at or above
// their own adminLevel, and you can never target yourself.
mob/proc/GetModerationTargets()
    var/list/targets = list()
    for(var/mob/player/P in players)
        if(P == src) continue
        if(!P.client) continue
        if(P.client.adminLevel >= client.adminLevel) continue
        targets["[P.name] ([P.key])"] = P
    return targets

// Bans live inside each player's own savefile, not a central registry, so this has to
// open every savefile in Player SaveFiles/ and check each slot — cheap enough for how
// rarely this runs (GM-invoked, not per-tick).
mob/proc/ShowBanList()
    var/list/labelToTarget = list()  // label -> list(ckey, slot)

    for(var/fname in flist("Player SaveFiles/"))
        if(length(fname) < 5 || copytext(fname, length(fname) - 3) != ".sav") continue
        var/ckey = copytext(fname, 1, length(fname) - 3)

        var/savefile/F = new("Player SaveFiles/[fname]")
        for(var/slot = 1 to MAX_CHARACTERS)
            var/banned
            F["char[slot].banned"] >> banned
            if(!banned) continue
            var/charName
            F["char[slot].name"] >> charName
            labelToTarget["[charName || "(unnamed)"] ([ckey], Slot [slot])"] = list(ckey, slot)
        // Drop the reference now rather than waiting on BYOND's GC — otherwise this
        // handle can still be open the moment something else opens its own fresh
        // savefile() on the same ckey.
        F = null

    if(!labelToTarget.len)
        src.ShowInfo("Nobody is currently banned.")
        return

    var/list/options = labelToTarget.Copy()
    options += "Cancel"

    var/choice = input(src, "Select a banned character to unban:", "GM_Ban — Ban List") in options
    if(!choice || choice == "Cancel") return

    var/list/pick = labelToTarget[choice]
    var/datum/SaveManager/SM = new(pick[1])
    SM.SetCharacterBanned(pick[2], FALSE)
    SM.Close()  // release the handle right away, same reasoning as F = null above
    src.ShowInfo("Unbanned [choice].")

// Flags the target's current save slot as banned and forces their client to
// disconnect right now. skipSaveOnLogout stops that disconnect's own
// Logout()/SaveAndLogout() (Main.dm) from immediately re-saving an un-banned copy
// over the flag just set below.
mob/proc/BanCharacter(mob/player/target, reason)
    if(!target || !target.saveManager) return

    target.saveManager.SetCharacterBanned(target.saveSlot || 1, TRUE)
    target.skipSaveOnLogout = TRUE

    var/client/C = target.client
    if(C)
        target.ShowInfo("You have been banned by a GM. Reason: [reason]")
        del(C)

// Disconnects a player WITHOUT saving (skipSaveOnLogout, same mechanism as GM_Ban) —
// the punishment is reverting to their last save, not erasing the character outright
// (that's GM_Pwipe below).
mob/verb/GM_Boot()
    set category = "GM"
    set desc = "Disconnects a connected player without saving their progress"

    if(!RequireAdmin()) return

    var/list/targets = GetModerationTargets()
    if(!targets.len)
        src.ShowInfo("No one eligible to boot is connected.")
        return

    var/list/options = targets.Copy()
    options += "Cancel"

    var/choice = input(src, "Select a player to boot:", "GM_Boot") in options
    if(!choice || choice == "Cancel") return

    var/mob/player/target = targets[choice]
    if(!target) return

    var/confirm = alert(src, "Boot [target.name] ([target.key])? They will lose all progress since their last save.", "Confirm Boot", "Yes", "No")
    if(confirm != "Yes") return

    BootCharacter(target)
    src.ShowInfo("Booted [target.name] ([target.key]).")

mob/proc/BootCharacter(mob/player/target)
    if(!target) return

    target.skipSaveOnLogout = TRUE
    var/client/C = target.client
    if(C)
        target.ShowInfo("You have been booted by a GM.")
        del(C)

// Same combined-verb shape as GM_Ban — a "Mute List" entry at the top of the picker
// instead of a separate unmute verb. isMuted is session-only — muting doesn't touch
// the savefile, so it doesn't survive a reconnect.
mob/verb/GM_Mute()
    set category = "GM"
    set desc = "Mute a connected player's chat, or unmute one from the mute list"

    if(!RequireAdmin()) return

    var/list/targets = GetModerationTargets()
    // Already-muted targets belong in the Mute List below, not the mute picker.
    for(var/label in targets)
        var/mob/player/P = targets[label]
        if(P.isMuted) targets -= label

    var/list/options = list("Mute List")
    options += targets
    options += "Cancel"

    var/choice = input(src, "Select a player to mute, or view the Mute List to unmute someone:", "GM_Mute") in options
    if(!choice || choice == "Cancel") return

    if(choice == "Mute List")
        ShowMuteList()
        return

    var/mob/player/target = targets[choice]
    if(!target) return

    var/confirm = alert(src, "Mute [target.name] ([target.key])? They won't be able to speak until unmuted.", "Confirm Mute", "Yes", "No")
    if(confirm != "Yes") return

    target.isMuted = TRUE
    // Deliberately NO message to the target — the OG's mute is silent, and
    // DeliverChat() (SocialVerbs.dm) keeps echoing their own chat back to them so
    // nothing looks broken from their side. Telling them here would defeat the mechanism.
    src.ShowInfo("You have secretly muted [target.name] ([target.key]).")

// Session-only (no savefile field), so unlike ShowBanList this just scans the live
// `players` list instead of every savefile on disk.
mob/proc/ShowMuteList()
    var/list/labelToTarget = list()
    for(var/mob/player/P in players)
        if(!P.isMuted) continue
        labelToTarget["[P.name] ([P.key])"] = P

    if(!labelToTarget.len)
        src.ShowInfo("Nobody is currently muted.")
        return

    var/list/options = labelToTarget.Copy()
    options += "Cancel"

    var/choice = input(src, "Select a muted player to unmute:", "GM_Mute — Mute List") in options
    if(!choice || choice == "Cancel") return

    var/mob/player/target = labelToTarget[choice]
    if(!target) return

    target.isMuted = FALSE
    // Silent on the target's side too — they were never told it started, so telling
    // them it ended would reveal it retroactively.
    src.ShowInfo("You have secretly unmuted [choice].")

// "Player wipe" — confirmed severity ordering: GM_Boot (revert to last save) <
// GM_Pwipe (lose this character entirely) < GM_Ban (also can't log back in). No Pwipe
// List like GM_Ban's — a wiped character is just gone. "All" is gated to LEVEL_AEON
// only, checked both when building the option list AND again right before it
// executes, since Admin-tier alone is enough to open this verb at all.
mob/verb/GM_Pwipe()
    set category = "GM"
    set desc = "Permanently erase a connected player's character from their savefile"

    if(!RequireAdmin()) return

    var/list/targets = GetModerationTargets()
    if(!targets.len)
        src.ShowInfo("No one eligible to pwipe is connected.")
        return

    var/list/options = targets.Copy()
    if(client.adminLevel == LEVEL_AEON)
        options += "All"
    options += "Cancel"

    var/choice = input(src, "Select a player to permanently wipe their character:", "GM_Pwipe") in options
    if(!choice || choice == "Cancel") return

    if(choice == "All")
        if(client.adminLevel != LEVEL_AEON) return  // shouldn't be reachable, safety net only

        var/confirm1 = alert(src, "Pwipe EVERY connected player's character? This cannot be undone.", "Confirm All Pwipe", "Yes", "No")
        if(confirm1 != "Yes") return
        var/confirm2 = alert(src, "Are you REALLY sure? This will erase [targets.len] character(s) permanently, right now.", "Are You Sure?", "Yes", "No")
        if(confirm2 != "Yes") return

        for(var/label in targets)
            PwipeCharacter(targets[label])
        src.ShowInfo("Pwiped all [targets.len] connected player(s).")
        return

    var/mob/player/target = targets[choice]
    if(!target) return

    var/confirm = alert(src, "Permanently wipe [target.name] ([target.key])'s character? This cannot be undone.", "Confirm Pwipe", "Yes", "No")
    if(confirm != "Yes") return

    PwipeCharacter(target)
    src.ShowInfo("Pwiped [target.name] ([target.key]).")

// Deletes the target's current save slot outright and disconnects them.
// skipSaveOnLogout stops SaveAndLogout() from writing a fresh copy back into the slot
// this just erased.
mob/proc/PwipeCharacter(mob/player/target)
    if(!target || !target.saveManager) return

    target.saveManager.DeleteCharacter(target.saveSlot || 1)
    target.skipSaveOnLogout = TRUE

    var/client/C = target.client
    if(C)
        target.ShowInfo("Your character has been permanently wiped by a GM.")
        del(C)

// Confirmed OG spec: broader target scope than the player-only pickers above —
// players AND mobs (NPCs/monsters). Mob half is every non-player mob in the GM's view
// (no "pick a nearby obj/mob" primitive exists yet). Same name validation as character
// creation (PromptForName(), LoginMenu.dm) — rejects outright via IsTextFiltered()
// rather than censoring, so a GM can't leave a half-asterisked name. This is a live
// mob.name change, so it persists on the player's next save with no extra step.
mob/verb/GM_NameChange()
    set category = "GM"
    set desc = "Rename a connected player's character, or any NPC/monster in view"

    if(!RequireGMHost()) return

    var/list/targets = GetModerationTargets()
    for(var/mob/M in view(src))
        if(istype(M, /mob/player)) continue
        targets["[M.name] ([M.type])"] = M

    if(!targets.len)
        src.ShowInfo("No one eligible to rename is connected or in view.")
        return

    var/list/options = targets.Copy()
    options += "Cancel"

    var/choice = input(src, "Select a player or mob to rename:", "GM_NameChange") in options
    if(!choice || choice == "Cancel") return

    var/mob/target = targets[choice]
    if(!target) return

    var/newName
    var/prompt = "New name for [target.name]:"
    while(TRUE)
        newName = input(src, prompt, "GM_NameChange") as text|null
        if(isnull(newName)) return  // Cancel

        newName = trimtext(newName)

        if(!length(newName))
            prompt = "Name can't be blank. New name for [target.name]:"
            continue

        if(length(newName) > MAX_NAME_LENGTH)
            prompt = "Name is too long (max [MAX_NAME_LENGTH] characters). New name for [target.name]:"
            continue

        if(IsTextFiltered(newName))
            prompt = "That name isn't allowed. New name for [target.name]:"
            continue

        break

    var/confirm = alert(src, "Rename [target.name] to \"[newName]\"?", "Confirm Rename", "Yes", "No")
    if(confirm != "Yes") return

    var/oldName = target.name
    target.name = newName
    src.ShowInfo("Renamed [oldName] to [newName].")
    if(target.client)
        target.ShowInfo("A GM renamed you to [newName].")

// Full character-sheet dump, confirmed field order/format. The confirmed OG example
// shows an empty title field ("Cere(Cerebella, )") — no title/rank-tag concept exists
// here, so it's always blank, not omitted, to keep the same shape.
mob/proc/BuildPlayerStatusText(mob/player/P)
    var/text = "<b>[P.name]([P.client ? P.client.ckey : "?"], )</b><br>"
    text += "Class: [P.class] Level: [P.Level] Party: [P.Party ? "[P.Party.name][P.isPartyLeader ? " Leader" : ""]" : "None"]<br>"
    text += "EXP: [P.Exp]/[P.Nexp] ([FormatPercent(P.Exp, P.Nexp)]%)<br>"
    text += "Gold: [P.Gold]<br>"
    text += "HP: [P.HP]/[P.MaxHP] MP: [P.MP]/[P.MaxMP] Stat Points: [P.StatPoints]<br>"
    text += "Strength: [P.Strength]+[P.equipStrength] "
    text += "Agility: [P.Agility]+[P.equipAgility] "
    text += "Vitality: [P.Vitality]+[P.equipVitality] "
    text += "Intelligence: [P.Intelligence]+[P.equipIntelligence] "
    text += "Spirit: [P.Spirit]+[P.equipSpirit]<br>"

    var/list/itemNames = list()
    for(var/obj/item/I in P.contents)
        itemNames += I.name
    text += "Inventory: [itemNames.len ? jointext(itemNames, ", ") : "(empty)"]<br>"

    // Every KNOWN skill, not just the 5 equipped to numpad slots — confirmed OG scope.
    var/list/skillNames = list()
    for(var/datum/skill/S in P.skills)
        skillNames += S.skillName
    text += "Skills: [skillNames.len ? jointext(skillNames, ", ") : "(none)"]<br>"

    return text

mob/verb/GM_PlayerStatus()
    set category = "GM"
    set desc = "Dumps a full character sheet for one player, or every connected player"

    if(!RequireGMHost()) return

    var/list/options = list()
    for(var/mob/player/P in players)
        options[P.name] = P
    if(!options.len)
        src.ShowInfo("No players online.")
        return
    options["All"] = "ALL"
    options["Cancel"] = null

    var/choice = input(src, "View status for whom?", "GM_PlayerStatus") in options
    var/picked = options[choice]
    if(!picked) return

    if(picked == "ALL")
        var/text = ""
        for(var/mob/player/P in players)
            text += BuildPlayerStatusText(P) + "<hr>"
        src << browse(text, "window=playerstatus;size=500x600")
    else
        var/mob/player/P = picked
        src << browse("Status of [P.name]<br><br>[BuildPlayerStatusText(P)]", "window=playerstatus;size=500x400")

// Runtime alternative to hand-editing test_builders/test_admins + recompiling. Toggle
// verbs, same shape as GM_Mute's combined mute/unmute: picking someone already on the
// list revokes it, picking someone not on it grants it. Persisted to its own file
// (AdminLevels.dm's adminPromotionsFile), deliberately not a player's own savefile.
mob/verb/GM_PromoteBuilder()
    set category = "GM"
    set desc = "Grant or revoke persistent Builder access for a connected player"

    if(!RequireGMHost()) return

    var/list/targets = GetModerationTargets()
    if(!targets.len)
        src.ShowInfo("No eligible players are connected.")
        return

    var/list/options = targets.Copy()
    options += "Cancel"
    var/choice = input(src, "Grant/revoke Builder for whom?", "GM_PromoteBuilder") in options
    if(!choice || choice == "Cancel") return

    var/mob/player/target = targets[choice]
    if(!target || !target.client) return

    var/targetCkey = target.client.ckey
    if(targetCkey in persistent_builders)
        persistent_builders -= targetCkey
        src.ShowInfo("[target.name] is no longer a persistent Builder.")
    else
        persistent_builders += targetCkey
        src.ShowInfo("[target.name] is now a persistent Builder.")

    SavePersistentAdminLists()
    target.client.ApplyAdminLevel()   // takes effect immediately, no relog needed

mob/verb/GM_PromoteAdmin()
    set category = "GM"
    set desc = "Grant or revoke persistent Admin access for a connected player"

    if(!RequireGMHost()) return

    var/list/targets = GetModerationTargets()
    if(!targets.len)
        src.ShowInfo("No eligible players are connected.")
        return

    var/list/options = targets.Copy()
    options += "Cancel"
    var/choice = input(src, "Grant/revoke Admin for whom?", "GM_PromoteAdmin") in options
    if(!choice || choice == "Cancel") return

    var/mob/player/target = targets[choice]
    if(!target || !target.client) return

    var/targetCkey = target.client.ckey
    if(targetCkey in persistent_admins)
        persistent_admins -= targetCkey
        src.ShowInfo("[target.name] is no longer a persistent Admin.")
    else
        persistent_admins += targetCkey
        src.ShowInfo("[target.name] is now a persistent Admin.")

    SavePersistentAdminLists()
    target.client.ApplyAdminLevel()

// Creates any of the game's functional world objects at the GM's own location — not
// mouse-placed like GM_MakeTurf/GM_MakeMob/GM_MakeArea, since several of these need a
// per-instance text prompt at creation (a lockable's name, a sign's message) that
// doesn't fit a click-to-place flow. World Login Point/Respawn Point need no prompt,
// just placement — this is how a host sets their world's spawn/respawn spots
// (GetPlayerSpawnTurf()/GetRespawnTurf(), Area.dm) instead of a hardcoded coordinate.
mob/verb/GM_CreateObj()
    set category = "GM"
    set desc = "Creates a functional obj (or a placeholder NPC) at your location"

    if(!RequireBuilder()) return

    var/list/choices = list(
        "Door" = /obj/door,
        "Bookcase" = /obj/stat/bookcase,
        "Pot" = /obj/stat/pot,
        "Drawers" = /obj/stat/drawers,
        "Sign" = /obj/stat/sign,
        "NPC" = /mob/npc,
        "Merchant" = /mob/npc/merchant,
        "World Login Point" = /obj/spawnMarker/playerStart,
        "Respawn Point" = /obj/spawnMarker/playerSpawn,
    )

    var/choice = input(src, "Choose what to create:", "GM_CreateObj") in choices
    if(!choice) return
    var/pickedType = choices[choice]

    if(pickedType == /mob/npc/merchant)
        CreateMerchant()
    else if(pickedType == /mob/npc)
        CreateNPC()
    else if(pickedType == /obj/door)
        // Only doors exist as a lockable type for now — add more here once other
        // lockable types exist (each needs its own is_locked var + OnInteract() check,
        // same as obj/door's in Code/World/Obj.dm).
        CreateDoor(pickedType, choice)
    else if(pickedType == /obj/stat/sign)
        CreateSign()
    else
        new pickedType(loc)
        src.ShowInfo("Created [choice].")

// Door skins are all one real type (obj/door, Obj.dm) painted as different icon_state
// instances, so GetCachedIconStates() reads door.dmi directly instead of a hardcoded
// list. "open" excluded — that's the shared mid-interaction sprite every skin swaps to
// on open(), not a selectable skin.
mob/proc/CreateDoor(doorType, choiceLabel)
    var/list/states = GetCachedIconStates(initial(doorType:icon))
    states -= "open"

    var/list/finalStates = PickDayNightState(states, "Day or Night door skin?", "GM_CreateObj")
    var/skin = input(src, "Choose a door skin:", "GM_CreateObj") in finalStates
    CreateLockable(doorType, choiceLabel, skin)

// Creates a lockable object and its matching key together, so they can't get out of
// sync. lockableType is only known at runtime, so the compiler can't statically verify
// "name"/"is_locked"/"closed_icon_state" exist on it — set dynamically via vars[]
// instead. icon_state IS a builtin /atom var, so that one's set directly.
mob/proc/CreateLockable(lockableType, choiceLabel, skin = null)
    var/lockName = input(src, "Name this [choiceLabel] (a matching key will be created too):", "Name It") as text|null
    if(isnull(lockName) || !length(trimtext(lockName)))
        src.ShowInfo("Cancelled — no name given.")
        return
    lockName = CensorText(trimtext(lockName))

    var/atom/newLockable = new lockableType(loc)
    newLockable.vars["name"] = lockName
    newLockable.vars["is_locked"] = TRUE
    if(skin)
        // Sets both the sprite AND the sprite close() restores to (Obj.dm) — without
        // the latter, opening then closing a freshly-skinned door would snap back to
        // the type's compiled-in default ("wooden") instead of staying jail/silver/etc.
        newLockable.icon_state = skin
        newLockable.vars["closed_icon_state"] = skin

    var/obj/item/key/newKey = new
    newKey.keyName = lockName
    newKey.name = "[lockName] Key"

    if(!PickUpItem(newKey))
        del newKey
        src.ShowInfo("Created [lockName], but your inventory was full — no key was given!")
        return

    src.ShowInfo("Created a locked [lockName] and put its key in your inventory.")

// Signs are otherwise plain (Obj.dm) except for their per-instance message var — set
// it right at creation instead of leaving it at the default "...".
mob/proc/CreateSign()
    var/message = input(src, "What should this sign say?", "Sign Message") as text|null
    if(isnull(message) || !length(trimtext(message))) message = "..."
    else message = CensorText(trimtext(message))

    var/obj/stat/sign/newSign = new(loc)
    newSign.message = message
    src.ShowInfo("Created a sign.")

// Merchants get their own creation flow rather than riding CreateNPC(): a shop needs
// its type chosen at placement, since that decides both its stock and its name. Only
// Item has real goods behind it — the other five OG shop types are offered so a GM can
// lay out a town ahead of their stock existing.
mob/proc/CreateMerchant()
    var/shopChoice = input(src, "What kind of shop?", "GM_CreateObj") in list("Item", "Amulet", "Food", "Drink", "Weapons", "Armor", "Cancel")
    if(!shopChoice || shopChoice == "Cancel") return

    var/mob/npc/merchant/M = new(loc)
    M.shopType = shopChoice
    M.name = "[shopChoice] Merchant"

    // Item and Amulet both have real goods now. The remaining three (Food/Drink/Weapons/
    // Armor) open with an empty stock list, which OpenShop() already handles — they can
    // still buy FROM players and say so plainly rather than erroring.
    switch(shopChoice)
        if("Item")
            // Keeps the type's own default consumable stock.
        if("Amulet")
            // Placeholder prices, deliberately steep — permanent stat gear should be a
            // real saving goal, not an early purchase. Erdrick's is a genuine endgame target.
            M.stock = list(
                /obj/item/amulet/strength = 300,
                /obj/item/amulet/agility = 300,
                /obj/item/amulet/vitality = 300,
                /obj/item/amulet/intelligence = 300,
                /obj/item/amulet/spirit = 300,
                /obj/item/amulet/power = 800,
                /obj/item/amulet/speed = 800,
                /obj/item/amulet/health = 750,
                /obj/item/amulet/magic = 750,
                /obj/item/amulet/light = 900,
                /obj/item/amulet/warrior = 850,
                /obj/item/amulet/wizard = 850,
                /obj/item/amulet/sky = 900,
                /obj/item/amulet/stars = 1500,
                /obj/item/amulet/erdrick = 5000,
                /obj/item/amulet/stepguard = 700,
                /obj/item/amulet/increase = 700,
                /obj/item/amulet/barrier = 700,
                /obj/item/amulet/awake = 600,
                /obj/item/amulet/gold = 900,
                /obj/item/amulet/exp = 900,
                /obj/item/amulet/luck = 1000,
            )
        else
            M.stock = list()

    src.ShowInfo("Created [M.name].")

// Spawns a carriable item straight into the GM's own inventory, for testing without
// walking to a merchant and paying for it. Two-step menu (category, then item) rather
// than one flat list — the amulet roster alone is 22 entries.
mob/verb/GM_MakeItem()
    set category = "GM"
    set desc = "Spawns a consumable or amulet directly into your inventory"

    if(!RequireBuilder()) return

    var/list/categories = list(
        "Consumable" = list(
            "Medical Herb" = /obj/item/consumable/herb,
            "Herbal Tea" = /obj/item/consumable/tea,
            "Leaf of the World Tree" = /obj/item/consumable/leaf,
            "Wing of Wyvern" = /obj/item/consumable/wyvernwing,
            "Dharma Scroll" = /obj/item/consumable/dharmaScroll,
        ),
        "Amulet" = list(
            "Amulet of Strength" = /obj/item/amulet/strength,
            "Amulet of Agility" = /obj/item/amulet/agility,
            "Amulet of Vitality" = /obj/item/amulet/vitality,
            "Amulet of Intelligence" = /obj/item/amulet/intelligence,
            "Amulet of Spirit" = /obj/item/amulet/spirit,
            "Amulet of Power" = /obj/item/amulet/power,
            "Amulet of Speed" = /obj/item/amulet/speed,
            "Amulet of Health" = /obj/item/amulet/health,
            "Amulet of Magic" = /obj/item/amulet/magic,
            "Amulet of Light" = /obj/item/amulet/light,
            "Warrior's Amulet" = /obj/item/amulet/warrior,
            "Wizard's Amulet" = /obj/item/amulet/wizard,
            "Amulet of the Sky" = /obj/item/amulet/sky,
            "Amulet of the Stars" = /obj/item/amulet/stars,
            "Erdrick's Amulet" = /obj/item/amulet/erdrick,
            "Amulet of Safe Passage" = /obj/item/amulet/stepguard,
            "Amulet of Protection" = /obj/item/amulet/increase,
            "Amulet of Barrier" = /obj/item/amulet/barrier,
            "Amulet of Wakefulness" = /obj/item/amulet/awake,
            "Amulet of Wealth" = /obj/item/amulet/gold,
            "Amulet of Experience" = /obj/item/amulet/exp,
            "Amulet of Luck" = /obj/item/amulet/luck,
        ),
    )

    var/categoryChoice = input(src, "What kind of item?", "GM_MakeItem") in categories + "Cancel"
    if(!categoryChoice || categoryChoice == "Cancel") return

    var/list/items = categories[categoryChoice]
    var/itemChoice = input(src, "Choose a [categoryChoice]:", "GM_MakeItem") in items + "Cancel"
    if(!itemChoice || itemChoice == "Cancel") return

    var/pickedType = items[itemChoice]
    var/obj/item/I = new pickedType

    // Falls back to dropping it at your feet rather than refusing outright — a GM
    // testing tool has no reason to punish a full inventory by destroying the item.
    if(PickUpItem(I))
        src.ShowInfo("Created [I.name] in your inventory.")
    else
        I.loc = loc
        src.ShowInfo("Your inventory is full — dropped [I.name] at your feet instead.")

// icon_state offered here comes straight from npc.dmi's own real sprite set
// (GetCachedIconStates()) — not hardcoded, so a new sprite added to the file is
// selectable immediately.
mob/proc/CreateNPC()
    var/list/states = GetCachedIconStates('npc.dmi')
    if(!states.len)
        src.ShowInfo("No NPC sprites found.")
        return
    var/stateChoice = input(src, "Choose an NPC appearance:", "GM_CreateObj") in states

    var/npcName = input(src, "Name this NPC:", "Name It") as text|null
    npcName = (isnull(npcName) || !length(trimtext(npcName))) ? Capitalize(stateChoice) : CensorText(trimtext(npcName))

    var/mob/npc/newNPC = new(loc)
    newNPC.icon_state = stateChoice
    newNPC.name = npcName

    // Matches the OG's own NPC creation fields (Day Speech, Night Speech, Action).
    // Both speech prompts are optional — blank keeps the "..." placeholder. Night
    // Speech falls back to Day Speech when unset (mob/npc, NPCs.dm).
    var/day = input(src, "Day Speech (leave blank for none):", "Day Speech") as text|null
    if(!isnull(day) && length(trimtext(day)))
        newNPC.daymsg = CensorText(trimtext(day))

    var/night = input(src, "Night Speech (leave blank to reuse Day Speech):", "Night Speech") as text|null
    if(!isnull(night) && length(trimtext(night)))
        newNPC.nightmsg = CensorText(trimtext(night))

    var/act = input(src, "Action", "Action") in list("Stand", "Walk")
    newNPC.action = act
    if(act == "Walk") newNPC.IdleLoop()  // New() already ran; start it now that the
                                          // action is actually set

    if(act == "Stand")
        var/face = input(src, "Which way should they face?", "Face") in list("North", "South", "East", "West")
        switch(face)
            if("North") newNPC.dir = NORTH
            if("South") newNPC.dir = SOUTH
            if("East")  newNPC.dir = EAST
            if("West")  newNPC.dir = WEST

    src.ShowInfo("Created [npcName] the NPC.")

// Appends/strips the "night" suffix on one atom's icon_state — shared by the turf and
// obj loops below. IsNightVariant() (Main.dm) is the shared suffix check.
proc/ToggleNightIconState(atom/A, toNight)
    if(!A.icon_state) return
    if(toNight)
        A.icon_state += "night"
    else if(IsNightVariant(A.icon_state))
        A.icon_state = copytext(A.icon_state, 1, length(A.icon_state) - 4)

// Toggles day/night. Delegates the actual sweep to SetWorldNight() (Main.dm) so a
// GM-forced toggle and the clock-driven one share one implementation.
mob/verb/GM_DayNight()
    set category = "GM"
    set desc = "Toggles day/night for every turf, obj, and mob in the world"

    if(!RequireGMHost()) return

    SetWorldNight(!isNight)

    world << output("[src] has turned it to [isNight ? "night" : "day"].", "Info")

// Flips loggingEnabled (TextFilter.dm) — gates LogChat()'s own lines (chat,
// login/logout, double-login) only. world.log's automatic connect/disconnect/host
// events keep writing to server.log regardless — that's the engine, not this.
mob/verb/GM_ToggleLog()
    set category = "GM"
    set desc = "Turns chat/login logging (server.log) on or off"

    if(!RequireGMHost()) return

    loggingEnabled = !loggingEnabled
    src.ShowInfo("Chat/login logging is now [loggingEnabled ? "ON" : "OFF"].")

// Directly applies the same side effects LevelCheck() does on a real level-up
// (StatPoints, RecalculateVitals()) rather than piling on Exp and hoping it triggers.
mob/verb/GM_LevelIncrease()
    set category = "GM"
    set desc = "Increases your level by a chosen amount, same as leveling up normally"

    if(!RequireGMHost()) return

    var/amount = input(src, "How many levels to add?", "GM_LevelIncrease", 1) as num
    if(isnull(amount) || amount < 1) return
    amount = round(amount)

    // Same per-level side effects as a real level-up, repeated — RecalculateVitals()
    // tops up HP/MP by however much Max just grew each time, so looping this is
    // equivalent to a real level-up chain, not a single jump.
    for(var/i = 1 to amount)
        Level += 1
        StatPoints += 6   // matches LevelCheck()'s confirmed OG value
        RecalculateVitals()

    src.ShowInfo("You are now Level [Level] (+[amount])")
    src << sound('levelup.wav', channel = 2, volume = client.ScaledVolume())

// Toggles whether attacks/skills are allowed in a specific area instance — see
// battleModeOn (Area.dm) and InBattleArea() (CombatSystem.dm), which checks it.

// Adds every real area instance to `choices`, labeled "Name (type)" — shared by
// every GM verb that offers an area picker (GM_BattleMode/GM_CoopMode/GM_PlayMusic/
// GM_GlobalRespawn), each of which only differs in what else the base list contains.
proc/AddAreaChoices(list/choices)
    for(var/area/A in world)
        choices["[A.name] ([A.type])"] = A
    return choices

mob/verb/GM_BattleMode()
    set category = "GM"
    set desc = "Toggles battle mode for one area, or every area at once"

    if(!RequireGMHost()) return

    var/list/areaChoices = AddAreaChoices(list("None" = null, "All Areas" = "ALL"))

    var/choice = input(src, "Choose an area to toggle battle mode (or All Areas):", "GM_BattleMode") in areaChoices
    var/selection = areaChoices[choice]
    if(!selection) return  // "None" selected, cancel

    if(selection == "ALL")
        // Global override — disregards each area type's own default while active.
        battleModeGlobalOn = !battleModeGlobalOn
        for(var/area/A in world)
            A.battleModeOn = battleModeGlobalOn
        world << output("[src] has turned battle mode [battleModeGlobalOn ? "ON" : "OFF"] everywhere.", "Info")
    else
        var/area/target = selection
        target.battleModeOn = !target.battleModeOn
        src.ShowInfo("[target.name] is now [target.battleModeOn ? "a dangerous area" : "a peaceful area"].")

// Per-area (or global) toggle for PLAYER-vs-PLAYER damage, separate from
// GM_BattleMode's monster-aggro/skill-use gate. Coop ON (the default everywhere,
// Area.dm's battleAllowsPvP = FALSE) means players can't hurt each other; Coop OFF
// enables PvP. Enforced in TakeDamage() (CombatSystem.dm), which also exempts GM-tier
// targets from the protection.
mob/verb/GM_CoopMode()
    set category = "GM"
    set desc = "Toggles player-vs-player damage for one area, or every area at once"

    if(!RequireGMHost()) return

    var/list/areaChoices = AddAreaChoices(list("None" = null, "All Areas" = "ALL"))

    var/choice = input(src, "Choose an area to toggle coop mode (or All Areas):", "GM_CoopMode") in areaChoices
    var/selection = areaChoices[choice]
    if(!selection) return  // "None" selected, cancel

    if(selection == "ALL")
        coopModeGlobalOn = !coopModeGlobalOn
        for(var/area/A in world)
            A.battleAllowsPvP = !coopModeGlobalOn
        world << output("[src] has turned coop mode [coopModeGlobalOn ? "ON" : "OFF"] everywhere.", "Info")
    else
        var/area/target = selection
        target.battleAllowsPvP = !target.battleAllowsPvP
        src.ShowInfo("[target.name] is now [target.battleAllowsPvP ? "PvP-enabled" : "a coop (PvE-only) area"].")

// Runtime setter for areaMusic (Area.dm) — same area-picker pattern as GM_BattleMode/
// GM_CoopMode. Setting areaMusic alone only affects whoever ENTERS the area next
// (area/Entered() -> PlayAreaMusic()) — pushed immediately to everyone already
// standing there too, so the change is heard right away.
mob/verb/GM_PlayMusic()
    set category = "GM"
    set desc = "Sets or changes an area's background music, or every area at once"

    if(!RequireGMHost()) return

    var/list/areaChoices = AddAreaChoices(list("None" = null, "All Areas" = "ALL"))

    var/choice = input(src, "Choose an area to set music for (or All Areas):", "GM_PlayMusic") in areaChoices
    var/selection = areaChoices[choice]
    if(!selection) return

    // Every real .mid track that exists in Sound & Music/ — friendly names, not
    // filenames, in the picker.
    var/list/tracks = list(
        "Silence (no music)" = null,
        "Town (DW4)" = 'dw4town.mid',
        "Town (DW3)" = 'dw3town.mid',
        "Continent (DW3)" = 'dw3conti.mid',
        "Shrine (DW3)" = 'dw3shri2.mid',
        "Cave" = 'cave.mid',
        "Casino (DW4)" = 'dw4casin.mid',
        "Hero Theme (DW4)" = 'dw4hero.mid',
        "Tower (DW4)" = 'dw4tower.mid',
        "Battle (DQ5)" = 'dq5battle.mid',
        "Cast/Overworld (DW4)" = 'Dw4cast.mid',
    )
    var/trackChoice = input(src, "Choose a track:", "GM_PlayMusic") in tracks
    if(isnull(trackChoice)) return
    var/trackFile = tracks[trackChoice]

    var/area/target = (selection == "ALL") ? null : selection
    if(target)
        target.areaMusic = trackFile
    else
        for(var/area/A in world)
            A.areaMusic = trackFile

    // Push immediately to whoever's already standing there — areas have no built-in
    // "members" list in DM, so this walks every client-having mob and checks its
    // current turf's area.
    for(var/mob/M in world)
        if(!M.client) continue
        var/turf/T = M.loc
        var/area/mobArea = T ? T.loc : null
        if(!target || mobArea == target)
            M.PlayAreaMusic(trackFile)

    if(target)
        src.ShowInfo("[target.name]'s music changed to [trackChoice].")
    else
        world << output("[src] changed the music everywhere to [trackChoice].", "Info")

// World-wide toggle: ON, a returning character loads at their exact last-saved
// (x,y,z) instead of GetPlayerSpawnTurf(). Position is always recorded on every save
// regardless of this flag — only the LOAD side checks it, so toggling this doesn't
// need anyone to re-save first, and toggling it off doesn't erase anyone's saved position.
mob/verb/GM_SaveLocation()
    set category = "GM"
    set desc = "Toggles whether returning characters spawn at their last saved position"

    if(!RequireGMHost()) return

    saveLocationEnabled = !saveLocationEnabled
    world << output("[src] turned location saving [saveLocationEnabled ? "ON" : "OFF"] — returning characters now spawn at [saveLocationEnabled ? "their last saved position" : "the normal spawn point"].", "Info")

// A named monster-spawn management system (confirmed 5-step spec: Name, Area, Monster
// type, Z level, Count). Session-only — no world serializer exists yet to persist it
// across a reboot. See Markdowns/CodeNotes.md for confirmed quirks (one-shot, not
// replenished; silent no-op if Area/Z don't match a real turf).
datum/RespawnDefinition
    var/defName
    var/area/targetArea   // null = "all areas"
    var/monsterType
    var/zLevel             // 0 = "all levels"
    var/count = 1
    var/list/mob/enemy/spawnedMobs = list()

var/list/datum/RespawnDefinition/respawnDefinitions = list()

// Kills whatever this definition last spawned (still alive), then spawns `count`
// fresh ones onto turfs matching targetArea/zLevel — both on create and modify, so
// stale mobs from the old settings never linger.
proc/ExecuteRespawnDefinition(datum/RespawnDefinition/D)
    for(var/mob/enemy/E in D.spawnedMobs)
        if(E) del E
    D.spawnedMobs = list()

    var/list/turf/candidates = list()
    for(var/turf/T in world)
        if(D.targetArea && T.loc != D.targetArea) continue
        if(D.zLevel && T.z != D.zLevel) continue
        if(T.density) continue
        candidates += T

    if(!candidates.len) return   // no matching turf — confirmed silent no-op, not an error

    for(var/i = 1 to D.count)
        var/turf/T = pick(candidates)
        D.spawnedMobs += new D.monsterType(T)

// Walks the confirmed 5-step creation/modify flow, writing onto D in place. Returns
// FALSE if cancelled at any step (caller discards the half-configured D).
mob/proc/ConfigureRespawnDefinition(datum/RespawnDefinition/D)
    var/newName = input(src, "Name this respawn definition:", "GM_GlobalRespawn") as text|null
    if(isnull(newName) || !length(trimtext(newName))) return FALSE
    D.defName = CensorText(trimtext(newName))

    var/list/areaChoices = AddAreaChoices(list("All Areas" = "ALL", "Cancel" = "CANCEL"))
    var/areaChoice = input(src, "Choose an area for [D.defName] (or All Areas):", "GM_GlobalRespawn") in areaChoices
    var/areaPicked = areaChoices[areaChoice]
    if(!areaPicked || areaPicked == "CANCEL") return FALSE
    D.targetArea = (areaPicked == "ALL") ? null : areaPicked

    var/list/monsterChoices = GetTypeChoices(/mob/enemy) - "None"
    var/monsterChoice = input(src, "Choose a monster type for [D.defName]:", "GM_GlobalRespawn") in monsterChoices + "Cancel"
    if(!monsterChoice || monsterChoice == "Cancel") return FALSE
    D.monsterType = monsterChoices[monsterChoice]

    var/z = input(src, "Z level for [D.defName] (0 for all levels):", "GM_GlobalRespawn", D.zLevel) as num|null
    if(isnull(z)) return FALSE
    D.zLevel = z

    var/count = input(src, "How many [monsterChoice] to spawn?", "GM_GlobalRespawn", max(D.count, 1)) as num|null
    if(isnull(count) || count < 1) return FALSE
    D.count = count

    return TRUE

mob/verb/GM_GlobalRespawn()
    set category = "GM"
    set desc = "Create, modify, or delete a one-shot monster spawn definition"

    if(!RequireGMHost()) return

    var/list/options = list("Create New Respawn" = "NEW")
    for(var/datum/RespawnDefinition/D in respawnDefinitions)
        options[D.defName] = D
    options["Cancel"] = null

    var/choice = input(src, "Manage monster spawn definitions:", "GM_GlobalRespawn") in options
    var/picked = options[choice]
    if(!picked) return

    if(picked == "NEW")
        var/datum/RespawnDefinition/D = new
        if(!ConfigureRespawnDefinition(D)) return
        respawnDefinitions += D
        ExecuteRespawnDefinition(D)
        src.ShowInfo("Created and spawned [D.count]x [initial(D.monsterType:name)] ([D.defName]).")
        return

    var/datum/RespawnDefinition/D = picked
    var/action = input(src, "[D.defName]: Modify, Delete, or Cancel?", "GM_GlobalRespawn") in list("Modify", "Delete", "Cancel")
    if(!action || action == "Cancel") return

    if(action == "Delete")
        for(var/mob/enemy/E in D.spawnedMobs)
            if(E) del E
        respawnDefinitions -= D
        src.ShowInfo("Deleted respawn definition [D.defName].")
        return

    // Modify — re-runs the same flow onto the existing definition, then respawns.
    if(!ConfigureRespawnDefinition(D)) return
    ExecuteRespawnDefinition(D)
    src.ShowInfo("Updated and re-spawned [D.defName].")

// Kills monsters through the real death pipeline (Die()/CleanUpDead(), CombatSystem.dm)
// instead of a raw del() — so they play the hit sound, get the "sleep" knockout pose,
// credit src with exp/gold, and linger as a corpse like dying in combat. Deliberately
// skips TakeDamage()'s RollDodge()/damage math — this is meant to always land.
// Monster type entries reuse GetTypeChoices(/mob/enemy) (BuildTools.dm) — the same
// list GM_MakeMob builds its picker from.
mob/verb/GM_KillMonsters()
    set category = "GM"
    set desc = "Instantly kills monsters through the real death process, by type or all at once"

    if(!RequireGMHost()) return

    var/list/choices = list("All" = "all")
    var/list/monsterChoices = GetTypeChoices(/mob/enemy)
    monsterChoices -= "None"
    choices += monsterChoices

    var/choice = input(src, "Kill which monsters?", "GM_KillMonsters") in choices
    if(!choice) return
    var/picked = choices[choice]

    var/killed = 0
    for(var/mob/enemy/E in world)
        if(E.HP <= 0) continue  // already dead and lingering through CleanUpDead()'s delay
        if(picked != "all" && E.type != picked) continue

        flick("hit", E)
        PlaySFXAt(E, 'enemyhit.wav')
        E.HP = 0
        E.Die(src)
        E.CleanUpDead()
        killed++

    world << output("[src] killed [killed] monster[killed == 1 ? "" : "s"][picked == "all" ? "" : " ([choice])"].", "Info")

// Confirmed OG flow: big red announcement, then a big red countdown, then save
// everyone and restart. NOT copied: the OG's own post-reboot reconnect left every
// client on a black screen — world/Reboot() (Main.dm) is a from-scratch fix for that
// (see Markdowns/CodeNotes.md). The most destructive single action in the toolkit.
mob/verb/GM_WorldReboot()
    set category = "GM"
    set desc = "Saves everyone, then reboots the world after a 10-second countdown"

    if(!RequireGMHost()) return

    var/confirm = alert(src, "Reboot the world? Everyone will be saved, then the map resets and the server restarts.", "Confirm World Reboot", "Yes", "No")
    if(confirm != "Yes") return

    players << output("<font color='red' size='5'><b>[src.name] has announced a server reboot in 10 seconds....</b></font>", "Messages")

    for(var/i = 10, i >= 0, i--)
        players << output("<font color='red' size='6'><b>[i]</b></font>", "Messages")
        sleep(10)

    // Save every real character before the wipe — same SaveCharacter() call
    // SaveAndLogout() (Main.dm) uses on a normal disconnect.
    for(var/mob/player/P in players)
        if(P.saveManager)
            P.saveManager.SaveCharacter(P, P.saveSlot || 1)

    world.Reboot()

// Overlays each turf CURRENTLY IN VIEW with its own area's icon/icon_state (Area.dm)
// so a GM can see area boundaries at a glance. Only builds images for a small area
// around the GM (AREA_OVERLAY_RADIUS) and refreshes via a polling loop
// (AreaOverlayLoop()) when they move to a new tile, rather than snapshotting the whole
// world once — see Markdowns/CodeNotes.md for the lag this replaced.

// world.view is 13x13 (Main.dm) — 6 tiles out from center. Padded a few tiles past
// that so the overlay is already built just off-screen before the GM walks into view
// of it, masking AreaOverlayLoop()'s refresh delay behind a buffer.
#define AREA_OVERLAY_BUFFER 3
#define AREA_OVERLAY_RADIUS (6 + AREA_OVERLAY_BUFFER)

mob/var/list/areaOverlayImages
mob/var/seeingAreas = FALSE
mob/var/turf/areaOverlayLastLoc

mob/verb/GM_SeeAreas()
    set category = "GM"
    set desc = "Toggles a visual overlay showing which area each tile belongs to"

    if(!RequireBuilder()) return

    seeingAreas = !seeingAreas

    if(seeingAreas)
        areaOverlayLastLoc = null  // force RefreshAreaOverlay() to build on the first tick
        AreaOverlayLoop()
        src.ShowInfo("Area overlay is now ON.")
    else
        if(areaOverlayImages)
            client.images -= areaOverlayImages
            areaOverlayImages = null
        src.ShowInfo("Area overlay is now OFF.")

// Polls while seeingAreas is on, rebuilding the overlay only when the GM has actually
// moved to a new tile — skips redundant rebuilds while standing still.
mob/proc/AreaOverlayLoop()
    set waitfor = 0
    while(seeingAreas && client)
        if(loc != areaOverlayLastLoc)
            areaOverlayLastLoc = loc
            RefreshAreaOverlay()
        sleep(5)  // check twice a second — cheap since each rebuild is viewport-sized

// Rebuilds areaOverlayImages for a small padded area around the GM, swapping out the
// old set for the new one in one shot. range(), not view() — this intentionally
// covers tiles beyond what's currently on-screen.
mob/proc/RefreshAreaOverlay()
    if(!client) return

    var/list/newImages = list()
    for(var/turf/T in range(AREA_OVERLAY_RADIUS, src))
        var/area/A = T.loc
        if(A && A.icon_state)
            // A.icon, not a hardcoded 'environment.dmi' — a future area with its own
            // distinct icon file would otherwise render wrong under this overlay.
            var/image/areaImg = image(A.icon, T, A.icon_state)
            // Shared with area/AddedTurf()'s always-on overlay (Area.dm) so the two
            // can't drift apart.
            areaImg.layer = AREA_OVERLAY_LAYER
            newImages += areaImg

        // World login/respawn markers are invisible to everyone normally — drawn here
        // as an ADDITIONAL layer on top of the tile's own area color, not instead of
        // it, without ever actually reassigning the tile's area.
        for(var/obj/spawnMarker/M in T.contents)
            var/image/markerImg = image(M.icon, T, M.icon_state)
            markerImg.layer = AREA_OVERLAY_LAYER
            newImages += markerImg

    if(areaOverlayImages)
        client.images -= areaOverlayImages
    client.images += newImages
    areaOverlayImages = newImages