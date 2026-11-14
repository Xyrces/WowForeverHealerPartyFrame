local _, ns = ...
local Visuals = {}
ns.Visuals = Visuals
-- Shared by live frames and preview; no separate mockup geometry.
ns.Layout = {width=314, height=116, pitch=124, portrait=84, portraitInner=72,
    healSize=36, auraSize=22, auraPitch=23, auraX=128, debuffY=-68, buffY=-94}
local L = ns.Layout
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local PORTRAIT_ART = "Interface\\CharacterFrame\\UI-Player-Portrait"
local PARTY_ART = "Interface\\TargetingFrame\\UI-PartyFrame"

local function text(parent, x, y, width, size, alignment)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    font:SetFont(FONT, size or 10, "OUTLINE")
    font:SetPoint("TOPLEFT", x, y)
    if width then font:SetWidth(width) end
    font:SetJustifyH(alignment or "LEFT")
    font:SetWordWrap(false)
    font:SetShadowColor(0, 0, 0, 0.9)
    font:SetShadowOffset(1, -1)
    return font
end

local function circleMask(parent, texture, size, relative)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(size, size)
    mask:SetPoint("CENTER", relative or texture, "CENTER")
    texture:AddMaskTexture(mask)
    return mask
end

local function portraitRim(parent, size, layer)
    local rim = parent:CreateTexture(nil, layer)
    rim:SetTexture(PORTRAIT_ART)
    -- Circular rim, excluding the bars: pixels (4,2)-(72,70) of 256x128.
    rim:SetTexCoord(4/256, 72/256, 2/128, 70/128)
    rim:SetSize(size, size)
    rim:SetPoint("CENTER")
    circleMask(parent, rim, size)
    return rim
end

local function statusBar(parent, y, height, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("TOPLEFT", 88, y)
    bar:SetSize(190, height)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.018, 0.021, 0.025, 0.94)
    return bar
end

local function barTrim(card)
    local trim = CreateFrame("Frame", nil, card)
    trim:SetPoint("TOPLEFT", 82, -16)
    trim:SetSize(204, 40)
    trim:SetFrameLevel(card.health:GetFrameLevel() + 2)
    trim:EnableMouse(false)
    -- Keep native bevels and endcaps; stretch only the straight center.
    for _, slice in ipairs({{44,48,0,8}, {48,112,8,180}, {112,120,188,16}}) do
        local art = trim:CreateTexture(nil, "ARTWORK")
        art:SetTexture(PARTY_ART)
        art:SetTexCoord(slice[1]/128, slice[2]/128, 8/64, 28/64)
        art:SetSize(slice[4], 40)
        art:SetPoint("TOPLEFT", slice[3], 0)
    end
    card.health.text = text(trim, 7, -5, 190, 11, "CENTER")
    card.power.text = text(trim, 7, -21, 190, 10, "CENTER")
    card.resourceLabel = text(trim, 9, -22, 40, 8, "LEFT")
    card.resourceLabel:SetTextColor(0.9, 0.85, 0.65)
end

function Visuals:DecorateSpellButton(button, size)
    button:SetSize(size, size)
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.border:SetColorTexture(0.42, 0.34, 0.19, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if button.kind == "heals" and button.card then
        circleMask(button, button.icon, L.portraitInner, button.card.portraitArea)
    else
        button.rim = button:CreateTexture(nil, "OVERLAY")
        button.rim:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        button.rim:SetSize(size * 1.65, size * 1.65)
        button.rim:SetPoint("CENTER")
        button.glow = button:CreateTexture(nil, "OVERLAY")
        button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        button.glow:SetBlendMode("ADD")
        button.glow:SetVertexColor(1, 0.73, 0.15)
        button.glow:SetSize(size * 1.8, size * 1.8)
        button.glow:SetPoint("CENTER")
        button.glow:SetAlpha(0)
    end
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetDrawBling(false)
    button.cooldown:SetHideCountdownNumbers(true)
    button.cooldown:EnableMouse(false)
    if button.kind == "heals" then button.cooldown:Hide() end
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button.cooldown:GetFrameLevel() + 2)
    overlay:EnableMouse(false)
    button.count = text(overlay, 0, 0, size, 9, "RIGHT")
    button.timer = text(overlay, -2, -(size - 8), size + 4, 8, "CENTER")
    button.rank = text(overlay, 0, -(size - 11), size, 10, "CENTER")
    return button
