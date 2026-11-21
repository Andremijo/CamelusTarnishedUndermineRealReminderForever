-- Scenario tests for Tarnished Real Reminder, run against tests/wow_mock.lua.
-- Run with:  python3 tests/run_tests.py
local ADDON_DIR = ADDON_DIR or "TarnishedRealReminder/"
local REAL, REAL_ID = "Tarnished Undermine Real", 213372 -- the ID is a stand-in for the test

local ns
local function load()
    -- Fresh client: wipe mock state that persists between "sessions".
    ns = {}
    -- Load the files in the order the .toc lists them.
    for line in io.lines(ADDON_DIR .. "TarnishedRealReminder.toc") do
        local file = line:match("^([%w_%-%.\\/]+%.lua)%s*$")
        if file then
            local chunk = assert(loadfile(ADDON_DIR .. file:gsub("\\", "/")))
            chunk("TarnishedRealReminder", ns)
        end
    end
    T.fire("ADDON_LOADED", "TarnishedRealReminder")
    T.fire("PLAYER_ENTERING_WORLD")
    T.advance(3.5)
end

local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end

local function enter(name, id)
    T.instance = { name = name, type = "party", id = id }
    T.fire("PLAYER_ENTERING_WORLD")
    T.advance(3.5)
end

local function killBoss(name, level, guid, opts)
    opts = opts or {}
    T.units.boss1 = { name = opts.secretName and SECRET or name, level = level, guid = guid }
    T.fire("ENCOUNTER_START", opts.id or 1, name, 1, 5)
    T.fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    T.advance(1.5)
    T.units.boss1.dead = true
    T.fire("ENCOUNTER_END", opts.id or 1, name, 1, 5, 1)
    T.units.boss1 = nil
    T.advance(0.5)
end

local function lootCorpse(guid, items, take)
    T.loot, T.lootSource = items, guid
    T.fire("LOOT_READY", false)
    T.fire("LOOT_OPENED", false)
    if take then
        for _, it in ipairs(items) do
            if it.name == REAL then T.addToBags(REAL, REAL_ID, it.qty or 1) end
        end
        T.fire("CHAT_MSG_LOOT", "You receive loot")
        T.fire("BAG_UPDATE_DELAYED")
        T.advance(0.3)
    end
    T.loot = {}
    T.fire("LOOT_CLOSED")
    T.advance(1)
end

local function pending() return #ns.CDB.pending end
local function banner() return TarnishedRealReminderBanner end

-------------------------------------------------------------------------------
load()
check(ns.DB ~= nil and ns.CDB ~= nil, "saved tables created")
check(SlashCmdList.TARNISHEDREALREMINDER ~= nil, "slash command registered")
check(ns.DB.raidWarning == false, "raid-warning text is off by default (it would double the banner text)")
check(ns.DB.settingsVersion == 2, "settings version recorded")

-- 1. Outside a dungeon nothing happens.
killBoss("Hogger", 11, "G-hogger")
check(pending() == 0, "no reminder outside a Real dungeon")

-- 2. BRD boss below 55: no reminder.
enter("Blackrock Depths", 230)
killBoss("Lord Roccor", 51, "G-roccor")
check(pending() == 0, "level 51 boss gives no reminder")

