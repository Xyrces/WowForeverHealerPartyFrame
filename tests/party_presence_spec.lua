local ui=assert(loadfile("tests/wow_ui_fake.lua"))()()
local secret={}
local seconds,combat=0,false
local popups,menus,hidden={},{},{}
GetEvictionTimeRemaining=function() return seconds end
UnitAffectingCombat=function() return combat end
C_PlayerInteractionManager={ShardTransferConfirm=function() error("addon must use native confirmation, never transfer directly") end}
StaticPopup_Show=function(which) popups[#popups+1]=which end
StaticPopup_Hide=function(which) hidden[#hidden+1]=which end
UnitPopup_OpenMenu=function(which,context) menus[#menus+1]={which,context} end
local info={presenceKind="shard",presenceText="Different shard",presenceTexture="phase",
    presenceTooltip="Different shard explanation",differentShard=true,presenceDim=true,location="Westfall"}
local ns={InCombat=function() return ui.combat end,IsSecret=function(v) return rawequal(v,secret) end,
    MemberInfo={Get=function() return info end}}
assert(loadfile("WowfPartyFrames/PartyPresence.lua"))("WowfPartyFrames",ns)
local P=ns.PartyPresence
local checks=0
local function eq(a,b,m) checks=checks+1;assert(a==b,m or tostring(a).." ~= "..tostring(b)) end
eq(P:CanConfirmTransfer(),false)
eq(P:ConfirmTransfer(),false);eq(#popups,0,"no arbitrary join action")
seconds=secret;eq(P:CanConfirmTransfer(),false,"secret countdown is never compared")
seconds=30;P:OnEvent("PLAYER_ENTERING_WORLD")
eq(P:CanConfirmTransfer(),true)
ui.combat=true;eq(P:ConfirmTransfer(),false);eq(#popups,0)
ui.combat=false;combat=secret;eq(P:ConfirmTransfer(),false)
combat=true;eq(P:ConfirmTransfer(),false)
combat=false;eq(P:ConfirmTransfer(),true);eq(popups[1],"SHARD_TRANSFER_IMMINENT_EVENT")
seconds=0;eq(P:ConfirmTransfer(),true);eq(popups[2],"SHARD_TRANSFER_IMMEDIATE","pending request survives countdown expiry")
for _,event in ipairs({"SHARD_TRANSFER_CANCELLED","SHARD_TRANSFER","PLAYER_LEAVING_WORLD"}) do
    P:OnEvent("SHARD_TRANSFER_IMMINENT");eq(P:CanConfirmTransfer(),true)
    seconds=30 -- Terminal events override a countdown that has not reset yet.
    P:OnEvent(event);eq(P:CanConfirmTransfer(),false)
    eq(P:ConfirmTransfer(),false,"stale timer cannot resurrect a cancelled transfer")
end
eq(hidden[1],"SHARD_TRANSFER_IMMEDIATE","cancel also closes our immediate confirmation")
seconds=0
local card=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate")
card:SetAttribute("unit","party1")
card.portraitArea=CreateFrame("Frame",nil,card)
card.portrait=card.portraitArea:CreateTexture()
card.location=card:CreateFontString()
P:Create(card)
local b=card.presenceButton
eq(b.protected,false,"presence icon is not a casting control")
P:Update(card,info)
eq(b.shown,true);eq(b.icon.texture,"phase");eq(card.presenceDim,true)
eq(card.location:GetText(),"Different shard · Westfall")
b:GetScript("OnClick")(b,"LeftButton")
eq(#popups,2,"different shard alone does not invent pending transfer")
eq(menus[1][2].unit,"party1");eq(menus[1][2].ownerFrame,card)
card.attrs.unit="party2"
b:GetScript("OnClick")(b,"RightButton")
eq(menus[2][2].unit,"party2","menu follows current secure owner after reorder")
P:OnEvent("SHARD_TRANSFER_IMMINENT")
b:GetScript("OnClick")(b,"LeftButton");eq(#popups,3)
eq(popups[3],"SHARD_TRANSFER_IMMEDIATE")
info={}
P:Update(card,info);eq(b.shown,false);eq(card.presenceDim,false);eq(card.location:GetText(),"")
P:Clear(card);eq(b.shown,false)
local preview=CreateFrame("Frame",nil,UIParent)
preview.previewIndex=1
preview.portraitArea=CreateFrame("Frame",nil,preview)
preview.portrait=preview.portraitArea:CreateTexture()
preview.location=preview:CreateFontString()
preview.previewInfo={presenceKind="shard",presenceText="Different shard",presenceTexture="phase",
    presenceTooltip="Sample shard mismatch",differentShard=true,presenceDim=true,location="Westfall"}
P:Create(preview)
local pb=preview.presenceButton
eq(pb.protected,false);eq(pb.template,nil,"sample presence never gains secure behavior")
P:Update(preview,preview.previewInfo)
eq(pb:IsShown(),true);eq(pb.icon.texture,b.icon.texture)
eq(preview.location:GetText(),"Different shard · Westfall");eq(preview.presenceDim,true)
ns.MemberInfo.Get=function() error("preview cannot query live member info") end
GetEvictionTimeRemaining=function() error("preview cannot inspect real transfer") end
pb:GetScript("OnEnter")(pb)
eq(GameTooltip:GetText(),"Different shard")
eq(GameTooltip.AddLineArgs[1],"Sample data: no party actions or shard transfer.")
local popupCount,menuCount=#popups,#menus
pb:GetScript("OnClick")(pb,"LeftButton");pb:GetScript("OnClick")(pb,"RightButton")
eq(#popups,popupCount,"sample shard cannot offer a real transfer")
eq(#menus,menuCount,"sample presence cannot open a real member menu")
P:Clear(preview);eq(pb:IsShown(),false)
P:Update(preview,{});eq(preview.location:GetText(),"");eq(preview.presenceDim,false)
eq(#ui.violations,0)
print("party_presence_spec: "..checks.." checks passed")
