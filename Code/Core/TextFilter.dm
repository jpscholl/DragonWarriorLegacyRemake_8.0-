// -----------------------------
// Text Filter
// -----------------------------
// Shared word-list filter for anything player-typed — character names, chat, etc.
// (adultServer is defined in Main.dm alongside the other shared config.)

// Slurs/hate speech — enforced regardless of adultServer.
var/list/banned_words_always = list(
	//Ethnic
	"nigger",
	"nig",
	"niglet",
	"nigglet",
	"honkey",
	"honky",
	"cracker",
	"whitedevil",
	"white devil",
	"darkie",
	"coon",
	"negro",
	"kike",
	"spic",
	"spick",
	"beaner",
	"wetback",
	"chink",
	"gook",
	"jap",
	"chinaman",
	"redskin",
	"injun",
	"sandnigger",
	"raghead",
	"towelhead",
	"wop",
	"guinea",
	"mick",
	"paddy",
	"heeb",
	"hymie",
	"nigga",
	"jigaboo",
	"spook",
	"sambo",
	"porchmonkey",
	"junglebunny",
	"spearchucker",
	"tarbaby",
	"dago",
	"polack",
	"kraut",
	"nip",
	"zipperhead",
	"gyp",
	"gypsy",
	"squaw",
	"camel jockey",
	"cameljockey",

	//Ableist
	"retard",
	"retarded",
	"spaz",
	"spastic",
	"mongoloid",
	"gimp",
	"cripple",

	//Homophobic/transphobic
	"dyke",
	"dike",
	"fag",
	"faggot",
	"fudgepacker",
	"tranny",
	"shemale",
	"heshe",
	"poof",
	"poofter"
)

// General profanity — only enforced when adultServer is FALSE.
var/list/banned_words_general = list(
    // Strong profanity
    "fuck",
    "fucks",
    "fucked",
    "fucker",
    "fuckers",
    "fucking",
    "fuckin",
    "motherfuck",
    "motherfucker",
    "motherfuckers",
    "motherfucking",

    // Shit
    "shit",
    "shits",
    "shitty",
    "shittier",
    "shittiest",
    "shithead",
    "shitheads",
    "shitface",
    "shitfaced",
    "bullshit",
    "horseshit",

    // Sexual profanity
    "cunt",
    "cunts",
    "twat",
    "twats",
    "cock",
    "cocks",
    "dick",
    "dicks",
    "pussy",
    "pussies",

    // Sexual insults
    "dickhead",
    "dickheads",
    "dumbfuck",
    "dumbfucks",
    "cocksucker",
    "cocksuckers",

    // Insults
    "bitch",
    "bitches",
    "bitchy",
    "sonofabitch",
    "sonofabitches",

    "asshole",
    "assholes",
    "arsehole",
    "arseholes",
    "jackass",
    "jackasses",
    "dumbass",
    "dumbasses",
    "smartass",
    "smartasses",
    "prick",
    "pricks",
    "wanker",
    "wankers",
    "bastard",
    "bastards",
    "slut",
    "sluts",
    "whore",
    "whores",

    // Other vulgar insults
    "douche",
    "douchebag",
    "douchebags",

    // Compound phrases
    "pieceofshit",
    "piece of shit",
    "fuckface",
    "fuckfaces",
    "fuckhead",
    "fuckheads",
    "dipshit",
    "dipshits"
)

// Returns TRUE if text contains a banned word for the current server mode (substring,
// case-insensitive) — so it also catches a banned word embedded inside a longer string.
// Used for names, where the whole entry just gets rejected outright.
proc/IsTextFiltered(text)
    var/lower = lowertext(text)

    for(var/word in banned_words_always)
        if(findtext(lower, word))
            return TRUE

    if(!adultServer)
        for(var/word in banned_words_general)
            if(findtext(lower, word))
                return TRUE

    return FALSE

// TRUE if ch (a single character) is a-z or A-Z — used to detect real word boundaries
// rather than treating any substring match as a hit.
proc/IsLetter(ch)
    var/code = text2ascii(ch)
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122)

proc/GetAsterisks(count)
    var/result = ""
    for(var/i = 1 to count)
        result += "*"
    return result

// Censors banned words found in text, replacing each with same-length asterisks, and
// returns the modified copy — unlike IsTextFiltered() (reject outright, used for names),
// this lets the message through with the offending word blanked out, for chat.
//
// Only matches whole words (checks the character immediately before/after each hit isn't
// a letter), so a banned word can't get flagged just because it's embedded inside an
// innocent longer word — e.g. banning "cunt" won't censor "Scunthorpe", banning "ass"
// won't censor "class". This is the classic "Scunthorpe problem" in content filtering.
proc/CensorText(text)
    var/list/words_to_check = banned_words_always.Copy()
    if(!adultServer)
        words_to_check += banned_words_general

    var/result = text

    for(var/word in words_to_check)
        var/wordLen = length(word)
        var/searchStart = 1

        while(TRUE)
            var/lower = lowertext(result)   // re-derive each pass since result may have changed
            var/pos = findtext(lower, word, searchStart)
            if(!pos) break

            var/beforeOK = (pos <= 1) || !IsLetter(copytext(lower, pos - 1, pos))
            var/afterPos = pos + wordLen
            var/afterOK = (afterPos > length(lower)) || !IsLetter(copytext(lower, afterPos, afterPos + 1))

            if(beforeOK && afterOK)
                // Same-length replacement keeps every other position in the string
                // stable, so we don't need to re-scan from the start after this.
                result = copytext(result, 1, pos) + GetAsterisks(wordLen) + copytext(result, pos + wordLen)

            searchStart = pos + 1

    return result

// -----------------------------
// Chat Log
// -----------------------------
// Every text chat verb (Say/Tell/Emote/WorldSay/WorldEmote/PartySay) logs here
// unconditionally — Tell is private and Say/Emote/PartySay only reach whoever's in
// view/party, so this is the only place a GM can audit any of it after the fact.
// Logged even when CheckMuted() blocks the message from actually displaying
// (SocialVerbs.dm/PartyVerbs.dm), so a muted player attempting to speak still leaves
// a paper trail. Writes straight to world.log (redirected to server.log, world/New()
// in Main.dm) rather than a separate file — matches a confirmed real excerpt from the
// OG's own server log, where connect/disconnect/host events and chat lines
// (`<Name(ckey) says:> msg`) all share one auto-timestamped stream. Each call site
// builds its own bracketed line to match that exact per-verb format (says/wsays/
// psays/tells, or bare for Emote/WorldEmote). BYOND's own auto-timestamp is time-only
// ([HH:MM:SS]) — the OG excerpt only had a full date on the session-start/-end banner
// lines, not per-message — so a full date+time is written explicitly into every line
// here rather than relying on that. No IP on chat lines — confirmed from a real OG
// excerpt, only login/logout lines carry one (and those spell it into the sentence
// itself, "logs in at 1.2.3.4.", rather than going through this proc).
//
// GM-toggleable (GMtogglelog(), GMCommands.dm) — loggingEnabled only gates OUR own
// lines here, not world.log itself: BYOND's automatic connect/disconnect/host events
// keep writing to server.log regardless (that's the engine, not something this can
// toggle without un-redirecting world.log entirely and losing those too).
var/global/loggingEnabled = TRUE

proc/LogChat(line)
    if(!loggingEnabled) return
    world.log << "[time2text(world.realtime, "YYYY-MM-DD hh:mm:ss")] [line]"
