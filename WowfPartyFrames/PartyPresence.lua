local _, ns = ...
local Presence = {pendingTransfer=false,initialized=false}
ns.PartyPresence = Presence
local function public(value,kind) return not ns.IsSecret(value) and type(value)==kind end
local function remaining()
    if type(GetEvictionTimeRemaining)~="function" then return nil end
    local ok,value=pcall(GetEvictionTimeRemaining)
    if ok and public(value,"number") and value==value and value<math.huge then return value end
end
function Presence:OnEvent(event)
    if event=="SHARD_TRANSFER_IMMINENT" then self.pendingTransfer=true;self.initialized=true
    elseif event=="SHARD_TRANSFER_CANCELLED" or event=="SHARD_TRANSFER"
        or event=="PLAYER_LEAVING_WORLD" then
        self.pendingTransfer=false;self.initialized=true
        if self.openedPopup and type(StaticPopup_Hide)=="function" then StaticPopup_Hide(self.openedPopup) end
        self.openedPopup=nil
    elseif event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LOGIN" then
        local seconds=remaining()
        self.pendingTransfer=seconds~=nil and seconds>0
        self.initialized=true
    end
end
function Presence:CanConfirmTransfer()
    -- Recover an already pending transfer once at startup. A terminal event
    -- wins over a stale positive countdown until the next native request.
    if not self.initialized then
        local seconds=remaining()
        self.pendingTransfer=seconds~=nil and seconds>0
        self.initialized=true
    end
    return self.pendingTransfer and type(StaticPopup_Show)=="function"
        and C_PlayerInteractionManager and type(C_PlayerInteractionManager.ShardTransferConfirm)=="function" or false
end
function Presence:ConfirmTransfer()
    if not self:CanConfirmTransfer() then return false end
    if ns.InCombat() then return false end
    if type(UnitAffectingCombat)=="function" then
        local value=UnitAffectingCombat("player")
        if not public(value,"boolean") or value then return false end
    end
    -- Open the client's own confirmation. It chooses the destination; this
    -- API cannot request an arbitrary member's shard and takes no unit token.
    local seconds=remaining()
    self.openedPopup=seconds and seconds>0 and "SHARD_TRANSFER_IMMINENT_EVENT" or "SHARD_TRANSFER_IMMEDIATE"
    StaticPopup_Show(self.openedPopup)
    return true
end
local function unitOf(card)
    local unit=card:GetAttribute("unit")
    return public(unit,"string") and unit:match("^party[1-4]$") and unit or nil
end
function Presence:Create(card)
    if card.presenceButton or ns.InCombat() or card.previewIndex then return end
    local button=CreateFrame("Button",nil,card)
    card.presenceButton=button
    button:Hide(); button:SetSize(14,14)
    button:SetPoint("BOTTOMLEFT",card.portraitArea,"TOPLEFT",18,2)
    button:SetFrameLevel(card.portraitArea:GetFrameLevel()+6)
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints(button)
    button:SetScript("OnEnter",function(self)
        local unit=unitOf(card)
        local info=unit and ns.MemberInfo:Get(unit,card.presetID)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        if info then
            GameTooltip:SetText(info.presenceText or "Party member")
            GameTooltip:AddLine(info.presenceTooltip or "",.85,.85,.85,true)
            if info.differentShard and Presence:CanConfirmTransfer() then
                GameTooltip:AddLine("Click to confirm your pending shard transfer.",1,.82,0,true)
                GameTooltip:AddLine("Uses the destination already offered by the server.",.8,.8,.8,true)
                if ns.InCombat() then GameTooltip:AddLine("Available after combat.",1,.4,.3) end
            else GameTooltip:AddLine("Click for party actions.",.8,.8,.8,true) end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnClick",function(_,mouse)
        local unit=unitOf(card)
        if not unit then return end
        local info=ns.MemberInfo:Get(unit,card.presetID)
        if mouse=="LeftButton" and info.differentShard and Presence:CanConfirmTransfer() then
            Presence:ConfirmTransfer()
        elseif type(UnitPopup_OpenMenu)=="function" then
            UnitPopup_OpenMenu("PARTY",{unit=unit,ownerFrame=card})
        end
    end)
end
function Presence:Update(card,info)
    local button=card.presenceButton
    if button then
        if info.presenceAtlas then button.icon:SetAtlas(info.presenceAtlas); button.icon:SetTexCoord(0,1,0,1)
        elseif info.presenceTexture then
            button.icon:SetTexture(info.presenceTexture)
            button.icon:SetTexCoord(unpack(info.presenceTexCoord or {0,1,0,1}))
        end
        button:SetShown(info.presenceKind~=nil)
    end
    -- Fade only the portrait, preserving the legibility of healing controls.
    card.presenceDim=info.presenceDim and true or false
    card.portrait:SetDesaturated(card.presenceDim)
    local label=info.presenceText or ""
    if info.location then label=label~="" and (label.." · "..info.location) or info.location end
    card.location:SetText(label)
    card.location:SetTextColor(info.presenceKind and 1 or .7,info.presenceKind and .78 or .77,info.presenceKind and .4 or .85)
end
function Presence:Clear(card)
    if card.presenceButton then card.presenceButton:Hide() end
    card.presenceDim=false
end
