local _, ns = ...
local Display = {}
ns.AuraDisplay = Display
local COUNT = 8

-- CustomAuraContainerTemplate owns aura data, filtering, visibility and timers
-- in Blizzard's secure environment. Addon code supplies presentation only.
local function initializeIcon(button, clickThrough)
    local size = ns.Layout.auraSize
    button:SetSize(size, size)
    -- Unassigned aura icons retain native hover details, while clicks reach
    -- the member frame beneath them for targeting and the context menu.
    button:SetMouseClickEnabled(false)
    if clickThrough then button:EnableMouse(false) end
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:EnableMouse(false)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    overlay:EnableMouse(false)
    local function text(point, y, alignment, fontSize)
        local region = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        region:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        region:SetPoint(point, overlay, point, 0, y)
        region:SetWidth(size)
        region:SetJustifyH(alignment)
        return region
    end
    local duration = text("BOTTOM", -1, "CENTER", 7)
    local count = text("TOP", 0, "RIGHT", 8)
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetDurationText(duration)
    button:SetApplicationCount(count)
end

local function disable(state)
    local success = true
    for _, view in ipairs(state.views) do
        -- These holders have no secure actions and never expose aura state.
        view.holder:Hide()
        if view.container and type(view.container.SetEnabled) == "function" then
            if not pcall(view.container.SetEnabled, view.container, false) then success = false end
        end
    end
    state.unit = nil
    return success
end

function Display:Create(card)
    if card.auraDisplay then return card.auraDisplay.supported end
    if ns.InCombat() then return false end
    local state = { views = {}, supported = false }
    card.auraDisplay = state
    if not C_AuraContainerUtil or type(C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions) ~= "function" then
        state.reason = "Native aura containers are unavailable on this client."
        return false
    end
    local L = ns.Layout
    local width = L.auraSize + (COUNT - 1) * L.auraPitch
    local ok, reason = pcall(function()
        for index, filter in ipairs({ "HARMFUL", "HELPFUL", "HELPFUL" }) do
            local holder = CreateFrame("Frame", nil, card)
            holder:EnableMouse(false)
            if index ~= 2 then
                holder:SetSize(width, L.auraSize)
                holder:SetPoint("TOPLEFT", card, "TOPLEFT", L.auraX, index == 1 and L.debuffY or L.buffY)
            else
                holder:SetAllPoints(card)
            end
            holder:Hide()
            local view = { holder = holder }
            state.views[#state.views + 1] = view
            local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
            view.container = container
            for _, method in ipairs({"SetEnabled", "SetUnit", "AddAuraGroup", "AddAuraSlot",
                "SetAuraSlotCandidateFilters", "SetAuraSlotEnabled", "SetFlowLayoutMaximumLineSize",
                "SetAuraGroupMaxFrameCount", "SetAuraGroupCandidateFilters"}) do
                assert(type(container[method]) == "function", "Native aura container method unavailable: " .. method)
            end
            container:SetEnabled(false)
            container:EnableMouse(false)
            container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            if index ~= 2 then
                container:SetFlowLayoutMaximumLineSize(width)
                container:AddAuraGroup("auras", filter, {
                    maxFrameCount = index == 1 and COUNT or 0,
                    initializeFrame = initializeIcon,
                    layout = { elementWidth = L.auraSize, elementHeight = L.auraSize,
                        elementSpacing = L.auraPitch - L.auraSize, lineSpacing = 0 },
                })
            else
                for slot = 1, ns.MAX_BUFFS do
                    local target = assert(card.buffs[slot], "Buff control is not ready")
                    local key = "buff" .. slot
                    container:AddAuraSlot(key, filter, {
                        candidateFilters = { includeSpellIDs = {} },
                        initializeFrame = function(button)
                            -- Presentation is initialized once, before native access
                            -- restrictions apply. No aura frame is inspected later.
                            button:SetFrameLevel(target:GetFrameLevel() + 10)
                            initializeIcon(button, true)
                            button:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
                        end,
                    })
                    container:SetAuraSlotEnabled(key, false)
                end
            end
        end
        state.buffsConfigured = false
    end)
    if not ok then
        disable(state)
        state.reason = "Native aura display setup failed: " .. tostring(reason)
        return false
    end
    state.supported = true
    return true
end

function Display:ConfigureBuffs(card)
    local state = card.auraDisplay
    if not state or not state.supported or ns.InCombat() then return false end
    local container = state.views[2].container
    -- Reconfiguration can momentarily clear a native assignment. Keep the
    -- entire layer hidden until every slot has its new recipient-preset filter.
    state.views[2].holder:Hide()
    state.views[3].holder:Hide()
    local ok, reason = pcall(function()
        local excluded, last = {}, 0
        for index, button in ipairs(card.buffs) do
            local key, id = "buff" .. index, button.spellID
            local ids = id and ns.Spells:GetAuraSpellIDs(id) or {}
            if id then
                last = index
                for auraID in pairs(ids) do excluded[auraID] = true end
            end
            container:SetAuraSlotEnabled(key, false)
            container:SetAuraSlotCandidateFilters(key, { includeSpellIDs = ids })
            container:SetAuraSlotEnabled(key, id ~= nil)
        end
        local extras = state.views[3]
        extras.container:SetAuraGroupMaxFrameCount("auras", 0)
        extras.container:SetAuraGroupCandidateFilters("auras", next(excluded) and { excludeSpellIDs = excluded } or nil)
        extras.holder:ClearAllPoints()
        extras.holder:SetPoint("TOPLEFT", card, "TOPLEFT",
            ns.Layout.auraX + last * ns.Layout.auraPitch, ns.Layout.buffY)
        extras.container:SetAuraGroupMaxFrameCount("auras", math.max(0, COUNT - last))
    end)
    state.buffsConfigured = ok
    if not ok then
        disable(state)
        state.reason = "Native buff display setup failed: " .. tostring(reason)
        return false
    end
    if state.unit then
        state.views[2].holder:Show()
        state.views[3].holder:Show()
    end
    return true
end

function Display:Update(card, unit)
    local state = card.auraDisplay
    if not state or not state.supported or not state.buffsConfigured then return false end
    if ns.IsSecret(unit) or type(unit) ~= "string" or not unit:match("^party[1-4]$") then
        disable(state)
        return false
    end
    if state.unit == unit then return true end
    -- Hide and disable all old views before touching any unit binding.
    -- Never show a mixture of old/new recipients after a partial failure.
    if not disable(state) then
        state.reason = "Native aura display could not release its previous unit."
        return false
    end
    local ok, reason = pcall(function()
        for _, view in ipairs(state.views) do view.container:SetUnit(unit) end
        for _, view in ipairs(state.views) do view.container:SetEnabled(true) end
    end)
    if not ok then
        disable(state)
        state.reason = "Native aura display could not bind this member: " .. tostring(reason)
        return false
    end
    state.unit, state.reason = unit, nil
    for _, view in ipairs(state.views) do view.holder:Show() end
    return true
end
