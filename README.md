# WoW Forever Party Frames

Vanilla-style party portraits and attached bars, with numerical health/resources, visible auras, and named healing and buff presets. Incoming combat rates require a client-accessible combat event feed; the current Forever API does not expose the old reader to addons.

Version **0.4.3** targets **WoW Forever 1.60.1.70862**, interface **16001**. Assigned tank/healer/damage icons and party markers (skull, star, moon, etc.) now appear beside the name. Written role labels are removed; unassigned icons are omitted. Active buffs and their reapply buttons continue to share one row, with native combat timers and exact-rank casting. Member details retain level, class, selected preset, and a different location when available. Portrait controls, modifier assignments, and bar artwork retain their previous behavior. Offline tests pass; in-game confirmation is pending. The [in-game checklist](tests/IN_GAME_CHECKLIST.md) covers the checks still needed.

The frames float directly over the game with no enclosing window, border, or background. The existing bar style, colors, and status-bar texture are retained. The silver trim uses the larger native player-frame artwork, with mirrored endcaps and a stretched straight center. Portraits are 82 UI units, healing buttons 36×36, bars 174 units wide, and member frames 138 units apart. Debuffs and buffs occupy two rows below the bars. A compact information line sits under the name, with the preset below the portrait and a remote location below the buffs. The solo preview uses the same geometry and saved position as the live frames. Settings remain a separate panel.

## Install

1. Close WoW or return to character selection.
2. Extract `dist/WowfPartyFrames-0.4.3.zip` into your Forever client's `Interface/AddOns` folder. The resulting path should be `Interface/AddOns/WowfPartyFrames/WowfPartyFrames.toc`, with no extra nested folder.
3. Enable **WoW Forever Party Frames** in the character-selection AddOns list and log in.
4. Enter `/wpf settings` to assign spells, or `/wpf test` while solo to inspect the noncasting preview. For an already-enabled installation updated on disk, enter `/reload` yourself to load the new files.

Install into your own WoW Forever client's `Interface/AddOns` folder. Creating the package does not install it into the game.

## Set up spells

Open **WoW Forever Party Frames** in the minimap's **AddOns** menu, or enter `/wpf`. Select a **preset**, select **Base**, **Shift**, **Ctrl**, or **Shift+Ctrl**, and drag spells into its four healing slots. Buffs are shared across those layers. The dropdown includes **New**, **Duplicate**, **Rename**, and **Delete** actions, a checkmark for the selection, and pages for longer lists. Name presets freely, such as Tank, Melee, or Caster. **Default** is always available and editable; it cannot be renamed or deleted. Fresh presets contain no assigned spells.

Use the exact rank you want from your spellbook: the addon saves that spell's ID instead of upgrading it to your highest rank. Different quadrants can contain different ranks of the same ability. Right-click a settings slot to clear it. Assignments save immediately and persist between sessions. Edits are locked during combat.

Under **Portrait controls**, choose **Buttons** for four full square icons on hover, or **Quadrants** to keep them inside the circular portrait. Both modes use the same sixteen assignments and positions. This display preference is saved and changes outside combat. The settings layer selects what you edit and what the solo preview demonstrates; live frames follow the modifier keys you hold.

Right-click a party member's frame, portrait healing quadrant, or buff button and choose **Assign preset**. The native menu retains its normal party actions, and the active preset is checked. The current preset appears below the portrait and in the frame/spell tooltip; the label adds no extra control. Editing a preset updates everyone using it. Deleting one returns affected members to Default.

New party members receive Default. If you previously assigned another preset to that character, a small prompt offers **Confirm (10s)** or **Keep Default**. Timeout or dismissal keeps Default without forgetting the previous choice; explicitly selecting Default in the context menu does remember that choice. Each visible prompt has its own ten-second window, paused during combat and loading screens. Reordering the party or using `/reload` preserves current assignments and any remaining confirmation time. New logins and genuine rejoins offer remembered choices again. Remembered choices are separate for each of your characters and identify recipients by GUID, with realm-qualified names as a fallback. No messages are sent to party chat.

## Use the frames

