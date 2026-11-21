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
    end
end

-- Frames ---------------------------------------------------------------------
local function newObject(kind)
    local o = { kind = kind, shown = (kind ~= "Frame"), scripts = {}, events = {}, text = nil }
    return setmetatable(o, { __index = function(self, k)
        return function() end -- any unknown method is a no-op
    end })
end

local frameMethods = {}
function frameMethods.RegisterEvent(self, e)
    if T.unknownEvents and T.unknownEvents[e] then error("unknown event " .. e) end
    self.events[e] = true
end
function frameMethods.SetScript(self, k, fn) self.scripts[k] = fn end
function frameMethods.Show(self) self.shown = true end
function frameMethods.Hide(self) self.shown = false end
function frameMethods.IsShown(self) return self.shown end
function frameMethods.SetText(self, t) self.text = t end
function frameMethods.GetText(self) return self.text end
function frameMethods.GetPoint() return "TOP", nil, "TOP", 0, -150 end
function frameMethods.CreateFontString(self) return T.makeFrame("FontString") end
function frameMethods.CreateTexture(self) return T.makeFrame("Texture") end

function T.makeFrame(kind, name)
    local o = newObject(kind)
    for k, fn in pairs(frameMethods) do o[k] = fn end
    if kind == "Frame" then o.shown = true end
    table.insert(T.frames, o)
    if name then _G[name] = o end
    return o
end
function CreateFrame(kind, name) local f = T.makeFrame(kind or "Frame", name); return f end

UIParent = T.makeFrame("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(T.chat, msg) end }
RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.5, b = 0 } }
SOUNDKIT = { RAID_WARNING = 8959 }
function RaidNotice_AddMessage(_, text) table.insert(T.warnings, text) end
function PlaySound() T.sounds = T.sounds + 1 end
function FlashClientIcon() end
function InCombatLockdown() return T.combat end
SlashCmdList = {}

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
