local _, ns = ...
local Assignments = { members = {} }
ns.Assignments = Assignments

local function public(value, kind)
    return not ns.IsSecret(value) and type(value) == kind
end

function Assignments:Identity(unit)
    local guid = UnitGUID(unit)
    if public(guid, "string") and guid ~= "" then return "guid:" .. guid end
    local name, realm = UnitName(unit)
    if not public(name, "string") or name == "" or name == UNKNOWN or name == UNKNOWNOBJECT then return nil end
    if ns.IsSecret(realm) then return nil end
    if not realm or realm == "" then realm = GetRealmName() end
    if not public(realm, "string") or realm == "" then return nil end
    return "name:" .. name .. "-" .. realm:gsub("%s+", "")
end

function Assignments:Init(db)
    self.db, self.members, self.ready = db, {}, false
    self.previousSession = type(db.session) == "table" and db.session or {}
    db.remembered = type(db.remembered) == "table" and db.remembered or {}
end

-- PLAYER_ENTERING_WORLD distinguishes a UI reload from a new login. Only
-- reloads restore the current party choices without another confirmation.
function Assignments:BeginSession(isReload)
    if self.ready then return end
    self.owner = self:Identity("player")
    if not self.owner then return end
    local remembered = self.db.remembered[self.owner]
    self.memory = type(remembered) == "table" and remembered or {}
    self.db.remembered[self.owner] = self.memory
    local old = self.previousSession
    self.resume = isReload and old.owner == self.owner and type(old.members) == "table" and old.members or {}
    self.ready = true
    self:PrunePresets()
end

function Assignments:Save()
    if not self.ready then return end
    local saved = {}
    for key, member in pairs(self.members) do
        saved[key] = { presetID = member.presetID }
        if member.pending then
            saved[key].pending = { presetID = member.pending.presetID, remaining = member.pending.remaining }
        end
    end
    -- Keep unresolved reload members until a complete roster arrives.
    for key, entry in pairs(self.resume or {}) do if not saved[key] then saved[key] = entry end end
    self.db.session = { owner = self.owner, members = saved }
end

function Assignments:PrunePresets()
    if not self.ready then return end
    for key, id in pairs(self.memory) do
        if type(key) ~= "string" or not ns.Profiles:GetPreset(id) then self.memory[key] = nil end
    end
    for _, member in pairs(self.members) do
        if not ns.Profiles:GetPreset(member.presetID) then member.presetID = "default" end
        if member.pending and not ns.Profiles:GetPreset(member.pending.presetID) then member.pending = nil end
    end
    self:Save()
end

function Assignments:Sync(roster, complete)
    if not self.ready or ns.InCombat() then return false end
    local seen = {}
    for _, entry in ipairs(roster) do
        local key = entry.key
        if key then
            seen[key] = true
            local member = self.members[key]
            if not member then
                member = { presetID = "default" }
                local old = self.resume[key]
                if type(old) == "table" and ns.Profiles:GetPreset(old.presetID) then
                    member.presetID = old.presetID
                    local pending = old.pending
                    if type(pending) == "table" and ns.Profiles:GetPreset(pending.presetID)
                        and type(pending.remaining) == "number" and pending.remaining > 0 then
                        member.pending = { presetID = pending.presetID, remaining = math.min(10, pending.remaining) }
                    end
                else
                    local remembered = self.memory[key]
                    if remembered ~= "default" and ns.Profiles:GetPreset(remembered) then
                        member.pending = { presetID = remembered, remaining = 10 }
                    end
                end
                self.resume[key] = nil
                self.members[key] = member
            end
            member.name = entry.name
        end
    end
    if complete then
        for key in pairs(self.members) do if not seen[key] then self.members[key] = nil end end
        self.resume = {}
    end
    self:PrunePresets()
    return true
end

function Assignments:GetPreset(key)
    local member = key and self.members[key]
    local id = member and member.presetID
    return ns.Profiles:GetPreset(id) and id or "default"
end

function Assignments:FindUnit(key)
    if not key or IsInRaid() then return nil end
    for index = 1, 4 do
        local unit = "party" .. index
        if self:Identity(unit) == key then return unit end
    end
end

function Assignments:Assign(key, presetID)
    if ns.InCombat() then return false, "Assign presets after combat ends." end
    local member = self.members[key]
    if not member or not self:FindUnit(key) then return false, "That player is no longer in your party." end
    if not ns.Profiles:GetPreset(presetID) then return false, "That preset no longer exists." end
    member.presetID, member.pending = presetID, nil
    self.memory[key] = presetID
    self:Save()
    if ns.OnProfileChanged then ns.OnProfileChanged(presetID) end
    return true
end

function Assignments:Confirm(key, expectedPreset)
    local member = self.members[key]
    if not member or not member.pending or member.pending.presetID ~= expectedPreset then
        return false, "That preset suggestion has expired."
    end
    return self:Assign(key, expectedPreset)
end

function Assignments:KeepDefault(key)
    if ns.InCombat() then return false end
    local member = self.members[key]
    if not member or not member.pending then return false end
    -- Declining a suggestion does not erase the last explicit choice.
    member.pending = nil
    self:Save()
    return true
end

function Assignments:Advance(key, elapsed)
    if ns.InCombat() then return end
    local member = self.members[key]
    if not member or not member.pending then return end
    member.pending.remaining = math.max(0, member.pending.remaining - elapsed)
    if member.pending.remaining == 0 then member.pending = nil end
    self:Save()
end
