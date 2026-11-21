-- Tests for the minimap button, tooltip, settings window and banner styling.
local ADDON_DIR = ADDON_DIR or "TarnishedRealReminder/"
local REAL, REAL_ID = "Tarnished Undermine Real", 213372 -- stand-in ID for the test

local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end

-- Settings saved by version 1.0.0, before the look could be customised.
TarnishedRealReminderDB = { sound = false, raidWarning = true, nagSeconds = 30, locked = true,
                            point = { "TOP", "TOP", 10, -200 }, learnedInstances = {} }

local ns = {}
for line in io.lines(ADDON_DIR .. "TarnishedRealReminder.toc") do
    local file = line:match("^([%w_%-%.\\/]+%.lua)%s*$")
    if file then assert(loadfile(ADDON_DIR .. file:gsub("\\", "/")))("TarnishedRealReminder", ns) end
end
T.instance = { name = "Blackrock Depths", type = "party", id = 230 }
T.fire("ADDON_LOADED", "TarnishedRealReminder")
T.fire("PLAYER_ENTERING_WORLD")
T.advance(3.5)

-- Upgrade from 1.0.0 keeps old choices and fills in the new ones.
local DB = ns.DB
check(DB.sound == false and DB.nagSeconds == 30, "old settings kept")
check(DB.raidWarning == false, "upgrade from 1.1.x switches the doubled raid-warning text off once")
check(DB.settingsVersion == 2, "upgrade records settings version 2")
check(DB.point[3] == 10 and DB.point[4] == -200, "old banner position kept")
check(DB.display and DB.display.width == 480 and DB.display.animation == "pulse", "new look defaults added")
check(DB.minimap and DB.minimap.hide == false, "minimap defaults added")
DB.sound = true

-- Settings entry under Options > AddOns.
check(T.settingsPanel ~= nil and T.settingsCategory ~= nil, "registered in the game's Settings panel")

-- Minimap button.
local DBI = LibStub("LibDBIcon-1.0")
local LDB = LibStub("LibDataBroker-1.1")
local NAME = "Camelus' Tarnished Undermine Real Reminder"
check(LDB:GetDataObjectByName(NAME) ~= nil, "LibDataBroker launcher registered under the full name")
check(DBI:IsRegistered(NAME), "LibDBIcon button registered")
local mm = DBI:GetMinimapButton(NAME)
check(mm ~= nil and mm:IsShown(), "minimap button shown")
check(_G["LibDBIcon10_" .. NAME] == mm, "button uses LibDBIcon's standard frame name")
check(DB.minimap.minimapPos == 215, "1.1.0 button angle carried over to LibDBIcon")
T.advance(1.1)
check(mm.trrDot and not mm.trrDot:IsShown(), "no red dot with nothing pending")

-- A kill and a loot, so the tooltip has something to list.
local function kill(name, level, guid)
    T.units.boss1 = { name = name, level = level, guid = guid }
    T.fire("ENCOUNTER_START", 1, name, 1, 5)
    T.advance(1.5)
    T.fire("ENCOUNTER_END", 1, name, 1, 5, 1)
    T.units.boss1 = nil
    T.advance(0.5)
end
local function loot(guid, qty)
    T.loot, T.lootSource = { { name = REAL, id = REAL_ID, qty = qty } }, guid
    T.fire("LOOT_READY")
    T.addToBags(REAL, REAL_ID, qty)
    T.fire("BAG_UPDATE_DELAYED")
    T.advance(0.3)
    T.loot = {}
    T.fire("LOOT_CLOSED")
    T.advance(1)
end

kill("Emperor Dagran Thaurissan", 59, "G-emp")
T.advance(1.1)
check(mm.trrDot:IsShown(), "red dot while a Real waits")
mm.scripts.OnEnter(mm)
check(T.tooltipText():find("Still to loot", 1, true) ~= nil, "tooltip lists the waiting boss")
loot("G-emp", 3)
kill("Magmus", 57, "G-mag")
loot("G-mag", 1)
kill("General Angerforge", 57, "G-ang")
T.advance(1.1)

