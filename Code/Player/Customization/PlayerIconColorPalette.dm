// Stores default colors for every icon, organized by class
datum/DefaultIconColors
    var/list/colors_by_class

    New()
        colors_by_class = list()
        Initialize()

    proc/Initialize()
        // Hero class
        colors_by_class["Hero"] = list()
        colors_by_class["Hero"]["dw3hero.dmi"] = list(
            "Hair"   = rgb(0,124,254),
            "Eyes"   = rgb(0,124,250),
            "Main"   = rgb(0,124,255),
            "Accent" = rgb(255,255,255)
        )
        // Soldier/Wizard's DW3 icons only use ONE real costume color in the actual
        // pixel data, so only "Main" is populated — a real property of these sprites,
        // not a shortcut. See Markdowns/CodeNotes.md.
        colors_by_class["Soldier"] = list()
        colors_by_class["Soldier"]["dw3guard.dmi"] = list(
            "Main" = rgb(0,120,248)
        )
        colors_by_class["Wizard"] = list()
        colors_by_class["Wizard"]["dw3malewizard.dmi"] = list(
            "Main" = rgb(0,172,64)
        )
        colors_by_class["Fighter"] = list()
        colors_by_class["Pilgrim"] = list()
        colors_by_class["Goof-off"] = list()
        colors_by_class["Sage"] = list()

    proc/GetIconColors(class, icon_id, mob/M)
        if(!(class in colors_by_class))
            if(M) M.ShowInfo("No default colors for class [class]")
            return list()
        if(!(icon_id in colors_by_class[class]))
            if(M) M.ShowInfo("No default colors for icon [icon_id]")
            return list()
        return colors_by_class[class][icon_id]