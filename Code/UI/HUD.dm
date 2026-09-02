// -----------------------------
// Combat feedback HUD
// -----------------------------
// Wires up art that already existed in "UI & Effects/" (meter.dmi/magicmeter.dmi/
// expmeter.dmi/numbers.dmi/text.dmi) but had zero screen-object code behind it — the
// "HUD code" gap flagged as the highest-value remaining item in RemakeVsOGStructure.md,
// and explicitly carved into this build pass rather than deferred to the Big Beautiful
// Update (TODOList.md Phase 3, 2026-08-13 carve-out: bottom HUD + floating HP/MP meters
// + floating combat numbers are needed for combat to be legible/testable at all).
//
// PLACEHOLDER throughout: every pixel offset, glyph width, and timing value below is a
// guess — Claude can't drive the actual BYOND client to check alignment, so this is
// "compiles and runs," not "pixel-tuned." Expect a visual pass once it's actually seen
// in-game.
#define HUD_LAYER 20                // the black backdrop bar
#define HUD_TEXT_LAYER 21           // text, drawn above the backdrop bar
#define METER_MAX_STEP 12           // meter.dmi/magicmeter.dmi/expmeter.dmi have icon_states "0".."12"
                                     // (still used by the floating per-mob bars below —
                                     // the bottom HUD itself uses no bars, see BuildHUD())

// Real reference screenshot (2026-08-29): the bottom HUD is a single solid black bar,
// exactly 1 tile tall, spanning the full 13-tile view width, topmost layer — not a
// stat-panel, not bars. Two rows of plain white text: "Level: N" / "XP:NN.N%" on the
// left, "HP:"/"MP:" labels then "cur/" then "max" spread rightward.
//
// Real per-glyph measurements (Debug_MeasureFont(), DebugTools.dm, 2026-08-29) —
// text.dmi is a PROPORTIONAL font, not monospace: ink width ranged from 4px (":") to
// 14px ("e"/"8"/"%"), ink sits roughly y=3-16 within each glyph's 32x32 canvas.
// HUD_GLYPH_SPACING is a single fixed advance width covering the widest letter actually
// measured (14px) plus a small margin — not true kerning (narrow letters like "l"/":"
// get a little extra trailing gap), but no more overlap either. numbers.dmi measured
// separately (~8-9px ink) since it's a visibly smaller font used only for the floating
// combat numbers, not the bottom HUD.
#define HUD_GLYPH_SPACING 15
#define COMBATNUM_GLYPH_SPACING 8   // tightened from 11 -- "miss" (its narrowest glyph, "i") read with visible gaps at 11; checked digits still don't touch at 8
#define HUD_BAR_HEIGHT 32
#define HUD_ROW_TOP 16
#define HUD_ROW_BOTTOM 0
#define HUD_COL_LEVEL 4
#define HUD_COL_LABEL 150
#define HUD_COL_CURRENT 215
#define HUD_COL_MAX 310

#define FLOATING_NUM_RISE_PIXELS 16
#define FLOATING_NUM_RISE_TIME 10   // deciseconds — total on-screen time
#define FLOATING_NUM_MOVE_TIME 5    // deciseconds — how long the pop-up rise itself takes; snappier than the full hold below
#define FLOATING_NUM_HOLD_TIME 7    // deciseconds — stays fully opaque this long (holds in place once the rise above finishes), THEN fades over the remainder (was fading across the whole lifetime, which read as too transparent almost immediately)
#define FLOATING_NUM_Y_OFFSET 30    // px above the mob's own sprite origin

#define FLOATING_BAR_LAYER_OFFSET 0.5   // added to src.layer, keeps it above the mob
                                         // sprite and the weapon-swing overlay (target.layer
                                         // + 0.1, CombatSystem.dm) without hardcoding a layer
#define FLOATING_BAR_Y_OFFSET 32        // px above the mob's own sprite origin
#define FLOATING_BAR_SPACING 9           // vertical gap between a mob's HP and MP bar
#define FLOATING_BAR_IDLE_HIDE_TIME 50  // deciseconds — 5s idle before the bars fade out

