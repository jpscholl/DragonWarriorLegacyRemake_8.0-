// -----------------------------
// Skill Catalog — the skill frameworks, then every named skill
// -----------------------------
// Layout: the shared frameworks first (GenericPhysical, GenericSpell/HealSpell,
// AoESpell, SpellBolt, BeamSpell), then physical skills, offensive spells, heals, buffs,
// status bolts and utility skills. Most named skills are a few lines of vars on one of
// the frameworks; the ones with a genuinely different shape (Club's spin, the jumps,
// Boomerang, Thornwhip, Sage Saber, Revive...) override OnUse()/PerformHit().
// Attack and Defend live in SkillDatum.dm.
//
// Every damage_multiplier/heal_amount/mana_cost is a tunable guess unless marked OG.
// Markdowns/Spells.md is the behavior-by-behavior reference (local only).

// -----------------------------
// Generic Physical — melee weapon/martial skills (Str or Agi gated)
// -----------------------------
datum/skill/GenericPhysical
    parent_type = /datum/skill
    isMelee = TRUE
    icon_state = "weapon"
    cast_time = 2

    // FALSE = skip the one-tile flash of fx_state at swing start, for a skill that
    // draws its own art in PerformHit() (Thornwhip's extending whip). fx_state stays
    // set either way -- it's also what hides the portrait's weapon sprite.
    var/flashSwingFX = TRUE

    // Hook for how contact is actually resolved — override this alone (e.g.
    // Thornwhip's lash, a bolt sword's bolt) to change what a swing hits without
    // duplicating the whole windup/recovery sequence in OnUse().
    proc/PerformHit(mob/user, mob/target)
        user.PerformMeleeHit(src, target)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return

        user.canAct = FALSE

        // Drop the defend stance for the swing+recovery — auto-resumes below, but only
        // if the player hasn't manually toggled Defend in the meantime.
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        // wasDefending (captured before the drop), not user.isDefending (already FALSE),
        // so the speed penalty still applies to a swing thrown out of a defensive stance.
        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        user.PlayAttackAnimation(user, src, target)
        // The skill's spells.dmi art (SkillFX.dm), on top of the portrait's own swing
        // pose that PlayAttackAnimation() just played. Drawn on the target when there is
        // one, otherwise on the tile being swung at — same placement as the weapon
        // overlay. PlayAttackAnimation() flips animAlternate first, so a handed FX pair
        // ("leftclaw"/"rightclaw") always agrees with the hand in the pose.
        if(flashSwingFX) user.PlaySkillFX(src, target || get_step(user, user.dir))

        // The target captured at swing-start (UseSkillSlot()) is passed through rather
        // than re-scanning the tile ahead once the windup has elapsed.
        spawn(cast_time)
            PerformHit(user, target)
            // Swing landed — the user may move again, but can't attack again until the
            // full recovery ends (canAct stays FALSE that whole time).
            if(!user.isDead) user.attackRecoveryOnly = TRUE

        spawn(atkDelay)
            // Died meanwhile — Die() locked canAct as part of the death/respawn flow;
            // unlocking it here would undo that.
            if(user.isDead) return
            user.canAct = TRUE
            user.attackRecoveryOnly = FALSE
            user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Generic Spell — what every spell shares (Int gated). Each spell shape below brings
// its own OnUse(); all of them open with PayToCast() (SkillDatum.dm) and the cast meter.
// -----------------------------
datum/skill/GenericSpell
    parent_type = /datum/skill
    isSpell = TRUE
    icon_state = "weapon"

// -----------------------------
// Heal Spell — a flat heal_amount on the target faced, or on the caster when facing
// nobody. Usable anywhere, peaceful areas included. Plays through
// PlayHealCastSequence() (CombatSystem.dm): cast meter, then the heal art held on the
// target before the heal lands.
// -----------------------------
datum/skill/HealSpell
    parent_type = /datum/skill/GenericSpell

    var/heal_amount = 0

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return

        var/mob/patient = target || user
        if(patient.HP >= patient.MaxHP)
            user.ShowInfo("[patient == user ? "You are" : "[patient] is"] already at full HP.")
            return

        if(!PayToCast(user)) return
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        user.PlayHealCastSequence(src, patient, heal_amount, wasDefending, mySession)

// -----------------------------
// AoE Spell — hits everything in a blob instead of one target, and optionally leaves a
// hazard field on the ground afterwards (HazardFields.dm).
// -----------------------------
datum/skill/AoESpell
    parent_type = /datum/skill/GenericSpell

    var
        aoe_radius = 1   // Manhattan radius of the blast
        aoe_range = 3    // how far ahead the blast centers when nothing is being faced
        aoe_square = FALSE      // TRUE = full square (diagonals too) instead of a diamond
        aoe_on_caster = FALSE   // TRUE = centered on the caster (who is never hit by it)
        blast_fx_state = null   // art flashed on each blast tile; null = fx_state

        // Residual ground hazard left behind. null = none.
        hazardFieldType = null
        hazard_radius = 1
        hazard_duration = 60
        // The field's power is scaled off the damage this cast actually rolled rather
        // than being a flat number, so residual fire from a high-Intelligence caster
        // keeps pace with the spell that made it.
        hazard_power_multiplier = 0.5

    GetArtStates()
        return ..() + blast_fx_state

    // The caster's own tile (aoe_on_caster), else the target's, else the furthest
    // unblocked tile up to aoe_range ahead — so casting into open ground puts the blast
    // out in front of the caster instead of on top of them.
    proc/FindBlastCenter(mob/user, mob/target)
        if(aoe_on_caster) return user.loc
        if(target && target.loc) return target.loc

        var/turf/T = user.loc
        for(var/i = 1 to aoe_range)
            var/turf/next = get_step(T, user.dir)
            if(!next || IsTurfBlocked(next)) break
            T = next
        return T

    // One damage roll shared by everyone caught in the blast, not a separate roll per
    // victim — an explosion should read as a single event. fxDir: which way directional
    // blast art faces -- the caster's facing unless a spell bolt passes its flight dir.
    proc/ApplyBlast(mob/user, turf/center, damage, fxDir = 0)
        if(!fxDir) fxDir = user.dir
        var/fxState = ResolveSkillFXState(blast_fx_state || fx_state, fxDir, user.animAlternate)
        var/list/area = aoe_square ? GetSquareTurfs(center, aoe_radius) : GetDiamondTurfs(center, aoe_radius)

        for(var/turf/T in area)
            if(fxState) FlashSkillFX(T, fxState, fxDir = fxDir, pixelY = user.pixel_y)

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
        if(!PayToCast(user)) return

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        // Aim locks now, at cast start — the blast shouldn't re-aim itself if the
        // caster turns during the windup.
        var/turf/center = FindBlastCenter(user, target)

        if(!user.PlayCastMeter(src, wasDefending)) return  // died or interrupted
        ApplyBlast(user, center, user.ComputeSpellDamage(damage_multiplier))

        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

