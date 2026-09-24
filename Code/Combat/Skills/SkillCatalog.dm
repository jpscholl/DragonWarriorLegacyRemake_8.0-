// -----------------------------
// Skill Catalog — generic framework + every named skill from ClassReference.md
// -----------------------------
// Every named skill below is a thin subtype of GenericPhysical or GenericSpell,
// setting only name/icon_state/cost/multiplier. A few skills (status effects, Rest/
// Return/Meditate, Revive, Classchange, Thornwhip) have a genuinely different shape
// and get their own OnUse(). Attack/Defend/Fireball/Blaze live in SkillDatum.dm, not
// here. See Markdowns/CodeNotes.md for placeholder/OG-confirmation history on the
// numbers below — every damage_multiplier/heal_amount/mana_cost is a tunable guess
// unless that doc says otherwise.

// -----------------------------
// Generic Physical — melee weapon/martial skills (Str or Agi gated)
// -----------------------------
datum/skill/GenericPhysical
    parent_type = /datum/skill
    isMelee = TRUE
    icon_state = "weapon"
    cast_time = 2

    var
        isRanged = FALSE

    // Hook for how contact is actually resolved — override this alone (e.g.
    // Thornwhip's line attack below) to change what a swing hits without
    // duplicating the whole windup/recovery sequence in OnUse().
    proc/PerformHit(mob/user, mob/target)
        user.PerformMeleeHit(src, target)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        user.PlayAttackAnimation(user, src, target)
        // The skill's spells.dmi art (SkillFX.dm), on top of the portrait's own swing
        // pose that PlayAttackAnimation() just played. Drawn on the target when there is
        // one, otherwise on the tile being swung at — same placement as the weapon
        // overlay. PlayAttackAnimation() flips animAlternate first, so a handed FX pair
        // ("leftclaw"/"rightclaw") always agrees with the hand in the pose.
        user.PlaySkillFX(src, target || get_step(user, user.dir))

        spawn(cast_time)
            PerformHit(user, target)
            if(!user.isDead) user.attackRecoveryOnly = TRUE

        spawn(atkDelay)
            if(user.isDead) return
            user.canAct = TRUE
            user.attackRecoveryOnly = FALSE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Generic Spell — offensive or healing magic (Int gated). isHealing picks the branch;
// damage spells scale off Intelligence via damage_multiplier, heals use heal_amount.
// -----------------------------
datum/skill/GenericSpell
    parent_type = /datum/skill
    isSpell = TRUE
    icon_state = "weapon"
    cast_time = 6

    var
        isHealing = FALSE
        heal_amount = 0
        // TRUE only for heal-tier skills with real spells.dmi art (Heal/Healmore/
        // Healmost) — routes through PlayHealCastSequence() (CombatSystem.dm), which
        // holds the heal art on the target before the heal lands.
        hasHealAnimation = FALSE

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Healing is allowed outside battle areas; damage spells are not.
        if(!isHealing && !user.InBattleArea()) return

        var/mob/actualTarget = isHealing ? (target || user) : target

        // A single-target damage spell with nothing valid in front used to spend the
        // MP, play the whole cast, and hit nothing.
        if(!isHealing && (!target || !user.CanHarm(target)))
            user.ShowInfo("No target.")
            return

        if(isHealing && actualTarget && actualTarget.HP >= actualTarget.MaxHP)
            user.ShowInfo("[actualTarget == user ? "You are" : "[actualTarget] is"] already at full HP.")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        if(isHealing && hasHealAnimation)
            user.PlayHealCastSequence(src, actualTarget, heal_amount, wasDefending, mySession)
            return

        if(!user.PlayCastMeter(src, wasDefending)) return  // died mid-cast

        // The effect art plays once the windup completes, not at cast start.
        user.PlaySkillFX(src, actualTarget)  // spells.dmi effect art (SkillFX.dm)

        if(isHealing)
            user.ApplyHeal(actualTarget, heal_amount)
        else
            // A skill with separate hit art ("icespear" -> "icespearhit") lets its
            // main art play out first, so the two read as cast-then-impact.
            if(impact_fx_state)
                sleep(SKILL_FX_DURATION)
                if(user.isDead) return
            // Base number from ComputeSpellDamage() (DamageFormula.dm), which owns
            // every offensive coefficient. The impact burst is gated on the hit
            // actually landing — a dodged spell shouldn't visibly detonate on the
            // target (same rule obj/projectile/Impact() follows).
            if(user.ApplySpellDamage(target, user.ComputeSpellDamage(damage_multiplier), src.element) && impact_fx_state)
                user.PlaySkillImpactFX(src, target)

        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// AoE Spell — hits everything in a blob instead of one target, and optionally leaves a
