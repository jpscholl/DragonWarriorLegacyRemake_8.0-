// -----------------------------
// MOB COMBAT PROCS
// -----------------------------
// Shared by players AND enemies — every proc here is a plain mob/proc, not split by
// type, so the same code path handles "player attacks enemy" and "enemy attacks
// player" identically.
//
// Attack pipeline: UseSkillSlot()/AILoop() decides to attack -> PlayAttackAnimation()
// (visual/audio only) -> PerformMeleeHit()/ApplySpellDamage() finds who's hit and
// calls TakeDamage() -> TakeDamage() rolls dodge, applies damage, calls Die() +
// CleanUpDead() at 0 HP -> Die() credits the attacker's Exp/LevelCheck() and branches
// player-respawn vs. enemy-cleanup. See Markdowns/CodeNotes.md for OG-confirmation
// status of the numbers below.
#define DEATH_EXP_LOSS_PERCENT 5
#define DEATH_GOLD_LOSS_PERCENT 50
#define RESPAWN_AUTO_DELAY 600  // world.time units (60 real seconds)

mob/var/isDead = FALSE
mob/var/deathTime = 0

// Whoever landed the FIRST hit on this mob — Die() credits them, not whoever landed
// the killing blow, so a fight can't be sniped at the last moment.
mob/var/mob/firstAttacker = null

// Toggled by datum/skill/Defend (SkillDatum.dm) — TRUE while holding up a shield.
mob/var/isDefending = FALSE
#define DEFEND_DAMAGE_REDUCTION_PERCENT 50

// Bumped whenever isDefending is toggled BY THE PLAYER (Defend.OnUse()) — lets
// Attack.OnUse() auto-restore a defend stance it dropped mid-swing without stomping a
// manual toggle that happened in the meantime.
mob/var/defendToggleSession = 0

mob/proc
    // Drops an active defend stance for an attack/cast. Returns whether it was
    // actually defending, which the caller passes to RestoreDefendIfUntouched().
    DropDefendForAction()
        if(!isDefending) return FALSE
        isDefending = FALSE
        icon_state = "world"
        return TRUE

    // Re-raises the stance DropDefendForAction() dropped, unless the player toggled
    // Defend themselves in the meantime (mySession = defendToggleSession at drop time).
    RestoreDefendIfUntouched(wasDefending, mySession)
        if(wasDefending && defendToggleSession == mySession)
            isDefending = TRUE
            icon_state = "defend"

#define DODGE_BASE_PERCENT 0
#define DODGE_AGILITY_SCALE 1
#define DODGE_MAX_PERCENT 30

mob/proc
    RollDodge()
        var/dodgeChance = min(DODGE_MAX_PERCENT, DODGE_BASE_PERCENT + GetEffectiveAgility() * DODGE_AGILITY_SCALE)
        return prob(dodgeChance)

// Flat subtraction rather than percentage reduction — lets a heavily-invested tank
// shrug off weak hits entirely without a separate armor stat.
#define PHYSICAL_DEFENSE_DIVISOR 4
#define MAGIC_DEFENSE_DIVISOR 4
#define MIN_DAMAGE 1

mob/proc
    // defenseBonus/magicDefenseBonus are Increase/Barrier buffs (StatusEffects.dm);
    // equipDefenseBonus/equipMagicDefenseBonus are their amulet equivalents
    // (Inventory.dm) — added here rather than to the stats so neither trips a
    // stat-cap check or gets baked into a mid-buff/mid-equip save.
    GetDefense()
        return round((GetEffectiveAgility() + GetEffectiveVitality()) / PHYSICAL_DEFENSE_DIVISOR) + defenseBonus + equipDefenseBonus

    GetMagicDefense()
        return round((GetEffectiveVitality() + GetEffectiveIntelligence()) / MAGIC_DEFENSE_DIVISOR) + magicDefenseBonus + equipMagicDefenseBonus

