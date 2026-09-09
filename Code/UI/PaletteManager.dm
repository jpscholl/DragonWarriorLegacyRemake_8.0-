datum/PaletteManager
    var/class
    var/icon_id               // bare icon filename (e.g. "dw3hero.dmi") — NOT an /icon object,
                               // must match a key in DefaultIconColors.colors_by_class
    var/list/originalColors   // defaults
    var/list/colors           // current/custom

    New(_class, _icon_id, mob/M)
        class = _class
        icon_id = _icon_id

        // Always valid (if possibly empty) lists, regardless of whether real defaults
        // exist below -- confirmed 2026-09-09: the earlier version of this proc only
        // initialized these AFTER the no-defaults check, leaving them null on an early
        // return. RebuildIcon() (SaveSystem.dm) indexes palette.originalColors[zone]
        // unconditionally, and indexing a null list runtime-errors, aborting the whole
        // icon rebuild before `icon = playerIcon` ever ran -- a character whose icon
        // has no colors_by_class entry (e.g. Hero's dw1hero.dmi, Wizard's dw1wizard.dmi
        // -- only the dw3 variants are populated) loaded with NO sprite at all.
        originalColors = list()
        colors = list()

        var/list/defaults = new /datum/DefaultIconColors().GetIconColors(class, icon_id, M)
        // GetIconColors() returns list() (empty, not null) for a class/icon with no
        // entry yet in colors_by_class (PlayerIconColorPalette.dm) -- an empty list is
        // still truthy in DM, so `if(!defaults)` alone never caught this case. Without
        // the .len check, this warning never fired and every SetZoneColor() call
        // afterward failed with a much less obvious "Invalid zone" instead of pointing
        // at the real cause.
        if(!defaults || !defaults.len)
            if(M) M.ShowInfo("No base icon colors for [class]/[icon_id]")
            return

        for(var/zone in defaults)
            originalColors[zone] = defaults[zone]
            colors[zone] = defaults[zone]

    proc/GetZoneColor(zone)
        return colors[zone]

    proc/SetZoneColor(zone, newColor, mob/M)
        if(!(zone in colors))
            if(M) M.ShowInfo("Invalid zone: [zone]")
            return
        colors[zone] = newColor