// -----------------------------
// Spell Bolt — every "cast, then something flies" spell (user's design, 2026-09-25;
// OG: nearly every offensive spell's use() just spawned a /proj). Cast meter, then
// fx_state flies out in the facing direction. Aimed, not locked on -- needs no target.
//
// Shape knobs, all per skill:
//   bolt_lanes     1 = one bolt; 3 = a row of three, side by side (Icespears, Blazemost)
//   bolt_pierces   flies through whoever it hits instead of stopping (Infernos, Firebane)
//   bolt_range     tiles it may travel; 0 = until it hits something
//   bolt_slowness  multiplies the flight step delay -- 2 = half speed
//   bolt_bursts    on contact / at a wall / at range's end it explodes as this spell's
//                  AoESpell blast (aoe_radius, aoe_square, blast_fx_state, hazard field)
//   bolt_status    a status bolt (Sleep, Stopspell): applies this instead of damage
//
// A plain bolt stops on the first solid mob or wall. A landed hit on a mob the caster
// may harm flashes impact_fx_state; an ally or a wall just stops it with no flash; a
// dodge lets it fly on. A bursting bolt detonates on ANY mob it touches, dodge or not --
// the blast does the damage, so dodging the bolt itself means nothing.
// -----------------------------
#define SPELL_BOLT_LANE_SPREAD 90  // side lanes sit at facing +/- this many degrees

datum/skill/SpellBolt
    parent_type = /datum/skill/AoESpell  // for the burst: ApplyBlast() and its knobs

    var
        bolt_lanes = 1
        bolt_pierces = FALSE
        bolt_range = 0
        bolt_slowness = 1
        bolt_bursts = FALSE
        bolt_status = null
        bolt_status_chance = 100  // % a status bolt takes hold; a fail shows "miss"

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!PayToCast(user)) return

        // Aim locks at cast start -- turning isn't blocked by canAct.
        var/castDir = user.dir
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        if(!user.PlayCastMeter(src, wasDefending)) return  // died or interrupted

        // atkDelay / slowFactor: a lethargic caster winds up slower, but the bolt itself
        // still flies at full speed once it leaves their hands.
        var/stepDelay = max(PROJECTILE_MIN_STEP_DELAY, atkDelay / user.slowFactor / PROJECTILE_SPEED_DIVISOR) * bolt_slowness

        var/turf/front = get_step(user, castDir)
        var/list/spawns = list(front)
        if(bolt_lanes >= 3 && front)
            spawns += get_step(front, turn(castDir, SPELL_BOLT_LANE_SPREAD))
            spawns += get_step(front, turn(castDir, -SPELL_BOLT_LANE_SPREAD))

        for(var/turf/T in spawns)
            var/obj/projectile/spell/P = new(T)
            P.skill = src
            P.caster = user
            P.travelDir = castDir
            P.stepDelay = stepDelay
            P.icon_state = ResolveSkillFXState(fx_state, castDir)
            // Each lane rolls its own damage -- the three Icespears hit separately
            // (user, 2026-09-25). A burst still shares its one roll across its blast.
            P.damage = bolt_status ? 0 : user.ComputeSpellDamage(damage_multiplier)
            P.element = element
            P.pierces = bolt_pierces
            P.maxRange = bolt_range
            P.blockedByMobs = !bolt_pierces
            P.Launch()

        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)

    // What a bolt does to the mob it reached. Returns TRUE when the bolt should stop
    // (or, piercing, count this mob as hit).
    proc/BoltHit(obj/projectile/spell/P, turf/T, mob/M)
        var/mob/user = P.caster
        if(!user) return TRUE
        if(bolt_bursts) return TRUE  // Finish() blasts this tile, target included

        if(bolt_status)
            // A fail still uses the bolt up -- it reached them, it just didn't take.
            if(!prob(bolt_status_chance))
                view(M) << output("[M] resists [skillName]!", "Info")
                ShowCombatNumber(M, "miss", "#ffffff")
                return TRUE
            M.ApplyStatusEffect(bolt_status)
            OnStatusLanded(user, M)
            return TRUE

        var/landed = user.ApplySpellDamage(M, P.damage, element)
        if(landed) FlashSkillFX(T, impact_fx_state, IMPACT_FX_DURATION)
        return landed

    // Extra effect when a status bolt takes hold (Stopspell's MP drain). Base: none.
    proc/OnStatusLanded(mob/user, mob/M)
        return

    // The bolt's last open tile -- a bursting bolt explodes here.
    proc/BoltFinish(obj/projectile/spell/P, turf/T)
        if(!bolt_bursts || !T || !P.caster) return
        ApplyBlast(P.caster, T, P.damage, P.travelDir)

