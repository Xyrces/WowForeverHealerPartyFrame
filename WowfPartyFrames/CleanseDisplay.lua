local _, ns = ...
local Display = {}
ns.CleanseDisplay = Display
local COUNT, SIZE, GAP = 4, 36, 2
local TYPES = {"Magic", "Disease", "Poison", "Curse"}
local COLORS = {Magic={0.45,0.78,1}, Disease={0.84,0.65,0.36}, Poison={0.3,0.9,0.35}, Curse={0.75,0.45,1}}
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
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

local function initialize(button, card, index, state)
    position(button, card, index)
    button:SetFrameLevel(card.portraitArea:GetFrameLevel()+12)
    button:SetAttribute("useparent-unit", true)
    button:SetMouseClickEnabled(false)
    button:SetTooltipAnchorPoint("ANCHOR_RIGHT")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.07,0.93,0.07,0.93)
    button:SetIcon(icon)
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
    local label = overlay:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetFont(FONT,9,"OUTLINE"); label:SetPoint("LEFT",button,"RIGHT",5,0)
    label:SetWidth(50); label:SetJustifyH("LEFT"); label:SetWordWrap(true)

    -- The action is a CHILD of the native aura, not a persistent underlay.
    -- Blizzard owns parent visibility. No addon script reads aura presence,
    -- hides a protected button in combat, or leaves a transparent hitbox.
    -- All attributes are assigned before combat. The parent-unit chain reaches
    -- the named member card even when its secure header changes party tokens.
    local cast = CreateFrame("Button", nil, button, "SecureActionButtonTemplate")
    cast:SetAllPoints(button); cast:SetFrameLevel(overlay:GetFrameLevel()+2)
    cast:RegisterForClicks("AnyDown", "AnyUp")
    cast:SetMouseMotionEnabled(false)
    cast:SetAttribute("useparent-unit",true)
    cast:SetAttribute("checkselfcast",false)
    cast:SetAttribute("checkfocuscast",false)
    cast:SetAttribute("checkmouseovercast",false)
    cast:SetAttribute("type1",""); cast:SetAttribute("*type1","")
    cast:SetAttribute("type2","togglemenu"); cast:SetAttribute("*type2","togglemenu")
    state.slots[index] = {cast=cast,label=label}
end

local function release(state)
    if not state or not state.container then return true end
    local ok = pcall(state.container.SetEnabled,state.container,false)
    state.unit=nil
    -- Never mask a failed native hide with alpha: that would leave a live,
    -- invisible action. Outside combat the container can also be hidden.
    if not ok then
        state.reason="Native cleanse display could not release its previous member."
        if not ns.InCombat() then
            state.configured=false
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
        container:SetAttribute("useparent-unit",true)
        for index=1,COUNT do
            local slot=index
            container:AddAuraSlot("cleanse"..slot,"HARMFUL|RAID",{
                candidateFilters={includeDispelTypes={}},
                initializeFrame=function(button) initialize(button,card,slot,state) end,
            })
            -- Native securecallfunction can report callback errors without
            -- rethrowing them to our pcall. Require the final success marker.
            assert(state.slots[slot] and state.slots[slot].cast,"Native cleanse initialization did not complete")
            container:SetAuraSlotEnabled("cleanse"..slot,false)
        end
    end)
    if not ok then
        release(state)
        if state.container then pcall(state.container.Hide,state.container) end
        state.reason="Cleanse setup failed: "..tostring(reason)
        return false
    end
    state.supported=true
    return true
end

local function signature(actions)
    local parts={}
    for _,action in ipairs(actions) do parts[#parts+1]=action.spellID..":"..names(action.types) end
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
    local ok,reason=pcall(function()
        for index=1,COUNT do
            local slot,action=state.slots[index],actions[index]
            state.container:SetAuraSlotEnabled("cleanse"..index,false)
            slot.cast:SetAttribute("type1",action and "spell" or "")
            slot.cast:SetAttribute("*type1",action and "spell" or "")
            slot.cast:SetAttribute("spell",action and action.spellID or nil)
            slot.label:SetText(action and names(action.types) or "")
            state.container:SetAuraSlotCandidateFilters("cleanse"..index,{includeDispelTypes=action and action.types or {}})
            state.container:SetAuraSlotEnabled("cleanse"..index,action~=nil)
        end
        state.container:Show()
    end)
    if not ok then
        release(state); pcall(state.container.Hide,state.container)
        state.configured=false; state.reason="Cleanse configuration failed: "..tostring(reason)
        return false
    end
    state.configured,state.signature,state.actionCount=true,key,#actions
    state.reason=nil
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
    return "native removable-debuff controls; "..state.actionCount.." assigned actions."
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
        button:SetShown(active~=nil and active~=false)
        if action then
            button.spellID=action.spellID
            button.icon:SetTexture(action.record.icon)
            button.label:SetText(names(action.types))
            button.timer:SetText(index==1 and "8s" or "24s")
            button.glow:SetAlpha(1)
            local color=COLORS[action.key] or COLORS.Magic
            button.glow:SetVertexColor(unpack(color))
        end
    end
    return true
end
