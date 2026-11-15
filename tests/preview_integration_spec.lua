-- Exercise the shipped slash-command preview, not a renderer-only fixture.
-- The native engine is deliberately unavailable: samples must remain inert.
local state = assert(loadfile("tests/wow_ui_fake.lua"))()()
local ns, checks = {}, 0
local function equal(actual, expected, message)
    checks=checks+1
    assert(actual==expected,(message or "unexpected value")..": "..tostring(actual).." ~= "..tostring(expected))
end
state.subgroupCount=0
state.units.player={guid="Player-Owner",name="Priest",class="PRIEST",health=100,maxHealth=100,power=100,maxPower=100}
UISpecialFrames={}
WowfPartyFramesDB=nil
issecretvalue=function() return false end
GetLocale=function() return "enUS" end
IsLoggedIn=function() return true end
GetBuildInfo=function() return "1.60.1","70938","date",16001 end
C_AuraContainerUtil=nil
C_UnitAuras=nil
C_CombatLog={IsCombatLogRestricted=function() return true end}
local showPets=true
GetCVarBool=function(name) return name=="showPartyPets" and showPets or false end
GameTooltip.GetOwner=function(self) return self.SetOwnerArgs and self.SetOwnerArgs[1] end
GameTooltip.IsOwned=function(self,owner) return self:GetOwner()==owner end
GameTooltip.GetBottom=function(self) return self:GetTop()-self:GetHeight() end
local watchCalls, voiceCalls, menuCalls, transferCalls=0,0,0,0
local watch=RegisterUnitWatch
RegisterUnitWatch=function(frame) watchCalls=watchCalls+1;return watch(frame) end
VoiceActivityManager={RegisterFrameForVoiceActivityNotifications=function() voiceCalls=voiceCalls+1 end,
    UnregisterFrameForVoiceActivityNotifications=function() voiceCalls=voiceCalls+1 end}
UnitPopup_OpenMenu=function() menuCalls=menuCalls+1 end
StaticPopup_Show=function() transferCalls=transferCalls+1 end
C_PlayerInteractionManager={ShardTransferConfirm=function() transferCalls=transferCalls+1 end}
local ids={2050,2052,139,1243}
local data={
    [2050]={name="Lesser Heal",iconID=100,spellID=2050},
    [2052]={name="Lesser Heal",iconID=100,spellID=2052},
    [139]={name="Renew",iconID=200,spellID=139},
    [1243]={name="Power Word: Fortitude",iconID=300,spellID=1243},
}
Enum={SpellBookSpellBank={Player=0,Pet=1}}
C_Spell={GetSpellInfo=function(id) return data[id] end,
    GetSpellSubtext=function(id) return id==2052 and "Rank 2" or "Rank 1" end,
    GetSpellDescription=function(id) return id==139 and "Heals the target for 45 over 15 sec." or "Heals the target for 15 to 20." end,
    RequestLoadSpellData=function() end}
C_SpellBook={IsSpellKnown=function(id) return data[id]~=nil end,
    GetNumSpellBookSkillLines=function() return 1 end,
    GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=#ids} end,
    GetSpellBookItemInfo=function(slot) return data[ids[slot]] end}
AddonCompartmentFrame={RegisterAddon=function() end}
for line in io.lines("WowfPartyFrames/WowfPartyFrames.toc") do
    local file=line:match("^%s*(.-)%s*$")
    if file~="" and file:sub(1,1)~="#" then assert(loadfile("WowfPartyFrames/"..file))("WowfPartyFrames",ns) end