// hazard field on the ground afterwards (HazardFields.dm).
// -----------------------------
// Needs its own OnUse() rather than a PerformHit()-style hook because GenericSpell's
// whole shape assumes a single target (the heal branch, the "already at full HP" check,
// the one ApplySpellDamage() call).
datum/skill/AoESpell
    parent_type = /datum/skill/GenericSpell

    var
        aoe_radius = 1   // Manhattan radius of the blast
        aoe_range = 3    // how far ahead the blast centers when nothing is being faced

        // Residual ground hazard left behind. null = none.
        hazardFieldType = null
        hazard_radius = 1
        hazard_duration = 60
        // The field's power is scaled off the damage this cast actually rolled rather
        // than being a flat number, so residual fire from a high-Intelligence caster
        // keeps pace with the spell that made it.
        hazard_power_multiplier = 0.5

    // The target's own tile when facing something, otherwise the furthest unblocked
    // tile up to aoe_range ahead — so casting into open ground puts the blast out in
    // front of the caster instead of on top of them.
    proc/FindBlastCenter(mob/user, mob/target)
        if(target && target.loc) return target.loc

        var/turf/T = user.loc
        for(var/i = 1 to aoe_range)
            var/turf/next = get_step(T, user.dir)
            if(!next || IsTurfBlocked(next)) break
            T = next
        return T

    // One damage roll shared by everyone caught in the blast, not a separate roll per
    // victim — an explosion should read as a single event.
    proc/ApplyBlast(mob/user, turf/center, damage)
        var/fxState = ResolveSkillFXState(fx_state, user.dir, user.animAlternate)

        for(var/turf/T in GetDiamondTurfs(center, aoe_radius))
            if(fxState) FlashSkillFX(T, fxState, fxDir = user.dir, pixelY = user.pixel_y)

            for(var/mob/M in T)
                // Coop mode / friendly fire (CanHarm(), CombatSystem.dm) -- also
                // excludes the caster itself.
                if(!user.CanHarm(M)) continue
                if(M.HP <= 0) continue
                user.ApplySpellDamage(M, damage, element)

        if(hazardFieldType)
            SpawnHazardBlob(center, hazardFieldType, hazard_radius, user,
                            round(damage * hazard_power_multiplier), element, hazard_duration)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        // Aim locks now, at cast start — the blast shouldn't re-aim itself if the
        // caster turns during the windup.
        var/turf/center = FindBlastCenter(user, target)

        if(!user.PlayCastMeter(src, wasDefending)) return  // died mid-cast
        ApplyBlast(user, center, user.ComputeSpellDamage(damage_multiplier))

        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

// =============================================================================
// PHYSICAL SKILLS (Str/Agi gated) — damage_multiplier scales Strength
// =============================================================================
// fx_state names a state in spells.dmi (SkillFX.dm). Most of these are unambiguous —
// spells.dmi literally contains "club", "thornwhip", "battleaxe" and so on, and they
// went unused for a long time only because every skill inherited the generic "weapon".
// Where a skill has NO matching art, fx_state is still set to the name the art would
// have: nothing is drawn today, and dropping a state by that name into spells.dmi is the
// only step needed to light it up. Those are marked "no art yet".
//
// "claw"/"fireclaw"/"goldclaw" have no bare state at all — the art ships as
// "leftclaw"/"rightclaw" pairs, which ResolveSkillFXState() picks between using the same
// swing alternation as the portrait's pose.
datum/skill/Punch
    parent_type = /datum/skill/GenericPhysical
    skillName = "Punch"
    damage_multiplier = 1.0
    // Deliberately null, not a placeholder name: a bare-fisted punch is fully
    // described by the portrait's own swing pose and wants no spells.dmi overlay.

// A full clockwise spin (OG, recalled by the user 2026-09-24): swing in the facing
// direction, turn to the user's right and swing, twice more, and stop once back where
// it started -- one hit per side, so it can catch enemies on all four at once. Rooted
// and held in the attack pose the whole time.
datum/skill/Club
    parent_type = /datum/skill/GenericPhysical
    skillName = "Club"
    fx_state = "club"
    damage_multiplier = 1.1

    var/spinStepDelay = 2  // deciseconds per side -- invented, tune by feel

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE  // rooted: attackRecoveryOnly stays FALSE for the whole spin
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        Spin(user, wasDefending, mySession)

    proc/Spin(mob/user, wasDefending, mySession)
        set waitfor = 0
        PlaySFXAt(user, istype(user, /mob/enemy) ? 'enemyattack.wav' : 'attack.wav', base = 60)  // once for the whole spin
        for(var/side = 1 to 4)
            if(!user || user.isDead) return
            user.animAlternate = !user.animAlternate  // handed portraits alternate hands
            var/attackState = user.ResolveAnimState("attack")
            if(attackState) user.icon_state = attackState
            user.PlaySkillFX(src, get_step(user, user.dir), spinStepDelay)
            user.PerformMeleeHit(src)  // no locked target -- whoever's on this side
            sleep(spinStepDelay)
            if(!user) return
            user.dir = turn(user.dir, -90)  // -90 = clockwise = the user's own right

        // Four right turns later it's facing where it started.
        if(!user || user.isDead) return
        user.icon_state = "world"
        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

datum/skill/IronClaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iron Claw"
    fx_state = "claw"  // -> leftclaw/rightclaw
    damage_multiplier = 1.2

// Utility, not an attack (user's design, 2026-09-24 -- the OG mechanics aren't
// recoverable): a hop one tile forward -- two if you're still holding that direction
// at the top of the arc (PerformHop()) -- airborne for JUMP_AIR_TIME. Anything aimed at
// the jumper while airborne misses (TakeDamage(), CombatSystem.dm) and ground fire
// can't touch them (HazardFields.dm) -- that's the point: jump out of an attack. With
// a wall or solid object ahead, it's a hop in place, still a dodge. A mob ahead is no
// obstacle: you go over it and land on top (the monster steps out from under you --
// StepOffStack(), EnemyNPCs.dm). No spells.dmi art exists
// for it; the hop itself is the animation.
#define JUMP_AIR_TIME 4   // deciseconds airborne -- invented, tune by feel
#define JUMP_HEIGHT 12    // pixels at the top of the arc -- invented
#define JUMP_LAYER_LIFT 0.2  // how far above other mobs a jumper draws (MOB_LAYER is 4)

