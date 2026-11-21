-- Minimal mock of the parts of the WoW: Forever client API the addon uses.
-- Not a game simulator: just enough state to drive the addon through events.
T = {
    now = 1000,             -- GetTime()
    server = 1700000000,    -- GetServerTime()
    resetIn = 6 * 3600,     -- seconds until daily reset, as of T.server at start
    resetAtServer = nil,
    timers = {},
    tickers = {},
    chat = {},
    warnings = {},
    sounds = 0,
    combat = false,
    instance = { name = "Stormwind City", type = "none", id = 0 },
    units = {},
    bags = { [0] = {} },
    currencies = {},
    loot = {},
    lootSource = nil,
    frames = {},
}
T.resetAtServer = T.server + T.resetIn

SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(v) return v == SECRET end

unpack = unpack or table.unpack
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetTime() return T.now end
function GetServerTime() return math.floor(T.server) end
C_DateAndTime = {
    GetSecondsUntilDailyReset = function()
        local s = T.resetAtServer - T.server
        while s <= 0 do T.resetAtServer = T.resetAtServer + 86400; s = T.resetAtServer - T.server end
        return s
    end,
}
function GetQuestResetTime() return C_DateAndTime.GetSecondsUntilDailyReset() end

C_Timer = {
    After = function(d, fn) table.insert(T.timers, { at = T.now + d, fn = fn }) end,
    NewTicker = function(d, fn) local t = { every = d, next = T.now + d, fn = fn }; table.insert(T.tickers, t); return t end,
}

-- Advance the clock in 0.1 s steps, firing timers and tickers as they come due.
function T.advance(sec)
    local steps = math.floor(sec * 10 + 0.5)
    for _ = 1, steps do
        T.now = T.now + 0.1
        T.server = T.server + 0.1
        local due = {}
        for i = #T.timers, 1, -1 do
            if T.timers[i].at <= T.now + 1e-9 then table.insert(due, 1, table.remove(T.timers, i)) end
        end
        table.sort(due, function(a, b) return a.at < b.at end)
        for _, t in ipairs(due) do t.fn() end
        for _, t in ipairs(T.tickers) do
            if t.next <= T.now + 1e-9 then t.next = t.next + t.every; t.fn() end
        end
        -- Like the game, run OnUpdate on every visible frame each step.
        for _, f in ipairs(T.frames) do
            local fn = f.scripts and f.scripts.OnUpdate
            if fn and T.isVisible(f) then fn(f, 0.1) end
        end
    end
end

-- Frames ---------------------------------------------------------------------
-- Unknown methods (capitalised keys) are no-ops; unknown fields stay nil.
local function newObject(otype)
    local o = { _type = otype, shown = true, scripts = {}, events = {}, text = nil,
                w = 0, h = 0, scale = 1, alpha = 1 }
    return setmetatable(o, { __index = function(self, k)
        if type(k) == "string" and k:match("^[A-Z]") then return function() end end
        return nil
    end })
end

local frameMethods = {}
function frameMethods.RegisterEvent(self, e)
    if T.unknownEvents and T.unknownEvents[e] then error("unknown event " .. e) end
    self.events[e] = true
end
function frameMethods.SetScript(self, k, fn) self.scripts[k] = fn end
function frameMethods.GetScript(self, k) return self.scripts[k] end
function frameMethods.Show(self) local was = self.shown; self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function frameMethods.Hide(self) local was = self.shown; self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function frameMethods.SetShown(self, v) if v then self:Show() else self:Hide() end end
function frameMethods.IsShown(self) return self.shown end
function frameMethods.SetText(self, t) self.text = t end
function frameMethods.GetText(self) return self.text end
function frameMethods.GetPoint() return "TOP", nil, "TOP", 0, -150 end
function frameMethods.SetSize(self, w, h) self.w, self.h = w, h end
function frameMethods.SetWidth(self, w) self.w = w end
function frameMethods.SetHeight(self, h) self.h = h end
function frameMethods.GetWidth(self) return self.w end
function frameMethods.GetHeight(self) return self.h end
function frameMethods.SetScale(self, v) self.scale = v end
function frameMethods.SetAlpha(self, v) self.alpha = v end
function frameMethods.GetCenter() return 500, 400 end
function frameMethods.GetEffectiveScale() return 1 end
function frameMethods.SetFont(self, path, size, flags) self.font = { path, size, flags }; return true end
function frameMethods.GetFont(self) if self.font then return unpack(self.font) end end
function frameMethods.SetMinMaxValues(self, a, b) self.minV, self.maxV = a, b end
function frameMethods.GetValue(self) return self.value or 0 end
function frameMethods.SetValue(self, v)
    v = math.max(self.minV or v, math.min(self.maxV or v, v))
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function frameMethods.SetTexture(self, t) self.texture = t end
function frameMethods.SetColorTexture(self, r, g, b, a) self.color = { r, g, b, a } end
function frameMethods.SetTextColor(self, r, g, b, a) self.textColor = { r, g, b, a } end
function frameMethods.SetBackdrop(self, b) self.backdrop = b end
function frameMethods.CreateFontString(self) local o = T.makeFrame("FontString"); o.parent = self; return o end
function frameMethods.CreateTexture(self) local o = T.makeFrame("Texture"); o.parent = self; return o end
function frameMethods.GetParent(self) return self.parent end
function frameMethods.CreateAnimationGroup(self)
    local g = T.makeFrame("AnimationGroup"); g.parent = self
    g.CreateAnimation = function(grp) local an = T.makeFrame("Animation"); an.parent = grp; return an end
    return g
