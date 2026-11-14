local _, ns = ...
local Estimates = {cache={}, pending={}}
ns.SpellEstimates = Estimates

local function public(value, kind)
    return not ns.IsSecret(value) and type(value) == kind
end
local function validID(id)
    return public(id,"number") and id > 0 and id < math.huge and id == math.floor(id)
end
local function copy(value)
    if not value then return nil end
    return {direct=value.direct, hot=value.hot, absorb=value.absorb,
        duration=value.duration, source=value.source}
end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn,...)
    if ok then return result end
end
local function amount(text)
    if not text then return nil end
    -- Only plain integer health quantities; percentages, formulas and abbreviated
    -- numbers are not estimates. Commas must be proper English thousands groups.
    if text:find(",",1,true) then
        if not text:match("^%d%d?%d?,%d%d%d$") and not text:match("^%d%d?%d?,%d%d%d,%d%d%d$") then return nil end
    elseif not text:match("^%d+$") then return nil end
    local value = tonumber((text:gsub(",","")))
    if value and value > 0 and value <= 100000000 then return value end
end

-- Intentionally a small grammar, not a scan for the first number in a tooltip.
-- An unsupported sentence produces no strip instead of a misleading estimate.
function Estimates:ParseDescription(description, locale)
    if not public(locale,"string") or (locale ~= "enUS" and locale ~= "enGB") then return nil end
    if not public(description,"string") or #description == 0 or #description > 4096 then return nil end
    local text = description:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower()
    text = text:gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
    if text:find("%d%.%d") then return nil end
    for _, forbidden in ipairs({"%%","channel","every ","per second","group","nearby","allies","jump","additional target","up to ","depending","based on","maximum health","max health"}) do
        if text:find(forbidden) then return nil end
    end
    local result = {direct=0,hot=0,absorb=0,source="spell description"}
    local sentence = text:match("^(.-)%.") or text
    local healing = sentence:match("^heals a friendly target (.+)$")
        or sentence:match("^a slow casting spell that heals a single target (.+)$")
        or sentence:match("^heals the target (.+)$")
        or sentence:match("^heal a friendly target (.+)$")
        or sentence:match("^heal the target (.+)$")
        or sentence:match("^heal your target (.+)$")
        or sentence:match("^heals your target (.+)$")
    if healing then
        healing = healing:gsub("^of ","for "):gsub(" health",""):gsub(" damage","")
        local low, high, hot, duration = healing:match("^for ([%d,]+) to ([%d,]+) and another ([%d,]+) over (%d+) sec%a*$")
        if low then
            result.direct, result.hot, result.duration = amount(low), amount(hot), amount(duration)
            local upper = amount(high)
            if not result.direct or not upper or upper < result.direct or not result.hot or not result.duration then return nil end
        else
            hot, duration = healing:match("^for ([%d,]+) over (%d+) sec%a*$")
            if hot then
                result.hot, result.duration = amount(hot), amount(duration)
                if not result.hot or not result.duration then return nil end
            else
                low, high = healing:match("^for ([%d,]+) to ([%d,]+)$")
                if low then
                    result.direct = amount(low)
                    local upper = amount(high)
                    if not result.direct or not upper or upper < result.direct then return nil end
                else
                    result.direct = amount(healing:match("^for ([%d,]+)$"))
                    if not result.direct then return nil end
                end
            end
        end
        -- Other healing clauses could make the first sentence only a partial
        -- description. Decline rather than silently misrepresent such spells.
        local rest = text:sub(#sentence+1)
        if rest:find("heal") or rest:find("absorb") then return nil end
    else
        local shield = sentence:match("^draws on the soul of the party member to shield them, absorbing ([%d,]+) damage$")
            or sentence:match("^shields the target, absorbing ([%d,]+) damage$")
            or sentence:match("^shields a friendly target, absorbing ([%d,]+) damage$")
        if not shield then return nil end
        result.absorb = amount(shield)
        if not result.absorb then return nil end
        result.duration = amount(text:match("lasts (%d+) sec"))
    end
    return result
end

function Estimates:Get(id)
    if not validID(id) then return nil end
    if self.cache[id] ~= nil then return copy(self.cache[id]) end
    -- Protected combat aura data is never a source for estimates. Cache only
    -- public spell descriptions, retaining the exact assigned rank's ID.
    if ns.InCombat() then return nil end
    local description = call(C_Spell and C_Spell.GetSpellDescription,id)
    if public(description,"string") and description ~= "" then
        local result = self:ParseDescription(description,call(GetLocale))
        self.cache[id] = result or false
        return copy(result)
    end
    self.cache[id] = false
    if not self.pending[id] and C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
        self.pending[id] = true
        pcall(C_Spell.RequestLoadSpellData,id)
    end
    return nil
end

function Estimates:Invalidate(id)
    if ns.IsSecret(id) then return end
    if id == nil then self.cache = {}; return end
    if validID(id) then self.cache[id] = nil end
end

function Estimates:OnSpellDataLoadResult(id, success)
    if not validID(id) or not public(success,"boolean") then return end
    self.pending[id] = nil
    if success then self.cache[id] = nil end
end
