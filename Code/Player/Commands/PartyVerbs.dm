// -----------------------------
// Party Verbs
// -----------------------------
// Party tab (partykick/leave/recruit/say/share/who) — hidden by default (see
// ShowPartyVerbs()/HidePartyVerbs(), PlayerTemplate.dm), only added to src.verbs
// once actually in a party. CreateParty() itself stays on the always-visible
// Social tab since you don't have a party yet when you'd call it.
var/list/PARTY_VERBS = list(
    /mob/player/verb/PartyKick,
    /mob/player/verb/PartyLeave,
    /mob/player/verb/PartyRecruit,
    /mob/player/verb/PartySay,
    /mob/player/verb/PartyShare,
    /mob/player/verb/PartyWho,
)

mob/player/verb/CreateParty()
    set category = "Social"
    set desc = "Found a new party"

    if(Party)
        src << output("<font color='#006400'>You're already in a party.</font>", "Messages")
        return

    var/partyName = input(src, "Name your party:", "Create Party") as text|null
    if(!partyName || !trimtext(partyName)) return
    partyName = CensorText(trimtext(partyName))

    new /datum/party(src, partyName)
    src << output("<font color='#006400'>[partyName] has been successfully created.</font>", "Messages")

// -----------------------------
// PARTY TAB
// -----------------------------
mob/player/verb/PartyKick(mob/player/M in Party.members)
    set category = "Party"
    set desc = "Remove a member from your party (leader only)"

    if(!Party) return
    if(!isPartyLeader)
        src << output("<font color='#006400'>Only the party leader can kick members.</font>", "Messages")
        return
    if(M == src)
        src << output("<font color='#006400'>Use Party Leave to leave your own party.</font>", "Messages")
        return

    Party.RemoveMember(M)

mob/player/verb/PartyLeave()
    set category = "Party"
    set desc = "Leave your current party"

    if(!Party) return
    Party.RemoveMember(src)

mob/player/verb/PartyRecruit(mob/player/M in view(src))
    set category = "Party"
    set desc = "Invite a nearby player into your party"

    if(!Party) return
    if(M == src) return
    if(M.Party)
        src << output("<font color='#006400'>[M.name] is already in a party.</font>", "Messages")
        return

    Party.AddMember(M)

mob/player/verb/PartySay(msg as text)
    set category = "Party"
    set desc = "Talk to your party only"

    if(!Party) return
    if(trimtext(msg) == "") return
    LogChat("<[src.name]([src.key]) psays ([Party.name]):> [msg]", src)
    if(CheckMuted()) return
    msg = CensorText(msg)

    Party.Broadcast("\icon[src]&lt;[src.name] psays:&gt; [msg]")

mob/player/verb/PartyShare()
    set category = "Party"
    set desc = "Toggle experience sharing for the party (leader only)"

    if(!Party) return
    if(!isPartyLeader)
        src << output("<font color='#006400'>Only the party leader can toggle experience sharing.</font>", "Messages")
        return

    Party.shareExp = !Party.shareExp
    Party.Broadcast("Experience sharing is now [Party.shareExp ? "ON" : "OFF"].")

mob/player/verb/PartyWho()
    set category = "Party"
    set desc = "List your party's members"

    if(!Party) return
    src << output("<font color='#006400'><b>[Party.name]</b></font>", "Messages")
    for(var/mob/player/M in Party.members)
        var/tag = (M == Party.leader) ? " Leader" : ""
        src << output("<font color='#006400'> \icon[M] [M.name]([M.key]) <b>Class:</b> [M.class] <b>Level:</b> [M.Level][tag]</font>", "Messages")
