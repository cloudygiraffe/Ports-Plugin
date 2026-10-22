# Player-owned Ports and The Arc: research for a helper plugin

Compiled October 22nd, 2026, mostly from the RuneScape Wiki, plus RuneHQ,
Tip.It, RuneApps, GitHub and the official forum archive. Numbers marked
**(unverified)** came from pages that contradicted each other or wouldn't
load. Check those in game before building on them.

---

## 1. The short version

Nothing in the official plugin directory covers Ports or the Arc. The existing
tools are old websites where you type everything in by hand. The newest is an
Alt1 crew optimizer last updated in 2020, which was never finished. The
biggest gaps are things the game **never shows you**:

**Ports**
- A countdown to the daily (00:00 UTC) and weekly resets.
- How many voyage and crew rerolls you'll **lose** at reset.
- Warnings before hitting the chime cap (200,000) or trade-goods cap (250 each).
- Reminders for the Thursday Barmaid's Tip and Wednesday resets (Meg, the
  Black Marketeer, Advance Time).
- A Portnight streak count (one voyage a day for 14 days).
- Distance to the next region as a number (the game only shows a %).
- Progress toward specific gear: scroll pieces plus trade goods.
- Crew selection that accounts for traits and the Shipwright bonus.

**Arc**
- Chimes sold today versus the 20,000–30,000 daily cap.
- Contracts done today versus your 3–7 limit, and the current reroll cost.
- When birds spawn, and which castaway bottles are out today. Both follow
  fixed public schedules.
- Berry planter timers (42 hours) and Spirit Realm charm minutes left.

---

## 2. Ports mechanics

