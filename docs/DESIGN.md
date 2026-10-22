# Design

## Goals

1. **Useful on day one with no permissions.** Countdowns, reminders, the Arc
   timetable and the story helper only need the time. The time comes from a
   game variable, with no permission at all.
2. **Never stutter the game.** Per-tick work is tiny, and the crew search
   runs a slice at a time.
3. **Keep game-facing code thin.** Everything that decides what to show is a
   pure function with unit tests. `main.lua`, `panel.lua`, `alert_line.lua`,
   `storage.lua` and `src/sources/*` are the only files that touch the game API.
4. **Fail quietly.** Every game call is wrapped in `pcall`. Missing data
   means a feature stays silent; it never produces a wrong warning.

## Modules

```
sources/port_vars.lua ----+
(game variables)          +--> port_state.lua --> warnings.lua --\
sources/captains_log.lua -+          |                             display.lua --> panel.lua
(open windows, scaffold)             |                             story.lua ----/
schedule.lua, arc_schedule.lua ------+--> reminders.lua --> alert_line.lua
optimizer.lua (crew search, a slice each server tick)
clock.lua <-- voyage-list timer, chat timestamps, RuneDate, os.time()
```

| File | Role |
|---|---|
| `timeutil.lua` | Calendar maths in UTC (no `os.date`), duration formatting, weekdays. Shared with the Voice of Seren plugin. |
| `clock.lua` | Turns a one-off time reading into a running clock by counting logic ticks; ranks sources (below). |
| `runedate.lua` | RuneDate (days since February 27th, 2002) to and from Unix time, and finding it in window text. |
| `schedule.lua` | Daily reset, Wednesday reset, Thursday Barmaid's Tip, day keys. |
| `arc_schedule.lua` | Bird of the day and the castaway bottle rotation. |
| `port_state.lua` | What's known about the port, and the Portnight day history. A plain store. |
| `warnings.lua` | Ships back or damaged, rerolls lost at reset, chime and trade-good caps, Barmaid's Tip today. |
| `reminders.lua` | Which reminders are due. Each has an "occurrence", so it shows once even across reloads. |
| `optimizer.lua` | Exhaustive captain and crew search (below). |
| `story.lua` | Adventurers, icons, trios, joint pairs, the visit-chance formula, and the Story helper's text. |
| `display.lua` | Text for the overview, Arc and crew sections. |
| `storage.lua` | PersistentDB wrapper; keys are per character where the data is. |
| `panel.lua`, `alert_line.lua` | UI. |
| `sources/port_vars.lua` | Reads undocumented game variables (see [VARIABLES.md](VARIABLES.md)). |
| `sources/captains_log.lua`, `sources/window_text.lua` | Reads the text of open game windows; inactive until window IDs are known. |

## Event budget

| Event | Rate | Work |
|---|---|---|
| `Logic` | 50 per second | `Clock.OnLogicTick` only |
| `ServerLogic` | every 0.6 s | Alert-line timeout; one optimizer slice (15,000 setups) |
| every 3rd `ServerLogic` | ~1.8 s | Character check, game variables, open windows |
| every 8th `ServerLogic` | ~4.8 s | Reminders and panel refresh |
| `VarTransmit` | on change | Clock sync from the voyage-list timer |
| `ChatMessage` | on message | Clock sync from timestamps (with `chatAccess`) |
| `ContentLayerReady` | panel opened | Rebuild the panel from `main.lua`'s state |

## The clock

The Client API has no clock. `clock.lua` records "it is now *T*" together
with the logic tick at that moment, then reports *T* plus the elapsed ticks
divided by 50.

Sources are ranked (`Clock.QUALITY`). A source only replaces the clock if it
is at least as good as the one that set it:

| Rank | Source | Accuracy | Needs |
|---|---|---|---|
| 4 | `os.time()` | exact | sandbox support (not available on the beta world) |
| 3 | chat timestamps | to the second | `chatAccess` |
| 2 | `POP_VOYAGE_LIST_TIMER_STARTED` | to the minute (+30 s used) | opening the voyage list |
| 1 | Captain's Log RuneDate | about ±7 minutes | the window's interface ID |

The voyage-list timer is only trusted when its value *changes*. The game also
re-sends the old value, which would be stale.

**RuneDate:** Unix = 1014768000 + RuneDate × 86400. The display is rounded
down to 0.01 day (864 s), so the plugin adds half a step (432 s).

## The crew optimizer

Success chance is the **lowest** of the three stat bars. Each bar is (ship +
captain + crew) ÷ the voyage's requirement, capped at 100%, plus any flat
bonus such as the Command Centre's.

The search tries every captain with every combination of min(5, crew) crew:
captains × C(crew, 5). A full roster of 5 captains and 25 crew is 265,650
setups, about 0.35 s in plain Lua 5.4. In game it runs 15,000 setups per
server tick and finishes in about 11 seconds. It's exhaustive because the
"lowest bar" rule makes greedy picks unreliable. `evaluate()` works in plain
local numbers and only builds tables when it finds a new best.

Tie-breaks, in order:

1. Higher chance, compared to 0.1% so floating-point noise can't decide it.
2. On resource voyages, having a merchant.
3. Lower total crew level, so low-level crew get the experience.
4. Lower captain level.

Setups with two or more merchants are skipped, since merchants don't stack.

## The story helper's visit chance

From the RuneScape Wiki: each icon adds 1 to its adventurer's weight, and
everyone else available has weight 1. Visitors are drawn by weight without
replacement. With *n* available adventurers and *k* icons on the one you
want:

- one-visitor day: (1 + k) ÷ (n + k)
- two-visitor day: 1 − ((n − 1) ÷ (n + k)) × ((n − 2) ÷ (n + k − 1))

The wiki's example: 3 icons and 12 adventurers give 26.7% on a one-visitor
day and 47.6% on a two-visitor day. Jagex hasn't confirmed the formula, so
the panel labels it an estimate.

## The Arc timetables

- **Birds:** one island's bird per weekday. It appears every 1,830 s from
  00:00 UTC and stays about 600 s. The schedule restarts at midnight.
- **Castaways:** bottle *n* is out every *n* days. Each has an anchor date it
  was out, and it's out on any day where (day − anchor) mod *n* = 0. The tests
  check the anchors against days listed on the wiki, including
  October 3rd, 2029, when all ten line up.

## Reading the game

1. **Game variables** (`sources/port_vars.lua`) are the main source. They
   need no permission and no open window. Their IDs come from the client's
   own lists, and [VARIABLES.md](VARIABLES.md) records what each one means and
   how sure we are.
2. **Window text** (`sources/captains_log.lua`) is a backup for anything the
   variables don't cover. `window_text.lua` collects every text string in an
   interface; `captains_log.lua` looks for the RuneDate and runs a list of
   per-window parsers. Both lists are empty until `tools/ports-discovery`
   reports the interface IDs.

## Open questions

- How `POP_CREW_INV_VAR_0..29` encodes the crew roster.
- Whether `LOCAL_NOTIFICATION_EVENT_PORTS_1..4_TIME` hold ship return times
  while voyages are out.
- Which `POP_ADVENTURER_n` number is which adventurer.
- What exactly the reroll counts mean (voyage rerolls are very likely "left
  today").
- The build-menu names of the icons (the plugin uses the wiki's object names).
- Interface IDs of the Captain's Log, Crew Roster and voyage windows.
