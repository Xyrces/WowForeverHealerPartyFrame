local _, ns = ...
local Settings = { healLayer = "base" }
ns.Settings = Settings
local QUADRANT_LABELS = { "Top left", "Top right", "Bottom left", "Bottom right" }
local WIDTH, BUFF_TOP, BUFF_ROW = 340, 259, 76
local LAYERS = { {"base", "Base"}, {"shift", "Shift"}, {"ctrl", "Ctrl"}, {"ctrlshift", "Shift+Ctrl"} }
local LAYER_NAMES = { base = "Base", shift = "Shift", ctrl = "Ctrl", ctrlshift = "Shift+Ctrl" }

local function label(parent, text, x, y, template)
    local result = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    if result.SetFont then
        local size = template == "GameFontNormalLarge" and 16
            or template == "GameFontNormal" and 13 or 10
        result:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    end
    result:SetPoint("TOPLEFT", x, y)
    result:SetText(text)
    return result
end

function Settings:Assign(slot, clear)
    if ns.InCombat() then
        self.frame.note:SetText("Assignments are locked during combat.")
        return false
    end
    local record, reason
    if not clear then
        record, reason = ns.Spells:FromCursor()
        if not record then self.frame.note:SetText(reason); return false end
    end
    local ok
    ok, reason = ns.Profiles:SetSpell(self.presetID, slot.kind, slot.index, record and record.id or nil, slot.kind == "heals" and self.healLayer or nil)
    if not ok then self.frame.note:SetText(reason); return false end
    if record then ClearCursor() end
    self:Refresh()
    return true
end

function Settings:SelectHealLayer(layer)
    if not LAYER_NAMES[layer] then return false end
    self.healLayer = layer
    self:Refresh()
    if ns.Frames then ns.Frames:RefreshAll() end
    return true
end

function Settings:SetControlStyle(style)
    if style ~= "buttons" and style ~= "quadrants" then return false end
    if ns.InCombat() then
        if self.frame then self.frame.note:SetText("Change portrait controls after combat ends.") end
        return false
    end
    local db = ns.db or ns.Profiles.db
    if not db then return false end
    db.controlStyle = style
    if ns.Frames then ns.Frames:ApplyProfiles(); ns.Frames:RefreshAll() end
    self:Refresh()
    return true
end

local function choice(parent, text, width, click)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 22)
    ns.SetBackdrop(button, {0.035, 0.03, 0.025, 1}, {0.4, 0.35, 0.25, 1})
    button.title = label(button, text, 0, -6, "GameFontHighlightSmall")
    button.title:SetWidth(width)
    button.title:SetJustifyH("CENTER")
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button:SetScript("OnClick", click)
    return button
end

local function paintChoice(button, selected, locked)
    button.selected = selected
    button:SetBackdropBorderColor(selected and 0.9 or 0.4, selected and 0.72 or 0.35, selected and 0.38 or 0.25, 1)
    button.title:SetTextColor(1, selected and 0.82 or 1, selected and 0 or 1)
    button:SetAlpha(locked and 0.55 or 1)
end

