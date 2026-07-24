mob
    verb
        // -----------------------------
        // LOCAL EMOTE
        // -----------------------------
        Emote(msg as text)
            set category = "Social"
            set desc = "Chat to players in view"

            if(trimtext(msg) == "") return  // ignore empty messages
            msg = CensorText(msg)

            // Send an emote to all players in view
            // Styled in black, shows the player icon and emote text
            view() << output("<font color='black'> \icon[src]&lt;[src.name] [msg]&gt;</font>", "Messages")


        // -----------------------------
        // LOCAL SAY
        // -----------------------------
        Say(msg as text)
            set category = "Social"
            set desc = "Talk to players in view"

            if(trimtext(msg) == "") return  // ignore empty messages
            msg = CensorText(msg)

            // Send a spoken message to all players in view
            // Styled in blue, includes "says:" prefix
            view() << output("<font color='blue'> \icon[src]&lt;[src.name] says:&gt; [msg]</font>", "Messages")


        // -----------------------------
        // PRIVATE TELL
        // -----------------------------
        Tell(mob/M, msg as text)
            set category = "Social"
            set desc = "Directly talk to another player"

            if(trimtext(msg) == "") return  // ignore empty messages
            msg = CensorText(msg)
            if(M != src)
                // Message to the recipient, styled in navy
                M << output("<font color='navy'> \icon[src]&lt;[src] tells you:&gt; [msg]</font>", "Messages")

                // Confirmation back to the sender
                src << output("<font color='navy'> \icon[M]&lt;You tell [M]:&gt; [msg]</font>", "Messages")


        // -----------------------------
        // WHO LIST
        // -----------------------------
        Who()
            set category = "Social"
            set desc = "Shows all players logged in and basic info"

            // Header
            src << output("<b>Players currently online:</b>", "Info")

            // List each player in the global players list
            for(var/mob/M in players)
                // Currently hard-coded class, level, party info
                src << output("<font color='blue'> \icon[M] [M.name]([M.key]) <b>Class:</b> Hero <b>Level:</b> 1 <b>Party:</b> None</font>", "Info")


        // -----------------------------
        // WORLD EMOTE
        // -----------------------------
        WorldEmote(msg as text)
            set category = "Social"
            set desc = "Emote to all players in the world"

            if(trimtext(msg) == "") return  // ignore empty messages
            msg = CensorText(msg)

            // Send an emote to every player in the world
            // Styled in maroon
            players << output("<font color='maroon'> \icon[src]&lt;[src.name] [msg] to the world&gt;</font>", "Messages")


        // -----------------------------
        // WORLD SAY
        // -----------------------------
        WorldSay(msg as text)
            set category = "Social"
            set desc = "Chat to all players in the world"

            if(trimtext(msg) == "") return  // ignore empty messages
            msg = CensorText(msg)

            // Send a spoken message to every player in the world
            // Styled in purple, "wsays:" prefix distinguishes it from local Say
            players << output("<font color='purple'> \icon[src]&lt;[src.name] wsays:&gt; [msg]</font>", "Messages")
