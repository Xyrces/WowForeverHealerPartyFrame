local _, ns = ...
local History = {}
ns.HealthHistory = History

local COUNT, DEFAULT_INTERVAL = 12, 0.25
local EPSILON = 0.000001
History.SAMPLE_INTERVALS = {0.25, 0.5, 1, 2, 5}
local cards = setmetatable({}, {__mode="k"})
local stops = {{0,200,50,55},{0.15,226,68,65},{0.45,235,139,50},
    {0.70,222,203,68},{0.90,64,191,96},{1,64,191,96}}
local curve, curveAttempted, colorAvailable
local function secret(value) return issecretvalue and issecretvalue(value) or false end
local function publicNumber(value)
    return not secret(value) and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end
local function publicString(value)
    return not secret(value) and type(value) == "string" and value ~= ""
end
local function validInterval(value)
    return publicNumber(value) and value >= DEFAULT_INTERVAL and publicNumber(value * COUNT)
end

function History:GetSampleInterval()
    local value = ns.db and ns.db.historySampleInterval
    return validInterval(value) and value or DEFAULT_INTERVAL
end

function History:GetWindowSeconds()
    return COUNT * self:GetSampleInterval()
end

function History:SetSampleInterval(seconds)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Change the history step after combat ends."
    end
    if not validInterval(seconds) then
        return false, "Enter a finite history step of at least 0.25 seconds."
    end
    local previous = self:GetSampleInterval()
    ns.db = ns.db or {}
    ns.db.historySampleInterval = seconds
    if previous ~= seconds then
        for card in pairs(cards) do
            self:Clear(card)
            local state = card.healthHistory
            state.interval = seconds
            state.retryAt, state.retryIdentity = nil, nil
        end
        self.reason = nil
    end
    return true
end

function History:SetWindowSeconds(seconds)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Change the history duration after combat ends."
    end
    if not publicNumber(seconds) or seconds < COUNT * DEFAULT_INTERVAL then
        return false, "Enter a finite total history of at least 3 seconds."
    end
    -- Keep only the interval in saved variables so the two settings cannot
    -- drift apart; the twelve visible rows determine the total duration.
    return self:SetSampleInterval(seconds / COUNT)
end

local function identityOf(card, unit)
    local guid = UnitGUID(unit)
    local readableGUID = publicString(guid) and guid or nil
    if card.header then
        -- The secure name-list header remains bound to this member in combat,
        -- even when the client hides GUIDs. Reuse only its verified public
        -- roster identity, never a unit token as a substitute player identity.
        local key, name = card.memberKey, card.memberName
        local filter, boundUnit = card.header:GetAttribute("nameList"), card:GetAttribute("unit")
        if not publicString(key) or not publicString(name) or not publicString(filter)
            or filter ~= name or not publicString(boundUnit) or boundUnit ~= unit then return nil end
        if readableGUID and key:sub(1, 5) == "guid:" and key ~= "guid:" .. readableGUID then return nil end
        return key, readableGUID
    end
    return readableGUID, readableGUID
end
local function initializeCurve()
    if curveAttempted then return end
    curveAttempted = true
    local ok, result = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        c:SetType(Enum.LuaCurveType.Linear)
        for _, stop in ipairs(stops) do
            c:AddPoint(stop[1], CreateColor(stop[2]/255, stop[3]/255, stop[4]/255, 1))
        end
        return c
    end)
    if ok and type(UnitHealthPercent) == "function" then curve, colorAvailable = result, true end
end

local function render(state)
    -- Mark dirty before painting so even a partially failed native update is
    -- cleared. Hidden/empty cards can otherwise skip all repeated UI writes.
    state.cleared = false
    local offset = COUNT - #state.samples
    for index, row in ipairs(state.rows) do
        local sample = state.samples[index - offset]
        if sample then
            -- Opaque health and color values only travel to native setters.
            row:SetMinMaxValues(0, sample.maximum)
            row:SetValue(sample.health)
            row:SetStatusBarColor(sample.color[1], sample.color[2], sample.color[3], 1)
            row:SetAlpha(0.25 + 0.4 * index / COUNT)
        else
            row:SetValue(0)
            row:SetAlpha(0)
        end
    end
    state.holder:SetAlpha(#state.samples > 0 and 1 or 0)
end

function History:Clear(card)
    local state = card and card.healthHistory
    if not state then return end
    state.identity, state.last, state.preview, state.guid = nil, nil, nil, nil
    if state.cleared then return end
    state.samples, state.cleared = {}, true
    -- Clearing must remain safe even after a native paint call fails.
    if state.holder then pcall(state.holder.SetAlpha, state.holder, 0) end
    for _, row in ipairs(state.rows) do
        pcall(row.SetAlpha, row, 0)
        pcall(row.SetValue, row, 0)
    end
end

function History:Create(card)
    if card.healthHistory then return card.healthHistory.supported end
    if InCombatLockdown and InCombatLockdown() then return false end
    initializeCurve()
    local state = {rows={}, samples={}, supported=false, interval=self:GetSampleInterval()}
    card.healthHistory = state
    cards[card] = true
    local ok = pcall(function()
        local holder = CreateFrame("Frame", nil, card.health)
        state.holder = holder
        holder:SetFrameLevel(card.health:GetFrameLevel() + 2)
        holder:SetSize(ns.Layout.barWidth, COUNT)
        holder:SetPoint("BOTTOMLEFT", card.health, "TOPLEFT", 0, 5)
        holder:EnableMouse(false)
        holder:SetClipsChildren(true)
        holder:SetAlpha(0)
        for index = 1, COUNT do
            local row = CreateFrame("StatusBar", nil, holder)
            state.rows[index] = row
            row:SetFrameLevel(holder:GetFrameLevel())
            row:SetSize(ns.Layout.barWidth, 1)
            row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(index - 1))
            row:EnableMouse(false)
            row:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            row:SetMinMaxValues(0, 1)
            row:SetValue(0)
            row:SetAlpha(0)
        end
    end)
    state.supported = ok
    if ok then state.cleared = true end
    if not ok then self:Clear(card); self.reason = "unavailable: native setup failed" end
    return ok
