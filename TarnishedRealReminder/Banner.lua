-- The reminder banner: every part of its look comes from DB.display, so the
-- settings window can change it live.
local _, ns = ...

local Banner = {}
ns.Banner = Banner

ns.FONTS = {
    { key = "friz",     label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "arial",    label = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", label = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri",   label = "Skurri",        path = "Fonts\\SKURRI.TTF" },
}
ns.OUTLINES = {
    { key = "",             label = "None" },
    { key = "OUTLINE",      label = "Outline" },
    { key = "THICKOUTLINE", label = "Thick outline" },
}
ns.BORDERS = {
    { key = "none",    label = "None" },
    { key = "solid",   label = "Solid line", size = 2 },
    { key = "gold",    label = "Gold dialog", size = 20,
      edge = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border" },
    { key = "dialog",  label = "Silver dialog", size = 20,
      edge = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    { key = "tooltip", label = "Tooltip", size = 14,
      edge = "Interface\\Tooltips\\UI-Tooltip-Border" },
}
ns.ANIMATIONS = {
    { key = "none",   label = "None" },
    { key = "pulse",  label = "Pulse (text and icon fade)" },
    { key = "flash",  label = "Flash (whole banner blinks)" },
    { key = "bounce", label = "Bounce" },
    { key = "shake",  label = "Shake" },
    { key = "grow",   label = "Grow and shrink" },
    { key = "glow",   label = "Glowing border" },
}
ns.INTROS = {
    { key = "none",  label = "None" },
    { key = "fade",  label = "Fade in" },
    { key = "zoom",  label = "Zoom in" },
    { key = "slide", label = "Slide down" },
}
ns.STRATAS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN_DIALOG" }
ns.ICON_SIDES = {
    { key = "LEFT",  label = "Left" },
    { key = "RIGHT", label = "Right" },
    { key = "NONE",  label = "Hidden" },
}
ns.JUSTIFY = {
    { key = "LEFT",   label = "Left" },
    { key = "CENTER", label = "Center" },
    { key = "RIGHT",  label = "Right" },
}

function ns.lookup(list, key)
    for _, item in ipairs(list) do
        if item.key == key then return item end
    end
    return list[1]
end

local f         -- container: holds the position, never animated
local body      -- everything visible; animations move and scale this
local introStart = -100
local INTRO_TIME = 0.45

local function D() return ns.DB.display end

local function rgba(c, fallback)
    c = c or fallback
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

local function savePoint()
    local point, _, relPoint, x, y = f:GetPoint(1)
    ns.DB.point = { point or "CENTER", relPoint or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
    if ns.Options then ns.Options.Refresh() end
end

local function build()
    if f then return end
    f = CreateFrame("Frame", "TarnishedRealReminderBanner", UIParent)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not ns.DB.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePoint() end)

    body = CreateFrame("Frame", nil, f)
    body:SetPoint("CENTER")
    f.body = body

    body.bg = body:CreateTexture(nil, "BACKGROUND")
    body.bg:SetAllPoints()

    -- Solid border: four strips.
    body.strips = {}
    for i = 1, 4 do body.strips[i] = body:CreateTexture(nil, "BORDER") end

    -- Texture borders: a backdrop on a child frame (template if the client
    -- has it, otherwise the mixin, otherwise no texture border at all).
    local ok, edge = pcall(CreateFrame, "Frame", nil, body, "BackdropTemplate")
    if not ok then
        edge = CreateFrame("Frame", nil, body)
        if BackdropTemplateMixin and Mixin then
            pcall(Mixin, edge, BackdropTemplateMixin)
            if edge.OnBackdropLoaded then pcall(edge.OnBackdropLoaded, edge) end
        end
    end
    edge:SetAllPoints()
    body.edge = edge

    body.icon = body:CreateTexture(nil, "ARTWORK")
    body.title = body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    body.sub = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body.sub:SetWordWrap(true)
    body.hint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    body.hint:SetText("Nothing on the corpse? Close this with X.")

    local close = CreateFrame("Button", nil, body)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    close:SetScript("OnClick", function()
        if ns.Options and ns.Options.IsShown() and #ns.CDB.pending == 0 then return end
        ns.dismissAll()
    end)
    body.close = close

    f.elapsed = 0
    f:SetScript("OnUpdate", function(self, dt) Banner.Animate(dt) end)
    f:Hide()
end

------------------------------------------------------------------------------
-- Apply settings
------------------------------------------------------------------------------

local function layoutBorder(d)
    local style = ns.lookup(ns.BORDERS, d.border)
    local r, g, b, a = rgba(d.borderColor, { 1, 1, 1, 1 })
    local size = math.max(1, d.borderSize or 2)

    local s = body.strips
    for i = 1, 4 do s[i]:ClearAllPoints(); s[i]:Hide() end
    if style.key == "solid" then
        s[1]:SetPoint("TOPLEFT"); s[1]:SetPoint("TOPRIGHT"); s[1]:SetHeight(size)
        s[2]:SetPoint("BOTTOMLEFT"); s[2]:SetPoint("BOTTOMRIGHT"); s[2]:SetHeight(size)
        s[3]:SetPoint("TOPLEFT"); s[3]:SetPoint("BOTTOMLEFT"); s[3]:SetWidth(size)
        s[4]:SetPoint("TOPRIGHT"); s[4]:SetPoint("BOTTOMRIGHT"); s[4]:SetWidth(size)
        for i = 1, 4 do s[i]:SetColorTexture(r, g, b, a); s[i]:Show() end
    end

    local edge = body.edge
    if edge.SetBackdrop then
        if style.edge then
            edge:SetBackdrop({ edgeFile = style.edge, edgeSize = size })
            if edge.SetBackdropBorderColor then edge:SetBackdropBorderColor(r, g, b, a) end
            edge:Show()
        else
            edge:SetBackdrop(nil)
            edge:Hide()
        end
    end
    -- Keep the background inside a texture border so its corners stay clean.
    local inset = style.edge and math.floor(size / 4) or 0
    body.bg:ClearAllPoints()
    body.bg:SetPoint("TOPLEFT", inset, -inset)
    body.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
end

local function setFont(fs, d, size)
    local font = ns.lookup(ns.FONTS, d.font)
    local ok = pcall(fs.SetFont, fs, font.path, size, d.outline or "")
    if not ok or not fs:GetFont() then
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, d.outline or "")
    end
end

function Banner.Apply()
    build()
    f.applied = true
    local d = D()
    f:SetSize(d.width, d.height)
    body:SetSize(d.width, d.height)
    f:SetScale(math.max(0.3, d.scale or 1))
    f:SetAlpha(d.alpha or 1)
    f:SetFrameStrata(d.strata or "HIGH")

    f:ClearAllPoints()
    local p = ns.DB.point
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end

    body.bg:SetColorTexture(rgba(d.bgColor, { 0, 0, 0, 0.75 }))
    layoutBorder(d)

    local pad = 14
    local rightPad = d.showClose and 32 or pad
    local icon = body.icon
    icon:ClearAllPoints()
    icon:SetSize(d.iconSize, d.iconSize)
    icon:SetTexture(ns.DB.realIcon or ns.REAL_FALLBACK_ICON)
    local left, right = pad, rightPad
    if d.showIcon and d.iconSide ~= "NONE" then
        icon:Show()
        if d.iconSide == "RIGHT" then
            icon:SetPoint("RIGHT", -rightPad, 0)
            right = rightPad + d.iconSize + 10
        else
            icon:SetPoint("LEFT", pad, 0)
            left = pad + d.iconSize + 10
        end
    else
        icon:Hide()
    end

    local title, sub, hint = body.title, body.sub, body.hint
    setFont(title, d, d.titleSize)
    setFont(sub, d, d.subSize)
    title:SetTextColor(rgba(d.titleColor, { 1, 0.82, 0, 1 }))
    sub:SetTextColor(rgba(d.subColor, { 1, 1, 1, 1 }))
    title:SetText(d.titleText ~= "" and d.titleText or ("Loot your " .. ns.REAL_DISPLAY_NAME .. "!"))

    for _, fs in ipairs({ title, sub, hint }) do
        fs:ClearAllPoints()
        fs:SetJustifyH(d.justify or "LEFT")
    end
    -- Centre the text block vertically.
    local blockH = d.titleSize + 6 + d.subSize + (d.showHint and 16 or 0)
    local top = -math.max(8, (d.height - blockH) / 2)
    title:SetPoint("TOPLEFT", left, top)
    title:SetPoint("TOPRIGHT", -right, top)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -6)
    hint:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("TOPRIGHT", sub, "BOTTOMRIGHT", 0, -4)
    hint:SetShown(d.showHint and true or false)
    body.close:SetShown(d.showClose and true or false)

    Banner.Update()
