local _, ns = ...
-- Explicit, noncasting sample data shared by /wpf test and offline rendering.
-- These records are never injected into unit APIs, secure headers, or presets.
local Preview = {}
ns.PreviewData = Preview
local function aura(name, icon, duration, dispel, description)
    return {name=name,icon="Interface\\Icons\\"..icon,durationText=duration,
        dispelType=dispel,description=description or "Sample effect for preview only."}
end
Preview.samples = {
    {name="Thorin Stoneheart",classToken="WARRIOR",level=24,roleToken="TANK",markerIndex=1,
        health=3240,healthMax=4500,power=62,powerMax=100,powerToken="RAGE",
        totalIncomingHeals=650,totalIncomingHealsFromHealer=400,totalDamageAbsorbs=450,totalHealAbsorbs=0,
        presence={presenceKind="shard",presenceText="Different shard",presenceDim=true,differentShard=true,
            presenceTexture="Interface\\TargetingFrame\\UI-PhasingIcon",presenceTexCoord={.15625,.84375,.15625,.84375},
            presenceTooltip="Sample: this member is on a different shard. No transfer is offered in preview."},
        status={leader=true,pvp="Alliance",readyState="ready",connected=true,threat=2},
        pet={name="Companion",icon="Interface\\Icons\\Ability_Hunter_Pet_Bear",health=420,healthMax=600,threat=1,
            debuffs={aura("Poison","Spell_Nature_CorrosiveBreath","8s","Poison")}},
        auras={helpful={aura("Fortitude","Spell_Holy_WordFortitude","18m"),aura("Renew","Spell_Holy_Renew","12s"),
            aura("Divine Spirit","Spell_Holy_DivineSpirit","12m"),aura("Shadow Protection","Spell_Shadow_AntiShadow","12m"),
            aura("Shield","Spell_Holy_PowerWordShield","20s")},
            harmful={aura("Weakened Soul","Spell_Holy_AshesToAshes","12s","None")}}},
    {name="Lyra Silvermoon",classToken="MAGE",level=24,roleToken="DAMAGER",markerIndex=5,
        health=2100,healthMax=2100,power=2800,powerMax=3600,powerToken="MANA",
        totalIncomingHeals=0,totalIncomingHealsFromHealer=0,totalDamageAbsorbs=600,totalHealAbsorbs=0,
        presence={presenceKind="summon",presenceText="Summon pending",presenceAtlas="Raid-Icon-SummonPending",
            presenceTooltip="Sample: a summon is awaiting this member's response."},
        status={readyState="waiting",connected=true,voice=true,threat=0},
        auras={helpful={aura("Divine Spirit","Spell_Holy_DivineSpirit","12m")},
            harmful={aura("Magic effect","Spell_Shadow_ShadowWordPain","8s","Magic")}}},
    {name="Elowen Moonwhisper",classToken="DRUID",level=24,roleToken="HEALER",
        health=2410,healthMax=2800,power=1920,powerMax=3100,powerToken="MANA",
        totalIncomingHeals=100,totalIncomingHealsFromHealer=100,totalDamageAbsorbs=0,totalHealAbsorbs=700,
        status={connected=false,threat=0},auras={helpful={},harmful={}}},
    {name="Kael Nightwind",classToken="ROGUE",level=24,roleToken="DAMAGER",location="Westfall",
        health=390,healthMax=2600,power=80,powerMax=100,powerToken="ENERGY",
        totalIncomingHeals=150,totalIncomingHealsFromHealer=0,totalDamageAbsorbs=180,totalHealAbsorbs=0,
        status={readyState="notready",connected=true,threat=3},
        auras={helpful={aura("Fortitude","Spell_Holy_WordFortitude","18m")},
            harmful={aura("Disease","Spell_Nature_NullifyDisease","24s","Disease")}}},
}

function Preview:GetInfo(sample,presetID)
    local preset=ns.Profiles:GetPreset(presetID)
    local info={displayName=sample.name,level=sample.level,class=sample.classToken,
        roleToken=sample.roleToken,markerIndex=sample.markerIndex,location=sample.location,
        preset=preset and preset.name or "Default"}
    for _,class in ipairs(ns.CLASSES) do if class.token==sample.classToken then info.class=class.name;break end end
    local roles={TANK=TANK or "Tank",HEALER=HEALER or "Healer",DAMAGER=DAMAGER or "Damage"}
    info.role=roles[sample.roleToken]
    info.summary=ns.MemberInfo:Summarize(info)
    for key,value in pairs(sample.presence or {}) do info[key]=value end
    return info
end
