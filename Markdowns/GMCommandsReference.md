# GM Commands Reference — from original Dragon Warrior Legacy

32 confirmed GM verbs from the OG game's GM Commands tab. Categorized per the original
design notes (Admin/Builder/GM tiers) where that categorization already existed;
`GMindestructablemode` is new — wasn't in the original design notes at all, tier TBD.

Fill in as we go through each one: what it does, what it prompts for (if anything), and
which permission tier it should actually require in the remake (may not match the OG's
own tier if we decide differently — see `AdminLevels.dm` for our current tiers).

Status key: `[ ]` not discussed yet, `[x]` confirmed behavior documented below.

---

## Admin tier (per original design notes)

- [x] `GMannounce` — prompts the GM for announcement text, then broadcasts to everyone:
      first a small line "`[GM name] has an announcement`", then the announcement text
      itself in large, bold, red font — confirmed from a live test ("Aeon has an
      announcement" followed by a large red "Welcome!"). Printed straight into the
      message pane, not a separate popup window.
- [x] `GMban` — normally opens a list of all connected players to pick a target from
      (couldn't fully verify with only one player online — it skipped straight to the
      reason prompt since you were the only option). Confirmed requirements:
      1. Player list to choose from, excluding yourself (can't self-ban), with a Cancel
         option
      2. Hierarchy check — a lower-tier GM cannot ban someone at or above their own tier
         (ties into the existing `AdminLevels.dm` tier system)
      3. Text prompt for a ban reason/message, with OK/Cancel
      4. **Remake addition, not confirmed OG behavior**: an extra "are you sure?"
         confirmation before the ban actually lands, since this is a destructive action

      **Implemented as `GM_Ban` (`GMCommands.dm`)** — deliberately merged with
      `GMunban` below into one verb rather than the OG's two (a "Ban List" entry sits
      at the top of the same target picker), and per-CHARACTER not per-account (the
      target's OTHER save slots are unaffected) — neither of those is confirmed-OG,
      just this remake's own call. Hierarchy check (#2), reason prompt (#3, shown to
      the target as their parting message right before disconnect), and the "are you
      sure?" confirm (#4) are all in.
- [x] `GMboot` (called "kick" colloquially, but the actual verb is `GMboot`) — same
      player-list/hierarchy-check pattern as `GMban`. Critically: disconnects the player
      **without saving their current stats** — this is intentional, not a bug to fix.
      The player reverting to their last save is meant to be the punishment, which is
      enough in some situations without a full pwipe.

      **Implemented as `GM_Boot` (`GMCommands.dm`)** — same player-list/hierarchy/
      confirm pattern as `GM_Ban`. Uses a `skipSaveOnLogout` flag (`PlayerTemplate.dm`)
      to force-disconnect (`del(client)`) without the normal on-logout save firing.
- [ ] `GMmute` — same player-list pattern as `GMban`/`GMboot`/`GMpwipe`: pick a target,
      confirm. Muted players can't talk (`Say`/`Tell`/`WorldSay`) or emote
      (`Emote`/`WorldEmote`) — ties directly to the `isMuted` var already flagged as
      needed in `TODOList.md` Phase 2. Not built yet — `isMuted` exists and is
      enforced, but nothing sets it on another player yet.
- [ ] `GMpwipe` — "player wipe": same player-list/hierarchy-check pattern as `GMban`, but
      instead of disconnecting, it **deletes the target's current character from their
      savefile entirely** — erased, not recoverable; they have to pick a different save
      slot or create a brand new character afterward. **Confirmed punishment severity
      ordering: `GMboot` (revert to last save) < `GMpwipe` (lose this character
      entirely) < `GMban` (also can't log back in at all)**. Not built yet.
- [x] `GMunban` — opens a list of currently banned players to select and unban; if
      nobody is currently banned, shows a message stating so instead of an empty list.
      **Implemented as part of `GM_Ban`'s "Ban List" option** (see above) rather than
      its own verb.

## Builder tier (per original design notes)

- [x] `GMdelobjmob` — deletes the closest obj/mob within a 1-square radius of the GM in
      every direction (not the whole view range as first thought — a tight 3x3 area
      centered on the GM). If there are multiple equally-close candidates within that
      radius, opens a selection list instead of guessing. Confirmed
      deletable targets include doors, bookcases, musical bookcases, and signs — all
      objs, consistent with how doors/signs/bookcases are already built as `obj` types
      in `Code/World/Obj.dm` (the "musical bookcase" is the paused jukebox feature idea,
      also an obj as expected).
- [x] `GMghostform` — **already implemented**, confirmed matching our existing
      `GM_GhostForm()` in `Code/Admin/Commands/GMCommands.dm` (invisible + no
      collision + ghost sprite overlay). Was `GM_GhostIconform` — renamed to match
      the OG's `GMghostform` naming exactly, nothing left to do here.
- [x] `GMmakearea` — the area-painting tool. Areas are the unseen top layer over turfs;
      each area instance can carry its own music, battlemode, coopmode,
      indestructiblemode, and weather (confirms these all need to become per-area vars,
      not globals — see `TODOList.md` Phase 8 note, since only `areaMusic` exists as a
      per-area var in `Code/World/Area.dm` today). Opens the same area-picker list style
      as `GMbattlemode`/`GMcoopmode`/`GMglobalrespawn`, plus a "None" entry. Selecting a
      real area **automatically enters build mode** (see `GMmaketool`, covered next);
      selecting "None" exits build mode instead of painting anything. While in build
      mode, a white cursor square shows which tile is currently targeted. Confirmed
      working example: repainting a spot that used to be the "rain" area into "jail".
- [x] `GMmakeitem` — opens a scrollable list of every item type in the game
      (`/item/key`, `/item/paper`, `/item/gem/redgem`, `/item/gem/greengem`,
      `/item/gem/bluegem`, `/item/gem/ring`, `/item/gem/drop`, `/item/gem/crown`,
      `/item/amulet/strength`, `/item/amulet/power`, `/item/amulet/agility`,
      `/item/amulet/speed`, and more below the visible scroll — worth a dedicated item
      reference doc later, same as classes/monsters). Selected item spawns **on the
      ground at the GM's current tile**, not directly into their inventory (different
      from `GM_Create_Lockable` in our own `GMCommands.dm`, which puts the key straight
      into the creator's inventory instead).

      Picking `/item/key` specifically adds an extra naming prompt: "What will the key be
      called? (To make a key work for a door, you must name it the name of the door,
      followed by \" key\".)" — **this confirms our own key-naming convention is already
      correct**: `GM_Create_Lockable()` names keys `"[lockName] Key"`, matching the OG's
      `"[DoorName] key"` pattern exactly.
- [x] `GMmakestat` — "stat" is the OG's umbrella term for interactable objects: doors,
      signs, pots, drawers, bookcases, chests, NPCs, merchants. **This already matches
      our own codebase** — `Code/World/Obj.dm` groups exactly these under `obj/stat/...`
      (door/drawers/bookcase/chest/sign/pot), so the terminology and structure are
      already aligned, not something to rename.

      Confirmed full type list (list-picker pattern, same as other `GMmakeX` tools, needs
      the "None to cancel" entry too):
      - Signs: `wooden`, `inn`, `snowwooden`, `snowinn`, `church`, `weapon`, `armor`,
        `grave`, `item` — we currently only have wooden/inn/church/grave; snowwooden,
        snowinn, weapon, armor, item are new variants to add
      - Doors: `wooden`, `silver`, plus a `switchdoor` type (name suggests a
        switch-activated door, not player-interact-to-open like our current `obj/door`)
      - Merchants: `greatestamuletmerchant`, `foodmerchant`, `drinkmerchant` — confirms a
        shop/vendor NPC system exists in the OG that isn't anywhere in our design yet at
        all (not classes — these are shopkeeper NPCs)
      - Singular (no sub-variants) stat types: `bookcase`, `musicalbookcase` (**this is
        the paused jukebox feature — confirmed as `/stat/musicalbookcase`, a real distinct
        type from plain bookcase, not something we were misremembering**), `warppoint`,
        `respawn`, `levelbarrier`, `playerstart`, `playerspawn`, `boulderspawn`
- [x] `GMmaketool` — sets which brush mode `GMmakearea`/`GMmaketurf`/`GMmakemob`'s build
      mode uses to apply the currently-selected type. A white cursor square shows the
      target tile. Confirmed 7 modes (more than the original design notes' 5 — Move and
      Delete weren't in the original plan at all):
      - **Click** — places one instance per click
      - **Drag** — places continuously wherever the cursor is dragged while held
      - **Block** — rectangular region from first-click point to release point, filled
        entirely (this is what the original design notes called "Fill")
      - **Line** — click-drag constrained to a straight line only
      - **Move** — click-and-hold an existing obj/mob/item, drag it to a new spot,
        release to relocate it there. Works on **players and enemies too**, not just
        placed scenery — effectively a universal "relocate any atom" tool
      - **Flood** — paint-bucket style: replaces the clicked tile and every contiguous
        matching tile with the current selection (matches original design notes exactly)
      - **Delete** — clears whatever's on the clicked tile, then immediately places the
        currently-selected mob/obj there — a combined clear-and-replace, not a plain delete
      Selecting a mode prints "[Mode] tool selected." as confirmation.
- [x] `GMseeareas` — toggles a GM-only visual grid overlay (blue lines around every tile)
      showing area boundaries, so a GM can tell which area they're standing in/near
      while building. Purely visual/client-side to the GM — doesn't affect gameplay or
      require build mode to be active. Also reveals spawn-point markers, distinguished by
      type: **login spawns** (the door icons seen at the bottom of the map in an earlier
      screenshot), **death (respawn) spawns**, and **monster spawns** — so this verb
      doubles as a way to audit where players/respawns/monsters actually land, not just
      area boundaries. Confirms `playerstart` vs `playerspawn` from `GMmakestat`'s list
      are indeed distinct (login point vs. death-respawn point), resolving the "needs
      confirming" note left on those in `TODOList.md` Phase 8.

      **Implemented `playerstart`/`playerspawn` as plain OBJECTS, matching
      `GMmakestat`'s own stat-object listing** — `obj/spawnMarker/playerStart`
      (door.dmi/wooden) and `/playerSpawn` (sign.dmi/church), both in
      `Code/World/Area.dm`, placed via `GM_CreateObj` ("World Login Point"/"Respawn
      Point"). Deliberately NOT areas: a turf only ever belongs to one area, so an
      area-based marker painted onto an existing Town/Dungeon/etc. tile would strip it
      of that area's own music/battle-mode/everything else — an object sitting on top
      leaves the tile's real area completely untouched. `GetPlayerSpawnTurf()`/
      `GetRespawnTurf()` (Area.dm) pick a random tile with a marker of the right type
      on it (falling back to the old hardcoded `PLAYER_SPAWN` coordinate with a log
      warning if a map has none yet). The markers are invisible during normal play
      (`invisibility = 100`) and only ever rendered via `GMseeareas`' own overlay,
      which now draws them as an extra layer on top of the tile's normal area color —
      matching this verb's own "GM-only-visible spawn markers, distinct from area
      boundaries" framing exactly. Monster spawns (the third marker type mentioned
      above) are still not built at all.
- [x] `GMtransfer` — two-step player picker: select the player to teleport, then select
      the destination player; the first appears directly in front of the second. Special
      case: using it **on yourself** just moves you forward one tile — and does so even
      through density (can step onto/through a dense object), unlike normal movement.
- [x] `GMmakemob` — the monster-placement version of `GMmakearea`/`GMmaketurf`: same
      list-picker pattern (`/mob/monster/*` types), with "None" at the bottom to exit
      build mode, same as the other `GMmakeX` tools. Presumably also auto-enters build
      mode on selecting a real monster type, matching `GMmakearea`'s confirmed behavior.
      **Design rule confirmed general, not incidental**: every `GMmakeX` build-mode
      picker (area/turf/mob, and likely item too) must include a "None" entry so a GM can
      cancel out of build mode without picking something to place.

## Builder tier (continued)

- [x] `GMmaketurf` — the turf version of `GMmakearea`/`GMmakemob`: same list-picker
      pattern. Confirmed types so far: `bridge/bridgev`, `bridge/bridgeh`,
      `bridge/stonebridge`, `bridge/snowbridgev`, `bridge/snowbridgeh`, `floor/path`,
      `floor/snowpath`, `floor/redcobble`, `floor/stonecobble`, `floor/fancycobble`,
      `floor/icecobble`, `floor/sandcobble` (more below the visible scroll, not captured
      yet). Cross-checked against our own `Turfs.dm`: bridgev/bridgeh/stonebridge and
      redcobble already exist; **snowbridgev, snowbridgeh, and every other cobble/path
      variant (stonecobble/fancycobble/icecobble/sandcobble/path/snowpath) don't exist
      yet** — same "add when the map needs it" situation as the sign/door variants in
      `TODOList.md`, not an urgent gap.

## GM tier (per original design notes)

- [x] `GMblaze` — prompts a level select (0–4 seen in the list; 0 presumably = off).
      Leaves a trail of fire behind the GM as they walk, dealing AoE damage over time to
      anything standing in it — handy for clearing out enemies. Level 1 only puts fire on
      the exact tile you're currently walking on; higher levels' exact effect (wider
      trail? stronger DoT? bigger AoE per tile?) not yet confirmed. **Depends on the
      spell/fire-damage system existing first** — low priority until then.
- [x] `GMcoopmode` — same per-area-instance toggle pattern as `GMbattlemode`. Coop ON =
      players cannot kill each other (PvE only); Coop OFF = PvP enabled between players.
      Note: GMs are never considered "players" for this check — players can still hurt a
      GM regardless of coop mode. Every area defaults to Coop ON except the Arena, which
      defaults OFF since it exists specifically for PvP.
- [x] `GMdaynight` — **implemented** in `Code/Admin/Commands/GMCommands.dm`. A toggle
      (day→night and back again) that swaps **World Icons only** (turfs/objects/
      environment) to their night variant by appending `"night"` directly onto the
      current `icon_state` (e.g. `"redcobble"` → `"redcobblenight"`, confirmed exact
      suffix convention, no separator, no exceptions). Iterates every turf and obj
      currently in the world (excluding `/obj/StatLink`, a UI helper type with no visual
      icon of its own), gated to GM tier (`client.adminLevel >= LEVEL_GM_HOST`). Reverts
      by stripping the trailing "night" back off, tracked via the new global `isNight`
      var (`Main.dm`). Player/monster icons do NOT have night variants in the OG — they
      stay the same regardless of time of day, so mobs are intentionally excluded.
      **Remake idea (later, not OG behavior)**: darken player/monster sprites at night and
      eventually build out more dynamic lighting — worth a Quality-of-Life entry, not part
      of matching the OG's actual `GMdaynight` behavior.
- [x] `GMglobalrespawn` — a full named monster-spawn management system. Opens a list of
      existing spawn definitions (e.g. "Slimes") plus a "Create New Respawn" option.

      **Creating a new one** walks through 5 prompts in order:
      1. Name (text input) — e.g. "Slimes"
      2. Monster type — a list of `/mob/monster/*` types to pick from (cat, slime, dog,
         redslime, bat, fox, babble, skeleton, drakee, healer, snailslime, magician, etc.
         — confirms these monster types exist in the OG, useful reference for our own
         enemy roster later)
      3. Area — same area-instance picker as `GMbattlemode`/`GMcoopmode` (specific placed
         areas like `/area/town/rain`, not area types generally)
      4. Z level — numeric input, "Levels are 1-5; use 0 for all levels" (confirms the OG
         world has exactly 5 z-levels, and spawn definitions can target one or all of them)
      5. Spawn rate — numeric input, how many of that monster to maintain/spawn

      **Selecting an existing definition** prompts Modify / Delete / Cancel. Modify
      re-runs the same 5-step creation flow and overwrites the saved definition. Both
      modifying and deleting **kill all currently-spawned monsters tied to that
      definition in the area on reset**, rather than leaving stale mobs from the old
      settings standing around.
- [x] `GMbattlemode` — opens a list of specific area **instances** on the map (not just
      area types — e.g. `/area/town/rain` is listed separately from `/area/town`, so this
      targets individual placed areas, not every area of a given type at once). Selecting
      one toggles that specific area's battle mode: ON means players can use attacks/
      skills there, OFF means the area is peaceful (no combat). Confirmed message on
      toggling to dangerous: "The rain is now a dangerous area." (presumably a mirrored
      "...is now a peaceful area" message when toggled off, not yet confirmed).
- [x] `GMkillallmonsters` — two-step picker: first select a monster type (list of
      `/mob/monster/*`, presumably with an "all monsters" option at the top) or "all",
      then select a specific area instance or "all areas" (same area-picker style as
      `GMbattlemode`/`GMcoopmode`/`GMglobalrespawn`). On confirm, every monster matching
      both selections dies. Surfaced more monster type names for the roster: ghost, wolf,
      magidrakee, reptile, arcticfox, panther, gremlin, acolyte, blazeghost, tiger, yeti,
      manowar (added to the running list in `TODOList.md`'s Phase 6).
- [x] `GMlevelincrease` — opens a player list to select a target, then a numeric prompt
      ("GMlevelincrease [name] number") for how many levels to grant. Applies that many
      level-ups at once, including whatever stat points/HP/MP normally come with leveling
      — confirmed by the target receiving one "You have gained a level!" message per
      level granted (5 messages for an input of 5), i.e. it just runs the normal
      level-up flow N times rather than a special bulk-add path.
- [x] `GMnamechange` — opens a list to pick a target (player **or mob** — broader scope
      than the player-only lists used by `GMban`/`GMboot`/`GMmute`/`GMpwipe`, so this can
      rename NPCs/monsters too, not just players), then prompts for the new name and
      applies it. Should reuse the same name validation already used at character
      creation — `IsTextFiltered()`/`CensorText()` (`TextFilter.dm`) and
      `MAX_NAME_LENGTH` (`Main.dm`) — rather than allowing anything through unchecked.
      Confirmed persistence: the rename is a live change to `mob.name`, not a temporary
      alias — if the renamed player's character saves afterward (including a normal
      auto-save on logout), the new name overwrites the original name in their savefile
      permanently, no separate confirmation or revert step.
- [x] `GMplayerstatus` — opens a player list with an "All" option at the bottom. Picking
      one (or All) opens a popup window ("Status of [Name]") dumping a full character
      sheet — confirmed fields, in order:
      - `Name(ckey, [title])` — e.g. "Cere(Cerebella, )"; title field shown empty here,
        presumably populated for GM tiers or party role
      - `Class: X Level: Y Party: Z` — party field shows role too, e.g. "Aeon's Crew
        Leader" not just the party name
      - `EXP: current/next (X)` — the "(0)" here likely mirrors the Status panel's
        "(X%)" but rendered without the % sign in this popup; not fully confirmed
      - `Gold: X`
      - `HP: cur/max MP: cur/max Stat Points: X`
      - All 5 stats with the same `base+bonus` notation as the Battle tab (`Strength:
        14+0`, etc.)
      - `Inventory:` — flat comma-separated list of every carried item by name (confirms
        no stacking: seeing the same item name appear twice as separate list entries)
      - `Skills:` — every **known** skill, not just the 5 currently equipped
      A genuinely useful full-dump admin/debug tool — worth keeping this shape when we
      build it, not simplifying it down.
- [x] `GMplaymusic` — same area-picker pattern as `GMbattlemode`/`GMcoopmode`/etc., but
      instead of a boolean toggle, it directly sets/changes that area's background music
      — essentially the GM-verb equivalent of what the `musicalbookcase` stat object
      (the paused jukebox feature) gives to players in-world. The list's last entry is
      "area" meaning **all areas at once**, not a specific one — picking it plays the
      chosen track everywhere simultaneously rather than per-instance. Ties directly to
      the existing `areaMusic` var on `Code/World/Area.dm`'s base `area` type — this verb
      is just a runtime setter for a var that already exists.
- [x] `GMroleplaymode` — a **world-wide** toggle (not per-area like battlemode/coopmode/
      indestructiblemode). While active:
      - Chat is restricted to players in view — world-channel chat (`WorldSay`/
        `WorldEmote`) presumably gets disabled/blocked rather than just discouraged,
        exact mechanism not yet confirmed
      - Adds **Hunger, Thirst, and Sleep** survival mechanics — brand new systems, not
        mentioned anywhere in the original design notes at all
      - Ties into the Day/Night cycle and Weather system (both already separate GM
        toggles — roleplay mode appears to activate/depend on them together rather than
        being fully independent). **Confirmed via live testing**: extreme temperatures
        deal damage over time, and passive HP regen is disabled entirely, while roleplay
        mode is active — see `GMweather`'s entry below for the full detail.
      This is a large feature bundle, not a simple flag — needs its own design pass
      before building, see `TODOList.md` Phase 8. **Low priority**: you weren't a fan of
      how this played in the OG, so treat this as a candidate for redesign/expansion
      rather than a faithful port whenever it does get picked up.
- [x] `GMsavelocation` — a global toggle: when ON, a player's exact (x, y, z) location is
      saved on logout and restored on their next login, instead of always spawning at
      the fixed start point. Confirmed our code currently has **no location persistence
      at all** — every login (`Code/Save/SaveSystem.dm`, `Code/UI/LoginMenu.dm`)
      unconditionally sets `newPlayer.loc = GetPlayerSpawnTurf()` (was a raw
      `PLAYER_SPAWN` coordinate, now the area-based lookup, `Code/World/Area.dm`). This
      verb would need: a saved x/y/z field in the savefile, and a conditional at those
      two call sites to use it instead of `GetPlayerSpawnTurf()` when the toggle is on.
- [x] `GMswitchicon` — lets a GM switch between their own custom cosmetic icons, purely
      for flair (no gameplay effect). Almost certainly what the existing
      `"Mob Icons/Custom GM"` `FILE_DIR` entry in the `.dme` is for — that folder already
      exists in the project's include list with nothing pointing at it yet.
      **Idea floated for later, not committed**: eventually let regular players create
      their own custom icons and use them on servers they host, not just GMs.
- [x] `GMweather` — opens a 3-option menu: Rain, Puddles, Temperature.
      - **Rain**: prompts "Will it rain or snow?" (Rain/Snow/Cancel). Only applies to
        outside areas.
      - **Puddles**: scatters either water puddles (walkable, same as the water icon) or
        snow onto random turfs, depending on which was picked under Rain — this is the
        actual visual/terrain effect of the weather, separate from just flagging that
        it's raining
      - **Temperature**: same area-instance picker as `GMbattlemode`/etc., then a 9-level
        scale: Blazing, Very Hot, Hot, Warm, Normal (default), Cool, Cold, Very Cold,
        Freezing — set per area
      This maps directly onto the `weather` var already scaffolded on `Area.dm`'s base
      `area` type — it'll need to hold more than a single value (rain-vs-snow state,
      whether puddles/snow are currently scattered, and a temperature level), not just a
      boolean.
      **Confirmed via live testing** (not just a guess as first thought): while
      `GMroleplaymode` is active, extreme temperatures deal damage over time, and passive
      HP regen is disabled entirely. This only happens during roleplay mode, not
      globally — temperature has no standalone gameplay effect outside of it. Whether
      specific equipment counters the temperature damage is still unconfirmed.
- [x] `GMworldreboot` — most of the flow actually works and is worth copying: announces
      "[GM name] has announced a server reboot in 10 seconds...." in large text, then
      shows a large centered countdown (10, 9, 8...), then saves the world/players as-is
      and restarts the server. **The part that's confirmed broken**: after the reboot,
      selecting a character at the login screen doesn't work — it just stays a black
      screen instead of loading you into the world. So the countdown/announce/save/
      restart sequence is good reference behavior; only the post-reboot reconnect/login
      path needs to be designed fresh rather than copied, since the OG's own version of
      that part doesn't work.

## Uncategorized — not in original design notes

- [x] `GMindestructablemode` — toggles whether the **world environment** reacts to
      fire/ice elemental damage (not player/mob invincibility, despite the name — this is
      about terrain, not HP). Default is ON (indestructible, world takes no damage). When
      turned OFF:
      - Fire-based attacks/spells: cobble → burnt cobble, grass/plants/brush/signs → ash,
        water → lava, **pathways → sand** (not ash — confirmed distinct from
        grass/plants/brush/signs)
      - Ice/snow-based attacks/spells: leave snow overlay on the ground
      - Wood doors are destroyed outright; stronger (non-wood) doors are not affected
      - Tubs are confirmed **immune** — sitting in a fully lava'd-over room, they didn't
        burn/change at all, unlike the surrounding cobble/grass/water
      Exact confirmed toggle-off message: "Indestructable mode has been deactivated."
      This is a real terrain-state system (each affected tile/obj needs a damaged-state
      icon_state and a way to revert or persist), not a simple boolean flag — worth
      scoping carefully once elemental spells actually exist to trigger it.

## Other GM-only interactions (not verbs in the GM Commands tab)

- [x] **Double-clicking a stairs turf as a GM** toggles it between jumping 1 z-level and
      2 z-levels (double-click again to revert to 1). Current code (`Code/World/Turfs.dm`
      `stairsup`/`stairsdown`, lines ~212-233) only ever moves `M.z ± 1` via `Entered()` —
      this GM double-click toggle doesn't exist at all yet, needs a var (e.g.
      `zJumpAmount`, default 1) on the stairs turf plus a GM-gated `DblClick()` override.
- [x] **Double-clicking a door, sign, or key as a GM** opens a text box to rename it
      (choose a new name or cancel). Keys can also just be deleted and recreated with a
      new name via the existing `GMdelobjmob` + `GMmakeitem` verbs instead of a dedicated
      rename, if that's easier. None of this rename behavior is built yet — our current
      `obj/door`'s `DblClick()` slot is unused, `obj/stat/sign` has no `DblClick()` at
      all, and `obj/item/key`'s existing `DblClick()` in `Inventory.dm` is already used
      for the lock-toggle mechanic, so a key rename would need a different trigger (this
      double-click is GM-only and player-facing double-click is already taken).
      **Worth flagging for our own lock system**: `GM_Create_Lockable()` names a door and
      its matching key together, and the lock check in `Obj.dm`'s `OnInteract()` compares
      a carried key's `keyName` against the door's **current** `name`. Since **both** the
      door and the key can independently be renamed after creation, either direction can
      desync them — a door renamed without its key, or a key renamed without its door —
      silently making the pair permanently non-matching. Needs handling (auto-rename the
      pair together, or block one-sided renames, or something else) once this feature
      gets built.
