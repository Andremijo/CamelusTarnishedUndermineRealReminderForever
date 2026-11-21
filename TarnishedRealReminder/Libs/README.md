# Embedded libraries

These are unmodified copies of the standard WoW libraries used to make the minimap button.
Minimap-button collectors and broker displays (Titan Panel, ChocolateBar and others) recognise buttons built with them.

| Library | Version | Licence | Source |
|---|---|---|---|
| LibStub | minor 2 | Public domain (see the file header) | Ace3 / wowace.com |
| CallbackHandler-1.0 | minor 8 | Ace3 BSD-style licence, `CallbackHandler-1.0/LICENSE.txt` | Ace3 / wowace.com |
| LibDataBroker-1.1 | — | Distributed by its author for embedding in addons (curseforge.com/wow/addons/libdatabroker-1-1) | github.com/tekkub/libdatabroker-1-1, identical copy |
| LibDBIcon-1.0 | minor 56 | Ace3 BSD-style, as stated on curseforge.com/wow/addons/libdbicon-1-0 | wowace.com, taken from the copy shipped in Questie (Nov 2026), which runs on WoW: Forever |

LibStub only loads the newest copy of each library across all addons.
If another addon ships a newer LibDBIcon, that newer copy is the one used.
