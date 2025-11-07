mob/var/image/ghost
mob/var/in_ghostform = FALSE
mob/var/icon/original_icon

mob/proc/ToggleGhostForm()
	if(in_ghostform)
		view() << sound('spell.WAV', volume=100)
		in_ghostform = FALSE
		invisibility = 0
		density = 1
		overlays -= ghost
		if(client) client.images -= ghost
		ghost = null
		icon = original_icon
		icon_state = "world"
		src << output("You reappear!", "Info")
	else
		view() << sound('spell.WAV', volume=100)
		in_ghostform = TRUE
		original_icon = icon
		icon = null
		invisibility = 1
		density = 0
		ghost = image('phase.dmi', src)
		if(client) client.images += ghost
		src << output("You disappear!", "Info")

mob/verb/GMghostform()
	ToggleGhostForm()