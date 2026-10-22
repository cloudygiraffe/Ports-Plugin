# Ports & Arc Helper — RuneScape 3 plugin

A plugin for the official RuneScape 3 Client API that takes the chores and
guesswork out of **Player-owned Ports** and **The Arc**.

> **Status: beta-ready, version 0.1.0.** Everything that only needs the clock
> works now. Features that read your port (ships, rerolls, resources, crew
> stats) wait on the window IDs that `tools/ports-discovery` will find on the
> beta world. Nothing for Ports or the Arc existed in the official plugin
> directory as of October 22nd, 2026.

## What it does

The panel opens from the plugin's icon in the Plugins ribbon window and has
five sections:

| Section | What you get | Needs |
|---|---|---|
| **Port overview** | Daily and weekly reset countdowns, next Barmaid's Tip, warnings (ships back, rerolls about to be lost, chime and trade-good caps), Portnight streak | Clock only for countdowns; warnings need port data |
| **Arc today** | Today's bird and island, when it next appears, and which castaway bottles are out today | Clock only |
| **Crew optimizer** | Enter a voyage's Morale, Combat and Seafaring; get the captain and crew with the best success chance, ties going to your lowest-level crew so they level up | Crew Roster data |
| **Story helper** | Which port **icon** brings each adventurer (and the skill at 90 it needs), visit odds with 0–3 icons, each adventurer's story voyages and regions, the four trio storylines, joint-voyage partners, and which storylines the capes need | Nothing |
| **Reminders** | Turn on or off: 1 hour before reset, Barmaid's Tip Thursdays, day before the Wednesday reset, Arc bird about to appear | Clock only |

Reminders show as a gold line at the top of the screen, and in your chat box
too if you allow the optional chat permission.

### How it knows the time

The Client API has no clock, so the plugin uses, best first: the RuneDate in
the Captain's Log header, chat message timestamps (optional permission), and
Lua's `os.time` when the client provides it. It then counts game ticks. If it
doesn't know the time yet, the panel says so and tells you to open the
Captain's Log once.

### Port icons in short

Three hotspots at the pier ends; 1,000 chimes per build, free to remove;
needs level 90 in the adventurer's skill and their first story voyage done.
Icons stack: all three on one adventurer takes them from about 17% to 48% on a
two-visitor day (the wiki's formula). The Story helper lists every icon.

## Repository layout

```
ports-helper/            the plugin (copy this folder into dev_plugins)
  plugin.json
  main.lua               wires game events to the modules below
  src/                   schedule, Arc timetable, optimizer, story data, panel, ...
  src/sources/           reading open game windows (Captain's Log)
tools/ports-discovery/   developer tool for the beta world (not for release)
tests/                   pure-Lua tests and a fake-game end-to-end test
docs/RESEARCH.md         mechanics, sources and feature ideas
docs/DESIGN.md           how the code fits together
docs/TESTING.md          step-by-step beta-world test plan
```

## Running the tests

With Lua 5.4 or 5.5, from the repository root:

```
lua tests/run_tests.lua        # 35 tests: schedules, Arc, RuneDate, optimizer, warnings, story
lua tests/mock_game_test.lua   # loads main.lua against a strict fake game API
```

## Guidelines

Everything shown is information the game already gives you, or public
schedules and wiki data. The crew optimizer gives "actionable
recommendations", which the plugin guidelines list as subject to review; it
never selects crew or clicks anything for you.

## Credits and licences

- Code: MIT (see `LICENSE`).
- Game data in `src/story.lua`, `src/arc_schedule.lua` and `docs/RESEARCH.md`
  comes from the [RuneScape Wiki](https://runescape.wiki) and is
  CC BY-NC-SA 3.0.
- Not affiliated with Jagex. RuneScape is a trademark of Jagex Ltd.
