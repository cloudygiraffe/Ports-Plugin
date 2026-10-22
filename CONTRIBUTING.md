# Contributing

Thanks for helping. This plugin is small and the codebase is meant to be easy
to pick up, so this page is short.

## Setup

- **Lua 5.4** (5.3 works). On Debian/Ubuntu: `sudo apt-get install lua5.4`.
  On Windows, any Lua 5.4 build. There's nothing else to install.
- From the repository root:

  ```sh
  lua5.4 tests/run_tests.lua
  lua5.4 tests/mock_game_test.lua
  ```

  Both must pass before a pull request. CI runs them, plus a `luac5.4 -p`
  syntax check on every file.

- For in-game testing you need access to the plugin beta world. See the
  README's [Installation](README.md#installation-beta-world) section and
  [docs/TESTING.md](docs/TESTING.md).

## How the code is organised

- **Pure core, thin shell.** Anything that decides *what* to show (schedules,
  warnings, reminders, the optimizer, story text, number formats) is a module
  with no game calls, covered by unit tests. Only `main.lua`, `panel.lua`,
  `alert_line.lua`, `storage.lua` and `src/sources/*` touch the game API.
- **Modules are plain tables.** `local X = {} ... return X`, loaded with
  `require("src/name")`. Paths are relative to the plugin root.
  Constructor-style objects use `X.__index = X` and `setmetatable`.
- [docs/DESIGN.md](docs/DESIGN.md) explains how the pieces fit, and the maths
  behind the optimizer, clock and visit odds.

## Conventions

- 4-space indentation, `camelCase` locals, `PascalCase` module functions,
  `UPPER_CASE` constants.
- **Every file starts with a header comment**: what it does, where it fits,
  and its current status. Every public function says what it takes and
  returns. Explain *why*, not just *what*, wherever the reason isn't obvious.
- **Wrap every game API call in `pcall`.** The API is new and some behaviour
  is undocumented, and a failed read must never take the plugin down. Check
  types on anything read back.
- **Use only documented API.** Don't set component properties the docs don't
  list; the fake game in `tests/mock_game_test.lua` fails if you do. Anything
  you rely on that you've only *observed* gets a comment saying so, with the
  date: "observed on the beta world, October 22nd, 2026".
- **Undocumented game variables** go in `src/sources/port_vars.lua` with their
  ID, name and status (CONFIRMED / LIKELY / TO CONFIRM), and in
  [docs/VARIABLES.md](docs/VARIABLES.md).
- **PersistentDB is shared by every character on the computer.** Anything
  per character goes under a key that includes the character's name (see
  `storage.lua`).
- **Keep per-tick work tiny.** `Event.Logic` fires 50 times a second and only
  advances the clock. Heavy work runs on `Event.ServerLogic` (every 0.6 s), and
  long jobs are sliced across ticks the way the optimizer is (`Job:Step`).
- **Refill lists with `List:SetEntries`.** On the beta client
  (October 22nd, 2026), `Clear()` followed by `Add()` left stale rows behind.
- Markup in text: `<br>` for line breaks, `<col=RRGGBB>…</col>` for colour.
- Dates in docs and comments are written out US-style: "October 22nd, 2026".

## Adding tests

- Unit tests: add a `test("what it checks", function() ... end)` to the
  matching `tests/*_tests.lua` file. Use `eq(actual, expected, label)` or
  `assert`. A new test file needs adding to `extraFiles` at the bottom of
  `tests/run_tests.lua`; it receives `test` and `eq` as its chunk arguments.
- Behaviour that involves events or the panel: extend the scenario in
  `tests/mock_game_test.lua`. If the plugin needs an API member the fake
  doesn't have, add it to the fake, using exactly the documented name.

## `plugin.json` gotcha

The October 22nd, 2026 beta client rejects an empty dependency list:
`"requiredDependencies": []` fails with *"unexpected json Array, expected a
json Object"*. **Leave out dependency fields you don't use.** Empty
permission lists (`"requiredPermissions": []`) are fine.

## Testing on the beta world

1. Copy `ports-helper` (and `tools/ports-discovery` if you need it) into
   `dev_plugins` in the beta client folder.
2. In the console: `prf`, `plist`, `pon ports-helper`; after edits,
   `prl ports-helper`, then close and reopen the panel.
3. Work through the relevant parts of [docs/TESTING.md](docs/TESTING.md).
   For new variables, `ports-discovery`'s `PORT VARS` block shows values
   changing live.

## Pull request checklist

- [ ] `lua5.4 tests/run_tests.lua` and `lua5.4 tests/mock_game_test.lua` pass.
- [ ] New logic has unit tests; new UI or event wiring is covered by the
      fake-game test.
- [ ] Header and function comments are up to date; observed or unconfirmed
      game behaviour is marked as such.
- [ ] README, docs and `CHANGELOG.md` (under *Unreleased*) are updated.
- [ ] Tested on the beta world if it touches the game API, with what you
      checked written in the PR.

## Submitting to the Plugin Hub

Jagex's AI policy requires whoever submits a plugin to have **reviewed and
understood all of its code**. Parts of this code were written with AI
assistance. Read every file before submitting, and replace the placeholder
`contactEmailAddress` in `plugin.json`.
