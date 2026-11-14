local _, ns = ...
local Prediction = {}
ns.HealthPrediction = Prediction

-- Native calculators and status bars own all arithmetic involving unit data.
-- In particular, never read a fill's width or branch on a calculated amount.
local REQUIRED = {
    "SetIncomingHealClampMode", "SetDamageAbsorbClampMode", "SetHealAbsorbClampMode",
    "SetHealAbsorbMode", "SetMaximumHealthMode", "SetIncomingHealOverflowPercent",
    "SetPredictedValues", "ResetPredictedValues", "GetMaximumHealth", "GetIncomingHeals", "GetDamageAbsorbs", "GetHealAbsorbs",
}

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function setupReason(err)
    if not isSecret(err) and type(err) == "string" then
        return "Native prediction setup failed: " .. err:sub(1, 240)
    end
    return "Native prediction setup failed"
end

local function clear(state)
    state.unit = nil
    if state.holder then state.holder:SetAlpha(0) end
    if state.glowHolder then state.glowHolder:SetAlpha(0) end
    for _, bar in ipairs(state.bars) do bar:SetValue(0) end
    if state.overAbsorbGlow then state.overAbsorbGlow:SetAlpha(0) end
    if state.overHealAbsorbGlow then state.overHealAbsorbGlow:SetAlpha(0) end
    if state.calculator then state.calculator:ResetPredictedValues() end
end

local function setAtlas(texture, atlas, fallback, tiled)
    local available = true
    if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
        available = ok and info ~= nil
    end
    if available then
        local ok, result
        if tiled then
            ok, result = pcall(texture.SetAtlas, texture, atlas, false, nil, false, "REPEAT", "REPEAT")
        else
            ok, result = pcall(texture.SetAtlas, texture, atlas)
        end
        -- SetAtlas has no documented return value; nil is normal success.
        if ok and result ~= false then
            if type(texture.GetAtlas) == "function" then
                local readOK, currentAtlas = pcall(texture.GetAtlas, texture)
                if readOK and currentAtlas == atlas then return true end
            else
                return true
            end
        end
    end
    if fallback then
        local ok, result = pcall(texture.SetTexture, texture, fallback,
            tiled and "REPEAT" or "CLAMP", tiled and "REPEAT" or "CLAMP")
        return ok and result ~= false, true
    end
    return false
end

local function makePattern(bar, atlas, file)
    local texture
    local ok = pcall(function()
        texture = bar:CreateTexture(nil, "OVERLAY")
        if file then
            if texture:SetTexture(file, "REPEAT", "REPEAT") == false then error("Pattern texture unavailable") end
        elseif not setAtlas(texture, atlas, nil, true) then
            error("Pattern atlas unavailable")
        end
        texture:SetAllPoints(bar:GetStatusBarTexture())
        if type(texture.SetHorizTile) == "function" then texture:SetHorizTile(true) end
        if type(texture.SetVertTile) == "function" then texture:SetVertTile(true) end
    end)
    -- Optional pattern artwork must not disable native prediction on a client
    -- with a different atlas set; the underlying colored fill still works.
    if not ok then
        if texture then pcall(texture.SetAlpha, texture, 0) end
        return nil
    end
    return texture
end

