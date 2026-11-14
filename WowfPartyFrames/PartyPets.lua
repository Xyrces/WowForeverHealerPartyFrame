local _, ns = ...
local Pets = {bottom=148, pitch=156}
ns.PartyPets = Pets
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local function public(value, kind) return not ns.IsSecret(value) and type(value)==kind end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok then return value end
end
function Pets:WantsSpace()
    local getter=C_CVar and C_CVar.GetCVarBool or GetCVarBool
    local value=call(getter,"showPartyPets")
    return public(value,"boolean") and value
end
local function unitOf(card)
    local unit=card:GetAttribute("unit")
    if public(unit,"string") then
        local index=unit:match("^party([1-4])$")
        if index then return "partypet"..index end
    end
end
local function ownerOffline(card)
    local unit=card:GetAttribute("unit")
    if not public(unit,"string") or not unit:match("^party[1-4]$") then return false end
    local connected=call(UnitIsConnected,unit)
    return public(connected,"boolean") and not connected
end
local function release(state)
    for _,container in ipairs(state and state.containers or {}) do pcall(container.SetEnabled,container,false) end
    if state then state.unit=nil end
end
local function createThreat(state)
    local rim=state.button:CreateTexture(nil,"OVERLAY")
    state.threat=rim
    rim:SetTexture("Interface\\CharacterFrame\\UI-Player-Portrait")
    rim:SetTexCoord(72/256,4/256,2/128,70/128)
    rim:SetSize(20,20);rim:SetPoint("CENTER",state.portrait,"CENTER")
    rim:SetBlendMode("ADD");rim:SetAlpha(0)
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve or not CreateColor or not Enum or not Enum.LuaCurveType then return end
    state.threatCurve=call(function()
        local curve=C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        for _,p in ipairs({{0,1,1,1,0},{1,1,1,0,1},{2,1,.6,0,1},{3,1,0,0,1}}) do
            curve:AddPoint(p[1],CreateColor(p[2],p[3],p[4],p[5]))
        end
        return curve
    end)
end
local function updateThreat(state,unit)
    state.threat:SetAlpha(0)
    local dead,ghost=call(UnitIsDead,unit),call(UnitIsGhost,unit)
    if public(dead,"boolean") and dead or public(ghost,"boolean") and ghost then return end
    local enabled=call(IsThreatWarningEnabled)
    if not public(enabled,"boolean") or not enabled or not state.threatCurve then return end
    local threat=call(UnitThreatSituation,unit)
    if type(threat)=="number" or ns.IsSecret(threat) then
        pcall(function()
            local r,g,b,a=state.threatCurve:Evaluate(threat):GetRGBA()
            state.threat:SetVertexColor(r,g,b);state.threat:SetAlpha(a)
        end)
    end
end
local function createAuras(state)
    if not C_AuraContainerUtil then return end
    state.containers={}
    local ok,reason=pcall(function()
        local styles=assert(Enum and Enum.CustomAuraButtonDispelTypeTextureStyle,"Native aura border styles unavailable")
        for index=1,2 do
        local container=CreateFrame("AuraContainer",nil,state.button,"CustomAuraContainerTemplate")
        state.containers[index]=container
        if index==1 then state.container=container end
        container:SetEnabled(false); container:EnableMouse(false)
        container:SetPoint("TOPLEFT",state.button,"TOPLEFT",115, -2)
        container:SetFlowLayoutMaximumLineSize(59)
        container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura,{
            ignoreBuffs=true,ignoreDebuffs=false,ignoreDispelDebuffs=false,
            displayOnlyDispellableDebuffs=index==2})
        -- The native portrait pet frame displays four harmful effects by
        -- default, not the member's assigned reapplication buttons.
        container:AddAuraGroup("petDebuffs","HARMFUL",{
            maxFrameCount=4,
            sortMethod=AuraContainerSortMethod.UnitFrameDebuff,
            layout={elementWidth=14,elementHeight=14,elementSpacing=1,lineSpacing=0},
            initializeFrame=function(button)
                button:SetSize(14,14)
                button:SetMouseClickEnabled(false); button:SetMouseMotionEnabled(true)
                button:SetHideTooltipInCombat(false)
                local icon=button:CreateTexture(nil,"ARTWORK")
                icon:SetAllPoints(button); icon:SetTexCoord(.07,.93,.07,.93)
                button:SetIcon(icon)
                local border=button:CreateTexture(nil,"OVERLAY")
                border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
                border:SetTexCoord(.296875,.5703125,0,.515625);border:SetAllPoints(button)
                button:AddDispelTypeTexture(border,{showWhenHarmful=true,showWhenHelpful=false,
                    showWithoutDispelType=true,style=styles.PreserveAsset})
                local cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
                cooldown:SetAllPoints(button); cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false)
                cooldown:SetHideCountdownNumbers(true); cooldown:EnableMouse(false)
                button:SetDurationCooldown(cooldown)
                local overlay=CreateFrame("Frame",nil,button)
                overlay:SetAllPoints(button); overlay:SetFrameLevel(cooldown:GetFrameLevel()+2)
                overlay:EnableMouse(false)
                local timer=overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                timer:SetFont(FONT,7,"OUTLINE"); timer:SetPoint("BOTTOM",button,"BOTTOM",0,-1)
                button:SetDurationText(timer)
                local count=overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                count:SetFont(FONT,7,"OUTLINE"); count:SetPoint("TOPRIGHT",button,"TOPRIGHT",0,0)
                button:SetApplicationCount(count)
            end,
        })
        end
    end)
    if not ok then
        release(state)
        for _,container in ipairs(state.containers) do pcall(container.Hide,container) end
        state.auraReason="Pet auras unavailable: "..tostring(reason)
        state.container=nil
    end
