// -----------------------------
// MOB COMBAT PROCS
// -----------------------------
// Shared by players AND enemies — every proc here is a plain mob/proc (or a free-
// standing proc for the two-argument helpers), not split by type, so the same code
// path handles "player attacks enemy" and "enemy attacks player" identically.
//
// THE ATTACK PIPELINE, start to finish:
//   1. Something decides to attack — a player pressing a numpad skill key
//      (UseSkillSlot(), PlayerTemplate.dm) or an enemy's AILoop() (EnemyNPCs.dm) once
//      adjacent to its target.
//   2. PlayAttackAnimation() plays the flick/sound/weapon-or-spell overlay — purely
//      visual/audio, does no damage itself.
//   3. PerformMeleeHit() (melee) or ApplySpellDamage() (spells) finds who's actually
//      getting hit and calls TakeDamage() on them.
//   4. TakeDamage() is where the actual outcome happens: RollDodge() first (a miss
//      just plays a sound and stops there), then damage is applied, then Die() +
//      CleanUpDead() if that brought HP to 0.
//   5. Die() credits the ATTACKER's Exp/LevelCheck(), then branches: a player goes
//      into the isDead/respawn-via-Interact() flow, an enemy just gets flagged for
//      CleanUpDead() to delete a few seconds later.
//
// GetAttackDelay()/IsCardinallyAdjacent()/InBattleArea() are standalone helpers the
// pipeline above and EnemyNPCs.dm both lean on — attack speed, "am I actually next to
// my target" (not just Chebyshev-close), and "is combat even allowed here."

// Placeholder death penalty percentages — Gold loss matches "lose half gold" already
// documented from the original design notes; EXP loss is a new addition with no prior
// number, tunable like everything else here.
#define DEATH_EXP_LOSS_PERCENT 25
#define DEATH_GOLD_LOSS_PERCENT 50

// How long a dead player must wait before Interact() (Code/Player/Commands/PlayerVerbs.dm)
// will respawn them.
#define RESPAWN_DELAY 100  // world.time units (10 real seconds at the default tick rate)

mob/var/isDead = FALSE
mob/var/deathTime = 0

// Dodge chance is new — no such mechanic existed before, so this is a placeholder
// formula, not OG-derived. Agility-based, capped so it's never a sure thing even at
// high Agility. Tune by feel.
#define DODGE_BASE_PERCENT 0
#define DODGE_AGILITY_SCALE 1  // % dodge chance per point of Agility
#define DODGE_MAX_PERCENT 30

mob/proc
    // Returns TRUE if this mob (the one about to take a hit) dodges it.
    RollDodge()
        var/dodgeChance = min(DODGE_MAX_PERCENT, DODGE_BASE_PERCENT + Agility * DODGE_AGILITY_SCALE)
        return prob(dodgeChance)

mob/proc
    // Apply damage to this mob
    TakeDamage(damage, mob/attacker)
        if(HP <= 0) return

        // "src" here is a /mob/enemy check because enemies and players use different
        // sound files for the same events (attack/hit/dodge) — see PlayAttackAnimation()
        // below for the attack.wav/enemyattack.wav split.
        var/isEnemy = istype(src, /mob/enemy)

        if(RollDodge())
            // view(src), not bare view() — bare view() centers on usr, which is
            // unreliable (often stale/unset) outside of code paths triggered directly
            // by a verb. TakeDamage() also runs from background procs like an enemy's
            // AILoop() calling PerformMeleeHit(), where usr isn't the mob taking the
            // hit — that silently broke this exact sound for player-vs-enemy combat.
            view(src) << sound(isEnemy ? 'enemydodge.wav' : 'dodge.wav', channel = SFX_CHANNEL, volume = baseVolume)
            view(src) << output("[src] dodges the attack!", "Info")
            return

        flick("hit", src)
        // channel = SFX_CHANNEL (defined in the .dme, see its comment), not 1 —
        // channel 1 is area background music (PlayAreaMusic(), Area.dm), and this
        // used to interrupt/kill it every hit.
        view(src) << sound(isEnemy ? 'enemyhit.wav' : 'hit.wav', channel = SFX_CHANNEL, volume = baseVolume)  // see usr note above

        HP -= damage
        view(src) << output("[src] takes [damage] damage! (HP: [max(HP,0)])", "Info")

        if(HP <= 0)
            Die(attacker)
            CleanUpDead()

