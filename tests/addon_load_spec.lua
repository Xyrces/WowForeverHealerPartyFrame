-- Load the actual manifest, not a hand-maintained subset. This catches module
-- order and startup/UI regressions that can otherwise make /wpf disappear.
-- The UI fixture models calls, not the client's secure/native aura engine.
local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
local ns, checks = {}, 0
local function equal(actual, expected, message)
    checks=checks+1
    assert(actual==expected,(message or "unexpected value")..": "..tostring(actual).." ~= "..tostring(expected))
end
state.units.player={guid="Player-Owner",name="Priest",class="PRIEST",health=100,maxHealth=100,power=100,maxPower=100}
state.units.party1={guid="Player-Tank",name="Tank",class="WARRIOR",health=75,maxHealth=100,power=30,maxPower=100}
state.subgroupCount=1
UISpecialFrames={}
WowfPartyFramesDB=nil
issecretvalue=function() return false end
GetLocale=function() return "enUS" end
IsLoggedIn=function() return true end
GetBuildInfo=function() return "1.60.1","70938","date",16001 end
-- Deliberately unavailable native auras must not stop ordinary party frames,
-- settings, or slash commands from initializing.
C_AuraContainerUtil=nil
C_UnitAuras=nil
C_CombatLog={IsCombatLogRestricted=function() return true end}
local known={[527]=true,[988]=true,[528]=true,[552]=true,[2050]=true}
local ids={527,988,528,552,2050}
local data={
    [527]={name="Dispel Magic",iconID=100,spellID=527},
    [988]={name="Dispel Magic",iconID=100,spellID=988},
    [528]={name="Cure Disease",iconID=200,spellID=528},
    [552]={name="Abolish Disease",iconID=300,spellID=552},
    [2050]={name="Lesser Heal",iconID=400,spellID=2050},
}
local rank={[527]="Rank 1",[988]="Rank 2",[2050]="Rank 1"}
Enum={SpellBookSpellBank={Player=0,Pet=1}}
C_Spell={
    GetSpellInfo=function(id) return data[id] end,
    GetSpellSubtext=function(id) return rank[id] or "" end,
    GetSpellDescription=function(id) return id==2050 and "Heals the target for 15 to 20." or "Removes a harmful effect." end,
    RequestLoadSpellData=function() end,
}
C_SpellBook={
    IsSpellKnown=function(id,bank) assert(bank==0);return known[id]==true end,
    GetNumSpellBookSkillLines=function() return 1 end,
    GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=#ids} end,
    GetSpellBookItemInfo=function(slot,bank)
        assert(bank==0)
        local id=ids[slot]
        if id then return {spellID=id,name=data[id].name,subName=rank[id] or "",iconID=data[id].iconID} end
    end,
}
local cursor,cleared={},0
GetCursorInfo=function() return unpack(cursor) end
ClearCursor=function() cursor={};cleared=cleared+1 end
local minimap={}
AddonCompartmentFrame={RegisterAddon=function(_,entry) minimap[#minimap+1]=entry end}
local modules={}
for line in io.lines("WowfPartyFrames/WowfPartyFrames.toc") do
    local file=line:match("^%s*(.-)%s*$")
    if file~="" and file:sub(1,1)~="#" then
        equal(file:match("%.lua$")~=nil,true,"TOC executable entry is Lua")
        assert(loadfile("WowfPartyFrames/"..file))("WowfPartyFrames",ns)
        modules[#modules+1]=file
    end
end
equal(#modules>=22,true,"whole current manifest loaded")
equal(type(SlashCmdList.WOWFPARTYFRAMES),"function")
state.emit("ADDON_LOADED","WowfPartyFrames")
state.emit("PLAYER_LOGIN")
state.emit("PLAYER_ENTERING_WORLD",true,false)
equal(ns.started,true,"all real modules reach successful startup")
equal(ns.Frames.ready,true)
equal(ns.Cleanses.owner,"guid:Player-Owner")
equal(ns.Cleanses:GetSpell("Magic"),988,"manifest startup selects highest learned Dispel rank")
equal(ns.Cleanses:GetSpell("Disease"),528)
equal(ns.Cleanses:GetSpell("Poison"),nil)
equal(#ns.Cleanses:GetActions(),2)
equal(#minimap,1,"repeated login does not duplicate AddOns menu")
local card=ns.Frames.cards[1]
equal(card:GetAttribute("unit"),"party1")
equal(card.health.value,75,"ordinary bars work without native aura API")
equal(card.cleanseDisplay.supported,false)
equal(card.cleanseDisplay.container,nil,"unsupported native API creates no cast container")
equal(next(card.cleanseDisplay.slots),nil,"unsupported feature leaves no clickable underlay")
SlashCmdList.WOWFPARTYFRAMES("")
equal(ns.Settings.frame:IsShown(),true,"/wpf opens actual settings")
SlashCmdList.WOWFPARTYFRAMES("settings")
equal(ns.Settings.frame:IsShown(),false)
minimap[1].func()
equal(ns.Settings.frame:IsShown(),true,"native AddOns entry reaches same settings")
ns.Settings.frame.cleanseButton:GetScript("OnClick")()
equal(ns.CleanseSettings.frame:IsShown(),true,"main settings opens removal popup")
equal(ns.CleanseSettings.slots.Magic.rank:GetText(),"Rank 2")
equal(ns.CleanseSettings.slots.Disease.title:GetText(),"Cure Disease")

-- Count but retain the real Core callback and Frames implementations.
local callback,apply,refresh=ns.OnCleansesChanged,ns.Frames.ApplyProfiles,ns.Frames.RefreshAll
local edits,applies,refreshes=0,0,0
ns.OnCleansesChanged=function(...) edits=edits+1;return callback(...) end
ns.Frames.ApplyProfiles=function(self,...) applies=applies+1;return apply(self,...) end
ns.Frames.RefreshAll=function(self,...) refreshes=refreshes+1;return refresh(self,...) end
cursor={"spell",1,"spell",527}
ns.CleanseSettings.slots.Magic:GetScript("OnReceiveDrag")(ns.CleanseSettings.slots.Magic)
equal(cleared,1)
equal(edits,1,"real user edit reaches Core callback")
equal(applies,1,"callback reapplies live assignments")
equal(refreshes,1,"callback refreshes live presentation")
equal(ns.Cleanses:GetSpell("Magic"),527)
equal(ns.CleanseSettings.slots.Magic.rank:GetText(),"Rank 1")
equal(card.health.value,75,"failed-closed cleanse display preserves ordinary bar updates")
equal(card.cleanseDisplay.container,nil)
equal(WowfPartyFramesDB.cleanseCharacters["guid:Player-Owner"].overrides.Magic,527)

-- Existing noncasting solo preview also refreshes through the same callback.
state.subgroupCount=0
SlashCmdList.WOWFPARTYFRAMES("test")
equal(ns.Frames.preview:IsShown(),true)
local preview=ns.Frames.preview.cards
equal(preview[1].cleansePreview[1]:IsShown(),true,"idle sample keeps visible cleanse controls")
equal(preview[1].cleansePreview[1].icon.SetDesaturatedArgs[1],true,"idle sample is grey")
equal(preview[2].cleansePreview[1]:IsShown(),true,"active sample appears")
equal(preview[2].cleansePreview[1].spellID,527)
equal(preview[2].cleansePreview[1]:GetAttribute("type1"),nil,"preview cannot cast")
cursor={"spell",2,"spell",988}
ns.CleanseSettings.slots.Magic:GetScript("OnClick")(ns.CleanseSettings.slots.Magic,"LeftButton")
equal(cleared,2)
equal(edits,2)
equal(applies,2)
equal(refreshes,2)
equal(preview[2].cleansePreview[1].spellID,988,"real callback refreshes existing preview")
equal(preview[2].cleansePreview[1]:GetAttribute("spell"),nil)

-- The two real numeric settings are linked and persist one canonical value.
local settings=ns.Settings.frame
equal(settings.historyStep:GetText(),"0.25")
equal(settings.historyTotal:GetText(),"3")
settings.historyStep:SetText("0.5")
settings.historyStep:GetScript("OnEnterPressed")(settings.historyStep)
equal(ns.HealthHistory:GetSampleInterval(),0.5)
equal(ns.HealthHistory:GetWindowSeconds(),6)
equal(settings.historyTotal:GetText(),"6","step edit updates total UI")
equal(WowfPartyFramesDB.historySampleInterval,0.5)
settings.historyTotal:SetText("9")
settings.historyTotal:GetScript("OnEnterPressed")(settings.historyTotal)
equal(ns.HealthHistory:GetSampleInterval(),0.75)
equal(ns.HealthHistory:GetWindowSeconds(),9)
equal(settings.historyStep:GetText(),"0.75","total edit updates step UI")
equal(WowfPartyFramesDB.historySampleInterval,0.75)
-- Existing saved-variable initialization must not erase either new feature.
ns.db=ns.Profiles:Init(WowfPartyFramesDB)
ns.Cleanses:Init(ns.db)
equal(ns.HealthHistory:GetSampleInterval(),0.75,"history step survives profile sanitization")
equal(ns.HealthHistory:GetWindowSeconds(),9)
equal(ns.Cleanses:GetSpell("Magic"),988,"cleanse choice survives profile sanitization")
equal(ns.Cleanses:GetSlots()[1].mode,"manual")

state.combat=true
state.emit("PLAYER_REGEN_DISABLED")
ns.events:GetScript("OnUpdate")(ns.events,0.11)
equal(ns.Frames.preview:IsShown(),false,"combat closes noncasting preview")
equal(ns.CleanseSettings:Assign(ns.CleanseSettings.slots.Magic,true),false)
equal(ns.Cleanses:GetSpell("Magic"),988)
equal(ns.Settings:SetHistoryValue("step","1"),false)
equal(ns.HealthHistory:GetSampleInterval(),0.75)
equal(card.cleanseDisplay.container,nil,"no combat fallback creates invisible casting buttons")
equal(#state.violations,0)
state.combat=false
state.emit("PLAYER_REGEN_ENABLED")
SlashCmdList.WOWFPARTYFRAMES("status")
equal(table.concat(state.messages,"\n"):find("Debuff removal: Native cleanse controls are unavailable",1,true)~=nil,true)
equal(ns.started,true)
equal(#state.violations,0)
print("addon_load_spec: "..checks.." checks passed; "..#modules.." manifest modules loaded")