// Rolled by the ATTACKER (reads src's own Spirit). Applies to both melee and spell
// damage — nothing says crit is melee-only.
#define CRIT_BASE_PERCENT 0
#define CRIT_SPIRIT_SCALE 1
#define CRIT_MAX_PERCENT 50
#define CRIT_DAMAGE_PERCENT 150

mob/proc
    RollCrit()
        var/critChance = min(CRIT_MAX_PERCENT, CRIT_BASE_PERCENT + GetEffectiveSpirit() * CRIT_SPIRIT_SCALE)
        return prob(critChance)

mob/proc
    // isMagic picks which defense stat mitigates the hit. isCrit only affects the
    // message shown — the damage number is expected to already include the crit
    // multiplier by the time it gets here. Returns whether the hit actually landed
    // (FALSE for already-dead/blocked/dodged) — Projectiles.dm's Launch() uses this to
    // decide whether a projectile stops here or keeps flying.
    TakeDamage(damage, mob/attacker, isMagic = FALSE, isCrit = FALSE)
        if(HP <= 0) return FALSE

        // No friendly fire on your own pet, and a pet can't hurt its own owner either
        // (RunWildAI() already avoids targeting its owner — this is the backstop for
        // any other path, e.g. a stray AoE).
        if(istype(src, /mob/enemy))
            var/mob/enemy/E = src
            if(E.owner && E.owner == attacker) return FALSE

        if(istype(attacker, /mob/enemy))
            var/mob/enemy/A = attacker
            if(A.owner && A.owner == src) return FALSE

        // Coop mode blocks player-vs-player damage unless the target's area allows
        // PvP (Area.dm's battleAllowsPvP) — separate from GM_BattleMode's monster-
        // aggro gate (InBattleArea()). GM-tier targets are exempt from the protection.
        if(istype(src, /mob/player) && istype(attacker, /mob/player))
            var/mob/player/targetP = src
            if(!(targetP.client && targetP.client.adminLevel >= LEVEL_GM_HOST))
                var/turf/pvpTurf = src.loc
                var/area/pvpArea = pvpTurf ? pvpTurf.loc : null
                if(!pvpArea || !pvpArea.battleAllowsPvP)
                    attacker.ShowInfo("Coop mode is active here — you cannot attack other players.")
                    return FALSE

        var/isEnemy = istype(src, /mob/enemy)

        if(RollDodge())
            // view(src), not bare view() — bare view() centers on usr, which is
            // unreliable outside a code path triggered directly by a verb (e.g. an
            // enemy's AILoop() calling this via PerformMeleeHit()).
            PlaySFXAt(src, isEnemy ? 'enemydodge.wav' : 'dodge.wav')
            view(src) << output("[src] dodges the attack!", "Info")
            ShowCombatNumber(src, "miss", "#ffffff")
            return FALSE

        flick("hit", src)
        PlaySFXAt(src, isEnemy ? 'enemyhit.wav' : 'hit.wav')

        // Defense subtracted before the defend-stance percentage, then floored — stops
        // a heavily-defended mob from ever taking a true zero.
        var/defense = isMagic ? GetMagicDefense() : GetDefense()
        damage = max(MIN_DAMAGE, damage - defense)

        if(isDefending)
            damage = round(damage * (100 - DEFEND_DAMAGE_REDUCTION_PERCENT) / 100)
        damage = max(MIN_DAMAGE, damage)

        if(!firstAttacker && attacker && attacker != src)
            firstAttacker = attacker

        HP -= damage
        view(src) << output(isCrit ? "[src] takes a critical hit for [damage] damage! (HP: [max(HP,0)])" : "[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")
        ShowCombatNumber(src, "[damage]", isCrit ? "#ffff00" : DAMAGE_NUMBER_COLOR)
        ShowFloatingHPBar()

        // Being hit wakes you up — without this, Sleep was an unbreakable stun for its
        // full duration.
        RemoveStatusEffect(/datum/status_effect/sleep)

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

        return TRUE

