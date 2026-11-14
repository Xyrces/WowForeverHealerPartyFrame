local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local frames, toggles, combat = {}, 0, false
CreateFrame = function(kind)
    equal(kind, "Frame", "only an invisible event listener is created")
    local frame = {events = {}, scripts = {}}
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
local function newModule()
    local ns = {Settings = {Toggle = function()
        toggles = toggles + 1
        -- The settings entry point owns combat policy, not the minimap menu.
        return combat
    end}}
    assert(loadfile("WowfPartyFrames/Minimap.lua"))("WowfPartyFrames", ns)
    return ns.Minimap
end
local entries = {}
local function compartment()
    return {RegisterAddon = function(self, entry)
        entries[#entries + 1] = entry
    end}
end

AddonCompartmentFrame = compartment()
local immediate = newModule()
equal(immediate:Initialize(), true, "available native menu registers immediately")
equal(#entries, 1)
equal(#frames, 0, "ready API needs no listener or standalone button")
equal(entries[1].text, "WoW Forever Party Frames")
equal(type(entries[1].icon), "string")
equal(entries[1].notCheckable, true)
entries[1].func({}, {buttonName = "LeftButton"}, {})
equal(toggles, 1, "native menu callback opens settings")
combat = true
entries[1].func()
equal(toggles, 2, "combat uses existing settings behavior")
equal(immediate:Initialize(), true)
equal(immediate:Register(), true)
equal(#entries, 1, "repeated initialization never duplicates entry")

AddonCompartmentFrame = nil
local delayed = newModule()
equal(delayed:Initialize(), false)
equal(#frames, 1)
local waiter = frames[1]
equal(waiter.events.ADDON_LOADED, true)
equal(waiter.events.PLAYER_LOGIN, true)
equal(waiter.events.PLAYER_ENTERING_WORLD, true)
equal(delayed:Initialize(), false)
equal(#frames, 1, "repeated attempts reuse event listener")
waiter.scripts.OnEvent(waiter, "ADDON_LOADED", "UnrelatedAddon")
equal(#entries, 1, "unavailable API does not register")
AddonCompartmentFrame = {}
waiter.scripts.OnEvent(waiter, "PLAYER_LOGIN")
equal(#entries, 1, "frame without its API is not ready")
AddonCompartmentFrame = compartment()
local event = waiter.scripts.OnEvent
event(waiter, "ADDON_LOADED", "Blizzard_Minimap")
equal(#entries, 2, "late native API receives one entry")
equal(delayed.registered, true)
equal(next(waiter.events), nil, "successful registration stops listening")
equal(waiter.scripts.OnEvent, nil)
event(waiter, "PLAYER_ENTERING_WORLD")
equal(delayed:Initialize(), true)
equal(#entries, 2, "queued events cannot duplicate entry")
entries[2].func()
equal(toggles, 3)
print("minimap_spec: " .. checks .. " checks passed")
