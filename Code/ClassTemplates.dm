mob
	see_invisible = 1
	var
		class = null
		Level = 1
		HP = 30
		MaxHP = 30
		MP = 0
		MaxMP = 0
		Exp = 0
		Nexp = 100
		Strength = 1
		Vitality = 1
		Agility = 1
		Intelligence = 1
		Luck = 1
		StatPoints = 10

//wtf is this code???
	//login override
	//Login()
		//..()

//mob variables
	var/list/skills = list()
	var/datum/Skill/active_skill
	var/can_move = TRUE

	verb/UseSkill()
		if (!active_skill)
			usr << "No skill equipped."
			return
		active_skill.Activate(src, null)

	verb/EquipBasicAttack()
		set hidden = 1
		var/datum/skill/Attack/atk = new
		skills += atk
		active_skill = atk
		usr << "Equipped skill: [atk.name]"

	verb/Attack()
		set hidden = 1
		set desc = "Use your equipped skill"
		UseSkill()

	verb/Interact()
		set hidden = 1

//class overrides
mob/player/hero
	class = "Hero"
	MaxMP = 10

mob/player/soldier
	class = "Soldier"
	MaxMP = 0

mob/player/wizard
	class = "Wizard"
	MaxMP = 30