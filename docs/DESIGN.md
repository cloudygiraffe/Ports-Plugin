# Design

## Goals

1. Useful on day one with **no permissions and no port data**: countdowns,
   reminders, the Arc timetable and the story helper only need the time.
2. Never stutter the game: per-tick work is tiny, and the crew search runs a
   slice at a time.
3. Keep game-facing code thin. Everything that decides what to show is a pure
   function with tests; `main.lua` and `panel.lua` only wire events and UI.

## Modules

```
sources/captains_log.lua --> port_state.lua --> warnings.lua --\
(reads open port windows)        |                               display.lua --> panel.lua
schedule.lua, arc_schedule.lua --+--> reminders.lua --> alert_line.lua
optimizer.lua (crew search, a slice each tick)
story.lua (static icon and storyline data + its own text)
```

| File | Role |
|---|---|
| `timeutil.lua` | Calendar maths in UTC (no `os.date`), duration formatting, weekdays |
| `clock.lua` | Turns a one-off time reading into a running clock by counting logic ticks. Better sources replace worse ones (`SyncWithQuality`): system clock < chat timestamp < RuneDate |
| `runedate.lua` | RuneDate (days since February 27th, 2002) to and from Unix time, and finding it in window text |
| `schedule.lua` | Daily reset, weekly Wednesday reset, Thursday Barmaid's Tip |
| `arc_schedule.lua` | Bird of the day (spawns every 30 min 30 s from 00:00 UTC, visible 10 min) and the castaway bottle rotation |
| `port_state.lua` | Latest known port values and the Portnight day history |
| `warnings.lua` | Ships back or damaged, rerolls lost at reset, chime and trade-good caps, Barmaid's Tip today |
| `reminders.lua` | Which reminders are due; each has an "occurrence" so it shows once, even across reloads |
| `optimizer.lua` | Exhaustive captain + crew search (see below) |
| `story.lua` | Adventurers, icons, trios, joint pairs, visit-chance formula, and the Story helper text |
| `display.lua` | Text for the overview, Arc and crew sections |
| `storage.lua` | PersistentDB wrapper; per-character keys where data is per character |
| `panel.lua`, `alert_line.lua` | UI components |

## The crew optimizer

Success chance is the **lowest** of the three stat bars, where each bar is
(captain + crew + ship) ÷ voyage requirement, capped at 100%, plus any flat
bonus. The search tries every captain with every combination of up to five
crew. A full roster (5 captains, 25 crew) is 265,650 combinations: about 0.35 s
in plain Lua, so in game it runs 15,000 combinations per server tick and
finishes within a few seconds.

Ties (within 0.1%) are broken by: a merchant on resource voyages, then the
lowest total crew level (so low crew get the experience), then the lowest
captain level. At most one merchant is used.

## The story helper's visit chance

From the wiki: each icon adds 1 to its adventurer's weight, everyone else
available has weight 1. With *n* available adventurers and *k* icons on the
one you want:

- one-visitor day: (1 + k) ÷ (n + k)
- two-visitor day: 1 − ((n − 1) ÷ (n + k)) × ((n − 2) ÷ (n + k − 1))

Jagex has not confirmed this formula, so the panel labels it an estimate.

## Reading game windows

The API lets a plugin read the text of open interfaces. `window_text.lua`
collects every text string from an interface; `captains_log.lua` looks for the
RuneDate and runs a list of small parsers (one per window) that return
`port_state` fields. Both lists are empty until `tools/ports-discovery` has
reported the interface IDs and their text on the beta world.

## Things still unknown

- Interface IDs of the Captain's Log, Crew Roster and voyage windows.
- Whether the game sends any port values as variables (VarPlayer/VarClient).
- Exact build-menu names of the icons (the plugin uses the wiki's object names).
