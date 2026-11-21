-- Static data for Tarnished Real Reminder.
--
-- Nothing here has to be complete. The addon also learns as you play:
--   * any instance where a Real shows up in a loot window is added to the
--     eligible list automatically (covers dungeons missing below);
--   * every boss reported by the game's ENCOUNTER_END event is remembered by
--     name, with its level, so later kills are judged on what was seen.
local _, ns = ...

-- Minimum boss level that drops a Real.
ns.MIN_BOSS_LEVEL = 55

-- Lower-cased fragment of the item / currency name. Matching on a fragment
-- tolerates "Tarnished Undermine Real" and "Tarnished Undermine Reals".
ns.REAL_NAME_FRAGMENT = "undermine real"
ns.REAL_DISPLAY_NAME = "Tarnished Undermine Real"
ns.REAL_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Coin_17"

-- Dungeons whose level 55+ bosses drop a Real once per day.
-- Keyed by instance ID (8th return of GetInstanceInfo) where known, and by
-- lower-cased instance name so new dungeons work without knowing their ID.
ns.ELIGIBLE_INSTANCE_IDS = {
    [230] = "Blackrock Depths",
    [229] = "Blackrock Spire",
    [429] = "Dire Maul",
    [289] = "Scholomance",
    [329] = "Stratholme",
}

ns.ELIGIBLE_INSTANCE_NAMES = {
    ["blackrock depths"] = true,
    ["blackrock spire"] = true,
    ["lower blackrock spire"] = true,
    ["upper blackrock spire"] = true,
    ["dire maul"] = true,
    ["scholomance"] = true,
    ["stratholme"] = true,
    -- New level 55-60 dungeons in WoW: Forever.
    ["shaper's terrace"] = true,
    ["the shaper's terrace"] = true,
    ["blackmaw hold"] = true,
}

-- Boss names, used only as a fallback when the game does not report a kill
-- through ENCOUNTER_END: if one of these is seen dead (target, focus,
-- mouseover or a boss frame) it counts as a kill. Bosses below level 55 are
-- still filtered out by their level when the addon could read it.
ns.BOSS_NAMES = {}
local function add(list)
    for _, name in ipairs(list) do ns.BOSS_NAMES[name:lower()] = true end
end

-- Blackrock Depths
add({
    "High Interrogator Gerstahn", "Lord Roccor", "Houndmaster Grebmar",
    "Anub'shiah", "Eviscerator", "Gorosh the Dervish", "Grizzle",
    "Hedrum the Creeper", "Ok'thor the Breaker", "Theldren",
    "Pyromancer Loregrain", "Warder Stilgiss", "Verek", "Watchman Doomgrip",
    "Fineous Darkvire", "Lord Incendius", "Bael'Gar", "General Angerforge",
    "Golem Lord Argelmach", "Hurley Blackbreath", "Phalanx",
    "Ribbly Screwspigot", "Plugger Spazzring", "Ambassador Flamelash",
    "Doom'rel", "Magmus", "Princess Moira Bronzebeard",
    "Emperor Dagran Thaurissan",
})
-- Blackrock Spire (lower and upper)
add({
    "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone",
    "Mother Smolderweb", "Urok Doomhowl", "Quartermaster Zigris", "Halycon",
    "Gizrul the Slavener", "Overlord Wyrmthalak", "Pyroguard Emberseer",
    "Solakar Flamewreath", "Goraluk Anvilcrack", "Warchief Rend Blackhand",
    "The Beast", "General Drakkisath",
})
-- Dire Maul
add({
    "Pusillin", "Zevrim Thornhoof", "Hydrospawn", "Lethtendris",
    "Alzzin the Wildshaper", "Tendris Warpwood", "Illyanna Ravenoak",
    "Magister Kalendris", "Immol'thar", "Prince Tortheldrin",
    "Guard Mol'dar", "Stomper Kreeg", "Guard Fengus", "Guard Slip'kik",
    "Captain Kromcrush", "Cho'Rush the Observer", "King Gordok",
})
-- Scholomance
add({
    "Kirtonos the Herald", "Jandice Barov", "Rattlegore", "Marduk Blackpool",
    "Vectus", "Ras Frostwhisper", "Instructor Malicia",
    "Doctor Theolen Krastinov", "Lorekeeper Polkelt", "The Ravenian",
    "Lord Alexei Barov", "Lady Illucia Barov", "Darkmaster Gandling",
})
-- Stratholme
add({
    "Timmy the Cruel", "Malor the Zealous", "Cannon Master Willey",
    "Archivist Galford", "Balnazzar", "Hearthsinger Forresten",
    "The Unforgiven", "Magistrate Barthilas", "Nerub'enkan",
    "Baroness Anastari", "Maleki the Pallid", "Ramstein the Gorger",
    "Baron Rivendare", "Postmaster Malown",
})
-- Shaper's Terrace (WoW: Forever). Names from early community guides; the
-- addon learns the real ones from the game as you kill them.
add({
    "Titanosaur", "Thunderhoof", "Venomridge", "Direhorn Matriarch",
    "Izha'Rel", "Tor'Rel", "Cinder", "King Op", "Snowtalon", "Bolt",
    "Vitrix", "Nanaya",
})
-- Blackmaw Hold (WoW: Forever). Same caveat.
add({
    "Withermaw", "Impaan the Imprisoner", "Elder Shaman Bloodmane",
    "Bonesnout the Unbroken", "Blackmaw Behemoth", "Unbound Spirit",
    "Varrox Bleakhoof",
})

