local _, ns = ...
local Menus = { prompts = {}, owners = {} }
ns.PresetMenus = Menus

local function result(ok, reason)
    if not ok and reason then ns.Print(reason) end
end

function Menus:Extend(_, root, context)
    if ns.IsSecret(context) or type(context) ~= "table" then return end
    local unit = context.unit
    if ns.IsSecret(unit) or type(unit) ~= "string" or not unit:match("^party[1-4]$") then return end
    if ns.IsSecret(context.ownerFrame) then return end
    local card = self.owners[context.ownerFrame]
    if not card then return end
    local key = ns.Assignments:Identity(unit)
    if not key or key ~= card.memberKey or not ns.Assignments.members[key] then return end
    root:CreateDivider()
    local submenu = root:CreateButton("Assign preset")
    submenu:SetScrollMode(240)
    submenu:SetEnabled(not ns.InCombat())
    for _, preset in ipairs(ns.Profiles:List()) do
        local id = preset.id
        local entry = submenu:CreateRadio(preset.name,
            function() return ns.Assignments:GetPreset(key) == id end,
            function()
                -- partyN can refer to someone else by the time this menu is
                -- clicked. Assign by captured identity, never by stale slot.
                result(ns.Assignments:Assign(key, id))
            end)
        entry:SetEnabled(not ns.InCombat())
    end
end

local function text(parent, value, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(value)
    return label
end

local function button(parent, title, x)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(108, 21)
    control:SetPoint("BOTTOMLEFT", x, 7)
    control:SetText(title)
    return control
end

function Menus:CreatePrompt(index, card)
    -- Independent of the secure card: it can disappear immediately in combat.
    local prompt = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    prompt:SetSize(248, 76)
    prompt:SetFrameStrata("DIALOG")
    prompt:SetClampedToScreen(true)
    prompt:SetPoint("TOPLEFT", card, "TOPRIGHT", 6, 0)
    ns.SetBackdrop(prompt, {0.035, 0.03, 0.025, 0.96}, {0.5, 0.43, 0.31, 1})
    prompt.title = text(prompt, "", 9, -7)
    prompt.title:SetWidth(230)
    prompt.title:SetHeight(41)
    prompt.title:SetWordWrap(true)
    prompt.confirm = button(prompt, "Confirm (10s)", 9)
    prompt.keep = button(prompt, "Keep Default", 131)
    prompt.confirm:SetScript("OnClick", function()
        result(ns.Assignments:Confirm(prompt.memberKey, prompt.presetID))
        self:RefreshPrompts()
    end)
    prompt.keep:SetScript("OnClick", function()
        ns.Assignments:KeepDefault(prompt.memberKey)
        self:RefreshPrompts()
    end)
    prompt:Hide()
    self.prompts[index] = prompt
    return prompt
end

function Menus:Initialize()
    for _, card in ipairs(ns.Frames.cards) do
        self.owners[card] = card
        for _, kind in ipairs({"heals", "buffs"}) do
            for _, control in ipairs(card[kind]) do self.owners[control] = card end
        end
    end
    if not self.registered and Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_UNIT_PARTY", function(...) self:Extend(...) end)
        self.registered = true
    end
    self:RefreshPrompts()
end

function Menus:RefreshPrompts()
    for index, card in ipairs(ns.Frames.cards) do
        local key = card.memberKey
        local member = key and ns.Assignments.members[key]
        local pending = member and member.pending
        local preset = pending and ns.Profiles:GetPreset(pending.presetID)
        local prompt = self.prompts[index]
        local currentUnit = card:GetAttribute("unit")
        local validUnit = not ns.IsSecret(currentUnit) and type(currentUnit) == "string"
            and ns.Assignments:Identity(currentUnit) == key
        if not ns.InCombat() and ns.worldActive ~= false and preset and card:IsVisible() and validUnit then
            if not prompt then prompt = self:CreatePrompt(index, card) end
            prompt.memberKey, prompt.presetID = key, pending.presetID
            prompt.title:SetText('Assign "' .. preset.name .. '" to ' .. member.name .. '?')
            prompt.confirm:SetText("Confirm (" .. math.ceil(pending.remaining) .. "s)")
            prompt:Show()
        elseif prompt then
            prompt.memberKey, prompt.presetID = nil, nil
            prompt:Hide()
        end
    end
end

function Menus:Update(elapsed)
    if ns.InCombat() or ns.worldActive == false then self:RefreshPrompts(); return end
    for _, prompt in pairs(self.prompts) do
        -- Only visible suggestions spend their ten-second confirmation window.
        if prompt:IsShown() and prompt.memberKey then ns.Assignments:Advance(prompt.memberKey, elapsed) end
    end
    self:RefreshPrompts()
end