datum/skill/Jump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Jump"
    fx_state = "jump"  // no art yet -- the hop is the whole visual
    damage_multiplier = 0  // never hits anything

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).

        user.canAct = FALSE
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        if(!user.PerformHop(ontoMobs = TRUE, allowExtend = TRUE)) return  // died in the air

        user.next_step = world.time  // free to walk the moment you land
        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

// The hop Jump and Quakejump share: one tile forward in the facing direction, arcing
// up JUMP_HEIGHT and back down over JUMP_AIR_TIME, airborne (untouchable) the whole
// way. With the tile ahead blocked it's a hop in place.
//
// ontoMobs lets the landing tile hold a mob -- Quakejump comes down ON the enemy it's
// hitting. Walls, doors and solid objects still block either way. Synchronous; returns
// FALSE if the jumper died in the air.
//
// allowExtend (Jump only): still holding the jump's direction at the top of the arc
// carries the hop one tile further. Each tile glides over one half of the arc, so a
// plain hop covers its tile on the way up and comes straight down onto it, while an
// extended one keeps moving through the fall.
mob/proc/PerformHop(ontoMobs = FALSE, allowExtend = FALSE)
    var/jumpDir = dir
    var/baseY = pixel_y
    var/halfAir = JUMP_AIR_TIME / 2

    isAirborne = TRUE
    // Drawn above every other mob for the whole hop, and still on top of whoever it
    // lands on -- mobs sharing a layer on one tile draw in no fixed order, and the
    // jumper kept ending up underneath. mob/Move() (Main.dm) restores the layer on the
    // first move after landing.
    if(isnull(layerBeforeHop)) layerBeforeHop = layer
    layer = layerBeforeHop + JUMP_LAYER_LIFT
    animate(src, pixel_y = baseY + JUMP_HEIGHT, time = halfAir, easing = SINE_EASING | EASE_OUT)
    animate(pixel_y = baseY, time = halfAir, easing = SINE_EASING | EASE_IN)

    HopStep(jumpDir, ontoMobs, halfAir)  // blocked = a hop in place
    sleep(halfAir)

    if(src && allowExtend && !isDead && client && client.move_dir == jumpDir)
        HopStep(jumpDir, ontoMobs, halfAir)
    sleep(halfAir)

    if(!src) return FALSE
    isAirborne = FALSE
    pixel_y = baseY
    if(!SharesTileWithMob())  // landed clear of everyone -- nothing to stay on top of
        layer = layerBeforeHop
        layerBeforeHop = null
    return !isDead

mob/proc/SharesTileWithMob()
    for(var/mob/M in loc)
        if(M != src) return TRUE
    return FALSE

// One airborne tile of a hop, glided over glideTime. Returns whether it moved.
// Non-dense for that one step so it can come down on a mob (ontoMobs); walls and solid
// objects are checked first, since a non-dense mover would pass through those too.
mob/proc/HopStep(hopDir, ontoMobs, glideTime)
    var/turf/T = get_step(src, hopDir)
    if(!T || (ontoMobs ? IsTurfBlocked(T) : IsTileOccupied(T))) return FALSE

    var/wasDense = density
    if(ontoMobs) density = FALSE
    glide_size = TILE_WIDTH / glideTime * world.tick_lag
    var/moved = step(src, hopDir)
    density = wasDense
    if(moved && client && client.camera)
        client.camera.TrackTarget(src)
    return moved

// TRUE if a mob or anything else solid stands on T, or T itself is a wall/door.
proc/IsTileOccupied(turf/T)
    if(!T || T.density) return TRUE
    for(var/atom/movable/A in T)
        if(A.density) return TRUE
    return FALSE

// Utility (user's design, 2026-09-24): vanish until something gives you away. Hidden,
// monsters won't target you and single-target skills can't pick you (IsTargetable(),
// CombatSystem.dm). You reappear on a step, on using any ability (this one included),
// on a landed hit, or on taking damage of any kind -- see Unhide() for every trigger.
// Area hits can still find you by accident, and they reveal you.
#define HIDE_TOGGLE_COOLDOWN 10  // deciseconds between toggles -- invented

datum/skill/Hide
    parent_type = /datum/skill/GenericPhysical
    skillName = "Hide"
    damage_multiplier = 0  // never hits anything
    // No fx_state — Hide isn't a strike, so there's nothing to flash.

    // Holding the key down auto-repeats it, which flickered Hide on/off/on. Same fix as
    // Defend's DEFEND_TOGGLE_COOLDOWN (SkillDatum.dm), just longer: hiding is a
    // deliberate act, not a stance you tap in and out of mid-fight.
    var/lastToggleTime = -1#INF  // per player -- each has their own datum

    OnUse(mob/user, mob/target = null)
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).
        if(world.time - lastToggleTime < HIDE_TOGGLE_COOLDOWN) return
        lastToggleTime = world.time
        if(user.isHidden)
            user.Unhide()  // using an ability reveals you -- Hide itself included
            return
        if(!user.canAct) return
        user.Hide()

datum/skill/Magicknife
    parent_type = /datum/skill/GenericPhysical
    skillName = "Magicknife"
    fx_state = "magicknife"
    damage_multiplier = 1.2

