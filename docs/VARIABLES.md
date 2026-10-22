# Game variables for Ports and the Arc

A reference of the client variables that carry Player-owned Ports and Arc
data, for anyone extending `ports-helper/src/sources/port_vars.lua`.

None of this is in Jagex's plugin documentation. It comes from the client's
own variable lists, and the meanings are our reading of the names plus what
we've seen change in game. **Check before relying on anything marked "to
confirm".**

## Where the lists come from

On the beta client (October 22nd, 2026), these console commands copy the
full variable list to the clipboard:

```
pan VarPlayer     # 62,360 entries, including varbits
pan VarClient     # 7,802 entries
```

Each line reads `id NAME TYPE [varp mask]`:

- **VarPlayer / VarClient** entries have a non-negative ID and are read with
  `var.VarPlayer.FromID(id).value` (or `var.VarClient`).
- **Varbits** have a negative ID followed by the VarPlayer that holds them and
  the bit mask, e.g. `-17122 POP_VOYAGE_REROLLS INTEGER 3403 0x7f` is the low
  7 bits of VarPlayer 3403. `var.VarPlayer.FromID(-17122).value` returns the
  already-shifted value (observed on the beta world).

IDs can change when the game updates. If a value stops making sense, re-run
`pan VarPlayer` / `pan VarClient` and compare names.

The game appears to call **Morale "graft"** internally (every
`*_GRAFT` variable sits where Morale would be). To confirm on the voyage
screen.

Status key: **confirmed** = checked against the game on the beta world;
**likely** = strong evidence but not checked directly; **to confirm** = name
only.

`tools/ports-discovery` prints most of the variables below as a labelled
`PORT VARS` block whenever one changes, which is the quickest way to confirm
them.

## Clock and the voyage list

| ID | Name | Kind | Meaning | Status | Used by |
|---|---|---|---|---|---|
| 2624 | `POP_VOYAGE_LIST_TIMER_STARTED` | VarClient | Minutes since January 1st, 1970 UTC, stamped when the voyage list opens. 29878112 = 16:32 UTC, October 22nd, 2026, the minute a voyage was sent. | confirmed | clock (`Clock.QUALITY.PORT_TIMER`) |
| 2625 | `POP_VOYAGE_LIST_TIMER_TICK` | VarClient | Companion tick for the above. | to confirm | |
| 3414 | `POP_VOYAGE_LIST_TIMER` | VarPlayer | Return time of the selected voyage, in minutes since 1970 (went 0 → 29878277, i.e. 165 minutes after the timer above). | likely | not yet |
| 3411 | `POP_VOYAGE_LIST_DIFF_GRAFT` | VarPlayer | Selected voyage's Morale requirement. | confirmed (6500) | crew optimizer auto-fill |
| 3412 | `POP_VOYAGE_LIST_DIFF_COMBAT` | VarPlayer | Selected voyage's Combat requirement. | confirmed (6500) | crew optimizer auto-fill |
| 3413 | `POP_VOYAGE_LIST_DIFF_SEAFARING` | VarPlayer | Selected voyage's Seafaring requirement. | confirmed (0) | crew optimizer auto-fill |
| 3408–3410 | `POP_VOYAGE_LIST_SHIP_GRAFT` / `_COMBAT` / `_SEAFARING` | VarPlayer | Your selected ship + crew totals for that voyage (5108 / 4418 / 8127 seen). | likely | not yet |
| 3407 | `POP_VOYAGE_LIST_CHANCES` | VarPlayer | Packed bar percentages: `_CHANCE_GRAFT` (-17127, 0x7f), `_CHANCE_COMBAT` (-17128, 0x3f80), `_CHANCE_SEAFARING` (-17129, 0x1fc000). | to confirm | |
| 3406 | `POP_VOYAGE_LIST_DATA` | VarPlayer | Packed list state: `_MODE`, `_SELECTED`, `_OFFSET`, `_SHIP` (which ship is selected), `_REQ1..3_MET`. | to confirm | |
| 3417 | `POP_VOYAGE_DRYDOCK_HOURS` | VarPlayer | Hours a ship spends in drydock (damage). | to confirm | |
| 3415 | `POP_VOYAGE_LIST_STORY_AVAILABLE` | VarPlayer | Whether a story voyage is on offer. | to confirm | |

