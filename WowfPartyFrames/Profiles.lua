local _, ns = ...
local Profiles = {}
ns.Profiles = Profiles
local MAX_PRESETS = 40

local function integer(value, maximum)
    return not ns.IsSecret(value) and type(value) == "number"
        and value > 0 and value < math.huge and value == math.floor(value)
        and (not maximum or value <= maximum)
end

local function validSlot(kind, index)
    if ns.IsSecret(kind) then return false end
    return (kind == "heals" and integer(index, 4))
        or (kind == "buffs" and integer(index, ns.MAX_BUFFS))
end

local function cleanName(name)
    if ns.IsSecret(name) or type(name) ~= "string" then return nil end
    -- Pipes can introduce texture, hyperlink, or color escapes in game text.
    if name:find("[%c|]") then return nil end
    name = name:match("^%s*(.-)%s*$")
    if #name == 0 or #name > 32 then return nil end
    return name
end

local function cleanSpells(source)
    source = type(source) == "table" and source or {}
    local clean = { heals = {}, buffs = {} }
    for _, kind in ipairs({ "heals", "buffs" }) do
        local slots = type(source[kind]) == "table" and source[kind] or {}
        for index = 1, kind == "heals" and 4 or ns.MAX_BUFFS do
            if integer(slots[index]) then clean[kind][index] = slots[index] end
        end
    end
    return clean
end

local function changed(id)
    if ns.OnProfileChanged then ns.OnProfileChanged(id) end
end

function Profiles:Init(saved)
    if type(saved) ~= "table" then saved = {} end
    local old = type(saved.presets) == "table" and saved.presets or {}
    local presets, order, names = {}, { "default" }, { default = true }
    presets.default = cleanSpells(old.default)
    presets.default.name = "Default"
    local function add(id, source, name)
        if type(id) ~= "string" or not id:match("^[%w_-]+$") or #id > 64
            or presets[id] or #order >= MAX_PRESETS or type(source) ~= "table" then return end
        name = cleanName(name)
        if not name or names[name:lower()] then return end
        local profile = cleanSpells(source)
        profile.name = name
        presets[id], order[#order + 1], names[name:lower()] = profile, id, true
    end
    if type(saved.presetOrder) == "table" then
        for _, id in ipairs(saved.presetOrder) do
            local source = type(id) == "string" and old[id]
            if type(source) == "table" then add(id, source, source.name) end
        end
    end
    local remaining = {}
    for id in pairs(old) do if type(id) == "string" then remaining[#remaining + 1] = id end end
    table.sort(remaining)
    for _, id in ipairs(remaining) do
        if type(old[id]) == "table" then add(id, old[id], old[id].name) end
    end
    -- Migrate only once: class is no longer an assignment rule.
    if saved.version ~= 2 and type(saved.classes) == "table" then
        for _, class in ipairs(ns.CLASSES) do
            local source = saved.classes[class.token]
            local clean = cleanSpells(source)
            if next(clean.heals) or next(clean.buffs) then
                add("class-" .. class.token, clean, class.name)
            end
        end
    end
    saved.classes = nil
    saved.presets, saved.presetOrder = presets, order
    local points = { TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true,
        RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true }
    local p = type(saved.position) == "table" and saved.position or {}
    local function coordinate(value, fallback)
        if type(value) == "number" and value == value and math.abs(value) < 100000 then return value end
        return fallback
    end
    saved.position = {
        point = type(p.point) == "string" and points[p.point] and p.point or "TOPLEFT",
        relativePoint = type(p.relativePoint) == "string" and points[p.relativePoint] and p.relativePoint or "TOPLEFT",
        x = coordinate(p.x, 16), y = coordinate(p.y, -128),
    }
    saved.scale = type(saved.scale) == "number" and saved.scale >= 0.5 and saved.scale <= 2 and saved.scale or 1
    saved.version = 2
    self.db = saved
    WowfPartyFramesDB = saved
    return saved
end

function Profiles:GetPreset(id)
    if not self.db or ns.IsSecret(id) or type(id) ~= "string" then return nil end
    return self.db.presets[id]
end

function Profiles:List()
    local list = {}
    if self.db then
        for _, id in ipairs(self.db.presetOrder) do
            list[#list + 1] = { id = id, name = self.db.presets[id].name }
        end
    end
    return list
end

function Profiles:GetSpell(id, kind, index)
    if not validSlot(kind, index) then return nil end
    local profile = self:GetPreset(id)
    return profile and profile[kind][index] or nil
end

function Profiles:SetSpell(id, kind, index, spellID)
    if ns.InCombat() then return false, "Assignments cannot change during combat." end
    local profile = self:GetPreset(id)
    if not profile or not validSlot(kind, index) then return false, "Invalid preset or spell slot." end
    if ns.IsSecret(spellID) then return false, "Spell information is unavailable." end
    if spellID ~= nil and (not integer(spellID) or not ns.Spells:Get(spellID)) then
        return false, "Choose a spell from your spellbook."
    end
    profile[kind][index] = spellID
    changed(id)
    return true
end

local function validateName(self, name, except)
    name = cleanName(name)
    if not name then return nil, "Choose a short name without line breaks or special formatting." end
    for id, preset in pairs(self.db.presets) do
        if id ~= except and preset.name:lower() == name:lower() then
            return nil, "A preset with that name already exists."
        end
    end
    return name
end

function Profiles:Create(name, copyID)
    if ns.InCombat() then return nil, "Presets cannot change during combat." end
    if not self.db then return nil, "Presets are not ready." end
    if #self.db.presetOrder >= MAX_PRESETS then return nil, "You can have up to 40 presets." end
    local clean, reason = validateName(self, name)
    if not clean then return nil, reason end
    local source = copyID ~= nil and self:GetPreset(copyID) or nil
    if copyID ~= nil and not source then return nil, "Choose an existing preset to copy." end
    local index = integer(self.db.nextPresetID) and self.db.nextPresetID or 1
    while self.db.presets["preset-" .. index] do index = index + 1 end
    local id = "preset-" .. index
    self.db.nextPresetID = index + 1
    local profile = cleanSpells(source)
    profile.name = clean
    self.db.presets[id] = profile
    self.db.presetOrder[#self.db.presetOrder + 1] = id
    changed(id)
    return id
end

function Profiles:Rename(id, name)
    if ns.InCombat() then return false, "Presets cannot change during combat." end
    local profile = self:GetPreset(id)
    if not profile then return false, "Choose an existing preset." end
    if id == "default" then return false, "Default cannot be renamed." end
    local clean, reason = validateName(self, name, id)
    if not clean then return false, reason end
    profile.name = clean
    changed(id)
    return true
end

function Profiles:Delete(id)
    if ns.InCombat() then return false, "Presets cannot change during combat." end
    if not self:GetPreset(id) then return false, "Choose an existing preset." end
    if id == "default" then return false, "Default cannot be deleted." end
    self.db.presets[id] = nil
    for index, entry in ipairs(self.db.presetOrder) do
        if entry == id then table.remove(self.db.presetOrder, index); break end
    end
    changed(id)
    return true
end