mm.scripts.OnEnter(mm)
local tip = T.tooltipText()
check((T.lastTooltip or GameTooltip).lines[1] == NAME, "tooltip headline is the full addon name")
check(tip:find("Reals carried | 4", 1, true) ~= nil, "tooltip shows Reals carried")
check(tip:find("Daily reset in", 1, true) ~= nil, "tooltip shows the reset timer")
check(tip:find("Blackrock Depths", 1, true) ~= nil, "tooltip groups by dungeon")
check(tip:find("Emperor Dagran Thaurissan | 3 Reals", 1, true) ~= nil, "tooltip lists the Emperor with 3 Reals")
check(tip:find("Magmus | 1 Real", 1, true) ~= nil, "tooltip lists Magmus")
check(tip:find("General Angerforge", 1, true) ~= nil, "tooltip lists the boss still waiting")
check(tip:find("Not looted yet in Blackrock Depths", 1, true) ~= nil, "tooltip lists known bosses not looted")
mm.scripts.OnLeave(mm)
ns.dismissAll()

-- Compartment entry points.
check(pcall(TarnishedRealReminder_OnCompartmentEnter, "TarnishedRealReminder", mm), "compartment hover works")
check(pcall(TarnishedRealReminder_OnCompartmentLeave), "compartment leave works")

