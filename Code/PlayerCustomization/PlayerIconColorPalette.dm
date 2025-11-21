// Declare the global list
var/list/baseIconColors

// Wrap all assignments inside a proc
proc/InitializeIconBaseColors()
    baseIconColors = list()

    // Hero class
    baseIconColors["Hero"] = list()
    baseIconColors["Hero"]['dw3hero.dmi'] = list(
        "Main"   = rgb(0,124,255),
        "Accent" = rgb(255,255,255),
        "Eyes"   = rgb(0,124,250),
        "Hair"   = rgb(0,124,254)
    )