mob/proc
    // Base drops nothing; mob/enemy overrides with the real drop roll (EnemyNPCs.dm).
    // Declared on the base so Die() can call it unconditionally.
    DropLoot(mob/killer)
        return

mob/proc
    // Never applies to players, who go through the isDead/respawn flow in Die() instead.
    CleanUpDead()
        if(istype(src, /mob/player)) return
        spawn(100)  // lets the corpse linger briefly before it disappears
            del src

mob/proc
    // Credit the attacker (not whoever landed the finishing blow), then branch on
    // player vs. enemy.
    Die(mob/attacker)
        view(src) << output("[src] has been defeated!", "Info")

        // Reward the first attacker (TakeDamage()'s firstAttacker), falling back to
        // the killer when there's no recorded first hit (poison, GM_KillMonsters, etc).
        if(firstAttacker)
            attacker = firstAttacker

        ClearStatusEffects()

        if(attacker)
            var/reward = src.expReward
            var/goldDrop = src.goldReward
            var/attackerGoldGained = 0
            if(attacker.Party && attacker.Party.shareExp)
                // Split evenly among the party — gold splits on the same shareExp
                // flag rather than its own toggle.
                var/memberCount = attacker.Party.members.len
                var/share = max(1, round(reward / memberCount))
                var/goldShare = goldDrop ? max(1, round(goldDrop / memberCount)) : 0
                for(var/mob/player/M in attacker.Party.members)
                    // Each member's own Amulet of Experience/Wealth boosts only their
                    // own share, not the shared pool before split.
                    var/expGained = round(share * (100 + M.equipExpBonusPercent) / 100)
                    var/goldGained = round(goldShare * (100 + M.equipGoldBonusPercent) / 100)
                    M.Exp += expGained
                    M.Gold += goldGained
                    M.LevelCheck()
                    if(M == attacker) attackerGoldGained = goldGained
            else
                attackerGoldGained = round(goldDrop * (100 + attacker.equipGoldBonusPercent) / 100)
                attacker.Exp += round(reward * (100 + attacker.equipExpBonusPercent) / 100)
                attacker.Gold += attackerGoldGained
                attacker.LevelCheck()

            if(attackerGoldGained)
                attacker.ShowInfo("You gain [attackerGoldGained] Gold.")

            // Rolled inside the attacker branch so an unattributed death doesn't
            // scatter loot with nobody around to claim it.
            DropLoot(attacker)

        if(istype(src, /mob/player))
            isDead = TRUE
            deathTime = world.time
            // Exp is per-level progress (LevelCheck() resets it on every level-up), so
            // flooring at 0 already means a death penalty can never de-level you.
            Exp = max(0, Exp - round(Exp * DEATH_EXP_LOSS_PERCENT / 100))
            Gold = max(0, Gold - round(Gold * DEATH_GOLD_LOSS_PERCENT / 100))
            density = 0
            icon_state = "sleep"
            canAct = FALSE
            // Also cleared here (not just relied on from the attack's own recovery
            // spawn()) — a second hit landing during the "moving but can't attack yet"
            // window would otherwise leave this TRUE, letting Step() wave the death
            // lock through.
            attackRecoveryOnly = FALSE
            src.ShowInfo("You will auto-respawn in [RESPAWN_AUTO_DELAY / 10] seconds. You may press 5 on your numpad to respawn before then.")

            // Captures deathTime so an early respawn (numpad 5) followed by a second
            // death doesn't get yanked by this older timer firing late.
            var/thisDeath = deathTime
            spawn(RESPAWN_AUTO_DELAY)
                if(isDead && deathTime == thisDeath)
                    RespawnPlayer()
        else
            // CleanUpDead() (called from TakeDamage right after this) does the deletion.
            density = 0
            icon_state = "sleep"

