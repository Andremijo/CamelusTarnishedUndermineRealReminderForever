-- Minimap button and Addon Compartment entry.
--
-- The button is a LibDataBroker launcher drawn by LibDBIcon, the standard
-- minimap button library, so minimap-button collectors and broker displays
-- (Titan Panel, ChocolateBar, ...) recognise it and show its proper name.
-- Hover: today's looted bosses. Left-click: settings. Right-click: test reminder.
local _, ns = ...

local Minimap_ = {}
ns.Minimap = Minimap_

-- Name shown by collectors and broker displays, and the tooltip headline.
ns.DISPLAY_NAME = "Camelus' Tarnished Undermine Real Reminder"
local LDB_NAME = ns.DISPLAY_NAME

local GREEN, RED, GREY, WHITE = { 0.25, 1, 0.25 }, { 1, 0.35, 0.35 }, { 0.6, 0.6, 0.6 }, { 1, 1, 1 }

local ldb, icon, dataObject

------------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------------

function ns.FillTooltip(tt)
    ns.checkDailyReset()
    local CDB, DB = ns.CDB, ns.DB
    local count = ns.countReals()
    ns.state.realCount = count

    tt:AddLine(ns.DISPLAY_NAME, 1, 0.82, 0)
    tt:AddDoubleLine("Reals carried", tostring(count), 1, 0.82, 0, 1, 1, 1)
    tt:AddDoubleLine("Daily reset in", ns.formatDuration((CDB.resetAt or ns.serverNow()) - ns.serverNow()),
        1, 0.82, 0, 1, 1, 1)

    -- Looted today, grouped by dungeon.
    local groups, order = {}, {}
    for _, v in pairs(CDB.looted) do
        local inst = v.instance or "Other"
        if not groups[inst] then groups[inst] = {}; order[#order + 1] = inst end
        table.insert(groups[inst], v)
    end
    table.sort(order)
    tt:AddLine(" ")
    if #order == 0 then
        tt:AddLine("No bosses looted today yet.", GREY[1], GREY[2], GREY[3])
    else
        tt:AddLine("Looted today", 1, 0.82, 0)
        for _, inst in ipairs(order) do
            tt:AddLine(inst, WHITE[1], WHITE[2], WHITE[3])
            table.sort(groups[inst], function(a, b) return a.name < b.name end)
            for _, v in ipairs(groups[inst]) do
                if v.none then
                    tt:AddDoubleLine("   " .. v.name, "nothing for you", GREY[1], GREY[2], GREY[3], GREY[1], GREY[2], GREY[3])
                else
                    tt:AddDoubleLine("   " .. v.name, (v.n and v.n > 1) and (v.n .. " Reals") or "1 Real",
                        GREEN[1], GREEN[2], GREEN[3], GREEN[1], GREEN[2], GREEN[3])
                end
            end
        end
    end

    if #CDB.pending > 0 then
        tt:AddLine(" ")
        tt:AddLine("Still to loot", RED[1], RED[2], RED[3])
        for _, p in ipairs(CDB.pending) do
            tt:AddLine("   " .. p.name .. (p.instance and ("  (" .. p.instance .. ")") or ""), RED[1], RED[2], RED[3])
        end
    end

    -- Bosses met before in this dungeon that have not given a Real today.
    local inst = ns.currentInstance()
    local known = inst and DB.knownBosses[inst]
    if known and ns.isEligibleInstance() then
        local missing = {}
        for boss in pairs(known) do
            if not CDB.looted[boss:lower()] then missing[#missing + 1] = boss end
        end
        if #missing > 0 then
            table.sort(missing)
            tt:AddLine(" ")
            tt:AddLine("Not looted yet in " .. inst, 1, 0.82, 0)
            for _, boss in ipairs(missing) do tt:AddLine("   " .. boss, WHITE[1], WHITE[2], WHITE[3]) end
        end
    end

    tt:AddLine(" ")
    tt:AddLine("Left-click: settings   Right-click: test reminder", GREY[1], GREY[2], GREY[3])
end

local function onClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.slash("test")
    else
        ns.Options.Toggle()
    end
end

------------------------------------------------------------------------------
-- LibDBIcon button
------------------------------------------------------------------------------

local function button()
    return icon and icon.GetMinimapButton and icon:GetMinimapButton(LDB_NAME) or nil
end

-- Little red dot on the button while a Real is waiting.
local function updateDot()
    local b = button()
    if not b then return end
    if not b.trrDot then
        b.trrDot = b:CreateTexture(nil, "OVERLAY", nil, 7)
        b.trrDot:SetColorTexture(1, 0.2, 0.2, 1)
        b.trrDot:SetSize(6, 6)
        b.trrDot:SetPoint("TOPRIGHT", -6, -6)
    end
    b.trrDot:SetShown(ns.CDB ~= nil and #ns.CDB.pending > 0)
end

function Minimap_.Refresh()
    if not (ns.DB and icon and dataObject) then return end
    dataObject.icon = ns.DB.realIcon or ns.REAL_FALLBACK_ICON
    if ns.DB.minimap.hide then
        icon:Hide(LDB_NAME)
    else
        icon:Show(LDB_NAME)
    end
    updateDot()
end

function Minimap_.Init()
    if not LibStub then return end
    ldb = LibStub("LibDataBroker-1.1", true)
    icon = LibStub("LibDBIcon-1.0", true)
    if not (ldb and icon) then return end

    -- Version 1.1.0 stored the angle as "angle"; LibDBIcon calls it minimapPos.
    local mm = ns.DB.minimap
    if mm.minimapPos == nil and mm.angle then mm.minimapPos = mm.angle end

    dataObject = ldb:GetDataObjectByName(LDB_NAME) or ldb:NewDataObject(LDB_NAME, {
        type = "launcher",
        label = ns.DISPLAY_NAME,
        text = ns.DISPLAY_NAME,
        icon = ns.DB.realIcon or ns.REAL_FALLBACK_ICON,
        OnClick = function(_, mouseButton) onClick(mouseButton) end,
        OnTooltipShow = function(tt) ns.FillTooltip(tt) end,
    })
    if not icon:IsRegistered(LDB_NAME) then
        icon:Register(LDB_NAME, dataObject, mm)
    end
    Minimap_.Refresh()

    C_Timer.NewTicker(1, updateDot)
end

function Minimap_.Button() return button() end

------------------------------------------------------------------------------
-- Addon Compartment (the addon list under the minimap on the modern client)
------------------------------------------------------------------------------

function TarnishedRealReminder_OnCompartmentClick(_, mouseButton)
    onClick(mouseButton)
end

function TarnishedRealReminder_OnCompartmentEnter(_, menuButton)
    if not menuButton then return end
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    ns.FillTooltip(GameTooltip)
    GameTooltip:Show()
end

function TarnishedRealReminder_OnCompartmentLeave()
    GameTooltip:Hide()
end
