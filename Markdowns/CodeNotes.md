# Code Notes

Design rationale, OG-confirmation status, and placeholder/unconfirmed markers pulled
out of source comments during the 2026-09 comment-simplification pass. Each entry
cites the `.dm` file and line it came from **at the time of extraction** — line
numbers will drift as the file is edited afterward; use the note's own description to
relocate it if the cited line no longer matches.

Organized by source file, in the order files were processed.

---

## Code/World/Interaction.dm

- **Line 9, `OnInteract()`**: no separate "is this interactable" marker var — the
  override itself is the marker (base returns `FALSE`, meaning "not interactable").
  Caller is `Interact()` in `Code/Player/Commands/PlayerVerbs.dm`.

## Code/Combat/Skills/SkillCatalog.dm

- **File-level (original lines 1-18)**: building a bespoke `OnUse()` for ~90 individual
  skills was out of scope for "mechanics working, tune later" — every named skill is a
  thin subtype of `GenericPhysical`/`GenericSpell`, setting only name/icon_state/cost/
  multiplier, the same reduction `ClassReference.md` itself already made ("which stat
  governs it"). **PLACEHOLDER POLICY**: every `damage_multiplier`/`heal_amount`/
  `mana_cost`/`element` value in this file is invented, not OG-derived —
  `ClassReference.md` only ever confirmed *which stat* gates a skill, never its
  numbers. All tunable once there's real playtesting to feel them against.
- **Lines 26-30 (`GenericPhysical.icon_state`)**: reuses Attack's "weapon" sprite state
  — no per-skill animation states exist yet, and Fighter's own icons don't even have a
  "weapon" state (PlayerTemplate.dm), so this is a known-imperfect visual, not a new gap.
- **Lines 34-36 (`GenericPhysical.isRanged`)**: flag only — no actual ranged/thrown
  behavior built (e.g. Boomerang still resolves as a normal melee hit via
  `PerformMeleeHit()`).
- **Lines 73-77 (`GenericSpell` header)**: OVERTURNED 2026-08-10 — live OG testing
  showed Heal's amount going 60→63 as Int and Spirit both climbed +1, so heals DO scale
  with a stat (Int, Spirit, or both; not yet isolated since they moved together).
  `heal_amount` needs a scaling term added once the governing stat is confirmed — don't
  treat it as flat. See `CombatDataSheet.md`'s Heal amounts table.
- **Lines 101-106 (`GenericSpell.OnUse`)**: the battle-area gate applies to offensive
  spells only, not healing — healing has always been usable anywhere in this genre
  (after a fight, in a corridor, back home). Gating it the same way as damage spells
  used to silently no-op the entire cast (no MP cost, no windup, no number, no error
  message) the instant a player tried to Heal outside a battle-mode area.
- **Lines 113-117**: casting a heal on a target already at full HP is blocked before
  spending MP or starting the cast — the number shown on a successful cast is always
  the spell's full rated power (`ApplyHeal()`, CombatSystem.dm), so there's no
  meaningful "wasted overheal" case where casting anyway would show anything.
- Per-skill placeholder markers stripped (all covered by the file-level policy above);
  notable ones with EXTRA information beyond "unconfirmed guess":
  - `damage_multiplier`s for Jump/Hide/Dash/Quakejump: mechanically just a strike for
    now — real leap/stealth/dash-movement/ground-slam-AoE not modeled this pass.
  - Magicknife's governing stat is unconfirmed in `ClassReference.md`, assumed Strength.
  - Fireclaw/Iceclaw/Flamesword/Goldclaw/IceSaber: Str-scaled only, no elemental bonus
    modeled despite the elemental name.
  - SwordOfLethargy: no slow/debuff effect modeled this pass, damage only.
  - Confirmed stat GATES (not the damage numbers, just the unlock threshold) for:
    Chainsickle 19 Str, DragonKiller 30 Str, ThunderSword 35 Str (Hero's table);
    Icebolt 7 Int, Lightning 10 Int, Icespears 13 Int, Bang 18 Int, Thordain 20 Int,
    Firebane ~21 Int (originally an 18-24 range), Upper 10 Int, Sleep 9 Int, Stopspell
    ~20 Int (originally 17-23), Return 14 Int, Vivify ~22 Int (originally 21-24) — all
    from Hero's skill-unlock table, `Code/Player/SkillUnlocks.dm`.
  - Blazemore: the next tier up from Blaze, whose own real projectile system stays the
    actual Blaze skill (SkillDatum.dm) — Blazemore is generic-framework damage only.
- **Lines 216-227 (`Thornwhip`)**: CONFIRMED 2026-08-18 (live OG test, CombatDataSheet.md)
  — real damage is ~80% of a plain hit (was 1.4, which hit HARDER than a normal swing as
  well as further — wrong in both directions). CONFIRMED 2026-08-10, restated more
  precisely 2026-08-18: a 3-tile line attack in the facing direction, hitting whichever
  enemy is closest within that line (1, 2, or 3 tiles out, not always the full 3),
  stopping on the first one found — does NOT pierce (an earlier recollection that it did
  is superseded by current live behavior). Confirmed gate is 8 Str.
- **Lines 433-435 (`Heal.heal_amount`)**: CONFIRMED 2026-08-10 (Hero1 live test, single
  sample) — heals on animation completion, not instantly on cast. Gate is 6 Int
  (Hero's table), also confirmed this session.
- **Lines 450, 468 (Healus/Healusmore `icon_state`)**: no dedicated "healus"/
  "healusmore" art exists in spells.dmi — these reuse Healmore's/Healmost's icon_state
  per the user's own explicit call, not a bug.
- **Lines 481-486 (`BuffSpell` header)**: Upper/Increase/Barrier became real timed
  buffs as of 2026-08-25 (`datum/status_effect/buff/*`, StatusEffects.dm). They used to
  be stand-ins that quietly healed a few HP instead — worse than not existing, since the
  skill list advertised a buff and the code did something unrelated with no way for a
  player to tell. They target self by default (a buff with no target is a self-buff) but
  can be cast on an ally by facing them, same targeting rule as every other skill.
- **Lines 731-735 (`Classchange`)**: Goof-off's signature unlock, transforms the
  character into a Sage (DW3-style). Level 25, no stat gate — confirmed by the OG help
  file, matching the data point `TODOList.md` already carried (2026-08-04 decision
  notes). Gates on level and confirms, then hands off to `BecomeSage()`
  (PlayerTemplate.dm) for the actual mob-swap and level-1 reset the OG's own
  confirmation prompt promises.
- **Lines 750-757**: the level check is re-verified in `OnUse()` (not just relied on at
  unlock time) because a GM_LevelIncrease down, a future respec, or any other path that
  moves Level after the fact would otherwise let Classchange fire under-level — the
  skill itself is granted at level 25 via Goofoff's unlock table (SkillUnlocks.dm), but
  that only controls when it's LEARNED.
- **Lines 759-765**: CONFIRMED OG requirement (string: "You must unequip everything
  before you can change your class.") — now a real check against worn amulets
  (`obj/item/amulet`, Inventory.dm), the remake's only equippable slot as of 2026-08-25.
- **Lines 770-774**: CONFIRMED 2026-08-25 (live OG test) — classchange re-runs the
  actual character creation flow (icon, colors, stat allocation), not a straight stat/
  appearance carry-over. See `RunSageReclassFlow()`'s own note (PlayerTemplate.dm).

## Code/Player/PlayerTemplate.dm

- **Lines 7-23 (`canAct`/`attackRecoveryOnly`)**: `canAct` is the shared "can this mob
  currently move or act" gate, checked by `mob/proc/Step()` (SmoothMovement.dm) so a
  single flag roots a mob regardless of WHY: mid-attack swing/cast (SkillDatum.dm),
  dead (`Die()`, CombatSystem.dm), falling through a turf/sky (Turfs.dm). Enemies
  (EnemyNPCs.dm) reuse it for their own attack cooldown the same way. `attackRecoveryOnly`
  splits "can move" from canAct's "can start a NEW action" once a melee swing's windup
  has landed (Attack/GenericPhysical/Thornwhip's `OnUse()` — SkillDatum.dm/
  SkillCatalog.dm): canAct stays FALSE for the rest of the recovery (still gates
  re-attacking), but `Step()` lets movement through anyway once this is TRUE, instead
  of rooting the whole recovery window. Left FALSE for every other canAct=FALSE case
  (death, sleep, hazards, spellcasting, enemies), which are meant to fully root the mob.
- **Lines 37-39 (`expReward`/`goldReward`)**: `expReward`'s 10 was the old hardcoded
  flat reward for every kill. `goldReward` is new — nothing in the game granted Gold at
  all before this (it was display-only, saved and halved on death with no way to ever
  earn any).
- **Lines 78-84 (`HPfactor`/`MPfactor`)**: the OG confirms these existed
  (`OGGameStructure.md` §4) but not their real values, so a Soldier and a Wizard at
  equal Vitality no longer come out with identical HP. PLACEHOLDER numbers grounded in
  the OG help file's own class flavor text ("Soldiers are the best class at taking
  damage", "Wizard: very weak in physical combat... most powerful offensive magic",
  etc.) rather than invented from nothing.
- **Lines 98-102 (stat caps)**: confirmed numbers pulled from `ClassReference.md`;
  every gap it marks `?` gets a placeholder value per-class. Per-class cap PLACEHOLDER/
  confirmed status (originally inline, now consolidated here):
  - **Hero**: Strength 60 confirmed, Agility 60 placeholder (mirrored off Strength),
    Vitality 80 placeholder, Intelligence 150 confirmed, Spirit 60 placeholder.
  - **Soldier**: Strength 100 confirmed, Agility 60 placeholder, Vitality 100
    confirmed, Intelligence 20 placeholder (kept low — no Int-gated skills in
    ClassReference.md's Soldier table), Spirit 40 placeholder. HPfactor 1.3 placeholder
    ("the best class at taking damage").
  - **Wizard**: Strength 40 confirmed, Agility 40 confirmed, Vitality 60 confirmed,
    Intelligence 100 confirmed, Spirit 60 placeholder. HPfactor 0.7 / MPfactor 1.3
    placeholder ("very weak in physical combat... most powerful offensive magic").
  - **Fighter**: all confirmed (Str 100, Agi 100, Vit 80, Int 40, Spirit 40).
    `hasMana = FALSE` is placeholder — no Int-gated skill in ClassReference.md's
    Fighter table, assumed non-caster. HPfactor 0.85 placeholder ("not so good at
    taking damage").
  - **Pilgrim**: Strength 80/Agility 60/Intelligence 100 confirmed, Vitality 60 and
    Spirit 60 placeholder. MPfactor 1.1 placeholder ("specializes in healing and
    defensive magic").
  - **Goof-off**: Strength 80 confirmed, Agility 60 placeholder, Vitality 60/
    Intelligence 40/Spirit 40 confirmed. `hasMana = FALSE` placeholder (no Int-gated
    skill in its table; Magicknife's governing stat is itself unconfirmed). HPfactor
    0.9 placeholder ("weaker than the rest").
  - **Sage**: every cap is placeholder — `ClassReference.md` has no Sage numbers at
    all. Kept in confirmed caster territory per the doc's explicit call ("horrible in
    physical combat"), Intelligence matched to Hero's since Sage's skill list is the
    Hero+Wizard+Pilgrim union. MPfactor 1.3 matches Wizard since Sage's spell list is a
    strict superset of it.
- **`RunSageReclassFlow()`/`BecomeSage()`**: CONFIRMED 2026-08-25 via live OG testing
  (screenshot) — classchange re-runs the actual character creation flow (icon
  selection with the exact OG-confirmed "Who will you look like?" prompt, color
  customization, stat allocation), not a straight carry-over of the old character's
  appearance/stats. This was missed entirely in the first pass at Classchange, which
  just copied the old mob's icon/colors/stats onto the new Sage outright.
  `RunSageReclassFlow()` reuses `IconSelect()`/`CustomizeColors()`/`StatAllocation()`
  directly on the existing player mob P rather than duplicating that flow — those
  procs only touch vars declared at plain `mob` scope, so they work identically
  whether P is a fresh `mob/playerTemp` or a live `mob/player` mid-game; their
  parameter types were loosened from `mob/playerTemp` to plain `mob` to allow this.
  `BecomeSage()`'s progress reset (Level/Exp/Nexp/stats/StatPoints all reset like a
  genuinely fresh character) is CONFIRMED OG behavior, both from the classchange
  confirmation prompt itself ("You will keep all your items and gold, but you will be
  set back to level 1") and from the reclass flow being confirmed as a real re-run of
  character creation. Unspent level-up points on the OLD character are deliberately
  NOT preserved either — carrying those forward would let this "start over" reclass
  end up with more allocated stats than a real fresh Sage. Vitals are recomputed fresh
  and topped off to full rather than carrying the old HP/MP number and clamping it
  down — a level-25 character's leftover 400 HP clamped to a level-1 Sage's ~35 max
  isn't meaningfully different from just starting full, matching every other
  "new character" path in the codebase.

## Code/Player/Inventory.dm

- **Lines 4-11 (inventory capacity)**: confirmed shape via the OG help file's own
  flavor text ("Strength: increases physical damage AND the number of items you can
  carry", `TODOList.md` 2026-08-04 decision). Coefficients are placeholder, chosen so a
  fresh level-1 character (Strength = 1, the actual creation default) lands exactly on
  the one confirmed real data point: capacity 9. `STR_PER_CAPACITY` reuses the same /5
  divisor already established by the stat-point cost formula
  (`obj/StatLink/GetCost()`, ClickableStats.dm) for internal consistency, not because
  it's independently confirmed.
- **Lines 118-126 (consumables header)**: names and behavior are OG-confirmed (appear
  verbatim in the extracted string table): "medical herb", "herbal tea", "leaf of the
  world tree", "wing of wyvern". Heal/restore amounts are placeholder — the OG stored a
  `heal_amount` per item but that value isn't recovered yet. ART PLACEHOLDER: every
  consumable borrows the key sprite (`World Icons/Items/` only has key.dmi) — this is
  the single most visible unfinished thing about them.
- **Line 130 (`maxStack = 99`)**: placeholder — no OG stack-limit number recovered.
- **Lines 218-225 (`dharmaScroll`)**: CONFIRMED OG item (`ClassReference.md`/
  `TODOList.md` Phase 1) — the non-Goof-off path to Sage. Goof-off learns Classchange
  as a free leveled skill; every other class needs this scroll instead. There's only
  one real "become a Sage" implementation in the codebase (`RunSageReclassFlow()`/
  `BecomeSage()`, PlayerTemplate.dm) — this is just a second door into it. PLACEHOLDER:
  applies the same level-25/unequip-everything gates as Classchange for consistency —
  no OG confirmation either way whether the scroll path shares them.
- **Lines 260-276 (amulets header)**: CONFIRMED OG system — 23 named amulets, a max of
  2 worn at once ("You cannot wear more than 2 amulets at the same time!" is verbatim),
  each with an `/item/amulet/<x>/equip` override. This was an entire
  character-building axis with no remake equivalent at all before
  (`RemakeVsOGStructure.md` Part 3.6). The OG's own naming splits cleanly into two
  families, preserved here: "Amulet of `<Stat>`" (raw stat bonuses) vs. "Amulet of
  `<Power>`" (derived bonuses — Power, Speed, Health, Magic, Light, etc.).
  PLACEHOLDER bonus values throughout — the OG stored a per-amulet `bonus` field that
  isn't recovered yet.
- **Lines 500-502 (utility amulets)**: Safe Passage/Protection/Barrier/Wakefulness
  confirmed by the user from memory of the OG (no string-table/monster-table data
  recovered for these, unlike the stat amulets above) — functionally as solid as
  anything else in this file, just sourced differently.
- **Lines 531, 537, 543 (Wealth/Experience/Luck percentages)**: all placeholder 10%
  values.

## Code/Combat/CombatSystem.dm

- **Lines 27-29 (`DEATH_EXP_LOSS_PERCENT`)**: CONFIRMED 2026-08-25 (OG string table,
  string 605): "You have lost 5% of your EXP as penalty for respawn." — 5%, verbatim.
  Was 25% before, an invented number.
- **Lines 31-37 (`DEATH_GOLD_LOSS_PERCENT`)**: UNCONFIRMED — remake-only, deliberately
  left in place. An old comment here claimed this matched a "lose half gold" original
  design note, but the full 4450-string OG table contains no gold-loss message and no
  gold-loss variable anywhere (`RemakeVsOGStructure.md` Part 5.2). The OG's only stated
  respawn penalty is the 5% EXP line above. Kept at 50 rather than silently zeroed
  since removing a penalty is a balance decision, not a correction — treat this as a
  remake addition, not OG-derived.
- **Lines 39-45 (`RESPAWN_AUTO_DELAY`)**: CONFIRMED 2026-08-25 (OG string table, string
  887): "You will auto-respawn in 60 seconds. You may press 5 on your numpad to
  respawn before then." Both halves are implemented: auto-fire after this delay, and
  numpad 5 (the "Center" macro, Interface.dmf) respawns immediately with NO minimum
  wait. The old model was the reverse: a 10-second minimum before a manual press was
  even allowed, and no auto-respawn at all.
- **Lines 60-66 (`DEFEND_DAMAGE_REDUCTION_PERCENT`)**: CONFIRMED 2026-08-10 — live OG
  testing shows Defend literally halves incoming physical damage while held; this 50%
  guess matches exactly, no longer a placeholder. OG also drops the stance on attack
  (`DropDefendForAction()`, already matches). The remake's own addition on top —
  `DEFEND_ATTACK_SPEED_PENALTY` below, an attack-speed penalty on drop, not in the OG —
  is explicitly preferred by the user over the OG's plain drop, so it stays.
- **Lines 94-99 (`RollDodge()`/dodge constants)**: dodge chance is a new mechanic — no
  such thing existed before, so this is a placeholder formula, not OG-derived.
  Agility-based, capped so it's never a sure thing.
- **Lines 107-118 (defense divisors)**: new — no OG numeric formula exists to confirm
  against (only the help file's plain-language claim that Agility+Vitality drive
  physical defense and Vitality+Intelligence drive magic defense).
- **Lines 132-141 (crit constants)**: new — no OG numeric formula exists either, only
  the help file's claim that Spirit drives crit rate.
- **Lines 228-234 (`firstAttacker` credit in Die())**: the OG's own rules text is
  explicit: "You won't get any EXP or gold from it unless you hit it first, anyway."
  Without this, anyone could wait out someone else's fight and steal the reward with a
  finishing blow. Recorded in `TakeDamage()` rather than `Die()` because by then the
  first attacker is long gone from the call chain.
- **Lines 290-295 (`expReward` history)**: used to be a flat literal 10 for every kill,
  meaning a Tier 4 Dragonlord paid exactly what a Tier 1 Bat did. Survivable against
  the old flat "Nexp += 10" curve, but not against the convex one (`LevelCheck()`):
  level 49→50 alone needs 15 × 49² = 36,015 exp, i.e. ~3,600 kills of ANY monster at a
  flat 10.
- **Lines 397-403 (`BASE_EXP`/exp curve)**: PLACEHOLDER, convex on purpose ("fast at
  first, slows down" per the user's own description). Quadratic (Level²), not a
  fractional exponent — DM has no exponentiation operator or pow()/exp()/ln()
  builtins. `BASE_EXP` is invented, no OG data exists for this pacing.
- **Lines 419-422 (`StatPoints += 6`)**: CONFIRMED 2026-08-10 — Hero1 sat on 12 unspent
  points after 2 level-ups (1→2→3) with none spent along the way, i.e. 6 per level,
  not the old placeholder 5 (`TODOList.md` Phase 7).
- **Lines 480-505 (elemental scaffolding)**: real, working code, but currently inert —
  nothing yet sets `elementalWeakness`/`elementalResistance`, so these checks never
  trigger until something does. Same pattern as Area.dm's battleModeOn/weather vars
  before GM_BattleMode wired them up. Confirmed remake idea, not OG-derived — see
  `TODOList.md` Phase 6 for open questions (how many elements, whether player affinity
  is a creation-time choice). `mobElement` (a mob's OWN affinity, distinct from what
  it's weak/resistant TO) IS real OG data: the .dmb type table stores an element name
  string per monster (literally "Fire"/"Water"/"Ice"/"Air"/"Iron"/"Plant"/"Darkness"/
  "Holy"/"Normal"/"Physical"), and every monster in MonsterRoster.dm now carries its
  real one. The OG resolved attacker-element vs. defender-element through a single
  `/proc/Element(off, def)` lookup whose multiplier table lives in undisassembled
  bytecode — until that's recovered, `ResolveElementalDefense()` derives
  weakness/resistance from affinity using only the one safe rule (a creature of an
  element resists that element), deliberately not inventing an opposition table
  (fire-beats-ice etc.), which would be pure guesswork. Players leave `mobElement`
  null; no creation-time affinity choice exists.
- **Line 544 (`ApplyHeal()` full-power display)**: confirmed real-game behavior — Heal
  always displays its full healing power even when already near/at max HP, only the
  underlying HP gain itself is capped.
- **Lines 556-559 (`SPELL_AGI_SYNERGY_DIVISOR`)**: placeholder, tune by feel.
- **Lines 561-566 (`DEFEND_ATTACK_SPEED_PENALTY`)**: on top of the auto-drop mechanic
  itself, attacking from a defensive stance is also slightly slower to throw —
  placeholder, tune by feel.
- **Lines 622-634 (animation-state resolution header)**: confirmed by reading the
  actual .dmi files — Hero/Soldier/Wizard/Pilgrim/Goof-off/Sage all use "attack"/
  "weapon", but ALL FOUR Fighter icons (dw1fighter/dw2fighter/dw3malefighter/
  dw3femalefighter) instead split them per hand: "rightattack"/"leftattack" and
  "rightweapon"/"leftweapon", no plain "attack"/"weapon" state at all. Asking flick()
  for a state an icon doesn't have silently plays nothing — this is why a Fighter had
  no swing animation and no weapon overlay whatsoever before `ResolveAnimState()`.
- **Lines 667-697 (`GetWeaponOverlayNudge()`)**: values tuned live against Cere.dmi
  during 2026-09-02/03 playtesting (see [[dwlr-archsage-icon-collaborator]] memory) —
  East/West pull the overlay closer and down slightly; North/South are still at (0,0),
  untuned. Revisit once the underlying Cere.dmi art itself gets redrawn (a new
  collaborator is picking that up) — this nudge table may need re-tuning from scratch
  against the new art rather than assuming these numbers still apply.
- **Lines 780-786 (spell-overlay layering bug, `PlayAttackAnimation()`)**: unlike the
  melee weaponOverlay, this branch still uses a plain `/icon` instead of `/image` with
  an explicit `.layer` — `/icon` has no layer property, so this overlay likely renders
  BEHIND the target's own sprite rather than on top, the same visual bug the melee
  overlay had before it was fixed. Left as-is since it's untested (no enemy casts
  spells yet, hasn't come up in player testing) — worth the same `/image` treatment
  once it does.
- **Lines 844-858 (`PerformLineHit()` header)**: built for Thornwhip, whose real
  behavior was confirmed TWICE by live OG testing: a 3-tile line attack in the facing
  direction that hits whichever enemy is closest within that line (1, 2, or 3 tiles
  out, not always the full 3) and stops on the first one found. Deliberately not built
  on Projectiles.dm's `pierces` flag — that models a travelling projectile passing
  through several targets, explicitly not what the OG does here (no travel time, no
  visible projectile, just a longer arm). Walls don't block it yet — deciding what
  counts as blocking (dense turfs only? dense objs too?) isn't confirmed from the OG
  either way, and guessing would be a real behavior change, not a gap being filled.

## Code/Combat/StatusEffects.dm

- **Lines 129-133 (`POISON_CAN_KILL`)**: FALSE floors damage at 1 HP, matching classic
  Dragon Warrior (poison never kills outright) and avoiding "died to a ticking number I
  couldn't respond to." Flip to TRUE if poison should be genuinely lethal — the death
  path is already wired for it either way.
- **Line 124 area (poison numbers)**: all placeholder.
- **Lines 159-164 (direct HP change, not TakeDamage())**: deliberate — TakeDamage()
  would roll RollDodge(), and you shouldn't be able to dodge poison already in your
  veins. The hit SOUND is still wanted every tick (confirmed), so it's played
  explicitly, same player/enemy split and SFX_CHANNEL TakeDamage() uses so it doesn't
  stomp area music.
- **Lines 186-192 (Sleep header/durations)**: placeholder durations (10s/20s) — no
  wake-on-hit yet, worth adding once tuned against real combat.
- **Lines 210-214 (Sleep's `OnExpire()` isDead guard)**: same guard Attack/Blaze's own
  deferred recovery spawns use for the identical reason — Die() locks canAct
  deliberately as part of the death/respawn flow, and an unconditional unlock here
  would quietly undo that and let a "dead" mob walk before respawning.
- **Lines 226-244 (Buffs header)**: CONFIRMED the OG had these as real timed buffs —
  `upper`/`upper_time`/`upperon` and `barrier`/`barrier_time`/`barrieron` are all real
  vars in the extracted string table, with the `*on` flag driving a visual overlay.
  Until this pass these three skills were stand-ins that quietly healed a few HP
  instead (SkillCatalog.dm's old "no real buff system exists yet" note) — worse than
  not existing, since a player reading the skill list had no way to know it wasn't a
  real buff. PLACEHOLDER amounts and durations throughout — the OG's own values aren't
  recovered.
- **Line 316 (`SILENCE_DURATION`)**: placeholder, 15 seconds.

## Code/Player/Commands/SocialVerbs.dm

- **Lines 4-15 (shadow mute)**: CONFIRMED 2026-08-25 (OG string table) — mute in the
  original was SILENT to its target. The table carries GM-only "(Muted)`<name(key)
  says:>` ..." copies of every chat form alongside the normal ones, and GM_Mute's own
  confirmation reads "You have secretly [un]muted X" — the whole design is that a
  muted player keeps talking into a void, never learning they've been muted. The
  remake previously hard-muted instead, telling the target "You are muted and cannot
  speak." and sending nothing, which tips them off immediately and makes the mute
  useless as a moderation tool.
- **Lines 41-46 (`WORLD_CHAT_COOLDOWN`)**: CONFIRMED 2026-08-25 (OG string table): "You
  must wait 1 second between each world say" / "...world emote", backed by the OG's
  own `wsay_limit` var. WorldSay/WorldEmote reach every player on the server at once
  and had no throttle at all before this. One shared timestamp for both, same as the
  OG's single var — spamming alternately between the two shouldn't dodge the limit.
- **Lines 57-60 (`worldChatEnabled`)**: CONFIRMED OG (strings: "You turn off worldsay
  and worldemote." / "X deactivates worldsay.").
- **Lines 125-128 (Whisper's three-tier confirmation)**: CONFIRMED OG (string table
  carries both "(Muted)`<name(key) whispers:>`" and "`<name(key) whispers:>`" forms
  alongside says/shouts) — the OG's chat was tiered by range: whisper reaches only the
  tiles immediately around you, Say reaches your view, Shout reaches well past it. The
  remake only had the middle tier before this.

## Code/Combat/NPCs/EnemyNPCs.dm

- **Pets (design note, 2026-08-01, user's idea)**: any mob/enemy can become a pet —
  there's no separate pet type. A GM double-clicking a wild (unowned) one gets an
  "Assign Pet" option; picking a nearby player sets `owner` on that same mob instance,
  in place — same stats, same icon, no leveling system yet. Once owned, `AILoop()`
  routes every tick through `HandlePetTick()` instead of the wild logic, branching on
  `petMode`. Only one pet per owner for now (enforced in `ShowAssignPetMenu()`) — no
  roster/stable system yet.
- **`sightRange`/`attackRange`/`aiTickDelay`/`attackCooldown`/`wanderChance`/
  `fleeHealthPercent`/`castChance`/`healThresholdPercent`**: all placeholder tuning
  numbers, no OG data recovered for any of them.
- **`castableSkills`/`healSkills` header**: the OG gave 20+ monsters their own Fight
  override and 33 distinct attack/spell procs; every enemy here was melee-only before
  this. Rather than reproduce 33 bespoke procs, a monster declares which skills it can
  cast and shared logic (`TryCastAt()`/`TryHeal()`) picks one — the same
  "everything is a skill" model players use, pointed at the existing
  `datum/skill` catalog instead of a parallel monster-only implementation.
- **`dropType`/`dropChance`**: the OG stored exactly this pair per monster (a single
  item typepath + a percent rolled once on death), but the real per-monster values
  aren't recovered (the monster extract's columns stop before them) — the mechanism is
  the OG's, the numbers assigned in MonsterRoster.dm are placeholder/ours.
- **`RunWildAI()`/pet-mode-wander sharing**: shared by genuinely wild enemies and by
  PET_MODE_WANDER pets (defined as behaving exactly like a wild monster). Those two
  used to be separate verbatim copies that had already drifted apart — the pet copy
  nulled and re-acquired its target from scratch every tick instead of running the
  stale-target checks, so a Wander-mode pet could never hold aggro the way a wild
  monster does. Now there is one copy and "acts exactly like a wild monster" is
  literally true.
- **`StepRelativeTo()` — why not `step_to()`**: BYOND's built-in tries a diagonal step
  first whenever the target isn't aligned on either axis, and Main.dm's `mob/Move()`
  override silently blocks any diagonal dir (this game has no diagonal movement at
  all), which left `step_to()` stuck rather than falling back to a cardinal step —
  exactly why chasing only worked when already lined up N/S/E/W.
- **`MovementLoop()`'s per-tick HP/leash checks**: death happens asynchronously
  (`TakeDamage()`/`Die()`, CombatSystem.dm), not synced to `AILoop()`'s slower ~1s
  decision cadence, so a freshly-killed enemy could keep sliding for up to a second
  before `AILoop()` noticed and cleared `moveIntent` — checking HP every
  `MovementLoop()` tick instead stops the corpse immediately. Same reasoning for the
  leash: a fleeing enemy steps continuously in `MovementLoop()` the whole second
  between `AILoop()` decisions, so it could run well past `sightRange` before the
  slower check ever caught it.

## Code/World/Turfs.dm

- **Turf collapse (file-level convention)**: DONE as of 2026-07-21 — every purely
  visual variant (differed from a sibling ONLY by icon_state/name, no real behavior)
  was removed from this file. What used to be e.g. `turf/floor/cobble`,
  `turf/floor/carpet` are now just `turf/floor`, painted as different map-editor
  INSTANCES (icon_state override) instead of separate hardcoded types. Source:
  https://www.byond.com/forum/post/1620724 ("Snippet Sunday #2: Learning to love the
  map editor" — polymorphism isn't a database). The map will not compile until every
  placed tile using a removed type gets repainted as an instance of the surviving base
  type — that's expected, not a bug.
- **`turf/New()`/area decoration**: placing a brand new turf on top of an existing tile
  (GM_MakeTurf, or `new turf_type(oldTurf)` anywhere) replaces the turf object at that
  cell outright — the fresh instance starts with empty overlays regardless of what area
  already owns that cell, so without this override it would silently render as if the
  area decoration wasn't there until the next time someone happened to repaint that
  tile's area. `loc` is a turf's owning area at the moment `New()` runs (BYOND resolves
  area membership before `New()` fires, even for a turf replacing another in place),
  so this one choke point covers every turf creation path there is.
- **Bed restore rate (`BED_RESTORE_INTERVAL`/`AMOUNT`)**: confirmed as "restore 1 of
  each per half second" for a BED, explicitly expected to be retuned. Real resting
  balance (rate, whether it scales with anything, whether an inn bed differs from a
  world one) is still an open design question. The planned Rest skill (sleep in place,
  anywhere) should recover SLOWER than a bed — that's why `SleepRestoreLoop()` takes
  its rate as arguments instead of reading the defines directly; numbers for that
  aren't decided yet.
- **Stairs history**: `cavestairsup` used to be non-functional because "up"/"down"
  behavior lived on the stairsup/stairsdown SUBTYPES only — any skin painted on the
  bare base type (which the turf collapse above produces) inherited no `Entered()` at
  all. `GetStairDirection()` fixed this by inferring direction from icon_state itself,
  confirmed against the actual `icon_states()` dump (every real skin in stairs.dmi
  except castle/icecastle/black has a direction-named state).
- **Hazard terrain header**: CONFIRMED the OG had these — its own type list carries
  `/turf/grass/swamp` with an `Entered()` override, and lava alongside it. The remake
  had no damaging terrain at all before this (`RemakeVsOGStructure.md` Part 3.12),
  meaning a whole category of level design (a route that costs something rather than
  just blocking it) wasn't available. Damage is applied per STEP, not on a timer while
  standing — the simpler reading of the OG's Entered()-based implementation, and it
  keeps hazards predictable (crossing a five-tile swamp always costs exactly five ticks
  regardless of how fast the player moves). A standing-still drain would also fight
  with the passive regeneration in StatsDatum.dm in a way that isn't designed yet.
  Placeholder damage values throughout — no OG numbers recovered.
- **Swamp's `poisonChance = 15`**: placeholder — classic Dragon Warrior swamps poison,
  and the remake already has a poison effect (StatusEffects.dm) to reach for.

## Code/World/NPCs.dm

- **`mob/npc` header**: CONFIRMED OG shape — daymsg/nightmsg per NPC, an Action of
  Stand or Walk, and a Direction/Face setting are all real fields in the OG's own NPC
  creation prompts ("Day Speech", "Night Speech", "Action", "Stand", "Walk",
  "Direction", "Face"). The remake's NPC was a 16-line placeholder with no behavior at
  all before this (`RemakeVsOGStructure.md` Part 3.14).
- **Merchants header**: the remake's first economy sink — until this, Gold was earned
  from kills and lost on death with nothing anywhere to spend it on. Every
  player-facing string is verbatim from the OG string table (shop greeting, Buy/Sell
  prompts with running gold total, "Come again." exit, both refusals). The OG had six
  shop types (Item/Amulet/Food/Drink/weapons/armor); only Item is wired up here since
  it's the only category whose goods actually exist in the remake — amulets in
  particular are an entire missing character-building axis
  (`RemakeVsOGStructure.md` Part 3.6), not just missing stock.
- **`stock`/prices**: placeholder — the OG stored a `value` per item that isn't
  recovered yet. Chosen so a fresh player's early kills (3-10 gold each) make a herb a
  real but reachable purchase, not from any confirmed number.
- **`buybackPercent = 50`**: placeholder — a standard "shops buy low" spread, no OG
  number recovered.

## Code/Combat/NPCs/MonsterRoster.dm

- **File-level (stat provenance)**: stat blocks are REAL OG DATA as of 2026-08-25, not
  placeholders — every Level/MaxHP/MaxMP/Strength/Agility/Vitality/Intelligence/
  Spirit/element/exp/gold value is read straight out of the original Dragon Warrior
  Legacy .dmb's own type table (`Markdowns/OGMonsterBaseStats.tsv` for the raw extract,
  `Markdowns/MonsterBaseStats.md` for confidence notes). The two flat placeholder tiers
  this file used to carry (`TIER1_*`/`TIER2_*` defines, `mob/enemy/tier1`/`tier2` base
  types) are gone — never a real OG concept. Confidence varies by column: element is
  CERTAIN (stored values are literally element name strings), Level/MaxHP/MaxMP and the
  five stats are HIGH, exp/gold are MEDIUM.
  - **Two columns deliberately NOT applied**: `delay` — real and high-confidence
    (inversely monotonic with Agility across the whole roster), but its UNITS are
    unknown. Values run 4-8; `attackCooldown` (EnemyNPCs.dm) is in deciseconds and
    defaults to 10, so mapping delay straight across would roughly double every
    monster's attack rate on an unverified unit conversion — left alone until a
    bytecode pass recovers how delay is consumed. `flee` — applied as
    `fleeHealthPercent`, but flagged MEDIUM confidence in the TSV ("name is a guess").
    The values behave exactly like a percent (0 on every boss and on Skeleton, highest
    on the metal monsters), which is what `fleeHealthPercent` already means, so the
    mapping is safe even if the name turns out wrong.
  - Originally trimmed to ten monsters (cat, slime, dog, redslime, bat, fox, babble,
    skeleton, drakee, healer) per the "5-6 monster types for training cages, not the
    full ~86 roster" call from the 2026-08-14 session. Expanded 2026-08-28 to all 24
    monster names actually CONFIRMED to exist in the OG (via
    GMglobalrespawn/GMkillallmonsters's type pickers, `GMCommandsReference.md`) — the
    other 53 rows in the TSV belong to icons with no confirmed real name, left out
    rather than guessed at. The TSV holds real stats for all 77; adding one more back
    is just a block with its row's numbers, no tier to pick. `dropType`/`dropChance`
    aren't in the TSV at all (no drop data extractable) — chosen in the same loose
    style throughout, not sourced from anything.
- **Bat's Agility 10**: fastest thing in the originally-trimmed roster — the stat the
  old flat tiers erased. Babble's Agility 1 is the slowest.
- **Healer**: CONFIRMED 2026-08-18 — "Healer" is the proper OG name for what earlier
  notes called "healslime"/"healer slime" (same monster, not a separate gap). The real
  MaxMP (20) is what pays for its `TryHeal()` AI; with Heal costing 4 MP it gets
  roughly five casts before it's dry and drops to melee, which is what makes killing it
  first actually matter.
- **Magician/Magidrakee/Gremlin/Blazeghost (real MP, no caster AI)**: have a real MP
  pool per the TSV, but no `castableSkills` wired — the confirmed OG caster AI (kiting,
  MP-drain-then-fallback-to-melee, `TODOList.md` Phase 6) isn't built yet, so these are
  melee-only despite the name/MP.
- **Acolyte**: CONFIRMED OG AI (`TODOList.md` Phase 6, live-tested 2026-08-10) —
  Acolytes self-cast Increase (physical defense buff) the instant they spot the
  player. Not built here — EnemyNPCs.dm has no "self-buff on aggro" hook at all yet
  (only castableSkills/healSkills, both offense/heal-shaped) — worth its own
  `AILoop()` pass alongside the other confirmed-but-unbuilt caster behaviors, not
  bolted on here.
- **`fleeHealthPercent = 0` (Skeleton, Ghost, Blazeghost, Man O' War)**: never flees —
  real TSV value, matches every boss in the TSV.

## Code/Player/Commands/PlayerVerbs.dm

- **`Help()`**: matches the confirmed OG presentation (a browse() popup with a title
  bar/close button, not the output pane or a stat panel) — real content is still
  future work ("even the OG's own doc admits it's outdated").
- **Quick item (`quickItem`)**: CONFIRMED OG feature, described in its own help file:
  "To choose a quick item, drag it onto the slot in your inventory or press * on your
  numpad to cycle through items. To use your quick item, press - on your numpad." The
  cycle half is built; the drag-onto-a-slot half needs a screen-object HUD that
  doesn't exist yet (no `screen_loc` usage anywhere in the codebase —
  `RemakeVsOGStructure.md` Part 3.15).
- **Quick cast (`quickSpells`)**: CONFIRMED OG feature (`quick_5`/`quick_6`/`quick_7`
  vars, plus its own "Quick Cast Hotkeys" prompt and the "You have no spells that can
  be hotkeyed." refusal, both verbatim).
- **`SetQuickCast()`'s `hidden = 1`**: stays functional (F5/F6/F7 macros still work),
  just not shown in the Action tab — user's call, 2026-08-30.
- **Player click menu (`PLAYER_MENU_RANGE`)**: CONFIRMED OG feature (strings: "What
  shall you do?", "Give Gold", "Give Item", "Cast Magic") — the OG's own way of doing
  player-to-player trading and targeted support casting, and the only route it had for
  casting a spell on someone who isn't directly in front of you.
- **`Interact()`'s mob-checking loop**: mobs were never checked here before, which
  meant an NPC standing in front of you was unreachable no matter what it implemented
  — the reason merchants needed this (mob/npc/merchant, NPCs.dm).
- **`Look()`**: same hardcoded Class/Level/Party stub as `Who()` until the real data
  exists (future work).

## Code/Player/StatsDatum.dm

- **`MP_PER_SPIRIT = 2`**: CONFIRMED 2026-08-10 — live OG testing (Hero1) showed +1
  Spirit = +2 MaxMP exactly, matching this coefficient. No longer a placeholder guess.
  Every other vitals coefficient (`BASE_MAX_HP`, `HP_PER_VITALITY`, `HP_PER_LEVEL`,
  `BASE_MAX_MP`, `MP_PER_INTELLIGENCE`, `MP_PER_LEVEL`) is still placeholder, same
  "tune later once there's something to playtest against" status as the damage formula
  in CombatSystem.dm — not verified against the original game (not recoverable from
  play, see `ClassReference.md`).
- **Passive regen header**: CONFIRMED the OG had this — `HPregen`/`MPregen` plus
  `cur_HPregen`/`cur_MPregen` countdown timers are all real vars in the extracted
  string table. The remake had no passive regeneration at all before this — the only
  way to recover was sleeping in a bed (Turfs.dm) or spending a Rest/Meditate cast,
  which made any fight away from town a one-way trip. The OG's help file states the
  governing stats plainly: "Vitality: increases max HP, HP regeneration rate";
  "Intelligence: increases max MP, MP regeneration rate" — so the stat pairing is
  confirmed even though the coefficients aren't. Coefficients are placeholder, set so
  a fresh level-1 character (Vitality 1) ticks 1 HP roughly every 5 seconds and a
  heavy investment is noticeably but not dramatically faster.

## Code/Core/Main.dm

- **World clock header**: CONFIRMED OG shape (string table) — a running clock with
  per-minute/per-hour ticks, sunrise at 6:00 AM and sunset at 6:00 PM, a 12:00 PM
  start, and a distinct flavor message for each transition. The remake had `isNight`
  and `IsNightVariant()` as helpers with nothing driving them before this — day/night
  only ever changed if a GM typed the verb. Placeholder cadence: the OG's
  real-time-to-game-time ratio isn't recovered, so one game hour per real minute was
  chosen (a full day/night cycle every 24 real minutes) — tune freely, every other
  part of the clock derives from `GAME_MINUTES_PER_TICK`/`REAL_DECISECONDS_PER_TICK`.
- **World clock DISABLED (world/New())**: 2026-08-26, user call — only useful for RP
  mode, which isn't built and isn't current scope (see
  `dwlr-current-priorities` memory note). Cadence was also flagged too fast
  independent of the scope question. `WorldClockLoop()`/`GetGameTimeString()` are left
  intact, not deleted — this is the wire-up point to re-enable once an RP-mode pass
  wants it.
- **Fade states (`FADE_STATES`)**: confirmed real icon_states in 'UI & Effects/fade.dmi'
  (dumped from the actual file, not guessed): 0, 12.5, 25, 37.5, 50, 62.5, 75, 87.5,
  100 — 8 steps from fully transparent to fully black, plus an unrelated "waterfade"
  state this doesn't use. Each state is a solid single-color 32x32 tile (confirmed
  from the .dmi's own pixel data), which is what makes the screen_loc range-tiling in
  `GetFadeOverlay()` work: one icon tiled across the whole 13x13 view reads as one
  uniform overlay, not a repeating pattern.
- **`FADE_STEP_INCREMENT`/`DECREMENT` (every OTHER state, not all 9)**: `sleep(1)` is
  already `world.tick_lag`'s floor (no explicit tick_lag set, so BYOND's default
  0.1s/tick), so halving frame COUNT is what actually speeds this up rather than
  shrinking a delay already at the minimum meaningfully visible step. 4 transitions =
  0.4s per direction, down from 0.8s, and still four distinct visible stages rather
  than a snap.
- **`ApplyNightSuffix()`**: used by `obj/door`'s `close()` (Obj.dm) — `closed_icon_state`
  is a fixed value set once at door creation, and GM_DayNight's own sweep
  (`ToggleNightIconState()`) only ever touches a door's LIVE icon_state, never that
  stored baseline. Without this, a door closing during night was reverting straight
  back to its creation-time (often day) skin instead of the currently-correct one —
  this computes the right sprite fresh every time instead of trusting a value that can
  go stale.
- **`world.Reboot()` override**: `world.Reboot()` itself only wipes/reinitializes
  world state — it does NOT automatically give already-connected clients a fresh mob
  or call `Login()` on it (CONFIRMED broken in the OG's own version,
  `GMCommandsReference.md`: everyone stuck on a black screen after reboot). `..()`
  does the actual engine-level wipe and re-parents `mob` as `world.mob`'s default for
  any brand-new connection, but existing clients need to be walked through login again
  explicitly. CONFIRMED ENVIRONMENT QUIRK (not a bug in this override):
  `world.Reboot()` only completes properly under a real Dream Daemon-hosted session —
  testing straight from Dream Seeker/DM.exe without a real Dream Daemon process just
  freezes on the call. `GM_WorldReboot` (GMCommands.dm) needs a real hosted session to
  test end-to-end.
- **Double-login rejection (`client/New()`)**: confirmed from a real OG server log
  excerpt — two different ckeys ("D-FORCE"/"Supersayion5") from the same address, the
  new one logged as an "attempted double login" and immediately disconnected while the
  original session kept running unaffected. GMs are exempt (confirmed) — e.g. testing
  with a second window from the same machine.
- **`del(src)` at the end of `SaveAndLogout()`**: CONFIRMED bug this fixes — BYOND
  matches a newly-connecting client to any EXISTING mob whose `.key` still matches
  theirs. A mob left undeleted here keeps its key forever, so reconnecting (whether
  after a normal disconnect or a GM_Boot/GM_Ban) silently reattaches the new client
  straight to this same stale mob instead of running `mob/playerTemp`'s
  `Login()`/`ShowLoginMenu()` at all — that stale mob's `loc` was just nulled and never
  gets reset, so the "skipped the login menu, logged in at 1,1,1" symptom is BYOND's
  fallback placement once a client is watching it again.

## Code/UI/HUD.dm

- **File-level**: wires up art that already existed in "UI & Effects/" (meter.dmi/
  magicmeter.dmi/expmeter.dmi/numbers.dmi/text.dmi) but had zero screen-object code
  behind it — the "HUD code" gap flagged as the highest-value remaining item in
  `RemakeVsOGStructure.md`, carved into this build pass rather than deferred (bottom
  HUD + floating HP/MP meters + floating combat numbers are needed for combat to be
  legible/testable at all). PLACEHOLDER throughout — every pixel offset, glyph width,
  and timing value is a guess (no way to drive the actual BYOND client to check
  alignment during development), so this is "compiles and runs," not "pixel-tuned."
- **Bottom HUD layout (`HUD_ROW_TOP`/`HUD_COL_*` etc.)**: real reference screenshot
  (2026-08-29) — a single solid black bar, exactly 1 tile tall, spanning the full
  13-tile view width, topmost layer, not a stat-panel or bars. Two rows of plain white
  text: "Level: N" / "XP:NN.N%" on the left, "HP:"/"MP:" labels then "cur/" then "max"
  spread rightward.
- **`HUD_GLYPH_SPACING`/`COMBATNUM_GLYPH_SPACING`**: real per-glyph measurements
  (`Debug_MeasureFont()`, DebugTools.dm, 2026-08-29) — text.dmi is a PROPORTIONAL font,
  not monospace: ink width ranged from 4px (":") to 14px ("e"/"8"/"%"), ink sits
  roughly y=3-16 within each glyph's 32x32 canvas. `HUD_GLYPH_SPACING` is a single
  fixed advance width covering the widest letter measured (14px) plus a small margin —
  not true kerning (narrow letters like "l"/":" get a little extra trailing gap), but
  no overlap either. numbers.dmi was measured separately (~8-9px ink) since it's a
  visibly smaller font used only for floating combat numbers.
  `COMBATNUM_GLYPH_SPACING` was tightened from 11 to 8 — "miss" (its narrowest glyph,
  "i") read with visible gaps at 11; checked digits still don't touch at 8.
- **`FLOATING_NUM_HOLD_TIME`**: was fading across the whole lifetime before, which read
  as too transparent almost immediately — now holds fully opaque for this long once
  the rise finishes, THEN fades over the remainder.
- **`FLOATING_NUM_X_OFFSET`**: shifts the number block right of tile-center, landing
  over the top-right of the sprite instead of dead-center.

## Code/Player/SkillUnlocks.dm

- **Soldier's Club (`GetStartingKit()`)**: ClassReference.md's confirmed Soldier kit
  is Attack/Defend/Club — Club itself didn't exist as a real skill datum until this
  pass.
- **Goofoff's Classchange unlock level (25)**: `TODOList.md`'s own confirmed
  placeholder for this ("the first real data point for it") — not invented fresh here,
  carried over from there.
- Every unconfirmed level/stat threshold across every class's `GetSkillUnlocks()` was
  invented per the 2026-08-04 placeholder policy, mirroring Hero's own confirmed
  spacing where reasonable — every table is real and filled-in, not placeholder test
  data, but only 2 of ~90 entries total (Hero's Heal at level 3/Int 6, Thornwhip at
  level 5/Str 8) are OG-confirmed.

## Code/World/Obj.dm

- **Obj collapse (file-level convention)**: DONE as of the map repaint session
  following the Turfs.dm collapse — every purely-visual variant (differed from a
  sibling only by icon_state/name/message) has been removed. What used to be e.g.
  `obj/stat/sign/inn`, `obj/stat/sign/church` are now just `obj/stat/sign`, painted as
  different map-editor INSTANCES. Source: same as Turfs.dm's collapse
  (https://www.byond.com/forum/post/1620724). The map will not compile until every
  placed obj using a removed type gets repainted as an instance of the surviving base
  type.
- **`close()`'s `ApplyNightSuffix()` call**: `closed_icon_state` is fixed at creation
  and never updated by a later day/night toggle, which was reverting a door closed at
  night back to its day skin — `ApplyNightSuffix()` (Main.dm) recomputes the right
  sprite fresh every time instead.
- **`bookcase`**: CONFIRMED OG mechanic (`OGGameStructure.md`, string 1687):
  "player-writable shared book storage" — any player can add a message, and read what
  everyone else (not just themselves) has written to THIS bookcase. Distinct from
  sign's message: a sign's text is set once by whoever placed it, a bookcase's message
  list grows from ordinary player interaction with no placement-time content at all.
- **Storage containers header**: fills in the "interaction stores and takes items"
  TODOs left on drawers/chest/pot. CONFIRMED OG shape: its own prompts are "What would
  you like to do?" with Store / Take / Leave, and drawers/chests carry an optional
  name that makes them lockable ("Use no name for unlockable drawers.").

## Code/UI/LoginMenu.dm

- **`ShowLoginMenu()`'s LoadCharacter failure handling**: `M` was never handed a real
  character or relocated off `mob/playerTemp`'s default spot (BYOND's (1,1,1) origin —
  nothing gives playerTemp its own spawn, `world.mob = /mob/playerTemp` in Main.dm has
  no loc override). Previously this failed completely silently.
- **`IconSelect()`'s confirmed prompt wording**: CONFIRMED OG string table: "Who will
  you look like?" — was "Choose your icon:" with title "Icon Selection" before, neither
  of which matches the OG. Title shortened to "Icon" too (confirmed via live OG
  screenshot, 2026-08-25).
- **Stat allocation confirmation (2026-08-10)**: creation starts every stat at 1 (base
  mob default, PlayerTemplate.dm).

## Code/Admin/Debug/DebugTools.dm

- **Debug verbs header**: gated to Builder+ per `TODOList.md` Phase 9 ("currently
  unrestricted, no permission check at all — worth gating before this is ever run on a
  shared server").
- **`Debug_MeasureFont()`/`MeasureGlyph()`**: added 2026-08-29 because two prior
  guesses at HUD glyph spacing (too narrow, then too wide) both failed — real
  measurement beats a third guess. Two failed detection approaches before the current
  one: alpha-based (this icon format reports every pixel fully opaque, no usable alpha
  at all) and near-black color check (transparent pixels report as an EMPTY STRING
  from `GetPixel()`, not a color — `text2num("")` comes back 0, so "R/G/B all under 60"
  accidentally matched blank pixels too, same bug as the alpha attempt in a new
  shape). CONFIRMED 2026-08-29 via the color tally this proc prints: e.g. 'l' was 940
  blank pixels + 84 real #000000 pixels, adding up to the full 1024 (32x32) — blank IS
  the transparent background, a real color is ink, no darkness threshold needed at
  all. Report the output back so `HUD_GLYPH_SPACING`/`HUD_ROW_TOP`/`HUD_ROW_BOTTOM`
  (HUD.dm) can be set from real numbers instead of guesses.

## Code/Admin/Commands/GMCommands.dm

- **`GM_Announce()`**: confirmed OG presentation (real screenshot) — a plain "[GM] has
  an announcement" line, then the message on its own line, big/bold/red. Uses
  `players`, not `world <<`, matching the broadcast convention every other
  server-wide message in this codebase uses.
- **`GHOST_INVISIBILITY = 2`**: a regular player's `see_invisible` fluctuates between 0
  (indoors) and 1 (outdoors, so the roof itself becomes visible) via
  `area/ceiling`'s `Entered()`/`Exited()` — it never reaches 2, so this keeps ghosts
  hidden regardless of indoor/outdoor. Previously both systems used
  `invisibility`/`see_invisible = 1`, which meant any player standing outdoors (most of
  the map, most of the time) could actually see a "hidden" ghosted GM.
- **`ToggleGhostForm()`**: exit recomputes `see_invisible` fresh (matching whatever the
  roof system would set for a normal mob standing there) rather than hardcoding it —
  `get_area()` isn't available in this BYOND environment, `T.loc` (turf -> area) is the
  proven pattern used elsewhere. Enter sets `phase.dmi` directly on the mob (not a
  detached `client.images` overlay like before) so every existing flick()/icon_state-
  driven visual — attack, hit, sleep, weapon — just works off it the same way it
  already does for a normal player icon, instead of silently doing nothing to an
  invisible detached image that never tracked those state changes. The
  `PlaySFXAt()` call uses `channel = SFX_CHANNEL` explicitly — an unspecified channel
  still interrupts channel 1 area music in this BYOND version, same issue found and
  fixed for attack/hit/dodge sounds (CombatSystem.dm).
- **`GM_SwitchIcon()`**: the "Mob Icons/Custom GM" FILE_DIR already existed with real
  files in it and nothing pointing at them until this verb.
- **`GM_Ban()`/Ban List**: one combined verb instead of the OG's separate
  GMban/GMunban — a deliberate remake UX call, not confirmed-OG behavior. Bans are per-
  CHARACTER (one save slot), not per-account — the savefile and its other slots are
  untouched; the banned slot just can't be loaded (ShowLoginMenu(), LoginMenu.dm) and
  stops saving the moment it's banned (`skipSaveOnLogout`), so stats freeze at
  whatever was last saved rather than getting erased (that's `GM_Pwipe`'s job).
  Confirmed severity ordering: boot < pwipe < ban.
- **`ShowBanList()`**: confirmed OG fallback — an empty ban list shows a message
  instead of an empty picker.
- **`GM_Mute()`**: `GMCommandsReference.md`'s own spec just says "pick a target,
  confirm," no reason prompt like `GM_Ban`'s, since nothing forces a disconnect here
  for it to double as a parting message.
- **`GM_NameChange()`**: `MAX_NAME_LENGTH` is defined in the .dme (shared with
  LoginMenu.dm's own name validation).
- **`BuildPlayerStatusText()`**: EXP percent reuses `FormatPercent()` (StatPanels.dm)
  — the OG's own popup doesn't show the % sign, this one does, matching the Status
  panel instead since that's more useful for a debug dump.
- **`GM_CreateObj()`/door skins**: NPC included per its own note (NPCs.dm) — no
  dialogue/AI yet, just a placeable placeholder body for now.
- **Amulet shop stock (`CreateMerchant()`)**: each will start selling the moment its
  item category is built — Item and Amulet both have real goods now, the remaining
  three (Food/Drink/Weapons/Armor) open with an empty stock list, which `OpenShop()`
  already handles.
- **`GM_GlobalRespawn()`/`RespawnDefinition`**: confirmed 5-step spec (Name, Area,
  Monster type, Z level, Count) from `GMCommandsReference.md`.
- **`GM_SeeAreas()` — the lag it replaced**: originally snapshotted every turf in the
  WHOLE WORLD once on toggle — even batched across ticks to avoid a one-time freeze,
  that still left potentially thousands of persistent `/image` objects permanently
  tracked on one client, which the renderer has to composite every single frame
  regardless of whether they're on-screen. That was the actual ongoing lag source, not
  just the build loop — fixed by only building images for a small area around the GM
  and refreshing via a polling loop when they actually move to a new tile.

## Code/Admin/Commands/BuildTools.dm

- **`GM_MakeMob` note**: correcting an earlier design doc's `/mob/monster/*` — the
  actual base type built is `/mob/enemy` (MonsterRoster.dm). No exclusions needed in
  its picker — every `mob/enemy` subtype is a real, placeable monster; the old
  tier1/tier2 stat-template base types this used to filter out are gone, replaced by
  real per-monster OG stats.
- **`GM_MakeArea`'s night-area split**: night areas (snownight, rainnight,
  waternight1, deepwaternight, ...) are their own separate area TYPES, not a
  toggleable icon_state like turfs — split into their own list rather than mixed
  alphabetically with the day ones. Substring match (not `IsNightVariant`'s exact
  suffix) since some of these end in a digit after "night" (e.g. "Deepwaternight1").
- **`GM_MakeTool`**: confirmed OG text ("[Mode] tool selected.").

## Code/Player/Customization/PlayerIconColorPalette.dm

- **Soldier/Wizard's single "Main" zone**: sampled by loading the actual .dmi (PNG-
  formatted internally) and counting distinct pixel colors. Unlike dw3hero.dmi, which
  encodes Hair/Eyes/Main as three barely-distinguishable-but-genuinely-separate
  palette entries (0,124,254 / 0,124,250 / 0,124,255), dw3guard.dmi and
  dw3malewizard.dmi each only use one real costume color in the actual pixel data
  (plus a shared skin tone and white/near-white background/outline, neither
  customizable) — a real property of these two sprites, not a shortcut.
  PaletteManager.dm only ever iterates whatever zones are present in this list, so a
  missing Hair/Eyes/Accent entry just means that zone has no visible effect, not a crash.

## Code/World/Area.dm

- **World spawn markers**: confirmed OG names "playerstart" (login) / "playerspawn"
  (after-death respawn), confirmed distinct from each other
  (`GMCommandsReference.md`'s Builder tier section: GMseeareas shows login spawns and
  death/respawn spawns as separately-marked types). Matches the OG closer than an area
  would have too: GMmakestat (the OG's stat-object placement tool) lists both among
  its stat types, not among area types.
- **`SPAWN_MARKER_INVISIBILITY = 100`**: this high keeps markers unseen by every
  normal client regardless of indoor/outdoor `see_invisible` swings (`area/ceiling`'s
  `Entered()`/`Exited()` only ever sets 0 or 1) — "can only be seen as an area for GMs"
  means GM_SeeAreas' overlay specifically, not merely being a GM; nothing renders
  these directly, ever.
- **`GetRespawnTurf()` vs `GetPlayerSpawnTurf()`**: deliberately separate — confirmed
  OG design uses a different marker (church sign vs. wooden door) for after-death
  respawn than the world login point, not the same spot.

## Code/Save/SaveSystem.dm

- **`SetCharacterBanned()`**: stored as metadata alongside "[key].name" rather than
  inside the `CharacterSaveData` blob, same reasoning as the name field — checking/
  flipping ban status shouldn't require deserializing the whole save. The slot's
  actual data is never touched by this — banning freezes progress, it doesn't erase it.
- **`RebuildIcon()`'s `new /icon(...)` note**: must keep the leading slash — every atom
  has a built-in var also named "icon" (this mob's own sprite), so without the slash
  DM resolves the bare word to that var (null on a freshly loaded mob) instead of the
  `/icon` type, and crashes trying to instantiate type null.
- **`RebuildIcon()`'s recoloring scope**: only takes effect for icons that have real
  default-color data in `DefaultIconColors` — right now that's just Hero's
  dw3hero.dmi (plus Soldier/Wizard's DW3 icons). Everything else just shows its plain
  sprite.

## Code/Core/TextFilter.dm

- **`NormalizeLeet()`**: folds common leetspeak digit/symbol substitutions back to
  their letter, so "sh1t"/"5hit" still matches the plain word lists — done as plain
  substitution instead of regex char classes since there's no engine available to
  verify BYOND `/regex` behavior against right now. Every swap is one character for
  one character, so position/length in the caller's string stays untouched —
  `CensorText()` relies on that to keep slicing the ORIGINAL text while scanning this
  normalized copy.
- **`CensorText()`'s word-boundary check**: only matches whole words (checks the
  character immediately before/after each hit isn't a letter), so a banned word can't
  get flagged just because it's embedded inside an innocent longer word — e.g. banning
  "cunt" won't censor "Scunthorpe", banning "ass" won't censor "class." The classic
  "Scunthorpe problem" in content filtering.
- **Chat log date/IP formatting**: BYOND's own auto-timestamp is time-only
  ([HH:MM:SS]) — the OG excerpt only had a full date on the session-start/-end banner
  lines, not per-message — so a full date+time is written explicitly into every line
  here rather than relying on that. No IP on chat lines — confirmed from a real OG
  excerpt, only login/logout lines carry one (and those spell it into the sentence
  itself, "logs in at 1.2.3.4.", rather than going through `LogChat()`).

## Code/Combat/Skills/SkillDatum.dm

- **`Attack.OnUse()`'s Defend interaction**: can't hold a steady shield and swing a
  sword through it at the same instant, so the defend stance drops for the swing+
  recovery, same window canAct already covers. This dropped window is the main
  balance lever for Defend: attack a lot while defending and you spend most of your
  time unshielded (faster kills, less mitigation); attack rarely and you stay
  shielded most of the time (slower kills, more mitigation). On top of that,
  `GetAttackDelay()` also applies a small flat speed penalty when `wasDefending` —
  attacking out of a braced stance is a little slower to throw regardless.
- **Weapon-overlay duration (`PlayAttackAnimation()` call)**: stays at the default
  rather than scaling to `atkDelay` (the FULL windup+recovery) — tried that so a slow
  attacker's weapon would visibly linger, but that's wrong: the overlay is the SWING
  itself, not the whole recovery. At `atkDelay` length it visibly outlived the
  character's own attack pose (which reverts fast, independent of this) — "sword
  floating there after the player's already back to normal."
- **`DEFEND_TOGGLE_COOLDOWN`**: holding the numpad key down fires `UseSkillKey`
  repeatedly (same OS key-repeat that lets you hold-to-attack), and Attack's own
  canAct cooldown happens to swallow those repeats silently. Defend has nothing
  gating it the same way, so every repeat flipped the toggle again — rapid on/off/
  on/off while held instead of one clean toggle. This debounces it: short enough not
  to feel laggy on a deliberate press, long enough to eat the OS repeat rate.
- **Blaze's `PROJECTILE_SPEED_DIVISOR`**: for reference, a player moves one tile per
  1.36 deciseconds (step_delay, SmoothMovement.dm) — anything at or above that number
  here means the spell can be outrun on foot, which is exactly what the first
  playtest hit. These values put it roughly 2-4x player speed.
- **Blaze's skillName comment**: "no, we are not adding a THC damage-over-time
  effect, put the pipe down and finish reviewing the projectile code" — kept for
  color, not removed as noise.
- **Blaze's cast-meter bug history**: the meter never appeared at all in the first
  playtest — it was added once with no icon_state set (rendering nothing), and every
  subsequent frame assignment updated an object the overlays list no longer cared
  about, since BYOND's overlays list stores an immutable snapshot at add-time, not a
  live reference.
- **Blaze's death-mid-cast guard**: no interruption logic yet (confirmed, subject to
  change), but this stops it from launching off a corpse or stomping Die()'s own
  canAct lock — the same pre-existing gap Attack/Fireball had before this pass.
