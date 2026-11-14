local _, ns = ...
local Settings = {}
ns.Settings = Settings
local QUADRANT_LABELS = { "Top left", "Top right", "Bottom left", "Bottom right" }
local WIDTH, BUFF_TOP, BUFF_ROW = 340, 232, 76

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
    ok, reason = ns.Profiles:SetSpell(self.classToken, slot.kind, slot.index, record and record.id or nil)
    if not ok then self.frame.note:SetText(reason); return false end
    if record then ClearCursor() end
    self:Refresh()
    return true
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
        local id = ns.Profiles:GetSpell(Settings.classToken, self.kind, self.index)
        if id then GameTooltip:SetSpellByID(id) else GameTooltip:SetText("Drag a spell here") end
        if self.kind == "heals" then
            GameTooltip:AddLine(QUADRANT_LABELS[self.index] .. " portrait quadrant", 1, 0.82, 0)
        end
        GameTooltip:AddLine("Drag a spell to assign its exact rank.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("Right-click to clear. Changes save immediately.", 0.85, 0.85, 0.85, true)
        if ns.InCombat() then GameTooltip:AddLine("Locked during combat.", 1, 0.3, 0.3) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function Settings:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "WowfPartyFramesSettings", UIParent, "BackdropTemplate")
    self.frame = frame
    self.classToken = ns.CLASSES[1].token
    frame:SetSize(WIDTH, 330)
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
    label(frame, "Party-member class", 17, -53, "GameFontHighlightSmall")
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
    menu:SetSize(154, #ns.CLASSES * 23 + 12)
    menu:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
    menu:SetFrameLevel(frame:GetFrameLevel() + 10)
    ns.SetBackdrop(menu, { 0.075, 0.065, 0.045, 1 }, { 0.65, 0.51, 0.27, 1 })
    frame.classOptions = {}
    for index, class in ipairs(ns.CLASSES) do
        local token, name = class.token, class.name
        local option = CreateFrame("Button", nil, menu)
        option:SetSize(140, 23)
        option:SetPoint("TOPLEFT", 7, -6 - (index - 1) * 23)
        option:SetNormalFontObject("GameFontHighlight")
        option:SetText(name)
        local text = option:GetFontString()
        text:ClearAllPoints()
        text:SetPoint("LEFT", 20, 0)
        text:SetWidth(116)
        text:SetJustifyH("LEFT")
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        option.check = option:CreateTexture(nil, "ARTWORK")
        option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        option.check:SetSize(18, 18)
        option.check:SetPoint("LEFT", 0, 0)
        frame.classOptions[token] = option
        option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if color then option:GetFontString():SetTextColor(color.r, color.g, color.b) end
        option:SetScript("OnClick", function()
            Settings.classToken = token
            menu:Hide()
            paintSelector()
            Settings:Refresh()
        end)
    end
    menu:Hide()
    menu:SetScript("OnHide", function() paintSelector() end)
    selector:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()); paintSelector() end)
    paintSelector()
    frame:SetScript("OnHide", function() menu:Hide(); GameTooltip:Hide() end)

    label(frame, "Healing abilities", 17, -80, "GameFontNormal")
    self.healSlots, self.buffSlots = {}, {}
    for index = 1, 4 do
        local x = 17 + ((index - 1) % 2) * 157
        local y = -103 - math.floor((index - 1) / 2) * 52
        self.healSlots[index] = createSlot(frame, "heals", index, x, y, 149)
    end
    label(frame, "Buffs", 17, -210, "GameFontNormal")
    for index = 1, ns.MAX_BUFFS do
        self.buffSlots[index] = createSlot(frame, "buffs", index, 17, -BUFF_TOP, 72)
    end
    frame.note = label(frame, "", 17, -304, "GameFontHighlightSmall")
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
    for _, class in ipairs(ns.CLASSES) do
        if class.token == self.classToken then
            frame.selector.title:SetText(class.name)
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class.token]
            if color then frame.selector.title:SetTextColor(color.r, color.g, color.b)
            else frame.selector.title:SetTextColor(1, 0.82, 0) end
        end
        frame.classOptions[class.token].check:SetShown(class.token == self.classToken)
    end
    local locked = ns.InCombat()
    local function paint(slot)
        local id = ns.Profiles:GetSpell(self.classToken, slot.kind, slot.index)
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
        local configured = ns.Profiles:GetSpell(self.classToken, "buffs", index) ~= nil
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
    frame:SetHeight(330 + (rows - 1) * BUFF_ROW)
    frame.note:ClearAllPoints()
    frame.note:SetPoint("TOPLEFT", 17, -304 - (rows - 1) * BUFF_ROW)
    frame.note:SetText(locked and "Assignments are locked during combat."
        or "Drag spells here. Ranks are saved. Right-click to clear.")
end

function Settings:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide() else self:Refresh(); frame:Show() end
end
