local ns, combat, checks = {}, false, 0
local secret = setmetatable({}, {__lt=function() error("secret comparison") end, __tostring=function() error("secret string") end})
ns.IsSecret=function(value) return rawequal(value,secret) end
ns.InCombat=function() return combat end
local descriptions, calls, requests = {}, {}, {}
GetLocale=function() return "enUS" end
C_Spell={GetSpellDescription=function(id) calls[id]=(calls[id] or 0)+1; return descriptions[id] end,
    RequestLoadSpellData=function(id) requests[id]=(requests[id] or 0)+1 end}
assert(loadfile("WowfPartyFrames/SpellEstimates.lua"))("WowfPartyFrames",ns)
local E=ns.SpellEstimates
local function eq(a,b,label) checks=checks+1; assert(a==b,label or (tostring(a).." ~= "..tostring(b))) end
local cases={
    {"Heal your target for 157 to 181.",157,0,0},
    {"Heals a friendly target for 46 to 56.",46,0,0},
    {"Heals the target of 157 to 181 damage.",157,0,0},
    {"A slow casting spell that heals a single target for 899 to 1013.",899,0,0},
    {"Heals the target for 1,200 to 1,500.",1200,0,0},
    {"Heals the target of 100 damage over 15 sec.",0,100,0,15},
    {"Heals the target for 180 over 12 sec.",0,180,0,12},
    {"Heals a friendly target for 93 to 107 and another 98 over 21 sec.",93,98,0,21},
    {"Draws on the soul of the party member to shield them, absorbing 44 damage. Lasts 30 sec. While the shield holds, spellcasting will not be interrupted by damage. Once shielded, the target cannot be shielded again for 15 sec.",0,0,44,30},
    {"Shields the target, absorbing 250 damage. Lasts 30 sec.",0,0,250,30},
    {"Heals the target for |cff00ff00100|r health.",100,0,0},
}
for index,case in ipairs(cases) do
    local text=case[1]
    -- Actual Lesser Heal wording uses 'Heal your target'.
    local r=E:ParseDescription(text,"enUS")
    assert(r,"missing parse case "..index)
    eq(r.direct,case[2]);eq(r.hot,case[3]);eq(r.absorb,case[4]);eq(r.duration,case[5]);eq(r.source,"spell description")
end
for _,text in ipairs({
    "75 Mana 40 yard range. Heals the target for 100.",
    "Heals all party members for 100.",
    "Heals the target for 100 to 120, then jumps to additional targets.",
    "Heals the target for 100 every 2 sec for 8 sec.",
    "Heals the target for 10% of maximum health.",
    "Heals the target for 1.5k.",
    "Heals the target for 12,34.",
    "Heals the target for 120 to 100.",
    "Heals the target for 0.",
    "Heals the target for 100. Also heals another target for 50.",
    "Heals the target for 100 over 15 sec. Channeled.",
    "Increases Stamina by 10 for 30 min.",
    "Heals the target for $s1 to $s2.",
    string.rep("x",4097),
}) do eq(E:ParseDescription(text,"enUS"),nil,text) end
eq(E:ParseDescription(secret,"enUS"),nil)
eq(E:ParseDescription("Heals the target for 100.",secret),nil)
eq(E:ParseDescription("Heals the target for 100.","deDE"),nil)
descriptions[1]="Heals the target for 100 to 120."
descriptions[2]="Heals the target for 200 to 220."
eq(E:Get(1).direct,100);eq(E:Get(2).direct,200)
local r=E:Get(1);r.direct=999;eq(E:Get(1).direct,100)
eq(calls[1],1,"cached query")
combat=true
descriptions[1]="Heals the target for 300 to 320."
eq(E:Get(1).direct,100,"combat uses public warmed estimate")
eq(E:Get(3),nil);eq(calls[3],nil,"no combat query")
E:Invalidate(1);eq(E:Get(1),nil,"invalidated data never used in combat")
combat=false
eq(E:Get(1).direct,300,"refresh after invalidation")
eq(E:Get(3),nil);eq(E:Get(3),nil);eq(calls[3],1);eq(requests[3],1)
descriptions[3]="Heals the target for 400."
E:OnSpellDataLoadResult(3,true);eq(E:Get(3).direct,400,"async exact ID completion")
descriptions[4]=secret
eq(E:Get(4),nil);eq(E:Get(secret),nil);eq(E:Get(0),nil);eq(E:Get(math.huge),nil);eq(E:Get(1.5),nil)
descriptions[5]="Unsupported spell."
eq(E:Get(5),nil);eq(E:Get(5),nil);eq(calls[5],1,"unsupported descriptions negatively cached")
eq(requests[5],nil,"loaded unsupported description never requests reload")
E:Invalidate();eq(E:Get(2).direct,200);eq(calls[2],2)
print("spell_estimates_spec: "..checks.." checks passed")
