-- Tests for learning which bosses drop no Real (their corpse had none for
-- you on a day you hadn't looted them), so below-55 bosses the list doesn't
-- flag stop reminding after the first time.
local ADDON_DIR = ADDON_DIR or "TarnishedRealReminder/"
local REAL, REAL_ID = "Tarnished Undermine Real", 213372 -- stand-in ID for the test

local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end

local ns = {}
for line in io.lines(ADDON_DIR .. "TarnishedRealReminder.toc") do
    local file = line:match("^([%w_%-%.\\/]+%.lua)%s*$")
    if file then assert(loadfile(ADDON_DIR .. file:gsub("\\", "/")))("TarnishedRealReminder", ns) end
end
T.instance = { name = "Blackrock Depths", type = "party", id = 230 }
T.fire("ADDON_LOADED", "TarnishedRealReminder")
T.fire("PLAYER_ENTERING_WORLD")
T.advance(3.5)
local DB, CDB = ns.DB, ns.CDB

local n = 0
local function kill(name, level)
    n = n + 1
    local guid = "G" .. n
    T.units.boss1 = { name = name, level = level, guid = guid }
    T.fire("ENCOUNTER_START", n, name, 1, 5)
    T.advance(1.5)
    T.fire("ENCOUNTER_END", n, name, 1, 5, 1)
    T.units.boss1 = nil
    T.advance(0.5)
    return guid
end
local function openCorpse(guid, items)
    T.loot, T.lootSource = items, guid
    T.fire("LOOT_READY")
    for _, it in ipairs(items) do
        if it.name == REAL then T.addToBags(REAL, REAL_ID, it.qty or 1); T.fire("BAG_UPDATE_DELAYED"); T.advance(0.3) end
    end
    T.loot = {}
    T.fire("LOOT_CLOSED")
    T.advance(1)
end
local function nextDay()
    T.server = T.resetAtServer + 10
    T.resetAtServer = T.resetAtServer + 86400
    ns.checkDailyReset()
end
local function row(groupName, name)
    for _, g in ipairs(ns.Roster.Build()) do
        if g.name == groupName then
            for _, r in ipairs(g.rows) do
                for _, nm in ipairs(r.names) do if nm == name then return r end end
            end
        end
    end
end

-- Ring of the Law isn't flagged below 55 in the list, and its level can't be
-- read: the first kill reminds.
local g = kill("Ring of the Law", SECRET)
check(#CDB.pending == 1, "unflagged boss with an unreadable level reminds the first time")

-- Its corpse has loot but no Real for us, on a day we hadn't looted it.
openCorpse(g, { { name = "Arena Wristguards", quality = 3 } })
check(#CDB.pending == 0, "reminder cleared")
check(DB.noRealBosses["ring of the law"] == "Ring of the Law", "learned: Ring of the Law drops no Real")
check(T.chatContains("doesn't drop one"), "the player is told what was learned")
local r = row("Blackrock Depths", "Ring of the Law")
check(r and r.status == "none", "today's checklist: nothing for you")

-- Next day: no reminder any more, and the checklist says why.
nextDay()
kill("Ring of the Law", SECRET)
check(#CDB.pending == 0, "next day: no reminder for the learned boss")
r = row("Blackrock Depths", "Ring of the Law")
check(r and r.status == "low" and ns.Roster.STATUS.low.text(r) == "no Real (learned)", "checklist: no Real (learned)")
local brdTotal
for _, gr in ipairs(ns.Roster.Build()) do if gr.name == "Blackrock Depths" then brdTotal = gr.total end end
check(brdTotal == 8, "learned boss left out of the dungeon count (" .. tostring(brdTotal) .. ")")

-- Trash loot (no GUID match) teaches nothing.
local g2 = kill("Magmus", SECRET)
openCorpse("G-trash", { { name = "Linen Cloth" } })
check(#CDB.pending == 1 and not DB.noRealBosses["magmus"], "trash corpse doesn't teach anything")
openCorpse(g2, { { name = REAL, id = REAL_ID } })
check(#CDB.pending == 0 and CDB.looted["magmus"] and not CDB.looted["magmus"].none, "Magmus looted normally")

-- A level read in game still wins over what was learned, and looting a Real
-- from the boss unlearns it.
DB.noRealBosses["general angerforge"] = "General Angerforge"
local g3 = kill("General Angerforge", 57)
check(#CDB.pending == 1, "readable level 57 reminds even if learned otherwise")
openCorpse(g3, { { name = REAL, id = REAL_ID } })
check(DB.noRealBosses["general angerforge"] == nil, "looting a Real from it unlearns it")

-- /trr relearn forgets everything learned.
check(DB.noRealBosses["ring of the law"] ~= nil, "still learned before relearn")
ns.slash("relearn")
check(next(DB.noRealBosses) == nil, "/trr relearn forgets learned bosses")
check(T.chatContains("forgotten"), "/trr relearn reports it")
nextDay()
kill("Ring of the Law", SECRET)
check(#CDB.pending == 1, "after relearn the boss reminds again")

-- Bosses flagged in the list never get a reminder, learned or not.
ns.dismissAll()
kill("High Interrogator Gerstahn", SECRET)
check(#CDB.pending == 0, "listed below-55 boss: no reminder")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
