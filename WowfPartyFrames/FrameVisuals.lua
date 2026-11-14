local _, ns = ...
local Visuals = {}
ns.Visuals = Visuals
-- Shared by live frames and preview; no separate mockup geometry.
ns.Layout = {width=270, height=128, pitch=138, portrait=82, portraitInner=74,
    portraitX=184, healSize=36, healGap=2, healInset=4, auraSize=16, auraPitch=17, auraX=44,
    debuffY=-76, buffY=-96, barX=5, barWidth=174, rateY=-60, rateHeight=12,
    infoY=-15, locationY=-116}
local L = ns.Layout
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local PORTRAIT_ART = "Interface\\CharacterFrame\\UI-Player-Portrait"
local ROLE_ATLASES = {TANK="roleicon-tiny-tank", HEALER="roleicon-tiny-healer", DAMAGER="roleicon-tiny-dps"}

function Visuals:PaintIdentityIcons(card, roleToken, markerIndex)
    local role = not ns.IsSecret(roleToken) and type(roleToken) == "string" and ROLE_ATLASES[roleToken]
    -- Sprite-cell selection is done by the client, including for secret
    -- indices. No addon arithmetic or table lookup inspects the marker.
    local marker = type(markerIndex) == "number"
    if marker and not ns.IsSecret(markerIndex) then
        marker = markerIndex >= 1 and markerIndex <= 8 and markerIndex == math.floor(markerIndex)
    end
    card.roleIcon:Hide()
    card.markerIcon:Hide()
    if role then card.roleIcon:SetAtlas(role); card.roleIcon:Show() end
    if marker then
        local ok = pcall(card.markerIcon.SetSpriteSheetCell, card.markerIcon, markerIndex, 4, 4)
        marker = ok
        card.markerIcon:SetShown(ok)
    end
    local count = (role and 1 or 0) + (marker and 1 or 0)
    local maximum = L.barWidth - count * 14
    card.memberInfo:SetWidth(maximum)
    local width = card.memberInfo.GetStringWidth and card.memberInfo:GetStringWidth()
    if ns.IsSecret(width) or type(width) ~= "number" or width < 0 or width ~= width then width = maximum end
    local x = L.barX + math.min(width, maximum) + 2
    if role then
        card.roleIcon:ClearAllPoints()
        card.roleIcon:SetPoint("TOPLEFT", card, "TOPLEFT", x, L.infoY + 1)
        x = x + 14
    end
    if marker then
        card.markerIcon:ClearAllPoints()
        card.markerIcon:SetPoint("TOPLEFT", card, "TOPLEFT", x, L.infoY + 1)
    end