// -----------------------------
// Bitmap font glyphs are drawn in plain black in the source art (both text.dmi and
// numbers.dmi) — reasonable for editing against Dream Maker's white-background icon
// editor, but two real problems in-game: (1) black text is unreadable against most of
// the map, and (2) BYOND's `color` var is a MULTIPLY tint, not a replacement — white
// times red is red, but black times red is still black, so ShowCombatNumber()'s
// red/yellow/green tinting below would silently do nothing on unmodified black
// glyphs. Fix: swap black to white ONCE per font (cached), exactly the same
// `icon.SwapColor()` technique already used for player recoloring (RebuildIcon(),
// SaveSystem.dm) — everything downstream (`color` tints, or plain white HUD text)
// then works the way a white base sprite normally would. Safe no-op if a font somehow
// turns out already-white.
var/list/whiteFontIconCache = list()
proc/GetWhiteFontIcon(fontFile)
    if(!whiteFontIconCache[fontFile])
        var/icon/whiteIcon = icon(fontFile)
        whiteIcon.SwapColor(rgb(0, 0, 0), rgb(255, 255, 255))
        whiteFontIconCache[fontFile] = whiteIcon
    return whiteFontIconCache[fontFile]

// -----------------------------
// Bitmap text — shared by the bottom HUD and floating combat numbers. Every character
// in `text` must be a real icon_state in `fontIcon` (digits in both fonts, "m"/"i"/"s"
// for numbers.dmi's "miss", A-Z/a-z/punctuation in text.dmi).
// -----------------------------
obj/screen/hudGlyph
    layer = HUD_TEXT_LAYER

obj/screen/hudBar
    icon_state = "0"
    layer = HUD_LAYER

// Builds a solid rectangle of `colorHex`, any size, from any existing icon — DM has no
// "blank canvas" icon constructor, so this starts from a known fully-opaque source
// (a floor turf's own sprite has no transparency, unlike an item/key silhouette),
// shrinks it to one pixel, then Blend()s with ICON_MULTIPLY: multiplying by pure black
// (0,0,0) always yields black regardless of the source pixel, so the starting icon's
// actual appearance never matters. Scaling that single black pixel back up gives a
// clean solid-color rectangle at any size. Cached per (color,width,height) since the
// black backdrop bar only ever needs building once per dimensions.
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
// which fires far more often than the "~1/sec" originally assumed here, and the old
// remove-then-recreate-everything approach was visibly flickering the HUD text as a
// result. Only the DELTA in length (e.g. HP going from 2 digits to 3) actually adds or
// removes an object now; same-length updates (the overwhelming majority) just mutate
// what's already on screen.
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

    // Trim any leftover glyphs from a longer previous value, from the tail backward
    // so removing one doesn't shift the indices of ones still left to remove.
    for(var/i = row.len to textLen + 1 step -1)
        var/obj/screen/G = row[i]
        M.client.screen -= G
        del G
        row.Cut(i, i + 1)

// -----------------------------
// Bottom HUD — Level/HP/MP/EXP, built lazily on first Stat() tick (same pattern
// StatPanels.dm already uses for its clickable stat links) and refreshed every tick
// after that.
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

        // Solid black bar, full 13-tile view width, exactly 1 tile tall, anchored to
        // the bottom edge, on top of everything else in view (real reference
        // screenshot, 2026-08-29).
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

        // Labels move here from BuildHUD() (previously built once and left alone) so
        // their color stays in sync with the rest of the HUD every tick too.
        SetBitmapText(src, hudHPLabel, "HP:", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_LABEL, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudMPLabel, "MP:", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_LABEL, 0, HUD_ROW_BOTTOM, hudColor)

        SetBitmapText(src, hudHPCurrent, "[HP]/", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_CURRENT, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudMPCurrent, "[MP]/", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_CURRENT, 0, HUD_ROW_BOTTOM, hudColor)
        SetBitmapText(src, hudHPMax, "[MaxHP]", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_MAX, 0, HUD_ROW_TOP, hudColor)
        SetBitmapText(src, hudMPMax, "[MaxMP]", 'text.dmi', HUD_GLYPH_SPACING, 0, HUD_COL_MAX, 0, HUD_ROW_BOTTOM, hudColor)

// -----------------------------
// Floating combat numbers — numbers.dmi (digits "0"-"9" plus "m"/"i"/"s" for "miss").
// World-space, not client-screen: spawned on the target's own turf so every nearby
// player sees the same pop, not just the one who caused it.
// -----------------------------
obj/effect/combatNumber
    icon = 'numbers.dmi'
    density = FALSE
    mouse_opacity = 0
    layer = FLOATING_BAR_LAYER_OFFSET + 10   // above floating HP/MP bars

