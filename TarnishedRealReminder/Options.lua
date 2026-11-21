-- Settings window: /trr options, or left-click the minimap button.
--
-- Every widget is drawn from plain frames and colour textures, with no
-- Blizzard templates, so nothing depends on a template a Forever build might
-- not ship. Changes apply to the banner immediately; while the window is open
-- the banner stays up as a preview.
local _, ns = ...

local Options = {}
ns.Options = Options

local win
local controls = {}
Options.controls = controls

local BG     = { 0.055, 0.055, 0.065 }
local CARD   = { 0.090, 0.090, 0.105 }
local LINE   = { 0.220, 0.220, 0.250 }
local BTN    = { 0.150, 0.150, 0.175 }
local BTN_HI = { 0.230, 0.230, 0.265 }
local ACCENT = { 1.000, 0.820, 0.000 }
local DIM    = { 0.620, 0.620, 0.660 }

local COL_W, ROW_GAP = 280, 8

local function D() return ns.DB.display end
local function apply() if ns.Banner then ns.Banner.Apply() end end

------------------------------------------------------------------------------
-- Widget kit
------------------------------------------------------------------------------

local function fill(frame, layer, c, a)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    return t
end

local function outline(frame, c)
    local function strip(p1, p2, horizontal)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c[1], c[2], c[3], 1)
        t:SetPoint(p1); t:SetPoint(p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    end
    strip("TOPLEFT", "TOPRIGHT", true)
    strip("BOTTOMLEFT", "BOTTOMRIGHT", true)
    strip("TOPLEFT", "BOTTOMLEFT", false)
    strip("TOPRIGHT", "BOTTOMRIGHT", false)
end

local function label(parent, str, font, c)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetText(str or "")
    if c then fs:SetTextColor(c[1], c[2], c[3]) end
    return fs
end

local function flatButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h or 22)
    b.bg = fill(b, "BACKGROUND", BTN)
    outline(b, LINE)
    b.label = label(b, text)
    b.label:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(BTN_HI[1], BTN_HI[2], BTN_HI[3], 1) end)
    b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(BTN[1], BTN[2], BTN[3], 1) end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A column lays controls out top to bottom.
local function column(parent, title, x)
    local c = CreateFrame("Frame", nil, parent)
    c:SetPoint("TOPLEFT", x, -52)
    c:SetPoint("BOTTOMLEFT", x, 48)
    c:SetWidth(COL_W)
    fill(c, "BACKGROUND", CARD)
    outline(c, LINE)
    local t = label(c, title, "GameFontNormal", ACCENT)
    t:SetPoint("TOPLEFT", 12, -10)
    c.y = -34
    function c:place(frame, h)
        frame:SetPoint("TOPLEFT", self, "TOPLEFT", 12, self.y)
        frame:SetWidth(COL_W - 24)
        frame:SetHeight(h)
        self.y = self.y - h - ROW_GAP
    end
    return c
end

local function register(ctrl)
    controls[#controls + 1] = ctrl
    return ctrl
end

local function checkbox(col, text, get, set)
    local row = CreateFrame("Button", nil, col)
    col:place(row, 18)
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    fill(box, "BACKGROUND", BG)
    outline(box, LINE)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    local fs = label(row, text)
    fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
    row:SetScript("OnClick", function()
        set(not get())
        mark:SetShown(get() and true or false)
        apply()
    end)
    row.Refresh = function() mark:SetShown(get() and true or false) end
    row.kind = "checkbox"
    return register(row)
end

local function slider(col, text, minV, maxV, step, get, set, fmt)
    local row = CreateFrame("Frame", nil, col)
    col:place(row, 34)
    local fs = label(row, text)
    fs:SetPoint("TOPLEFT")
    local val = label(row, "", "GameFontHighlightSmall", ACCENT)
    val:SetPoint("TOPRIGHT")

    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT", 0, 2)
    s:SetPoint("BOTTOMRIGHT", 0, 2)
    s:SetHeight(14)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(BG[1], BG[2], BG[3], 1)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    thumb:SetSize(8, 14)
    s:SetThumbTexture(thumb)

    local function show(v)
        val:SetText(fmt and fmt(v) or tostring(v))
    end
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        v = math.floor(v / step + 0.5) * step
        set(v); show(v); apply()
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.max(minV, math.min(maxV, self:GetValue() + delta * step)))
    end)
    row.Refresh = function()
        updating = true
        local v = get()
        s:SetValue(v); show(v)
        updating = false
    end
    row.slider, row.kind, row.min, row.max, row.labelText = s, "slider", minV, maxV, text
    return register(row)
