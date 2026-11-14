# In-game acceptance checklist

Status: **not yet run**. Target: WoW Forever **1.60.1.70862**, interface **16001**.

Record the client build, addon version, pass/fail results, and exact error text when testing. Run the initial checks in a quiet area with a cooperative party. The preview cannot validate casting.

## Load and appearance

- [ ] The addon appears in the AddOns list and loads without Lua errors.
- [ ] While solo, `/wpf test` shows four floating vanilla-style frames with attached bars, class colors, numerical resources, and readable rates and aura rows. There is no enclosing window, border, background, or close button. A small caption identifies the preview, class icons stand in for portraits, and clicking casts nothing.
- [ ] Portrait hover reveals four distinct spell quadrants; leaving the portrait restores the portrait image.
- [ ] Test at the UI scale and screen resolution actually used in play. Names, resource totals, spell ranks, and timers do not overlap or become clipped.
- [ ] Check the compact proportions against the native party frames: 54-unit portraits, 110-unit bars, and 90-unit row spacing. Bottom healing-quadrant rank labels stay inside the portrait, and three/four-digit rates remain readable.
- [ ] `/wpf unlock` reveals a text handle. Dragging and releasing moves the frames; `/wpf lock` hides the handle. `/wpf reset` places the frames at the native party-frame position. Preview and live frames share that position, and a custom position survives `/reload`.
- [ ] `/wpf blizzard` restores/hides native party frames and retains the choice after `/reload`.

## Simple settings and ranks

- [ ] `/wpf settings` contains one preset selector, four healing slots, and buff slots; fresh profiles have an empty editable Default preset.
- [ ] Existing nonempty class configurations migrate to named presets, preserving every assigned spell and rank. They are not automatically assigned by class.
- [ ] The preset dropdown has a native arrow graphic, hover/pressed feedback, and a selection checkmark. New, Duplicate, Rename, and Delete work; duplicate edits do not alter the source. Long lists paginate and keep management actions reachable. Default cannot be renamed or deleted.
- [ ] Create Tank and assign two ranks of one heal to different quadrants. The visible ranks match the spellbook.
- [ ] With the solo preview open, drop a different spell or rank into a settings slot. The cursor clears and both settings and the matching preview quadrant update immediately, with no Lua errors. Preview buttons still cast nothing.
- [ ] Assign different spells to Caster. Returning to Tank retains Tank's assignments.
- [ ] Clearing a spell also clears it in the open preview. Deleting the selected preset immediately displays Default and its spells in settings and preview.
- [ ] Drag a buff into the empty slot. Another empty slot appears, up to eight assigned buffs.
- [ ] Right-click a middle buff slot to clear it; remaining assignments stay intact and the empty slot can be reused.
- [ ] Dropping an item or other invalid cursor content does not erase the old spell or consume the cursor item.
- [ ] Assignments and exact ranks survive `/reload`.

## Preset assignment and remembered choices

- [ ] New members use Default regardless of class. Right-click the frame body, a portrait quadrant, or a buff: the normal native actions remain, with Assign preset and a checkmark beside the active preset. Long preset submenus scroll.
- [ ] Assign Tank to a druid and then Caster to the same player. The four heals and buffs change immediately; name color remains the druid class color. The active preset appears in tooltips, with no added permanent frame controls.
- [ ] Edit an assigned preset and verify every member using it updates. Delete it and verify those members return to Default, with stale remembered references cleared.
- [ ] Have a previously assigned player leave and rejoin. Default is active while the ten-second remembered-preset prompt is visible. Confirm applies the named preset to that player.
- [ ] Let a prompt expire, or click Keep Default: Default stays active. Rejoin again and verify the previous preference is still offered. Explicitly choose Default in the right-click menu and verify that choice replaces the remembered preference.
- [ ] Multiple joining players receive independent prompts. Reordering the party cannot apply one player's suggestion to another. A departed player's old menu cannot change another member's preset.
- [ ] `/reload` keeps current assignments and remaining prompt time without new prompts. A new login offers remembered choices again. Different characters' remembered choices remain separate.
- [ ] Combat and loading screens hide prompts and pause their remaining time. The preset menu refuses changes during combat, including when combat begins after opening it. After combat, prompts and assignments reconcile with the current roster.

## Live party actions

- [ ] Join a party while the preview is open. It closes automatically and live frames occupy the same position and use the same spacing. Each visible name, portrait, class, HP, and resource bar matches the member. `/wpf test` refuses to overlay sample frames while grouped.
- [ ] The native party-control drawer remains available in a real group, including its party-marker controls. Its absence in the solo sample preview is expected.
- [ ] Target one member, then heal a different member through each configured portrait quadrant. The intended member receives the intended rank and the original target remains selected.
- [ ] Repeat with two ranks of the same heal, checking the cast/spellbook information and mana use as appropriate.
- [ ] Missing assigned buffs offer reapplication; clicking applies the selected rank to the displayed member without changing the current target.
- [ ] Right-click a buff to open its member's native menu. Holding Shift, Ctrl, or Alt while left-clicking a heal or buff still casts on the displayed member.
- [ ] Active buffs show their available timers/stacks. Let one expire and verify that its missing-state display returns.
- [ ] Apply another rank of an assigned buff and verify it is recognized as present when aura data is readable.
- [ ] Observe Weakened Soul on a party member while another member is targeted. Confirm it remains visible with other debuffs.
- [ ] Observe dead, disconnected, and out-of-range members; the display remains understandable and casts fail normally rather than hitting someone else.

## Rates and unavailable data

- [ ] On joining or changing zones, rates show a collecting/unavailable state until a complete five-second window is available.
- [ ] The rate bar shares the exact left and right edges of the health and resource bars. Healing is the left number, net the center number, and damage the right number. All three remain readable as the fills move.
- [ ] In a context allowing combat data, incoming damage increases the red portion from the right and effective healing increases the green portion from the left. The split shows their relative proportions. Overhealing does not inflate healing/sec.
- [ ] The displayed delta equals healing/sec minus damage/sec, allowing for rounding. Activity ages out after five seconds, returning available idle rates to zero.
- [ ] Equal nonzero rates split the bar evenly. Healing-only is green, damage-only is red, and zero/zero leaves an empty track with zero values. Unavailable data clears old fills and numbers. Large values fit using compact notation, with unabridged rates in the unit tooltip.
- [ ] If the client restricts combat or aura data, rates show dashes and unknown buffs are not falsely advertised as missing. `/wpf status` explains availability.

## Combat and roster stability

- [ ] Enter combat with spells configured. Existing healing and buff buttons still cast on the correct members without protected-action errors.
- [ ] Try changing or clearing settings in combat. The change is refused and assignments remain intact.
- [ ] Attempt movement/position commands in combat. Protected positions are not changed; no errors occur.
- [ ] Reorder a party containing different classes during combat. Each displayed name retains its assigned preset and every cast still reaches that named member.
- [ ] Have a member leave and another join during combat. The newcomer is deferred until combat ends; no old button casts on the wrong member.
- [ ] After combat, verify the roster and new member's assignments update correctly.
- [ ] Members with unresolved names are not bound to spells until their unique names become available. No frame labeled Unknown casts on a different member. Temporarily unresolved roster entries do not erase existing preset choices.
- [ ] Leave and rejoin the party, enter and exit a raid, change zones, and `/reload`. No stale party names, duplicate frames, or Lua errors remain.

## Result

- Client build:
- Addon version:
- Tester/date:
- Passed checks:
- Failed checks and reproduction steps:
- Lua error or protected-action message:
