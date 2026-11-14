-- Offline plumbing regression tests, not an emulator of native secret values.
local state=assert(loadfile("tests/wow_ui_fake.lua"))()()
assert(loadfile("tests/prediction_api_fake.lua"))()(state)
local ns={Layout={barWidth=174}}
assert(loadfile("WowfPartyFrames/HealthPrediction.lua"))("WowfPartyFrames",ns)
local P=ns.HealthPrediction
local checks=0
local function eq(a,b,why)
    checks=checks+1
    assert(rawequal(a,b),(why or "unexpected")..": "..tostring(a).." ~= "..tostring(b))
end
local function card()
    local c=CreateFrame("Button",nil,UIParent,"SecureUnitButtonTemplate")
    c.health=CreateFrame("StatusBar",nil,c); c.health:SetSize(174,12)
    c.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    P:Create(c)
    return c
end
local c=card()
local p=c.healthPrediction
eq(p.supported,true,"native APIs supported")
eq(p.calculator.IncomingHealClampMode,Enum.UnitIncomingHealClampMode.MissingHealth)
eq(p.calculator.DamageAbsorbClampMode,Enum.UnitDamageAbsorbClampMode.MissingHealth)
eq(p.calculator.HealAbsorbClampMode,Enum.UnitHealAbsorbClampMode.CurrentHealth)
eq(p.calculator.HealAbsorbMode,Enum.UnitHealAbsorbMode.ReducedByIncomingHeals)
eq(p.calculator.IncomingHealOverflowPercent,1,"prediction stays inside existing health bar")
local function hasAnchor(frame,relative,point)
    for _,v in ipairs(frame.points or {}) do
        if v[2]==relative and v[3]==point then return true end
    end
    return false
end
eq(hasAnchor(p.myHeal,c.health:GetStatusBarTexture(),"RIGHT"),true,"own heals follow current health fill")
eq(hasAnchor(p.otherHeal,p.myHeal:GetStatusBarTexture(),"RIGHT"),true,"other heals follow own heals")
eq(hasAnchor(p.damageAbsorb,p.otherHeal:GetStatusBarTexture(),"RIGHT"),true,"shield follows incoming heals")
eq(hasAnchor(p.healAbsorb,c.health:GetStatusBarTexture(),"RIGHT"),true,"heal absorbs overlay current health")
eq(p.healAbsorb.reverseFill,true,"heal absorbs extend back over health")
state.units.party1={health=400,maxHealth=1000,prediction={health=400,healthMax=1000,
    totalIncomingHeals=200,totalIncomingHealsFromHealer=80,totalDamageAbsorbs=250,totalHealAbsorbs=0}}