## Rerolls

| ID | Name | Kind | Meaning | Status | Used by |
|---|---|---|---|---|---|
| -17122 | `POP_VOYAGE_REROLLS` | varbit of 3403 (0x7f) | Voyage rerolls left today. VarPlayer 3403 (`POP_VOYAGES_TRACKER`) went 8847 → 8846, whose low 7 bits are 15 → 14, matching the 15 daily rerolls. | likely | reset warning |
| -17462 | `POP_CREW_REROLLS` | varbit of 3453 (0x1e0) | Crew rerolls left today. | to confirm | reset warning |

## Ships and voyage slots

Four ship slots, each with the same layout (slot 1 shown; slots 2–4 follow
at the IDs in parentheses).

| ID | Name | Meaning | Status |
|---|---|---|---|
| -17072 (-17083, -17094, -17105) | `POP_VOYAGE_n_ID` | Voyage the ship is on (0 = none?) | to confirm |
| -17073 (-17084, -17095, -17106) | `POP_VOYAGE_n_DONE` | Voyage finished, waiting to be claimed. Would drive "ship has returned" warnings. | to confirm |
| -17081 … | `POP_VOYAGE_n_SPACES`, `_ASYNCH`, `_SPEEDBOOST`, `_GRAFTBOOST`, `_COMBATBOOST`, `_SEAFARINGBOOST`, `_PROTECTED`, `_XPBOOST`, `_REWARDBOOST` | Per-slot voyage modifiers. | to confirm |
| 3381, 3383, 3385, 3387 | `POP_SHIP_SETTINGS_1..4` | Packed ship parts: `_HULL`, `_RUDDER`, `_DECK1`, `_DECK2`, `_RAM`. | to confirm |
| 3382, 3384, 3386, 3388 | `POP_SHIP_NAME_1..4` | Packed ship name: `_PREFIX`, `_NAME1`, `_NAME2` (indexes into name lists). | to confirm |
| 2601 | `POP_SHIP_STAT_NAME` (VarClient, string) | Name of the ship being viewed, e.g. "U.S.S. Misty Cloud". | confirmed |
| 2603–2619 | `POP_SHIP_STAT_*`, `POP_SHIP_PART_*` (VarClient) | Stats of the ship / part being viewed (speed, combat, graft, seafaring and their boosts). | likely |
| 2611 | `POP_SHIP_VOYAGE_STATE` (VarClient) | 0 → 1 when a voyage was sent. | to confirm |

**Ship return times (roadmap):** VarClients 6715–6722,
`LOCAL_NOTIFICATION_EVENT_PORTS_1..4_TIME` and `_ID`, look like the game's own
"ship returned" notification per slot. They read −1 with no ships out; if
they fill in while a voyage is out, they give return alerts directly.

## Adventurers, story progress and trios

