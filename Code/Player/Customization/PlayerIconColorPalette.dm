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
        // Soldier, Wizard, etc. — empty for now, so those classes/icons render with
        // their plain template sprite and no custom-color support until filled in.
        // Add an entry per icon filename, sampled from the actual .dmi pixel colors
        // (not guessed), same shape as the Hero/dw3hero.dmi block above.
        colors_by_class["Soldier"] = list()
        colors_by_class["Wizard"] = list()
        colors_by_class["Fighter"] = list()
        colors_by_class["Pilgrim"] = list()
        colors_by_class["Goof-off"] = list()
        colors_by_class["Sage"] = list()

    proc/GetIconColors(class, icon_id)
        if(!(class in colors_by_class))
            src << output("No default colors for class [class]", "Info")
            return list()
        if(!(icon_id in colors_by_class[class]))
            src << output("No default colors for icon [icon_id]", "Info")
            return list()
        return colors_by_class[class][icon_id]