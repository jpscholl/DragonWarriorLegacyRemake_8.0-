// Ghost form variables
mob
    var/image/ghost
    var/in_ghostform = FALSE
    var/icon/original_icon

// Toggle ghost form on/off

mob/proc/ToggleGhostForm()
    // Play the spell sound for everyone nearby
    view() << sound('spell.WAV', volume = worldVolume)

    if(in_ghostform)
        // --- Exit ghost form ---
        in_ghostform   = FALSE
        invisibility   = 0
        density        = 1
        overlays      -= ghost
        if(client) client.images -= ghost
        ghost          = null
        icon           = original_icon
        icon_state     = "world"
        src << output("You reappear!", "Info")
    else
        // --- Enter ghost form ---
        in_ghostform   = TRUE
        original_icon  = icon
        icon           = null
        invisibility   = 1
        density        = 0
        ghost          = image('phase.dmi', src)
        if(client) client.images += ghost
        src << output("You disappear!", "Info")

// GM verb to toggle ghost form
mob/verb/GMghostform()
    ToggleGhostForm()