end

-- "< value >" picker over a list of { key, label } entries (or plain strings).
local function selector(col, text, list, get, set)
    local row = CreateFrame("Frame", nil, col)
    col:place(row, 38)
    local fs = label(row, text)
    fs:SetPoint("TOPLEFT")
    local function keyOf(i) local e = list[i]; return type(e) == "table" and e.key or e end
    local function labelOf(i) local e = list[i]; return type(e) == "table" and e.label or e end
    local function index()
        for i = 1, #list do if keyOf(i) == get() then return i end end
        return 1
    end
    local box = CreateFrame("Frame", nil, row)
    box:SetPoint("BOTTOMLEFT"); box:SetPoint("BOTTOMRIGHT"); box:SetHeight(20)
    fill(box, "BACKGROUND", BG)
    outline(box, LINE)
    local value = label(box, "")
    value:SetPoint("CENTER")
    local function step(delta)
        local i = (index() - 1 + delta) % #list + 1
        set(keyOf(i)); value:SetText(labelOf(i)); apply()
    end
    local prev = flatButton(box, "<", 20, 20, function() step(-1) end)
    prev:SetPoint("LEFT")
    local nxt = flatButton(box, ">", 20, 20, function() step(1) end)
    nxt:SetPoint("RIGHT")
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function(_, button) step(button == "RightButton" and -1 or 1) end)
    row.Refresh = function() value:SetText(labelOf(index())) end
    row.kind, row.step, row.count = "selector", step, #list
    return register(row)
end

local PRESET_COLORS = {
    { 1, 0.82, 0, 1 }, { 1, 1, 1, 1 }, { 1, 0.25, 0.25, 1 }, { 0.25, 1, 0.25, 1 },
    { 0.3, 0.6, 1, 1 }, { 0.8, 0.4, 1, 1 }, { 0, 0, 0, 0.75 }, { 0, 0, 0, 1 },
}

local function openColorPicker(c, hasAlpha, onChange)
    local old = { c[1], c[2], c[3], c[4] }
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        local function read()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            c[1], c[2], c[3] = r, g, b
            if hasAlpha and ColorPickerFrame.GetColorAlpha then c[4] = ColorPickerFrame:GetColorAlpha() end
            onChange()
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c[1], g = c[2], b = c[3], opacity = c[4] or 1, hasOpacity = hasAlpha,
            swatchFunc = read, opacityFunc = read,
            cancelFunc = function() c[1], c[2], c[3], c[4] = old[1], old[2], old[3], old[4]; onChange() end,
        })
        return
    end
    -- No colour picker on this client: step through presets.
    local nextIndex = 1
    for i, p in ipairs(PRESET_COLORS) do
        if math.abs(p[1] - c[1]) < 0.01 and math.abs(p[2] - c[2]) < 0.01 and math.abs(p[3] - c[3]) < 0.01 then
            nextIndex = i % #PRESET_COLORS + 1
        end
    end
    local p = PRESET_COLORS[nextIndex]
    c[1], c[2], c[3] = p[1], p[2], p[3]
    if hasAlpha then c[4] = p[4] end
    onChange()
end

local function colorSwatch(col, text, getTable, hasAlpha)
    local row = CreateFrame("Button", nil, col)
    col:place(row, 18)
    local sw = CreateFrame("Frame", nil, row)
    sw:SetSize(30, 16)
    sw:SetPoint("LEFT")
    outline(sw, LINE)
    local swatch = sw:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1); swatch:SetPoint("BOTTOMRIGHT", -1, 1)
    local fs = label(row, text)
    fs:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    local function paint()
        local c = getTable()
        swatch:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    row:SetScript("OnClick", function()
        openColorPicker(getTable(), hasAlpha, function() paint(); apply() end)
    end)
    row.Refresh = paint
    row.kind = "color"
    return register(row)