end

function Visuals:DecorateUnit(card)
    card:SetSize(L.width, L.height)
    card.health = statusBar(card, -22, 13, 0.10, 0.75, 0.12)
    card.power = statusBar(card, -39, 12, 0.12, 0.28, 0.88)
    barTrim(card)
    local area = CreateFrame("Frame", nil, card)
    card.portraitArea = area
    area:SetSize(L.portrait, L.portrait)
    area:SetPoint("TOPLEFT", 0, -1)
    area:SetFrameLevel(card.health:GetFrameLevel() + 4)
    area:EnableMouse(false)
    card.targetRing = portraitRim(area, 89, "BACKGROUND")
    card.targetRing:SetVertexColor(1, 0.8, 0.2)
    card.targetRing:SetBlendMode("ADD")
    card.targetRing:SetAlpha(0)
    card.portrait = area:CreateTexture(nil, "ARTWORK")
    card.portrait:SetSize(L.portraitInner, L.portraitInner)
    card.portrait:SetPoint("CENTER")
    circleMask(area, card.portrait, L.portraitInner)
    card.portraitRim = portraitRim(area, L.portrait, "OVERLAY")
    card.name = text(card, 88, 0, 146, 14)
    card.status = text(card, 235, -2, 49, 9, "RIGHT")
    card.status:SetTextColor(0.82, 0.8, 0.72)
    card.healRate = text(card, 88, -56, 66, 10)
    card.damageRate = text(card, 156, -56, 66, 10)
    card.netRate = text(card, 224, -56, 65, 10)
    card.healRate:SetTextColor(0.4, 1, 0.4)
    card.damageRate:SetTextColor(1, 0.4, 0.32)
    card.netRate:SetTextColor(0.9, 0.88, 0.7)
    card.debuffLabel = text(card, 84, -74, 40, 9, "RIGHT")
    card.debuffLabel:SetText("Debuffs")
    card.debuffLabel:SetTextColor(0.9, 0.8, 0.72)
    card.buffLabel = text(card, 84, -100, 40, 9, "RIGHT")
    card.buffLabel:SetText("Buffs")
    card.buffLabel:SetTextColor(0.9, 0.86, 0.7)
    card.debuffs = {}
    for index = 1, 8 do
        local button = CreateFrame("Button", nil, card)
        self:DecorateSpellButton(button, L.auraSize)
        button:SetPoint("TOPLEFT", L.auraX + (index - 1) * L.auraPitch, L.debuffY)
        button.rim:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        button.rim:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        button.rim:SetSize(L.auraSize + 3, L.auraSize + 3)
        button.rim:SetVertexColor(0.8, 0.2, 0.15)
        card.debuffs[index] = button
    end
    local guides = CreateFrame("Frame", nil, area)
    guides:SetAllPoints()
    guides:SetFrameLevel(area:GetFrameLevel() + 10)
    guides:EnableMouse(false)
    card.portraitDividers = {}
    for index = 1, 2 do
        local divider = guides:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(0.78, 0.64, 0.36, 0.95)
        divider:SetPoint("CENTER")
        divider:SetSize(index == 1 and 1 or L.portraitInner, index == 1 and L.portraitInner or 1)
        divider:SetAlpha(0)
        card.portraitDividers[index] = divider
    end
    return card
end

function Visuals:SetPortraitHover(card, show)
    local alpha = show and 1 or 0
    for _, button in ipairs(card.heals or {}) do
        button.icon:SetAlpha(alpha)
        button.rank:SetAlpha(alpha)
    end
    for _, divider in ipairs(card.portraitDividers or {}) do divider:SetAlpha(alpha) end
end