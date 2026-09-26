// -----------------------------
// Damage formula — the single place base damage is built and mitigated
// -----------------------------
// The original's real melee/spell damage routine is NOT recovered and probably won't be
// from the decompiled source we have: hit(), cast(), and every monster attack proc
// checked (Attack/Punch/Dash/Quakejump/Fireclaw/Thornwhip/Chainsickle) each fall into an
// unresolved decompiler opcode within ~15 instructions, before any STR/INT math appears.
// That's a systemic blind spot in that tool, not one unlucky proc — see
// Markdowns/OGCombatFormulas.md §11.
//
// So every coefficient in this file is INVENTED and meant to be tuned. What it buys is
// that they're invented in ONE place: before this, attack power was inlined in
// ResolvePhysicalHit(), spell power was inlined in GenericSpell's OnUse(), and
// mitigation was inlined in TakeDamage(), so a balance pass meant editing three files
// and hoping you'd found every site.
//
// The full pipeline, in order:
//   1. GetPhysicalPower() / GetSpellPower()  — stat + buff + equipment, this file
//   2. ComputePhysicalDamage() / ComputeSpellDamage() — × the skill's multiplier,
//      then a variance roll, this file
//   3. GetElementalMultiplier()  — real OG matrix, CombatSystem.dm (do NOT invent here)
//   4. RollCrit() / CRIT_DAMAGE_PERCENT  — CombatSystem.dm
//   5. MitigateDamage()  — defense subtraction, defend stance, damage floor, this file
//
// Only step 3 is real OG data. Steps 1, 2 and 5 are ours.

// Straight multipliers on the governing stat. At 1.0 these reproduce exactly what the
// inlined versions did, so introducing this file changed no damage number on its own.
#define PHYS_STRENGTH_SCALE 1.0
#define SPELL_INTELLIGENCE_SCALE 1.0

// Random spread applied to every computed hit, as a percentage either side. This one IS
// a real behavior change and not just a refactor: damage used to be perfectly
// deterministic, so the same character hitting the same monster produced an identical
// number forever. Dragon Warrior's own damage always had a spread. Set to 0 to go back
// to fixed numbers.
#define DAMAGE_VARIANCE_PERCENT 12

// Flat additive attack power from gear, kept separate from the equipStrength/
// equipIntelligence amulet bonuses (Inventory.dm) because those are stat points and
// feed MaxHP/regen/caps as well, while these are meant to be weapon damage and nothing
// else. Nothing sets them yet — there is no weapon-equipment system, only amulets — so
// they're a zero term today and the hook for one later.
mob
    var
        equipWeaponPower = 0
        equipSpellPower = 0

// Symmetric spread: rand(-spread, spread). Rounds the spread to whole HP and skips the
// roll entirely for small numbers, where a percentage would round to 0 anyway.
proc/RollDamageVariance(amount, percent = DAMAGE_VARIANCE_PERCENT)
    if(amount <= 0 || percent <= 0) return amount
    var/spread = round(amount * percent / 100)
    if(spread < 1) return amount
    return amount + rand(-spread, spread)

mob/proc
    // attackBonus is Upper/Increase (StatusEffects.dm) -- added for damage purposes only,
    // never written back to the stat.
    GetPhysicalPower()
        return GetEffectiveStrength() + attackBonus + equipWeaponPower

    GetSpellPower()
        return GetEffectiveIntelligence() + equipSpellPower

    // mult is the skill's damage_multiplier. Floored at 1 so a heavy variance roll on a
    // tiny hit can never produce 0 or a heal.
    ComputePhysicalDamage(mult = 1)
        var/base = round(GetPhysicalPower() * PHYS_STRENGTH_SCALE * mult)
        return max(1, RollDamageVariance(base))

    ComputeSpellDamage(mult = 1)
        var/base = round(GetSpellPower() * SPELL_INTELLIGENCE_SCALE * mult)
        return max(1, RollDamageVariance(base))

// Defense mitigation, called from TakeDamage() (CombatSystem.dm) on the TARGET.
//
// Flat subtraction rather than percentage reduction — that's a deliberate choice, not a
// placeholder shape: it lets a heavily-invested tank shrug off weak hits entirely
// without needing a separate armor stat. Defense comes off before the defend-stance
// percentage, and the result is floored, so a well-defended mob still can't take a true
// zero and become unkillable.
#define MIN_DAMAGE 1
#define MAX_DAMAGE_REDUCTION_PERCENT 90  // cap on damageReductionPercent (Barrier), however it stacks

mob/proc/MitigateDamage(damage, isMagic = FALSE)
    var/defense = isMagic ? GetMagicDefense() : GetDefense()
    damage = max(MIN_DAMAGE, damage - defense)

    if(isDefending)
        damage = round(damage * (100 - DEFEND_DAMAGE_REDUCTION_PERCENT) / 100)

    return ApplyDamageReduction(damage)

// Barrier (StatusEffects.dm): a flat percent cut to all damage taken -- every hit,
// physical or magic (MitigateDamage() above), and damage over time (TakeDirectDamage(),
// CombatSystem.dm).
mob/proc/ApplyDamageReduction(damage)
    if(damageReductionPercent > 0)
        damage = round(damage * (100 - min(MAX_DAMAGE_REDUCTION_PERCENT, damageReductionPercent)) / 100)
    return max(MIN_DAMAGE, damage)
