-- Unit-watch and aura delegates are simulated; not proof of engine security.
local ui=assert(loadfile("tests/wow_ui_fake.lua"))()()
local checks=0
local function eq(a,b,why)
    checks=checks+1
    assert(rawequal(a,b),(why or "unexpected value")..": "..tostring(a).." ~= "..tostring(b))
end
local enabled=true
local dispelOnly=false
GetCVarBool=function(name)
    if name=="showDispelDebuffs" then return dispelOnly end
    eq(name,"showPartyPets"); return enabled
end
local watches,containers={},{}
local function resolved(button)
    local owner=button.parent.attrs.unit
    return owner and owner:gsub("^party([1-4])$","partypet%1") or nil
end
local function nativeWatchTick()
    for button in pairs(watches) do
        local unit=resolved(button)
        button.shown=unit~=nil and ui.units[unit]~=nil
    end
end
RegisterUnitWatch=function(button)
    assert(not ui.combat,"watch registration is OOC")
    watches[button]=true; nativeWatchTick()
end
UnregisterUnitWatch=function(button)
    assert(not ui.combat,"watch deregistration is OOC")
    watches[button]=nil
end
local secret={}
local ns={InCombat=function() return ui.combat end,IsSecret=function(v) return v==secret or v==777 end}
C_AuraContainerUtil={}
Enum=Enum or {}
Enum.CustomAuraButtonDispelTypeTextureStyle={PreserveAsset=1}
Enum.LuaCurveType={Linear=1}
CustomAuraContainerAuraProcessingPolicy={ProcessAura=1}
AuraContainerSortMethod={UnitFrameDebuff=2}
local threatValue=0
local evaluatedThreat
IsThreatWarningEnabled=function() return true end
UnitThreatSituation=function() return threatValue end
UnitCanAssist=function() return true end
CreateColor=function(r,g,b,a) return {GetRGBA=function() return r,g,b,a end} end
C_CurveUtil={CreateColorCurve=function()
    return {SetType=function() end,AddPoint=function() end,Evaluate=function(_,value)
        evaluatedThreat=value
        return CreateColor(1,.6,0,.8)
    end}
end}
local original=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local f=original(kind,name,parent,template)
    if kind=="AuraContainer" then
        containers[#containers+1]=f
        function f:SetEnabled(value) self.enabled=value end
        function f:SetUnit(value) self.unit=value end
        function f:SetFlowLayoutMaximumLineSize(value) self.flow=value end
        function f:SetAuraProcessingPolicy(policy,options) self.policy=policy;self.processing=options end
        function f:AddAuraGroup(key,filter,options)
            self.key,self.filter,self.options=key,filter,options
            local aura=original("AuraButton",nil,self)
            function aura:SetIcon(v) self.icon=v end
            function aura:SetDurationCooldown(v) self.cooldown=v end
            function aura:SetDurationText(v) self.duration=v end
            function aura:SetApplicationCount(v) self.count=v end
            function aura:SetHideTooltipInCombat(v) self.SetHideTooltipInCombatArgs={v} end
            function aura:AddDispelTypeTexture(texture,options) self.border=texture;self.borderOptions=options end
            options.initializeFrame(aura)
            self.sample=aura
        end
    end
    return f
end
GameTooltip.SetUnit=function(self,unit) self.tooltipUnit=unit; return true end
GameTooltip.GetOwner=function(self) return self.SetOwnerArgs and self.SetOwnerArgs[1] end
UnitHealth=function(unit) return ui.units[unit] and ui.units[unit].health end
UnitHealthMax=function(unit) return ui.units[unit] and ui.units[unit].maxHealth end
UnitIsConnected=function(unit) return ui.units[unit] and ui.units[unit].connected~=false end
SetPortraitTexture=function(texture,unit) texture.portraitUnit=unit end
assert(loadfile("WowfPartyFrames/PartyPets.lua"))("WowfPartyFrames",ns)
local P=ns.PartyPets
local function card()
    local c=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
    c:SetAttribute("unit","party1")
    return c
end
ui.units.party1={}; ui.units.party2={}
local c=card()
eq(P:Create(c),true)
local state=c.partyPet
eq(state.supported,true); eq(state.enabled,true)
eq(state.button.parent,c)
eq(state.button.attrs.unit,nil,"never freeze the current roster slot onto pet")
eq(state.button.attrs["useparent-unit"],true)
eq(state.button.attrs.unitsuffix,"pet")
eq(state.button.attrs.type1,"target");eq(state.button.attrs["*type1"],"target")
eq(state.button.attrs.type2,"togglemenu");eq(state.button.attrs["*type2"],"togglemenu")
eq(state.button.attrs.useOnKeyDown,false,"normal pet target uses mouse release")
eq(state.button.attrs.checkselfcast,false)
eq(state.button.attrs.checkfocuscast,false)
eq(state.button.attrs.checkmouseovercast,false)
eq(state.button.width,174);eq(state.button.height,18)
eq(state.button.point[5],-130)
eq(state.button.shown,false,"absent pet has no ghost target region")
eq(P:Update(c),false)
eq(state.container.enabled,false)
eq(P:WantsSpace(),true)
eq(state.container.parent,state.button,"native presentation is below ordinary secure action, never its ancestor")
eq(state.container.filter,"HARMFUL")
eq(state.container.options.maxFrameCount,4)
eq(#state.containers,2,"both native filtering policies precreated before combat")
eq(state.container.options.sortMethod,AuraContainerSortMethod.UnitFrameDebuff)
eq(state.container.policy,CustomAuraContainerAuraProcessingPolicy.ProcessAura)
eq(state.container.processing.ignoreBuffs,true)
eq(state.container.processing.ignoreDispelDebuffs,false)
eq(state.container.processing.displayOnlyDispellableDebuffs,false)
eq(state.containers[2].processing.displayOnlyDispellableDebuffs,true)
eq(state.container.sample.borderOptions.showWhenHarmful,true)
eq(state.container.sample.borderOptions.showWhenHelpful,false)
eq(state.container.sample.borderOptions.showWithoutDispelType,true)
eq(state.container.sample.borderOptions.style,Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
eq(state.container.sample.SetMouseClickEnabledArgs[1],false)
eq(state.container.sample.SetMouseMotionEnabledArgs[1],true)
eq(state.container.sample.SetHideTooltipInCombatArgs[1],false)
eq(state.container.sample.cooldown.mouseEnabled,false)
eq(state.container.sample.attrs.type1,nil,"native aura contains no casting or targeting action")

-- Engine watcher, rather than addon code, shows a newly summoned pet in combat.
ui.combat=true
ui.units.partypet1={health=300,maxHealth=500}
nativeWatchTick()
eq(state.button.shown,true)
eq(P:Update(c),true)
eq(state.health.value,300);eq(state.health.maximum,500)
eq(state.text.format,"%d / %d")
eq(state.text.formatValues[1],300)
eq(state.container.unit,"partypet1");eq(state.container.enabled,true)
eq(state.portrait.portraitUnit,"partypet1")
threatValue=secret
P:Update(c)
eq(evaluatedThreat,secret,"opaque threat passes to native curve without comparison")
eq(state.threat.alpha,.8,"native curve alpha forwards to texture")
local originalDead,originalGhost=UnitIsDead,UnitIsGhost
UnitIsDead=function() return true end
P:Update(c)
eq(state.threat.alpha,0,"dead pet suppresses stale positive threat")
UnitIsDead=function() return false end
UnitIsGhost=function() return true end
P:Update(c)
eq(state.threat.alpha,0,"ghost pet suppresses stale positive threat")
UnitIsDead=function() return secret end
UnitIsGhost=function() return secret end
P:Update(c)
eq(state.threat.alpha,.8,"opaque death flags are never used as boolean conditions")
UnitIsDead,UnitIsGhost=originalDead,originalGhost
local allDebuffs=state.container
dispelOnly=true
P:Update(c)
eq(state.container,state.containers[2]);eq(allDebuffs.enabled,false)
eq(state.container.enabled,true);eq(state.container.unit,"partypet1")
UnitCanAssist=function() return false end
P:Update(c)
eq(state.container,allDebuffs,"non-assistable pet uses all debuffs like native frame")
eq(state.containers[2].enabled,false)
UnitCanAssist=function() return true end
dispelOnly=false
local threatCurve=state.threatCurve
state.threatCurve=nil
P:Update(c)
eq(state.threat.alpha,0,"missing native curve fails closed for secret threat")
state.threatCurve=threatCurve
state.button:GetScript("OnEnter")(state.button)
eq(GameTooltip.tooltipUnit,"partypet1")
eq(P:Configure(c),false)
eq(P:Create({}),false,"no additional controls created during combat")

-- Simulate the trusted header updating its named member's roster token.
ui.units.partypet2={health=0,maxHealth=700}
c.attrs.unit="party2"
nativeWatchTick()
eq(resolved(state.button),"partypet2","click target follows current owner token")
eq(P:Update(c),true)
eq(state.health.value,0,"dead pet health is a legitimate zero")
eq(state.container.unit,"partypet2")
eq(state.portrait.portraitUnit,"partypet2")
state.button:UpdateTooltip()
eq(GameTooltip.tooltipUnit,"partypet2")
local nativeSetUnit=GameTooltip.SetUnit
local nativeUnitName=UnitName
GameTooltip.SetUnit=function() return false end
UnitName=function() return "Companion" end
state.button:UpdateTooltip()
eq(GameTooltip:GetText(),"Companion","false native tooltip result falls back to public pet name")
GameTooltip.SetUnit=function() error("unavailable") end
UnitName=function() return secret end
state.button:UpdateTooltip()
eq(GameTooltip:GetText(),"Pet","failed native tooltip never displays a secret name")
GameTooltip.SetUnit=nativeSetUnit; UnitName=nativeUnitName
state.button:GetScript("OnLeave")(state.button)
eq(state.button.UpdateTooltip,nil);eq(GameTooltip.shown,false)
state.button:GetScript("OnEnter")(state.button)
local other=CreateFrame("Frame",nil,UIParent)
GameTooltip:SetOwner(other,"ANCHOR_RIGHT")
state.button:GetScript("OnHide")(state.button)
eq(state.button.UpdateTooltip,nil);eq(GameTooltip.shown,true,"pet hiding preserves another owner's tooltip")
state.button:GetScript("OnEnter")(state.button)
state.button:GetScript("OnHide")(state.button)
eq(state.button.UpdateTooltip,nil);eq(GameTooltip.shown,false,"hidden pet releases its own tooltip")
state.button:GetScript("OnEnter")(state.button)
ui.units.partypet2.health=777
eq(P:Update(c),true)
eq(state.health.value,777,"opaque numeric health passes directly to native setter")
eq(state.text.formatValues[1],777)
ui.units.partypet2.health=nil
eq(P:Update(c),true)
eq(state.health.value,0);eq(state.text:GetText(),"")
ui.units.partypet2=nil
nativeWatchTick()
eq(state.button.shown,false,"pet disappearance removes input in combat")
eq(P:Update(c),false);eq(state.container.enabled,false)
eq(state.health.value,0)
ui.units.partypet2={health=200,maxHealth=700}
nativeWatchTick();P:Update(c)
ns.worldActive=false
eq(P:Update(c),false);eq(state.container.enabled,false)
ns.worldActive=true
eq(P:Update(c),true);eq(state.container.enabled,true)
local previous=UnitExists
UnitExists=function() return secret end
eq(P:Update(c),false,"unreadable unit presence never drives addon visibility")
eq(state.container.enabled,false)
UnitExists=previous
c.attrs.unit=secret
eq(P:Update(c),false)
c.attrs.unit="party2"
eq(#ui.violations,0,"combat refresh never changes protected geometry, actions or visibility")

-- Some clients retain a pet token after its owner disconnects. The secure
-- watcher cannot see connectivity: keep a visible grey explanation in combat,
-- then unregister/hide out of combat rather than displaying stale pet HP.
ui.units.party2.connected=false
nativeWatchTick()
eq(state.button.shown,true,"engine still reports the stale pet token exists")
eq(P:Update(c),false)
eq(state.health.value,0,"disconnected owner clears stale pet health")
eq(state.threat.alpha,0,"offline owner clears stale pet threat")
eq(state.text:GetText(),"Owner offline")
eq(state.portrait.SetDesaturatedArgs[1],true)
eq(state.container.enabled,false,"disconnected owner clears stale pet auras")
eq(state.button.shown,true,"addon does not hide a protected target during combat")
eq(watches[state.button],true,"native watcher retains visibility authority")
eq(state.button.alpha,1,"offline pet row is visibly labelled, not a ghost hitbox")
state.button:UpdateTooltip()
eq(GameTooltip:GetText(),"Owner offline","offline tooltip does not expose stale native pet data")
eq(P:GetStatus(c):find("row hides after combat",1,true)~=nil,true)
eq(#ui.violations,0)
ui.combat=false
eq(P:Update(c),false)
eq(watches[state.button],nil,"disconnect unregisters watcher after combat")
eq(state.button.shown,false)
eq(P:GetStatus(c),"owner offline; pet row hidden.")
ui.units.party2.connected=true
eq(P:Update(c),true,"reconnecting owner re-enables a disabled row without roster/settings event")
eq(watches[state.button],true)
eq(state.button.shown,true)
eq(state.text.formatValues[1],200)
eq(state.portrait.SetDesaturatedArgs[1],false)
eq(state.container.enabled,true)

enabled=false
eq(P:Configure(c),true)
eq(watches[state.button],nil);eq(state.button.shown,false)
eq(P:WantsSpace(),false)
eq(P:Update(c),false)
enabled=true
eq(P:Configure(c),true);eq(watches[state.button],true)
eq(state.button.shown,true)
eq(P:Update(c),true)
P:Clear(c)
eq(state.container.enabled,false)
eq(state.button.shown,true,"clear leaves protected existence handling to native watcher")
eq(state.text:GetText(),"")
eq(P:Update(c),true);eq(state.container.enabled,true)

local oldAura=C_AuraContainerUtil
C_AuraContainerUtil=nil
local noAuras=card()
eq(P:Create(noAuras),true,"missing aura API does not remove safe native pet targeting")
eq(noAuras.partyPet.container,nil)
eq(noAuras.partyPet.button.attrs.type1,"target")
C_AuraContainerUtil=oldAura
local styles=Enum.CustomAuraButtonDispelTypeTextureStyle
Enum.CustomAuraButtonDispelTypeTextureStyle=nil
local noBorders=card()
eq(P:Create(noBorders),true,"unsupported native border API preserves safe pet targeting")
eq(noBorders.partyPet.container,nil,"unsupported aura presentation fails closed")
eq(type(noBorders.partyPet.auraReason),"string")
Enum.CustomAuraButtonDispelTypeTextureStyle=styles
local watch=RegisterUnitWatch
RegisterUnitWatch=nil
local unsupported=card()
eq(P:Create(unsupported),false)
eq(unsupported.partyPet.button,nil,"unsupported watcher creates no ghost region")
RegisterUnitWatch=watch
local preview=card();preview.previewIndex=1
eq(P:Create(preview),false,"preview does not invent a live secure pet target")
eq(preview.partyPet,nil)
eq(#ui.violations,0)
print("party_pets_spec: "..checks.." checks passed (native watcher simulated, not engine proof)")
