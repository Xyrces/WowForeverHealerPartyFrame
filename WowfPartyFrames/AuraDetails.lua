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
local function initializeIcon(button)
    button:SetSize(SIZE,SIZE)
    button:SetMouseClickEnabled(false)
    button:SetMouseMotionEnabled(true)
    button:SetHideTooltipInCombat(false)
    if button.SetTooltipAnchorPoint then button:SetTooltipAnchorPoint("ANCHOR_RIGHT") end
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(button); icon:SetTexCoord(0.07,0.93,0.07,0.93)
    button:SetIcon(icon)
    local cooldown = CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
    cooldown:SetAllPoints(button); cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false); cooldown:SetHideCountdownNumbers(true)
    button:SetDurationCooldown(cooldown)
    local overlay = CreateFrame("Frame",nil,button)
    overlay:SetAllPoints(button); overlay:SetFrameLevel(cooldown:GetFrameLevel()+2)
    overlay:EnableMouse(false)
    -- Native code chooses the dispel border atlas and visibility, including
    -- the None border for physical effects. No aura values enter addon Lua.
    local border = overlay:CreateTexture(nil,"OVERLAY")
    border:SetAllPoints(button)
    button:AddDispelTypeTexture(border,{showWhenHarmful=true,showWhenHelpful=false,
        showWithoutDispelType=true,style=Enum.CustomAuraButtonDispelTypeTextureStyle.Border})
    local timer = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    timer:SetFont(FONT,8,"OUTLINE"); timer:SetPoint("BOTTOM",0,-1)
    button:SetDurationText(timer)
    local count = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    count:SetFont(FONT,8,"OUTLINE"); count:SetPoint("TOPRIGHT",0,0)
    button:SetApplicationCount(count)
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
    if self.panelState then
        self.panelState.frame:Hide()
        disableViews(self.panelState)
    end
    self.card, self.unit, self.leaveAt = nil, nil, nil
end

local function createPanel()
    if Details.panelState then return Details.panelState.supported end
    local state = {views={},supported=false}
    Details.panelState = state
    local panel = CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    state.frame = panel
    panel:Hide(); panel:SetSize(WIDTH,138); panel:SetFrameStrata("TOOLTIP")
    panel:SetClampedToScreen(true)
    panel:SetMouseClickEnabled(false); panel:SetMouseMotionEnabled(true)
    if ns.SetBackdrop then ns.SetBackdrop(panel,{0.025,0.025,0.025,0.96},{0.45,0.4,0.28,1}) end
    label(panel,"Auras",12,-10)
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
            view.container = nativeContainer(holder)
            if index==2 then prepareDebuffOrder(view.container,false) end
            view.container:SetFlowLayoutMaximumLineSize(WIDTH-24)
            view.container:AddAuraGroup("details",filter,{maxFrameCount=index==1 and 16 or 8,
                sortMethod=index==2 and AuraContainerSortMethod.UnitFrameDebuff or AuraContainerSortMethod.Default,
                initializeFrame=initializeIcon,
                layout={elementWidth=SIZE,elementHeight=SIZE,elementSpacing=GAP,lineSpacing=GAP}})
        end
    end)
    if not ok then disableViews(state);state.reason=tostring(reason);return false end
    state.supported = true
    panel:SetScript("OnUpdate",function(_,elapsed)
        local card = Details.card
        if not card then return end
        if not validUnit(Details.unit) or call(card.IsVisible,card) ~= true then Details:Hide();return end
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
    if not styles or not card.portraitArea then return false end
    local ok,reason = pcall(function()
        -- Both processing policies are prepared OOC. The public native CVar chooses
        -- which display is enabled, without reading any aura in addon code.
        for index=1,2 do
            local holder = CreateFrame("Frame",nil,card)
            holder:SetSize((ns.Layout and ns.Layout.portrait or 82)+6,(ns.Layout and ns.Layout.portrait or 82)+6)
            holder:SetPoint("CENTER",card.portraitArea,"CENTER")
            holder:SetFrameLevel(card.portraitArea:GetFrameLevel()+1)
            holder:EnableMouse(false); holder:Hide()
            local view = {holder=holder}
            state.views[#state.views+1] = view
            view.container = nativeContainer(holder)
            prepareDebuffOrder(view.container,index==2)
            local initialized = false
            view.container:AddAuraSlot("border","HARMFUL",{
                sortMethod=AuraContainerSortMethod.UnitFrameDebuff,
                initializeFrame=function(button)
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
                    button:AddDispelTypeTexture(rim,{showWhenHarmful=true,showWhenHelpful=false,
                        showWithoutDispelType=true,style=styles.PreserveAsset})
                    initialized = true
                end})
            assert(initialized,"Native harmful border initialization did not complete")
        end
    end)
    if not ok then disableViews(state);state.reason=tostring(reason);return false end
    state.supported = true
    return true
end

function Details:Create(card)
    if ns.InCombat() or card.previewIndex then return false end
    if not C_AuraContainerUtil then return false end
    local panel = createPanel()
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

function Details:Show(card,unit)
    if card.previewIndex or not validUnit(unit) then self:Hide();return false end
    if not self.panelState or not self.panelState.supported then return false end
    if not bindPanel(unit) then self:Hide();return false end
    local panel = self.panelState.frame
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
