local ui = assert(loadfile("tests/wow_ui_fake.lua"))()()
local secret, checks, containers = {}, 0, {}
local ns = { InCombat=function() return ui.combat end, IsSecret=function(v) return v == secret end,
    Spells={ GetAuraSpellIDs=function(_,id) return {[id]=true,[id+1]=true} end } }
local function equal(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local originalCreate = CreateFrame
local failBind, failFilter, failEnable, failDisable
CreateFrame=function(kind,name,parent,template)
    local frame=originalCreate(kind,name,parent,template)
    if kind=="AuraContainer" then
        containers[#containers+1]=frame
        frame.slots={}
        function frame:SetEnabled(enabled)
            if (enabled and self==failEnable) or (not enabled and self==failDisable) then error("enable failure") end
            self.enabled=enabled
        end
        function frame:SetUnit(unit)
            if self==failBind then error("bind failure") end
            self.unit=unit
        end
        function frame:AddAuraSlot(key,filter,options)
            local button=originalCreate("AuraButton",nil,self)
            function button:SetDurationText(text) self.duration=text end
            options.initializeFrame(button)
            -- Native frames become inaccessible to addon code after initialization.
            button.GetAuraData=function() error("must not inspect native aura") end
            button.IsShown=function() error("must not inspect native visibility") end
            self.slots[key]={filter=filter,button=button,options=options}
        end
        function frame:SetAuraSlotEnabled(key,enabled) self.slots[key].enabled=enabled end
        function frame:SetAuraSlotCandidateFilters(key,filters)
            if failFilter then error("filter failure") end
            self.slots[key].filters=filters
        end
    end
    return frame
end
C_AuraContainerUtil={ProcessCustomAuraButtonDurationTextOptions=function() end}
local exists=true
UnitExists=function() return exists end
assert(loadfile("WowfPartyFrames/HealAuraDisplay.lua"))("WowfPartyFrames",ns)
local D=ns.HealAuraDisplay
local card=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
card.heals={}
for index=1,4 do
    local button=CreateFrame("Button",nil,card,"SecureActionButtonTemplate")
    button.layerSpells={base=100,shift=200,ctrl=300,ctrlshift=400}
    button:SetAttribute("spell",100)
    card.heals[index]=button
end
equal(D:Create(card),true)
equal(D:Create(card),true)
equal(#containers,4,"one container per layer, created once")
equal(D:Update(card,"party1"),false,"must configure before binding")
equal(D:Configure(card),true)
for layerIndex,view in ipairs(card.healAuraDisplay.views) do
    equal(view.holder.alpha,0,"not visible until hovered and bound")
    for index=1,4 do
        local slot=view.container.slots["heal"..index]
        equal(slot.filter,"HELPFUL","any caster, not PLAYER filter")
        equal(slot.filters.includeSpellIDs[layerIndex*100],true)
        equal(slot.filters.includeSpellIDs[layerIndex*100+1],true,"matching rank family")
        equal(slot.button.allPoints[1],card.heals[index],"correct clickable control")
        equal(slot.button.mouseEnabled,false,"clicks reach cast button")
        equal(slot.button.duration.point[1],"CENTER","rank corners remain free")
        equal(slot.button.duration~=nil,true)
        equal(card.heals[index]:GetAttribute("spell"),100,"cast attributes untouched")
    end
end
equal(D:Update(card,"party1"),true)
D:SetVisible(card,"base",true)
equal(card.healAuraDisplay.views[1].holder.alpha,1)
ui.combat=true
equal(D:Configure(card),false,"filters never mutate during combat")
D:SetVisible(card,"ctrlshift",true)
for index,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,index==4 and 1 or 0) end
D:SetVisible(card,"alt",true)
for _,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,0) end
D:SetVisible(card,"shift",true)
equal(D:Update(card,"party2"),true,"combat rebind")
for _,view in ipairs(card.healAuraDisplay.views) do equal(view.container.unit,"party2") end
equal(#ui.violations,0,"no protected UI mutation")
for _,badUnit in ipairs({secret,"player","party5",false}) do
    equal(D:Update(card,badUnit),false)
    for _,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,0) end
end
exists=false
equal(D:Update(card,"party1"),false,"missing unit clears")
exists=secret
equal(D:Update(card,"party1"),false,"secret existence is not branched on")
exists=true
equal(D:Update(card,"party1"),true)
failBind=containers[3]
equal(D:Update(card,"party2"),false)
for _,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,0); equal(view.container.enabled,false) end
failBind=nil
equal(D:Update(card,"party2"),true,"retry after native error")
failDisable=containers[2]
equal(D:Update(card,"party3"),false,"do not bind when old owner cannot release")
for _,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,0) end
failDisable=nil
failEnable=containers[4]
equal(D:Update(card,"party3"),false)
for _,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,0) end
failEnable=nil
ui.combat=false
failFilter=true
equal(D:Configure(card),false)
equal(D:Update(card,"party1"),false,"failed configure cannot reveal mixed profile")
failFilter=false
card.heals[1].layerSpells.base=nil
equal(D:Configure(card),true)
equal(containers[1].slots.heal1.enabled,false)
equal(next(containers[1].slots.heal1.filters.includeSpellIDs),nil)
equal(D:Update(card,"party1"),true)
D:Clear(card)
equal(card.healAuraDisplay.unit,nil)
for _,view in ipairs(card.healAuraDisplay.views) do equal(view.holder.alpha,0) end
C_AuraContainerUtil=nil
local unsupported=CreateFrame("Frame",nil,UIParent)
equal(D:Create(unsupported),false,"unavailable native API makes no active claim")
equal(unsupported.healAuraDisplay.supported,false)
print("heal_aura_display_spec: " .. checks .. " checks passed")
