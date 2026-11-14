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
    if kind=="Frame" and failures.textureParent==parent then
        frame.CreateTexture=function()
            failures.partialArt=frame
            error("arc texture construction failed")
        end
    end
    if template=="SecureActionButtonTemplate" and failures.hitSize then
        failures.hitSize=failures.hitSize-1
        if failures.hitSize==0 then
            frame.SetSize=function()
                failures.partialHit=frame
                error("strip size failed after registration")
            end
        end
    end
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
    worldActive=true,db={controlStyle="buttons"},Cleanses={GetActions=function() return actions end}}
assert(loadfile("WowfPartyFrames/CleanseGeometry.lua"))("WowfPartyFrames",ns)
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
-- Only this harness reads native fields. Production must never inspect native
-- aura values/visibility to decide whether a secure hit region should exist.
local function visible(frame)
    while frame do if not frame.shown then return false end;frame=frame.parent end
    return true
end
local function clickable(cast)
    return visible(cast) and cast.attrs.type1=="spell" and cast.attrs.spell~=nil
end
local function first(slot) return slot.buttons[1] end
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
local function disarmed(slot)
    eq(slot.art and slot.art.shown or false,false,"unassigned or failed art is hidden")
    for _,cast in ipairs(slot.buttons) do
        eq(cast.shown,false,"unused strips are hidden")
        eq(cast.attrs.type1,"")
        eq(cast.attrs["*type1"],"")
        eq(cast.attrs.spell,nil,"unused strips cannot retain an old rank")
        eq(clickable(cast),false)
    end
end
local function allDisarmed(state)
    for _,slot in ipairs(state.slots) do disarmed(slot) end
end
local function snapshot(state)
    local result={}
    for _,slot in ipairs(state.slots) do
        for _,cast in ipairs(slot.buttons) do
            local attributes={};for key,value in pairs(cast.attrs) do attributes[key]=value end
            result[#result+1]={cast=cast,point={unpack(cast.point)},width=cast.width,height=cast.height,
                shown=cast.shown,attrs=attributes}
        end
    end
    return result
end
local function unchanged(saved)
    for _,entry in ipairs(saved) do
        local cast=entry.cast
        eq(cast.width,entry.width,"native aura changes cannot resize hit regions")
        eq(cast.height,entry.height)
        eq(cast.shown,entry.shown,"idle and active casting geometry remains fixed")
        for index,value in ipairs(entry.point) do eq(cast.point[index],value) end
        for key,value in pairs(entry.attrs) do eq(cast.attrs[key],value,"secure attributes remain unchanged") end
        for key,value in pairs(cast.attrs) do eq(entry.attrs[key],value,"no new secure attributes appear") end
    end
