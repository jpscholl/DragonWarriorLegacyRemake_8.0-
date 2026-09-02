// -----------------------------
// Chat delivery — shadow mute
// -----------------------------
// CONFIRMED 2026-08-25 (OG string table): mute in the original was SILENT to its target.
// The table carries GM-only "(Muted)<name(key) says:> ..." copies of every chat form
// alongside the normal ones, and GM_Mute's own confirmation reads "You have secretly
// [un]muted X" — the whole design is that a muted player keeps talking into a void,
// never learning they've been muted. The remake previously hard-muted instead, telling
// the target "You are muted and cannot speak." and sending nothing, which tips them off
// immediately and makes the mute useless as a moderation tool.
//
// DeliverChat() is now the single delivery path for every chat verb below (and PartySay,
// PartyVerbs.dm). Not muted: everyone in `audience` hears it, normally. Muted: only the
// speaker sees their own line (so nothing looks wrong from their side), plus every
// connected GM gets a "(Muted)" copy so moderation can still watch what they're saying.
mob
    proc/DeliverChat(list/audience, msg)
        if(!isMuted)
            audience << output(msg, "Messages")
            return

        // Speaker still sees their own message — this is what makes the mute invisible.
        src << output(msg, "Messages")

        // GM-visible copy. Tagged so a GM can tell at a glance that nobody else received
        // it, matching the OG's own "(Muted)<...>" prefix convention.
        for(var/mob/player/P in players)
            if(P == src) continue
            if(P.client && P.client.canAdmin)
                P << output("<font color='gray'>(Muted)</font> [msg]", "Messages")

    // Retained so existing callers keep compiling, but it no longer speaks to the target
    // — see DeliverChat() above. Returns whether this mob is muted, for any caller that
    // needs to branch on it without sending anything.
    proc/CheckMuted()
        return isMuted

// -----------------------------
// World chat rate limit
// -----------------------------
// CONFIRMED 2026-08-25 (OG string table): "You must wait 1 second between each world say"
// and "You must wait 1 second between each world emote", backed by the OG's own
// `wsay_limit` var. WorldSay/WorldEmote reach every player on the server at once and had
// no throttle at all here before this. One shared timestamp for both, same as the OG's
// single var — spamming alternately between the two shouldn't dodge the limit.
#define WORLD_CHAT_COOLDOWN 10  // world.time units (1 real second)

// Chat range tiers. Say uses the client's own view (world.view is 13x13, i.e. 6 tiles
// out — Main.dm), so these bracket it on either side. PLACEHOLDER distances: the OG's
// exact whisper/shout radii aren't recovered, only that the three tiers existed and
// were ordered this way.
#define WHISPER_RANGE 1
#define SHOUT_RANGE 12

mob/var/wsayLimit = 0

// CONFIRMED OG (strings: "You turn off worldsay and worldemote." / "X deactivates
// worldsay."). Opting out is public — everyone is told — which is the point: it stops
// people quietly ignoring world chat and then being blamed for not answering.
mob/var/worldChatEnabled = TRUE

mob/verb/ToggleWorldSay()
    set category = "Social"
    set desc = "Turn world say and world emote on or off for yourself"

    worldChatEnabled = !worldChatEnabled
    src.ShowInfo("You turn [worldChatEnabled ? "on" : "off"] worldsay and worldemote.")
    players << output("<font color='purple'>[src.name]([src.key]) [worldChatEnabled ? "activates" : "deactivates"] worldsay.</font>", "Messages")

// Everyone who currently wants world chat. Opting out silences both directions — a
// player who isn't listening doesn't get to broadcast either.
proc/WorldChatAudience()
    var/list/listeners = list()
    for(var/mob/player/P in players)
        if(P.worldChatEnabled) listeners += P
    return listeners