mob/proc
    // The single respawn path — reached by Die()'s auto-timer or immediately via
    // numpad 5 (Interact(), PlayerVerbs.dm).
    RespawnPlayer()
        if(!isDead) return

        isDead = FALSE
        HP = MaxHP
        MP = MaxMP
        density = 1
        icon_state = "world"
        isDefending = FALSE
        ClearStatusEffects()
        loc = GetRespawnTurf()
        canAct = TRUE
        src.ShowInfo("You respawn.")

// Convex exp curve (Level^2) — cheap early on, balloons at high levels. DM has no
// exponentiation operator, so plain integer multiplication is the safe way to get a
// convex curve.
#define BASE_EXP 15

// Matches ClassReference.md's stated cap for every class.
#define MAX_LEVEL 99

mob/proc
    LevelCheck()
        if(src.Level >= MAX_LEVEL) return

        if(src.Exp >= src.Nexp)
            src.Exp = 0
            src.Level += 1
            src.Nexp = BASE_EXP * src.Level * src.Level
            src.StatPoints += 6
            src.RecalculateVitals()  // Level affects MaxHP/MaxMP too
            src.ShowInfo("You are now Level [src.Level]")
            src << sound('levelup.wav', channel = 2, volume = client ? client.ScaledVolume() : 100)

            // Enemies also route through this (Die()'s attacker.LevelCheck() call
            // above), so guard skill-learning to players only.
            if(istype(src, /mob/player))
                var/mob/player/P = src
                P.CheckSkillUnlocks()

mob/proc
    // M, when passed, is the target captured at the INSTANT the swing started
    // (UseSkillSlot()/AILoop()) — trusted from capture time and never re-validated
    // here (only re-checked for still being alive). A target legitimately in range at
    // swing-start that steps away during the windup still gets hit; RollDodge() above
    // is the only thing that should turn a committed swing into a miss. Falls back to
    // scanning the tile ahead only when no target was captured up front.
    PerformMeleeHit(datum/skill/S, mob/M = null)
        if(!M)
            var/turf/T = get_step(src, dir)
            if(!T) return
            for(var/mob/X in T.contents)
                if(X == src) continue
                if(X.HP <= 0) continue
                M = X
                break

        if(!M || M.HP <= 0) return

        var/mult = S ? S.damage_multiplier : 1
        ResolvePhysicalHit(M, mult)

    // Shared by PerformMeleeHit()/PerformLineHit() — rolls a Strength-based physical
    // hit and applies it. attackBonus is the Upper buff (StatusEffects.dm) — added to
    // Strength for damage purposes only, never to the stat itself.
    ResolvePhysicalHit(mob/target, mult)
        var/damage = round((GetEffectiveStrength() + attackBonus) * mult)
        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        return target.TakeDamage(damage, src, isMagic = FALSE, isCrit = isCrit)

// Elemental scaffolding — real, working code, but currently inert: nothing yet sets
// elementalWeakness/elementalResistance on a player or monster, so these checks never
// trigger until something does.
mob/var/elementalWeakness = null    // e.g. "ice" — takes bonus damage from that element
mob/var/elementalResistance = null  // e.g. "fire" — takes reduced damage from that element
#define ELEMENTAL_WEAKNESS_BONUS_PERCENT 50
#define ELEMENTAL_RESISTANCE_REDUCTION_PERCENT 50

// A mob's OWN elemental affinity, distinct from what it's weak/resistant TO — real OG
// data for monsters (MonsterRoster.dm). Players leave this null.
mob/var/mobElement = null

mob/proc
    // Called from New() on every mob with an affinity. Sets elementalResistance from
    // mobElement unless something already set it explicitly. Self-element resistance
    // only — weakness stays null on purpose (no opposition table exists, see
    // Markdowns/CodeNotes.md).
    ResolveElementalDefense()
        if(!mobElement) return
        if(isnull(elementalResistance))
            elementalResistance = mobElement