end
function Pets:Create(card)
    if card.partyPet then return card.partyPet.supported end
    if ns.InCombat() or card.previewIndex then return false end
    local state={supported=false,enabled=false}
    card.partyPet=state
    if type(RegisterUnitWatch)~="function" or type(UnregisterUnitWatch)~="function" then
        state.reason="Native pet unit watching is unavailable."; return false
    end
    local ok,reason=pcall(function()
        local button=CreateFrame("Button",nil,card,"SecureActionButtonTemplate")
        state.button=button
        button:Hide(); button:SetSize(174,18)
        button:SetPoint("TOPLEFT",card,"TOPLEFT",5,-130)
        button:SetAttribute("useparent-unit",true); button:SetAttribute("unitsuffix","pet")
        button:SetAttribute("type1","target"); button:SetAttribute("*type1","target")
        button:SetAttribute("type2","togglemenu"); button:SetAttribute("*type2","togglemenu")
        button:SetAttribute("useOnKeyDown",false)
        button:SetAttribute("checkselfcast",false); button:SetAttribute("checkfocuscast",false)
        button:SetAttribute("checkmouseovercast",false)
        button:RegisterForClicks("AnyUp"); button:EnableMouse(true)
        state.portrait=button:CreateTexture(nil,"ARTWORK")
        state.portrait:SetPoint("TOPLEFT",0,0); state.portrait:SetSize(18,18)
        local mask=button:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(state.portrait); state.portrait:AddMaskTexture(mask)
        createThreat(state)
        local health=CreateFrame("StatusBar",nil,button)
        state.health=health
        health:EnableMouse(false); health:SetSize(91,14); health:SetPoint("TOPLEFT",button,"TOPLEFT",21,-2)
        health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        health:SetStatusBarColor(.1,.65,.16)
        local background=health:CreateTexture(nil,"BACKGROUND")
        background:SetAllPoints(health); background:SetColorTexture(.025,.03,.025,.95)
        state.text=health:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        state.text:SetFont(FONT,8,"OUTLINE"); state.text:SetPoint("CENTER",health,"CENTER")
        local function refreshTooltip(self)
            local unit=unitOf(card)
            if ownerOffline(card) then
                GameTooltip:SetText("Owner offline")
                GameTooltip:AddLine("Pet information is unavailable until the owner reconnects.",.8,.8,.8,true)
            else
                local hasTooltip=unit and call(GameTooltip.SetUnit,GameTooltip,unit)
                if not public(hasTooltip,"boolean") or not hasTooltip then
                    local name=unit and call(UnitName,unit)
                    GameTooltip:SetText(public(name,"string") and name or "Pet")
                end
            end
            GameTooltip:Show()
        end
        local function clearTooltip(self)
            self.UpdateTooltip=nil
            if GameTooltip:GetOwner()==self then GameTooltip:Hide() end
        end
        button:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            -- The native tooltip update loop re-resolves the parent's secure
            -- unit after combat roster changes, without another mouse enter.
            self.UpdateTooltip=refreshTooltip
            refreshTooltip(self)
        end)
        button:SetScript("OnLeave",clearTooltip)
        button:SetScript("OnHide",clearTooltip)
        createAuras(state)
    end)
    if not ok then
        release(state)
        if state.button then pcall(UnregisterUnitWatch,state.button); state.button:Hide() end
        state.reason="Pet frame setup failed: "..tostring(reason)
        return false
    end
    state.supported=true
    return self:Configure(card)
