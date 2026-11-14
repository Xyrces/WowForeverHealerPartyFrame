# Release history

## 0.10.0 — native party information

Added Forever surname formatting, native member tooltips, phase/shard and summon indicators, leader/guide and PvP badges, ready checks, disconnect/dead/ghost treatment, low-health/threat warnings, native voice activity, and optional party pets. A hover panel exposes native aura overflow and dispel-colored borders. Portraits honor the native class-portrait preference. The existing Portrait controls labels remain Buttons and Quadrants.

Shard confirmation is offered only for an existing server-requested transfer, outside combat; cancellation invalidates the offer even if the countdown briefly remains positive. No arbitrary member-to-member shard jump is added. Secure pet targeting, hover tooltips, and retained ready-check results follow member identity through party reorders. Offline pet owners hide outside combat; in combat a still-visible native-watched pet clears stale data and reports Owner offline.

Validation: 27 Lua syntax checks and 30 isolated suites, source audit and Astra review, plus offline renders of both portrait-control styles. Engine-level casting, native aura interaction, voice activity, and combat visuals still require client verification. Conditional shared-client capabilities and the pet offline limitation are documented in the README. This release has its own development commit.

## 0.9.0 — radial cleanse controls

Cleanse actions now use custom curved artwork on the portrait's right side. Quadrants keeps a compact ring; Buttons leaves room around the full square healing controls. Both styles retain their existing settings choice, exact spell ranks, modifier targeting and native member menus. Idle arcs remain visibly grey; native aura displays add color, timers and glow when applicable. One action occupies the upper quadrant, two use right quadrants, and three/four divide the right half into smaller arcs.

Fixed secure input strips stay inside the visible curves and cast on mouse press, avoiding release cancellation when the pointer crosses a strip boundary. Healing controls take precedence in overlaps. Style changes, assignment changes and cleanup run outside combat. Stack spacing, preset labels, drag handles and screen bounds adapt to the selected style; health/resource bar artwork and dimensions are unchanged.

Validation: 23 Lua syntax checks, 26 isolated test suites, reproducible artwork/package checks and offline renders of both styles. Astra reviewed the secure/native boundaries after AGY exhausted its quota. Live client casting and rendering still need confirmation. This change has its own development commit; it is not a reconstructed snapshot.

## Recovered releases through 0.8.1

Twenty saved release packages were imported on November 14, 2026. Each snapshot has its own commit, preserving its Lua and TOC files byte for byte. Each package was checked against its saved SHA-256 sidecar before import.

**This is reconstructed release history, not the original development log.** Commit dates reflect reconstruction time. Intermediate edits, original authorship/timestamps and historical test versions were not recovered. The final publication commit adds the current tests, packaging tools and continuous checks.

Packaged README/checklist files were moved to their repository locations, their checklist links adjusted, and a machine-specific installation-directory paragraph replaced with generic instructions. No executable addon source was rewritten during reconstruction.

Tags before v0.8.1 mark reconstructed snapshots. The v0.8.1 tag marks the final publication commit, which has the same addon Lua/TOC as its recovered snapshot plus current development files and public-facing documentation.

The [provenance manifest](history/recovered-releases.json) records original archive hashes, snapshot commits and per-file source hashes. The installable v0.8.1 release archive is rebuilt with publication documentation, so its release checksum differs from the original local archive recorded in that manifest.

Older snapshots preserve bugs and superseded behavior. In particular, v0.8.0 displayed cleanse alerts but its embedded casting did not work; use the current release. Offline test success does not establish in-game protected execution or rendering.

