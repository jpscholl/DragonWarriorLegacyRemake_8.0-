// -----------------------------
// Vitals (MaxHP/MaxMP derived from stats) — placeholder coefficients throughout except
// MP_PER_SPIRIT, see Markdowns/CodeNotes.md.
// -----------------------------
#define BASE_MAX_HP 30
#define HP_PER_VITALITY 5
#define HP_PER_LEVEL 3
#define BASE_MAX_MP 10
#define MP_PER_INTELLIGENCE 4
#define MP_PER_SPIRIT 2
#define MP_PER_LEVEL 2

// Equipment-granted maxima (obj/item/amulet, Inventory.dm) — added to the computed
// totals below rather than baked into the formula inputs, so unequipping is a clean
// subtraction and a save taken while equipped can't make the bonus permanent.
mob/var/equipMaxHP = 0
mob/var/equipMaxMP = 0

// Called whenever a stat point is spent (ClickableStats.dm) or a level is gained
// (LevelCheck(), CombatSystem.dm) — not a one-time creation value. Tops up current
// HP/MP by however much the max just grew, so gaining a max doesn't leave the bar
// looking emptier than before.
mob/proc/RecalculateVitals()
    var/oldMaxHP = MaxHP
    var/oldMaxMP = MaxMP

    // HPfactor/MPfactor apply to the whole total, not just the stat-derived part — a
    // class multiplier on the base+level portion too is what makes a Soldier's early
    // HP already feel tankier, not just its per-point scaling. GetEffective*()
    // includes equipment bonuses, so a Vitality amulet raises MaxHP like real Vitality.
    MaxHP = round((BASE_MAX_HP + (GetEffectiveVitality() * HP_PER_VITALITY) + (Level * HP_PER_LEVEL)) * HPfactor) + equipMaxHP
    HP += max(0, MaxHP - oldMaxHP)

    if(hasMana)
        MaxMP = round((BASE_MAX_MP + (GetEffectiveIntelligence() * MP_PER_INTELLIGENCE) + (GetEffectiveSpirit() * MP_PER_SPIRIT) + (Level * MP_PER_LEVEL)) * MPfactor) + equipMaxMP
        MP += max(0, MaxMP - oldMaxMP)
    else
        MaxMP = 0
        MP = 0

// -----------------------------
// Effective stats — base stat + equipment bonus. Every combat formula reads these
// rather than the raw stat, so an amulet contributes exactly like real points would
// without ever being written into the stat itself. Floored at 1: a negative-Vitality
// amulet (Wizard's Amulet) must never drive a stat to zero and start producing zero or
// negative HP.
// -----------------------------
mob/proc
    GetEffectiveStrength()
        return max(1, Strength + equipStrength)
    GetEffectiveAgility()
        return max(1, Agility + equipAgility)
    GetEffectiveVitality()
        return max(1, Vitality + equipVitality)
    GetEffectiveIntelligence()
        return max(1, Intelligence + equipIntelligence)
    GetEffectiveSpirit()
        return max(1, Spirit + equipSpirit)

// -----------------------------
// Passive HP/MP regeneration — see Markdowns/CodeNotes.md for OG confirmation. Stat
// pairing (Vitality->HP, Intelligence->MP) is confirmed; coefficients are placeholder.
// -----------------------------
#define REGEN_TICK_INTERVAL 50   // deciseconds between regeneration ticks (5 seconds)
#define HP_REGEN_BASE 1
#define HP_REGEN_PER_VITALITY 0.5
#define MP_REGEN_BASE 1
#define MP_REGEN_PER_INTELLIGENCE 0.5

mob/proc
    GetHPRegen()
        return max(1, round(HP_REGEN_BASE + Vitality * HP_REGEN_PER_VITALITY))

    GetMPRegen()
        return max(1, round(MP_REGEN_BASE + Intelligence * MP_REGEN_PER_INTELLIGENCE))

    // Runs for the life of the mob, started from mob/player/New(). Does nothing while
    // dead — a corpse shouldn't heal its way out of the respawn wait.
    RegenLoop()
        set waitfor = 0
        while(src)
            sleep(REGEN_TICK_INTERVAL)
            if(isDead) continue
            if(HP <= 0) continue

            // Passive regen alone shouldn't count as "activity" — only refresh a
            // bar's numbers if it's already visible from a real trigger
            // (ShowFloatingHPBar()/ShowFloatingMPBar(), HUD.dm); never resurrect a
            // hidden one just because a regen tick landed.
            if(HP < MaxHP)
                HP = min(MaxHP, HP + GetHPRegen())
                if(floatingHPBarImage) UpdateFloatingHPBar()
            if(hasMana && MP < MaxMP)
                MP = min(MaxMP, MP + GetMPRegen())
                if(floatingMPBarImage) UpdateFloatingMPBar()