obj/projectile/spell
    var/datum/skill/SpellBolt/skill

    Impact(turf/T, mob/target = null)
        if(!target || !skill) return FALSE
        return skill.BoltHit(src, T, target)

    Finish(turf/T)
        if(skill) skill.BoltFinish(src, T)

// -----------------------------
// Beam Spell — a line that grows out from the caster tile by tile, like Thornwhip's
// lash (user's design for Thordain, from the OG, 2026-09-25). The first tile draws
// beam_origin_state facing the cast; each tile after it draws fx_state resolved by
// facing ("thordainns"/"thordainew"), up to beam_range tiles past the first. Mobs never
// stop it: it strikes every mob the caster may harm as it reaches them (one damage
// roll per cast, each victim can dodge). Only a wall or solid object ends it early.
// Once it's done growing it holds a moment, then vanishes from the caster outward.
// -----------------------------
#define BEAM_STEP_DELAY 0.5  // deciseconds per tile, growing and vanishing -- invented
#define BEAM_HOLD 2          // deciseconds held at full length -- invented

datum/skill/BeamSpell
    parent_type = /datum/skill/GenericSpell

    var
        beam_origin_state = null  // first tile's art; null = same as the rest
        beam_range = 6            // tiles beyond the first

    GetArtStates()
        return ..() + beam_origin_state

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!PayToCast(user)) return

        var/castDir = user.dir
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        if(!user.PlayCastMeter(src, wasDefending)) return  // died or interrupted

        // The caster is free once the beam leaves their hands; it grows on its own.
        user.canAct = TRUE
        user.RestoreDefendIfUntouched(wasDefending, mySession)
        Grow(user, castDir, user.ComputeSpellDamage(damage_multiplier))

    proc/Grow(mob/user, castDir, damage)
        set waitfor = 0
        var/bodyState = ResolveSkillFXState(fx_state, castDir)
        var/originState = beam_origin_state || bodyState
        var/pixelY = user.pixel_y
        var/list/segments = list()  // turf = image, in growth order
        var/list/struck = list()
        var/turf/T = user.loc

        for(var/i = 0 to beam_range)
            T = get_step(T, castDir)
            if(!T || IsTurfBlocked(T)) break

            segments[T] = AddTurfFX(T, (i == 0) ? originState : bodyState, castDir, pixelY)

            if(user)
                for(var/mob/M in T)
                    if(M in struck) continue
                    if(M.HP <= 0 || !user.CanHarm(M)) continue
                    struck += M
                    if(user.ApplySpellDamage(M, damage, element))
                        FlashSkillFX(T, impact_fx_state, IMPACT_FX_DURATION)

            if(i < beam_range) sleep(BEAM_STEP_DELAY)

        ClearTurfFX(segments, BEAM_HOLD, BEAM_STEP_DELAY)  // caster's end first

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

// -----------------------------
// Bolt Sword — melee AND projectile (user's design, 2026-09-25; OG's
// /proj/thunderswordblast, /proj/icesaberblast and /proj/lightswordblast tie the bolts
// to these swords). The swing hits the tile ahead like any sword, then a bolt
// (bolt_state) flies on from that tile until it hits something. A landed hit on a mob
// the user may harm flashes bolt_hit_state; a dodge lets the bolt fly on; a wall
// swallows it with no flash.
//
// The bolt starts ON the swung tile but ignores everyone standing there -- that tile
// belongs to the sword, so an adjacent target isn't hit twice by one use.
// -----------------------------
#define SWORD_BOLT_STEP_DELAY 0.65  // deciseconds per tile -- invented, obj/projectile's default

datum/skill/BoltSword
    parent_type = /datum/skill/GenericPhysical

    var
        bolt_state = null       // spells.dmi, 4 dirs -- the flying bolt
        bolt_hit_state = null   // spells.dmi -- flashed on a landed hit
        bolt_multiplier = null  // bolt's own Strength multiplier; null = same as the swing

    GetArtStates()
        return ..() + bolt_state + bolt_hit_state

    PerformHit(mob/user, mob/target)
        user.PerformMeleeHit(src, target)
        if(!user || user.isDead) return

        var/turf/swung = get_step(user, user.dir)
        if(!swung || IsTurfBlocked(swung)) return  // swinging into a wall -- no bolt

        var/obj/projectile/swordbolt/B = new(swung)
        B.caster = user
        B.travelDir = user.dir
        B.stepDelay = SWORD_BOLT_STEP_DELAY
        B.icon_state = bolt_state
        B.impactIconState = bolt_hit_state
        B.multiplier = isnull(bolt_multiplier) ? damage_multiplier : bolt_multiplier
        B.skipTurf = swung
        B.Launch()

obj/projectile/swordbolt
    var
        turf/skipTurf   // the swung tile -- the sword already covered it
        multiplier = 1

    FindTarget(turf/T)
        if(T == skipTurf) return null
        return ..()

    // Physical, not a spell: Strength-scaled through the same hit path as the swing
    // (dodge, crit, TakeDamage), instead of ApplySpellDamage().
    Impact(turf/T, mob/target = null)
        if(!target || !caster) return FALSE
        var/landed = caster.ResolvePhysicalHit(target, multiplier)
        if(landed) FlashSkillFX(T, impactIconState, IMPACT_FX_DURATION)
        return landed

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

// A light cut that drains MP (user, 2026-09-25: the OG knife only drained MP, did no
// damage; the user wants a little damage too). The drain only happens on a landed hit,
// scales off Strength like the cut, and the user soaks it up (DrainMP()).
#define MAGICKNIFE_DRAIN_MULTIPLIER 1.0  // MP drained, as a physical-hit multiplier -- invented

