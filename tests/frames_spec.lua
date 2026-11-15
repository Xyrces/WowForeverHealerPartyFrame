local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
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
load("MemberInfo")
UnitLevel=function(unit) return state.units[unit] and state.units[unit].level end
UnitGroupRolesAssigned=function(unit) return state.units[unit] and state.units[unit].role end
GetRaidTargetIndex=function(unit) return state.units[unit] and state.units[unit].marker end
Enum=Enum or {}; Enum.UIMapType={Zone=3}
C_Map={GetBestMapForUnit=function(unit) return state.units[unit] and state.units[unit].map end,
    GetMapInfo=function(id) return {name=id==1 and "Elwynn Forest" or "Westfall",mapType=3,parentMapID=0} end}
state.units.player.map=1
ns.db = ns.Profiles:Init({ classes = { WARRIOR = { heals = {2050, 2052}, buffs = {1243} }, MAGE = { heals = {2053}, buffs = {1459} } } })
ns.Assignments:Init(ns.db)
ns.Assignments:BeginSession(false)
ns.Spells = { Get = function(_, id) return { id = id, icon = id, rank = "Rank 1" } end }
local rateCalls, unitChanges = {}, 0
ns.Rates = {
    SetUnits = function() unitChanges = unitChanges + 1 end,
    Get = function(_, unit) rateCalls[#rateCalls + 1] = unit; return 50, 45, 5, "available" end,
}
local buffState = "active"
ns.Auras = {
    GetDebuffs = function() return { { auraInstanceID = 7 } }, true end,
    GetAssignedBuff = function() return { state = buffState } end,
    Paint = function(buttons, button) button.timer:SetText("") end,
}
load("FrameVisuals")
load("CleanseGeometry")
local bindingCalls=0
local function globalBinding() bindingCalls=bindingCalls+1;error("party controls must not set global bindings") end
SetBinding, SetBindingClick, SetOverrideBindingClick, SetOverrideBinding = globalBinding, globalBinding, globalBinding, globalBinding
load("PreviewData"); load("Frames")
state.units.party1 = { name = "Tank", class = "WARRIOR", guid = "tank", health = 500, maxHealth = 1000, power = 0, maxPower = 0 }
state.units.party2 = { name = "Mage", class = "MAGE", guid = "mage", health = 250, maxHealth = 500, power = 100, maxPower = 200 }
state.units.party1.level,state.units.party1.role,state.units.party1.map=24,"TANK",2
state.units.party2.level,state.units.party2.role,state.units.party2.map=23,"DAMAGER",1
state.units.party1.marker=8
equal(ns.Frames:Create(), true)
equal(#ns.Frames.cards, 4)
equal(ns.Frames.cards[1].heals[1]:GetAttribute("spell1"), nil, "new members start at Default regardless of class")
assert(ns.Assignments:Assign("guid:tank", "class-WARRIOR"))
assert(ns.Assignments:Assign("guid:mage", "class-MAGE"))
ns.Frames:ApplyProfiles()
ns.Frames:RefreshAll(true)
local tank, mage = ns.Frames.cards[1], ns.Frames.cards[2]
equal(tank.memberInfo:GetText(),"24 WARRIOR · Tank")
equal(mage.memberInfo:GetText(),"23 MAGE · Damage")
equal(tank.roleIcon.atlas,"roleicon-tiny-tank")
equal(tank.markerIcon.spriteCell[1],8)
equal(mage.markerIcon:IsShown(),false,"no marker without an assignment")
equal(tank.presetLabel:GetText(),"Preset: "..ns.Profiles:GetPreset("class-WARRIOR").name)
equal(tank.location:GetText(),"Westfall")
equal(mage.location:GetText(),"","same zone does not add location clutter")
assert(ns.Profiles:SetSpell("class-WARRIOR","heals",1,2052,"shift"))
assert(ns.Profiles:SetSpell("class-WARRIOR","heals",1,2053,"ctrl"))
assert(ns.Profiles:SetSpell("class-WARRIOR","heals",1,2054,"ctrlshift"))
ns.Frames:ApplyProfiles()
local combinations={{"",2050},{"shift-",2052},{"ctrl-",2053},{"ctrl-shift-",2054}}
for _,combination in ipairs(combinations) do
    local prefix,id=combination[1],combination[2]
    equal(tank.heals[1]:GetAttribute(prefix.."type1"),"spell")
    equal(tank.heals[1]:GetAttribute(prefix.."spell1"),id,"exact modifier rank is secured before combat")
    equal(tank.heals[1]:GetAttribute("alt-"..prefix.."type1"),"","Alt combinations explicitly do nothing")
    equal(tank.heals[1]:GetAttribute("alt-"..prefix.."spell1"),nil)
    equal(tank.heals[3]:GetAttribute(prefix.."type1"),"","empty layer is no action, not target or fallback")
    equal(tank.heals[3]:GetAttribute(prefix.."spell1"),nil)
end
equal(tank.heals[1]:GetAttribute("spell"),nil,"no generic spell fallback")
for _,button in ipairs(tank.heals) do
    equal(button:GetAttribute("type2"),"togglemenu")
    equal(button:GetAttribute("*type2"),"togglemenu","right-click modifiers retain native menu")
    equal(button:GetAttribute("useparent-unit"),true)
end
local function offsetX(region) return region.point[#region.point-1] end
local function offsetY(region) return region.point[#region.point] end
for index,button in ipairs(tank.heals) do
    equal(button:GetWidth(),36)
    equal(button:GetHeight(),36)
    equal(button.point[2],tank.portraitArea)
    equal(button:GetFrameLevel(),tank.portraitArea:GetFrameLevel()+10,"heals stay above radial art and secure cleanse regions")
    equal(offsetX(button),(index-1)%2*38+4,"two square columns have two-pixel separation")
    equal(offsetY(button),-4-math.floor((index-1)/2)*38)
end
for index,button in ipairs(tank.buffs) do
    equal(offsetX(button)+button:GetWidth()<=offsetX(tank.health)+tank.health:GetWidth(),true,"all eight buffs fit below bars")
    equal(offsetX(button)+button:GetWidth()<offsetX(tank.portraitArea),true,"buff icons stay clear of healing controls")
end

equal(tank.header:GetAttribute("nameList"), "Tank")
equal(tank.heals[1]:GetAttribute("spell1"), 2050, "Rank 1 ID retained")
equal(tank.heals[2]:GetAttribute("spell1"), 2052, "Rank 2 ID retained")
equal(mage.heals[1]:GetAttribute("spell1"), 2053, "explicit recipient preset chooses spells")
equal(SecureButton_GetUnit(tank.heals[1]), "party1")
equal(tank.power.value, 0)
equal(tank.power.maximum, 0, "zero maximum passed safely without division")
equal(tank.power.text.formatValues[1], 0)
equal(tank.health.text.formatValues[1], 500)
equal(tank.heals[1]:GetAttribute("*type1"), nil, "no wildcard action can leak Base into an empty layer")
equal(tank.buffs[1]:GetAttribute("*type2"), "togglemenu")

-- Unresolved and ambiguous identities must never attach one member's spells
-- to whichever equally named unit the secure header happens to match first.
UNKNOWNOBJECT = "Unknown"
state.units.party1.name, state.units.party2.name = UNKNOWNOBJECT, UNKNOWNOBJECT
ns.Frames:RefreshRoster()
equal(tank.classToken, nil)
equal(mage.classToken, nil)
equal(tank.heals[1]:GetAttribute("spell1"), nil)
equal(tank:IsVisible(), false)
state.combat = true
state.units.party3 = {name=UNKNOWNOBJECT, class="PRIEST", guid="joining"}
for _, header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
equal(tank:IsVisible(), false, "unknown arrival cannot inherit an unresolved frame")
equal(ns.Frames:RefreshRoster(), false)
state.combat = false
state.units.party3 = nil
state.units.party1.name, state.units.party2.name = "Ambiguous", "Ambiguous"
ns.Frames:RefreshRoster()
equal(tank.classToken, nil, "first duplicate is rejected too")
equal(mage.classToken, nil)
state.units.party1.name, state.units.party2.name = "Tank", "Mage"
ns.Frames:RefreshRoster()
equal(tank.classToken, "WARRIOR")
equal(mage.classToken, "MAGE")

-- Native owner refresh follows the secure binding while the pointer stays still.
local nativeTooltipAvailable = true
GameTooltip.IsOwned = function(self, owner) return self.SetOwnerArgs and self.SetOwnerArgs[1] == owner end
GameTooltip.SetUnit = function(self, unit)
    self.nativeUnit = unit
    if not nativeTooltipAvailable then return false end
    self:SetText(UnitName(unit))
    return true
end
tank:GetScript("OnEnter")(tank)
equal(GameTooltip.nativeUnit, "party1")
equal(type(tank.UpdateTooltip), "function")
state.combat = true
state.units.party1, state.units.party2 = state.units.party2, state.units.party1
tank:UpdateTooltip()
equal(GameTooltip.nativeUnit, "party1", "refresh uses current binding until native header reconciles")
for _, header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
tank:UpdateTooltip()
equal(GameTooltip.nativeUnit, "party2", "stationary tooltip follows named member after combat reorder")
equal(GameTooltip:GetText(), "Tank")
nativeTooltipAvailable = false
GameTooltip:SetText("Stale member")
tank:UpdateTooltip()
equal(GameTooltip:GetText(), "Tank", "false native tooltip result uses member name fallback")
nativeTooltipAvailable = true
tank:GetScript("OnLeave")(tank)
equal(tank.UpdateTooltip, nil)
equal(GameTooltip:IsShown(), false)
tank:GetScript("OnEnter")(tank)
GameTooltip:SetOwner(mage, "ANCHOR_NONE")
GameTooltip:Show()
tank:GetScript("OnHide")(tank)
equal(tank.UpdateTooltip, nil, "hidden member stops native tooltip updates")
equal(GameTooltip:IsShown(), true, "hiding another member preserves current tooltip")
equal(ns.Frames:RefreshRoster(), false)
equal(tank.header:GetAttribute("nameList"), "Tank", "name binding remains immutable in combat")
equal(tank.classToken, "WARRIOR")
equal(SecureButton_GetUnit(tank.heals[1]), "party2", "healing follows recipient after slot reorder")
equal(SecureButton_GetUnit(tank.buffs[1]), "party2", "buff action inherits current recipient")
equal(tank.heals[1]:GetAttribute("spell1"), 2050)
equal(ns.Frames:ApplyProfiles(), false)
equal(ns.Frames:SetUnlocked(true), false)
equal(ns.Frames:ResetPosition(), false)
equal(ns.Frames:TogglePreview(), false)
equal(ns.Frames:SetBlizzardVisible(false), false)
state.hover = tank.portraitArea
ns.Frames:RefreshAll(true)
equal(tank.memberInfo:GetText(),"24 WARRIOR · Tank","combat reorder follows named member")
equal(tank.markerIcon.spriteCell[1],8,"assigned marker follows named member in combat")
equal(tank.location:GetText(),"Westfall","location follows current secure unit")
equal(tank.name:GetText(), "Tank")
equal(tank.heals[1].icon:GetAlpha(), 1)
local heal=tank.heals[1]
heal:GetScript("OnEnter")(heal)
equal(GameTooltip.SetSpellByIDArgs[1],2050)
equal(GameTooltip.point[2],tank,"tooltip anchors to member rather than covering hovered control")
UIParent.width=1200
ns.Frames.anchor.left=20
heal:GetScript("OnEnter")(heal)
equal(GameTooltip.point[1],"TOPLEFT")
equal(GameTooltip.point[3],"TOPRIGHT","tooltip uses free space beside frame")
ns.Frames.anchor.left=1100
heal:GetScript("OnEnter")(heal)
equal(GameTooltip.point[1],"TOPRIGHT")
equal(GameTooltip.point[3],"TOPLEFT","right-edge tooltip flips to stay on screen")
ns.Frames.anchor.left=nil
UIParent.width=nil

for _,combination in ipairs({{true,false,false,"shift",2052},{false,true,false,"ctrl",2053},
    {true,true,false,"ctrlshift",2054},{true,true,true,"alt",nil},{false,false,false,"base",2050}}) do
    state.shift,state.ctrl,state.alt=combination[1],combination[2],combination[3]
    ns.Frames:RefreshAll(false)
    equal(heal.activeLayer,combination[4])
    equal(heal.spellID,combination[5],"held modifiers paint matching exact rank")
    equal(heal.icon.texture,combination[5] or "Interface\\Icons\\INV_Misc_QuestionMark")
    if combination[5] then equal(GameTooltip.SetSpellByIDArgs[1],combination[5],"hovered tooltip refreshes without mouse movement")
    else equal(GameTooltip:GetText(),"No spell assigned") end
    equal(SecureButton_GetUnit(heal),"party2","all layers still inherit reordered member")
    equal(heal:GetAttribute("spell1"),2050,"painting does not rewrite secure Base")
end
heal:GetScript("OnLeave")(heal)
equal(#state.violations,0,"modifier display changes in combat never mutate protected controls")
equal(bindingCalls,0,"no global key bindings")
for _, value in ipairs({ "active", "missing", "unknown" }) do
    buffState = value
    ns.Frames:RefreshAll(true)
    equal(tank.buffs[1].buffState, value)
    equal(tank.buffs[1]:GetAttribute("spell"), 1243)
end
equal(tank.buffs[1].timer:GetText(), "?")
-- A sentinel throws on arithmetic/concatenation but is accepted by display setters.
local secret = setmetatable({}, { __add = function() error("secret arithmetic") end,
    __div = function() error("secret arithmetic") end, __concat = function() error("secret concatenation") end })
issecretvalue = function(value) return value == secret end
state.units.party2.health, state.units.party2.maxHealth = secret, secret
state.units.party2.power, state.units.party2.maxPower = secret, secret
ns.Frames:RefreshAll(false)
equal(tank.health.value, secret)
equal(tank.health.maximum, secret)
equal(tank.health.text.formatValues[1], secret)
equal(tank.power.text.formatValues[2], secret)
-- Leaving the party hides the engine's matching card, never repurposes it.
state.units.party2 = nil
for _, header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
ns.Frames:RefreshAll(true)
equal(tank:IsVisible(), false)
equal(SecureButton_GetUnit(tank.heals[1]), nil)
equal(#state.violations, 0, "no protected mutation attempts, including caught errors")
state.combat = false
equal(ns.Frames:RefreshRoster(), true)
equal(ns.Frames.pendingRoster, false)
equal(ns.Frames.cards[1].classToken, "MAGE")
equal(ns.Frames.cards[1].heals[1]:GetAttribute("spell1"), 2053)
equal(ns.Frames.cards[2].heals[1]:GetAttribute("spell1"), nil, "vacant member has no stale spell")
-- Drag coordinates are converted from mover scale into secure anchor scale.
ns.Frames.anchor:SetScale(0.5)
ns.Frames.mover:SetScale(1)
ns.Frames.anchor.left, ns.Frames.anchor.top = 100, 600
equal(ns.Frames:SetUnlocked(true), true)
equal(ns.Frames.mover.point[4], 50)
equal(ns.Frames.mover.point[5], 330, "handle starts 30 units above scaled frame")
ns.Frames.mover.left, ns.Frames.mover.top = 200, 400
ns.Frames.mover:GetScript("OnDragStart")()
ns.Frames.mover:GetScript("OnDragStop")()
equal(ns.Frames.anchor.point[4], 400)
equal(ns.Frames.anchor.point[5], 740, "subtract gap after converting coordinate scale")
equal(ns.db.position.x, 400)
equal(ns.db.position.y, 740, "dragged position persists outside combat")
equal(ns.Frames:TogglePreview(), false, "party members must not be duplicated by sample cards")
state.subgroupCount = 0
equal(ns.Frames:TogglePreview(), true)
local preview = ns.Frames.preview
equal(preview:GetParent(), ns.Frames.anchor, "preview inherits live frame scale and position")
equal(preview.allPoints[1], ns.Frames.anchor, "preview covers the live frame anchor")
equal(preview.template, nil, "preview has no window backdrop template")
equal(preview.SetBackdropArgs, nil, "preview has no surrounding window background")
equal(preview.SetFrameStrataArgs and preview.SetFrameStrataArgs[1] == "DIALOG" or false, false)
equal(preview:GetEffectiveScale(), ns.Frames.anchor:GetEffectiveScale())
local function offsets(frame)
    local point = frame.point
    return point[#point - 1], point[#point]
end
for index, card in ipairs(preview.cards) do
    local x, y = offsets(card)
    local liveX, liveY = offsets(ns.Frames.headers[index])
    equal(x, liveX, "preview/live horizontal geometry matches")
    equal(y, liveY, "preview/live vertical spacing matches")
    equal(card:GetWidth(), ns.Frames.cards[index]:GetWidth())
    equal(card:GetHeight(), ns.Frames.cards[index]:GetHeight())
end
-- Radial controls change stack bounds and spacing, never the existing bars or
-- large member-target buttons. Exercise both styles with an existing preview.
local oldCleanses, oldStyle = ns.Cleanses, ns.db.controlStyle
local actionCount = 2
ns.Cleanses = {GetActions=function()
    local actions = {}; for index=1,actionCount do actions[index]={spellID=index} end
    return actions
end}
local anchor = ns.Frames.anchor
-- The shared fake may omit this API; this local recorder checks calls without
-- claiming to emulate native screen clamping.
if not anchor.SetClampRectInsets then
    anchor.SetClampRectInsets=function(self,...)
        assert(not state.combat,"clamp rectangle cannot change during combat")
        self.SetClampRectInsetsArgs={...}
    end
end
local originalPoint = {anchor:GetPoint()}
for _, layout in ipairs({{"quadrants",64,152,27,293,584,-112},{"buttons",76,176,39,305,663,-124}}) do
    ns.db.controlStyle = layout[1]
    equal(ns.Frames:ApplyProfiles(),true)
    equal(ns.Frames.pitch,layout[3])
    equal(ns.Frames.topPadding,layout[4])
    equal(anchor:GetWidth(),layout[5],"radial extent is included in screen clamp width")
    equal(anchor:GetHeight(),layout[6],"last preset label is included in stack height")
    equal(anchor.SetClampRectInsetsArgs[3],layout[4],"positive top clamp reserves arc above anchor")
    equal(anchor.point[4],originalPoint[4],"style changes retain custom anchor x")
    equal(anchor.point[5],originalPoint[5],"style changes retain custom anchor y")
    equal(preview.title.point[2],preview)
    equal(preview.title.point[3],"BOTTOMLEFT","preview caption follows resized stack")
    for index, card in ipairs(ns.Frames.cards) do
        equal(offsetY(ns.Frames.headers[index]),-(index-1)*layout[3])
        equal(offsetY(preview.cards[index]),offsetY(ns.Frames.headers[index]),"preview uses live radial row pitch")
        equal(offsetY(card.presetLabel),layout[7])
        equal(offsetY(preview.cards[index].presetLabel),layout[7])
        equal(card:GetWidth(),ns.Layout.width,"target hit box must not grow under the radial ring")
        equal(card:GetHeight(),ns.Layout.height)
        equal(card.health:GetWidth(),ns.Layout.barWidth,"radials never restyle or resize health bars")
        equal(card.portraitArea:GetWidth(),ns.Layout.portrait)
        -- Label's lower edge leaves eight units before the next arc begins.
        equal(layout[3]+42-layout[2] >= -layout[7]+9+8,true,"labels and next member arc stay separate")
    end
    local factor = anchor:GetEffectiveScale()/ns.Frames.mover:GetEffectiveScale()
    equal(ns.Frames.mover:GetWidth(),layout[5]*factor)
    equal(ns.Frames.mover.point[5],(anchor:GetTop()+layout[4])*factor+30,"move handle clears ring at current scale")
end
state.combat = true
ns.db.controlStyle = "quadrants"
equal(ns.Frames:ApplyProfiles(),false)
equal(ns.Frames:LayoutCards(2),false,"direct layout request is also guarded during combat")
equal(ns.Frames.pitch,176,"combat leaves old layout untouched")
equal(offsetY(ns.Frames.headers[2]),-176)
equal(anchor.SetClampRectInsetsArgs[3],39)
equal(#state.violations,0,"radial geometry never mutates secure frames during combat")
state.combat = false
equal(ns.Frames:ApplyProfiles(),true)
equal(ns.Frames.pitch,152,"deferred style is applied outside combat")
ns.Frames.mover.left, ns.Frames.mover.top = 200, 400
ns.Frames.mover:GetScript("OnDragStart")()
ns.Frames.mover:GetScript("OnDragStop")()
equal(anchor.point[4],400)
equal(anchor.point[5],713,"drag conversion subtracts radial padding in anchor units")
equal(ns.db.position.y,713,"radial drag preserves the actual anchor coordinate")
actionCount = 0
ns.Frames:ApplyProfiles()
equal(ns.Frames.pitch,ns.Layout.pitch,"no assigned cleanse restores normal spacing")
equal(anchor:GetWidth(),ns.Layout.width)
equal(anchor:GetHeight(),ns.Layout.pitch*3+ns.Layout.height)
equal(anchor.SetClampRectInsetsArgs[3],0)
equal(offsetY(ns.Frames.cards[1].presetLabel),-87)
equal(offsetY(preview.cards[1].presetLabel),-87)
ns.Cleanses, ns.db.controlStyle = oldCleanses, oldStyle
ns.Frames:ApplyProfiles()
for _, card in ipairs(ns.Frames.preview.cards) do
    for _, kind in ipairs({ "heals", "buffs" }) do
        for _, button in ipairs(card[kind]) do equal(button:GetAttribute("type1"), nil, "preview never casts") end
    end
end
equal(ns.Profiles:GetSpell("class-WARRIOR", "heals", 3), nil, "preview never populates saved heals")
equal(ns.Profiles:GetSpell("class-WARRIOR", "buffs", 2), nil, "preview never populates saved buffs")
equal(preview.cards[1].heals[1].spellID, nil, "empty Default has no sample heal fallback")
equal(preview.cards[1].buffs[1].spellID, nil, "empty Default has no sample buff fallback")
ns.Settings={presetID="class-WARRIOR",healLayer="ctrl"}
ns.Frames:ApplyProfiles()
ns.Frames:RefreshAll(false)
equal(preview.cards[1].heals[1].spellID,2053,"preview follows settings layer without held modifiers")
state.shift=true
ns.Frames:RefreshAll(false)
equal(preview.cards[1].heals[1].spellID,2052,"physical modifier overrides settings preview layer")
state.shift=false
ns.Frames:RefreshAll(false)
equal(preview.cards[1].heals[1].spellID,2053,"releasing returns to settings preview layer")
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",8,14752))
ns.Frames:ApplyProfiles()
equal(offsetX(preview.cards[1].buffs[8]),ns.Layout.auraX+ns.Layout.auraPitch,"preview compacts existing sparse buffs")
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",1,nil))
ns.Frames:ApplyProfiles()
equal(offsetX(preview.cards[1].buffs[8]),ns.Layout.auraX,"preview closes gap after removal")
equal(preview.cards[1].buffs[8].spellID,14752)
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",8,nil))
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",1,1243))
ns.Frames:ApplyProfiles()
for _,prefix in ipairs({"","shift-","ctrl-","ctrl-shift-","alt-","alt-shift-","alt-ctrl-","alt-ctrl-shift-"}) do
    equal(preview.cards[1].heals[1]:GetAttribute(prefix.."type1"),nil,"preview has no casting attributes on any layer")
end
state.subgroupCount = 2
ns.Frames:RefreshRoster()
equal(preview:IsShown(), false, "joining a party dismisses solo sample cards")
equal(ns.Frames:TogglePreview(), false)
state.subgroupCount, state.raid = 0, true
equal(ns.Frames:TogglePreview(), false, "raid membership also refuses the sample overlay")
state.subgroupCount, state.raid = 2, false
-- Blizzard may call Show during a roster update. Its hidden ancestor must keep
-- the native frame out of the way, and toggling back must restore its parent.
local originalParent = CreateFrame("Frame", nil, UIParent)
PartyFrame = CreateFrame("Frame", nil, originalParent, "SecureUnitButtonTemplate")
PartyFrame.UpdatePartyFrames = function() error("Native update must not run under addon taint") end
equal(ns.Frames:SetBlizzardVisible(false), true)
PartyFrame:Show()
equal(PartyFrame:IsVisible(), false, "native Show cannot undo hidden-parent suppression")
equal(ns.Frames:SetBlizzardVisible(false), true, "repeated hiding is idempotent")
equal(ns.Frames:SetBlizzardVisible(true), true)
equal(PartyFrame:GetParent(), originalParent, "restore exact original native parent")
equal(PartyFrame:IsVisible(), true)
state.combat = true
local nativeParent = PartyFrame:GetParent()
equal(ns.Frames:SetBlizzardVisible(false), false)
equal(PartyFrame:GetParent(), nativeParent)
equal(#state.violations, 0)
print("frames_spec: " .. checks .. " checks passed (simulated headers; in-game secure verification still required)")
