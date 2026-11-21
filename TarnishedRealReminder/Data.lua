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
    -- Wing names the game may report for split dungeons.
    ["dire maul - warpwood quarter"] = true,
    ["dire maul - capital gardens"] = true,
    ["dire maul - gordok commons"] = true,
    ["warpwood quarter"] = true,
    ["capital gardens"] = true,
    ["gordok commons"] = true,
    ["stratholme - main gate"] = true,
    ["stratholme - service entrance"] = true,
    ["stratholme live"] = true,
    ["stratholme undead"] = true,
}

------------------------------------------------------------------------------
-- Boss checklist (the "Bosses today" tab in the settings window)
--
-- Boss lists and order follow Wowhead's WoW: Forever Dungeon Journal
-- (wowhead.com/forever/dungeon-journal/...), November 2026. For Shaper's
-- Terrace and Blackmaw Hold, which have no journal page there yet, they come
-- from Wowhead's Forever guides, zone pages, kill statistics and hotfix notes.
--
--   aliases   other names for the same boss. The game's own encounter names
--             (what ENCOUNTER_END reports, e.g. "Kirtonos") can differ from
--             the journal's ("Kirtonos the Herald"); either ticks the row,
--             and the row then shows the game's name.
--   optional  rares, summoned and quest bosses: listed, but only counted
--             once you get a Real from them.
--   low       below level 55 in Classic, so no Real; a level the addon
--             reads in game always wins over this.
--
-- instanceNames: the names GetInstanceInfo may report for the group, when
-- they differ from the group name. Groups sharing an instance (the two halves
-- of Blackrock Spire, the three wings of Dire Maul, both sides of
-- Stratholme) are told apart by boss name. Bosses the game reports that are
-- not listed here are added to the checklist automatically.
------------------------------------------------------------------------------
ns.ROSTER = {
    {
        name = "Blackrock Depths", ids = { 230 },
        bosses = {
            { "High Interrogator Gerstahn", low = true },
            { "Lord Roccor", low = true },
            { "Houndmaster Grebmar", low = true },
            { "Ring of the Law", aliases = { "Ring of Law", "Gorosh the Dervish", "Grizzle", "Eviscerator",
                                             "Ok'thor the Breaker", "Anub'shiah", "Hedrum the Creeper" } },
            { "Fineous Darkvire", low = true },
            { "Pyromancer Loregrain", low = true },
            { "Bael'gar", low = true },
            { "Lord Incendius", low = true },
            { "General Angerforge" },
            { "Golem Lord Argelmach" },
            { "Phalanx" },
            { "Hurley Blackbreath" },
            { "Ambassador Flamelash" },
            { "Chest of the Seven", aliases = { "The Seven", "Doom'rel" } },
            { "Magmus" },
            { "Emperor Dagran Thaurissan", aliases = { "Princess Moira Bronzebeard" } },
            { "Warder Stilgiss & Verek", aliases = { "Warder Stilgiss", "Verek" }, optional = true },
            { "Panzor the Invincible", optional = true },
        },
    },
    {
        name = "Lower Blackrock Spire", ids = { 229 },
        instanceNames = { "blackrock spire", "lower blackrock spire" },
        bosses = {
            { "Highlord Omokk" },
            { "Shadow Hunter Vosh'gajin" },
            { "War Master Voone" },
            { "Mor Grayhoof", optional = true },
            { "Mother Smolderweb" },
            { "Urok Doomhowl" },
            { "Quartermaster Zigris" },
            { "Halycon" },
            { "Gizrul the Slavener" },
            { "Overlord Wyrmthalak" },
            { "Spirestone Butcher", optional = true },
            { "Spirestone Battle Lord", optional = true },
            { "Bannok Grimaxe", optional = true },
            { "Crystal Fang", optional = true },
        },
    },
    {
        name = "Upper Blackrock Spire", ids = { 229 },
        instanceNames = { "blackrock spire", "upper blackrock spire" },
        bosses = {
            { "Pyroguard Emberseer" },
            { "Solakar Flamewreath" },
            { "Goraluk Anvilcrack" },
            { "Warchief Rend Blackhand & Gyth", aliases = { "Warchief Rend Blackhand", "Gyth" } },
            { "The Beast" },
            { "General Drakkisath" },
            { "Jed Runewatcher", optional = true },
        },
    },
    {
        name = "Dire Maul East", ids = { 429 },
        instanceNames = { "dire maul", "dire maul - warpwood quarter", "warpwood quarter" },
        bosses = {
            { "Pusillin" },
            { "Lethtendris" },
            { "Hydrospawn" },
            { "Zevrim Thornhoof" },
            { "Alzzin the Wildshaper" },
            { "Isalien", optional = true },
        },
    },
    {
        name = "Dire Maul West", ids = { 429 },
        instanceNames = { "dire maul", "dire maul - capital gardens", "capital gardens" },
        bosses = {
            { "Tendris Warpwood" },
            { "Magister Kalendris" },
            { "Illyanna Ravenoak" },
            { "Immol'thar" },
            { "Prince Tortheldrin" },
            { "Tzu'see", aliases = { "Tsu'zee" }, optional = true },
            { "Lord Hel'nurath", optional = true },
        },
    },
    {
        name = "Dire Maul North", ids = { 429 },
        instanceNames = { "dire maul", "dire maul - gordok commons", "gordok commons" },
        bosses = {
            { "Guard Mol'dar" },
            { "Stomper Kreeg" },
            { "Guard Fengus" },
            { "Guard Slip'kik" },
            { "Captain Kromcrush" },
            { "King Gordok & Cho'Rush the Observer", aliases = { "King Gordok", "Cho'Rush the Observer" } },
        },
    },
    {
        name = "Scholomance", ids = { 289 },
        bosses = {
            { "Blood Steward of Kirtonos", optional = true },
            { "Kirtonos the Herald", aliases = { "Kirtonos" } },
            { "Jandice Barov" },
            { "Rattlegore" },
            { "Marduk Blackpool" },
            { "Vectus" },
            { "Ras Frostwhisper", aliases = { "Ras Frostwhisperer" } },
            { "Kormok", optional = true },
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
        name = "Stratholme Live", ids = { 329 },
        instanceNames = { "stratholme", "stratholme - main gate", "stratholme live" },
        bosses = {
            { "Ezra Grimm" },
            { "The Unforgiven" },
            { "Postmaster Malown" },
            { "Timmy the Cruel" },
            { "Malor the Zealous", aliases = { "Commander Malor" } },
            { "Cannon Master Willey", aliases = { "Willey Hopebreaker" } },
            { "Archivist Galford", aliases = { "Instructor Galford" } },
            { "Balnazzar", aliases = { "Grand Crusader Dathrohan" } },
            { "Skul", optional = true },
            { "Hearthsinger Forresten", optional = true },
        },
    },
    {
        name = "Stratholme Undead", ids = { 329 },
        instanceNames = { "stratholme", "stratholme - service entrance", "stratholme undead" },
        bosses = {
            { "Magistrate Barthilas" },
            { "Nerub'enkan" },
            { "Baroness Anastari" },
            { "Maleki the Pallid" },
            { "Ramstein the Gorger" },
            { "Baron Rivendare", aliases = { "Lord Aurius Rivendare" } },
            { "Stonespine", optional = true },
        },
    },
    {
        -- The four raptors (summoned with Power Crystals) open the way to the
        -- final boss, Nanaya. Wowhead mentions optional dinosaurs too, without
        -- names; they are added automatically when killed.
        name = "The Shaper's Terrace", instanceNames = { "shaper's terrace", "the shaper's terrace" },
        bosses = {
            { "Cinder" }, { "Snowtalon" }, { "Bolt" }, { "Vitrix" }, { "Nanaya" },
        },
    },
    {
        name = "Blackmaw Hold",
        bosses = {
            { "Withermaw" },
            { "Impaan the Imprisoner" },
            { "Bonesnout the Unbroken" },
            { "Unbound Spirit" },
            { "Clawbert and the Blackmaw Behemoth", aliases = { "Blackmaw Behemoth", "Clawbert" } },
            { "Elder Shaman Bloodmane" },
            { "Varrox Bleakhoof" },
            { "Moontouched Wanderer", optional = true },
            { "Tunnelweb Matriarch", optional = true },
            { "Mopes", optional = true },
            { "Gortek the Apprentice", optional = true },
        },
    },
}

-- Boss names used only as a fallback when the game does not report a kill
-- through ENCOUNTER_END: if one of these is seen dead (target, focus,
-- mouseover or a boss frame) it counts as a kill. Built from ns.ROSTER so
-- there is one list to maintain.
ns.BOSS_NAMES = {}
for _, def in ipairs(ns.ROSTER) do
    for _, b in ipairs(def.bosses) do
        ns.BOSS_NAMES[b[1]:lower()] = true
        for _, a in ipairs(b.aliases or {}) do ns.BOSS_NAMES[a:lower()] = true end
    end
end
