// -----------------------------
// Text Filter
// -----------------------------
// Shared word-list filter for anything player-typed — character names, chat, etc.
// (adultServer is defined in Main.dm alongside the other shared config.)

// Slurs/hate speech — enforced regardless of adultServer. Deliberately left empty;
// fill in with your own curated list rather than anything auto-generated.
var/list/banned_words_always = list()

// General profanity — only enforced when adultServer is FALSE. Small test list.
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

    // Sexual insults
    "dickhead",
    "dickheads",
    "dumbfuck",
    "dumbfucks",

    // Insults
    "bitch",
    "bitches",
    "bitchy",
    "sonofabitch",
    "sonofabitches",

    "asshole",
    "assholes",
    "jackass",
    "jackasses",
    "dumbass",
    "dumbasses",
    "smartass",
    "smartasses",

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
