// -----------------------------
// GM Announce
// -----------------------------
// Confirmed OG presentation (real screenshot): a plain "[GM] has an announcement" line,
// then the message itself on its own line — big, bold, red. `players`
// (Code/Core/Main.dm), not `world <<`, matches the broadcast convention every other
// server-wide message in this codebase already uses (SocialVerbs.dm's Broadcast()).
// GM-tier power — this reaches every connected player at once.
mob/verb/GM_Announce()
    set category = "GM"
    set desc = "Broadcasts a big red announcement to every connected player"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/msg = input(src, "Announcement:", "GM_Announce") as text|null
    if(isnull(msg) || !length(trimtext(msg))) return
    msg = CensorText(trimtext(msg))

    players << output("[src.name] announces:", "Messages")
    players << output("<font color='red' size='5'><b>[msg]</b></font>", "Messages")

// -----------------------------
// GM Ghost Form
// -----------------------------
// GHOST_INVISIBILITY is deliberately its own tier, ABOVE obj/ceiling's
// invisibility = 1 (Obj.dm — the roof-hiding system). A regular player's
// see_invisible fluctuates between 0 (indoors) and 1 (outdoors, so the roof itself
// becomes visible) via area/ceiling's Entered()/Exited() (Area.dm) — it never
// reaches 2, so this keeps ghosts hidden from ordinary players regardless of whether
// they're currently indoors or outdoors. Previously both systems used invisibility/
// see_invisible = 1, which meant any player standing outdoors (i.e. most of the map,
// most of the time) could actually see a "hidden" ghosted GM. If anything else ever
// needs its own invisibility tier, keep it below this value or update this comment.
#define GHOST_INVISIBILITY 2

mob
    var/image/ghostIcon
    var/isGhostform = FALSE
    var/icon/ghostFormIcon   // remembers appearance while ghosted, unrelated to the character's baseIcon

// Toggle ghostIcon form on/off
mob/proc/ToggleGhostForm()
    // Play the spell sound for everyone nearby. channel = SFX_CHANNEL (.dme), not
    // left unspecified — turns out an unspecified channel still interrupts channel 1
    // area music (PlayAreaMusic(), Area.dm) in this BYOND version, same issue found
    // and fixed for attack/hit/dodge sounds (CombatSystem.dm).
    PlaySFXAt(src, 'spell.WAV')

    if(isGhostform)
        // --- Exit ghostIcon form ---
        isGhostform = FALSE
        invisibility = 0
        density = 1
        overlays -= ghostIcon
        if(client) client.images -= ghostIcon
        ghostIcon = null
        icon = ghostFormIcon
        icon_state = "world"
        // Recompute the mundane see_invisible instead of hardcoding — matches
        // whatever the roof system (area/ceiling, Area.dm) would have set for a
        // normal mob standing here: 0 indoors (under a roof), 1 outdoors (so the
        // roof itself is visible). Ghost form had bumped this to GHOST_INVISIBILITY.
        // get_area() isn't available in this BYOND environment (confirmed earlier) —
        // T.loc (turf -> area) is the proven pattern used elsewhere (SaveSystem.dm,
        // InBattleArea() in CombatSystem.dm).
        var/turf/T = loc
        var/area/A = T ? T.loc : null
        see_invisible = istype(A, /area/ceiling) ? 0 : 1
        src << output("You reappear!", "Info")
    else
        // --- Enter ghostIcon form ---
        isGhostform = TRUE
        ghostFormIcon = icon
        icon = null
        invisibility = GHOST_INVISIBILITY
        // Bumping see_invisible to match (not just invisibility) means a ghosted mob
        // can also see OTHER ghosted mobs — builders can follow each other around
        // while both are ghosted, requested alongside this fix.
        see_invisible = GHOST_INVISIBILITY
        density = 0
        ghostIcon = image('phase.dmi', src)
        if(client) client.images += ghostIcon
        src << output("You disappear!", "Info")

// GM verb to toggle ghostIcon form — Admin-category power (Code/Admin/AdminLevels.dm)
mob/verb/GM_GhostForm()
    set category = "GM"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    ToggleGhostForm()

