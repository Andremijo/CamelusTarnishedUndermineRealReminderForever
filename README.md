# Camelus' Tarnished Undermine Real Reminder (WoW: Forever)

An addon that reminds you to loot your **Tarnished Undermine Real** from every boss that drops one,
once per boss per day.

**Install with WoWUp (recommended):** in WoWUp 2.24.1 or later, pick your WoW: Forever installation, open **Get Addons**, choose **Install from URL**, and paste:

```
https://github.com/Andremijo/CamelusTarnishedUndermineRealReminderForever
```

WoWUp then keeps it updated from this repository's GitHub Releases.

**Manual download:** get the zip from the latest [GitHub Release](../../releases/latest). The same zips are also kept in [`releases/`](releases/), each with its version in the name.

**Making a release:** bump `## Version` in the `.toc`, add a `## vX.Y.Z` section to `CHANGELOG.md`, run `tools/build_zip.sh`, commit, and merge to `main`. The Release workflow sees the new version, runs the tests, and publishes the GitHub Release (tag `vX.Y.Z`) with the zip and that changelog section as its notes. A version that's already released is skipped.

Each release is laid out the way WoWUp's GitHub support expects: the zip asset's name ends in `-forever.zip` (GitHub doesn't allow spaces or apostrophes in asset file names, so the asset is `Camelus-Tarnished-Undermine-Real-Reminder-vX.Y.Z-forever.zip`, labelled "Camelus' Tarnished Undermine Real Reminder vX.Y.Z"), and a `release.json` lists it under the `forever` flavor. `tools/release_assets.py` builds and checks these files; the workflow re-checks the published release.

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
In dungeons the game often won't tell addons a boss's level. Then the addon uses its boss list, which marks the Blackrock Depths bosses below 55, such as High Interrogator Gerstahn.
For a boss it knows nothing about, it reminds you anyway, because a needless reminder is better than a missed Real.
If you then open that boss's corpse and there's no Real for you, the addon learns that the boss doesn't drop one and won't remind you again (`/trr relearn` undoes this).

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

Left-click opens the settings, shift-click opens the boss checklist, right-click shows a test reminder, and dragging moves the button around the minimap.
In the settings you can choose whether the tooltip lists the bosses you've looted, the ones you haven't, or both ("Minimap tooltip shows").
It's a standard LibDBIcon button, so minimap-button collectors and broker bars (Titan Panel, ChocolateBar and others) list it as "Camelus' Tarnished Undermine Real Reminder".
The same menu is in the addon list under the minimap (the Addon Compartment).
`/trr minimap` hides or shows the button.

## Boss checklist

The settings window's **Bosses today** tab lists every boss that drops a Real, grouped by dungeon, with today's status: looted (and how many Reals), nothing for you, killed but not looted (red), not looted, below 55, or ignored.
Each dungeon shows a count such as `13/13`. It's green when the dungeon is done and red when you killed a boss there without looting its Real.

Open it with `/cturr bosses` or by shift-clicking the minimap button.
Hover over a boss for details. Right-click a boss to ignore it if it doesn't exist in this version of the game or never drops a Real.
The boss lists follow Wowhead's WoW: Forever Dungeon Journal, including its split into Lower/Upper Blackrock Spire, Dire Maul East/West/North and Stratholme Live/Undead. Shaper's Terrace and Blackmaw Hold come from Wowhead's Forever guides, since they have no journal page yet.
Rares and summoned or quest bosses are marked optional: they're listed, but only counted once they give you a Real.
When the game reports a boss under a different name than the journal ("Kirtonos" for "Kirtonos the Herald"), the row switches to the game's name. Bosses the game reports that aren't in the list are added automatically.

## Customising the reminder

Open the settings with `/cturr` (or `/trr options`), a left-click on the minimap button, or **Options > AddOns > Camelus' Real Reminder**.
Changes apply right away, and the banner stays on screen as a preview while the window is open.

| Section | Settings |
|---|---|
| Banner | Width, height, scale, opacity, horizontal and vertical position (or untick Lock and drag it), frame layer, background colour, border style (none, solid line, gold dialog, silver dialog, tooltip), border colour and size |
| Text and icon | Title text, font, outline, alignment, title size and colour, boss-name size and colour, icon on or off, icon side and size, the hint line, the close button |
| Animation and sound | Animation (pulse, flash, bounce, shake, grow and shrink, glowing border, or none) and its speed; entrance effect (fade, zoom, slide, or none); sound on or off; built-in sound choice or your own file path or FileDataID; sound channel; repeat interval; chat message; taskbar flash; minimap button |
| Warning text | The big text that names the boss: on or off, position (sliders, or untick Lock and drag it), size, colour, font, outline, and how long it stays before fading. By default it sits under the banner. It's the addon's own frame, so raid leaders' warnings aren't affected |

**Reset look to defaults** puts the banner back the way it started without touching your other settings.

## Commands

| Command | What it does |
|---|---|
| `/trr` (or `/reals`) | Reals carried, bosses looted today, time until the daily reset, and the bosses seen in this dungeon |
| `/cturr` (or `/trr options`) | Opens the settings window. `/cturr <command>` also works like `/trr <command>` |
| `/cturr bosses` | Opens today's boss checklist |
| `/trr test` | Shows a test reminder |
| `/trr clear` | Dismisses the waiting reminders (the X on the banner does the same) |
| `/trr reset` | Forgets what you looted today on this character |
| `/trr relearn` | Forgets which bosses the addon learned drop no Real |
| `/trr add` | Counts the dungeon you're in as a Real dungeon |
| `/trr unlock` / `/trr lock` | Move the banner |
| `/trr sound`, `/trr warning` | Turns the sound or the warning text on or off |
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
