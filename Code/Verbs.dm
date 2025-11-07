mob
	verb
		Change_Name(t as text)
			src.name = t
			src << "You changed your name to [src.name]"

		Save()
			//src.SaveProc()