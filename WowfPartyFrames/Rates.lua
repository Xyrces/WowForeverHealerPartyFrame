local _, ns = ...
local Rates = { units = {}, guids = {}, streams = {}, status = "Not initialized" }
ns.Rates = Rates
local WINDOW = ns.WINDOW_SECONDS or 5
local CAPACITY = 8192
local EVENT = "COMBAT_LOG_EVENT_UNFILTERED"
local function secret(value)
    return ns.IsSecret and ns.IsSecret(value) or false
end
local function number(value)
    return not secret(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end
local function newStream()
    return { entries = {}, first = 1, last = 0, healing = 0, damage = 0 }
end
local function prune(stream, now)
    while stream.first <= stream.last do
        local entry = stream.entries[stream.first]
        if entry.time > now - WINDOW then break end
        stream.healing = stream.healing - entry.healing
        stream.damage = stream.damage - entry.damage
        stream.entries[stream.first] = nil
        stream.first = stream.first + 1
    end
    if stream.first > stream.last then
        stream.first, stream.last, stream.healing, stream.damage = 1, 0, 0, 0
    end
end
local function add(stream, now, healing, damage)
    prune(stream, now)
    if stream.last - stream.first + 1 >= CAPACITY then return false end
    -- Compact indices so even a continuously busy stream stays bounded.
    if stream.last >= CAPACITY * 2 then
        local entries, count = {}, 0
        for i = stream.first, stream.last do
            count = count + 1
            entries[count] = stream.entries[i]
        end
        stream.entries, stream.first, stream.last = entries, 1, count
    end
    stream.last = stream.last + 1
    stream.entries[stream.last] = { time = now, healing = healing, damage = damage }
    stream.healing, stream.damage = stream.healing + healing, stream.damage + damage
    return true
end
-- CLEU header occupies fields 1..11. Damage amounts already exclude absorbs;
-- overkill is included, and healing amounts include overhealing.
local function decode(event)
    local kind = event[2]
    if secret(kind) then return nil, "Combat data restricted" end
    if type(kind) ~= "string" then return nil, "Invalid combat data" end
    local amountIndex, excessIndex, heal
    if kind == "SPELL_HEAL" or kind == "SPELL_PERIODIC_HEAL" then
        amountIndex, excessIndex, heal = 15, 16, true
    elseif kind == "SWING_DAMAGE" then
        amountIndex, excessIndex = 12, 13
    elseif kind == "ENVIRONMENTAL_DAMAGE" then
        amountIndex, excessIndex = 13, 14
    elseif kind == "SPELL_DAMAGE" or kind == "SPELL_PERIODIC_DAMAGE"
        or kind == "RANGE_DAMAGE" or kind == "DAMAGE_SHIELD" or kind == "DAMAGE_SPLIT" then
        amountIndex, excessIndex = 15, 16
    else
        return nil
    end
    -- Cast starts, aura events, and other irrelevant events may have no
    -- destination. They must not repeatedly erase a valid rolling window.
    local guid = event[8]
    if secret(guid) then return nil, "Combat data restricted" end
    if type(guid) ~= "string" then return nil, "Invalid combat data" end
    local amount, excess = event[amountIndex], event[excessIndex]
    if secret(amount) or secret(excess) then return nil, "Combat data restricted" end
    if not number(amount) or not number(excess) then return nil, "Invalid combat data" end
    local effective = math.max(0, amount - math.max(0, excess))
    return { guid = guid, healing = heal and effective or 0, damage = heal and 0 or effective }
end
Rates.Test = { NewStream = newStream, Add = add, Prune = prune, Decode = decode, Capacity = CAPACITY }

function Rates:Reset()
    self.streams = {}
    self.started = nil
    self.lastTime = nil
end

function Rates:SetUnits(units)
    local copied = {}
    for _, unit in ipairs(units or {}) do
        if type(unit) == "string" then copied[#copied + 1] = unit end
    end
    self.units = copied
    self:Reset()
    self.guids = {}
end

local function capability()
    -- This target supplies an explicit restriction query. Without it we cannot
    -- establish permission to subscribe; never probe a restricted event blindly.
    if not C_CombatLog or type(C_CombatLog.IsCombatLogRestricted) ~= "function" then
        return "Combat log permission unknown"
    end
    local ok, restricted = pcall(C_CombatLog.IsCombatLogRestricted)
    if not ok or secret(restricted) or type(restricted) ~= "boolean" then return "Combat log permission unknown" end
    if restricted then return "Combat data restricted" end
    -- Prefer the public namespace when a client exposes it. Forever moves
    -- the reader to a SecureOnly API; never call C_CombatLogSecure or infer
    -- separate incoming healing/damage from HP changes or outgoing HPS.
    local reader = C_CombatLog.GetCurrentEventInfo
    if type(reader) ~= "function" then reader = CombatLogGetCurrentEventInfo end
    if type(reader) ~= "function" then return "Client does not expose incoming combat events" end
    return "available", reader
end

function Rates:Tick()
    if not self.frame then return end
    local status, reader = capability()
    self.reader = reader
    if status ~= self.status then
        self:Reset()
        self.status = status
    end
    if status ~= "available" then
        if self.registered then
            pcall(self.frame.UnregisterEvent, self.frame, EVENT)
            self.registered = false
        end
        return
    end
    if not self.registered then
        local ok = pcall(self.frame.RegisterEvent, self.frame, EVENT)
        local checked, registered = pcall(self.frame.IsEventRegistered, self.frame, EVENT)
        if not ok or not checked or secret(registered) or not registered then
            self.status = "Combat log unavailable"
            return
        end
        self.registered = true
    end
    local now = GetTime()
    if not number(now) then self.status = "Clock unavailable"; self:Reset(); return end
    if self.lastTime and now < self.lastTime then self:Reset() end
    self.lastTime = now
    local guids, changed = {}, false
    for _, unit in ipairs(self.units) do
        local ok, guid = pcall(UnitGUID, unit)
        if not ok or secret(guid) then
            self.status = "Unit data restricted"; self:Reset(); return
        end
        if type(guid) == "string" then guids[unit] = guid end
        if guids[unit] ~= self.guids[unit] then changed = true end
    end
    if changed then self:Reset(); self.lastTime = now end
    self.guids = guids
    self.started = self.started or now
    for _, stream in pairs(self.streams) do prune(stream, now) end
end

function Rates:Get(unit)
    self:Tick()
    if self.status ~= "available" then return nil, nil, nil, self.status end
    local guid = self.guids[unit]
    if not guid then return nil, nil, nil, "Unit unavailable" end
    if not self.started or self.lastTime - self.started < WINDOW then
        return nil, nil, nil, "Collecting rates"
    end
    local stream = self.streams[guid]
    local healing = stream and stream.healing / WINDOW or 0
    local damage = stream and stream.damage / WINDOW or 0
    return healing, damage, healing - damage, "available"
end

function Rates:OnCombatEvent()
    self:Tick()
    if self.status ~= "available" then return end
    local function read() return { self.reader() } end
    local ok, event = pcall(read)
    if not ok then self.status = "Combat log unavailable"; self:Reset(); return end
    local entry, reason = decode(event)
    if reason then self.status = reason; self:Reset(); return end
    if not entry then return end
    local tracked = false
    for _, guid in pairs(self.guids) do if guid == entry.guid then tracked = true; break end end
    if not tracked then return end
    local stream = self.streams[entry.guid]
    if not stream then stream = newStream(); self.streams[entry.guid] = stream end
    if not add(stream, self.lastTime, entry.healing, entry.damage) then
        self:Reset() -- Unknown after overflow; collect an entirely new window.
    end
end

function Rates:Initialize()
    if self.frame then return end
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event)
        if event == EVENT then self:OnCombatEvent()
        else self:Reset(); self:Tick() end
    end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
    self:Tick()
end