end

function History:Update(card, unit, now)
    local state = card and card.healthHistory
    if not state or not state.supported then return false end
    now = now or GetTime()
    if not publicNumber(now) then self:Clear(card); return false end
    local interval = self:GetSampleInterval()
    -- Do not mix rows sampled at different cadences, including when a saved
    -- setting is restored by another part of the addon between updates.
    if state.interval ~= interval then
        self:Clear(card)
        state.interval = interval
        state.retryAt, state.retryIdentity = nil, nil
    end
    -- Identity queries can fail before there is a member key to compare.
    -- Back off those native failures too, without re-entering their APIs.
    if state.retryAt and not state.retryIdentity and now + EPSILON < state.retryAt then return false end
    local attemptedIdentity
    local ok, updated = pcall(function()
        if secret(unit) or type(unit) ~= "string" or not unit:match("^party[1-4]$") then
            self:Clear(card); return false
        end
        local exists = UnitExists(unit)
        local connected = UnitIsConnected and UnitIsConnected(unit)
        local identity, guid = identityOf(card, unit)
        if secret(exists) or not exists or (not secret(connected) and connected == false)
            or not identity then
            self:Clear(card); return false
        end
        if state.identity ~= identity or state.preview or (guid and state.guid and guid ~= state.guid) then self:Clear(card) end
        if state.last and (now < state.last or now - state.last + EPSILON >= COUNT * interval) then self:Clear(card) end
        state.identity = identity
        if guid then state.guid = guid end
        attemptedIdentity = identity
        if state.retryIdentity == identity and state.retryAt and now + EPSILON < state.retryAt then return false end
        state.retryAt, state.retryIdentity = nil, nil
        if state.last and now - state.last + EPSILON < interval then return false end
        local health, maximum = UnitHealth(unit, false), UnitHealthMax(unit)
        if (not secret(health) and (not publicNumber(health) or health < 0))
            or (not secret(maximum) and (not publicNumber(maximum) or maximum <= 0)) then
            self:Clear(card)
            state.retryAt, state.retryIdentity = now + interval, identity
            self.reason = "unavailable: health data missing"; return false
        end
        local color = {64/255,191/255,96/255}
        if curve then
            local colorOK, r, g, b = pcall(function()
                return UnitHealthPercent(unit, false, curve):GetRGB()
            end)
            colorAvailable = colorOK
            if colorOK then color = {r,g,b} end
        end
        -- Keep real history through brief stalls without manufacturing samples
        -- for missed sampling slots. False is an explicit blank row. A tiny
        -- clock tolerance prevents fractional steps from losing a row
        -- because subtraction lands just below the exact interval.
        if state.last then
            local missed = math.floor((now - state.last + EPSILON) / interval) - 1
            for _ = 1, missed do state.samples[#state.samples + 1] = false end
        end
        state.samples[#state.samples + 1] = {health=health, maximum=maximum, color=color}
        while #state.samples > COUNT do table.remove(state.samples, 1) end
        state.last = now
        render(state)
        self.reason = nil
        return true
    end)
    if not ok then
        self:Clear(card)
        state.retryAt, state.retryIdentity = now + interval, attemptedIdentity
        self.reason = "unavailable: native update failed"
    end
    return ok and updated
end

-- Only this explicit preview path performs public sample arithmetic.
function History:Preview(card, currentHP, maximum)
    local state = card and card.healthHistory
    if not state or not state.supported then return false end
    if not publicNumber(currentHP) or not publicNumber(maximum) or maximum <= 0 then
        self:Clear(card); return false
    end
    if state.preview and state.previewHP == currentHP and state.previewMax == maximum then return true end
    self:Clear(card)
    state.retryAt, state.retryIdentity = nil, nil
    state.preview, state.previewHP, state.previewMax = true, currentHP, maximum
    for index = 1, COUNT do
        local fraction = math.max(0, math.min(1, currentHP / maximum + (COUNT-index) * 0.018))
        local color
        for s = 2, #stops do
            if fraction <= stops[s][1] then
                local low, high = stops[s-1], stops[s]
                local blend = (fraction - low[1]) / (high[1] - low[1])
                color = {}
                for channel = 2, 4 do color[channel-1] = (low[channel] + (high[channel]-low[channel])*blend)/255 end
                color[4] = 1
                break
            end
        end
        state.samples[index] = {health=fraction*maximum,maximum=maximum,color=color}
    end
    render(state)
    return true
end

function History:GetStatus()
    if self.reason then return self.reason end
    if not curveAttempted then return "not initialized" end
    return string.format("%gs samples / %gs history; ", self:GetSampleInterval(), self:GetWindowSeconds())
        .. (colorAvailable and "native health colors" or "uniform green (native color curve unavailable)")
end
