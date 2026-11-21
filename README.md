# Camelus' Tarnished Undermine Real Reminder (WoW: Forever)

An addon that reminds you to loot your **Tarnished Undermine Real** from every boss that drops one,
once per boss per day.

**Download:** get the zip from the latest [GitHub Release](../../releases/latest). The same zips are also kept in [`releases/`](releases/), each with its version in the name.

**Making a release:** bump `## Version` in the `.toc`, add a `## vX.Y.Z` section to `CHANGELOG.md`, run `tools/build_zip.sh`, commit, then push a tag such as `v1.2.0`. The Release workflow runs the tests and publishes the GitHub Release with the zip and the changelog section as its notes.

When an eligible boss dies, you get a pulsing banner, a raid-warning sound and the boss's name.
The reminder stays up until the Real is in your bags. It repeats every 20 seconds when you're out of combat.

## Which bosses count

Bosses of level 55 or higher in:

- Blackrock Depths
- Blackrock Spire
- Dire Maul
- Scholomance
- Stratholme
- **Shaper's Terrace** (new, Un'Goro Crater)
- **Blackmaw Hold** (new, Azshara)

The addon reads each boss's level during the fight, so bosses under 55 (Lord Roccor, for example) are skipped.
If the game won't show the level, the addon reminds you anyway, because a needless reminder is better than a missed Real.

Each boss gives you one Real a day. Once you've looted it, you won't be reminded for that boss again until the daily reset.

The addon also learns as you play. If a Real ever shows up in a loot window in a dungeon that isn't on the list, that dungeon is added automatically.
You can also add the dungeon you're in with `/trr add`.

## Install

1. In the Battle.net app, select WoW: Forever, click the gear next to Play, and choose **Show in Explorer** (Finder on Mac).
2. Open `Interface\AddOns` inside that folder. Create it if it doesn't exist.
3. Unzip the latest zip from `releases/` there. You should end up with `Interface\AddOns\TarnishedRealReminder\`.
4. Restart the game or type `/reload`, then type `/trr test` to check that it works.

## Minimap button

Hover over the coin on the minimap to see:

- how many Reals you carry and how long until the daily reset;
- every boss you've looted today, grouped by dungeon, with how many Reals each gave;
- bosses still waiting to be looted (the button also shows a red dot while a Real is waiting);
- bosses you've met before in the current dungeon that you haven't looted today.

Left-click opens the settings, right-click shows a test reminder, and dragging moves the button around the minimap.
The same menu is in the addon list under the minimap (the Addon Compartment).
`/trr minimap` hides or shows the button.

## Customising the reminder

Open the settings with `/trr options`, a left-click on the minimap button, or **Options > AddOns > Camelus' Real Reminder**.
Changes apply right away, and the banner stays on screen as a preview while the window is open.

| Section | Settings |
|---|---|
| Banner | Width, height, scale, opacity, horizontal and vertical position (or untick Lock and drag it), frame layer, background colour, border style (none, solid line, gold dialog, silver dialog, tooltip), border colour and size |
| Text and icon | Title text, font, outline, alignment, title size and colour, boss-name size and colour, icon on or off, icon side and size, the hint line, the close button |
| Animation and sound | Animation (pulse, flash, bounce, shake, grow and shrink, glowing border, or none) and its speed; entrance effect (fade, zoom, slide, or none); sound on or off; built-in sound choice or your own file path or FileDataID; sound channel; repeat interval; raid-warning text; chat message; taskbar flash; minimap button |

**Reset look to defaults** puts the banner back the way it started without touching your other settings.

## Commands

| Command | What it does |
|---|---|
| `/trr` (or `/reals`) | Reals carried, bosses looted today, time until the daily reset, and the bosses seen in this dungeon |
| `/trr options` | Opens the settings window |
| `/trr test` | Shows a test reminder |
| `/trr clear` | Dismisses the waiting reminders (the X on the banner does the same) |
| `/trr reset` | Forgets what you looted today on this character |
| `/trr add` | Counts the dungeon you're in as a Real dungeon |
| `/trr unlock` / `/trr lock` | Move the banner |
| `/trr sound`, `/trr warning` | Turns the sound or the raid-warning text on or off |
| `/trr minimap` | Hides or shows the minimap button |
| `/trr nag <seconds>` | Sets how often the sound repeats while a Real is waiting (0 turns it off) |
| `/trr debug` | Prints why each kill did or didn't create a reminder |

## How it works (and why it isn't a WeakAura)

WoW: Forever runs the modern Retail/Midnight client, interface `16001`. On that client the combat log is closed to addons,
and many unit values are "secret" in instances. WeakAuras has no Forever version for that reason.

So the addon:

- detects boss kills from the game's own `ENCOUNTER_END` / `BOSS_KILL` events;
- if the client never sends those events, falls back to noticing a known boss dead when it's your target, focus,
  mouseover or boss frame;
- clears a reminder when your Real count goes up (it checks both bag items and the currency tab);
- warns you if you close a loot window that still has your Real in it;
- clears a reminder without a warning when you open that boss's corpse and there's no Real for you,
  which means you already took it today;
- checks every value for secrecy before using it, and wraps every client call that could fail in `pcall`.

## Known limits

- Drop rules for the two new dungeons come from early community guides. If a boss there doesn't drop a Real,
  close the banner with X and the addon won't ask again today.
- Matching is by name ("Undermine Real"), so it only works on English clients.
- On early Forever builds, saved variables sometimes failed to load. If that happens to you, the addon still works,
  but its list of bosses looted today starts empty after each restart.

## Tests

```bash
pip install lupa
```

```bash
python3 tests/run_tests.py
```

These run the addon under Lua 5.1 against a mocked client. They step through dungeon runs (kills, loot, the daily reset,
secret values, a client without encounter events, the Real stored as a currency), then drive the minimap tooltip and every
control in the settings window, and check that each animation, entrance, border, font and sound reaches the banner.
