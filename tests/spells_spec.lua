-- Spell presentation caches and display-only rank-family matching.
local ns,checks,combat={},0,false
local hidden=setmetatable({}, {__eq=function() error("secret comparison") end,__lt=function() error("secret comparison") end})
ns.IsSecret=function(value) return rawequal(value,hidden) end
ns.InCombat=function() return combat end
local function equal(a,b,why)
    checks=checks+1
    assert(a==b,(why or "unexpected value")..": "..tostring(a).." ~= "..tostring(b))
end
local data={
 [1243]={name="Power Word: Fortitude",iconID=100},
 [1244]={name="Power Word: Fortitude",iconID=100},
 [592]={name="Power Word: Shield",iconID=101},
 [6075]={name="Renew",iconID=102},
 [999]={name="Future spell",iconID=134400},
}
local ranks={[1243]="Rank 1",[1244]="Rank 2",[592]="Rank 2",[6075]="Rank 3"}
local calls,bookCalls=0,0
C_Spell={
 GetSpellInfo=function(id) calls=calls+1;return data[id] end,
 GetSpellSubtext=function(id) return ranks[id] end,
}
Enum={SpellBookSpellBank={Player=0,Pet=1}}
local slots={
 [5]={spellID=1243,name="Power Word: Fortitude",subName="Rank 1",iconID=100},
 [6]={spellID=1244,name="Power Word: Fortitude",subName="Rank 2",iconID=100},
 [7]={spellID=592,name="Power Word: Shield",subName="Rank 2",iconID=101},
 [8]={spellID=hidden,name=hidden,iconID=hidden},
 [9]={name="Flyout",actionID=6075,iconID=102},
}
local lineCount=1
C_SpellBook={
 GetNumSpellBookSkillLines=function() bookCalls=bookCalls+1;return lineCount end,
 GetSpellBookSkillLineInfo=function() return {itemIndexOffset=4,numSpellBookItems=5} end,
 GetSpellBookItemInfo=function(slot,bank) equal(bank,0,"only player spellbook scanned");return slots[slot] end,
 GetSpellBookItemName=function(slot) local item=slots[slot];return item and item.name,item and item.subName end,
}
assert(loadfile("WowfPartyFrames/Spells.lua"))("WowfPartyFrames",ns)
local S=ns.Spells
local initial=S:Get(1244)
equal(initial.id,1244)
equal(initial.icon,100)
equal(initial.rank,"Rank 2")
initial.icon=9999
equal(S:Get(1244).icon,100,"callers cannot corrupt cached metadata")
data[1244]=nil
equal(S:Get(1244).icon,100,"temporarily missing spell retains prior icon")
equal(S:Get(1244).name,"Power Word: Fortitude")
data[1244]=hidden
equal(S:Get(1244).rank,"Rank 2","secret metadata retains prior public rank")
data[1244]={name=hidden,originalIconID=hidden,iconID=hidden}
ranks[1244]=hidden
equal(S:Get(1244).icon,100)
equal(S:Get(1244).name,"Power Word: Fortitude")
data[1244]={name="Power Word: Fortitude",originalIconID=0,iconID=134400}
ranks[1244]=""
equal(S:Get(1244).icon,100,"placeholder never replaces known icon")
equal(S:Get(1244).rank,"Rank 2","transient empty rank retains known rank")
data[1244]={name="Power Word: Fortitude",originalIconID=134400,iconID=103}
equal(S:Get(1244).icon,103,"real current icon beats placeholder original icon")
combat=true
local before=calls
data[1244]=nil
equal(S:Get(1244).icon,103)
equal(calls,before,"cached spell presentation performs no combat query")
equal(S:RefreshCache(),false,"spellbook scan never runs in combat")
equal(S:Get(hidden),nil)
equal(S:Get(0),nil)
equal(S:Get(math.huge),nil)
equal(S:Get(1.5),nil)
equal(S:Get(6075).icon,102,"uncached public metadata can still be displayed")
equal(S.cache[6075],nil,"runtime metadata is not promoted into out-of-combat cache")
combat=false
equal(S:RefreshCache(),true)
equal(S:Get(1244).icon,100,"public spellbook metadata supplies stable icon")
equal(S:Get(1244).rank,"Rank 2")
local family=S:GetAuraSpellIDs(1244)
equal(family[1243],true,"lower known rank matches buff family")
equal(family[1244],true,"assigned exact rank always included")
equal(family[592],nil,"other buff family excluded")
equal(family[6075],nil,"flyout actionID is not treated as a spell")
equal(S:Get(1244).id,1244,"display family never upgrades cast rank")
family[592]=true
equal(S:GetAuraSpellIDs(1244)[592],nil,"caller edits do not alter future matching sets")
local unknown=S:GetAuraSpellIDs(123456)
equal(unknown[123456],true,"unknown valid configured ID stays eligible without guessing")
equal(next(S:GetAuraSpellIDs(hidden)),nil)
combat=true
before=bookCalls
data[1243]=hidden
equal(S:GetAuraSpellIDs(1244)[1243],true,"rank family survives restricted metadata")
equal(bookCalls,before,"family lookup in combat never rescans spellbook")
combat=false
lineCount=hidden
equal(S:RefreshCache(),false,"secret spellbook count is never iterated")
equal(S:GetAuraSpellIDs(1244)[1243],true,"failed refresh does not erase known rank family")
-- A later public spellbook refresh picks up newly learned ranks, even when
-- asynchronous global spell metadata has not loaded yet.
lineCount=1
slots[10]={spellID=1245,name="Power Word: Fortitude",subName="Rank 3",iconID=100}
C_SpellBook.GetSpellBookSkillLineInfo=function() return {itemIndexOffset=4,numSpellBookItems=6} end
equal(S:RefreshCache(),true)
equal(S:GetAuraSpellIDs(1244)[1245],true,"new rank joins family after spellbook change")
equal(S:Get(1245).icon,100,"spellbook supplies missing global metadata")
equal(S:Get(1245).rank,"Rank 3")
equal(S:Get(1244).id,1244,"newly learned rank does not replace exact assigned rank")

-- Cursor exact ID and spellbook-only rank fallback still work with caching.
lineCount=1
slots[6].subName="Rank 2"
local cursor={"spell",6,"spell",1244}
GetCursorInfo=function() return unpack(cursor) end
local record=assert(S:FromCursor())
equal(record.id,1244)
equal(record.rank,"Rank 2")
cursor={"spell",5,"spell",1243}
data[1243]={name="Power Word: Fortitude",iconID=100}
equal(S:FromCursor().id,1243,"dragging lower rank remains exact")
cursor={"spell",7,"spell"}
equal(S:FromCursor().id,592,"cursor slot resolved by book only when exact ID absent")
cursor={"spell",7,"pet",592}
equal(S:FromCursor(),nil,"pet assignments still rejected")
print("spells_spec: "..checks.." checks passed")