mob/proc
    // Remove this mob asynchronously — never applies to players, who go through the
    // isDead/respawn flow in Die() instead of being deleted.
    CleanUpDead()
        if(istype(src, /mob/player)) return
        spawn(100)  // lets the corpse linger in place (EnemyNPCs.dm's AILoop() already
                     // stops acting entirely on death) before it disappears
            del src

mob/proc
    // Handle death: credit the attacker (not the mob that died), then branch on
    // whether this was a player or an enemy.
    Die(mob/attacker)
        view(src) << output("[src] has been defeated!", "Info")

        if(attacker)
            attacker.Exp += 10
            attacker.LevelCheck()

        if(istype(src, /mob/player))
            // Player death: no auto-respawn, no deletion — wait for Interact() once
            // RESPAWN_DELAY has passed. Lose a percentage of Exp/Gold as a penalty.
            isDead = TRUE
            deathTime = world.time
            Exp = max(0, Exp - round(Exp * DEATH_EXP_LOSS_PERCENT / 100))
            Gold = max(0, Gold - round(Gold * DEATH_GOLD_LOSS_PERCENT / 100))
            density = 0
            icon_state = "sleep"
            // Locks movement via mob/proc/Step()'s existing canAct gate
            // (SmoothMovement.dm) — same mechanism already used to root a player
            // mid-attack. Reset on respawn, see Interact() in PlayerVerbs.dm.
            canAct = FALSE
            src << output("You have died. Press Interact in [RESPAWN_DELAY / 10] seconds to respawn.", "Info")
        else
            // Enemy death: CleanUpDead() (called from TakeDamage right after this)
            // handles the actual deletion.
            density = 0
            icon_state = "sleep"

mob/proc
    // Level up check
    LevelCheck()
        if(src.Exp >= src.Nexp)
            src.Exp = 0
            src.Nexp += 10
            src.Level += 1
            src.StatPoints += 5
            src.RecalculateVitals()  // Code/Player/StatsDatum.dm — Level affects MaxHP/MaxMP too
            src << output("You are now Level [src.Level]", "Info")
            src << sound('levelup.wav', channel = 2, volume = baseVolume)

mob/proc
    // Melee hit detection
    PerformMeleeHit(datum/skill/S)
        var/turf/T = get_step(src, dir)
        if(!T) return

        for(var/mob/M in T.contents)
            if(M == src) continue
            if(M.HP <= 0) continue

            var/damage = Strength
            M.TakeDamage(damage, src)

mob/proc
    // Spell damage helper
    ApplySpellDamage(mob/target, damage, element)
        if(!target) return
        target.TakeDamage(damage, src)
        // Can later add resistances, AoE, elemental effects

#define MELEE_ATK_BASE_DELAY 12
#define MELEE_ATK_MIN_DELAY 4
#define SPELL_ATK_BASE_DELAY 14
#define SPELL_ATK_MIN_DELAY 6
// Agility's magic-speed bonus is (Agility * Intelligence / this) — scales WITH
// Intelligence rather than being a flat add, so Agility barely helps a low-INT
// character's cast speed but meaningfully helps a high-INT one. Tune by feel.
#define SPELL_AGI_SYNERGY_DIVISOR 40

mob/proc
    // Stat-based delay for skill usage. Deliberately NOT gated by class or an
    // isSpellcaster flag — physical vs. magic speed falls out purely from how a player
    // allocates stat points (ClickableStats.dm), so e.g. a Hero/Pilgrim can freely lean
    // physical, magic, or a hybrid of both through their own stat choices.
    GetAttackDelay(datum/skill/S)
        if(S.isMelee)
            // Geometric mean of Agility and whichever of Vitality/Intelligence is
            // higher: needs Agility PLUS a real secondary investment to get fast, but
            // deliberately doesn't force that secondary investment to be Vitality
            // specifically — a Wizard who leans Intelligence instead of Vitality still
            // has a legitimate path to a competent physical attack (Agility+Intelligence),
            // same as a Fighter's Agility+Vitality path. Neither stat alone is enough
            // (sqrt(A*x) gets dragged down hard by whichever side is low), but which
            // *second* stat gets you there is the player's choice, not a fixed pairing.
            var/meleeSpeedStat = sqrt(Agility * max(Vitality, Intelligence))
            return max(MELEE_ATK_MIN_DELAY, MELEE_ATK_BASE_DELAY - meleeSpeedStat)
        else if(S.isSpell)
            // Intelligence alone already gets a caster reasonably fast on its own;
            // Agility adds a small standalone bonus that only really grows once paired
            // with real Intelligence (see SPELL_AGI_SYNERGY_DIVISOR above).
            var/spellSpeedStat = Intelligence + (Agility * Intelligence / SPELL_AGI_SYNERGY_DIVISOR)
            return max(SPELL_ATK_MIN_DELAY, SPELL_ATK_BASE_DELAY - spellSpeedStat)
        else
            return 10

