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
--   noReal    confirmed in game not to drop a Real, whatever its level
--             (Warder Stilgiss is 56 and drops none).
--   likelyNoReal  very likely no Real (not on the drop list, and a similar
--             boss is confirmed): no reminder, but unlike noReal the addon
--             still learns it if one does give you a Real.
--   real      confirmed in game to drop a Real, whatever its level (Fineous
--             Darkvire is 54 and drops one). The "55+" rule is only a guide.
--   variable  the boss you fight changes from run to run (Ring of the Law
--             picks one challenger; some are level 55+, some aren't). Its
--             eligibility comes from the challenger seen in the fight, and the
--             addon never "learns" it as no-Real.
--
-- Boss levels are in ns.BOSS_LEVELS below.
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
            { "High Interrogator Gerstahn", noReal = true }, -- confirmed in game: no Real
            { "Lord Roccor", noReal = true },                -- confirmed in game: no Real
            { "Houndmaster Grebmar" },
            { "Ring of the Law", variable = true, aliases = { "Ring of Law", "Gorosh the Dervish", "Grizzle", "Eviscerator",
                                             "Ok'thor the Breaker", "Anub'shiah", "Hedrum the Creeper" } },
            -- Level 54, but confirmed in game to drop a Real.
            { "Fineous Darkvire", real = true },
            { "Pyromancer Loregrain" },
            { "Bael'gar" },
            { "Lord Incendius" },
            { "General Angerforge" },
            { "Golem Lord Argelmach" },
            { "Phalanx" },
            { "Hurley Blackbreath" },
            { "Ambassador Flamelash" },
            -- A chest you get after the seven dwarves, not a boss: confirmed no Real.
            { "Chest of the Seven", noReal = true, aliases = { "The Seven", "Doom'rel", "Gloom'rel", "Seeth'rel",
                                                               "Vile'rel", "Dope'rel", "Anger'rel", "Hate'rel" } },
            { "Magmus" },
            { "Emperor Dagran Thaurissan", aliases = { "Princess Moira Bronzebeard" } },
            -- Level 56/55, but players report no Real from it.
            { "Warder Stilgiss & Verek", aliases = { "Warder Stilgiss", "Verek" }, optional = true, noReal = true },
            -- Comes after Warder Stilgiss; the game reports it as a boss. No Real (confirmed).
            { "The Vault", optional = true, noReal = true },
            { "Panzor the Invincible", optional = true },
            -- Not in Wowhead's journal, but the game reports them as bosses.
            -- Confirmed in game: no Real (Ribbly 53, Plugger 55).
            { "Ribbly Screwspigot", optional = true, noReal = true },
            { "Plugger Spazzring", optional = true, noReal = true },
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
            -- The guards: none is on the drop list, and all are confirmed in
            -- game to drop no Real.
            { "Guard Mol'dar", noReal = true },
            { "Stomper Kreeg", noReal = true },
            { "Guard Fengus", noReal = true },
            { "Guard Slip'kik", noReal = true },
            { "Captain Kromcrush", noReal = true },
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
            { "Hearthsinger Forresten", optional = true, noReal = true }, -- confirmed in game: no Real
            -- Summoned (blacksmithing plans); not in Wowhead's journal, but the
            -- game reports him as a boss. Confirmed in game: no Real.
            { "Crimson Hammersmith", optional = true, noReal = true },
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
        name = "The Shaper's Terrace", new = true, instanceNames = { "shaper's terrace", "the shaper's terrace" },
        bosses = {
            -- The four raptors, summoned with Power Crystals: all confirmed in
            -- game to drop no Real.
            { "Cinder", noReal = true }, { "Snowtalon", noReal = true },
            { "Bolt", noReal = true }, { "Vitrix", noReal = true },
            { "Nanaya" },
        },
    },
    {
        name = "Blackmaw Hold", new = true,
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

-- Bosses confirmed not to drop a Real (noReal) and confirmed to drop one
-- (real), by every name.
ns.NO_REAL_BOSSES, ns.REAL_BOSSES = {}, {}
for _, def in ipairs(ns.ROSTER) do
    for _, b in ipairs(def.bosses) do
        local set = (b.noReal and ns.NO_REAL_BOSSES) or (b.real and ns.REAL_BOSSES)
        if set then
            set[b[1]:lower()] = true
            for _, a in ipairs(b.aliases or {}) do set[a:lower()] = true end
        end
    end
end

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

------------------------------------------------------------------------------
-- Boss levels, from Wowhead's WoW: Forever database (wowhead.com/forever/
-- npc=...), November 2026. Bosses of level 55+ usually drop a Real, so the
-- level is the addon's first guess; what happens in game (the real/noReal
-- flags above, and what the addon learns from loot) always wins. Used when the
-- game won't tell the addon a boss's level (it often won't in dungeons); a
-- level read in game always wins. Values marked "Classic" weren't found for
-- Forever and are the Classic level (High Interrogator Gerstahn, confirmed
-- 52 in Forever, matches Classic). Bosses not listed are assumed to drop a
-- Real, so one is never missed. Wowhead has no levels yet for Shaper's
-- Terrace and Blackmaw Hold; both are max-level dungeons (55-60 and 58-60)
-- whose loot needs level 55, so their bosses count as Real bosses.
------------------------------------------------------------------------------
ns.BOSS_LEVELS = {}
local function levels(t)
    for name, level in pairs(t) do ns.BOSS_LEVELS[name:lower()] = level end
end

-- Blackrock Depths
levels({
    ["High Interrogator Gerstahn"] = 52,
    ["Lord Roccor"] = 51,            -- Classic
    ["Houndmaster Grebmar"] = 52,    -- Classic
    ["Fineous Darkvire"] = 54,       -- Classic
    ["Pyromancer Loregrain"] = 52,   -- Classic
    ["Bael'gar"] = 54,               -- Classic
    ["Lord Incendius"] = 55,
    ["General Angerforge"] = 57,
    ["Golem Lord Argelmach"] = 57,
    ["Phalanx"] = 55,
    ["Hurley Blackbreath"] = 55,
    ["Ambassador Flamelash"] = 57,
    ["Magmus"] = 57,
    ["Emperor Dagran Thaurissan"] = 59,
    ["Warder Stilgiss"] = 56,
    ["Verek"] = 55,
    ["Panzor the Invincible"] = 57,
    ["Ribbly Screwspigot"] = 53,
    ["Plugger Spazzring"] = 55,
    -- Chest of the Seven
    ["Doom'rel"] = 57, ["Gloom'rel"] = 56, ["Seeth'rel"] = 56, ["Vile'rel"] = 56, ["Dope'rel"] = 56,
    ["Anger'rel"] = 55, ["Hate'rel"] = 55,
    -- Ring of the Law challengers (one per run)
    ["Gorosh the Dervish"] = 56,
    ["Grizzle"] = 54,
    ["Eviscerator"] = 54,
    ["Anub'shiah"] = 54,
    ["Hedrum the Creeper"] = 53,
    ["Ok'thor the Breaker"] = 53,
})
-- Blackrock Spire
levels({
    ["Highlord Omokk"] = 59, ["Shadow Hunter Vosh'gajin"] = 59, ["War Master Voone"] = 59,
    ["Mother Smolderweb"] = 59, ["Urok Doomhowl"] = 60, ["Quartermaster Zigris"] = 59,
    ["Halycon"] = 59, ["Gizrul the Slavener"] = 60,
    ["Overlord Wyrmthalak"] = 60,    -- Classic
    ["Pyroguard Emberseer"] = 60,    -- Classic
    ["Warchief Rend Blackhand"] = 60, -- Classic
    ["General Drakkisath"] = 62,     -- Classic
})
-- Dire Maul
levels({
    ["Pusillin"] = 56, ["Lethtendris"] = 57, ["Hydrospawn"] = 57, ["Zevrim Thornhoof"] = 57,
    ["Alzzin the Wildshaper"] = 58,
    ["Tendris Warpwood"] = 60, ["Magister Kalendris"] = 60, ["Illyanna Ravenoak"] = 60,
    ["Immol'thar"] = 61, ["Prince Tortheldrin"] = 61,
    ["Stomper Kreeg"] = 59,
    ["Guard Mol'dar"] = 59, ["Guard Fengus"] = 59, ["Guard Slip'kik"] = 59, -- Classic
    ["Captain Kromcrush"] = 61,                                             -- Classic
    ["King Gordok"] = 62,
})
-- Scholomance
levels({
    ["Blood Steward of Kirtonos"] = 57, ["Kirtonos the Herald"] = 60, ["Jandice Barov"] = 61,
    ["Rattlegore"] = 61, ["Marduk Blackpool"] = 58, ["Vectus"] = 60, ["Ras Frostwhisper"] = 60,
    ["Instructor Malicia"] = 60, ["Doctor Theolen Krastinov"] = 60, ["Lorekeeper Polkelt"] = 60,
    ["The Ravenian"] = 60, ["Lord Alexei Barov"] = 60, ["Lady Illucia Barov"] = 60,
    ["Darkmaster Gandling"] = 61,
})
-- Stratholme
levels({
    ["Ezra Grimm"] = 61, ["The Unforgiven"] = 57, ["Postmaster Malown"] = 60, ["Timmy the Cruel"] = 58,
    ["Skul"] = 58, ["Baroness Anastari"] = 59, ["Ramstein the Gorger"] = 61, ["Baron Rivendare"] = 62,
    ["Cannon Master Willey"] = 60,
})

------------------------------------------------------------------------------
-- Drop list: every dungeon NPC recorded dropping a Tarnished Undermine Real,
-- from the "Dropped By" list on forevertwinking.com/items/tarnished-undermine-real,
-- whose item sources come from Wowhead's WoW: Forever database (via
-- Polestar), fetched November 2026. (The % is how often players saw it drop;
-- it's below 100% because each boss gives you one only once per day.) That
-- list also has raid bosses, which suggests part of it is Season of
-- Discovery data, but for the dungeons it matched every boss confirmed in
-- game. It has nothing yet for Shaper's Terrace or Blackmaw Hold.
--
-- In the five classic dungeons the addon uses it as:
--   on the list                          -> drops a Real (Bael'Gar and Lord
--                                           Incendius do although they're
--                                           near or below level 55);
--   not on it, and a rare, summoned or
--   quest boss ("optional"), or a boss
--   the boss list doesn't know           -> no Real;
--   not on it but a regular boss         -> decided by level as before (the
--                                           list may just lack reports), and
--                                           learning silences it if it
--                                           doesn't drop one.
------------------------------------------------------------------------------
ns.DROP_LIST = {}
for _, name in ipairs({
    "Malor the Zealous", -- Stratholme, level 60, 88.76%
    "Illyanna Ravenoak", -- Dire Maul, level 60, 71.7%
    "Vectus", -- Scholomance, level 60, 71.1%
    "Lethtendris", -- Dire Maul, level 57, 70.59%
    "Marduk Blackpool", -- Scholomance, level 58, 70.34%
    "Ezra Grimm", -- Stratholme, level 61, 69.81%
    "Lorekeeper Polkelt", -- Scholomance, level 60, 69.66%
    "Instructor Malicia", -- Scholomance, level 60, 68.09%
    "Prince Tortheldrin", -- Dire Maul, level 60 - 61, 67.92%
    "Pusillin", -- Dire Maul, level 57, 67.31%
    "Tendris Warpwood", -- Dire Maul, level 60, 67.06%
    "Fineous Darkvire", -- Blackrock Depths, level 54, 67.01%
    "Phalanx", -- Blackrock Depths, level 55, 66.87%
    "Hurley Blackbreath", -- Blackrock Depths, level 55, 66.84%
    "Doctor Theolen Krastinov", -- Scholomance, level 60, 66.31%
    "Kirtonos the Herald", -- Scholomance, level 60, 66.08%
    "Darkmaster Gandling", -- Scholomance, level 61, 65.71%
    "Rattlegore", -- Scholomance, level 61, 65.45%
    "Golem Lord Argelmach", -- Blackrock Depths, level 57, 64.89%
    "Lady Illucia Barov", -- Scholomance, level 60, 64.87%
    "Ambassador Flamelash", -- Blackrock Depths, level 57, 64.85%
    "Jandice Barov", -- Scholomance, level 61, 64.62%
    "Bael'Gar", -- Blackrock Depths, level 54, 64.47%
    "Emperor Dagran Thaurissan", -- Blackrock Depths, level 59, 64.43%
    "The Ravenian", -- Scholomance, level 60, 64.19%
    "General Angerforge", -- Blackrock Depths, level 57, 64.09%
    "Ras Frostwhisper", -- Scholomance, level 62, 64.04%
    "Lord Alexei Barov", -- Scholomance, level 60, 62.82%
    "Lord Incendius", -- Blackrock Depths, level 55, 61.66%
    "Magmus", -- Blackrock Depths, level 57, 59.84%
    "Mother Smolderweb", -- Blackrock Spire, level 59, 59.73%
    "Shadow Hunter Vosh'gajin", -- Blackrock Spire, level 58, 59.66%
    "Baron Rivendare", -- Stratholme, level 62, 59%
    "Baroness Anastari", -- Stratholme, level 59, 58.64%
    "Maleki the Pallid", -- Stratholme, level 61, 58.12%
    "Warchief Rend Blackhand", -- Blackrock Spire, level 62, 58%
    "Nerub'enkan", -- Stratholme, level 60, 57.74%
    "Halycon", -- Blackrock Spire, level 59, 57.71%
    "Gizrul the Slavener", -- Blackrock Spire, level 60, 57.68%
    "Pyroguard Emberseer", -- Blackrock Spire, level 60, 57.45%
    "Overlord Wyrmthalak", -- Blackrock Spire, level 60, 57.39%
    "Urok Doomhowl", -- Blackrock Spire, level 60, 57.3%
    "King Gordok", -- Dire Maul, level 61 - 62, 56.82%
    "The Beast", -- Blackrock Spire, level 62, 56.57%
    "War Master Voone", -- Blackrock Spire, level 58, 55.87%
    "Ramstein the Gorger", -- Stratholme, level 61, 54.7%
    "General Drakkisath", -- Blackrock Spire, level 62, 54.07%
    "Magister Kalendris", -- Dire Maul, level 60, 51.79%
    "Highlord Omokk", -- Blackrock Spire, level 59, 51.05%
    "Postmaster Malown", -- Stratholme, level 60, 48.57%
    "Timmy the Cruel", -- Stratholme, level 58, 47.42%
    "Cannon Master Willey", -- Stratholme, level 60, 47.2%
    "Magistrate Barthilas", -- Stratholme, level 58, 46.4%
    "Balzaphon", -- Stratholme, level 60, 46.34%
    "Archivist Galford", -- Stratholme, level 60, 43.93%
    "The Unforgiven", -- Stratholme, level 57, 41.13%
    "Hydrospawn", -- Dire Maul, level 57, 35.77%
    "Immol'thar", -- Dire Maul, level 61, 34.23%
    "Zevrim Thornhoof", -- Dire Maul, level 57, 31.94%
    "Alzzin the Wildshaper", -- Dire Maul, level 58, 31.94%
}) do ns.DROP_LIST[name:lower()] = true end
