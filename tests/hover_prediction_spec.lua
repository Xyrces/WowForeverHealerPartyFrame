-- Offline plumbing checks; native clipping/secret semantics still need client QA.
local state=assert(loadfile("tests/wow_ui_fake.lua"))()()
assert(loadfile("tests/prediction_api_fake.lua"))()(state)
local estimates={[1]={direct=160},[2]={hot=300,duration=15},[3]={absorb=250},[4]={direct=80,hot=200}}
local ns={Layout={barWidth=174},SpellEstimates={Get=function(_,id) return estimates[id] end}}
assert(loadfile("WowfPartyFrames/HoverPrediction.lua"))("WowfPartyFrames",ns)
local H=ns.HoverPrediction
local checks=0
local function eq(a,b,message)
    checks=checks+1
    assert(rawequal(a,b),message or "unexpected value")
end
local function card()
    local c=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
    c.health=CreateFrame("StatusBar",nil,c)
    c.health:SetSize(174,12)
    c.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    H:Create(c)
    return c
end
local c=card()
local p=c.hoverPrediction
local button={card=c,spellID=1}
eq(p.supported,true)
eq(p.holder.height,2,"thin strip")
eq(p.holder.point[2],c.health)
eq(p.holder.point[3],"TOPLEFT")
eq(p.holder.point[5],5,"touches existing upper trim")
eq(p.direct.point[2],c.health:GetStatusBarTexture(),"heal anchored to native health fill")
eq(p.hot.point[2],p.direct:GetStatusBarTexture(),"HoT follows direct component")
eq(p.absorb.point[2],p.holder,"shield starts at left even at full health")
eq(p.hotClip.allPoints[1],p.hot:GetStatusBarTexture(),"segment gaps clipped to native HoT fill")
state.units.party1={health=400,maxHealth=1000}
eq(H:Show(button,"party1"),true)
eq(p.direct.value,160); eq(p.hot.value,0); eq(p.absorb.value,0)
eq(p.direct.maximum,1000); eq(p.holder.alpha,1)
button.spellID=2
eq(H:Update(button,"party1"),true)
eq(p.direct.value,0); eq(p.hot.value,300)
button.spellID=3
state.units.party1.health=1000
eq(H:Show(button,"party1"),true)
eq(p.absorb.value,250,"shield preview retained at full HP")
eq(p.hot.value,0)
button.spellID=4
eq(H:Show(button,nil,4500),true)
eq(p.direct.maximum,4500); eq(p.direct.value,80); eq(p.hot.value,200)
local opaque=setmetatable({}, {__add=function() error("secret arithmetic") end,
    __sub=function() error("secret arithmetic") end,__div=function() error("secret arithmetic") end,
    __lt=function() error("secret comparison") end,__le=function() error("secret comparison") end})
state.units.party1.maxHealth=opaque
issecretvalue=function(v) return rawequal(v,opaque) end
local originalCreate=CreateFrame
CreateFrame=function() error("hover must not create frames") end
local originalPoint=state.methods.SetPoint
state.methods.SetPoint=function() error("hover must not reanchor") end
state.methods.GetWidth=function() error("hover must not inspect geometry") end
state.combat=true
eq(H:Show(button,"party1"),true)
eq(p.direct.maximum,opaque,"protected maximum reaches native setter untouched")
eq(p.hot.maximum,opaque)
eq(#state.violations,0)
button.spellID=999
eq(H:Show(button,"party1"),false)
eq(p.holder.alpha,0,"unknown spell clears prior hover")
eq(p.direct.value,0)
button.spellID=1
eq(H:Show(button,"party5"),false)
eq(H:Show(button,"party2"),false,"departed member clears")
eq(H:Show(button,nil,0),false,"invalid preview maximum")
eq(H:Show(button,"party1"),true)
local originalMax=UnitHealthMax
UnitHealthMax=function() error("unavailable") end
eq(H:Show(button,"party1"),false)
eq(p.holder.alpha,0); eq(p.button,nil)
UnitHealthMax=originalMax
eq(H:Show(button,"party1"),true,"transient failure recovers")
H:Clear(c)
eq(p.holder.alpha,0); eq(p.direct.value,0); eq(p.hot.value,0); eq(p.absorb.value,0)
eq(p.button,nil)
CreateFrame=originalCreate
state.methods.SetPoint=originalPoint
local uninitialized={}
eq(H:Create(uninitialized),false,"combat setup forbidden")
eq(uninitialized.hoverPrediction,nil,"combat setup can retry later")
state.combat=false
estimates[5]={direct=-10,hot=math.huge,absorb=0/0}
button.spellID=5
eq(H:Show(button,"party1"),false,"invalid public estimates rejected")
issecretvalue=function(v) return rawequal(v,opaque) end
button.spellID=opaque
eq(H:Show(button,"party1"),false,"secret spell ID not inspected")
button.spellID=1
eq(H:Show(button,opaque),false,"secret unit rejected")
local connected, dead = true, false
UnitIsConnected=function() return connected end
UnitIsDeadOrGhost=function() return dead end
dead=true
eq(H:Show(button,"party1"),false,"known dead members do not receive a heal preview")
dead=false; connected=false
eq(H:Show(button,"party1"),false,"known offline members do not receive a heal preview")
connected=opaque; dead=opaque
eq(H:Show(button,"party1"),true,"unknown protected status is not compared or used to suppress combat preview")
connected=true; dead=false
state.units.party1.maxHealth=0
eq(H:Show(button,"party1"),false,"public zero maximum does not make an invalid native range")
state.units.party1.maxHealth=1000
eq(H:Show(button,"party1"),true,"recover after valid health maximum returns")
print("hover_prediction_spec: "..checks.." checks passed")
