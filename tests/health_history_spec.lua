local state=assert(loadfile("tests/wow_ui_fake.lua"))()()
assert(loadfile("tests/history_api_fake.lua"))()(state)
local ns={Layout={barWidth=174}}
assert(loadfile("WowfPartyFrames/HealthHistory.lua"))("WowfPartyFrames",ns)
local H=ns.HealthHistory
local checks=0
local function eq(a,b,message) checks=checks+1; assert(rawequal(a,b),message or "unexpected value") end
local card=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
card.health=CreateFrame("StatusBar",nil,card)
eq(H:Create(card),true)
local p=card.healthHistory
eq(#p.rows,12); eq(p.holder.height,12); eq(p.holder.point[5],5)
eq(p.holder.level,card.health.level+2)
eq(p.rows[12].point[5],-11)
eq(#state.historyCurve.points,6)
eq(state.historyCurve.points[4][1],.70)
local r,g,b=state.historyCurve.points[4][2]:GetRGBA()
eq(r,222/255); eq(g,203/255); eq(b,68/255)
local originalHealth=UnitHealth
UnitHealth=function(unit,predicted) eq(predicted,false,"history excludes predicted HP"); return originalHealth(unit) end
state.units.party1={guid="A",health=500,maxHealth=1000}
eq(H:Update(card,"party1",10),true)
eq(#p.samples,1); eq(p.rows[12].value,500); eq(p.rows[1].alpha,0)
eq(H:Update(card,"party1",10.24),false)
eq(#p.samples,1)
state.units.party1.health=600; state.units.party1.maxHealth=1200
state.historyColor=CreateColor(.8,.7,.2,1)
eq(H:Update(card,"party1",10.25),true)
eq(p.rows[11].value,500); eq(p.rows[11].maximum,1000,"old maximum preserved")
eq(p.rows[12].maximum,1200)
eq(p.rows[11].SetStatusBarColorArgs[1],.25,"old color preserved")
eq(p.rows[12].SetStatusBarColorArgs[1],.8)
eq(math.abs(p.rows[12].alpha-.65)<.000001,true)
for index=2,13 do state.units.party1.health=index; H:Update(card,"party1",10+index*.25) end
eq(#p.samples,12); eq(p.rows[1].value,2); eq(p.rows[12].value,13)
state.units.party2=state.units.party1
eq(H:Update(card,"party2",13.5),true)
eq(#p.samples,12,"same player across unit-token reorder preserved")
state.units.party2={guid="B",health=200,maxHealth=400}
eq(H:Update(card,"party2",13.51),true)
eq(#p.samples,1,"new identity clears immediately even before sample deadline")
eq(p.rows[12].value,200)
eq(H:Update(card,"party2",14.02),true)
eq(#p.samples,3,"modest stall keeps prior sample plus explicit missed slot")
eq(p.samples[2],false,"missed sample remains blank")
eq(p.rows[11].alpha,0,"missed slot renders blank")
eq(p.rows[10].value,200,"prior real sample survives stall")
eq(H:Update(card,"party2",17.02),true)
eq(#p.samples,1,"whole history window gap resets")
eq(H:Update(card,"party2",1),true)
eq(#p.samples,1,"backward public clock resets")
local opaque=setmetatable({}, {__add=function() error("secret arithmetic") end,
    __sub=function() error("secret arithmetic") end,__div=function() error("secret arithmetic") end,
    __lt=function() error("secret comparison") end,__le=function() error("secret comparison") end,
    __tostring=function() error("secret formatting") end})
issecretvalue=function(v) return rawequal(v,opaque) end
state.units.party2.health=opaque; state.units.party2.maxHealth=opaque
state.historyColor=CreateColor(opaque,opaque,opaque,opaque)
local create,point,size=CreateFrame,state.methods.SetPoint,state.methods.SetSize
CreateFrame=function() error("no combat frame creation") end
state.methods.SetPoint=function() error("no runtime reanchor") end
state.methods.SetSize=function() error("no runtime resize") end
state.methods.GetWidth=function() error("no native geometry readback") end
state.combat=true
eq(H:Update(card,"party2",1.25),true)
eq(p.rows[12].value,opaque); eq(p.rows[12].maximum,opaque)
eq(p.rows[12].SetStatusBarColorArgs[1],opaque)
eq(p.rows[12].SetStatusBarColorArgs[4],1,"native color alpha stays public")
eq(#state.violations,0)
eq(H:Create({}),false)
state.units.party2.guid=opaque
eq(H:Update(card,"party2",1.3),false); eq(p.holder.alpha,0); eq(#p.samples,0)
state.units.party2.guid="B"
eq(H:Update(card,"party2",1.5),true)
local connected=UnitIsConnected
UnitIsConnected=function() return false end
eq(H:Update(card,"party2",1.6),false); eq(#p.samples,0)
UnitIsConnected=connected
eq(H:Update(card,"party3",1.7),false)
eq(H:Update(card,opaque,1.7),false)
eq(H:Update(card,"party2",1.75),true)
local health=UnitHealth
local failedReads=0
UnitHealth=function() failedReads=failedReads+1; error("native read failure") end
eq(H:Update(card,"party2",2),false); eq(p.holder.alpha,0)
eq(H:GetStatus(),"unavailable: native update failed")
eq(H:Update(card,"party2",2.01),false)
eq(H:Update(card,"party2",2.24),false)
eq(failedReads,1,"failed health reads retry only at sampling cadence")
UnitHealth=health
state.units.party2.guid="C"
eq(H:Update(card,"party2",2.24),true,"new identity bypasses old member retry delay")
state.units.party2.guid="B"
local percent=UnitHealthPercent
UnitHealthPercent=function() error("color unavailable") end
eq(H:Update(card,"party2",2.25),true)
eq(p.rows[12].SetStatusBarColorArgs[1],64/255)
eq(H:GetStatus():find("uniform green",1,true)~=nil,true)
UnitHealthPercent=percent
eq(H:Update(card,"party2",2.5),true)
eq(H:GetStatus():find("native health colors",1,true)~=nil,true)
H:Clear(card)
eq(p.identity,nil); eq(p.last,nil); eq(p.holder.alpha,0)
local alphaSetter,valueSetter=state.methods.SetAlpha,state.methods.SetValue
local clearWrites=0
state.methods.SetAlpha=function(self,value) clearWrites=clearWrites+1; return alphaSetter(self,value) end
state.methods.SetValue=function(self,value) clearWrites=clearWrites+1; return valueSetter(self,value) end
local emptySamples=p.samples
H:Clear(card); H:Clear(card)
eq(clearWrites,0,"already empty cards perform no repeated native writes")
eq(p.samples,emptySamples,"already empty cards reuse the empty sample table")
eq(H:Update(card,"party2",2.75),true,"cleared card starts sampling again")
clearWrites=0
H:Clear(card)
eq(clearWrites>0,true,"new paint dirties the card and requires cleanup")
clearWrites=0
H:Clear(card)
eq(clearWrites,0)
-- Invalid sampling may set public identity before any paint. Clear still
-- resets metadata even when the native display was already empty.
state.units.party2.health=nil
eq(H:Update(card,"party2",2.8),false)
eq(p.identity,nil); eq(p.last,nil); eq(clearWrites,0)
state.units.party2.health=opaque
state.methods.SetAlpha=alphaSetter; state.methods.SetValue=valueSetter
CreateFrame=create; state.methods.SetPoint=point; state.methods.SetSize=size; state.combat=false
eq(H:Preview(card,700,1000),true)
eq(#p.samples,12); eq(p.rows[12].value,700)
eq(p.rows[12].SetStatusBarColorArgs[1],222/255)
eq(H:Update(card,"party2",3),true); eq(#p.samples,1,"live never reuses fabricated preview data")
eq(H:Preview(card,opaque,1000),false); eq(#p.samples,0)
local setter=state.methods.SetValue
state.methods.SetValue=function() error("native paint failure") end
eq(H:Update(card,"party2",4),false,"native painting failure cannot escape into frame loop")
eq(p.holder.alpha,0)
eq(p.cleared,true,"partial paint failure is cleaned despite starting from empty")
eq(#p.samples,0)
state.methods.SetValue=setter
eq(H:Update(card,"party2",4.01),false,"paint failure also observes retry cadence")
eq(H:Update(card,"party2",4.25),true,"native painting may recover")
local api=C_CurveUtil
C_CurveUtil=nil
local fallbackNS={Layout={barWidth=174}}
assert(loadfile("WowfPartyFrames/HealthHistory.lua"))("WowfPartyFrames",fallbackNS)
local fallbackCard=CreateFrame("Button",nil,UIParent)
fallbackCard.health=CreateFrame("StatusBar",nil,fallbackCard)
eq(fallbackNS.HealthHistory:Create(fallbackCard),true,"missing curve API does not disable history")
eq(fallbackNS.HealthHistory:Update(fallbackCard,"party2",5),true)
eq(fallbackCard.healthHistory.rows[12].SetStatusBarColorArgs[2],191/255)
C_CurveUtil=api
-- Live cards already have a public member identity and secure name-list
-- binding. A protected GUID must not erase their combat history.
H:Clear(card)
card.header=CreateFrame("Frame",nil,UIParent)
card.memberKey,card.memberName="guid:B","Member"
card.header:SetAttribute("nameList","Member")
card:SetAttribute("unit","party2")
state.units.party2.guid="B"
eq(H:Update(card,"party2",6),true)
state.units.party2.guid=opaque
eq(H:Update(card,"party2",6.25),true,"secure named binding survives a secret GUID")
eq(#p.samples,2)
eq(p.identity,"guid:B")
state.units.party1,state.units.party2=state.units.party2,nil
card:SetAttribute("unit","party1")
eq(H:Update(card,"party1",6.5),true,"secret GUID can follow secure token reorder")
eq(#p.samples,3)
card.header:SetAttribute("nameList","Other")
eq(H:Update(card,"party1",6.6),false,"stale name binding cannot reuse remembered identity")
eq(#p.samples,0)
card.header:SetAttribute("nameList","Member")
state.units.party1.guid="Different"
eq(H:Update(card,"party1",6.75),false,"readable GUID mismatch refuses old roster identity")
card.memberKey="guid:Different"
eq(H:Update(card,"party1",7),true)
eq(#p.samples,1,"new roster identity starts empty")
state.units.party1.guid=opaque
card.memberKey=opaque
eq(H:Update(card,"party1",7.25),false,"secret cached identity is never compared or reused")
card.memberKey="guid:Different"
local guidAPI,failedIdentityReads=UnitGUID,0
UnitGUID=function() failedIdentityReads=failedIdentityReads+1; error("identity read failed") end
eq(H:Update(card,"party1",8),false)
eq(H:Update(card,"party1",8.01),false)
eq(H:Update(card,"party1",8.24),false)
eq(failedIdentityReads,1,"failures before identity resolution also back off")
UnitGUID=guidAPI
state.units.party1.guid="Different"
eq(H:Update(card,"party1",8.25),true,"identity reads resume at the next retry interval")

-- Sampling cadence is a saved display preference, independent of row count
-- and secret health values. Unsupported saved values retain the old default.
eq(H:GetSampleInterval(),.25)
eq(H:GetWindowSeconds(),3)
eq(#H.SAMPLE_INTERVALS,5)
for _,bad in ipairs({0,-1,.1,.24,"0.5",false,{},0/0,math.huge,-math.huge,1e308,opaque}) do
    ns.db={historySampleInterval=bad}
    eq(H:GetSampleInterval(),.25,"invalid saved interval uses the default")
    eq(H:SetSampleInterval(bad),false,"invalid interval cannot be assigned")
end
ns.db={}
eq(H:SetSampleInterval(nil),false)
local second=CreateFrame("Button",nil,UIParent)
second.health=CreateFrame("StatusBar",nil,second)
eq(H:Create(second),true)
eq(H:Preview(second,700,1000),true)
eq(H:SetSampleInterval(.5),true)
eq(ns.db.historySampleInterval,.5,"step is persisted")
eq(H:GetSampleInterval(),.5); eq(H:GetWindowSeconds(),6)
eq(#p.samples,0,"changing step clears existing live samples")
eq(#second.healthHistory.samples,0,"changing step also clears preview samples")
eq(p.holder.height,12); eq(#p.rows,12,"step never changes geometry")
state.units.party1.health=600; state.units.party1.maxHealth=1000
eq(H:Update(card,"party1",100),true)
eq(H:Update(card,"party1",100.49),false)
eq(H:Update(card,"party1",100.5),true)
eq(H:Update(card,"party1",101.5),true)
eq(#p.samples,4); eq(p.samples[3],false,"missed slots use configured cadence")
eq(H:Update(card,"party1",105.5),true)
eq(#p.samples,12,"four seconds is a partial stall in a six-second window")
eq(p.rows[1].value,600,"retained sample survives a gap larger than old three-second default")
eq(H:Update(card,"party1",111.5),true)
eq(#p.samples,1,"full configured window clears the old history")
eq(H:GetStatus():find("0.5s samples / 6s history",1,true)~=nil,true)

state.combat=true
eq(H:SetSampleInterval(1),false,"editing cadence in combat is rejected")
eq(H:SetWindowSeconds(12),false,"editing total duration in combat is rejected")
eq(ns.db.historySampleInterval,.5); eq(#p.samples,1)
state.combat=false
for _,bad in ipairs({0,-1,2.99,"6",false,{},0/0,math.huge,-math.huge,opaque}) do
    eq(H:SetWindowSeconds(bad),false,"invalid total duration cannot be assigned")
    eq(ns.db.historySampleInterval,.5,"invalid total duration does not alter interval")
end
eq(H:SetWindowSeconds(nil),false)
eq(H:SetWindowSeconds(3),true)
eq(ns.db.historySampleInterval,.25,"minimum total gives minimum step")
eq(H:GetWindowSeconds(),3)
eq(H:SetSampleInterval(.24),false,"step cannot be below quarter second")
eq(ns.db.historySampleInterval,.25)
eq(H:SetWindowSeconds(6),true)
eq(ns.db.historySampleInterval,.5)
eq(H:GetWindowSeconds(),6)
eq(H:SetWindowSeconds(10),true)
eq(ns.db.historySampleInterval,10/12,"arbitrary total stores its exact divided interval")
eq(H:GetSampleInterval(),10/12)
eq(H:GetWindowSeconds(),10)
eq(H:SetSampleInterval(1.75),true)
eq(H:GetWindowSeconds(),21,"editing step updates total duration")
eq(H:SetSampleInterval(10000),true,"no arbitrary upper limit on finite history")
eq(H:GetWindowSeconds(),120000)
eq(H:SetSampleInterval(.25),true)
eq(H:Update(card,"party1",200),true)
for index=1,12 do
    eq(H:Update(card,"party1",200+index*.25),true,"quarter-second sampling deadlines are preserved")
end
eq(#p.samples,12)
eq(H:GetStatus():find("0.25s samples / 3s history",1,true)~=nil,true)
eq(H:Update(card,"party1",206),true)
eq(#p.samples,1,"full-window gap resets at minimum step")
local reads=0
UnitHealth=function() reads=reads+1; error("configured retry") end
eq(H:Update(card,"party1",206.25),false)
eq(H:Update(card,"party1",206.49),false); eq(reads,1)
eq(H:Update(card,"party1",206.5),false); eq(reads,2,"retry cadence follows the setting")
UnitHealth=health
eq(H:SetSampleInterval(1),true)
eq(p.retryAt,nil,"changing interval clears the old retry deadline")
eq(H:GetWindowSeconds(),12)
eq(H:Update(card,"party1",207),true)
eq(H:Update(card,"party1",207.99),false)
eq(H:Update(card,"party1",208),true)
eq(#p.samples,2)
eq(H:SetSampleInterval(1),true)
eq(#p.samples,2,"reselecting current step keeps its valid history")
ns.db.historySampleInterval=.25
eq(H:Update(card,"party1",208.01),true,"externally restored interval restarts sampling")
eq(#p.samples,1,"restored settings do not mix cadences")
eq(H:GetStatus():find("0.25s samples / 3s history",1,true)~=nil,true)

local savedNS={Layout={barWidth=174},db={historySampleInterval=10/12}}
assert(loadfile("WowfPartyFrames/HealthHistory.lua"))("WowfPartyFrames",savedNS)
eq(savedNS.HealthHistory:GetSampleInterval(),10/12,"fresh module honors arbitrary persisted preference")
eq(savedNS.HealthHistory:GetWindowSeconds(),10)
print("health_history_spec: "..checks.." checks passed")
