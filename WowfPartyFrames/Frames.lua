local _, ns = ...
local Frames = { headers = {}, cards = {}, pendingRoster = false }
ns.Frames = Frames
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local EMPTY_NAME = "__WOWF_NO_MEMBER__"
local L = ns.Layout

local function public(value, kind)
    return not ns.IsSecret(value) and (not kind or type(value) == kind)
end

local function portraitHovered(card)
    local hovered = card.portraitArea:IsMouseOver()
    return public(hovered, "boolean") and hovered
end

local function unitOf(card)
    local unit = card:GetAttribute("unit")
    if public(unit, "string") then return unit end
end

local function fullName(unit)
    local name, realm = UnitName(unit)
    if not public(name, "string") or name == "" or name == UNKNOWNOBJECT or name == UNKNOWN then return nil end
    if not public(realm) then return nil end
    if realm and realm ~= "" then name = name .. "-" .. realm end
    return name
end

local function colorFor(class)
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or {r=0.9, g=0.85, b=0.7}
end

local function hideTooltip() GameTooltip:Hide() end

local function spellTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.spellID then
        GameTooltip:SetSpellByID(button.spellID)
        if button.kind == "heals" then
            GameTooltip:AddLine(ns.QUADRANTS[button.index] .. ": click to heal this member.", 1, 0.82, 0, true)
        else
            local state = button.buffState
            local note = state == "missing" and "Missing - click to reapply to this member."
                or state == "active" and "Active - click to refresh on this member."
                or "Buff status unavailable - click to cast on this member."
            GameTooltip:AddLine(note, 1, 0.82, 0, true)
        end
    else
        GameTooltip:SetText("No spell assigned")
        GameTooltip:AddLine("Open /wpf to edit presets. Right-click this member to assign one.", 0.85, 0.85, 0.85, true)
    end
    local preset = ns.Profiles:GetPreset(button.card.presetID)
    GameTooltip:AddLine("Preset: " .. (preset and preset.name or "Default"), 1, 0.82, 0)
    if button.preview then GameTooltip:AddLine("Preview only: no spells will be cast.", 1, 0.5, 0.25, true) end
    GameTooltip:Show()
end

local function decorateControls(card, preview)
    ns.Visuals:DecorateUnit(card)
    card.heals, card.buffs = {}, {}
    for _, kind in ipairs({"heals", "buffs"}) do
        for index = 1, kind == "heals" and 4 or ns.MAX_BUFFS do
            -- Direct parenting is intentional: useparent-unit follows the
            -- secure header's current unit token, including combat reorders.
            local button = CreateFrame("Button", nil, card, not preview and "SecureActionButtonTemplate" or nil)
            button.kind, button.index, button.card, button.preview = kind, index, card, preview
            ns.Visuals:DecorateSpellButton(button, kind == "heals" and L.healSize or L.auraSize)
            if not preview then
                button:RegisterForClicks("AnyDown", "AnyUp")
                button:SetAttribute("useparent-unit", true)
                button:SetAttribute("checkselfcast", false)
                button:SetAttribute("checkfocuscast", false)
                button:SetAttribute("checkmouseovercast", false)
                button:SetAttribute("type2", "togglemenu")
                button:SetAttribute("*type2", "togglemenu")
            end
            if kind == "heals" then
                local x = (index - 1) % 2 * L.healSize + L.healInset
                local y = -L.healInset - math.floor((index - 1) / 2) * L.healSize
                button:SetPoint("TOPLEFT", card.portraitArea, "TOPLEFT", x, y)
                button:SetFrameLevel(card.portraitArea:GetFrameLevel() + 2)
                button.border:SetAlpha(0)
                if index > 2 then
                    -- Keep bottom-quadrant ranks inside the circular portrait.
                    button.rank:ClearAllPoints()
                    button.rank:SetPoint("TOPLEFT", 0, -1)
                end
            else
                button:SetPoint("TOPLEFT", L.auraX + (index - 1) * L.auraPitch, L.buffY)
            end
            button:SetScript("OnEnter", function(self) spellTooltip(self) end)
            button:SetScript("OnLeave", hideTooltip)
            card[kind][index] = button
        end
    end
    for _, button in ipairs(card.debuffs) do
        button:SetScript("OnEnter", function(self)
            local unit = not preview and unitOf(card)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if unit and self.auraInstanceID and GameTooltip.SetUnitDebuffByAuraInstanceID then
                local ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, unit, self.auraInstanceID)
                if not ok then GameTooltip:SetText("Debuff details unavailable") end
            else
                GameTooltip:SetText(preview and "Preview debuff" or "Debuff")
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", hideTooltip)
    end
    ns.Visuals:SetPortraitHover(card, false)
