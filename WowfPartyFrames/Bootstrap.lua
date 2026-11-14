local addonName, ns = ...
ns.name = addonName
ns.VERSION = "0.2.0"
ns.MAX_BUFFS = 8
ns.WINDOW_SECONDS = 5
ns.QUADRANTS = { "Top left", "Top right", "Bottom left", "Bottom right" }
ns.CLASSES = {}

local classes = {
    { "WARRIOR", "Warrior", 1 }, { "PALADIN", "Paladin", 2 },
    { "HUNTER", "Hunter", 3 }, { "ROGUE", "Rogue", 4 },
    { "PRIEST", "Priest", 5 }, { "SHAMAN", "Shaman", 7 },
    { "MAGE", "Mage", 8 }, { "WARLOCK", "Warlock", 9 }, { "DRUID", "Druid", 11 },
}
for _, class in ipairs(classes) do
    ns.CLASSES[#ns.CLASSES + 1] = {
        token = class[1], name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class[1]] or class[2], id = class[3],
    }
end

function ns.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function ns.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function ns.Print(message)
    local line = "|cffffcf70WoWf Party Frames:|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) else print(line) end
end

function ns.SetBackdrop(frame, background, border)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    local bg, edge = background or {0.05, 0.04, 0.03, 0.95}, border or {0.65, 0.55, 0.35, 1}
    frame:SetBackdropColor(unpack(bg))
    frame:SetBackdropBorderColor(unpack(edge))
end

-- pcall handles unavailable APIs; it is never used to inspect or decode secrets.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

function ns.Readable(value)
    return not ns.IsSecret(value)
end
