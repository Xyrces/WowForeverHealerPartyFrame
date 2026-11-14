local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
local ns, checks = {}, 0
local function equal(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function load(name) assert(loadfile("WowfPartyFrames/"..name..".lua"))("WowfPartyFrames",ns) end
state.units.player={guid="healer",name="Healer",class="PRIEST"}
state.units.party1={guid="tank",name="Tank",class="DRUID"}
state.units.party2={guid="caster",name="Caster",class="DRUID"}
GetRealmName=function() return "Test Realm" end
load("Bootstrap")
load("Profiles")
load("Assignments")
local P,A=ns.Profiles,ns.Assignments
local db=P:Init({})
local tank=assert(P:Create("Tank"))
local caster=assert(P:Create("Caster"))
local roster={{key="guid:tank",name="Tank"},{key="guid:caster",name="Caster"}}
local function restart(reload)
    A:Init(db)
    A:BeginSession(reload)
    assert(A:Sync(roster,true))
end
restart(false)
equal(A:Identity("party1"),"guid:tank")
equal(A:GetPreset("guid:tank"),"default","join starts Default")
equal(A.members["guid:tank"].pending,nil)
equal(A:Assign("guid:tank",tank),true)
equal(A:GetPreset("guid:tank"),tank)
equal(db.remembered["guid:healer"]["guid:tank"],tank)
equal(A:Assign("guid:caster",caster),true)
equal(A:GetPreset("guid:caster"),caster,"same class need not imply same preset")
state.units.party1,state.units.party2=state.units.party2,state.units.party1
A:Sync({roster[2],roster[1]},true)
equal(A:GetPreset("guid:tank"),tank,"reorder preserves identity assignment")
equal(A:FindUnit("guid:tank"),"party2")
A:Sync({},false)
equal(A:GetPreset("guid:tank"),tank,"unresolved roster preserves assignments")
restart(true)
equal(A:GetPreset("guid:tank"),tank,"reload restores current party choice")
equal(A.members["guid:tank"].pending,nil,"reload never prompts assigned member")
restart(false)
equal(A:GetPreset("guid:tank"),"default","fresh login requires confirmation")
equal(A.members["guid:tank"].pending.presetID,tank)
equal(A.members["guid:tank"].pending.remaining,10)
A:Advance("guid:tank",4)
equal(A.members["guid:tank"].pending.remaining,6)
equal(A.members["guid:caster"].pending.remaining,10,"other unseen prompt is not timed")
state.combat=true
A:Advance("guid:tank",100)
equal(A.members["guid:tank"].pending.remaining,6,"combat pauses countdown")
equal(A:Confirm("guid:tank",tank),false)
equal(A:Assign("guid:caster",tank),false)
equal(A:KeepDefault("guid:tank"),false)
state.combat=false
restart(true)
equal(A.members["guid:tank"].pending.remaining,6,"reload retains remaining prompt time")
A:Advance("guid:tank",6)
equal(A.members["guid:tank"].pending,nil)
equal(A:GetPreset("guid:tank"),"default")
equal(A:Confirm("guid:tank",tank),false,"expired confirmation cannot assign")
equal(A.memory["guid:tank"],tank,"timeout preserves last explicit choice")
restart(true)
equal(A:GetPreset("guid:tank"),"default")
equal(A.members["guid:tank"].pending,nil,"reload after timeout does not re-prompt")
A:Sync({roster[2]},true)
equal(A.members["guid:tank"],nil)
A:Sync(roster,true)
equal(A.members["guid:tank"].pending.presetID,tank,"actual rejoin offers remembered choice")
equal(A:Confirm("guid:tank",caster),false,"stale/different choice refused")
equal(A:Confirm("guid:tank",tank),true)
equal(A:GetPreset("guid:tank"),tank)
equal(A.members["guid:tank"].pending,nil)
equal(P:Rename(tank,"Main tank"),true)
A:PrunePresets()
equal(A:GetPreset("guid:tank"),tank,"rename preserves stable ID")
equal(P:GetPreset(A:GetPreset("guid:tank")).name,"Main tank")
-- A click from a frame whose member departed cannot affect the replacement.
state.units.party2={guid="new",name="Replacement",class="WARRIOR"}
equal(A:Assign("guid:tank",caster),false)
equal(A:GetPreset("guid:tank"),tank)
state.units.party2={guid="tank",name="Tank",class="DRUID"}
equal(P:Delete(tank),true)
A:PrunePresets()
equal(A:GetPreset("guid:tank"),"default","deleted current preset falls back")
equal(A.memory["guid:tank"],nil,"deleted remembered preset pruned")
equal(P:Delete(caster),true)
A:PrunePresets()
equal(A.members["guid:caster"].pending,nil,"deleted suggestion removed")
equal(A:Confirm("guid:caster",caster),false)
local healer=assert(P:Create("Healer"))
equal(A:Assign("guid:caster",healer),true)
restart(false)
equal(A:KeepDefault("guid:caster"),true)
equal(A:GetPreset("guid:caster"),"default")
equal(A.memory["guid:caster"],healer,"declining preserves memory")
equal(A:Assign("guid:caster","default"),true)
equal(A.memory["guid:caster"],"default","explicit Default is remembered")
restart(false)
equal(A.members["guid:caster"].pending,nil,"remembered Default needs no prompt")
state.units.player={guid="other-healer",name="Other",class="PRIEST"}
restart(true)
equal(A:GetPreset("guid:caster"),"default","different owner cannot inherit session")
equal(A.memory["guid:caster"],nil,"memory is scoped by local player")
state.units.party3={name="Crossrealm",realm="Other Realm"}
equal(A:Identity("party3"),"name:Crossrealm-OtherRealm")
state.units.party3={name="Local"}
equal(A:Identity("party3"),"name:Local-TestRealm")
UNKNOWNOBJECT="Unknown"
state.units.party3={name=UNKNOWNOBJECT}
equal(A:Identity("party3"),nil)
state.raid=true
equal(A:Assign("guid:caster","default"),false,"raid units are not party targets")
print("assignments_spec: " .. checks .. " checks passed")
