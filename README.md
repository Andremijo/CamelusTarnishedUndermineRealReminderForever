# Tarnished Real Reminder (WoW: Forever)

An addon that reminds you to loot your **Tarnished Undermine Real** from every boss that drops one,
once per boss per day.

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
3. Copy the `TarnishedRealReminder` folder from this repository into it.
4. Restart the game or type `/reload`, then type `/trr test` to check that it works.

## Commands

| Command | What it does |
|---|---|
| `/trr` (or `/reals`) | Reals carried, bosses looted today, time until the daily reset, and the bosses seen in this dungeon |
| `/trr test` | Shows a test reminder |
| `/trr clear` | Dismisses the waiting reminders (the X on the banner does the same) |
| `/trr reset` | Forgets what you looted today on this character |
| `/trr add` | Counts the dungeon you're in as a Real dungeon |
| `/trr unlock` / `/trr lock` | Move the banner |
| `/trr sound`, `/trr warning` | Turns the sound or the raid-warning text on or off |
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

These run the addon under Lua 5.1 against a mocked client and step through dungeon runs: kills, loot, the daily reset,
secret values, a client without encounter events, and the Real stored as a currency.
