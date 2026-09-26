// -----------------------------
// SaveManager datum
// Handles saving/loading/deleting up to 4 characters per player
// -----------------------------
datum/SaveManager
    var/savefile/F  // BYOND savefile object

    // -----------------------------
    // Constructor: Open or create savefile for a given player key
    // -----------------------------
    New(ckey)
        // Ensure the directory exists in your project: "Player SaveFiles/"
        F = new("Player SaveFiles/[ckey].sav")

    // Releases this instance's file handle — call once a character's session is truly
    // over. Without this, a second /savefile opened on the same path later (GM_Ban's
    // Ban List scan) could read a stale cached copy from before this session's last
    // write — confirmed: a just-banned character wasn't showing up in the Ban List
    // until a full server restart.
    proc/Close()
        F = null

    // -----------------------------
    // Volume settings — stored at the ckey level (this same F), not per character
    // slot, since login music (mob/playerTemp/Login(), Main.dm) plays before any
    // slot is picked and needs a volume to use immediately.
    // -----------------------------
    proc/LoadVolumeSettings(client/C)
        var/m, mu, sfx
        F["volume.master"] >> m
        F["volume.music"]  >> mu
        F["volume.sfx"]    >> sfx
        C.masterVolume = isnull(m)   ? DEFAULT_MASTER_VOLUME  : m
        C.musicVolume  = isnull(mu)  ? DEFAULT_CHANNEL_VOLUME : mu
        C.sfxVolume    = isnull(sfx) ? DEFAULT_CHANNEL_VOLUME : sfx

    proc/SaveVolumeSettings(client/C)
        F["volume.master"] << C.masterVolume
        F["volume.music"]  << C.musicVolume
        F["volume.sfx"]    << C.sfxVolume
        F.Flush()

    // -----------------------------
    // Save a player's data to a specific slot (1-4)
    // -----------------------------
    proc/SaveCharacter(mob/player/M, slot)
        if(slot < 1 || slot > MAX_CHARACTERS) return 0
        var/key = "char[slot]"

        var/datum/CharacterSaveData/D = new
        D.BuildFromCharacter(M)

        // Save metadata separately (optional but nice)
        F["[key].name"] << M.name

        // Save whole blob
        F["[key].data"] << D

        F.Flush()
        return 1