Adventurers are numbered 1–12 by the game. **Which number is which adventurer
is not known yet.** Matching them up (compare `PORT VARS` with your story
progress and today's visitors) is the main open task for the Story helper.

| ID | Name | Meaning | Status |
|---|---|---|---|
| -17023, -17024 | `POP_PORT_ADVENTURER_1_ID`, `_2_ID` (varps 3365/3366, 0x1f800000) | The two adventurers visiting today. | to confirm |
| -17025, -17026 | `POP_PORT_ADVENTURER_1_STORY_ID`, `_2_STORY_ID` (varp 3371) | Story voyage each visitor offers. | to confirm |
| -17027…-17030 | `POP_PORT_ADVENTURER_n_RESOURCE_ID`, `_SPECIAL_ID` (varps 3372/3373) | Their resource and special voyages. | to confirm |
| per adventurer | `POP_ADVENTURER_n_COMPLETED` (4 bits) | Story voyages completed (0–6 expected). | to confirm |
| per adventurer | `POP_ADVENTURER_n_AVAILABLE` (3 bits), `_MISSION` (3 bits), `_XP` (13 bits) | Availability, current mission, adventurer XP. | to confirm |
| -17020 | `POP_ADVENTURER_QUIN_COMPLETED` (varp 3370) | Trio storyline progress. | to confirm |
| -17007 | `POP_ADVENTURER_COLONIST_COMPLETED` (varp 3367) | Trio storyline progress; probably Hyu-Ji. | to confirm |
| -21319 | `POP_ADVENTURER_CREATURE_COMPLETED` (varp 4032) | Trio storyline progress; probably Eastern Curiosities. | to confirm |
| -26848 | `POP_ADVENTURER_KAIJU_COMPLETED` (varp 5077) | Trio storyline progress; probably Guardians of the World. | to confirm |

The `COMPLETED` varbit IDs for adventurers 1–12 are −16995, −16999, −17003,
−17008, −17012, −17016, −21307, −21311, −21315, −26836, −26840 and −26844.
For each one, `AVAILABLE` is that ID − 1 and `MISSION` is that ID − 3. The
packing (6 adventurers in varps 3365–3370, 3 in 4030–4032, 3 in 5075–5077)
suggests 1–6 are the original adventurers, 7–9 the second group and 10–12
the third, matching the trio groupings.

## Port buildings, icons and items

| ID | Name | Meaning | Status |
|---|---|---|---|
| 3437, 3438 | `POP_PORT_HOTSPOTS_1/2` | 20 packed 3-bit `POP_PORT_HOTSPOT_n_ID` values (-17396 … -17415): building or upgrade level per hotspot. The 3 icon hotspots are probably among them. | to confirm |
| -17432, -17433 | `POP_PORT_UPGRADE_BUILDING`, `_UPGRADE` (varp 3449) | Upgrade in progress. | to confirm |
| 3448 | `POP_PORT_ITEMS_1` | Packed item quantities `POP_PORT_ITEM_n_QUANTITY`. | to confirm |
| 9610 | `CHEEVO_POP_LOG_SCORE` | Port score (3141 seen). | likely |

## Resources and trade goods

| ID | Name | Meaning | Status |
|---|---|---|---|
| 3441–3447, 4038, 4039 | `POP_PORT_RESOURCE_1..9` | Resource stockpiles (would drive cap warnings). | to confirm |
| 3439, 3440 | `POP_PORT_GOODS_1/2` | Packed `POP_REWARD_RESOURCE_1..7` (8 bits each): trade goods? | to confirm |
| 6528 | `CURRENCY_ARC_CHIMES` | Chimes balance. Possibly shared by Ports and the Arc. | to confirm |

## Crew (VarClients)

| ID | Name | Meaning | Status |
|---|---|---|---|
| 2655–2684 | `POP_CREW_INV_VAR_0..29` | 30 packed values that look like the crew roster (large numbers, some 0). Decoding these would let the optimizer load crew without opening anything. | to confirm |
| 2626–2650 | `POP_CREW_STAT_*` | Stats of the crew member being viewed: name, trait, level, speed, combat, graft, seafaring, boosts, costs, captain number. | likely |
| 2651–2654 | `POP_CREW_RECRUIT_FLUFF_0..3` | Recruitment text. | to confirm |
| 2685–2688 | `POP_RANDOMEVENT`, `_REWARD1..3` | Port random event and its rewards (−1 when none). | to confirm |

## The Arc (internal prefix `ELR1_`)

| ID | Name | Meaning | Status |
|---|---|---|---|
| -33142 | `ELR1_SELL_PER_DAY` (varp 6385, 0xffff) | Chimes sold today, against the daily cap. | to confirm |
| -33147 | `ELR1_SELL_PER_DAY_CAP_INCREASE` | Cap upgrades bought. | to confirm |
| -33127 | `ELR1_SUPPLIES` | Supplies held. | to confirm |
| -33381 | `ELR1_DAILY_SUPPLIES_TAKEN` | Daily supplies claimed. | to confirm |
| -33894, -33897 | `ELR1_BERRY_TIME_1/2` (26 bits) | Berry planter timers; possibly minutes since 1970. | to confirm |
| -33895, -33898 | `ELR1_BERRY_TYPE_1/2` | What's planted. | to confirm |
| -33165 … -33893 | `ELR1_LORE_BOTTLE_01..10` (+ `_MULTIVAR`) | Castaway bottles found. | to confirm |
| 6755, 6756 | `LOCAL_NOTIFICATION_EVENT_ARCH_RESEARCH_CONTRACT_1_TIME/_ID` (VarClient) | An Archaeology research notification. Not the Arc; listed so nobody confuses it. | likely |

Arc contracts have no obvious variable yet.
