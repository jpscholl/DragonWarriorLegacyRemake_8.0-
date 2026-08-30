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

    // Releases this instance's file handle — call once a character's session is
    // truly over (SaveAndLogout(), Main.dm). Without this, F stays open in memory
    // for the rest of the server's life (mobs aren't garbage-collected on logout,
    // just pulled out of `players`), and a second /savefile opened on the same path
    // later (GM_Ban's Ban List scan, GMCommands.dm) can read a stale cached copy
    // from before this session's last write — confirmed: a just-banned character
    // wasn't showing up in the Ban List until a full server restart.
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

        // Skills aren't part of the save blob (Code/Save/SaveData.dm) — re-equip the
        // starting kit every load, same as a fresh character, per its own
        // GetStartingKit() (Code/Player/SkillUnlocks.dm).
        newPlayer.EquipStartingKit()

        // Apply saved snapshot to the mob
        D.ApplyToCharacter(newPlayer)

        // Recreate carried items (Code/Save/SaveData.dm) — after stats are set above,
        // since re-equipping a saved amulet calls RecalculateVitals().
        D.ApplyInventory(newPlayer)

        // Re-sync any leveled unlocks already earned before this player last
        // disconnected — silent, since these were already learned, not just-now. MUST
        // run after ApplyToCharacter() above, not before — CheckSkillUnlocks() reads
        // Level/stats off the mob, which are still fresh-mob defaults (Level 1,
        // Strength 1, etc.) until ApplyToCharacter() sets them from the save. Running
        // it too early is exactly why a Fireball learned mid-session was vanishing on
        // relog: the unlock check always failed against default stats.
        newPlayer.CheckSkillUnlocks(silent = TRUE)

        // Restore the player's own numpad slot arrangement (Code/Player/SkillLink.dm's
        // drag-and-drop) — must run LAST, after every skill it could reference is
        // actually known (starting kit above, plus whatever CheckSkillUnlocks() just
        // re-granted).
        D.ApplySkillSlots(newPlayer)

        // Full mana on login, every time — not just whatever was saved.
        newPlayer.MP = newPlayer.MaxMP

        // Rebuild palette & apply saved colors
        newPlayer.palette = new /datum/PaletteManager(
            newPlayer.class,
            newPlayer.basePlayerIcon
        )

        if(newPlayer.hairColor)   newPlayer.palette.SetZoneColor("Hair", newPlayer.hairColor)
        if(newPlayer.eyeColor)    newPlayer.palette.SetZoneColor("Eyes", newPlayer.eyeColor)
        if(newPlayer.mainColor)   newPlayer.palette.SetZoneColor("Main", newPlayer.mainColor)
        if(newPlayer.accentColor) newPlayer.palette.SetZoneColor("Accent", newPlayer.accentColor)

        // Finally, rebuild the icon with applied palette/colors
        newPlayer.RebuildIcon()

        // Stop the login-menu music before handing control to the real character
        M << sound(null, channel = 1)

        // Transfer client control. Grab the client ref BEFORE reassigning client.mob —
        // once that reassignment happens, the engine clears M's own .client (M is no
        // longer that client's mob), so "M.client.SyncGMVerbs()" after would be
        // null.SyncGMVerbs(), aborting the proc before newPlayer.loc got set below and
        // leaving newPlayer stuck at the default (1,1,1) spawn. Same pattern already
        // used in FinalizePlayer() (LoginMenu.dm).
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

        var/area/spawnArea = newPlayer.loc?.loc
        if(spawnArea && spawnArea.areaMusic)
            newPlayer.PlayAreaMusic(spawnArea.areaMusic)

        players += newPlayer
        del M

        return 1

    // -----------------------------
    // Delete a character slot
    // -----------------------------
    proc/DeleteCharacter(slot)
        if(slot < 1 || slot > MAX_CHARACTERS) return 0

        var/prefix = "char[slot]."

        for(var/key in F.dir)
            if(findtext(key, prefix) == 1)
                F[key] = null

        F.Flush()
        return 1

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
mob/player/proc/RebuildIcon()
    if(!baseIcon)
        return src

    // NOTE: must be "new /icon(...)" with the leading slash, not "new icon(...)".
    // Every atom has a built-in var also named "icon" (this mob's own sprite, set
    // below) — without the slash, DM resolves the bare word to that var (null on a
    // freshly loaded mob) instead of the /icon type, and crashes trying to
    // instantiate type null.
    var/icon/playerIcon = new /icon(baseIcon)

    if(!playerIcon)
        src << output("ERROR: Failed to load icon [baseIcon]", "Info")
        return src

    // Recoloring only takes effect for icons that have real default-color data in
    // DefaultIconColors (Code/Player/Customization/PlayerIconColorPalette.dm) — right
    // now that's just Hero's dw3hero.dmi. Everything else just shows its plain sprite.
    var/list/zones = list("Hair", "Eyes", "Main", "Accent")

    for(var/zone in zones)
        var/baseColor = palette?.originalColors[zone]
        var/replaceColor = null

        switch(zone)
            if("Hair")
                replaceColor = hairColor

            if("Eyes")
                replaceColor = eyeColor

            if("Main")
                replaceColor = mainColor

            if("Accent")
                replaceColor = accentColor

        if(baseColor && replaceColor)
            playerIcon.SwapColor(baseColor, replaceColor)

    icon = playerIcon
    UpdateAppearance()

    return src