// -----------------------------
// Load a player's data from a specific slot (1-4)
// Returns 1 on success, 0 on failure
// -----------------------------
    proc/LoadCharacter(mob/playerTemp/M, slot)
        if(slot < 1 || slot > MAX_CHARACTERS) return 0
        var/key = "char[slot]"

        // Load the saved snapshot
        var/datum/CharacterSaveData/D
        F["[key].data"] >> D
        if(!D) return 0

        // Spawn the correct player mob — GetPlayerClassType() (PlayerTemplate.dm) is
        // the one place the name->type switch lives now.
        var/mob/player/newPlayer
        var/type = GetPlayerClassType(D.class)
        if(type) newPlayer = new type
        if(!newPlayer) return 0

        newPlayer.isCharacter = TRUE
        newPlayer.saveSlot = slot
        newPlayer.saveManager = src

        // Re-equip the starting kit every load, same as a fresh character, per its own
        // GetStartingKit() (Code/Player/SkillUnlocks.dm) -- so a kit change reaches
        // existing characters too.
        newPlayer.EquipStartingKit()

        // Apply saved snapshot to the mob
        D.ApplyToCharacter(newPlayer)

        // Recreate carried items (Code/Save/SaveData.dm) — after stats are set above,
        // since re-equipping a saved amulet calls RecalculateVitals().
        D.ApplyInventory(newPlayer)

        // Re-sync any leveled unlocks already earned before disconnecting — silent,
        // since these were already learned. MUST run after ApplyToCharacter() above:
        // CheckSkillUnlocks() reads Level/stats off the mob, which are still fresh-mob
        // defaults until ApplyToCharacter() sets them from the save — running it too
        // early is exactly why a Fireball learned mid-session was vanishing on relog.
        newPlayer.CheckSkillUnlocks(silent = TRUE)

        // Whatever else they knew -- skills a reclass carried over (SaveData.dm).
        D.ApplyKnownSkills(newPlayer)

        // Restore the numpad slot arrangement — must run LAST, after every skill it
        // could reference is actually known.
        D.ApplySkillSlots(newPlayer)

        // Recompute the maxima from the loaded stats instead of trusting the ones in the
        // save. ApplyToCharacter() restores MaxHP/MaxMP verbatim, so a returning
        // character kept whatever those were the day they logged out — which goes stale
        // the moment the HP formula changes, as it did when SetMaxHP()'s real power-law
        // curve replaced the old linear one. This only happened to work before for
        // characters wearing an amulet, since equipping one calls RecalculateVitals() as
        // a side effect; everyone else kept the old numbers indefinitely.
        //
        // RecalculateVitals() tops current HP up by however much the max GREW but never
        // trims it, so the clamp below covers a recompute that shrank the max instead.
        newPlayer.RecalculateVitals()
        newPlayer.HP = min(newPlayer.HP, newPlayer.MaxHP)
        // Logged out while dead: isDead isn't saved, so they'd load "alive" at 0 HP --
        // which TakeDamage() and regen both treat as a corpse, leaving them unhittable
        // and never healing. They come back respawned instead.
        if(newPlayer.HP <= 0) newPlayer.HP = newPlayer.MaxHP

        // Full mana on login, every time — not just whatever was saved.
        newPlayer.MP = newPlayer.MaxMP

        // Rebuild palette from the saved picks, then repaint from the live art
        newPlayer.palette = new /datum/PaletteManager(newPlayer.basePlayerIcon, newPlayer.zoneColors)
        newPlayer.RebuildIcon()

        // Stop the login-menu music before handing control to the real character
        M << sound(null, channel = 1)

        // Grab the client ref BEFORE reassigning client.mob — once that happens the
        // engine clears M's own .client, so "M.client.SyncGMVerbs()" after would be
        // null.SyncGMVerbs(), aborting the proc before newPlayer.loc got set below.
        // Same pattern as FinalizePlayer() (LoginMenu.dm).
        var/client/C = M.client
        C.mob = newPlayer
        // The new mob's own verb list starts fresh from its type declaration (includes
        // GM-only verbs like GM_ToggleLog by default) — re-sync (AdminLevels.dm) so a
        // non-GM's removal carries over from the old temp mob.
        C.SyncGMVerbs()

        // GM_SaveLocation (GMCommands.dm) — restore the exact spot this character was
        // last saved at instead of the usual spawn point, when the world-wide toggle
        // is on and a real saved position exists (locate() returns null for garbage
        // coordinates or a Z-level that no longer exists, so this falls back safely).
        var/turf/restoreTurf = (saveLocationEnabled && D.savedX) ? locate(D.savedX, D.savedY, D.savedZ) : null
        newPlayer.loc = restoreTurf || GetPlayerSpawnTurf()
        C.AttachCamera(newPlayer)  // camera (SmoothMovement.dm) takes over as eye from here on

        newPlayer.PlayMusicForArea(newPlayer.loc?.loc)

        players += newPlayer
        del M

        return 1

    // -----------------------------
    // Delete a character slot
    // -----------------------------
    // Confirmed 2026-09-09 UX decision: deleting slot 1 while 2/3/4 are occupied should
    // leave them at 1/2/3, not leave a gap at 1 -- every later slot shifts down to keep
    // filled slots contiguous starting at 1. MoveCharacterSlot() below moves the
    // ".banned" key along with ".name"/".data", so a ban follows the character it was
    // actually on, not the slot number (matters for ShowBanList(), GMCommands.dm, which
    // reads bans straight off slot number on demand).
    //
    // Deliberately a cascade, low slot to high, each writing into the slot the
    // PREVIOUS iteration just finished reading out of: slot [slot+1] -> [slot], then
    // [slot+2] -> [slot+1], etc. Every slot except the very last one in the chain gets
    // fully overwritten by the next iteration (or by nulls, if that next source slot
    // was empty) -- MoveCharacterSlot() doesn't need to (and must NOT, see its own
    // comment) separately clear the slot it just read from. Only the true tail end
    // (char[MAX_CHARACTERS], never anyone's destination) needs the explicit cleanup
    // below.
    proc/DeleteCharacter(slot)
        if(slot < 1 || slot > MAX_CHARACTERS) return 0

        for(var/i = slot to MAX_CHARACTERS - 1)
            MoveCharacterSlot(i + 1, i)

        var/prefix = "char[MAX_CHARACTERS]."
        for(var/key in F.dir)
            if(findtext(key, prefix) == 1)
                F[key] = null

        F.Flush()
        return 1

    // Copies the "char[fromSlot]" entry onto "char[toSlot]" (.data/.name/.banned),
    // reading each into its ACTUAL type rather than a generic untyped var via an F.dir
    // scan -- an untyped read/write round-trip of ".data" was silently losing the
    // /icon nested inside its CharacterSaveData blob (confirmed 2026-09-09).
    //
    // Deliberately does NOT clear fromSlot afterward. It used to (immediately null it
    // right after copying out), which looked safe in isolation but broke on a 3-slot
    // cascade: deleting slot 1 correctly moved 2->1, then 3->2 silently lost its icon
    // — the second move's destination (slot 2) was exactly the slot the FIRST move had
    // just nulled moments earlier, and a flush() in between didn't fix it either. Root
    // cause not fully pinned down (a savefile quirk around immediately rewriting a
    // just-cleared key, near as testing narrowed it), but DeleteCharacter()'s cascade
    // never actually needs this proc to self-clean: every slot but the true tail gets
    // fully overwritten by the next call in the chain anyway (or by nulls, if that next
    // source was itself empty), and the tail is handled once, explicitly, in
    // DeleteCharacter() itself. Safe to call with an empty fromSlot -- writes nulls
    // through, which correctly empties toSlot too (GetCharacterSlots() treats a null
    // .name as unoccupied). Params aren't named from/to -- `to` is a reserved DM
    // keyword (for(x = a to b)) and broke compilation.
    proc/MoveCharacterSlot(fromSlot, toSlot)
        var/datum/CharacterSaveData/D
        F["char[fromSlot].data"] >> D

        var/charName
        F["char[fromSlot].name"] >> charName

        var/banned
        F["char[fromSlot].banned"] >> banned

        F["char[toSlot].data"] << D
        F["char[toSlot].name"] << charName
        F["char[toSlot].banned"] << banned

    // -----------------------------
    // Ban / unban a single character slot (GM_Ban, GMCommands.dm)
    // -----------------------------
    // Stored as metadata alongside "[key].name" rather than inside the
    // CharacterSaveData blob, same reasoning as the name field: checking/flipping ban
    // status shouldn't require deserializing the whole save. The slot's actual data
    // is never touched by this — banning freezes progress, it doesn't erase it.
    proc/SetCharacterBanned(slot, banned)
        if(slot < 1 || slot > MAX_CHARACTERS) return
        F["char[slot].banned"] << banned
        F.Flush()

    proc/IsCharacterBanned(slot)
        if(slot < 1 || slot > MAX_CHARACTERS) return FALSE
        var/banned
        F["char[slot].banned"] >> banned
        return banned || FALSE

    // -----------------------------
    // Return a list of filled character slots with names
    // -----------------------------
    proc/GetCharacterSlots()
        var/list/out = list()
        for(var/i = 1 to MAX_CHARACTERS)
            var/name
            F["char[i].name"] >> name
            if(name)
                out["[i]"] = name
        return out