end

local function configureSpell(button, id)
    local spell = id and ns.Spells:Get(id)
    button.spellID = id
    if not button.preview then
        -- Numeric spell IDs preserve the precise dragged rank.
        button:SetAttribute("spell", id)
        button:SetAttribute("type1", id and "spell" or "target")
        button:SetAttribute("*type1", id and "spell" or "target")
    end
    button.icon:SetTexture(spell and spell.icon or QUESTION)
    button.icon:SetDesaturated(false)
    local rank = spell and spell.rank or ""
    local rankNumber = rank:match("%d+")
    button.rank:SetText(button.kind == "heals" and rankNumber and ("R" .. rankNumber) or "")
    if button.kind == "buffs" then button:SetShown(id ~= nil) end
end

local function applyCardProfile(card)
    card.presetID = card.previewIndex and (ns.Settings and ns.Settings.presetID or "default")
        or card.memberKey and ns.Assignments:GetPreset(card.memberKey) or nil
    local hasBuffs = false
    for _, kind in ipairs({"heals", "buffs"}) do
        for index, button in ipairs(card[kind]) do
            local id = ns.Profiles:GetSpell(card.presetID, kind, index)
            configureSpell(button, id)
            if kind == "buffs" and button.spellID then
                hasBuffs = true
                if card.previewIndex then
                    button.buffState = index == 1 and card.previewIndex == 2 and "missing" or "active"
                    button.glow:SetAlpha(button.buffState == "missing" and 1 or 0)
                    button.timer:SetText(button.buffState == "missing" and "+" or (index == 1 and "18m" or "12m"))
                end
            end
        end
    end
    card.buffLabel:SetText(hasBuffs and "Buffs" or "")
end

function Frames:ApplyProfiles()
    if ns.InCombat() then self.pendingProfiles = true; return false end
    for _, card in ipairs(self.cards) do applyCardProfile(card) end
    if self.preview then
        for _, card in ipairs(self.preview.cards) do applyCardProfile(card) end
    end
    self.pendingProfiles = false
    return true
end

function Frames:Create()
    if self.anchor then return self.ready == true end
    if ns.InCombat() then return false end
    local anchor = CreateFrame("Frame", "WowfPartyFramesAnchor", UIParent)
    self.anchor = anchor
    anchor:SetSize(L.width, L.pitch * 3 + L.height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    local p = ns.db.position
    anchor:SetScale(ns.db.scale)
    if p.point == "TOPLEFT" and p.relativePoint == "TOPLEFT"
        and ((p.x == 24 and p.y == -190) or (p.x == 16 and p.y == -128)) then
        self:PositionAtNative()
    else
        anchor:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    end

    for index = 1, 4 do
        local header = CreateFrame("Frame", "WowfPartyFramesHeader" .. index, anchor, "SecureGroupHeaderTemplate")
        header:Hide()
        header:SetAttribute("_ignore", true)
        header:SetAttribute("template", "SecureUnitButtonTemplate")
        header:SetAttribute("initialConfigFunction", string.format([[
            self:SetWidth(%d); self:SetHeight(%d);
            self:SetAttribute("type1", "target");
            self:SetAttribute("type2", "togglemenu");
        ]], L.width, L.height))
        header:SetAttribute("showParty", true)
        header:SetAttribute("showRaid", false)
        header:SetAttribute("showPlayer", false)
        header:SetAttribute("showSolo", false)
        header:SetAttribute("nameList", EMPTY_NAME)
        header:SetAttribute("sortMethod", "NAMELIST")
        header:SetAttribute("unitsPerColumn", 1)
        header:SetAttribute("maxColumns", 1)
        header:SetAttribute("point", "TOPLEFT")
        header:SetAttribute("_ignore", nil)
        header:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(index - 1) * L.pitch)
        -- Blizzard's updater allocates child1 even for an empty name list.
        SecureGroupHeader_Update(header)
        local card = header:GetAttribute("child1")
        assert(card, "WoW Forever did not create a secure party button")
        card.header = header
        card:RegisterForClicks("AnyUp")
        card:SetAttribute("type1", "target")
        card:SetAttribute("type2", "togglemenu")
        decorateControls(card, false)
        card:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.memberName or "Party member")
            local preset = ns.Profiles:GetPreset(self.presetID)
            GameTooltip:AddLine("Preset: " .. (preset and preset.name or "Default"), 1, 0.82, 0)
            GameTooltip:AddLine("Left-click to target. Right-click to assign a preset or open party actions.", 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine("Rate bar: healing left, net center, damage right. Per second over the last 5 seconds.", 0.85, 0.85, 0.85, true)
            if self.rateStatus == "available" then
                GameTooltip:AddLine(string.format("Healing %.1f/s  |  Net %+.1f/s  |  Damage %.1f/s",
                    self.healingPerSecond, self.netPerSecond, self.damagePerSecond), 1, 1, 1, true)
            end
            if self.rateStatus and self.rateStatus ~= "available" then
                GameTooltip:AddLine(self.rateStatus, 1, 0.65, 0.3, true)
            end
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", hideTooltip)
        self.headers[index], self.cards[index] = header, card
        RegisterStateDriver(header, "visibility", "[group:raid] hide; show")
    end
    -- The move handle is independent of the protected anchor so it can hide
    -- safely if combat begins while the frames are unlocked.
    local mover = CreateFrame("Button", "WowfPartyFramesMover", UIParent)
    self.mover = mover
    mover:SetSize(L.width, 24)
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:SetFrameStrata("DIALOG")
    mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    mover.text:SetPoint("CENTER")
    mover.text:SetText("Drag party frames  |  /wpf lock")
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        -- Only move this independent handle. The secure frames adopt its
        -- position on release, outside combat.
        if not ns.InCombat() then mover:StartMoving(); self.moving = true end
    end)
    mover:SetScript("OnDragStop", function() self:StopMoving() end)
    mover:Hide()
    self:RefreshRoster()
    self.ready = true
    return true
