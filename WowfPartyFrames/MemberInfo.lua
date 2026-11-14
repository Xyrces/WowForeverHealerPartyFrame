local _, ns = ...
local MemberInfo = {}
ns.MemberInfo = MemberInfo

local function public(value, kind)
    return not ns.IsSecret(value) and type(value) == kind
end
local function text(value)
    return public(value, "string") and value ~= "" and value or nil
end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function positiveInteger(value)
    return public(value, "number") and value > 0 and value < math.huge and value == math.floor(value)
end
local function record(value)
    if not public(value, "table") then return false end
    if canaccesstable then return canaccesstable(value) end
    return not (issecrettable and issecrettable(value))
end

local function zone(unit)
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    local dungeonType = Enum and Enum.UIMapType and Enum.UIMapType.Dungeon
    if not public(zoneType, "number") or not C_Map then return end
    local id = call(C_Map.GetBestMapForUnit, unit)
    local seen, result, dungeon = {}, nil, nil
    -- Floors share their enclosing dungeon; a dungeon remains distinct from
    -- its outdoor zone. Missing/cyclic ancestry proves neither identity.
    for _ = 1, 32 do
        if not positiveInteger(id) or seen[id] then return end
        seen[id] = true
        local info = call(C_Map.GetMapInfo, id)
        if not record(info) or not public(info.mapType, "number") then return end
        if public(dungeonType, "number") and info.mapType == dungeonType then
            local name = text(info.name)
            if not name then return end
            dungeon = {id = id, name = name}
        elseif info.mapType == zoneType then
            local name = text(info.name)
            if not name then return end
            result = {id = id, name = name}
        elseif info.mapType < zoneType then
            return dungeon or result
        end
        local parent = info.parentMapID
        if public(parent, "number") and parent == 0 then return dungeon or result end
        id = parent
    end
end

function MemberInfo:Get(unit, presetID)
    local result = {summary = "", preset = "Default"}
    local preset = ns.Profiles and call(ns.Profiles.GetPreset, ns.Profiles,
        text(presetID) or "default")
    if record(preset) then result.preset = text(preset.name) or result.preset end
    if not text(unit) then return result end
    local exists = call(UnitExists, unit)
    if public(exists, "boolean") and not exists then return result end

    local level = call(UnitLevel, unit)
    result.level = positiveInteger(level) and level or nil
    result.class = text(call(UnitClass, unit))
    local roleToken = text(call(UnitGroupRolesAssigned, unit))
    local roles = {TANK = text(TANK) or "Tank", HEALER = text(HEALER) or "Healer",
        DAMAGER = text(DAMAGER) or "Damage"}
    result.role = roleToken and roles[roleToken] or nil
    local identity = {}
    if result.level then identity[#identity + 1] = tostring(result.level) end
    if result.class then identity[#identity + 1] = result.class end
    result.summary = table.concat(identity, " ")
    if result.role then
        result.summary = result.summary ~= "" and (result.summary .. " · " .. result.role) or result.role
    end
    local memberZone, playerZone = zone(unit), zone("player")
    if memberZone and playerZone and memberZone.id ~= playerZone.id then
        result.location = memberZone.name
    end
    return result
end
