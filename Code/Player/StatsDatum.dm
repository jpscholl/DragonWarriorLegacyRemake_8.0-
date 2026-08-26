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

// -----------------------------
// Passive HP/MP regeneration
// -----------------------------
// CONFIRMED the OG had this: HPregen/MPregen plus cur_HPregen/cur_MPregen countdown
// timers are all real vars in the extracted string table. The remake had no passive
// regeneration at all — the only way to recover was sleeping in a bed (Turfs.dm) or
// spending a Rest/Meditate cast, which made any fight away from town a one-way trip.
//
// The OG's help file states the governing stats plainly: "Vitality: increases max HP,
// HP regeneration rate"; "Intelligence: increases max MP, MP regeneration rate". So the
// stat pairing here is confirmed even though the coefficients aren't — those are
// PLACEHOLDER, set so a fresh level-1 character (Vitality 1) ticks 1 HP roughly every
// 5 seconds and a heavy investment is noticeably but not dramatically faster.
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

    // Runs for the life of the mob, started from mob/player/New() (PlayerTemplate.dm).
    // Deliberately does nothing while dead — a corpse shouldn't heal its way out of the
    // respawn wait — and stops entirely if the mob is gone.
    RegenLoop()
        set waitfor = 0
        while(src)
            sleep(REGEN_TICK_INTERVAL)
            if(isDead) continue
            if(HP <= 0) continue

            if(HP < MaxHP)
                HP = min(MaxHP, HP + GetHPRegen())
            if(hasMana && MP < MaxMP)
                MP = min(MaxMP, MP + GetMPRegen())
