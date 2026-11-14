local _, ns = ...
local Profiles = {}
ns.Profiles = Profiles

local function integer(value, maximum)
    return not ns.IsSecret(value) and type(value) == "number"
        and value > 0 and value < math.huge and value == math.floor(value)
        and (not maximum or value <= maximum)
end

local function validClass(token)
    if ns.IsSecret(token) or type(token) ~= "string" then return false end
    for _, class in ipairs(ns.CLASSES) do
        if class.token == token then return true end
    end
    return false
end

local function validSlot(kind, index)
    if ns.IsSecret(kind) then return false end
    return (kind == "heals" and integer(index, 4))
        or (kind == "buffs" and integer(index, ns.MAX_BUFFS))
end

function Profiles:Init(saved)
    if type(saved) ~= "table" then saved = {} end
    local classes = type(saved.classes) == "table" and saved.classes or {}
    saved.classes = {}
    for _, class in ipairs(ns.CLASSES) do
        local old = type(classes[class.token]) == "table" and classes[class.token] or {}
        local clean = { heals = {}, buffs = {} }
        for _, kind in ipairs({ "heals", "buffs" }) do
            local source = type(old[kind]) == "table" and old[kind] or {}
            for index = 1, kind == "heals" and 4 or ns.MAX_BUFFS do
                if integer(source[index]) then clean[kind][index] = source[index] end
            end
        end
        saved.classes[class.token] = clean
    end
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
    saved.version = 1
    self.db = saved
    WowfPartyFramesDB = saved
    return saved
end

function Profiles:GetClass(token)
    if not self.db or not validClass(token) then return nil end
    return self.db.classes[token]
end

function Profiles:GetSpell(token, kind, index)
    if not validSlot(kind, index) then return nil end
    local profile = self:GetClass(token)
    return profile and profile[kind][index] or nil
end

function Profiles:SetSpell(token, kind, index, spellID)
    if ns.InCombat() then return false, "Assignments cannot change during combat." end
    local profile = self:GetClass(token)
    if not profile or not validSlot(kind, index) then return false, "Invalid class or spell slot." end
    if ns.IsSecret(spellID) then return false, "Spell information is unavailable." end
    if spellID ~= nil and (not integer(spellID) or not ns.Spells:Get(spellID)) then
        return false, "Choose a spell from your spellbook."
    end
    profile[kind][index] = spellID
    if ns.OnProfileChanged then ns.OnProfileChanged(token) end
    return true
end
