// -----------------------------
// Friendly NPCs
// -----------------------------
// Bare-bones placeholder — no dialogue/AI/movement yet, just a standing, non-hostile
// mob a GM can dress a town with (GM_CreateObj, Code/Admin/Commands/GMCommands.dm).
// One base type, not a hardcoded subtype per appearance — same "real behavior gets a
// subtype, a different sprite doesn't" convention Turfs.dm/Obj.dm already established.
// icon_state is picked at creation time from npc.dmi's real sprite set (merchant/
// guard/priest/etc.) via GetCachedIconStates() (Code/Combat/CombatSystem.dm), so a new
// sprite added to npc.dmi is selectable immediately, no code change needed here.
// Real dialogue/interaction/quest logic is a future system — this only exists so a GM
// has someone to place while that's being built.
mob/npc
    icon = 'npc.dmi'
    icon_state = "man"
    density = 1
