# Testing on the plugin beta world

Plugins only run on the beta world until Jagex approves them. Your beta
character is a copy of your live one ("import save" in the lobby, once an
hour), so nothing you do there affects your real account.

## 1. Set up

1. Join the beta using the link on
   [developer.runescape.com → Accessing the API](https://developer.runescape.com/rs/tutorial/1helloworld.html),
   then press **import save** in the lobby.
2. In the beta client folder (on Windows usually
   `C:\ProgramData\Jagex\RuneScape-BETA`), create `dev_plugins` if needed.
3. Copy `ports-helper` and `tools/ports-discovery` into `dev_plugins`.
4. Open the console with **Alt + the key under Esc**. Run `prf`, then `plist`.

Console commands: `pon <name>`, `poff <name>`, `prl <name>` (reload), `plist`.

## 2. Find the port windows (about 15 minutes)

1. Allow the optional chat permission if asked, then run `pon ports-discovery`.
2. Wait for `Scan complete`. Copy every `MATCH` line.
3. Go to your port. Open, one at a time, leaving each open for 5 seconds:
   the **Captain's Log** (every page), the **Voyages** window, the
   **Crew Roster**, and a voyage's crew-selection screen.
4. Each should print `PORT WINDOW? interface=...` and up to 40 lines of text.
   Copy them all.
5. Send a voyage, collect one, and use a reroll if you have one. Copy every
   `CHANGE` and `CHAT` line printed while you do.
6. Run `poff ports-discovery` and paste everything into a GitHub issue.

## 3. Test the plugin

Run `pon ports-helper`.

### Clock and overview
- [ ] The plugin's icon appears in the Plugins ribbon window and the panel opens.
- [ ] If the panel says it doesn't know the time, open the Captain's Log once
      (after window IDs are filled in) or allow the chat permission and wait
      for a chat message. Countdowns then appear.
- [ ] "Daily reset in ..." matches the time left until 00:00 UTC.
- [ ] The Wednesday reset and Barmaid's Tip countdowns are right.
- [ ] The Portnight line says tracking starts later (no fake "0 days").

### Arc today
- [ ] Today's bird and island match the wiki's table for today's weekday.
- [ ] "Next appearance in ..." matches the bird actually appearing.
- [ ] The castaway list matches the bottles you can see.

### Crew optimizer (after the Crew Roster parser exists)
- [ ] Enter a voyage's three stats and press **Find best crew**. A result
      appears within a few seconds, and the game doesn't stutter.
- [ ] The chance shown matches the in-game crew screen when you pick the
      same captain and crew.

### Story helper
- [ ] The topic dropdown opens over the text, not underneath it.
- [ ] Icon names match what the build menu at a pier hotspot calls them.
      Note any that differ.
- [ ] Each adventurer, trio and the capes page fit in the panel. Note anything
      cut off and the panel's size.

### Reminders
- [ ] With less than an hour to reset, the gold line appears at the top of the
      screen once, and in chat if the permission is on. It doesn't repeat
      after `prl ports-helper`.
- [ ] Ticking or unticking a reminder survives `prl ports-helper`.

### General
- [ ] `<col=...>` colours and `<br>` line breaks render (not shown as text).
- [ ] Hiding the controls of other sections works: only the current
      section's inputs, checkboxes or dropdown are visible.
