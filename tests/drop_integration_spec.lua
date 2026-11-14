-- Exercise real drop -> profile notification -> frame refresh -> settings repaint.
-- Secure header behavior remains simulated; this is not an in-client input test.
local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
state.units.player = {guid="healer",name="Healer",class="PRIEST"}
local ns, checks = {}, 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function load(name) assert(loadfile("WowfPartyFrames/" .. name .. ".lua"))("WowfPartyFrames", ns) end
local cursor, cleared = {}, 0
local spells = {
    [2050] = { name = "Lesser Heal", iconID = 100, spellID = 2050 },
    [2052] = { name = "Lesser Heal", iconID = 101, spellID = 2052 },
    [1243] = { name = "Power Word: Fortitude", iconID = 102, spellID = 1243 },
}
Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 } }
C_Spell = {
    GetSpellInfo = function(id) return spells[id] end,
    GetSpellSubtext = function(id) return id == 2052 and "Rank 2" or "Rank 1" end,
}
GetCursorInfo = function() return unpack(cursor) end
ClearCursor = function() cleared = cleared + 1; cursor = {} end
IsLoggedIn = function() return true end
load("Bootstrap")
load("Profiles")
load("Assignments")
load("Spells")
ns.Rates = { Initialize = function() end, SetUnits = function() end, Tick = function() end,
    Get = function() return 0, 0, 0 end }
ns.Auras = { GetDebuffs = function() return {}, true end,
    GetAssignedBuff = function() return { state = "missing" } end, Paint = function() end }