// User's design (2026-09-24): thrown, not swung. It flies BOOMERANG_OUT_RANGE tiles
// ahead, then turns around and comes back along the same line toward the spot it was
// thrown from. Anything solid ends the flight -- a wall or solid object drops it, and a
// mob stops it too (hurt only if the thrower may harm them; a dodge lets it fly on).
// The thrower is solid as well, but on the way back meeting them is a CATCH, not a
// hit. Step off the line and it sails past the throw spot for BOOMERANG_OVERSHOOT more
// tiles -- a second chance to hit something behind you, on purpose.
//
// One boomerang per thrower: the skill can't be used again until it's caught or down.
// The thrower is free to move once the throw itself is done.
#define BOOMERANG_OUT_RANGE 4    // tiles out before turning back -- invented
#define BOOMERANG_OVERSHOOT 3    // tiles past the throw spot if not caught -- invented
#define BOOMERANG_STEP_DELAY 1   // deciseconds per tile -- invented; a walking step is 1.36

datum/skill/Boomerang
    parent_type = /datum/skill/GenericPhysical
    skillName = "Boomerang"
    fx_state = "boomerang"   // spells.dmi: a 4-frame spin, drawn as the flying boomerang
    damage_multiplier = 1.3
    isRanged = TRUE

    var/obj/projectile/boomerang/inFlight  // per player -- each has their own datum

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(inFlight)
            user.ShowInfo("Your boomerang is still in the air!")
            return

        user.canAct = FALSE
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        var/throwDir = user.dir

        user.PlayAttackAnimation(user, src)  // throwing pose + sound
        sleep(cast_time)
        if(!user || user.isDead) return

        var/obj/projectile/boomerang/B = new(user.loc)
        B.caster = user
        B.skill = src
        B.travelDir = throwDir
        B.stepDelay = BOOMERANG_STEP_DELAY
        inFlight = B
        B.Launch()

        sleep(max(0, user.GetAttackDelay(src, wasDefending) - cast_time))
        if(!user || user.isDead) return
        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

obj/projectile/boomerang
    icon_state = "boomerang"
    var/datum/skill/Boomerang/skill

    // The whole flight line is fixed at the throw: out, back through the throw spot,
    // then the overshoot beyond it. What's standing on it is checked live, tile by
    // tile, so the thrower can step into it (catch) or out of it (let it fly past).
    Launch()
        set waitfor = 0
        var/turf/origin = loc
        var/backDir = turn(travelDir, 180)

        var/list/path = list()
        var/turf/T = origin
        for(var/i = 1 to BOOMERANG_OUT_RANGE)
            T = get_step(T, travelDir)
            if(!T) break
            path += T
        var/outCount = path.len
        for(var/i = outCount - 1 to 1 step -1)  // back, not re-visiting the far tip
            path += path[i]
        path += origin
        T = origin
        for(var/i = 1 to BOOMERANG_OVERSHOOT)
            T = get_step(T, backDir)
            if(!T) break
            path += T

        for(var/i = 1 to path.len)
            var/turf/next = path[i]
            if(IsTurfBlocked(next)) break  // hit a wall or solid object -- it drops
            var/returning = (i > outCount)
            dir = returning ? backDir : travelDir
            loc = next

            if(returning && caster && !caster.isDead && caster.loc == next)
                caster.ShowInfo("You catch your boomerang.")
                break
            if(StopsOnMob(next)) break
            sleep(stepDelay)

        if(skill) skill.inFlight = null
        del src

    // Hits the first solid mob on T. TRUE if the flight ends here: a landed hit, or a
    // mob the thrower can't hurt (an ally still blocks it). A dodge lets it fly on.
    proc/StopsOnMob(turf/T)
        for(var/mob/M in T)
            if(M == caster || M.HP <= 0 || !M.density) continue
            if(!caster || !caster.CanHarm(M)) return TRUE
            if(caster.ResolvePhysicalHit(M, skill ? skill.damage_multiplier : 1)) return TRUE
        return FALSE

datum/skill/Morningstar
    parent_type = /datum/skill/GenericPhysical
    skillName = "Morningstar"
    fx_state = "morningstar"
    damage_multiplier = 1.3

// Utility, not an attack (user's design, 2026-09-24): the "dash" speed lines play on
// the tile you start from while you're carried forward fast, up to DASH_DISTANCE
// tiles, stopping early at walls and objects. Mobs in the way get shoved ahead of the
// dash rather than stopping it (see the loop below).
#define DASH_DISTANCE 3        // tiles -- invented, tune by feel
#define DASH_STEP_DELAY 0.5    // deciseconds per tile -- invented; a normal walk step is 1.36

datum/skill/Dash
    parent_type = /datum/skill/GenericPhysical
    skillName = "Dash"
    fx_state = "dash"
    damage_multiplier = 0  // never hits anything

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).

        user.canAct = FALSE
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        var/dashDir = user.dir
        user.PlaySkillFX(src, user.loc)  // speed lines on the starting tile

        user.glide_size = TILE_WIDTH / DASH_STEP_DELAY * world.tick_lag
        for(var/i = 1 to DASH_DISTANCE)
            // Plow into a mob and shove it one tile ahead, then carry on into the
            // space it left -- so a dash can bulldoze someone along. Only mobs you
            // could hurt (CanHarm(): coop keeps players from shoving allies into lava).
            // A mob that can't be shoved (wall or another mob behind it) stops the dash.
            var/turf/next = get_step(user, dashDir)
            if(next && !IsTurfBlocked(next))
                for(var/mob/M in next.contents.Copy())
                    if(M.density && M.HP > 0 && user.CanHarm(M))
                        M.KnockBack(dashDir, DASH_STEP_DELAY)
            if(!step(user, dashDir)) break  // hit something solid -- stop there
            if(user.client && user.client.camera)
                user.client.camera.TrackTarget(user)
            sleep(DASH_STEP_DELAY)
            if(!user || user.isDead) return

        user.next_step = world.time  // free to walk the moment the dash ends
        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

