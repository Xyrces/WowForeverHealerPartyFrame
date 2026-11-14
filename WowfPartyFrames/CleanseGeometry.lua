local _, ns = ...
local Geometry = {}
ns.CleanseGeometry = Geometry

-- Public layout constants only. None of these calculations inspect auras or
-- protected unit values. Geometry is cached and applied outside combat.
local cache = {}
local STEP, EPSILON, PADDING = 2, 0.05, 4
local RAD = math.pi / 180
local ROOT = "Interface\\AddOns\\WowfPartyFrames\\Media\\cleanse-"

function Geometry:Get(style, index, count)
    style = style == "quadrants" and "quadrants" or "buttons"
    count = math.max(1, math.min(4, math.floor(tonumber(count) or 1)))
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > count then return nil end
    -- One action occupies the upper-right quadrant rather than a half-circle.
    local segments = math.max(2, count)
    local key = style .. "-" .. segments .. "-" .. index
    if cache[key] then return cache[key] end
    local inner = style == "quadrants" and 44 or 56
    local outer = inner + 20
    local first = -90 + (index - 1) * 180 / segments + 2
    local last = -90 + index * 180 / segments - 2
    local angle = segments == 2 and (index == 1 and -30 or 30) or (first + last) / 2
    local middle = (inner + outer) / 2
    local result = {
        inner = inner, outer = outer, startAngle = first, endAngle = last,
        iconX = middle * math.cos(angle * RAD), iconY = middle * math.sin(angle * RAD),
        iconSize = 18, rects = {}, artSize = 2 * (outer + PADDING),
        artOffset = -(outer + PADDING), textureBase = ROOT .. key,
    }
    local tangentFirst, tangentLast = math.tan(first * RAD), math.tan(last * RAD)
    local inside, outside = inner + EPSILON, outer - EPSILON
    -- Each horizontal rectangle is entirely inside the painted annular sector.
    -- Constrain its closest corner against the inner radius, its furthest
    -- corner against the outer radius, then both angular half-planes. The
    -- strip boundaries meet; only a subpixel border around the arc is omitted.
    for y = -outer, outer - STEP, STEP do
        local bottom = y + STEP
        local farY = math.max(math.abs(y), math.abs(bottom))
        if farY < outside then
            local nearY = y <= 0 and bottom >= 0 and 0 or math.min(math.abs(y), math.abs(bottom))
            local left = math.sqrt(math.max(0, inside * inside - nearY * nearY))
            local right = math.sqrt(outside * outside - farY * farY)
            if tangentFirst < 0 then left = math.max(left, y / tangentFirst)
            elseif tangentFirst > 0 then right = math.min(right, y / tangentFirst) end
            if tangentLast > 0 then left = math.max(left, bottom / tangentLast)
            elseif tangentLast < 0 then right = math.min(right, bottom / tangentLast) end
            if right > left then
                result.rects[#result.rects + 1] = {x = left, y = y, width = right - left, height = STEP}
            end
        end
    end
    cache[key] = result
    return result
end
