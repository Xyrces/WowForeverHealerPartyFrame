local secret = setmetatable({}, {__concat=function() error("secret concat") end,
    __lt=function() error("secret compare") end, __le=function() error("secret compare") end})
local checks=0
local function eq(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected")..": "..tostring(a).." ~= "..tostring(b))
end
local level, class, role, exists = 24, "Paladin", "TANK", true
local marker
GetRaidTargetIndex=function() return marker end
UnitLevel=function() return level end
UnitClass=function() return class,"PALADIN" end
UnitGroupRolesAssigned=function() return role end
UnitExists=function() return exists end
TANK, HEALER, DAMAGER = "Tank", "Healer", "Damage"
Enum={UIMapType={Zone=3,Dungeon=4}}
local maps={
    [1]={name="Eastern Kingdoms",mapType=2,parentMapID=0},
    [10]={name="Elwynn Forest",mapType=3,parentMapID=1},
    [11]={name="Goldshire Inn",mapType=5,parentMapID=10},
    [12]={name="Mine",mapType=5,parentMapID=10},
    [13]={name="Nested area",mapType=3,parentMapID=10},
    [20]={name="Westfall",mapType=3,parentMapID=1},
    [21]={name="Westfall cave",mapType=5,parentMapID=20},
    [40]={name="The Deadmines",mapType=4,parentMapID=0},
    [41]={name="Deadmines floor one",mapType=4,parentMapID=40},
    [42]={name="Deadmines floor two",mapType=5,parentMapID=40},
    [50]={name="The Stockade",mapType=4,parentMapID=10},
}
local unitMaps={player=10,party1=20}
C_Map={GetBestMapForUnit=function(unit) return unitMaps[unit] end,
    GetMapInfo=function(id) return maps[id] end}
local forbidden={}
canaccesstable=function(value) return value~=forbidden end
local ns={IsSecret=function(value) return rawequal(value,secret) end,
    Profiles={GetPreset=function(_,id) return {name=id=="tank" and "Tank" or "Default"} end}}
assert(loadfile("WowfPartyFrames/MemberInfo.lua"))("WowfPartyFrames",ns)
local M=ns.MemberInfo
local value=M:Get("party1","tank")
eq(value.summary,"24 Paladin · Tank"); eq(value.preset,"Tank")
eq(value.level,24); eq(value.class,"Paladin"); eq(value.roleToken,"TANK"); eq(value.location,"Westfall")
eq(value.role,"Tank","written role accompanies the icon")
role="NONE"
eq(M:Get("party1").summary,"24 Paladin","no guessed role")
eq(M:Get("party1").roleToken,nil)
role="HEALER"; eq(M:Get("party1").roleToken,"HEALER")
role="DAMAGER"; eq(M:Get("party1").roleToken,"DAMAGER")
role="UNKNOWN"; eq(M:Get("party1").roleToken,nil)
marker=8; eq(M:Get("party1").markerIndex,8)
marker=1; eq(M:Get("party1").markerIndex,1)
for _,bad in ipairs({0,9,-1,1.5,"8",secret}) do
    marker=bad; eq(M:Get("party1").markerIndex,nil)
end
marker=nil; eq(M:Get("party1").markerIndex,nil,"cleared marker is not cached")
-- Simulate a secret numeric value (Lua cannot manufacture native secrets).
local oldSecret=ns.IsSecret
ns.IsSecret=function(value) return value==77 or oldSecret(value) end
marker=77; eq(M:Get("party1").markerIndex,77,"secret number forwarded without range inspection")
ns.IsSecret=oldSecret; marker=nil
class="Paladin localisé"; eq(M:Get("party1").class,class)
unitMaps.party1=11; eq(M:Get("party1").location,nil,"same zone micro map")
unitMaps.player=12; eq(M:Get("party1").location,nil,"different submaps same zone")
unitMaps.party1=13; eq(M:Get("party1").location,nil,"nested zone shares enclosing zone")
unitMaps.party1=21; eq(M:Get("party1").location,"Westfall","different zone resolves parent label")
unitMaps.party1=40; eq(M:Get("party1").location,"The Deadmines","independent dungeon root")
unitMaps.party1=50; eq(M:Get("party1").location,"The Stockade","dungeon distinct from same outdoor zone")
unitMaps.player=50; unitMaps.party1=10
eq(M:Get("party1").location,"Elwynn Forest","outdoor member distinct from player's dungeon")
unitMaps.player=41; unitMaps.party1=42
eq(M:Get("party1").location,nil,"floors of same dungeon share identity")
unitMaps.party1=50; eq(M:Get("party1").location,"The Stockade","different dungeons")
maps[51]={name="Unknown dungeon",mapType=4,parentMapID=999}
unitMaps.party1=51; eq(M:Get("party1").location,nil,"incomplete dungeon ancestry omitted")
maps[51].parentMapID=51; eq(M:Get("party1").location,nil,"cyclic dungeon ancestry omitted")
maps[51].parentMapID=secret; eq(M:Get("party1").location,nil,"secret dungeon ancestry omitted")
unitMaps.player=12
unitMaps.party1=nil; eq(M:Get("party1").location,nil,"no stale prior location")
unitMaps.party1=secret; eq(M:Get("party1").location,nil)
unitMaps.party1=1; eq(M:Get("party1").location,nil,"continent alone proves no zone")
unitMaps.party1=30; maps[30]={mapType=5,parentMapID=30}
eq(M:Get("party1").location,nil,"cyclic ancestry terminates")
maps[30]={mapType=5,parentMapID=999}; eq(M:Get("party1").location,nil)
maps[30]={mapType=3,parentMapID=secret,name="Hidden"}; eq(M:Get("party1").location,nil)
maps[30]=forbidden; eq(M:Get("party1").location,nil)
maps[30]={mapType=3,parentMapID=1,name=secret}; eq(M:Get("party1").location,nil)
level,class,role=secret,secret,secret
eq(M:Get("party1").summary,"")
eq(M:Get("party1").roleToken,nil,"secret assigned role is not guessed")
level,class,role=-1,"Paladin","NONE"
eq(M:Get("party1").summary,"Paladin","unknown level omitted")
exists=false; eq(M:Get("party1").summary,"")
exists=true
UnitLevel=function() error("unsupported") end
UnitClass=nil; UnitGroupRolesAssigned=nil
C_Map.GetBestMapForUnit=function() error("unsupported") end
value=M:Get("party1",secret)
eq(value.summary,""); eq(value.location,nil); eq(value.preset,"Default")
eq(M:Get(secret).summary,"")
C_Map=nil; eq(M:Get("party1").location,nil)
-- Surnames are display text, never secure-header identity keys.
local first,surname="Aeldris","Oakheart"
UnitName=function() return first,surname end
Constants={CharacterNameSeparatorConsts={CHARACTERNAME_SURNAME_SEPARATOR=" "}}
GetUnitName=nil; NameUtil=nil
eq(M:GetDisplayName("party1"),"Aeldris Oakheart","Forever surname fallback uses the display separator")
surname="Moonfall"
eq(M:GetDisplayName("party1"),"Aeldris Moonfall","same first name does not reuse another surname")
first="Aeldris Moonfall"
eq(M:GetDisplayName("party1"),first,"already formatted fallback name is not doubled")
first="Élodie"; surname="Lumière"
eq(M:GetDisplayName("party1"),"Élodie Lumière","UTF-8 names are preserved")
surname=""; eq(M:GetDisplayName("party1"),"Élodie","empty surname adds no space")
surname=nil; eq(M:GetDisplayName("party1"),"Élodie")
surname=secret; eq(M:GetDisplayName("party1"),"Élodie","secret surname is not concatenated")
first=secret
eq(M:GetDisplayName("party1"),nil,"public tooltip name never returns a secret")
local font={SetText=function(self,value) self.value=value end}
M:PaintName(font,"party1")
eq(rawequal(font.value,secret),true,"opaque name forwarded directly to FontString")
first,surname="Aeldris","Oakheart"
local formatterCalls=0
GetUnitName=function(unit,showSurname)
    formatterCalls=formatterCalls+1
    eq(unit,"party1");eq(showSurname,true)
    return "Native Full Name"
end
eq(M:GetDisplayName("party1"),"Native Full Name","native display format wins")
M:PaintName(font,"party1");eq(font.value,"Native Full Name")
eq(formatterCalls,2)
GetUnitName=function() return secret end
M:PaintName(font,"party1");eq(rawequal(font.value,secret),true)
eq(M:GetDisplayName("party1"),nil)
GetUnitName=function() error("name unavailable") end
eq(M:GetDisplayName("party1"),"Aeldris Oakheart","formatter failure has public fallback")
GetUnitName=nil
NameUtil={FormatUnitNameForDisplay=function(unit) return "NameUtil Full Name" end}
eq(M:GetDisplayName("party1"),"NameUtil Full Name","helper works when global wrapper is absent")
NameUtil=nil; UnitName=function() error("unavailable") end
M:PaintName(font,"party1");eq(font.value,nil,"missing member clears prior name")
eq(M:GetDisplayName(secret),nil,"secret unit not passed into formatter")
UnitName=function() return first,surname end
eq(M:Get("party1").displayName,"Aeldris Oakheart")

-- Match native presence priority: another group, summon, then phase reason.
Enum.PhaseReason={Phasing=0,Sharding=1,WarMode=2,ChromieTime=3,TimerunningHwt=4,RuleSet=5}
Enum.SummonStatus={Pending=1,Accepted=2,Declined=3}
local otherParty, incoming, summonStatus, connected, reason=false,false,nil,true,nil
UnitInOtherParty=function() return otherParty end
UnitIsConnected=function() return connected end
UnitPhaseReason=function() return reason end
C_IncomingSummon={HasIncomingSummon=function() return incoming end,
    IncomingSummonStatus=function() return summonStatus end}
local phaseCalls=0
PartyUtil={GetPhasedReasonString=function(phase,unit)
    phaseCalls=phaseCalls+1;eq(phase,reason);eq(unit,"party1")
    return "Native phase explanation"
end}
UnitInPartyShard=function() return false end
eq(M:Get("party1").presenceKind,nil,"not-in-party-shard alone proves no mismatch")
reason=Enum.PhaseReason.Sharding
value=M:Get("party1")
eq(value.presenceKind,"shard");eq(value.presenceText,"Different shard")
eq(value.differentShard,true);eq(value.phaseReason,1)
eq(value.presenceTooltip,"Native phase explanation")
eq(value.presenceTexture,"Interface\\TargetingFrame\\UI-PhasingIcon")
eq(value.presenceTexCoord[1],.15625);eq(value.presenceDim,true)
reason=Enum.PhaseReason.Phasing
value=M:Get("party1")
eq(value.presenceKind,"phase","zero-valued phase reason is not absent")
eq(value.differentShard,false,"quest phase is not mislabeled a different shard")
reason=Enum.PhaseReason.RuleSet
eq(M:Get("party1").presenceText,"Different ruleset")
for key,kind in pairs({WarMode="warMode",ChromieTime="chromieTime",TimerunningHwt="worldTier"}) do
    reason=Enum.PhaseReason[key];eq(M:Get("party1").presenceKind,kind)
end
reason=1;connected=false
eq(M:Get("party1").presenceKind,nil,"offline unit clears prior phase")
connected=secret;eq(M:Get("party1").presenceKind,nil,"secret connection not inspected")
connected=true;reason=secret
local callsBefore=phaseCalls
eq(M:Get("party1").presenceKind,nil,"secret reason not compared to enum values")
eq(phaseCalls,callsBefore,"secret reason not passed to Lua explanation formatter")
reason=1;PartyUtil.GetPhasedReasonString=function() return secret end
eq(M:Get("party1").presenceTooltip,"Different shard","secret tooltip gets public fallback")
PartyUtil.GetPhasedReasonString=function() error("unsupported") end
eq(M:Get("party1").presenceTooltip,"Different shard")
incoming=true;summonStatus=1
value=M:Get("party1")
eq(value.presenceKind,"summonPending");eq(value.presenceAtlas,"Raid-Icon-SummonPending")
eq(value.phaseReason,nil,"native summon takes priority over phase")
summonStatus=2;eq(M:Get("party1").presenceKind,"summonAccepted")
summonStatus=3;eq(M:Get("party1").presenceKind,"summonDeclined")
summonStatus=secret;eq(M:Get("party1").presenceKind,nil,"secret summon state not compared")
summonStatus=1;otherParty=true
value=M:Get("party1")
eq(value.presenceKind,"otherParty","other group precedes summon")
eq(value.presenceAtlas,"groupfinder-eye-single");eq(value.presenceDim,true)
otherParty=secret;incoming=secret;reason=nil
eq(M:Get("party1").presenceKind,nil,"opaque group/summon states never become flags")
otherParty=false;incoming=false;reason=1;exists=false
eq(M:Get("party1").presenceKind,nil,"missing member cannot retain a phase indicator")
exists=true;reason=nil
eq(M:Get("party1").presenceKind,nil,"phase clearing removes prior indicator")
print("member_info_spec: "..checks.." checks passed")
