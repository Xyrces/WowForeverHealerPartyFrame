local _, ns = ...
local Details = {}
ns.AuraDetails = Details
local SIZE, GAP, COLUMNS = 22, 2, 8
local WIDTH = COLUMNS * (SIZE + GAP) - GAP + 24
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local function public(value, kind)
    return not ns.IsSecret(value) and type(value) == kind
end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function validUnit(unit)
    if not public(unit,"string") or not unit:match("^party[1-4]$") or ns.worldActive == false then return false end
    local exists = call(UnitExists,unit)
    return public(exists,"boolean") and exists
end
local function label(parent,text,x,y)
    local font = parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font:SetFont(FONT,10,"OUTLINE"); font:SetPoint("TOPLEFT",x,y)
    font:SetWidth(WIDTH-24); font:SetJustifyH("LEFT"); font:SetWordWrap(false)
    font:SetText(text)
    return font
end
local function sampleColor(kind)
    local fallback={Magic={r=.2,g=.6,b=1},Curse={r=.6,g=0,b=1},Disease={r=.6,g=.4,b=0},Poison={r=0,g=.6,b=0},none={r=.8,g=0,b=0}}
    return DebuffTypeColor and (DebuffTypeColor[kind or "none"] or DebuffTypeColor.none) or fallback[kind or "none"] or fallback.none
end
local function sampleTooltip(button)
    local aura=button.sampleAura
    if not aura then return end
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    GameTooltip:SetText(aura.name or "Sample aura")
    if aura.description then GameTooltip:AddLine(aura.description,.85,.85,.85,true) end
    GameTooltip:AddLine("Sample data - preview only.",1,.82,0,true)
    GameTooltip:Show()
end
local function clearSampleTooltip(button)
    if GameTooltip.GetOwner and GameTooltip:GetOwner()==button then GameTooltip:Hide() end
end
local function initializeIcon(button,preview)
    button:SetSize(SIZE,SIZE)
    button:SetMouseClickEnabled(false)
    button:SetMouseMotionEnabled(true)
    if not preview then button:SetHideTooltipInCombat(false) end
    if button.SetTooltipAnchorPoint then button:SetTooltipAnchorPoint("ANCHOR_RIGHT") end
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(button); icon:SetTexCoord(0.07,0.93,0.07,0.93)
    if not preview then button:SetIcon(icon) end
    local cooldown = CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
    cooldown:SetAllPoints(button); cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false); cooldown:SetHideCountdownNumbers(true)
    if not preview then button:SetDurationCooldown(cooldown) end
    local overlay = CreateFrame("Frame",nil,button)
    overlay:SetAllPoints(button); overlay:SetFrameLevel(cooldown:GetFrameLevel()+2)
    overlay:EnableMouse(false)
    -- Native code chooses the dispel border atlas and visibility, including
    -- the None border for physical effects. No aura values enter addon Lua.
    local border = overlay:CreateTexture(nil,"OVERLAY")
    border:SetAllPoints(button)
    if not preview then
        button:AddDispelTypeTexture(border,{showWhenHarmful=true,showWhenHelpful=false,
            showWithoutDispelType=true,style=Enum.CustomAuraButtonDispelTypeTextureStyle.Border})
    else
        border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        border:SetTexCoord(.296875,.5703125,0,.515625)
    end
    local timer = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    timer:SetFont(FONT,8,"OUTLINE"); timer:SetPoint("BOTTOM",0,-1)
    if not preview then button:SetDurationText(timer) end
    local count = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    count:SetFont(FONT,8,"OUTLINE"); count:SetPoint("TOPRIGHT",0,0)
    if not preview then button:SetApplicationCount(count) end
    if preview then
        button.sampleIcon,button.sampleBorder,button.sampleTimer,button.sampleCount=icon,border,timer,count
        button:SetScript("OnEnter",sampleTooltip)
        button:SetScript("OnLeave",clearSampleTooltip)
        button:SetScript("OnHide",clearSampleTooltip)
    end
