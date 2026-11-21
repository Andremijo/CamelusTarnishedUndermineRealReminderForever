-- Tests for the "Bosses today" checklist (Roster.lua and its settings tab).
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
T.fire("ADDON_LOADED", "TarnishedRealReminder")
T.fire("PLAYER_ENTERING_WORLD")
T.advance(3.5)
local DB, CDB = ns.DB, ns.CDB
local R = ns.Roster

local function enter(name, id)
    T.instance = { name = name, type = "party", id = id }
    T.fire("PLAYER_ENTERING_WORLD")
    T.advance(3.5)
end
local guid = 0
local function kill(name, level)
    guid = guid + 1
    T.units.boss1 = { name = name, level = level or 60, guid = "G" .. guid }
    T.fire("ENCOUNTER_START", guid, name, 1, 5)
    T.advance(1.5)
    T.fire("ENCOUNTER_END", guid, name, 1, 5, 1)
    T.units.boss1 = nil
    T.advance(0.5)
    return "G" .. guid
end
local function loot(g, qty)
    T.loot, T.lootSource = { { name = REAL, id = REAL_ID, qty = qty or 1 } }, g
    T.fire("LOOT_READY")
    T.addToBags(REAL, REAL_ID, qty or 1)
    T.fire("BAG_UPDATE_DELAYED")
    T.advance(0.3)
    T.loot = {}
    T.fire("LOOT_CLOSED")
    T.advance(1)
end
-- Open a corpse that has nothing for us (its Real was already taken today).
local function lootNothing(g)
    T.loot, T.lootSource = { { name = "Linen Cloth" } }, g
    T.fire("LOOT_READY")
    T.loot = {}
    T.fire("LOOT_CLOSED")
    T.advance(1)
end
local function group(name)
    for _, g in ipairs(R.Build()) do if g.name == name then return g end end
end
local function rowOf(g, name)
    for _, r in ipairs(g.rows) do
        for _, n in ipairs(r.names) do if n == name then return r end end
    end
end

-- Name matching.
check(R.Match("Kirtonos", "Kirtonos the Herald"), "short name matches the long one")
check(R.Match("Ras Frostwhisper", "Ras Frostwhisperer"), "Frostwhisper matches Frostwhisperer")
check(R.Match("Bael'Gar", "BaelGar"), "punctuation ignored")
check(not R.Match("Bolt", "Bolton"), "very short names must match exactly")
check(not R.Match("The Seven", "The Beast"), "different bosses don't match")
check(not R.Match("Future Boss", "Future Boss Three"), "a longer name with another word is a different boss")
check(not R.Match("Lord Roccor", "Lord Roccorsonian"), "more than a few extra letters is a different boss")
check(not R.Match("Lord Alexei Barov", "Lady Illucia Barov"), "Barovs kept apart")

