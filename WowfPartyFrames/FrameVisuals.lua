local _, ns = ...
local Visuals = {}
ns.Visuals = Visuals
-- Shared by live frames and preview; no separate mockup geometry.
ns.Layout = {width=224, height=84, pitch=90, portrait=54, portraitInner=46,
    healSize=23, healInset=4, auraSize=16, auraPitch=17, auraX=88,
    debuffY=-50, buffY=-68, barX=57, barWidth=110, rateY=-38, rateHeight=10}
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
    bar:SetPoint("TOPLEFT", L.barX, y)
    bar:SetSize(L.barWidth, height)
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
    trim:SetPoint("TOPLEFT", 52, -12)
    trim:SetSize(120, 26)
    trim:SetFrameLevel(card.health:GetFrameLevel() + 2)
    trim:EnableMouse(false)
    -- Keep native bevels and endcaps; stretch only the straight center.
    for _, slice in ipairs({{44,48,0,5}, {48,112,5,105}, {112,120,110,10}}) do
        local art = trim:CreateTexture(nil, "ARTWORK")
        art:SetTexture(PARTY_ART)
        art:SetTexCoord(slice[1]/128, slice[2]/128, 8/64, 28/64)
        art:SetSize(slice[4], 26)
        art:SetPoint("TOPLEFT", slice[3], 0)
    end
    card.health.text = text(trim, 5, -3, L.barWidth, 9, "CENTER")
    card.power.text = text(trim, 5, -14, L.barWidth, 8, "CENTER")
end

local function rateBar(card)
    local bar = CreateFrame("Frame", nil, card)
    card.rateBar = bar
    bar:SetPoint("TOPLEFT", L.barX, L.rateY)
    bar:SetSize(L.barWidth, L.rateHeight)
    bar:EnableMouse(false)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.025, 0.028, 0.032, 0.98)
    bar.healingFill = bar:CreateTexture(nil, "ARTWORK")
    bar.healingFill:SetPoint("TOPLEFT", 1, -1)
    bar.healingFill:SetSize(L.barWidth - 2, L.rateHeight - 2)
    bar.healingFill:SetColorTexture(0.045, 0.32, 0.105, 1)
    bar.damageFill = bar:CreateTexture(nil, "ARTWORK")
    bar.damageFill:SetPoint("TOPRIGHT", -1, -1)
    bar.damageFill:SetSize(L.barWidth - 2, L.rateHeight - 2)
    bar.damageFill:SetColorTexture(0.43, 0.065, 0.045, 1)
    -- Fixed text columns never follow the moving meeting point of the fills.
    local center = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    center:SetPoint("TOPLEFT", 35, 0)
    center:SetSize(40, L.rateHeight)
    center:SetColorTexture(0.01, 0.012, 0.014, 0.3)
    card.healRate = text(bar, 2, -1, 32, 8, "LEFT")
    card.netRate = text(bar, 35, -1, 40, 8, "CENTER")
    card.damageRate = text(bar, 76, -1, 32, 8, "RIGHT")
    card.healRate:SetTextColor(0.65, 1, 0.68)
    card.damageRate:SetTextColor(1, 0.7, 0.63)
end