end
local function assigned(card,slot,action)
    local g=slot.geometry
    eq(g~=nil,true)
    eq(slot.art.shown,true)
    eq(slot.art.mouseEnabled,false,"arc artwork is not a broad rectangular input surface")
    eq(slot.art.width,g.artSize)
    eq(slot.fill.texture,g.textureBase.."-fill.tga")
    eq(slot.rim.texture,g.textureBase.."-rim.tga")
    eq(slot.iconAnchor.point[2],card.portraitArea)
    eq(slot.iconAnchor.point[4],g.iconX)
    eq(slot.iconAnchor.point[5],-g.iconY)
    eq(slot.icon.texture,action.record.icon)
    eq(slot.spellID,action.spellID)
    eq(#slot.buttons>=#g.rects,true)
    for index,cast in ipairs(slot.buttons) do
        eq(cast.parent,card,"every secure strip is directly parented outside the native tree")
        eq(cast.template,"SecureActionButtonTemplate")
        eq(cast.mouseEnabled,true)
        eq(cast:GetFrameLevel(),card.portraitArea:GetFrameLevel()+1,"radial controls stay below healing layer")
        eq(cast.attrs.checkselfcast,false)
        eq(cast.attrs.checkfocuscast,false)
        eq(cast.attrs.checkmouseovercast,false)
        eq(cast.attrs.type2,"togglemenu")
        eq(cast.attrs["*type2"],"togglemenu")
        eq(cast.attrs["useparent-unit"],true)
        eq(cast.attrs.useOnKeyDown,true,"press casts before pointer motion can cross a narrow strip")
        eq(assignedUnit(cast),card.attrs.unit)
        if index<=#g.rects then
            local r=g.rects[index]
            eq(cast.point[2],card.portraitArea)
            eq(cast.point[3],"CENTER")
            eq(cast.point[4],r.x);eq(cast.point[5],-r.y)
            eq(cast.width,r.width);eq(cast.height,r.height)
            eq(cast.attrs.type1,"spell");eq(cast.attrs["*type1"],"spell")
            eq(cast.attrs.spell,action.spellID,"all pieces of the arc cast the same exact rank")
            eq(cast.shown,true);eq(cast.alpha,1);eq(clickable(cast),true)
        else
            eq(cast.shown,false,"surplus pooled strips do not retain ghost targets")
            eq(cast.attrs.type1,"");eq(cast.attrs["*type1"],"");eq(cast.attrs.spell,nil)
        end
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
    local native=container.slots["cleanse"..index]
    local slot=state.slots[index]
    eq(native.filter,"HARMFUL|RAID","native filter checks this player's dispel capability")
    eq(native.button.allPoints[1],slot.art,"native alert follows visible radial artwork")
    eq(native.button.mouseEnabled,false,"native alert intercepts neither clicks nor hover")
    eq(native.button.cooldown.mouseEnabled,false)
    eq(native.button.cooldown.SetDrawSwipeArgs[1],false,"square swipe never spills outside round icon")
    eq(native.button.icon,nil,"native aura never replaces assigned spell art with debuff art")
    eq(slot.activeIcon.parent,native.button)
    eq(slot.activeIcon.texture,slot.icon.texture)
    eq(slot.icon.SetDesaturatedArgs[1],true,"idle assigned spell art is grey")
    eq(slot.icon.SetVertexColorArgs[1],.4)
    eq(slot.icon.SetVertexColorArgs[2],.4)
    eq(slot.icon.SetVertexColorArgs[3],.4)
    eq(slot.activeIcon.SetDesaturatedArgs,nil,"native overlay preserves full color")
    eq(native.enabled,index<=2)
    eq(visible(native.button),false,"native alert is absent until removable debuff appears")
    eq(#native.button.dispelTextures,3,"native color owns radial fill, rim, and glow")
    for _,entry in ipairs(native.button.dispelTextures) do
        eq(entry.settings.showWhenHarmful,true)
        eq(entry.settings.showWhenHelpful,false)
        eq(entry.settings.style,Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
    end
    eq(native.button.duration~=nil,true);eq(native.button.count~=nil,true)
    if index<=2 then assigned(card,slot,actions[index]) else disarmed(slot) end
end
noNativeActions(container)
eq(first(state.slots[1]).attrs.spell,988,"selected Magic rank remains exact")
eq(first(state.slots[2]).attrs.spell,528,"Cure Disease is not replaced by Abolish")
eq(container.slots.cleanse1.filters.includeDispelTypes.Magic,true)
eq(container.slots.cleanse1.filters.includeDispelTypes.Disease,nil)
eq(container.slots.cleanse2.filters.includeDispelTypes.Disease,true)
eq(state.slots[1].types,"Magic");eq(state.slots[2].types,"Disease")
eq(D:Update(card,"party1"),true)
eq(container.enabled,true)
local hit=first(state.slots[1])
hit:GetScript("OnEnter")(hit)
eq(GameTooltip.SetSpellByIDArgs[1],988,"ordinary strip tooltip identifies assigned exact rank")
eq(GameTooltip.SetOwnerArgs[1],state.slots[1].iconAnchor,"tooltip has stable anchor across narrow strips")
eq(GameTooltip.SetOwnerArgs[2],"ANCHOR_RIGHT");eq(GameTooltip.shown,true)
hit:GetScript("OnLeave")(hit);eq(GameTooltip.shown,false)

-- Switching styles keeps a reusable pool but shrinks the active input geometry.
local poolBefore=#state.slots[1].buttons
local firstBefore=first(state.slots[1])
local oldGeometry=state.slots[1].geometry
ns.db.controlStyle="quadrants"
eq(D:Configure(card),true)
eq(state.slots[1].geometry.outer,64)
eq(state.slots[1].geometry==oldGeometry,false,"style alone invalidates configuration signature")
eq(first(state.slots[1]),firstBefore,"style changes reuse existing secure buttons")
eq(#state.slots[1].buttons,poolBefore)
eq(#state.slots[1].geometry.rects<poolBefore,true,"round style needs fewer hit strips")
for index=1,2 do assigned(card,state.slots[index],actions[index]) end
ns.db.controlStyle="buttons"
eq(D:Configure(card),true)
eq(state.slots[1].geometry.outer,76)
eq(first(state.slots[1]),firstBefore)
eq(#state.slots[1].buttons,poolBefore,"returning to square style does not leak frames")
for index=1,2 do assigned(card,state.slots[index],actions[index]) end

ui.combat=true
local nativeBefore=#nativeCalls
local fixed=snapshot(state)
oldGeometry=state.slots[1].geometry
ns.db.controlStyle="quadrants"
eq(D:Configure(card),false,"configuration and geometry freeze in combat")
eq(state.slots[1].geometry,oldGeometry)
eq(#nativeCalls,nativeBefore,"combat configure cannot rewrite native filters")
eq(D:Create({}),false,"combat does not create additional controls")
ns.db.controlStyle="buttons"
setNativeDebuffs("party1",{{kind="Magic",removable=false}})
eq(visible(container.slots.cleanse1.button),false,"generic Magic debuff is insufficient for alert")
setNativeDebuffs("party1",{{kind="Magic",removable=true}})
eq(visible(container.slots.cleanse1.button),true,"native aura reveals full-color alert")
eq(state.slots[1].activeIcon.texture,111)
eq(visible(container.slots.cleanse2.button),false)
unchanged(fixed)
setNativeDebuffs("party1",{{kind="Magic",removable=true},{kind="Disease",removable=true}})
eq(visible(container.slots.cleanse2.button),true)
setNativeDebuffs("party1",{})
eq(visible(container.slots.cleanse1.button),false,"expiry removes only the alert")
eq(visible(container.slots.cleanse2.button),false)
unchanged(fixed)
eq(visible(state.slots[1].art),true,"idle artwork remains visible, not a ghost button")
eq(clickable(first(state.slots[1])),true)
eq(clickable(first(state.slots[2])),true)
card.shown=false
eq(clickable(first(state.slots[1])),false,"hiding member card hides its secure strips")
eq(clickable(first(state.slots[2])),false)
card.shown=true
eq(clickable(first(state.slots[1])),true)
setNativeDebuffs("party2",{{kind="Disease",removable=true}})
card.attrs.unit="party2"
eq(D:Update(card,"party2"),true)
eq(container.unit,"party2")
for _,slot in ipairs(state.slots) do
    for _,cast in ipairs(slot.buttons) do eq(assignedUnit(cast),"party2","all strips inherit reordered unit") end
end
eq(visible(container.slots.cleanse1.button),false)
eq(visible(container.slots.cleanse2.button),true)
eq(#ui.violations,0,"native combat refresh never mutates protected controls")
eq(nativeReads,0,"addon never reads native aura data/visibility")
for _,bad in ipairs({secret,"player","party5",false}) do
    eq(D:Update(card,bad),false)
    eq(container.enabled,false)
    eq(visible(container.slots.cleanse2.button),false)
    eq(clickable(first(state.slots[2])),true,"invalid binding leaves visible grey action")
end
eq(D:Update(card,"party2"),true)
ui.units.party2=nil
eq(D:Update(card,"party2"),false,"missing unit releases native display")
eq(container.enabled,false);eq(state.unit,nil)
ui.units.party2={}
eq(D:Update(card,"party2"),true)
ns.worldActive=false
eq(D:Update(card,"party2"),false,"world unload releases even unchanged unit")
eq(container.enabled,false);eq(visible(container.slots.cleanse2.button),false)
eq(clickable(first(state.slots[2])),true)
ns.worldActive=true
eq(D:Update(card,"party2"),true)
nativeBefore=#nativeCalls
D:Clear(card)
eq(nativeCalls[nativeBefore+1][1],"enabled");eq(nativeCalls[nativeBefore+1][3],false)
eq(container.alpha,1,"clear never substitutes alpha-zero native casting surface")
eq(visible(container.slots.cleanse2.button),false)
eq(clickable(first(state.slots[2])),true)
failures.bind=container
eq(D:Update(card,"party1"),false)
eq(container.enabled,false)
has(D:GetStatus(card),"could not bind","binding failure is reported")
failures.bind=nil
failures.enable=container
eq(D:Update(card,"party2"),false)
eq(container.enabled,false,"partial activation is released")
eq(visible(container.slots.cleanse2.button),false)
eq(clickable(first(state.slots[2])),true)
failures.enable=nil
eq(D:Update(card,"party2"),true)
failures.disable=container
eq(D:Update(card,"party1"),false,"failed release blocks a new binding")
has(D:GetStatus(card),"could not release")
eq(container.unit,"party2")
eq(container.alpha,1)
eq(clickable(first(state.slots[2])),true)
eq(#ui.violations,0,"failed native release cannot cause insecure combat Hide")
unchanged(fixed)
failures.disable=nil
D:Clear(card)
ui.combat=false

-- Combined dispels use one arc, not duplicate arcs for every dispel type.
actions={{key="Magic",spellID=4987,types={Magic=true,Disease=true,Poison=true},record={icon=333}}}
eq(D:Configure(card),true)
eq(state.actionCount,1)
assigned(card,state.slots[1],actions[1])
eq(state.slots[1].types,"Magic/Disease/Poison")
eq(container.slots.cleanse1.filters.includeDispelTypes.Poison,true)
eq(container.slots.cleanse1.filters.includeDispelTypes.Disease,true)
for index=2,4 do eq(container.slots["cleanse"..index].enabled,false);disarmed(state.slots[index]) end
setNativeDebuffs("party2",{{kind="Poison",removable=true}})
eq(D:Update(card,"party2"),true)
eq(visible(container.slots.cleanse1.button),true)
eq(state.slots[1].activeIcon.texture,333)
noNativeActions(container)

-- Configure rebinding and metadata refresh must not wait for a later event.
setNativeDebuffs("party2",{{kind="Magic",removable=true}})
actions={{key="Magic",spellID=527,types={Magic=true},record={}}}
eq(D:Configure(card),true)
eq(state.unit,"party2");eq(container.unit,"party2");eq(container.enabled,true)
eq(visible(container.slots.cleanse1.button),true)
eq(first(state.slots[1]).attrs.spell,527)
eq(state.slots[1].icon.texture,"Interface\\Icons\\INV_Misc_QuestionMark")
eq(state.slots[1].activeIcon.texture,"Interface\\Icons\\INV_Misc_QuestionMark")
actions[1].record.icon=444
eq(D:Configure(card),true)
eq(state.slots[1].icon.texture,444);eq(state.slots[1].activeIcon.texture,444)
eq(state.unit,"party2");eq(container.enabled,true);eq(visible(container.slots.cleanse1.button),true)
nativeBefore=#nativeCalls
eq(D:Configure(card),true)
eq(#nativeCalls,nativeBefore,"unchanged configuration retains fast path")

-- All selected unique actions remain available when there are more than two.
actions={
    {key="Magic",spellID=527,types={Magic=true},record={icon=111}},
    {key="Disease",spellID=528,types={Disease=true},record={icon=222}},
    {key="Poison",spellID=526,types={Poison=true},record={icon=333}},
    {key="Curse",spellID=475,types={Curse=true},record={icon=444}},
}
eq(D:Configure(card),true);eq(state.actionCount,4)
for index,action in ipairs(actions) do assigned(card,state.slots[index],action) end
noNativeActions(container)

-- Setup and partial-layout failures must hide all work and disarm all strips.
local undecorated=newCard()
failures.textureParent=undecorated
eq(D:Create(undecorated),false)
eq(undecorated.cleanseDisplay.supported,false)
eq(#undecorated.cleanseDisplay.slots,1,"partial slot is registered before artwork construction")
eq(failures.partialArt,undecorated.cleanseDisplay.slots[1].art)
allDisarmed(undecorated.cleanseDisplay)
eq(undecorated.cleanseDisplay.container.enabled,false)
eq(undecorated.cleanseDisplay.container.shown,false)
failures.textureParent,failures.partialArt=nil,nil
failures.setupKey="cleanse2"
local broken=newCard()
eq(D:Create(broken),false)
eq(broken.cleanseDisplay.supported,false)
eq(broken.cleanseDisplay.container.enabled,false);eq(broken.cleanseDisplay.container.shown,false)
allDisarmed(broken.cleanseDisplay)
failures.setupKey=nil
failures.swallowedCallback="cleanse2"
local swallowed=newCard()
eq(D:Create(swallowed),false,"swallowed native initializer failure cannot mark setup successful")
eq(swallowed.cleanseDisplay.container.shown,false)
allDisarmed(swallowed.cleanseDisplay)
failures.swallowedCallback=nil
local partial=newCard()
eq(D:Create(partial),true)
failures.hitSize=2
eq(D:Configure(partial),false,"failure while constructing secure strips fails closed")
eq(partial.cleanseDisplay.configured,false)
eq(failures.partialHit~=nil,true)
eq(failures.partialHit.shown,false)
eq(failures.partialHit.attrs.spell,nil)
allDisarmed(partial.cleanseDisplay)
eq(partial.cleanseDisplay.container.shown,false)
failures.hitSize,failures.partialHit=nil,nil
local getGeometry=ns.CleanseGeometry.Get
ns.CleanseGeometry.Get=function(self,style,index,count)
    if index==2 then error("second arc layout failed") end
    return getGeometry(self,style,index,count)
end
ns.db.controlStyle="quadrants"
eq(D:Configure(card),false,"failure after first arc layout disarms every partially configured arc")
eq(state.configured,false);eq(container.enabled,false);eq(container.shown,false)
allDisarmed(state)
ns.CleanseGeometry.Get=getGeometry
ns.db.controlStyle="buttons"
actions={{key="Magic",spellID=527,types={Magic=true},record={icon=111}}}
failures.filterKey="cleanse2"
eq(D:Configure(card),false)
eq(state.configured,false);eq(container.enabled,false);eq(container.shown,false)
allDisarmed(state)
eq(D:Update(card,"party1"),false,"partial configuration cannot bind")
failures.filterKey=nil
eq(D:Configure(card),true)
eq(first(state.slots[1]).attrs.spell,527,"recovery preserves deliberate lower rank")
eq(D:Update(card,"party1"),true)
failures.disable=container
D:Clear(card)
eq(state.configured,false,"failed OOC release invalidates signature fast path")
eq(container.shown,false)
allDisarmed(state)
failures.disable=nil
eq(D:Configure(card),true,"unchanged actions recover after transient release failure")
eq(container.shown,true)
eq(D:Update(card,"party1"),true)
actions={}
eq(D:Configure(card),true)
has(D:GetStatus(card),"no learned or assigned")
for index=1,4 do eq(container.slots["cleanse"..index].enabled,false) end
allDisarmed(state)

actions={
    {key="Magic",spellID=527,types={Magic=true},record={icon=111}},
    {key="Disease",spellID=528,types={Disease=true},record={icon=222}},
}
for previewIndex=1,4 do
    local preview=newCard(previewIndex)
    eq(D:Configure(preview),true)
    eq(preview.cleanseDisplay,nil,"preview does not create a native action hierarchy")
    for index,slot in ipairs(preview.cleansePreview.slots) do
        eq(slot.art.shown,index<=2,"assigned preview art is visible in idle and active states")
        for _,button in ipairs(slot.buttons) do
            eq(button.protected,false);eq(button.template,nil)
            eq(button.parent,preview)
            eq(button.attrs.type1,nil);eq(button.attrs["*type1"],nil);eq(button.attrs.spell,nil)
            eq(button.attrs.type2,nil);eq(button.attrs["*type2"],nil)
            eq(button:GetScript("OnClick"),nil,"preview never casts through scripts either")
        end
        if index<=2 then
            local active=previewIndex==4 or previewIndex==index+1
            eq(slot.icon.texture,actions[index].record.icon)
            eq(slot.icon.SetDesaturatedArgs[1],not active)
            eq(slot.icon.SetVertexColorArgs[1],active and 1 or .4)
            eq(slot.glow.alpha,active and 1 or 0)
            eq(slot.timer:GetText(),active and (index==1 and "8s" or "24s") or "")
        end
    end
    local previewFirst=first(preview.cleansePreview.slots[1])
    local countBefore=#preview.cleansePreview.slots[1].buttons
    ns.db.controlStyle="quadrants"
    eq(D:Configure(preview),true)
    eq(first(preview.cleansePreview.slots[1]),previewFirst)
    eq(#preview.cleansePreview.slots[1].buttons,countBefore)
    for _,slot in ipairs(preview.cleansePreview.slots) do
        for index,button in ipairs(slot.buttons) do
            eq(button.shown,index<=#slot.geometry.rects,"preview hides surplus strip pool on style change")
            eq(button.attrs.type1,nil);eq(button.attrs.spell,nil)
        end
    end
    ui.combat=true
    eq(D:Preview(preview),false,"preview layout cannot change during combat")
    ui.combat=false
    ns.db.controlStyle="buttons"
end
local api=C_AuraContainerUtil
C_AuraContainerUtil=nil
local unavailable=newCard()
eq(D:Create(unavailable),false)
eq(#unavailable.cleanseDisplay.slots,0,"unsupported API creates no interactive controls")
has(D:GetStatus(unavailable),"unavailable")
C_AuraContainerUtil=api
eq(nativeReads,0)
eq(#ui.violations,0)
print("cleanse_display_spec: "..checks.." checks passed (structural native-boundary tests, not engine proof)")
