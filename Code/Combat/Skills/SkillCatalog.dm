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

        user.PlayAttackAnimation(src, target)
        // The skill's spells.dmi art (SkillFX.dm), on top of the portrait's own swing
        // pose that PlayAttackAnimation() just played. Drawn on the target when there is
        // one, otherwise on the tile being swung at — same placement as the weapon
        // overlay. PlayAttackAnimation() flips animAlternate first, so a handed FX pair
        // ("leftclaw"/"rightclaw") always agrees with the hand in the pose.
        if(flashSwingFX) user.PlaySkillFX(src, target || get_step(user, user.dir))

        // The target captured at swing-start (UseSkillSlot()) is passed through rather
        // than re-scanning the tile ahead once the windup has elapsed.
        spawn(cast_time)
            if(!user || user.isDead) return  // died in the windup -- no posthumous hit
            PerformHit(user, target)
            // Swing landed — the user may move again, but can't attack again until the
            // full recovery ends (canAct stays FALSE that whole time).
            if(!user.isDead) user.attackRecoveryOnly = TRUE

        spawn(atkDelay)
            // Died meanwhile — Die() locked canAct as part of the death/respawn flow;
            // unlocking it here would undo that.
            if(user.isDead) return
            user.attackRecoveryOnly = FALSE
            user.EndAction(wasDefending, mySession)

// -----------------------------
// Generic Spell — what every spell shares (Int gated). Each spell shape below brings
// its own OnUse(); all of them open with PayToCast() (SkillDatum.dm) and the cast meter.
// -----------------------------
datum/skill/GenericSpell
    parent_type = /datum/skill
    isSpell = TRUE
    icon_state = "weapon"

    // Who a support spell (heal, buff) lands on: the target when it's on the caster's own
    // side (players and their pets, or wild monsters -- CombatSide(), CombatSystem.dm),
    // else the caster. The skill slots pass whoever is faced as the target, and that
    // used to include the monster being fought -- healing and buffing it.
    proc/AllyOrSelf(mob/user, mob/target)
        if(target && target != user && target.CombatSide() == user.CombatSide()) return target
        return user

// -----------------------------
// Heal Spell — a flat heal_amount on the ally faced, or on the caster when facing
// nobody (or an enemy -- AllyOrSelf()). A party heal (heal_party) instead covers the
// caster plus every party member in view. Usable anywhere, peaceful areas included. Plays through
// PlayHealCastSequence() (CombatSystem.dm): cast meter, then the heal art held on each
// patient before the heal lands.
// -----------------------------
datum/skill/HealSpell
    parent_type = /datum/skill/GenericSpell

    var
        heal_amount = 0
        heal_full = FALSE   // TRUE = restores each patient to full HP instead (Healmost)
        heal_party = FALSE  // TRUE = caster + party members in view (Healus, Healusmore)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return

        // Only the ones who need it -- a party heal still goes off if anyone's hurt.
        var/list/patients = list()
        for(var/mob/M in GetPatients(user, target))
            if(M.HP < M.MaxHP) patients += M
        if(!patients.len)
            var/mob/single = heal_party ? null : AllyOrSelf(user, target)
            if(!single) user.ShowInfo("Everyone is already at full HP.")
            else user.ShowInfo("[single == user ? "You are" : "[single] is"] already at full HP.")
            return

        if(!PayToCast(user)) return
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        user.PlayHealCastSequence(src, patients, wasDefending, mySession)

    proc/GetPatients(mob/user, mob/target)
        if(!heal_party) return list(AllyOrSelf(user, target))
        var/list/L = list(user)
        var/mob/player/P = user
        if(istype(P) && P.Party)
            for(var/mob/player/M in P.Party.members)
                if(M == user || M.isDead) continue
                if(M in view(user)) L += M
        return L

    proc/HealAmountFor(mob/M)
        return heal_full ? M.MaxHP : heal_amount

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
        aoe_cut_corners = FALSE // with aoe_square: drop the square's 4 corner tiles (Boom's 3-5-5-5-3)
        aoe_on_caster = FALSE   // TRUE = centered on the caster (who is never hit by it)
        blast_fx_state = null   // art flashed on each blast tile; null = fx_state
        blast_dodgeable = TRUE  // FALSE = everyone in the blast is hit, no dodge roll (Bang)
        blast_covers_walls = FALSE  // TRUE = the whole shape is drawn, over walls too (Bang, Boom)

        // Residual ground hazard left behind, over the blast's shape. null = none.
        hazardFieldType = null
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

    // The blast's tiles around center: a diamond, a square, or a square with its corners
    // cut (aoe_radius, aoe_square, aoe_cut_corners).
    proc/GetBlastArea(turf/center, skipWalls = TRUE)
        var/list/area = aoe_square ? GetSquareTurfs(center, aoe_radius, skipWalls) : GetDiamondTurfs(center, aoe_radius, skipWalls)
        if(aoe_square && aoe_cut_corners)
            for(var/turf/T in area.Copy())
                if(abs(T.x - center.x) == aoe_radius && abs(T.y - center.y) == aoe_radius)
                    area -= T
        return area

    // One damage roll shared by everyone caught in the blast, not a separate roll per
    // victim — an explosion should read as a single event. fxDir: which way directional
    // blast art faces -- the caster's facing unless a spell bolt passes its flight dir.
    proc/ApplyBlast(mob/user, turf/center, damage, fxDir = 0)
        if(!fxDir) fxDir = user.dir
        var/fxState = ResolveSkillFXState(blast_fx_state || fx_state, fxDir, user.animAlternate)
        var/list/area = GetBlastArea(center, !blast_covers_walls)

        for(var/turf/T in area)
            if(fxState) FlashSkillFX(T, fxState, fxDir = fxDir, pixelY = user.pixel_y)

            for(var/mob/M in T)
                // Coop mode / friendly fire (CanHarm(), CombatSystem.dm) -- also
                // excludes the caster itself.
                if(!user.CanHarm(M)) continue
                if(M.HP <= 0) continue
                user.ApplySpellDamage(M, damage, element, canDodge = blast_dodgeable)

        // The fire takes the blast's own shape, walls left out (Explodet's 3-5-5-5-3).
        if(hazardFieldType)
            var/power = round(damage * hazard_power_multiplier)
            for(var/turf/T in GetBlastArea(center))
                PlaceHazardField(T, hazardFieldType, user, power, element, hazard_duration)

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!PayToCast(user)) return

        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        // Aim locks now, at cast start — the blast shouldn't re-aim itself if the
        // caster turns during the windup.
        var/turf/center = FindBlastCenter(user, target)

        if(!user.PlayCastMeter(src, wasDefending, mySession)) return  // died or interrupted
        ApplyBlast(user, center, user.ComputeSpellDamage(damage_multiplier))

        user.EndAction(wasDefending, mySession)