end
local function paintSample(button,aura,harmful)
    button.sampleAura=aura
    button:SetShown(aura~=nil)
    if not aura then return end
    button.sampleIcon:SetTexture(aura.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.sampleTimer:SetText(aura.durationText or "")
    button.sampleCount:SetText(aura.stacks and aura.stacks>1 and tostring(aura.stacks) or "")
    button.sampleBorder:SetShown(harmful==true)
    if harmful then
        local c=sampleColor(aura.dispelType)
        button.sampleBorder:SetVertexColor(c.r,c.g,c.b)
    end
end
local function disableViews(state)
    local ok = true
    for _,view in ipairs(state.views) do
        if view.holder then view.holder:Hide() end
        if view.container and not pcall(view.container.SetEnabled,view.container,false) then ok = false end
    end
    state.unit, state.filter = nil, nil
    return ok
end
local function nativeContainer(holder)
    local container = CreateFrame("AuraContainer",nil,holder,"CustomAuraContainerTemplate")
    container:SetEnabled(false); container:EnableMouse(false)
    container:SetPoint("TOPLEFT",holder,"TOPLEFT",0,0)
    return container
end
local function prepareDebuffOrder(container,dispellableOnly)
    -- Classification and comparison run inside the native aura environment;
    -- UnitFrameDebuff requires the debuffType metadata supplied by ProcessAura.
    container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura,{
        ignoreBuffs=true,ignoreDebuffs=false,ignoreDispelDebuffs=false,
        displayOnlyDispellableDebuffs=dispellableOnly or false})
end

function Details:Hide()
    for _,state in pairs({live=self.panelState,preview=self.previewPanelState}) do
        state.frame:Hide()
        disableViews(state)
    end
    self.card, self.unit, self.leaveAt = nil, nil, nil
end

