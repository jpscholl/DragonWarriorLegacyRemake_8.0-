mob/verb/Interact()
    set hidden = 1   // don’t clutter verb panel
    // Get the turf one step in the direction the mob is facing
    var/turf/target = get_step(src, src.dir)

    if(target)
        // If the first turf is a counter, skip ahead one more space
        if(istype(target, /turf/furniture/counter))
            target = get_step(target, src.dir)

        // Now check for objects on that turf
        for(var/obj/O in target.contents)
            usr << output("You interact with [O].", "Info")
            // Do something with O here (open, pick up, etc.)
            return

        // If no objects, interact with the turf itself
        usr << output("You interact with [target].", "Info")