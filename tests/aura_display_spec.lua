local ui = assert(loadfile("tests/wow_ui_fake.lua"))()()
local secret = {}
local ns = { MAX_BUFFS=8, Spells={GetAuraSpellIDs=function(_,id) return {[id]=true,[id+1]=true} end}, Layout = { auraX=44, debuffY=-64, buffY=-84, auraSize=16, auraPitch=17 },
    InCombat=function() return ui.combat end, IsSecret=function(value) return value == secret end }
local checks, calls, containers = 0, {}, {}
local function equal(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local originalCreate = CreateFrame
local failCreation, failBind, failEnable, failDisable, failFilters
CreateFrame = function(kind,name,parent,template)
    if kind == "AuraContainer" and failCreation then error("Unknown frame type") end
    local frame = originalCreate(kind,name,parent,template)
    if kind == "AuraContainer" then
        frame.number = #containers + 1
        containers[#containers+1] = frame
        function frame:SetEnabled(enabled)
            calls[#calls+1] = {"enabled", self.number, enabled}
            if (enabled and self == failEnable) or (not enabled and self == failDisable) then error("Native enable failed") end
            self.enabled = enabled
        end
        function frame:SetUnit(unit)
            calls[#calls+1] = {"unit", self.number, unit}
            if self == failBind then error("Native bind failed") end
            self.boundUnit = unit
        end
        function frame:SetFlowLayoutMaximumLineSize(width) self.lineWidth=width end
        local function iconFor(options)
            local icon = originalCreate("AuraButton",nil,frame)
            function icon:SetIcon(value) self.icon=value end
            function icon:SetDurationCooldown(value) self.cooldown=value end
            function icon:SetDurationText(value) self.duration=value end
            function icon:SetApplicationCount(value) self.count=value end
            function icon:SetHideTooltipInCombat(value) self.hideTooltipInCombat=value end
            options.initializeFrame(icon)
            return icon
        end
        function frame:AddAuraGroup(key,filter,options)
            self.group={key=key,filter=filter,options=options}
            self.testIcon=iconFor(options)
        end
        function frame:SetAuraGroupMaxFrameCount(key,value) self.group.options.maxFrameCount=value end
        function frame:SetAuraGroupCandidateFilters(key,value) self.group.filters=value end
        function frame:AddAuraSlot(key,filter,options)
            self.slots=self.slots or {}
            self.slots[key]={filter=filter,options=options,icon=iconFor(options)}
        end
        function frame:SetAuraSlotEnabled(key,value) self.slots[key].enabled=value end
        function frame:SetAuraSlotCandidateFilters(key,value)
            if failFilters then error("filter failed") end
            self.slots[key].filters=value
        end
    end
    return frame
end
C_AuraContainerUtil = { ProcessCustomAuraButtonDurationTextOptions=function() end }
assert(loadfile("WowfPartyFrames/AuraDisplay.lua"))("WowfPartyFrames",ns)
local D=ns.AuraDisplay
local card=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
card.buffs={}
for i=1,8 do
    card.buffs[i]=CreateFrame("Button",nil,card,"SecureActionButtonTemplate")
    card.buffs[i]:SetAttribute("spell",100+i)
end
card.buffs[1].spellID=100
equal(D:Create(card),true)
equal(#card.auraDisplay.views,3)
equal(D:Create(card),true)
equal(#containers,3,"creation is idempotent")
for index,view in ipairs(card.auraDisplay.views) do
    local container=view.container
    equal(view.holder.protected,false,"holder has no protected template")
    equal(view.holder:IsShown(),false)
    equal(container.kind,"AuraContainer")
    equal(container.template,"CustomAuraContainerTemplate")
end
local harmful=containers[1]
equal(harmful.parent.width,135)
equal(harmful.parent.point[4],44)
equal(harmful.parent.point[5],-64)
equal(harmful.group.filter,"HARMFUL")
equal(harmful.group.options.maxFrameCount,8)
equal(harmful.lineWidth,135)
equal(harmful.testIcon.duration~=nil,true)
equal(harmful.testIcon.SetMouseClickEnabledArgs[1],false,"debuff clicks pass through to member actions")
equal(containers[3].testIcon.SetMouseClickEnabledArgs[1],false,"extra buff clicks pass through to member actions")
for _, icon in ipairs({harmful.testIcon, containers[3].testIcon}) do
    equal(icon.SetMouseMotionEnabledArgs[1],true,"unassigned auras receive native hover events")
    equal(icon.hideTooltipInCombat,false,"native details remain available in combat")
    equal(icon:GetScript("OnEnter"),nil,"addon does not replace native tooltip handlers")
    equal(icon.cooldown.mouseEnabled,false,"cooldown does not intercept native hover")
end
local helpful=containers[2]
equal(helpful.group,nil,"no second all-helpful row")
equal(helpful.parent.allPoints[1],card)
equal(D:Update(card,"party1"),false,"no unconfigured native slots shown")
equal(D:ConfigureBuffs(card),true)
for i=1,8 do
    local slot=helpful.slots["buff"..i]
    equal(slot.filter,"HELPFUL")
    equal(slot.icon.point[2],card.buffs[i],"same physical recast slot")
    equal(slot.icon.SetMouseClickEnabledArgs[1],false,"native visual does not intercept clicks")
    equal(slot.icon.SetMouseMotionEnabledArgs[1],false,"assigned overlay leaves spell tooltip to cast button")
    equal(slot.icon.cooldown.mouseEnabled,false)
    equal(slot.icon.level>card.buffs[i].level,true)
    equal(slot.icon.duration~=nil,true)
    equal(slot.enabled,i==1)
    equal(card.buffs[i]:GetAttribute("spell"),100+i,"cast rank untouched")
end
equal(helpful.slots.buff1.filters.includeSpellIDs[100],true)
equal(helpful.slots.buff1.filters.includeSpellIDs[101],true,"other ranks can match")
ui.combat=true
local oldFilters=helpful.slots.buff1.filters
equal(D:ConfigureBuffs(card),false)
equal(helpful.slots.buff1.filters,oldFilters,"combat does not rewrite slot filters")
ui.combat=false
card.buffs[1].spellID=nil
card.buffs[2].spellID=200
equal(D:ConfigureBuffs(card),true)
equal(helpful.slots.buff1.enabled,false)
equal(next(helpful.slots.buff1.filters.includeSpellIDs),nil,"old spell map removed")
equal(helpful.slots.buff2.filters.includeSpellIDs[200],true)
equal(containers[3].group.options.maxFrameCount,7,"empty saved slots do not consume aura capacity")
equal(containers[3].group.filters.excludeSpellIDs[200],true)
equal(containers[3].group.filters.excludeSpellIDs[100],nil,"old exclusion removed")
equal(containers[3].parent.point[4],61,"extras follow the compacted configured buttons")
equal(containers[3].parent.point[5],-84,"same buff row")
card.buffs[8].spellID=800
equal(D:ConfigureBuffs(card),true)
equal(containers[3].group.options.maxFrameCount,6,"sparse high slot still leaves room for other buffs")
equal(containers[3].parent.point[4],78,"two configured buffs occupy only two positions")
card.buffs[8].spellID=nil
card.buffs[2].spellID=nil
equal(D:ConfigureBuffs(card),true)
equal(containers[3].group.options.maxFrameCount,8,"empty preset still shows other active buffs")
equal(containers[3].group.filters,nil,"no spell identity filter when no buffs are configured")
equal(containers[3].parent.point[4],44)
failFilters=true
equal(D:ConfigureBuffs(card),false)
equal(D:Update(card,"party1"),false)
for _,view in ipairs(card.auraDisplay.views) do equal(view.holder:IsShown(),false) end
failFilters=false
equal(D:ConfigureBuffs(card),true)
calls={}
equal(D:Update(card,"party1"),true)
equal(#calls,9,"disable all, bind all, enable all")
equal(calls[1][1],"enabled")
equal(calls[1][3],false)
equal(calls[2][3],false)
equal(calls[3][3],false)
equal(calls[4][1],"unit")
equal(calls[5][1],"unit")
equal(calls[6][1],"unit")
equal(calls[7][3],true)
equal(calls[9][3],true)
equal(card.auraDisplay.unit,"party1")
equal(D:Update(card,"party1"),true)
equal(#calls,9,"same unit never tears down native rendering")
ui.combat=true
equal(D:Update(card,"party2"),true,"native delegated rebind works without geometry changes")
for _,view in ipairs(card.auraDisplay.views) do
    equal(view.container.boundUnit,"party2")
    equal(view.holder:IsShown(),true)
end
equal(#ui.violations,0)
failBind=containers[2]
equal(D:Update(card,"party3"),false)
equal(card.auraDisplay.unit,nil)
for _,view in ipairs(card.auraDisplay.views) do
    equal(view.holder:IsShown(),false,"partial rebind cannot show stale recipient")
    equal(view.container.enabled,false)
end
failBind=nil
equal(D:Update(card,"party3"),true,"failed bindings retry safely")
failEnable=containers[2]
equal(D:Update(card,"party4"),false)
equal(card.auraDisplay.unit,nil)
for _,view in ipairs(card.auraDisplay.views) do equal(view.holder:IsShown(),false) end
failEnable=nil
equal(D:Update(card,"party4"),true)
failDisable=containers[1]
equal(D:Update(card,"party1"),false)
equal(containers[1].boundUnit,"party4","failed cleanup prevents a new unit bind")
for _,view in ipairs(card.auraDisplay.views) do equal(view.holder:IsShown(),false) end
failDisable=nil
equal(D:Update(card,"party1"),true)
equal(D:Update(card,nil),false)
equal(card.auraDisplay.unit,nil)
for _,view in ipairs(card.auraDisplay.views) do equal(view.holder:IsShown(),false) end
equal(D:Update(card,secret),false,"secret tokens are never inspected or passed to native")
equal(D:Update(card,"target"),false)
local late=CreateFrame("Frame",nil,UIParent)
equal(D:Create(late),false,"no presentation objects created during combat")
equal(late.auraDisplay,nil)
ui.combat=false
C_AuraContainerUtil=nil
local unsupported=CreateFrame("Frame",nil,UIParent)
equal(D:Create(unsupported),false)
equal(D:Update(unsupported,"party1"),false)
equal(#unsupported.auraDisplay.views,0)
C_AuraContainerUtil={ProcessCustomAuraButtonDurationTextOptions=function() end}
failCreation=true
local missingTemplate=CreateFrame("Frame",nil,UIParent)
equal(D:Create(missingTemplate),false,"missing template falls back instead of breaking startup")
equal(missingTemplate.auraDisplay.views[1].holder:IsShown(),false)
equal(D:Update(missingTemplate,"party1"),false)
equal(#ui.violations,0)
print("aura_display_spec: " .. checks .. " checks passed")
