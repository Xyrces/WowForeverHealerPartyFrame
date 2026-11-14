local _, ns = ...
local Minimap = {}
ns.Minimap = Minimap

function Minimap:Register()
    if self.registered then return true end
    local compartment = AddonCompartmentFrame
    if not compartment or type(compartment.RegisterAddon) ~= "function" then return false end

    compartment:RegisterAddon({
        text = "WoW Forever Party Frames",
        icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing_02",
        notCheckable = true,
        func = function()
            -- Use the same settings entry point as /wpf, including its combat lock.
            ns.Settings:Toggle()
        end,
    })
    self.registered = true
    if self.events then
        self.events:UnregisterAllEvents()
        self.events:SetScript("OnEvent", nil)
    end
    return true
end

function Minimap:Initialize()
    if self:Register() then return true end
    if not self.events then
        -- Some UI replacements load the native compartment later. Wait for it
        -- without creating another minimap button or polling every frame.
        self.events = CreateFrame("Frame")
        self.events:RegisterEvent("ADDON_LOADED")
        self.events:RegisterEvent("PLAYER_LOGIN")
        self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.events:SetScript("OnEvent", function() self:Register() end)
    end
    return false
end