-- 3a. With the defaults, a kill shows the banner and plays a sound, but adds
--     no raid-warning text on top of the banner.
enter("Blackrock Depths", 230)
local sounds0, warnings0 = T.sounds, #T.warnings
killBoss("Golem Lord Argelmach", 58, "G-golem0")
check(banner() and banner():IsShown(), "banner shown by default")
check(T.sounds > sounds0, "sound by default")
check(#T.warnings == warnings0, "no raid-warning text by default")
T.advance(25)
check(#T.warnings == warnings0, "nag repeats without raid-warning text by default")
ns.dismissAll()
ns.CDB.looted["golem lord argelmach"] = nil

-- The rest of this file checks the raid-warning output too, so switch it on.
ns.DB.raidWarning = true

-- 3. BRD boss 59: reminder, sound, banner.
local sounds = T.sounds
killBoss("Emperor Dagran Thaurissan", 59, "G-emp")
check(pending() == 1, "level 59 boss creates a reminder")
check(T.sounds > sounds, "reminder plays a sound")
check(#T.warnings > 0 and T.warnings[#T.warnings]:find("Emperor", 1, true), "raid warning names the boss")
check(banner() and banner():IsShown(), "banner shown")

-- 4. Nag repeats while waiting, but not in combat.
local w = #T.warnings
T.combat = true
T.advance(25)
check(#T.warnings == w, "no nag in combat")
T.combat = false
T.advance(25)
check(#T.warnings > w, "nags out of combat")

-- 5. Looting the Real clears the reminder and records the boss.
lootCorpse("G-emp", { { name = REAL, id = REAL_ID, qty = 3 }, { name = "Ironfoe", quality = 4 } }, true)
check(pending() == 0, "looting clears the reminder")
check(ns.CDB.looted["emperor dagran thaurissan"] ~= nil, "boss recorded as looted")
check(ns.CDB.looted["emperor dagran thaurissan"].n == 3, "3 Reals counted from a final boss")
check(not banner():IsShown(), "banner hidden after looting")
check(ns.DB.realItemID == REAL_ID, "item ID learned from loot")

-- 6. Same boss again the same day: nothing.
killBoss("Emperor Dagran Thaurissan", 59, "G-emp2")
check(pending() == 0, "no second reminder the same day")

-- 7. Leaving the Real on the corpse warns.
killBoss("Magmus", 57, "G-magmus")
check(pending() == 1, "Magmus reminder")
local chatBefore = #T.chat
lootCorpse("G-magmus", { { name = REAL, id = REAL_ID } }, false)
check(T.chatContains("left the Real on the corpse"), "warns when the loot window closes with the Real still there")
check(pending() == 1, "reminder stays until the Real is taken")
lootCorpse("G-magmus", { { name = REAL, id = REAL_ID } }, true)
check(pending() == 0, "taken on second try")

-- 8. Boss corpse with no Real for you (already taken today) clears its reminder.
killBoss("General Angerforge", 57, "G-anger")
check(pending() == 1, "Angerforge reminder")
lootCorpse("G-anger", { { name = "Some Blue", quality = 3 } }, false)
check(pending() == 0, "corpse without a Real resolves the reminder")
check(ns.CDB.looted["general angerforge"].none, "recorded as none")

-- 9. Trash loot without a Real does not clear a reminder.
killBoss("Golem Lord Argelmach", 58, "G-golem")
lootCorpse("G-trash", { { name = "Linen Cloth" } }, false)
check(pending() == 1, "trash loot leaves the reminder alone")
-- Dismiss with the close button path.
ns.dismissAll()
check(pending() == 0, "dismiss clears")

-- 10. Leaving the dungeon with an unlooted Real warns and hides the banner.
killBoss("Ambassador Flamelash", 57, "G-flame")
enter("Searing Gorge", 0)
T.instance.type = "none"
T.fire("ZONE_CHANGED_NEW_AREA")
check(T.chatContains("You left with unlooted Reals"), "warns when leaving with a pending Real")
check(not banner():IsShown(), "banner hidden outside the dungeon")
enter("Blackrock Depths", 230)
check(banner():IsShown(), "banner back on re-entry")
ns.dismissAll()

-- 11. Daily reset brings bosses back.
T.server = T.resetAtServer + 10
killBoss("Emperor Dagran Thaurissan", 59, "G-emp3")
check(pending() == 1, "reminder again after the daily reset")
check(ns.CDB.looted["emperor dagran thaurissan"] == nil, "looted list wiped at reset")
ns.dismissAll()

-- 12. New Forever dungeons by name (unknown instance IDs), skull-level boss.
enter("Shaper's Terrace", 99901)
killBoss("Nanaya", -1, "G-nanaya")
check(pending() == 1, "Shaper's Terrace boss gives a reminder")
ns.dismissAll()
enter("Blackmaw Hold", 99902)
killBoss("Varrox Bleakhoof", 61, "G-varrox")
check(pending() == 1, "Blackmaw Hold boss gives a reminder")
ns.dismissAll()

-- 13. Unknown dungeon is learned from a Real in a loot window.
enter("Some Future Dungeon", 99903)
killBoss("Future Boss", 60, "G-fb1")
check(pending() == 0, "unknown dungeon not tracked at first")
lootCorpse("G-fb1", { { name = REAL, id = REAL_ID } }, true)
check(ns.DB.learnedInstances["some future dungeon"], "dungeon learned from loot")
killBoss("Future Boss Two", 60, "G-fb2")
check(pending() == 1, "learned dungeon now tracked")
ns.dismissAll()

-- 14. Secret unit names in the encounter do not break anything.
enter("Scholomance", 289)
killBoss("Darkmaster Gandling", 61, "G-gand", { secretName = true })
check(pending() == 1, "kill registered with secret boss unit name")
ns.dismissAll()

-- 15. /trr commands run.
for _, cmd in ipairs({ "", "help", "test", "clear", "unlock", "lock", "sound", "sound", "nag 10", "add", "debug", "debug" }) do
    local ok, err = pcall(SlashCmdList.TARNISHEDREALREMINDER, cmd)
    check(ok, "/trr " .. cmd .. " runs: " .. tostring(err))
end
SlashCmdList.TARNISHEDREALREMINDER("test")
check(pending() == 1, "/trr test shows a reminder")
SlashCmdList.TARNISHEDREALREMINDER("clear")
check(pending() == 0 and ns.CDB.looted["test boss"] == nil, "test reminder leaves no record")

-------------------------------------------------------------------------------
-- 16. Client without encounter events: fallback from a boss seen dead.
T.unknownEvents = { ENCOUNTER_START = true, ENCOUNTER_END = true, BOSS_KILL = true }
T.frames = { UIParent }
T.timers, T.tickers = {}, {}
TarnishedRealReminderDB, TarnishedRealReminderCharDB = nil, nil
T.instance = { name = "Stratholme", type = "party", id = 329 }
local okLoad, errLoad = pcall(load)
check(okLoad, "loads when encounter events are unknown: " .. tostring(errLoad))
T.units.target = { name = "Baron Rivendare", level = 62, guid = "G-baron" }
T.fire("PLAYER_TARGET_CHANGED")
T.units.target.dead = true
T.fire("UNIT_HEALTH", "target")
T.advance(2.5)
check(pending() == 1, "fallback: boss seen dead creates a reminder")
lootCorpse("G-baron", { { name = REAL, id = REAL_ID, qty = 3 } }, true)
check(pending() == 0, "fallback reminder cleared by looting")

T.units.target = { name = "Timmy the Cruel", level = 58, guid = "G-timmy", dead = true }
T.fire("PLAYER_TARGET_CHANGED")
T.advance(2.5)
check(pending() == 1, "fallback works for a second boss")

-- 17. Real stored as a currency instead of an item.
T.unknownEvents = nil
T.frames = { UIParent }
T.timers, T.tickers = {}, {}
T.bags = { [0] = {} }
TarnishedRealReminderDB, TarnishedRealReminderCharDB = nil, nil
T.currencies = { { name = REAL, quantity = 5, isHeader = false } }
T.instance = { name = "Dire Maul", type = "party", id = 429 }
load()
check(ns.state.realCount == 5, "counts Reals in the currency tab")
killBoss("King Gordok", 60, "G-gordok")
check(pending() == 1, "Dire Maul reminder")
T.currencies[1].quantity = 8
T.fire("CURRENCY_DISPLAY_UPDATE")
T.advance(0.5)
check(pending() == 0, "currency gain clears the reminder")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