// get_dist()/step_to() use Chebyshev (king-move) distance, which treats a
// diagonally-adjacent tile the same as a cardinally-adjacent one — but this game is
// 4-directional only (no diagonal movement, Main.dm's mob/Move() override), so combat
// adjacency needs its own check: true only when exactly one axis differs, not both.
// Used by EnemyNPCs.dm's AILoop() so enemies can't attack (or face) diagonally.
proc/IsCardinallyAdjacent(atom/A, atom/B, range=1)
    var/dx = abs(A.x - B.x)
    var/dy = abs(A.y - B.y)
    return (dx <= range && dy == 0) || (dx == 0 && dy <= range)

mob/proc
    // Check if the mob is in a battle-enabled area — checks the real per-area
    // battleModeOn var (Code/World/Area.dm), set via GMbattlemode
    // (Code/Admin/Commands/GMCommands.dm).
    InBattleArea()
        var/turf/T = src.loc
        var/area/A = T ? T.loc : null
        return A && A.battleModeOn

mob/proc
    // Play animations for skills
    PlayAttackAnimation(mob/user, datum/skill/S, mob/target = null)
        if(S.isMelee)
            flick("attack", user)
            // view(user), not "user <<" — the latter only reaches the attacker's own
            // client, so it silently never played at all for enemies (no client to
            // reach). This broadcasts to everyone nearby who can see the attack,
            // attacker included, same pattern TakeDamage() already uses for hit.wav.
            view(user) << sound(istype(user, /mob/enemy) ? 'enemyattack.wav' : 'attack.wav', channel = SFX_CHANNEL, volume = 60)
            if(target)
                // Layered directly on the mob actually being hit, not the turf in
                // front of the attacker. No pixel_y set here (unlike the turf case
                // below) — overlays inherit their parent atom's own pixel_y
                // automatically, so target already renders shifted correctly; setting
                // it again here would double-apply the offset instead of fixing it.
                // layer is nudged just above the target's own so it draws on top.
                var/image/weaponOverlay = image(icon = user.icon, icon_state = S.icon_state, dir = user.dir)
                weaponOverlay.layer = target.layer + 0.1
                target.overlays += weaponOverlay
                spawn(2)
                    target.overlays -= weaponOverlay
            else
                // Swinging at an empty tile (nobody in front) — fall back to the turf,
                // matched to the ATTACKER's own offset since there's no target mob.
                var/turf/targetTile = get_step(user, user.dir)
                if(targetTile)
                    var/image/weaponOverlay = image(icon = user.icon, icon_state = S.icon_state, dir = user.dir)
                    weaponOverlay.pixel_y = user.pixel_y
                    targetTile.overlays += weaponOverlay
                    spawn(2)
                        targetTile.overlays -= weaponOverlay
        else if(S.isSpell)
            flick("cast", user)
            view(user) << sound('spell.wav', channel = SFX_CHANNEL, volume = 70)  // see attack.wav note above
            if(target)
                // NOTE: unlike the melee weaponOverlay above, this still uses a plain
                // /icon instead of /image with an explicit .layer — /icon has no layer
                // property, so this overlay likely renders BEHIND the target's own
                // sprite rather than on top, the same visual bug the melee overlay had
                // before it was fixed. Left as-is rather than silently changed since
                // it's untested (no enemy casts spells yet, and this hasn't come up in
                // player testing) — worth the same /image treatment once it does.
                var/icon/spellOverlay = icon(user.icon, S.icon_state)
                target.overlays += spellOverlay
                spawn(6)
                    target.overlays -= spellOverlay
