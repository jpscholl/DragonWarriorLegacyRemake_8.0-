// -----------------------------
// Skill FX — resolving a skill's spell/weapon effect art out of spells.dmi
// -----------------------------
// Two DIFFERENT art layers exist per skill and they are easy to confuse:
//
//   1. datum/skill.icon_state — a state on the USER'S OWN portrait .dmi (the held
//      weapon / swing pose). Resolved by mob/ResolveAnimState() (CombatSystem.dm) and
//      drawn by PlayAttackAnimation(). Almost every skill leaves this at "weapon".
//   2. datum/skill.fx_state — a state in spells.dmi: the spell burst, the whip, the
//      swung axe, the lightning bolt. This file resolves and draws that one.
//
// spells.dmi already ships real art for most of SkillCatalog.dm's roster, which went
// unused for a long time because every skill inherited the generic "weapon" state.
// Adding art later needs NO code change: name the new icon_state after the skill's
// fx_state and ResolveSkillFXState() picks it up on the next compile. A skill whose
// fx_state names a state that doesn't exist yet silently draws nothing rather than
// erroring, so fx_state can be filled in ahead of the art.

// SKILL_FX_FILE / SKILL_FX_DURATION live in the .dme's shared define block, not here —
// CombatSystem.dm (PlayHealCastSequence()) needs them and compiles before this file
// alphabetically, and macros are textual so they have to be defined first. Same reason
// the cast-meter and damage-number constants already sit up there.

// Some FX art ships as VARIANTS of one base name rather than a single state, in two
// patterns that already exist in spells.dmi:
//   - directional: "thordain" + "thordainns"/"thordainew" (vertical/horizontal beams)
//   - handed:      "leftclaw"/"rightclaw", "leftfireclaw"/"rightfireclaw" (no bare
//                  "claw" state exists at all)
// Directional wins over handed, which wins over the bare name — a base that has a
// directional pair drawn for it wants that pair used, not its own fallback frame.
// Returns null when nothing matches, which callers treat as "no art yet, draw nothing".
proc/ResolveSkillFXState(baseName, dir = 0, alternate = FALSE)
    if(!baseName) return null

    var/list/states = GetCachedIconStates(SKILL_FX_FILE)
    if(!states.len) return baseName  // unreadable file — let the caller try anyway

    if(dir)
        var/suffix = (dir & (NORTH|SOUTH)) ? "ns" : "ew"
        if("[baseName][suffix]" in states) return "[baseName][suffix]"

    var/rightName = "right[baseName]"
    var/leftName = "left[baseName]"
    var/hasRight = (rightName in states)
    var/hasLeft = (leftName in states)
    if(hasRight && hasLeft) return alternate ? leftName : rightName
    if(hasRight) return rightName
    if(hasLeft) return leftName

    if(baseName in states) return baseName
    return null

// Flashes one spells.dmi state over any atom — a mob, a turf, an obj.
//
// FREE-STANDING, not a proc on /mob or /obj, for the same reason FlashTurfEffect()
// (Projectiles.dm) is: the cleanup sleeps, and if it ran inside a proc owned by an atom
// that gets deleted meanwhile (a dying monster, a spent projectile) the pending block
// dies with its owner and the overlay is stranded on screen forever. A global proc has
// no src to delete.
proc/FlashSkillFX(atom/A, stateName, duration = SKILL_FX_DURATION, layerOffset = 0.1)
    set waitfor = 0
    if(!A || !stateName) return

    var/image/fx = image(SKILL_FX_FILE, A, stateName)
    // A turf's own layer is far below a mob's, so "just above the turf" would bury an
    // explosion underneath whoever is standing in it. Turf-hosted effects get a fixed
    // high layer instead, same value and same reason as FlashTurfEffect()
    // (Projectiles.dm). Mob- and obj-hosted effects sit just above their host.
    fx.layer = isturf(A) ? 6 : (A.layer + layerOffset)
    A.overlays += fx
    sleep(duration)
    // A may have been deleted during the sleep — the ref goes null rather than dangling.
    if(A) A.overlays -= fx

mob/proc
    // The normal entry point: draw S's own FX at `where`. Passes src.dir and src's
    // swing-alternation flag through so directional/handed variants resolve against the
    // attacker, not the target.
    PlaySkillFX(datum/skill/S, atom/where, duration = SKILL_FX_DURATION)
        if(!S || !where) return
        var/state = ResolveSkillFXState(S.fx_state, dir, animAlternate)
        if(state) FlashSkillFX(where, state, duration)

    // The burst drawn where a hit LANDS, as opposed to the swing/cast art above.
    // Several skills ship both halves ("blaze"/"blazehit", "lightning"/"lightninghit",
    // "icespear"/"icespearhit", "lightsword"/"lightswordblast"); a skill with no
    // separate impact state falls back to its main fx_state so something still shows.
    PlaySkillImpactFX(datum/skill/S, atom/where, duration = SKILL_FX_DURATION)
        if(!S || !where) return
        var/state = ResolveSkillFXState(S.impact_fx_state, dir, animAlternate)
        if(!state) state = ResolveSkillFXState(S.fx_state, dir, animAlternate)
        if(state) FlashSkillFX(where, state, duration)
