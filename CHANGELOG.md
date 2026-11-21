# Changelog

Each `## vX.Y.Z` section below becomes the notes of that version's GitHub Release, published automatically when the version reaches `main`.

## v1.2.3

**Install or update:** WoWUp picks this up automatically. To install by hand, unzip the `-forever.zip` below into your WoW: Forever `Interface\AddOns` folder.

### Fixed
- **Ribbly Screwspigot and Plugger Spazzring no longer remind you.** Neither is in Wowhead's Forever dungeon journal, but the game reports both as bosses. Ribbly is level 53 and Plugger level 55, and both are confirmed in game to drop no Real. They're now in the Blackrock Depths list as optional, and the checklist shows "drops no Real".

## v1.2.2

**Install or update:** WoWUp picks this up automatically. To install by hand, unzip the `-forever.zip` below into your WoW: Forever `Interface\AddOns` folder.

### Fixed
- **Level 55 is only a guide, so what happens in game now wins.**
  - **Warder Stilgiss & Verek no longer remind you.** Stilgiss is level 56 but drops no Real. The checklist shows "drops no Real".
  - **Fineous Darkvire reminds you again.** He's level 54 but does drop a Real. Version 1.2.1 had stopped reminding about him.
  - **High Interrogator Gerstahn and Lord Roccor** are confirmed in game to drop no Real, and never remind you.
- **The addon learns both ways from loot:**
  - **A boss gives you a Real the addon didn't expect** (a boss below 55): it's recorded as looted for today, so you aren't reminded about it again today, and the addon reminds you about that boss from then on.
  - **A boss's own corpse has no Real for you** on a day you hadn't looted it: the addon stops reminding about it, whatever its level.

  Whichever happened last counts. Ring of the Law is never learned, and `/trr relearn` forgets everything learned.
- **Wowhead's level beats what's read in game.** For bosses without such evidence, Wowhead's Forever level now wins over a level read during the fight, which can belong to an add, be hidden, or be a wrong value saved by an older version. The addon also no longer takes the highest level of all boss frames in a fight (an add's could win), and never saves an add's level as the boss's.
- Reminders still waiting for a boss that turns out to drop no Real disappear at the next loading screen.

## v1.2.1

**Install or update:** WoWUp picks this up automatically. To install by hand, unzip the `-forever.zip` below into your WoW: Forever `Interface\AddOns` folder.

### Fixed
- **No more reminders for bosses below level 55**, such as High Interrogator Gerstahn (52) in Blackrock Depths. In dungeons the game often won't tell addons a boss's level, and the addon then reminded you to be safe. It now knows every boss's level from Wowhead's WoW: Forever database:
  - **Blackrock Depths** is the only dungeon with bosses below 55: Gerstahn, Lord Roccor, Houndmaster Grebmar, Fineous Darkvire, Pyromancer Loregrain, Bael'gar and Lord Incendius. These no longer remind you.
  - **Every boss in Blackrock Spire, Dire Maul, Scholomance and Stratholme** is level 56–62 and reminds you as before.
  - **Shaper's Terrace and Blackmaw Hold** have no levels on Wowhead yet. They're max-level dungeons whose loot needs level 55, so their bosses remind you.
  - **Level read in game:** when the addon can read a boss's level, that still decides.
- **Ring of the Law picks a random challenger.** Gorosh the Dervish (56) drops a Real; Grizzle, Eviscerator and Anub'shiah (54) and Hedrum and Ok'thor (53) don't. The addon now looks at who you actually fought, from the boss frame or your target, and reminds you only for Gorosh. If it can't tell, it reminds you.
- A waiting reminder left over for a below-55 boss disappears at the next loading screen.
- The checklist shows these bosses as "level 52, no Real" and so on, and leaves them out of the dungeon's count.

### New
- **Learns which bosses drop no Real**, for bosses Wowhead has no level for, such as the new dungeons. If you open a boss's own corpse and there's no Real for you on a day you hadn't looted it, it doesn't drop Reals, so the addon remembers this and stops reminding you about it.
  - It never learns from trash loot, and never learns Ring of the Law.
  - Looting a Real from a learned boss unlearns it.
  - The checklist shows "no Real (learned)".
  - `/trr relearn` forgets everything learned.

## v1.2.0

**Install or update:** WoWUp picks this up automatically. To install by hand, unzip the `-forever.zip` below into your WoW: Forever `Interface\AddOns` folder.

### New
- **Boss checklist.** The settings window has a new **Bosses today** tab. Open it with `/cturr bosses` or shift-click the minimap button. It lists every boss that drops a Real, grouped by dungeon, with today's status:
  - **looted** (and how many Reals);
  - **nothing for you**;
  - **killed, not looted** (in red);
  - **not looted**;
  - **below 55**;
  - **ignored**.

  Each dungeon shows a count such as `13/13` in green when done, or in red when a Real was missed. Hover over a boss for details. Right-click a boss to ignore it if it doesn't exist in this version of the game or never drops a Real.
