//system to make it where you can add stat points by
//clicking on the stats in the stat panel
obj
	stat_link
		var
			label
			value

		New(_label, _value, _mob)
			label = _label
			value = _value
			name = "[label]: [value]"

		proc/Update(new_value)
			value = new_value
			name = "[label]: [new_value]"

		Click()
			if(usr && ismob(usr))
				var/mob/player/P = usr
				if(P.StatPoints > 0)
					P.StatPoints--
					P.vars[label] += 1
					Update(P.vars[label])