local ui = assert(loadfile("tests/wow_ui_fake.lua"))()()
local checks, cleared, changed = 0, 0, 0
local cursor = {}
local secret = {}
local function equal(actual, expected, message)
    checks=checks+1
    assert(actual==expected,(message or "unexpected value")..": "..tostring(actual).." ~= "..tostring(expected))
end
local ns = {
    IsSecret=function(value) return rawequal(value,secret) end,
    InCombat=function() return ui.combat end,
    SetBackdrop=function() end,
    Assignments={Identity=function() return "guid:priest" end},
}
local known = {[527]=true,[988]=true,[528]=true,[552]=true}
local data = {
    [527]={name="Dispel Magic",iconID=100},
    [988]={name="Dispel Magic",iconID=100},
    [528]={name="Cure Disease",iconID=200},
    [552]={name="Abolish Disease",iconID=300},
    [475]={name="Remove Lesser Curse",iconID=400},
    [2050]={name="Lesser Heal",iconID=500},
}
local ranks = {[527]="Rank 1",[988]="Rank 2"}
Enum={SpellBookSpellBank={Player=0,Pet=1}}
C_Spell={GetSpellInfo=function(id) return data[id] end,GetSpellSubtext=function(id) return ranks[id] or "" end}
C_SpellBook={IsSpellKnown=function(id,bank) equal(bank,0,"known checks use player bank");return known[id]==true end,
    GetSpellBookItemInfo=function(slot,bank) if slot==7 and bank==0 then return {spellID=527} end end,
}
GetCursorInfo=function() return unpack(cursor) end
ClearCursor=function() cleared=cleared+1;cursor={} end
UISpecialFrames={}
assert(loadfile("WowfPartyFrames/Spells.lua"))("WowfPartyFrames",ns)
assert(loadfile("WowfPartyFrames/Cleanses.lua"))("WowfPartyFrames",ns)
assert(loadfile("WowfPartyFrames/CleanseSettings.lua"))("WowfPartyFrames",ns)
local C,S = ns.Cleanses,ns.CleanseSettings
local db={}
C:Init(db)
ns.OnCleansesChanged=function() changed=changed+1;S:Refresh() end
local frame=S:Create()
equal(frame.width,340)
equal(frame.height,292)
equal(frame:IsShown(),false)
equal(UISpecialFrames[1],"WowfPartyFramesCleanseSettings")
equal(S:Create(),frame,"one dialog reused")
equal(#UISpecialFrames,1,"ESC registration is not duplicated")
equal(S.slots.Magic.title:GetText(),"Dispel Magic")
equal(S.slots.Magic.rank:GetText(),"Rank 2")
equal(S.slots.Magic.status:GetText(),"Auto")
equal(S.slots.Poison.title:GetText(),"No learned ability")
equal(S.slots.Poison.status:GetText(),"Auto")
equal(S.slots.Disease.icon.width,32)
equal(S.slots.Disease.icon.height,32)
S:Toggle()
equal(frame:IsShown(),true)
S:Toggle()
equal(frame:IsShown(),false)

-- Real cursor parser + actual config API, including the cursor-ID and
-- spellbook-slot paths that previously failed to assign dragged spells.
cursor={"spell",7,"spell",527}
S.slots.Magic:GetScript("OnReceiveDrag")(S.slots.Magic)
equal(C:GetSpell("Magic"),527)
equal(S.slots.Magic.rank:GetText(),"Rank 1")
equal(S.slots.Magic.status:GetText(),"Manual")
equal(cleared,1,"successful drop consumes cursor exactly once")
cursor={"spell",8,"spell",552}
S.slots.Disease:GetScript("OnClick")(S.slots.Disease,"LeftButton")
equal(C:GetSpell("Disease"),552)
equal(S.slots.Disease.title:GetText(),"Abolish Disease")
equal(cleared,2,"click-with-cursor also assigns")
equal(changed,2)
cursor={"spell",7,"spell"}
equal(S:Assign(S.slots.Magic,false),true)
equal(C:GetSpell("Magic"),527,"slot-only cursor resolves exact rank")
equal(cleared,3)

-- Wrong school, non-removal, unlearned and non-spell drops preserve cursor
-- and leave the useful error message intact across UI refreshes.
cursor={"spell",7,"spell",552}
equal(S:Assign(S.slots.Magic,false),false)
equal(cleared,3)
equal(C:GetSpell("Magic"),527)
local errorNote=frame.note:GetText()
equal(errorNote:find("Magic",1,true)~=nil,true)
S:Refresh()
equal(frame.note:GetText(),errorNote,"refresh retains failed-drop explanation")
cursor={"spell",7,"spell",2050}
equal(S:Assign(S.slots.Disease,false),false)
equal(cleared,3)
cursor={"spell",7,"spell",475}
equal(S:Assign(S.slots.Curse,false),false)
equal(frame.note:GetText():find("learned",1,true)~=nil,true)
cursor={"item",7}
equal(S:Assign(S.slots.Magic,false),false)
equal(cleared,3)
cursor={"spell",7,"pet",527}
equal(S:Assign(S.slots.Magic,false),false)
equal(cleared,3)

-- Right-click disabling never consumes a held spell/item; Auto restores only
-- that type and remains separate from the manual exact-rank choice elsewhere.
cursor={"spell",7,"spell",988}
S.slots.Disease:GetScript("OnClick")(S.slots.Disease,"RightButton")
equal(C:GetSpell("Disease"),nil)
equal(S.slots.Disease.status:GetText(),"Off")
equal(S.slots.Disease.title:GetText(),"Disabled")
equal(cleared,3)
equal(cursor[4],988)
C:Init(db);S:Refresh()
equal(S.slots.Disease.status:GetText(),"Off","disabled choice survives reload")
S.slots.Disease.auto:GetScript("OnClick")()
equal(C:GetSpell("Disease"),528)
equal(S.slots.Disease.status:GetText(),"Auto")
equal(C:GetSpell("Magic"),527,"one Auto button does not reset another slot")
equal(cleared,3,"Auto does not consume held cursor")

-- Combat leaves all configuration untouched; both edit routes show the lock.
ui.combat=true
local beforeChanges=changed
equal(S:Assign(S.slots.Magic,false),false)
equal(S:Assign(S.slots.Disease,true),false)
equal(S:Reset("Magic"),false)
equal(cleared,3)
equal(changed,beforeChanges)
equal(C:GetSpell("Magic"),527)
equal(C:GetSpell("Disease"),528)
S:Refresh()
equal(frame.note:GetText(),"Assignments are locked during combat.")
equal(S.slots.Magic.alpha,0.55)
equal(S.slots.Magic.icon.SetDesaturatedArgs[1],true)
equal(#ui.violations,0,"dialog edits never mutate protected frames")
ui.combat=false
cursor={"spell",7,"spell",988}
equal(S:Assign(S.slots.Magic,false),true)
equal(S.slots.Magic.rank:GetText(),"Rank 2")
equal(frame.note:GetText():find("Drag a removal spell",1,true)~=nil,true,"successful assignment resets failure note")

-- A saved manual choice stays recognizable when that spell is unlearned.
known[988]=nil
frame:GetScript("OnEvent")(frame,"SPELLS_CHANGED")
equal(C:GetSpell("Magic"),nil)
equal(S.slots.Magic.title:GetText(),"Dispel Magic")
equal(S.slots.Magic.rank:GetText(),"Rank 2")
equal(S.slots.Magic.status:GetText(),"Manual - not learned")
S.slots.Magic:GetScript("OnEnter")(S.slots.Magic)
equal(GameTooltip.SetSpellByIDArgs[1],988)
equal(GameTooltip:IsShown(),true)
S.slots.Magic:GetScript("OnLeave")()
equal(GameTooltip:IsShown(),false)
known[988]=true
frame:GetScript("OnEvent")(frame,"SPELLS_CHANGED")
equal(S.slots.Magic.status:GetText(),"Manual")
frame:GetScript("OnDragStart")(frame)
equal(frame.StartMovingArgs~=nil,true)
frame:GetScript("OnDragStop")(frame)
equal(frame.StopMovingOrSizingArgs~=nil,true)
frame:Show();frame.close:GetScript("OnClick")()
equal(frame:IsShown(),false)
print("cleanse_settings_spec: "..checks.." checks passed")
