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
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

function Spells:Get(id)
    if not spellID(id) then return nil end
    local info = call(C_Spell and C_Spell.GetSpellInfo, id)
    if not readable(info, "table") or not readable(info.name, "string") or info.name == "" then return nil end
    local rank = call(C_Spell.GetSpellSubtext, id)
    local icon = info.originalIconID
    if not readable(icon, "number") and not readable(icon, "string") then icon = info.iconID end
    if not readable(icon, "number") and not readable(icon, "string") then icon = 134400 end
    return { id = id, name = info.name, rank = readable(rank, "string") and rank or "", icon = icon }
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
    return record
end
