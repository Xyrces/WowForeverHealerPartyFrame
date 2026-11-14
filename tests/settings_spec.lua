-- Run from the repository root with a Lua 5.1-compatible interpreter.
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local secret = {}
local combat, changed = false, 0
local ns = {
    MAX_BUFFS = 8,
    CLASSES = { { token = "WARRIOR", name = "Warrior" }, { token = "MAGE", name = "Mage" } },
    IsSecret = function(value) return value == secret end,
    InCombat = function() return combat end,
    OnProfileChanged = function() changed = changed + 1 end,
}
local spellData = {
    [2050] = { name = "Lesser Heal", iconID = 1, spellID = 2050 },
    [2052] = { name = "Lesser Heal", iconID = 2, spellID = 2052 },
    [1243] = { name = "Power Word: Fortitude", iconID = 3, spellID = 1243 },
}
local cursor = {}
local cleared = 0
Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 } }
C_Spell = {
    GetSpellInfo = function(id) return spellData[id] end,
    GetSpellSubtext = function(id) return id == 2050 and "Rank 1" or "" end,
}
C_SpellBook = {
    GetSpellBookItemInfo = function(slot, bank)
        equal(bank, 0, "fallback uses player bank")
        if slot == 7 then return { spellID = 2052 } end
    end,
    GetSpellBookItemName = function() return "Lesser Heal", "Rank 2" end,
}
GetCursorInfo = function() return unpack(cursor) end
ClearCursor = function() cleared = cleared + 1 end
assert(loadfile("WowfPartyFrames/Profiles.lua"))("WowfPartyFrames", ns)
assert(loadfile("WowfPartyFrames/Spells.lua"))("WowfPartyFrames", ns)
assert(loadfile("WowfPartyFrames/Settings.lua"))("WowfPartyFrames", ns)

local db = ns.Profiles:Init({ position = { x = 0/0 }, scale = -1 })
equal(db, WowfPartyFramesDB)
equal(db.position.x, 16, "corrupt position repaired")
equal(db.scale, 1)
local tank = assert(ns.Profiles:Create("Tank"))
local caster = assert(ns.Profiles:Create("Caster"))
equal(ns.Profiles:GetPreset("default").heals[1], nil, "no implicit defaults")
equal(ns.Profiles:SetSpell("UNKNOWN", "heals", 1, 2050), false)
equal(ns.Profiles:SetSpell(tank, "heals", 0, 2050), false)
equal(ns.Profiles:SetSpell(tank, "heals", 1, secret), false)
equal(ns.Profiles:SetSpell(tank, "heals", 1, math.huge), false)
equal(ns.Profiles:SetSpell(tank, "heals", 1, 9999), false)
equal(ns.Profiles:SetSpell(tank, "heals", 2, 2052), true)
equal(ns.Profiles:GetSpell(tank, "heals", 2), 2052, "lower-rank ID retained")
equal(ns.Profiles:GetSpell(caster, "heals", 2), nil, "preset assignments isolated")
combat = true
equal(ns.Profiles:SetSpell(tank, "heals", 2, nil), false)
equal(ns.Profiles:GetSpell(tank, "heals", 2), 2052)
combat = false

cursor = { "spell", 7, "spell", 2050 }
local record = ns.Spells:FromCursor()
equal(record.id, 2050, "fourth return beats spellbook slot")
equal(record.rank, "Rank 1")
equal(cleared, 0, "reading cursor does not clear it")
cursor = { "spell", 7, "spell" }
record = ns.Spells:FromCursor()
equal(record.id, 2052)
equal(record.rank, "Rank 2", "spellbook subName fallback")
cursor = { "spell", 7, "unknown" }
equal(ns.Spells:FromCursor(), nil, "unknown bank must not guess slot as ID")
cursor = { "spell", 7, "pet", 2050 }
equal(ns.Spells:FromCursor(), nil)
cursor = { "item", 2050 }
equal(ns.Spells:FromCursor(), nil)
cursor = { "spell", 7, "spell", secret }
equal(ns.Spells:FromCursor(), nil)
spellData[9999] = { name = secret, iconID = 1 }
equal(ns.Spells:Get(9999), nil, "secret name rejected")
spellData[9998] = { name = "Readable", iconID = secret, originalIconID = secret }
equal(ns.Spells:Get(9998).icon, 134400, "secret icon gets safe fallback")

