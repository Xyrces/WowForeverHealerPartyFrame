local ns = {}
assert(loadfile("WowfPartyFrames/CleanseGeometry.lua"))("WowfPartyFrames", ns)
local G, checks = ns.CleanseGeometry, 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function contains(g, x, y)
    local r = math.sqrt(x*x + y*y)
    local a, b = g.startAngle * math.pi/180, g.endAngle * math.pi/180
    return r >= g.inner - 0.000001 and r <= g.outer + 0.000001
        and math.cos(a)*y - math.sin(a)*x >= -0.000001
        and math.sin(b)*x - math.cos(b)*y >= -0.000001
end
for _,style in ipairs({"quadrants", "buttons"}) do
    for count=1,4 do
        for index=1,count do
            local g = G:Get(style,index,count)
            check(g == G:Get(style,index,count), "geometry is cached")
            check(g.outer-g.inner == 20, "consistent band thickness")
            check(g.artSize == 2 * (g.outer+4), "four pixels of glow padding")
            check(g.artOffset == -g.artSize/2, "art centered on portrait")
            check(#g.rects > 5 and #g.rects < 80, "bounded action count")
            local area = 0
            for _,r in ipairs(g.rects) do
                check(r.width>0 and r.height==2, "positive two-unit hit strips")
                -- Test corners and midpoints: catches an inner-hole crossing
                -- even if all four outer corners would individually be valid.
                for _,x in ipairs({r.x, r.x+r.width/2, r.x+r.width}) do
                    for _,y in ipairs({r.y, r.y+r.height/2, r.y+r.height}) do
                        check(contains(g,x,y), "no strip enters transparent hole, exterior or adjacent sector")
                    end
                end
                area = area + r.width*r.height
            end
            local painted = (g.endAngle-g.startAngle)*math.pi/360*(g.outer*g.outer-g.inner*g.inner)
            check(area/painted > 0.83, "hit strips cover the visible arc without oversized invisible bounds")
            check(area/painted <= 1, "hit area never exceeds visible sector")
            for angle=0,359,3 do
                local rad=angle*math.pi/180
                check(contains(g,g.iconX+9*math.cos(rad),g.iconY+9*math.sin(rad)), "round 18px spell icon remains inside sector")
            end
            if style=="buttons" then
                check(g.inner > math.sqrt(37*37+37*37), "full square healing controls have clear radial separation")
            else
                check(g.inner == 44, "circular mode preserves compact ring")
            end
        end
    end
end
check(G:Get("quadrants",1,1) == G:Get("quadrants",1,2), "one action reuses upper quadrant")
check(G:Get("quadrants",0,2)==nil and G:Get("buttons",3,2)==nil, "invalid indices rejected")
check(G:Get("buttons",1.5,2)==nil, "fractional index rejected")
print("cleanse_geometry_spec: "..checks.." geometry checks passed")
