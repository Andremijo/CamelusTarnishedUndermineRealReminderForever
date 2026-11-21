-- Tarnished Real Reminder
-- Reminds you to loot the Tarnished Undermine Real from every eligible boss,
-- once per boss per day, in WoW: Forever.
--
-- WoW: Forever runs the modern (Midnight-era) client API: the combat log is
-- closed to addons and some unit values can be "secret" in instances. So
-- kills are detected from ENCOUNTER_END / BOSS_KILL, with a fallback that
-- watches for a known boss being seen dead. Every value read from a unit is
-- checked with issecretvalue before use, and every API call that might be
-- missing or restricted is wrapped in pcall.
local ADDON, ns = ...

local DB, CDB -- account-wide and per-character saved tables
local state = {
    encounter = nil,         -- { id, name, maxLevel, guids } while a boss fight runs
    lastEncounterEnd = -100, -- GetTime() of the last ENCOUNTER_END / BOSS_KILL
    levels = {},             -- lower-cased unit name -> last level seen this session
    fallbackSeen = {},       -- lower-cased name -> GetTime() of last fallback trigger
    realCount = nil,         -- Reals carried at last recount (nil until the first count)
    loot = nil,              -- what the open loot window holds
    lastLootSources = nil,   -- GUIDs of the last loot window that held a Real
    lastNag = 0,
    wasInEligible = false,
}
ns.state = state

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function isSecret(v)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        return ok and secret
    end
    return false
end

-- A value an addon may use, or nil if it is secret.
local function plain(v)
    if v == nil or isSecret(v) then return nil end
    return v
end

local unpack = unpack or table.unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

-- pcall that returns the call's results, or nothing if it failed.
local function try(fn, ...)
    if type(fn) ~= "function" then return end
    local res = pack(pcall(fn, ...))
    if not res[1] then return end
    return unpack(res, 2, res.n)
end

local function lower(s)
    if type(s) ~= "string" then return nil end
    return s:lower()
end

local function serverNow()
    return try(GetServerTime) or time()
end

local function say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Real Reminder:|r " .. msg)
end

local function debug(msg)
    if DB and DB.debug then say("|cff999999" .. msg .. "|r") end
end

local function isRealName(name)
    name = lower(plain(name))
    return name ~= nil and name:find(ns.REAL_NAME_FRAGMENT, 1, true) ~= nil
end

