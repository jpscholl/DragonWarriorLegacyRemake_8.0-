// -----------------------------
// Combat feedback HUD — bottom HUD (Level/HP/MP/EXP), floating combat numbers, and
// floating per-mob HP/MP bars. See Markdowns/CodeNotes.md for the reference
// screenshot/measurement basis behind the pixel constants below; every value is
// placeholder until seen tuned in-game.
// -----------------------------
#define HUD_LAYER 20                // the black backdrop bar
#define HUD_TEXT_LAYER 21           // text, drawn above the backdrop bar
#define METER_MAX_STEP 12           // meter.dmi/magicmeter.dmi/expmeter.dmi icon_states "0".."12"

#define HUD_GLYPH_SPACING 15
#define COMBATNUM_GLYPH_SPACING 8
#define HUD_BAR_HEIGHT 32
#define HUD_ROW_TOP 16
#define HUD_ROW_BOTTOM 0
#define HUD_COL_LEVEL 4
#define HUD_COL_LABEL 150
#define HUD_COL_CURRENT 215
#define HUD_COL_MAX 310

#define FLOATING_NUM_RISE_PIXELS 16
#define FLOATING_NUM_RISE_TIME 10   // deciseconds — total on-screen time
#define FLOATING_NUM_MOVE_TIME 5    // deciseconds — how long the pop-up rise itself takes
#define FLOATING_NUM_HOLD_TIME 7    // deciseconds — stays fully opaque this long before fading
#define FLOATING_NUM_Y_OFFSET 30    // px above the mob's own sprite origin
#define FLOATING_NUM_X_OFFSET 12    // px — shifts the number block right of tile-center

#define FLOATING_BAR_LAYER_OFFSET 0.5   // added to src.layer, keeps it above the mob
                                         // sprite and the weapon-swing overlay without
                                         // hardcoding a layer
#define FLOATING_BAR_Y_OFFSET 32        // px above the mob's own sprite origin
#define FLOATING_BAR_SPACING 9          // vertical gap between a mob's HP and MP bar
#define FLOATING_BAR_IDLE_HIDE_TIME 50  // deciseconds — 5s idle before the bars fade out

// Bitmap font glyphs are drawn in plain black in the source art — unreadable against
// most of the map, and BYOND's `color` var is a MULTIPLY tint (white*red=red, but
// black*red=black), so tinting would silently do nothing on unmodified black glyphs.
// Fix: swap black to white ONCE per font (cached), same icon.SwapColor() technique
// already used for player recoloring (RebuildIcon(), SaveSystem.dm).
var/list/whiteFontIconCache = list()
proc/GetWhiteFontIcon(fontFile)
    if(!whiteFontIconCache[fontFile])
        var/icon/whiteIcon = icon(fontFile)
        whiteIcon.SwapColor(rgb(0, 0, 0), rgb(255, 255, 255))
        whiteFontIconCache[fontFile] = whiteIcon
    return whiteFontIconCache[fontFile]

// -----------------------------
// Bitmap text — shared by the bottom HUD and floating combat numbers. Every character
// in `text` must be a real icon_state in `fontIcon`.
// -----------------------------
obj/screen/hudGlyph
    layer = HUD_TEXT_LAYER

obj/screen/hudBar
    icon_state = "0"
    layer = HUD_LAYER

// Builds a solid rectangle of `colorHex`, any size, from any existing icon — DM has no
// "blank canvas" icon constructor, so this starts from a known fully-opaque source,
// shrinks it to one pixel, then Blend()s with ICON_MULTIPLY (multiplying by pure black
// always yields black regardless of source pixel), then scales back up. Cached per
// (color,width,height).
var/list/solidColorIconCache = list()
proc/GetSolidColorIcon(colorHex, width, height)
    var/cacheKey = "[colorHex]_[width]x[height]"
    if(!solidColorIconCache[cacheKey])
        var/icon/I = icon('floor.dmi', "burntcobble")
        I.Scale(1, 1)
        I.Blend(colorHex, ICON_MULTIPLY)
        I.Scale(width, height)
        solidColorIconCache[cacheKey] = I
    return solidColorIconCache[cacheKey]