mob/proc
    // Returns TakeDamage()'s landed/dodged result — Projectiles.dm's Impact() passes
    // this back up to Launch() so a dodged shot keeps flying instead of stopping.
    ApplySpellDamage(mob/target, damage, element)
        if(!target) return FALSE

        if(element)
            if(target.elementalWeakness == element)
                damage = round(damage * (100 + ELEMENTAL_WEAKNESS_BONUS_PERCENT) / 100)
            else if(target.elementalResistance == element)
                damage = round(damage * (100 - ELEMENTAL_RESISTANCE_REDUCTION_PERCENT) / 100)

        var/isCrit = RollCrit()
        if(isCrit) damage = round(damage * CRIT_DAMAGE_PERCENT / 100)
        return target.TakeDamage(damage, src, isMagic = TRUE, isCrit = isCrit)

mob/proc
    // Symmetric to ApplySpellDamage() but restores HP, capped at MaxHP. No dodge/
    // elemental interaction.
    ApplyHeal(mob/target, amount)
        if(!target) return
        // Number shown is the spell's full rated power, not whatever actually landed
        // after the MaxHP cap — confirmed real-game behavior.
        target.HP = min(target.MaxHP, target.HP + amount)
        target.ShowInfo("You are healed for [amount] HP! (HP: [target.HP]/[target.MaxHP])")
        ShowCombatNumber(target, "[amount]", "#00ff00")
        target.ShowFloatingHPBar()

#define MELEE_ATK_BASE_DELAY 12
#define MELEE_ATK_MIN_DELAY 4
#define SPELL_ATK_BASE_DELAY 14
#define SPELL_ATK_MIN_DELAY 6
// Scales WITH Intelligence rather than a flat add, so Agility barely helps a low-INT
// character's cast speed but meaningfully helps a high-INT one.
#define SPELL_AGI_SYNERGY_DIVISOR 40
#define DEFEND_ATTACK_SPEED_PENALTY 3

mob/proc
    // Deliberately NOT gated by class — physical vs. magic speed falls out purely from
    // stat allocation (ClickableStats.dm).
    GetAttackDelay(datum/skill/S, wasDefending = FALSE)
        var/delay
        if(S.isMelee)
            // Geometric mean of Agility and whichever of Vitality/Intelligence is
            // higher — needs Agility plus a real secondary investment, but doesn't
            // force that secondary to be Vitality specifically.
            var/meleeSpeedStat = sqrt(GetEffectiveAgility() * max(GetEffectiveVitality(), GetEffectiveIntelligence()))
            delay = max(MELEE_ATK_MIN_DELAY, MELEE_ATK_BASE_DELAY - meleeSpeedStat)
        else if(S.isSpell)
            var/spellSpeedStat = GetEffectiveIntelligence() + (GetEffectiveAgility() * GetEffectiveIntelligence() / SPELL_AGI_SYNERGY_DIVISOR)
            delay = max(SPELL_ATK_MIN_DELAY, SPELL_ATK_BASE_DELAY - spellSpeedStat)
        else
            delay = 10

        if(wasDefending)
            delay += DEFEND_ATTACK_SPEED_PENALTY

        return delay

// get_dist()/step_to() use Chebyshev distance (diagonal counts as adjacent), but this
// game is 4-directional only — true only when exactly one axis differs.
proc/IsCardinallyAdjacent(atom/A, atom/B, range=1)
    var/dx = abs(A.x - B.x)
    var/dy = abs(A.y - B.y)
    return (dx <= range && dy == 0) || (dx == 0 && dy <= range)

mob/proc
    // Real per-area battleModeOn var (Area.dm), set via GM_BattleMode (GMCommands.dm).
    InBattleArea()
        var/turf/T = src.loc
        var/area/A = T ? T.loc : null
        return A && A.battleModeOn

// -----------------------------
// Animation state resolution — not every mob icon uses the same icon_state names for
// the same action (e.g. Fighter icons split "attack"/"weapon" into per-hand "right"/
// "left" pairs instead). ResolveAnimState() picks whichever the mob's icon actually
// has. See Markdowns/CodeNotes.md for the full confirmed breakdown.
// -----------------------------
mob/var/animAlternate = FALSE  // flipped once per swing by PlayAttackAnimation()