// -----------------------------
// Rebuild the player's icon after loading or recoloring
// -----------------------------
// Rebuilds this character's sprite from scratch: resolve the saved icon id back to its
// LIVE art (PlayerIconColorPalette.dm), then paint on only the zone colors this player
// actually chose. Nothing here reads a stored sprite, so repainting a .dmi — or fixing a
// zone's color in the registry — shows up on the next login for every character wearing
// that icon, instead of only for ones created afterward.
mob/player/proc/RebuildIcon()
    var/datum/PlayerIcon/entry = GetPlayerIcon(basePlayerIcon)

    // Re-resolved every time rather than trusted from before, so the art is always
    // whatever the registry points at today. baseIcon keeps its previous value only as
    // the pre-rework fallback MigrateLegacyAppearance() (SaveData.dm) may have set.
    if(entry)
        baseIcon = entry.file

    if(!baseIcon)
        src.ShowInfo("ERROR: no registered art for icon [basePlayerIcon]")
        return src

    // NOTE: must be "new /icon(...)" with the leading slash, not "new icon(...)".
    // Every atom has a built-in var also named "icon" (this mob's own sprite, set
    // below) — without the slash, DM resolves the bare word to that var (null on a
    // freshly loaded mob) instead of the /icon type, and crashes trying to
    // instantiate type null.
    var/icon/playerIcon = new /icon(baseIcon)

    if(!playerIcon)
        src.ShowInfo("ERROR: Failed to load icon [basePlayerIcon]")
        return src

    // Same painter the creation preview uses (ColorSwap.dm), so what a player sees while
    // customizing is exactly what they get in the world.
    ApplyZoneColors(playerIcon, entry, zoneColors)

    icon = playerIcon
    UpdateAppearance()

    return src