local function createSlot(parent, kind, index, x, y, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local buff = kind == "buffs"
    button:SetSize(width, buff and 66 or 48)
    button:SetPoint("TOPLEFT", x, y)
    button.kind, button.index = kind, index
    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetSize(36, 36)
    border:SetPoint("TOPLEFT", buff and (width - 36) / 2 or 0, -2)
    border:SetColorTexture(0.58, 0.46, 0.26, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(32, 32)
    button.icon:SetPoint("CENTER", border, "CENTER")
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.title = label(button, "", buff and 0 or 43, buff and -41 or -5, "GameFontHighlightSmall")
    button.title:SetWidth(buff and width or width - 43)
    button.title:SetHeight(buff and 24 or 16)
    button.title:SetJustifyH(buff and "CENTER" or "LEFT")
    button.title:SetWordWrap(buff)
    button.rank = label(button, "", buff and 0 or 43, buff and -25 or -24, "GameFontNormalSmall")
    button.rank:SetWidth(buff and width or width - 43)
    button.rank:SetJustifyH(buff and "CENTER" or "LEFT")
    button.rank:SetWordWrap(false)
    button.rank:SetShadowColor(0, 0, 0, 1)
    button.rank:SetShadowOffset(1, -1)
    if buff then
        button.plus = label(button, "+", 0, -8, "GameFontNormalLarge")
        button.plus:SetWidth(width)
        button.plus:SetJustifyH("CENTER")
    end
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnReceiveDrag", function(self) Settings:Assign(self, false) end)
    button:SetScript("OnClick", function(self, mouseButton)
        Settings:Assign(self, mouseButton == "RightButton")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local id = ns.Profiles:GetSpell(Settings.presetID, self.kind, self.index, self.kind == "heals" and Settings.healLayer or nil)
        if id then GameTooltip:SetSpellByID(id) else GameTooltip:SetText("Drag a spell here") end
        if self.kind == "heals" then
            GameTooltip:AddLine(LAYER_NAMES[Settings.healLayer] .. " - " .. QUADRANT_LABELS[self.index], 1, 0.82, 0)
        end
        GameTooltip:AddLine("Drag a spell to assign its exact rank.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("Right-click to clear. Changes save immediately.", 0.85, 0.85, 0.85, true)
        if ns.InCombat() then GameTooltip:AddLine("Locked during combat.", 1, 0.3, 0.3) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function Settings:SelectPreset(id)
    if not ns.Profiles:GetPreset(id) then return false end
    self.presetID = id
    self.menuPage = nil
    if self.frame then self.frame.menu:Hide() end
    self:Refresh()
    if ns.Frames then
        ns.Frames:ApplyProfiles()
        ns.Frames:RefreshAll()
    end
    return true
end

function Settings:SavePresetAction(action, name, targetID)
    if ns.InCombat() then return false, "Presets are locked during combat." end
    targetID = targetID or self.presetID
    local result, reason
    if action == "new" or action == "duplicate" then
        result, reason = ns.Profiles:Create(name, action == "duplicate" and targetID or nil)
        if result then self:SelectPreset(result) end
    elseif action == "rename" then
        result, reason = ns.Profiles:Rename(targetID, name)
    elseif action == "delete" then
        result, reason = ns.Profiles:Delete(targetID)
        if result and self.presetID == targetID then self:SelectPreset("default") end
    else
        return false, "Unknown preset action."
    end
    if result then self:Refresh() end
    return result and true or false, reason
end

function Settings:PromptPresetAction(action)
    self.frame.menu:Hide()
    if ns.InCombat() then self.frame.note:SetText("Presets are locked during combat."); return end
    local dialog = self.dialog
    if not dialog then
        dialog = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        self.dialog = dialog
        dialog:SetSize(290, 144)
        dialog:SetPoint("CENTER")
        dialog:SetFrameLevel(self.frame:GetFrameLevel() + 25)
        dialog:EnableMouse(true)
        ns.SetBackdrop(dialog, { 0.075, 0.065, 0.045, 1 }, { 0.65, 0.51, 0.27, 1 })
        dialog.title = label(dialog, "", 14, -14, "GameFontNormal")
        dialog.title:SetWidth(262)
        dialog.title:SetWordWrap(true)
        dialog.input = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        dialog.input:SetSize(250, 24)
        dialog.input:SetPoint("TOPLEFT", 20, -43)
        dialog.input:SetAutoFocus(false)
        dialog.input:SetMaxLetters(32)
        dialog.note = label(dialog, "", 14, -74, "GameFontHighlightSmall")
        dialog.note:SetWidth(262)
        dialog.note:SetWordWrap(true)
        local accept = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        dialog.accept = accept
        accept:SetSize(100, 23)
        accept:SetPoint("BOTTOMRIGHT", -14, 12)
        local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancel:SetSize(100, 23)
        cancel:SetPoint("BOTTOMLEFT", 14, 12)
        cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function() dialog:Hide() end)
        local function save()
            local ok, reason = self:SavePresetAction(dialog.action, dialog.input:GetText(), dialog.targetID)
            if ok then dialog:Hide() else dialog.note:SetText(reason or "Unable to save preset.") end
        end
        accept:SetScript("OnClick", save)
        dialog.input:SetScript("OnEnterPressed", save)
        dialog.input:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog:SetScript("OnHide", function() dialog.input:ClearFocus() end)
    end
    dialog.action, dialog.targetID = action, self.presetID
    local preset = ns.Profiles:GetPreset(self.presetID)
    local titles = { new = "New preset", duplicate = "Duplicate preset", rename = "Rename preset" }
    dialog.title:SetText(action == "delete" and ("Delete " .. preset.name .. "?") or titles[action])
    dialog.note:SetText(action == "delete" and "Members using it return to Default." or "Choose a short, unique name.")
    dialog.accept:SetText(action == "delete" and "Delete" or "Save")
    dialog.input:SetText(action == "rename" and preset.name or "")
    dialog.input:SetShown(action ~= "delete")
    dialog:Show()
    if action ~= "delete" then dialog.input:SetFocus(); dialog.input:HighlightText() end
end

function Settings:RefreshMenu()
    local frame = self.frame
    if not frame then return end
    local entries, presets = {}, ns.Profiles:List()
    local pages = math.max(1, math.ceil(#presets / 8))
    if not self.menuPage then
        self.menuPage = 1
        for index, preset in ipairs(presets) do
            if preset.id == self.presetID then self.menuPage = math.ceil(index / 8); break end
        end
    end
    self.menuPage = math.max(1, math.min(pages, self.menuPage))
    if self.menuPage > 1 then
        entries[#entries + 1] = { name = "Previous presets", page = self.menuPage - 1 }
    end
    for index = (self.menuPage - 1) * 8 + 1, math.min(#presets, self.menuPage * 8) do
        local preset = presets[index]
        entries[#entries + 1] = { name = preset.name, id = preset.id }
    end
    if self.menuPage < pages then
        entries[#entries + 1] = { name = "More presets...", page = self.menuPage + 1 }
    end
    entries[#entries + 1] = { name = "New preset...", action = "new" }
    entries[#entries + 1] = { name = "Duplicate preset...", action = "duplicate" }
    if self.presetID ~= "default" then
        entries[#entries + 1] = { name = "Rename preset...", action = "rename" }
        entries[#entries + 1] = { name = "Delete preset...", action = "delete" }
    end
    for _, option in ipairs(frame.presetOptions) do option:Hide() end
    for index, entry in ipairs(entries) do
        local option = frame.presetOptions[index]
        if not option then
            option = CreateFrame("Button", nil, frame.menu)
            option:SetSize(196, 23)
            option:SetPoint("TOPLEFT", 7, -6 - (index - 1) * 23)
            option:SetNormalFontObject("GameFontHighlight")
            -- A plain Button gets its font string on the first SetText call.
            option:SetText(entry.name)
            local text = option:GetFontString()
            text:ClearAllPoints()
            text:SetPoint("LEFT", 20, 0)
            text:SetWidth(170)
            text:SetJustifyH("LEFT")
            text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            option.check = option:CreateTexture(nil, "ARTWORK")
            option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            option.check:SetSize(18, 18)
            option.check:SetPoint("LEFT", 0, 0)
            option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            option:SetScript("OnClick", function(button)
                if button.entry.page then Settings.menuPage = button.entry.page; Settings:RefreshMenu()
                elseif button.entry.id then Settings:SelectPreset(button.entry.id)
                else Settings:PromptPresetAction(button.entry.action) end
            end)
            frame.presetOptions[index] = option
        end
        option.entry = entry
        option:SetText(entry.name)
        option.check:SetShown(entry.id == self.presetID)
        option:GetFontString():SetTextColor(1, entry.action and 0.82 or 1, entry.action and 0 or 1)
        option:Show()
    end
    frame.menu:SetHeight(#entries * 23 + 12)
end

function Settings:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "WowfPartyFramesSettings", UIParent, "BackdropTemplate")
    self.frame = frame
    self.presetID = self.presetID or "default"
    frame:SetSize(WIDTH, 389)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ns.SetBackdrop(frame, { 0.075, 0.065, 0.045, 0.98 }, { 0.65, 0.51, 0.27, 1 })
    label(frame, "Party Frame Settings", 17, -17, "GameFontNormalLarge")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)
    label(frame, "Preset", 17, -53, "GameFontHighlightSmall")
    local selector = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.selector = selector
    selector:SetSize(154, 24)
    selector:SetPoint("TOPRIGHT", -17, -46)
    ns.SetBackdrop(selector, { 0.035, 0.03, 0.025, 1 }, { 0.5, 0.43, 0.31, 1 })
    selector.title = label(selector, "", 10, -7, "GameFontHighlightSmall")
    selector.title:SetWidth(114)
    selector.title:SetHeight(12)
    selector.title:SetJustifyH("LEFT")
    selector.title:SetWordWrap(false)
    selector.arrow = selector:CreateTexture(nil, "ARTWORK")
    selector.arrow:SetSize(24, 24)
    selector.arrow:SetPoint("RIGHT", -2, 0)
    local function paintSelector(pressed)
        local open = frame.menu and frame.menu:IsShown()
        local direction = open and "Up" or "Down"
        selector.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. direction
            .. (pressed and "-Down" or "-Up"))
        local lit = open or selector.hovered
        selector:SetBackdropBorderColor(lit and 0.9 or 0.5, lit and 0.72 or 0.43, lit and 0.38 or 0.31, 1)
        selector:SetBackdropColor(pressed and 0.015 or 0.035, pressed and 0.012 or 0.03, 0.025, 1)
    end
    selector:SetScript("OnEnter", function() selector.hovered = true; paintSelector() end)
    selector:SetScript("OnLeave", function() selector.hovered = false; paintSelector() end)
    selector:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then paintSelector(true) end end)
    selector:SetScript("OnMouseUp", function() paintSelector() end)
    local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.menu = menu
    menu:SetSize(210, 120)
    menu:SetPoint("TOPRIGHT", selector, "BOTTOMRIGHT", 0, -2)
    menu:SetFrameLevel(frame:GetFrameLevel() + 10)
    ns.SetBackdrop(menu, { 0.075, 0.065, 0.045, 1 }, { 0.65, 0.51, 0.27, 1 })
    frame.presetOptions = {}
    menu:Hide()
    menu:SetScript("OnHide", function() paintSelector() end)
    selector:SetScript("OnClick", function()
        local opening = not menu:IsShown()
        if opening then self.menuPage = nil end
        self:RefreshMenu()
        menu:SetShown(opening)
        paintSelector()
    end)
    paintSelector()
    frame:SetScript("OnHide", function() menu:Hide(); if self.dialog then self.dialog:Hide() end; GameTooltip:Hide() end)

    label(frame, "Healing abilities", 17, -80, "GameFontNormal")
    frame.layerTabs = {}
    for index, layer in ipairs(LAYERS) do
        local id = layer[1]
        local tab = choice(frame, layer[2], 74, function() Settings:SelectHealLayer(id) end)
        tab:SetPoint("TOPLEFT", 17 + (index - 1) * 78, -100)
        frame.layerTabs[id] = tab
    end
    self.healSlots, self.buffSlots = {}, {}
    for index = 1, 4 do
        local x = 17 + ((index - 1) % 2) * 157
        local y = -130 - math.floor((index - 1) / 2) * 52
        self.healSlots[index] = createSlot(frame, "heals", index, x, y, 149)
    end
    label(frame, "Buffs", 17, -237, "GameFontNormal")
    for index = 1, ns.MAX_BUFFS do
        self.buffSlots[index] = createSlot(frame, "buffs", index, 17, -BUFF_TOP, 72)
    end
    frame.styleLabel = label(frame, "Portrait controls", 17, -337, "GameFontHighlightSmall")
    frame.styleButtons = {}
    for index, style in ipairs({ {"buttons", "Buttons"}, {"quadrants", "Quadrants"} }) do
        local id = style[1]
        local control = choice(frame, style[2], 90, function() Settings:SetControlStyle(id) end)
        control:SetPoint("TOPLEFT", 132 + (index - 1) * 96, -331)
        control:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(id == "buttons" and "Four full square spell buttons on hover." or "Four sections inside the circular portrait.")
            if ns.InCombat() then GameTooltip:AddLine("Change after combat ends.", 1, 0.3, 0.3) end
            GameTooltip:Show()
        end)
        control:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.styleButtons[id] = control
    end
    frame.note = label(frame, "", 17, -363, "GameFontHighlightSmall")
    frame.note:SetWidth(WIDTH - 34)
    frame.note:SetJustifyH("LEFT")
    frame.note:SetWordWrap(true)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("SPELL_TEXT_UPDATE")
    frame:SetScript("OnEvent", function() Settings:Refresh() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WowfPartyFramesSettings") end
    frame:Hide()
    self:Refresh()
    return frame
end

function Settings:Refresh()
    local frame = self.frame
    if not frame then return end
    if not ns.Profiles:GetPreset(self.presetID) then self.presetID = "default" end
    frame.selector.title:SetText(ns.Profiles:GetPreset(self.presetID).name)
    frame.selector.title:SetTextColor(1, 0.82, 0)
    self:RefreshMenu()
    local locked = ns.InCombat()
    for id, tab in pairs(frame.layerTabs) do paintChoice(tab, id == self.healLayer, false) end
    local db = ns.db or ns.Profiles.db
    local style = db and db.controlStyle or "buttons"
    for id, control in pairs(frame.styleButtons) do paintChoice(control, id == style, locked) end
    local function paint(slot)
        local id = ns.Profiles:GetSpell(self.presetID, slot.kind, slot.index, slot.kind == "heals" and self.healLayer or nil)
        local spell = ns.Spells:Get(id)
        slot.icon:SetTexture(spell and spell.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        slot.icon:SetDesaturated(locked)
        slot:SetAlpha(locked and 0.55 or 1)
        slot.title:SetText(spell and spell.name or (id and ("Spell #" .. id)
            or (slot.kind == "buffs" and "Add buff" or "Drop spell")))
        local rank = spell and spell.rank or ""
        if slot.kind == "heals" then
            slot.rank:SetText(rank ~= "" and rank or QUADRANT_LABELS[slot.index])
        else
            slot.rank:SetText(rank:match("%d+") or "")
            slot.plus:SetText(id and "" or "+")
        end
    end
    for _, slot in ipairs(self.healSlots) do paint(slot) end
    local firstEmpty, visible = nil, {}
    for index, slot in ipairs(self.buffSlots) do
        local configured = ns.Profiles:GetSpell(self.presetID, "buffs", index) ~= nil
        if not configured and not firstEmpty then firstEmpty = index end
        if configured then visible[#visible + 1] = slot else slot:Hide() end
        paint(slot)
    end
    if firstEmpty then visible[#visible + 1] = self.buffSlots[firstEmpty] end
    -- Display order is compact, while each button retains its saved slot index.
    for position, slot in ipairs(visible) do
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", 17 + ((position - 1) % 4) * 78,
            -BUFF_TOP - math.floor((position - 1) / 4) * BUFF_ROW)
        slot:Show()
    end
    local rows = math.max(1, math.ceil(#visible / 4))
    frame:SetHeight(389 + (rows - 1) * BUFF_ROW)
    frame.styleLabel:ClearAllPoints()
    frame.styleLabel:SetPoint("TOPLEFT", 17, -337 - (rows - 1) * BUFF_ROW)
    for index, id in ipairs({"buttons", "quadrants"}) do
        local control = frame.styleButtons[id]
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", 132 + (index - 1) * 96, -331 - (rows - 1) * BUFF_ROW)
    end
    frame.note:ClearAllPoints()
    frame.note:SetPoint("TOPLEFT", 17, -363 - (rows - 1) * BUFF_ROW)
    frame.note:SetText(locked and "Assignments are locked during combat."
        or "Drag spells here. Ranks are saved. Right-click to clear.")
end

function Settings:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide() else self:Refresh(); frame:Show() end
end
