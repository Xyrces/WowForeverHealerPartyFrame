# WoW Forever Party Frames

Vanilla-style party portraits and attached bars, with numerical health/resources, incoming healing and damage rates, visible debuffs, and class-based healing and buff assignments.

Version **0.1.0** targets **WoW Forever 1.60.1.70862**, interface **16001**. This is an initial build; it has **not yet been tested inside the game**. The [in-game checklist](tests/IN_GAME_CHECKLIST.md) covers the checks still needed.

## Install

1. Close WoW or return to character selection.
2. Extract `dist/WowfPartyFrames-0.1.0.zip` into your Forever client's `Interface/AddOns` folder. The resulting path should be `Interface/AddOns/WowfPartyFrames/WowfPartyFrames.toc`, with no extra nested folder.
3. Enable **WoW Forever Party Frames** in the character-selection AddOns list and log in.
4. Enter `/wpf settings` to assign spells, or `/wpf test` to inspect the noncasting preview.

Install into your own WoW Forever client's `Interface/AddOns` folder. Creating the package does not install it into the game.

## Set up spells

Select a **party-member class**, drag healing spells into the four portrait-quadrant slots, then drag buffs into the buff slots. Repeat for the classes you want to configure. There are no default spell assignments.

Use the exact rank you want from your spellbook: the addon saves that spell's ID instead of upgrading it to your highest rank. Different quadrants can contain different ranks of the same ability. Right-click a settings slot to clear it. Assignments save immediately and persist between sessions. Edits are locked during combat.

## Use the frames

- **Portraits and bars:** four party-member frames retain the vanilla silhouette, with class-colored names and numerical current/maximum health and resources.
- **Healing:** hover over a portrait to reveal four healing quadrants. Click a configured quadrant to cast its spell directly on that member without changing your current target.
- **Buffs:** each member displays the buffs assigned to their class. Missing buffs are highlighted for reapplication. Left-click casts the assigned spell directly on that member without changing your selected target; right-click targets them. Active buffs remain clickable for an early refresh. Another rank of the same buff can count as present; reapplication still uses your assigned rank.
- **Debuffs:** harmful effects remain visible without targeting the member. Readable Weakened Soul is prioritized. Timers and stacks appear when the client makes them available.
- **Rates:** healing received, damage taken, and their signed difference use a trailing five-second window. Healing excludes overhealing; damage excludes overkill and absorbed damage. `+5/s` means effective healing exceeded damage by five health per second over that window.

Rates show dashes while collecting a fresh window or when the client restricts the data. Unknown buff state is not treated as proof a buff is missing. These displays depend on the information the Forever client permits addons to read.

Existing member assignments stay attached to their names when the party order changes during combat. New members arriving during combat are configured after combat ends.

## Commands

| Command | Action |
| --- | --- |
| `/wpf settings` | Open the class, healing, and buff settings. |
| `/wpf unlock` | Allow moving the party frames outside combat. |
| `/wpf lock` | Lock their position. |
| `/wpf reset` | Restore the starting position. |
| `/wpf test` | Toggle a noncasting visual preview; preview values are examples. |
| `/wpf status` | Show addon and data-availability status. |
| `/wpf blizzard` | Toggle the native party frames; this choice is saved. |

Native party frames are hidden only after the replacement frames initialize successfully. Use `/wpf blizzard` outside combat to show them again if needed.

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
