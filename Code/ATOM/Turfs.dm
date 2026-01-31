//these are the collections of turf stuff that makes da world that you play in

//grass: dis is ground...you walk on it
turf
	ground
		icon = 'grass.dmi'
		density = 0

		grass
			name = "grass"
			icon_state = "grass"

		brush
			name = "brush"
			icon_state= "brush"

		flowers
			name = "flowers"
			icon_state= "flowers"

		farmland
			name = "farmland"
			icon_state= "farmland"

		cavedirt
			name = "dirt"
			icon_state = "cavedirt"

		sand
			name = "sand"
			icon_state = "sand"

//floor: this is what you get on after you open the door and before you walk the dinosaur
//also you walk on it like ground
	floor
		icon = 'floor.dmi'
		density = 0

		cobble
			name = "cobble"
			icon_state = "redcobble"

		burntcobble
			name = "cobble"
			icon_state = "burntcobble"

		carpet
			name = "floor"
			icon_state = "carpet"

		woodfloor
			name = "floor"
			icon_state = "woodfloor"

		stool
			name = "stool"
			icon_state= "stool"

		woodchair
			name = "chair"
			icon_state= "chair"

		path
			name = "path"
			icon_state= "path"


//tables: don't flip these please

//where the hell did it go???
/*
turf/table/longtablecenter
	name = "table"
	icon = 'table.dmi'
	icon_state= "woodcenter"
	density = 1
*/

	furniture
		icon = 'table.dmi'
		density = 1

		table
			name = "table"
			icon_state= "table"

		woodtable
			name = "table"
			icon_state= "woodtable"

		stonetable
			name = "table"
			icon_state= "stonetable"

		woodtableleft
			name = "table"
			icon_state= "woodtableleft"

		woodtableright
			name = "table"
			icon_state= "woodtableright"

		plant
			name = "plant"
			icon_state= "plant"

		stove
			name = "stove"
			icon_state= "stove"
//interaction causes prompt to cook food (if in inventory)

		curtains
			name = "curtains"
			icon = 'wall.dmi'
			icon_state = "curtains"

		statue
			name = "statue"
			icon_state = "statue"

		tub
			name = "tub"
			icon_state= "tub"
//interaction grabs glasses of water

		bedleft
			name = "bed"
			icon_state= "bedleft"
//interaction causes player to sleep on bed and gradually restore health/magic

		bedright
			name = "bed"
			icon_state= "bedright"

		woodbedleft
			name = "bed"
			icon_state= "woodbedleft"
//interaction causes player to sleep on bed and gradually restore health/magic

		woodbedright
			name = "bed"
			icon_state= "woodbedright"

		counter
			name = "counter"
			icon_state = "counter"
//able to interact with npcs behind it (extra space away)

		throneright
			name = "throne"
			icon_state = "throneright"

		throneleft
			name = "throne"
			icon_state = "throneleft"

		thronecenter
			name = "throne"
			icon_state = "thronecenter"

		thronearm
			name = "throne"
			icon_state = "thronedown"

		evilthrone
			name = "throne"
			icon_state = "evilthrone"

//Trees: the leafy things that provide oxygen
	tree
		icon = 'tree.dmi'
		density = 1

		tree
			name = "tree"
			icon_state = "tree"

//stairs: no these aren't stairways to heaven just up or down a level
	stairs
		icon = 'stairs.dmi'
		density = 0


		stairsup
			name = "stairs"
			icon_state = "stoneup"
			Entered(atom/movable/A)
				if(ismob(A))
					var/mob/M = A
					var/turf/new_loc = locate(M.x, M.y, M.z + 1)
					if(new_loc)
						M.loc = new_loc
				view() << sound('stairs.wav', repeat = 0, volume = worldVolume)
//walking over causes player to warp one Z level up

		stairsdown
			name = "stairs"
			icon_state = "stonedown"
			Entered(atom/movable/A)
				if(ismob(A))
					var/mob/M = A
					var/turf/new_loc = locate(M.x, M.y, M.z - 1)
					if(new_loc)
						M.loc = new_loc
				view() << sound('stairs.wav', repeat = 0, volume = worldVolume)

//walking over causes player to warp one Z level down

		cavestairsup
			name = "stairs"
			icon_state = "caveup"

//walls: all and all we're just another brick in the wall
	wall
		icon = 'wall.dmi'
		name = "wall"
		density = 1

		stonewall
			icon_state = "stone"

		stonewalledge
			icon_state = "stoneedge"

		cobblewall
			icon_state = "cobble"

		cobblewalledge
			icon_state = "cobbleedge"

		cavewall
			icon_state = "cavewall"

		cavewalledge
			icon_state = "cavewalledge"

		logwall
			icon_state = "log"

		pillartop
			name = "pillar"
			icon_state = "pillarup"

		pillarbottom
			name = "pillar"
			icon_state = "pillardown"

		voidwall
			name = "void"
			icon_state = "void"

		woodwall
			icon_state = "wood"

		woodwalledge
			icon_state = "woodedge"

		wooddownleftcorner
			icon_state = "wooddownleft"

		wooddownrightcorner
			icon_state = "wooddownright"

		woodupleftcorner
			icon_state = "woodupleft"

		wooduprightcorner
			icon_state = "woodupright"

//Fence: I'm still on the fence about this
	fence
		name = "fence"
		icon = 'wall.dmi'
		density = 1

		fence
			icon_state = "fence"

		sandfence
			icon_state = "sandfence"

//something about sky here idk I got nothing
	sky
		name = "sky"
		icon = 'sky.dmi'
		density = 0

		sky
			icon_state = "sky"
//walking on this should drop you 1 Z level down

//don't go burning these...how else you supposed to get across water?
	bridge
		name = "bridge"
		icon = 'bridge.dmi'
		density = 0

		bridgev
			icon_state = "bridge"

		bridgeh
			icon_state = "bridgeh"

		stonebridge
			icon_state = "stonebridge"

//that's some high quality h20
	water
		name = "water"
		icon = 'water.dmi'
		density = 1

		water
			icon_state = "water"

		upedge
			name ="wall"
			icon_state = "upedge"

		downedge
			name = "water temple"
			icon_state = "downedge"

		rightedge
			name = "water temple"
			icon_state = "rightedge"

		leftedge
			name = "water temple"
			icon_state = "leftedge"

		upleftedge
			name = "water temple"
			icon_state = "upleftedge"

		uprightedge
			name = "wall"
			icon_state = "uprightedge"

		downleftedge
			name = "wall"
			icon_state = "downleftedge"

		downrightedge
			name = "wall"
			icon_state = "downrightedge"

//it teleports you duh
	warp
		name = "warp"
		icon = 'warp.dmi'

		warp
			icon_state = "warp"