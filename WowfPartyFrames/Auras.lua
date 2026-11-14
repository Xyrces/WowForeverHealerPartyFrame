local _, ns = ...
local Auras = {}
ns.Auras = Auras

local function public(value)
    return not ns.IsSecret(value)
end

local function readableTable(value)
    return public(value) and type(value) == "table"
        and not (issecrettable and issecrettable(value))
end

local function call(fn, ...)
    if type(fn) ~= "function" then return false, nil end
    return pcall(fn, ...)
end

local function unitAvailable(unit)
    for _, fn in ipairs({UnitExists, UnitIsConnected, UnitIsVisible}) do
        local ok, value = call(fn, unit)
        if not ok or not public(value) or not value then return false end
    end
    return UnitExists ~= nil and UnitIsConnected ~= nil and UnitIsVisible ~= nil
end

local function unrestricted()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, value = call(C_Secrets.ShouldAurasBeSecret)
        return ok and public(value) and value == false
    end
    -- Without the predicate, do not declare a missing buff during combat.
    return not ns.InCombat()
end

local function entryFrom(unit, aura, instanceID)
    if not readableTable(aura) then return nil end
    local id = instanceID
    if id == nil and public(aura.auraInstanceID) then id = aura.auraInstanceID end
    local entry = {
        auraInstanceID = id, icon = aura.icon, applications = aura.applications,
        expirationTime = aura.expirationTime, duration = aura.duration,
        name = aura.name, spellId = aura.spellId,
    }
    if public(id) and type(id) == "number" and C_UnitAuras then
        local ok, duration = call(C_UnitAuras.GetAuraDuration, unit, id)
        if ok and public(duration) then entry.durationObject = duration end
        local countOK, count = call(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2)
        if countOK then entry.applicationText = count end
    end
    return entry
end

