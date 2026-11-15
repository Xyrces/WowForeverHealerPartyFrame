local _, ns = ...
local Status = {cards=setmetatable({}, {__mode="k"}), readyGeneration=0, finishedReady={}}
ns.PartyStatus = Status
local PORTRAIT_ART = "Interface\\CharacterFrame\\UI-Player-Portrait"
local READY = {waiting="UI-LFG-PendingMark",ready="UI-LFG-ReadyMark",notready="UI-LFG-DeclineMark",afk="UI-LFG-DeclineMark"}
local function public(value, kind)
    return not ns.IsSecret(value) and (not kind or type(value)==kind)
end
local function call(fn, ...)
    if type(fn)~="function" then return nil end
    local ok,result=pcall(fn,...)
    if ok then return result end
end
local function now()
    local value=call(GetTime)
    return public(value,"number") and value or 0
end
local function icon(parent, size, point, relative, x, y)
    local t=parent:CreateTexture(nil,"OVERLAY")
    t:SetSize(size,size);t:SetPoint(point,relative,point,x,y);t:Hide()
    return t
end
local function setIcon(t,atlas)
    if atlas then t:SetAtlas(atlas);t:Show() else t:Hide() end
end
local function rim(parent,card)
    local t=parent:CreateTexture(nil,"OVERLAY")
    t:SetTexture(PORTRAIT_ART);t:SetTexCoord(72/256,4/256,2/128,70/128)
    t:SetSize(85,85);t:SetPoint("CENTER",card.portraitArea,"CENTER")
    local mask=parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(t);t:AddMaskTexture(mask);t:SetBlendMode("ADD")
    return t
end
local function buildCurve(points)
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve or not CreateColor or not Enum or not Enum.LuaCurveType then return end
    return call(function()
        local curve=C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        for _,p in ipairs(points) do curve:AddPoint(p[1],CreateColor(p[2],p[3],p[4],p[5])) end
        return curve
    end)
end

function Status:Create(card)
    if card.partyStatus then return true end
    if ns.InCombat() then return false end
    local s={lines={}}
    card.partyStatus=s
    if not card.previewIndex then self.cards[card]=true end
    local holder=CreateFrame("Frame",nil,card)
    s.holder=holder;holder:SetAllPoints(card.portraitArea)
    holder:SetFrameLevel(card.portraitArea:GetFrameLevel()+6);holder:EnableMouse(false)
    s.leader=icon(holder,16,"TOPLEFT",card.portraitArea,-2,6)
    s.pvp=icon(holder,16,"BOTTOMLEFT",card.portraitArea,-2,1)
    s.ready=icon(holder,22,"CENTER",card.portraitArea,0,0)
    s.disconnect=icon(holder,30,"CENTER",card.portraitArea,0,0)
    s.disconnect:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
    s.voiceAnchor=CreateFrame("Frame",nil,holder)
    s.voiceAnchor:SetSize(16,16)
    s.voiceAnchor:SetPoint("LEFT",card.portraitArea,"LEFT",-2,0)
    s.voiceAnchor:EnableMouse(false)
    if card.previewIndex then
        -- A sample speaker uses the native art, never a real voice subscription.
        s.previewVoice=icon(s.voiceAnchor,16,"CENTER",s.voiceAnchor,0,0)
        s.previewVoice:SetAtlas("voicechat-icon-speaker")
    end
    local warnings=CreateFrame("Frame",nil,card)
    s.warnings=warnings;warnings:SetAllPoints(card.portraitArea)
    warnings:SetFrameLevel(card.portraitArea:GetFrameLevel()+1);warnings:EnableMouse(false)
    s.threat=rim(warnings,card);s.threat:SetAlpha(0)
    s.lowHolder=CreateFrame("Frame",nil,warnings)
    s.lowHolder:SetAllPoints(card.portraitArea);s.lowHolder:EnableMouse(false);s.lowHolder:SetAlpha(0)
    s.low=rim(s.lowHolder,card);s.low:SetVertexColor(1,0.05,0.05)
    if not self.curvesAttempted then
        self.curvesAttempted=true
        self.healthCurve=buildCurve({{0,1,1,1,0},{0.000001,1,0.05,0.05,1},{0.2,1,0.05,0.05,1},{0.200001,1,1,1,0},{1,1,1,1,0}})
        self.threatCurve=buildCurve({{0,1,1,1,0},{1,1,1,0,1},{2,1,0.6,0,1},{3,1,0,0,1}})
    end
    return true