// -----------------------------
// GM Profanity Filter Toggle
// -----------------------------
// Flips adultServer (Code/Core/Main.dm) — TRUE disables the general-profanity list,
// leaving only banned_words_always (slurs/hate speech) enforced. Admin-category power.
mob/verb/GM_ToggleProfanityFilter()
    set category = "GM"
    set desc = "Turns the general-profanity filter (names/chat) on or off"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    adultServer = !adultServer
    src << output("Profanity filter is now [adultServer ? "OFF" : "ON"] (adultServer = [adultServer]).", "Info")

// -----------------------------
// GM Multi-Login Toggle
// -----------------------------
// Flips allowMultiLogin (Code/Core/Main.dm) — when ON, the address-based
// double-login block in client/New() is skipped entirely, letting a second client
// from the same machine connect as a non-GM (e.g. to be a GM_Ban/GM_Boot target)
// without needing a real second player. GMs/Host+ are already always exempt from
// that block regardless of this setting. Admin-category power, not a confirmed OG
// verb — this is purely a dev/testing convenience.
mob/verb/GM_ToggleMultiLogin()
    set category = "GM"
    set desc = "Turns the same-IP double-login block on or off (for testing with two clients)"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    allowMultiLogin = !allowMultiLogin
    src << output("Multi-login is now [allowMultiLogin ? "ALLOWED" : "BLOCKED"] (allowMultiLogin = [allowMultiLogin]).", "Info")

// -----------------------------
// GM Ban / Unban
// -----------------------------
// One combined verb instead of the OG's separate GMban/GMunban (Markdowns/
// GMCommandsReference.md) — a deliberate remake UX call, not a confirmed-OG
// behavior: a "Ban List" entry sits at the top of the same target picker, so
// undoing a ban doesn't need its own separate verb to hunt for. Bans are per-
// CHARACTER (one save slot), not per-account — the savefile and its other slots
// are untouched; the banned slot just can't be loaded anymore (ShowLoginMenu(),
// LoginMenu.dm) and stops saving the moment it's banned (skipSaveOnLogout,
// PlayerTemplate.dm), so stats freeze at whatever was last saved rather than
// getting erased (that's GM_Boot's — see below and GMCommandsReference.md's
// confirmed severity ordering: boot < pwipe < ban). Admin-tier power per the
// original design notes.
mob/verb/GM_Ban()
    set category = "GM"
    set desc = "Ban a connected player's character, or unban one from the ban list"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

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

    // Confirmed OG step — a reason prompt, shown to the target as their parting
    // message. Order matches the OG: reason prompt (its own OK/Cancel) first, then
    // the remake's own extra "are you sure?" as the final gate before it lands.
    var/reason = input(src, "Reason for banning [target.name] (shown to them):", "GM_Ban") as text|null
    if(isnull(reason)) return  // Cancel
    reason = length(trimtext(reason)) ? CensorText(trimtext(reason)) : "No reason given."

    var/confirm = alert(src, "Ban [target.name] ([target.key])? They will not be able to log back in with this character until unbanned.", "Confirm Ban", "Yes", "No")
    if(confirm != "Yes") return

    BanCharacter(target, reason)
    src << output("Banned [target.name] ([target.key]).", "Info")

// Shared "pick another connected player, respecting GM hierarchy" target list for
// GM_Ban/GM_Boot — confirmed OG rule: a lower (or equal) tier GM can't target
// someone at or above their own adminLevel, and you can never target yourself.
mob/proc/GetModerationTargets()
    var/list/targets = list()
    for(var/mob/player/P in players)
        if(P == src) continue
        if(!P.client) continue
        if(P.client.adminLevel >= client.adminLevel) continue
        targets["[P.name] ([P.key])"] = P
    return targets

