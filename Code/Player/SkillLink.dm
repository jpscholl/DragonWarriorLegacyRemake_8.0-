// -----------------------------
// Clickable/draggable Skill Link — Battle tab numpad slots + Free Skills list
// -----------------------------
// Same mechanism as obj/StatLink (Code/Player/ClickableStats.dm) for the stat-alloc
// links — a real BYOND obj shown in the stat panel via stat(), not plain text, so it
// can be dragged. Confirmed OG behavior (ClassReference.md's "Skills vs. equipped
// skills" note): drag a known skill from Free Skills onto a numpad slot to equip it
// there (swaps with whatever was already in that slot), and drag an equipped skill
// back onto the Free Skills area to unequip it. Works both directions, and slot-to-slot
// dragging is a true swap.
//
// MouseDrop() fires on the DRAGGED object (src), not the drop target — `over` is the
// target. Easy to get backward (an earlier version of this file did), which is exactly
// why only one direction worked before: MouseDrop() was written as if it fired on the
// target instead.
obj/SkillLink
    var/mob/player/P
    var/datum/skill/S       // skill this link represents; null on an empty numpad slot
                              // or the dedicated Free Skills area marker
    var/slotNum = null      // numpad slot number if this is an equipped-slot link; null
                              // for a Free Skills entry or the Free Skills area marker

    New(mob/player/owner, datum/skill/skill, slot = null)
        ..()
        P = owner
        S = skill
        slotNum = slot
        UpdateName()

    proc/UpdateName()
        if(slotNum != null)
            name = "Numpad [slotNum]: [S ? S.skillName : "Nothing"]"
        else if(S)
            name = S.skillName
        else
            name = "Free Skills -"   // the dedicated Free Skills drop-target area marker

    // src is being dragged onto over. Two drop-target cases: a numpad slot (equip src's
    // skill there) or the Free Skills area/an existing free-skill link (unequip src).
    MouseDrop(atom/over)
        if(!P || usr != P) return
        if(!istype(over, /obj/SkillLink)) return

        var/obj/SkillLink/target = over
        if(target == src) return
        if(target.P != P) return   // can't drag onto someone else's panel

        if(target.slotNum != null)
            // Dropped onto a numpad slot — need something to actually equip.
            if(!S) return

            // True swap if src was itself an equipped slot: target's old skill takes
            // src's old slot. Dragging a Free Skill onto an occupied slot instead just
            // bumps the slot's old skill back to Free Skills (nowhere to put it) —
            // `skills`/known and `skillSlots`/equipped are tracked separately
            // (ClassReference.md's "Skills vs. equipped skills"), so it shows up there
            // automatically next refresh.
            var/datum/skill/displaced = target.S
            if(slotNum != null)
                P.skillSlots[slotNum] = displaced
            P.skillSlots[target.slotNum] = S
        else
            // Dropped onto the Free Skills area or an existing free-skill link —
            // unequip src if it was equipped. Dragging a Free Skill onto Free Skills
            // is already a no-op state, nothing to do.
            if(slotNum == null) return
            P.skillSlots[slotNum] = null

        // Immediate feedback — the next Stat() refresh would confirm this from
        // skillSlots either way, this just avoids a beat of stale display.
        UpdateName()
        target.UpdateName()

    // Double-clicking an equipped skill unequips it — same end state as dragging it
    // onto the Free Skills area, just a faster path.
    DblClick()
        if(!P || usr != P) return
        if(slotNum == null || !S) return

        P.skillSlots[slotNum] = null
        UpdateName()
