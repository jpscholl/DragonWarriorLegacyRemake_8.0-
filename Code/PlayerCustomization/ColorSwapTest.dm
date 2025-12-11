// In depth list of colors
var/list/color_swatches = list(
    "Red" = rgb(255,0,0),
    "Green" = rgb(0,255,0),
    "Cyan" = rgb(0,255,255),
    "Blue" = rgb(0,0,255),
    "Yellow" = rgb(255,255,0),
    "Orange" = rgb(255,128,0),
    "Magenta" = rgb(255,0,255),
    "Purple" = rgb(128,0,128),
    "White" = rgb(255,255,255),
    "Gray" = rgb(128,128,128),
    "Black" = rgb(0,0,0),
    "Brown" = rgb(88,57,39))

// Apply palette swaps to preview (unchanged)
mob/proc/UpdateAppearance()
    if (!selected_icon || !palette || !preview_obj) return
    var/icon/base = new /icon(selected_icon)
    for (var/zone in palette.colors)
        var/original = palette.originalColors[zone]
        var/custom   = palette.colors[zone]   // rgb
        if(original && custom)
            base.SwapColor(original, custom)
    preview_obj.icon = icon(base)

// Color selection verbs (unchanged)
mob/proc/Set_Main()
    var/choice = input(src, "Pick a color") in color_swatches
    var/new_color = color_swatches[choice]
    palette.SetZoneColor("Main", new_color)
    UpdateAppearance()

mob/proc/Set_Accent()
    var/choice = input(src, "Pick a color") in color_swatches
    var/new_color = color_swatches[choice]
    palette.SetZoneColor("Accent", new_color)
    UpdateAppearance()

mob/proc/Set_Hair()
    var/choice = input(src, "Pick a color") in color_swatches
    var/new_color = color_swatches[choice]
    palette.SetZoneColor("Hair", new_color)
    UpdateAppearance()

mob/proc/Set_Eyes()
    var/choice = input(src, "Pick a color") in color_swatches
    var/new_color = color_swatches[choice]
    palette.SetZoneColor("Eyes", new_color)
    UpdateAppearance()

// Scan for colors of icons and get rgb value of colors (unchanged)
mob/proc/IsColorUsed(color)
    for(var/zone in palette.colors)
        if(palette.colors[zone] == color)
            return TRUE
    return FALSE

// -----------------------------
// Live icon rebuild + application
// -----------------------------
// Convert saved text choices -> palette rgb
mob/player/proc/ApplySavedColorsToPalette()
    if(!palette)
        palette = new /datum/PaletteManager(class, base_icon)
    if(hair_color && color_swatches[hair_color])
        palette.SetZoneColor("Hair", color_swatches[hair_color])
    if(eye_color && color_swatches[eye_color])
        palette.SetZoneColor("Eyes", color_swatches[eye_color])
    if(main_color && color_swatches[main_color])
        palette.SetZoneColor("Main", color_swatches[main_color])
    if(accent_color && color_swatches[accent_color])
        palette.SetZoneColor("Accent", color_swatches[accent_color])

// Set base icon and apply palette swaps to the live mob icon
mob/player/proc/RebuildIconLive()
    // Set base icon from saved base_icon
    icon = null
    if(base_icon)
        var/path = "Mob Icons/Player/" + base_icon
        icon = file(path)

    // Apply swaps on the live mob icon
    if(!palette || !icon) return src
    var/icon/working = new /icon(icon)
    for (var/zone in palette.colors)
        var/orig = palette.originalColors[zone]
        var/cust = palette.colors[zone]   // rgb
        if(orig && cust)
            working.SwapColor(orig, cust)
    src.icon = working
    return src