local function formatDuration(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

------------------------------------------------------------------------------
-- Saved data
------------------------------------------------------------------------------

local DEFAULTS = {
    sound = true,
    raidWarning = true,
    nagSeconds = 20,     -- repeat the sound while a Real is waiting (0 = off)
    locked = true,
    fallback = true,     -- detect kills by seeing a known boss dead
    debug = false,
    point = nil,         -- banner position
    realItemID = nil,    -- learned from loot / bags
    realIcon = nil,
    learnedInstances = {},  -- lower-cased instance name or "id:<n>" -> true
    bossLevels = {},        -- lower-cased boss name -> level
    knownBosses = {},       -- instance name -> { boss name -> true }
    encounterEventsSeen = false,
}

local function applyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            if type(v) == "table" then
                t[k] = {}
                applyDefaults(t[k], v)
            else
                t[k] = v
            end
        end
    end
end

local function initDB()
    TarnishedRealReminderDB = TarnishedRealReminderDB or {}
    TarnishedRealReminderCharDB = TarnishedRealReminderCharDB or {}
    DB, CDB = TarnishedRealReminderDB, TarnishedRealReminderCharDB
    applyDefaults(DB, DEFAULTS)
    applyDefaults(CDB, {
        resetAt = nil,
        looted = {},   -- lower-cased boss name -> { name, t, n, none }
        pending = {},  -- list of { key, name, t, instance, guids }
    })
    ns.DB, ns.CDB = DB, CDB
end

------------------------------------------------------------------------------
-- Daily reset
------------------------------------------------------------------------------

local function secondsUntilDailyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local s = plain(try(C_DateAndTime.GetSecondsUntilDailyReset))
        if type(s) == "number" and s > 0 then return s end
    end
    local s = plain(try(GetQuestResetTime))
    if type(s) == "number" and s > 0 then return s end
    return nil
end

local function checkDailyReset()
    local now = serverNow()
    if CDB.resetAt and now < CDB.resetAt then return end
    if CDB.resetAt and (next(CDB.looted) or #CDB.pending > 0) then
        say("Daily reset: every boss has a fresh Real for you again.")
    end
    wipe(CDB.looted)
    wipe(CDB.pending)
    local s = secondsUntilDailyReset()
    CDB.resetAt = s and (now + s) or (now + 86400 - (now % 86400))
end
ns.checkDailyReset = checkDailyReset

------------------------------------------------------------------------------
-- Instances
------------------------------------------------------------------------------

local function currentInstance()
    local name, instanceType, _, _, _, _, _, instanceID = try(GetInstanceInfo)
    return plain(name), plain(instanceType), plain(instanceID)
end

local function isEligibleInstance()
    local name, instanceType, id = currentInstance()
    if instanceType ~= "party" and instanceType ~= "raid" then return false end
    if id and (ns.ELIGIBLE_INSTANCE_IDS[id] or DB.learnedInstances["id:" .. id]) then
        return true
    end
    local lname = lower(name)
    if lname and (ns.ELIGIBLE_INSTANCE_NAMES[lname] or DB.learnedInstances[lname]) then
        return true
    end
    return false
end
ns.isEligibleInstance = isEligibleInstance

local function learnInstance()
    local name, instanceType, id = currentInstance()
    if instanceType ~= "party" and instanceType ~= "raid" then return end
    if isEligibleInstance() then return end
    if name then DB.learnedInstances[name:lower()] = true end
    if id then DB.learnedInstances["id:" .. id] = true end
    say(string.format("Learned that |cffffffff%s|r drops Reals. Its bosses will be tracked from now on.",
        name or "this dungeon"))
end

------------------------------------------------------------------------------
-- Counting Reals (bag item, or currency if Forever made it one)
------------------------------------------------------------------------------

local function countReals()
    local total, seen = 0, false

    if DB.realItemID and C_Item and C_Item.GetItemCount then
        local c = plain(try(C_Item.GetItemCount, DB.realItemID, false))
        if type(c) == "number" then total, seen = c, true end
    end

    if not seen and C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 5 do
            local slots = plain(try(C_Container.GetContainerNumSlots, bag)) or 0
            for slot = 1, slots do
                local info = try(C_Container.GetContainerItemInfo, bag, slot)
                local link = info and plain(info.hyperlink)
                local name = link and link:match("%[(.-)%]")
                if name and isRealName(name) then
                    total = total + (plain(info.stackCount) or 1)
                    seen = true
                    local id = plain(info.itemID)
                    if id then DB.realItemID = id end
                    if plain(info.iconFileID) then DB.realIcon = info.iconFileID end
                end
            end
        end
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        local size = plain(try(C_CurrencyInfo.GetCurrencyListSize)) or 0
        for i = 1, size do
            local info = try(C_CurrencyInfo.GetCurrencyListInfo, i)
            if info and not info.isHeader and isRealName(info.name) then
                total = total + (plain(info.quantity) or 0)
                if plain(info.iconFileID) then DB.realIcon = info.iconFileID end
            end
        end
    end

    return total
end
ns.countReals = countReals

------------------------------------------------------------------------------
-- Reminder banner
------------------------------------------------------------------------------

local banner

local function pendingNames()
    local names = {}
    for _, p in ipairs(CDB.pending) do names[#names + 1] = p.name end
    return table.concat(names, ", ")
end

local function savePoint()
    local point, _, relPoint, x, y = banner:GetPoint(1)
    DB.point = { point, relPoint, x, y }
end

local function createBanner()
    if banner then return banner end
    local ok, f = pcall(CreateFrame, "Frame", "TarnishedRealReminderBanner", UIParent, "BackdropTemplate")
    if not ok then f = CreateFrame("Frame", "TarnishedRealReminderBanner", UIParent) end
    banner = f
    f:SetSize(480, 86)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    if DB.point then
        f:SetPoint(DB.point[1], UIParent, DB.point[2], DB.point[3], DB.point[4])
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(52, 52)
    f.icon:SetPoint("LEFT", 16, 0)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, -2)
    f.title:SetPoint("RIGHT", -34, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetText("Loot your " .. ns.REAL_DISPLAY_NAME .. "!")

    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.sub:SetPoint("RIGHT", -34, 0)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWordWrap(true)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 12, -4)
    f.hint:SetText("Nothing on the corpse? Close this with X.")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() ns.dismissAll() end)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not DB.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePoint() end)

    -- Pulse so it catches the eye.
    f.elapsed = 0
    f:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        local a = 0.55 + 0.45 * math.abs(math.sin(self.elapsed * 3))
        self.title:SetAlpha(a)
        self.icon:SetAlpha(a)
    end)
    f:Hide()
    return f
