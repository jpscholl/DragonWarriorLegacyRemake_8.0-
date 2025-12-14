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
        // Soldier, Wizard, etc.
        colors_by_class["Soldier"] = list()
        colors_by_class["Wizard"] = list()
        // Add more icons as needed

    proc/GetIconColors(class, icon_id)
        if(!(class in colors_by_class))
            src << output("No default colors for class [class]", "Info")
            return list()
        if(!(icon_id in colors_by_class[class]))
            src << output("No default colors for icon [icon_id]", "Info")
            return list()
        return colors_by_class[class][icon_id]