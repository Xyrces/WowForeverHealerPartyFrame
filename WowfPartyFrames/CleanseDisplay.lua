local _, ns = ...
local Display = {}
ns.CleanseDisplay = Display
local COUNT, SIZE, GAP = 4, 36, 2
local TYPES = {"Magic", "Disease", "Poison", "Curse"}
local COLORS = {Magic={0.45,0.78,1}, Disease={0.84,0.65,0.36}, Poison={0.3,0.9,0.35}, Curse={0.75,0.45,1}}
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local function names(types)
    local result = {}
    for _, kind in ipairs(TYPES) do if types[kind] then result[#result + 1] = kind end end
    return table.concat(result, "/")
end
local function position(frame, card, index)
    frame:SetSize(SIZE, SIZE)
    frame:SetPoint("TOPLEFT", card.portraitArea, "TOPRIGHT",
        8 + math.floor((index-1)/2)*96, -4 - ((index-1)%2)*(SIZE+GAP))
end

local function createAction(card, index)
    -- Keep the protected action outside the native aura hierarchy. Native
    -- AuraButtons suppress addon-installed scripts, including child clicks.
    local cast = CreateFrame("Button", nil, card, "SecureActionButtonTemplate")
    cast:Hide()
    position(cast, card, index)
    cast:SetFrameLevel(card.portraitArea:GetFrameLevel()+10)
    ns.Visuals:DecorateSpellButton(cast, SIZE)
    cast.icon:SetDesaturated(true)
    cast.icon:SetVertexColor(0.4, 0.4, 0.4)
    cast:RegisterForClicks("AnyDown", "AnyUp")
    cast:EnableMouse(true)
    cast:SetAttribute("useparent-unit",true)
    cast:SetAttribute("checkselfcast",false)
    cast:SetAttribute("checkfocuscast",false)
    cast:SetAttribute("checkmouseovercast",false)
    cast:SetAttribute("type1",""); cast:SetAttribute("*type1","")
    cast:SetAttribute("type2","togglemenu"); cast:SetAttribute("*type2","togglemenu")
    local label = cast:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetFont(FONT,9,"OUTLINE"); label:SetPoint("LEFT",cast,"RIGHT",5,0)
    label:SetWidth(50); label:SetJustifyH("LEFT"); label:SetWordWrap(true)
    cast:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        if self.spellID then GameTooltip:SetSpellByID(self.spellID) end
        GameTooltip:AddLine("Left-click to cleanse this party member.",1,0.82,0,true)
        GameTooltip:AddLine("Grey: no matching alert. Color and glow: a removable debuff is present.",0.8,0.8,0.8,true)
        GameTooltip:AddLine("Range, mana and cooldown still apply. Hover the debuff row for effect details.",0.8,0.8,0.8,true)
        GameTooltip:Show()
    end)
    cast:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return {cast=cast,label=label}
end

local function initialize(button, card, index, state)
    position(button, card, index)
    local slot = state.slots[index]
    button:SetFrameLevel(slot.cast:GetFrameLevel()+10)
    -- Display-only overlay: both clicks and hover reach the ordinary action
    -- below. Debuff details remain available on the separate native aura row.
    button:EnableMouse(false)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
    icon:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
    icon:SetTexCoord(0.07,0.93,0.07,0.93)
    -- A static copy of the assigned removal spell, NOT the debuff's icon.
    -- Native visibility reveals this full-color art above the grey action.
    slot.activeIcon = icon
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true); cooldown:EnableMouse(false)
    button:SetDurationCooldown(cooldown)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button); overlay:SetFrameLevel(cooldown:GetFrameLevel()+2)
    overlay:EnableMouse(false)
    local duration = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    duration:SetFont(FONT,11,"OUTLINE"); duration:SetPoint("BOTTOM",0,0)
    button:SetDurationText(duration)
    local count = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    count:SetFont(FONT,10,"OUTLINE"); count:SetPoint("TOPRIGHT",-1,-1)
    button:SetApplicationCount(count)
    local border = overlay:CreateTexture(nil,"OVERLAY")
    border:SetAllPoints(button)
    button:AddDispelTypeTexture(border, {showWhenHarmful=true,showWhenHelpful=false,
        style=Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon})
    local glow = overlay:CreateTexture(nil,"OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD"); glow:SetSize(SIZE*1.8,SIZE*1.8); glow:SetPoint("CENTER",button,"CENTER")
    button:AddDispelTypeTexture(glow, {showWhenHarmful=true,showWhenHelpful=false,
        style=Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset})
    slot.initialized = true
end