// -----------------------------
// Spell Bolt — every "cast, then something flies" spell (user's design, 2026-09-25;
// OG: nearly every offensive spell's use() just spawned a /proj). Cast meter, then
// fx_state flies out in the facing direction. Aimed, not locked on -- needs no target.
//
// Shape knobs, all per skill:
//   bolt_lanes     1 = one bolt; 3 = a row of three, side by side (Icespears, Blazemost,
//                  Infermost)
//   bolt_pierces   flies through whoever it hits instead of stopping (Infernos family)
//   bolt_range     tiles it may travel; 0 = until it hits something
//   bolt_slowness  multiplies the flight step delay -- 2 = half speed
//   bolt_bursts    on contact / at a wall / at range's end it explodes as this spell's
//                  AoESpell blast (aoe_radius, aoe_square, blast_fx_state, hazard field)
//   bolt_status    a status bolt (Sleep, Stopspell): applies this instead of damage
//   bolt_homes     seeks the nearest mob the caster may harm (Blazemore) -- see below
//   bolt_four_ways one bolt each way, N/E/S/W, from the tiles around the caster
//                  (Blizzard); overrides bolt_lanes
//   bolt_knockback_chance / _again_chance / _max
//                  a landed hit may shove the target back along the flight (Infernos)
//
// A plain bolt stops on the first solid mob or wall. A landed hit on a mob the caster
// may harm flashes impact_fx_state; an ally or a wall just stops it with no flash; a
// dodge lets it fly on. A bursting bolt detonates on ANY mob it touches, dodge or not --
// the blast does the damage, so dodging the bolt itself means nothing.
//
// A homing bolt (user's design for Blazemore, 2026-09-25) picks its target when it
// leaves the caster's hands: the nearest mob in sight the caster may harm, hidden and
// ghosted ones excluded. It launches toward that mob and re-aims every tile, diagonals
// included. Anyone else in its path still takes the hit. If the target dies, hides or
// leaves, it re-picks from where it is now. With no target left it flies straight.
// If its target dodges, it stops homing and flies straight on.
// Homing lanes (Blazemost) all launch toward the nearest target, then split up: the
// middle bolt keeps that one, and each side bolt takes the nearest one nobody else has.
// -----------------------------
#define SPELL_BOLT_LANE_SPREAD 90  // side lanes sit at facing +/- this many degrees
#define HOMING_ACQUIRE_RANGE 6     // tiles a homing bolt looks for a target -- the 13x13 screen's edge; invented
#define HOMING_MAX_TILES 20        // a homing bolt gives up after this many tiles -- invented safety cap
#define SPELL_KNOCKBACK_GLIDE 1.5  // deciseconds per tile a bolt's knockback slides the target -- invented

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
        bolt_homes = FALSE
        bolt_four_ways = FALSE
        bolt_knockback_chance = 0        // % a landed hit knocks the target back a tile
        bolt_knockback_again_chance = 0  // % each further tile, once knocked back
        bolt_knockback_max = 1           // most tiles one hit can knock a target back

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!PayToCast(user)) return

        // Aim locks at cast start -- turning isn't blocked by canAct.
        var/castDir = user.dir
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()
        var/atkDelay = user.GetAttackDelay(src, wasDefending)

        if(!user.PlayCastMeter(src, wasDefending, mySession)) return  // died or interrupted

        // atkDelay / slowFactor: a lethargic caster winds up slower, but the bolt itself
        // still flies at full speed once it leaves their hands.
        var/stepDelay = max(PROJECTILE_MIN_STEP_DELAY, atkDelay / user.slowFactor / PROJECTILE_SPEED_DIVISOR) * bolt_slowness

        // A homing bolt launches at its target, not where the caster faces.
        var/mob/homeOn = bolt_homes ? FindHomingTarget(user, user) : null
        if(homeOn) castDir = HomingStepDir(user, homeOn) || castDir

        var/turf/front = get_step(user, castDir)
        var/list/spawns = list()  // spawn turf = its travel dir
        if(bolt_four_ways)
            for(var/d in list(castDir, turn(castDir, 90), turn(castDir, 180), turn(castDir, -90)))
                var/turf/S = get_step(user, d)
                if(S) spawns[S] = d
        else if(front)
            spawns[front] = castDir
            if(bolt_lanes >= 3)
                for(var/side in list(SPELL_BOLT_LANE_SPREAD, -SPELL_BOLT_LANE_SPREAD))
                    var/turf/S = get_step(front, turn(castDir, side))
                    if(S) spawns[S] = castDir

        var/list/claimed = homeOn ? list(homeOn) : list()
        for(var/turf/T in spawns)
            var/flyDir = spawns[T]
            var/obj/projectile/spell/P = new(T)
            P.skill = src
            P.caster = user
            P.travelDir = flyDir
            P.stepDelay = stepDelay
            P.icon_state = ResolveSkillFXState(fx_state, flyDir)
            // Each lane rolls its own damage -- the three Icespears hit separately
            // (user, 2026-09-25). A burst still shares its one roll across its blast.
            P.damage = bolt_status ? 0 : user.ComputeSpellDamage(damage_multiplier)
            P.element = element
            P.pierces = bolt_pierces
            P.maxRange = bolt_range
            P.blockedByMobs = !bolt_pierces
            if(bolt_homes)
                P.homing = TRUE
                P.homingTarget = (T == front) ? homeOn : PickLaneTarget(user, T, claimed)
                if(!P.maxRange) P.maxRange = HOMING_MAX_TILES
            P.Launch()

        user.EndAction(wasDefending, mySession)

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
        if(landed && bolt_knockback_chance && prob(bolt_knockback_chance))
            BlowBack(M, P.travelDir)
        return landed

    // A landed hit's knockback: one tile the way the bolt flies, then each further
    // tile rolls bolt_knockback_again_chance, up to bolt_knockback_max tiles. A wall, a
    // solid object or another mob in the way ends it (KnockBack()).
    proc/BlowBack(mob/M, pushDir)
        set waitfor = 0
        for(var/i = 1 to bolt_knockback_max)
            if(!M || M.HP <= 0 || M.isDead) return
            if(i > 1 && !prob(bolt_knockback_again_chance)) return
            if(!M.KnockBack(pushDir, SPELL_KNOCKBACK_GLIDE)) return
            sleep(SPELL_KNOCKBACK_GLIDE)

    // Whether a homing bolt may chase M: alive, visible, and someone the caster may harm.
    proc/IsHomeable(mob/user, mob/M)
        if(!user || !M || !M.loc || M == user) return FALSE
        if(M.HP <= 0 || M.isDead || !M.IsTargetable()) return FALSE
        return user.CanHarm(M)

    // The nearest homeable mob in sight of `origin` (the caster at launch, the bolt
    // mid-flight). Ties go to the straighter line.
    proc/FindHomingTarget(mob/user, atom/origin, list/exclude = null)
        var/mob/best = null
        var/bestDist = 0
        var/bestLine = 0
        for(var/mob/M in view(HOMING_ACQUIRE_RANGE, origin))
            if(exclude && (M in exclude)) continue
            if(!IsHomeable(user, M)) continue
            var/dist = get_dist(origin, M)
            var/line = (M.x - origin.x) ** 2 + (M.y - origin.y) ** 2
            if(best && (dist > bestDist || (dist == bestDist && line >= bestLine))) continue
            best = M
            bestDist = dist
            bestLine = line
        return best

    // A side lane's homing target: the nearest mob from its own tile that no other lane
    // of this cast has claimed, so a volley spreads over a group. With fewer targets than
    // lanes, it doubles up on the nearest anyway.
    proc/PickLaneTarget(mob/user, turf/T, list/claimed)
        var/mob/M = FindHomingTarget(user, T, claimed) || FindHomingTarget(user, T)
        if(M) claimed |= M
        return M

    // Extra effect when a status bolt takes hold (Stopspell's MP drain). Base: none.
    proc/OnStatusLanded(mob/user, mob/M)
        return

    // The bolt's last open tile -- a bursting bolt explodes here.
    proc/BoltFinish(obj/projectile/spell/P, turf/T)
        if(!bolt_bursts || !T || !P.caster) return
        ApplyBlast(P.caster, T, P.damage, P.travelDir)