end

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
    rim:SetTexCoord(72/256, 4/256, 2/128, 70/128)
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
    trim:SetPoint("TOPLEFT", 0, -27)
    trim:SetSize(L.barWidth + 10, 33)
    trim:SetFrameLevel(card.health:GetFrameLevel() + 2)
    trim:EnableMouse(false)
    -- The native player sheet has the same silver trim at higher resolution
    -- than the tiny party sheet. Use its health/power rows, omitting the name
    -- box. Mirror the caps and stretch only the straight center section.
    for _, slice in ipairs({{193,185,0,10}, {185,73,10,L.barWidth-7}, {73,67,L.barWidth+3,7}}) do
        local art = trim:CreateTexture(nil, "ARTWORK")
        art:SetTexture(PORTRAIT_ART)
        art:SetTexCoord(slice[1]/256, slice[2]/256, 33/128, 60/128)
        art:SetSize(slice[4], 33)
        art:SetPoint("TOPLEFT", slice[3], 0)
    end
    card.health.text = text(trim, 5, -4, L.barWidth, 11, "CENTER")
    card.power.text = text(trim, 5, -18, L.barWidth, 10, "CENTER")
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
    center:SetPoint("TOPLEFT", 58, 0)
    center:SetSize(58, L.rateHeight)
    center:SetColorTexture(0.01, 0.012, 0.014, 0.3)
    card.healRate = text(bar, 2, -1, 53, 9, "LEFT")
    card.netRate = text(bar, 58, -1, 58, 9, "CENTER")
    card.damageRate = text(bar, 119, -1, 53, 9, "RIGHT")
    card.rateUnavailable = text(bar, 2, -1, L.barWidth - 4, 9, "CENTER")
    card.rateUnavailable:SetTextColor(0.65, 0.65, 0.65)
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
    for _, label in ipairs({card.healRate, card.netRate, card.damageRate}) do label:SetAlpha(available and 1 or 0) end
    card.rateUnavailable:SetAlpha(available and 0 or 1)
    if not available then
        card.rateUnavailable:SetText(status == "Collecting rates" and "Collecting rates..." or "Rates unavailable")
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
        button.portraitMask = circleMask(button, button.icon, L.portraitInner, button.card.portraitArea)
        button.maskAttached = true
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
    card.health = statusBar(card, -32, 12, 0.10, 0.75, 0.12)
    card.power = statusBar(card, -46, 10, 0.12, 0.28, 0.88)
    barTrim(card)
    local area = CreateFrame("Frame", nil, card)
    card.portraitArea = area
    area:SetSize(L.portrait, L.portrait)
    area:SetPoint("TOPLEFT", L.portraitX, -1)
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
    card.name = text(card, L.barX, 0, L.barWidth - 40, 12)
    card.roleIcon = card:CreateTexture(nil, "OVERLAY")
    card.roleIcon:SetSize(12, 12)
    card.roleIcon:Hide()
    card.markerIcon = card:CreateTexture(nil, "OVERLAY")
    card.markerIcon:SetSize(12, 12)
    card.markerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    card.markerIcon:Hide()
    card.status = text(card, L.barX + L.barWidth - 36, -2, 36, 9, "RIGHT")
    card.status:SetTextColor(0.82, 0.8, 0.72)
    card.memberInfo = text(card, L.barX, L.infoY, L.barWidth, 9)
    card.memberInfo:SetTextColor(0.78, 0.78, 0.74)
    card.presetLabel = text(card, L.portraitX, -87, L.portrait, 9, "CENTER")
    card.presetLabel:SetTextColor(0.88, 0.78, 0.53)
    card.location = text(card, L.barX, L.locationY, L.barWidth, 8)
    card.location:SetTextColor(0.7, 0.77, 0.85)
    rateBar(card)
    self:PaintRates(card, nil, nil, nil, "Collecting rates")
    card.debuffLabel = text(card, L.barX, L.debuffY - 4, 35, 8, "RIGHT")
    card.debuffLabel:SetText("Debuffs")
    card.debuffLabel:SetTextColor(0.9, 0.8, 0.72)
    card.buffLabel = text(card, L.barX, L.buffY - 4, 35, 8, "RIGHT")
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

function Visuals:ApplyControlStyle(card)
    local round = ns.db and ns.db.controlStyle == "quadrants"
    card.controlStyle = round and "quadrants" or "buttons"
    for index, button in ipairs(card.heals or {}) do
        if round and not button.maskAttached then
            button.icon:AddMaskTexture(button.portraitMask)
            button.maskAttached = true
        elseif not round and button.maskAttached then
            button.icon:RemoveMaskTexture(button.portraitMask)
            button.maskAttached = false
        end
        button.rank:ClearAllPoints()
        button.rank:SetPoint("TOPLEFT", 0, round and index > 2 and -1 or -(L.healSize - 10))
        button.rank:SetFont(FONT, 10, "OUTLINE")
    end
    self:SetPortraitHover(card, false)
end

function Visuals:SetPortraitHover(card, show)
    local round = card.controlStyle == "quadrants"
    local alpha = show and 1 or 0
    card.portrait:SetAlpha(show and not round and 0 or 1)
    card.portraitRim:SetAlpha(show and not round and 0 or 1)
    for _, button in ipairs(card.heals or {}) do
        button.icon:SetAlpha(alpha)
        button.rank:SetAlpha(alpha)
        button.border:SetAlpha(show and not round and 1 or 0)
    end
    for _, divider in ipairs(card.portraitDividers or {}) do divider:SetAlpha(round and alpha or 0) end
end
