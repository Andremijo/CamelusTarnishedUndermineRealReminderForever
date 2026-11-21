-- Tests for deciding which bosses drop a Real when the game won't tell the
-- addon a boss's level: Wowhead's levels (ns.BOSS_LEVELS), Ring of the Law's
-- challenger, and learning from a corpse with no Real.
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
-- unitName: the name boss1 shows (nil = no boss frame at all).
local function kill(name, level, unitName)
    n = n + 1
    local guid = "G" .. n
    if unitName ~= false then
        T.units.boss1 = { name = unitName or name, level = level, guid = guid }
    end
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
local function enter(name, id)
    T.instance = { name = name, type = "party", id = id }
    T.fire("PLAYER_ENTERING_WORLD")
    T.advance(3.5)
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
local function total(groupName)
    for _, g in ipairs(ns.Roster.Build()) do if g.name == groupName then return g.total end end
end

-------------------------------------------------------------------------------
-- Wowhead's levels decide when the game hides the level.
kill("High Interrogator Gerstahn", SECRET)
check(#CDB.pending == 0, "Gerstahn (52 on Wowhead), level hidden: no reminder")
kill("Lord Incendius", nil, false)
check(#CDB.pending == 0, "Incendius (53), no boss frame at all: no reminder")
kill("Magmus", SECRET)
check(#CDB.pending == 1, "Magmus (57), level hidden: reminder")
ns.dismissAll()
local r = row("Blackrock Depths", "High Interrogator Gerstahn")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "level 52, no Real", "checklist: level 52, no Real")
r = row("Blackrock Depths", "Phalanx")
check(r.level == 55 and r.status == "todo", "Phalanx (55) counts")

-- Ring of the Law: the challenger who shows up decides.
kill("Ring of the Law", SECRET, "Grizzle")
check(#CDB.pending == 0, "Ring of the Law vs Grizzle (54): no reminder")
nextDay()
local ring = kill("Ring of the Law", SECRET, "Gorosh the Dervish")
check(#CDB.pending == 1, "Ring of the Law vs Gorosh the Dervish (56): reminder")
-- Its corpse without a Real must not teach "no Real": tomorrow may be Gorosh again.
openCorpse(ring, { { name = "Arena Wristguards", quality = 3 } })
check(#CDB.pending == 0 and DB.noRealBosses["ring of the law"] == nil, "Ring of the Law is never learned as no-Real")
nextDay()
kill("Ring of the Law", SECRET, false)
check(#CDB.pending == 1, "Ring of the Law, challenger unknown: reminder (never miss a Real)")
ns.dismissAll()
nextDay()
-- Challenger seen only as the target (no boss frame).
T.units.target = { name = "Hedrum the Creeper", level = SECRET, guid = "G-hedrum" }
T.fire("ENCOUNTER_START", 900, "Ring of the Law", 1, 5)
T.fire("PLAYER_TARGET_CHANGED")
T.advance(1.5)
T.fire("ENCOUNTER_END", 900, "Ring of the Law", 1, 5, 1)
T.units.target = nil
T.advance(0.5)
check(#CDB.pending == 0, "Ring of the Law vs Hedrum (53), seen as target: no reminder")
check(DB.bossLevels["ring of the law"] == nil, "no level stored under Ring of the Law")
r = row("Blackrock Depths", "Ring of the Law")
check(r.level == nil and r.status ~= "low", "checklist doesn't call Ring of the Law below 55")

-------------------------------------------------------------------------------
-- Learning, for bosses Wowhead has no level for (the new dungeons).
enter("Blackmaw Hold", 99902)
local g = kill("Withermaw", SECRET)
check(#CDB.pending == 1, "boss without a known level reminds the first time")
openCorpse("G-trash", { { name = "Linen Cloth" } })
check(#CDB.pending == 1 and not DB.noRealBosses["withermaw"], "trash corpse teaches nothing")
openCorpse(g, { { name = "Cloak of the Fleshborer", quality = 3 } })
check(#CDB.pending == 0, "reminder cleared by its own corpse")
check(DB.noRealBosses["withermaw"] == "Withermaw", "learned: its corpse had no Real")
check(T.chatContains("doesn't drop one"), "the player is told what was learned")
nextDay()
kill("Withermaw", SECRET)
check(#CDB.pending == 0, "next day: no reminder for the learned boss")
r = row("Blackmaw Hold", "Withermaw")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "no Real (learned)", "checklist: no Real (learned)")
check(total("Blackmaw Hold") == 6, "learned boss left out of the count (" .. tostring(total("Blackmaw Hold")) .. ")")

-- A level read in game still wins, and a Real from it unlearns it.
local g2 = kill("Withermaw", 59)
check(#CDB.pending == 1, "readable level 59 reminds despite the learning")
openCorpse(g2, { { name = REAL, id = REAL_ID } })
check(DB.noRealBosses["withermaw"] == nil, "looting a Real from it unlearns it")

-- /trr relearn.
DB.noRealBosses["varrox bleakhoof"] = "Varrox Bleakhoof"
ns.slash("relearn")
check(next(DB.noRealBosses) == nil and T.chatContains("forgotten"), "/trr relearn forgets learned bosses")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