// Reuses existing glyph objects in place (just moves icon_state/screen_loc) instead of
// destroying and recreating the whole row every call — this runs on every Stat() tick,
// and the old remove-then-recreate approach visibly flickered the HUD text. Only the
// DELTA in length (e.g. HP going from 2 digits to 3) adds or removes an object.
proc/SetBitmapText(mob/player/M, list/row, text, fontIcon, glyphWidth, tileX, pixelX, tileY, pixelY, colorHex = "#ffffff")
    if(!M.client) return

    text = "[text]"
    var/textLen = length(text)

    for(var/i = 1 to textLen)
        var/ch = copytext(text, i, i + 1)
        var/obj/screen/hudGlyph/G
        if(i <= row.len)
            G = row[i]
        else
            G = new
            G.icon = GetWhiteFontIcon(fontIcon)
            M.client.screen += G
            row += G
        G.icon_state = ch
        G.color = colorHex
        G.screen_loc = "WEST+[tileX]:[pixelX + (i - 1) * glyphWidth],SOUTH+[tileY]:[pixelY]"

    // Trim leftover glyphs from a longer previous value, tail-first so removing one
    // doesn't shift the indices of ones still left to remove.
    for(var/i = row.len to textLen + 1 step -1)
        var/obj/screen/G = row[i]
        M.client.screen -= G
        del G
        row.Cut(i, i + 1)

// -----------------------------
// Bottom HUD — built lazily on first Stat() tick, refreshed every tick after that.
// -----------------------------
mob/player
    var
        obj/screen/hudBackdrop
        list/hudLevelLine = list()    // "Level: N"
        list/hudXPLine = list()       // "XP:NN.N%"
        list/hudHPLabel = list()      // "HP:"
        list/hudMPLabel = list()      // "MP:"
        list/hudHPCurrent = list()    // "cur/"
        list/hudMPCurrent = list()
        list/hudHPMax = list()        // "max"
        list/hudMPMax = list()

    proc/BuildHUD()
        if(!client || hudBackdrop) return   // no client yet, or already built (e.g. a relog)

        hudBackdrop = new
        hudBackdrop.icon = GetSolidColorIcon(rgb(0, 0, 0), TILE_WIDTH * 13, HUD_BAR_HEIGHT)
        hudBackdrop.layer = HUD_LAYER
        hudBackdrop.screen_loc = "WEST+0:0,SOUTH+0:0"
        client.screen += hudBackdrop

        UpdateHUD()

    // CONFIRMED OG behavior (live-tested 2026-08-30): the whole HUD's text turns green
    // at 25% HP or below, and a light red/pink once HP hits 0 — otherwise plain white.
    proc/GetHUDHealthColor()
        if(MaxHP <= 0) return "#ffffff"
        if(HP <= 0) return "#ff9999"
        if(HP <= MaxHP * 0.25) return "#00ff00"
        return "#ffffff"

    proc/UpdateHUD()
        if(!client) return
        if(!hudBackdrop) BuildHUD()

        var/hudColor = GetHUDHealthColor()

        SetBitmapText(src, hudLevelLine, "Level:[Level]", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_LEVEL, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudXPLine, "XP:[FormatPercent(Exp, Nexp)]%", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_LEVEL, 0, HUD_ROW_BOTTOM, hudColor)

        SetBitmapText(src, hudHPLabel, "HP:", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_LABEL, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudMPLabel, "MP:", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_LABEL, 0, HUD_ROW_BOTTOM, hudColor)

        SetBitmapText(src, hudHPCurrent, "[HP]/", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_CURRENT, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudMPCurrent, "[MP]/", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_CURRENT, 0, HUD_ROW_BOTTOM, hudColor)
        SetBitmapText(src, hudHPMax, "[MaxHP]", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_MAX, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudMPMax, "[MaxMP]", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_MAX, 0, HUD_ROW_BOTTOM, hudColor)

// -----------------------------
// Floating combat numbers — numbers.dmi (digits "0"-"9" plus "m"/"i"/"s" for "miss").
// World-space, not client-screen: spawned on the target's own turf so every nearby
// player sees the same pop.
// -----------------------------
obj/effect/combatNumber
    icon = 'numbers.dmi'
    density = FALSE
    mouse_opacity = 0
    layer = FLOATING_BAR_LAYER_OFFSET + 10   // above floating HP/MP bars

