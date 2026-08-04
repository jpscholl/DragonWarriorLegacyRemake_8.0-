// -----------------------------
// Admin Levels
// -----------------------------
// Resolved fresh from hardcoded data every time a client connects — never read from or
// written to a savefile, so a player can't grant themselves access by editing their own
// save (this project has its own Save File Editor tool sitting in the repo, so that's a
// real risk to design around, not a hypothetical one).
//
// Builder and Admin are separate capability sets, not rungs on the same ladder — a
// Builder doesn't get Admin powers and vice versa. GM and Host are peers: same level,
// both get Builder + Admin combined, neither outranks the other. Aeon's Crew and Aeon
// sit above every individual server's Host since they're tied to the game itself, not
// one hosted instance.
#define LEVEL_PLAYER      0
#define LEVEL_BUILDER     1
#define LEVEL_ADMIN       2
#define LEVEL_GM_HOST     3   // GM and Host share this level on purpose
#define LEVEL_AEONS_CREW  4
#define LEVEL_AEON        5

// TEMPORARY test lists for Builder/Admin/GM — there's no real promotion system yet (Host
// promoting players needs persistent server-side storage + its own verbs, not built yet).
// Add your own ckey to whichever list you want to test as, recompile, test, then remove
// it again. Host itself needs no list — see ResolveAdminLevel() below.
var/list/test_builders = list()
var/list/test_admins = list()
var/list/test_gms = list("guest3341048356")  // temp — Guest-3341048356, remove once done testing

// Aeon's Crew — close friends, hardcoded by ckey. Real list, not a test scaffold; add
// ckeys here as needed.
var/list/aeons_crew = list()

// Aeon — hardcoded to a single ckey. Fill in your own BYOND ckey (lowercase, stripped of
// punctuation — same form as the "ckey" var described in the DM guide).
#define AEON_CKEY "cerebella"

// Resolves this ckey's admin level. Called once per connection from client/New() in
// Code/Core/Main.dm.
proc/ResolveAdminLevel(ckey)
    if(ckey == AEON_CKEY)
        return LEVEL_AEON
    if(ckey in aeons_crew)
        return LEVEL_AEONS_CREW
    if(ckey == world.host)
        return LEVEL_GM_HOST
    if(ckey in test_gms)
        return LEVEL_GM_HOST
    if(ckey in test_admins)
        return LEVEL_ADMIN
    if(ckey in test_builders)
        return LEVEL_BUILDER
    return LEVEL_PLAYER

client
    var/adminLevel = LEVEL_PLAYER
    var/canBuild = FALSE   // Builder, GM/Host, Aeon's Crew, Aeon
    var/canAdmin = FALSE   // Admin, GM/Host, Aeon's Crew, Aeon

    // Sets adminLevel/canBuild/canAdmin fresh from ResolveAdminLevel() — never trust
    // anything already stored on this client, always recompute from the hardcoded data.
    proc/ApplyAdminLevel()
        adminLevel = ResolveAdminLevel(ckey)
        canBuild = (adminLevel == LEVEL_BUILDER || adminLevel >= LEVEL_GM_HOST)
        canAdmin = (adminLevel == LEVEL_ADMIN || adminLevel >= LEVEL_GM_HOST)
        SyncGMVerbs()

    // Every verb below now lives in the single consolidated "GM" category (Stage 5
    // verb reorg — was split across Admin/Builder/GM). This used to only cover
    // GMtogglelog ("every OTHER GM verb here is still visible-to-everyone-but-
    // rejected-on-use" per the old comment, matching TODOList.md's Admin verbs note) —
    // extended to all 10 so a player without sufficient access doesn't see a verb they
    // can't use at all, instead of seeing it and getting rejected on click. Each verb
    // still keeps its own internal canBuild/canAdmin/adminLevel check too (defense in
    // depth) — this only controls whether it's offered in the first place. Verbs live
    // per-mob, not per-client, so this needs re-running whenever `mob` changes — called
    // here (ApplyAdminLevel(), covers the initial mob/playerTemp) and again from
    // FinalizePlayer() (LoginMenu.dm)/LoadCharacter() (SaveSystem.dm)/BecomeSage()
    // (PlayerTemplate.dm) once the real mob/player character takes over.
    //
    // MAINTENANCE NOTE: this is the one central place a verb's access tier is
    // declared — its own internal check (e.g. GMmaketurf's `if(!client.canBuild)`)
    // only rejects on USE, it doesn't hide the verb. A future GM verb that gets its
    // internal check right but isn't added to one of the three lists below will still
    // be visible-but-rejected for anyone below that tier — the exact bug this proc was
    // extended to fix for the other 10. DM verbs can't carry their own custom
    // metadata to read back generically here, so there's no way to derive these lists
    // automatically; a new GM verb needs a manual entry below.
    proc/SyncGMVerbs()
        if(!mob) return

        var/list/builderVerbs = list(
            /mob/verb/TestBuilderVerb,
            /mob/verb/GM_Create_Lockable,
            /mob/verb/GMseeareas,
            /mob/verb/GMmaketurf,
            /mob/verb/GMmakemob,
            /mob/verb/GMmakearea,
            /mob/verb/GMmaketool,
        )
        var/list/adminVerbs = list(
            /mob/verb/TestAdminVerb,
            /mob/verb/GMghostIconform,
            /mob/verb/GMToggleProfanityFilter,
        )
        var/list/gmHostVerbs = list(
            /mob/verb/GMdaynight,
            /mob/verb/GMtogglelog,
            /mob/verb/GMlevelincrease,
            /mob/verb/GMbattlemode,
        )

        if(canBuild)
            mob.verbs += builderVerbs
        else
            mob.verbs -= builderVerbs

        if(canAdmin)
            mob.verbs += adminVerbs
        else
            mob.verbs -= adminVerbs

        if(adminLevel >= LEVEL_GM_HOST)
            mob.verbs += gmHostVerbs
        else
            mob.verbs -= gmHostVerbs

// -----------------------------
// Test verbs — confirm who gets what before any real Builder/Admin tools exist
// -----------------------------
mob/verb/TestBuilderVerb()
    set category = "GM"
    set desc = "Test verb - requires Builder-category access"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    src << output("Builder test verb worked! (adminLevel=[client.adminLevel])", "Info")

mob/verb/TestAdminVerb()
    set category = "GM"
    set desc = "Test verb - requires Admin-category access"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    src << output("Admin test verb worked! (adminLevel=[client.adminLevel])", "Info")