end
state.emit("ADDON_LOADED","WowfPartyFrames")
state.emit("PLAYER_LOGIN")
state.emit("PLAYER_ENTERING_WORLD",true,false)
equal(ns.started,true,"whole manifest starts before the slash command")
local preset=assert(ns.Profiles:Create("Preview spells"))
assert(ns.Profiles:SetSpell(preset,"heals",1,2050))
assert(ns.Profiles:SetSpell(preset,"heals",1,2052,"shift"))
assert(ns.Profiles:SetSpell(preset,"heals",1,139,"ctrl"))
assert(ns.Profiles:SetSpell(preset,"buffs",1,1243))
ns.Settings:SelectPreset(preset)
local beforeObjects,beforeWatch,beforeVoice=#state.objects,watchCalls,voiceCalls
GameTooltip.SetUnit=function() error("Sample tooltip must not query a real unit") end
local generation=ns.PartyStatus.readyGeneration
local finished=ns.PartyStatus.finishedReady
local members=ns.Assignments.members
SlashCmdList.WOWFPARTYFRAMES("test")
local preview=assert(ns.Frames.preview)
equal(preview:IsShown(),true)
equal(#preview.cards,4)
equal(watchCalls,beforeWatch,"preview creates no native unit watchers")
equal(voiceCalls,beforeVoice,"preview creates no live voice registration")
equal(ns.PartyStatus.readyGeneration,generation,"sample ready states do not change live generation")
equal(ns.PartyStatus.finishedReady,finished,"sample ready states do not replace live results")
equal(ns.Assignments.members,members,"sample members do not enter live assignment roster")
local counts={role=0,marker=0,presence=0,ready=0,leader=0,pvp=0,pet=0}
for index,card in ipairs(preview.cards) do
    equal(card.previewIndex,index,"sample identity remains explicit")
    equal(card:GetAttribute("unit"),nil,"sample never impersonates a live party unit")
    equal(card.name:GetText():find(" ",1,true)~=nil,true,"shipped sample shows surname")
    equal(card.previewSample,ns.PreviewData.samples[index],"one shared fixture drives command and renderer")
    equal(card.presetID,preset,"selected preset still controls preview spells")
    equal(card.heals[1].spellID,2050)
    equal(card.buffs[1].spellID,1243)
    if card.roleIcon:IsShown() then counts.role=counts.role+1 end
    if card.markerIcon:IsShown() then counts.marker=counts.marker+1 end
    if card.presenceButton and card.presenceButton:IsShown() then
        counts.presence=counts.presence+1
        local click=card.presenceButton:GetScript("OnClick")
        if click then click(card.presenceButton,"LeftButton");click(card.presenceButton,"RightButton") end
    end
    local status=assert(card.partyStatus,"preview must use the real status widgets")
    for _,key in ipairs({"ready","leader","pvp"}) do if status[key]:IsShown() then counts[key]=counts[key]+1 end end
    if card.partyPet and card.partyPet.button:IsShown() then counts.pet=counts.pet+1 end
end
for key,count in pairs(counts) do equal(count>0,true,"preview demonstrates "..key) end
equal(menuCalls,0,"sample presence never opens live party menu")
equal(transferCalls,0,"sample shard never opens or confirms live transfer")
-- The body and aura hover use the shipped callbacks, not a mock renderer.
local sample=preview.cards[1]
local enter=assert(sample:GetScript("OnEnter"),"sample body tooltip is wired")
enter(sample)
equal(GameTooltip:GetText(),sample.previewSample.name,"sample tooltip keeps the complete display name")
local auraPanel=assert(ns.AuraDetails.previewPanelState,"preview aura panel exists without native aura APIs")
equal(auraPanel.frame:IsShown(),true,"body hover opens sample aura details")
local aura=assert(auraPanel.views[1].icons[1],"helpful sample icons are accessible")
equal(aura:IsShown(),true)
equal(aura.sampleIcon.texture,sample.previewSample.auras.helpful[1].icon)
aura:GetScript("OnEnter")(aura)
equal(GameTooltip:GetText(),sample.previewSample.auras.helpful[1].name,"sample effect tooltip names the hovered aura")
local harmful=assert(auraPanel.views[2].icons[1])
equal(harmful:IsShown(),true)
equal(harmful.sampleTimer:GetText(),sample.previewSample.auras.harmful[1].durationText)
ns.AuraDetails:Hide()
equal(auraPanel.frame:IsShown(),false,"same hide path closes sample panel")
for index=beforeObjects+1,#state.objects do
    local object=state.objects[index]
    equal(object.protected,false,"all preview-created objects are ordinary UI")
    equal(object:GetAttribute("unit"),nil)
    equal(object:GetAttribute("type1"),nil,"preview has no secure action")
    equal(object:GetAttribute("spell1"),nil,"preview has no secure spell")
    equal(object.unitWatch,nil)
end
-- Public settings and modifier events keep using the ordinary preview path.
ns.Settings:SelectHealLayer("shift")
ns.Frames:RefreshAll(true)
equal(preview.cards[1].heals[1].spellID,2052)
state.ctrl=true
state.emit("MODIFIER_STATE_CHANGED","LCTRL",1)
equal(preview.cards[1].heals[1].spellID,139,"physical modifier selects its exact assigned spell")
state.ctrl=false
state.emit("MODIFIER_STATE_CHANGED","LCTRL",0)
equal(preview.cards[1].heals[1].spellID,2052,"release returns to settings preview layer")
assert(ns.Settings:SetControlStyle("quadrants"))
equal(ns.db.controlStyle,"quadrants")
equal(preview.cards[1].heals[1].spellID,2052,"style preserves selected spell layer")
showPets=false
state.emit("CVAR_UPDATE","showPartyPets","0")
for _,card in ipairs(preview.cards) do
    if card.partyPet then equal(card.partyPet.button:IsShown(),false,"native pet preference updates sample row") end
end
showPets=true
state.emit("CVAR_UPDATE","showPartyPets","1")
equal(preview.cards[1].partyPet.button:IsShown(),true,"pet sample returns without a fake live unit")
sample:GetScript("OnEnter")(sample)
equal(auraPanel.frame:IsShown(),true)
SlashCmdList.WOWFPARTYFRAMES("test")
equal(preview:IsShown(),false)
-- The minimal harness does not dispatch native OnHide when a parent hides.
-- Invoke that real callback to check the cleanup the client will dispatch.
assert(preview:GetScript("OnHide"))(preview)
equal(auraPanel.frame:IsShown(),false,"closing preview clears its independent hover panel")
equal(sample.UpdateTooltip,nil,"closing preview releases the body tooltip callback")
equal(sample.partyStatus.leader:IsShown(),false,"hidden preview clears transient native-style badges")
SlashCmdList.WOWFPARTYFRAMES("test")
equal(preview:IsShown(),true)
equal(preview.cards[1].partyStatus.leader:IsShown(),true,"reopening restores shared status decorations")
equal(preview.cards[1].presenceButton:IsShown(),true)
-- Transition to a real party must not copy synthetic identity or badges.
state.units.party1={name="Actual",class="MAGE",guid="Player-Actual",health=80,maxHealth=100,power=50,maxPower=100}
state.subgroupCount=1
state.emit("GROUP_ROSTER_UPDATE")
equal(preview:IsShown(),false,"joining a real party closes samples")
equal(ns.Frames.cards[1].name:GetText(),"Actual")
equal(ns.Frames.cards[1].partyStatus.leader:IsShown(),false,"sample leader never contaminates live member")
equal(ns.Frames.cards[1].partyStatus.ready:IsShown(),false,"sample ready never contaminates live member")
equal(ns.Frames.cards[1].previewSample,nil)
equal(ns.PartyStatus.readyGeneration,generation)
equal(#state.violations,0)
print("preview_integration_spec: "..checks.." checks passed (actual slash path; native engine not emulated)")
