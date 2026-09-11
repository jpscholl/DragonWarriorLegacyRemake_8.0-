// Working state for the color-customization menu: which portrait is being edited, and
// which zones the player has explicitly chosen a color for so far.
//
// Only OVERRIDES are tracked. A zone the player never touched -- or reset back to
// default -- has no entry here at all, and that absence is the whole point: nothing gets
// painted over it, so it renders exactly as the art draws it and keeps following any
// later change to that art. Storing the default's literal color instead (what this used
// to do) froze the zone at whatever the default happened to be the moment the character
// was created, which no later fix could reach.
datum/PaletteManager
    var/icon_id                     // bare icon filename, e.g. "dw3hero.dmi"
    var/datum/PlayerIcon/entry      // registry entry (PlayerIconColorPalette.dm)
    var/list/overrides              // zone -> chosen color; a zone absent here uses the art as drawn

    New(_icon_id, list/_overrides, mob/M)
        icon_id = _icon_id
        entry = GetPlayerIcon(_icon_id)
        overrides = list()

        if(!entry)
            if(M) M.ShowInfo("No registered art for icon [_icon_id]")
            return

        // Carry in existing picks (a loaded character's saved colors), dropping anything
        // for a zone this icon doesn't actually have -- a leftover color nothing can
        // paint would otherwise sit in the save forever.
        if(_overrides)
            for(var/zone in _overrides)
                if(_overrides[zone] && (zone in entry.zoneDefaults))
                    overrides[zone] = _overrides[zone]

    // Zone names this icon has, in the order the menu should offer them.
    proc/Zones()
        return entry ? entry.zoneDefaults : list()

    // The player's explicit pick, or null if this zone is still following the art.
    proc/GetZoneColor(zone)
        return overrides[zone]

    // A null newColor clears the override, handing the zone back to the art.
    proc/SetZoneColor(zone, newColor, mob/M)
        if(!entry || !(zone in entry.zoneDefaults))
            if(M) M.ShowInfo("Invalid zone: [zone]")
            return
        if(newColor)
            overrides[zone] = newColor
        else
            overrides -= zone

    proc/ClearAll()
        overrides = list()