// `text` must be lowercase digits/m/i/s only. `colorHex` picks red (normal damage),
// yellow (crit), green (heal).
proc/ShowCombatNumber(atom/target, text, colorHex)
    if(!target) return
    var/turf/T = GetTurfOf(target)   // get_turf() isn't a builtin in this DM version
    if(!T) return

    text = "[text]"
    var/totalWidth = length(text) * COMBATNUM_GLYPH_SPACING
    var/startX = FLOATING_NUM_X_OFFSET - totalWidth / 2

    for(var/i = 1 to length(text))
        var/ch = copytext(text, i, i + 1)
        var/obj/effect/combatNumber/N = new(T)
        // numbers.dmi's own art is already white-fill/black-outline — NOT
        // GetWhiteFontIcon() here, which would swap the outline to white too and let
        // `color` tint the whole glyph solid instead of just the fill.
        N.icon = 'numbers.dmi'
        N.icon_state = ch
        N.color = colorHex
        N.pixel_x = startX + (i - 1) * COMBATNUM_GLYPH_SPACING
        N.pixel_y = FLOATING_NUM_Y_OFFSET
        // Pops up quickly, holds fully opaque, then fades over the remainder. Chained
        // animate() calls (no target after the first) continue from the previous
        // keyframe rather than restarting from N's original static vars.
        animate(N, pixel_y = N.pixel_y + FLOATING_NUM_RISE_PIXELS, time = FLOATING_NUM_MOVE_TIME)
        animate(time = FLOATING_NUM_HOLD_TIME - FLOATING_NUM_MOVE_TIME)
        animate(alpha = 0, time = FLOATING_NUM_RISE_TIME - FLOATING_NUM_HOLD_TIME)
        spawn(FLOATING_NUM_RISE_TIME)
            del N

// -----------------------------
// Floating HP/MP bars above any mob — players AND enemies alike. World-space /image
// overlays added directly to the mob, not client.screen, so they move with the mob for
// free and are visible to everyone who can see it. Always rebuilds a fresh /image
// rather than mutating icon_state on an existing one — BYOND's overlays list stores an
// immutable snapshot at add-time, so mutating an already-added image silently stops
// updating (the same bug already found and fixed for the Blaze cast meter, SkillDatum.dm).
// -----------------------------
mob
    var
        image/floatingHPBarImage
        image/floatingMPBarImage
        floatingHPHideSession = 0
        floatingMPHideSession = 0

    // HP and MP bars fade independently — HP shows on damage/healing, MP shows on
    // spell cast, both show while resting (SleepRestoreLoop, Turfs.dm). Session-
    // counter guard (same pattern as sleepSession/pendingSession elsewhere) so only
    // the last ShowFloating*Bar() call's hide timer wins.
    proc/ShowFloatingHPBar()
        UpdateFloatingHPBar()
        floatingHPHideSession++
        var/mySession = floatingHPHideSession
        spawn(FLOATING_BAR_IDLE_HIDE_TIME)
            if(src && floatingHPHideSession == mySession)
                HideFloatingHPBar()

    proc/ShowFloatingMPBar()
        if(!hasMana || MaxMP <= 0) return
        UpdateFloatingMPBar()
        floatingMPHideSession++
        var/mySession = floatingMPHideSession
        spawn(FLOATING_BAR_IDLE_HIDE_TIME)
            if(src && floatingMPHideSession == mySession)
                HideFloatingMPBar()

    proc/HideFloatingHPBar()
        if(floatingHPBarImage)
            overlays -= floatingHPBarImage
            floatingHPBarImage = null

    proc/HideFloatingMPBar()
        if(floatingMPBarImage)
            overlays -= floatingMPBarImage
            floatingMPBarImage = null

    proc/UpdateFloatingHPBar()
        if(isDead || HP <= 0)
            HideFloatingHPBar()
            return
        var/hpStep = MaxHP > 0 ? round(HP / MaxHP * METER_MAX_STEP) : 0
        var/image/newHP = image('meter.dmi', src, "[hpStep]")
        newHP.pixel_y = FLOATING_BAR_Y_OFFSET
        newHP.layer = src.layer + FLOATING_BAR_LAYER_OFFSET
        if(floatingHPBarImage) overlays -= floatingHPBarImage
        overlays += newHP
        floatingHPBarImage = newHP

    proc/UpdateFloatingMPBar()
        if(isDead || HP <= 0 || !hasMana || MaxMP <= 0)
            HideFloatingMPBar()
            return
        var/mpStep = round(MP / MaxMP * METER_MAX_STEP)
        var/image/newMP = image('magicmeter.dmi', src, "[mpStep]")
        newMP.pixel_y = FLOATING_BAR_Y_OFFSET - FLOATING_BAR_SPACING
        newMP.layer = src.layer + FLOATING_BAR_LAYER_OFFSET
        if(floatingMPBarImage) overlays -= floatingMPBarImage
        overlays += newMP
        floatingMPBarImage = newMP

    // Every mob gets its floating bars the moment it exists, so a full-health mob
    // shows them immediately rather than only after its first hit.
    New()
        . = ..()
        ShowFloatingHPBar()
        ShowFloatingMPBar()
