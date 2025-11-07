datum/PaletteManager
    var/class
    var/icon_id
    var/list/originalColors
    var/list/colors

    New(_class, _icon_id)
        class = _class
        icon_id = _icon_id

        originalColors = baseIconColors[class][icon_id]
        colors = list()
        for(var/zone in originalColors)
            colors[zone] = originalColors[zone]  // start with defaults

    proc/GetZoneColor(zone)
        return colors[zone]

    proc/SetZoneColor(zone, newColor)
        if(!(zone in colors))
            world.log << "Invalid zone: [zone]"
            return
        if(islist(newColor))
            world.log << "Invalid color value: [newColor]"
            return
        colors[zone] = newColor

    proc/GetAllZones()
        return colors