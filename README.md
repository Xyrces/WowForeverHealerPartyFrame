# WoW Forever Party Frames

Vanilla-style party portraits and attached bars, with numerical health/resources, incoming healing and damage rates, visible debuffs, and named healing and buff presets.

Version **0.4.0** targets **WoW Forever 1.60.1.70862**, interface **16001**. Portraits and healing controls now sit on the right of the bars. Choose full square buttons or circular portrait quadrants, with independent Base, Shift, Ctrl, and Shift+Ctrl assignments. Settings also open from the minimap's native AddOns menu. Existing presets and exact spell ranks migrate to Base without being changed. Offline tests and layout renders pass; in-game confirmation is pending. The [in-game checklist](tests/IN_GAME_CHECKLIST.md) covers the checks still needed.

The frames float directly over the game with no enclosing window, border, or background. The existing bar style, colors, and status-bar texture are retained. The silver trim uses the larger native player-frame artwork, with mirrored endcaps and a stretched straight center. Portraits are 82 UI units, healing buttons 36×36, bars 174 units wide, and rows 110 units apart. Aura rows fit below the bars without overlapping the healing controls. The solo preview uses the same geometry and saved position as the live frames. Settings remain a separate panel.

## Install

1. Close WoW or return to character selection.
2. Extract `dist/WowfPartyFrames-0.4.0.zip` into your Forever client's `Interface/AddOns` folder. The resulting path should be `Interface/AddOns/WowfPartyFrames/WowfPartyFrames.toc`, with no extra nested folder.
3. Enable **WoW Forever Party Frames** in the character-selection AddOns list and log in.
4. Enter `/wpf settings` to assign spells, or `/wpf test` while solo to inspect the noncasting preview. For an already-enabled installation updated on disk, enter `/reload` yourself to load the new files.

Install into your own WoW Forever client's `Interface/AddOns` folder. Creating the package does not install it into the game.

## Set up spells

Open **WoW Forever Party Frames** in the minimap's **AddOns** menu, or enter `/wpf`. Select a **preset**, select **Base**, **Shift**, **Ctrl**, or **Shift+Ctrl**, and drag spells into its four healing slots. Buffs are shared across those layers. The dropdown includes **New**, **Duplicate**, **Rename**, and **Delete** actions, a checkmark for the selection, and pages for longer lists. Name presets freely, such as Tank, Melee, or Caster. **Default** is always available and editable; it cannot be renamed or deleted. Fresh presets contain no assigned spells.

Use the exact rank you want from your spellbook: the addon saves that spell's ID instead of upgrading it to your highest rank. Different quadrants can contain different ranks of the same ability. Right-click a settings slot to clear it. Assignments save immediately and persist between sessions. Edits are locked during combat.

Under **Portrait controls**, choose **Buttons** for four full square icons on hover, or **Quadrants** to keep them inside the circular portrait. Both modes use the same sixteen assignments and positions. This display preference is saved and changes outside combat. The settings layer selects what you edit and what the solo preview demonstrates; live frames follow the modifier keys you hold.

Right-click a party member's frame, portrait healing quadrant, or buff button and choose **Assign preset**. The native menu retains its normal party actions, and the active preset is checked. The current preset also appears in the frame/spell tooltip; no permanent preset controls are added to the frames. Editing a preset updates everyone using it. Deleting one returns affected members to Default.

New party members receive Default. If you previously assigned another preset to that character, a small prompt offers **Confirm (10s)** or **Keep Default**. Timeout or dismissal keeps Default without forgetting the previous choice; explicitly selecting Default in the context menu does remember that choice. Each visible prompt has its own ten-second window, paused during combat and loading screens. Reordering the party or using `/reload` preserves current assignments and any remaining confirmation time. New logins and genuine rejoins offer remembered choices again. Remembered choices are separate for each of your characters and identify recipients by GUID, with realm-qualified names as a fallback. No messages are sent to party chat.

## Use the frames

- **Portraits and bars:** four floating party-member frames replace the native party frames, with class-colored names and numerical current/maximum health and resources. Their starting position follows the native party frame position; a custom position is preserved.
- **Healing:** hover over a portrait to reveal four healing buttons. Hold Shift, Ctrl, or both to select another group of four; the icons, ranks, and open tooltip update immediately. Click a configured button to cast that exact rank directly on the member without changing your current target. Empty slots do nothing, including an empty Base slot; Alt combinations also do nothing on healing controls. Left-click the name or bars to target normally. Spell tooltips open outside the party stack.
- **Buffs:** each member displays the buffs in their assigned preset. Missing buffs glow and show a `+` for reapplication. Left-click casts the assigned spell directly on that member without changing your selected target; right-click opens their native menu, including preset assignment. Active buffs remain clickable for an early refresh. Another rank of the same buff can count as present; reapplication still uses your assigned rank.
- **Debuffs:** harmful effects remain visible without targeting the member. Readable Weakened Soul is prioritized. Timers and stacks appear when the client makes them available.
- **Rates:** a two-sided bar matches the health and resource bars' width. Green healing fills from the left and red damage from the right; their relative shares determine where they meet. The numbers stay fixed: healing on the left, signed net in the center, damage on the right, all per second over a trailing five-second window. For example, `50/s | +5/s | 45/s` means healing exceeded damage by five health per second. Dark fills and outlined text keep the values readable. Larger values use compact notation such as `12.5k/s`; hovering the unit frame shows the rates without abbreviation. Healing excludes overhealing; damage excludes overkill and absorbed damage.

Rates show dashes while collecting a fresh window or when the client restricts the data; the center shows `...` during collection. Both fills clear when rates are unavailable or both rates are zero. An available zero still displays `0/s`, distinct from missing data. Unknown buff state is not treated as proof a buff is missing. These displays depend on the information the Forever client permits addons to read.

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