// Bans live inside each player's own savefile (SetCharacterBanned(), SaveSystem.dm),
// not a central registry, so there's no in-memory list to just read — has to open
// every savefile in Player SaveFiles/ and check each slot. Cheap enough for how
// rarely this runs (GM-invoked, not per-tick). Confirmed OG fallback: an empty ban
// list shows a message instead of an empty picker.
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
        // Drop the reference now rather than waiting on BYOND's (non-immediate)
        // garbage collector — otherwise this handle can still be open, on the same
        // path, the moment something else (the unban write just below, or another
        // GM_Ban call) opens its own fresh savefile() on that same ckey.
        F = null

    if(!labelToTarget.len)
        src << output("Nobody is currently banned.", "Info")
        return

    var/list/options = labelToTarget.Copy()
    options += "Cancel"

    var/choice = input(src, "Select a banned character to unban:", "GM_Ban — Ban List") in options
    if(!choice || choice == "Cancel") return

    var/list/pick = labelToTarget[choice]
    var/datum/SaveManager/SM = new(pick[1])
    SM.SetCharacterBanned(pick[2], FALSE)
    // Same reasoning as the scan loop's F = null above — release this handle right
    // away instead of leaving it for GC to eventually get to.
    SM.Close()
    src << output("Unbanned [choice].", "Info")

// Flags the target's current save slot as banned and forces their client to
// disconnect right now. skipSaveOnLogout (PlayerTemplate.dm) stops that disconnect's
// own Logout()/SaveAndLogout() (Main.dm) from immediately re-saving an un-banned
// copy over the flag just set below.
mob/proc/BanCharacter(mob/player/target, reason)
    if(!target || !target.saveManager) return

    target.saveManager.SetCharacterBanned(target.saveSlot || 1, TRUE)
    target.skipSaveOnLogout = TRUE

    var/client/C = target.client
    if(C)
        target << output("You have been banned by a GM. Reason: [reason]", "Info")
        del(C)

// -----------------------------
// GM Boot
// -----------------------------
// Disconnects a player WITHOUT saving (skipSaveOnLogout, same mechanism as
// GM_Ban above) — the intentional punishment is reverting to their last save, not
// erasing the character outright (that's GMpwipe, not built yet). Same player-list/
// hierarchy pattern as GM_Ban, Admin-tier power per the original design notes.
mob/verb/GM_Boot()
    set category = "GM"
    set desc = "Disconnects a connected player without saving their progress"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    var/list/targets = GetModerationTargets()
    if(!targets.len)
        src << output("No one eligible to boot is connected.", "Info")
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
    src << output("Booted [target.name] ([target.key]).", "Info")

mob/proc/BootCharacter(mob/player/target)
    if(!target) return

    target.skipSaveOnLogout = TRUE
    var/client/C = target.client
    if(C)
        target << output("You have been booted by a GM.", "Info")
        del(C)

// -----------------------------
// GM Mute / Unmute
// -----------------------------
// Same combined-verb shape as GM_Ban — a "Mute List" entry at the top of the same
// target picker instead of a separate GMunmute verb (GMCommandsReference.md's own
// spec just says "pick a target, confirm", no reason prompt like GM_Ban's, since
// nothing forces a disconnect here for it to double as a parting message). isMuted
// (PlayerTemplate.dm) is session-only, same as before this verb existed — muting
// doesn't touch the savefile, so it doesn't survive a reconnect. CheckMuted()
// (SocialVerbs.dm) already enforces it on every chat verb; this is just what
// finally sets it on someone other than yourself. Admin-tier power per the
// original design notes.
mob/verb/GM_Mute()
    set category = "GM"
    set desc = "Mute a connected player's chat, or unmute one from the mute list"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

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
    // Deliberately NO message to the target — the OG's mute is silent ("You have
    // secretly muted X"), and DeliverChat() (SocialVerbs.dm) keeps echoing their own
    // chat back to them so nothing looks broken from their side. Telling them here
    // would defeat the entire mechanism.
    src << output("You have secretly muted [target.name] ([target.key]).", "Info")

// isMuted is session-only (no savefile field), so unlike ShowBanList this just
// scans the live `players` list instead of every savefile on disk.
mob/proc/ShowMuteList()
    var/list/labelToTarget = list()
    for(var/mob/player/P in players)
        if(!P.isMuted) continue
        labelToTarget["[P.name] ([P.key])"] = P

    if(!labelToTarget.len)
        src << output("Nobody is currently muted.", "Info")
        return

    var/list/options = labelToTarget.Copy()
    options += "Cancel"

    var/choice = input(src, "Select a muted player to unmute:", "GM_Mute — Mute List") in options
    if(!choice || choice == "Cancel") return

    var/mob/player/target = labelToTarget[choice]
    if(!target) return

    target.isMuted = FALSE
    // Silent on the target's side too, same reasoning as muting above — they were never
    // told it started, so telling them it ended would reveal it retroactively.
    src << output("You have secretly unmuted [choice].", "Info")

