# Changelog

Each `## vX.Y.Z` section below becomes the notes of that version's GitHub Release, published automatically when the version reaches `main`.

## v1.1.0

**Install:** download the zip below and unzip it into your WoW: Forever `Interface\AddOns` folder. Then type `/reload` and `/trr options`.

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