end
function Pets:Configure(card)
    if ns.InCombat() then return false end
    local state=card.partyPet
    if not state then return self:Create(card) end
    if not state.supported then return false end
    state.requested=self:WantsSpace()
    state.ownerOffline=ownerOffline(card)
    local enabled=state.requested and not state.ownerOffline
    if enabled~=state.enabled then
        if enabled then
            -- Blizzard's watcher calls SecureButton_GetUnit, including the
            -- parent-unit inheritance and party1pet -> partypet1 conversion.
            -- It follows combat reorders and pet summons without addon writes.
            RegisterUnitWatch(state.button)
        else
            UnregisterUnitWatch(state.button); state.button:Hide(); release(state)
        end
        state.enabled=enabled
    end
    return true
end
function Pets:Update(card)
    local state=card.partyPet
    if not state or not state.supported then return false end
    -- Also revisit disabled rows, so reconnecting owners regain native pet
    -- watching without requiring a separate settings/roster event.
    if not ns.InCombat() then self:Configure(card) end
    if not state.enabled then return false end
    state.ownerOffline=ownerOffline(card)
    if state.ownerOffline then
        -- Unit watching only knows pet existence, not owner connectivity.
        -- In combat it remains the sole visibility authority. Leave a visibly
        -- grey, labelled target rather than stale HP or an invisible hit area.
        self:Clear(card)
        state.text:SetText("Owner offline")
        state.portrait:SetDesaturated(true)
        return false
    end
    local unit=unitOf(card)
    local exists=unit and call(UnitExists,unit)
    if not unit or not public(exists,"boolean") or not exists or ns.worldActive==false then
        self:Clear(card); return false
    end
    local hp,maximum=call(UnitHealth,unit,false),call(UnitHealthMax,unit)
    -- Native setters consume opaque numeric health values directly.
    if type(hp)=="number" and type(maximum)=="number" then
        state.health:SetMinMaxValues(0,maximum); state.health:SetValue(hp)
        state.text:SetFormattedText("%d / %d",hp,maximum)
    else
        state.health:SetMinMaxValues(0,1); state.health:SetValue(0); state.text:SetText("")
    end
    SetPortraitTexture(state.portrait,unit)
    local connected=call(UnitIsConnected,unit)
    state.portrait:SetDesaturated(public(connected,"boolean") and not connected or false)
    updateThreat(state,unit)
    if state.container then
        local getter=C_CVar and C_CVar.GetCVarBool or GetCVarBool
        local onlyDispel=call(getter,"showDispelDebuffs")
        local assist=call(UnitCanAssist,"player",unit)
        local index=public(onlyDispel,"boolean") and onlyDispel and public(assist,"boolean") and assist and 2 or 1
        if state.container~=state.containers[index] then release(state);state.container=state.containers[index] end
    end
    if state.container and state.unit~=unit then
        release(state)
        local ok=pcall(function()
            state.container:SetUnit(unit); state.container:SetEnabled(true)
        end)
        if ok then state.unit=unit else release(state) end
    end
    return true
end
function Pets:Clear(card)
    local state=card and card.partyPet
    release(state)
    if state and state.threat then state.threat:SetAlpha(0) end
    if state and state.health then
        state.health:SetMinMaxValues(0,1); state.health:SetValue(0); state.text:SetText("")
    end
end
function Pets:GetStatus(card)
    local state=card and card.partyPet
    if not state or not state.supported then return state and state.reason or "unavailable." end
    if state.requested and state.ownerOffline then
        return state.enabled and "owner offline; stale pet data cleared, row hides after combat."
            or "owner offline; pet row hidden."
    end
    if not state.enabled then return "disabled by the native Show Party Pets setting." end
    return state.auraReason or (state.container and "native pet targeting, health and debuffs." or "pet targeting and health; native aura display unavailable.")
end
