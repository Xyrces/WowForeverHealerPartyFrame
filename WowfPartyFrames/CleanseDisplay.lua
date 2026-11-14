local _, ns = ...
local Display = {}
ns.CleanseDisplay = Display
local COUNT, ICON = 4, 18
local TYPES = {"Magic", "Disease", "Poison", "Curse"}
local COLORS = {Magic={0.45,0.78,1}, Disease={0.84,0.65,0.36}, Poison={0.3,0.9,0.35}, Curse={0.75,0.45,1}}
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function names(types)
    local result = {}
    for _, kind in ipairs(TYPES) do if types[kind] then result[#result + 1] = kind end end
    return table.concat(result, "/")
end
local function style()
    return ns.db and ns.db.controlStyle == "quadrants" and "quadrants" or "buttons"
end
local function texture(parent, layer)
    local region = parent:CreateTexture(nil, layer)
    region:SetAllPoints(parent)
    return region
end
local function icon(parent, relative)
    local region = parent:CreateTexture(nil,"ARTWORK")
    region:SetAllPoints(relative)
    region:SetTexCoord(0.07,0.93,0.07,0.93)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(relative)
    region:AddMaskTexture(mask)
    return region
end
local function tooltip(self)
    local slot = self.cleanseSlot
    GameTooltip:SetOwner(slot.iconAnchor,"ANCHOR_RIGHT")
    if slot.spellID then GameTooltip:SetSpellByID(slot.spellID) end
    GameTooltip:AddLine(slot.types or "",0.8,0.8,0.8)
    if slot.preview then
        GameTooltip:AddLine("Preview only: no spell will be cast.",1,0.6,0.2,true)
    else
        GameTooltip:AddLine("Left-click this arc to cleanse this party member.",1,0.82,0,true)
        GameTooltip:AddLine("Grey: no matching alert. Color and glow: a removable debuff is present.",0.8,0.8,0.8,true)
        GameTooltip:AddLine("Range, mana and cooldown still apply. Hover the debuff row for effect details.",0.8,0.8,0.8,true)
    end
    GameTooltip:Show()
end
local function createSlot(card, state, index, preview)
    -- Register partial work before decoration; setup failure can hide it all.
    local slot = {buttons={},preview=preview}
    state.slots[index] = slot
    local art = CreateFrame("Frame",nil,card)
    slot.art = art
    art:Hide(); art:EnableMouse(false)
    art:SetFrameLevel(card.portraitArea:GetFrameLevel()+1)
    art:SetPoint("CENTER",card.portraitArea,"CENTER")
    slot.fill = texture(art,"BACKGROUND")
    slot.fill:SetVertexColor(0.12,0.15,0.16,0.95)
    slot.rim = texture(art,"BORDER")
    slot.rim:SetVertexColor(0.52,0.48,0.35,0.85)
    local anchor = CreateFrame("Frame",nil,art)
    slot.iconAnchor = anchor
    anchor:SetSize(ICON,ICON); anchor:EnableMouse(false)
    slot.icon = icon(art,anchor)
    slot.icon:SetDesaturated(true); slot.icon:SetVertexColor(0.4,0.4,0.4)
    if preview then
        slot.glow = texture(art,"OVERLAY")
        slot.glow:SetBlendMode("ADD")
        slot.timer = art:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        slot.timer:SetFont(FONT,9,"OUTLINE")
        slot.timer:SetPoint("BOTTOM",anchor,"BOTTOM",0,-1)
    end
    return slot
end
local function createHit(card, slot)
    -- Fixed narrow rectangles approximate the arc from INSIDE its artwork.
    -- All secure strips are card children, outside the native aura hierarchy.
    local cast = CreateFrame("Button",nil,card,not slot.preview and "SecureActionButtonTemplate" or nil)
    cast:Hide()
    slot.buttons[#slot.buttons+1] = cast
    cast.cleanseSlot = slot
    cast:SetFrameLevel(card.portraitArea:GetFrameLevel()+1)
    cast:RegisterForClicks("AnyDown","AnyUp")
    cast:EnableMouse(true)
    if not slot.preview then
        cast:SetAttribute("useparent-unit",true)
        -- Cast on press so small pointer motion between fixed strips cannot
        -- cancel a release click. This is local to cleanses, not a global bind.
        cast:SetAttribute("useOnKeyDown",true)
        cast:SetAttribute("checkselfcast",false)
        cast:SetAttribute("checkfocuscast",false)
        cast:SetAttribute("checkmouseovercast",false)
        cast:SetAttribute("type1",""); cast:SetAttribute("*type1","")
        cast:SetAttribute("type2","togglemenu"); cast:SetAttribute("*type2","togglemenu")
    end
    cast:SetScript("OnEnter",tooltip)
    cast:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return cast
end
local function layout(card, slot, index, count)
    local g = ns.CleanseGeometry:Get(style(),index,count)
    slot.geometry = g
    slot.art:SetSize(g.artSize,g.artSize)
    slot.iconAnchor:ClearAllPoints()
    slot.iconAnchor:SetPoint("CENTER",card.portraitArea,"CENTER",g.iconX,-g.iconY)
    slot.fill:SetTexture(g.textureBase.."-fill.tga")
    slot.rim:SetTexture(g.textureBase.."-rim.tga")
    if slot.activeFill then
        slot.activeFill:SetTexture(g.textureBase.."-fill.tga")
        slot.activeRim:SetTexture(g.textureBase.."-rim.tga")
        slot.activeGlow:SetTexture(g.textureBase.."-glow.tga")
    elseif slot.glow then slot.glow:SetTexture(g.textureBase.."-glow.tga") end
    for i,rect in ipairs(g.rects) do
        local cast = slot.buttons[i] or createHit(card,slot)
        cast:ClearAllPoints()
        cast:SetPoint("TOPLEFT",card.portraitArea,"CENTER",rect.x,-rect.y)
        cast:SetSize(rect.width,rect.height)
    end
end
local function initialize(button, card, index, state)
    local slot = state.slots[index]
    -- Native presentation follows ordinary artwork. Protected actions never
    -- depend on a native aura's visibility, geometry, or restricted scripts.
    button:SetAllPoints(slot.art)
    button:SetFrameLevel(card.portraitArea:GetFrameLevel()+2)
    button:EnableMouse(false)
    slot.activeFill = texture(button,"BACKGROUND")
    slot.activeFill:SetAlpha(0.42)
    slot.activeIcon = icon(button,slot.iconAnchor)
    local cooldown = CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
    cooldown:SetAllPoints(slot.iconAnchor)
    cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false)
    -- The native timer remains; a square cooldown swipe would spill outside
    -- the circular icon and the thin curved arc behind it.
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
    cooldown:SetHideCountdownNumbers(true); cooldown:EnableMouse(false)
    button:SetDurationCooldown(cooldown)
    local overlay = CreateFrame("Frame",nil,button)
    overlay:SetAllPoints(button); overlay:SetFrameLevel(card.portraitArea:GetFrameLevel()+5)
    overlay:EnableMouse(false)
    local duration = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    duration:SetFont(FONT,9,"OUTLINE"); duration:SetPoint("BOTTOM",slot.iconAnchor,"BOTTOM",0,-1)
    button:SetDurationText(duration)
    local count = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    count:SetFont(FONT,8,"OUTLINE"); count:SetPoint("TOPRIGHT",slot.iconAnchor,"TOPRIGHT",1,1)
    button:SetApplicationCount(count)
    slot.activeRim = texture(overlay,"OVERLAY")
    slot.activeGlow = texture(overlay,"OVERLAY")
    slot.activeGlow:SetBlendMode("ADD")
    for _,region in ipairs({slot.activeFill,slot.activeRim,slot.activeGlow}) do
        button:AddDispelTypeTexture(region,{showWhenHarmful=true,showWhenHelpful=false,
            style=Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset})
    end
    slot.initialized = true
end
local function disableActions(state)
    -- Setup/configuration only, never in response to aura expiry.
    for _,slot in ipairs(state.slots) do
        if slot.art then slot.art:Hide() end
        for _,cast in ipairs(slot.buttons) do
            cast:Hide()
            cast:SetAttribute("type1",""); cast:SetAttribute("*type1","")
            cast:SetAttribute("spell",nil)
        end
        slot.spellID=nil
    end
end
local function release(state)
    if not state or not state.container then return true end
    local ok=pcall(state.container.SetEnabled,state.container,false)
    state.unit=nil
    if not ok then
        state.reason="Native cleanse display could not release its previous member."
        if not ns.InCombat() then
            state.configured=false; disableActions(state)
            pcall(state.container.Hide,state.container)
        end
    end
    return ok
end
function Display:Create(card)
    if card.cleanseDisplay then return card.cleanseDisplay.supported end
    if ns.InCombat() then return false end
    local state={slots={},supported=false}
    card.cleanseDisplay=state
    if not C_AuraContainerUtil or not Enum or not Enum.CustomAuraButtonDispelTypeTextureStyle then
        state.reason="Native cleanse controls are unavailable on this client."; return false
    end
    local ok,reason=pcall(function()
        local container=CreateFrame("AuraContainer",nil,card,"CustomAuraContainerTemplate")
        state.container=container
        for _,method in ipairs({"SetEnabled","SetUnit","AddAuraSlot","SetAuraSlotEnabled","SetAuraSlotCandidateFilters"}) do
            assert(type(container[method])=="function","Missing native method: "..method)
        end
        container:SetEnabled(false); container:EnableMouse(false)
        container:SetPoint("TOPLEFT",card,"TOPLEFT",0,0)
        for index=1,COUNT do
            local slot=index
            createSlot(card,state,slot,false)
            container:AddAuraSlot("cleanse"..slot,"HARMFUL|RAID",{
                candidateFilters={includeDispelTypes={}},
                initializeFrame=function(button) initialize(button,card,slot,state) end,
            })
            assert(state.slots[slot].initialized,"Native cleanse initialization did not complete")
            container:SetAuraSlotEnabled("cleanse"..slot,false)
        end
    end)
    if not ok then
        release(state); disableActions(state)
        if state.container then pcall(state.container.Hide,state.container) end
        state.reason="Cleanse setup failed: "..tostring(reason)
        return false
    end
    state.supported=true
    return true
end
local function signature(actions)
    local parts={style()}
    for _,action in ipairs(actions) do
        parts[#parts+1]=action.spellID..":"..names(action.types)..":"..tostring(action.record and action.record.icon or QUESTION)
    end
    return table.concat(parts,";")
end
function Display:Configure(card)
    if ns.InCombat() then return false end
    if card.previewIndex then return self:Preview(card) end
    if not self:Create(card) then return false end
    local state=card.cleanseDisplay
    local actions=ns.Cleanses and ns.Cleanses:GetActions() or {}
    local key=signature(actions)
    if state.configured and state.signature==key then return true end
    if not release(state) then return false end
    disableActions(state)
    local ok,reason=pcall(function()
        for index=1,COUNT do
            local slot,action=state.slots[index],actions[index]
            state.container:SetAuraSlotEnabled("cleanse"..index,false)
            if action then
                layout(card,slot,index,#actions)
                slot.spellID,slot.types=action.spellID,names(action.types)
                local image=action.record and action.record.icon or QUESTION
                slot.icon:SetTexture(image); slot.activeIcon:SetTexture(image)
                for i=1,#slot.geometry.rects do
                    local cast=slot.buttons[i]
                    cast:SetAttribute("type1","spell"); cast:SetAttribute("*type1","spell")
                    cast:SetAttribute("spell",action.spellID)
                end
            end
            state.container:SetAuraSlotCandidateFilters("cleanse"..index,{includeDispelTypes=action and action.types or {}})
            state.container:SetAuraSlotEnabled("cleanse"..index,action~=nil)
        end
        state.container:Show()
        -- Publish art and actions only after all configuration succeeds.
        for index,slot in ipairs(state.slots) do
            if actions[index] then
                slot.art:Show()
                for i=1,#slot.geometry.rects do slot.buttons[i]:Show() end
            end
        end
    end)
    if not ok then
        release(state); pcall(state.container.Hide,state.container); disableActions(state)
        state.configured=false; state.reason="Cleanse configuration failed: "..tostring(reason)
        return false
    end
    state.configured,state.signature,state.actionCount=true,key,#actions
    state.reason=nil
    self:Update(card,card:GetAttribute("unit"))
    return true
end
function Display:Update(card,unit)
    local state=card.cleanseDisplay
    if not state or not state.supported or not state.configured then return false end
    if ns.IsSecret(unit) or type(unit)~="string" or not unit:match("^party[1-4]$") then release(state); return false end
    local exists=UnitExists(unit)
    if ns.IsSecret(exists) or not exists or ns.worldActive==false then release(state); return false end
    if state.unit==unit then return true end
    if not release(state) then return false end
    local ok,reason=pcall(function()
        state.container:SetUnit(unit)
        state.container:SetEnabled(true)
    end)
    if not ok then
        release(state); state.reason="Cleanse display could not bind this member: "..tostring(reason); return false
    end
    state.unit,state.reason=unit,nil
    return true
end
function Display:Clear(card) release(card and card.cleanseDisplay) end
function Display:GetStatus(card)
    local state=card and card.cleanseDisplay
    if state and state.reason then return state.reason end
    if not state or not state.supported then return "unavailable." end
    if not state.configured or state.actionCount==0 then return "no learned or assigned removal abilities." end
    return "radial cleanse buttons with native alerts; "..state.actionCount.." assigned actions."
end
-- Synthetic sample states only; preview controls never receive cast attributes.
function Display:Preview(card)
    if not card.previewIndex or ns.InCombat() then return false end
    local actions=ns.Cleanses and ns.Cleanses:GetActions() or {}
    card.cleansePreview=card.cleansePreview or {slots={}}
    local state=card.cleansePreview
    for index=1,COUNT do
        local slot=state.slots[index] or createSlot(card,state,index,true)
        slot.art:Hide()
        for _,button in ipairs(slot.buttons) do button:Hide() end
        local action=actions[index]
        if action then
            layout(card,slot,index,#actions)
            local active=card.previewIndex==4 or card.previewIndex==index+1
            slot.spellID,slot.types=action.spellID,names(action.types)
            slot.icon:SetTexture(action.record and action.record.icon or QUESTION)
            slot.icon:SetDesaturated(not active)
            local shade=active and 1 or 0.4
            slot.icon:SetVertexColor(shade,shade,shade)
            local c=COLORS[action.key] or COLORS.Magic
            if active then
                slot.fill:SetVertexColor(c[1]*0.42,c[2]*0.42,c[3]*0.42)
                slot.rim:SetVertexColor(unpack(c))
            else
                slot.fill:SetVertexColor(0.12,0.15,0.16,0.95)
                slot.rim:SetVertexColor(0.52,0.48,0.35,0.85)
            end
            slot.glow:SetVertexColor(unpack(c)); slot.glow:SetAlpha(active and 1 or 0)
            slot.timer:SetText(active and (index==1 and "8s" or "24s") or "")
            slot.art:Show()
            for i=1,#slot.geometry.rects do slot.buttons[i]:Show() end
        end
    end
    return true
end
