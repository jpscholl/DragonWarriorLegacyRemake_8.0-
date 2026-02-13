// -----------------------------
// MOB COMBAT PROCS
// -----------------------------

mob/proc
    // Apply damage to this mob
    TakeDamage(damage, mob/attacker)
        if(HP <= 0) return

        flick("hit", src)
        view() << sound("hit.wav", channel = 1, volume = baseVolume)

        HP -= damage
        view(src) << output("[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

mob/proc
    // Remove this mob asynchronously
    CleanUpDead()
        spawn(100)  // async so attacking continues uninterrupted
        del src

mob/proc
    // Handle death: update XP, level, visual state
    Die(mob/attacker)
        view(src) << output("[src] has been defeated!", "Info")
        src.Exp += 10
        src.LevelCheck()
        src.density = 0
        src.icon_state = "sleep"

mob/proc
    // Level up check
    LevelCheck()
        if(src.Exp >= src.Nexp)
            src.Exp = 0
            src.Nexp += 10
            src.Level += 1
            src.StatPoints += 5
            src << output("You are now Level [src.Level]", "Info")
            src << sound('levelup.wav', channel = 2, volume = baseVolume)

mob/proc
    // Melee hit detection
    PerformMeleeHit(datum/skill/S)
        var/turf/T = get_step(src, dir)
        if(!T) return

        for(var/mob/M in T.contents)
            if(M == src) continue
            if(M.HP <= 0) continue

            var/damage = Strength
            M.TakeDamage(damage, src)

mob/proc
    // Spell damage helper
    ApplySpellDamage(mob/target, damage, element)
        if(!target) return
        target.TakeDamage(damage, src)
        // Can later add resistances, AoE, elemental effects

mob/proc
    // Stat-based delay for skill usage
    GetAttackDelay(datum/skill/S)
        if(S.isMelee)
            return max(4, 12 - Agility)          // melee uses Agility
        else if(S.isSpell)
            return max(6, 14 - Intelligence / 2) // spells use INT
        else
            return 10

mob/proc
    // Check if the mob is in a battle-enabled area
    InBattleArea()
        // Replace with real area logic
        return BattleModeEnabled

mob/proc
    // Play animations for skills
    PlayAttackAnimation(mob/user, datum/skill/S, mob/target = null)
        if(S.isMelee)
            flick("attack", user)
            user << sound('attack.wav', volume = 60)
            var/turf/targetTile = get_step(user, user.dir)
            if(targetTile)
                var/icon/weaponIcon = icon(user.icon, S.icon_state, user.dir)
                targetTile.overlays += weaponIcon
                spawn(2)
                    targetTile.overlays -= weaponIcon
        else if(S.isSpell)
            flick("cast", user)
            user << sound('spell.wav', volume = 70)
            if(target)
                var/icon/spellOverlay = icon(user.icon, S.icon_state)
                target.overlays += spellOverlay
                spawn(6)
                    target.overlays -= spellOverlay