- **Boss lists from Wowhead.** The lists follow Wowhead's WoW: Forever Dungeon Journal, split the way the journal splits them:
  - Lower and Upper Blackrock Spire;
  - Dire Maul East, West and North;
  - Stratholme Live and Undead.

  Shaper's Terrace and Blackmaw Hold come from Wowhead's Forever guides and statistics, since they have no journal page yet.
- **Optional bosses.** Rares and summoned or quest bosses are marked *optional*. They're listed but only counted once they give you a Real.
- **Game names.** The game sometimes reports a different name than the journal uses, for example "Kirtonos" for "Kirtonos the Herald" or "Ras Frostwhisperer" for "Ras Frostwhisper". Both tick the same row, and the row switches to the game's name. Bosses the list doesn't know are added automatically.
- **Minimap tooltip setting.** Under Appearance > Animation and sound, "Minimap tooltip shows" picks what the tooltip lists:
  - **Looted bosses** (as before);
  - **Bosses not looted yet**;
  - **Looted and not looted**.

  Dungeons you haven't started today show only their count, to keep the tooltip short.

### Fixed
- A Real looted in one dungeon no longer ticks off a boss you missed in another dungeon.
- The banner and its repeat sound only remind you of bosses in the dungeon you're in. Reals missed elsewhere show in the checklist and the tooltip instead. The banner's X only dismisses what it shows.
- The first boss in a dungeon the addon learns about from its first Real is now recorded too.

## v1.1.2

**Install or update:** WoWUp picks this up automatically. To install by hand, unzip the `-forever.zip` below into your WoW: Forever `Interface\AddOns` folder.

### Fixed
- The reminder no longer shows its text twice on top of itself. The big "Loot the Tarnished Undermine Real from …" text used the game's raid-warning frame, which sits right where the banner is. It now has its own frame, and by default that frame sits under the banner.

### New
- **Movable warning text.** A new **Warning text** column in the settings (`/cturr`) controls it:
  - on or off;
  - horizontal and vertical position, or untick **Lock** and drag it;
  - text size, colour, font and outline;
  - how many seconds it stays before fading out.
  There's also **Show test warning** and **Reset warning to defaults**.
- The game's own raid-warning frame is left alone, so raid leaders' warnings still appear where they always did.

## v1.1.1

**Install or update:** WoWUp picks this up automatically. To install by hand, unzip the `-forever.zip` below into your WoW: Forever `Interface\AddOns` folder.

### Fixed
- The minimap button is now a standard LibDBIcon button. Minimap-button collectors and broker bars recognise it, so they show its name and tooltip instead of "This is a custom button. Please ask the addon author to use the standard LibDBIcon library instead."
- The minimap tooltip's headline is now "Camelus' Tarnished Undermine Real Reminder".

### New
- `/cturr` opens the settings window. `/cturr <command>` works like `/trr <command>`.

### Notes
- Bundles LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 (see `Libs/README.md`).
- Your minimap button position from v1.1.0 is kept.

## v1.1.0

**Install:** in WoWUp, use **Install from URL** with `https://github.com/Andremijo/CamelusTarnishedUndermineRealReminderForever`. Or download the `-forever.zip` below and unzip it into your WoW: Forever `Interface\AddOns` folder. Then type `/reload` and `/trr options`.

### New
- **Minimap button.** Hover over it to see today's looted bosses grouped by dungeon, bosses still waiting, Reals carried and the time until the daily reset. A red dot shows while a Real is waiting. Left-click opens settings, right-click shows a test reminder, and dragging moves it. It's also in the addon list under the minimap.
- **Settings window.** Open it with `/trr options`, the minimap button, or Options > AddOns. You can set:
  - **Banner:** width, height, scale, opacity, position, frame layer, background colour, border style (none, solid, gold, silver, tooltip), border colour and size.
  - **Text and icon:** title text, font, outline, alignment, text sizes and colours, icon on or off, icon side and size.
  - **Animations:** pulse, flash, bounce, shake, grow, glowing border, with adjustable speed. **Entrance effects:** fade, zoom, slide.
  - **Sound:** 8 built-in sounds or your own file path or FileDataID, sound channel and repeat interval. Raid-warning text, chat message and taskbar flash can each be turned on or off.
- The addon is now named **Camelus' Tarnished Undermine Real Reminder**.

### Changed
- A locked banner no longer blocks clicks on whatever is behind it.
- Settings from v1.0.0 are kept when you upgrade.

## v1.0.0

- First version. When a level 55+ boss dies in Blackrock Depths, Blackrock Spire, Dire Maul, Scholomance, Stratholme, Shaper's Terrace or Blackmaw Hold, you get a reminder to loot its Tarnished Undermine Real. Each boss is tracked once per day.