local note = ""
ns.Settings.presetID = tank
ns.Settings.frame = { note = { SetText = function(_, value) note = value end } }
local refreshed = 0
ns.Settings.Refresh = function() refreshed = refreshed + 1 end
local slot = { kind = "buffs", index = 1 }
cursor = { "spell", 7, "spell", 1243 }
equal(ns.Settings:Assign(slot, false), true)
equal(cleared, 1)
equal(refreshed, 1)
equal(ns.Profiles:GetSpell(tank, "buffs", 1), 1243)
combat = true
equal(ns.Settings:Assign(slot, true), false)
equal(cleared, 1, "blocked edit retains cursor")
equal(ns.Profiles:GetSpell(tank, "buffs", 1), 1243)
combat = false
cursor = { "item", 1 }
equal(ns.Settings:Assign(slot, false), false)
equal(cleared, 1, "bad drop retains cursor")
equal(ns.Settings:Assign(slot, true), true)
equal(ns.Profiles:GetSpell(tank, "buffs", 1), nil)
equal(cleared, 1, "clearing slot leaves other cursor content alone")
-- Layout regression: sparse saved buff indices must not create visual gaps,
-- and the panel must shrink again when switching to an empty preset.
local ui = assert(loadfile("tests/wow_ui_fake.lua"))()()
ui.methods.SetFont = function(self, path, size) self.fontSize = size end
local plainButton = CreateFrame("Button", nil, UIParent)
plainButton:SetNormalFontObject("GameFontHighlight")
equal(plainButton:GetFontString(), nil, "setting a font does not create a button label")
plainButton:SetText("Label")
equal(plainButton:GetFontString():GetText(), "Label", "SetText initializes the button label")
ns.SetBackdrop = function() end
ns.OnProfileChanged = nil
assert(loadfile("WowfPartyFrames/Settings.lua"))("WowfPartyFrames", ns)
ns.Profiles:Init({})
tank = assert(ns.Profiles:Create("Tank"))
caster = assert(ns.Profiles:Create("Caster"))
ns.Profiles:GetPreset(tank).buffs = { [2]=1243, [5]=1243, [8]=1243 }
ns.Settings.presetID = tank
local panel = ns.Settings:Create()
equal(panel.width, 340, "compact panel width")
equal(panel.height, 477, "one buff row plus linked history settings fits panel")
equal(ns.Settings.buffSlots[2].point[2], 17)
equal(ns.Settings.buffSlots[5].point[2], 95)
equal(ns.Settings.buffSlots[8].point[2], 173)
equal(ns.Settings.buffSlots[1].point[2], 251, "first empty index is add slot at end")
equal(ns.Settings.buffSlots[8].index, 8, "visual compression preserves saved index")
equal(ns.Settings.buffSlots[3]:IsShown(), false)
ns.Profiles:GetPreset(tank).buffs[4] = 1243
ns.Settings:Refresh()
equal(panel.height, 553, "fifth visible slot creates second row")
equal(ns.Settings.buffSlots[1].point[3], -335, "add slot wraps into next row")
ns.Profiles:GetPreset(tank).buffs[5] = nil
ns.Settings:Refresh()
equal(panel.height, 477, "clearing slot removes unused row")
equal(ns.Settings.buffSlots[8].point[2], 173, "remaining configured slots compact after clear")
ns.Settings:SelectPreset(caster)
ns.Settings:Refresh()
equal(panel.height, 477)
equal(ns.Settings.buffSlots[1]:IsShown(), true)
equal(ns.Settings.buffSlots[1].point[2], 17)
equal(ns.Settings.buffSlots[8]:IsShown(), false)
equal(ns.Settings.healSlots[1].title.fontSize, 10, "explicit compact font")
-- Management actions retain exact ranks, keep independent copies, and guard Default.
ns.Settings:SelectPreset(tank)
ns.Profiles:SetSpell(tank, "heals", 1, 2050)
equal(ns.Settings:SavePresetAction("duplicate", "Off tank"), true)
local copy = ns.Settings.presetID
equal(copy ~= tank, true)
equal(ns.Profiles:GetSpell(copy, "heals", 1), 2050)
equal(ns.Profiles:GetSpell(copy, "buffs", 8), 1243)
ns.Profiles:SetSpell(copy, "heals", 1, 2052)
equal(ns.Profiles:GetSpell(tank, "heals", 1), 2050, "duplicate does not share spell tables")
equal(ns.Settings:SavePresetAction("rename", "Backup tank"), true)
equal(panel.selector.title:GetText(), "Backup tank")
equal(ns.Settings:SavePresetAction("rename", "Tank"), false, "duplicate names rejected")
equal(ns.Settings:SavePresetAction("new", ""), false, "empty name rejected")
equal(ns.Settings:SavePresetAction("new", "Healer"), true)
equal(ns.Profiles:GetSpell(ns.Settings.presetID, "heals", 1), nil)
equal(ns.Settings:SavePresetAction("delete"), true)
equal(ns.Settings.presetID, "default")
equal(ns.Settings:SavePresetAction("delete"), false, "Default cannot be deleted")
equal(ns.Settings:SelectPreset("absent"), false)
ns.Settings:SelectPreset(copy)
combat = true
equal(ns.Settings:SavePresetAction("rename", "Cannot rename"), false)
equal(ns.Profiles:GetPreset(copy).name, "Backup tank")
combat = false
-- Management is reached through the dropdown; its confirmation targets the
-- original preset even if a refresh or selection happens before the click.
ns.Settings:PromptPresetAction("rename")
equal(ns.Settings.dialog:IsShown(), true)
ns.Settings.dialog.input:SetText("Emergency")
ns.Settings.dialog.accept:GetScript("OnClick")()
equal(ns.Profiles:GetPreset(copy).name, "Emergency")
equal(ns.Settings.dialog:IsShown(), false)
ns.Settings:PromptPresetAction("delete")
equal(ns.Settings.dialog.input:IsShown(), false)
equal(ns.Profiles:GetPreset(copy) ~= nil, true, "opening delete prompt does not delete")
ns.Settings:SelectPreset(tank)
ns.Settings.dialog.accept:GetScript("OnClick")()
equal(ns.Profiles:GetPreset(copy), nil)
equal(ns.Settings.presetID, tank, "confirmation deletes its captured preset")
-- Long lists remain bounded and navigation keeps all presets reachable.
for index = 1, 18 do assert(ns.Profiles:Create("Extra " .. index)) end
ns.Settings:SelectPreset("default")
equal(panel.menu.height <= 334, true, "dropdown stays compact")
local nextOption
for _, option in ipairs(panel.presetOptions) do
    if option:IsShown() and option.entry.page == 2 then nextOption = option end