end

function Frames:StopMoving()
    if not self.moving then return end
    self.mover:StopMovingOrSizing()
    self.moving = false
    -- Combat cancels a drag; neither position nor anchors change then.
    if not ns.InCombat() then
        local factor = self.mover:GetEffectiveScale() / self.anchor:GetEffectiveScale()
        local left, top = self.mover:GetLeft() * factor, self.mover:GetTop() * factor
        self.anchor:ClearAllPoints()
        self.anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top - 30 * factor)
        self:SavePosition()
    end
end

function Frames:SavePosition()
    if ns.InCombat() or not self.anchor then return end
    local point, _, relativePoint, x, y = self.anchor:GetPoint(1)
    ns.db.position = {point=point, relativePoint=relativePoint, x=x, y=y}
    self.positionDirty = false
end

function Frames:SetUnlocked(unlocked)
    if ns.InCombat() then return false, "Move the frames after combat ends." end
    self:StopMoving()
    self.unlocked = unlocked
    if unlocked then
        local factor = self.anchor:GetEffectiveScale() / self.mover:GetEffectiveScale()
        self.mover:ClearAllPoints()
        self.mover:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            self.anchor:GetLeft() * factor, self.anchor:GetTop() * factor + 30)
    end
    self.mover:SetShown(unlocked)
    return true
end

function Frames:ResetPosition()
    if ns.InCombat() then return false, "Reset the position after combat ends." end
    self:StopMoving()
    self:PositionAtNative()
    self:SavePosition()
    if self.unlocked then self:SetUnlocked(true) end
    return true
end

function Frames:PositionAtNative()
    if ns.InCombat() then return end
    self.anchor:ClearAllPoints()
    local native = PartyFrame or PartyMemberFrame1
    if native then
        local left, top = native:GetLeft(), native:GetTop()
        if public(left, "number") and public(top, "number") then
            local factor = native:GetEffectiveScale() / self.anchor:GetEffectiveScale()
            self.anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * factor, top * factor)
            return
        end
    end
    self.anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -128)
end