end

------------------------------------------------------------------------------
-- Show / hide
------------------------------------------------------------------------------

function Banner.Update()
    if not ns.DB then return end
    build()
    if not f.applied then return Banner.Apply() end
    local pending = ns.CDB and ns.CDB.pending or {}
    local preview = ns.Options and ns.Options.IsShown()
    local n = #pending
    local active = n > 0 and (ns.isEligibleInstance() or ns.testMode)

    if active then
        body.sub:SetText((n == 1 and "Waiting on: " or (n .. " bosses waiting: ")) .. ns.pendingNames())
    elseif preview then
        body.sub:SetText("Preview: Emperor Dagran Thaurissan")
    elseif not ns.DB.locked then
        body.sub:SetText("Unlocked: drag me, then type /trr lock")
    end
    body.icon:SetTexture(ns.DB.realIcon or ns.REAL_FALLBACK_ICON)

    -- Only take the mouse while unlocked, so a locked banner never blocks
    -- clicks on the world behind it. The close button has its own mouse.
    f:EnableMouse(not ns.DB.locked)
    if active or preview or not ns.DB.locked then
        f:Show()
    else
        f:Hide()
    end
end

function Banner.PlayIntro()
    introStart = GetTime()
end

function Banner.IsShown() return f and f:IsShown() end
function Banner.Frame() return f end

