-- Structural/native-boundary tests, not an emulator or proof of the engine's
-- native rendering. Secure casting buttons are direct card children, visibly
-- grey while idle; separate native, mouse-disabled overlays signal debuffs.
-- No protected action may be placed inside the restricted native hierarchy.
local ui=assert(loadfile("tests/wow_ui_fake.lua"))()()
local checks, containers, nativeCalls, nativeReads=0,{}, {},0
local secret={}
local function eq(a,b,why)
    checks=checks+1
    assert(rawequal(a,b),(why or "unexpected value")..": "..tostring(a).." ~= "..tostring(b))
end
local function has(text,needle,why) eq(type(text)=="string" and text:find(needle,1,true)~=nil,true,why) end
local originalCreate=CreateFrame
local failures={}
local nativeDebuffs={}
local function nativePaint(container)
    for _,slot in pairs(container.slots) do
        local present=false
        local types=slot.filters and slot.filters.includeDispelTypes or {}
        for _,aura in ipairs(nativeDebuffs[container.unit] or {}) do
            if aura.removable and types[aura.kind] then present=true end
        end
        -- Direct field updates model trusted native visibility, deliberately
        -- bypassing the fake's addon-side protected frame mutation guard.
        slot.button.shown=container.enabled and slot.enabled and present or false
    end
end
local function setNativeDebuffs(unit,auras)
    nativeDebuffs[unit]=auras
    for _,container in ipairs(containers) do nativePaint(container) end
