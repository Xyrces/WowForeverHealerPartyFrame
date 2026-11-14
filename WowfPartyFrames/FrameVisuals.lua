local _, ns = ...
local Visuals = {}
ns.Visuals = Visuals

local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STATUS_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local function text(parent, template, x, y, width, alignment)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    font:SetPoint("TOPLEFT", x, y)
    if width then font:SetWidth(width) end
    font:SetJustifyH(alignment or "LEFT")
    font:SetWordWrap(false)
    font:SetShadowColor(0, 0, 0, 1)
    font:SetShadowOffset(1, -1)
    return font
end

local function disk(parent, diameter, x, y, layer, sublevel, r, g, b)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetSize(diameter, diameter)
    texture:SetPoint("CENTER", parent, "CENTER", x, y)
    texture:SetColorTexture(r, g, b, 1)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
end

local function statusBar(parent, x, y, width, height, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    bar:SetPoint("TOPLEFT", x, y)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(STATUS_TEXTURE)
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.025, 0.025, 0.025, 0.9)
    -- A separate decorative frame keeps the narrow native trim above the fill.
    local trim = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    trim:SetPoint("TOPLEFT", -3, 3)
    trim:SetPoint("BOTTOMRIGHT", 3, -3)
    trim:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 9 })
    trim:SetBackdropBorderColor(0.62, 0.58, 0.47, 1)
    trim:EnableMouse(false)
    bar.text = trim:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    bar.text:SetShadowColor(0, 0, 0, 1)
    bar.text:SetShadowOffset(1, -1)
    return bar
end

function Visuals:DecorateSpellButton(button, size)
    button:SetSize(size, size)
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.border:SetColorTexture(0.62, 0.55, 0.37, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if button.kind == "heals" and button.card and button.card.portraitArea then
        -- One portrait-sized mask shared geometrically by all four icons:
        -- each icon is clipped to its quarter of the circular portrait.
        -- The underlying secure click rectangles remain unchanged.
        local mask = button:CreateMaskTexture()
        mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetSize(58, 58)
        mask:SetPoint("CENTER", button.card.portraitArea, "CENTER")
        button.icon:AddMaskTexture(mask)
    end
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetDrawBling(false)
    button.cooldown:SetHideCountdownNumbers(true)
    button.cooldown:EnableMouse(false)
    if button.kind == "heals" then
        -- Healing controls have no aura timer. Do not leave an empty native
        -- cooldown layer over the portrait when the spell art is transparent.
        button.cooldown:Hide()
    end
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    overlay:EnableMouse(false)
    button.count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("TOPRIGHT", 0, 0)
    button.timer = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.timer:SetPoint("BOTTOM", 0, -1)
    button.rank = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    if button.kind == "heals" then
        -- Keep ranks inside the circular crop, including the lower quadrants.
        button.rank:SetPoint("CENTER", 0, -4)
    else
        button.rank:SetPoint("BOTTOMLEFT", 1, 1)
    end
    for _, font in ipairs({ button.count, button.timer, button.rank }) do
        font:SetShadowColor(0, 0, 0, 1)
        font:SetShadowOffset(1, -1)
    end
    return button
end

function Visuals:DecorateUnit(card)
    card:SetSize(360, 142)
    local portraitArea = CreateFrame("Frame", nil, card)
    card.portraitArea = portraitArea
    portraitArea:SetSize(64, 64)
    portraitArea:SetPoint("TOPLEFT", 4, -12)
    portraitArea:EnableMouse(false)
    -- Layered circular native textures form the familiar raised portrait rim.
    card.targetRing = disk(portraitArea, 72, 0, 0, "BACKGROUND", -5, 1, 0.79, 0.18)
    card.targetRing:Hide()
    disk(portraitArea, 68, 0, 0, "BACKGROUND", -4, 0.12, 0.11, 0.09)
    disk(portraitArea, 66, 0, 1, "BACKGROUND", -3, 0.70, 0.66, 0.55)
    disk(portraitArea, 63, 0, -1, "BACKGROUND", -2, 0.29, 0.27, 0.23)
    disk(portraitArea, 60, 0, 0, "BACKGROUND", -1, 0.055, 0.05, 0.04)
    card.portrait = portraitArea:CreateTexture(nil, "ARTWORK")
    card.portrait:SetSize(58, 58)
    card.portrait:SetPoint("CENTER")
    local mask = portraitArea:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(card.portrait)
    card.portrait:AddMaskTexture(mask)

    card.name = text(card, "GameFontNormal", 78, -3, 266)
    card.health = statusBar(card, 72, -24, 272, 20, 0.12, 0.70, 0.17)
    card.power = statusBar(card, 72, -46, 272, 14, 0.12, 0.35, 0.88)
    card.resourceLabel = text(card, "GameFontHighlightSmall", 4, -79, 56, "CENTER")
    card.resourceLabel:SetTextColor(0.7, 0.75, 0.85)
    card.healRate = text(card, "GameFontHighlightSmall", 73, -66, 90)
    card.damageRate = text(card, "GameFontHighlightSmall", 164, -66, 90)
    card.netRate = text(card, "GameFontHighlightSmall", 255, -66, 90, "RIGHT")
    card.healRate:SetTextColor(0.35, 1, 0.45)
    card.damageRate:SetTextColor(1, 0.36, 0.3)
    card.netRate:SetTextColor(0.95, 0.88, 0.65)
    card.debuffLabel = text(card, "GameFontHighlightSmall", 61, -89, 48, "RIGHT")
    card.buffLabel = text(card, "GameFontHighlightSmall", 61, -117, 48, "RIGHT")
    card.debuffLabel:SetText("Debuffs")
    card.buffLabel:SetText("Buffs")
    card.debuffLabel:SetTextColor(0.8, 0.65, 0.62)
    card.buffLabel:SetTextColor(0.7, 0.7, 0.65)
    card.status = text(card, "GameFontHighlightSmall", 0, -97, 60, "CENTER")

    card.debuffs = {}
    for index = 1, 8 do
        local icon = CreateFrame("Button", nil, card)
        self:DecorateSpellButton(icon, 24)
        icon:SetPoint("TOPLEFT", 112 + (index - 1) * 28, -84)
        icon.border:SetVertexColor(1, 0.25, 0.25)
        card.debuffs[index] = icon
    end

    -- Dividers live above quadrant art without receiving clicks themselves.
    local guides = CreateFrame("Frame", nil, portraitArea)
    guides:SetAllPoints()
    guides:SetFrameLevel(portraitArea:GetFrameLevel() + 10)
    guides:EnableMouse(false)
    card.portraitDividers = {}
    for index = 1, 2 do
        local divider = guides:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(0.85, 0.77, 0.51, 0.85)
        divider:SetPoint("CENTER")
        divider:SetSize(index == 1 and 1 or 60, index == 1 and 60 or 1)
        divider:SetAlpha(0)
        card.portraitDividers[index] = divider
    end
    return card
end

function Visuals:SetPortraitHover(card, show)
    local alpha = show and 1 or 0
    for _, button in ipairs(card.heals or {}) do
        if button.icon then button.icon:SetAlpha(alpha) end
        if button.rank then button.rank:SetAlpha(alpha) end
    end
    for _, divider in ipairs(card.portraitDividers or {}) do divider:SetAlpha(alpha) end
end