local function createPanel(preview)
    local key=preview and "previewPanelState" or "panelState"
    if Details[key] then return Details[key].supported end
    local state = {views={},supported=false,preview=preview}
    Details[key] = state
    local panel = CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    state.frame = panel
    panel:Hide(); panel:SetSize(WIDTH,138); panel:SetFrameStrata("TOOLTIP")
    panel:SetClampedToScreen(true)
    -- Sample panels consume clicks inside their visible bounds so inspecting a
    -- fixture cannot target the world underneath. Native panels keep their
    -- existing click-through behavior; neither panel installs casting actions.
    panel:SetMouseClickEnabled(preview==true); panel:SetMouseMotionEnabled(true)
    if ns.SetBackdrop then ns.SetBackdrop(panel,{0.025,0.025,0.025,0.96},{0.45,0.4,0.28,1}) end
    label(panel,preview and "Sample auras" or "Auras",12,-10)
    label(panel,"Buffs",12,-30)
    label(panel,"Debuffs",12,-96)
    local ok,reason = pcall(function()
        for index,filter in ipairs({"HELPFUL","HARMFUL"}) do
            local holder = CreateFrame("Frame",nil,panel)
            holder:SetPoint("TOPLEFT",panel,"TOPLEFT",12,index==1 and -46 or -112)
            holder:SetSize(WIDTH-24,index==1 and SIZE*2+GAP or SIZE)
            holder:EnableMouse(false); holder:Hide()
            local view = {holder=holder}
            state.views[#state.views+1] = view
            if preview then
                view.icons={}
                for slot=1,index==1 and 16 or 8 do
                    local button=CreateFrame("Button",nil,holder)
                    button:SetPoint("TOPLEFT",holder,"TOPLEFT",(slot-1)%COLUMNS*(SIZE+GAP),-math.floor((slot-1)/COLUMNS)*(SIZE+GAP))
                    initializeIcon(button,true);button:Hide();view.icons[slot]=button
                end
            else
                view.container = nativeContainer(holder)
                if index==2 then prepareDebuffOrder(view.container,false) end
                view.container:SetFlowLayoutMaximumLineSize(WIDTH-24)
                view.container:AddAuraGroup("details",filter,{maxFrameCount=index==1 and 16 or 8,
                    sortMethod=index==2 and AuraContainerSortMethod.UnitFrameDebuff or AuraContainerSortMethod.Default,
                    initializeFrame=function(button) initializeIcon(button,false) end,
                    layout={elementWidth=SIZE,elementHeight=SIZE,elementSpacing=GAP,lineSpacing=GAP}})
            end
        end
    end)
    if not ok then disableViews(state);state.reason=tostring(reason);return false end
    state.supported = true
    panel:SetScript("OnUpdate",function(_,elapsed)
        local card = Details.card
        if not card then return end
        if (not card.previewIndex and not validUnit(Details.unit)) or ns.worldActive==false or call(card.IsVisible,card) ~= true then Details:Hide();return end
        -- The plain panel's bounds include its native children. Never inspect
        -- an AuraButton's visibility or secret aura state to keep it open.
        local overCard,overPanel = call(card.IsMouseOver,card),call(panel.IsMouseOver,panel)
        if public(overCard,"boolean") and overCard or public(overPanel,"boolean") and overPanel then
            Details.leaveAt = nil
        else
            Details.leaveAt = (Details.leaveAt or 0) + elapsed
            if Details.leaveAt >= 0.25 then Details:Hide() end
        end
    end)
    return true
end

local function createBorder(card)
    if card.auraDetailsBorder then return card.auraDetailsBorder.supported end
    local state = {views={},supported=false}
    card.auraDetailsBorder = state
    local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    if (not styles and not card.previewIndex) or not card.portraitArea then return false end
    local ok,reason = pcall(function()
        -- Both processing policies are prepared OOC. The public native CVar chooses
        -- which display is enabled, without reading any aura in addon code.
        for index=1,card.previewIndex and 1 or 2 do
            local holder = CreateFrame("Frame",nil,card)
            holder:SetSize((ns.Layout and ns.Layout.portrait or 82)+6,(ns.Layout and ns.Layout.portrait or 82)+6)
            holder:SetPoint("CENTER",card.portraitArea,"CENTER")
            holder:SetFrameLevel(card.portraitArea:GetFrameLevel()+1)
            holder:EnableMouse(false); holder:Hide()
            local view = {holder=holder}
            state.views[#state.views+1] = view
            local initialized = false
            local function initializeBorder(button)
                button:SetAllPoints(holder); button:EnableMouse(false)
                button:SetFrameLevel(holder:GetFrameLevel())
                local rim = button:CreateTexture(nil,"OVERLAY")
                rim:SetAllPoints(button)
                rim:SetTexture("Interface\\CharacterFrame\\UI-Player-Portrait")
                rim:SetTexCoord(72/256,4/256,2/128,70/128)
                rim:SetBlendMode("ADD")
                local mask = button:CreateMaskTexture()
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(button);rim:AddMaskTexture(mask)
                if card.previewIndex then view.rim=rim
                else button:AddDispelTypeTexture(rim,{showWhenHarmful=true,showWhenHelpful=false,
                    showWithoutDispelType=true,style=styles.PreserveAsset}) end
                initialized = true
            end
            if card.previewIndex then initializeBorder(CreateFrame("Frame",nil,holder))
            else
                view.container = nativeContainer(holder)
                prepareDebuffOrder(view.container,index==2)
                view.container:AddAuraSlot("border","HARMFUL",{
                    sortMethod=AuraContainerSortMethod.UnitFrameDebuff,initializeFrame=initializeBorder})
            end
            assert(initialized,"Native harmful border initialization did not complete")
        end
    end)
    if not ok then disableViews(state);state.reason=tostring(reason);return false end
    state.supported = true
    return true
end

function Details:Create(card)
    if ns.InCombat() then return false end
    if not card.previewIndex and not C_AuraContainerUtil then return false end
    local panel = createPanel(card.previewIndex~=nil)
    createBorder(card)
    return panel
end

local function bindPanel(unit)
    local state = Details.panelState
    if not state or not state.supported then return false end
    if state.unit == unit then return true end
    if not disableViews(state) then return false end
    local ok,reason = pcall(function()
        for _,view in ipairs(state.views) do view.container:SetUnit(unit) end
        for _,view in ipairs(state.views) do view.container:SetEnabled(true) end
    end)
    if not ok then disableViews(state);state.reason=tostring(reason);return false end
    state.unit,state.reason = unit,nil
    for _,view in ipairs(state.views) do view.holder:Show() end
    return true
end

function Details:Preview(card,auras)
    if not card.previewIndex then return false end
    card.previewAuras=auras or {helpful={},harmful={}}
    if not card.auraDetailsBorder and not self:Create(card) then return false end
    local state=card.auraDetailsBorder
    if state and state.supported then
        local aura=card.previewAuras.harmful and card.previewAuras.harmful[1]
        local view=state.views[1]
        view.holder:SetShown(aura~=nil)
        if aura then local c=sampleColor(aura.dispelType);view.rim:SetVertexColor(c.r,c.g,c.b) end
    end
    return true
end
function Details:Show(card,unit)
    local preview=card.previewIndex~=nil
    if not preview and not validUnit(unit) then self:Hide();return false end
    local state=preview and self.previewPanelState or self.panelState
    if not state or not state.supported then return false end
    if preview then
        local auras=card.previewAuras or {}
        for index,view in ipairs(state.views) do
            local list=auras[index==1 and "helpful" or "harmful"] or {}
            for slot,button in ipairs(view.icons) do paintSample(button,list[slot],index==2) end
            view.holder:Show()
        end
        if self.panelState then self.panelState.frame:Hide();disableViews(self.panelState) end
        unit=nil
    else
        if self.previewPanelState then self.previewPanelState.frame:Hide();disableViews(self.previewPanelState) end
        if not bindPanel(unit) then self:Hide();return false end
    end
    local panel = state.frame
    -- Snapshot the body's tooltip position. Anchoring to GameTooltip itself
    -- would make this panel jump when a native aura takes over that tooltip.
    local scale = call(card.GetEffectiveScale,card) or 1
    local parentScale = call(UIParent.GetEffectiveScale,UIParent) or 1
    panel:SetScale(scale/parentScale)
    local tooltipScale = GameTooltip and call(GameTooltip.GetEffectiveScale,GameTooltip) or scale
    local left = GameTooltip and call(GameTooltip.GetLeft,GameTooltip)
    local bottom = GameTooltip and call(GameTooltip.GetBottom,GameTooltip)
    local top = GameTooltip and call(GameTooltip.GetTop,GameTooltip)
    local tooltipVisible = GameTooltip and call(GameTooltip.IsShown,GameTooltip)
    local x,y
    if tooltipVisible == true and public(left,"number") and public(bottom,"number") then
        x,y = left*tooltipScale/scale, bottom*tooltipScale/scale-6
    else
        x,y = (call(card.GetRight,card) or 0)+10,(call(card.GetTop,card) or 0)
    end
    local screenWidth = UIParent:GetWidth()*parentScale/scale
    local screenHeight = UIParent:GetHeight()*parentScale/scale
    x = math.max(0,math.min(x,math.max(0,screenWidth-WIDTH)))
    if y < panel:GetHeight() then y = math.min(screenHeight,(public(top,"number") and top*tooltipScale/scale or y)+panel:GetHeight()+6) end
    y = math.min(screenHeight,math.max(panel:GetHeight(),y))
    panel:ClearAllPoints();panel:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
    self.card,self.unit,self.leaveAt = card,unit,nil
    panel:Show()
    return true
end

function Details:Update(card,unit)
    if card.previewIndex then
        if self.card==card and (ns.worldActive==false or call(card.IsVisible,card)~=true) then self:Hide() end
        return self:Preview(card,card.previewAuras)
    end
    local state = card.auraDetailsBorder
    local valid = validUnit(unit)
    if state and state.supported then
        if not valid then disableViews(state)
        else
            local dispellable = call(GetCVarBool,"showDispelDebuffs")
            local assistable = call(UnitCanAssist,"player",unit)
            local filter = public(dispellable,"boolean") and dispellable
                and public(assistable,"boolean") and assistable and 2 or 1
            if state.unit ~= unit or state.filter ~= filter then
                local released = disableViews(state)
                local view = state.views[filter]
                local ok = released and pcall(function()
                    view.container:SetUnit(unit);view.container:SetEnabled(true)
                end)
                if ok then state.unit,state.filter=unit,filter;view.holder:Show()
                else disableViews(state) end
            end
        end
    end
    if self.card == card then
        if not valid or call(card.IsVisible,card) ~= true or not bindPanel(unit) then self:Hide()
        else self.unit=unit end
    end
end

function Details:Clear(card)
    if card and card.auraDetailsBorder then disableViews(card.auraDetailsBorder) end
    if not card or self.card == card then self:Hide() end
end
