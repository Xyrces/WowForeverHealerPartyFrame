local _, ns = ...
local Cleanses = {}
ns.Cleanses = Cleanses

-- These are friendly dispels in the Forever/classic spellbook, not retail
-- class defaults. Learned spells, never the recipient's class, enable them.
local ORDER = { "Magic", "Disease", "Poison", "Curse" }
local SPELLS = {
    [527] = { Magic=true }, [988] = { Magic=true },
    [528] = { Disease=true }, [552] = { Disease=true },
    [4987] = { Magic=true, Disease=true, Poison=true },
    [1152] = { Disease=true, Poison=true },
    [2782] = { Curse=true }, [475] = { Curse=true },
    [2893] = { Poison=true }, [8946] = { Poison=true },
    [526] = { Poison=true }, [2870] = { Disease=true },
}
-- Highest learned Dispel Magic rank; direct cures before preventative
-- Abolish alternatives. Dragging a different spell/rank overrides this.
local PRIORITY = {
    Magic = { 988, 527, 4987 },
    Disease = { 528, 552, 4987, 1152, 2870 },
    Poison = { 8946, 2893, 4987, 1152, 526 },
    Curse = { 2782, 475 },
}

local function public(value, kind)
    return not ns.IsSecret(value) and type(value) == kind
end

local function integer(value)
    return public(value, "number") and value > 0 and value < math.huge
        and value == math.floor(value)
end

local function validType(kind)
    return public(kind, "string") and PRIORITY[kind] ~= nil
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function copyTypes(source)
    local result = {}
    for _, kind in ipairs(ORDER) do if source[kind] then result[kind] = true end end
    return result
end

local function copyRecord(record)
    if not record then return nil end
    return { id=record.id, name=record.name, rank=record.rank, icon=record.icon }
end

local function recordFor(id)
    local record = call(ns.Spells and ns.Spells.Get, ns.Spells, id)
    if not public(record, "table") or not integer(record.id) or record.id ~= id
        or not public(record.name, "string") or record.name == "" then return nil end
    return {
        id=id, name=record.name,
        rank=public(record.rank, "string") and record.rank or "",
        icon=(public(record.icon, "number") or public(record.icon, "string")) and record.icon or 134400,
    }
end

local function isKnown(id)
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if book and type(book.IsSpellKnown) == "function" and public(bank, "number") then
        return call(book.IsSpellKnown, id, bank)
    end
    -- Older clients can expose the global API instead. Neither path treats
    -- spell metadata, a previously cached ID, or a pet spell as learned.
    if type(IsPlayerSpell) == "function" then return call(IsPlayerSpell, id) end
    if type(IsSpellKnown) == "function" then return call(IsSpellKnown, id, false) end
end

function Cleanses:Init(db)
    if ns.InCombat() then return false, "Cleanse assignments cannot change during combat." end
    if not public(db, "table") then return false, "Settings are not ready." end
    self.db, self.owner, self.config = db, nil, nil
    self.known, self.records, self.ready = {}, {}, false
    db.cleanseCharacters = public(db.cleanseCharacters, "table") and db.cleanseCharacters or {}
    return self:Refresh()
end

function Cleanses:Refresh()
    if ns.InCombat() then return false, "Cleanse assignments cannot change during combat." end
    if not self.db then return false, "Settings are not ready." end
    local owner = call(ns.Assignments and ns.Assignments.Identity, ns.Assignments, "player")
    if not public(owner, "string") or owner == "" then
        -- No shared fallback bucket: unresolved player identity cannot inherit
        -- another character's cures or overwrite that character's settings.
        self.owner, self.config, self.ready = nil, nil, false
        self.known, self.records = {}, {}
        return false, "Waiting for your character information."
    end
    self.owner = owner
    local config = self.db.cleanseCharacters[owner]
    if not public(config, "table") then config = {} end
    local old = public(config.overrides, "table") and config.overrides or {}
    local overrides = {}
    for _, kind in ipairs(ORDER) do
        local id = old[kind]
        if not ns.IsSecret(id) then
            if id == false then overrides[kind] = false
            elseif integer(id) and SPELLS[id] and SPELLS[id][kind] then overrides[kind] = id end
        end
    end
    config.overrides = overrides
    self.db.cleanseCharacters[owner], self.config = config, config
    local known, records, answered = {}, {}, false
    for id in pairs(SPELLS) do
        local value = isKnown(id)
        if public(value, "boolean") then
            answered = true
            if value then known[id], records[id] = true, recordFor(id) end
        end
    end
    self.known, self.records, self.ready = known, records, answered
    if not answered then return false, "Learned spell information is unavailable." end
    return true