end
CreateFrame=function(kind,name,parent,template)
    local frame=originalCreate(kind,name,parent,template)
    if kind=="AuraContainer" then
        containers[#containers+1]=frame
        frame.slots={}
        function frame:SetEnabled(enabled)
            nativeCalls[#nativeCalls+1]={"enabled",self,enabled}
            if not enabled and failures.disable==self then error("native disable failed") end
            self.enabled=enabled
            nativePaint(self)
            if enabled and failures.enable==self then error("native enable failed after partial paint") end
        end
        function frame:SetUnit(unit)
            nativeCalls[#nativeCalls+1]={"unit",self,unit}
            if failures.bind==self then error("native bind failed") end
            self.unit=unit
            nativePaint(self)
        end
        function frame:AddAuraSlot(key,filter,options)
            local button=originalCreate("AuraButton",nil,self)
            button.shown=false
            function button:SetTooltipAnchorPoint(value) self.tooltipAnchor=value end
            function button:SetIcon(value) self.icon=value end
            function button:SetDurationCooldown(value) self.cooldown=value end
            function button:SetDurationText(value) self.duration=value end
            function button:SetApplicationCount(value) self.count=value end
            function button:AddDispelTypeTexture(texture,settings)
                self.dispelTextures=self.dispelTextures or {}
                self.dispelTextures[#self.dispelTextures+1]={texture=texture,settings=settings}
            end
            self.slots[key]={filter=filter,options=options,button=button,enabled=false,
                filters=options.candidateFilters}
            if failures.swallowedCallback~=key then options.initializeFrame(button) end
            local function forbidRead()
                nativeReads=nativeReads+1
                error("addon must not read native aura data or visibility")
            end
            button.GetAuraData,button.IsShown,button.IsVisible=forbidRead,forbidRead,forbidRead
            if failures.setupKey==key then error("native setup failed after creating separate action") end
        end
        function frame:SetAuraSlotEnabled(key,enabled)
            nativeCalls[#nativeCalls+1]={"slot-enabled",self,key,enabled}
            self.slots[key].enabled=enabled
            nativePaint(self)
        end
        function frame:SetAuraSlotCandidateFilters(key,filters)
            nativeCalls[#nativeCalls+1]={"filters",self,key,filters}
            if failures.filterKey==key then error("native filter failed") end
            self.slots[key].filters=filters
            nativePaint(self)
        end
    end
    return frame
end
Enum=Enum or {}
Enum.CustomAuraButtonDispelTypeTextureStyle={BorderWithIcon=1,PreserveAsset=2}
C_AuraContainerUtil={}
local actions={
    {key="Magic",spellID=988,types={Magic=true},record={icon=111}},
    {key="Disease",spellID=528,types={Disease=true},record={icon=222}},
}
local ns={InCombat=function() return ui.combat end,IsSecret=function(v) return rawequal(v,secret) end,
    worldActive=true,Cleanses={GetActions=function() return actions end},
    Visuals={DecorateSpellButton=function(_,button)
        if failures.decorate then
            failures.decorationButton=button
            error("spell decoration failed before slot registration")
        end
        button.icon=button:CreateTexture(nil,"ARTWORK")
        button.timer=button:CreateFontString(nil,"OVERLAY")
        button.glow=button:CreateTexture(nil,"OVERLAY")
    end}}
assert(loadfile("WowfPartyFrames/CleanseDisplay.lua"))("WowfPartyFrames",ns)
local D=ns.CleanseDisplay
local function newCard(previewIndex)
    local card=CreateFrame(previewIndex and "Frame" or "Button",nil,UIParent,
        not previewIndex and "SecureUnitButtonTemplate" or nil)
    card.portraitArea=CreateFrame("Frame",nil,card)
    card.previewIndex=previewIndex
    if not previewIndex then card:SetAttribute("unit","party1") end
    return card
end
-- Only the harness reads native fields to model whether an alert is visible.
-- The addon must not inspect the native aura or native visibility.
local function visible(frame)
    while frame do if not frame.shown then return false end;frame=frame.parent end
    return true
end
local function clickable(cast)
    return visible(cast) and cast.attrs.type1=="spell" and cast.attrs.spell~=nil
end
local function noNativeActions(frame)
    eq(frame.template and frame.template:find("SecureActionButtonTemplate",1,true)~=nil or false,false,
        "native aura trees contain no secure actions")
    for _,child in ipairs(frame.children) do noNativeActions(child) end
end
local function assignedUnit(frame)
    while frame do
        if frame.attrs.unit then return frame.attrs.unit end
        if not frame.attrs["useparent-unit"] then return nil end
        frame=frame.parent
    end
end
local card=newCard()
ui.units.party1={guid="one"};ui.units.party2={guid="two"}
eq(D:Create(card),true)
eq(D:Create(card),true)
eq(#containers,1,"create is idempotent")
local state=card.cleanseDisplay
local container=state.container
eq(container.parent,card)
eq(container.template,"CustomAuraContainerTemplate")
eq(D:Update(card,"party1"),false,"unconfigured casts never bind")
eq(D:Configure(card),true)
eq(state.actionCount,2)
for index=1,4 do
    local slot=container.slots["cleanse"..index]
    local cast=state.slots[index].cast
    eq(slot.filter,"HARMFUL|RAID","native filter checks this player's dispel capability")
    eq(cast.parent,card,"secure action is a direct card child outside the native tree")
    eq(cast.template,"SecureActionButtonTemplate")
    eq(cast.point[2],card.portraitArea)
    eq(cast.point[3],slot.button.point[3])
    eq(cast.point[4],slot.button.point[4],"native alert overlays the assigned action position")
    eq(cast.point[5],slot.button.point[5])
    eq(slot.button.mouseEnabled,false,"native alert intercepts neither clicks nor hover")
    eq(slot.button.cooldown.mouseEnabled,false)
    eq(cast.mouseEnabled,true,"ordinary action receives clicks")
    eq(slot.button.icon,nil,"native aura never replaces assigned spell artwork with a debuff icon")
    eq(state.slots[index].activeIcon.parent,slot.button)
    eq(state.slots[index].activeIcon.texture,cast.icon.texture,"full-color overlay uses assigned spell art")
    eq(cast.icon.SetDesaturatedArgs[1],true,"idle assigned spell artwork is grey")
    eq(cast.icon.SetVertexColorArgs[1],.4)
    eq(cast.icon.SetVertexColorArgs[2],.4)
    eq(cast.icon.SetVertexColorArgs[3],.4)
    eq(state.slots[index].activeIcon.SetDesaturatedArgs,nil,"native overlay preserves full color")
    eq(slot.button.width,36);eq(slot.button.height,36)
    eq(slot.button.point[2],card.portraitArea)
    eq(slot.button.point[3],"TOPRIGHT","cleanse area is right of portrait")
    eq(cast.attrs["checkselfcast"],false)
    eq(cast.attrs["checkfocuscast"],false)
    eq(cast.attrs["checkmouseovercast"],false)
    eq(cast.attrs["type2"],"togglemenu")
    eq(cast.attrs["*type2"],"togglemenu")
    eq(cast.attrs["useparent-unit"],true)
    eq(assignedUnit(cast),"party1")
    eq(slot.enabled,index<=2)
    eq(clickable(cast),index<=2,"configured idle actions remain visibly available")
    eq(cast.shown,index<=2,"unused slots have neither artwork nor hitboxes")
    eq(cast.alpha,1,"idle casting control is not transparent")
    eq(visible(slot.button),false,"native alert is hidden without a matching debuff")
    eq(#slot.button.dispelTextures,2,"native dispel border and glow are registered")
    eq(slot.button.dispelTextures[1].settings.showWhenHarmful,true)
    eq(slot.button.dispelTextures[1].settings.showWhenHelpful,false)
    eq(slot.button.duration~=nil,true)
    eq(slot.button.count~=nil,true)
end
noNativeActions(container)
eq(state.slots[1].cast.attrs.spell,988,"selected Magic rank remains exact")
eq(state.slots[2].cast.attrs.spell,528,"Cure Disease is not silently replaced by Abolish")
eq(container.slots.cleanse1.filters.includeDispelTypes.Magic,true)
eq(container.slots.cleanse1.filters.includeDispelTypes.Disease,nil)
eq(container.slots.cleanse2.filters.includeDispelTypes.Disease,true)
eq(state.slots[1].label:GetText(),"Magic")
eq(state.slots[2].label:GetText(),"Disease")
eq(D:Update(card,"party1"),true)
eq(container.enabled,true)
eq(clickable(state.slots[1].cast),true)
eq(visible(container.slots.cleanse1.button),false)
state.slots[1].cast:GetScript("OnEnter")(state.slots[1].cast)
eq(GameTooltip.SetSpellByIDArgs[1],988,"ordinary button tooltip identifies the assigned exact rank")
eq(GameTooltip.SetOwnerArgs[1],state.slots[1].cast)
eq(GameTooltip.SetOwnerArgs[2],"ANCHOR_RIGHT")
eq(GameTooltip.shown,true)
state.slots[1].cast:GetScript("OnLeave")(state.slots[1].cast)
eq(GameTooltip.shown,false)

ui.combat=true
local nativeBefore=#nativeCalls
eq(D:Configure(card),false,"configuration is frozen in combat")
eq(#nativeCalls,nativeBefore,"combat configure does not rewrite native filters")
eq(state.slots[1].cast.attrs.spell,988)
eq(D:Create({}),false,"combat does not create additional controls")
setNativeDebuffs("party1",{{kind="Magic",removable=false}})
eq(visible(container.slots.cleanse1.button),false,"a generic Magic debuff is not enough to light an alert")
eq(clickable(state.slots[1].cast),true,"grey action remains clickable without an alert")
setNativeDebuffs("party1",{{kind="Magic",removable=true}})
eq(visible(container.slots.cleanse1.button),true,"native aura reveals full-color alert")
eq(state.slots[1].activeIcon.texture,111,"alert shows assigned removal spell, not changing debuff artwork")
eq(clickable(state.slots[1].cast),true)
eq(visible(container.slots.cleanse2.button),false,"unneeded Disease remains grey without a native alert")
eq(clickable(state.slots[2].cast),true)
setNativeDebuffs("party1",{{kind="Magic",removable=true},{kind="Disease",removable=true}})
eq(visible(container.slots.cleanse2.button),true)
eq(clickable(state.slots[2].cast),true)
setNativeDebuffs("party1",{})
eq(visible(container.slots.cleanse1.button),false,"native expiry removes alert only")
eq(visible(container.slots.cleanse2.button),false)
eq(clickable(state.slots[1].cast),true,"expiry restores the visible grey action")
eq(clickable(state.slots[2].cast),true)
eq(state.slots[1].cast.alpha,1)
-- The secure header, rather than secret aura presence, owns card visibility.
card.shown=false
eq(clickable(state.slots[1].cast),false,"hiding the member card also hides its action")
eq(clickable(state.slots[2].cast),false)
card.shown=true
eq(clickable(state.slots[1].cast),true)
setNativeDebuffs("party2",{{kind="Disease",removable=true}})
-- Simulate the secure name-list header changing this card's unit token.
card.attrs.unit="party2"
eq(D:Update(card,"party2"),true)
eq(container.unit,"party2")
eq(assignedUnit(state.slots[2].cast),"party2","cast inherits the secure card's current token")
eq(visible(container.slots.cleanse1.button),false)
eq(clickable(state.slots[1].cast),true)
eq(visible(container.slots.cleanse2.button),true)
eq(clickable(state.slots[2].cast),true)
eq(#ui.violations,0,"addon performs no protected mutations during native combat refresh")
eq(nativeReads,0,"addon does not inspect the native aura or its visibility")

for _,bad in ipairs({secret,"player","party5",false}) do
    eq(D:Update(card,bad),false)
    eq(container.enabled,false)
    eq(visible(container.slots.cleanse2.button),false)
    eq(clickable(state.slots[2].cast),true,"invalid native binding cannot create an invisible cast region")
end
eq(D:Update(card,"party2"),true)
ui.units.party2=nil
eq(D:Update(card,"party2"),false,"missing unit releases native display")
eq(container.enabled,false);eq(state.unit,nil)
ui.units.party2={}
eq(D:Update(card,"party2"),true)
ns.worldActive=false
eq(D:Update(card,"party2"),false,"world unload releases native display even on unchanged unit")
eq(container.enabled,false);eq(visible(container.slots.cleanse2.button),false)
eq(clickable(state.slots[2].cast),true,"world unload clears native alert without changing protected action")
ns.worldActive=true
eq(D:Update(card,"party2"),true)
nativeBefore=#nativeCalls
D:Clear(card)
eq(nativeCalls[nativeBefore+1][1],"enabled")
eq(nativeCalls[nativeBefore+1][3],false,"clear uses native disable, not alpha")
eq(container.alpha,1,"no invisible alpha-zero casting surface")
eq(visible(container.slots.cleanse2.button),false)
eq(clickable(state.slots[2].cast),true,"Clear keeps the separate grey action visible")

failures.bind=container
eq(D:Update(card,"party1"),false)
eq(container.enabled,false)
has(D:GetStatus(card),"could not bind","binding failure is reported")
failures.bind=nil
failures.enable=container
eq(D:Update(card,"party2"),false)
eq(container.enabled,false,"failed native activation is released")
eq(visible(container.slots.cleanse2.button),false)
eq(clickable(state.slots[2].cast),true,"failed native activation leaves a visible grey action")
failures.enable=nil
eq(D:Update(card,"party2"),true)
failures.disable=container
eq(D:Update(card,"party1"),false,"failed release blocks a new binding")
has(D:GetStatus(card),"could not release","native release failure remains visible as a diagnostic")
eq(container.unit,"party2","failed release does not silently bind another unit")
eq(container.alpha,1,"hide failure never leaves an alpha-zero live hitbox")
eq(state.slots[2].cast.alpha,1)
eq(clickable(state.slots[2].cast),true)
eq(#ui.violations,0,"failed release does not attempt insecure protected Hide in combat")
failures.disable=nil
D:Clear(card)
ui.combat=false

-- Upstream actions are already deduplicated by spell; a multi-type action
-- gets a single native slot and secure button, not one button per dispel type.
actions={{key="Magic",spellID=4987,types={Magic=true,Disease=true,Poison=true},record={icon=333}}}
eq(D:Configure(card),true)
eq(state.actionCount,1)
eq(state.slots[1].cast.attrs.spell,4987)
eq(state.slots[1].label:GetText(),"Magic/Disease/Poison")
eq(container.slots.cleanse1.filters.includeDispelTypes.Poison,true)
eq(container.slots.cleanse1.filters.includeDispelTypes.Disease,true)
for index=2,4 do
    eq(container.slots["cleanse"..index].enabled,false)
    eq(state.slots[index].cast.attrs.type1,"")
    eq(state.slots[index].cast.attrs.spell,nil)
end
setNativeDebuffs("party2",{{kind="Poison",removable=true}})
eq(D:Update(card,"party2"),true)
eq(clickable(state.slots[1].cast),true)
eq(visible(container.slots.cleanse1.button),true)
eq(state.slots[1].activeIcon.texture,333)
eq(clickable(state.slots[2].cast),false)
noNativeActions(container)

-- Settings changes must restore native alerts immediately without waiting for
-- another roster/aura event. Changes to cached artwork also invalidate the
-- configuration signature even when spell rank and dispel types are unchanged.
setNativeDebuffs("party2",{{kind="Magic",removable=true}})
actions={{key="Magic",spellID=527,types={Magic=true},record={}}}
eq(D:Configure(card),true)
eq(state.unit,"party2","reconfigure immediately rebinds the card's current unit")
eq(container.unit,"party2")
eq(container.enabled,true,"assignment changes reactivate native display immediately")
eq(visible(container.slots.cleanse1.button),true,"new action alert does not wait for another event")
eq(state.slots[1].cast.attrs.spell,527)
eq(state.slots[1].cast.icon.texture,"Interface\\Icons\\INV_Misc_QuestionMark")
eq(state.slots[1].activeIcon.texture,"Interface\\Icons\\INV_Misc_QuestionMark")
actions[1].record.icon=444
eq(D:Configure(card),true)
eq(state.slots[1].cast.icon.texture,444,"new metadata refreshes idle spell art")
eq(state.slots[1].activeIcon.texture,444,"new metadata refreshes active spell art")
eq(state.unit,"party2")
eq(container.enabled,true)
eq(visible(container.slots.cleanse1.button),true)
nativeBefore=#nativeCalls
eq(D:Configure(card),true)
eq(#nativeCalls,nativeBefore,"unchanged metadata retains the fast path")

-- Setup/configuration failures must release partially built action trees OOC.
failures.decorate=true
local undecorated=newCard()
eq(D:Create(undecorated),false)
eq(undecorated.cleanseDisplay.supported,false)
eq(#undecorated.cleanseDisplay.slots,0,"decoration failed before returning its slot")
eq(failures.decorationButton.parent,undecorated)
eq(failures.decorationButton.shown,false,"action is hidden before any decoration may throw")
eq(failures.decorationButton.attrs.spell,nil)
eq(failures.decorationButton.attrs.type1,nil)
eq(clickable(failures.decorationButton),false,"unregistered partial action cannot intercept casting clicks")
eq(undecorated.cleanseDisplay.container.enabled,false)
eq(undecorated.cleanseDisplay.container.shown,false)
failures.decorate,failures.decorationButton=nil,nil
failures.setupKey="cleanse2"
local broken=newCard()
eq(D:Create(broken),false)
eq(broken.cleanseDisplay.supported,false)
eq(broken.cleanseDisplay.container.enabled,false)
eq(broken.cleanseDisplay.container.shown,false)
eq(clickable(broken.cleanseDisplay.slots[1].cast),false)
eq(clickable(broken.cleanseDisplay.slots[2].cast),false)
failures.setupKey=nil
failures.swallowedCallback="cleanse2"
local swallowed=newCard()
eq(D:Create(swallowed),false,"native callback errors cannot silently mark setup successful")
eq(swallowed.cleanseDisplay.container.shown,false)
eq(clickable(swallowed.cleanseDisplay.slots[1].cast),false,"partially built action tree stays hidden")
failures.swallowedCallback=nil
actions={{key="Magic",spellID=527,types={Magic=true},record={icon=111}}}
failures.filterKey="cleanse2"
eq(D:Configure(card),false)
eq(state.configured,false)
eq(container.enabled,false);eq(container.shown,false)
eq(clickable(state.slots[1].cast),false)
eq(D:Update(card,"party1"),false,"partially configured actions cannot bind")
failures.filterKey=nil
eq(D:Configure(card),true)
eq(state.slots[1].cast.attrs.spell,527,"reconfiguration preserves deliberately lower rank")
eq(D:Update(card,"party1"),true)
failures.disable=container
D:Clear(card)
eq(state.configured,false,"failed OOC release invalidates the unchanged-signature fast path")
eq(container.shown,false)
failures.disable=nil
eq(D:Configure(card),true,"same actions recover after a transient native release failure")
eq(container.shown,true)
eq(D:Update(card,"party1"),true)
actions={}
eq(D:Configure(card),true)
has(D:GetStatus(card),"no learned or assigned","empty configuration is reported")
for index=1,4 do eq(container.slots["cleanse"..index].enabled,false) end
for index=1,4 do eq(clickable(state.slots[index].cast),false,"removed actions are hidden and disarmed OOC") end

actions={
    {key="Magic",spellID=527,types={Magic=true},record={icon=111}},
    {key="Disease",spellID=528,types={Disease=true},record={icon=222}},
}
for previewIndex=1,4 do
    local preview=newCard(previewIndex)
    eq(D:Configure(preview),true)
    eq(preview.cleanseDisplay,nil,"preview never creates native secure action hierarchy")
    for index,button in ipairs(preview.cleansePreview) do
        eq(button.protected,false)
        eq(button.attrs.type1,nil,"preview never receives a casting action")
        eq(button.attrs.spell,nil)
        eq(button:GetScript("OnClick"),nil)
        eq(button.shown,index<=2,"assigned preview controls remain visible while idle")
        if index<=2 then
            local active=previewIndex==4 or previewIndex==index+1
            eq(button.icon.texture,actions[index].record.icon,"preview always shows assigned spell art")
            eq(button.icon.SetDesaturatedArgs[1],not active)
            eq(button.icon.SetVertexColorArgs[1],active and 1 or .4)
            eq(button.glow.alpha,active and 1 or 0,"preview glow follows synthetic active state")
            eq(button.timer:GetText(),active and (index==1 and "8s" or "24s") or "")
        end
    end
end
local api=C_AuraContainerUtil
C_AuraContainerUtil=nil
local unavailable=newCard()
eq(D:Create(unavailable),false)
has(D:GetStatus(unavailable),"unavailable","unsupported client remains noninteractive")
C_AuraContainerUtil=api
eq(nativeReads,0)
eq(#ui.violations,0)
print("cleanse_display_spec: "..checks.." checks passed (structural native-boundary tests, not engine proof)")
