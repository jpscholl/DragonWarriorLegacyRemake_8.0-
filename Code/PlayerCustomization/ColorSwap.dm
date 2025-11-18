//In depth list of colors
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

mob/proc/GetAllColorOptions()
    var/list/all_colors = list()
    for (var/name in palette.colors)
        all_colors[name] = palette.colors[name]
    return all_colors

mob/proc/UpdateAppearance()
    if (!selected_icon || !palette) return  // Defensive check
    var/icon/base = new /icon(selected_icon, icon_state)
    for (var/zone in palette.colors)
        var/original = palette.originalColors[zone]
        var/custom = palette.colors[zone]
        base.SwapColor(original, custom)
    src.icon = base


//these verbs bring up the list and allow players to select color
mob/verb/Set_Main()
    set category = "Set Colors"
    var/list/choices = color_swatches
    var/new_color = input("Choose Main Color:") in choices
    if(IsColorUsed(choices[new_color])) return
    src.palette.SetZoneColor("Main", choices[new_color])
    UpdateAppearance()

mob/verb/Set_Accent()
    set category = "Set Colors"
    var/list/choices = color_swatches
    var/new_color = input("Choose Accent Color:") in choices
    if (IsColorUsed(choices[new_color])) return
    src.palette.SetZoneColor("Accent", choices[new_color])
    UpdateAppearance()

mob/verb/Set_Hair()
    set category = "Set Colors"
    var/list/choices = color_swatches
    var/new_color = input("Choose Hair Color:") in choices
    if (IsColorUsed(choices[new_color])) return
    src.palette.SetZoneColor("Hair", choices[new_color])
    UpdateAppearance()

mob/verb/Set_Eyes()
    set category = "Set Colors"
    var/list/choices = color_swatches
    var/new_color = input("Choose Eyes Color:") in choices
    if (IsColorUsed(choices[new_color])) return
    src.palette.SetZoneColor("Eyes", choices[new_color])
    UpdateAppearance()


//scan for colors of icons and get rgb value of colors

proc/HexToRGB(hex)
    if (!istext(hex)) return null

    // Strip leading "#" if present
    if (copytext(hex, 1, 2) == "#")
        hex = copytext(hex, 2)

    // Validate length
    if (length(hex) != 6) return null

    // Extract and convert each pair
    var r = text2num("0x" + copytext(hex, 1, 3))
    var g = text2num("0x" + copytext(hex, 3, 5))
    var b = text2num("0x" + copytext(hex, 5, 7))

    return list(r, g, b)

mob/verb/TestHexToRGB()
    set category = "Debug"
    var input = input("Enter a hex color (e.g. #FF00FF or FF00FF):", "Hex to RGB") as text
    var rgb = HexToRGB(input)

    if (isnull(rgb))
        usr << "Invalid hex input. Please enter a 6-digit hex code."
    else
        usr << "RGB values: [rgb[1]], [rgb[2]], [rgb[3]]"

mob/verb/DebugSwatches()
    set category = "Debug"
    var/list/test = GetAllColorOptions()
    for(var/name in test)
        usr << "[name]: [test[name]]"


mob/proc/IsColorUsed(color)
    for(var/zone in palette.colors)
        if(palette.colors[zone] == color)
            return TRUE
    return FALSE


mob/proc/GetAllColorOptions_Debug()
    return color_swatches