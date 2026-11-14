assert(loadfile("tests/wow_ui_fake.lua"))()()
local ns, checks = {}, 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
assert(loadfile("WowfPartyFrames/Bootstrap.lua"))("WowfPartyFrames", ns)
assert(loadfile("WowfPartyFrames/FrameVisuals.lua"))("WowfPartyFrames", ns)
local card = CreateFrame("Frame", nil, UIParent)
ns.Visuals:DecorateUnit(card)
local function x(region) return region.point[#region.point - 1] end
equal(x(card.health), x(card.power), "health and power left edges align")
equal(card.health:GetWidth(), card.power:GetWidth(), "health and power widths align")
local function y(region) return region.point[#region.point] end
local L=ns.Layout
equal(L.historyHeight,12,"history reserves exactly twelve UI pixels")
equal(y(card.health),-44,"health shifts down to fit history")
equal(y(card.power),-58,"resource bar shifts with native trim")
equal(card.health:GetHeight(),12,"main health height remains unchanged")
equal(card.power:GetHeight(),10,"resource height remains unchanged")
equal(L.pitch,138,"member spacing includes the history band")
equal(y(card.memberInfo)-9 > y(card.health)+5+L.historyHeight,true,"details clear the top of history")
equal(y(card.memberInfo) - 9 > y(card.health),true,"member details fit above health trim")
equal(y(card.location) < L.buffY-L.auraSize,true,"remote location stays below buffs")
equal(x(card.presetLabel),x(card.portraitArea),"preset is aligned with portrait")
equal(y(card.presetLabel) < y(card.portraitArea)-L.portrait,true,"preset clears healing controls")
equal(-y(card.location)+8 <= L.height,true,"remote location fits within member frame")
equal(card.activeBuffs,nil,"buffs have one shared display/action row")
card.name:SetText("Member")
card.memberInfo:SetText("24 Druid · Healer")
ns.Visuals:PaintIdentityIcons(card,nil,nil)
equal(card.roleIcon:IsShown(),false,"no role guessed from class")
equal(card.markerIcon:IsShown(),false,"no marker placeholder")
equal(card.memberInfo:GetWidth(),L.barWidth,"unassigned icons reserve no detail width")
for marker=1,8 do
    ns.Visuals:PaintIdentityIcons(card,"HEALER",marker)
    equal(card.roleIcon.atlas,"roleicon-tiny-healer")
    equal(card.markerIcon.spriteCell[1],marker,"native sprite selector receives assigned marker")
    equal(card.markerIcon.spriteCell[2],4)
    equal(card.markerIcon.spriteCell[3],4)
    equal(x(card.markerIcon)>=x(card.roleIcon)+card.roleIcon:GetWidth(),true,"icons do not overlap")
end
card.memberInfo.measuredWidth=1000
ns.Visuals:PaintIdentityIcons(card,"TANK",8)
equal(x(card.markerIcon)+12<=L.barX+L.barWidth,true,"long detail text cannot push icons outside bars")
equal(y(card.status)>y(card.markerIcon),true,"status stays on the name line above assigned icons")
equal(x(card.name)+card.name:GetWidth()<x(card.status),true,"name cannot overlap status")
equal(y(card.markerIcon)-card.markerIcon:GetHeight()>y(card.health)+5+L.historyHeight,true,"inline icons clear the top of history")
local originalSecret=ns.IsSecret
ns.IsSecret=function(value) return value==77 end
card.memberInfo.measuredWidth=77
ns.Visuals:PaintIdentityIcons(card,"DAMAGER",77)
equal(card.markerIcon.spriteCell[1],77,"secret numeric index forwards without a range check")
equal(x(card.markerIcon)+12<=L.barX+L.barWidth,true,"secret detail width uses a bounded fallback")
ns.IsSecret=originalSecret
local selector=card.markerIcon.SetSpriteSheetCell
card.markerIcon.SetSpriteSheetCell=function() error("unavailable renderer") end
ns.Visuals:PaintIdentityIcons(card,nil,8)
equal(card.markerIcon:IsShown(),false,"failed rendering clears the old marker")
card.markerIcon.SetSpriteSheetCell=selector
ns.Visuals:PaintIdentityIcons(card,"NONE",nil)
equal(card.roleIcon:IsShown(),false,"cleared role removes its icon")
equal(card.markerIcon:IsShown(),false,"cleared marker removes its icon")
equal(card.memberInfo:GetWidth(),L.barWidth)
card.memberInfo.measuredWidth=nil
equal(L.healSize,36,"healing controls remain readable at native icon size")
equal(x(card.portraitArea) >= x(card.health)+card.health:GetWidth(),true,"portrait sits right of all bars")
equal(y(card.power)-card.power:GetHeight() > L.debuffY,true,"debuffs start below resource bar")
equal(L.debuffY-L.auraSize > L.buffY,true,"aura rows do not overlap")
equal(-L.buffY+L.auraSize<=card:GetHeight(),true,"buff row stays within member frame")
equal(L.auraX+7*L.auraPitch+L.auraSize<=L.barX+L.barWidth,true,"all eight aura icons fit under bars")
for index,button in ipairs(card.debuffs) do
    equal(button:GetWidth(),L.auraSize)
    equal(x(button)+button:GetWidth()<=x(card.portraitArea),true,"debuff icons never overlap healing controls")
    equal(y(button),L.debuffY)
    if index>1 then equal(x(button)>=x(card.debuffs[index-1])+card.debuffs[index-1]:GetWidth(),true) end
end
card.heals={}
for index=1,4 do
    local button=CreateFrame("Button",nil,card)
    button.kind,button.card="heals",card
    ns.Visuals:DecorateSpellButton(button,L.healSize)
    card.heals[index]=button
end
ns.db={controlStyle="buttons"}
ns.Visuals:ApplyControlStyle(card)
equal(card.controlStyle,"buttons")
for _,button in ipairs(card.heals) do
    equal(button:GetWidth(),36)
    equal(button:GetHeight(),36)
    equal(button.maskAttached,false,"square buttons remove circular crop")
    equal(button.icon.AddMaskTextureArgs,nil)
    equal(button.rank.font[2],10,"rank uses readable ten-point font")
    equal(y(button.rank),-26,"square rank sits inside bottom of button")
end
ns.Visuals:SetPortraitHover(card,true)
equal(card.portrait:GetAlpha(),0,"square buttons replace portrait on hover")
equal(card.portraitRim:GetAlpha(),0)
for _,button in ipairs(card.heals) do equal(button.border:GetAlpha(),1);equal(button.icon:GetAlpha(),1) end
for _,divider in ipairs(card.portraitDividers) do equal(divider:GetAlpha(),0) end
ns.db.controlStyle="quadrants"
ns.Visuals:ApplyControlStyle(card)
equal(card.controlStyle,"quadrants")
for index,button in ipairs(card.heals) do
    equal(button.maskAttached,true)
    equal(button.icon.AddMaskTextureArgs[1],button.portraitMask,"quadrants restore portrait mask")
    equal(y(button.rank),index>2 and -1 or -26,"round ranks move toward center away from cropped corners")
end
ns.Visuals:SetPortraitHover(card,true)
equal(card.portrait:GetAlpha(),1)
equal(card.portraitRim:GetAlpha(),1)
for _,button in ipairs(card.heals) do equal(button.border:GetAlpha(),0);equal(button.icon:GetAlpha(),1) end
for _,divider in ipairs(card.portraitDividers) do equal(divider:GetAlpha(),1) end
ns.db.controlStyle="buttons"
ns.Visuals:ApplyControlStyle(card)
for _,button in ipairs(card.heals) do
    equal(button.maskAttached,false,"switching back removes mask again")
    equal(y(button.rank),-26)
end
ns.Visuals:SetPortraitHover(card,false)
equal(card.portrait:GetAlpha(),1,"portrait returns when controls are not hovered")
for _,button in ipairs(card.heals) do equal(button.icon:GetAlpha(),0);equal(button.rank:GetAlpha(),0) end

print("visuals_spec: " .. checks .. " checks passed (offline geometry and portrait controls)")