// User's design (2026-09-24): Jump's hop, landing as an attack. You come down one tile
// forward (two if still holding that direction at the top of the arc, same as Jump) --
// onto an enemy standing there, if there is one -- and:
//   - the landing tile takes full damage at a high crit chance,
//   - the 8 tiles around it take QUAKEJUMP_RING_DAMAGE_PERCENT of that and whoever is
//     hit gets shoved one tile straight outward (the NE tile's mob goes NE, etc).
// The "quakejump" art has 8 directions, one shockwave segment per ring tile, each
// drawn on its own tile so together they read as a ring around the landing.
#define QUAKEJUMP_CENTER_CRIT_PERCENT 75   // invented -- "high chance" on the landing tile
#define QUAKEJUMP_RING_DAMAGE_PERCENT 50   // invented -- ring hits for half
#define QUAKEJUMP_RING_DURATION SKILL_FX_DURATION  // how long the ring shows -- the jumper stays rooted this long

datum/skill/Quakejump
    parent_type = /datum/skill/GenericPhysical
    skillName = "Quakejump"
    fx_state = "quakejump"
    damage_multiplier = 1.4

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        // Same extension as Jump: holding the direction at the top of the arc lands a
        // tile further. The quake always happens wherever you actually come down.
        if(!user.PerformHop(ontoMobs = TRUE, allowExtend = TRUE)) return  // died in the air
        Quake(user)

        // Rooted until the shockwave ring has fully faded -- or for the rest of a
        // normal swing's delay (counting the time in the air), if that's longer.
        sleep(max(QUAKEJUMP_RING_DURATION, user.GetAttackDelay(src, wasDefending) - JUMP_AIR_TIME))
        if(!user || user.isDead) return
        user.next_step = world.time
        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

    proc/Quake(mob/user)
        var/turf/center = user.loc
        if(!center) return
        PlaySFXAt(user, istype(user, /mob/enemy) ? 'enemyattack.wav' : 'attack.wav', base = 60)

        // One roll for the whole landing, like an AoE spell's blast.
        var/base = user.ComputePhysicalDamage(damage_multiplier)

        for(var/mob/M in center)
            if(M.HP <= 0 || !user.CanHarm(M)) continue
            var/isCrit = prob(QUAKEJUMP_CENTER_CRIT_PERCENT)
            M.TakeDamage(isCrit ? round(base * CRIT_DAMAGE_PERCENT / 100) : base, user, isMagic = FALSE, isCrit = isCrit)

        var/ringBase = max(1, round(base * QUAKEJUMP_RING_DAMAGE_PERCENT / 100))
        for(var/pushDir in list(NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST))
            var/turf/T = get_step(center, pushDir)
            if(!T || IsTurfBlocked(T)) continue  // no shockwave inside a wall

            var/fxState = ResolveSkillFXState(fx_state, pushDir)
            if(fxState) FlashSkillFX(T, fxState, QUAKEJUMP_RING_DURATION, fxDir = pushDir, pixelY = user.pixel_y)

            // Copy: a successful shove moves M out of T mid-loop.
            for(var/mob/M in T.contents.Copy())
                if(M.HP <= 0 || !user.CanHarm(M)) continue
                var/isCrit = user.RollCrit()
                var/landed = M.TakeDamage(isCrit ? round(ringBase * CRIT_DAMAGE_PERCENT / 100) : ringBase, user, isMagic = FALSE, isCrit = isCrit)
                if(landed && M && M.HP > 0)
                    M.KnockBack(pushDir)

// Shoves this mob one tile in pushDir (diagonals included) without turning it around,
// glided over glideTime. Used by Quakejump's ring and Dash.
// Nothing happens when the destination is a wall, a solid object, or already occupied.
// A real Move(), so hazard terrain at the destination still counts as a step.
mob/proc/KnockBack(pushDir, glideTime = JUMP_AIR_TIME)
    var/turf/dest = get_step(src, pushDir)
    if(!dest || IsTileOccupied(dest)) return FALSE
    var/facing = dir
    glide_size = TILE_WIDTH / glideTime * world.tick_lag
    allowDiagonalMove = TRUE  // mob/Move() (Main.dm) otherwise rejects every diagonal
    var/moved = Move(dest, pushDir)
    allowDiagonalMove = FALSE
    dir = facing
    if(moved && client && client.camera)
        client.camera.TrackTarget(src)
    return moved

datum/skill/Fireclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Fireclaw"
    fx_state = "fireclaw"  // -> leftfireclaw/rightfireclaw
    damage_multiplier = 1.4

datum/skill/Iceclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Iceclaw"
    fx_state = "iceclaw"  // no art yet — a left/right pair would resolve automatically
    damage_multiplier = 1.4

// A 3-tile line attack in the facing direction, not a single-tile hit — overrides
// only PerformHit(), inheriting the rest of GenericPhysical's swing sequence as-is.
// The FX still draws on the tile directly ahead rather than along the whole line;
// worth revisiting once the art is seen in motion.
datum/skill/Thornwhip
    parent_type = /datum/skill/GenericPhysical
    skillName = "Thornwhip"
    fx_state = "thornwhip"
    damage_multiplier = 0.8
    var/reach = 3

    PerformHit(mob/user, mob/target)
        user.PerformLineHit(src, reach)

