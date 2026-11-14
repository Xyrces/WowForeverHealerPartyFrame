# In-game acceptance checklist

Status: **not yet run**. Target: WoW Forever **1.60.1.70862**, interface **16001**.

Record the client build, addon version, pass/fail results, and exact error text when testing. Run the initial checks in a quiet area with a cooperative party. The preview cannot validate casting.

## Load and appearance

- [ ] The addon appears in the AddOns list and loads without Lua errors.
- [ ] `/wpf test` shows four vanilla-style portraits with attached bars, class colors, numerical resources, and readable rates and aura rows. It is clearly a preview and clicking it casts nothing.
- [ ] Portrait hover reveals four distinct spell quadrants; leaving the portrait restores the portrait image.
- [ ] Test at the UI scale and screen resolution actually used in play. Names, resource totals, spell ranks, and timers do not overlap or become clipped.
- [ ] `/wpf unlock`, moving, `/wpf lock`, and `/wpf reset` behave as described. The saved position survives `/reload`.
- [ ] `/wpf blizzard` restores/hides native party frames and retains the choice after `/reload`.

## Simple settings and ranks

- [ ] `/wpf settings` contains one recipient-class selector, four healing slots, and buff slots; fresh profiles have no preassigned spells.
- [ ] Select Warrior and assign two ranks of one heal to different quadrants. The visible ranks match the spellbook.
- [ ] Assign different spells to Mage. Returning to Warrior retains the Warrior assignments.
- [ ] Drag a buff into the empty slot. Another empty slot appears, up to eight assigned buffs.
- [ ] Right-click a middle buff slot to clear it; remaining assignments stay intact and the empty slot can be reused.
- [ ] Dropping an item or other invalid cursor content does not erase the old spell or consume the cursor item.
- [ ] Assignments and exact ranks survive `/reload`.

## Live party actions

- [ ] Turn the preview off and join a party. Each visible name, portrait, class, HP, and resource bar matches the member.
- [ ] Target one member, then heal a different member through each configured portrait quadrant. The intended member receives the intended rank and the original target remains selected.
- [ ] Repeat with two ranks of the same heal, checking the cast/spellbook information and mana use as appropriate.
- [ ] Missing assigned buffs offer reapplication; clicking applies the selected rank to the displayed member without changing the current target.
- [ ] Right-click a buff to target its member. Holding Shift, Ctrl, or Alt while left-clicking a heal or buff still casts on the displayed member.
- [ ] Active buffs show their available timers/stacks. Let one expire and verify that its missing-state display returns.
- [ ] Apply another rank of an assigned buff and verify it is recognized as present when aura data is readable.
- [ ] Observe Weakened Soul on a party member while another member is targeted. Confirm it remains visible with other debuffs.
- [ ] Observe dead, disconnected, and out-of-range members; the display remains understandable and casts fail normally rather than hitting someone else.

## Rates and unavailable data

- [ ] On joining or changing zones, rates show a collecting/unavailable state until a complete five-second window is available.
- [ ] In a context allowing combat data, incoming damage raises damage/sec and effective healing raises healing/sec. Overhealing does not inflate healing/sec.
- [ ] The displayed delta equals healing/sec minus damage/sec, allowing for rounding. Activity ages out after five seconds, returning available idle rates to zero.
- [ ] If the client restricts combat or aura data, rates show dashes and unknown buffs are not falsely advertised as missing. `/wpf status` explains availability.

## Combat and roster stability

- [ ] Enter combat with spells configured. Existing healing and buff buttons still cast on the correct members without protected-action errors.
- [ ] Try changing or clearing settings in combat. The change is refused and assignments remain intact.
- [ ] Attempt movement/position commands in combat. Protected positions are not changed; no errors occur.
- [ ] Reorder a party containing different classes during combat. Each displayed name retains the appropriate class assignments and every cast still reaches that named member.
- [ ] Have a member leave and another join during combat. The newcomer is deferred until combat ends; no old button casts on the wrong class/member.
- [ ] After combat, verify the roster and new member's assignments update correctly.
- [ ] Members with unresolved names are not bound to class spells until their unique names become available. No frame labeled Unknown casts on a different member.
- [ ] Leave and rejoin the party, enter and exit a raid, change zones, and `/reload`. No stale party names, duplicate frames, or Lua errors remain.

## Result

- Client build:
- Addon version:
- Tester/date:
- Passed checks:
- Failed checks and reproduction steps:
- Lua error or protected-action message:
