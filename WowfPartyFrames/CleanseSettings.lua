local _, ns = ...
local Settings = {}
ns.CleanseSettings = Settings
local ORDER = { "Magic", "Disease", "Poison", "Curse" }
local INSTRUCTION = "Drag a removal spell. Right-click to disable. Auto restores suggestions."
local EMPTY = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function label(parent, text, x, y, size, template)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 10, "")
    font:SetPoint("TOPLEFT", x, y)
    font:SetJustifyH("LEFT")
    font:SetText(text)
    return font
end

function Settings:SetNote(message)
    self.message = message
    if self.frame then
        self.frame.note:SetText(ns.InCombat() and "Assignments are locked during combat."
            or self.message or INSTRUCTION)
    end
end

function Settings:Assign(slot, clear)
    if ns.InCombat() then self:SetNote("Assignments are locked during combat."); return false end
    if not slot or not slot.kind then self:SetNote("Choose a debuff removal slot."); return false end
    local record, reason
    if not clear then
        record, reason = ns.Spells:FromCursor()
        if not record then self:SetNote(reason or "Drag a removal spell from your spellbook."); return false end
    end
    local ok
    ok, reason = ns.Cleanses:SetSpell(slot.kind, record and record.id or false)
    if not ok then self:SetNote(reason or "That spell could not be assigned."); return false end
    -- Invalid drops and right-click disabling leave any cursor contents alone.
    if record and ClearCursor then ClearCursor() end
    self:SetNote(nil)
    self:Refresh()
    return true
end

function Settings:Reset(kind)
    if ns.InCombat() then self:SetNote("Assignments are locked during combat."); return false end
    local ok, reason = ns.Cleanses:Reset(kind)
    if not ok then self:SetNote(reason or "Automatic selection is unavailable."); return false end
    self:SetNote(nil)
    self:Refresh()
    return true
end

local function tooltip(slot)
    local row = slot.row or {}
    local id = row.spellID or row.selectedSpellID
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    if id then GameTooltip:SetSpellByID(id) else GameTooltip:SetText(slot.kind .. " removal") end
    local mode = row.mode == "disabled" and "Off" or row.mode == "manual" and "Manual selection" or "Automatic selection"
    GameTooltip:AddLine(slot.kind .. " - " .. mode, 1, 0.82, 0)
    if row.mode == "manual" and not row.spellID then
        GameTooltip:AddLine("Your selected spell is not currently learned. Its assignment is saved.", 1, 0.65, 0.3, true)
    elseif not row.available then
        GameTooltip:AddLine("No supported learned ability for this type.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine("Drag a removal spell to use its exact rank for every preset.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Right-click to disable this type. Auto restores a learned suggestion.", 0.85, 0.85, 0.85, true)
    if ns.InCombat() then GameTooltip:AddLine("Locked during combat.", 1, 0.3, 0.3) end
    GameTooltip:Show()
end

local function createSlot(parent, kind, x, y)
    local slot = CreateFrame("Button", nil, parent)
    slot.kind = kind
    slot:SetSize(149, 76)
    slot:SetPoint("TOPLEFT", x, y)
    slot.label = label(slot, kind, 0, 0, 12, "GameFontNormal")
    local border = slot:CreateTexture(nil, "BACKGROUND")
    border:SetSize(36, 36)
    border:SetPoint("TOPLEFT", 0, -22)
    border:SetColorTexture(0.58, 0.46, 0.26, 1)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetSize(32, 32)
    slot.icon:SetPoint("CENTER", border, "CENTER")
    slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slot.title = label(slot, "", 43, -21)
    slot.title:SetWidth(106)
    slot.title:SetHeight(24)
    slot.title:SetWordWrap(true)
    slot.rank = label(slot, "", 43, -47, 10, "GameFontNormalSmall")
    slot.rank:SetWidth(106)
    slot.rank:SetHeight(12)
    slot.rank:SetWordWrap(false)
    slot.status = label(slot, "", 0, -63)
    slot.status:SetWidth(149)
    slot.status:SetWordWrap(false)
    slot:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnReceiveDrag", function(self) Settings:Assign(self, false) end)
    slot:SetScript("OnClick", function(self, mouseButton) Settings:Assign(self, mouseButton == "RightButton") end)
    slot:SetScript("OnEnter", tooltip)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local auto = CreateFrame("Button", nil, slot, "BackdropTemplate")
    slot.auto = auto
    auto:SetSize(40, 19)
    auto:SetPoint("TOPRIGHT", 0, 3)
    ns.SetBackdrop(auto, {0.035, 0.03, 0.025, 1}, {0.45, 0.38, 0.26, 1})
    auto.title = label(auto, "Auto", 0, -5)
    auto.title:SetWidth(40)
    auto.title:SetJustifyH("CENTER")
    auto:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    auto:SetScript("OnClick", function() Settings:Reset(kind) end)
    auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatic " .. kind .. " removal")
        GameTooltip:AddLine("Restore a suggestion from your learned spells.", 0.85, 0.85, 0.85, true)
        if ns.InCombat() then GameTooltip:AddLine("Locked during combat.", 1, 0.3, 0.3) end
        GameTooltip:Show()
    end)
    auto:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return slot