datum/skill/Lightsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Lightsword"
    fx_state = "lightsword"
    impact_fx_state = "lightswordblast"
    damage_multiplier = 1.5

datum/skill/Battleaxe
    parent_type = /datum/skill/GenericPhysical
    skillName = "Battleaxe"
    fx_state = "battleaxe"
    damage_multiplier = 1.5

datum/skill/Flamesword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Flamesword"
    fx_state = "flamesword"
    damage_multiplier = 1.6

datum/skill/Falconsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Falconsword"
    fx_state = "falconsword"
    damage_multiplier = 1.7

datum/skill/Goldclaw
    parent_type = /datum/skill/GenericPhysical
    skillName = "Goldclaw"
    fx_state = "goldclaw"  // -> leftgoldclaw/rightgoldclaw
    damage_multiplier = 1.7

// spells.dmi has BOTH "chain" and "sickle" for this one skill. Which is the swing and
// which is the trailing half is a guess — swap them if it looks wrong in motion.
datum/skill/Chainsickle
    parent_type = /datum/skill/GenericPhysical
    skillName = "Chainsickle"
    fx_state = "sickle"
    impact_fx_state = "chain"
    damage_multiplier = 1.8

datum/skill/SwordOfLethargy
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sword Of Lethargy"
    fx_state = "swordoflethargy"
    damage_multiplier = 1.9

datum/skill/IceSaber
    parent_type = /datum/skill/GenericPhysical
    skillName = "Ice Saber"
    fx_state = "icesaber"
    damage_multiplier = 1.9

datum/skill/Demonhammer
    parent_type = /datum/skill/GenericPhysical
    skillName = "Demonhammer"
    fx_state = "demonhammer"
    damage_multiplier = 2.0

datum/skill/DragonKiller
    parent_type = /datum/skill/GenericPhysical
    skillName = "DragonKiller"
    fx_state = "dragonkiller"
    damage_multiplier = 2.3

datum/skill/ThunderSword
    parent_type = /datum/skill/GenericPhysical
    skillName = "ThunderSword"
    fx_state = "thundersword"
    damage_multiplier = 2.6

// =============================================================================
// OFFENSIVE SPELLS (Int gated) — damage_multiplier scales Intelligence
// =============================================================================
// Same fx_state rules as the physical block above. A few of these assignments are
// GUESSES where spells.dmi's state names don't map one-to-one onto the skill roster —
// marked inline. The "flameblast"/"iceblast"/"thunderblast" trio in particular looks
// like one matched set of big elemental bursts, so they're handed to the top tier of
// each element, but which exact skill each belongs to isn't established.
datum/skill/Icebolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Icebolt"
    element = "ice"
    fx_state = "icespear"
    impact_fx_state = "icespearhit"
    damage_multiplier = 0.7
    mana_cost = 4

datum/skill/Lightning
    parent_type = /datum/skill/GenericSpell
    skillName = "Lightning"
    element = "lightning"
    fx_state = "lightning"
    impact_fx_state = "lightninghit"
    damage_multiplier = 0.9
    mana_cost = 5

datum/skill/Infernos
    parent_type = /datum/skill/GenericSpell
    skillName = "Infernos"
    element = "fire"
    fx_state = "infernos"
    damage_multiplier = 1.0
    mana_cost = 5

datum/skill/Icespears
    parent_type = /datum/skill/GenericSpell
    skillName = "Icespears"
    element = "ice"
    fx_state = "iceblast"  // GUESS — "icespear" is taken by Icebolt above
    damage_multiplier = 1.1
    mana_cost = 6

datum/skill/Blazemore
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemore"
    element = "fire"
    fx_state = "blazemore"
    impact_fx_state = "blazemorehit"
    damage_multiplier = 1.2
    mana_cost = 7

datum/skill/Blizzard
    parent_type = /datum/skill/GenericSpell
    skillName = "Blizzard"
    element = "ice"
    fx_state = "blizzard"
    damage_multiplier = 1.3
    mana_cost = 8

datum/skill/Boom
    parent_type = /datum/skill/GenericSpell
    skillName = "Boom"
    element = "fire"
    fx_state = "boom"  // no art yet — "bang" belongs to Bang, "explodet" to Explodet
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Bang
    parent_type = /datum/skill/GenericSpell
    skillName = "Bang"
    element = "fire"
    fx_state = "bang"
    damage_multiplier = 1.5
    mana_cost = 9

datum/skill/Infermore
    parent_type = /datum/skill/GenericSpell
    skillName = "Infermore"
    element = "fire"
    fx_state = "infermore"
    damage_multiplier = 1.5
    mana_cost = 9

// spells.dmi also ships "thordainns"/"thordainew" — ResolveSkillFXState() prefers the
// directional pair over the bare state automatically, so a vertical cast draws the
// vertical beam with no extra wiring. ("darkthordain" and "darklightning" exist too,
// presumably a monster-cast variant; no skill uses them yet.)
datum/skill/Thordain
    parent_type = /datum/skill/GenericSpell
    skillName = "Thordain"
    element = "lightning"
    fx_state = "thordain"
    damage_multiplier = 1.6
    mana_cost = 10

