// -----------------------------
// Hazard fields — runtime-spawned, self-expiring ground hazards
// -----------------------------
// The missing half of turf/hazard (Turfs.dm). That one is static terrain authored into
// the map (lava, swamp) and damages on STEP. This one is spawned by a spell at runtime,
// covers a blob of tiles, ticks on whoever is STANDING in it, and cleans itself up after
// a duration.
//
// Built as an /obj sitting on the turf rather than by swapping the turf's type, which
// matters more than it looks: turf replacement would have to snapshot and restore the
// original turf's type, icon, and every var on it, and the map is full of turfs whose
// identity is load-bearing (warp pairs with partner links, doors that toggle density,
// ceiling boundaries). An obj layered over the ground touches none of that and deletes
// cleanly.
//
// The first real user is Explodet's residual flame (SkillCatalog.dm). That mechanic is
// the OG behavior recalled first-hand: Explodet deals its impact damage and then leaves
// a circle of fire on the ground, and it's standing IN the fire — not the direct hit —
// that burns you. That's why datum/status_effect/burn (StatusEffects.dm) sat dormant
// with a finished formula and no trigger; this is the trigger.

// Above OBJ_LAYER so flame draws over items/decals on the same tile, below MOB_LAYER so
// it never covers the mob standing in it.
#define HAZARD_FIELD_LAYER 3.1

obj/hazard_field
    name = "flames"
    icon = 'spells.dmi'
    icon_state = "explodetflame"
    density = FALSE
    layer = HAZARD_FIELD_LAYER
    mouse_opacity = 0  // clicking the tile should reach what's under the flames

    var
        // Who created it. Used for kill credit and for the friendly-fire rule below;
        // null means an unowned field that burns everyone (a map-authored or
        // environmental one).
        mob/owner = null

        duration = 60       // deciseconds before it burns out
        tickInterval = 10   // deciseconds between passes over whoever's standing here

        // Handed to whatever the field applies. For a flame field this is the burn's D0
        // (see castburn()'s formula, StatusEffects.dm) and its element for the
        // elemental matrix.
        power = 0
        element = null

        // Status effect TYPES applied to anyone standing here. Re-applied every tick,
        // which for burn means the effect REFRESHES while you stand in it and then runs
        // out shortly after you step clear — the right shape for fire, and the reason
        // this field doesn't need to deal damage itself.
        list/applyEffects = null

        // Direct HP loss per tick, separate from applyEffects. Zero for flame (burn
        // does that damage); a future field that should hurt without a status effect
        // sets this instead.
        tickDamage = 0
        tickMessage = "You're caught in it!"
        tickColor = "red"

        expiresAt = 0

    // Same coop-mode / friendly-fire rule as every other damage path (CanHarm(),
    // CombatSystem.dm), judged as if the field's owner were hitting M -- which also
    // spares the owner. An unowned field (or one whose caster has since been deleted)
    // affects everyone.
    proc/AffectsMob(mob/M)
        if(!M || M.HP <= 0 || M.isDead) return FALSE
        if(M.isGhostform) return FALSE
        if(M.isAirborne) return FALSE  // mid-Jump, over the flames
        if(M.equipHazardImmune) return FALSE
        if(!owner) return TRUE
        return owner.CanHarm(M)

    // Deliberately NOT called from New() — PlaceHazardField() below assigns power/
    // duration/owner after the `new`, so a loop started in New() would already have
    // snapshotted the type's DEFAULT duration into expiresAt. The spawner calls this
    // last, once the field is fully configured.
    proc/Ignite()
        set waitfor = 0
        expiresAt = world.time + duration

        while(src && world.time < expiresAt)
            sleep(tickInterval)
            if(!src) return
            var/turf/T = loc
            if(!T) break

            for(var/mob/M in T)
                if(!AffectsMob(M)) continue

                if(applyEffects)
                    for(var/effectType in applyEffects)
                        if(effectType == /datum/status_effect/burn)
                            M.ApplyBurn(power, element)
                        else
                            M.ApplyStatusEffect(effectType)

                // Not TakeDamage() — you don't dodge the ground you're standing on. Still
                // run through the element matrix, like the spell that made it.
                if(tickDamage > 0)
                    var/dmg = max(1, round(tickDamage * GetElementalMultiplier(element, M.mobElement)))
                    M.TakeDirectDamage(dmg, owner, "<font color='[tickColor]'>[tickMessage] (-[dmg] HP)</font>")

        if(src) del src

    // Re-arms an existing field instead of stacking a second one on the same tile (see
    // PlaceHazardField()). Strictly a strengthen-or-extend: the stronger power wins and
    // the later expiry wins, so a weak or short overlapping cast can never downgrade or
    // cut short a field that's already burning.
    //
    // `owner` is deliberately left alone. Re-owning would flip which side the field
    // hurts, so two casters on opposing sides overlapping their fires could turn a
    // player's own flames against them — a worse outcome than the fire simply staying
    // credited to whoever lit it.
    proc/Refresh(newPower, newDuration)
        expiresAt = max(expiresAt, world.time + max(newDuration, 0))
        if(newPower > power) power = newPower

