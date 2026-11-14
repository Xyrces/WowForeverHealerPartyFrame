-- Character-owned cleanse choices are independent of recipient presets.
local checks, combat, owner, changes, knownCalls = 0, false, "guid:priest", 0, 0
local secret = setmetatable({}, {__eq=function() error("secret comparison") end})
local ns = {
    IsSecret=function(value) return rawequal(value, secret) end,
    InCombat=function() return combat end,
    Assignments={Identity=function(_,unit) assert(unit=="player"); return owner end},
    OnCleansesChanged=function() changes=changes+1 end,
}
local function equal(actual, expected, message)
    checks=checks+1
    assert(actual==expected, (message or "unexpected value")..": "..tostring(actual).." ~= "..tostring(expected))
end
local learned = {[527]=true,[988]=true,[528]=true,[552]=true}
local info = {}
for _,id in ipairs({527,988,528,552,4987,1152,2782,475,2893,8946,526,2870}) do
    info[id]={id=id,name="Spell "..id,rank=id==988 and "Rank 2" or "Rank 1",icon=id+1000}
end
ns.Spells={Get=function(_,id) return info[id] end}
Enum={SpellBookSpellBank={Player=0,Pet=1}}
C_SpellBook={IsSpellKnown=function(id,bank)
    knownCalls=knownCalls+1;assert(bank==0,"player spells only")
    return learned[id] == true
end}
assert(loadfile("WowfPartyFrames/Cleanses.lua"))("WowfPartyFrames",ns)
local C, db = ns.Cleanses, {presets={default={name="Default"},tank={name="Tank"}}}
equal(C:Init(db),true)
equal(C:GetSpell("Magic"),988,"auto selects highest learned Dispel Magic")
equal(C:GetSpell("Disease"),528,"auto prefers Cure Disease over Abolish")
equal(C:GetSpell("Poison"),nil)
equal(#C:GetActions(),2,"priest has two distinct actions")
equal(C:GetActions()[1].types.Magic,true)
equal(C:GetActions()[2].types.Disease,true)
equal(C:GetSlots()[1].mode,"auto")
equal(C:GetSlots()[3].available,false)
equal(#C:GetChoices("Disease"),2,"both learned disease alternatives available")
equal(C:GetChoices("Magic")[1].spellID,988)
equal(C:GetChoices("Magic")[2].spellID,527)
equal(C:SetSpell("Magic",527),true)
equal(C:GetSpell("Magic"),527,"manual exact lower rank remains assigned")
equal(C:GetSlots()[1].mode,"manual")
equal(C:SetSpell("Disease",552),true)
equal(C:GetSpell("Disease"),552,"manual Abolish preference preserved")
C:Refresh()
equal(C:GetSpell("Magic"),527,"cache refresh does not upgrade manual rank")
equal(C:GetSpell("Disease"),552)
equal(C:Init(db),true)
equal(C:GetSpell("Magic"),527,"manual preference survives reload")
equal(C:GetSpell("Disease"),552)
equal(db.presets.tank.name,"Tank","presets untouched")
equal(C:SetSpell("Disease",nil),true)
equal(C:GetSpell("Disease"),nil,"clearing is explicit disable, not auto refill")
equal(C:GetSlots()[2].mode,"disabled")
equal(#C:GetActions(),1)
C:Init(db)
equal(C:GetSlots()[2].mode,"disabled","disabled survives reload")
equal(C:Reset("Disease"),true)
equal(C:GetSpell("Disease"),528)
equal(C:SetSpell("Magic",552),false,"wrong dispel type rejected")
equal(C:SetSpell("Magic",12345),false,"unknown map ID rejected")
equal(C:SetSpell("Curse",475),false,"metadata alone is not proof learned")
equal(C:SetSpell("Magic",secret),false)
equal(C:SetSpell(secret,527),false)
equal(C:GetSpell(secret),nil)
equal(#C:GetChoices(secret),0)
equal(C:Reset(secret),false)
equal(C:SetSpell("Magic",math.huge),false)
equal(C:SetSpell("Magic",527.5),false)
local before=changes
combat=true
local beforeCalls=knownCalls
equal(C:Refresh(),false)
equal(C:SetSpell("Magic",988),false)
equal(C:SetSpell("Disease",false),false)
equal(C:Reset(),false)
equal(C:Init({}),false)
equal(C:GetSpell("Magic"),527,"combat reads retained public exact choice")
equal(#C:GetActions(),2)
equal(knownCalls,beforeCalls,"no combat spell queries")
equal(changes,before,"combat changes do not fire callback")
combat=false

-- Unlearning a manually chosen spell suppresses it, but does not replace the
-- preference; relearning it restores exactly that spell.
learned[527]=nil
C:Refresh()
equal(C:GetSpell("Magic"),nil)
equal(C:GetSlots()[1].selectedSpellID,527)
equal(C:GetSlots()[1].mode,"manual")
equal(C:GetSlots()[1].available,true,"other learned ranks remain selectable")
learned[527]=true
C:Refresh()
equal(C:GetSpell("Magic"),527)

-- A paladin's one selected Cleanse is one action, not three duplicate buttons.
owner,learned="guid:paladin",{[4987]=true,[1152]=true}
C:Refresh()
equal(C:GetSpell("Magic"),4987)
equal(C:GetSpell("Disease"),4987)
equal(C:GetSpell("Poison"),4987)
local actions=C:GetActions()
equal(#actions,1)
equal(actions[1].spellID,4987)
equal(actions[1].types.Magic,true)
equal(actions[1].types.Poison,true)
equal(actions[1].types.Disease,true)
equal(C:SetSpell("Disease",false),true)
equal(C:GetActions()[1].types.Disease,nil,"disabled type does not light another action")
equal(C:GetActions()[1].types.Poison,true)
equal(C:SetSpell("Poison",1152),true)
equal(#C:GetActions(),2,"different deliberate ability gets separate action")
equal(C:GetActions()[2].spellID,1152)
actions=C:GetActions();actions[1].types.Curse=true;actions[1].record.name="Modified"
equal(C:GetActions()[1].types.Curse,nil,"returned type sets are copies")
equal(C:GetActions()[1].record.name,"Spell 4987","returned records are copies")
local choices=C:GetChoices("Poison");choices[1].types.Curse=true;choices[1].name="Changed"
equal(C:GetChoices("Poison")[1].types.Curse,nil)
equal(C:GetChoices("Poison")[1].name,"Spell 4987")

owner,learned="guid:priest",{[527]=true,[988]=true,[528]=true,[552]=true}
C:Refresh()
equal(C:GetSpell("Magic"),527,"characters keep separate exact choices")
equal(C:GetSpell("Disease"),528)
equal(db.cleanseCharacters["guid:paladin"].overrides.Disease,false)
equal(C:Reset(),true)
equal(C:GetSpell("Magic"),988)
equal(C:GetSlots()[1].mode,"auto")

-- No shared fallback identity, no secret-value indexing, no last-character
-- action leak if identity or public learned-spell information is unavailable.
owner=nil
equal(C:Refresh(),false)
equal(#C:GetActions(),0)
equal(C:SetSpell("Disease",528),false)
equal(C:Reset(),false)
equal(db.cleanseCharacters["guid:paladin"].overrides.Disease,false)
owner=secret
equal(C:Refresh(),false)
equal(#C:GetActions(),0)
owner="guid:priest"
local knownAPI=C_SpellBook.IsSpellKnown
C_SpellBook.IsSpellKnown=function() return secret end
equal(C:Refresh(),false)
equal(#C:GetActions(),0,"unreadable known flags never expose old action")
C_SpellBook.IsSpellKnown=function() error("temporarily unavailable") end
equal(C:Refresh(),false)
equal(#C:GetActions(),0)
C_SpellBook.IsSpellKnown=knownAPI
info[988]=nil
equal(C:Refresh(),true)
equal(C:GetSpell("Magic"),988,"auto selection does not silently downgrade when metadata loads")
equal(#C:GetActions(),1,"missing public metadata does not create a broken action")
equal(C:SetSpell("Magic",988),false)
info[988]={id=988,name="Dispel Magic",rank="Rank 2",icon=1000}
C:Refresh()
equal(#C:GetActions(),2)

-- Malformed saved overrides are sanitized, but a supported unlearned manual
-- choice remains stored so training it again can restore the user's choice.
db.cleanseCharacters[owner].overrides={Magic=552,Disease=552,Poison=secret,Curse=475}
C:Refresh()
equal(C:GetSlots()[1].mode,"auto")
equal(C:GetSlots()[3].mode,"auto")
equal(C:GetSlots()[4].selectedSpellID,475)
equal(C:GetSpell("Curse"),nil)

-- Every mapped caster class is based on learned skills rather than UnitClass.
owner,learned="guid:druid",{[2782]=true,[8946]=true,[2893]=true}
C:Refresh()
equal(C:GetSpell("Poison"),8946)
equal(C:GetSpell("Curse"),2782)
equal(#C:GetActions(),2)
owner,learned="guid:mage",{[475]=true}
C:Refresh()
equal(#C:GetActions(),1)
equal(C:GetActions()[1].types.Curse,true)
owner,learned="guid:shaman",{[526]=true,[2870]=true}
C:Refresh()
equal(C:GetSpell("Disease"),2870)
equal(C:GetSpell("Poison"),526)
equal(#C:GetActions(),2)
C_SpellBook=nil
IsSpellKnown=function(id,pet) equal(pet,false,"global fallback excludes pet bank");return learned[id]==true end
equal(C:Refresh(),true)
equal(#C:GetActions(),2)
print("cleanses_spec: "..checks.." checks passed")