// icon_states() builds a fresh list per call and this runs on every swing — cached
// per icon instead.
var/list/iconStateCache = list()

proc/GetCachedIconStates(icon_ref)
    if(!icon_ref) return list()
    var/key = "[icon_ref]"
    if(key in iconStateCache)
        return iconStateCache[key]
    var/list/states = icon_states(icon_ref)
    iconStateCache[key] = states
    return states

mob/proc/ResolveAnimState(baseName)
    var/list/states = GetCachedIconStates(icon)
    if(!states.len) return baseName  // no readable states — let the caller try anyway
    if(baseName in states) return baseName

    var/rightName = "right[baseName]"
    var/leftName = "left[baseName]"
    var/hasRight = (rightName in states)
    var/hasLeft = (leftName in states)

    if(hasRight && hasLeft)
        return animAlternate ? leftName : rightName
    if(hasRight) return rightName
    if(hasLeft) return leftName
    return null

// Per-direction pixel nudge for the floating weapon overlay below — it renders on the
// tile ADJACENT to the attacker, not the attacker's own tile, so there's a real 32px
// seam between "hand" and "weapon" that redrawing the sprite itself can't close.
// Scoped to basePlayerIcon so a nudge tuned for one custom icon can't move anyone
// else's weapon — returns (0,0) for every icon not listed. Sign convention: pixel_x
// negative=left/positive=right; pixel_y is BYOND's bottom-up axis, negative=down/
// positive=up. See Markdowns/CodeNotes.md for the full sign-convention writeup.
proc/GetWeaponOverlayNudge(iconFilename, dir)
    if(iconFilename != "Cere.dmi")
        return list(0, 0)

    switch(dir)
        if(EAST)  return list(-10, -9)
        if(WEST)  return list(10, -5)
        if(NORTH) return list(0, 0)
        if(SOUTH) return list(0, 0)
    return list(0, 0)

mob/proc
    // duration (deciseconds) is how long the melee weapon overlay stays visible —
    // callers pass their real attack-cycle length so it lingers/resets in step with
    // how often the attacker can actually swing again.
    PlayAttackAnimation(mob/user, datum/skill/S, mob/target = null, duration = 2)
        if(S.isMelee)
            // One flip per swing (not per state lookup) so the pose and its weapon
            // overlay always agree on which hand is being used.
            user.animAlternate = !user.animAlternate

            var/attackState = user.ResolveAnimState("attack")
            if(attackState)
                // Held manually for S.cast_time rather than relying on flick()'s own
                // (too-short/single-frame) baked duration. Only reverts if nothing
                // else changed icon_state meanwhile (death, a second swing already
                // started).
                var/priorState = user.icon_state
                user.icon_state = attackState
                spawn(S.cast_time)
                    if(user.icon_state == attackState)
                        user.icon_state = priorState
            // view(user), not "user <<" — the latter only reaches the attacker's own
            // client, so this silently never played for enemies at all.
            PlaySFXAt(user, istype(user, /mob/enemy) ? 'enemyattack.wav' : 'attack.wav', base = 60)
            var/list/weaponNudge = GetWeaponOverlayNudge(user.basePlayerIcon, user.dir)
            if(target)
                // Layered on the mob being hit, not the turf. Only the deliberate
                // nudge is added here, not target.pixel_y — overlays already inherit
                // their parent atom's own pixel_y automatically.
                var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                weaponOverlay.pixel_x = weaponNudge[1]
                weaponOverlay.pixel_y = weaponNudge[2]
                weaponOverlay.layer = target.layer + 0.1
                target.overlays += weaponOverlay
                spawn(duration)
                    target.overlays -= weaponOverlay
            else
                // Swinging at an empty tile — layered above the ATTACKER (not
                // targetTile, whose own layer is far below a mob's), since a big
                // enough nudge can pull this visually back onto the attacker's tile;
                // without this it silently renders behind the attacker's sprite.
                var/turf/targetTile = get_step(user, user.dir)
                if(targetTile)
                    var/image/weaponOverlay = image(icon = user.icon, icon_state = user.ResolveAnimState(S.icon_state), dir = user.dir)
                    weaponOverlay.pixel_x = weaponNudge[1]
                    weaponOverlay.pixel_y = user.pixel_y + weaponNudge[2]
                    weaponOverlay.layer = user.layer + 0.1
                    targetTile.overlays += weaponOverlay
                    spawn(duration)
                        targetTile.overlays -= weaponOverlay
        else if(S.isSpell)
            // "cast" isn't a real state on any player icon — falls back to "attack".
            var/castState = user.ResolveAnimState("cast") || user.ResolveAnimState("attack")
            if(castState) flick(castState, user)
            PlaySFXAt(user, 'spell.wav', base = 70)
            if(target)
                // NOTE: unlike the melee overlay above, this uses a plain /icon (no
                // .layer property), so it likely renders behind the target's sprite —
                // worth the same /image treatment once a spell-casting enemy exists to
                // surface it.
                var/icon/spellOverlay = icon(user.icon, S.icon_state)
                target.overlays += spellOverlay
                spawn(6)
                    target.overlays -= spellOverlay