obj/projectile/spell
    var
        datum/skill/SpellBolt/skill
        homing = FALSE
        mob/homingTarget

    Impact(turf/T, mob/target = null)
        if(!target || !skill) return FALSE
        var/landed = skill.BoltHit(src, T, target)
        if(!landed && target == homingTarget) homing = FALSE  // dodged -- fly on past
        return landed

    Steer()
        if(!homing || !skill) return
        if(!skill.IsHomeable(caster, homingTarget))
            homingTarget = skill.FindHomingTarget(caster, src)
            if(!homingTarget)
                homing = FALSE  // nobody left -- straight on from here
                return
        var/newDir = HomingStepDir(src, homingTarget)
        if(!newDir || newDir == travelDir) return
        travelDir = newDir
        dir = newDir
        icon_state = ResolveSkillFXState(skill.fx_state, newDir)

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
        beam_hold = BEAM_HOLD     // deciseconds held at full length before it fades
        // A hazard field (HazardFields.dm) laid on each beam tile instead of plain art --
        // the beam stays for beam_hold as damage over time (Firevolt's burning line).
        beam_hazard_type = null
        beam_hazard_power_multiplier = 0.5  // field power vs. the beam's damage roll

    GetArtStates()
        return ..() + beam_origin_state

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!user.InBattleArea()) return
        if(!PayToCast(user)) return

        var/castDir = user.dir
        var/mySession = user.defendToggleSession
        var/wasDefending = user.DropDefendForAction()

        if(!user.PlayCastMeter(src, wasDefending, mySession)) return  // died or interrupted

        // The caster is free once the beam leaves their hands; it grows on its own.
        user.EndAction(wasDefending, mySession)
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

            // A burning beam lays its fire field as it grows, and the field IS the beam's
            // art (Firevolt). Laid a step apart, the fields also burn out a step apart --
            // so it still vanishes from the caster's end first.
            if(beam_hazard_type)
                PlaceHazardField(T, beam_hazard_type, user, round(damage * beam_hazard_power_multiplier),
                                 element, beam_hold, castDir)
            else
                segments[T] = AddTurfFX(T, (i == 0) ? originState : bodyState, castDir, pixelY)

            if(user)
                for(var/mob/M in T)
                    if(M in struck) continue
                    if(M.HP <= 0 || !user.CanHarm(M)) continue
                    struck += M
                    if(user.ApplySpellDamage(M, damage, element))
                        FlashSkillFX(T, impact_fx_state, IMPACT_FX_DURATION)

            if(i < beam_range) sleep(BEAM_STEP_DELAY)

        ClearTurfFX(segments, beam_hold, BEAM_STEP_DELAY)  // caster's end first

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
        user.PlayAttackSound()  // once for the whole spin
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
        user.EndAction(wasDefending, mySession)

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
        user.EndAction(wasDefending, mySession)

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

        user.PlayAttackAnimation(src)  // throwing pose + sound
        sleep(cast_time)
        if(!user || user.isDead) return

        var/obj/projectile/boomerang/B = new(user.loc)
        B.icon_state = fx_state
        B.caster = user
        B.skill = src
        B.travelDir = throwDir
        B.stepDelay = BOOMERANG_STEP_DELAY
        inFlight = B
        B.Launch()

        sleep(max(0, user.GetAttackDelay(src, wasDefending) - cast_time))
        if(!user || user.isDead) return
        user.EndAction(wasDefending, mySession)

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

