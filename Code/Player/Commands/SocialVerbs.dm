// -----------------------------
// Chat delivery — shadow mute
// -----------------------------
// DeliverChat() is the single delivery path for every chat verb below (and PartySay,
// PartyVerbs.dm). Not muted: everyone in `audience` hears it, normally. Muted: only
// the speaker sees their own line (so nothing looks wrong from their side), plus every
// connected GM gets a "(Muted)" copy so moderation can still watch what they're saying
// — see Markdowns/CodeNotes.md for why this is deliberately silent rather than telling
// the muted player.
mob
    proc/DeliverChat(list/audience, msg)
        if(!isMuted)
            audience << output(msg, "Messages")
            return

        // Speaker still sees their own message — this is what makes the mute invisible.
        src << output(msg, "Messages")

        // GM-visible copy, tagged so a GM can tell at a glance nobody else received it.
        for(var/mob/player/P in players)
            if(P == src) continue
            if(P.client && P.client.canAdmin)
                P << output("<font color='gray'>(Muted)</font> [msg]", "Messages")

    // Filters a view() list down to only mobs sharing src's indoor/outdoor state — the
    // same area/ceiling boundary used by the roof-hiding system (Area.dm) and
    // GM_GhostForm's see_invisible recompute (GMCommands.dm). Used by Say/Emote so a
    // shout through a wall doesn't also carry through a ceiling.
    proc/IndoorAudience(list/candidates)
        var/turf/myTurf = loc
        var/mySide = myTurf && istype(myTurf.loc, /area/ceiling)
        var/list/matched = list()
        for(var/mob/M in candidates)
            var/turf/theirTurf = M.loc
            var/theirSide = theirTurf && istype(theirTurf.loc, /area/ceiling)
            if(theirSide == mySide) matched += M
        return matched

// -----------------------------
// World chat rate limit
// -----------------------------
#define WORLD_CHAT_COOLDOWN 10  // world.time units (1 real second)

// Say sits between these. Placeholder distances — the OG's exact whisper/shout radii
// aren't recovered, only that the three tiers existed and were ordered this way.
#define WHISPER_RANGE 1
#define SHOUT_RANGE 12

// Say/Emote reach further than the client's default view (13x13, world.view — Main.dm)
// so nearby players don't need to be on-screen to hear normal chat. view(10) is 21x21,
// the closest centered square to the requested 20x20 (view() is always odd-sized).
#define SAY_RANGE 10
#define EMOTE_RANGE 10

mob/var/wsayLimit = 0

// Opting out is public — everyone is told — so people can't quietly ignore world chat
// and then get blamed for not answering.
mob/var/worldChatEnabled = TRUE

mob/verb/ToggleWorldSay()
    set category = "Social"
    set desc = "Turn world say and world emote on or off for yourself"

    if(!RequireCanAct()) return
    worldChatEnabled = !worldChatEnabled
    src.ShowInfo("You turn [worldChatEnabled ? "on" : "off"] worldsay and worldemote.")
    players << output("<font color='purple'>[src.name]([src.key]) [worldChatEnabled ? "activates" : "deactivates"] worldsay.</font>", "Messages")

// Opting out silences both directions — a player who isn't listening doesn't get to
// broadcast either.
proc/WorldChatAudience()
    var/list/listeners = list()
    for(var/mob/player/P in players)
        if(P.worldChatEnabled) listeners += P
    return listeners

mob
    // Unlike the mute check above, this one DOES tell the player — it's a rate limit,
    // not a moderation action.
    proc/WorldChatThrottled(what)
        if(world.time - wsayLimit < WORLD_CHAT_COOLDOWN)
            src.ShowInfo("You must wait 1 second between each world [what]")
            return TRUE
        wsayLimit = world.time
        return FALSE

    verb
        Emote(msg as text)
            set category = "Social"
            set desc = "Chat to players in view"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) [msg]>")
            msg = CensorText(msg)
            DeliverChat(IndoorAudience(view(EMOTE_RANGE, src)), "<font color='black'> \icon[src]&lt;[src.name] [msg]&gt;</font>")

        Say(msg as text)
            set category = "Social"
            set desc = "Talk to players in view"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) says:> [msg]")
            msg = CensorText(msg)
            DeliverChat(IndoorAudience(view(SAY_RANGE, src)), "<font color='blue'> \icon[src]&lt;[src.name] says:&gt; [msg]</font>")

        // Shorter range than Say — see Markdowns/CodeNotes.md for the OG's three-tier
        // whisper/say/shout confirmation.
        Whisper(msg as text)
            set category = "Social"
            set desc = "Talk quietly to players standing right next to you"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) whispers:> [msg]")
            msg = CensorText(msg)
            DeliverChat(view(WHISPER_RANGE, src), "<font color='gray'> \icon[src]&lt;[src.name] whispers:&gt; [msg]</font>")

        // Longer range than Say.
        Shout(msg as text)
            set category = "Social"
            set desc = "Talk loudly to players well beyond your normal view"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) shouts:> [msg]")
            msg = CensorText(msg)
            DeliverChat(view(SHOUT_RANGE, src), "<font color='red'> \icon[src]&lt;[src.name] shouts:&gt; [msg]</font>")

        Tell(mob/M, msg as text)
            set category = "Social"
            set desc = "Directly talk to another player"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) tells [M.name]([M.key]):> [msg]")
            msg = CensorText(msg)
            if(M != src)
                // Through DeliverChat() so a muted sender's Tell silently doesn't arrive.
                DeliverChat(list(M), "<font color='navy'> \icon[src]&lt;[src] tells you:&gt; [msg]</font>")

                // Direct, not via DeliverChat() — always meant for the sender alone,
                // and a muted sender must still see it for the mute to stay invisible.
                src << output("<font color='navy'> \icon[M]&lt;You tell [M]:&gt; [msg]</font>", "Messages")

        Who()
            set category = "Social"
            set desc = "Shows all players logged in and basic info"
            if(!RequireCanAct()) return

            src.ShowInfo("<b>Players currently online:</b>")
            for(var/mob/player/M in players)
                src.ShowInfo("<font color='blue'> \icon[M] [M.name]([M.key]) <b>Class:</b> [M.class] <b>Level:</b> [M.Level] <b>Party:</b> [M.Party ? M.Party.name : "None"]</font>")

        WorldEmote(msg as text)
            set category = "Social"
            set desc = "Emote to all players in the world"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            if(!worldChatEnabled)
                src.ShowInfo("You have worldsay turned off.")
                return
            if(WorldChatThrottled("emote")) return
            LogChat("<[src.name]([src.key]) [msg] to the world>")
            msg = CensorText(msg)
            DeliverChat(WorldChatAudience(), "<font color='maroon'> \icon[src]&lt;[src.name] [msg] to the world&gt;</font>")

        WorldSay(msg as text)
            set category = "Social"
            set desc = "Chat to all players in the world"
            if(!RequireCanAct()) return

            if(trimtext(msg) == "") return
            if(!worldChatEnabled)
                src.ShowInfo("You have worldsay turned off.")
                return
            if(WorldChatThrottled("say")) return
            LogChat("<[src.name]([src.key]) wsays:> [msg]")
            msg = CensorText(msg)
            DeliverChat(WorldChatAudience(), "<font color='purple'> \icon[src]&lt;[src.name] wsays:&gt; [msg]</font>")