P:Update(c,"party1")
eq(p.unit,"party1"); eq(p.myHeal.value,80); eq(p.otherHeal.value,120)
eq(p.damageAbsorb.value,250); eq(p.healAbsorb.value,0)
eq(p.myHeal.maximum,1000)
eq(state.predictionCalls[#state.predictionCalls][2],"player","own-heal source supplied")
state.units.party1.prediction={health=400,healthMax=1000,totalIncomingHeals=200,
    totalIncomingHealsFromHealer=0,totalDamageAbsorbs=150,totalHealAbsorbs=0}
P:Update(c,"party1")
eq(p.myHeal.value,0,"zero own-heal amount")
eq(p.otherHeal.value,200,"other heals still show after zero-width own fill")
eq(p.damageAbsorb.value,150,"shield still follows others with zero own heals")
state.units.party1.prediction={health=1000,healthMax=1000,totalDamageAbsorbs=300}
P:Update(c,"party1")
eq(p.damageAbsorb.value,0,"full-health shield does not overrun health bar")
eq(p.overAbsorbGlow.alphaBoolean,true,"full-health shield remains visible via overflow glow")
-- Exercise reduction and overflow input/output plumbing through the public fixture.
state.units.party1.prediction={health=900,healthMax=1000,totalIncomingHeals=300,
    totalIncomingHealsFromHealer=50,totalDamageAbsorbs=200,totalHealAbsorbs=30}
P:Update(c,"party1")
eq(p.myHeal.value,50); eq(p.otherHeal.value,50); eq(p.damageAbsorb.value,0)
eq(p.overAbsorbGlow.alphaBoolean,true,"shield overflow forwarded")
state.units.party1.prediction={health=200,healthMax=1000,totalIncomingHeals=50,
    totalIncomingHealsFromHealer=20,totalDamageAbsorbs=0,totalHealAbsorbs=400}
P:Update(c,"party1")
eq(p.myHeal.value,0); eq(p.otherHeal.value,0); eq(p.healAbsorb.value,200)
eq(p.overHealAbsorbGlow.alphaBoolean,true,"heal-absorb overflow forwarded")
local function opaque()
    return setmetatable({}, {__add=function() error("secret arithmetic") end,
        __sub=function() error("secret arithmetic") end,__mul=function() error("secret arithmetic") end,
        __div=function() error("secret arithmetic") end,__lt=function() error("secret comparison") end,
        __le=function() error("secret comparison") end,__concat=function() error("secret concat") end})
end
local maximum,my,other,shield,block,overShield,overBlock=opaque(),opaque(),opaque(),opaque(),opaque(),opaque(),opaque()
state.units.party1.predictionOutputs={GetMaximumHealth={maximum},GetIncomingHeals={opaque(),my,other,opaque()},
    GetDamageAbsorbs={shield,overShield},GetHealAbsorbs={block,overBlock}}
local originalPoint=state.methods.SetPoint
state.methods.SetPoint=function() error("prediction must not reanchor during update") end
state.combat=true
P:Update(c,"party1")
eq(p.myHeal.value,my,"opaque own-heal amount untouched")
eq(p.otherHeal.value,other,"opaque other-heal amount untouched")
eq(p.damageAbsorb.value,shield,"opaque absorption untouched")
eq(p.healAbsorb.value,block,"opaque heal absorption untouched")
eq(p.myHeal.maximum,maximum,"opaque health maximum untouched")
eq(p.overAbsorbGlow.alphaBoolean,overShield,"opaque boolean reaches native setter")
eq(p.overHealAbsorbGlow.alphaBoolean,overBlock,"opaque boolean reaches native setter")
eq(#state.violations,0,"no protected mutations in combat")
-- A failed fetch on a changed unit must never leave the previous member's overlay.
state.units.party2={health=100,maxHealth=500}
state.predictionError=true
P:Update(c,"party2")
eq(p.myHeal.value,0); eq(p.otherHeal.value,0); eq(p.damageAbsorb.value,0); eq(p.healAbsorb.value,0)
eq(p.supported,true,"transient errors remain retryable")
state.predictionError=false
P:Update(c,"party2")
eq(p.unit,"party2"); eq(p.myHeal.maximum,500,"recovers without old member maximum")
p.calculator.failMethod="GetHealAbsorbs"
P:Update(c,"party1")
eq(p.myHeal.value,0,"getter exception clears prior values")
eq(p.holder.alpha,0,"getter exception hides overlays")
eq(p.glowHolder.alpha,0,"getter exception hides overflow")
eq(p.unit,nil,"failure clears old unit identity")
p.calculator.failMethod=nil
P:Update(c,"party2")
eq(p.reason,nil,"successful retry clears diagnostics")
P:Update(c,nil)
eq(p.unit,nil); eq(p.holder.alpha,0); eq(p.glowHolder.alpha,0)
local queries=#state.predictionCalls
local secretUnit=opaque()
issecretvalue=function(value) return rawequal(value,secretUnit) end
P:Update(c,secretUnit)
eq(#state.predictionCalls,queries,"secret unit token never queried")
eq(p.unit,nil); eq(p.holder.alpha,0)
local unitExists=UnitExists
UnitExists=function() return secretUnit end
P:Update(c,"party2")
eq(#state.predictionCalls,queries,"secret existence result never branched or queried")
eq(p.unit,nil); eq(p.holder.alpha,0)
UnitExists=unitExists
issecretvalue=nil
P:Update(c,"party3")
eq(#state.predictionCalls,queries,"absent unit never queried")
eq(p.unit,nil); eq(p.holder.alpha,0)
P:Update(c,"party9")
eq(#state.predictionCalls,queries,"invalid unit token never queried")
eq(p.myHeal.value,0); eq(p.damageAbsorb.value,0)
local resets=p.calculator.resetCount
P:Clear(c)
eq(p.calculator.resetCount,resets+1,"clear discards calculator input history")
eq(p.calculator.outputs,nil,"clear discards opaque fixture outputs")
eq(p.myHeal.value,0); eq(p.otherHeal.value,0); eq(p.healAbsorb.value,0); eq(p.damageAbsorb.value,0)
eq(#state.violations,0)
state.combat=false; state.methods.SetPoint=originalPoint
P:Preview(c,{health=400,healthMax=1000,totalIncomingHeals=150,totalIncomingHealsFromHealer=100,
    totalDamageAbsorbs=200,totalHealAbsorbs=0})
eq(p.myHeal.value,100); eq(p.otherHeal.value,50); eq(p.damageAbsorb.value,200)
P:Clear(c)
eq(p.myHeal.value,0)
local create=CreateUnitHealPredictionCalculator
CreateUnitHealPredictionCalculator=nil
local unsupported=card()
eq(unsupported.healthPrediction.supported,false,"missing calculator handled")
P:Update(unsupported,"party1"); P:Clear(unsupported)
CreateUnitHealPredictionCalculator=create
local detailed=UnitGetDetailedHealPrediction
UnitGetDetailedHealPrediction=nil
local unsupportedQuery=card()
eq(unsupportedQuery.healthPrediction.supported,false,"missing query handled")
P:Update(unsupportedQuery,"party1"); P:Clear(unsupportedQuery)
UnitGetDetailedHealPrediction=detailed
local alphaFromBoolean=state.methods.SetAlphaFromBoolean
state.methods.SetAlphaFromBoolean=nil
local unsupportedAlpha=card()
eq(unsupportedAlpha.healthPrediction.supported,false,"missing native boolean setter disables feature")
eq(unsupportedAlpha.healthPrediction.holder.alpha,0,"partial construction hidden")
P:Update(unsupportedAlpha,"party1"); P:Clear(unsupportedAlpha)
state.methods.SetAlphaFromBoolean=alphaFromBoolean
state.missingPredictionAtlases=true
local fallback=card()
eq(fallback.healthPrediction.supported,true,"missing prediction atlases retain native indicators")
eq(type(fallback.healthPrediction.damageAbsorb:GetStatusBarTexture().texture),"string","shield file artwork fallback")
eq(type(fallback.healthPrediction.healAbsorb:GetStatusBarTexture().texture),"string","heal-absorb file artwork fallback")
eq(type(fallback.healthPrediction.overAbsorbGlow.texture),"string","shield glow file artwork fallback")
eq(type(fallback.healthPrediction.overHealAbsorbGlow.texture),"string","heal-absorb glow file artwork fallback")
P:Update(fallback,"party2")
eq(fallback.healthPrediction.reason,nil,"fallback remains functional")
local textureAPI=C_Texture
C_Texture=nil
local missingWithoutMetadata=card()
eq(missingWithoutMetadata.healthPrediction.supported,true,"void SetAtlas failure detected through GetAtlas")
eq(type(missingWithoutMetadata.healthPrediction.damageAbsorb:GetStatusBarTexture().texture),"string")
C_Texture=textureAPI
state.missingPredictionAtlases=nil
state.predictionAtlasError=true
local throwingArt=card()
eq(throwingArt.healthPrediction.supported,true,"atlas errors use fallback artwork")
P:Update(throwingArt,"party2")
eq(throwingArt.healthPrediction.reason,nil)
state.predictionAtlasError=nil
local count=#state.objects
P:Create(c)
eq(#state.objects,count,"duplicate setup does not recreate anchors")
print("health_prediction_spec: "..checks.." checks passed")