// A stronger Boomerang, flight and all (user, 2026-09-25: "for now"). Not in the OG
// decompile at all; spells.dmi does have "masterang" art. No class unlocks it yet --
// Test_LearnSkill and Archsage have it. It's its own skill, so a Boomerang and a
// Masterang can both be in the air at once.
datum/skill/Boomerang/Masterang
    skillName = "Masterang"
    fx_state = "masterang"
    damage_multiplier = 1.8  // invented -- Boomerang's is 1.3

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
        user.EndAction(wasDefending, mySession)

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
        user.EndAction(wasDefending, mySession)

    proc/Quake(mob/user)
        var/turf/center = user.loc
        if(!center) return
        user.PlayAttackSound()

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

// Not in the OG decompile, but the user remembers it (2026-09-25) and drew
// "lefticeclaw"/"righticeclaw" from Fireclaw's art. Mirrors Fireclaw: the claw swing,
// then IceSaber's bolt.
datum/skill/Iceclaw
    parent_type = /datum/skill/BoltSword
    skillName = "Iceclaw"
    fx_state = "iceclaw"  // -> lefticeclaw/righticeclaw
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

// Plain melee swings, their own art in place of the generic weapon (user, 2026-09-25).
// Damage is a placeholder and special effects are undecided; none is in any class's
// unlock table yet (Test_LearnSkill and Archsage have them).
//
// Zenithiansword is OG: /skill/zenithiansword drew "zenithian", but no class could learn
// it (GM-only or cut). Gemsword and Demonsword aren't in the OG decompile; "gemsword"
// art exists, "demonsword" has none yet (a swing draws nothing until it's added).
datum/skill/Gemsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Gemsword"
    fx_state = "gemsword"
    damage_multiplier = 1.6    // placeholder

datum/skill/Demonsword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Demonsword"
    fx_state = "demonsword"    // no art yet
    damage_multiplier = 2.0    // placeholder

datum/skill/Zenithiansword
    parent_type = /datum/skill/GenericPhysical
    skillName = "Zenithiansword"
    fx_state = "zenithian"     // OG
    damage_multiplier = 2.5    // placeholder

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
// Every spell here has been described by the user one at a time (2026-09-25), usually
// from memory of the OG; "user" marks those calls. A leftover guess is marked "PICK".
// mana_cost is the real OG SpellCost() value where marked OG (Markdowns/
// OGCombatFormulas.md §1); damage_multiplier is ours.

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

