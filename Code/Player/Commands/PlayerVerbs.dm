// Reachable both from the Action tab and File > Help (Interface.dmf) — a menu command
// still fires a verb regardless of its own hidden/category state, so no second verb is
// needed to cover both entry points. Wrapped in a real <html><body> doc, not a bare
// fragment — starting with plain text/a quote mark instead of a tag makes the popup
// sniff the content as plain text and print literal tags instead of rendering them
// (same issue fixed in obj/stat/bookcase's Quotes reader, Obj.dm).
mob/verb/Help()
    set category = "Action"
    set desc = "How to play, what to do, and the general rules"

    if(!RequireCanAct()) return

    var/helpText = {"
<html><head><meta charset="utf-8"><style>h3{text-decoration:underline}</style></head><body style="font-family:sans-serif;font-size:13px">

<p><b>Updated as of 9/9/26</b></p>

<hr>

<h3>Welcome to Dragon Warrior Legacy Remake!</h3>
<p>Dragon Warrior Legacy is a remake of Tarq (key: WizDragon)'s original half-fan game, which used some of the ideas and most of the graphics of Dragon Warrior with gameplay very different from it. This remake keeps that spirit but rebuilds combat as real-time (Zelda-style), not turn-based. This help file will tell you how to play, what to do, and what the general rules are.</p>

<hr>

<h3>Creating a Character</h3>
<p>After putting in your name, you'll be prompted to choose your class. Here's a quick overview:</p>
<ul>
<li><b>Hero</b>: Balanced in all areas. Use this class if you plan on soloing most of the time.</li>
<li><b>Soldier</b>: Very strong physical power, defense, and HP. Soldiers are the best class at taking damage.</li>
<li><b>Fighter</b>: This class attacks extremely quickly and can deal huge amounts of physical damage, but isn't so good at taking damage.</li>
<li><b>Goof-off</b>: This odd class is weaker than the rest, but at level 25 they learn Classchange and can turn into the very powerful Sage class.</li>
<li><b>Pilgrim</b>: Specializes in healing and defensive magic, but is also fair in physical combat.</li>
<li><b>Wizard</b>: Very weak in physical combat, but has the most powerful offensive magic of any class.</li>
</ul>
<p>(Sage isn't a starting choice — you reach it by learning Classchange as a Goof-off at level 25, or by using a Dharma Scroll on any other class. Sage is a combination of Wizard and Pilgrim: it learns both offensive and defensive magic, but is horrible in physical combat.)</p>
<p>After choosing a class, you'll be asked to choose and color your icon. Once that's done, your character will be made.</p>

<hr>

<h3>Battle</h3>
<p>In certain areas, you'll be able to fight monsters, or sometimes other players. Your skills are listed in the Battle tab, and your vitals are listed in the HUD at the bottom of the screen.</p>
<p>You have 5 skill slots, bound to Numpad 9/7/3/1/0 (<b>Numlock must be off</b>). To equip a skill, drag it from the Free Skills list onto one of these slots on the Battle tab; drag an equipped skill back to Free Skills (or double-click it) to unequip it. Pressing a slot's key uses whatever is equipped there, targeting whoever is on the tile directly in front of you.</p>
<p>To target a spell on a specific player instead — for party healing, for instance — click them (if they're nearby) and choose <b>Cast Magic</b> from the menu, then pick the spell. That same menu also lets you give gold or an item directly to another player.</p>
<p>You can also bind up to three spells you know to <b>F5/F6/F7</b> as quick-cast hotkeys (set via the Quick Cast Hotkeys menu) — these also target whoever's in front of you.</p>

<hr>

<h3>Leveling Up</h3>
<p>Fighting monsters nets you EXP, and when you get enough EXP you'll level up, as in practically every other RPG on the planet. When you level up, your HP (and MP if you're a magic-user) will rise, you may learn a new skill, and you'll gain stat points. Stat points can be used to increase your stats by clicking on them. Here's a quick overview of what the stats do:</p>
<ul>
<li><b>Strength</b>: Increases physical damage and the number of items you can carry.</li>
<li><b>Agility</b>: Increases attack speed, casting speed, and physical defense.</li>
<li><b>Vitality</b>: Increases max HP, HP regeneration rate, physical defense, and magic defense.</li>
<li><b>Intelligence</b>: Increases max MP, MP regeneration rate, magic power, and magic defense.</li>
<li><b>Spirit</b>: Increases critical hit rate, and contributes to max MP alongside Intelligence.</li>
</ul>
<p>If you're in a party with EXP/gold sharing on, kills split evenly among the party instead of going only to whoever landed the hit.</p>

<hr>

<h3>Quick Item</h3>
<p>Quick items are a way to use items without having to click on them in your inventory. Press * on your numpad to cycle through your items, and - to use whichever one is currently selected.</p>

<hr>

<p><i>Note: I don't feel like rewriting the rules right now, but I will make an effort to eliminate most of the issues the rules cover.</i></p>

<h3>Rules</h3>
<ul>
<li><b>No racism, sexism, or anything else along those lines.</b> Swearing is fine, but don't go overboard on it.</li>
<li><b>There's a language filter in place that filters out swearing (this can be turned off) and racist remarks (always filtered).</b> Racism and sexism (among other things) will be taken seriously. Any attempt to get around the filter will get you banned — even though the filter blocks what shows up in-game, the actual text you typed still shows up in the logs, so it'll tell on you either way.</li>
<li><b>Don't flame or harass other players.</b> If you have a dispute, settle it like actual people instead of 2nd grade children, or take it to a GM.</li>
<li><b>Listen to the GMs.</b> GMs are anyone with a fancier icon than normal. If they're telling you to do something, listen to them.</li>
<li><b>Don't spam.</b> Spamming is filling up the chat with useless messages. Any kind of spamming will be dealt with very seriously.</li>
<li><b>Don't steal kills or loot.</b> When someone else is fighting a monster, don't help unless they ask for it! You won't get any EXP or gold from it unless you're the one fighting it, anyway. Likewise, if a monster drops something and you didn't kill it, don't pick it up.</li>
<li><b>Respect people so long as they deserve it.</b> Have courtesy in this game. Behind every little icon, there is an actual person with feelings and opinions. Don't pretend that person doesn't exist. I don't expect this to be a perfect little community of harmony and sunshine, but I don't want it to be a hellhole, either.</li>
</ul>

<hr>

<p><i>By Aeon (Cerebella)</i></p>

</body></html>
"}
    src << browse(helpText, "window=help;size=520x520")

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

    if(!RequireCanAct()) return
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

    if(CanUseItem(quickItem)) quickItem.UseItem(src)  // Inventory.dm

// -----------------------------
// Quick cast — F5 / F6 / F7. Three spell hotkeys separate from the five numpad skill
// slots, so a caster can keep utility spells reachable without spending a combat slot.
// -----------------------------
mob/var/list/quickSpells = alist(5 = null, 6 = null, 7 = null)

mob/player/verb/SetQuickCast()
    set category = "Action"
    set desc = "Assign a spell to one of the F5/F6/F7 hotkeys"
    set hidden = 1   // stays functional, just not shown in the Action tab

    if(!RequireCanAct()) return
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

    if(!RequireCanAct()) return
    var/datum/skill/S = quickSpells[slot]
    if(!S)
        src.ShowInfo("No spell assigned to F[slot].")
        return
    StartSkill(S, FindFacedTarget())

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

        GiveHeldItem(items[choice], target)

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

        // The menu waits on the player -- the target may have logged out or walked off
        // since it opened.
        if(!target || get_dist(src, target) > PLAYER_MENU_RANGE)
            src.ShowInfo("They're out of range.")
            return

        // Same gates as a numpad slot -- neither encumbrance nor Stopspell is
        // bypassable just by clicking a player.
        StartSkill(S, target)

mob/verb/Interact()
    set hidden = 1

    // Dead players use Interact() (bound to numpad 5) to respawn immediately instead
    // of the normal interact flow — no minimum wait; Die()'s own timer handles the
    // automatic case.
    if(isDead)
        RespawnPlayer()
        return

    // AFTER the isDead branch above, deliberately -- respawning via numpad 5 must stay
    // usable even while canAct is FALSE (Die() locks it as part of the death itself),
    // this only needs to block normal interaction.
    if(!RequireCanAct()) return

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

    if(!RequireCanAct()) return
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

    if(!RequireCanAct()) return
    turnWalkMode = !turnWalkMode
    src.ShowInfo("Turn-then-walk is now [turnWalkMode ? "ON" : "OFF"].")

// Returns to the character-select menu without disconnecting from the server. Named
// LogoutToMenu, NOT Logout -- mob/player/Logout() (Main.dm) is BYOND's own disconnect
// callback (fires on a real client disconnect); a verb literally named Logout() would
// override that hook instead of adding a separate one, silently breaking save-on-
// disconnect for everyone. `set name` below is what actually shows "Logout" in the
// Action tab. Saves the character with the same call SaveAndLogout() makes on a real
// disconnect, but skips its "has left the world"/LogChat lines since the player never
// actually left the server.
mob/player/verb/LogoutToMenu()
    set name = "Logout"
    set category = "Action"
    set desc = "Save and return to the character select menu"

    if(!client) return
    if(!RequireCanAct()) return

    var/confirm = alert(src, "Return to the character menu? Your character will be saved.", "Logout", "Yes", "No")
    if(confirm != "Yes") return

    var/client/C = client
    // Would otherwise linger in C.screen and double up with whatever character loads
    // next (HUD.dm) -- same reasoning as BecomeSage() (PlayerTemplate.dm).
    DestroyHUD(C)

    if(saveManager && !skipSaveOnLogout)
        saveManager.SaveCharacter(src, saveSlot || 1)

    players -= src

    // Reopen the savefile fresh rather than reusing the same handle for the rest of
    // this connection. RESTORED 2026-09-09 after being wrongly reverted: reusing one
    // long-lived SaveManager across repeated create/logout cycles in a single session
    // (create Hero, logout, create Soldier, logout, create Wizard, logout, ...) turned
    // out to silently drop the later characters entirely -- confirmed live: only Hero
    // (the very first character, first write) survived a disconnect/reconnect, Soldier
    // and Wizard never made it to disk despite their own creation-time and logout-time
    // SaveCharacter() calls each completing without error. A previous icon-loss report
    // (characters 2/3 rendering with no sprite) was wrongly blamed on THIS reopen and
    // used as the reason to revert it -- the real cause was an unrelated null-list
    // crash in PaletteManager.New() (PaletteManager.dm, fixed separately) that had
    // nothing to do with how many SaveManager instances existed. Each SaveCharacter()
    // call already Flush()es before this runs, so the fresh reopen always sees
    // everything saved so far.
    if(saveManager) saveManager.Close()
    C.saveManager = new /datum/SaveManager(C.ckey)

    var/mob/playerTemp/M = new()
    C.mob = M
    C.SyncGMVerbs()

    // Same login jingle mob/playerTemp/Login() (Main.dm) plays on a real connection --
    // replaces whatever area music was still on channel 1 for the character just left.
    C << sound('dw3conti.mid', repeat = 1, volume = C.ScaledVolume(isMusic = TRUE), channel = 1)

    LeavePartyIfAny()  // before the del() below — see the proc's own note (Party.dm)
    ReleasePetIfAny()  // same reason (EnemyNPCs.dm)

    // MUST run before ShowLoginMenu() -- that call blocks on input() for the player's
    // entire character-select/creation session, so del-ing src AFTER it (as originally
    // written) left the old mob's body, icon and all, standing untouched in the world
    // for as long as the menu stayed open. Confirmed 2026-09-09 ("leftover icons").
    del src

    ShowLoginMenu(M)

// -----------------------------
// Volume Control — Master/Music/SFX sliders (client/ScaledVolume(), Main.dm),
// per-ckey persisted (SaveManager.SaveVolumeSettings()). Three separate verbs so each
// can be adjusted independently without re-entering the others.
// -----------------------------
mob/verb/SetMasterVolume()
    set category = "Settings"
    set desc = "Overall volume, scales Music and SFX together"
    PromptVolume("masterVolume", "Master volume")

mob/verb/SetMusicVolume()
    set category = "Settings"
    set desc = "Area background music volume"
    PromptVolume("musicVolume", "Music volume")

mob/verb/SetSFXVolume()
    set category = "Settings"
    set desc = "Combat/event sound effect volume"
    PromptVolume("sfxVolume", "Sound effects volume")

// Shared by the three sliders above: asks for 0-100, stores it on the client var named
// by volumeVar, and saves it.
mob/proc/PromptVolume(volumeVar, label)
    if(!client) return
    if(!RequireCanAct()) return

    var/v = input(src, "[label] (0-100):", "Settings", client.vars[volumeVar]) as num
    if(isnull(v)) return
    client.vars[volumeVar] = max(0, min(100, round(v)))
    client.saveManager.SaveVolumeSettings(client)
    src.ShowInfo("[label] set to [client.vars[volumeVar]]%.")
    // Re-apply to the track already playing -- Master and Music both change it.
    // SOUND_UPDATE adjusts its volume in place instead of restarting it from the top.
    if(volumeVar != "sfxVolume" && current_music)
        client << sound(null, channel = 1, volume = client.ScaledVolume(isMusic = TRUE), status = SOUND_UPDATE)
