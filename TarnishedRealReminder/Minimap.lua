-- Minimap button (hand-made, no LibDBIcon) and the Addon Compartment entry.
-- Hover: today's looted bosses. Left-click: settings. Right-click: test reminder.
local _, ns = ...

local Minimap_ = {}
ns.Minimap = Minimap_

local button
local atan2 = math.atan2 or math.atan

local GREEN, RED, GREY, WHITE = { 0.25, 1, 0.25 }, { 1, 0.35, 0.35 }, { 0.6, 0.6, 0.6 }, { 1, 1, 1 }

------------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------------

function ns.FillTooltip(tt)
    ns.checkDailyReset()
    local CDB, DB = ns.CDB, ns.DB
    local count = ns.countReals()
    ns.state.realCount = count

    tt:AddLine("Camelus' Real Reminder")
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

local function showTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    ns.FillTooltip(GameTooltip)
    GameTooltip:Show()
end

local function onClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.slash("test")
    else
        ns.Options.Toggle()
    end
end

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------

local function place()
    local a = math.rad(ns.DB.minimap.angle or 215)
    local half = (Minimap:GetWidth() or 140) / 2
    local x, y = math.cos(a) * (half + 6), math.sin(a) * (half + 6)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        x = math.max(-half, math.min(half, x * 1.42))
        y = math.max(-half, math.min(half, y * 1.42))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function build()
    button = CreateFrame("Button", "TarnishedRealReminderMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    back:SetSize(20, 20)
    back:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.DB.realIcon or ns.REAL_FALLBACK_ICON)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT")

    -- Little red dot while a Real is waiting.
    local dot = button:CreateTexture(nil, "OVERLAY", nil, 7)
    dot:SetColorTexture(1, 0.2, 0.2, 1)
    dot:SetSize(6, 6)
    dot:SetPoint("TOPRIGHT", -6, -6)
    button.dot = dot

    button:SetScript("OnClick", function(_, mouseButton) onClick(mouseButton) end)
    button:SetScript("OnEnter", function(self) showTooltip(self) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.DB.minimap.angle = math.deg(atan2(py / scale - cy, px / scale - cx))
            place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

function Minimap_.Refresh()
    if not (Minimap and ns.DB) then return end
    if ns.DB.minimap.hide then
        if button then button:Hide() end
        return
    end
    if not button then build() end
    button.icon:SetTexture(ns.DB.realIcon or ns.REAL_FALLBACK_ICON)
    button.dot:SetShown(#ns.CDB.pending > 0)
    place()
    button:Show()
end

function Minimap_.Init()
    Minimap_.Refresh()
    -- Keep the red dot in step with pending Reals.
    C_Timer.NewTicker(1, function()
        if button and button:IsShown() then button.dot:SetShown(#ns.CDB.pending > 0) end
    end)
end

------------------------------------------------------------------------------
-- Addon Compartment (the addon list under the minimap on the modern client)
------------------------------------------------------------------------------

function TarnishedRealReminder_OnCompartmentClick(_, mouseButton)
    onClick(mouseButton)
end

function TarnishedRealReminder_OnCompartmentEnter(_, menuButton)
    if menuButton then showTooltip(menuButton, "ANCHOR_LEFT") end
end

function TarnishedRealReminder_OnCompartmentLeave()
    GameTooltip:Hide()
end