end

local function editBox(col, text, get, set)
    local row = CreateFrame("Frame", nil, col)
    col:place(row, 38)
    local fs = label(row, text)
    fs:SetPoint("TOPLEFT")
    local eb = CreateFrame("EditBox", nil, row)
    eb:SetPoint("BOTTOMLEFT"); eb:SetPoint("BOTTOMRIGHT"); eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetMaxLetters(200)
    fill(eb, "BACKGROUND", BG)
    outline(eb, LINE)
    local function commit(self) set(self:GetText() or ""); apply() end
    eb:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(get() or ""); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", commit)
    row.Refresh = function() eb:SetText(get() or "") end
    row.editBox, row.kind = eb, "edit"
    return register(row)
end

local function buttonRow(col, text, onClick)
    local b = flatButton(col, text, COL_W - 24, 22, onClick)
    col:place(b, 22)
    return b
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------

local DEFAULT_POINT = { "TOP", "TOP", 0, -150 }

-- Reading the position never creates one; only moving the slider does.
local function point()
    return ns.DB.point or DEFAULT_POINT
end
local function setOffset(i, v)
    if not ns.DB.point then
        ns.DB.point = { DEFAULT_POINT[1], DEFAULT_POINT[2], DEFAULT_POINT[3], DEFAULT_POINT[4] }
    end
    ns.DB.point[i] = v
end

local function pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function px(v) return string.format("%d", v) end
local function times(v) return string.format("%.1fx", v) end

------------------------------------------------------------------------------
-- "Bosses today" tab: every Real boss by dungeon, with today's status.
------------------------------------------------------------------------------

local GROUP_COLS, ROW_H = 4, 16