datum/skill/Magicknife
    parent_type = /datum/skill/GenericPhysical
    skillName = "Magicknife"
    fx_state = "magicknife"
    damage_multiplier = 0.4  // "a little damage" -- invented

    PerformHit(mob/user, mob/target)
        var/mob/M = user.PerformMeleeHit(src, target)
        if(M && M.HP > 0) M.DrainMP(user.ComputePhysicalDamage(MAGICKNIFE_DRAIN_MULTIPLIER), user)

// A plain one-tile swing that throws sand in the target's eyes (user's design,
// 2026-09-25 -- only the "sandtoss" art survives from the OG, and no class learned it).
// A landed hit blinds them (datum/status_effect/blind, StatusEffects.dm): they miss
// more and sometimes swing at the wrong tile. A dodge blinds nobody.
datum/skill/SandToss
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sand Toss"
    fx_state = "sandtoss"    // spells.dmi, 1 dir
    damage_multiplier = 0.3  // barely a scratch -- invented

    PerformHit(mob/user, mob/target)
        var/mob/M = user.PerformMeleeHit(src, target)
        if(M && M.HP > 0) M.ApplyStatusEffect(/datum/status_effect/blind)

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

// Club's 4-way spin, just harder (user, from the OG, 2026-09-25).
datum/skill/Morningstar
    parent_type = /datum/skill/Club
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
                if(user.ApplyPhysicalDamage(M, ringBase) && M && M.HP > 0)
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

// A claw, but fires Flamesword's bolt (OG: /proj/fireclawblast uses "flameblast").
datum/skill/Fireclaw
    parent_type = /datum/skill/BoltSword
    skillName = "Fireclaw"
    fx_state = "fireclaw"  // -> leftfireclaw/rightfireclaw
    bolt_state = "flameblast"
    bolt_hit_state = "flamespearhit"
    damage_multiplier = 1.4

// Not in the OG decompile, but the user remembers it (2026-09-25) and is drawing
// "lefticeclaw"/"righticeclaw" from Fireclaw's art. Mirrors Fireclaw: the claw swing,
// then IceSaber's bolt. Until the art lands the swing shows only the portrait's pose.
datum/skill/Iceclaw
    parent_type = /datum/skill/BoltSword
    skillName = "Iceclaw"
    fx_state = "iceclaw"  // -> lefticeclaw/righticeclaw once they exist in spells.dmi
    bolt_state = "iceblast"
    bolt_hit_state = "icespearhit"
    damage_multiplier = 1.4

// A whip that lashes out THORNWHIP_REACH tiles (user's design, 2026-09-25): one
// segment is laid per tile, tile by tile, until it reaches full length or lands a hit
// on a mob the user may harm. It holds there a moment, then pulls back in tip-first.
// Walls stop it short. Allies are passed over, and a dodge lets it keep extending past
// the dodger -- same rule as the bolt swords.
//
// The leading tile always draws whip_tip_state and every tile behind it whip_body_state
// (both default to fx_state) -- so Chainsickle's sickle stays on the end of its chain
// even when a hit stops it short.
#define THORNWHIP_REACH 3         // tiles -- user's design
#define THORNWHIP_STEP_DELAY 0.5  // deciseconds per tile, extending and retracting -- invented
#define THORNWHIP_HOLD 2          // deciseconds held at full length / on the hit -- invented

datum/skill/Thornwhip
    parent_type = /datum/skill/GenericPhysical
    skillName = "Thornwhip"
    fx_state = "thornwhip"  // spells.dmi, 4 dirs -- one per whip segment
    damage_multiplier = 0.8
    flashSwingFX = FALSE    // the whip draws itself as it extends

    var
        whip_body_state = null
        whip_tip_state = null

    GetArtStates()
        return ..() + whip_body_state + whip_tip_state

    PerformHit(mob/user, mob/target)
        var/whipDir = user.dir
        var/bodyState = ResolveSkillFXState(whip_body_state || fx_state, whipDir)
        var/tipState = ResolveSkillFXState(whip_tip_state || fx_state, whipDir)
        var/list/segments = list()  // turf = image, in extension order
        var/turf/T = user.loc
        var/turf/prevTip = null

        for(var/i = 1 to THORNWHIP_REACH)
            T = get_step(T, whipDir)
            if(!T || IsTurfBlocked(T)) break

            // The old tip becomes body now that the whip reaches past it.
            if(prevTip && bodyState != tipState)
                prevTip.overlays -= segments[prevTip]
                segments[prevTip] = AddTurfFX(prevTip, bodyState, whipDir, user.pixel_y)
            segments[T] = AddTurfFX(T, tipState, whipDir, user.pixel_y)
            prevTip = T

            if(StrikeTile(user, T)) break
            if(i < THORNWHIP_REACH) sleep(THORNWHIP_STEP_DELAY)
            if(!user || user.isDead) break

        ClearTurfFX(segments, THORNWHIP_HOLD, THORNWHIP_STEP_DELAY, fromTip = TRUE)

    // TRUE if a hit landed on T, which ends the lash there.
    proc/StrikeTile(mob/user, turf/T)
        for(var/mob/M in T)
            if(M == user || M.HP <= 0) continue
            if(!user.CanHarm(M)) continue
            if(user.ResolvePhysicalHit(M, damage_multiplier)) return TRUE
        return FALSE

// spells.dmi has no hit state for this bolt -- a landed hit shows nothing extra.
// Name one in bolt_hit_state once the art exists.
datum/skill/Lightsword
    parent_type = /datum/skill/BoltSword
    skillName = "Lightsword"
    fx_state = "lightsword"
    bolt_state = "lightswordblast"  // OG: /proj/lightswordblast
    damage_multiplier = 1.5

datum/skill/Battleaxe
    parent_type = /datum/skill/GenericPhysical
    skillName = "Battleaxe"
    fx_state = "battleaxe"
    damage_multiplier = 1.5