- **Portraits and bars:** four floating party-member frames replace the native party frames, with class-colored names and numerical current/maximum health and resources. Their starting position follows the native party frame position; a custom position is preserved.
- **Healing:** hover over a portrait to reveal four healing buttons. Hold Shift, Ctrl, or both to select another group of four; the icons, ranks, and open tooltip update immediately. Click a configured button to cast that exact rank directly on the member without changing your current target. Empty slots do nothing, including an empty Base slot; Alt combinations also do nothing on healing controls. Left-click the name or bars to target normally. Spell tooltips open outside the party stack.
- **Member details:** level and localized class appear under the name. Assigned role and skull/star/moon party-marker icons appear beside the name; neither is inferred from class or preset. Roles mirror the native party frames' assignment API, which does not report whether a human manually selected the assignment. Missing assignments show no icon. The selected preset appears below the portrait; hover the frame for its full name. A location appears only when public map data establishes a different zone or dungeon. Floors in the same dungeon and submaps in the same zone share a location; a dungeon remains distinct from its outdoor zone. Unavailable details are omitted. Labels refresh once per second and immediately when their unit, preset, or party marker changes. Solo preview does not invent assigned roles or markers.
- **Buffs:** configured spells keep fixed positions in one Buffs row. An active native aura covers its reapply button with the icon, timer, and stacks; when absent, the same slot shows the assigned spell with a `+`. Left-click always casts the assigned exact rank on that member without changing your selected target; right-click opens their native menu, including preset assignment. Known spellbook ranks with the same localized name count as one buff family for display, without changing the casting rank. Other active helpful auras fill the remaining slots after the last configured buff, excluding those families. The row holds eight icons total. Cached public spell metadata retains known icons when later API responses are unavailable. On clients lacking native containers, configured buffs use public reads and show `?` for unknown status.
- **Debuffs:** harmful effects remain visible without targeting the member. The native container renders icons, timers, and stacks inside the client without exposing aura data to the addon. Both aura rows follow the frame's current unit, including combat party reordering. A compatibility fallback uses permitted public aura reads when the native container API is unavailable; it cannot display data the client completely withholds. `/wpf status` reports which renderer is active. Readable Weakened Soul is prioritized in the fallback.
- **Rates:** a two-sided bar matches the health and resource bars' width. Green healing fills from the left and red damage from the right; their relative shares determine where they meet. The numbers stay fixed: healing on the left, signed net in the center, damage on the right, all per second over a trailing five-second window. For example, `50/s | +5/s | 45/s` means healing exceeded damage by five health per second. Dark fills and outlined text keep the values readable. Larger values use compact notation such as `12.5k/s`; hovering the unit frame shows the rates without abbreviation. Healing excludes overhealing; damage excludes overkill and absorbed damage.

The rate bar shows **Collecting rates...** for a fresh window and **Rates unavailable** when there is no usable feed. Both fills and previous numbers clear when unavailable. An available zero still displays `0/s`, distinct from missing data. `/wpf status` distinguishes missing APIs, explicit restrictions, and unavailable unit data.

**Current rate limitation:** Forever moved its event reader into [C_CombatLogSecure](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua), which is restricted to the secure environment. The old addon reader is absent; removing a combat guard cannot restore it. Native damage-meter session aggregates do not supply the required incoming healing stream. This build does not claim to restore live healing received/sec, damage taken/sec, or their delta on a restricted client. It preserves the calculation for supported public feeds, fixes unrelated events incorrectly resetting its window, and displays its actual availability. Preview values are sample data only.

Existing member assignments stay attached to their names when the party order changes during combat. New members arriving during combat are configured after combat ends.

Modifier actions are configured through the client's secure click buttons before combat. No global keyboard bindings are installed or changed. Self/focus/mouseover-cast modifiers cannot redirect these buttons away from their party member; right-click still opens that member's native menu with any modifier. Buff clicks retain their existing behavior across modifiers. Other click-casting addons should not register or modify these same buttons; overlapping addons cannot be guaranteed to coexist.

## Commands

| Command | Action |
| --- | --- |
| `/wpf settings` | Open the preset, healing, and buff settings. |
| `/wpf unlock` | Allow moving the party frames outside combat. |
| `/wpf lock` | Lock their position. |
| `/wpf reset` | Move to the native party frame position. |
| `/wpf test` | While solo, toggle a noncasting preview at the live frame position. |
| `/wpf status` | Show addon and data-availability status. |
| `/wpf blizzard` | Toggle the native party frames; this choice is saved. |

Native party frames are hidden only after the replacement frames initialize successfully. Use `/wpf blizzard` outside combat to show them again if needed.

The game's native party-control drawer for markers such as star, moon, and skull remains untouched. It appears when you are in a real group; a solo `/wpf test` preview does not create a group or open that drawer.

Unlocking reveals a small text handle above the frames. Drag it and release to apply the new position, then lock it again. The preview uses class icons instead of character portraits, shows the exact preset selected in settings (including empty slots), and closes when you join a group. Live frames show the actual party members' portraits and assigned presets. Right-click assignment and remembered-player prompts require a real party.

## Validation

Off-client Lua tests cover calculations, aura handling, saved profiles, and spell assignment. They cannot establish the appearance or protected casting behavior of the actual game client. Complete the [in-game checklist](tests/IN_GAME_CHECKLIST.md) before relying on this build in a dungeon.

## Developer validation

From the source repository, use Python 3.10 or newer:

```text
python -m pip install -r requirements-test.txt
python tests/run_tests.py
python tools/package.py
```

Tests use Lupa's Lua 5.1 runtime. The packaging script uses only the Python standard library, verifies the TOC file list and archive checksums, and writes the addon ZIP plus a `.zip.sha256` file under `dist`. It includes only the addon and user documentation, and does not install anything into the game.