end

local function updateBanner()
    local f = createBanner()
    local show = #CDB.pending > 0 and (isEligibleInstance() or ns.testMode or not DB.locked)
    if #CDB.pending == 0 and not DB.locked then
        f.sub:SetText("Unlocked: drag me, then type /trr lock")
        f:Show()
        return
    end
    if not show then f:Hide(); return end
    f.icon:SetTexture(DB.realIcon or ns.REAL_FALLBACK_ICON)
    local n = #CDB.pending
    f.sub:SetText((n == 1 and "Waiting on: " or (n .. " bosses waiting: ")) .. pendingNames())
    f:Show()
end
ns.updateBanner = updateBanner

local function alert(text)
    if DB.sound then
        try(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
    if DB.raidWarning and RaidNotice_AddMessage and RaidWarningFrame then
        try(RaidNotice_AddMessage, RaidWarningFrame, text,
            (ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]) or { r = 1, g = 0.8, b = 0 })
    end
    try(FlashClientIcon)
    state.lastNag = GetTime()
end

------------------------------------------------------------------------------
-- Kills and pending Reals
------------------------------------------------------------------------------

local function levelOK(level)
    if type(level) ~= "number" or level <= 0 then return true end -- unknown or skull: assume yes
    return level >= ns.MIN_BOSS_LEVEL
end

local function bossLevel(name)
    local lname = lower(name)
    return state.levels[lname] or DB.bossLevels[lname]
end

local function findPending(key)
    for i, p in ipairs(CDB.pending) do
        if p.key == key then return i, p end
    end
end

local function rememberBoss(name)
    local instName = currentInstance()
    if not instName then return end
    DB.knownBosses[instName] = DB.knownBosses[instName] or {}
    DB.knownBosses[instName][name] = true
end

-- A boss died. Start a reminder unless it is not eligible or already looted.
local function registerKill(name, level, source, guids, force)
    if not name then return end
    checkDailyReset()
    if not force and not isEligibleInstance() then
        debug(name .. " killed outside a Real dungeon.")
        return
    end
    if not force and not levelOK(level) then
        debug(string.format("%s is level %d, below %d: no Real.", name, level, ns.MIN_BOSS_LEVEL))
        return
    end
    local key = name:lower()
    if CDB.looted[key] and not force then
        debug(name .. " already gave you its Real today.")
        return
    end
    if findPending(key) then return end
    local instName = currentInstance()
    table.insert(CDB.pending, { key = key, name = name, t = serverNow(),
                                instance = instName, guids = guids or {},
                                test = (source == "test") or nil })
    debug(string.format("Kill registered via %s: %s (level %s)", source, name, tostring(level)))
    alert("Loot the " .. ns.REAL_DISPLAY_NAME .. " from " .. name .. "!")
    updateBanner()
end
ns.registerKill = registerKill

local function resolvePending(index, how, count)
    local p = table.remove(CDB.pending, index)
    if not p then return end
    if p.test then updateBanner(); return end
    CDB.looted[p.key] ={ name = p.name, t = serverNow(), n = count, none = (how == "none") or nil }
    if how == "looted" then
        say(string.format("Got %s from |cffffffff%s|r. %d carried.",
            (count and count > 1) and (count .. " Reals") or "your Real", p.name, state.realCount or 0))
    end
    updateBanner()
end

-- Which pending boss does a set of loot-source GUIDs belong to?
local function matchPendingByGuids(sources)
    if not sources then return nil end
    for i, p in ipairs(CDB.pending) do
        for guid in pairs(p.guids or {}) do
            if sources[guid] then return i end
        end
    end
end