------------------------------------------------------------------------------
-- Boss checklist (the "Bosses today" tab in the settings window)
--
-- One entry per boss encounter, in dungeon order. Names follow the game's
-- encounter names where known (Scholomance is taken from what the game
-- reports in WoW: Forever); "aliases" lists other names guides use, so a kill
-- reported under either name ticks the same row. "low" marks bosses below
-- level 55 in Classic, which drop no Real; a level the addon reads in game
-- always wins over this. Bosses the game reports that are not listed here are
-- added to the checklist automatically, and names are also matched loosely
-- ("Kirtonos" = "Kirtonos the Herald").
------------------------------------------------------------------------------
ns.ROSTER = {
    {
        name = "Blackrock Depths", ids = { 230 },
        bosses = {
            { "High Interrogator Gerstahn", low = true },
            { "Lord Roccor", low = true },
            { "Houndmaster Grebmar", low = true },
            { "Ring of Law", aliases = { "Gorosh the Dervish", "Grizzle", "Eviscerator", "Ok'thor the Breaker", "Anub'shiah", "Hedrum the Creeper" } },
            { "Pyromancer Loregrain", low = true },
            { "Lord Incendius", low = true },
            { "Warder Stilgiss", aliases = { "Verek" } },
            { "Fineous Darkvire", low = true },
            { "Bael'Gar", low = true },
            { "General Angerforge" },
            { "Golem Lord Argelmach" },
            { "Hurley Blackbreath" },
            { "Phalanx" },
            { "Ribbly Screwspigot" },
            { "Plugger Spazzring" },
            { "Ambassador Flamelash" },
            { "The Seven", aliases = { "Doom'rel" } },
            { "Magmus" },
            { "Emperor Dagran Thaurissan", aliases = { "Princess Moira Bronzebeard" } },
        },
    },
    {
        name = "Blackrock Spire", ids = { 229 },
        instanceNames = { "lower blackrock spire", "upper blackrock spire" },
        bosses = {
            { "Highlord Omokk" },
            { "Shadow Hunter Vosh'gajin" },
            { "War Master Voone" },
            { "Mother Smolderweb" },
            { "Urok Doomhowl" },
            { "Quartermaster Zigris" },
            { "Halycon" },
            { "Gizrul the Slavener" },
            { "Overlord Wyrmthalak" },
            { "Pyroguard Emberseer" },
            { "Solakar Flamewreath" },
            { "Warchief Rend Blackhand", aliases = { "Gyth" } },
            { "The Beast" },
            { "General Drakkisath" },
        },
    },
    {
        name = "Dire Maul", ids = { 429 },
        bosses = {
            { "Zevrim Thornhoof" },
            { "Hydrospawn" },
            { "Lethtendris" },
            { "Alzzin the Wildshaper" },
            { "Tendris Warpwood" },
            { "Illyanna Ravenoak" },
            { "Magister Kalendris" },
            { "Immol'thar" },
            { "Prince Tortheldrin" },
            { "Guard Mol'dar" },
            { "Stomper Kreeg" },
            { "Guard Fengus" },
            { "Guard Slip'kik" },
            { "Captain Kromcrush" },
            { "King Gordok", aliases = { "Cho'Rush the Observer" } },
        },
    },
    {
        name = "Scholomance", ids = { 289 },
        bosses = {
            { "Kirtonos", aliases = { "Kirtonos the Herald" } },
            { "Jandice Barov" },
            { "Rattlegore" },
            { "Marduk Blackpool" },
            { "Vectus" },
            { "Ras Frostwhisperer", aliases = { "Ras Frostwhisper" } },
            { "Instructor Malicia" },
            { "Doctor Theolen Krastinov" },
            { "Lorekeeper Polkelt" },
            { "The Ravenian" },
            { "Lord Alexei Barov" },
            { "Lady Illucia Barov" },
            { "Darkmaster Gandling" },
        },
    },
    {
        name = "Stratholme", ids = { 329 },
        bosses = {
            { "Hearthsinger Forresten" },
            { "Timmy the Cruel" },
            { "Malor the Zealous", aliases = { "Commander Malor" } },
            { "Cannon Master Willey", aliases = { "Willey Hopebreaker" } },
            { "Archivist Galford", aliases = { "Instructor Galford" } },
            { "Balnazzar", aliases = { "Grand Crusader Dathrohan" } },
            { "The Unforgiven" },
            { "Baroness Anastari" },
            { "Nerub'enkan" },
            { "Maleki the Pallid" },
            { "Magistrate Barthilas" },
            { "Ramstein the Gorger" },
            { "Baron Rivendare", aliases = { "Lord Aurius Rivendare" } },
        },
    },
    {
        name = "Shaper's Terrace", instanceNames = { "the shaper's terrace" },
        bosses = {
            { "Titanosaur" }, { "Ravasaur Hunters", aliases = { "Izha'Rel", "Tor'Rel" } },
            { "Thunderhoof" }, { "Venomridge" }, { "Direhorn Matriarch" },
            { "Cinder" }, { "King Op" }, { "Snowtalon" }, { "Bolt" }, { "Vitrix" }, { "Nanaya" },
        },
    },
    {
        name = "Blackmaw Hold",
        bosses = {
            { "Withermaw" }, { "Impaan the Imprisoner" }, { "Elder Shaman Bloodmane" },
            { "Bonesnout the Unbroken" }, { "Blackmaw Behemoth" }, { "Unbound Spirit" },
            { "Varrox Bleakhoof" },
        },
    },
}
