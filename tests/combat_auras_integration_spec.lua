-- Real addon lifecycle with native rendering delegated, never decoded here.
local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
local ns, checks = {}, 0
local function eq(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected")..": "..tostring(a).." ~= "..tostring(b))
end
local function load(name) assert(loadfile("WowfPartyFrames/"..name..".lua"))("WowfPartyFrames",ns) end
local originalCreate, containers, failBind = CreateFrame, {}, nil
CreateFrame = function(kind,name,parent,template)
    local frame = originalCreate(kind,name,parent,template)
    if kind=="AuraContainer" then
        containers[#containers+1]=frame
        function frame:SetEnabled(enabled) self.enabled=enabled end
        function frame:SetUnit(unit)
            -- Both old views must be hidden before either binding changes.
            eq(not self.parent:IsShown() or self.parent:GetAlpha()==0,true,"binding occurs behind hidden holder")
            if self==failBind then error("native bind failure") end
            self.boundUnit=unit
        end
        function frame:SetFlowLayoutMaximumLineSize(width) self.lineWidth=width end
        local function iconFor(options)
            local button=originalCreate("AuraButton",nil,frame)
            function button:SetIcon(v) self.icon=v end
            function button:SetDurationCooldown(v) self.cooldown=v end
            function button:SetDurationText(v) self.duration=v end
            function button:SetApplicationCount(v) self.count=v end
            function button:SetHideTooltipInCombat(v) self.hideTooltipInCombat=v end
            options.initializeFrame(button)
            return button
        end
        function frame:AddAuraGroup(key,filter,options)
            self.filter=filter; self.group=options; self.nativeIcon=iconFor(options)
        end
        function frame:AddAuraSlot(key,filter,options)
            self.slots=self.slots or {}
            self.slots[key]={filter=filter,icon=iconFor(options)}
        end
        function frame:SetAuraSlotEnabled(key,value) self.slots[key].enabled=value end
        function frame:SetAuraSlotCandidateFilters(key,value) self.slots[key].filters=value end
        function frame:SetAuraGroupMaxFrameCount(key,value) self.group.maxFrameCount=value end
        function frame:SetAuraGroupCandidateFilters(key,value) self.group.filters=value end
    end
    return frame
end
C_AuraContainerUtil={ProcessCustomAuraButtonDurationTextOptions=function() end}
local readCount=0
local function read()
    readCount=readCount+1
    if state.combat then error("addon aura access denied") end
    return nil
end
C_UnitAuras={GetUnitAuraInstanceIDs=function()
    read(); return {1}
end,GetAuraDataByAuraInstanceID=function()
    read(); return {auraInstanceID=1,spellId=10,icon=123,duration=30,expirationTime=40,isHelpful=true}
end,GetUnitAuraBySpellID=read,GetAuraDataBySpellName=read}
C_Secrets={ShouldAurasBeSecret=function() return state.combat end}
C_Spell={GetSpellName=function() return "Fortitude" end}
load("Bootstrap"); load("Profiles"); load("Assignments")
state.units.player={guid="healer",name="Healer",class="PRIEST"}
ns.db=ns.Profiles:Init({classes={WARRIOR={heals={2050},buffs={1243}}}})
ns.Assignments:Init(ns.db); ns.Assignments:BeginSession(false)
ns.Spells={Get=function(_,id) return {id=id,icon=id,rank="Rank 1"} end, GetAuraSpellIDs=function(_,id) return {[id]=true,[id+1]=true} end}
ns.Rates={SetUnits=function() end,Get=function() return nil,nil,nil,"unavailable" end}
state.units.player={guid="healer",name="Healer",class="PRIEST"}
state.units.party1={guid="tank",name="Tank",class="WARRIOR",health=500,maxHealth=1000,power=0,maxPower=0}
state.units.party2={guid="mage",name="Mage",class="MAGE",health=300,maxHealth=500,power=100,maxPower=200}
load("Auras"); load("FrameVisuals"); load("AuraDisplay"); load("HealAuraDisplay"); load("Frames")
eq(ns.Frames:Create(),true)
assert(ns.Assignments:Assign("guid:tank","class-WARRIOR"))
ns.Frames:ApplyProfiles(); ns.Frames:RefreshAll(true)
local tank=ns.Frames.cards[1]
local healDisplay=tank.healAuraDisplay
eq(healDisplay.supported,true)
eq(healDisplay.configured,true,"profile application configures native healing filters")
eq(healDisplay.unit,"party1")
eq(#healDisplay.views,4)
local baseHeal=healDisplay.views[1].container.slots.heal1
eq(baseHeal.filters.includeSpellIDs[2050],true)
eq(baseHeal.filters.includeSpellIDs[2051],true,"healing skill matches rank family")
eq(baseHeal.icon.allPoints[1],tank.heals[1])
eq(baseHeal.icon.mouseEnabled,false)
assert(ns.Profiles:SetSpell("class-WARRIOR","heals",1,139,"shift"))
assert(ns.Profiles:SetSpell("class-WARRIOR","heals",1,774,"ctrl"))
assert(ns.Profiles:SetSpell("class-WARRIOR","heals",1,17,"ctrlshift"))
ns.Frames:ApplyProfiles()
eq(healDisplay.views[2].container.slots.heal1.filters.includeSpellIDs[139],true)
eq(healDisplay.views[3].container.slots.heal1.filters.includeSpellIDs[774],true)
eq(healDisplay.views[4].container.slots.heal1.filters.includeSpellIDs[17],true)
local function visibleLayer(expected)
    for _,view in ipairs(healDisplay.views) do
        eq(view.holder:GetAlpha(),view.layer==expected and 1 or 0,"only hovered modifier layer is visible")
    end
end
visibleLayer(nil)
eq(tank.nativeAuras,true)
for _,view in ipairs(tank.auraDisplay.views) do
    eq(view.holder:IsShown(),true)
    eq(view.container.boundUnit,"party1")
    local icon=view.container.nativeIcon or view.container.slots.buff1.icon
    eq(icon.duration~=nil,true,"duration owned by native renderer")
end
local helpful=tank.auraDisplay.views[2].container
local slot=helpful.slots.buff1
eq(slot.icon.point[2],tank.buffs[1],"native overlay uses recast slot")
eq(slot.icon.SetMouseClickEnabledArgs[1],false,"secure button receives clicks")
eq(slot.icon.SetMouseMotionEnabledArgs[1],false,"secure button receives hover")
local debuffIcon=tank.auraDisplay.views[1].container.nativeIcon
eq(debuffIcon.SetMouseMotionEnabledArgs[1],true,"ordinary debuffs retain native hover input")
eq(debuffIcon.hideTooltipInCombat,false,"ordinary debuff details remain enabled in combat")
eq(slot.filters.includeSpellIDs[1243],true)
eq(slot.filters.includeSpellIDs[1244],true)
eq(tank.auraDisplay.views[3].container.group.filters.excludeSpellIDs[1243],true)
-- Removing assignments closes the row without renumbering saved slots or
-- separating native aura overlays from their exact-rank casting controls.
local extras=tank.auraDisplay.views[3]
local function buffX(button) return button.point[#button.point-1] end
local function extrasAfter(count)
    eq(extras.holder.point[4],ns.Layout.auraX+count*ns.Layout.auraPitch,"extras follow visible configured buffs")
    eq(extras.container.group.maxFrameCount,8-count,"all unused row positions remain available")
end
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",2,21562))
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",8,14752))
ns.Frames:ApplyProfiles()
eq(buffX(tank.buffs[8]),ns.Layout.auraX+2*ns.Layout.auraPitch,"existing sparse presets compact on apply")
extrasAfter(3)
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",2,nil))
ns.Frames:ApplyProfiles()
eq(tank.buffs[2]:IsShown(),false)
eq(helpful.slots.buff2.enabled,false)
eq(buffX(tank.buffs[8]),ns.Layout.auraX+ns.Layout.auraPitch,"middle removal closes its gap")
eq(tank.buffs[8]:GetAttribute("spell"),14752,"moving button retains exact spell rank")
eq(SecureButton_GetUnit(tank.buffs[8]),"party1","moving button retains recipient")
eq(helpful.slots.buff8.icon.point[2],tank.buffs[8],"native timer and icon follow moved button")
eq(helpful.slots.buff8.filters.includeSpellIDs[14752],true)
eq(extras.container.group.filters.excludeSpellIDs[21562],nil,"removed buff no longer excluded from extra auras")
eq(ns.Profiles:GetSpell("class-WARRIOR","buffs",8),14752,"layout preserves saved slot identity")
extrasAfter(2)
state.combat=true
eq(ns.Profiles:SetSpell("class-WARRIOR","buffs",1,nil),false,"combat cannot remove a secure assignment")
eq(ns.Frames:ApplyProfiles(),false,"combat cannot reposition buff controls")
eq(buffX(tank.buffs[8]),ns.Layout.auraX+ns.Layout.auraPitch)
state.combat=false
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",1,nil))
ns.Frames:ApplyProfiles()
eq(buffX(tank.buffs[8]),ns.Layout.auraX,"first removal closes leading gap")
extrasAfter(1)
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",8,nil))
ns.Frames:ApplyProfiles()
eq(tank.buffs[8]:IsShown(),false)
eq(helpful.slots.buff8.enabled,false)
extrasAfter(0)
assert(ns.Profiles:SetSpell("class-WARRIOR","buffs",1,1243))
ns.Frames:ApplyProfiles()
-- Preset changes clear old matching IDs and preserve exact casting rank.
ns.Profiles:SetSpell("class-WARRIOR","buffs",1,21562)
ns.Frames:ApplyProfiles()
eq(slot.filters.includeSpellIDs[1243],nil)
eq(slot.filters.includeSpellIDs[21562],true)
ns.Profiles:SetSpell("class-WARRIOR","buffs",1,1243)
ns.Frames:ApplyProfiles()
state.combat=true
ns.Frames:RefreshAll(true)
state.hover=tank.portraitArea
ns.Frames:RefreshAll(false)
visibleLayer("base")
state.shift=true
ns.Frames:RefreshAll(false)
visibleLayer("shift")
eq(tank.heals[1].spellID,139,"native aura layer follows displayed action")
state.shift=false; state.ctrl=true
ns.Frames:RefreshAll(false)
visibleLayer("ctrl")
state.shift=true
ns.Frames:RefreshAll(false)
visibleLayer("ctrlshift")
state.alt=true
ns.Frames:RefreshAll(false)
visibleLayer(nil)
state.alt=false; state.shift=false; state.ctrl=false
state.hover=nil
ns.Frames:RefreshAll(false)
visibleLayer(nil)
eq(tank.nativeAuras,true,"denied direct reads do not disable native display")
eq(tank.buffs[1].buffState,"native")
eq(tank.buffs[1]:IsShown(),true,"assigned recast controls remain available")
eq(tank.buffs[1]:GetAttribute("spell"),1243,"exact cast rank preserved")
eq(tank.buffs[1]:GetAttribute("type1"),"spell")
eq(tank.buffs[1].timer:GetText(),"+")
for _,buttons in ipairs({tank.debuffs}) do
    for _,button in ipairs(buttons) do eq(button:IsShown(),false,"no duplicate manual aura display") end
end
state.units.party1,state.units.party2=state.units.party2,state.units.party1
for _,header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
eq(ns.Frames:RefreshRoster(),false)
ns.Frames:RefreshAll(false)
eq(tank.header:GetAttribute("nameList"),"Tank")
eq(SecureButton_GetUnit(tank.buffs[1]),"party2")
eq(tank.auraDisplay.unit,"party2","native display follows current secure unit")
eq(healDisplay.unit,"party2","healing aura display follows secure reorder")
for _,view in ipairs(healDisplay.views) do
    eq(view.container.boundUnit,"party2"); eq(view.container.enabled,true)
end
for _,view in ipairs(tank.auraDisplay.views) do
    eq(view.container.boundUnit,"party2"); eq(view.container.enabled,true)
end
-- A partial rebind fails closed and attempts only the public fallback APIs.
failBind=tank.auraDisplay.views[2].container
state.units.party1,state.units.party2=state.units.party2,state.units.party1
for _,header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
local before=readCount
ns.Frames:RefreshAll(false)
eq(tank.nativeAuras,false)
eq(readCount>before,true,"failed native binding attempts safe fallback")
for _,view in ipairs(tank.auraDisplay.views) do
    eq(view.holder:IsShown(),false,"old member icons cannot remain visible")
    eq(view.container.enabled,false)
end
eq(tank.debuffs[1]:IsShown(),false,"denied fallback does not invent aura data")
failBind=nil
ns.Frames:RefreshAll(false)
eq(tank.nativeAuras,true,"binding recovers on next display update")
-- The world-leave cleanup path must not be undone by periodic refreshes.
state.hover=tank.portraitArea
ns.Frames:RefreshAll(false)
visibleLayer("base")
ns.worldActive=false
ns.Frames:ClearPredictions()
eq(healDisplay.unit,nil,"world-leave clears assigned-heal aura binding")
visibleLayer(nil)
ns.Frames:RefreshAll(false)
eq(healDisplay.unit,nil,"loading refresh does not rebind")
visibleLayer(nil)
ns.worldActive=true
ns.Frames:RefreshAll(false)
eq(healDisplay.unit,"party1","world reentry restores binding")
visibleLayer("base")
-- Invoke the real OnHide callback as a secure header would; the fake does
-- not dispatch frame scripts from its Hide method.
tank:GetScript("OnHide")(tank)
eq(healDisplay.unit,nil,"hidden member clears all aura layers immediately")
visibleLayer(nil)
ns.Frames:RefreshAll(false)
eq(healDisplay.unit,"party1")
state.units.party1=nil
for _,header in ipairs(ns.Frames.headers) do state.reconcileHeader(header) end
ns.Frames:RefreshAll(false)
eq(tank.auraDisplay.unit,nil)
eq(healDisplay.unit,nil,"departed member clears healing indicators")
for _,view in ipairs(healDisplay.views) do
    eq(view.holder:GetAlpha(),0); eq(view.container.enabled,false)
end
for _,view in ipairs(tank.auraDisplay.views) do
    eq(view.holder:IsShown(),false); eq(view.container.enabled,false)
end
eq(#state.violations,0,"combat aura updates never mutate protected geometry or actions")
print("combat_auras_integration_spec: "..checks.." checks passed (native delegate simulated)")
