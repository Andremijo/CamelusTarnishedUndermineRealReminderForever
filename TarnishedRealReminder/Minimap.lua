-- Minimap button and Addon Compartment entry.
--
-- The button is a LibDataBroker launcher drawn by LibDBIcon, the standard
-- minimap button library, so minimap-button collectors and broker displays
-- (Titan Panel, ChocolateBar, ...) recognise it and show its proper name.
-- Hover: today's looted bosses. Left-click: settings. Shift-click: boss
-- checklist. Right-click: test reminder.
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

-- What the tooltip lists under the totals (setting: DB.tooltipShows).
ns.TOOLTIP_MODES = {
    { key = "looted",   label = "Looted bosses" },
    { key = "unlooted", label = "Bosses not looted yet" },
    { key = "both",     label = "Looted and not looted" },
}

local function statusText(r)
    local st = ns.Roster.STATUS[r.status]
    return type(st.text) == "function" and st.text(r) or st.text, st.color
end

local function countColor(g)
    if g.missed > 0 then return RED end
    if g.total > 0 and g.done >= g.total then return GREEN end
    if g.done > 0 then return { 1, 0.82, 0 } end
    return GREY
end

local function addBossLine(tt, r)
    local text, c = statusText(r)
    tt:AddDoubleLine("   " .. r.display, text, c[1], c[2], c[3], c[1], c[2], c[3])
end

local function addGroupHeader(tt, g)
    local c = countColor(g)
    tt:AddDoubleLine(g.name, g.done .. "/" .. g.total, WHITE[1], WHITE[2], WHITE[3], c[1], c[2], c[3])
end

function ns.FillTooltip(tt)
    ns.checkDailyReset()
    local CDB, DB = ns.CDB, ns.DB
    local count = ns.countReals()
    ns.state.realCount = count

    tt:AddLine(ns.DISPLAY_NAME, 1, 0.82, 0)
    tt:AddDoubleLine("Reals carried", tostring(count), 1, 0.82, 0, 1, 1, 1)
    tt:AddDoubleLine("Daily reset in", ns.formatDuration((CDB.resetAt or ns.serverNow()) - ns.serverNow()),
        1, 0.82, 0, 1, 1, 1)

    local mode = DB.tooltipShows or "looted"
    local groups = ns.Roster.Build()
    local hereGroup = ns.Roster.GroupNameFor(ns.currentInstance())
    tt:AddLine(" ")

    if mode == "looted" then
        tt:AddLine("Looted today", 1, 0.82, 0)
        local any = false
        for _, g in ipairs(groups) do
            local list = {}
            for _, r in ipairs(g.rows) do
                if r.status == "looted" or r.status == "none" then list[#list + 1] = r end
            end
            if #list > 0 then
                any = true
                addGroupHeader(tt, g)
                for _, r in ipairs(list) do addBossLine(tt, r) end
            end
        end
        if not any then tt:AddLine("No bosses looted today yet.", GREY[1], GREY[2], GREY[3]) end

        -- Killed but not looted always matters, wherever it happened.
        local missed = {}
        for _, g in ipairs(groups) do
            for _, r in ipairs(g.rows) do
                if r.status == "waiting" or r.status == "missed" then missed[#missed + 1] = { g = g, r = r } end
            end
        end
        if #missed > 0 then
            tt:AddLine(" ")
            tt:AddLine("Still to loot", RED[1], RED[2], RED[3])
            for _, m in ipairs(missed) do
                tt:AddDoubleLine("   " .. m.r.display, m.g.name, RED[1], RED[2], RED[3], RED[1], RED[2], RED[3])
            end
        end
    else
        tt:AddLine(mode == "unlooted" and "Not looted yet today" or "Today's bosses", 1, 0.82, 0)
        local folded = false
        for _, g in ipairs(groups) do
            addGroupHeader(tt, g)
            local started = g.done > 0 or g.missed > 0 or g.name == hereGroup
            local complete = g.total > 0 and g.done >= g.total
            if started and not (mode == "unlooted" and complete) then
                for _, r in ipairs(g.rows) do
                    local show
                    if mode == "unlooted" then
                        show = r.status == "todo" or r.status == "waiting" or r.status == "missed"
                    else
                        show = r.status ~= "low" and r.status ~= "ignored"
                    end
                    if show then addBossLine(tt, r) end
                end
            elseif not started then
                folded = true
            end
        end
        if folded then
            tt:AddLine("Dungeons you haven't started today show only their count.", GREY[1], GREY[2], GREY[3])
        end
    end

    tt:AddLine(" ")
    tt:AddLine("Left-click: settings   Shift-click: boss checklist", GREY[1], GREY[2], GREY[3])
    tt:AddLine("Right-click: test reminder", GREY[1], GREY[2], GREY[3])
end

local function onClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.slash("test")
    elseif IsShiftKeyDown and IsShiftKeyDown() then
        ns.Options.Toggle("bosses")
    else
        ns.Options.Toggle("look")
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