// Icebolt in fire -- one flame spear, as Flamespears is Icespears in fire (user,
// 2026-09-25). Not in the OG: only the three-spear Flamespears was.
datum/skill/Flamespear
    parent_type = /datum/skill/Icebolt
    skillName = "Flamespear"
    element = "fire"
    fx_state = "flamespear"          // OG: /proj/flamespear
    impact_fx_state = "flamespearhit"
    damage_multiplier = 0.9          // invented -- Icebolt x Flamespears' 1.4/1.1
    mana_cost = 4                    // invented

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

// Lightning with the "dark" art (user, 2026-09-25) -- same bolt, chain, damage and
// cost. Art only in the OG: no dark spell survives in the decompile. No unlock yet.
datum/skill/Lightning/DarkLightning
    skillName = "DarkLightning"
    fx_state = "darklightning"
    impact_fx_state = "darklightninghit"

// Blaze that homes (user, 2026-09-25): locks onto the nearest enemy in sight and
// steers after it -- see the homing notes at SpellBolt.
datum/skill/Blazemore
    parent_type = /datum/skill/SpellBolt
    skillName = "Blazemore"
    element = "fire"
    fx_state = "blazemore"           // OG: /proj/blazemore
    impact_fx_state = "blazemorehit"
    bolt_homes = TRUE
    damage_multiplier = 1.2
    mana_cost = 7

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
// Flamespears at 16 MP and /skill/flamespears/use() exists -- though no OG class
// learned it. Wizard and Sage do in DWLR (user).
datum/skill/Flamespears
    parent_type = /datum/skill/Icespears
    skillName = "Flamespears"
    element = "fire"
    fx_state = "flamespear"
    impact_fx_state = "flamespearhit"
    damage_multiplier = 1.4          // invented -- a tier above Icespears' 1.1
    mana_cost = 16                   // OG

// Three fireballs abreast like Icespears, each homing like Blazemore (user, 2026-09-25).
// OG use() fired three /proj/blaze, from the caster's left, front and right.
datum/skill/Blazemost
    parent_type = /datum/skill/SpellBolt
    skillName = "Blazemost"
    element = "fire"
    fx_state = "blaze"               // OG /proj/blaze -- Fireball's art
    impact_fx_state = "blazehit"
    bolt_lanes = 3
    bolt_homes = TRUE
    damage_multiplier = 1.9
    mana_cost = 10

// --- Four ways: one bolt each direction ---
// Cast, then a blizzard flies out N, E, S and W at once (user, 2026-09-25; OG use()
// spawns /proj/blizzard in the caster's dir, then turns 90 until it's back). Each is a
// plain bolt: it flies until a mob or wall stops it, rolling its own damage.
datum/skill/Blizzard
    parent_type = /datum/skill/SpellBolt
    skillName = "Blizzard"
    element = "ice"
    fx_state = "blizzard"            // OG: /proj/blizzard
    impact_fx_state = "icespearhit"
    bolt_four_ways = TRUE
    damage_multiplier = 1.3          // OG Int*3+6, ~1.5x Blaze's Int*2+4
    mana_cost = 10

// --- Piercing: fly through everyone in the line ---
// OG /proj/infernos and /proj/infermore have their own slower Step().
// Wind spells (user, 2026-09-25; the OG's element list also calls Infernos "Air"): a
// landed hit may blow the target back along the flight. Infernos rarely, one tile;
// Infermore more often, and it can keep blowing them further, a roll per tile;
// Infermost always. "air" has no row in the element matrix (GetElementalMultiplier(), CombatSystem.dm),
// so it hits every monster type for neutral damage.
datum/skill/Infernos
    parent_type = /datum/skill/SpellBolt
    skillName = "Infernos"
    element = "air"
    fx_state = "infernos"            // 4-frame gust, no directions
    impact_fx_state = "infernoshit"  // user-drawn, 2026-09-25
    bolt_pierces = TRUE
    bolt_range = 6                   // user: gone after 7 tiles (6 past the first)
    bolt_slowness = 2
    bolt_knockback_chance = 20       // invented
    bolt_knockback_max = 1
    damage_multiplier = 1.0
    mana_cost = 5

datum/skill/Infermore
    parent_type = /datum/skill/Infernos
    skillName = "Infermore"
    fx_state = "infermore"           // hits with Infernos' "infernoshit"
    bolt_range = 9                   // user: reaches 10 tiles (9 past the first)
    bolt_knockback_chance = 45       // invented
    bolt_knockback_again_chance = 50 // invented -- so 2 tiles ~1 in 2, 3 tiles ~1 in 4
    bolt_knockback_max = 3           // invented
    damage_multiplier = 1.5
    mana_cost = 8

// Three Infermores abreast, like Blazemost but no homing (user, 2026-09-25), and a
// landed hit always blows the target back. Extra tiles still roll as Infermore's do.
// Not in the OG.
datum/skill/Infermost
    parent_type = /datum/skill/Infermore
    skillName = "Infermost"
    bolt_lanes = 3
    bolt_knockback_chance = 100      // user: guaranteed
    damage_multiplier = 1.9          // invented -- Blazemost's per-bolt draft
    mana_cost = 12                   // invented