// Explodet's residual fire. Deals no damage of its own — it applies Burn, whose
// OG-confirmed formula (target's Intelligence, +18 per worn Amulet of Barrier, random
// mitigation between B/3 and B*2/3) does the work.
obj/hazard_field/flame
    name = "flames"
    icon_state = "explodetflame"
    applyEffects = list(/datum/status_effect/burn)

// Firebane's line of fire (SkillCatalog.dm). Same burn as Explodet's; OG /burn/firebane
// drew it at layer 6.75, over the mobs standing in it.
obj/hazard_field/flame/firebane
    name = "firebane"
    icon_state = "firebane"
    layer = 6.75

// Snowstorm's storm (SkillCatalog.dm; user, 2026-09-25). No status effect -- it hurts
// directly, every tick, whoever stands in it. Its power is the per-tick damage.
obj/hazard_field/snowstorm
    name = "snowstorm"
    icon_state = "snowstorm"
    tickMessage = "The snowstorm bites!"
    tickColor = "#80c0ff"

    Ignite()
        tickDamage = power
        ..()

    Refresh(newPower, newDuration)
        ..()
        tickDamage = power

// -----------------------------
// Blob spawning
// -----------------------------
// Lays a field over a diamond area (GetDiamondTurfs(), CombatSystem.dm) -- now only the
// Test_ flame debug verb; spells lay theirs in their own shapes via PlaceHazardField(). It
// already skips tiles a spell can't occupy — so flame never appears inside a wall or a closed
// door. A tile that already holds a field of this type gets that one refreshed rather
// than a second one stacked on it.
proc/SpawnHazardBlob(turf/center, fieldType, radius = 1, mob/owner = null, power = 0, element = null, duration = 60)
    if(!center || !fieldType) return 0

    var/placed = 0
    for(var/turf/T in GetDiamondTurfs(center, radius))
        if(PlaceHazardField(T, fieldType, owner, power, element, duration)) placed++
    return placed

// Lays a field in a straight line through center: center itself plus up to `reach` tiles
// each way along lineDir (and its opposite). Each arm stops at the first tile a spell
// can't occupy, so fire never spreads through or past a wall. fieldDir sets the art's dir.
proc/SpawnHazardLine(turf/center, lineDir, reach, fieldType, mob/owner = null, power = 0, element = null, duration = 60, fieldDir = SOUTH)
    if(!center || !fieldType || IsTurfBlocked(center)) return 0

    var/placed = PlaceHazardField(center, fieldType, owner, power, element, duration, fieldDir) ? 1 : 0
    for(var/armDir in list(lineDir, turn(lineDir, 180)))
        var/turf/T = center
        for(var/i = 1 to reach)
            T = get_step(T, armDir)
            if(IsTurfBlocked(T)) break
            if(PlaceHazardField(T, fieldType, owner, power, element, duration, fieldDir)) placed++
    return placed

// One tile of a field. A tile that already holds a field of this type gets that one
// refreshed rather than a second one stacked on it. Returns the NEW field, or null.
proc/PlaceHazardField(turf/T, fieldType, mob/owner, power, element, duration, fieldDir = SOUTH)
    var/obj/hazard_field/existing = locate(fieldType) in T
    if(existing)
        existing.Refresh(power, duration)
        return null

    var/obj/hazard_field/F = new fieldType(T)
    F.owner = owner
    F.power = power
    F.element = element
    F.duration = duration
    F.dir = fieldDir
    F.Ignite()
    return F