datum/skill/Firevolt
    parent_type = /datum/skill/GenericSpell
    skillName = "Firevolt"
    element = "fire"
    fx_state = "flamespear"  // GUESS — unused fire-projectile art, fits a "volt"
    impact_fx_state = "flamespearhit"
    damage_multiplier = 1.6
    mana_cost = 10

datum/skill/Firebane
    parent_type = /datum/skill/GenericSpell
    skillName = "Firebane"
    element = "fire"
    fx_state = "firebane"
    damage_multiplier = 1.7
    mana_cost = 11

datum/skill/Snowstorm
    parent_type = /datum/skill/GenericSpell
    skillName = "Snowstorm"
    element = "ice"
    fx_state = "snowstorm"
    damage_multiplier = 1.8
    mana_cost = 12

datum/skill/Blazemost
    parent_type = /datum/skill/GenericSpell
    skillName = "Blazemost"
    element = "fire"
    fx_state = "flameblast"  // GUESS — no "blazemost" state exists
    damage_multiplier = 1.9
    mana_cost = 13

// The one skill that makes datum/status_effect/burn reachable. Recalled OG behavior:
// Explodet deals its impact damage and leaves a circle of flame on the ground, and
// standing in THAT circle is what burns you — the direct hit doesn't ignite anyone.
// spells.dmi ships both halves of the art: "explodet" for the blast, "explodetflame"
// for the residual fire (obj/hazard_field/flame's own icon_state, HazardFields.dm).
//
// Now an AoESpell rather than a single-target GenericSpell, which is the other half of
// matching the original — it was never a one-target spell.
datum/skill/Explodet
    parent_type = /datum/skill/AoESpell
    skillName = "Explodet"
    element = "fire"
    fx_state = "explodet"
    damage_multiplier = 2.2
    mana_cost = 16
    aoe_radius = 1
    hazardFieldType = /obj/hazard_field/flame
    hazard_radius = 1
    hazard_duration = 80  // deciseconds the fire stays on the ground

// =============================================================================
// HEALING SPELLS (Int gated) — heal_amount is flat, not stat-scaled
// =============================================================================
// These four were the only skills in the game already using real spells.dmi art, and
// they named it through icon_state — the var that everywhere else means "a state on the
// caster's own portrait". Moved onto fx_state with the rest of the roster;
// PlayHealCastSequence() (CombatSystem.dm) reads it from there now.
datum/skill/Heal
    parent_type = /datum/skill/GenericSpell
    skillName = "Heal"
    fx_state = "heal"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 60
    mana_cost = 4

datum/skill/Healmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmore"
    fx_state = "healmore"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 30
    mana_cost = 8

// No dedicated "healus" art — reuses Healmore's.
datum/skill/Healus
    parent_type = /datum/skill/GenericSpell
    skillName = "Healus"
    fx_state = "healmore"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 40
    mana_cost = 10

datum/skill/Healmost
    parent_type = /datum/skill/GenericSpell
    skillName = "Healmost"
    fx_state = "healmost"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 55
    mana_cost = 12

// No dedicated "healusmore" art — reuses Healmost's.
datum/skill/Healusmore
    parent_type = /datum/skill/GenericSpell
    skillName = "Healusmore"
    fx_state = "healmost"
    isHealing = TRUE
    hasHealAnimation = TRUE
    heal_amount = 75
    mana_cost = 15

datum/skill/Vivify
    parent_type = /datum/skill/GenericSpell
    skillName = "Vivify"
    fx_state = "vivify"  // no art yet
    isHealing = TRUE
    heal_amount = 90
    mana_cost = 16

// Buff spells target self by default; facing an ally casts it on them instead.
datum/skill/BuffSpell
    parent_type = /datum/skill/StatusSpell

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        var/mob/actualTarget = target || user

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        if(!user.PlayCastMeter(src)) return  // died mid-cast

        user.PlaySkillFX(src, actualTarget)  // the cast burst; the buff's own standing
                                              // indicator is activeFXState on the status
                                              // effect (StatusEffects.dm)
        if(actualTarget) actualTarget.ApplyStatusEffect(statusEffectType)

        user.canAct = TRUE

datum/skill/Upper
    parent_type = /datum/skill/BuffSpell
    skillName = "Upper"
    fx_state = "upper"
    statusEffectType = /datum/status_effect/buff/upper
    mana_cost = 3

datum/skill/Increase
    parent_type = /datum/skill/BuffSpell
    skillName = "Increase"
    fx_state = "increase"  // no art yet
    statusEffectType = /datum/status_effect/buff/increase
    mana_cost = 3

datum/skill/Barrier
    parent_type = /datum/skill/BuffSpell
    skillName = "Barrier"
    fx_state = "barrier"
    statusEffectType = /datum/status_effect/buff/barrier
    mana_cost = 4

// =============================================================================
// STATUS-EFFECT SKILLS — apply a datum/status_effect (StatusEffects.dm) to the target.
// =============================================================================
datum/skill/StatusSpell
    parent_type = /datum/skill
    icon_state = "weapon"
    isSpell = TRUE
    cast_time = 4

    var
        statusEffectType = null
        noTargetMessage = "No target."

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        // Hostile effects obey the same coop / friendly-fire / ghost rule as damage
        // (CanHarm(), CombatSystem.dm) -- this path never touches TakeDamage(), so it
        // used to let a player Sleep another player in a coop area, or a ghosted GM.
        if(!target || !user.CanHarm(target))
            user.ShowInfo(noTargetMessage)
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast [skillName]! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast [skillName]!")

        if(!user.PlayCastMeter(src)) return  // died mid-cast

        // Re-checked: the target may have ghosted, or coop flipped, mid-cast.
        if(target && user.CanHarm(target))
            user.PlaySkillFX(src, target)
            target.ApplyStatusEffect(statusEffectType)

        user.canAct = TRUE

