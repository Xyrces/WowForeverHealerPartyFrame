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

local function displayName(unit)
    if not text(unit) then return end
    -- Forever's Camelot NameUtil override treats UnitName's second return as
    -- a surname. The generic API documentation still calls it unitServer.
    -- This is display text only: secure headers retain their own hyphen keys.
    local formatter = GetUnitName or (NameUtil and NameUtil.FormatUnitNameForDisplay)
    local value = call(formatter, unit, true)
    if ns.IsSecret(value) or text(value) then return value end
    if type(UnitName) ~= "function" then return end
    local ok, first, surname = pcall(UnitName, unit)
    if not ok then return end
    if ns.IsSecret(first) then return first end
    first = text(first)
    if not first then return end
    surname = text(surname)
    if not surname then return first end
    local constants = Constants and Constants.CharacterNameSeparatorConsts
    local separator = constants and text(constants.CHARACTERNAME_SURNAME_SEPARATOR) or " "
    local suffix = separator .. surname
    -- Some compatible wrappers already return the complete display name.
    if first:sub(-#suffix) == suffix then return first end
    return first .. suffix
end

function MemberInfo:GetDisplayName(unit)
    return text(displayName(unit))
end

function MemberInfo:PaintName(font, unit)
    -- Native strings may be opaque. Forward them to the renderer without
    -- concatenation, comparison, or caching under another member's identity.
    local name = displayName(unit)
    font:SetText(name)
end

local function presence(result, unit)
    local otherParty = call(UnitInOtherParty, unit)
    if public(otherParty,"boolean") and otherParty then
        result.presenceKind, result.presenceText = "otherParty", "Other group"
        result.presenceTooltip = text(PARTY_IN_PUBLIC_GROUP_MESSAGE) or "This player is in another group."
        result.presenceAtlas, result.presenceDim = "groupfinder-eye-single", true
        return
    end
    local summon = C_IncomingSummon
    local incoming = summon and call(summon.HasIncomingSummon, unit)
    if public(incoming, "boolean") and incoming then
        local status = call(summon.IncomingSummonStatus, unit)
        local statuses = Enum and Enum.SummonStatus
        if not public(status, "number") or not statuses then return end
        if status == statuses.Pending then
            result.presenceKind, result.presenceText = "summonPending", "Summon pending"
            result.presenceAtlas = "Raid-Icon-SummonPending"
            result.presenceTooltip = text(INCOMING_SUMMON_TOOLTIP_SUMMON_PENDING) or "A summon is pending."
        elseif status == statuses.Accepted then
            result.presenceKind, result.presenceText = "summonAccepted", "Summon accepted"
            result.presenceAtlas = "Raid-Icon-SummonAccepted"
            result.presenceTooltip = text(INCOMING_SUMMON_TOOLTIP_SUMMON_ACCEPTED) or "The summon was accepted."
        elseif status == statuses.Declined then
            result.presenceKind, result.presenceText = "summonDeclined", "Summon declined"
            result.presenceAtlas = "Raid-Icon-SummonDeclined"
            result.presenceTooltip = text(INCOMING_SUMMON_TOOLTIP_SUMMON_DECLINED) or "The summon was declined."
        end
        return
    end
    local connected = call(UnitIsConnected, unit)
    if not public(connected,"boolean") or not connected then return end
    local reason = call(UnitPhaseReason, unit)
    if not public(reason,"number") then return end
    result.phaseReason = reason
    local reasons = Enum and Enum.PhaseReason or {}
    local kind, label = "phase", "Different phase"
    if reason == reasons.Sharding then kind, label = "shard", "Different shard"
    elseif reason == reasons.RuleSet then kind, label = "ruleset", "Different ruleset"
    elseif reason == reasons.WarMode then kind, label = "warMode", "Different War Mode"
    elseif reason == reasons.ChromieTime then kind, label = "chromieTime", "Different timeline"
    elseif reason == reasons.TimerunningHwt then kind, label = "worldTier", "Different world tier" end
    result.differentShard = kind == "shard"
    result.presenceKind, result.presenceText, result.presenceDim = kind, label, true
    result.presenceTexture = "Interface\\TargetingFrame\\UI-PhasingIcon"
    result.presenceTexCoord = {0.15625,0.84375,0.15625,0.84375}
    -- The native helper distinguishes which side is outside the party shard;
    -- UnitInPartyShard(false) alone does not prove these two members differ.
    result.presenceTooltip = text(call(PartyUtil and PartyUtil.GetPhasedReasonString,reason,unit)) or label
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
    result.displayName = self:GetDisplayName(unit)
    presence(result, unit)

    local level = call(UnitLevel, unit)
    result.level = positiveInteger(level) and level or nil
    result.class = text(call(UnitClass, unit))
    local roleToken = text(call(UnitGroupRolesAssigned, unit))
    -- This is the native assigned role, never inferred from class or preset.
    if roleToken == "TANK" or roleToken == "HEALER" or roleToken == "DAMAGER" then
        result.roleToken = roleToken
        local roles = {TANK=text(TANK) or "Tank", HEALER=text(HEALER) or "Healer", DAMAGER=text(DAMAGER) or "Damage"}
        result.role = roles[roleToken]
    end
    local marker = call(GetRaidTargetIndex, unit)
    -- Native Texture:SetSpriteSheetCell accepts secret numeric cells. Retain
    -- opaque values for that display path; never index a Lua table with them.
    if type(marker) == "number" and (ns.IsSecret(marker)
        or (positiveInteger(marker) and marker <= 8)) then
        result.markerIndex = marker
    end
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