-- Minimap: right-click shows a test reminder, left-click opens settings, drag moves it.
T.click(mm, "RightButton")
check(#ns.CDB.pending == 1 and ns.CDB.pending[1].name == "Test Boss", "right-click shows a test reminder")
ns.dismissAll()
T.click(mm, "LeftButton")
local win = TarnishedRealReminderOptions
check(win ~= nil and win:IsShown(), "left-click opens the settings window")
mm.scripts.OnDragStart(mm)
if mm.scripts.OnUpdate then mm.scripts.OnUpdate(mm) end
mm.scripts.OnDragStop(mm)
check(DB.minimap.minimapPos ~= 215, "dragging the minimap button saves its position")

-- With the window open and nothing pending, the banner shows as a preview.
local banner = TarnishedRealReminderBanner
check(banner:IsShown(), "banner previews while settings are open")
check(banner.body.sub:GetText():find("Preview", 1, true) ~= nil, "preview text shown")

-- Drive every control in the window.
local controls = ns.Options.controls
check(#controls >= 35, "settings window has all its controls (" .. #controls .. ")")
local okAll = true
for i, c in ipairs(controls) do
    local ok, err = pcall(function()
        if c.kind == "slider" then
            c.slider:SetValue(c.min); c.slider:SetValue(c.max)
        elseif c.kind == "selector" then
            for _ = 1, c.count + 1 do c.step(1); banner.scripts.OnUpdate(banner, 0.1) end
            c.step(-1)
        elseif c.kind == "checkbox" then
            T.click(c); T.click(c)
        elseif c.kind == "color" then
            T.click(c)
            ColorPickerFrame.info.swatchFunc()
            ColorPickerFrame.info.cancelFunc()
        elseif c.kind == "edit" then
            c.editBox:SetText("x")
            c.editBox.scripts.OnEnterPressed(c.editBox)
        end
    end)
    if not ok then okAll = false; print("control " .. i .. " (" .. tostring(c.kind) .. "): " .. tostring(err)) end
end
check(okAll, "every control works")

-- Specific settings reach the banner.
local d = DB.display
controls[1].slider:SetValue(600)
check(d.width == 600 and banner.w == 600, "width slider resizes the banner")
controls[2].slider:SetValue(120)
check(d.height == 120 and banner.h == 120, "height slider")
controls[3].slider:SetValue(1.5)
check(math.abs(d.scale - 1.5) < 1e-6 and math.abs(banner.scale - 1.5) < 1e-6, "scale slider")
controls[5].slider:SetValue(-250)
check(DB.point[3] == -250, "horizontal position slider")

d.border = "solid"; d.borderSize = 3; d.borderColor = { 1, 0, 0, 1 }
ns.Banner.Apply()
check(banner.body.strips[1]:IsShown() and banner.body.strips[1].color[1] == 1, "solid red border drawn")
d.border = "tooltip"
ns.Banner.Apply()
check(not banner.body.strips[1]:IsShown() and banner.body.edge.backdrop ~= nil
      and banner.body.edge.backdrop.edgeFile:find("Tooltip", 1, true), "tooltip border uses a backdrop")
d.border = "none"
ns.Banner.Apply()
check(banner.body.edge.backdrop == nil, "no border")

d.font = "morpheus"; d.titleSize = 30
ns.Banner.Apply()
check(banner.body.title.font[1] == "Fonts\\MORPHEUS.TTF" and banner.body.title.font[2] == 30, "font and size applied")
d.titleText = "GRAB THE COIN"
ns.Banner.Apply()
check(banner.body.title:GetText() == "GRAB THE COIN", "custom title text")
d.showIcon = false
ns.Banner.Apply()
check(not banner.body.icon:IsShown(), "icon can be hidden")

-- Every animation and entrance runs and actually moves something.
local function frames(n) for _ = 1, n do T.now = T.now + 0.05; banner.scripts.OnUpdate(banner, 0.05) end end
for _, a in ipairs(ns.ANIMATIONS) do
    d.animation = a.key
    local ok = pcall(frames, 40)
    check(ok, "animation " .. a.key .. " runs")
end
d.animation = "bounce"; frames(7)
check(banner.body.scale == 1, "bounce does not scale")
d.animation = "grow"; frames(7)
check(banner.body.scale ~= 1, "grow scales the banner")
d.animation = "flash"; local seen = {}
for _ = 1, 20 do frames(1); seen[banner.body.alpha] = true end
check(seen[1] and seen[0.25], "flash blinks")
d.animation = "none"
for _, intro in ipairs(ns.INTROS) do
    d.intro = intro.key
    ns.Banner.PlayIntro()
    frames(2)
    if intro.key == "zoom" then check(banner.body.scale > 1, "zoom entrance starts large") end
    if intro.key == "fade" then check(banner.body.alpha < 1, "fade entrance starts faded") end
    frames(20)
    check(banner.body.alpha == 1 and banner.body.scale == 1, "entrance " .. intro.key .. " settles")
end

-- Sounds.
DB.soundKey = "custom"; DB.soundCustom = "Interface\\AddOns\\MySounds\\coin.ogg"
ns.PlayAlertSound(true)
check(T.soundFiles[#T.soundFiles] == "Interface\\AddOns\\MySounds\\coin.ogg", "custom sound file plays")
DB.soundCustom = "567458"
ns.PlayAlertSound(true)
check(T.soundFiles[#T.soundFiles] == 567458, "custom FileDataID plays")
DB.soundKey = "ready_check"
local before = T.sounds
ns.PlayAlertSound(true)
check(T.sounds == before + 1, "built-in sound plays")
DB.sound = false
ns.PlayAlertSound()
check(T.sounds == before + 1, "sound off means silent")
DB.sound = true

-- Reset look to defaults (footer button, second from the left).
local resetDone = false
for _, f in ipairs(T.frames) do
    if f._type == "Button" and f.label and f.label:GetText() == "Reset look to defaults" then
        T.click(f); resetDone = true
    end
end
check(resetDone, "reset button found")
check(DB.display.width == 480 and DB.display.font == "friz" and DB.point == nil, "reset restores the default look")

-- Hiding the minimap button.
ns.slash("minimap")
check(not mm:IsShown(), "/trr minimap hides the button")
ns.slash("minimap")
check(mm:IsShown(), "/trr minimap shows it again")

-- Closing the window ends the preview.
win:Hide()
check(not banner:IsShown(), "banner hidden when settings close with nothing pending")
ns.slash("options")
check(win:IsShown(), "/trr options opens the window")
win:Hide()

-- /cturr opens the settings; with a word after it, it works like /trr.
check(SlashCmdList.CTURR ~= nil and SLASH_CTURR1 == "/cturr", "/cturr registered")
SlashCmdList.CTURR("")
check(win:IsShown(), "/cturr opens the settings")
win:Hide()
SlashCmdList.CTURR("test")
check(#ns.CDB.pending == 1, "/cturr test works like /trr test")
ns.dismissAll()

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