// -----------------------------
// GM Pwipe
// -----------------------------
// "Player wipe" — confirmed severity ordering (GMCommandsReference.md): GM_Boot
// (revert to last save) < GM_Pwipe (lose this character entirely) < GM_Ban (also
// can't log back in). No Pwipe List like GM_Ban's Ban List — a wiped character is
// just gone, there's nothing left afterward to reverse. Plain connected-player
// list via GetModerationTargets() (same hierarchy rule as Ban/Boot/Mute) plus an
// "All" entry at the bottom — gated to LEVEL_AEON only (AdminLevels.dm), checked
// both when building the option list AND again right before it executes, since
// Admin-tier alone is enough to open this verb at all.
mob/verb/GM_Pwipe()
    set category = "GM"
    set desc = "Permanently erase a connected player's character from their savefile"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    var/list/targets = GetModerationTargets()
    if(!targets.len)
        src << output("No one eligible to pwipe is connected.", "Info")
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
        src << output("Pwiped all [targets.len] connected player(s).", "Info")
        return

    var/mob/player/target = targets[choice]
    if(!target) return

    var/confirm = alert(src, "Permanently wipe [target.name] ([target.key])'s character? This cannot be undone.", "Confirm Pwipe", "Yes", "No")
    if(confirm != "Yes") return

    PwipeCharacter(target)
    src << output("Pwiped [target.name] ([target.key]).", "Info")

// Deletes the target's current save slot outright (DeleteCharacter(), SaveSystem.dm
// — same slot-prefix wipe GM_CreateObj/LoginMenu's own Delete Character option uses)
// and disconnects them. skipSaveOnLogout, same mechanism as GM_Ban/GM_Boot, stops
// SaveAndLogout() from writing a fresh copy back into the slot this just erased.
mob/proc/PwipeCharacter(mob/player/target)
    if(!target || !target.saveManager) return

    target.saveManager.DeleteCharacter(target.saveSlot || 1)
    target.skipSaveOnLogout = TRUE

    var/client/C = target.client
    if(C)
        target << output("Your character has been permanently wiped by a GM.", "Info")
        del(C)

// -----------------------------
// GM Name Change
// -----------------------------
// Confirmed OG spec (GMCommandsReference.md): broader target scope than the
// player-only pickers above — players AND mobs (NPCs/monsters), so a GM can rename
// wildlife too, not just people. Player half reuses GetModerationTargets() (same
// hierarchy/self-exclusion rule as Ban/Boot/Mute/Pwipe); mob half is just every
// non-player mob currently in the GM's view — there's no "pick a nearby obj/mob"
// primitive yet to reuse (GMdelobjmob isn't built), so view(src) is the simplest
// "what can I actually see to click on" scope. Same name validation as character
// creation (PromptForName(), LoginMenu.dm) — reject outright via IsTextFiltered()
// rather than censoring, so a GM can't accidentally leave a half-asterisked name.
// Confirmed persistence: this is a live mob.name change, so a renamed player's next
// save (including a normal logout autosave) writes the new name permanently — no
// separate "make it stick" step. GM-tier power per the original design notes.
#define MAX_NAME_LENGTH 24
mob/verb/GM_NameChange()
    set category = "GM"
    set desc = "Rename a connected player's character, or any NPC/monster in view"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/list/targets = GetModerationTargets()
    for(var/mob/M in view(src))
        if(istype(M, /mob/player)) continue
        targets["[M.name] ([M.type])"] = M

    if(!targets.len)
        src << output("No one eligible to rename is connected or in view.", "Info")
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
    src << output("Renamed [oldName] to [newName].", "Info")
    if(target.client)
        target << output("A GM renamed you to [newName].", "Info")

