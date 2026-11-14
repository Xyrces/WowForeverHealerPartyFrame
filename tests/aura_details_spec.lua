local ui = assert(loadfile("tests/wow_ui_fake.lua"))()()
local secret = {}
local ns = {Layout={portrait=82},InCombat=function() return ui.combat end,
    IsSecret=function(value) return value==secret end}
local checks,containers = 0,{}
local function eq(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected")..": "..tostring(a).." ~= "..tostring(b))
end
local originalCreate = CreateFrame
local failBind,failEnable,failInitialize
CreateFrame=function(kind,name,parent,template)
    local frame=originalCreate(kind,name,parent,template)
    if kind=="AuraContainer" then
        containers[#containers+1]=frame
        function frame:SetEnabled(value)
            if value and self==failEnable then error("enable failed") end
            self.enabled=value
        end
        function frame:SetUnit(value)
            if self==failBind then error("bind failed") end
            self.unit=value
        end
        function frame:SetFlowLayoutMaximumLineSize(value) self.lineWidth=value end
        function frame:SetAuraProcessingPolicy(policy,options) self.policy=policy;self.policyOptions=options end
        local function icon(options)
            local button=originalCreate("AuraButton",nil,frame)
            for _,key in ipairs({"Icon","DurationCooldown","DurationText","ApplicationCount","HideTooltipInCombat","TooltipAnchorPoint"}) do
                button["Set"..key]=function(self,value) self[key]=value end
            end
            function button:AddDispelTypeTexture(texture,options) self.dispelTexture=texture;self.dispelOptions=options end
            if not failInitialize then options.initializeFrame(button) end
            return button
        end
        function frame:AddAuraGroup(key,filter,options)
            self.group={filter=filter,options=options,icon=icon(options)}
        end
        function frame:AddAuraSlot(key,filter,options)
            self.slot={filter=filter,options=options,icon=icon(options)}
        end
    end
    return frame
end
Enum={CustomAuraButtonDispelTypeTextureStyle={Border=0,PreserveAsset=3}}
CustomAuraContainerAuraProcessingPolicy={ProcessAura=1}
AuraContainerSortMethod={Default=0,UnitFrameDebuff=2}
C_AuraContainerUtil={}
local dispellable=false
local assistable=true
GetCVarBool=function() return dispellable end
UnitCanAssist=function() return assistable end
function ui.methods:GetBottom() return self:GetTop()-self:GetHeight() end
UIParent:SetSize(1920,1080)
ui.units.party1={};ui.units.party2={}
local function card()
    local result=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
    result.portraitArea=CreateFrame("Frame",nil,result)
    return result
end
assert(loadfile("WowfPartyFrames/AuraDetails.lua"))("WowfPartyFrames",ns)
local D=ns.AuraDetails
local first=card()
eq(D:Create(first),true)
eq(#containers,4)
eq(D:Create(first),true)
eq(#containers,4,"idempotent preparation")
local panel=D.panelState.frame
eq(panel.protected,false,"no secure children can protect hover panel")
eq(panel:IsShown(),false)
eq(containers[1].group.filter,"HELPFUL")
eq(containers[1].group.options.maxFrameCount,16)
eq(containers[2].group.options.maxFrameCount,8)
for i=1,2 do
    local button=containers[i].group.icon
    eq(button.HideTooltipInCombat,false)
    eq(button.SetMouseClickEnabledArgs[1],false)
    eq(button.SetMouseMotionEnabledArgs[1],true)
    eq(button:GetScript("OnEnter"),nil,"native tooltip handlers untouched")
    eq(button.DurationCooldown~=nil,true)
    eq(button.DurationText~=nil,true)
    eq(button.ApplicationCount~=nil,true)
    eq(button.dispelOptions.style,Enum.CustomAuraButtonDispelTypeTextureStyle.Border,"native colored border atlas")
    eq(button.dispelOptions.showWithoutDispelType,true,"physical debuff icons keep native None border")
    eq(button.dispelOptions.showWhenHarmful,true)
    eq(button.dispelOptions.showWhenHelpful,false,"helpful icons have no debuff border")
    eq(button.dispelTexture.parent.mouseEnabled,false,"border overlay does not steal tooltip input")
    eq(button.dispelTexture.parent:GetFrameLevel()>button.DurationCooldown:GetFrameLevel(),true,"border remains above cooldown sweep")
end
eq(containers[3].slot.filter,"HARMFUL")
eq(containers[4].slot.filter,"HARMFUL","native processing retains boss and priority effects when dispel-only is set")
eq(containers[3].slot.options.candidateFilters,nil,"physical and untyped debuffs are not excluded")
eq(containers[3].slot.icon.dispelOptions.showWithoutDispelType,true,"native None color covers untyped harmful effects")
eq(containers[3].slot.icon.dispelOptions.showWhenHelpful,false)
eq(containers[1].group.options.sortMethod,AuraContainerSortMethod.Default)
eq(containers[2].group.options.sortMethod,AuraContainerSortMethod.UnitFrameDebuff)
for i=2,4 do
    eq(containers[i].policy,CustomAuraContainerAuraProcessingPolicy.ProcessAura,"native metadata precedes native comparator")
    eq(containers[i].policyOptions.ignoreDebuffs,false,"physical debuffs remain classified")
    eq(containers[i].policyOptions.ignoreDispelDebuffs,false)
    eq(containers[i].policyOptions.displayOnlyDispellableDebuffs,i==4)
end
eq(containers[3].slot.options.sortMethod,AuraContainerSortMethod.UnitFrameDebuff)
eq(containers[4].slot.options.sortMethod,AuraContainerSortMethod.UnitFrameDebuff)
eq(containers[3].slot.icon.dispelOptions.style,3)
eq(containers[3].slot.icon.mouseEnabled,false)
eq(containers[3].slot.icon.dispelTexture.AddMaskTextureArgs~=nil,true)
D:Update(first,"party1")
eq(containers[3].enabled,true)
eq(containers[4].enabled,false)
ui.combat=true
eq(D:Show(first,"party1"),true,"prepared native displays work in combat")
eq(panel:IsShown(),true)
eq(containers[1].unit,"party1")
eq(containers[2].unit,"party1")
eq(panel.point[2],UIParent,"panel does not track moving GameTooltip")
local update=panel:GetScript("OnUpdate")
ui.hover=first;update(panel,1)
eq(panel:IsShown(),true)
ui.hover=nil;update(panel,0.1)
eq(panel:IsShown(),true,"leave grace permits crossing to aura panel")
ui.hover=panel;update(panel,1)
eq(panel:IsShown(),true,"panel stays open for native aura tooltips")
ui.hover=nil;update(panel,0.26)
eq(panel:IsShown(),false)
eq(containers[3].enabled,true,"closing hover panel preserves harmful border")
dispellable=true;D:Update(first,"party1")
eq(containers[3].enabled,false)
eq(containers[4].enabled,true,"native dispellable-only preference honored")
assistable=false;D:Update(first,"party1")
eq(containers[3].enabled,true,"hostile units retain normal debuff policy")
eq(containers[4].enabled,false)
assistable=secret;D:Update(first,"party1")
eq(containers[3].enabled,true,"opaque assist state cannot select dispel-only policy")
assistable=true;D:Update(first,"party1")
eq(containers[4].enabled,true)
eq(D:Show(first,"party1"),true)
D:Update(first,"party2")
eq(D.unit,"party2")
eq(containers[1].unit,"party2")
eq(containers[4].unit,"party2")
ui.units.party2=nil;D:Update(first,"party2")
eq(panel:IsShown(),false,"departed roster member clears open panel")
eq(containers[4].enabled,false)
eq(#ui.violations,0,"no protected mutation in combat")
eq(D:Create(card()),false,"never create in combat")
ui.combat=false
local second=card()
eq(D:Create(second),true)
eq(#containers,6,"second member reuses shared overflow panel")
failBind=containers[2]
eq(D:Show(second,"party1"),false)
eq(containers[1].enabled,false,"partial bind failure clears all stale views")
eq(panel:IsShown(),false)
failBind=nil;failEnable=containers[2]
eq(D:Show(second,"party1"),false)
eq(containers[1].enabled,false,"partial enable failure clears first view")
failEnable=nil
eq(D:Show(second,"party1"),true)
ns.worldActive=false;update(panel,0.01)
eq(panel:IsShown(),false,"world transition closes native tooltips")
ns.worldActive=true
local preview=card();preview.previewIndex=1
eq(D:Create(preview),false)
eq(D:Show(preview,"party1"),false)
eq(D:Show(first,secret),false,"opaque unit cannot enter native binding")
failInitialize=true
local broken=card();D:Create(broken)
eq(broken.auraDetailsBorder.supported,false,"swallowed native initialization failure is detected")
failInitialize=false
D:Update(first,"party1");D:Show(first,"party1");D:Clear(first)
eq(panel:IsShown(),false)
eq(containers[4].enabled,false)
print("aura_details_spec: "..checks.." assertions passed")
