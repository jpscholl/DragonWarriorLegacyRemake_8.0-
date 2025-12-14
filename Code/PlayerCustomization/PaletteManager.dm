datum/PaletteManager
    var/class
    var/icon_id
    var/list/originalColors   // defaults
    var/list/colors           // current/custom

    New(_class, _icon_id)
        class = _class
        icon_id = _icon_id

        var/defaults = new /datum/DefaultIconColors().GetIconColors(class, icon_id)
        if(!defaults)
            world << "No base icon colors for [class]/[icon_id]"
            return

        originalColors = list()
        colors = list()
        for(var/zone in defaults)
            originalColors[zone] = defaults[zone]
            colors[zone] = defaults[zone]

    proc/GetZoneColor(zone)
        return colors[zone]

    proc/SetZoneColor(zone, newColor)
        if(!(zone in colors))
            world << "Invalid zone: [zone]"
            return
        colors[zone] = newColor

    proc/GetAllZones()
        return colors