// A Blaze bolt that leaves a line of fire where it stops (user, 2026-09-25; OG
// /proj/firebane Collide() lays /burn/firebane turned 90 from the flight). It flies until
// a mob or wall stops it, like Blaze, and a landed hit does its damage there. Then
// "firebane" burns on 5 tiles across the flight -- the stopping tile plus 2 each side
// (flying north/south it spreads east-west, flying east/west it spreads north-south).
// Walls cut the line short. Standing in it burns (HazardFields.dm), as Explodet's does.
// A dodge lets the bolt fly on, so the fire lands wherever it finally stops.
#define FIREBANE_SPREAD 2  // tiles of fire each side of the stopping tile

datum/skill/Firebane
    parent_type = /datum/skill/SpellBolt
    skillName = "Firebane"
    element = "fire"
    fx_state = "blaze"               // user: flies as Blaze (the OG proj drew "blazemore")
    impact_fx_state = "blazehit"
    damage_multiplier = 1.7
    mana_cost = 7
    hazardFieldType = /obj/hazard_field/flame/firebane
    hazard_duration = 100            // user: ~10 seconds on the ground

    BoltFinish(obj/projectile/spell/P, turf/T)
        if(!T || !P.caster) return
        var/across = turn(P.travelDir, 90)
        SpawnHazardLine(T, across, FIREBANE_SPREAD, hazardFieldType, P.caster,
                        round(P.damage * hazard_power_multiplier), element, hazard_duration, across)

// --- Bursts: the bolt explodes where it stops ---
// Bang (user, 2026-09-25): a Blaze bolt that erupts on contact into a 3x3 of "bang" --
// one tile of art drawn on each of the 9 tiles -- and instant damage to every enemy in
// it. No fire is left behind. Touching a mob centres the 3x3 on that mob (dodging
// the bolt doesn't save them -- the blast is what hits); a wall centres it on the tile
// in front of the wall. The OG decompile read Bang as the 4 sides only; the user's
// version is the full square.
datum/skill/Bang
    parent_type = /datum/skill/SpellBolt
    skillName = "Bang"
    element = "fire"
    fx_state = "blaze"
    blast_fx_state = "bang"
    bolt_bursts = TRUE
    aoe_radius = 1
    aoe_square = TRUE                // the full 3x3
    blast_dodgeable = FALSE          // user: every enemy in it takes the damage
    blast_covers_walls = TRUE        // user: the full shape shows even against a wall
    damage_multiplier = 1.5
    mana_cost = 6

// Bang, but a bigger blast (user, 2026-09-25): rows of 3-5-5-5-3 -- a 5x5 with its
// corners cut off -- still "bang" on every tile. (The OG /proj/boom flew with
// Blazemore's art; the user's Boom is Bang's bolt.)
datum/skill/Boom
    parent_type = /datum/skill/Bang
    skillName = "Boom"
    aoe_radius = 2
    aoe_cut_corners = TRUE
    mana_cost = 12

// Upgraded Boom (user, 2026-09-25): flies as "explodet", blasts exactly like Boom (3-5-5-5-3
// of "bang", no dodge), then leaves "explodetflame" burning over that same shape for 10
// seconds. Standing in the fire burns (damage over time, HazardFields.dm); the blast
// itself is the only up-front hit.
datum/skill/Explodet
    parent_type = /datum/skill/Boom
    skillName = "Explodet"
    fx_state = "explodet"            // OG: /proj/explodet
    damage_multiplier = 2.2
    mana_cost = 16
    hazardFieldType = /obj/hazard_field/flame
    hazard_duration = 100            // user: 10 seconds

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

// Thordain with the "dark" art (user, 2026-09-25) -- same beam, damage and cost.
// Art only in the OG: no dark spell survives in the decompile. No unlock yet.
datum/skill/Thordain/DarkThordain
    skillName = "DarkThordain"
    fx_state = "darkthordain"         // -> "darkthordainns"/"darkthordainew"
    impact_fx_state = "darklightninghit"
    beam_origin_state = "darkthordain"

// Fires like Thordain (user, 2026-09-25): a 7-tile line grows out from the caster,
// hitting every enemy it reaches -- but in "firebane" art, and it stays about 7 seconds
// as burning ground. Standing in it burns (damage over time), the same fire Firebane
// leaves (HazardFields.dm). Walls cut it short.
datum/skill/Firevolt
    parent_type = /datum/skill/BeamSpell
    skillName = "Firevolt"
    element = "fire"
    fx_state = "firebane"
    impact_fx_state = "blazehit"
    beam_range = 6                   // 7 tiles in all
    beam_hold = 70                   // user: ~7 seconds
    beam_hazard_type = /obj/hazard_field/flame/firebane
    damage_multiplier = 1.6
    mana_cost = 10

// --- Around the caster ---
// A storm in Boom's 3-5-5-5-3 shape, centred on the tile the caster stood on when it
// went off (user, 2026-09-25). "snowstorm" plays on every tile for SNOWSTORM_DURATION,
// and the whole time it deals damage over time to every enemy standing in it -- no
// up-front hit. It stays where it was cast; the caster can walk out. Walls are left out.
#define SNOWSTORM_DURATION 100    // deciseconds -- user: 10 seconds
#define SNOWSTORM_TICK_SHARE 0.2  // each tick's damage vs. the cast's damage roll -- invented