// Sage's top skill -- user's memory of the OG, 2026-09-25; the "sagesaber" art is in
// spells.dmi but no OG skill code survives. Only Sages unlock it (SkillUnlocks.dm), so
// knowing it is the gate. The swing sends whoever it lands on flying the way the
// user is facing, tile by tile, until they slam into a wall, a solid object or
// another mob. No damage on the swing itself -- it all lands on the slam, and grows
// exponentially with every tile flown: base x SAGESABER_GROWTH ^ tiles. No cap on the
// flight (user, 2026-09-25) -- across open ground they fly to the map edge, and the
// slam there is all but certain death. The slam can't be dodged (the swing was the
// dodge roll); the mob they hit takes nothing.
#define SAGESABER_GROWTH 1.5         // damage multiplier per tile flown -- invented
#define SAGESABER_DAMAGE_CAP 9999999 // only so 1.5^tiles can't overflow to infinity
#define SAGESABER_FLY_DELAY 1     // deciseconds per tile flown -- invented

datum/skill/SageSaber
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sage Saber"
    fx_state = "sagesaber"  // spells.dmi, 4 dirs
    damage_multiplier = 2.0  // the slam's base, before the per-tile growth -- invented

    PerformHit(mob/user, mob/target)
        var/mob/M = target || user.FindTargetAhead()
        if(!M || M.HP <= 0 || M.loc == user.loc || !user.CanHarm(M)) return
        if(M.isAirborne) return
        if(M.RollDodge())
            ShowCombatNumber(M, "miss", "#ffffff")
            return
        Launch(user, M, user.dir)

    proc/Launch(mob/user, mob/M, flyDir)
        set waitfor = 0
        var/couldAct = M.canAct
        M.canAct = FALSE  // no walking out of your own flight
        var/tiles = 0
        while(M && !M.isDead)
            if(!M.KnockBack(flyDir, SAGESABER_FLY_DELAY)) break
            tiles++
            sleep(SAGESABER_FLY_DELAY)
        if(!M) return
        if(couldAct && !M.isDead) M.canAct = TRUE
        if(!user || M.HP <= 0) return

        var/damage = round(min(SAGESABER_DAMAGE_CAP, user.ComputePhysicalDamage(damage_multiplier) * (SAGESABER_GROWTH ** tiles)))
        user.ApplyPhysicalDamage(M, damage, canDodge = FALSE)

datum/skill/Flamesword
    parent_type = /datum/skill/BoltSword
    skillName = "Flamesword"
    fx_state = "flamesword"
    bolt_state = "flameblast"
    bolt_hit_state = "flamespearhit"
    damage_multiplier = 1.6

datum/skill/Falconsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Falconsword"
    fx_state = "falconsword"
    damage_multiplier = 1.7

// Iron Claw, just stronger -- no projectile (user, from the OG, 2026-09-25).
datum/skill/Goldclaw
    parent_type = /datum/skill/IronClaw
    skillName = "Goldclaw"
    fx_state = "goldclaw"  // -> leftgoldclaw/rightgoldclaw
    damage_multiplier = 1.7

// Thornwhip's lash with a chain for a body and the sickle on the end (user, from the
// OG, 2026-09-25): at full reach that's chain, chain, sickle.
datum/skill/Chainsickle
    parent_type = /datum/skill/Thornwhip
    skillName = "Chainsickle"
    fx_state = "sickle"          // also what hides the portrait's weapon sprite
    whip_body_state = "chain"    // spells.dmi, 4 dirs
    whip_tip_state = "sickle"    // spells.dmi, 4 dirs
    damage_multiplier = 1.8

// User's own design (2026-09-25 -- the OG behavior isn't known): every landed hit
// saddles the target with lethargy (datum/status_effect/lethargy, StatusEffects.dm --
// slower steps, swings and spell windups), and a small chance also puts them to sleep
// exactly like the Sleep spell. A dodge does neither.
#define LETHARGY_SWORD_SLEEP_CHANCE 15  // % -- invented, "a slight chance"

datum/skill/SwordOfLethargy
    parent_type = /datum/skill/GenericPhysical
    skillName = "Sword Of Lethargy"
    fx_state = "swordoflethargy"
    damage_multiplier = 1.9

    PerformHit(mob/user, mob/target)
        var/mob/M = user.PerformMeleeHit(src, target)
        if(!M || M.HP <= 0) return
        M.ApplyStatusEffect(/datum/status_effect/lethargy)
        if(prob(LETHARGY_SWORD_SLEEP_CHANCE))
            M.ApplyStatusEffect(/datum/status_effect/sleep)

datum/skill/IceSaber
    parent_type = /datum/skill/BoltSword
    skillName = "Ice Saber"
    fx_state = "icesaber"
    bolt_state = "iceblast"        // OG: /proj/icesaberblast
    bolt_hit_state = "icespearhit"
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
    parent_type = /datum/skill/BoltSword
    skillName = "ThunderSword"
    fx_state = "thundersword"
    bolt_state = "thunderblast"    // OG: /proj/thunderswordblast
    bolt_hit_state = "lightninghit"
    damage_multiplier = 2.6

// =============================================================================
// OFFENSIVE SPELLS (Int gated) — damage_multiplier scales Intelligence
// =============================================================================
// Every spell here got a first shape in one pass (2026-09-25); the user is now going
// through them one at a time, and a spell marked "user" has been confirmed that way.
// The rest are drafts: the shape follows the OG decompile where it could be read (nearly
// every OG spell's use() spawned a /proj, and that /proj's art is used here), and is a
// pick, marked "PICK", where it couldn't. mana_cost is the real OG SpellCost() value
// (Markdowns/OGCombatFormulas.md §1); damage_multiplier is still ours. OG status/burn
// side effects (Firebane's burn trail) are left out for now.

