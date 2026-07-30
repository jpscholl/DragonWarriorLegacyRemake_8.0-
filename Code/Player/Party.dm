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
