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
print("member_info_spec: "..checks.." checks passed")