// --- Plain bolts: fly until they hit something ---

// OG: /proj/blaze, MP 4, the same Int*2+4 formula as Zap -- so Zap's multiplier.
datum/skill/Blaze
    parent_type = /datum/skill/SpellBolt
    skillName = "Blaze"
    element = "fire"
    fx_state = "blaze"
    impact_fx_state = "blazehit"
    damage_multiplier = 0.9
    mana_cost = 4                    // OG

// Blaze's art and flight, just faster and harder (user, from the OG, 2026-09-25).
// OG: /proj/firebal also flies with "blaze", MP 4, damage round(Int*2.5)+5 vs Blaze's
// Int*2+4 -- so ~1.25x Blaze's multiplier.
#define FIREBALL_SLOWNESS 0.5  // flight step delay vs. Blaze's -- 0.5 = twice as fast; invented

datum/skill/Fireball
    parent_type = /datum/skill/Blaze
    skillName = "Fireball"
    damage_multiplier = 1.1
    bolt_slowness = FIREBALL_SLOWNESS

// One ice spear, icespearhit on impact (user, from the OG, 2026-09-25).
datum/skill/Icebolt
    parent_type = /datum/skill/SpellBolt
    skillName = "Icebolt"
    element = "ice"
    fx_state = "icespear"            // OG: /proj/icespear
    impact_fx_state = "icespearhit"
    damage_multiplier = 0.7
    mana_cost = 3

// OG: /skill/zap fires /proj/zap ("lightning" art), and was the Hero's Level-1 spell.
// Its OG damage formula matched Lightning's (Int*2+4); the user has Lightning hit harder.
datum/skill/Zap
    parent_type = /datum/skill/SpellBolt
    skillName = "Zap"
    element = "lightning"
    fx_state = "lightning"
    impact_fx_state = "lightninghit"
    damage_multiplier = 0.9
    mana_cost = 3

// Zap, just stronger -- and it chains (user, from the OG, 2026-09-25): a landed hit
// also strikes every mob the caster may harm on the 8 tiles around the one it hit,
// diagonals included, each with its own lightninghit. LIGHTNING_CHAIN_JUMPS 1 = one
// hop only; raise it and every chained victim arcs on to its own neighbours in turn.
#define LIGHTNING_CHAIN_JUMPS 1  // invented -- see note above

datum/skill/Lightning
    parent_type = /datum/skill/Zap
    skillName = "Lightning"
    damage_multiplier = 1.2
    mana_cost = 4                    // OG

    BoltHit(obj/projectile/spell/P, turf/T, mob/M)
        var/landed = ..()
        if(landed) Chain(P.caster, T, M, P.damage)
        return landed

    // Same damage roll as the bolt; each victim can still dodge its own arc. A mob is
    // only ever struck once per cast.
    proc/Chain(mob/user, turf/start, mob/firstHit, damage)
        if(!user || !start) return
        var/list/struck = list(firstHit)
        var/list/sources = list(start)
        for(var/jump = 1 to LIGHTNING_CHAIN_JUMPS)
            var/list/nextSources = list()
            for(var/turf/center in sources)
                for(var/turf/T in GetRingTurfs(center))
                    for(var/mob/M in T)
                        if(M in struck) continue
                        if(M.HP <= 0 || !user.CanHarm(M)) continue
                        struck += M
                        if(user.ApplySpellDamage(M, damage, element))
                            FlashSkillFX(T, impact_fx_state, IMPACT_FX_DURATION)
                            nextSources |= T
            if(!nextSources.len) return
            sources = nextSources

datum/skill/Blazemore
    parent_type = /datum/skill/SpellBolt
    skillName = "Blazemore"
    element = "fire"
    fx_state = "blazemore"           // OG: /proj/blazemore
    impact_fx_state = "blazemorehit"
    damage_multiplier = 1.2
    mana_cost = 7

datum/skill/Firevolt
    parent_type = /datum/skill/SpellBolt
    skillName = "Firevolt"
    element = "fire"
    fx_state = "flamespear"          // PICK -- OG /proj/flamespear art, fits a "volt"
    impact_fx_state = "flamespearhit"
    damage_multiplier = 1.6
    mana_cost = 10

// --- Rows of three: side-by-side bolts ---
datum/skill/Icespears
    parent_type = /datum/skill/SpellBolt
    skillName = "Icespears"
    element = "ice"
    fx_state = "icespear"            // user, from the OG: Icebolt's spear, three abreast
    impact_fx_state = "icespearhit"
    bolt_lanes = 3
    damage_multiplier = 1.1
    mana_cost = 5

// Icespears in fire (user, 2026-09-25). A real OG spell -- SpellCost() lists
// Flamespears at 16 MP and /skill/flamespears/use() exists -- but no class unlocks it
// in DWLR yet (Test_LearnSkill grants it).
datum/skill/Flamespears
    parent_type = /datum/skill/Icespears
    skillName = "Flamespears"
    element = "fire"
    fx_state = "flamespear"
    impact_fx_state = "flamespearhit"
    damage_multiplier = 1.4          // invented -- a tier above Icespears' 1.1
    mana_cost = 16                   // OG

// OG use() turns the caster's dir by 90 -- read here as a row of three.
datum/skill/Blazemost
    parent_type = /datum/skill/SpellBolt
    skillName = "Blazemost"
    element = "fire"
    fx_state = "blazemore"           // no "blazemost" art -- Blazemore's, three abreast
    impact_fx_state = "blazemorehit"
    bolt_lanes = 3
    damage_multiplier = 1.9
    mana_cost = 10

