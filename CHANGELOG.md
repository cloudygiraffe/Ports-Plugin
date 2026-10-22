# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased] — 0.1.0

First version, in testing on the plugin beta world. Not yet submitted to the
Plugin Hub.

### Added

- **Port overview:** countdowns to the daily reset and the Wednesday reset
  (Meg, Black Marketeer, Advance Time); the next Barmaid's Tip; a warning
  before unused rerolls are lost at reset. The Portnight streak is hidden
  until voyages are recorded.
- **Arc today:** today's island bird, its next appearance (every 30 min 30 s
  from 00:00 UTC, about 10 minutes each), and the castaway bottles out today.
- **Crew optimizer:** exhaustive captain and crew search, run in slices so it
  never stutters the game. Ties go to the lowest-level crew; at most one
  merchant, preferred on resource voyages. The stat boxes fill in from the
  voyage shown in the game's voyage list.
- **Story helper:** port icon and skill for each adventurer, visit odds with
  0–3 icons (the wiki's formula), story voyage regions and distances, the four
  trio storylines, joint-voyage partners, and which storylines each cape needs.
- **Reminders:** on-screen gold line, optionally in chat as well. Each can be
  switched on or off: 1 hour before reset, Barmaid's Tip, the day before the
  Wednesday reset, Arc bird spawning.
- **Clock with no permissions**, from the `POP_VOYAGE_LIST_TIMER_STARTED`
  game variable (minutes since 1970), with chat timestamps and the Captain's
  Log RuneDate as other sources.
- **Game-variable reader** (`sources/port_vars.lua`) for rerolls and the
  current voyage's requirements.
- **Captain's Log reader scaffold** (`sources/captains_log.lua`), inactive
  until window IDs are known.
- **`tools/ports-discovery`:** variable scan, a `PORT VARS` snapshot,
  `PORT WINDOW?` finder and port chat log for the beta world.
- Unit tests, a strict fake-game end-to-end test, and CI.
- Docs: design, beta test plan, game-variable reference, and research notes.

### Fixed

- The plugin and discovery tool load on the October 22nd, 2026 beta client,
  which rejects an empty `"requiredDependencies": []` in `plugin.json`.
- The discovery tool no longer floods the console. Whole-word name matching
  stops `ARCHAEOLOGY_*` and `POPUP_*` matching, changes are rate-limited, and
  it skips the plugin's own panel.
