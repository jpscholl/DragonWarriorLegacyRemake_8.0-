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

    // GMtogglelog() (GMCommands.dm) only shows up in a GM's own verb panel — every
    // OTHER GM verb here is still visible-to-everyone-but-rejected-on-use (a known,
    // already-flagged gap, see TODOList.md's Admin verbs note), this establishes the
    // pattern for just this one rather than fixing all of them right now. Verbs live
    // per-mob, not per-client, so this needs re-running whenever `mob` changes — called
    // here (ApplyAdminLevel(), covers the initial mob/playerTemp) and again from
    // FinalizePlayer() (LoginMenu.dm)/LoadCharacter() (SaveSystem.dm) once the real
    // mob/player character takes over.
    proc/SyncGMVerbs()
        if(!mob) return
        if(adminLevel >= LEVEL_GM_HOST)
            mob.verbs += /mob/verb/GMtogglelog
        else
            mob.verbs -= /mob/verb/GMtogglelog

// -----------------------------
// Test verbs — confirm who gets what before any real Builder/Admin tools exist
// -----------------------------
mob/verb/TestBuilderVerb()
    set category = "Builder"
    set desc = "Test verb - requires Builder-category access"

    if(!client || !client.canBuild)
        src << output("You don't have Builder access.", "Info")
        return

    src << output("Builder test verb worked! (adminLevel=[client.adminLevel])", "Info")

mob/verb/TestAdminVerb()
    set category = "Admin"
    set desc = "Test verb - requires Admin-category access"

    if(!client || !client.canAdmin)
        src << output("You don't have Admin access.", "Info")
        return

    src << output("Admin test verb worked! (adminLevel=[client.adminLevel])", "Info")
