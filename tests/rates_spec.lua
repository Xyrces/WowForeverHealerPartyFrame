-- Run from repository root: lua tests/rates_spec.lua
local ns = { WINDOW_SECONDS = 5 }
local hidden = {}
ns.IsSecret = function(value) return value == hidden end
local now, restricted, guid, current = 100, false, "tank", {}
GetTime = function() return now end
UnitGUID = function() return guid end
C_CombatLog = { IsCombatLogRestricted = function() return restricted end }
CombatLogGetCurrentEventInfo = function() return unpack(current) end
local registrations = 0
CreateFrame = function()
    local frame = { events = {} }
    function frame:SetScript(kind, callback) self[kind] = callback end
    function frame:RegisterEvent(event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            assert(not restricted, "Must not attempt restricted registration")
            registrations = registrations + 1
        end
        self.events[event] = true
    end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:IsEventRegistered(event) return self.events[event] or false end
    return frame
end
assert(loadfile("WowfPartyFrames/Rates.lua"))("WowfPartyFrames", ns)
local rates, helpers = ns.Rates, ns.Rates.Test
local function equal(actual, expected)
    assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function event(kind, amount, excess)
    local result = {}
    for i = 1, 25 do result[i] = 0 end
    result[2], result[8] = kind, "tank"
    local index = kind == "SWING_DAMAGE" and 12 or kind == "ENVIRONMENTAL_DAMAGE" and 13 or 15
    result[index], result[index + 1] = amount, excess
    return result
end
equal(helpers.Decode(event("SPELL_HEAL", 200, 70)).healing, 130)
equal(helpers.Decode(event("SPELL_PERIODIC_HEAL", 200, 300)).healing, 0)
for _, kind in ipairs({ "SWING_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE", "RANGE_DAMAGE", "DAMAGE_SHIELD", "DAMAGE_SPLIT", "ENVIRONMENTAL_DAMAGE" }) do
    equal(helpers.Decode(event(kind, 200, 70)).damage, 130)
    equal(helpers.Decode(event(kind, 200, -1)).damage, 200)
end
local absorbed = event("SPELL_DAMAGE", 200, -1)
absorbed[20] = 500 -- Already excluded from damage; never subtract twice.
equal(helpers.Decode(absorbed).damage, 200)
equal(helpers.Decode(event("SPELL_ABSORBED", 100, 0)), nil)
local withoutDestination = event("SPELL_CAST_START", 0, 0)
withoutDestination[8] = nil
local ignored, ignoredReason = helpers.Decode(withoutDestination)
equal(ignored, nil)
equal(ignoredReason, nil)
local _, reason = helpers.Decode(event("SPELL_HEAL", hidden, 0))
equal(reason, "Combat data restricted")
local malformed = event("SPELL_HEAL", 0 / 0, 0)
equal(select(2, helpers.Decode(malformed)), "Invalid combat data")

local stream = helpers.NewStream()
assert(helpers.Add(stream, 10, 50, 45))
helpers.Prune(stream, 14.999)
equal(stream.healing, 50)
helpers.Prune(stream, 15)
equal(stream.healing, 0)
equal(stream.damage, 0)
for _ = 1, helpers.Capacity do assert(helpers.Add(stream, 20, 1, 1)) end
equal(helpers.Add(stream, 20, 1, 1), false)
helpers.Prune(stream, 25)
equal(next(stream.entries), nil)
-- A continuously active stream compacts its indices while retaining totals.
for i = 1, helpers.Capacity * 3 do
    assert(helpers.Add(stream, 30 + i, 2, 1))
end
equal(stream.healing, 10)
assert(stream.last < helpers.Capacity * 2)

rates:SetUnits({ "party1" })
restricted = true
rates:Initialize()
equal(registrations, 0)
equal(select(4, rates:Get("party1")), "Combat data restricted")
restricted = false
equal(select(4, rates:Get("party1")), "Collecting rates")
equal(registrations, 1)
now = 104
current = event("SPELL_HEAL", 300, 50)
rates:OnCombatEvent()
current = event("SWING_DAMAGE", 250, 25)
rates:OnCombatEvent()
current = withoutDestination
rates:OnCombatEvent()
equal(rates.status, "available")
now = 105
local healing, damage, net, status = rates:Get("party1")
equal(healing, 50); equal(damage, 45); equal(net, 5); equal(status, "available")
now = 109
equal(rates:Get("party1"), 0)
restricted = true
equal(rates:Get("party1"), nil)
equal(rates.registered, false)
restricted = false
equal(select(4, rates:Get("party1")), "Collecting rates")
now = 114
equal(select(4, rates:Get("party1")), "available")
now = 90 -- Clock regression discards the old time domain.
equal(select(4, rates:Get("party1")), "Collecting rates")
now = 95
equal(select(4, rates:Get("party1")), "available")
guid = "replacement"
equal(select(4, rates:Get("party1")), "Collecting rates")
guid = hidden
equal(select(4, rates:Get("party1")), "Unit data restricted")
guid = "tank"
rates:SetUnits({ "party1" })
equal(select(4, rates:Get("party1")), "Collecting rates")
current = event("SPELL_HEAL", hidden, 0)
rates:OnCombatEvent()
equal(rates.status, "Combat data restricted")
equal(next(rates.streams), nil)
local query = C_CombatLog.IsCombatLogRestricted
C_CombatLog.IsCombatLogRestricted = nil
equal(select(4, rates:Get("party1")), "Combat log permission unknown")
C_CombatLog.IsCombatLogRestricted = query
-- A modern public reader need not have the optional deprecated global alias.
local legacyReader = CombatLogGetCurrentEventInfo
CombatLogGetCurrentEventInfo = nil
C_CombatLog.GetCurrentEventInfo = legacyReader
rates:SetUnits({"party1"})
equal(select(4, rates:Get("party1")), "Collecting rates")
now = now + 4
current = event("SPELL_HEAL", 300, 50)
rates:OnCombatEvent()
current = event("SWING_DAMAGE", 250, 25)
rates:OnCombatEvent()
now = now + 1
healing, damage, net, status = rates:Get("party1")
equal(healing, 50); equal(damage, 45); equal(net, 5); equal(status, "available")
-- Restricted modern clients can expose only the SecureOnly reader. Do not
-- call it, register restricted events, or fabricate zero from absent data.
C_CombatLog.GetCurrentEventInfo = nil
local secureReads = 0
C_CombatLogSecure = {GetCurrentEventInfo = function() secureReads=secureReads+1;error("SecureOnly API must never be called") end}
equal(select(4, rates:Get("party1")), "Client does not expose incoming combat events")
equal(rates.registered, false)
equal(rates:Get("party1"), nil)
restricted = true
local registrationsBefore = registrations
equal(select(4, rates:Get("party1")), "Combat data restricted")
equal(registrations, registrationsBefore)
equal(secureReads, 0)
restricted = false
CombatLogGetCurrentEventInfo = legacyReader
equal(select(4, rates:Get("party1")), "Collecting rates")
print("rates_spec: passed")
