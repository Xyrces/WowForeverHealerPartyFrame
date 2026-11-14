local _, ns = ...
local Settings = {}
ns.Settings = Settings
local QUADRANT_LABELS = { "Top left", "Top right", "Bottom left", "Bottom right" }

local function label(parent, text, x, y, template)
    local result = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
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
    button:SetSize(width, 48)
    button:SetPoint("TOPLEFT", x, y)
    button.kind, button.index = kind, index
    ns.SetBackdrop(button, { 0.06, 0.05, 0.035, 0.95 }, { 0.45, 0.37, 0.23, 1 })
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(32, 32)
    button.icon:SetPoint("LEFT", 7, 0)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.title = label(button, "", 46, -7, "GameFontHighlightSmall")
    button.title:SetWidth(width - 52)
    button.title:SetJustifyH("LEFT")
    button.title:SetWordWrap(false)
    button.rank = label(button, "", 46, -27, "GameFontNormalSmall")
    button.rank:SetWidth(width - 52)
    button.rank:SetJustifyH("LEFT")
    button.rank:SetWordWrap(false)
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
    frame:SetSize(490, 570)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ns.SetBackdrop(frame, { 0.075, 0.065, 0.045, 0.98 }, { 0.65, 0.51, 0.27, 1 })
    label(frame, "WoW Forever Party Frames", 22, -22, "GameFontNormalLarge")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)
    label(frame, "Party-member class", 22, -61)
    local selector = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.selector = selector
    selector:SetSize(215, 26)
    selector:SetPoint("TOPRIGHT", -22, -54)
    local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.menu = menu
    menu:SetSize(215, #ns.CLASSES * 25 + 12)
    menu:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
    menu:SetFrameLevel(frame:GetFrameLevel() + 10)
    ns.SetBackdrop(menu, { 0.075, 0.065, 0.045, 1 }, { 0.65, 0.51, 0.27, 1 })
    for index, class in ipairs(ns.CLASSES) do
        local token, name = class.token, class.name
        local option = CreateFrame("Button", nil, menu)
        option:SetSize(201, 25)
        option:SetPoint("TOPLEFT", 7, -6 - (index - 1) * 25)
        option:SetNormalFontObject("GameFontHighlight")
        option:SetText(name)
        option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if color then option:GetFontString():SetTextColor(color.r, color.g, color.b) end
        option:SetScript("OnClick", function()
            Settings.classToken = token
            menu:Hide()
            Settings:Refresh()
        end)
    end
    menu:Hide()
    selector:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    frame:SetScript("OnHide", function() menu:Hide(); GameTooltip:Hide() end)

    label(frame, "Healing abilities", 22, -101)
    label(frame, "Drag spells into the matching portrait quadrants.", 22, -121, "GameFontHighlightSmall")
    self.healSlots, self.buffSlots = {}, {}
    for index = 1, 4 do
        local x = 22 + ((index - 1) % 2) * 227
        local y = -145 - math.floor((index - 1) / 2) * 56
        self.healSlots[index] = createSlot(frame, "heals", index, x, y, 219)
    end
    label(frame, "Buffs", 22, -272)
    label(frame, "Track and reapply these buffs for this class.", 22, -292, "GameFontHighlightSmall")
    for index = 1, ns.MAX_BUFFS do
        local x = 22 + ((index - 1) % 2) * 227
        local y = -315 - math.floor((index - 1) / 2) * 53
        self.buffSlots[index] = createSlot(frame, "buffs", index, x, y, 219)
    end
    frame.note = label(frame, "", 22, -537, "GameFontHighlightSmall")
    frame.note:SetWidth(446)
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
        if class.token == self.classToken then frame.selector:SetText(class.name .. "  v"); break end
    end
    local locked = ns.InCombat()
    local function paint(slot)
        local id = ns.Profiles:GetSpell(self.classToken, slot.kind, slot.index)
        local spell = ns.Spells:Get(id)
        slot.icon:SetTexture(spell and spell.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        slot.icon:SetDesaturated(locked)
        slot:SetAlpha(locked and 0.55 or 1)
        slot.title:SetText(spell and spell.name or (id and ("Spell #" .. id) or "Drop spell here"))
        local rank = spell and spell.rank or ""
        if slot.kind == "heals" then
            slot.rank:SetText(QUADRANT_LABELS[slot.index] .. (rank ~= "" and (" - " .. rank) or ""))
        else
            slot.rank:SetText(rank ~= "" and rank or (id and "Assigned buff" or "Add a buff"))
        end
    end
    for _, slot in ipairs(self.healSlots) do paint(slot) end
    local firstEmpty
    for index, slot in ipairs(self.buffSlots) do
        local configured = ns.Profiles:GetSpell(self.classToken, "buffs", index) ~= nil
        if not configured and not firstEmpty then firstEmpty = index end
        slot:SetShown(configured or index == firstEmpty)
        paint(slot)
    end
    frame.note:SetText(locked and "Assignments are locked during combat."
        or "Exact spell ranks are saved. Right-click a slot to clear it.")
end

function Settings:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide() else self:Refresh(); frame:Show() end
end