------------------------------------------------------------------------------
-- Animation
------------------------------------------------------------------------------

function Banner.Animate(dt)
    f.elapsed = f.elapsed + (dt or 0)
    local d = D()
    local t = f.elapsed * (d.animSpeed or 1)
    local anim = d.animation or "none"

    local alpha, contentAlpha, borderAlpha, scale, ox, oy = 1, 1, 1, 1, 0, 0
    if anim == "pulse" then
        contentAlpha = 0.45 + 0.55 * math.abs(math.sin(t * 3))
    elseif anim == "flash" then
        alpha = (math.floor(t * 2.5) % 2 == 0) and 1 or 0.25
    elseif anim == "bounce" then
        oy = math.abs(math.sin(t * 4)) * 10
    elseif anim == "shake" then
        local phase = t % 2
        if phase < 0.5 then ox = math.sin(t * 60) * 6 * (1 - phase * 2) end
    elseif anim == "grow" then
        scale = 1 + 0.06 * math.sin(t * 4)
    elseif anim == "glow" then
        borderAlpha = 0.25 + 0.75 * math.abs(math.sin(t * 3))
    end

    -- Entrance effect, layered on top.
    local since = GetTime() - introStart
    if since >= 0 and since < INTRO_TIME then
        local p = since / INTRO_TIME
        local intro = d.intro or "none"
        if intro == "fade" then
            alpha = alpha * p
        elseif intro == "zoom" then
            scale = scale * (1 + (1 - p) * 0.8)
            alpha = alpha * math.min(1, p * 2)
        elseif intro == "slide" then
            oy = oy + (1 - p) * 80
            alpha = alpha * p
        end
    end

    body:SetAlpha(alpha)
    body.title:SetAlpha(contentAlpha)
    body.icon:SetAlpha(contentAlpha)
    body.edge:SetAlpha(borderAlpha)
    for i = 1, 4 do body.strips[i]:SetAlpha(borderAlpha) end
    body:SetScale(scale)
    body:ClearAllPoints()
    body:SetPoint("CENTER", f, "CENTER", ox / scale, oy / scale)
end