// "sleep" is the cast burst; the sleeping target's own standing overlay is "asleep",
// set as activeFXState on the status effect (StatusEffects.dm).
datum/skill/Sleep
    parent_type = /datum/skill/StatusSpell
    skillName = "Sleep"
    fx_state = "sleep"
    statusEffectType = /datum/status_effect/sleep
    noTargetMessage = "No target to put to sleep."
    mana_cost = 5

datum/skill/Sleepmore
    parent_type = /datum/skill/Sleep
    skillName = "Sleepmore"
    statusEffectType = /datum/status_effect/sleep/more
    mana_cost = 9

datum/skill/Stopspell
    parent_type = /datum/skill/StatusSpell
    skillName = "Stopspell"
    fx_state = "stopspell"
    statusEffectType = /datum/status_effect/silence
    noTargetMessage = "No target to silence."
    mana_cost = 7

// =============================================================================
// UTILITY SKILLS — own resource/effect shape, not a plain damage/heal spell
// =============================================================================

// Vitality-gated self-heal, no mana cost (works for Fighter/Soldier/Goof-off too).
datum/skill/Rest
    parent_type = /datum/skill
    skillName = "Rest"
    icon_state = "weapon"
    cast_time = 4

    var/heal_percent = 30

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).

        user.canAct = FALSE
        user.ShowInfo("You sit down to rest...")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxHP * heal_percent / 100))
            user.ApplyHeal(user, amount)

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Spirit-gated MP restore — the mana-side equivalent of Rest.
datum/skill/Meditate
    parent_type = /datum/skill
    skillName = "Meditate"
    icon_state = "weapon"
    cast_time = 4

    var/restore_percent = 30

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).

        user.canAct = FALSE
        user.ShowInfo("You begin to meditate...")

        spawn(cast_time)
            var/amount = max(1, round(user.MaxMP * restore_percent / 100))
            user.MP = min(user.MaxMP, user.MP + amount)
            user.ShowInfo("You restore [amount] MP! (MP: [user.MP]/[user.MaxMP])")

        spawn(user.GetAttackDelay(src, FALSE))
            if(user.isDead) return
            user.canAct = TRUE

// Teleports the caster back to the spawn point (GetPlayerSpawnTurf(), Area.dm).
datum/skill/Return
    parent_type = /datum/skill
    skillName = "Return"
    icon_state = "weapon"
    isSpell = TRUE
    mana_cost = 8
    cast_time = 6

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Return! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast Return!")

        if(!user.PlayCastMeter(src)) return  // died mid-cast

        user.loc = GetPlayerSpawnTurf()
        if(user.client && user.client.camera)
            user.client.camera.SnapTo(user)  // direct .loc change bypasses client/Move(), the only place the camera normally tracks
        user.ShowInfo("You return to town!")

        user.canAct = TRUE

// Resurrects a fallen ally, bypassing their RESPAWN_DELAY wait (Die(), CombatSystem.dm).
datum/skill/Revive
    parent_type = /datum/skill
    skillName = "Revive"
    icon_state = "weapon"
    isSpell = TRUE
    mana_cost = 12
    cast_time = 6

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!target || !istype(target, /mob/player))
            user.ShowInfo("Revive only works on a fallen ally.")
            return

        var/mob/player/P = target
        if(!P.isDead)
            user.ShowInfo("[P.name] isn't in need of reviving.")
            return

        var/cost = GetManaCost()
        if(user.MP < cost)
            user.ShowInfo("Not enough MP to cast Revive! (need [cost])")
            return

        user.MP -= cost
        user.ShowFloatingMPBar()
        user.canAct = FALSE
        user.ShowInfo("You cast Revive!")

        if(!user.PlayCastMeter(src)) return  // died mid-cast

        if(P && P.isDead)
            P.isDead = FALSE
            P.density = 1
            P.icon_state = "world"
            P.canAct = TRUE
            P.HP = max(1, round(P.MaxHP * 0.5))
            P.ShowInfo("You have been revived by [user.name]!")

        user.canAct = TRUE

// Goof-off's signature unlock — transforms this character into a Sage (DW3-style).
#define CLASSCHANGE_MIN_LEVEL 25
datum/skill/Classchange
    parent_type = /datum/skill
    skillName = "Classchange"
    icon_state = "weapon"

    OnUse(mob/user, mob/target = null)
        if(!istype(user, /mob/player)) return
        var/mob/player/P = user
        if(!P.canAct) return
        if(istype(P, /mob/player/Sage))
            P.ShowInfo("You are already a Sage.")
            return

        if(P.Level < CLASSCHANGE_MIN_LEVEL)
            P.ShowInfo("You must be at least level [CLASSCHANGE_MIN_LEVEL] to change your class.")
            return

        for(var/obj/item/amulet/A in P.contents)
            if(A.worn)
                P.ShowInfo("You must unequip everything before you can change your class.")
                return

        var/confirm = alert(P, "Are you sure you want to change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Classchange", "Yes", "No")
        if(confirm != "Yes") return

        if(!RunSageReclassFlow(P))
            return  // backed out at the icon step — nothing has changed, still the old class

        P.BecomeSage()
