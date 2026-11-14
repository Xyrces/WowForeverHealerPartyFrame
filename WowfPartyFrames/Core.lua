local addonName, ns = ...
local events = CreateFrame("Frame")
ns.events = events
local elapsedDisplay, elapsedAuras = 0, 0

local function start()
    if ns.started or ns.InCombat() then return end
    ns.db = ns.Profiles:Init(WowfPartyFramesDB)
    ns.Assignments:Init(ns.db)
    if ns.worldSeen then ns.Assignments:BeginSession(ns.isReloadingUI) end
    ns.Rates:Initialize()
    if not ns.Frames:Create() then return end
    ns.Settings:Create()
    ns.PresetMenus:Initialize()
    ns.started = true
    ns.Frames:SetBlizzardVisible(ns.db.showBlizzard == true)
    ns.Print("Loaded. /wpf edits presets; right-click a party frame to assign one.")
end

function ns.OnProfileChanged()
    ns.Assignments:PrunePresets()
    ns.Settings:Refresh()
    ns.Frames:ApplyProfiles()
    ns.Frames:RefreshAll(true)
    ns.PresetMenus:RefreshPrompts()
end

local function report(ok, message)
    if not ok and message then ns.Print(message) end
end

SLASH_WOWFPARTYFRAMES1 = "/wpf"
SLASH_WOWFPARTYFRAMES2 = "/wowfpartyframes"
SlashCmdList.WOWFPARTYFRAMES = function(input)
    if not ns.started then
        ns.Print("Waiting for combat to end before creating secure party frames.")
        return
    end
    local command = (input or ""):match("^%s*(.-)%s*$"):lower()
    if command == "" or command == "settings" then ns.Settings:Toggle()
    elseif command == "unlock" then report(ns.Frames:SetUnlocked(true))
    elseif command == "lock" then report(ns.Frames:SetUnlocked(false))
    elseif command == "reset" then report(ns.Frames:ResetPosition())
    elseif command == "test" then report(ns.Frames:TogglePreview())
    elseif command == "blizzard" then
        local visible = not ns.db.showBlizzard
        local ok, reason = ns.Frames:SetBlizzardVisible(visible)
        report(ok, reason)
        if ok then ns.Print("Default party frames " .. (visible and "shown." or "hidden.")) end
    elseif command == "status" then
        local version, build, _, interface = GetBuildInfo()
        ns.Print("v" .. ns.VERSION .. "; client " .. version .. " (" .. build .. "), interface " .. interface .. ".")
        ns.Rates:Tick()
        ns.Print("Combat rates: " .. ns.Rates.status .. "; rolling window: 5 seconds.")
        if ns.Frames.pendingRoster then ns.Print("New party members will appear after combat ends.") end
    else
        ns.Print("/wpf, /wpf test, /wpf unlock, /wpf lock, /wpf reset, /wpf blizzard, /wpf status")
    end
end

events:SetScript("OnEvent", function(_, event, name, second)
    if event == "PLAYER_ENTERING_WORLD" then
        ns.worldActive = true
        if not ns.worldSeen then ns.isReloadingUI = second == true end
        ns.worldSeen = true
        start()
        if ns.started then
            ns.Assignments:BeginSession(ns.isReloadingUI)
            ns.Frames:RefreshRoster()
        end
        return
    end
    if event == "PLAYER_LEAVING_WORLD" then
        ns.worldActive = false
        if ns.started then ns.PresetMenus:RefreshPrompts() end
        return
    end
    if event == "ADDON_LOADED" then
        if name == addonName then
            events:UnregisterEvent("ADDON_LOADED")
            if IsLoggedIn and IsLoggedIn() then start() end
        end
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        start()
        if ns.started then
            if ns.worldSeen then ns.Assignments:BeginSession(ns.isReloadingUI) end
            if ns.Frames.positionDirty then ns.Frames:SavePosition() end
            ns.Frames:RefreshRoster()
            if ns.Frames.unlocked then ns.Frames:SetUnlocked(true) end
            ns.Settings:Refresh()
        end
    elseif ns.started then
        if event == "PLAYER_REGEN_DISABLED" then
            ns.Frames:StopMoving()
            ns.Frames.mover:Hide()
            if ns.Frames.preview then ns.Frames.preview:Hide() end
            ns.PresetMenus:RefreshPrompts()
        elseif event == "GROUP_ROSTER_UPDATE"
            or (event == "UNIT_NAME_UPDATE" and not ns.IsSecret(name)
                and type(name) == "string" and name:match("^party[1-4]$")) then
            ns.Frames:RefreshRoster()
        elseif event == "SPELLS_CHANGED" or event == "SPELL_TEXT_UPDATE" then
            ns.Frames:ApplyProfiles()
        end
        elapsedAuras = 1
    end
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if not ns.started then return end
    elapsedDisplay, elapsedAuras = elapsedDisplay + elapsed, elapsedAuras + elapsed
    if elapsedDisplay < 0.1 then return end
    ns.PresetMenus:Update(elapsedDisplay)
    elapsedDisplay = 0
    local refreshAuras = elapsedAuras >= 0.25
    if refreshAuras then elapsedAuras = 0 end
    ns.Frames:RefreshAll(refreshAuras)
end)

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE", "UNIT_NAME_UPDATE", "UNIT_AURA", "SPELLS_CHANGED", "SPELL_TEXT_UPDATE"}) do
    events:RegisterEvent(event)
end