// Real 3-stage cast for GenericSpell's healing branch — only for heal-tier skills with
// real spells.dmi art (Heal/Healmore/Healmost). Synchronous (sleep(), not spawn()) so
// nothing downstream can fire out of order relative to what's on screen.
mob/proc/PlayHealCastSequence(datum/skill/S, mob/target, heal_amount, wasDefending, mySession)
    var/atkDelay = GetAttackDelay(S, wasDefending)
    var/frameDelay = max(CAST_METER_MIN_FRAME_DELAY, atkDelay / CAST_METER_SPEED_DIVISOR)

    // Windup: cast meter over the CASTER — a fresh image per frame, previous one
    // explicitly removed rather than mutated in place (BYOND's overlays list
    // snapshots appearance at add-time).
    var/image/prevFrame = null
    for(var/i = 1 to 10)
        var/image/meterFrame = image('castmeter.dmi', src, "[i]")
        meterFrame.layer = layer + 0.1
        if(prevFrame) overlays -= prevFrame
        overlays += meterFrame
        prevFrame = meterFrame
        sleep(frameDelay)
    if(prevFrame) overlays -= prevFrame

    if(isDead) return  // died mid-cast

    // Resolution: the TARGET plays the skill's own spells.dmi state at its own baked
    // frame speed, held for HEAL_ANIM_DURATION before the heal lands and the number pops.
    if(target)
        var/image/healFx = image('spells.dmi', target, S.icon_state)
        healFx.layer = target.layer + 0.1
        target.overlays += healFx
        sleep(HEAL_ANIM_DURATION)
        target.overlays -= healFx

    ApplyHeal(target, heal_amount)

    canAct = TRUE
    RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Line (reach) melee hits — scans outward from this mob tile by tile in its facing
// direction, hitting the FIRST mob found (stops there, no pierce). Built for
// Thornwhip (SkillCatalog.dm). Deliberately NOT built on Projectiles.dm's pierces flag
// — this is an instant reach attack, no travel time or visible projectile. Walls don't
// block it yet (unconfirmed from the OG which turfs/objs should).
// -----------------------------
mob/proc
    PerformLineHit(datum/skill/S, reach = 3)
        var/mult = S ? S.damage_multiplier : 1
        var/turf/T = src.loc

        for(var/i = 1 to reach)
            T = get_step(T, dir)
            if(!T) return

            for(var/mob/M in T.contents)
                if(M == src) continue
                if(M.HP <= 0) continue

                ResolvePhysicalHit(M, mult)
                return  // first mob found ends the scan — no pierce