end
equal(nextOption ~= nil, true, "more presets accessible")
nextOption:GetScript("OnClick")(nextOption)
equal(ns.Settings.menuPage, 2)
local previousOption
for _, option in ipairs(panel.presetOptions) do
    if option:IsShown() and option.entry.page == 1 then previousOption = option end
end
equal(previousOption ~= nil, true)
previousOption:GetScript("OnClick")(previousOption)
equal(ns.Settings.menuPage, 1)
ns.Settings.menuPage = 3
panel.menu:Hide()
panel.selector:GetScript("OnClick")()
equal(ns.Settings.menuPage, 1, "opening menu returns to selected preset page")
-- Tabs edit independent exact-rank layers; buffs remain shared by the preset.
ns.Settings:SelectPreset("default")
ns.Profiles:SetSpell("default", "heals", 1, 2052)
equal(ns.Settings.healLayer, "base")
panel.layerTabs.shift:GetScript("OnClick")()
equal(ns.Settings.healLayer, "shift")
equal(panel.layerTabs.shift.selected, true)
equal(panel.layerTabs.base.selected, false)
equal(ns.Settings.healSlots[1].title:GetText(), "Drop spell", "unassigned modifier stays blank")
local beforeDrop = cleared
cursor = { "spell", 7, "spell", 2050 }
ns.Settings.healSlots[1]:GetScript("OnReceiveDrag")(ns.Settings.healSlots[1])
equal(cleared, beforeDrop + 1)
equal(ns.Profiles:GetSpell("default", "heals", 1, "shift"), 2050, "shift drop preserves lower rank")
equal(ns.Profiles:GetSpell("default", "heals", 1, "base"), 2052, "shift drop cannot replace base")
equal(ns.Settings.healSlots[1].rank:GetText(), "Rank 1")
for _, layer in ipairs({"ctrl", "ctrlshift"}) do
    panel.layerTabs[layer]:GetScript("OnClick")()
    equal(ns.Settings.healSlots[1].title:GetText(), "Drop spell", "other modifier layer is empty")
end
cursor = { "spell", 8, "spell", 1243 }
ns.Settings.buffSlots[1]:GetScript("OnReceiveDrag")(ns.Settings.buffSlots[1])
equal(ns.Profiles:GetSpell("default", "buffs", 1), 1243)
ns.Settings:SelectHealLayer("base")
equal(ns.Settings.healSlots[1].icon.texture, 2, "base spell restored when selecting its tab")
equal(ns.Settings.buffSlots[1].title:GetText(), "Power Word: Fortitude", "buff survives layer switch")
equal(ns.Settings:SelectHealLayer("alt"), false)
equal(ns.Settings.healLayer, "base")
ns.Settings:SelectHealLayer("shift")
ns.Settings.healSlots[1]:GetScript("OnClick")(ns.Settings.healSlots[1], "RightButton")
equal(ns.Profiles:GetSpell("default", "heals", 1, "shift"), nil)
equal(ns.Profiles:GetSpell("default", "heals", 1, "base"), 2052)
-- Styles apply immediately outside combat and do not change spell assignments.
local calls = {}
ns.Frames = {
    ApplyProfiles = function() calls[#calls + 1] = "apply" end,
    RefreshAll = function() calls[#calls + 1] = "refresh" end,
}
equal(panel.styleButtons.buttons.selected, true)
panel.styleButtons.quadrants:GetScript("OnClick")()
equal(ns.Profiles.db.controlStyle, "quadrants")
equal(calls[1], "apply")
equal(calls[2], "refresh")
equal(panel.styleButtons.quadrants.selected, true)
equal(panel.styleButtons.buttons.selected, false)
equal(ns.Profiles:GetSpell("default", "heals", 1), 2052)
combat = true
equal(ns.Settings:SetControlStyle("buttons"), false)
equal(ns.Profiles.db.controlStyle, "quadrants")
equal(#calls, 2, "combat style attempt does not touch frames")
combat = false
equal(ns.Settings:SetControlStyle("unsupported"), false)
equal(ns.Settings:SetControlStyle("buttons"), true)
equal(ns.Profiles.db.controlStyle, "buttons")
print("settings_spec: " .. checks .. " checks passed")
