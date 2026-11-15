local ui=assert(loadfile("tests/wow_ui_fake.lua"))()()
local checks=0
local function eq(a,b,why)
    checks=checks+1;assert(rawequal(a,b),(why or "unexpected value")..": "..tostring(a).." ~= "..tostring(b))
end
local secret=setmetatable({}, {__lt=function() error("secret comparison") end,
    __le=function() error("secret comparison") end,__concat=function() error("secret concat") end})
local ns={InCombat=InCombatLockdown,IsSecret=function(v) return rawequal(v,secret) end}
local curves={}
Enum={LuaCurveType={Linear=1}}
CreateColor=function(r,g,b,a) return {GetRGBA=function() return r,g,b,a end} end
C_CurveUtil={CreateColorCurve=function()
    local curve={points={}}
    function curve:SetType(t) self.kind=t end
    function curve:AddPoint(x,c) self.points[#self.points+1]={x,c} end
    function curve:Evaluate(x)
        if rawequal(x,secret) then self.secretForwarded=true;return CreateColor(secret,secret,secret,secret) end
        local prior=self.points[1]
        for _,point in ipairs(self.points) do
            if point[1]>x then break end
            prior=point
        end
        return prior[2]
    end
    curves[#curves+1]=curve;return curve
end}
local function value(unit,key,default)
    local row=ui.units[unit]
    if row and row[key]~=nil then return row[key] end
    return default
end
UnitIsConnected=function(unit) return value(unit,"connected",true) end
UnitIsDead=function(unit) return value(unit,"dead",false) end
UnitIsGhost=function(unit) return value(unit,"ghost",false) end
UnitIsGroupLeader=function(unit) return value(unit,"leader",false) end
UnitIsPVP=function(unit) return value(unit,"pvp",false) end
UnitIsPVPFreeForAll=function(unit) return value(unit,"ffa",false) end
UnitFactionGroup=function(unit) return value(unit,"faction","Alliance") end
HasLFGRestrictions=function() return ui.guide or false end
IsThreatWarningEnabled=function() return ui.threatEnabled~=false end
UnitThreatSituation=function(unit) return value(unit,"threat",nil) end
UnitHealthPercent=function(unit,includePrediction,curve)
    eq(includePrediction,false,"warning uses actual HP")
    if value(unit,"secretHealth",false) then
        ui.secretHealthForwarded=true
        return CreateColor(secret,secret,secret,secret)
    end
    return curve:Evaluate(value(unit,"health",100)/value(unit,"maximum",100))
end
GetReadyCheckStatus=function(unit) return value(unit,"ready",nil) end
GetReadyCheckTimeLeft=function() return ui.readyRemaining or 0 end
DEFAULT_READY_CHECK_STAY_TIME=5
local registered,unregistered={},{}
VoiceActivityManager={
    RegisterFrameForVoiceActivityNotifications=function(_,owner,guid,channel,template,kind,callback)
        registered[#registered+1]={owner=owner,guid=guid,template=template,kind=kind}
        local notification=CreateFrame("Button",nil,owner)
        callback(owner,notification)
        owner.notification=notification
    end,
    UnregisterFrameForVoiceActivityNotifications=function(_,owner)
        unregistered[#unregistered+1]=owner
        if owner.notification then owner.notification:Hide() end
    end,
}
ui.units.party1={guid="member1",name="One",health=100,maximum=100}
ui.units.party2={guid="member2",name="Two",health=100,maximum=100}
assert(loadfile("WowfPartyFrames/PartyStatus.lua"))("WowfPartyFrames",ns)
local S=ns.PartyStatus
local function card(unit)
    local c=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
    c:SetAttribute("unit",unit);c.memberKey="guid:"..ui.units[unit].guid
    c.portraitArea=CreateFrame("Frame",nil,c);c.portraitArea:SetFrameLevel(5)
    c.portrait=c.portraitArea:CreateTexture(nil,"ARTWORK")
    c.status=c:CreateFontString(nil,"OVERLAY")
    c.health=CreateFrame("StatusBar",nil,c)
    c.health.texture=c.health:CreateTexture(nil,"ARTWORK")
    function c.health:GetStatusBarTexture() return self.texture end
    return c
end
local a,b=card("party1"),card("party2")
eq(S:Create(a),true);eq(S:Create(b),true)
local sa,sb=a.partyStatus,b.partyStatus
eq(#curves,2,"shared native curves are created once")
eq(S:Create(a),true);eq(#curves,2)
eq(sa.holder.mouseEnabled,false);eq(sa.warnings.mouseEnabled,false)
eq(sa.voiceAnchor.mouseEnabled,false);eq(sa.lowHolder.mouseEnabled,false)
eq(sa.holder.level<a.portraitArea.level+10,true,"status indicators remain below healing controls")
eq(S:Update(a,"party1"),true)
eq(sa.leader:IsShown(),false);eq(sa.pvp:IsShown(),false)
eq(sa.ready:IsShown(),false);eq(sa.disconnect:IsShown(),false)
eq(sa.lowHolder.alpha,0);eq(sa.threat.alpha,0)
eq(a.status:GetText(),"")
eq(sa.voiceGUID,"member1")
eq(registered[1].owner,sa.voiceAnchor,"native voice uses ordinary separate anchor")
eq(registered[1].template,"VoiceActivityNotificationPartyTemplate")
eq(sa.voiceAnchor.notification.mouseEnabled,false,"speaker notification cannot consume heal input")
eq(sa.voiceAnchor.notification.parent,sa.voiceAnchor)
S:Update(a,"party1");eq(#registered,1,"unchanged GUID does not re-register")
a.presenceDim=true;S:Update(a,"party1")
eq(a.portrait.SetDesaturatedArgs[1],true,"status refresh retains phase/other-group desaturation")
a.presenceDim=false;S:Update(a,"party1")
eq(a.portrait.SetDesaturatedArgs[1],false,"return to same group restores portrait saturation")
ui.units.party1.leader=true
S:Update(a,"party1");eq(sa.leader.atlas,"UI-HUD-UnitFrame-Player-Group-LeaderIcon")
eq(S:GetTooltipLines(a)[1],"Party leader")
ui.guide=true;S:Update(a,"party1")
eq(sa.leader.atlas,"UI-HUD-UnitFrame-Player-Group-GuideIcon")
eq(S:GetTooltipLines(a)[1],"Dungeon guide")
ui.guide=false;ui.units.party1.leader=false
ui.units.party1.pvp=true;S:Update(a,"party1")
eq(sa.pvp.atlas,"ui-hud-unitframe-player-pvp-allianceicon")
ui.units.party1.faction="Horde";S:Update(a,"party1")
eq(sa.pvp.atlas,"ui-hud-unitframe-player-pvp-hordeicon")
ui.units.party1.ffa=true;S:Update(a,"party1")
eq(sa.pvp.atlas,"ui-hud-unitframe-player-pvp-ffaicon","FFA wins normal faction flag")
ui.units.party1.ffa=false;ui.units.party1.faction="Neutral";S:Update(a,"party1")
eq(sa.pvp:IsShown(),false,"neutral faction gets no guessed faction badge")
ui.units.party1.pvp=false
ui.units.party1.ghost=true;S:Update(a,"party1")
eq(a.status:GetText(),"Ghost");eq(a.portrait.SetVertexColorArgs[3],0.75)
ui.units.party1.ghost=false;ui.units.party1.dead=true;S:Update(a,"party1")
eq(a.status:GetText(),"Dead");eq(a.portrait.SetVertexColorArgs[1],0.35)
ui.units.party1.dead=false;ui.units.party1.connected=false;S:Update(a,"party1")
eq(a.status:GetText(),"Offline");eq(sa.disconnect:IsShown(),true)
eq(a.portrait.SetDesaturatedArgs[1],true);eq(a.health.texture.SetDesaturatedArgs[1],true)
eq(sa.voiceGUID,nil);eq(sa.voiceAnchor.alpha,0)
ui.units.party1.connected=true;S:Update(a,"party1")
eq(sa.disconnect:IsShown(),false);eq(a.portrait.SetDesaturatedArgs[1],false)
eq(a.health.texture.SetDesaturatedArgs[1],false)
eq(sa.voiceAnchor.alpha,1)
ui.units.party1.health=20;S:Update(a,"party1")
eq(sa.lowHolder.alpha,1);eq(a.portrait.SetVertexColorArgs[2],0.05)
eq(sa.low.alpha>=0.5 and sa.low.alpha<=1,true,"pulse animation uses public time only")
ui.units.party1.health=21;S:Update(a,"party1")
eq(sa.lowHolder.alpha,0);eq(a.portrait.SetVertexColorArgs[2],1)
for threat=0,3 do
    ui.units.party1.threat=threat;S:Update(a,"party1")
    eq(sa.threat.alpha,threat==0 and 0 or 1)
end
ui.threatEnabled=false;S:Update(a,"party1");eq(sa.threat.alpha,0,"native threat preference is respected")
ui.threatEnabled=true
ui.combat=true
ui.units.party1.secretHealth=true;ui.units.party1.threat=secret
S:Update(a,"party1")
eq(ui.secretHealthForwarded,true);eq(sa.lowHolder.alpha,secret)
eq(a.portrait.SetVertexColorArgs[1],secret,"opaque native color reaches texture directly")
eq(curves[2].secretForwarded,true);eq(sa.threat.alpha,secret)
ui.units.party1.secretHealth=false;ui.units.party1.threat=0
ui.units.party1.leader=secret;ui.units.party1.pvp=secret;ui.units.party1.ffa=secret
ui.units.party1.connected=secret;ui.units.party1.dead=secret;ui.units.party1.ghost=secret
S:Update(a,"party1")
eq(sa.leader:IsShown(),false);eq(sa.pvp:IsShown(),false)
eq(sa.disconnect:IsShown(),false,"unknown connection state is not invented offline")
eq(a.status:GetText(),"")
for _,k in ipairs({"leader","pvp","ffa","dead","ghost"}) do ui.units.party1[k]=false end
ui.units.party1.connected=true
ui.units.party1.ready="waiting";ui.units.party2.ready="ready"
S:OnEvent("READY_CHECK")
eq(sa.ready.atlas,"UI-LFG-PendingMark");eq(sb.ready.atlas,"UI-LFG-ReadyMark")
ui.units.party1.ready="notready";S:OnEvent("READY_CHECK_CONFIRM","party1")
eq(sa.ready.atlas,"UI-LFG-DeclineMark")
ui.units.party1.ready="waiting";S:OnEvent("READY_CHECK_CONFIRM","party1")
S:OnEvent("READY_CHECK_FINISHED")
eq(sa.readyState,"afk");eq(sa.ready.atlas,"UI-LFG-DeclineMark")
eq(sb.readyState,"ready")
ui.time=ui.time+5.75;S:Update(a,"party1")
eq(sa.ready.alpha,0.5,"finished check retains result then fades")
ui.time=ui.time+1;S:Update(a,"party1");eq(sa.ready:IsShown(),false)
eq(next(S.finishedReady),nil,"expired finished results are discarded")
-- Out-of-combat roster rebuild reuses slot cards for different members.
ui.combat=false
ui.units.party1.ready="notready";ui.units.party2.ready="ready"
S:OnEvent("READY_CHECK");S:OnEvent("READY_CHECK_FINISHED")
ui.units.party1,ui.units.party2=ui.units.party2,ui.units.party1
a.memberKey="guid:member2";b.memberKey="guid:member1"
S:Clear(a);S:Clear(b)
S:Update(a,"party1");S:Update(b,"party2")
eq(sa.readyState,"ready","finished ready result follows member onto a new card")
eq(sb.readyState,"notready","finished decline follows member onto a new card")
S.finishedReady["guid:member2"].generation=S.readyGeneration-1
S:Update(a,"party1");eq(sa.readyState,nil,"old generation cannot supply a finished result")
S.finishedReady["guid:member2"].generation=S.readyGeneration
S:Update(a,"party1");eq(sa.readyState,"ready")
ui.time=ui.time+5.75;S:Update(a,"party1")
eq(sa.ready.alpha,0.5,"roster reorder does not restart the finished fade")
-- A replacement member cannot inherit either former slot occupant's result.
a.memberKey="guid:replacement";S:Update(a,"party1")
eq(sa.readyState,nil,"unknown member gets no cached finished result")
a.memberKey="guid:member2";S:Update(a,"party1")
eq(sa.readyState,"ready","known member result survives card cleanup")
ui.time=ui.time+1;S:Update(b,"party2");S:Update(a,"party1")
eq(sa.readyState,nil);eq(sb.readyState,nil);eq(next(S.finishedReady),nil)
ui.units.party1,ui.units.party2=ui.units.party2,ui.units.party1
a.memberKey="guid:member1";b.memberKey="guid:member2"
S:Update(a,"party1");S:Update(b,"party2")
S:OnEvent("READY_CHECK");S:OnEvent("READY_CHECK_FINISHED")
eq(next(S.finishedReady)~=nil,true,"current generation has results before restart")
ui.combat=true
ui.units.party1.ready="ready";S:OnEvent("READY_CHECK")
eq(next(S.finishedReady),nil,"new generation invalidates previous finished results")
eq(sa.ready:IsShown(),true);eq(sa.ready.alpha,1,"new check cancels prior fade")
-- Current secure unit changes, but the same member identity remains attached.
ui.units.party2,ui.units.party1=ui.units.party1,ui.units.party2
a.attrs.unit="party2"
S:Update(a,"party2")
eq(sa.voiceGUID,"member1","voice follows public member GUID through reorder")
eq(sa.unit,"party2")
eq(#ui.violations,0,"combat update only changes unprotected presentation")
eq(S:Create({}),false,"combat never allocates new card presentation")
ui.combat=false
-- A genuinely different member cannot inherit an old finished ready result.
S:OnEvent("READY_CHECK_FINISHED")
a.memberKey="guid:new";ui.units.party2={guid="new",name="New",health=100,maximum=100}
S:Update(a,"party2")
eq(sa.readyState,nil);eq(sa.voiceGUID,"new")
S:Clear(a)
eq(sa.voiceGUID,nil);eq(sa.ready:IsShown(),false);eq(sa.leader:IsShown(),false)
eq(sa.threat.alpha,0);eq(sa.lowHolder.alpha,0)
eq(a.portrait.SetVertexColorArgs[1],1);eq(#S:GetTooltipLines(a),0)
ns.worldActive=false;eq(S:Update(a,"party2"),false)
ns.worldActive=true;eq(S:Update(a,secret),false);eq(S:Update(a,"player"),false)
eq(S:Update(a,"party4"),false)
S:Update(a,"party2");S:OnEvent("PLAYER_LEAVING_WORLD")
eq(sa.voiceGUID,nil);eq(sa.ready:IsShown(),false)
eq(next(S.finishedReady),nil,"world cleanup drops member ready cache")
S.finishedReady["guid:stale"]={state="ready",generation=S.readyGeneration}
S:OnEvent("GROUP_LEFT");eq(next(S.finishedReady),nil,"leaving group drops member ready cache")
-- Reload midway through a ready check is recognized without guessing old state.
ui.readyRemaining=8;ui.units.party2.ready="ready"
S:Update(a,"party2");eq(sa.readyState,"ready")
ui.readyRemaining=0;S:Update(a,"party2");eq(sa.ready:IsShown(),false)
-- Missing optional APIs do not stop party frame updates.
VoiceActivityManager=nil;UnitHealthPercent=nil;IsThreatWarningEnabled=nil
UnitIsGroupLeader=nil;UnitIsPVP=nil;UnitIsPVPFreeForAll=nil;GetReadyCheckStatus=nil
eq(S:Update(a,"party2"),true);eq(sa.leader:IsShown(),false);eq(sa.pvp:IsShown(),false)
eq(sa.lowHolder.alpha,0);eq(sa.threat.alpha,0)
local preview=card("party2");preview.previewIndex=1
local tracked=0;for _ in pairs(S.cards) do tracked=tracked+1 end
eq(S:Create(preview),true);eq(S:Update(preview,"party2"),false)
local afterCreate=0;for _ in pairs(S.cards) do afterCreate=afterCreate+1 end
eq(afterCreate,tracked,"sample cards are not registered in live ready/voice lifecycle")
local function noLiveRead() error("preview must not query live units or voice") end
UnitExists,UnitHealthPercent,UnitThreatSituation,UnitGUID=noLiveRead,noLiveRead,noLiveRead,noLiveRead
GetReadyCheckStatus,GetReadyCheckTimeLeft=noLiveRead,noLiveRead
VoiceActivityManager={RegisterFrameForVoiceActivityNotifications=noLiveRead,UnregisterFrameForVoiceActivityNotifications=noLiveRead}
local ps=preview.partyStatus
local generation=S.readyGeneration
local sample={leader=true,guide=true,pvp="FFA",readyState="ready",voice=true,health=20,healthMax=100,threat=3}
eq(S:Preview(preview,sample),true)
eq(ps.leader.atlas,"UI-HUD-UnitFrame-Player-Group-GuideIcon")
eq(ps.pvp.atlas,"ui-hud-unitframe-player-pvp-ffaicon")
eq(ps.ready.atlas,"UI-LFG-ReadyMark");eq(ps.ready.alpha,1)
eq(ps.previewVoice.atlas,"voicechat-icon-speaker");eq(ps.previewVoice:IsShown(),true)
eq(ps.voiceAnchor.alpha,1);eq(ps.voiceGUID,nil)
eq(ps.lowHolder.alpha,1);eq(ps.threat.alpha,1)
eq(preview.portrait.SetVertexColorArgs[2],.05)
eq(S:GetTooltipLines(preview)[1],"Dungeon guide")
eq(S.readyGeneration,generation);eq(next(S.finishedReady),nil)
sample.connected=false;S:Preview(preview,sample)
eq(preview.status:GetText(),"Offline");eq(ps.disconnect:IsShown(),true)
eq(ps.previewVoice:IsShown(),false);eq(ps.ready:IsShown(),false)
eq(ps.lowHolder.alpha,0);eq(ps.threat.alpha,0)
sample.connected=true;sample.ghost=true;S:Preview(preview,sample)
eq(preview.status:GetText(),"Ghost");eq(preview.portrait.SetVertexColorArgs[3],.75)
sample.ghost=false;sample.dead=true;S:Preview(preview,sample)
eq(preview.status:GetText(),"Dead");eq(preview.portrait.SetVertexColorArgs[1],.35)
eq(S:Preview(a,sample),false,"sample writer cannot overwrite a live card")
S:Clear(preview)
eq(ps.leader:IsShown(),false);eq(ps.ready:IsShown(),false);eq(ps.previewVoice:IsShown(),false)
eq(ps.voiceAnchor.alpha,0)
S:Preview(preview,{})
eq(ps.leader:IsShown(),false);eq(ps.pvp:IsShown(),false);eq(preview.status:GetText(),"")
eq(ps.lowHolder.alpha,0);eq(ps.threat.alpha,0)
eq(#ui.violations,0)
print("party_status_spec: "..checks.." checks passed (native curve/voice behavior simulated)")
