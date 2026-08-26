datum/PaletteManager
    var/class
    var/icon_id               // bare icon filename (e.g. "dw3hero.dmi") — NOT an /icon object,
                               // must match a key in DefaultIconColors.colors_by_class
    var/list/originalColors   // defaults
    var/list/colors           // current/custom

    New(_class, _icon_id, mob/M)
        class = _class
        icon_id = _icon_id

        var/defaults = new /datum/DefaultIconColors().GetIconColors(class, icon_id, M)
        if(!defaults)
            if(M) M << output("No base icon colors for [class]/[icon_id]", "Info")
            return

        originalColors = list()
        colors = list()
        for(var/zone in defaults)
            originalColors[zone] = defaults[zone]
            colors[zone] = defaults[zone]

    proc/GetZoneColor(zone)
        return colors[zone]

    proc/SetZoneColor(zone, newColor, mob/M)
        if(!(zone in colors))
            if(M) M << output("Invalid zone: [zone]", "Info")
            return
        colors[zone] = newColor