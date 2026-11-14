local _, ns = ...
local Hover = {}
ns.HoverPrediction = Hover

local HEIGHT, TOP_GAP = 2, 5
local function secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function amount(value)
    if secret(value) or type(value) ~= "number" then return 0 end
    if value ~= value or value == math.huge or value < 0 then return 0 end
    return value
end

local function makeBar(state, anchor, point, offset, r, g, b)
    local bar = CreateFrame("StatusBar", nil, state.holder)
    state.bars[#state.bars + 1] = bar
    bar:EnableMouse(false)
    bar:SetFrameLevel(state.level)
    bar:SetSize(ns.Layout.barWidth, HEIGHT)
    bar:SetPoint("BOTTOMLEFT", anchor, point, 0, offset)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(r, g, b, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

function Hover:Clear(card)
    local state = card and card.hoverPrediction
    if not state then return end
    state.button, state.unit, state.estimate = nil, nil, nil
    if state.holder then state.holder:SetAlpha(0) end
    for _, bar in ipairs(state.bars) do bar:SetValue(0) end
end

function Hover:Create(card)
    if card.hoverPrediction then return card.hoverPrediction.supported end
    -- Do not cache a failure here: a later out-of-combat setup may retry.
    if InCombatLockdown and InCombatLockdown() then return false end
    local state = {bars={}, supported=false}
    card.hoverPrediction = state
    local ok = pcall(function()
        local health = card.health
        state.level = health:GetFrameLevel() + 3
        local holder = CreateFrame("Frame", nil, health)
        state.holder = holder
        holder:EnableMouse(false)
        holder:SetFrameLevel(state.level)
        holder:SetSize(ns.Layout.barWidth, HEIGHT)
        holder:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, TOP_GAP)
        holder:SetClipsChildren(true)
        holder:SetAlpha(0)
        -- Native fill anchors track protected current health. No geometry is
        -- read back, and no target health arithmetic occurs in addon code.
        state.direct = makeBar(state, health:GetStatusBarTexture(), "TOPRIGHT", TOP_GAP, 0.15, 1, 0.42)
        state.hot = makeBar(state, state.direct:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0.15, 0.72, 0.35)
        state.absorb = makeBar(state, holder, "BOTTOMLEFT", 0, 0.64, 0.85, 1)

        -- Fixed public spacing, clipped by the native HoT fill. The gaps do
        -- not require inspecting or calculating that fill's protected width.
        local hotClip = CreateFrame("Frame", nil, state.hot)
        state.hotClip = hotClip
        hotClip:EnableMouse(false)
        hotClip:SetAllPoints(state.hot:GetStatusBarTexture())
        hotClip:SetFrameLevel(state.level + 1)
        hotClip:SetClipsChildren(true)
        for x = 4, ns.Layout.barWidth, 6 do
            local gap = CreateFrame("Frame", nil, hotClip)
            gap:EnableMouse(false)
            gap:SetSize(2, HEIGHT)
            gap:SetPoint("BOTTOMLEFT", state.hot, "BOTTOMLEFT", x, 0)
            local texture = gap:CreateTexture(nil, "OVERLAY")
            texture:SetAllPoints(gap)
            texture:SetColorTexture(0.03, 0.1, 0.04, 1)
        end
        local pattern = state.absorb:CreateTexture(nil, "OVERLAY")
        pattern:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
        pattern:SetAllPoints(state.absorb:GetStatusBarTexture())
        if pattern.SetHorizTile then pattern:SetHorizTile(true) end
        if pattern.SetVertTile then pattern:SetVertTile(true) end
        state.absorbPattern = pattern
    end)
    state.supported = ok
    if not ok then self:Clear(card) end
    return ok
end

function Hover:Show(button, unit, previewMax)
    local card = button and button.card
    local state = card and card.hoverPrediction
    if not state or not state.supported then return false end
    self:Clear(card)
    if secret(button.spellID) or type(button.spellID) ~= "number" then return false end
    if not ns.SpellEstimates or type(ns.SpellEstimates.Get) ~= "function" then return false end
    local ok = pcall(function()
        local estimate = ns.SpellEstimates:Get(button.spellID)
        if secret(estimate) or type(estimate) ~= "table" then return end
        local direct, hot, absorb = amount(estimate.direct), amount(estimate.hot), amount(estimate.absorb)
        if direct + hot + absorb == 0 then return end
        local maximum
        if previewMax ~= nil then
            maximum = amount(previewMax)
            if maximum == 0 then return end
        else
            if secret(unit) or type(unit) ~= "string" or not unit:match("^party[1-4]$") then return end
            local exists = UnitExists(unit)
            if secret(exists) or not exists then return end
            local connected = UnitIsConnected and UnitIsConnected(unit)
            local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
            -- Only known public status suppresses the preview. Protected status
            -- is not inspected and cannot turn off every combat preview.
            if not secret(connected) and connected == false then return end
            if not secret(dead) and dead == true then return end
            maximum = UnitHealthMax(unit)
            if not secret(maximum) and amount(maximum) == 0 then return end
        end
        -- Maximum health may be secret. Pass it straight to native setters;
        -- all values supplied by SpellEstimates are public spell data.
        for _, bar in ipairs(state.bars) do bar:SetMinMaxValues(0, maximum) end
        state.direct:SetValue(direct)
        state.hot:SetValue(hot)
        state.absorb:SetValue(absorb)
        state.holder:SetAlpha(1)
        state.button, state.unit, state.estimate = button, unit, estimate
    end)
    if not ok then self:Clear(card) end
    return ok and state.button ~= nil
end

Hover.Update = Hover.Show