local function onRealsGained(delta)
    checkDailyReset()
    local idx = matchPendingByGuids(state.lastLootSources) or (#CDB.pending > 0 and 1) or nil
    if idx then
        resolvePending(idx, "looted", delta)
    else
        -- A Real we had no reminder for (kill not detected). Credit the corpse
        -- you are targeting, if any, so it is not asked for again today.
        local name = plain(try(UnitName, "target"))
        if name and plain(try(UnitIsDead, "target")) then
            CDB.looted[name:lower()] = { name = name, t = serverNow(), n = delta }
        end
        say(string.format("+%d Real%s. %d carried.", delta, delta > 1 and "s" or "", state.realCount or 0))
    end
    state.lastLootSources = nil
end

local recountQueued = false
local function recount()
    recountQueued = false
    local c = countReals()
    local before = state.realCount
    state.realCount = c
    if before and c > before then onRealsGained(c - before) end
end
ns.recount = recount

local function queueRecount(delay)
    if recountQueued then return end
    recountQueued = true
    C_Timer.After(delay or 0.3, recount)
end

function ns.dismissAll()
    for i = #CDB.pending, 1, -1 do resolvePending(i, "none") end
    ns.testMode = nil
    updateBanner()
end

------------------------------------------------------------------------------
-- Encounter tracking
------------------------------------------------------------------------------

local function readBossUnits()
    local enc = state.encounter
    if not enc then return end
    for i = 1, 5 do
        local unit = "boss" .. i
        if plain(try(UnitExists, unit)) then
            local lvl = plain(try(UnitLevel, unit))
            if type(lvl) == "number" then
                if lvl <= 0 then enc.maxLevel = -1
                elseif enc.maxLevel ~= -1 and (not enc.maxLevel or lvl > enc.maxLevel) then enc.maxLevel = lvl end
            end
            local guid = plain(try(UnitGUID, unit))
            if guid then enc.guids[guid] = true end
            local name = plain(try(UnitName, unit))
            if name and type(lvl) == "number" then
                state.levels[name:lower()] = lvl
            end
        end
    end
end

local function onEncounterStart(id, name)
    state.encounter = { id = plain(id), name = plain(name), guids = {} }
    readBossUnits()
    C_Timer.After(1, readBossUnits)
end

local function onEncounterEnd(id, name, success)
    name = plain(name)
    local enc = state.encounter
    state.encounter = nil
    state.lastEncounterEnd = GetTime()
    if plain(success) ~= 1 and plain(success) ~= true then return end
    DB.encounterEventsSeen = true
    name = name or (enc and enc.name)
    if not name then return end
    local level = (enc and enc.maxLevel) or bossLevel(name)
    if type(level) == "number" then DB.bossLevels[name:lower()] = level end
    if isEligibleInstance() then rememberBoss(name) end
    registerKill(name, level, "encounter", enc and enc.guids)
end

local function onBossKill(id, name)
    name = plain(name)
    if not name then return end
    if state.encounter then
        onEncounterEnd(id, name, 1)
    else
        state.lastEncounterEnd = GetTime()
        DB.encounterEventsSeen = true
        if isEligibleInstance() then rememberBoss(name) end
        registerKill(name, bossLevel(name), "boss kill")
    end
end

------------------------------------------------------------------------------
-- Fallback: a known boss seen dead
------------------------------------------------------------------------------

local WATCHED_UNITS = { target = true, focus = true, mouseover = true,
                        boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true }

local function checkUnit(unit)
    if not WATCHED_UNITS[unit] and not (unit and unit:find("^nameplate")) then return end
    if not plain(try(UnitExists, unit)) then return end
    local name = plain(try(UnitName, unit))
    if not name then return end
    local lname = name:lower()
    local lvl = plain(try(UnitLevel, unit))
    if type(lvl) == "number" and not plain(try(UnitIsDead, unit)) then
        state.levels[lname] = lvl
    end
    if not ns.BOSS_NAMES[lname] then return end
    if type(lvl) == "number" then DB.bossLevels[lname] = lvl end

    if not DB.fallback or state.encounter then return end
    if not plain(try(UnitIsDead, unit)) then return end
    local last = state.fallbackSeen[lname]
    if last and GetTime() - last < 15 then return end
    state.fallbackSeen[lname] = GetTime()
    local guid = plain(try(UnitGUID, unit))
    -- Give ENCOUNTER_END a moment; if it reports the kill, it wins.
    C_Timer.After(2, function()
        if GetTime() - state.lastEncounterEnd < 6 then return end
        if DB.encounterEventsSeen then
            -- This client reports boss kills itself. Only trust a dead body for
            -- bosses the encounter system has named before, so a member of a
            -- multi-boss fight (e.g. Ring of Law) is not counted twice.
            local instName = currentInstance()
            local known = instName and DB.knownBosses[instName]
            if not (known and known[name]) then return end
        end
        registerKill(name, bossLevel(name), "seen dead", guid and { [guid] = true } or nil)
    end)
end

------------------------------------------------------------------------------
-- Loot window
------------------------------------------------------------------------------

local function scanLoot()
    local info = { hasReal = false, qty = 0, sources = {} }
    local n = plain(try(GetNumLootItems)) or 0
    for slot = 1, n do
        local icon, name, quantity, currencyID = try(GetLootSlotInfo, slot)
        if isRealName(name) then
            info.hasReal = true
            info.qty = info.qty + (plain(quantity) or 1)
            if plain(icon) then DB.realIcon = icon end
            local link = plain(try(GetLootSlotLink, slot))
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then DB.realItemID = id end
        end
        if GetLootSourceInfo then
            local guid = plain(try(GetLootSourceInfo, slot))
            if guid then info.sources[guid] = true end
        end
    end
    return info
end

local function onLootOpened()
    if state.loot then return end -- LOOT_READY and LOOT_OPENED both fire
    local info = scanLoot()
    state.loot = info
    if info.hasReal then
        learnInstance()
        info.countBefore = state.realCount or countReals()
        state.lastLootSources = info.sources
        return
    end
    -- A boss corpse we were waiting on, with no Real for us: already taken today.
    local idx = matchPendingByGuids(info.sources)
    if idx then
        debug(CDB.pending[idx].name .. " had no Real for you (already looted today?).")
        resolvePending(idx, "none")
    end
end

local function onLootClosed()
    local info = state.loot
    state.loot = nil
    if not (info and info.hasReal) then return end
    C_Timer.After(0.6, function()
        recount()
        if (state.realCount or 0) <= (info.countBefore or 0) then
            say("|cffff4040You closed the loot window and left the Real on the corpse!|r")
            alert("You left the " .. ns.REAL_DISPLAY_NAME .. " on the corpse!")
        end
    end)
end

------------------------------------------------------------------------------
-- Zone changes and nagging
------------------------------------------------------------------------------

local function onZoneChanged()
    local eligible = isEligibleInstance()
    if state.wasInEligible and not eligible and #CDB.pending > 0 then
        say("|cffff4040You left with unlooted Reals:|r " .. pendingNames()
            .. ". They wait until reset; /trr clear to forget them.")
    end
    state.wasInEligible = eligible
    state.levels = {}
    updateBanner()
end

local function nagTick()
    if not CDB or #CDB.pending == 0 then return end
    if DB.nagSeconds <= 0 or not isEligibleInstance() then return end
    if InCombatLockdown() then return end
    if GetTime() - state.lastNag >= DB.nagSeconds then
        alert("Loot the " .. ns.REAL_DISPLAY_NAME .. " from " .. pendingNames() .. "!")
    end
end

------------------------------------------------------------------------------
-- Status / slash commands
------------------------------------------------------------------------------

local function printStatus()
    checkDailyReset()
    state.realCount = countReals()
    say(string.format("%d Real%s carried. Daily reset in %s.", state.realCount,
        state.realCount == 1 and "" or "s", formatDuration((CDB.resetAt or serverNow()) - serverNow())))

    local looted = {}
    for _, v in pairs(CDB.looted) do
        looted[#looted + 1] = v.none and (v.name .. " |cff999999(none)|r") or v.name
    end
    table.sort(looted)
    say("Looted today: " .. (#looted > 0 and table.concat(looted, ", ") or "none yet"))
    if #CDB.pending > 0 then say("|cffff4040Still to loot:|r " .. pendingNames()) end

    local instName = currentInstance()
    local known = instName and DB.knownBosses[instName]
    if known and isEligibleInstance() then
        local lines = {}
        for boss in pairs(known) do
            local done = CDB.looted[boss:lower()]
            lines[#lines + 1] = (done and "|cff40ff40" or "|cffff8080") .. boss .. "|r"
        end
        table.sort(lines)
        say(instName .. " bosses seen so far: " .. table.concat(lines, ", "))
    end
    if not isEligibleInstance() and select(2, currentInstance()) == "party" then
        say("This dungeon is not on the Real list. If it should be: /trr add")
    end
end

local HELP = {
    "/trr - status: Reals carried, bosses looted today, time to reset",
    "/trr test - show a test reminder",
    "/trr clear - forget the bosses still waiting to be looted",
    "/trr reset - forget everything looted today on this character",
    "/trr add - count the dungeon you are in as a Real dungeon",
    "/trr unlock | lock - move the reminder banner",
    "/trr sound | warning - toggle the sound / raid warning text",
    "/trr nag <seconds> - repeat the sound while a Real waits (0 = off)",
    "/trr debug - toggle debug messages",
}

local function slash(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" or cmd == "status" then
        printStatus()
    elseif cmd == "test" then
        ns.testMode = true
        registerKill("Test Boss", 60, "test", nil, true)
        say("Test reminder shown. Close it with X or /trr clear.")
    elseif cmd == "clear" then
        ns.dismissAll()
        say("Cleared.")
    elseif cmd == "reset" then
        wipe(CDB.looted); wipe(CDB.pending); updateBanner()
        say("Today's list wiped for this character.")
    elseif cmd == "add" then
        local name, itype, id = currentInstance()
        if itype ~= "party" and itype ~= "raid" then say("You are not in a dungeon.") return end
        if name then DB.learnedInstances[name:lower()] = true end
        if id then DB.learnedInstances["id:" .. id] = true end
        say((name or "This dungeon") .. " added.")
    elseif cmd == "unlock" then
        DB.locked = false; updateBanner(); say("Banner unlocked: drag it, then /trr lock.")
    elseif cmd == "lock" then
        DB.locked = true; updateBanner(); say("Banner locked.")
    elseif cmd == "sound" then
        DB.sound = not DB.sound; say("Sound " .. (DB.sound and "on" or "off") .. ".")
    elseif cmd == "warning" then
        DB.raidWarning = not DB.raidWarning; say("Raid warning text " .. (DB.raidWarning and "on" or "off") .. ".")
    elseif cmd == "nag" then
        local n = tonumber(arg)
        if n then DB.nagSeconds = math.max(0, math.floor(n)) end
        say("Repeat sound every " .. DB.nagSeconds .. "s (0 = off).")
    elseif cmd == "fallback" then
        DB.fallback = not DB.fallback; say("Dead-boss fallback " .. (DB.fallback and "on" or "off") .. ".")
    elseif cmd == "debug" then
        DB.debug = not DB.debug; say("Debug " .. (DB.debug and "on" or "off") .. ".")
    else
        for _, line in ipairs(HELP) do say(line) end
    end
end

SLASH_TARNISHEDREALREMINDER1 = "/trr"
SLASH_TARNISHEDREALREMINDER2 = "/reals"
SlashCmdList["TARNISHEDREALREMINDER"] = slash
ns.slash = slash

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
ns.frame = frame

local handlers = {}

handlers.ADDON_LOADED = function(name)
    if name ~= ADDON then return end
    initDB()
    checkDailyReset()
end

handlers.PLAYER_ENTERING_WORLD = function()
    if not DB then initDB() end
    checkDailyReset()
    onZoneChanged()
    C_Timer.After(3, function() state.realCount = countReals() end)
end
handlers.ZONE_CHANGED_NEW_AREA = onZoneChanged

handlers.ENCOUNTER_START = function(id, name) onEncounterStart(id, name) end
handlers.ENCOUNTER_END = function(id, name, _, _, success) onEncounterEnd(id, name, success) end
handlers.BOSS_KILL = function(id, name) onBossKill(id, name) end
handlers.INSTANCE_ENCOUNTER_ENGAGE_UNIT = readBossUnits

handlers.LOOT_READY = onLootOpened
handlers.LOOT_OPENED = onLootOpened
handlers.LOOT_CLOSED = onLootClosed

handlers.BAG_UPDATE_DELAYED = function() queueRecount(0.2) end
handlers.CURRENCY_DISPLAY_UPDATE = function() queueRecount(0.2) end
handlers.CHAT_MSG_LOOT = function() queueRecount(0.5) end
handlers.CHAT_MSG_CURRENCY = function() queueRecount(0.5) end

handlers.PLAYER_TARGET_CHANGED = function() checkUnit("target") end
handlers.UPDATE_MOUSEOVER_UNIT = function() checkUnit("mouseover") end
handlers.UNIT_FLAGS = function(unit) checkUnit(unit) end
handlers.UNIT_HEALTH = function(unit) if unit == "target" or unit == "focus" then checkUnit(unit) end end
handlers.NAME_PLATE_UNIT_ADDED = function(unit) checkUnit(unit) end

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if not fn then return end
    if event ~= "ADDON_LOADED" and not DB then return end
    local ok, err = pcall(fn, ...)
    if not ok and DB and DB.debug then say("error in " .. event .. ": " .. tostring(err)) end
end)

-- Registering an event the client does not know throws on this client, so
-- each one is registered on its own.
for event in pairs(handlers) do
    pcall(frame.RegisterEvent, frame, event)
end

C_Timer.NewTicker(2, function() pcall(nagTick) end)

ns.handlers = handlers