datum/skill/Snowstorm
    parent_type = /datum/skill/AoESpell
    skillName = "Snowstorm"
    element = "ice"
    fx_state = "snowstorm"           // 4-frame, no directions
    aoe_on_caster = TRUE
    aoe_radius = 2
    aoe_square = TRUE
    aoe_cut_corners = TRUE           // Boom's shape
    damage_multiplier = 1.8
    mana_cost = 16

    ApplyBlast(mob/user, turf/center, damage, fxDir = 0)
        var/tickDamage = max(1, round(damage * SNOWSTORM_TICK_SHARE))
        for(var/turf/T in GetBlastArea(center))
            PlaceHazardField(T, /obj/hazard_field/snowstorm, user, tickDamage, element, SNOWSTORM_DURATION)

// =============================================================================
// HEALING SPELLS (Int gated) — heal_amount is flat, not stat-scaled (HealSpell, top)
// =============================================================================
// User, 2026-09-25: Heal small, Healmore bigger, Healmost a full heal; Healus is Healmore
// for the caster and party members in view, Healusmore is Healmost for them. Amounts are
// invented; MP costs are still drafts, not the OG's (Heal 6, Healmore 15, Healmost 40,
// Healus 20, Healusmore 60).
#define HEAL_AMOUNT 30      // invented
#define HEALMORE_AMOUNT 75  // invented

datum/skill/Heal
    parent_type = /datum/skill/HealSpell
    skillName = "Heal"
    fx_state = "heal"
    heal_amount = HEAL_AMOUNT
    mana_cost = 4

datum/skill/Healmore
    parent_type = /datum/skill/HealSpell
    skillName = "Healmore"
    fx_state = "healmore"
    heal_amount = HEALMORE_AMOUNT
    mana_cost = 8

// No dedicated "healus" art — reuses Healmore's.
datum/skill/Healus
    parent_type = /datum/skill/HealSpell
    skillName = "Healus"
    fx_state = "healmore"
    heal_amount = HEALMORE_AMOUNT
    heal_party = TRUE
    mana_cost = 10

// The OG's Healmost, made a full heal (user, 2026-09-25).
datum/skill/Healmost
    parent_type = /datum/skill/HealSpell
    skillName = "Healmost"
    fx_state = "healmost"
    heal_full = TRUE
    mana_cost = 12

// The OG's Healusmore: Healmost for the caster and party members in view. No dedicated
// "healusmore" art — reuses Healmost's.
datum/skill/Healusmore
    parent_type = /datum/skill/HealSpell
    skillName = "Healusmore"
    fx_state = "healmost"
    heal_full = TRUE
    heal_party = TRUE
    mana_cost = 15

// =============================================================================
// BUFF SPELLS — apply statusEffectType (StatusEffects.dm) to the ally faced, else self
// (AllyOrSelf())
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

        var/mob/buffTarget = AllyOrSelf(user, target)
        if(!user.PlayCastMeter(src)) return  // died or interrupted

        user.PlaySkillFX(src, buffTarget)  // the cast burst; the buff's own standing
                                           // indicator is activeFXState on the status
                                           // effect (StatusEffects.dm)
        if(burst_before_buff)
            sleep(SKILL_FX_DURATION)
            if(user.isDead) return
        // An ally who died during the cast gets nothing -- a buff on a fallen pet
        // would still be running when Revive brought it back.
        if(buffTarget && !buffTarget.isDead) buffTarget.ApplyStatusEffect(statusEffectType)

        user.canAct = TRUE

// User, from the OG, 2026-09-25: a slowish cast, then "upperon" flashes and goes, then
// "upper" stays on the buffed player for about a minute (BUFF_DURATION,
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

// A stronger Upper (user, 2026-09-25): same slow cast, same art, same minute -- it just
// adds more attack power (INCREASE_ATTACK_BONUS, StatusEffects.dm). No
// "increase" art exists, so it borrows Upper's.
datum/skill/Increase
    parent_type = /datum/skill/Upper
    skillName = "Increase"
    statusEffectType = /datum/status_effect/buff/increase
    mana_cost = 3

// Works like Upper (user, 2026-09-25): a slowish cast, "barrieron" flashes and goes,
// then "barrier" stays on the buffed player (BUFF_DURATION, StatusEffects.dm).
#define BARRIER_CAST_SLOWNESS 1.5  // cast meter vs. a normal spell -- invented, same as Upper

datum/skill/Barrier
    parent_type = /datum/skill/BuffSpell
    skillName = "Barrier"
    fx_state = "barrieron"
    burst_before_buff = TRUE
    cast_meter_slowness = BARRIER_CAST_SLOWNESS
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
#define SLEEPMORE_CHANCE 85   // % Sleepmore takes hold -- invented; user: higher than Sleep

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

// Flies like Stopspell, but a small chance to kill the target outright (user,
// 2026-09-25; OG /proj/defeat's Collide() dealt a flat 9999). Bosses (mob.isBoss) always
// resist. A fail shows "miss" and does nothing else. Like the other status bolts it
// can't be dodged -- the roll is the whole defense. Not in any class's unlock table
// yet (OG MP 20).
#define DEFEAT_CHANCE 10  // % Defeat kills -- invented

