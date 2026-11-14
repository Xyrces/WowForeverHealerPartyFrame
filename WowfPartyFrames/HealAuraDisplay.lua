local _, ns = ...
local Display = {}
ns.HealAuraDisplay = Display
local LAYERS = { "base", "shift", "ctrl", "ctrlshift" }

-- Each fixed native slot independently matches a helpful aura. Blizzard owns
-- its visibility and duration, including in combat; addon code never reads it.
local function initializeIndicator(button, target)
    button:SetAllPoints(target)
    button:SetFrameLevel(target:GetFrameLevel() + 10)
    button:SetMouseClickEnabled(false)
    button:EnableMouse(false)
    -- A small top edge avoids masking either the spell icon or its rank.
    local edge = button:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(0.25, 1, 0.38, 0.95)
    edge:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    edge:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    edge:SetHeight(2)
    local check = button:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetVertexColor(0.35, 1, 0.45)
    check:SetSize(12, 12)
    check:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -2)
    local duration = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    duration:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    duration:SetPoint("CENTER", button, "CENTER", 0, 0)
    duration:SetJustifyH("CENTER")
    duration:SetTextColor(0.65, 1, 0.65)
    -- Default native duration formatter handles seconds/minutes and expiry.
    -- No icon is registered: the assigned exact-rank icon remains underneath.
    button:SetDurationText(duration)
end

local function conceal(state)
    for _, view in ipairs(state.views) do view.holder:SetAlpha(0) end
end

local function disable(state)
    conceal(state)
    local success = true
    for _, view in ipairs(state.views) do
        if view.container and type(view.container.SetEnabled) == "function" then
            if not pcall(view.container.SetEnabled, view.container, false) then success = false end
        end
    end
    state.unit = nil
    return success
end

local function reveal(state)
    for _, view in ipairs(state.views) do
        view.holder:SetAlpha(state.unit and state.configured and state.visible
            and state.layer == view.layer and 1 or 0)
    end
end

function Display:Create(card)
    if card.healAuraDisplay then return card.healAuraDisplay.supported end
    if ns.InCombat() then return false end
    local state = { views = {}, supported = false, layer = "base", visible = false }
    card.healAuraDisplay = state
    if not C_AuraContainerUtil or type(C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions) ~= "function" then
        state.reason = "Native healing ability aura indicators are unavailable."
        return false
    end
    local ok, reason = pcall(function()
        for _, layer in ipairs(LAYERS) do
            local holder = CreateFrame("Frame", nil, card)
            holder:SetAllPoints(card)
            holder:EnableMouse(false)
            holder:SetAlpha(0)
            local view = { holder = holder, layer = layer }
            state.views[#state.views + 1] = view
            local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
            view.container = container
            for _, method in ipairs({ "SetEnabled", "SetUnit", "AddAuraSlot",
                "SetAuraSlotCandidateFilters", "SetAuraSlotEnabled" }) do
                assert(type(container[method]) == "function", "Native aura method unavailable: " .. method)
            end
            container:SetEnabled(false)
            container:EnableMouse(false)
            container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            for index = 1, 4 do
                local target = assert(card.heals[index], "Healing control is not ready")
                local key = "heal" .. index
                container:AddAuraSlot(key, "HELPFUL", {
                    candidateFilters = { includeSpellIDs = {} },
                    initializeFrame = function(button) initializeIndicator(button, target) end,
                })
                container:SetAuraSlotEnabled(key, false)
            end
        end
    end)
    if not ok then
        disable(state)
        state.reason = "Native healing aura setup failed: " .. tostring(reason)
        return false
    end
    state.supported = true
    return true
end

function Display:Configure(card)
    local state = card.healAuraDisplay
    if not state or not state.supported or ns.InCombat() then return false end
    conceal(state)
    state.configured = false
    local ok, reason = pcall(function()
        for _, view in ipairs(state.views) do
            for index = 1, 4 do
                local button = card.heals[index]
                local id = button.layerSpells and button.layerSpells[view.layer]
                local key = "heal" .. index
                local ids = id and ns.Spells:GetAuraSpellIDs(id) or {}
                view.container:SetAuraSlotEnabled(key, false)
                view.container:SetAuraSlotCandidateFilters(key, { includeSpellIDs = ids })
                view.container:SetAuraSlotEnabled(key, id ~= nil)
            end
        end
    end)
    if not ok then
        disable(state)
        state.reason = "Native healing aura configuration failed: " .. tostring(reason)
        return false
    end
    state.configured = true
    reveal(state)
    return true
end

function Display:Update(card, unit)
    local state = card.healAuraDisplay
    if not state or not state.supported or not state.configured then return false end
    if ns.IsSecret(unit) or type(unit) ~= "string" or not unit:match("^party[1-4]$") then
        disable(state)
        return false
    end
    local exists = UnitExists(unit)
    if ns.IsSecret(exists) or not exists then disable(state); return false end
    if state.unit == unit then return true end
    if not disable(state) then
        state.reason = "Native healing aura display could not release its previous unit."
        return false
    end
    local ok, reason = pcall(function()
        for _, view in ipairs(state.views) do view.container:SetUnit(unit) end
        for _, view in ipairs(state.views) do view.container:SetEnabled(true) end
    end)
    if not ok then
        disable(state)
        state.reason = "Native healing aura display could not bind this member: " .. tostring(reason)
        return false
    end
    state.unit, state.reason = unit, nil
    reveal(state)
    return true
end

function Display:SetVisible(card, layer, show)
    local state = card.healAuraDisplay
    if not state or not state.supported then return end
    if ns.IsSecret(layer) or ns.IsSecret(show) then conceal(state); return end
    state.layer, state.visible = layer, show == true
    reveal(state)
end

function Display:Clear(card)
    local state = card.healAuraDisplay
    if state then disable(state) end
end
