-- Lifecycle integration with real Frames, mocked data providers, and a UI guard.
local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
assert(loadfile("tests/prediction_api_fake.lua"))()(state)
assert(loadfile("tests/history_api_fake.lua"))()(state)
-- Forever defaults UnitHealth to predicted health. Keep the live fill and
-- history on actual HP so the hover preview starts at the same endpoint.
local actualHealth = UnitHealth
UnitHealth = function(unit, predicted)
    local hp = actualHealth(unit)
    return predicted == false and hp or hp + 20
end
state.units.player = {guid="healer",name="Healer",class="PRIEST"}
local ns = {}
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function load(name) assert(loadfile("WowfPartyFrames/" .. name .. ".lua"))("WowfPartyFrames", ns) end
load("Bootstrap")
load("Profiles")
load("Assignments")
ns.Spells = { Get = function(_, id) return { id = id, icon = id, rank = "Rank 1" } end }
local descriptions = {[2050]="Heals the target for 15 to 20.", [2052]="Heals the target for 25 to 30.",
    [2053]="Heals the target for 35 over 15 sec.", [2054]="Shields the target, absorbing 45 damage. Lasts 30 sec."}
local descriptionReads = 0
GetLocale = function() return "enUS" end
C_Spell = {GetSpellDescription=function(id)
    assert(not state.combat, "description queries stay outside combat")
    descriptionReads = descriptionReads + 1
    return descriptions[id]
end, RequestLoadSpellData=function() end}
load("SpellEstimates")
local initialized, settingsCreated, settingsRefresh, settingsToggle, rosterChanges = 0, 0, 0, 0, 0
ns.Rates = {
    status = "available", Initialize = function() initialized = initialized + 1 end,
    SetUnits = function() rosterChanges = rosterChanges + 1 end, Tick = function() end,
    Get = function() return nil, nil, nil, "Combat data restricted" end,
}
ns.Settings = {
    Create = function() settingsCreated = settingsCreated + 1 end,
    Refresh = function() settingsRefresh = settingsRefresh + 1 end,
    Toggle = function() settingsToggle = settingsToggle + 1 end,
}
local auraReads = 0
ns.Auras = {
    GetDebuffs = function() auraReads = auraReads + 1; return {}, true end,
    GetAssignedBuff = function() return { state = "missing" } end,
    Paint = function() end,
}
state.units.party1 = { name = "Tank", class = "WARRIOR", guid = "tank", health = 50, maxHealth = 100, power = 0, maxPower = 0 }
IsLoggedIn = function() return true end
GetBuildInfo = function() return "1.60.1", "70862", "date", 16001 end
load("FrameVisuals")
load("HealthPrediction")
load("HealthHistory")
load("HoverPrediction")
load("Frames")
ns.PresetMenus = { Initialize=function() end, RefreshPrompts=function() end, Update=function() end }
local minimapEntries = {}
AddonCompartmentFrame = {RegisterAddon = function(_, entry)
    minimapEntries[#minimapEntries + 1] = entry
end}
load("Minimap")
load("Core")
local presenceEvents, statusEvents = {}, {}
ns.PartyPresence = {OnEvent=function(_, event) presenceEvents[event]=(presenceEvents[event] or 0)+1 end}
ns.PartyStatus = {OnEvent=function(_, event) statusEvents[event]=(statusEvents[event] or 0)+1 end}
for _, event in ipairs({"GROUP_LEFT", "READY_CHECK", "READY_CHECK_FINISHED", "SHARD_TRANSFER_IMMINENT", "SHARD_TRANSFER_CANCELLED", "SHARD_TRANSFER"}) do
    state.emit(event)
    equal(statusEvents[event], 1, "native status lifecycle is registered even before frame startup")
    equal(presenceEvents[event], 1, "pending-transfer lifecycle reaches presence state")
end
ns.PartyPresence, ns.PartyStatus = nil, nil
state.combat = true
state.emit("ADDON_LOADED", "OtherAddon")
equal(initialized, 0)
state.emit("ADDON_LOADED", "WowfPartyFrames")
state.emit("PLAYER_LOGIN")
equal(initialized, 0, "secure creation waits through combat reload")
equal(ns.Frames.anchor, nil)
SlashCmdList.WOWFPARTYFRAMES("test")
equal(ns.Frames.preview, nil)
state.combat = false
state.emit("PLAYER_REGEN_ENABLED")
equal(ns.started, true)
equal(initialized, 1)
equal(settingsCreated, 1)
equal(#minimapEntries, 1, "startup registers native AddOns menu entry")
state.emit("PLAYER_ENTERING_WORLD", false, false)
local rosterBeforeNameEvent = rosterChanges
state.emit("UNIT_NAME_UPDATE", "target")
equal(rosterChanges, rosterBeforeNameEvent, "unrelated name events do not reset the rate window")
state.emit("UNIT_NAME_UPDATE", "party1")
equal(rosterChanges, rosterBeforeNameEvent, "unchanged party names preserve the rate window")
state.units.party1.name = "ReadyTank"
state.emit("UNIT_NAME_UPDATE", "party1")
equal(rosterChanges, rosterBeforeNameEvent + 1, "resolved party names refresh their binding")
state.emit("PLAYER_LOGIN")
equal(initialized, 1, "initialization remains idempotent")
equal(settingsCreated, 1)
equal(#minimapEntries, 1, "repeated login does not duplicate minimap entry")
SlashCmdList.WOWFPARTYFRAMES(" settings ")
equal(settingsToggle, 1)
for index, layer in ipairs({"base", "shift", "ctrl", "ctrlshift"}) do
    ns.Profiles:SetSpell("default", "heals", 1, ({2050,2052,2053,2054})[index], layer)
end
ns.Frames:ApplyProfiles()
local card = ns.Frames.cards[1]
local healing = card.heals[1]
local hover = card.hoverPrediction
local history = card.healthHistory
equal(history.supported, true)
equal(card.health.value, 50, "main fill explicitly requests actual health")
local function tick(at, elapsed)
    state.time = at
    ns.events:GetScript("OnUpdate")(ns.events, elapsed or 0.01)
end
tick(20)
equal(#history.samples, 0, "live history does not sample outside combat")
tick(20.24)
equal(#history.samples, 0)
state.units.party1.health = 40
tick(20.25)
equal(#history.samples, 0, "OOC health changes do not populate history")
equal(history.holder.alpha, 0)
equal(state.historyColorCalls, nil, "OOC polling never reads history colors")
equal(history.holder.point[3], "TOPLEFT")
equal(hover.holder.point[5], history.holder.point[5], "history and hover share a bottom edge")
equal(hover.holder.level > history.holder.level, true, "hover paints over history")
equal(history.holder:GetHeight(), 12)
equal(hover.holder:GetHeight(), 2)
state.units.party1.health = 50
equal(hover.supported, true)
healing:GetScript("OnEnter")(healing)
equal(hover.holder.alpha, 1, "minimum-heal preview remains available outside combat")
equal(history.holder.alpha, 0, "OOC mouseover does not reveal history")
healing:GetScript("OnLeave")(healing)
equal(ns.SpellEstimates:Get(2054).absorb, 45, "all modifier estimates warm before combat")
SlashCmdList.WOWFPARTYFRAMES("unlock")
equal(ns.Frames.mover:IsShown(), true)
state.subgroupCount = 0
SlashCmdList.WOWFPARTYFRAMES("test")
equal(ns.Frames.preview:IsShown(), true)
local previewHistory = ns.Frames.preview.cards[1].healthHistory
equal(#previewHistory.samples, 12, "solo preview shows explicit synthetic history")
SlashCmdList.WOWFPARTYFRAMES("test")
-- The small UI fake does not dispatch descendant OnHide automatically.
local previewCard = ns.Frames.preview.cards[1]
previewCard:GetScript("OnHide")(previewCard)
SlashCmdList.WOWFPARTYFRAMES("test")
equal(previewHistory.holder.alpha, 1, "preview history survives close and reopen")
ns.Frames.mover:GetScript("OnDragStart")()
equal(ns.Frames.moving, true)
local anchorBeforeCombat = ns.Frames.anchor.point
state.combat = true
state.emit("PLAYER_REGEN_DISABLED")
equal(#history.samples, 1, "combat entry immediately starts a fresh history")
equal(history.rows[12].value, 50)
tick(20.49)
equal(#history.samples, 1)
state.units.party1.health = 40
tick(20.5)
equal(#history.samples, 2, "quarter-second sampling is independent of the display cadence")
equal(history.rows[11].value, 50)
equal(history.rows[12].value, 40)
state.units.party1.health = 50
equal(ns.Frames.moving, false, "combat cancels an in-progress drag")
equal(ns.Frames.anchor.point, anchorBeforeCombat, "combat drag cancellation never moves protected frames")
equal(ns.Frames.mover:IsShown(), false)
equal(ns.Frames.preview:IsShown(), false)
local oldRefreshAll, modifierRefreshes = ns.Frames.RefreshAll, 0
ns.Frames.RefreshAll = function(self, refreshAuras)
    modifierRefreshes = modifierRefreshes + 1
    equal(refreshAuras, false, "modifier event requests presentation refresh only")
    return oldRefreshAll(self, refreshAuras)
end
state.emit("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
equal(modifierRefreshes, 1, "modifier changes refresh icons immediately during combat")
equal(#state.violations, 0, "combat modifier display refresh never writes protected state")
ns.Frames.RefreshAll = oldRefreshAll
local beforeHover = descriptionReads
state.hover = card.portraitArea
healing:GetScript("OnEnter")(healing)
equal(hover.holder.alpha, 1, "hover displays the minimum strip in combat")
equal(hover.direct.value, 15)
equal(hover.direct.maximum, 100)
equal(hover.unit, "party1")
for _, layer in ipairs({{true,false,false,25,0,0}, {false,true,false,0,35,0},
    {true,true,false,0,0,45}, {false,false,true,0,0,0}, {false,false,false,15,0,0}}) do
    state.shift, state.ctrl, state.alt = layer[1], layer[2], layer[3]
    state.emit("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    equal(hover.direct.value, layer[4], "hover tracks modifier without moving mouse")
    equal(hover.hot.value, layer[5])
    equal(hover.absorb.value, layer[6])
    equal(hover.holder.alpha, layer[3] and 0 or 1, "Alt clears the unassigned preview")
end
equal(descriptionReads, beforeHover, "combat hover uses only warmed public estimates")
state.subgroupCount = 2
state.emit("GROUP_ROSTER_UPDATE")
equal(ns.Frames.pendingRoster, true)
state.emit("SPELLS_CHANGED")
equal(ns.Frames.pendingProfiles, true)
equal(ns.SpellEstimates:Get(2050).direct, 15, "combat spell events retain the last public minimum")
for _, command in ipairs({ "test", "unlock", "lock", "reset", "blizzard" }) do SlashCmdList.WOWFPARTYFRAMES(command) end
local before = auraReads
state.emit("UNIT_AURA", "party1")
ns.events:GetScript("OnUpdate")(ns.events, 0.11)
equal(auraReads > before, true, "aura event reaches the next display update")
local prediction = ns.Frames.cards[1].healthPrediction
equal(prediction.supported, true)
state.units.party1.prediction = {health=50, healthMax=100, totalIncomingHeals=20,
    totalIncomingHealsFromHealer=5, totalDamageAbsorbs=15, totalHealAbsorbs=0}
for _, event in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED"}) do
    local calls = #state.predictionCalls
    state.emit(event, "party1")
    equal(#state.predictionCalls, calls + 1, "native prediction event refreshes immediately")
end
equal(prediction.myHeal.value, 5)
equal(prediction.otherHeal.value, 15)
equal(prediction.damageAbsorb.value, 15)
equal(ns.Frames.cards[1].health.value, 50, "prediction preserves current-health value")
local calls = #state.predictionCalls
state.emit("UNIT_HEAL_PREDICTION", "target")
equal(#state.predictionCalls, calls, "unrelated units do not repaint predictions")
-- Secure unit changes during combat move indicators with the named member.
state.units.party2, state.units.party1 = state.units.party1, nil
for _, header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
state.emit("UNIT_ABSORB_AMOUNT_CHANGED", "party2")
equal(prediction.unit, "party2")
equal(prediction.damageAbsorb.value, 15)
equal(hover.unit, "party2", "hover preview follows secure combat reorder")
tick(20.75)
equal(#history.samples, 3, "same member keeps samples through secure combat token reorder")
equal(history.identity, "guid:tank")
equal(hover.direct.value, 15)
local hiddenHistoryCount = #history.samples
equal(hiddenHistoryCount > 0, true)
card:GetScript("OnHide")(card)
equal(#history.samples, 0, "a live card hide explicitly clears its samples")
equal(history.holder.alpha, 0)
tick(21)
equal(#history.samples, 1, "a visible card starts fresh after being hidden")
state.emit("PLAYER_LEAVING_WORLD")
equal(prediction.holder.alpha, 0, "loading screens clear predictions")
equal(hover.holder.alpha, 0, "loading clears the hover strip and hover ownership")
equal(history.holder.alpha, 0, "loading clears history")
equal(#history.samples, 0)
equal(ns.Frames.tooltipButton, nil)
ns.events:GetScript("OnUpdate")(ns.events, 0.11)
equal(prediction.holder.alpha, 0, "polling cannot revive old predictions while loading")
equal(hover.holder.alpha, 0)
equal(#history.samples, 0, "polling cannot revive history during loading")
state.emit("PLAYER_ENTERING_WORLD", false, false)
ns.events:GetScript("OnUpdate")(ns.events, 0.11)
equal(prediction.holder.alpha, 1, "predictions resume after entering world")
equal(hover.holder.alpha, 0, "hover waits for a fresh pointer enter after loading")
equal(#history.samples, 1, "world entry starts a fresh history")
healing:GetScript("OnEnter")(healing)
equal(hover.holder.alpha, 1)
healing:GetScript("OnLeave")(healing)
equal(hover.holder.alpha, 0, "pointer leave clears preview immediately")
equal(hover.direct.value, 0)
state.units.party1, state.units.party2 = state.units.party2, nil
for _, header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
equal(#state.violations, 0)
state.combat = false
state.emit("PLAYER_REGEN_ENABLED")
equal(#history.samples, 0, "combat exit clears history immediately without a display tick")
equal(history.holder.alpha, 0)
equal(history.last, nil, "combat exit resets the sampling clock")
healing:GetScript("OnEnter")(healing)
tick(21.25, 0.11)
equal(#history.samples, 0, "polling cannot revive history after combat")
equal(hover.holder.alpha, 1, "OOC hover continues independently of combat-only history")
healing:GetScript("OnLeave")(healing)
state.units.party1.health = 35
state.combat = true
state.emit("PLAYER_REGEN_DISABLED")
equal(#history.samples, 1, "the next fight starts with only its first sample")
equal(history.rows[12].value, 35, "the next fight does not reuse the previous health")
state.combat = false
state.emit("PLAYER_REGEN_ENABLED")
equal(#history.samples, 0)
state.units.party1.health = 50
equal(#state.violations, 0, "combat visibility changes never move or mutate protected frames")
equal(ns.Frames.pendingRoster, false)
equal(ns.Frames.pendingProfiles, false)
equal(ns.Frames.mover:IsShown(), true, "unlocked preference restored after combat")
equal(settingsRefresh > 0, true)
descriptions[2050] = "Heals the target for 18 to 22."
state.emit("PLAYER_EQUIPMENT_CHANGED", 1, true)
equal(ns.SpellEstimates:Get(2050).direct, 18, "equipment changes refresh public descriptions outside combat")
ns.Profiles:SetSpell("default", "heals", 2, 999)
ns.Frames:ApplyProfiles()
equal(ns.SpellEstimates:Get(999), nil)
descriptions[999] = "Heals the target for 55."
state.emit("SPELL_DATA_LOAD_RESULT", 999, true)
equal(ns.SpellEstimates:Get(999).direct, 55, "loaded assigned spell is warmed through Core")
local statusStart = #state.messages
SlashCmdList.WOWFPARTYFRAMES("status")
local statusLines = table.concat(state.messages, "\n", statusStart + 1)
for _, text in ipairs({"rolling window: 5 seconds", "Aura display: public API fallback", "Health indicators: native",
    "Spell hover preview: minimum spell values; 2-pixel strip", "Assigned healing effects: unavailable",
    "Health history: 0.25s samples / 3s history; native health colors"}) do
    equal(statusLines:find(text, 1, true) ~= nil, true, text)
end
-- A previous partial creation can leave an anchor but no usable unit frames.
-- Core must leave the native frames available until creation really succeeds.
PartyFrame = CreateFrame("Frame", nil, UIParent, "SecureUnitButtonTemplate")
local nativeParent = PartyFrame:GetParent()
ns.started, ns.Frames.ready = nil, false
local settingsBefore = settingsCreated
state.emit("PLAYER_REGEN_ENABLED")
equal(ns.started, nil)
equal(settingsCreated, settingsBefore)
equal(PartyFrame:GetParent(), nativeParent)
equal(PartyFrame:IsVisible(), true, "partial initialization preserves native frames")
equal(ns.Frames:SetBlizzardVisible(false), false)
equal(PartyFrame:GetParent(), nativeParent)
print("core_spec: " .. checks .. " checks passed")
