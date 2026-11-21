# Changelog

Each `## vX.Y.Z` section below becomes the notes of that version's GitHub Release, published automatically when the version reaches `main`.

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
