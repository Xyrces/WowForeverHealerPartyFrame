-- Real menu extension, assignments, live cards, and confirmation controls.
local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
local ns, checks = {}, 0
local function equal(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected value")..": "..tostring(a).." ~= "..tostring(b))
end
local function load(name) assert(loadfile("WowfPartyFrames/"..name..".lua"))("WowfPartyFrames",ns) end
state.units.player={guid="healer",name="Healer",class="PRIEST"}
state.units.party1={guid="tank",name="Tank",class="WARRIOR",health=50,maxHealth=100,power=0,maxPower=100}
state.units.party2={guid="caster",name="Caster",class="DRUID",health=50,maxHealth=100,power=50,maxPower=100}
GetRealmName=function() return "Test Realm" end
local registrations={}
Menu={ModifyMenu=function(tag,callback) registrations[#registrations+1]={tag=tag,callback=callback} end}
load("Bootstrap")
load("Profiles")
load("Assignments")
ns.db=ns.Profiles:Init({})
local tankID=assert(ns.Profiles:Create("Tank"))
local casterID=assert(ns.Profiles:Create("Caster"))
ns.Assignments:Init(ns.db)
ns.Assignments:BeginSession(false)
ns.Spells={Get=function(_,id) return {id=id,icon=id,rank="Rank 1"} end}
ns.Rates={SetUnits=function() end,Get=function() return 0,0,0 end}
ns.Auras={GetDebuffs=function() return {},true end,GetAssignedBuff=function() return {state="missing"} end,Paint=function() end}
load("FrameVisuals")
load("Frames")
assert(ns.Frames:Create())
load("PresetMenus")
local M,A,F=ns.PresetMenus,ns.Assignments,ns.Frames
ns.OnProfileChanged=function() A:PrunePresets();F:ApplyProfiles();F:RefreshAll(true);M:RefreshPrompts() end
M:Initialize()
M:Initialize()
equal(#registrations,1,"native extension registers once")
equal(registrations[1].tag,"MENU_UNIT_PARTY")
equal(next(M.prompts),nil,"no prompt controls until a remembered suggestion exists")
local function description(label,kind)
    local node={label=label,kind=kind,children={},enabled=true}
    function node:SetEnabled(value) self.enabled=value end
    function node:SetScrollMode(height) self.scrollHeight=height end
    function node:CreateDivider() local item=description(nil,"divider");self.children[#self.children+1]=item;return item end
    function node:CreateButton(title) local item=description(title,"button");self.children[#self.children+1]=item;return item end
    function node:CreateRadio(title,selected,callback)
        local item=description(title,"radio");item.selected=selected;item.callback=callback
        self.children[#self.children+1]=item;return item
    end
    return node
end
local function menu(owner,unit)
    local root=description("native","root")
    local native=root:CreateButton("Whisper")
    registrations[1].callback(nil,root,{ownerFrame=owner,unit=unit})
    equal(root.children[1],native,"preexisting native actions preserved")
    return root,root.children[3]
end
local first=F.cards[1]
local root,submenu=menu(first,"party1")
equal(#root.children,3)
equal(root.children[2].kind,"divider")
equal(submenu.label,"Assign preset")
equal(submenu.scrollHeight,240,"long preset lists use a bounded native scroll menu")
equal(#submenu.children,3)
equal(submenu.children[1].selected(),true)
equal(submenu.children[2].selected(),false)
submenu.children[2].callback()
equal(A:GetPreset("guid:tank"),tankID)
equal(submenu.children[2].selected(),true,"checkmark follows chosen preset")
equal(submenu.children[1].selected(),false)
local unrelated=CreateFrame("Frame",nil,UIParent)
local ignored=menu(unrelated,"party1")
equal(#ignored.children,1,"native/default frames do not acquire addon entries")
ignored=menu(first,"target")
equal(#ignored.children,1,"nonparty context rejected")
ignored=menu(first,"party2")
equal(#ignored.children,1,"owner and current identity must agree")
for _,control in ipairs({first.heals[1],first.buffs[1]}) do
    local _,childMenu=menu(control,"party1")
    equal(childMenu.label,"Assign preset","secure spell controls share member menu")
end
state.combat=true
local _,locked=menu(first,"party1")
equal(locked.enabled,false)
for _,entry in ipairs(locked.children) do equal(entry.enabled,false) end
submenu.children[3].callback()
equal(A:GetPreset("guid:tank"),tankID,"combat beginning after menu open blocks click")
state.combat=false
state.units.party1,state.units.party2=state.units.party2,state.units.party1
for _,header in ipairs(F.headers) do state.reconcileHeader(header) end
submenu.children[3].callback()
equal(A:GetPreset("guid:tank"),casterID,"stale party slot still assigns captured player after reorder")
equal(A:GetPreset("guid:caster"),"default")
state.units.party2=nil
submenu.children[2].callback()
equal(A:GetPreset("guid:tank"),casterID,"departed player's old menu cannot reassign")
state.units.party2={guid="tank",name="Tank",class="WARRIOR",health=50,maxHealth=100,power=0,maxPower=100}
F:RefreshRoster()
-- Rejoin offers remembered choice, while Default is immediately active.
A:Sync({{key="guid:caster",name="Caster"}},true)
F:RefreshRoster()
local card=F.cards[2]
local prompt=M.prompts[2]
equal(A:GetPreset("guid:tank"),"default")
equal(prompt:IsShown(),true)
equal(prompt:GetParent(),UIParent,"prompt is not a protected card child")
equal(prompt.memberKey,"guid:tank")
equal(prompt.presetID,casterID)
equal(prompt.confirm:GetText(),"Confirm (10s)")
M:Update(4)
equal(A.members["guid:tank"].pending.remaining,6)
equal(prompt.confirm:GetText(),"Confirm (6s)")
ns.worldActive=false
M:Update(30)
equal(prompt:IsShown(),false,"loading screen hides prompt")
equal(A.members["guid:tank"].pending.remaining,6,"loading screen pauses visible countdown")
M:RefreshPrompts()
equal(prompt:IsShown(),false,"refresh cannot reveal prompt during loading")
ns.worldActive=true
M:RefreshPrompts()
equal(prompt:IsShown(),true,"prompt returns once the world is active")
equal(prompt.confirm:GetText(),"Confirm (6s)","loading time did not consume confirmation window")
state.combat=true
M:Update(50)
equal(prompt:IsShown(),false)
equal(A.members["guid:tank"].pending.remaining,6,"combat hides prompt and pauses countdown")
state.combat=false
M:RefreshPrompts()
equal(prompt:IsShown(),true)
M:Update(6)
equal(prompt:IsShown(),false)
equal(A:GetPreset("guid:tank"),"default")
equal(A.memory["guid:tank"],casterID,"timeout preserves memory")
local function rejoin()
    A:Sync({{key="guid:caster",name="Caster"}},true)
    F:RefreshRoster()
    return M.prompts[2]
end
prompt=rejoin()
prompt.confirm:GetScript("OnClick")(prompt.confirm)
equal(A:GetPreset("guid:tank"),casterID)
equal(prompt:IsShown(),false)
prompt=rejoin()
prompt.keep:GetScript("OnClick")(prompt.keep)
equal(A:GetPreset("guid:tank"),"default")
equal(A.memory["guid:tank"],casterID)
equal(prompt:IsShown(),false)
prompt=rejoin()
card:Hide()
M:RefreshPrompts()
equal(prompt:IsShown(),false,"hidden card cannot show floating confirmation")
M:Update(20)
equal(A.members["guid:tank"].pending.remaining,10,"hidden suggestion spends no time")
card:Show()
card:SetAttribute("unit","party1")
M:RefreshPrompts()
equal(prompt:IsShown(),false,"identity mismatch cannot show stale confirmation")
card:SetAttribute("unit","party2")
M:RefreshPrompts()
equal(prompt:IsShown(),true)
-- A disappearing member cannot be assigned by an already-visible Confirm.
state.units.party2=nil
prompt.confirm:GetScript("OnClick")(prompt.confirm)
equal(A:GetPreset("guid:tank"),"default")
equal(prompt:IsShown(),false)
equal(#state.violations,0,"no protected mutations in combat")
print("preset_menus_spec: "..checks.." checks passed")
