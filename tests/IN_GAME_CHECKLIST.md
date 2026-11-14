# In-game acceptance checklist

Status: **not yet run**. Target: WoW Forever **1.60.1.70862**, interface **16001**.

Record the client build, addon version, pass/fail results, and exact error text when testing. Run the initial checks in a quiet area with a cooperative party. The preview cannot validate casting.

## Load and appearance

- [ ] The addon appears in the AddOns list and loads without Lua errors.
- [ ] While solo, `/wpf test` shows four floating vanilla-style frames with attached bars, class colors, numerical resources, and readable aura rows. There is no enclosing window, border, background, or close button. A small caption identifies the preview, class icons stand in for portraits, and clicking casts nothing.
- [ ] Portraits appear on the right of the bars. Portrait hover reveals four full square buttons in Buttons mode, or circular quadrants in Quadrants mode. Switching modes retains all spells, persists across reload, and is refused during combat. Leaving the controls restores the portrait.
- [ ] Test at the UI scale and screen resolution actually used in play. Names, resource totals, spell ranks, and timers do not overlap or become clipped.
- [ ] Check 82-unit portraits, 36×36 healing buttons, 174-unit bars, and 138-unit member spacing. The 12px history band fits below member details and above the health trim, without overlapping assigned role/marker icons. The existing native silver trim, green health and resource fills keep their appearance. Ranks remain inside both control styles; eight debuffs and eight combined buff icons fit on two rows without overlapping controls or information labels.
- [ ] Confirm level/class/assigned role text under the name, followed by the assigned role and party-marker icons, with the selected preset below the portrait. Assign/clear each marker in the native drawer and verify the corresponding icon appears/disappears immediately, including in combat. Clearing a native role removes its text and icon. Neither class nor preset creates an assignment. Long detail text must not push icons over the portrait; Offline/Dead sits on the name line. Solo preview invents no role or marker.
- [ ] Long preset names are available in the frame tooltip. A member in a different zone/dungeon shows that location; same-location members and unavailable data leave the location line empty. Changes and combat reorders must follow the correct member.
- [ ] Hover spells on the top and bottom member. Tooltips sit outside the party stack. Move the stack near the right edge and verify tooltips switch to its left.
- [ ] The minimap AddOns menu has exactly one WoW Forever Party Frames entry. Clicking opens the same settings as `/wpf`; repeated zoning/reload does not duplicate it.
- [ ] `/wpf unlock` reveals a text handle. Dragging and releasing moves the frames; `/wpf lock` hides the handle. `/wpf reset` places the frames at the native party-frame position. Preview and live frames share that position, and a custom position survives `/reload`.
- [ ] `/wpf blizzard` restores/hides native party frames and retains the choice after `/reload`.
- [ ] After a clean `/reload`, toggle `/wpf blizzard` twice, then enter combat. No native UnitFrame/TextStatusBar secret-value errors appear in the client log.

## Simple settings and ranks

- [ ] `/wpf settings` contains one preset selector, Base/Shift/Ctrl/Shift+Ctrl tabs, four healing slots, buff slots, and Buttons/Quadrants choices; fresh profiles have an empty editable Default preset.
- [ ] Existing named presets retain exact old spells in Base; the three new modifier layers start empty. Duplicate copies all layers independently.
- [ ] Existing nonempty class configurations migrate to named presets, preserving every assigned spell and rank. They are not automatically assigned by class.
- [ ] The preset dropdown has a native arrow graphic, hover/pressed feedback, and a selection checkmark. New, Duplicate, Rename, and Delete work; duplicate edits do not alter the source. Long lists paginate and keep management actions reachable. Default cannot be renamed or deleted.
- [ ] Create Tank and assign two ranks of one heal to different quadrants. The visible ranks match the spellbook.
- [ ] With the solo preview open, drop a different spell or rank into a settings slot. The cursor clears and both settings and the matching preview quadrant update immediately, with no Lua errors. Preview buttons still cast nothing.
- [ ] Assign different spells to Caster. Returning to Tank retains Tank's assignments.
- [ ] Clearing a spell also clears it in the open preview. Deleting the selected preset immediately displays Default and its spells in settings and preview.
- [ ] Drag a buff into the empty slot. Another empty slot appears, up to eight assigned buffs.
- [ ] Right-click a first, middle, or last buff slot to clear it; remaining assignments close the gap in settings, live frames, and preview. Other active buffs follow immediately, with no lost row capacity. Remaining buttons still cast their assigned exact ranks on the correct member. Reuse a cleared slot and reload a previously sparse preset; neither should leave gaps.
- [ ] Dropping an item or other invalid cursor content does not erase the old spell or consume the cursor item.
- [ ] Assignments and exact ranks survive `/reload`.
- [ ] Configure different exact ranks in the same slot across all four layers. Changing tabs shows the correct assignments and clearing one layer leaves the others unchanged. Buffs do not change with the selected layer.
- [ ] Preview demonstrates the selected editor layer while no modifier is held. Physically holding Shift/Ctrl/both overrides that preview layer; release returns to the selected editor layer. Preview never casts.

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