end

function Cleanses:GetSpell(kind)
    if not validType(kind) or not self.config then return nil end
    local override = self.config.overrides[kind]
    if override == false then return nil end
    if override then return self.known[override] and override or nil end
    for _, id in ipairs(PRIORITY[kind]) do if self.known[id] then return id end end
end

function Cleanses:GetChoices(kind)
    local result = {}
    if not validType(kind) then return result end
    for _, id in ipairs(PRIORITY[kind]) do
        local record = self.known and self.known[id] and self.records[id]
        if record then
            local choice = copyRecord(record)
            choice.spellID, choice.types = id, copyTypes(SPELLS[id])
            result[#result + 1] = choice
        end
    end
    return result
end

function Cleanses:GetSlots()
    local result = {}
    for _, kind in ipairs(ORDER) do
        local override = self.config and self.config.overrides[kind]
        local id = self:GetSpell(kind)
        local mode = override == false and "disabled" or (override and "manual" or "auto")
        local available = false
        for _, candidate in ipairs(PRIORITY[kind]) do
            if self.known and self.known[candidate] then available = true; break end
        end
        result[#result + 1] = { key=kind, label=kind, spellID=id,
            selectedSpellID=type(override)=="number" and override or nil,
            mode=mode, available=available, record=copyRecord(id and self.records[id]) }
    end
    return result
end

function Cleanses:GetActions()
    local result, byID = {}, {}
    for _, kind in ipairs(ORDER) do
        local id = self:GetSpell(kind)
        local record = id and self.records[id]
        if record then
            local action = byID[id]
            if not action then
                action = { key=kind, spellID=id, types={}, record=copyRecord(record) }
                result[#result + 1], byID[id] = action, action
            end
            -- Only selected types trigger the display. An explicitly disabled
            -- type stays suppressed even if another selection cures it too.
            action.types[kind] = true
        end
    end
    return result
end

function Cleanses:SetSpell(kind, id)
    if ns.InCombat() then return false, "Cleanse assignments cannot change during combat." end
    if not validType(kind) then return false, "Choose Magic, Disease, Poison, or Curse." end
    self:Refresh()
    if not self.config then return false, "Waiting for your character information." end
    if ns.IsSecret(id) then return false, "Spell information is unavailable." end
    if id ~= nil and id ~= false then
        if not integer(id) or not SPELLS[id] or not SPELLS[id][kind] then
            return false, "Choose a supported spell that removes " .. kind .. "."
        end
        if not self.known[id] then return false, "Choose a removal spell you have learned." end
        if not self.records[id] then return false, "That spell's information is still loading. Try again shortly." end
    end
    self.config.overrides[kind] = id or false
    if ns.OnCleansesChanged then ns.OnCleansesChanged() end
    return true
end

function Cleanses:Reset(kind)
    if ns.InCombat() then return false, "Cleanse assignments cannot change during combat." end
    if kind ~= nil and not validType(kind) then return false, "Choose a valid debuff type." end
    self:Refresh()
    if not self.config then return false, "Waiting for your character information." end
    if kind then self.config.overrides[kind] = nil else self.config.overrides = {} end
    if ns.OnCleansesChanged then ns.OnCleansesChanged() end
    return true
end
