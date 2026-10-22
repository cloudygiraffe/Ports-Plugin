# Ports & Arc helper — RuneScape 3 plugin (planning)

A planned plugin to take the chores and guesswork out of **Player-owned Ports**
and **The Arc**: reset countdowns, warnings before rerolls or resources are
wasted, ship-return alerts, cap warnings, and Arc daily tracking.

> **Status: research only.** No code yet. Nothing for Ports or the Arc exists
> in the official plugin directory as of October 22nd, 2026.

- **[docs/RESEARCH.md](docs/RESEARCH.md)** covers the mechanics, the daily and
  weekly chores, what gets wasted, cape requirements, existing tools, player
  complaints, and a feature map with guideline tiers and the data each
  feature would need.

## Likely first version

1. Daily and weekly reset countdowns, with a warning when voyage or crew
   rerolls would be lost.
2. Ship return times with an in-game alert.
3. Chime (200,000) and trade-goods (250) cap warnings.
4. Arc: contracts done today and chimes sold today against their caps.

## First step

Run a variable-discovery tool on the beta world to see which port values the
game sends to the client. The same approach is used in the Voice of Seren and
Fairy Ring Codes repositories.