// `text` must be lowercase digits/m/i/s only (numbers.dmi's real icon_states) —
// "miss" for a dodge, or a plain damage/heal number. `colorHex` picks red (normal
// damage), yellow (crit), green (heal) per the confirmed spec (TODOList.md Phase 3).
proc/ShowCombatNumber(atom/target, text, colorHex)
    if(!target) return
    var/turf/T = GetTurfOf(target)   // get_turf() isn't a builtin in this DM version (BuildTools.dm)
    if(!T) return

    text = "[text]"
    var/totalWidth = length(text) * COMBATNUM_GLYPH_SPACING
    var/startX = -totalWidth / 2   // centers the whole string over the target's tile

    for(var/i = 1 to length(text))
        var/ch = copytext(text, i, i + 1)
        var/obj/effect/combatNumber/N = new(T)
        // numbers.dmi's own art is already white-fill/black-outline (confirmed by
        // rendering it directly) — NOT GetWhiteFontIcon(), which swaps every black
        // pixel to white before tinting. That's correct for text.dmi's plain-black
        // glyphs (SetBitmapText, below), but on numbers.dmi it was swapping the
        // outline to white too, so `color` below tinted the WHOLE glyph solid —
        // outline included — instead of just the fill. Left untouched, black×color
        // stays black (BYOND's `color` is a multiply tint) so the outline survives on
        // its own with no swap needed at all.
        N.icon = 'numbers.dmi'
        N.icon_state = ch
        N.color = colorHex
        N.pixel_x = startX + (i - 1) * COMBATNUM_GLYPH_SPACING
        N.pixel_y = FLOATING_NUM_Y_OFFSET
        // Pops up to its full rise height quickly (FLOATING_NUM_MOVE_TIME), then holds
        // there fully opaque until FLOATING_NUM_HOLD_TIME, THEN fades out over the
        // remainder — previously the rise and the opacity hold were the same duration
        // (a slower pop) and alpha faded linearly across the WHOLE lifetime (washed-out
        // almost as soon as it appeared). Chained animate() calls (no target after the
        // first) continue from the previous keyframe rather than restarting from N's
        // original static vars; a plain `time=` with no properties is just a hold.
        animate(N, pixel_y = N.pixel_y + FLOATING_NUM_RISE_PIXELS, time = FLOATING_NUM_MOVE_TIME)
        animate(time = FLOATING_NUM_HOLD_TIME - FLOATING_NUM_MOVE_TIME)
        animate(alpha = 0, time = FLOATING_NUM_RISE_TIME - FLOATING_NUM_HOLD_TIME)
        spawn(FLOATING_NUM_RISE_TIME)
            del N

// -----------------------------
// Floating HP/MP bars above any mob — players AND enemies alike (TODOList.md: "this one
// needs to work for any mob in view, not just yourself"). World-space /image overlays
// added directly to the mob, not client.screen, so they move with the mob for free and
// are visible to everyone who can see it.
//
// Always rebuilds a fresh /image rather than mutating icon_state on the existing one —
// BYOND's overlays list stores an immutable snapshot at the moment an image is added,
// so mutating an already-added image silently stops updating what's on screen (the
// exact bug already found and fixed once for the Blaze cast meter, SkillDatum.dm).
// -----------------------------
mob
    var
        image/floatingHPBarImage
        image/floatingMPBarImage
        floatingHPHideSession = 0
        floatingMPHideSession = 0

    // HP and MP bars fade independently — HP shows on damage/healing, MP shows on
    // spell cast, and both show while resting in bed (SleepRestoreLoop, Turfs.dm).
    // Each pair below rebuilds+shows one bar and (re)starts ITS OWN idle-hide
    // countdown. Session-counter guard, same one-shot-timer pattern used elsewhere in
    // this codebase (sleepSession, Turfs.dm; pendingSession, SmoothMovement.dm) — each
    // call invalidates any hide already in flight for that bar, so only the last call
    // wins.
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

    // Every mob (player or enemy) gets its floating bars the moment it exists, so a
    // full-health mob shows them immediately rather than only after its first hit —
    // ShowFloatingHPBar()/ShowFloatingMPBar(), not the Update procs directly, so a mob
    // that just sits there still fades out after FLOATING_BAR_IDLE_HIDE_TIME.
    New()
        . = ..()
        ShowFloatingHPBar()
        ShowFloatingMPBar()