| Version | Recovered change | Snapshot |
| --- | --- | --- |
| 0.1.0 | Initial party frames, numeric resources, rate tracking, debuffs and class-based healing/buff assignments. | [9ff0ad0f](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/9ff0ad0f8c8506a1e789fd6347863b7718016391) |
| 0.2.0 | Replaced enclosing windows with floating vanilla-style frames; shared live/preview geometry and movable placement. | [25b07178](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/25b07178968e11449c74d2c53e4bc6fdbef32235) |
| 0.2.1 | Reduced oversized portraits, bars and row spacing; improved native dropdown artwork and readable proportions. | [01c66787](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/01c667877548ef3838ca3a1924f47360c7826af6) |
| 0.2.2 | Aligned rate statistics with the resource bars in a two-sided healing/damage display with a centered net value. | [8b96d266](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/8b96d2666a5adab2ade792c0f2d9f1c363c065d5) |
| 0.2.3 | Fixed portrait-hover errors interrupting spell drops and refreshed open previews after assignment changes. | [8ddfa6b3](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/8ddfa6b3b3c3123c1822f689fc303d3c41424c7f) |
| 0.3.0 | Replaced class auto-assignment with named presets, remembered member assignments and native right-click menus. | [72494734](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/724947349b048e7eb7d94e34685ecb19e24d3b46) |
| 0.3.1 | Fixed preset-dropdown startup failure that prevented /wpf from opening. | [2f83cd4d](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/2f83cd4d336fc79cbb77380fff93636d921d1228) |
| 0.4.0 | Moved portraits right, enlarged controls, added square/quadrant styles and modifier layers, and registered the minimap AddOns entry. | [99c978e4](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/99c978e4d3cada3cd6fd2142a7474c49d64cfb55) |
| 0.4.1 | Added native combat aura rendering and timers; corrected restricted aura reads and native-frame update taint. | [c9b88881](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/c9b8888162ff70db5bb7098d9187c5a1d5a42cb7) |
| 0.4.2 | Unified active buffs with reapply controls and added level, class, assigned role, preset and remote-location details. | [aed7ece5](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/aed7ece5c267f8b52c0ff7501f9b4e1155d55aa2) |
| 0.4.3 | Added assigned role and party-marker icons while temporarily removing the written role label. | [8cd27d37](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/8cd27d373d6155c94832dffb19cebf059dfcf368) |
| 0.4.4 | Restored assigned role text alongside role and marker icons. | [21d20637](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/21d206374fc478de91fa425061df5a3558984a36) |
| 0.4.5 | Compacted buff slots after removal, including existing saved gaps and preview rows. | [7c444cdb](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/7c444cdbbfd59e5ac03e7afb6cfa700634308f0c) |
| 0.5.0 | Added native incoming-heal, damage-absorption and healing-absorption indicators and overflow glows. | [807e9b22](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/807e9b2204c7a147013e510eaffc75606bf96cb4) |
| 0.5.1 | Removed the unavailable healing/damage rate bar and reclaimed its space while preserving native predictions. | [161c8935](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/161c89359796c603e6e380cc7f8e15ec8fcffecc) |
| 0.6.0 | Added minimum-effect healing mouseover previews and active HoT/buff markers on assigned skills. | [8a5fbe16](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/8a5fbe1680312ff1ba252601761b2464b5a94cef) |
| 0.7.0 | Added twelve health-history samples above the health bar, with gradient colors and overlaid hover predictions. | [30357328](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/30357328551126341e91ba61ba36cc3ef2587174) |
| 0.7.1 | Limited live health history to combat and cleared it between fights. | [cb460691](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/cb46069121164ab2a9c25499df974e611c85b1ca) |
| 0.8.0 | Added cleanse configuration/native alerts and linked history step/total settings; its embedded cleanse casting was later found not to work. | [7a0b2208](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/7a0b22083b6d38eb0145cefe3f647f42a2cd2a6f) |
| 0.8.1 | Separated visible secure cleanse actions from native alerts, with grey-to-color/glow states, and explicitly enabled ordinary debuff hover details. | [307e0714](https://github.com/Xyrces/WowForeverHealerPartyFrame/commit/307e0714a159e5d5618244a77074a1526738016b) |
