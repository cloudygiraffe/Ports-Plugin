# Testing on the plugin beta world

Plugins only run on the beta world until Jagex approves them. Your beta
character is a copy of your live one ("import save" in the lobby, once an
hour), so nothing you do there affects your real account.

Run the offline tests first (`lua5.4 tests/run_tests.lua` and
`lua5.4 tests/mock_game_test.lua`). This page covers what only the real game
can check.

## 1. Set up

1. Join the beta using the link on
   [developer.runescape.com → Accessing the API](https://developer.runescape.com/rs/tutorial/1helloworld.html),
   then press **import save** in the lobby.
2. In the beta client folder (on Windows usually
   `C:\ProgramData\Jagex\RuneScape-BETA`), create `dev_plugins` if needed.
3. Copy `ports-helper` and `tools/ports-discovery` into `dev_plugins`.
4. Open the console with **Alt + the key under Esc**. Run `prf`, then `plist`.
   Both plugins should be listed with no `[ERROR]` lines. If you see
   "unexpected json Array, expected a json Object", check `plugin.json` for an
   empty dependency list (see CONTRIBUTING.md).

Console commands: `pon <name>`, `poff <name>`, `prl <name>` (reload),
`plist`. After `prl`, close and reopen the plugin's panel.

## 2. Confirm the game variables (about 15 minutes)

1. Allow the optional chat permission if asked, then run `pon ports-discovery`.
2. A `PORT VARS` block prints within a few seconds. Screenshot it and note:
   - your voyage and crew reroll counts in game (compare `voyage rerolls` and
     `crew rerolls`);
   - which two adventurers are in your port today (compare
     `in port today: adventurer 1/2`);
   - roughly how far through each adventurer's story you are (compare
     `adventurer n story done`).
3. Go to your port and open, one at a time, for about 5 seconds each: every
   page of the **Captain's Log**, the **Voyages** window, the **Crew
   Roster**, and a voyage's crew-selection screen. Each should print
   `PORT WINDOW? interface=...` with up to 25 lines of text. Copy them all.
4. Pick a voyage, send it, collect one, and use a reroll. A new `PORT VARS`
   block prints after each change. Note what changed. Do the
   `LOCAL_NOTIFICATION_EVENT_PORTS_*` values fill in while a ship is out?
5. Run `poff ports-discovery` and paste everything into a GitHub issue. New
   findings go into [VARIABLES.md](VARIABLES.md).

## 3. Test the plugin

Run `pon ports-helper`.

### Clock and overview
- [ ] The plugin's icon appears in the Plugins ribbon window and the panel opens.
- [ ] Before anything else, the panel says it doesn't know the time yet.
- [ ] Open the voyage list once. Within a few seconds the countdowns appear.
- [ ] "Daily reset in ..." matches the time left until 00:00 UTC.
- [ ] The Wednesday reset and Barmaid's Tip countdowns are right.
- [ ] Within two hours of reset, with rerolls left, the overview warns that
      they'll be lost, and the number matches the game.
- [ ] The Portnight line says tracking starts later (no fake "0 days").

### Arc today
- [ ] Today's bird and island match the wiki's table for today's weekday.
- [ ] "Next appearance in ..." matches the bird actually appearing.
- [ ] The castaway list matches the bottles you can see.

### Crew optimizer
- [ ] Select a voyage in game. The plugin's Morale / Combat / Seafaring boxes
      fill in with that voyage's requirements.
- [ ] You can still type over them.
- [ ] *(Once the roster is loaded; see the README roadmap)* Press **Find best
      crew**. A result appears within a few seconds and the game doesn't
      stutter. The chance matches the in-game crew screen for the same picks.

### Story helper
- [ ] The topic dropdown opens over the text, not underneath it.
- [ ] Icon names match what the build menu at a pier hotspot calls them.
      Note any that differ.
- [ ] Each adventurer, trio and the capes page fit in the panel. Note anything
      cut off, and the panel's size.
- [ ] The chosen topic is remembered after `prl ports-helper`.

### Reminders
- [ ] With less than an hour to reset, the gold line appears at the top of the
      screen once, and in chat if the permission is on. It doesn't repeat
      after `prl ports-helper`.
- [ ] Ticking or unticking a reminder survives `prl ports-helper`.

### General
- [ ] `<col=...>` colours and `<br>` line breaks render, rather than showing
      as text.
- [ ] Only the current section's inputs, checkboxes or dropdown are visible.
- [ ] No `[ERROR]` lines in the console during any of the above.