local function buildBossPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    page.summary = label(page, "", "GameFontHighlight")
    page.summary:SetPoint("TOPLEFT", 14, -58)
    page.legend = label(page, "Hover over a boss for details. Right-click a boss to ignore it, if it doesn't exist "
        .. "in this version of the game or never drops a Real. Optional bosses (rares, summoned and quest bosses) only "
        .. "count once they give you a Real.", "GameFontDisableSmall")
    page.legend:SetPoint("TOPLEFT", page.summary, "BOTTOMLEFT", 0, -4)

    local sf = CreateFrame("ScrollFrame", nil, page)
    sf:SetPoint("TOPLEFT", 12, -94)
    sf:SetPoint("BOTTOMRIGHT", -12, 48)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(GROUP_COLS * COL_W + (GROUP_COLS - 1) * 12, 10)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local v = (self:GetVerticalScroll() or 0) - delta * 48
        self:SetVerticalScroll(math.max(0, math.min(range, v)))
    end)
    page.headers, page.rows = {}, {}

    local function header(i)
        local h = page.headers[i]
        if not h then
            h = CreateFrame("Frame", nil, content)
            fill(h, "BACKGROUND", CARD)
            outline(h, LINE)
            h.name = label(h, "", "GameFontNormal", ACCENT)
            h.name:SetPoint("LEFT", 8, 0)
            h.count = label(h, "", "GameFontHighlight")
            h.count:SetPoint("RIGHT", -8, 0)
            page.headers[i] = h
        end
        return h
    end

    local function showRowTooltip(r)
        local d = r.data
        if not d then return end
        local st = ns.Roster.STATUS[d.status]
        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.display, 1, 0.82, 0)
        local text = type(st.text) == "function" and st.text(d) or st.text
        GameTooltip:AddLine(text, st.color[1], st.color[2], st.color[3])
        if type(d.level) == "number" then
            GameTooltip:AddLine("Level " .. (d.level > 0 and d.level or "??"), 1, 1, 1)
        end
        if #d.names > 1 then
            local others = {}
            for _, n in ipairs(d.names) do if n ~= d.display then others[#others + 1] = n end end
            GameTooltip:AddLine("Also called: " .. table.concat(others, ", "), 0.7, 0.7, 0.7, true)
        end
        if not d.seen then
            GameTooltip:AddLine("Not killed with the addon yet. The name comes from guides; the game's own name "
                .. "replaces it after the first kill.", 0.7, 0.7, 0.7, true)
        end
        if d.status == "missed" then
            GameTooltip:AddLine("You killed it today but its Real wasn't looted. If the corpse is still there, "
                .. "go back and loot it.", 1, 0.35, 0.35, true)
        end
        GameTooltip:AddLine(d.ignored and "Right-click: stop ignoring" or "Right-click: ignore this boss", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end

    local function row(i)
        local r = page.rows[i]
        if not r then
            r = CreateFrame("Button", nil, content)
            r:RegisterForClicks("RightButtonUp")
            r.name = label(r, "")
            r.name:SetPoint("LEFT", 12, 0)
            r.status = label(r, "")
            r.status:SetPoint("RIGHT", -8, 0)
            local hl = r:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.07)
            r:SetScript("OnClick", function(self, button)
                if button == "RightButton" and self.data then
                    ns.Roster.ToggleIgnore(self.data)
                    page.Refresh()
                    showRowTooltip(self)
                end
            end)
            r:SetScript("OnEnter", showRowTooltip)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            page.rows[i] = r
        end
        return r
    end

    function page.Refresh()
        local groups = ns.Roster.Build()
        page.groups = groups

        local total, done, reals, missed = 0, 0, 0, 0
        for _, g in ipairs(groups) do
            total, done, reals, missed = total + g.total, done + g.done, reals + g.reals, missed + g.missed
        end
        local reset = ns.formatDuration((ns.CDB.resetAt or ns.serverNow()) - ns.serverNow())
        local text = string.format("Today: %d Real%s from %d of %d bosses.   Daily reset in %s.",
            reals, reals == 1 and "" or "s", done, total, reset)
        if missed > 0 then
            text = text .. string.format("   |cffff5959%d killed but not looted!|r", missed)
        end
        page.summary:SetText(text)

        for _, h in ipairs(page.headers) do h:Hide() end
        for _, r in ipairs(page.rows) do r:Hide(); r.data = nil end

        local colY = {}
        for c = 1, GROUP_COLS do colY[c] = 0 end
        local n = 0
        for gi, g in ipairs(groups) do
            local c = 1
            for k = 2, GROUP_COLS do if colY[k] < colY[c] then c = k end end
            local x, y = (c - 1) * (COL_W + 12), -colY[c]

            local h = header(gi)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
            h:SetSize(COL_W, 22)
            h.name:SetText(g.name)
            h.count:SetText(g.done .. "/" .. g.total)
            if g.missed > 0 then
                h.count:SetTextColor(1, 0.35, 0.35)
            elseif g.total > 0 and g.done >= g.total then
                h.count:SetTextColor(0.25, 1, 0.25)
            elseif g.done > 0 then
                h.count:SetTextColor(1, 0.82, 0)
            else
                h.count:SetTextColor(0.8, 0.8, 0.8)
            end
            h:Show()
            y = y - 24

            for _, d in ipairs(g.rows) do
                n = n + 1
                local r = row(n)
                r.data = d
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
                r:SetSize(COL_W, ROW_H)
                local st = ns.Roster.STATUS[d.status]
                r.name:SetText(d.display)
                local dim = (d.status == "low" or d.status == "ignored" or d.status == "optional")
                if dim then
                    r.name:SetTextColor(st.color[1], st.color[2], st.color[3])
                elseif d.status == "looted" or d.status == "none" or d.status == "waiting" or d.status == "missed" then
                    r.name:SetTextColor(st.color[1], st.color[2], st.color[3])
                elseif d.seen then
                    r.name:SetTextColor(1, 1, 1)
                else
                    r.name:SetTextColor(0.78, 0.78, 0.78)
                end
                r.status:SetText(type(st.text) == "function" and st.text(d) or st.text)
                r.status:SetTextColor(st.color[1], st.color[2], st.color[3])
                r:Show()
                y = y - ROW_H
            end
            colY[c] = -y + 10
        end
        local height = 10
        for c = 1, GROUP_COLS do height = math.max(height, colY[c]) end
        content:SetHeight(height)
    end

    -- Keep it current while open (kills, loot, the daily reset).
    page.elapsed = 0
    page:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + (dt or 0)
        if self.elapsed >= 1 then self.elapsed = 0; self.Refresh() end
    end)
    page:SetScript("OnShow", function(self) self.elapsed = 0; self.Refresh() end)
    return page