function Frames:RefreshRoster()
    if not self.anchor then return false end
    if ns.InCombat() then self.pendingRoster = true; return false end
    if ns.worldSeen then ns.Assignments:BeginSession(ns.isReloadingUI) end
    if self.preview and (GetNumSubgroupMembers() > 0 or IsInRaid()) then self.preview:Hide() end
    local members, nameCounts, resolved = {}, {}, 0
    local complete = true
    for index = 1, 4 do
        local unit = "party" .. index
        local name = not IsInRaid() and fullName(unit) or nil
        local _, class = UnitClass(unit)
        if not public(class, "string") then class = nil end
        if not class then name = nil end
        local key = name and ns.Assignments:Identity(unit)
        members[index] = {name = name, class = class, key = key}
        if name then nameCounts[name] = (nameCounts[name] or 0) + 1 end
    end
    local roster = {}
    for _, member in ipairs(members) do
        if member.name and nameCounts[member.name] == 1 and member.key then
            roster[#roster + 1] = member
            resolved = resolved + 1
        elseif member.name then complete = false end
    end
    if not IsInRaid() and resolved < GetNumSubgroupMembers() then complete = false end
    ns.Assignments:Sync(roster, complete)
    local changed = not self.rosterInitialized
    for index, header in ipairs(self.headers) do
        local name, class = members[index].name, members[index].class
        -- Do not bind even the first occurrence of an ambiguous name: the
        -- secure name filter could otherwise select the wrong class/member.
        if not name or nameCounts[name] ~= 1 then name, class = nil, nil end
        local card = self.cards[index]
        local key = name and members[index].key
        if card.memberName ~= name or card.classToken ~= class or card.memberKey ~= key then
            changed = true
            header:SetAttribute("nameList", name or EMPTY_NAME)
        end
        card.classToken, card.memberName, card.memberKey = class, name, key
        SecureGroupHeader_Update(header)
        local color = colorFor(class)
        card.name:SetTextColor(color.r, color.g, color.b)
    end
    self.pendingRoster = false
    self.rosterInitialized = true
    self:ApplyProfiles()
    if changed then ns.Rates:SetUnits({"party1", "party2", "party3", "party4"}) end
    self:RefreshAll(true)
    if ns.PresetMenus then ns.PresetMenus:RefreshPrompts() end
    return true
end

local function paintResources(card, unit)
    -- Secret resource values go directly to permitted display setters. Never
    -- compare, divide, round, or concatenate these values in addon code.
    local hp, maxHP = UnitHealth(unit), UnitHealthMax(unit)
    card.health:SetMinMaxValues(0, maxHP)
    card.health:SetValue(hp)
    card.health.text:SetFormattedText("%d / %d", hp, maxHP)
    local power, powerToken = UnitPowerType(unit)
    if not public(power, "number") then power, powerToken = 0, "MANA" end
    if not public(powerToken, "string") then powerToken = "MANA" end
    local current, maximum = UnitPower(unit, power), UnitPowerMax(unit, power)
    card.power:SetMinMaxValues(0, maximum)
    card.power:SetValue(current)
    card.power.text:SetFormattedText("%d / %d", current, maximum)
    local color = PowerBarColor and (PowerBarColor[powerToken] or PowerBarColor[power]) or {r=0.12,g=0.35,b=0.88}
    if color then card.power:SetStatusBarColor(color.r, color.g, color.b) end
    local connected, dead = UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
    card.status:SetText(public(connected) and connected == false and "Offline"
        or public(dead) and dead and "Dead" or "")
    local target = UnitIsUnit(unit, "target")
    card.targetRing:SetAlpha(public(target) and target and 1 or 0)
    card.targetRing:Show()
    card.name:SetText(UnitName(unit))
    SetPortraitTexture(card.portrait, unit)
end

local function paintRates(card, unit)
    local heal, damage, net, status = ns.Rates:Get(unit)
    ns.Visuals:PaintRates(card, heal, damage, net, status)
end

local function paintAuras(card, unit)
    local entries, known = ns.Auras:GetDebuffs(unit, 8)
    card.debuffLabel:SetText(known and "Debuffs" or "Debuffs?")
    for index, button in ipairs(card.debuffs) do
        local entry = entries[index]
        button.auraInstanceID = entry and entry.auraInstanceID
        ns.Auras:Paint(button, unit, entry)
        -- Only these unprotected display buttons change visibility in combat.
        button:SetShown(entry ~= nil)
    end
    for _, button in ipairs(card.buffs) do
        if button.spellID then
            local buff = ns.Auras:GetAssignedBuff(unit, button.spellID)
            button.buffState = buff.state
            ns.Auras:Paint(button, unit, buff.aura)
            if buff.state ~= "active" then
                local spell = ns.Spells:Get(button.spellID)
                button.icon:SetTexture(spell and spell.icon or QUESTION)
            end
            button.icon:SetDesaturated(buff.state ~= "active")
            button.glow:SetAlpha(buff.state == "missing" and 1 or 0)
            if buff.state == "missing" then
                button.border:SetColorTexture(1, 0.72, 0.12, 1)
                button.icon:SetAlpha(1)
                button.timer:SetText("+")
            elseif buff.state == "unknown" then
                button.border:SetColorTexture(0.45, 0.45, 0.45, 1)
                button.icon:SetAlpha(0.65)
                button.timer:SetText("?")
            else
                button.border:SetColorTexture(0.38, 0.5, 0.35, 1)
                button.icon:SetAlpha(1)
            end
        end
    end
end

function Frames:RefreshAll(refreshAuras)
    for _, card in ipairs(self.cards) do
        local unit = unitOf(card)
        if unit and card:IsVisible() then
            paintResources(card, unit)
            paintRates(card, unit)
            if refreshAuras then paintAuras(card, unit) end
            ns.Visuals:SetPortraitHover(card, portraitHovered(card))
        end
    end
    if self.preview and self.preview:IsShown() then
        for _, card in ipairs(self.preview.cards) do
            ns.Visuals:SetPortraitHover(card, portraitHovered(card))
        end
    end
end

function Frames:SetBlizzardVisible(visible)
    if ns.InCombat() then return false, "Change the default frames after combat ends." end
    if not self.ready then return false, "Party frames are not ready yet." end
    self.nativeParents = self.nativeParents or {}
    local native = {}
    if PartyFrame then native[#native + 1] = PartyFrame
    else
        for index = 1, 4 do
            if _G["PartyMemberFrame" .. index] then native[#native + 1] = _G["PartyMemberFrame" .. index] end
        end
    end
    if visible then
        for frame, parent in pairs(self.nativeParents) do
            frame:SetParent(parent)
            if frame.UpdatePartyFrames then frame:UpdatePartyFrames() end
            self.nativeParents[frame] = nil
        end
    else
        if not self.nativeHolder then
            self.nativeHolder = CreateFrame("Frame", "WowfPartyFramesNativeHolder", UIParent)
            self.nativeHolder:Hide()
        end
        for _, frame in ipairs(native) do
            if not self.nativeParents[frame] then
                self.nativeParents[frame] = frame:GetParent()
                frame:SetParent(self.nativeHolder)
            end
        end
    end
    ns.db.showBlizzard = visible and true or false
    return true
end

function Frames:TogglePreview()
    if ns.InCombat() then return false, "Open the preview after combat ends." end
    if GetNumSubgroupMembers() > 0 or IsInRaid() then
        return false, "Your party frames are already live. Preview is available while solo."
    end
    if self.preview then self.preview:SetShown(not self.preview:IsShown()); return true end
    local preview = CreateFrame("Frame", "WowfPartyFramesPreview", self.anchor)
    self.preview = preview
    preview:SetAllPoints(self.anchor)
    local title = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 50, -7)
    title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    title:SetText("Preview  |  /wpf test to close")
    preview.cards = {}
    local samples = {
        {"Thorin", "WARRIOR", 3240, 4500, 62, 100, "Rage", 50, 45},
        {"Lyra", "MAGE", 1630, 2100, 2800, 3600, "Mana", 25, 38},
        {"Elowen", "DRUID", 2410, 2800, 1920, 3100, "Mana", 32, 20},
        {"Kael", "ROGUE", 2180, 2600, 80, 100, "Energy", 15, 15},
    }
    for index, sample in ipairs(samples) do
        local card = CreateFrame("Frame", nil, preview)
        card.classToken, card.previewIndex = sample[2], index
        card:SetPoint("TOPLEFT", 0, -(index - 1) * L.pitch)
        decorateControls(card, true)
        preview.cards[index] = card
        local color = colorFor(sample[2])
        card.name:SetText(sample[1]); card.name:SetTextColor(color.r, color.g, color.b)
        card.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[sample[2]]
        if coords then card.portrait:SetTexCoord(unpack(coords)) end
        card.health:SetMinMaxValues(0, sample[4]); card.health:SetValue(sample[3])
        card.health.text:SetFormattedText("%d / %d", sample[3], sample[4])
        card.power:SetMinMaxValues(0, sample[6]); card.power:SetValue(sample[5])
        card.power.text:SetFormattedText("%d / %d", sample[5], sample[6])
        local powerColor = PowerBarColor and PowerBarColor[sample[7]:upper()]
        if powerColor then card.power:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b) end
        ns.Visuals:PaintRates(card, sample[8], sample[9], sample[8] - sample[9], "available")
        applyCardProfile(card)
        for slot, button in ipairs(card.debuffs) do
            button:SetShown(slot == 1)
            if slot == 1 then
                button.icon:SetTexture("Interface\\Icons\\Spell_Holy_AshesToAshes")
                button.timer:SetText("12")
            end
        end
        ns.Visuals:SetPortraitHover(card, false)
    end
    if UISpecialFrames then table.insert(UISpecialFrames, "WowfPartyFramesPreview") end
    return true
end