load("FrameVisuals")
load("Frames")
load("Settings")
ns.PresetMenus = { Initialize=function() end, RefreshPrompts=function() end, Update=function() end }
local minimapEntries = {}
AddonCompartmentFrame = {RegisterAddon = function(_, entry)
    minimapEntries[#minimapEntries + 1] = entry
end}
load("Minimap")
load("Core")
state.subgroupCount = 0
state.emit("ADDON_LOADED", "WowfPartyFrames")
state.emit("PLAYER_ENTERING_WORLD", false, false)
equal(ns.started, true, "settings menu construction completes startup")
equal(#minimapEntries, 1, "startup registers settings in native minimap menu")
minimapEntries[1].func()
equal(ns.Settings.frame:IsShown(), true, "minimap entry opens real settings")
minimapEntries[1].func()
equal(ns.Settings.frame:IsShown(), false, "minimap entry uses the normal settings toggle")
SlashCmdList.WOWFPARTYFRAMES("")
equal(ns.Settings.frame:IsShown(), true, "bare /wpf opens settings after startup")
local firstOption = ns.Settings.frame.presetOptions[1]
equal(firstOption:GetFontString():GetText(), "Default", "menu label exists and displays the preset")
equal(firstOption.check ~= nil, true, "pooled menu row is fully initialized")
SlashCmdList.WOWFPARTYFRAMES("")
equal(ns.Settings.frame:IsShown(), false, "bare /wpf can close settings too")
SlashCmdList.WOWFPARTYFRAMES("settings")
SlashCmdList.WOWFPARTYFRAMES("test")
equal(MouseIsOver, nil, "obsolete global is absent like Forever")
equal(ns.Settings.frame:IsShown(), true)
equal(ns.Frames.preview:IsShown(), true)
local heal, buff = ns.Settings.healSlots[1], ns.Settings.buffSlots[1]
cursor = { "spell", 7, "spell", 2052 }
heal:GetScript("OnReceiveDrag")(heal)
equal(ns.Profiles:GetSpell("default", "heals", 1), 2052, "exact dragged rank saved")
equal(cleared, 1, "profile callback completes before cursor clears")
equal(heal.icon.texture, 101, "drop repaints healing icon")
equal(heal.title:GetText(), "Lesser Heal")
equal(heal.rank:GetText(), "Rank 2")
local previewHeal = ns.Frames.preview.cards[1].heals[1]
equal(previewHeal.spellID, 2052, "open preview updates chosen preset immediately")
equal(previewHeal.icon.texture, 101)
equal(previewHeal.rank:GetText(), "R2")
equal(previewHeal:GetAttribute("type1"), nil, "preview remains noncasting")
cursor = { "spell", 8, "spell", 1243 }
buff:GetScript("OnReceiveDrag")(buff)
equal(ns.Profiles:GetSpell("default", "buffs", 1), 1243)
equal(cleared, 2)
equal(buff.icon.texture, 102)
equal(buff.title:GetText(), "Power Word: Fortitude")
equal(ns.Settings.buffSlots[2]:IsShown(), true, "next buff slot becomes available")
-- Repeat against an actual live card so both refresh branches run without the global.
state.units.party1 = { name = "Tank", class = "WARRIOR", guid = "tank",
    health = 50, maxHealth = 100, power = 20, maxPower = 100 }
state.subgroupCount = 1
state.emit("GROUP_ROSTER_UPDATE")
local card = ns.Frames.cards[1]
state.hover = card.portraitArea
cursor = { "spell", 9, "spell", 2050 }
heal:GetScript("OnClick")(heal, "LeftButton")
equal(cleared, 3)
equal(ns.Profiles:GetSpell("default", "heals", 1), 2050)
equal(heal.rank:GetText(), "Rank 1", "click placement preserves lower rank")
equal(heal.icon.texture, 100)
equal(card.heals[1]:GetAttribute("spell1"), 2050, "profile notification updates live casting ID")
equal(card.heals[1].icon:GetAlpha(), 1, "native hover method reveals configured heal")
equal(card.buffs[1]:GetAttribute("spell"), 1243, "saved buff binds to live recipient")
cursor = { "item", 123 }
heal:GetScript("OnReceiveDrag")(heal)
equal(cleared, 3, "invalid drops retain cursor")
equal(ns.Profiles:GetSpell("default", "heals", 1), 2050)
equal(heal.icon.texture, 100, "invalid drop preserves displayed assignment")
state.combat = true
cursor = { "spell", 7, "spell", 2052 }
heal:GetScript("OnReceiveDrag")(heal)
equal(cleared, 3, "combat drops retain cursor")
equal(ns.Profiles:GetSpell("default", "heals", 1), 2050)
equal(heal.icon.texture, 100)
local secretHover, oldSecretCheck = {}, ns.IsSecret
ns.IsSecret = function(value) return value == secretHover or oldSecretCheck(value) end
card.portraitArea.IsMouseOver = function() return secretHover end
ns.Frames:RefreshAll(false)
equal(card.heals[1].icon:GetAlpha(), 0, "restricted hover value is not used as a boolean")
card.portraitArea.IsMouseOver = nil
ns.IsSecret = oldSecretCheck
equal(#state.violations, 0)
-- Deleting the preset being edited must select Default before preview repaint.
state.combat = false
state.units.party1 = nil
state.subgroupCount = 0
state.emit("GROUP_ROSTER_UPDATE")
SlashCmdList.WOWFPARTYFRAMES("test")
equal(ns.Frames.preview:IsShown(), true)
local otherID = assert(ns.Profiles:Create("Different heal"))
assert(ns.Profiles:SetSpell(otherID, "heals", 1, 2052))
ns.Settings:SelectPreset(otherID)
equal(previewHeal.spellID, 2052)
equal(ns.Settings:SavePresetAction("delete"), true)
equal(ns.Settings.presetID, "default")
equal(ns.Settings.frame.selector.title:GetText(), "Default")
equal(previewHeal.spellID, 2050, "deleted selection immediately repaints Default spells")
equal(previewHeal.icon.texture, 100)
equal(ns.Frames.preview.cards[1].buffs[1].spellID, 1243)
-- Real drop callbacks edit only the selected modifier layer, including exact ranks.
ns.Settings:SelectHealLayer("shift")
equal(heal.title:GetText(), "Drop spell", "new modifier layer is genuinely empty")
local layerDropCount = cleared
cursor = { "spell", 7, "spell", 2052 }
heal:GetScript("OnReceiveDrag")(heal)
equal(cleared, layerDropCount + 1)
equal(ns.Profiles:GetSpell("default", "heals", 1, "shift"), 2052)
equal(ns.Profiles:GetSpell("default", "heals", 1, "base"), 2050)
equal(heal.rank:GetText(), "Rank 2")
ns.Settings:SelectHealLayer("ctrl")
cursor = { "spell", 7, "spell", 2050 }
heal:GetScript("OnReceiveDrag")(heal)
equal(cleared, layerDropCount + 2)
equal(ns.Profiles:GetSpell("default", "heals", 1, "ctrl"), 2050, "lower-rank ctrl assignment retained")
equal(ns.Profiles:GetSpell("default", "heals", 1, "shift"), 2052)
equal(heal.rank:GetText(), "Rank 1")
ns.Settings:SelectHealLayer("ctrlshift")
equal(heal.title:GetText(), "Drop spell", "combined modifier has no inherited spell")
equal(ns.Profiles:GetSpell("default", "buffs", 1), 1243, "buff assignment independent of healing layers")
ns.Settings:SelectHealLayer("base")
equal(ns.Settings:SetControlStyle("quadrants"), true)
equal(ns.db.controlStyle, "quadrants")
equal(ns.Settings:SetControlStyle("buttons"), true)
equal(ns.db.controlStyle, "buttons")
print("drop_integration_spec: " .. checks .. " checks passed")