// --- Piercing: fly through everyone in the line ---
// OG /proj/infernos and /proj/infermore have their own slower Step() -- a rolling fire.
datum/skill/Infernos
    parent_type = /datum/skill/SpellBolt
    skillName = "Infernos"
    element = "fire"
    fx_state = "infernos"            // 4-frame flame, no directions
    impact_fx_state = "blazehit"     // PICK -- no infernos hit art
    bolt_pierces = TRUE
    bolt_range = 4
    bolt_slowness = 2
    damage_multiplier = 1.0
    mana_cost = 5

datum/skill/Infermore
    parent_type = /datum/skill/Infernos
    skillName = "Infermore"
    fx_state = "infermore"
    impact_fx_state = "blazemorehit"
    bolt_lanes = 3                   // PICK -- the bigger tier rolls three wide
    damage_multiplier = 1.5
    mana_cost = 8

datum/skill/Blizzard
    parent_type = /datum/skill/SpellBolt
    skillName = "Blizzard"
    element = "ice"
    fx_state = "blizzard"            // OG: /proj/blizzard
    impact_fx_state = "icespearhit"
    bolt_pierces = TRUE              // PICK -- a three-wide gust through everything
    bolt_lanes = 3
    bolt_range = 4
    damage_multiplier = 1.3
    mana_cost = 10

datum/skill/Firebane
    parent_type = /datum/skill/SpellBolt
    skillName = "Firebane"
    element = "fire"
    fx_state = "firebane"            // 2-frame, 4 dirs
    impact_fx_state = "blazemorehit"
    bolt_pierces = TRUE              // OG also left a burn trail -- left out for now
    bolt_range = 7
    damage_multiplier = 1.7
    mana_cost = 7

// --- Bursts: the bolt explodes where it stops ---
// OG /proj/bang flies with Blaze's art and its Collide() hits the 4 sides; /proj/boom
// flies with Blazemore's and also turns 45 -- the corners too.
datum/skill/Bang
    parent_type = /datum/skill/SpellBolt
    skillName = "Bang"
    element = "fire"
    fx_state = "blaze"
    blast_fx_state = "bang"
    bolt_bursts = TRUE
    aoe_radius = 1                   // the plus: centre + 4 sides
    damage_multiplier = 1.5
    mana_cost = 6

datum/skill/Boom
    parent_type = /datum/skill/Bang
    skillName = "Boom"
    fx_state = "blazemore"
    aoe_square = TRUE                // the full 3x3
    mana_cost = 12

// Boom's 3x3 plus the ring of flame it leaves on the ground (HazardFields.dm) -- burn
// comes from standing in the flames, not from the blast. Open question to the user
// whether the flames stay while status effects are off the table.
datum/skill/Explodet
    parent_type = /datum/skill/Boom
    skillName = "Explodet"
    fx_state = "explodet"            // OG: /proj/explodet
    damage_multiplier = 2.2
    mana_cost = 16
    hazardFieldType = /obj/hazard_field/flame
    hazard_radius = 1
    hazard_duration = 80  // deciseconds the fire stays on the ground

// --- Beam ---
// User, from the OG, 2026-09-25: "thordain" on the first tile, then 6 more tiles of
// "thordainns"/"thordainew" grow out; passes through mobs, only walls stop it.
datum/skill/Thordain
    parent_type = /datum/skill/BeamSpell
    skillName = "Thordain"
    element = "lightning"
    fx_state = "thordain"            // -> "thordainns"/"thordainew" by facing
    impact_fx_state = "lightninghit"
    beam_origin_state = "thordain"   // 4 dirs -- drawn facing the cast
    beam_range = 6
    damage_multiplier = 1.6
    mana_cost = 7

// --- Around the caster ---
datum/skill/Snowstorm
    parent_type = /datum/skill/AoESpell
    skillName = "Snowstorm"
    element = "ice"
    fx_state = "snowstorm"           // 4-frame, no directions
    aoe_on_caster = TRUE             // PICK -- a storm all around you
    aoe_radius = 2
    damage_multiplier = 1.8
    mana_cost = 16

// =============================================================================
// HEALING SPELLS (Int gated) — heal_amount is flat, not stat-scaled (HealSpell, top)
// =============================================================================
// Not yet reviewed with the user: the amounts are out of order (Heal outheals
// Healmore) and the MP costs aren't the OG's (Heal 6, Healmore 15, Healmost 40,
// Healus 20, Healusmore 60).
datum/skill/Heal
    parent_type = /datum/skill/HealSpell
    skillName = "Heal"
    fx_state = "heal"
    heal_amount = 60
    mana_cost = 4

datum/skill/Healmore
    parent_type = /datum/skill/HealSpell
    skillName = "Healmore"
    fx_state = "healmore"
    heal_amount = 30
    mana_cost = 8

// No dedicated "healus" art — reuses Healmore's.
datum/skill/Healus
    parent_type = /datum/skill/HealSpell
    skillName = "Healus"
    fx_state = "healmore"
    heal_amount = 40
    mana_cost = 10

datum/skill/Healmost
    parent_type = /datum/skill/HealSpell
    skillName = "Healmost"
    fx_state = "healmost"
    heal_amount = 55
    mana_cost = 12

// No dedicated "healusmore" art — reuses Healmost's.
datum/skill/Healusmore
    parent_type = /datum/skill/HealSpell
    skillName = "Healusmore"
    fx_state = "healmost"
    heal_amount = 75
    mana_cost = 15

// =============================================================================
// BUFF SPELLS — apply statusEffectType (StatusEffects.dm) to self, or to the ally faced
// =============================================================================
datum/skill/BuffSpell
    parent_type = /datum/skill/GenericSpell

    var
        statusEffectType = null
        // TRUE = the cast burst plays out in full before the buff (and its standing
        // overlay) lands, so the two read as separate beats (Upper).
        burst_before_buff = FALSE

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        // Utility, not combat -- usable anywhere, peaceful areas included (like heals/Return).
        if(!PayToCast(user)) return

        var/mob/buffTarget = target || user
        if(!user.PlayCastMeter(src)) return  // died or interrupted

        user.PlaySkillFX(src, buffTarget)  // the cast burst; the buff's own standing
                                           // indicator is activeFXState on the status
                                           // effect (StatusEffects.dm)
        if(burst_before_buff)
            sleep(SKILL_FX_DURATION)
            if(user.isDead) return
        if(buffTarget) buffTarget.ApplyStatusEffect(statusEffectType)

        user.canAct = TRUE

