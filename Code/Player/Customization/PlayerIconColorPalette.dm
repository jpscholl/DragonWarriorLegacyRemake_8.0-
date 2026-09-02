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
        // Soldier/Wizard's DW3 icons (TODOList.md Phase 1) — sampled by loading the
        // actual .dmi (they're PNG-formatted internally) and counting distinct pixel
        // colors. Unlike dw3hero.dmi above, which encodes Hair/Eyes/Main as three
        // barely-distinguishable-but-genuinely-separate palette entries (0,124,254 /
        // 0,124,250 / 0,124,255), dw3guard.dmi and dw3malewizard.dmi each only use ONE
        // real costume color in the actual pixel data (plus a shared skin tone and
        // white/near-white background/outline, neither of which is a customizable
        // zone) — so only "Main" is populated here. That's a real property of these
        // two sprites, not a shortcut: PaletteManager.dm only ever iterates whatever
        // zones are present in this list, so a missing Hair/Eyes/Accent entry just
        // means that zone has no visible effect on these icons, not a crash.
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