local function disableActions(state)
    -- Used only during setup/configuration outside combat, never on expiry.
    for _,slot in ipairs(state.slots) do
        slot.cast:Hide()
        slot.cast:SetAttribute("type1",""); slot.cast:SetAttribute("*type1","")
        slot.cast:SetAttribute("spell",nil)
        slot.cast.spellID=nil
    end
end

local function release(state)
    if not state or not state.container then return true end
    local ok = pcall(state.container.SetEnabled,state.container,false)
    state.unit=nil
    -- This container contains presentation only. Its visibility never changes
    -- the separate, visibly grey protected casting buttons.
    if not ok then
        state.reason="Native cleanse display could not release its previous member."
        if not ns.InCombat() then
            state.configured=false
            disableActions(state)
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
            state.slots[slot]=createAction(card,slot)
            container:AddAuraSlot("cleanse"..slot,"HARMFUL|RAID",{
                candidateFilters={includeDispelTypes={}},
                initializeFrame=function(button) initialize(button,card,slot,state) end,
            })
            -- Native securecallfunction can report callback errors without
            -- rethrowing them to our pcall. Require the final success marker.
            assert(state.slots[slot].initialized,"Native cleanse initialization did not complete")
            container:SetAuraSlotEnabled("cleanse"..slot,false)
        end
    end)
    if not ok then
        release(state)
        disableActions(state)
        if state.container then pcall(state.container.Hide,state.container) end
        state.reason="Cleanse setup failed: "..tostring(reason)
        return false
    end
    state.supported=true
    return true
end

local function signature(actions)
    local parts={}
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
            slot.cast:SetAttribute("type1",action and "spell" or "")
            slot.cast:SetAttribute("*type1",action and "spell" or "")
            slot.cast:SetAttribute("spell",action and action.spellID or nil)
            slot.cast.spellID=action and action.spellID or nil
            local texture=action and action.record and action.record.icon or QUESTION
            slot.cast.icon:SetTexture(texture)
            slot.activeIcon:SetTexture(texture)
            slot.label:SetText(action and names(action.types) or "")
            state.container:SetAuraSlotCandidateFilters("cleanse"..index,{includeDispelTypes=action and action.types or {}})
            state.container:SetAuraSlotEnabled("cleanse"..index,action~=nil)
        end
        state.container:Show()
        -- Publish only after every filter and action has been configured.
        for index,slot in ipairs(state.slots) do slot.cast:SetShown(actions[index]~=nil) end
    end)
    if not ok then
        release(state); pcall(state.container.Hide,state.container)
        disableActions(state)
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

function Display:Clear(card)
    release(card and card.cleanseDisplay)
end

function Display:GetStatus(card)
    local state=card and card.cleanseDisplay
    if state and state.reason then return state.reason end
    if not state or not state.supported then return "unavailable." end
    if not state.configured or state.actionCount==0 then return "no learned or assigned removal abilities." end
    return "visible cleanse buttons with native alerts; "..state.actionCount.." assigned actions."
end

-- Synthetic sample states only; preview controls never receive cast attributes.
function Display:Preview(card)
    if not card.previewIndex then return false end
    local actions=ns.Cleanses and ns.Cleanses:GetActions() or {}
    card.cleansePreview=card.cleansePreview or {}
    for index=1,COUNT do
        local button=card.cleansePreview[index]
        if not button then
            button=CreateFrame("Button",nil,card)
            position(button,card,index)
            ns.Visuals:DecorateSpellButton(button,SIZE)
            button.label=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            button.label:SetFont(FONT,9,"OUTLINE"); button.label:SetPoint("LEFT",button,"RIGHT",5,0)
            button.label:SetWidth(50); button.label:SetJustifyH("LEFT")
            button:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                if self.spellID then GameTooltip:SetSpellByID(self.spellID) end
                GameTooltip:AddLine("Preview only: no spell will be cast.",1,0.6,0.2,true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function() GameTooltip:Hide() end)
            card.cleansePreview[index]=button
        end
        local action=actions[index]
        local active=action and (card.previewIndex==4 or card.previewIndex==index+1)
        button:SetShown(action~=nil)
        if action then
            button.spellID=action.spellID
            button.icon:SetTexture(action.record.icon)
            button.icon:SetDesaturated(not active)
            local shade=active and 1 or 0.4
            button.icon:SetVertexColor(shade,shade,shade)
            button.label:SetText(names(action.types))
            button.timer:SetText(active and (index==1 and "8s" or "24s") or "")
            button.glow:SetAlpha(active and 1 or 0)
            local color=COLORS[action.key] or COLORS.Magic
            button.glow:SetVertexColor(unpack(color))
        end
    end
    return true
end