local function finite(value)
    return not ns.IsSecret(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function rateText(value, signed)
    local magnitude = math.floor(math.abs(value) + 0.5)
    local result
    if magnitude < 1000 then
        result = string.format("%.0f", magnitude)
    elseif magnitude >= 999500000000 then
        result = string.format("%.0e", magnitude):gsub("e%+0*", "e")
    else
        local divisor, suffix = 1000, "k"
        if magnitude >= 999500000 then divisor, suffix = 1000000000, "b"
        elseif magnitude >= 999500 then divisor, suffix = 1000000, "m" end
        local scaled = magnitude / divisor
        result = (string.format(scaled < 100 and "%.1f" or "%.0f", scaled):gsub("%.0$", "")) .. suffix
    end
    if signed then result = (value < 0 and magnitude > 0 and "-" or "+") .. result end
    return result .. "/s"
end

function Visuals:PaintRates(card, heal, damage, net, status)
    local bar = card.rateBar
    local available = status == "available" and finite(heal) and finite(damage) and finite(net)
        and heal >= 0 and damage >= 0
    card.rateStatus = available and "available" or (status ~= "available" and status or "Rates unavailable")
    card.healingPerSecond, card.damagePerSecond, card.netPerSecond = nil, nil, nil
    bar.healingFill:SetAlpha(0)
    bar.damageFill:SetAlpha(0)
    if not available then
        card.healRate:SetText("--")
        card.damageRate:SetText("--")
        card.netRate:SetText(status == "Collecting rates" and "..." or "--")
        card.netRate:SetTextColor(0.65, 0.65, 0.65)
        return
    end
    card.healingPerSecond, card.damagePerSecond, card.netPerSecond = heal, damage, net
    card.healRate:SetText(rateText(heal))
    card.damageRate:SetText(rateText(damage))
    card.netRate:SetText(rateText(net, true))
    if net >= 0.5 then card.netRate:SetTextColor(0.75, 1, 0.78)
    elseif net <= -0.5 then card.netRate:SetTextColor(1, 0.76, 0.7)
    else card.netRate:SetTextColor(0.93, 0.93, 0.9) end
    -- Normalize before adding: two valid finite rates can overflow their sum.
    local peak = math.max(heal, damage)
    if peak > 0 then
        local left, right = heal / peak, damage / peak
        local share = left / (left + right)
        local width = L.barWidth - 2
        bar.healingFill:SetWidth(math.max(0.01, width * share))
        bar.damageFill:SetWidth(math.max(0.01, width * (1 - share)))
        bar.healingFill:SetAlpha(heal > 0 and 1 or 0)
        bar.damageFill:SetAlpha(damage > 0 and 1 or 0)
    end
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
    button.count = text(overlay, 0, 0, size, 8, "RIGHT")
    button.timer = text(overlay, -2, -(size - 7), size + 4, 7, "CENTER")
    button.rank = text(overlay, 0, -(size - 8), size, 8, "CENTER")
    return button
end

function Visuals:DecorateUnit(card)
    card:SetSize(L.width, L.height)
    card.health = statusBar(card, -16, 9, 0.10, 0.75, 0.12)
    card.power = statusBar(card, -27, 8, 0.12, 0.28, 0.88)
    barTrim(card)
    local area = CreateFrame("Frame", nil, card)
    card.portraitArea = area
    area:SetSize(L.portrait, L.portrait)
    area:SetPoint("TOPLEFT", 0, -1)
    area:SetFrameLevel(card.health:GetFrameLevel() + 4)
    area:EnableMouse(false)
    card.targetRing = portraitRim(area, L.portrait + 3, "BACKGROUND")
    card.targetRing:SetVertexColor(1, 0.8, 0.2)
    card.targetRing:SetBlendMode("ADD")
    card.targetRing:SetAlpha(0)
    card.portrait = area:CreateTexture(nil, "ARTWORK")
    card.portrait:SetSize(L.portraitInner, L.portraitInner)
    card.portrait:SetPoint("CENTER")
    circleMask(area, card.portrait, L.portraitInner)
    card.portraitRim = portraitRim(area, L.portrait, "OVERLAY")
    card.name = text(card, 58, 0, 80, 11)
    card.status = text(card, 139, -1, 34, 8, "RIGHT")
    card.status:SetTextColor(0.82, 0.8, 0.72)
    rateBar(card)
    self:PaintRates(card, nil, nil, nil, "Collecting rates")
    card.debuffLabel = text(card, 50, L.debuffY - 4, 34, 8, "RIGHT")
    card.debuffLabel:SetText("Debuffs")
    card.debuffLabel:SetTextColor(0.9, 0.8, 0.72)
    card.buffLabel = text(card, 50, L.buffY - 4, 34, 8, "RIGHT")
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
