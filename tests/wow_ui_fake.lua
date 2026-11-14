-- Deliberately small UI harness, not an emulator of WoW's secure execution.
return function()
    local state = { combat = false, objects = {}, units = {}, messages = {}, time = 10, violations = {} }
    local methods = {}
    local function check(self, operation)
        if state.combat and self.protected then
            state.violations[#state.violations + 1] = operation
            error("Insecure protected mutation: " .. operation)
        end
    end
    local function object(kind, name, parent, template)
        local result = setmetatable({ kind = kind, name = name, parent = parent,
            template = template, attrs = {}, scripts = {}, events = {}, shown = true,
            protected = template and template:find("Secure") ~= nil or false,
            level = 1, alpha = 1, children = {} }, { __index = methods })
        if parent then parent.children[#parent.children + 1] = result end
        if result.protected then
            local ancestor = parent
            while ancestor do ancestor.protected = true; ancestor = ancestor.parent end
        end
        state.objects[#state.objects + 1] = result
        if name then _G[name] = result end
        return result
    end
    function methods:SetAttribute(key, value) check(self, "SetAttribute"); self.attrs[key] = value end
    function methods:GetAttribute(key) return self.attrs[key] end
    function methods:SetPoint(...)
        check(self, "SetPoint")
        self.point = { ... }
        self.points = self.points or {}
        for index, point in ipairs(self.points) do
            if point[1] == self.point[1] then self.points[index] = self.point; return end
        end
        self.points[#self.points + 1] = self.point
    end
    function methods:GetPoint() return unpack(self.point or { "TOPLEFT", nil, "TOPLEFT", 24, -190 }) end
    function methods:ClearAllPoints() check(self, "ClearAllPoints"); self.point, self.points, self.allPoints = nil, {}, nil end
    function methods:SetAllPoints(...) check(self, "SetAllPoints"); self.allPoints = { ... } end
    function methods:SetSize(w, h) check(self, "SetSize"); self.width, self.height = w, h end
    function methods:SetWidth(w) check(self, "SetWidth"); self.width = w end
    function methods:SetHeight(h) check(self, "SetHeight"); self.height = h end
    function methods:GetWidth() return self.width or 100 end
    function methods:GetHeight() return self.height or 100 end
    function methods:Show() check(self, "Show"); self.shown = true end
    function methods:Hide() check(self, "Hide"); self.shown = false end
    function methods:SetShown(value) if value then self:Show() else self:Hide() end end
    function methods:IsShown() return self.shown end
    function methods:IsMouseOver() return state.hover == self end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:SetParent(parent) check(self, "SetParent"); self.parent = parent end
    function methods:GetParent() return self.parent end
    function methods:GetName() return self.name end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        local previous = self.scripts[event]
        self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
    end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:RegisterUnitEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:UnregisterAllEvents() self.events = {} end
    function methods:IsEventRegistered(event) return self.events[event] or false end
    function methods:SetText(value)
        self.text = value
        -- Plain buttons have no font string until text is first assigned.
        -- GetFontString must never manufacture one: the client returns nil.
        if self.kind == "Button" and self.normalFontObject then
            if not self.fontString then self.fontString = self:CreateFontString(nil, "OVERLAY") end
            self.fontString:SetText(value)
        end
    end
    function methods:GetText() return self.text end
    function methods:SetFont(path, size, flags) self.font = { path, size, flags }; return true end
    function methods:GetFont() return unpack(self.font or { "Fonts\\FRIZQT__.TTF", 12, "" }) end
    function methods:SetNormalFontObject(value) self.normalFontObject = value end
    function methods:GetFontString() return self.fontString end
    function methods:SetAutoFocus(value) self.autoFocus = value end
    function methods:SetMaxLetters(value) self.maxLetters = value end
    function methods:SetFocus() self.focused = true end
    function methods:ClearFocus() self.focused = false end
    function methods:HighlightText() self.highlighted = true end
    function methods:SetFormattedText(format, ...) self.format, self.formatValues = format, { ... } end
    function methods:GetStringWidth() return self.measuredWidth or #(self.text or "") * 6 end
    function methods:SetAtlas(atlas) self.atlas = atlas end
    function methods:SetSpriteSheetCell(cell, rows, columns) self.spriteCell = {cell, rows, columns} end
    function methods:SetTexture(value) self.texture = value end
    function methods:SetBlendMode(value) self.blendMode = value end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:GetAlpha() return self.alpha end
    function methods:SetValue(value) self.value = value end
    function methods:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
    function methods:SetFrameLevel(value) self.level = value end
    function methods:GetFrameLevel() return self.level end
    function methods:SetScale(value) check(self, "SetScale"); self.scale = value end
    function methods:GetScale() return self.scale or 1 end
    function methods:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function methods:GetLeft() return self.left or 24 end
    function methods:GetRight() return self:GetLeft() + self:GetWidth() end
    function methods:GetTop() return self.top or 500 end
    function methods:GetChildren() return unpack(self.children) end
    function methods:CreateTexture(name, layer, template, sublevel)
        local region = object("Texture", name, self, template)
        region.layer, region.sublevel = layer, sublevel
        return region
    end
    function methods:CreateMaskTexture(name, layer, template, sublevel)
        local region = object("MaskTexture", name, self, template)
        region.layer, region.sublevel = layer, sublevel
        return region
    end
    function methods:RemoveMaskTexture(mask)
        if self.AddMaskTextureArgs and self.AddMaskTextureArgs[1] == mask then self.AddMaskTextureArgs = nil end
    end
    function methods:CreateFontString(name, layer, template)
        local region = object("FontString", name, self, template)
        region.layer = layer
        return region
    end
    function methods:SetFrameRef(key, frame) check(self, "SetFrameRef"); self.attrs[key] = frame end
    function methods:Execute() check(self, "Execute") end
    function methods:CallMethod(name, ...) return self[name](self, ...) end
    function methods:EnableMouse(value) check(self, "EnableMouse"); self.mouseEnabled = value end
    -- These calls only paint or configure noninteractive decoration in the harness.
    for _, name in ipairs({ "SetJustifyH", "SetWordWrap", "SetShadowColor", "SetShadowOffset", "SetColorTexture", "AddMaskTexture", "SetStatusBarTexture", "SetStatusBarColor", "SetBackdrop", "SetBackdropBorderColor", "SetBackdropColor", "SetTextColor", "SetTexCoord", "SetDrawEdge", "SetDrawBling", "SetHideCountdownNumbers", "SetVertexColor", "SetDesaturated", "SetCooldown", "Clear", "SetCooldownFromDurationObject", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "RegisterForClicks", "RegisterForDrag", "SetMovable", "SetClampedToScreen", "SetFrameStrata", "SetHitRectInsets", "SetMouseClickEnabled", "SetMouseMotionEnabled", "SetToplevel", "SetClipsChildren", "SetID", "StartMoving", "StopMovingOrSizing", "SetOwner", "AddLine", "SetSpellByID", "SetUnitAuraByAuraInstanceID" }) do
        methods[name] = function(self, ...) self[name .. "Args"] = { ... } end
    end
    for _, name in ipairs({ "RegisterForClicks", "RegisterForDrag", "SetMovable", "SetClampedToScreen", "SetFrameStrata", "SetHitRectInsets", "SetMouseClickEnabled", "SetMouseMotionEnabled", "StartMoving", "StopMovingOrSizing" }) do
        methods[name] = function(self, ...) check(self, name); self[name .. "Args"] = { ... } end
    end
    CreateFrame = function(kind, name, parent, template) return object(kind, name, parent, template) end
    UIParent = object("Frame", "UIParent")
    GameTooltip = object("GameTooltip", "GameTooltip")
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) state.messages[#state.messages + 1] = message end }
    InCombatLockdown = function() return state.combat end
    GetTime = function() return state.time end
    IsShiftKeyDown = function() return state.shift or false end
    IsControlKeyDown = function() return state.ctrl or false end
    IsAltKeyDown = function() return state.alt or false end
    GetRealmName = function() return "Realm" end
    UnitExists = function(unit) return state.units[unit] ~= nil end
    UnitName = function(unit) local data = state.units[unit]; if data then return data.name, data.realm end end
    UnitFullName = UnitName
    UnitClass = function(unit) local data = state.units[unit]; if data then return data.class, data.class end end
    UnitGUID = function(unit) local data = state.units[unit]; return data and data.guid end
    UnitHealth = function(unit) return state.units[unit].health end
    UnitHealthMax = function(unit) return state.units[unit].maxHealth end
    UnitPower = function(unit) return state.units[unit].power end
    UnitPowerMax = function(unit) return state.units[unit].maxPower end
    UnitPowerType = function(unit) return 0, "MANA" end
    UnitIsConnected = function() return true end
    UnitIsDeadOrGhost = function() return false end
    UnitIsUnit = function(left, right) return state.units[left] == state.units[right] end
    UnitInRange = function() return true, true end
    UnitIsVisible = function() return true end
    UnitReaction = function() return 5 end
    IsInRaid = function() return state.raid or false end
    IsInGroup = function() return state.subgroupCount == nil or state.subgroupCount > 0 or state.raid or false end
    GetNumGroupMembers = function() return 3 end
    GetNumSubgroupMembers = function() if state.subgroupCount ~= nil then return state.subgroupCount end; return 2 end
    SetPortraitTexture = function(texture, unit) texture.portraitUnit = unit end
    RegisterUnitWatch = function(frame) frame.unitWatch = true end
    UnregisterUnitWatch = function(frame) frame.unitWatch = false end
    SecureButton_GetUnit = function(frame)
        local current = frame
        while current do
            if current.attrs.unit then return current.attrs.unit end
            if not current.attrs["useparent-unit"] then return nil end
            current = current.parent
        end
    end
    SecureHandlerWrapScript = function() end
    SecureHandlerSetFrameRef = function(frame, key, target) frame:SetFrameRef(key, target) end
    SecureHandlerExecute = function(frame) check(frame, "SecureHandlerExecute") end
    -- Removed from Forever: never let this fake hide use of the obsolete global.
    MouseIsOver = nil
    RegisterStateDriver = function(frame, kind, condition)
        check(frame, "RegisterStateDriver")
        frame.stateDriver = condition
        frame.shown = condition ~= "hide"
    end
    UnregisterStateDriver = function(frame) check(frame, "UnregisterStateDriver"); frame.stateDriver = nil end
    -- Simulate the engine's name-filtered roster reconciliation, not addon code.
    state.reconcileHeader = function(header)
        local card = header.attrs.child1
        local matched
        for unit, data in pairs(state.units) do
            local name = data.name .. (data.realm and data.realm ~= "" and "-" .. data.realm or "")
            if name == header.attrs.nameList and unit:match("^party") then matched = unit; break end
        end
        card.attrs.unit = matched
        card.shown = matched ~= nil
    end
    SecureGroupHeader_Update = function(header)
        check(header, "SecureGroupHeader_Update")
        if not header.attrs.child1 then
            header.attrs.child1 = object("Button", nil, header, "SecureUnitButtonTemplate")
        end
        state.reconcileHeader(header)
    end
    RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
    SlashCmdList = {}
    state.methods = methods
    state.emit = function(event, ...)
        for _, frame in ipairs(state.objects) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    return state
end