end

local function releaseVoice(s)
    s.voiceAnchor:SetAlpha(0)
    if s.previewVoice then s.previewVoice:Hide() end
    if s.voiceGUID and VoiceActivityManager and VoiceActivityManager.UnregisterFrameForVoiceActivityNotifications then
        pcall(VoiceActivityManager.UnregisterFrameForVoiceActivityNotifications,VoiceActivityManager,s.voiceAnchor)
    end
    s.voiceGUID=nil
end

function Status:Clear(card)
    local s=card and card.partyStatus
    if not s then return end
    releaseVoice(s)
    for _,key in ipairs({"leader","pvp","ready","disconnect"}) do s[key]:Hide() end
    s.threat:SetAlpha(0);s.lowHolder:SetAlpha(0)
    s.lines={};s.unit=nil;s.identity=nil;s.readyState=nil;s.readyGeneration=nil
    if card.portrait then card.portrait:SetDesaturated(false);card.portrait:SetVertexColor(1,1,1) end
    if card.health and card.health.GetStatusBarTexture then
        local t=call(card.health.GetStatusBarTexture,card.health)
        if t and t.SetDesaturated then t:SetDesaturated(false) end
    end
end

local function updateVoice(card,s,unit,connected)
    local guid=call(UnitGUID,unit)
    if not public(guid,"string") then
        local key=card.memberKey
        guid=public(key,"string") and key:match("^guid:(.+)$") or nil
    end
    if not connected or not guid or guid=="" then releaseVoice(s);return end
    if s.voiceGUID==guid then return end
    releaseVoice(s)
    local manager=VoiceActivityManager
    if not manager or type(manager.RegisterFrameForVoiceActivityNotifications)~="function" then return end
    local ok=pcall(manager.RegisterFrameForVoiceActivityNotifications,manager,s.voiceAnchor,guid,nil,
        "VoiceActivityNotificationPartyTemplate","Button",function(owner,notification)
            notification:SetParent(owner);notification:ClearAllPoints()
            notification:SetPoint("CENTER",owner,"CENTER");notification:EnableMouse(false)
            notification:Show()
        end)
    if ok then s.voiceGUID=guid;s.voiceAnchor:SetAlpha(1) end
end

local function updateReady(self,s,unit,connected)
    if self.readyActive then
        local value=call(GetReadyCheckStatus,unit)
        s.readyState=public(value,"string") and READY[value] and value or nil
        s.readyGeneration=self.readyGeneration
    elseif not self.readyFinished then
        -- A reload in an active ready check still needs its current indicator.
        local remaining=call(GetReadyCheckTimeLeft)
        if public(remaining,"number") and remaining>0 then
            local value=call(GetReadyCheckStatus,unit)
            s.readyState=public(value,"string") and READY[value] and value or nil
            s.readyGeneration=self.readyGeneration
        else s.readyState=nil end
    end
    if not connected then s.readyState=nil end
    local alpha=1
    if self.readyFinished then
        local elapsed=now()-self.readyFinished
        local stay=public(DEFAULT_READY_CHECK_STAY_TIME,"number") and DEFAULT_READY_CHECK_STAY_TIME or 10
        -- Finished results belong to members, not reusable party-slot cards.
        -- Clear(card) intentionally keeps this short-lived cache through a
        -- roster rebuild; new checks and world/group cleanup invalidate it.
        if elapsed>=stay+1.5 then
            self.finishedReady={};s.readyState=nil;s.readyGeneration=nil
        else
            local result=s.identity and self.finishedReady[s.identity]
            if result and result.generation==self.readyGeneration then
                s.readyState=connected and result.state or nil
                s.readyGeneration=result.generation
            else s.readyState=nil;s.readyGeneration=nil end
            if elapsed>stay then alpha=1-(elapsed-stay)/1.5 end
        end
    end
    setIcon(s.ready,s.readyState and READY[s.readyState])
    s.ready:SetAlpha(alpha)
