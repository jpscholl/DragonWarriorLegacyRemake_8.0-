// Ghost form variables
mob
    var/image/ghostIcon
    var/isGhostform = FALSE
    var/icon/baseIcon

// Toggle ghostIcon form on/off

mob/proc/ToggleGhostForm()
    // Play the spell sound for everyone nearby
    view() << sound('spell.WAV', volume = baseVolume)

    if(isGhostform)
        // --- Exit ghostIcon form ---
        isGhostform = FALSE
        invisibility = 0
        density = 1
        overlays -= ghostIcon
        if(client) client.images -= ghostIcon
        ghostIcon = null
        icon = baseIcon
        icon_state = "world"
        src << output("You reappear!", "Info")
    else
        // --- Enter ghostIcon form ---
        isGhostform = TRUE
        baseIcon = icon
        icon = null
        invisibility = 1
        density = 0
        ghostIcon = image('phase.dmi', src)
        if(client) client.images += ghostIcon
        src << output("You disappear!", "Info")

// GM verb to toggle ghostIcon form
mob/verb/GMghostIconform()
    ToggleGhostForm()