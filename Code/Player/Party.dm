// -----------------------------
// Party Datum
// -----------------------------
// Real party data model (TODOList.md Phase 2/4) — name, leader, roster, and an
// experience-sharing toggle. Not saved/loaded; parties are session-only, same as
// OG behavior implied by "not a permanent tab" (StatPanels.dm / TODOList.md).
datum/party
    var/name
    var/mob/player/leader
    var/list/mob/player/members = list()
    var/shareExp = FALSE

    New(mob/player/founder, partyName)
        ..()
        name = partyName
        leader = founder
        members += founder
        founder.Party = src
        founder.isPartyLeader = TRUE
        founder.ShowPartyVerbs()

    // All party chatter/announcements share one color (dark green) so they read as
    // a single channel — confirmed look from OG testing (psays, join/leave, etc).
    proc/Broadcast(msg)
        for(var/mob/player/M in members)
            M << output("<font color='#006400'>[msg]</font>", "Messages")

    proc/AddMember(mob/player/M)
        members += M
        M.Party = src
        M.ShowPartyVerbs()
        Broadcast("[M.name] has joined [name].")

    proc/RemoveMember(mob/player/M)
        members -= M
        M.Party = null
        M.isPartyLeader = FALSE
        M.HidePartyVerbs()
        Broadcast("[M.name] has left [name].")

        if(!members.len)
            return

        if(M == leader)
            leader = members[1]
            leader.isPartyLeader = TRUE
            Broadcast("[leader.name] is now the party leader.")

// Must be called by every path that deletes a player mob — logging out, and returning to
// the character-select screen. Deleting a mob nulls variables that point at it but does
// NOT drop it from lists (verified 2026-09-10), so a member deleted while still in a
// party leaves a dead null sitting in members — inflating the count Die()'s exp split
// divides by, and never letting the party empty — while leader goes null with nobody
// promoted, stranding everyone else with no one able to kick or toggle exp sharing.
//
// Reclass (BecomeSage(), PlayerTemplate.dm) deliberately does NOT use this: it hands
// membership to the new mob instead, since changing class isn't leaving your party.
mob/player/proc/LeavePartyIfAny()
    if(Party) Party.RemoveMember(src)
