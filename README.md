# Ports & Arc Helper

[![Tests](https://github.com/cloudygiraffe/Ports-Plugin/actions/workflows/tests.yml/badge.svg)](https://github.com/cloudygiraffe/Ports-Plugin/actions/workflows/tests.yml)

A RuneScape 3 plugin, built on the official Client API, that takes the
chores and guesswork out of **Player-owned Ports** and **The Arc**: reset
countdowns and reminders, warnings before rerolls are wasted, the Arc's daily
timetable, a crew optimizer, and a story helper for bringing the right
adventurers to your port.

> **Status: 0.1.0, in beta testing.** Everything that only needs the time
> works. Reading your port from the game is partly done: rerolls and the
> current voyage's requirements work, ships and crew don't yet. See
> [Roadmap](#roadmap). Not yet submitted to the Plugin Hub.

## Contents

- [Features](#features)
- [Installation (beta world)](#installation-beta-world)
- [Usage](#usage)
- [Permissions](#permissions)
- [How it works](#how-it-works)
- [Project structure](#project-structure)
- [Development](#development)
- [Roadmap](#roadmap)
- [Plugin guidelines](#plugin-guidelines)
- [Contributing](#contributing)
- [Licence and credits](#licence-and-credits)

## Features

The panel opens from the plugin's icon in the Plugins ribbon window. A
dropdown switches between five sections:

| Section | What it shows | Works today? |
|---|---|---|
| **Port overview** | Countdown to the daily reset (00:00 UTC) and the Wednesday reset (Meg, Black Marketeer, Advance Time); the next Barmaid's Tip; warnings such as rerolls about to be lost; Portnight streak | Countdowns and the reroll warning: yes. Ship, chime and trade-good warnings wait on port data. Portnight streak: hidden until voyages are recorded. |
| **Arc today** | Today's island bird and when it next appears; which castaway bottles are out today | Yes (fixed public schedules) |
| **Crew optimizer** | Enter (or let the game fill in) a voyage's Morale, Combat and Seafaring needs and get the captain and crew with the best success chance. Ties go to your lowest-level crew so they level up; one merchant on resource voyages. | The stat boxes fill in from the voyage you're looking at. Loading your crew roster is still to do, so the search has nothing to run on yet. |
| **Story helper** | Which port **icon** attracts each adventurer and the level-90 skill it needs; visit odds with 0–3 icons; each adventurer's six story voyages and the distance they need; the four trio storylines; joint-voyage partners; which storylines the Completionist, Master quest and Trimmed completionist capes need | Yes (static data from the RuneScape Wiki) |
| **Reminders** | Toggle each reminder: 1 hour before reset, Barmaid's Tip on Thursdays, the day before the Wednesday reset, an Arc bird about to appear | Yes |

Reminders appear as a gold line at the top of the screen that doesn't block
clicks, and in your chat box too if you allow the optional chat permission.

## Installation (beta world)

Plugins only run on the plugin beta world until Jagex approves them. Your
beta character is a copy of your live one, so nothing there affects your
real account.

1. Join the beta through [developer.runescape.com → Accessing the
   API](https://developer.runescape.com/rs/tutorial/1helloworld.html) and press
   **import save** in the lobby.
2. Copy the `ports-helper` folder into the beta client's `dev_plugins` folder,
   on Windows usually `C:\ProgramData\Jagex\RuneScape-BETA\dev_plugins`
   (create `dev_plugins` if it's missing).
3. Optionally copy `tools/ports-discovery` there too (see
   [Development](#development)).
4. Open the console in game with **Alt + the key under Esc**, then:

   | Command | Does |
   |---|---|
   | `prf` | Re-scan `dev_plugins` |
   | `plist` | List plugins and any load errors |
   | `pon ports-helper` | Turn the plugin on |
   | `prl ports-helper` | Reload after editing files |
   | `poff ports-helper` | Turn it off |

   After `prl`, close and reopen the panel so it's rebuilt by the new code.

## Usage

- **Give it the time once.** Open your port's **voyage list**. That stamps
  the current minute into a game variable, and the countdowns appear. Allowing
  the optional chat permission works too.
- **Crew optimizer:** pick a voyage in game and its three requirements appear
  in the plugin's stat boxes. Tick "Resource voyage" if a merchant would help,
  then press **Find best crew**. The search runs in small slices, so the game
  never stutters.
- **Story helper:** choose an adventurer, a trio or "Which storylines capes
  need" from the topic dropdown. The plugin remembers your last choice.

## Permissions

| Permission | Required? | Used for |
|---|---|---|
| `chatAccess` | Optional | Reminders also posted to your chat box; chat timestamps as a backup clock |

There are no web requests. Everything else comes from game variables, public
schedules and wiki data bundled with the plugin.

## How it works

**The clock.** The Client API has no clock, so the plugin learns the time
once and then counts the client's logic ticks (50 per second). Sources, best
first:

1. `os.time()`, if the plugin sandbox has it. It isn't documented, and it
   wasn't available on the beta world.
2. Chat message timestamps (optional `chatAccess`).
3. `POP_VOYAGE_LIST_TIMER_STARTED`, a VarClient the game sets to the current
   time, in **minutes since 1970**, when you open the voyage list. Confirmed
   on the beta world on October 22nd, 2026.
4. The RuneDate in the Captain's Log header, accurate to about 7 minutes. This
   needs the window's interface ID, which isn't known yet.

A worse source never overwrites a better one (`Clock.SyncWithQuality`).

**Port data.** `src/sources/port_vars.lua` reads port variables every few
seconds. None of them are documented; their IDs come from the client's own
variable lists (`pan VarPlayer` / `pan VarClient` in the console).

- **Rerolls left:** `POP_VOYAGE_REROLLS`, `POP_CREW_REROLLS`.
- **The voyage you're looking at:** `POP_VOYAGE_LIST_DIFF_GRAFT` / `_COMBAT` /
  `_SEAFARING`. The game calls Morale "graft".

[docs/VARIABLES.md](docs/VARIABLES.md) lists every port and Arc variable
found so far, with what's confirmed and what isn't.

**Reading windows (scaffold).** `src/sources/captains_log.lua` can read the
text of open port windows, such as the Captain's Log's RuneDate. It needs
their interface IDs, which the discovery tool finds. It's inactive until
those are filled in.

**Pure core, thin shell.** Everything that decides what to show is a pure
Lua module with unit tests. `main.lua` and `panel.lua` only wire game events
and UI. See [docs/DESIGN.md](docs/DESIGN.md).

## Project structure

```
ports-helper/                 the plugin (this folder goes in dev_plugins)
  plugin.json                 manifest: name, version, permissions, ribbon icon
  main.lua                    entry point: wires events, panel and modules
  src/
    clock.lua                 running clock from the best available time source
    timeutil.lua              UTC calendar maths and duration formatting
    runedate.lua              RuneDate <-> Unix time
    schedule.lua              daily/weekly resets, Barmaid's Tip
    arc_schedule.lua          Arc bird and castaway timetables
    port_state.lua            what's known about your port; Portnight days
    warnings.lua              reroll / cap / ship warnings
    reminders.lua             which reminders are due, once per occurrence
    optimizer.lua             captain + crew search, run in slices
    story.lua                 icons, storylines, trios, visit odds, page text
    display.lua               text for the overview, Arc and crew sections
    storage.lua               PersistentDB wrapper
    panel.lua                 the panel UI
    alert_line.lua            the on-screen reminder line
    sources/
      port_vars.lua           game variables (rerolls, voyage requirements, clock)
      captains_log.lua        open-window reader (scaffold)
      window_text.lua         collects the text of a game window
tools/ports-discovery/        developer tool for the beta world (not for release)
tests/
  run_tests.lua               unit tests (loads the other *_tests.lua files)
  mock_game_test.lua          main.lua against a strict fake game API
docs/
  DESIGN.md                   architecture and the maths behind each feature
  TESTING.md                  step-by-step beta-world test plan
  VARIABLES.md                port and Arc game variables reference
  RESEARCH.md                 Ports and Arc mechanics, sources and ideas
.github/workflows/tests.yml   CI: syntax check and both test suites
```

## Development

You need Lua 5.4 (5.3 works). Nothing else, since the test harness is built
in.

```sh
lua5.4 tests/run_tests.lua         # unit tests: schedules, Arc, RuneDate,
                                   # optimizer, warnings, reminders, story, variables
lua5.4 tests/mock_game_test.lua    # end-to-end: main.lua against a fake game
```

The fake game in `mock_game_test.lua` is strict: reading an API member it
doesn't define, or setting a component property the docs don't list, raises
an error. That keeps the plugin on documented API. CI runs both suites, plus
`luac5.4 -p` on every file, for every push and pull request.

**On the beta world,** `tools/ports-discovery` prints:

- `PORT VARS` blocks: a labelled snapshot of the known port variables, printed
  whenever one changes;
- `PORT WINDOW?` lines: open windows that look like port windows, with their
  interface IDs;
- `MATCH` / `CHANGE` lines from a name scan;
- port-related chat messages.

[docs/TESTING.md](docs/TESTING.md) has the full test plan, and
[CONTRIBUTING.md](CONTRIBUTING.md) the conventions.

## Roadmap

- [ ] **Load the crew roster** by decoding `POP_CREW_INV_VAR_0..29`
      (VarClients 2655–2684), so the optimizer works without typing anything.
- [ ] **Ship return alerts** from `LOCAL_NOTIFICATION_EVENT_PORTS_1..4_TIME` /
      `_ID` (VarClients 6715–6722), which look like the game's own per-slot
      return notifications, or from `POP_VOYAGE_n_DONE`.
- [ ] **Personal story progress:** match the game's adventurer numbers
      (`POP_ADVENTURER_n_*`, `POP_PORT_ADVENTURER_1/2_ID`) to names. The Story
      helper can then show your progress, who's in port today, and who to put
      icons on.
- [ ] **Confirm what the reroll variables mean.** The voyage reroll count is
      very likely "left today"; the crew reroll count is unchecked.
- [ ] **Record Portnight days** once a reliable "voyage sent" signal is found
      (`PortState.RecordVoyageSent` is ready; nothing calls it yet).
- [ ] Chime and trade-good cap warnings from `POP_PORT_RESOURCE_*` /
      `POP_PORT_GOODS_*`.
- [ ] Arc tracking: chimes sold today (`ELR1_SELL_PER_DAY`) and berry planter
      timers.
- [ ] Check the icon names against the in-game build menu.

## Plugin guidelines

- Reads only information the game already shows you, public schedules and
  wiki data.
- Never clicks, selects crew, sends ships or acts for you.
- The crew optimizer gives **actionable recommendations**, which Jagex's
  plugin guidelines list as subject to review. It only suggests; you still
  pick and send the crew yourself.
- One optional permission (`chatAccess`), explained in the panel.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for setup, conventions and the beta-world gotchas we've hit. Changes are
listed in [CHANGELOG.md](CHANGELOG.md).

## Licence and credits

- Code: [MIT](LICENSE).
- Game data in `src/story.lua`, `src/arc_schedule.lua`,
  `src/schedule.lua` and `docs/RESEARCH.md` comes from the
  [RuneScape Wiki](https://runescape.wiki) under
  [CC BY-NC-SA 3.0](https://creativecommons.org/licenses/by-nc-sa/3.0/).
- Not affiliated with or endorsed by Jagex. RuneScape is a trademark of Jagex
  Ltd.