// User, from the OG, 2026-09-25: a slowish cast, then "upperon" flashes and goes, then
// "upper" stays on the buffed player for about a minute (UPPER_DURATION,
// StatusEffects.dm).
#define UPPER_CAST_SLOWNESS 1.5  // cast meter vs. a normal spell -- invented

datum/skill/Upper
    parent_type = /datum/skill/BuffSpell
    skillName = "Upper"
    fx_state = "upperon"
    burst_before_buff = TRUE
    cast_meter_slowness = UPPER_CAST_SLOWNESS
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
// STATUS BOLTS — SpellBolts that apply a status effect instead of damage (bolt_status)
// =============================================================================
// OG: /proj/sleep and /proj/stopspell applied their effect in Collide(). The
// "sleep"/"stopspell" art flies like any bolt; the sleeping target's own standing overlay is
// "asleep", set as activeFXState on the status effect (StatusEffects.dm).
//
// The OG Sleep always took hold and no hit woke the sleeper. The user wants it able to
// fail (2026-09-25): a roll on contact, and a fail shows "miss". Waking on damage is
// SLEEP_WAKE_ON_HIT_PERCENT (CombatSystem.dm); nap length is StatusEffects.dm's.
#define SLEEP_CHANCE 70       // % Sleep takes hold -- invented
#define SLEEPMORE_CHANCE 85   // % Sleepmore takes hold -- invented

datum/skill/Sleep
    parent_type = /datum/skill/SpellBolt
    skillName = "Sleep"
    fx_state = "sleep"
    bolt_status = /datum/status_effect/sleep
    bolt_status_chance = SLEEP_CHANCE
    mana_cost = 3

datum/skill/Sleepmore
    parent_type = /datum/skill/Sleep
    skillName = "Sleepmore"
    bolt_status = /datum/status_effect/sleep/more
    bolt_status_chance = SLEEPMORE_CHANCE
    mana_cost = 7

// Silences AND drains MP (user, from the OG, 2026-09-25; OG use() passed Int*2+10 to
// the bolt, likely the drain). The caster soaks up what it drains (DrainMP()). Amount
// is ComputeSpellDamage(damage_multiplier), so it scales like a spell hit.
// Can fail like Sleep (user, 2026-09-25) -- a fail neither silences nor drains.
#define STOPSPELL_CHANCE 75  // % Stopspell takes hold -- invented

datum/skill/Stopspell
    parent_type = /datum/skill/SpellBolt
    skillName = "Stopspell"
    fx_state = "stopspell"
    bolt_status = /datum/status_effect/silence
    bolt_status_chance = STOPSPELL_CHANCE
    damage_multiplier = 1.0  // MP drained, as a spell-hit multiplier -- invented
    mana_cost = 6

    OnStatusLanded(mob/user, mob/M)
        M.DrainMP(user.ComputeSpellDamage(damage_multiplier), user)

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
    parent_type = /datum/skill/GenericSpell
    skillName = "Return"
    mana_cost = 8

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!PayToCast(user)) return
        if(!user.PlayCastMeter(src)) return  // died or interrupted

        user.loc = GetPlayerSpawnTurf()
        if(user.client && user.client.camera)
            user.client.camera.SnapTo(user)  // direct .loc change bypasses client/Move(), the only place the camera normally tracks
        user.ShowInfo("You return to town!")

        user.canAct = TRUE

// Resurrects a fallen ally, bypassing their auto-respawn wait (Die(), CombatSystem.dm).
// Slow windup, always works (user, from the OG, 2026-09-25). revive_chance < 100 makes
// it a gamble (Vivify, below); a fail still spends the MP.
#define REVIVE_CAST_SLOWNESS 1.5  // cast meter vs. a normal spell -- invented, same as Upper

datum/skill/Revive
    parent_type = /datum/skill/GenericSpell
    skillName = "Revive"
    mana_cost = 50                // OG
    cast_meter_slowness = REVIVE_CAST_SLOWNESS

    var
        revive_chance = 100      // % the spell brings them back
        revive_hp_percent = 50   // of MaxHP they come back with

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!target || !istype(target, /mob/player))
            user.ShowInfo("[skillName] only works on a fallen ally.")
            return

        var/mob/player/P = target
        if(!P.isDead)
            user.ShowInfo("[P.name] isn't in need of reviving.")
            return

        if(!PayToCast(user)) return
        if(!user.PlayCastMeter(src)) return  // died or interrupted

        if(P && P.isDead)
            if(prob(revive_chance))
                P.isDead = FALSE
                P.density = 1
                P.icon_state = "world"
                P.canAct = TRUE
                P.HP = max(1, round(P.MaxHP * revive_hp_percent / 100))
                P.ShowInfo("You have been revived by [user.name]!")
            else
                user.ShowInfo("[skillName] fails to revive [P.name].")
                P.ShowInfo("[user.name]'s [skillName] fails to revive you.")
                ShowCombatNumber(P, "miss", "#ffffff")

        user.canAct = TRUE

// Revive at a coin flip -- same slow windup (user, from the OG, 2026-09-25).
#define VIVIFY_CHANCE 50           // user's number

datum/skill/Vivify
    parent_type = /datum/skill/Revive
    skillName = "Vivify"
    revive_chance = VIVIFY_CHANCE
    mana_cost = 20                 // OG

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