function Auras:GetDebuffs(unit, limit)
    local entries, known = {}, true
    if not unitAvailable(unit) or not C_UnitAuras then return entries, false end
    limit = type(limit) == "number" and math.max(0, math.floor(limit)) or 8
    -- Enumerate all IDs before truncating so readable Weakened Soul is not lost.
    local ok, ids = call(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HARMFUL")
    if ok and readableTable(ids) then
        for _, id in ipairs(ids) do
            if public(id) and type(id) == "number" then
                local got, aura = call(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
                local entry = got and entryFrom(unit, aura, id)
                if entry then entries[#entries + 1] = entry else known = false end
            else
                known = false
            end
        end
    elseif unrestricted() and C_UnitAuras.GetAuraDataByIndex then
        -- Older implementations may lack instance enumeration; never use a
        -- failed/secret read as the end of a known list.
        known = false
        for index = 1, 255 do
            local got, aura = call(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
            if not got or not public(aura) then break end
            if aura == nil then known = true; break end
            local entry = entryFrom(unit, aura)
            if not entry then break end
            entries[#entries + 1] = entry
        end
    else
        return entries, false
    end
    -- Engine enumeration order need not be stable between UNIT_AURA events.
    -- Every retained instance ID is public, so sorting never inspects secrets.
    table.sort(entries, function(a, b)
        local left = type(a.auraInstanceID) == "number" and a.auraInstanceID or 0
        local right = type(b.auraInstanceID) == "number" and b.auraInstanceID or 0
        return left < right
    end)
    -- Stable insertion, retaining the instance order for every other aura.
    for index = 1, #entries do
        if public(entries[index].spellId) and entries[index].spellId == 6788 then
            table.insert(entries, 1, table.remove(entries, index))
            break
        end
    end
    while #entries > limit do table.remove(entries) end
    return entries, known
end

function Auras:GetAssignedBuff(unit, spellID)
    local unknown = {state = "unknown"}
    if not public(spellID) or type(spellID) ~= "number" or spellID <= 0
        or not unitAvailable(unit) or not C_UnitAuras then return unknown end
    -- This API explicitly requires a nonsecret aura; failure is not absence.
    local ok, aura = call(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    if not ok or not public(aura) then return unknown end
    if aura == nil then
        if not unrestricted() then return unknown end
        -- Buff rank is an assignment/casting detail, not proof the buff is
        -- absent: another caster may have supplied a different rank.
        local nameOK, name = call(C_Spell and C_Spell.GetSpellName, spellID)
        if not nameOK or not public(name) or type(name) ~= "string" or name == "" then
            return unknown
        end
        local found, namedAura = call(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
        if not found or not public(namedAura) then return unknown end
        if namedAura == nil then return {state = "missing"} end
        if not readableTable(namedAura) or not public(namedAura.name)
            or namedAura.name ~= name then return unknown end
        aura = namedAura
    end
    local entry = entryFrom(unit, aura)
    if not entry then return unknown end
    -- Reject harmful spells accidentally assigned to a buff slot.
    if not public(aura.isHelpful) or aura.isHelpful ~= true then return unknown end
    return {state = "active", aura = entry}
end

function Auras:AddPrivateAnchors(parent, unit)
    local ids = {}
    if ns.InCombat() or not parent or not public(unit) or type(unit) ~= "string"
        or not C_UnitAuras then return ids end
    -- Native CompactUnitIndividualPrivateAuraAnchorMixin structure, 1.60.1.
    -- These anchors retain unitToken. Do not attach to a frame whose unit can
    -- rebind in combat unless its owner can keep the native anchors in sync.
    for index = 1, 2 do
        local ok, id = call(C_UnitAuras.AddPrivateAuraAnchor, {
            unitToken = unit, auraIndex = index, parent = parent,
            showCooldownFrame = true, showCooldownEdge = false,
            showCountdownNumbers = true, showDispelIcon = false, isContainer = false,
            iconInfo = {
                iconAnchor = {point = "TOPLEFT", relativeTo = parent,
                    relativePoint = "TOPLEFT", offsetX = 8 + (index - 1) * 26, offsetY = -88},
                iconWidth = 22, iconHeight = 22, borderScale = 1,
            },
        })
        if ok and public(id) and type(id) == "number" then ids[#ids + 1] = id end
    end
    return ids
end

function Auras:RemovePrivateAnchors(ids)
    if ns.InCombat() or not readableTable(ids) or not C_UnitAuras then return false end
    local removed = true
    for index = #ids, 1, -1 do
        local id = ids[index]
        if public(id) and type(id) == "number" and call(C_UnitAuras.RemovePrivateAuraAnchor, id) then
            table.remove(ids, index)
        else
            removed = false
        end
    end
    return removed
end

local function set(object, method, ...)
    if object and type(object[method]) == "function" then
        return pcall(object[method], object, ...)
    end
    return false
end

function Auras:Paint(button, unit, entry)
    -- Only visual region setters: never change protected visibility or actions.
    set(button.count, "SetText", "")
    set(button.timer, "SetText", "")
    set(button.cooldown, "SetHideCountdownNumbers", true)
    if not set(button.cooldown, "Clear") then set(button.cooldown, "SetCooldown", 0, 0) end
    if not entry then return end
    set(button.icon, "SetTexture", entry.icon)
    if ns.IsSecret(entry.applicationText) or entry.applicationText ~= nil then
        set(button.count, "SetText", entry.applicationText)
    elseif public(entry.applications) and type(entry.applications) == "number"
        and entry.applications > 1 then
        set(button.count, "SetText", entry.applications)
    end
    local nativeNumbers = entry.durationObject
        and (not public(entry.expirationTime) or not public(entry.duration)
            or type(entry.expirationTime) ~= "number" or type(entry.duration) ~= "number")
    if nativeNumbers then set(button.cooldown, "SetHideCountdownNumbers", false) end
    if entry.durationObject then
        set(button.cooldown, "SetCooldownFromDurationObject", entry.durationObject)
    elseif public(entry.duration) and public(entry.expirationTime)
        and type(entry.duration) == "number" and type(entry.expirationTime) == "number"
        and entry.duration > 0 then
        set(button.cooldown, "SetCooldown", entry.expirationTime - entry.duration, entry.duration)
    end
    if not nativeNumbers and public(entry.expirationTime) and type(entry.expirationTime) == "number"
        and entry.expirationTime > 0 and GetTime then
        local remaining = math.max(0, entry.expirationTime - GetTime())
        if remaining >= 60 then
            set(button.timer, "SetText", math.ceil(remaining / 60) .. "m")
        else
            set(button.timer, "SetText", tostring(math.ceil(remaining)))
        end
    end
end