datum/skill/Defeat
    parent_type = /datum/skill/SpellBolt
    skillName = "Defeat"
    fx_state = "defeat"              // OG: /proj/defeat
    mana_cost = 20                   // OG

    BoltHit(obj/projectile/spell/P, turf/T, mob/M)
        var/mob/user = P.caster
        if(!user) return TRUE
        if(M.isBoss || !prob(DEFEAT_CHANCE))
            view(M) << output("[M] resists [skillName]!", "Info")
            ShowCombatNumber(M, "miss", "#ffffff")
            return TRUE
        view(M) << output("[M] is struck down by [skillName]!", "Info")
        M.TakeDirectDamage(M.HP, user, reducible = FALSE)  // user gets the kill; Barrier can't stop it
        return TRUE

// =============================================================================
// UTILITY SKILLS — own resource/effect shape, not a plain damage/heal spell
// =============================================================================

// Rest and Meditate: sit down for cast_time, then get restore_percent of max HP (Rest)
// or MP (Meditate) back. No MP cost, usable anywhere (peaceful areas included); rooted
// for a normal attack delay. Dying mid-sit restores nothing.
datum/skill/Recover
    parent_type = /datum/skill
    icon_state = "weapon"
    cast_time = 4

    var
        restore_percent = 30
        restores_mp = FALSE  // FALSE = HP (Rest), TRUE = MP (Meditate)
        start_message = null

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return

        user.canAct = FALSE
        user.ShowInfo(start_message)

        spawn(cast_time)
            if(!user || user.isDead) return
            if(restores_mp)
                var/amount = max(1, round(user.MaxMP * restore_percent / 100))
                user.MP = min(user.MaxMP, user.MP + amount)
                user.ShowFloatingMPBar()
                user.ShowInfo("You restore [amount] MP! (MP: [user.MP]/[user.MaxMP])")
            else
                user.ApplyHeal(user, max(1, round(user.MaxHP * restore_percent / 100)))

        spawn(user.GetAttackDelay(src, FALSE))
            if(!user || user.isDead) return
            user.canAct = TRUE

// Vitality-gated self-heal (works for Fighter/Soldier/Goof-off too).
datum/skill/Rest
    parent_type = /datum/skill/Recover
    skillName = "Rest"
    start_message = "You sit down to rest..."

// Spirit-gated MP restore — the mana-side equivalent of Rest.
datum/skill/Meditate
    parent_type = /datum/skill/Recover
    skillName = "Meditate"
    restores_mp = TRUE
    start_message = "You begin to meditate..."

// Teleports the caster back to the spawn point (GetPlayerSpawnTurf(), Area.dm).
datum/skill/Return
    parent_type = /datum/skill/GenericSpell
    skillName = "Return"
    mana_cost = 8

    OnUse(mob/user, mob/target = null)
        if(!user.canAct) return
        if(!PayToCast(user)) return
        if(!user.PlayCastMeter(src)) return  // died or interrupted

        user.TeleportTo(GetPlayerSpawnTurf())
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
        var/mob/M = FindFallen(user, target)
        if(!M)
            if(target && !IsFallen(target)) user.ShowInfo("[target.name] isn't in need of reviving.")
            else user.ShowInfo("[skillName] only works on a fallen ally or pet.")
            return

        if(!PayToCast(user)) return
        if(!user.PlayCastMeter(src)) return  // died or interrupted

        // A pet's corpse may have faded during the windup -- then there's nothing left.
        if(M && IsFallen(M))
            if(prob(revive_chance))
                Raise(user, M)
            else
                user.ShowInfo("[skillName] fails to revive [M.name].")
                M.ShowInfo("[user.name]'s [skillName] fails to revive you.")
                ShowCombatNumber(M, "miss", "#ffffff")

        user.canAct = TRUE

    // A dead player, or a fallen pet whose corpse hasn't faded yet (user, 2026-09-25).
    proc/IsFallen(mob/M)
        if(istype(M, /mob/player)) return M.isDead
        var/mob/enemy/E = M
        return istype(E) && E.IsRevivablePet()

    // The given target, else the first fallen mob on the tile faced -- the skill slots
    // never pick a corpse as the target themselves (UseSkillSlot() skips HP <= 0).
    proc/FindFallen(mob/user, mob/target)
        if(target) return IsFallen(target) ? target : null
        var/turf/T = get_step(user, user.dir)
        if(!T) return null
        for(var/mob/M in T)
            if(M != user && IsFallen(M)) return M
        return null

    proc/Raise(mob/user, mob/M)
        if(istype(M, /mob/player))
            M.ReviveInPlace(M.MaxHP * revive_hp_percent / 100)
            M.ShowInfo("You have been revived by [user.name]!")
            return
        var/mob/enemy/E = M
        E.RevivePet(revive_hp_percent)
        view(E) << output("[E.name] is revived by [user.name]!", "Info")
        if(E.owner && E.owner != user) E.owner.ShowInfo("[user.name] revived your pet [E.name]!")

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
        if(!P.CanBecomeSage()) return

        var/confirm = alert(P, "Are you sure you want to change your class to Sage? (You will keep all your items and gold, but you will be set back to level 1.)", "Classchange", "Yes", "No")
        if(confirm != "Yes") return

        if(!RunSageReclassFlow(P))
            return  // backed out at the icon step — nothing has changed, still the old class

        P.BecomeSage()