end

local function build()
    win = CreateFrame("Frame", "TarnishedRealReminderOptions", UIParent)
    win:SetSize(4 * COL_W + 5 * 12, 700)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    fill(win, "BACKGROUND", BG, 0.97)
    outline(win, LINE)
    if UISpecialFrames then table.insert(UISpecialFrames, "TarnishedRealReminderOptions") end

    local title = label(win, "Camelus' Tarnished Undermine Real Reminder", "GameFontNormalLarge", ACCENT)
    title:SetPoint("TOPLEFT", 14, -16)
    local sub = label(win, "Changes apply right away. The banner stays up as a preview while this window is open.",
        "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    local close = flatButton(win, "X", 22, 22, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)

    -- Two pages: the look of the reminder, and today's boss checklist.
    local look = CreateFrame("Frame", nil, win)
    look:SetAllPoints()
    local bosses = buildBossPage(win)
    Options.bossPage = bosses
    local tabs = {}
    local function tab(text, key)
        local b = flatButton(win, text, 120, 22, function() Options.ShowTab(key) end)
        b.underline = b:CreateTexture(nil, "OVERLAY")
        b.underline:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        b.underline:SetPoint("BOTTOMLEFT", 1, 1)
        b.underline:SetPoint("BOTTOMRIGHT", -1, 1)
        b.underline:SetHeight(2)
        tabs[key] = b
        return b
    end
    local tabBosses = tab("Bosses today", "bosses")
    tabBosses:SetPoint("RIGHT", close, "LEFT", -12, 0)
    local tabLook = tab("Appearance", "look")
    tabLook:SetPoint("RIGHT", tabBosses, "LEFT", -6, 0)

    function Options.ShowTab(key)
        Options.currentTab = key
        look:SetShown(key == "look")
        bosses:SetShown(key == "bosses")
        for k, b in pairs(tabs) do
            b.underline:SetShown(k == key)
            if k == key then b.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) else b.label:SetTextColor(1, 1, 1) end
        end
        if key == "bosses" then
            sub:SetText("Every boss that drops a Real, by dungeon, and what you've looted today.")
        else
            sub:SetText("Changes apply right away. The banner stays up as a preview while this tab is open.")
        end
        if win.resetLook then win.resetLook:SetShown(key == "look") end
        if ns.Banner then ns.Banner.Update() end
    end

    -- Column 1: the banner itself.
    local c1 = column(look, "Banner", 12)
    slider(c1, "Width", 150, 1000, 5, function() return D().width end, function(v) D().width = v end, px)
    slider(c1, "Height", 30, 400, 1, function() return D().height end, function(v) D().height = v end, px)
    slider(c1, "Scale", 0.5, 2.5, 0.05, function() return D().scale end, function(v) D().scale = v end, times)
    slider(c1, "Opacity", 0.1, 1, 0.05, function() return D().alpha end, function(v) D().alpha = v end, pct)
    slider(c1, "Horizontal position", -1200, 1200, 1, function() return point()[3] end, function(v) setOffset(3, v) end, px)
    slider(c1, "Vertical position", -900, 900, 1, function() return point()[4] end, function(v) setOffset(4, v) end, px)
    checkbox(c1, "Lock (untick to drag the banner)", function() return ns.DB.locked end,
        function(v) ns.DB.locked = v end)
    selector(c1, "Frame layer", ns.STRATAS, function() return D().strata end, function(v) D().strata = v end)
    colorSwatch(c1, "Background colour", function() return D().bgColor end, true)
    selector(c1, "Border", ns.BORDERS, function() return D().border end, function(v)
        D().border = v
        local style = ns.lookup(ns.BORDERS, v)
        if style.size then D().borderSize = style.size end -- a sensible size for that style
        Options.Refresh()
    end)
    colorSwatch(c1, "Border colour", function() return D().borderColor end, true)
    slider(c1, "Border size", 1, 40, 1, function() return D().borderSize end, function(v) D().borderSize = v end, px)

    -- Column 2: text and icon.
    local c2 = column(look, "Text and icon", 12 * 2 + COL_W)
    editBox(c2, "Title text", function() return D().titleText end, function(v) D().titleText = v end)
    selector(c2, "Font", ns.FONTS, function() return D().font end, function(v) D().font = v end)
    selector(c2, "Font outline", ns.OUTLINES, function() return D().outline end, function(v) D().outline = v end)
    selector(c2, "Text alignment", ns.JUSTIFY, function() return D().justify end, function(v) D().justify = v end)
    slider(c2, "Title size", 8, 48, 1, function() return D().titleSize end, function(v) D().titleSize = v end, px)
    colorSwatch(c2, "Title colour", function() return D().titleColor end, true)
    slider(c2, "Boss name size", 8, 32, 1, function() return D().subSize end, function(v) D().subSize = v end, px)
    colorSwatch(c2, "Boss name colour", function() return D().subColor end, true)
    checkbox(c2, "Show the Real icon", function() return D().showIcon end, function(v) D().showIcon = v end)
    selector(c2, "Icon side", ns.ICON_SIDES, function() return D().iconSide end, function(v) D().iconSide = v end)
    slider(c2, "Icon size", 12, 160, 1, function() return D().iconSize end, function(v) D().iconSize = v end, px)
    checkbox(c2, "Show the \"close with X\" hint", function() return D().showHint end, function(v) D().showHint = v end)
    checkbox(c2, "Show the close button", function() return D().showClose end, function(v) D().showClose = v end)

    -- Column 3: motion and sound.
    local c3 = column(look, "Animation and sound", 12 * 3 + COL_W * 2)
    selector(c3, "Animation", ns.ANIMATIONS, function() return D().animation end, function(v) D().animation = v end)
    slider(c3, "Animation speed", 0.2, 3, 0.1, function() return D().animSpeed end, function(v) D().animSpeed = v end, times)
    selector(c3, "Entrance", ns.INTROS, function() return D().intro end, function(v) D().intro = v end)
    buttonRow(c3, "Play entrance", function() ns.Banner.PlayIntro() end)
    checkbox(c3, "Play a sound", function() return ns.DB.sound end, function(v) ns.DB.sound = v end)
    selector(c3, "Sound", ns.SOUNDS, function() return ns.DB.soundKey end, function(v)
        ns.DB.soundKey = v
        ns.PlayAlertSound(true)
    end)
    editBox(c3, "Custom sound (file path or FileDataID)", function() return ns.DB.soundCustom end,
        function(v) ns.DB.soundCustom = v end)
    selector(c3, "Sound channel", ns.SOUND_CHANNELS, function() return ns.DB.soundChannel end,
        function(v) ns.DB.soundChannel = v end)
    buttonRow(c3, "Play sound", function() ns.PlayAlertSound(true) end)
    slider(c3, "Repeat sound every (0 = off)", 0, 120, 5, function() return ns.DB.nagSeconds end,
        function(v) ns.DB.nagSeconds = v end, function(v) return v == 0 and "off" or (v .. " s") end)
    checkbox(c3, "Chat message", function() return ns.DB.chatAlerts end, function(v) ns.DB.chatAlerts = v end)
    checkbox(c3, "Flash the taskbar icon", function() return ns.DB.flashTaskbar end,
        function(v) ns.DB.flashTaskbar = v end)
    checkbox(c3, "Minimap button", function() return not ns.DB.minimap.hide end, function(v)
        ns.DB.minimap.hide = not v
        if ns.Minimap then ns.Minimap.Refresh() end
    end)
    selector(c3, "Minimap tooltip shows", ns.TOOLTIP_MODES, function() return ns.DB.tooltipShows end,
        function(v) ns.DB.tooltipShows = v end)

    -- Column 4: the big warning text.
    local function W() return ns.DB.warning end
    local DEFAULT_WP = { "TOP", "TOP", 0, -250 }
    local function wpoint() return W().point or DEFAULT_WP end
    local function setWOffset(i, v)
        if not W().point then W().point = { DEFAULT_WP[1], DEFAULT_WP[2], DEFAULT_WP[3], DEFAULT_WP[4] } end
        W().point[i] = v
    end
    local function applyWarning() if ns.Banner then ns.Banner.ApplyWarning() end end
    local c4 = column(look, "Warning text", 12 * 4 + COL_W * 3)
    local note = label(c4, "Big text that names the boss. It sits under the banner by default. Untick Lock (Banner column) to drag it.",
        "GameFontDisableSmall")
    note:SetWordWrap(true)
    c4:place(note, 40)
    checkbox(c4, "Show warning text", function() return ns.DB.raidWarning end, function(v) ns.DB.raidWarning = v end)
    slider(c4, "Horizontal position", -1200, 1200, 1, function() return wpoint()[3] end,
        function(v) setWOffset(3, v); applyWarning() end, px)
    slider(c4, "Vertical position", -900, 900, 1, function() return wpoint()[4] end,
        function(v) setWOffset(4, v); applyWarning() end, px)
    slider(c4, "Text size", 10, 60, 1, function() return W().size end,
        function(v) W().size = v; applyWarning() end, px)
    colorSwatch(c4, "Text colour", function() return W().color end, true)
    selector(c4, "Font", ns.FONTS, function() return W().font end, function(v) W().font = v; applyWarning() end)
    selector(c4, "Font outline", ns.OUTLINES, function() return W().outline end,
        function(v) W().outline = v; applyWarning() end)
    slider(c4, "Shown for", 1, 15, 1, function() return W().duration end,
        function(v) W().duration = v end, function(v) return v .. " s" end)
    buttonRow(c4, "Show test warning", function()
        if ns.Banner then ns.Banner.ShowWarning("Loot the Tarnished Undermine Real from Test Boss!") end
    end)
    buttonRow(c4, "Reset warning to defaults", function()
        ns.DB.warning = {}
        ns.applyDefaults(ns.DB.warning, ns.DEFAULTS.warning)
        Options.Refresh()
        applyWarning()
    end)

    -- Footer.
    local test = flatButton(win, "Test reminder", 130, 24, function() ns.slash("test") end)
    test:SetPoint("BOTTOMLEFT", 12, 12)
    local reset = flatButton(win, "Reset look to defaults", 170, 24, function()
        ns.DB.display = {}
        ns.applyDefaults(ns.DB.display, ns.DEFAULTS.display)
        ns.DB.point = nil
        Options.Refresh()
        apply()
    end)
    reset:SetPoint("LEFT", test, "RIGHT", 8, 0)
    win.resetLook = reset
    local done = flatButton(win, "Close", 90, 24, function() win:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -12, 12)

    win:SetScript("OnShow", function() Options.Refresh(); apply() end)
    Options.ShowTab("look")
    win:SetScript("OnHide", function() if ns.Banner then ns.Banner.Update() end end)
    win:Hide()
end

function Options.Refresh()
    if not win then return end
    for _, c in ipairs(controls) do c.Refresh() end
end

function Options.IsShown()
    return win ~= nil and win:IsShown()
end

-- The banner and warning preview only while the Appearance tab is showing.
function Options.IsPreviewing()
    return Options.IsShown() and Options.currentTab ~= "bosses"
end

-- tab: "look" (default) or "bosses".
function Options.Show(tab)
    if not win then build() end
    win:Show()
    Options.ShowTab(tab or Options.currentTab or "look")
end

function Options.Toggle(tab)
    if not win then build() end
    if win:IsShown() and (not tab or tab == Options.currentTab) then
        win:Hide()
    else
        Options.Show(tab)
    end
end

-- An entry under Options > AddOns that opens this window.
function Options.RegisterWithSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "Camelus' Real Reminder"
    local t = label(panel, "Camelus' Tarnished Undermine Real Reminder", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    local b = flatButton(panel, "Open settings", 160, 26, function()
        if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
        Options.Show()
    end)
    b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end