end

function Settings:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "WowfPartyFramesCleanseSettings", UIParent, "BackdropTemplate")
    self.frame, self.slots = frame, {}
    frame:SetSize(340, 292)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function(self) self:StopMovingOrSizing(); GameTooltip:Hide() end)
    ns.SetBackdrop(frame, {0.075, 0.065, 0.045, 0.98}, {0.65, 0.51, 0.27, 1})
    label(frame, "Debuff removal", 17, -17, 16, "GameFontNormalLarge")
    local subtitle = label(frame, "Shared across presets for this character.", 17, -44)
    subtitle:SetWidth(306)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close = close
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)
    for index, kind in ipairs(ORDER) do
        self.slots[kind] = createSlot(frame, kind, 17 + ((index - 1) % 2) * 157,
            -76 - math.floor((index - 1) / 2) * 82)
    end
    frame.note = label(frame, "", 17, -251)
    frame.note:SetWidth(306)
    frame.note:SetHeight(28)
    frame.note:SetWordWrap(true)
    for _, event in ipairs({"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "SPELL_TEXT_UPDATE", "SPELL_DATA_LOAD_RESULT"}) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function()
        if not ns.InCombat() then ns.Cleanses:Refresh() end
        Settings:Refresh()
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WowfPartyFramesCleanseSettings") end
    frame:Hide()
    self:Refresh()
    return frame
end

function Settings:Refresh()
    if not self.frame then return end
    local locked = ns.InCombat()
    for _, row in ipairs(ns.Cleanses:GetSlots()) do
        local slot = self.slots[row.key]
        if slot then
            slot.row = row
            local record = row.record
            if not record and row.selectedSpellID then record = ns.Spells:Get(row.selectedSpellID) end
            slot.icon:SetTexture(record and record.icon or EMPTY)
            slot.icon:SetDesaturated(locked or row.mode == "disabled" or (row.mode == "manual" and not row.spellID))
            slot.title:SetText(record and record.name or (row.selectedSpellID and "Spell #" .. row.selectedSpellID)
                or (row.mode == "disabled" and "Disabled" or "No learned ability"))
            slot.rank:SetText(record and record.rank or "")
            slot.status:SetText(row.mode == "disabled" and "Off" or (row.mode == "manual"
                and (row.spellID and "Manual" or "Manual - not learned") or "Auto"))
            slot.status:SetTextColor(row.mode == "disabled" and 0.65 or 1,
                row.mode == "disabled" and 0.65 or 0.82, row.mode == "disabled" and 0.65 or 0.4)
            slot:SetAlpha(locked and 0.55 or (row.available and 1 or 0.72))
            slot.auto.title:SetTextColor(1, row.mode == "auto" and 0.82 or 1, row.mode == "auto" and 0 or 1)
        end
    end
    self:SetNote(self.message)
end

function Settings:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide(); return end
    if not ns.InCombat() then ns.Cleanses:Refresh() end
    self:SetNote(nil)
    self:Refresh()
    frame:Show()
end