// -----------------------------
// GM Create Obj
// -----------------------------
// Creates any of the game's functional world objects at the GM's own location — not
// mouse-placed like GM_MakeTurf/GM_MakeMob/GM_MakeArea, since several of these need a
// per-instance text prompt right at creation (a lockable's name, a sign's message) that
// doesn't fit a click-to-place flow. Builder-category power (world content creation),
// not Admin. NPC included per its own comment (Code/World/NPCs.dm) — no dialogue/AI
// yet, just a placeable placeholder body for now. World Login Point/Respawn Point
// (obj/spawnMarker/playerStart, /playerSpawn — Area.dm) need no per-instance prompt,
// just placement — this is how a host actually sets their world's spawn/respawn spots
// (GetPlayerSpawnTurf()/GetRespawnTurf(), Area.dm) instead of a hardcoded coordinate.
mob/verb/GM_CreateObj()
    set category = "GM"
    set desc = "Creates a functional obj (or a placeholder NPC) at your location"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    var/list/choices = list(
        "Door" = /obj/door,
        "Bookcase" = /obj/stat/bookcase,
        "Pot" = /obj/stat/pot,
        "Drawers" = /obj/stat/drawers,
        "Sign" = /obj/stat/sign,
        "NPC" = /mob/npc,
        "World Login Point" = /obj/spawnMarker/playerStart,
        "Respawn Point" = /obj/spawnMarker/playerSpawn,
    )

    var/choice = input(src, "Choose what to create:", "GM_CreateObj") in choices
    if(!choice) return
    var/pickedType = choices[choice]

    if(pickedType == /mob/npc)
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
        src << output("Created [choice].", "Info")

// Door skins (wooden/jail/dw1/silver/gold/snow/ice, each with a night variant) are all
// one real type (obj/door, Code/World/Obj.dm) painted as different icon_state
// instances — same collapse convention as turfs, so GetCachedIconStates()
// (Code/Combat/CombatSystem.dm) reads door.dmi directly instead of a hardcoded list.
// "open" excluded — that's the shared mid-interaction sprite every skin swaps to on
// open() (Obj.dm), not a selectable skin. Night split matches GM_MakeTurf's.
mob/proc/CreateDoor(doorType, choiceLabel)
    var/list/states = GetCachedIconStates(initial(doorType:icon))
    states -= "open"

    var/list/dayStates = list()
    var/list/nightStates = list()
    for(var/s in states)
        if(IsNightVariant(s)) nightStates += s
        else dayStates += s

    var/list/finalStates = dayStates
    if(nightStates.len)
        var/period = input(src, "Day or Night door skin?", "GM_CreateObj") in list("Day", "Night")
        finalStates = (period == "Night") ? nightStates : dayStates

    var/skin = input(src, "Choose a door skin:", "GM_CreateObj") in finalStates
    CreateLockable(doorType, choiceLabel, skin)

// Creates a lockable object and its matching key together in one step, so they can't
// get out of sync. lockableType is only known at runtime (chosen from GM_CreateObj's
// input), so the compiler can't statically verify "name"/"is_locked"/"closed_icon_state"
// exist on it — set them dynamically via vars[] instead, same pattern already used in
// StatAllocation() in Code/UI/LoginMenu.dm. Typed as /atom (not left bare) so the
// compiler knows it has a vars[] list at all — every future lockable type will still be
// some kind of atom. icon_state itself IS a builtin /atom var (unlike the other two),
// so that one's set directly rather than through vars[].
mob/proc/CreateLockable(lockableType, choiceLabel, skin = null)
    var/lockName = input(src, "Name this [choiceLabel] (a matching key will be created too):", "Name It") as text|null
    if(isnull(lockName) || !length(trimtext(lockName)))
        src << output("Cancelled — no name given.", "Info")
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
        src << output("Created [lockName], but your inventory was full — no key was given!", "Info")
        return

    src << output("Created a locked [lockName] and put its key in your inventory.", "Info")

// Signs are otherwise plain (Code/World/Obj.dm) except for their per-instance message
// var — set it right at creation instead of leaving it at the default "..." (its own
// comment already called out a GM-creation verb setting this per-instance).
mob/proc/CreateSign()
    var/message = input(src, "What should this sign say?", "Sign Message") as text|null
    if(isnull(message) || !length(trimtext(message))) message = "..."
    else message = CensorText(trimtext(message))

    var/obj/stat/sign/newSign = new(loc)
    newSign.message = message
    src << output("Created a sign.", "Info")

