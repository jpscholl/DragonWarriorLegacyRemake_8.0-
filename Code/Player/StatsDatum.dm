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
#define MP_PER_SPIRIT 2   // CONFIRMED 2026-08-10: live OG testing (Hero1) showed +1
                          // Spirit = +2 MaxMP exactly, matching this coefficient. No
                          // longer a placeholder guess. See ClassReference.md's Stat
                          // effects section.
#define MP_PER_LEVEL 2

// Recalculates MaxHP/MaxMP from current Vitality/Intelligence/Spirit/Level. Called
// whenever a stat point is spent (Code/Player/ClickableStats.dm) or a level is gained
// (Code/Combat/CombatSystem.dm's LevelCheck()) — not a one-time creation value.
// Tops up current HP/MP by however much the max just grew, so gaining a max doesn't
// leave the bar looking emptier than before. hasMana (Code/Player/PlayerTemplate.dm)
// keeps 0-MP classes like Soldier at 0 regardless of Intelligence/Spirit.
mob/proc/RecalculateVitals()
    var/oldMaxHP = MaxHP
    var/oldMaxMP = MaxMP

    // HPfactor/MPfactor (PlayerTemplate.dm) apply to the whole total, not just the
    // stat-derived part — a class multiplier on the base+level portion too is what
    // makes a Soldier's early HP already feel tankier, not just its per-point scaling.
    MaxHP = round((BASE_MAX_HP + (Vitality * HP_PER_VITALITY) + (Level * HP_PER_LEVEL)) * HPfactor)
    HP += max(0, MaxHP - oldMaxHP)

    if(hasMana)
        MaxMP = round((BASE_MAX_MP + (Intelligence * MP_PER_INTELLIGENCE) + (Spirit * MP_PER_SPIRIT) + (Level * MP_PER_LEVEL)) * MPfactor)
        MP += max(0, MaxMP - oldMaxMP)
    else
        MaxMP = 0
        MP = 0