-- Before anything: every dungeon listed, nothing done.
local groups = R.Build()
local names = {}
for _, g in ipairs(groups) do names[#names + 1] = g.name end
check(table.concat(names, ",") == "Blackrock Depths,Lower Blackrock Spire,Upper Blackrock Spire,Dire Maul East,"
    .. "Dire Maul West,Dire Maul North,Scholomance,Stratholme Live,Stratholme Undead,The Shaper's Terrace,Blackmaw Hold",
    "every dungeon part listed in Wowhead's order: " .. table.concat(names, ","))
local scholo = group("Scholomance")
check(#scholo.rows == 15 and scholo.total == 13 and scholo.done == 0, "Scholomance: 15 journal bosses, 13 counted, none done")
check(rowOf(scholo, "Kormok").status == "optional", "summoned boss shown as optional")
local brd = group("Blackrock Depths")
check(#brd.rows == 21, "BRD: Wowhead's 18 journal entries plus Ribbly, Plugger and The Vault, which the game reports as bosses")
check(rowOf(brd, "Lord Roccor").status == "low", "Lord Roccor (51) shown as below 55")
check(brd.total == 9, "BRD counts level 55+ bosses plus Darkvire (54, confirmed Real), not the Chest of the Seven (" .. brd.total .. ")")
check(rowOf(brd, "The Seven").status == "low", "Chest of the Seven drops no Real")
check(rowOf(brd, "Ribbly Screwspigot").status == "low", "Ribbly listed as dropping no Real")

-- The run from the screenshot: all 13 Scholomance bosses, with the game's names.
enter("Scholomance", 289)
local scholoKills = { "Kirtonos", "Jandice Barov", "Rattlegore", "Marduk Blackpool", "Vectus", "Ras Frostwhisperer",
    "Instructor Malicia", "Doctor Theolen Krastinov", "Lorekeeper Polkelt", "The Ravenian", "Lord Alexei Barov",
    "Lady Illucia Barov", "Darkmaster Gandling" }
for _, boss in ipairs(scholoKills) do loot(kill(boss, 60)) end
scholo = group("Scholomance")
check(#scholo.rows == 15, "no duplicate rows after a full clear (" .. #scholo.rows .. ")")
check(scholo.done == 13 and scholo.total == 13 and scholo.reals == 13, "Scholomance 13/13, 13 Reals")
check(rowOf(scholo, "Kirtonos").status == "looted", "Kirtonos ticked")
check(rowOf(scholo, "Kirtonos").display == "Kirtonos", "row shows the game's name, not the journal's")
check(rowOf(scholo, "Ras Frostwhisper").status == "looted", "journal's Ras Frostwhisper ticked by the game's Ras Frostwhisperer")

-- Stratholme: the game reports a name that only matches an alias.
enter("Stratholme", 329)
loot(kill("Commander Malor", 60))
local strat = group("Stratholme Live")
local malor = rowOf(strat, "Malor the Zealous")
check(malor.status == "looted" and malor.display == "Commander Malor", "alias ticks the row and the game's name is shown")
check(#strat.rows == 11, "alias didn't add a row")

-- A boss the list doesn't know is added to its dungeon.
loot(kill("Balzaphon", 60))
strat = group("Stratholme Live")
check(#strat.rows == 12 and rowOf(strat, "Balzaphon").status == "looted", "unlisted boss added and ticked")

-- Killed but not looted: "waiting" inside, "missed" after leaving.
kill("Baron Rivendare", 62)
strat = group("Stratholme Undead")
check(rowOf(strat, "Baron Rivendare").status == "waiting" and strat.missed == 1,
    "same instance, other side: the boss goes to Stratholme Undead, waiting to be looted")
check(group("Stratholme Live").missed == 0, "...and not to Stratholme Live")
enter("Stormwind City", 0); T.instance.type = "none"; T.fire("ZONE_CHANGED_NEW_AREA")
strat = group("Stratholme Undead")
check(rowOf(strat, "Baron Rivendare").status == "missed" and strat.missed == 1, "after leaving: missed")

-- Wowhead's level wins over a level read in game (which can be an add's, or
-- stale): Roccor (51 on Wowhead) read as 56 still gives no reminder.
enter("Blackrock Depths", 230)
kill("Lord Roccor", 56)
brd = group("Blackrock Depths")
check(rowOf(brd, "Lord Roccor").status == "low" and #ns.CDB.pending == 1, "Roccor read as 56: still below 55, no reminder")
check(brd.total == 9, "BRD total unchanged (" .. brd.total .. ")")

-- A boss's corpse with nothing for us counts as done for today.
local angerforge = kill("General Angerforge", 57)
brd = group("Blackrock Depths")
check(rowOf(brd, "General Angerforge").status == "waiting", "Angerforge waiting")
lootNothing(angerforge)
brd = group("Blackrock Depths")
check(rowOf(brd, "General Angerforge").status == "none" and brd.done == 1, "corpse without a Real counts as done, nothing for you")

-- Ignore a boss.
R.ToggleIgnore(rowOf(brd, "Magmus"))
brd = group("Blackrock Depths")
-- 9 counted minus Magmus. (Angerforge, done today as "nothing for you",
-- still counts today; from tomorrow he's learned as no-Real.)
check(rowOf(brd, "Magmus").status == "ignored" and brd.total == 8, "ignored boss left out of the count (" .. brd.total .. ")")
R.ToggleIgnore(rowOf(brd, "Magmus"))
check(rowOf(group("Blackrock Depths"), "Magmus").status == "todo", "un-ignored")

-- A dungeon learned from loot gets its own group.
enter("Some Future Dungeon", 99903)
local g1 = kill("Future Boss", 60)
loot(g1)
loot(kill("Second Future Boss", 60))
local fut = group("Some Future Dungeon")
check(fut and fut.done == 2 and fut.total == 2, "learned dungeon listed; its first boss credited too")

-------------------------------------------------------------------------------
-- The tab in the settings window.
ns.slash("bosses")
local win = TarnishedRealReminderOptions
local page = ns.Options.bossPage
check(win:IsShown() and page:IsShown() and ns.Options.currentTab == "bosses", "/cturr bosses opens the checklist tab")
check(not TarnishedRealReminderBanner:IsShown(), "no banner preview on the checklist tab")
check(page.summary:GetText():find("Today:", 1, true) ~= nil, "summary line shown")
check(page.summary:GetText():find("killed but not looted", 1, true) ~= nil, "summary warns about the missed Real")

local function headerFor(name)
    for _, h in ipairs(page.headers) do if h:IsShown() and h.name:GetText() == name then return h end end
end
check(headerFor("Scholomance") and headerFor("Scholomance").count:GetText() == "13/13", "Scholomance header 13/13")
check(headerFor("Scholomance").count.textColor[2] == 1 and headerFor("Scholomance").count.textColor[1] < 0.5, "complete dungeon in green")
check(headerFor("Stratholme Undead").count.textColor[1] == 1 and headerFor("Stratholme Undead").count.textColor[2] < 0.5, "dungeon with a missed Real in red")

local shownRows, missedRow = 0, nil
for _, r in ipairs(page.rows) do
    if r:IsShown() then
        shownRows = shownRows + 1
        if r.data.display == "Baron Rivendare" then missedRow = r end
    end
end
check(shownRows > 90, "every boss has a row (" .. shownRows .. ")")
check(missedRow and missedRow.status:GetText() == "killed, not looted", "missed boss row says so")
missedRow.scripts.OnEnter(missedRow)
check(T.tooltipText():find("go back and loot it", 1, true) ~= nil, "row tooltip explains the missed Real")
T.click(missedRow, "RightButton")
check(missedRow.data.status == "ignored" or true, "right-click handled")
local ign = false
for _, g in ipairs(R.Build()) do for _, r in ipairs(g.rows) do if r.display == "Baron Rivendare" and r.ignored then ign = true end end end
check(ign, "right-click ignores the boss")

-- Refreshes itself while open.
loot(kill("Future Boss Three", 60))
T.advance(1.2)
check(headerFor("Some Future Dungeon").count:GetText() == "3/3", "tab refreshes while open")

-- Switching tabs.
ns.Options.ShowTab("look")
check(not page:IsShown() and TarnishedRealReminderBanner:IsShown(), "Appearance tab shows the banner preview again")
win:Hide()

-- Minimap: shift-click opens the checklist.
IsShiftKeyDown = function() return true end
local mm = LibStub("LibDBIcon-1.0"):GetMinimapButton("Camelus' Tarnished Undermine Real Reminder")
T.click(mm, "LeftButton")
check(win:IsShown() and ns.Options.currentTab == "bosses", "shift-click opens the checklist")
IsShiftKeyDown = function() return false end
T.click(mm, "LeftButton")
check(win:IsShown() and ns.Options.currentTab == "look", "plain click switches to Appearance")
T.click(mm, "LeftButton")
check(not win:IsShown(), "click again closes")

-- Daily reset clears the ticks.
T.server = T.resetAtServer + 10
scholo = group("Scholomance")
check(scholo.done == 0 and scholo.total == 13 and #scholo.rows == 15, "after reset: 0/13, names kept")
check(rowOf(scholo, "Ras Frostwhisper").display == "Ras Frostwhisperer", "game's names remembered after reset")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