// icon_state offered here comes straight from npc.dmi's own real sprite set
// (GetCachedIconStates(), Code/Combat/CombatSystem.dm) — merchant/guard/priest/etc. —
// not hardcoded, so a new sprite added to the file is selectable immediately.
mob/proc/CreateNPC()
    var/list/states = GetCachedIconStates('npc.dmi')
    if(!states.len)
        src << output("No NPC sprites found.", "Info")
        return
    var/stateChoice = input(src, "Choose an NPC appearance:", "GM_CreateObj") in states

    var/npcName = input(src, "Name this NPC:", "Name It") as text|null
    npcName = (isnull(npcName) || !length(trimtext(npcName))) ? Capitalize(stateChoice) : CensorText(trimtext(npcName))

    var/mob/npc/newNPC = new(loc)
    newNPC.icon_state = stateChoice
    newNPC.name = npcName

    src << output("Created [npcName] the NPC.", "Info")

// -----------------------------
// GM Day/Night Toggle
// -----------------------------
// Appends/strips the "night" suffix on one atom's icon_state — shared by both the
// turf and obj loops below, which used to each duplicate this logic once per
// direction (4 near-identical blocks total). IsNightVariant() (Code/Core/Main.dm) is
// the shared "does this end in the night suffix" check.
proc/ToggleNightIconState(atom/A, toNight)
    if(!A.icon_state) return
    if(toNight)
        A.icon_state += "night"
    else if(IsNightVariant(A.icon_state))
        A.icon_state = copytext(A.icon_state, 1, length(A.icon_state) - 4)

// Swaps every turf/obj's icon_state to its night variant and back. Confirmed OG
// convention: night states are just the day icon_state with "night" appended directly
// (e.g. "redcobble" -> "redcobblenight"), no separator, and it's world-icons only —
// mobs don't have night sprites. GM-tier power (both Builder+Admin combined), not
// Admin or Builder alone.
mob/verb/GM_DayNight()
    set category = "GM"
    set desc = "Toggles day/night for every turf and obj in the world"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    isNight = !isNight

    for(var/turf/T in world)
        ToggleNightIconState(T, isNight)
    for(var/obj/O in world)
        if(istype(O, /obj/StatLink)) continue
        ToggleNightIconState(O, isNight)

    world << output("[src] has turned it to [isNight ? "night" : "day"].", "Info")

// -----------------------------
// GM Log Toggle
// -----------------------------
// Flips loggingEnabled (Code/Core/TextFilter.dm) — gates LogChat()'s own lines (chat,
// login/logout, double-login) only. world.log's automatic connect/disconnect/host
// events keep writing to server.log regardless — that's the engine, not this. GM-tier
// power, not Admin, since it's about who can talk without being logged, not general
// server admin — players never see this verb at all (not just gated on use).
mob/verb/GM_ToggleLog()
    set category = "GM"
    set desc = "Turns chat/login logging (server.log) on or off"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    loggingEnabled = !loggingEnabled
    src << output("Chat/login logging is now [loggingEnabled ? "ON" : "OFF"].", "Info")

// -----------------------------
// GM Level Increase
// -----------------------------
// Was Test_Leveling() (DebugTools.dm) — added a huge pile of Exp and hoped
// LevelCheck() (CombatSystem.dm) would trigger. Directly applies the same
// side effects LevelCheck() does on a real level-up (StatPoints, RecalculateVitals())
// instead, so this actually increases Level rather than just being a shortcut to it.
// GM-tier power, matching the confirmed OG command name.
mob/verb/GM_LevelIncrease()
    set category = "GM"
    set desc = "Increases your level by a chosen amount, same as leveling up normally"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/amount = input(src, "How many levels to add?", "GM_LevelIncrease", 1) as num
    if(isnull(amount) || amount < 1) return
    amount = round(amount)

    // Same per-level side effects as a real level-up, just repeated — RecalculateVitals()
    // (Code/Player/StatsDatum.dm) tops up HP/MP by however much Max just grew each time,
    // so looping it is equivalent to a real level-up chain, not a single jump.
    for(var/i = 1 to amount)
        Level += 1
        StatPoints += 5
        RecalculateVitals()

    src << output("You are now Level [Level] (+[amount])", "Info")
    src << sound('levelup.wav', channel = 2, volume = client.ScaledVolume())

