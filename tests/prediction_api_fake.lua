-- Test-only public calculator model. This does not emulate native secret handling,
-- secure execution, or prove the client's rendering/health-prediction semantics.
return function(state)
    local methods = state.methods
    local predictionAtlases = {
        ["raidframe-shield-fill"]=true, ["raidframe-absorb-fill"]=true,
        ["RaidFrame-Shield-Overlay"]=true, ["RaidFrame-Absorb-Overlay"]=true,
        ["RaidFrame-Shield-Overshield"]=true, ["RaidFrame-Absorb-Overabsorb"]=true,
    }
    function methods:SetAtlas(atlas,useAtlasSize,filterMode,resetTexCoords,wrapH,wrapV)
        assert(type(atlas)=="string", "atlas must be a string")
        assert(useAtlasSize==nil or type(useAtlasSize)=="boolean", "useAtlasSize must be boolean")
        assert(filterMode==nil or filterMode=="LINEAR" or filterMode=="TRILINEAR" or filterMode=="NEAREST", "invalid texture filter mode")
        assert(resetTexCoords==nil or type(resetTexCoords)=="boolean", "resetTexCoords must be boolean")
        for _,wrap in pairs({wrapH,wrapV}) do
            assert(wrap=="CLAMP" or wrap=="CLAMPTOBLACK" or wrap=="CLAMPTOBLACKADDITIVE" or wrap=="REPEAT" or wrap=="MIRROR", "invalid texture wrap mode")
        end
        self.atlasArgs={atlas,useAtlasSize,filterMode,resetTexCoords,wrapH,wrapV}
        if predictionAtlases[atlas] then
            if state.predictionAtlasError then error("atlas unavailable") end
            if state.missingPredictionAtlases then return end
        end
        self.atlas=atlas
        -- SetAtlas has no documented return value.
    end
    function methods:GetAtlas() return self.atlas end
    C_Texture = {GetAtlasInfo=function(atlas)
        if predictionAtlases[atlas] and state.missingPredictionAtlases then return nil end
        return {width=32,height=32}
    end}
    function methods:GetStatusBarTexture()
        if not self.statusTexture then self.statusTexture = self:CreateTexture(nil, "ARTWORK") end
        return self.statusTexture
    end
    local previousStatusTexture=methods.SetStatusBarTexture
    function methods:SetStatusBarTexture(value)
        previousStatusTexture(self,value)
        if type(value)=="table" then self.statusTexture=value
        else self:GetStatusBarTexture():SetTexture(value) end
    end
    function methods:SetReverseFill(value) self.reverseFill = value end
    function methods:SetOrientation(value) self.orientation = value end
    function methods:SetAlphaFromBoolean(value, on, off)
        self.alphaBoolean = value
        self.alphaBooleanArgs = {value, on, off}
        -- Opaque fixtures must reach this native sink without Lua branching.
        if type(value) == "boolean" then self.alpha = value and (on or 1) or (off or 0) end
    end
    Enum = Enum or {}
    Enum.UnitDamageAbsorbClampMode = {MissingHealth=0, MissingHealthWithoutIncomingHeals=1, MaximumHealth=2}
    Enum.UnitHealAbsorbClampMode = {CurrentHealth=0, MaximumHealth=1}
    Enum.UnitHealAbsorbMode = {ReducedByIncomingHeals=0, Total=1}
    Enum.UnitIncomingHealClampMode = {MissingHealth=0, MaximumHealth=1}
    Enum.UnitMaximumHealthMode = {Default=0, WithAbsorbs=1}
    state.predictionCalls, state.calculators = {}, {}
    local calcMethods = {}
    for _, key in ipairs({"DamageAbsorbClampMode", "HealAbsorbClampMode", "HealAbsorbMode",
        "IncomingHealClampMode", "IncomingHealOverflowPercent", "MaximumHealthMode"}) do
        calcMethods["Set"..key] = function(self, value) self[key] = value end
        calcMethods["Get"..key] = function(self) return self[key] end
    end
    function calcMethods:SetToDefaults()
        self.DamageAbsorbClampMode=0; self.HealAbsorbClampMode=0; self.HealAbsorbMode=0
        self.IncomingHealClampMode=0; self.IncomingHealOverflowPercent=1; self.MaximumHealthMode=0
    end
    function calcMethods:ResetPredictedValues() self.resetCount=(self.resetCount or 0)+1; self.values={health=0,healthMax=1}; self.outputs=nil end
    function calcMethods:Reset() self:SetToDefaults(); self:ResetPredictedValues() end
    function calcMethods:SetPredictedValues(values) self.values=values; self.outputs=nil end
    function calcMethods:GetPredictedValues() return self.values end
    local function numbers(self)
        local v=self.values
        local health,maxHealth=v.health or 0,v.healthMax or 1
        local heal,own,shield,block=v.totalIncomingHeals or 0,v.totalIncomingHealsFromHealer or 0,v.totalDamageAbsorbs or 0,v.totalHealAbsorbs or 0
        local reducedHeal,reducedBlock=heal,block
        if self.HealAbsorbMode==0 then reducedHeal=math.max(0,heal-block); reducedBlock=math.max(0,block-heal) end
        local healMax=self.IncomingHealClampMode==1 and maxHealth or math.max(0,maxHealth*(self.IncomingHealOverflowPercent or 1)-health)
        local incoming=math.min(reducedHeal,healMax)
        local ownIncoming=math.min(own,incoming)
        local shieldMax=maxHealth
        if self.DamageAbsorbClampMode==0 then shieldMax=math.max(0,maxHealth-health-incoming)
        elseif self.DamageAbsorbClampMode==1 then shieldMax=math.max(0,maxHealth-health) end
        local blockMax=self.HealAbsorbClampMode==1 and maxHealth or health
        return {GetCurrentHealth={health},GetMaximumHealth={maxHealth},GetMissingHealth={maxHealth-health},
            GetIncomingHeals={incoming,ownIncoming,incoming-ownIncoming,reducedHeal>healMax},
            GetDamageAbsorbs={math.min(shield,shieldMax),shield>shieldMax},
            GetHealAbsorbs={math.min(reducedBlock,blockMax),reducedBlock>blockMax},
            GetTotalDamageAbsorbs={shield},GetTotalHealAbsorbs={block},GetTotalIncomingHeals={heal},
            GetTotalIncomingHealsFromHealer={own},GetMaximumIncomingHeals={healMax},
            GetMaximumDamageAbsorbs={shieldMax},GetMaximumHealAbsorbs={blockMax}}
    end
    for _, key in ipairs({"CurrentHealth","MaximumHealth","MissingHealth","IncomingHeals","DamageAbsorbs","HealAbsorbs",
        "TotalDamageAbsorbs","TotalHealAbsorbs","TotalIncomingHeals","TotalIncomingHealsFromHealer",
        "MaximumIncomingHeals","MaximumDamageAbsorbs","MaximumHealAbsorbs"}) do
        local method="Get"..key
        calcMethods[method]=function(self)
            if self.failMethod==method then error("calculator getter failure") end
            return unpack((self.outputs or numbers(self))[method])
        end
    end
    CreateUnitHealPredictionCalculator=function()
        local calc=setmetatable({}, {__index=calcMethods}); calc:Reset()
        state.calculators[#state.calculators+1]=calc
        return calc
    end
    UnitGetDetailedHealPrediction=function(unit,healer,calculator)
        state.predictionCalls[#state.predictionCalls+1]={unit,healer,calculator}
        if state.predictionError then error("prediction fetch failure") end
        local data=state.units[unit] or {}
        calculator:SetPredictedValues(data.prediction or {health=data.health or 0,healthMax=data.maxHealth or 1})
        calculator.outputs=data.predictionOutputs
    end
    return state
end