mob
    // Returns TRUE (and explains why) if this mob is still inside the world-chat
    // cooldown. Unlike the mute check above, this one DOES tell the player — it's a
    // rate limit, not a moderation action, and the OG shows the message too.
    proc/WorldChatThrottled(what)
        if(world.time - wsayLimit < WORLD_CHAT_COOLDOWN)
            src.ShowInfo("You must wait 1 second between each world [what]")
            return TRUE
        wsayLimit = world.time
        return FALSE

    verb
        // -----------------------------
        // LOCAL EMOTE
        // -----------------------------
        Emote(msg as text)
            set category = "Social"
            set desc = "Chat to players in view"

            if(trimtext(msg) == "") return  // ignore empty messages
            LogChat("<[src.name]([src.key]) [msg]>", src)
            msg = CensorText(msg)

            // Send an emote to all players in view
            // Styled in black, shows the player icon and emote text
            DeliverChat(view(src), "<font color='black'> \icon[src]&lt;[src.name] [msg]&gt;</font>")


        // -----------------------------
        // LOCAL SAY
        // -----------------------------
        Say(msg as text)
            set category = "Social"
            set desc = "Talk to players in view"

            if(trimtext(msg) == "") return  // ignore empty messages
            LogChat("<[src.name]([src.key]) says:> [msg]", src)
            msg = CensorText(msg)

            // Send a spoken message to all players in view
            // Styled in blue, includes "says:" prefix
            DeliverChat(view(src), "<font color='blue'> \icon[src]&lt;[src.name] says:&gt; [msg]</font>")


        // -----------------------------
        // WHISPER — shorter range than Say
        // -----------------------------
        // CONFIRMED OG (string table carries both "(Muted)<name(key) whispers:>" and
        // "<name(key) whispers:>" forms alongside says/shouts). The OG's chat was tiered
        // by range: whisper reaches only the tiles immediately around you, Say reaches
        // your view, Shout reaches well past it. The remake only had the middle tier.
        Whisper(msg as text)
            set category = "Social"
            set desc = "Talk quietly to players standing right next to you"

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) whispers:> [msg]", src)
            msg = CensorText(msg)

            DeliverChat(view(WHISPER_RANGE, src), "<font color='gray'> \icon[src]&lt;[src.name] whispers:&gt; [msg]</font>")


        // -----------------------------
        // SHOUT — longer range than Say
        // -----------------------------
        Shout(msg as text)
            set category = "Social"
            set desc = "Talk loudly to players well beyond your normal view"

            if(trimtext(msg) == "") return
            LogChat("<[src.name]([src.key]) shouts:> [msg]", src)
            msg = CensorText(msg)

            DeliverChat(view(SHOUT_RANGE, src), "<font color='red'> \icon[src]&lt;[src.name] shouts:&gt; [msg]</font>")


        // -----------------------------
        // PRIVATE TELL
        // -----------------------------
        Tell(mob/M, msg as text)
            set category = "Social"
            set desc = "Directly talk to another player"

            if(trimtext(msg) == "") return  // ignore empty messages
            LogChat("<[src.name]([src.key]) tells [M.name]([M.key]):> [msg]", src)
            msg = CensorText(msg)
            if(M != src)
                // Recipient's copy goes through DeliverChat() so a muted sender's Tell
                // silently doesn't arrive, same as every other chat form.
                DeliverChat(list(M), "<font color='navy'> \icon[src]&lt;[src] tells you:&gt; [msg]</font>")

                // Confirmation back to the sender — direct, not via DeliverChat(), since
                // this line is always meant for the sender alone and a muted sender must
                // still see it for the mute to stay invisible.
                src << output("<font color='navy'> \icon[M]&lt;You tell [M]:&gt; [msg]</font>", "Messages")


        // -----------------------------
        // WHO LIST
        // -----------------------------
        Who()
            set category = "Social"
            set desc = "Shows all players logged in and basic info"

            // Header
            src.ShowInfo("<b>Players currently online:</b>")

            // List each player in the global players list
            for(var/mob/player/M in players)
                src.ShowInfo("<font color='blue'> \icon[M] [M.name]([M.key]) <b>Class:</b> [M.class] <b>Level:</b> [M.Level] <b>Party:</b> [M.Party ? M.Party.name : "None"]</font>")


        // -----------------------------
        // WORLD EMOTE
        // -----------------------------
        WorldEmote(msg as text)
            set category = "Social"
            set desc = "Emote to all players in the world"

            if(trimtext(msg) == "") return  // ignore empty messages
            if(!worldChatEnabled)
                src.ShowInfo("You have worldsay turned off.")
                return
            if(WorldChatThrottled("emote")) return
            LogChat("<[src.name]([src.key]) [msg] to the world>", src)
            msg = CensorText(msg)

            // Send an emote to every player who hasn't opted out
            // Styled in maroon
            DeliverChat(WorldChatAudience(), "<font color='maroon'> \icon[src]&lt;[src.name] [msg] to the world&gt;</font>")


        // -----------------------------
        // WORLD SAY
        // -----------------------------
        WorldSay(msg as text)
            set category = "Social"
            set desc = "Chat to all players in the world"

            if(trimtext(msg) == "") return  // ignore empty messages
            if(!worldChatEnabled)
                src.ShowInfo("You have worldsay turned off.")
                return
            if(WorldChatThrottled("say")) return
            LogChat("<[src.name]([src.key]) wsays:> [msg]", src)
            msg = CensorText(msg)

            // Send a spoken message to every player who hasn't opted out
            // Styled in purple, "wsays:" prefix distinguishes it from local Say
            DeliverChat(WorldChatAudience(), "<font color='purple'> \icon[src]&lt;[src.name] wsays:&gt; [msg]</font>")
