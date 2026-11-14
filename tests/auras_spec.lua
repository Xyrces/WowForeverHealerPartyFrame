-- Run from repository root with Lua 5.1 or newer.
local secret = setmetatable({}, {
    __lt = function() error("secret comparison") end,
    __le = function() error("secret comparison") end,
    __sub = function() error("secret arithmetic") end,
    __concat = function() error("secret concatenation") end,
})
local ns = {IsSecret = function(value) return rawequal(value, secret) end}
local secretRecords, forbiddenRecords = {}, {}
issecrettable = function(value) return secretRecords[value] == true end
canaccesstable = function(value) return forbiddenRecords[value] ~= true end
local combat, visible, restricted = false, true, false
ns.InCombat = function() return combat end
UnitExists = function() return true end
UnitIsConnected = function() return true end
UnitIsVisible = function() return visible end
GetTime = function() return 100 end
C_Secrets = {ShouldAurasBeSecret = function() return restricted end}
C_Spell = {GetSpellName = function() return "test" end}
local auras, ids, buff, fail = {}, {}, nil, false
C_UnitAuras = {
    GetUnitAuraInstanceIDs = function() if fail then error("restricted") end return ids end,
    GetAuraDataByAuraInstanceID = function(_, id) return auras[id] end,
    GetUnitAuraBySpellID = function() if fail then error("restricted") end return buff end,
    GetAuraDataBySpellName = function() return nil end,
    GetAuraDuration = function() return {native = true} end,
    GetAuraApplicationDisplayCount = function() return secret end,
}
assert(loadfile("WowfPartyFrames/Auras.lua"))("WowfPartyFrames", ns)
local A = ns.Auras
local function eq(actual, expected) assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected)) end
local function aura(id, spell)
    return {auraInstanceID=id, spellId=spell, icon=123, applications=2,
        duration=30, expirationTime=120, name="test", isHelpful=true}
end
eq(A:GetAssignedBuff("party1", 10).state, "missing")
restricted, combat = true, true
eq(A:GetAssignedBuff("party1", 10).state, "unknown")
buff = secret
eq(A:GetAssignedBuff("party1", 10).state, "unknown")
buff = aura(1, 10)
eq(A:GetAssignedBuff("party1", 10).state, "active")
visible = false
eq(A:GetAssignedBuff("party1", 10).state, "unknown")
visible, fail = true, true
eq(A:GetAssignedBuff("party1", 10).state, "unknown")
local list, known = A:GetDebuffs("party1", 8)
eq(#list, 0); eq(known, false)
fail = false
ids = {1, 2, 3}
auras = {[1]=aura(1, 10), [2]=aura(2, 6788), [3]=aura(3, 20)}
list, known = A:GetDebuffs("party1", 2)
eq(known, true); eq(#list, 2); eq(list[1].spellId, 6788); eq(list[2].spellId, 10)
auras[2] = secret
list, known = A:GetDebuffs("party1", 8)
eq(known, false); eq(#list, 2)
auras[1].spellId = secret
auras[1].duration = secret
auras[1].expirationTime = secret
auras[1].icon = secret
list = A:GetDebuffs("party1", 8)
local painted = {}
local button = {
    icon={SetTexture=function(_, value) painted.icon=value end},
    count={SetText=function(_, value) painted.count=value end},
    timer={SetText=function(_, value) painted.timer=value end},
    cooldown={Clear=function() painted.cleared=true end,
        SetHideCountdownNumbers=function(_, value) painted.hideNativeNumbers=value end,
        SetCooldownFromDurationObject=function(_, value) painted.duration=value end,
        SetCooldown=function() error("must use native duration") end},
}
A:Paint(button, "party1", list[1])
assert(rawequal(painted.icon, secret)); assert(rawequal(painted.count, secret))
eq(painted.timer, ""); eq(painted.duration.native, true)
eq(painted.hideNativeNumbers, false)
A:Paint(button, "party1", {durationObject={}, duration=30, expirationTime=120})
eq(painted.hideNativeNumbers, true); eq(painted.timer, "20")
A:Paint(button, "party1", nil)
eq(painted.count, ""); eq(painted.timer, ""); eq(painted.cleared, true)
restricted, combat, buff = false, false, aura(1, 10)
buff.isHelpful = secret
eq(A:GetAssignedBuff("party1", 10).state, "unknown")
buff = nil
C_UnitAuras.GetAuraDataBySpellName = function() return aura(4, 999) end
eq(A:GetAssignedBuff("party1", 10).state, "active")
C_UnitAuras.GetAuraDataBySpellName = function() return secret end
eq(A:GetAssignedBuff("party1", 10).state, "unknown")
local anchorArgs = {}
C_UnitAuras.AddPrivateAuraAnchor = function(args)
    anchorArgs[#anchorArgs + 1] = args
    return #anchorArgs
end
C_UnitAuras.RemovePrivateAuraAnchor = function(id) assert(id == 1 or id == 2) end
local privateIDs = A:AddPrivateAnchors({}, "party1")
eq(#privateIDs, 2); eq(anchorArgs[2].iconInfo.iconAnchor.offsetX, 34)
eq(anchorArgs[1].unitToken, "party1")
combat = true
eq(#A:AddPrivateAnchors({}, "party1"), 0)
eq(A:RemovePrivateAnchors(privateIDs), false); eq(#privateIDs, 2)
combat = false
eq(A:RemovePrivateAnchors(privateIDs), true); eq(#privateIDs, 0)

-- Combat visibility hints and secret record contents must not suppress aura
-- data that the native API permits us to forward to display setters.
combat, restricted = true, true
UnitIsVisible = function() return secret end
UnitIsConnected = function() return secret end
ids = {71}
local opaque = aura(71, 6788)
opaque.spellId, opaque.icon = secret, secret
opaque.duration, opaque.expirationTime = secret, secret
secretRecords[opaque] = true
auras = {[71] = opaque}
list, known = A:GetDebuffs("party1", 8)
eq(known, true); eq(#list, 1)
eq(list[1].auraInstanceID, 71)
painted.cleared = false
A:Paint(button, "party1", list[1])
assert(rawequal(painted.icon, secret))
eq(painted.duration.native, true); eq(painted.hideNativeNumbers, false)
eq(painted.cleared, false) -- no clearing/restarting the sweep every display tick
forbiddenRecords[opaque] = true
list, known = A:GetDebuffs("party1", 8)
eq(known, false); eq(#list, 0)
forbiddenRecords[opaque] = nil

local requestedFilter
C_UnitAuras.GetUnitAuraInstanceIDs = function(_, filter)
    requestedFilter = filter
    return ids
end
list, known = A:GetHelpfulAuras("party1", 8)
eq(requestedFilter, "HELPFUL"); eq(known, true); eq(#list, 1)
eq(list[1].auraInstanceID, 71)
-- An opaque helpful icon does not prove that a configured buff is active.
buff = nil
eq(A:GetAssignedBuff("party1", 10).state, "unknown")

-- The by-index fallback can forward permitted display data in combat too.
C_UnitAuras.GetUnitAuraInstanceIDs = nil
C_UnitAuras.GetAuraDataByIndex = function(_, index, filter)
    eq(filter, "HARMFUL")
    if index == 1 then return opaque end
end
list, known = A:GetDebuffs("party1", 8)
eq(known, true); eq(#list, 1)
eq(list[1].auraInstanceID, 71)
UnitIsVisible = function() return false end
list, known = A:GetDebuffs("party1", 8)
eq(known, false); eq(#list, 0)
print("auras_spec: passed")
