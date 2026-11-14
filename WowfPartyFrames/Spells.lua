local _, ns = ...
local Spells = {}
ns.Spells = Spells

local function readable(value, kind)
    return not ns.IsSecret(value) and type(value) == kind
end
local function spellID(value)
    return readable(value, "number") and value > 0 and value < math.huge and value == math.floor(value)
end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end
local QUESTION = 134400
local function iconID(value)
    if readable(value, "number") then return spellID(value) and value ~= QUESTION end
    if readable(value, "string") and value ~= "" then
        return value:lower() ~= "interface\\icons\\inv_misc_questionmark"
    end
    return false
end
local function copy(record)
    if record then return {id=record.id, name=record.name, rank=record.rank, icon=record.icon} end
end
local function remember(self, id, name, rank, icon)
    self.cache = self.cache or {}
    local old = self.cache[id]
    if not readable(name, "string") or name == "" then name = old and old.name end
    if not name then return nil end
    if not readable(rank, "string") or rank == "" then rank = old and old.rank or "" end
    if not iconID(icon) then icon = old and old.icon or QUESTION end
    local record = {id=id, name=name, rank=rank, icon=icon}
    self.cache[id] = record
    return copy(record)
end

function Spells:Get(id)
    if not spellID(id) then return nil end
    local cached = self.cache and self.cache[id]
    -- Runtime presentation must keep reliable spellbook metadata instead of
    -- replacing it with a question mark when combat restricts spell queries.
    if ns.InCombat() and cached then return copy(cached) end
    local info = call(C_Spell and C_Spell.GetSpellInfo, id)
    if not readable(info, "table") then return copy(cached) end
    local icon = iconID(info.originalIconID) and info.originalIconID or info.iconID
    local rank = call(C_Spell and C_Spell.GetSpellSubtext, id)
    if ns.InCombat() then
        if not readable(info.name, "string") or info.name == "" then return nil end
        return {id=id, name=info.name, rank=readable(rank,"string") and rank or "",
            icon=iconID(icon) and icon or QUESTION}
    end
    return remember(self, id, info.name, rank, icon)
end

-- Warm metadata from the player's public spellbook, never from combat auras.
-- All ranks with the same localized spell name form one display-only family;
-- secure casting continues to use the exact ID assigned to the button.
function Spells:RefreshCache()
    if ns.InCombat() then return false end
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local count = call(book and book.GetNumSpellBookSkillLines)
    if not readable(bank,"number") or not readable(count,"number")
        or count < 0 or count > 128 or count ~= math.floor(count) then return false end
    for line = 1, count do
        local skill = call(book.GetSpellBookSkillLineInfo, line)
        if readable(skill,"table") then
            local offset, slots = skill.itemIndexOffset, skill.numSpellBookItems
            if readable(offset,"number") and readable(slots,"number") and offset >= 0 and offset <= 10000
                and slots >= 0 and slots <= 10000 and offset == math.floor(offset) and slots == math.floor(slots) then
                for slot = offset + 1, offset + slots do
                    local info = call(book.GetSpellBookItemInfo, slot, bank)
                    if readable(info,"table") and spellID(info.spellID) then
                        local id = info.spellID
                        self:Get(id)
                        remember(self, id, info.name, info.subName, info.iconID)
                    end
                end
            end
        end
    end
    self.bookScanned = true
    return true
end

function Spells:GetAuraSpellIDs(id)
    local ids = {}
    if not spellID(id) then return ids end
    ids[id] = true
    if not self.bookScanned and not ns.InCombat() then self:RefreshCache() end
    local selected = self:Get(id)
    if selected then
        for knownID, record in pairs(self.cache or {}) do
            if record.name == selected.name then ids[knownID] = true end
        end
    end
    return ids
end

local function playerBank(bank)
    if ns.IsSecret(bank) then return nil end
    local enum = Enum and Enum.SpellBookSpellBank
    if not enum then return nil end
    if bank == "spell" or bank == enum.Player then return enum.Player end
    -- Pet spellbook slots are deliberately not assigned to friendly party controls.
    return nil
end

function Spells:FromCursor()
    if ns.InCombat() then return nil, "Assignments cannot change during combat." end
    if not GetCursorInfo then return nil, "Spell dragging is unavailable." end
    local ok, kind, slot, bank, id = pcall(GetCursorInfo)
    if not ok or not readable(kind, "string") or kind ~= "spell" then
        return nil, "Drag a spell from your spellbook here."
    end
    if ns.IsSecret(id) or ns.IsSecret(slot) or ns.IsSecret(bank) then
        return nil, "Spell information is unavailable."
    end
    local resolvedBank = playerBank(bank)
    if bank == "pet" or (Enum and Enum.SpellBookSpellBank and bank == Enum.SpellBookSpellBank.Pet) then
        return nil, "Choose one of your own spells."
    end
    if not spellID(id) and spellID(slot) and resolvedBank then
        local info = call(C_SpellBook and C_SpellBook.GetSpellBookItemInfo, slot, resolvedBank)
        if readable(info, "table") and spellID(info.spellID) then id = info.spellID end
    end
    local record = self:Get(id)
    if not record then return nil, "That spell is unavailable. Try dragging it again." end
    if record.rank == "" and spellID(slot) and resolvedBank then
        local info = call(C_SpellBook and C_SpellBook.GetSpellBookItemInfo, slot, resolvedBank)
        if readable(info, "table") and spellID(info.spellID) and info.spellID == id then
            local _, rank = call(C_SpellBook.GetSpellBookItemName, slot, resolvedBank)
            if readable(rank, "string") then record.rank = rank end
        end
    end
    if record.rank ~= "" and self.cache and self.cache[id] then
        self.cache[id].rank = record.rank
    end
    return record
end
