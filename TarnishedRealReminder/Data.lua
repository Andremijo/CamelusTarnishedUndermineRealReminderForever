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