// -----------------------------
// GM Battle Mode Toggle
// -----------------------------
// Toggles whether attacks/skills are allowed in a specific area instance — see
// battleModeOn on the base area type (Code/World/Area.dm) and InBattleArea()
// (Code/Combat/CombatSystem.dm), which checks it. GM-tier power, matching the
// original design notes.
mob/verb/GM_BattleMode()
    set category = "GM"
    set desc = "Toggles battle mode for one area, or every area at once"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

    var/list/areaChoices = list("None" = null, "All Areas" = "ALL")
    for(var/area/A in world)
        areaChoices["[A.name] ([A.type])"] = A

    var/choice = input(src, "Choose an area to toggle battle mode (or All Areas):", "GM_BattleMode") in areaChoices
    var/selection = areaChoices[choice]
    if(!selection) return  // "None" selected, cancel

    if(selection == "ALL")
        // Global override, same shape as GM_DayNight() above — disregards each area
        // type's own default (Area.dm) while active.
        battleModeGlobalOn = !battleModeGlobalOn
        for(var/area/A in world)
            A.battleModeOn = battleModeGlobalOn
        world << output("[src] has turned battle mode [battleModeGlobalOn ? "ON" : "OFF"] everywhere.", "Info")
    else
        var/area/target = selection
        target.battleModeOn = !target.battleModeOn
        src << output("[target.name] is now [target.battleModeOn ? "a dangerous area" : "a peaceful area"].", "Info")

// -----------------------------
// GM Kill Monsters
// -----------------------------
// Kills monsters through the real death pipeline (Die()/CleanUpDead(), CombatSystem.dm)
// instead of a raw del() — so they play the actual hit sound, get the "sleep" icon_state
// knockout pose Die() sets on every enemy death, credit src with exp/gold same as a real
// kill, and linger as a corpse for CleanUpDead()'s normal delay before disappearing,
// exactly like dying in combat. Deliberately skips TakeDamage()'s RollDodge()/damage
// math though — this is meant to always land ("Overpowered attack that instant kills"),
// not be a normal attack that can whiff or get reduced by defending.
//
// "All option at the top, then every real type" shape matches GM_BattleMode's own area
// list above. Monster type entries reuse GetTypeChoices(/mob/enemy)
// (Code/Admin/Commands/BuildTools.dm) — the same typesof()-driven list GM_MakeMob
// builds its picker from — rather than re-deriving the type/display-name list here.
// Destructive world-wide action, so GM-tier power like GM_DayNight/GM_BattleMode, not
// just Builder-tier.
mob/verb/GM_KillMonsters()
    set category = "GM"
    set desc = "Instantly kills monsters through the real death process, by type or all at once"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

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

// -----------------------------
// GM World Reboot
// -----------------------------
// Confirmed OG flow (GMCommandsReference.md): big red announcement, then a big red
// countdown, then save everyone and restart. **Not copied**: the OG's own post-reboot
// reconnect left every client on a black screen — client/mob never got a fresh
// Login() call, since world.Reboot() doesn't do that on its own. world/Reboot()
// (Main.dm) is a from-scratch fix for that specific gap: after the engine wipes and
// reinitializes, every still-connected client gets a brand-new mob/playerTemp and an
// explicit Login() call, same as if they'd just connected. GM-Host tier — the most
// destructive single action in the whole toolkit (everyone's session ends, the map
// resets to its compiled state), matching GM_DayNight/GM_BattleMode/GM_KillMonsters.
mob/verb/GM_WorldReboot()
    set category = "GM"
    set desc = "Saves everyone, then reboots the world after a 10-second countdown"

    if(!client || client.adminLevel < LEVEL_GM_HOST)
        src << output("You don't have GM access.", "Info")
        return

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