end

local function paintHealthWarning(card,s,r,g,b,a)
    card.portrait:SetVertexColor(r,g,b)
    -- The client gates the pulse with opaque alpha. Lua only computes time.
    s.lowHolder:SetAlpha(a)
    s.low:SetAlpha(0.5+0.5*math.abs(math.sin(now()*math.pi*2)))
end

local function paintThreat(self,s,threat)
    if self.threatCurve and (type(threat)=="number" or ns.IsSecret(threat)) then
        pcall(function()
            local r,g,b,a=self.threatCurve:Evaluate(threat):GetRGBA()
            s.threat:SetVertexColor(r,g,b);s.threat:SetAlpha(a)
        end)
    elseif public(threat,"number") and threat>0 then
        local colors={{1,1,0},{1,0.6,0},{1,0,0}}
        local c=colors[threat]
        if c then s.threat:SetVertexColor(unpack(c));s.threat:SetAlpha(1) end
    end
end

local function paintWarnings(self,card,s,unit,connected,dead,ghost,sample)
    s.threat:SetAlpha(0);s.lowHolder:SetAlpha(0)
    card.portrait:SetDesaturated(not connected or card.presenceDim == true)
    if not connected or dead then card.portrait:SetVertexColor(0.35,0.35,0.35);return end
    if ghost then card.portrait:SetVertexColor(0.2,0.2,0.75);return end
    card.portrait:SetVertexColor(1,1,1)
    if sample then
        -- Arithmetic here is only on the addon's explicit public fixture.
        if type(sample.health)=="number" and type(sample.healthMax)=="number" and sample.healthMax>0 then
            local fraction=sample.health/sample.healthMax
            if self.healthCurve then
                pcall(function() paintHealthWarning(card,s,self.healthCurve:Evaluate(fraction):GetRGBA()) end)
            elseif fraction>0 and fraction<=.2 then paintHealthWarning(card,s,1,.05,.05,1) end
        end
        paintThreat(self,s,sample.threat)
        return
    end
    if self.healthCurve and type(UnitHealthPercent)=="function" then
        pcall(function() paintHealthWarning(card,s,UnitHealthPercent(unit,false,self.healthCurve):GetRGBA()) end)
    end
    local enabled=call(IsThreatWarningEnabled)
    if not public(enabled,"boolean") or not enabled then return end
    paintThreat(self,s,call(UnitThreatSituation,unit))
end