### Access and voyages
- Members only. You need level 90 in one of 12 skills to send ships (boosts
  don't count). Each skill unlocks one adventurer.
- **Success chance equals the lowest of the three stat bars** (Morale, Combat,
  Seafaring). Speed only changes how long a voyage takes.
- Fort Forinthry's Command Centre adds +3%, +6% or +10% success at tiers 1–3.
- Each voyage takes 1 captain, up to 5 crew, and the ship's parts.
- Duration = max(15, floor(voyage speed × distance ÷ effective speed ÷ 10))
  minutes, where effective speed is the ship's speed clamped between 0.75× and
  1.25× the voyage's.
  - Totem of Navigation: −15% (no charging needed since April 13th, 2026).
  - Scroll, trade-good and unlock voyages take 50% longer.
- **Standard voyages:** 3 slots plus **15 rerolls a day** (18 a day in total).
  Unused slots carry over midnight; **unused rerolls don't**.
- Only voyages to your **newest region** give full distance; older regions give half.
- **Advance Time** (93 Magic) completes all active voyages instantly, 3 casts
  a week, reset Wednesday 00:00.

### Failure
- Partial completion gives 20% of the rewards.
- Damage costs resources or dry-dock time (1, 2 or 5 hours). Felix repairs
  instantly for 20,000 coins per hour of dry dock.
- A random crew member can die; the captain survives 5% of the time (+20% with Loyal).
- Distance counts whether the voyage succeeds or fails.

### Ships, captains and crew
- Up to **4 ships (unverified)**, unlocked through Office upgrades. Each has
  5 part slots; 62 parts exist. **Seafaring only comes from hulls and decks**,
  so it's usually the weakest stat.
- Up to 5 captains and 25 crew. 1 captain and 3 crew for hire at a time;
  15 crew rerolls a day.
- Units level 0–10 (each level +10% base stats; 4,000 XP to max). XP per voyage
  ranges from 7 (Arc) to 85 (Shield).
- Traits come in 4 tiers. Tier 4 (±1% to total stats) multiplies with the
  Shipwright bonus.

**How good players pick crew** (the main decision pain point): raise the
lowest bar to 100% using your **lowest-level crew who don't lower the chance**,
so they level up. Add one merchant only on resource voyages. Use Solidarity
crew on multi-stat voyages. Fit rudders to the voyage's speed range.

### Regions

| Region | Distance to unlock | Voyage distance | Time (slow / fast) | Resource |
|---|---|---|---|---|
| Arc | 0 | 250 | 33 / 20 min | bamboo |
| Skull | 5,000 | 600 | 80 / 48 min | gunpowder |
| Hook | 40,000 | 1,200 | 160 / 96 min | black slate |
| Scythe | 140,000 | 2,400 | 320 / 192 min | cherrywood |
| Bowl | 450,000 | 4,800 | 640 / 384 min | jade |
| Pincers | 1,200,000 | 6,000 | 800 / 480 min | stainless steel |
| Loop | 2,300,000 | 6,800 | 906 / 544 min | terracotta |
| Shield | 4,100,000 | 8,000 | 1,066 / 640 min | azure |

Distance caps at 6,000,000. Story voyages give no distance and must be
claimed at the port, not through the Captain's Log.

### Port score
Maximum 4,664, from distance, scroll pieces, upgrades, ship parts,
adventurers met, story voyages and clues. The title "Portmaster" needs 4,500.

### Resources, buildings and shops
- **Caps:** chimes are soft-capped at **200,000** (trimmed at reset). Trade
  goods are hard-capped at **250 each**, and extra is lost when you claim a
  voyage. Other resources cap at 999,999 (the Wiki is inconsistent about
  whether that's soft or hard).
- **Shipwright** (+% to total ship stats) is the only building that directly
  raises success chance.
- **Totems** (4 hotspots): telescope, parrot, cherry tree, Pandora's box, jade
  statue and map table. Stacking the same type gives +4/7/9/10%.
- **The Trader** swaps resources for trade goods daily; the rates aren't
  documented on the Wiki. **Felix** sells port resources for coins weekly.

---

## 3. Port chores, and what gets wasted

**Daily reset, 00:00 UTC** (applies on your first login after it)
- New visiting adventurers and a new captain for hire.
- New Trader stock.
- 15 voyage rerolls and 15 crew rerolls.
- Chimes over the cap are trimmed.

**Weekly**
- **Thursday:** the Barmaid's Tip voyage. It must be claimed before Thursday's reset.
- **Wednesday 00:00:** Meg's questions (an XP lamp), Black Marketeer stock,
  and Advance Time charges all reset.

**Wasted if you don't act**
1. Unused rerolls disappear at reset, which can cost up to 15 voyages a day.
2. Visiting adventurers you didn't send are replaced at midnight.
3. Chimes over 200,000 are trimmed.
4. Trade goods over 250 are lost when you claim a voyage.
5. Rerolls from random-event rewards are lost at reset if you redeem them late.
6. Returned ships sit idle until claimed.
7. A pending random event blocks new ones, and logging out loses it.

---

## 4. Cape requirements involving Ports and the Arc

| Cape | Requirement |
|---|---|
| Completionist | Port Life; Walking the Reef (all Reefwalker scroll pieces); Trip to the East (one trio storyline); Unlocking Waiko I; Upgrading Waiko I; Ancient Eastern Tortle Portals; all Arc miniquests |
| Trimmed Completionist | Eastern Explorer (reach the Shield, 4.1M distance); Scrolling in the Deep (all 108 scroll pieces); Salty; All Your Energies; Don't Crush My Memories; Mitts and Waders; Bone to Pick With You |
| Master Quest | Castaways of the Arc; Flippers; one Eastern Adventurer storyline (**check how many after the February 2026 split**) |

---

## 5. The Arc

### Contracts
- Given by **Sojobo** (Waiko: combat and skilling), **Hubbub** (Whale's Maw:
  fishing, needs 91+ Fishing) and **Ling** (Aminishi: Slayer, needs 90 Slayer).
- **3 a day, up to 7 with upgrades**, shared across all three givers, reset
  at 00:00 UTC.
- Rerolls cost 1 chime before your first completion each day, then 10 chimes
  per contract completed (halved by the contract guru).
- Most pay 150 chimes plus XP.

### Chimes (the Arc's currency, separate from port chimes)
- **Daily cap on chimes from selling: 20,000, +5,000 per upgrade (30,000 max)**,
  reset 00:00 UTC. Pickpocketing chimes don't count. Whether contract chimes
  count is unknown.
- Best sellers: shark soup (85–102), Arc gumbo (65–78), golden idol (50–60).
- **Salty** (every Arc unlock and upgrade) costs 302,350 chimes and 384 taijitu in total.

### Uncharted Isles
- Short, medium and long voyages cost 5, 12 or 20 supplies. A return to your
  claimed island costs 3.
- Rosie's crate gives 5 free supplies a day (it holds 50 or 75 — the Wiki
  says both).
- **Washed-up items disappear if you leave or log out.** A claimed island's
  resources reset at 00:00 UTC.
- Salty crablets each have their own 5 minute 30 second timer.

### Collections with schedules a plugin could compute
- **Birds (16):** each named island has a bird on one weekday. It appears
  every **30 minutes 30 seconds** from 00:00 UTC, for about 10 minutes, on
  every world. The Wiki's rotation code uses reference time 1756080000
  (Monday, August 25th, 2025, 00:00 UTC) + weekday offset + i × 1830 s.

  | Day | Island bird |
  |---|---|
  | Monday | Crested Sillago Snatcher (Whale's Maw) |
  | Tuesday | Shrine Ibis (Aminishi) |
  | Wednesday | Gongdung Peligorn (Goshima) |
  | Thursday | Cyclosis Cockatiel (Cyclosis) |
  | Friday | Titchy Tinamou (Turtles) |
  | Saturday | Tuai Leit Toucan (Tuai Leit) |
  | Sunday | Waiko Warbler (Waiko) |

- **Castaways (10):** bottle *n* is visible every *n* days, changing at
  00:00 UTC, the same for everyone. Rotation start dates (2025): 1 always;
  2 and 3: August 31st; 4: August 29th; 5: August 30th; 6: August 31st;
  7: August 27th; 8: August 29th; 9: August 31st; 10: August 25th.
- **Berries (16):** the Tuai Leit planter has 2 spots, and each bush takes
  **42 hours**. The full set takes about 14 days.
- **Kami (16)** and **mushrooms (16)** have no fixed schedule.

### Spirit Realm
1 spirit dragon charm to enter, then 1 per minute; you're thrown out when you
run out. A charm countdown would be useful, and the game doesn't show one.

### How the Arc depends on your port
- The **"Meet the Assassin"** story voyage is needed for Spiritual
  Enlightenment, every miniquest after it, and Ling's contracts.
- The **Cyclosis voyage** (800 in every stat) is needed for Eye for an Eye and later.
- Unlocking the **Whaler** unlocks Hubbub.

---

## 6. Existing tools

| Tool | What it does | Limitation |
|---|---|---|
| [Wiki: Optimal set-up calculator](https://runescape.wiki/w/Calculator:Player-owned_port/Optimal_set-up) | Best crew for a voyage | Manual entry; ignores most traits |
| [Wiki: Voyage rewards calculator](https://runescape.wiki/w/Calculator:Player-owned_port/Voyage_rewards) | Expected rewards | Manual entry |
| [Kags Ports Encyclopedia](https://runescape.wiki/w/User:Kags) | The community's main guide, updated through September 2026 | Reading only |
| [Tip.It Voyage Calculator](https://www.tip.it/runescape/pages/view/pop_voyage.htm) | Most complete optimizer | Last updated 2015 |
| [Tip.It POP Timers](https://www.tip.it/runescape/pages/view/pop_timers.htm) | Manual voyage countdowns | Last updated 2013 |
| [RuneApps PoP Tracker](https://runeapps.org/popapp) | Type in arrival times; syncs to phone | No screen reading or alerts |
| [leejay10/ports](https://github.com/leejay10/ports) | Alt1 crew optimizer that reads crew stats from the screen | Last commit 2020; incomplete |
| [DailyScape](https://dailyscape.github.io/) | Manual dailies checklist and Ports profit table | Manual |

**The Wiki has no calculators at all for Arc contracts, the Uncharted Isles or Tuai Leit.**

## 7. What players complain about

- Having to log in on a schedule. Later voyages take 12–20 hours, and a
  missed day or week sets you back.
- Picking crew is tedious and done in your head or a spreadsheet.
- Only 3 voyages are visible at a time, so you burn rerolls to find good ones.
- Slow crew levelling. The Loop is widely disliked.
- The Captain's Log can't send story voyages or item-reward voyages.
- Arc: chimes are grindy, the daily shark soup routine is long, contract
  rerolls get pricier, and washed-up items vanish on logout.

---

## 8. Plugin feature map

Tiers follow the [plugin guidelines](https://developer.runescape.com/rs/submission/guidelines.html).
"Allowed" covers trackers, logs, planners and notifications based on known
information. Timers and anything giving "actionable recommendations" get
extra review.

| Feature | Data the plugin would need | Guideline tier | Notes |
|---|---|---|---|
| Daily and weekly reset countdowns | Real clock | Allowed | The Captain's Log header shows the Runedate *with a fraction of the day*. Reading it gives a clock with no permissions. |
| "You'll lose N rerolls at reset" warning | Reroll counts (variable or Voyages screen) + clock | Allowed | Probably the most valuable single feature |
| Ship return times and "ship returned" alert | Ship status (variable or Captain's Log) | Allowed / timer review | Sounds are possible; desktop notifications aren't |
| Chime and trade-goods cap warnings | Resource counts | Allowed | |
| Thursday Barmaid's Tip and Wednesday reminders | Clock | Allowed | |
| Portnight streak | Voyages sent per day, stored locally | Allowed | |
| Distance to next region, as a number | Distance (Port Statistics page or variable) | Allowed | |
| Gear progress (scrolls + trade goods) | Scroll pieces, trade goods | Allowed | |
| Crew optimizer | Crew stats and traits, voyage stats | **Stricter review** | "Actionable recommendations." Non-combat, so likely possible, but expect iteration. |
| Arc: contracts today, reroll cost | Contract count (variable or chat) | Allowed | |
| Arc: chimes sold today vs cap | Chime pouch changes | Allowed | |
| Arc: bird and castaway schedule | Clock only; schedules are public | Probably allowed | Deterministic, public. Ask on the plugin Discord. |
| Arc: berry planter timer | Planting time, stored locally | Allowed | |
| Arc: Spirit Realm charms left | Inventory/currency count | Allowed | |

### API pieces that make this possible
- `Event.VarTransmit` and `var.VarPlayer` for port state, **if** the server
  sends it to the client. This needs checking with a discovery tool (see the
  Voice of Seren and Fairy Ring repos for the pattern).
- Reading text from built-in interfaces (`ui.Interfaces:GetComponent`, label
  `content`) as a fallback, e.g. the Captain's Log while it's open.
- `PersistentDB` for streaks, planting times and settings.
- `audio.Play` for alert sounds.

---

## 9. Questions to answer on the beta world

1. Which port values reach the client as variables (rerolls, ship status,
   resources, distance)? Ports runs from interfaces, so many probably do.
2. Can the Captain's Log header (Runedate with a fraction) be read reliably as a clock?
3. Are Arc contract counts and chimes-sold-today stored in variables?
4. Ask on the RS Plugin Discord whether bird and castaway schedules count as
   "predicting future state" (they're public and deterministic).

## Sources

- [Player-owned port](https://runescape.wiki/w/Player-owned_port) and subpages:
  [Captains and crew](https://runescape.wiki/w/Player-owned_port/Captains_and_crew),
  [Strategies](https://runescape.wiki/w/Player-owned_port/Strategies),
  [Rewards](https://runescape.wiki/w/Player-owned_port/Rewards),
  [Interfaces](https://runescape.wiki/w/Player-owned_port/Interfaces),
  [Special voyages](https://runescape.wiki/w/Player-owned_port/Special_voyages)
- [Captain's Log](https://runescape.wiki/w/Captain%27s_Log), [Advance Time](https://runescape.wiki/w/Advance_Time),
  [Command centre](https://runescape.wiki/w/Command_centre), [Port resources](https://runescape.wiki/w/Port_resources)
- [The Arc](https://runescape.wiki/w/The_Arc), [Contracts](https://runescape.wiki/w/Contracts),
  [Chimes](https://runescape.wiki/w/Chimes), [Waiko Reward Shop](https://runescape.wiki/w/Waiko_Reward_Shop),
  [Uncharted Isles](https://runescape.wiki/w/Uncharted_Isles), [Arc Journal](https://runescape.wiki/w/Arc_Journal),
  [The Arc/Birds](https://runescape.wiki/w/The_Arc/Birds), [Module:Rotations/js](https://runescape.wiki/w/Module:Rotations/js),
  [Castaways](https://runescape.wiki/w/Castaways), [Berry planter](https://runescape.wiki/w/Berry_planter),
  [Salty (achievement)](https://runescape.wiki/w/Salty_(achievement))
- [Completionist Cape (achievement)](https://runescape.wiki/w/Completionist_Cape_(achievement)),
  [Trimmed Completionist Cape (achievement)](https://runescape.wiki/w/Trimmed_Completionist_Cape_(achievement)),
  [Master Quest Cape (achievement)](https://runescape.wiki/w/Master_Quest_Cape_(achievement))
- [RuneHQ Ports guide](https://reforged.runehq.com/rs3/minigame/player-owned-ports),
  [official forum archive thread](https://forums.rs/en/48,49,508,65714630,goto,4.html),
  [RuneApps 2015 request thread](https://runeapps.org/forums/viewtopic.php?id=136)