// -----------------------------
// GM See Areas Toggle
// -----------------------------
// Overlays each turf CURRENTLY IN VIEW with its own area's icon/icon_state from
// Code/World/Area.dm (e.g. "town", "townrain", "bar") so a GM can see area
// boundaries at a glance — reuses the icon/icon_state areas already have, no
// separate grid asset needed. Builder-tier power, matching the original design notes.
// Originally snapshotted every turf in the WHOLE WORLD once on toggle — even batched
// across ticks to avoid a one-time freeze, that still left potentially thousands of
// persistent /image objects permanently tracked on one client, which the renderer has
// to composite every single frame regardless of whether they're on-screen. That's the
// actual ongoing lag source, not just the build loop. Now only builds images for a
// small area around the GM (see AREA_OVERLAY_RADIUS below) and refreshes via a
// polling loop (AreaOverlayLoop(), same shape as other loops in this codebase —
// client/MoveLoop() etc.) whenever they actually move to a new tile, so the image
// count stays small and bounded instead of scaling with map size.

// The GM's own view is 13x13 (world.view, Main.dm) — 6 tiles out from center each
// way. Padded a few tiles past that so the overlay is already built for tiles just
// off-screen before the GM actually walks into view of them — masks
// AreaOverlayLoop()'s up-to-half-second refresh delay behind a buffer instead of
// visible pop-in right at the screen edge. Update if world.view's size ever changes.
#define AREA_OVERLAY_BUFFER 3
#define AREA_OVERLAY_RADIUS (6 + AREA_OVERLAY_BUFFER)

mob/var/list/areaOverlayImages
mob/var/seeingAreas = FALSE
mob/var/turf/areaOverlayLastLoc

mob/verb/GM_SeeAreas()
    set category = "GM"
    set desc = "Toggles a visual overlay showing which area each tile belongs to"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    seeingAreas = !seeingAreas

    if(seeingAreas)
        areaOverlayLastLoc = null  // force RefreshAreaOverlay() to build on the first tick
        AreaOverlayLoop()
        src << output("Area overlay is now ON.", "Info")
    else
        if(areaOverlayImages)
            client.images -= areaOverlayImages
            areaOverlayImages = null
        src << output("Area overlay is now OFF.", "Info")

// Polls while seeingAreas is on, rebuilding the overlay only when the GM has actually
// moved to a new tile — skips redundant rebuilds while standing still.
mob/proc/AreaOverlayLoop()
    set waitfor = 0
    while(seeingAreas && client)
        if(loc != areaOverlayLastLoc)
            areaOverlayLastLoc = loc
            RefreshAreaOverlay()
        sleep(5)  // check twice a second — cheap since each rebuild is viewport-sized

// Rebuilds areaOverlayImages for a small padded area around the GM (AREA_OVERLAY_RADIUS
// above — deliberately bigger than the actual viewport), swapping out the old set for
// the new one on the client in one shot. range(), not view() — this intentionally
// covers tiles beyond what's currently on-screen, and view() would cap at the client's
// actual visible/line-of-sight area instead.
mob/proc/RefreshAreaOverlay()
    if(!client) return

    var/list/newImages = list()
    for(var/turf/T in range(AREA_OVERLAY_RADIUS, src))
        var/area/A = T.loc
        if(A && A.icon_state)
            // A.icon, not a hardcoded 'environment.dmi' — every ordinary area's icon
            // IS 'environment.dmi' (base area type, Area.dm) so this changes nothing
            // for them, but a future area with its own distinct icon file would
            // otherwise render as a missing/wrong sprite under this overlay.
            var/image/areaImg = image(A.icon, T, A.icon_state)
            // Layer 3 (below mobs' default 4, above turfs' default 2) — a plain
            // image() otherwise defaults above mobs, which meant standing on a
            // marked tile drew the overlay ON TOP of the GM's own sprite.
            areaImg.layer = 3
            newImages += areaImg

        // World login/respawn markers (obj/spawnMarker/playerStart, /playerSpawn —
        // Area.dm) are invisible to everyone normally (that's the whole point — a
        // turf's real area, e.g. Town, stays untouched by them) and drawn here as an
        // ADDITIONAL layer on top of the tile's own area color above, not instead of
        // it, confirming "can only be seen as an area for GMs" without ever actually
        // reassigning the tile's area.
        for(var/obj/spawnMarker/M in T.contents)
            var/image/markerImg = image(M.icon, T, M.icon_state)
            markerImg.layer = 3
            newImages += markerImg

    if(areaOverlayImages)
        client.images -= areaOverlayImages
    client.images += newImages
    areaOverlayImages = newImages