-- Live data collection and explicit sample data share the same visual writer.
local function paintBasics(card,s,connected,dead,ghost,leader,guide,pvp)
    s.lines={}
    setIcon(s.leader,leader and (guide and "UI-HUD-UnitFrame-Player-Group-GuideIcon" or "UI-HUD-UnitFrame-Player-Group-LeaderIcon") or nil)
    if leader then s.lines[#s.lines+1]=guide and "Dungeon guide" or "Party leader" end
    local pvpAtlas=pvp=="FFA" and "ui-hud-unitframe-player-pvp-ffaicon"
        or pvp=="Horde" and "ui-hud-unitframe-player-pvp-hordeicon"
        or pvp=="Alliance" and "ui-hud-unitframe-player-pvp-allianceicon" or nil
    setIcon(s.pvp,pvpAtlas)
    if pvpAtlas then s.lines[#s.lines+1]=pvp=="FFA" and "Free-for-all PvP" or "PvP flagged" end
    s.disconnect:SetShown(not connected)
    if card.status then card.status:SetText(not connected and "Offline" or ghost and "Ghost" or dead and "Dead" or "") end
    if card.health and card.health.GetStatusBarTexture then
        local t=call(card.health.GetStatusBarTexture,card.health)
        if t and t.SetDesaturated then t:SetDesaturated(not connected) end
    end
end

local function readyTooltip(s)
    if s.readyState then s.lines[#s.lines+1]=s.readyState=="ready" and "Ready" or s.readyState=="waiting" and "Ready check: waiting" or "Not ready" end
end

function Status:Update(card,unit)
    local s=card.partyStatus
    if not s or card.previewIndex then return false end
    if not public(unit,"string") or not unit:match("^party[1-4]$") or ns.worldActive==false then self:Clear(card);return false end
    local exists=call(UnitExists,unit)
    if not public(exists,"boolean") or not exists then self:Clear(card);return false end
    local identity=public(card.memberKey,"string") and card.memberKey or call(UnitGUID,unit)
    if public(identity,"string") and s.identity and s.identity~=identity then self:Clear(card) end
    s.unit=unit;s.identity=public(identity,"string") and identity or nil;s.lines={}
    local connectedValue=call(UnitIsConnected,unit)
    local connected=true
    if public(connectedValue,"boolean") then connected=connectedValue end
    local deadValue,ghostValue=call(UnitIsDead,unit),call(UnitIsGhost,unit)
    local dead=public(deadValue,"boolean") and deadValue
    local ghost=public(ghostValue,"boolean") and ghostValue
    local leaderValue=call(UnitIsGroupLeader,unit)
    local leader=public(leaderValue,"boolean") and leaderValue
    local guideValue=call(HasLFGRestrictions)
    local guide=public(guideValue,"boolean") and guideValue
    local pvpValue,ffaValue=call(UnitIsPVP,unit),call(UnitIsPVPFreeForAll,unit)
    local pvp=public(pvpValue,"boolean") and pvpValue
    local ffa=public(ffaValue,"boolean") and ffaValue
    local faction=call(UnitFactionGroup,unit)
    local pvpKind=ffa and "FFA" or pvp and public(faction,"string") and faction or nil
    paintBasics(card,s,connected,dead,ghost,leader,guide,pvpKind)
    updateReady(self,s,unit,connected)
    readyTooltip(s)
    paintWarnings(self,card,s,unit,connected,dead,ghost)
    updateVoice(card,s,unit,connected)
    return true
end

function Status:Preview(card,sample)
    if not card.previewIndex then return false end
    if not card.partyStatus and not self:Create(card) then return false end
    local s=card.partyStatus
    sample=sample or {}
    local connected=sample.connected~=false
    local dead,ghost=sample.dead==true,sample.ghost==true
    paintBasics(card,s,connected,dead,ghost,sample.leader==true,sample.guide==true,sample.pvp)
    s.readyState=connected and READY[sample.readyState] and sample.readyState or nil
    setIcon(s.ready,s.readyState and READY[s.readyState]);s.ready:SetAlpha(1)
    readyTooltip(s)
    paintWarnings(self,card,s,nil,connected,dead,ghost,sample)
    s.previewVoice:SetShown(connected and sample.voice==true)
    s.voiceAnchor:SetAlpha(connected and sample.voice==true and 1 or 0)
    return true
end

function Status:OnEvent(event)
    if event=="READY_CHECK" then
        self.readyGeneration=self.readyGeneration+1;self.readyActive=true;self.readyFinished=nil;self.finishedReady={}
    elseif event=="READY_CHECK_FINISHED" then
        self.readyActive=false;self.readyFinished=now()
        for card in pairs(self.cards) do
            local s=card.partyStatus
            if s.readyState=="waiting" then s.readyState="afk" end
            if s.identity and s.readyState and s.readyGeneration==self.readyGeneration then
                self.finishedReady[s.identity]={state=s.readyState,generation=self.readyGeneration}
            end
        end
    elseif event=="GROUP_LEFT" or event=="PLAYER_LEAVING_WORLD" then
        self.readyActive=false;self.readyFinished=nil;self.finishedReady={}
        for card in pairs(self.cards) do self:Clear(card) end
        return
    end
    for card in pairs(self.cards) do
        if not card.previewIndex then self:Update(card,card:GetAttribute("unit")) end
    end
end

function Status:GetTooltipLines(card)
    return card and card.partyStatus and card.partyStatus.lines or {}
end