local function makeBar(state, anchor, reverse, atlas, r, g, b)
    local bar = CreateFrame("StatusBar", nil, state.holder)
    state.bars[#state.bars + 1] = bar
    bar:EnableMouse(false)
    bar:SetFrameLevel(state.level)
    bar:SetSize(ns.Layout.barWidth, 12)
    bar:SetPoint(reverse and "RIGHT" or "LEFT", anchor, "RIGHT", 0, 0)
    bar:SetReverseFill(reverse)
    if atlas then
        local texture = bar:CreateTexture(nil, "ARTWORK")
        local _, fallback = setAtlas(texture, atlas, "Interface\\TargetingFrame\\UI-StatusBar", false)
        if fallback then
            if atlas == "raidframe-shield-fill" then r, g, b = 0.6, 0.82, 1
            else r, g, b = 0.55, 0.2, 0.65 end
        end
        bar:SetStatusBarTexture(texture)
    else
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    bar:SetStatusBarColor(r, g, b, 0.85)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function makeGlow(state, health, atlas, right)
    local glow = state.glowHolder:CreateTexture(nil, "OVERLAY")
    if type(glow.SetAlphaFromBoolean) ~= "function" then
        error("Native conditional alpha is unavailable")
    end
    local fallback = right and "Interface\\RaidFrame\\Shield-Overshield" or "Interface\\RaidFrame\\Absorb-Overabsorb"
    setAtlas(glow, atlas, fallback, false)
    glow:SetBlendMode("ADD")
    glow:SetWidth(16)
    if right then
        glow:SetPoint("TOPLEFT", health, "TOPRIGHT", -7, 0)
        glow:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", -7, 0)
    else
        glow:SetPoint("TOPRIGHT", health, "TOPLEFT", 7, 0)
        glow:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", 7, 0)
    end
    glow:SetAlpha(0)
    return glow
end

local function initialize(card, state)
    if type(CreateUnitHealPredictionCalculator) ~= "function"
        or type(UnitGetDetailedHealPrediction) ~= "function" then
        error("Native prediction API is unavailable")
    end
    local calc = CreateUnitHealPredictionCalculator()
    for _, method in ipairs(REQUIRED) do
        if type(calc[method]) ~= "function" then error("Native prediction calculator is incomplete") end
    end
    state.calculator = calc
    calc:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
    calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
    calc:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.CurrentHealth)
    calc:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.ReducedByIncomingHeals)
    calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
    calc:SetIncomingHealOverflowPercent(1)

    -- Construct once, outside combat. Fill-to-fill anchors track native changes
    -- without fetching secret-dependent geometry or moving protected frames.
    local health = card.health
    state.level = health:GetFrameLevel() + 1
    local holder = CreateFrame("Frame", nil, health)
    state.holder = holder
    holder:SetAllPoints(health)
    holder:SetFrameLevel(state.level)
    holder:EnableMouse(false)
    holder:SetClipsChildren(true)
    holder:SetAlpha(0)
    local healthFill = health:GetStatusBarTexture()
    state.myHeal = makeBar(state, healthFill, false, nil, 0.0, 1.0, 0.5)
    state.otherHeal = makeBar(state, state.myHeal:GetStatusBarTexture(), false, nil, 0.0, 0.65, 0.35)
    state.damageAbsorb = makeBar(state, state.otherHeal:GetStatusBarTexture(), false, "raidframe-shield-fill", 1, 1, 1)
    state.healAbsorb = makeBar(state, healthFill, true, "raidframe-absorb-fill", 1, 1, 1)
    state.damageAbsorbOverlay = makePattern(state.damageAbsorb, nil, "Interface\\RaidFrame\\Shield-Overlay")
    state.healAbsorbOverlay = makePattern(state.healAbsorb, "RaidFrame-Absorb-Overlay")

    -- Overflow glows sit outside the clipped interior. They remain below the
    -- existing health numbers and silver trim (which occupy health level + 2).
    local glowHolder = CreateFrame("Frame", nil, health)
    state.glowHolder = glowHolder
    glowHolder:SetAllPoints(health)
    glowHolder:SetFrameLevel(state.level)
    glowHolder:EnableMouse(false)
    glowHolder:SetAlpha(0)
    state.overAbsorbGlow = makeGlow(state, health, "RaidFrame-Shield-Overshield", true)
    state.overHealAbsorbGlow = makeGlow(state, health, "RaidFrame-Absorb-Overabsorb", false)
end

function Prediction:Create(card)
    if card.healthPrediction then return card.healthPrediction.supported end
    local state = {supported=false, reason="Native prediction API is unavailable", bars={}}
    card.healthPrediction = state
    if InCombatLockdown and InCombatLockdown() then
        state.reason = "Native prediction setup requires leaving combat"
        return false
    end
    local ok, err = pcall(initialize, card, state)
    state.supported = ok
    if ok then state.reason = nil else
        state.reason = setupReason(err)
        pcall(clear, state)
    end
    return ok
end

local function render(state)
    local calc = state.calculator
    local maximum = calc:GetMaximumHealth()
    local _, myHeal, otherHeal = calc:GetIncomingHeals()
    local damageAbsorb, overAbsorb = calc:GetDamageAbsorbs()
    local healAbsorb, overHealAbsorb = calc:GetHealAbsorbs()
    for _, bar in ipairs(state.bars) do bar:SetMinMaxValues(0, maximum) end
    state.myHeal:SetValue(myHeal)
    state.otherHeal:SetValue(otherHeal)
    state.damageAbsorb:SetValue(damageAbsorb)
    state.healAbsorb:SetValue(healAbsorb)
    state.overAbsorbGlow:SetAlphaFromBoolean(overAbsorb, 1, 0)
    state.overHealAbsorbGlow:SetAlphaFromBoolean(overHealAbsorb, 1, 0)
    state.holder:SetAlpha(1)
    state.glowHolder:SetAlpha(1)
end

local function update(state, unit)
    UnitGetDetailedHealPrediction(unit, "player", state.calculator)
    render(state)
end

function Prediction:Update(card, unit)
    local state = card.healthPrediction
    if not state or not state.supported then return false end
    if isSecret(unit) then self:Clear(card); return false end
    if unit == nil then self:Clear(card); return true end
    if type(unit) ~= "string" or not unit:match("^party[1-4]$") then
        self:Clear(card)
        return false
    end
    if type(UnitExists) == "function" then
        local exists = UnitExists(unit)
        if isSecret(exists) or not exists then self:Clear(card); return false end
    end
    local ok = pcall(update, state, unit)
    if ok then
        state.unit = unit
        state.reason = nil
    else
        pcall(clear, state)
        state.reason = "Native prediction update failed"
    end
    return ok
end

local function preview(state, values)
    state.calculator:SetPredictedValues(values)
    render(state)
end

function Prediction:Preview(card, values)
    local state = card.healthPrediction
    if not state or not state.supported then return false end
    state.unit = nil
    local ok = pcall(preview, state, values)
    if ok then state.reason = nil else
        pcall(clear, state)
        state.reason = "Native prediction preview failed"
    end
    return ok
end

function Prediction:Clear(card)
    local state = card.healthPrediction
    if not state then return end
    pcall(clear, state)
end