- [ ] Live health history remains hidden outside combat, appears with fresh samples on combat entry, and clears immediately on exit. Starting another fight never shows samples from the previous fight. The minimum-heal mouseover strip still works outside combat. Frame positions stay steady across the transition; `/wpf test` intentionally retains synthetic history for solo inspection.
- [ ] Watch a member take damage and receive healing in combat. The 12px band above health builds roughly three seconds of horizontal snapshots at quarter-second intervals, newest at bottom/oldest faded at top. No protected-value errors occur. Colors follow each sample's health remaining: green near full, yellow around 70%, orange around 45%, red around 15%; older rows retain their sampled color. Max-HP changes do not change the proportions of older rows.
- [ ] While history is moving, hover a direct heal, HoT, and shield on all modifier layers. The 2px bright preview overlays only the bottom two history rows and clears on leave, revealing history again. Native predictions remain inside the ordinary health bar; HP numbers remain actual HP. Check legibility at the UI scale used in play.
- [ ] Reorder the party during combat: history stays with the same named member. Have someone leave/disconnect and another join: no old samples appear on the new member. Zoning clears history and starts fresh on arrival. After a long client stall, the display starts fresh rather than filling the gap with invented values. `/wpf status` reports native history colors or an explicit fallback/unavailable state.
- [ ] Toggle solo preview off/on and open settings: synthetic history remains visible and uses the current preview values. It never enters live history after joining a party.
- [ ] Hover an assigned direct heal on an injured member: a 2 UI pixel green strip touches the top of the existing health trim, begins at current HP, and clips at the right edge. The tooltip's minimum matches that exact rank's spell description. Leaving the button clears it; existing health/mana bars and native incoming-heal indicators retain their appearance.
- [ ] Repeat with a HoT (segmented green), a combined direct heal + HoT, and a shield (patterned pale blue capacity from the left, including at full health). HoTs preview the full duration's described healing. Unsupported descriptions and empty slots show no strip; they must not reuse a previous spell's estimate.
- [ ] Hold Shift, Ctrl, Shift+Ctrl, and Alt without moving the pointer: the strip and tooltip follow the displayed layer and exact rank; Alt clears it. Repeat in combat, while health changes, after party reordering, and after zoning. No protected-value errors or stale previews remain. Check both Buttons and Quadrants, at the actual UI scale.
- [ ] Assign Renew/Rejuvenation or another HoT to a healing button, then apply it: the button keeps its assigned spell icon/rank and gains a green top edge/check with remaining time. Expiry/removal clears the mark. Repeat with two assigned ranks of that HoT, a shield, and a buff placed in a healing slot; same-name known ranks and another caster's matching aura also count as active. Timers must remain readable without covering the rank.
- [ ] Verify active marks on all modifier layers in combat. Leaving the portrait conceals them; moving to another member does not reuse the first member's marks. Combat party reordering and zoning keep marks on the correct person. Intentional refresh still casts the assigned exact rank with no target change; passive marks must not intercept left/right clicks.
- [ ] Cast a heal on an injured member and watch prediction extend their current health fill; cancel/finish it and verify the extension clears. Have someone else cast with none of your heals pending: their prediction and any following shield must begin at the correct position, without a gap. Health numbers and trim remain readable.
- [ ] Apply a shield at partial and full health. Partial-health shield fill/pattern must align after incoming heals; a shield exceeding the available bar space shows the right-edge glow, including at full health. Consumption/expiry clears it. Check zero-health/dead members for stale or misplaced indicators.
- [ ] Observe a healing-absorption effect: its pattern covers current health, incoming heals reduce the displayed remaining absorption, and overflow shows the left-edge glow. Removal clears the pattern and glow.
- [ ] Repeat prediction/shield checks in combat, after combat party reordering, and after zoning. Indicators stay attached to the same named member, respect the health-bar edges, and never block target/cast/context-menu clicks. `/wpf status` reports native health indicators separately from unavailable rates.
- [ ] Join a party while the preview is open. It closes automatically and live frames occupy the same position and use the same spacing. Each visible name, portrait, class, HP, and resource bar matches the member. `/wpf test` refuses to overlay sample frames while grouped.
- [ ] The native party-control drawer remains available in a real group, including its party-marker controls. Its absence in the solo sample preview is expected.
- [ ] Target one member, then heal a different member through each configured portrait quadrant. The intended member receives the intended rank and the original target remains selected.
- [ ] Repeat with two ranks of the same heal, checking the cast/spellbook information and mana use as appropriate.
- [ ] Missing assigned buffs offer reapplication; clicking applies the selected rank to the displayed member without changing the current target.
- [ ] Base, Shift, Ctrl, and Shift+Ctrl each cast the assigned rank on the displayed member, including when those modifiers are configured for self/focus casting in the game. Every click dispatches once. Empty healing slots and every Alt combination cast nothing; they never fall back to Base.
- [ ] While already hovering a healing button, press/release modifiers and verify its icon, rank, and tooltip update to the spell the next click casts. Repeat in combat with no protected-action errors.
- [ ] Right-click the body, healing buttons, and buffs with every modifier combination; the same native member menu and preset submenu remain available. Modified left-clicks on buffs retain their assigned buff and displayed member.
- [ ] Existing Shift/Ctrl keyboard binds outside these mouse controls still work. If another click-casting addon is enabled, check it does not take ownership of these same buttons.
- [ ] Active buffs show their available timers/stacks. Let one expire and verify that its missing-state display returns.
- [ ] Apply another known spellbook rank of an assigned buff and verify it is recognized in the same slot, including in combat. Change the configured rank outside combat and verify the active aura does not duplicate; a click must still use the newly assigned exact rank.
- [ ] `/wpf status` reports the built-in combat renderer on supported clients. Active Buffs and Debuffs keep their icons, remaining time, and stacks when combat starts; removals disappear normally and new auras appear. Expiring buffs do not vanish solely because the combat state changed.
- [ ] Reorder the party during combat and verify both native aura rows immediately follow the same named member as the health bars and click actions. An unresolved or failed native binding must never show a different member's auras.
- [ ] There is no separate Recast row. Native active icons remain clickable through to the underlying secure buff button; expiry reveals that same slot's `+`. Other helpful auras fill remaining slots without duplicating configured buff families. With all eight buff slots configured, extras are omitted; with none configured, up to eight active buffs remain visible.
- [ ] Known spell icons persist through combat. If an icon is still a question mark after reloading out of combat, record the configured spell and rank; this may indicate an unavailable or invalid spell ID rather than a display-state problem.
- [ ] Observe Weakened Soul on a party member while another member is targeted. Confirm it remains visible with other debuffs.
- [ ] Observe dead, disconnected, and out-of-range members; the display remains understandable and casts fail normally rather than hitting someone else.

## Compact layout

- [ ] Live frames and solo preview show no healing/damage/net bar, unavailable-rate placeholder, or rate tooltip. Debuffs sit directly below the resource bars with clearance for their icon rims; buffs and remote location follow without overlaps.
- [ ] Native healing and absorption indicators remain visible inside the health bars. Portraits, healing buttons, and preset labels keep their existing sizes and positions.

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
