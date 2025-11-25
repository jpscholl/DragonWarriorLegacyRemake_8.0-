mob
    verb
        // -------------------- Local Emote --------------------
        Emote(msg as text)
            set category = "Social"
            set desc = "Chat to players in view"
            if(trimtext(msg) == "") return
            // Sends an emote to everyone in view, styled in black
            view() << output("<font color='black'> \icon[src]<[src.name] *[msg]*</font>", "Messages")

        // -------------------- Local Say --------------------
        Say(msg as text)
            set category = "Social"
            set desc = "Talk to players in view"
            if(trimtext(msg) == "") return
            // Sends a spoken message to everyone in view, styled in blue
            view() << output("<font color='blue'> \icon[src]<[src.name] says: [msg]</font>", "Messages")

        // -------------------- Private Tell --------------------
        Tell(mob/M, msg as text)
            set category = "Social"
            set desc = "Directly talk to another player"
            if(trimtext(msg) == "") return
            if(M != src)
                // Message to the recipient
                M << output("<font color='navy'> \icon[src]<[src] tells you: [msg]</font>", "Messages")
                // Confirmation back to the sender
                src << output("<font color='navy'> \icon[M]<You tell [M]: [msg]</font>", "Messages")

        // -------------------- Who List --------------------
        Who()
            set category = "Social"
            set desc = "Shows all players logged in and basic info"
            src << output("<b>Players currently online:</b>", "Info")
            for(var/mob/M in players)
                // Currently hard-coded class/level/party info
                src << output("<font color='blue'> \icon[M] [M.name] ([M.key]) Class: Hero Level: 1 Party: None</font>", "Info")

        // -------------------- World Emote --------------------
        WorldEmote(msg as text)
            set category = "Social"
            set desc = "Emote to all players in the world"
            if(trimtext(msg) == "") return
            // Sends an emote to everyone in the world, styled in maroon
            players << output("<font color='maroon'> \icon[src]<[src.name] [msg]</font>", "Messages")

        // -------------------- World Say --------------------
        WorldSay(msg as text)
            set category = "Social"
            set desc = "Chat to all players in the world"
            if(trimtext(msg) == "") return
            // Sends a spoken message to everyone in the world, styled in purple
            players << output("<font color='purple'> \icon[src]<[src.name] says: [msg]</font>", "Messages")