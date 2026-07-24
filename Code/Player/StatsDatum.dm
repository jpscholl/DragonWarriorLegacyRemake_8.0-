// -----------------------------
// Vitals (MaxHP/MaxMP derived from stats)
// -----------------------------
// Placeholder coefficients — same "tune later once there's something to playtest
// against" status as the damage formula in Code/Combat/CombatSystem.dm. Not verified
// against the original game (not recoverable from play, see ClassReference.md).
#define BASE_MAX_HP 30
#define HP_PER_VITALITY 5
#define HP_PER_LEVEL 3
#define BASE_MAX_MP 10
#define MP_PER_INTELLIGENCE 4
#define MP_PER_LEVEL 2

// Recalculates MaxHP/MaxMP from current Vitality/Intelligence/Level. Called whenever
// a stat point is spent (Code/Player/ClickableStats.dm) or a level is gained
// (Code/Combat/CombatSystem.dm's LevelCheck()) — not a one-time creation value.
// Tops up current HP/MP by however much the max just grew, so gaining a max doesn't
// leave the bar looking emptier than before. hasMana (Code/Player/PlayerTemplate.dm)
// keeps 0-MP classes like Soldier at 0 regardless of Intelligence.
mob/proc/RecalculateVitals()
    var/oldMaxHP = MaxHP
    var/oldMaxMP = MaxMP

    MaxHP = BASE_MAX_HP + (Vitality * HP_PER_VITALITY) + (Level * HP_PER_LEVEL)
    HP += max(0, MaxHP - oldMaxHP)

    if(hasMana)
        MaxMP = BASE_MAX_MP + (Intelligence * MP_PER_INTELLIGENCE) + (Level * MP_PER_LEVEL)
        MP += max(0, MaxMP - oldMaxMP)
    else
        MaxMP = 0
        MP = 0
