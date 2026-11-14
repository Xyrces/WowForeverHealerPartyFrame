-- Persistent preset migration, exact spell IDs, CRUD, and reload stability.
local ns, combat, changes = { MAX_BUFFS = 8, CLASSES = {
    { token = "WARRIOR", name = "Warrior" }, { token = "DRUID", name = "Druid" },
    { token = "MAGE", name = "Mage" },
} }, false, 0
local secret = {}
ns.IsSecret = function(value) return value == secret end
ns.InCombat = function() return combat end
ns.Spells = { Get = function(_, id) if id == 2050 or id == 2052 or id == 1243 then return { id = id } end end }
ns.OnProfileChanged = function() changes = changes + 1 end
assert(loadfile("WowfPartyFrames/Profiles.lua"))("WowfPartyFrames", ns)
local P, checks = ns.Profiles, 0
local function eq(a, b, why)
    checks = checks + 1
    assert(a == b, (why or "unexpected value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local remembered, session = { character = "class-WARRIOR" }, { value = true }
local db = P:Init({ version = 1, classes = {
    WARRIOR = { heals = {2050,2052, "2052", [5]=2050}, buffs = {1243} },
    DRUID = { heals = {}, buffs = {} }, MAGE = { heals = {0,math.huge,-1} },
}, position = {point="CENTER", relativePoint="TOP", x=33, y=-42}, scale=0.8,
showBlizzard=true, remembered=remembered, session=session })
eq(db.version, 3)
eq(db.classes, nil)
eq(db.remembered, remembered)
eq(db.session, session)
eq(db.showBlizzard, true)
eq(db.position.x, 33)
eq(db.position.point, "CENTER")
eq(db.scale, 0.8)
eq(#P:List(), 2, "only nonempty classes migrated")
eq(P:List()[1].id, "default")
eq(P:GetPreset("default").name, "Default")
eq(P:GetSpell("default", "heals", 1), nil, "default never inherits a class")
eq(P:GetSpell("class-WARRIOR", "heals", 1), 2050)
eq(P:GetSpell("class-WARRIOR", "heals", 2), 2052)
eq(P:GetSpell("class-WARRIOR", "heals", 3), nil)
eq(P:GetSpell("class-WARRIOR", "heals", 5), nil)
eq(P:GetSpell("class-WARRIOR", "buffs", 1), 1243)
eq(P:GetPreset("class-DRUID"), nil)
eq(changes, 0, "initialization emits no mutations")
local tank = assert(P:Create("  Tank  ", "class-WARRIOR"))
eq(P:GetPreset(tank).name, "Tank")
eq(P:GetSpell(tank, "heals", 2), 2052, "copy preserves exact lower rank")
eq(P:SetSpell(tank,"heals",2,2050), true)
eq(P:GetSpell("class-WARRIOR","heals",2),2052, "copy does not alias source")
eq(P:GetSpell(tank,"heals",2),2050)
eq(P:Create("tank"),nil, "case-insensitive duplicate")
eq(P:Create(""),nil)
eq(P:Create("  "),nil)
eq(P:Create("Bad\nName"),nil)
eq(P:Create("|cffff0000Tank"),nil)
eq(P:Create(string.rep("x",33)),nil)
eq(P:Create(secret),nil)
eq(P:Create("Missing copy","missing"),nil)
eq(P:Rename(tank,"  Main tank "),true)
eq(P:GetPreset(tank).name,"Main tank")
eq(P:Rename(tank,"Default"),false)
eq(P:Rename("default","Baseline"),false)
eq(P:Delete("default"),false)
eq(P:SetSpell("default","heals",1,2052),true)
eq(P:GetSpell("default","heals",1),2052)
eq(P:SetSpell(tank,"buffs",0,1243),false)
eq(P:SetSpell(tank,"heals",5,2050),false)
eq(P:SetSpell(tank,"heals",1,secret),false)
eq(P:SetSpell(tank,"heals",1,99999),false)
eq(P:SetSpell(tank,"heals",1,nil),true)
eq(P:GetSpell(tank,"heals",1),nil)
local before = changes
combat = true
eq(P:Create("Combat"),nil)
eq(P:Rename(tank,"Combat"),false)
eq(P:Delete(tank),false)
eq(P:SetSpell(tank,"heals",1,2050),false)
eq(changes,before)
combat = false
P:Init(db)
eq(P:GetSpell("default","heals",1),2052)
eq(P:GetPreset(tank).name,"Main tank")
eq(#P:List(),3)
eq(P:Delete(tank),true)
eq(P:GetPreset(tank),nil)
eq(#P:List(),2)
eq(db.remembered,remembered,"assignment module owns memory")
eq(db.session,session,"assignment module owns session")
local newTank = assert(P:Create("Tank"))
eq(newTank == tank,false,"deleted IDs must not be reused for remembered assignments")
local list = P:List()
list[1].name = "changed"
eq(P:GetPreset("default").name,"Default","list is detached")
for i = #P:List()+1,40 do assert(P:Create("Extra " .. i)) end
eq(#P:List(),40)
eq(P:Create("Too many"),nil)
P:Init({version=2,presets={default={name="Wrong",heals={2050}},z={name=" Zed ",buffs={1243}},a={name="Alpha"}},presetOrder={"z","z","missing"},position={x=0/0},scale=-1})
eq(P:List()[1].id,"default")
eq(P:List()[2].id,"z")
eq(P:List()[3].id,"a")
eq(#P:List(),3)
eq(P:GetPreset("z").name,"Zed")
eq(P.db.position.x,16)
eq(P.db.scale,1)
-- v2 presets retain Base without inventing modifier assignments.
P:Init({version=2, controlStyle="unknown", presets={default={name="Default",heals={2052},buffs={1243}}},
    classes={WARRIOR={heals={2050}}}})
eq(P.db.version,3)
eq(P.db.controlStyle,"buttons","standalone buttons are the default")
eq(P:GetSpell("default","heals",1),2052)
eq(P:GetSpell("default","heals",1,"base"),2052)
eq(P:GetPreset("class-WARRIOR"),nil,"v2 never repeats obsolete class migration")
for _,layer in ipairs({"shift","ctrl","ctrlshift"}) do
    eq(P:GetSpell("default","heals",1,layer),nil,"migration leaves modifier layers empty")
    eq(P:SetSpell("default","heals",1,2050,layer),true)
    eq(P:GetSpell("default","heals",1,layer),2050,"exact lower rank retained per layer")
end
eq(P:GetSpell("default","heals",1),2052,"modifier edits do not alter Base")
eq(P:SetSpell("default","heals",1,2052,"ctrl"),true)
eq(P:GetSpell("default","heals",1,"shift"),2050,"layers are independent")
eq(P:GetSpell("default","heals",1,"ctrl"),2052)
local layered=assert(P:Create("Layered copy","default"))
for _,layer in ipairs({"base","shift","ctrl","ctrlshift"}) do
    eq(P:GetSpell(layered,"heals",1,layer),P:GetSpell("default","heals",1,layer))
    eq(P:SetSpell(layered,"heals",1,nil,layer),true)
    eq(P:GetSpell(layered,"heals",1,layer),nil,"clearing affects exactly one layer")
    eq(P:GetSpell("default","heals",1,layer)~=nil,true,"copied layers do not alias source")
end
eq(P:SetSpell("default","heals",1,2050,"alt"),false)
eq(P:GetSpell("default","heals",1,"alt"),nil)
eq(P:SetSpell("default","heals",1,2050,secret),false)
eq(P:GetSpell("default","heals",1,secret),nil)
eq(P:SetSpell("default","heals",1,2050,{}),false)
eq(P:GetSpell("default","heals",1,{}),nil)
eq(P:SetSpell("default","buffs",1,1243,"alt"),true,"buffs ignore modifier layers")
eq(P:GetSpell("default","buffs",1,secret),1243)
combat=true
eq(P:SetSpell("default","heals",1,nil,"shift"),false)
eq(P:GetSpell("default","heals",1,"shift"),2050)
combat=false
local saved=P.db
saved.controlStyle="quadrants"
saved.presets.default.healLayers.shift[2]="2052"
saved.presets.default.healLayers.shift[3]=math.huge
saved.presets.default.healLayers.shift[5]=2050
saved.presets.default.healLayers.alt={2050}
saved.presets.default.healLayers.ctrlshift=false
P:Init(saved)
eq(P.db.controlStyle,"quadrants")
eq(P:GetSpell("default","heals",1,"shift"),2050)
eq(P:GetSpell("default","heals",2,"shift"),nil,"string layer IDs rejected")
eq(P:GetSpell("default","heals",3,"shift"),nil,"nonfinite layer IDs rejected")
eq(P:GetPreset("default").healLayers.shift[5],nil,"extra layer slots removed")
eq(P:GetPreset("default").healLayers.alt,nil,"unsupported layer removed")
eq(type(P:GetPreset("default").healLayers.ctrlshift),"table","malformed layer rebuilt empty")
eq(P:GetSpell("default","heals",1,"ctrlshift"),nil)
print("profiles_spec: " .. checks .. " checks passed")