end
function frameMethods.SetParent(self, p) self.parent = p end
function frameMethods.GetName(self) return self.name end

function T.makeFrame(otype, name)
    local o = newObject(otype)
    for k, fn in pairs(frameMethods) do o[k] = fn end
    table.insert(T.frames, o)
    if name then _G[name] = o end
    return o
end
function securecallfunction(fn, ...) return fn(...) end
function securecall(fn, ...) return fn(...) end

-- Tooltips record their lines; T.lastTooltip is the one most recently filled.
local function makeTooltip(tt)
    tt.lines = {}
    function tt:SetOwner() self.lines = {}; T.lastTooltip = self end
    function tt:ClearLines() self.lines = {} end
    function tt:AddLine(t) table.insert(self.lines, t); T.lastTooltip = self end
    function tt:AddDoubleLine(a, b) table.insert(self.lines, a .. " | " .. b); T.lastTooltip = self end
    return tt
end

function CreateFrame(otype, name, parent)
    local o = T.makeFrame(otype or "Frame", name)
    o.parent, o.name = parent, name
    if otype == "GameTooltip" then makeTooltip(o) end
    return o
end

function T.isVisible(f)
    while f do
        if f.shown == false then return false end
        f = f.parent
    end
    return true
end

function T.click(frame, button)
    assert(frame.scripts.OnClick, "frame has no OnClick")
    frame.scripts.OnClick(frame, button or "LeftButton")
end

UIParent = T.makeFrame("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(T.chat, msg) end }
RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.5, b = 0 } }
SOUNDKIT = { RAID_WARNING = 8959 }
T.blizzardWarnings = {}
function RaidNotice_AddMessage(_, text) table.insert(T.blizzardWarnings, text) end
function PlaySound() T.sounds = T.sounds + 1 end
function FlashClientIcon() end
function InCombatLockdown() return T.combat end
SlashCmdList = {}
UISpecialFrames = {}
ChatFontNormal = {}
Minimap = T.makeFrame("Frame", "Minimap")
Minimap.w = 140
function GetCursorPosition() return 600, 500 end
T.soundFiles = {}
function PlaySoundFile(f) table.insert(T.soundFiles, f) end

GameTooltip = makeTooltip(T.makeFrame("GameTooltip", "GameTooltip"))
function T.tooltipText() return table.concat((T.lastTooltip or GameTooltip).lines, "\n") end

ColorPickerFrame = T.makeFrame("Frame", "ColorPickerFrame")
function ColorPickerFrame:SetupColorPickerAndShow(info) self.info = info end
function ColorPickerFrame:GetColorRGB() return 0.1, 0.2, 0.3 end
function ColorPickerFrame:GetColorAlpha() return 0.4 end

Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) T.settingsPanel = panel; return { name = name } end,
    RegisterAddOnCategory = function(cat) T.settingsCategory = cat end,
}

-- World / units ----------------------------------------------------------------
function GetInstanceInfo()
    local i = T.instance
    return i.name, i.type, 1, "Normal", 5, 0, false, i.id
end

local function u(unit) return T.units[unit] end
function UnitExists(unit) return u(unit) ~= nil end
function UnitName(unit) return u(unit) and u(unit).name end
function UnitLevel(unit) return u(unit) and u(unit).level end
function UnitIsDead(unit) return u(unit) and u(unit).dead or false end
function UnitGUID(unit) return u(unit) and u(unit).guid end

-- Items ------------------------------------------------------------------------
C_Container = {
    GetContainerNumSlots = function(bag) return T.bags[bag] and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local it = T.bags[bag] and T.bags[bag][slot]
        if not it then return nil end
        return { hyperlink = "|cff1eff00|Hitem:" .. it.id .. "::|h[" .. it.name .. "]|h|r",
                 stackCount = it.count, itemID = it.id, iconFileID = 133789 }
    end,
}
C_Item = {
    GetItemCount = function(id)
        local n = 0
        for _, bag in pairs(T.bags) do for _, it in pairs(bag) do if it.id == id then n = n + it.count end end end
        return n
    end,
}
C_CurrencyInfo = {
    GetCurrencyListSize = function() return #T.currencies end,
    GetCurrencyListInfo = function(i) return T.currencies[i] end,
}

function T.addToBags(name, id, count)
    local bag = T.bags[0]
    for _, it in pairs(bag) do if it.id == id then it.count = it.count + count; return end end
    table.insert(bag, { name = name, id = id, count = count })
end

-- Loot -------------------------------------------------------------------------
function GetNumLootItems() return #T.loot end
function GetLootSlotInfo(slot)
    local l = T.loot[slot]
    return 133789, l.name, l.qty or 1, nil, l.quality or 2
end
function GetLootSlotLink(slot)
    local l = T.loot[slot]
    return l.id and ("|Hitem:" .. l.id .. "::|h[" .. l.name .. "]|h") or nil
end
function GetLootSourceInfo(slot) return T.lootSource end

-- Driving ----------------------------------------------------------------------
function T.fire(event, ...)
    for _, f in ipairs(T.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

function T.lastChat() return T.chat[#T.chat] or "" end
function T.chatContains(s)
    for _, m in ipairs(T.chat) do if m:find(s, 1, true) then return true end end
    return false
end
