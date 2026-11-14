-- Exercise real history settings and EditBox event ordering. The fake's base
-- ClearFocus does not dispatch events; add that native behavior locally here.
local ui = assert(loadfile("tests/wow_ui_fake.lua"))()()
local focused
function ui.methods:HasFocus() return self.focused == true end
function ui.methods:SetFocus()
    if focused and focused ~= self then focused:ClearFocus() end
    focused, self.focused = self, true
end
function ui.methods:ClearFocus()
    local wasFocused = self.focused
    self.focused = false
    if focused == self then focused = nil end
    if wasFocused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end

local checks, failures = 0, {}
local function eq(actual, expected, message)
    checks = checks + 1
    if not rawequal(actual, expected) then
        failures[#failures + 1] = (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected)
    end
end
local function contains(text, needle, message)
    eq(type(text)=="string" and text:find(needle,1,true)~=nil,true,message)
end
local ns = {}
for _,name in ipairs({"Bootstrap","Profiles","HealthHistory","Settings"}) do
    assert(loadfile("WowfPartyFrames/"..name..".lua"))("WowfPartyFrames",ns)
end
ns.db = ns.Profiles:Init({})
ns.Spells = {Get=function() return nil end}
local redraws = 0
ns.Frames = {RefreshAll=function(_,refreshAuras)
    redraws=redraws+1
    eq(refreshAuras,false,"history preference redraw does not force an aura scan")
end}
local S,H = ns.Settings,ns.HealthHistory
local panel=S:Create()
panel:Show()
local step,total=panel.historyStep,panel.historyTotal
local commits=0
local setValue=S.SetHistoryValue
function S:SetHistoryValue(field,value)
    commits=commits+1
    return setValue(self,field,value)
end
local function press(edit,event) edit:GetScript(event)(edit) end
local function display(actualStep,actualTotal)
    eq(step:GetText(),string.format("%.6g",actualStep),"step display follows saved interval")
    eq(total:GetText(),string.format("%.6g",actualTotal),"total display follows twelve samples")
end

display(.25,3)
eq(S:SetHistoryValue("total","10"),true)
eq(ns.db.historySampleInterval,10/12,"total input preserves exact divided value")
display(10/12,10)
eq(S:SetHistoryValue("step","0.5"),true)
eq(H:GetWindowSeconds(),6)
display(.5,6)
eq(S:SetHistoryValue("unsupported","1"),false)
eq(ns.db.historySampleInterval,.5)

-- Refreshing spells, presets or the panel must not overwrite a pending edit.
step:SetFocus();step:SetText("0.8123456789012")
S:Refresh()
eq(step:GetText(),"0.8123456789012","unrelated refresh preserves focused edit")
eq(step.savedText,"0.5","savedText remains the persisted value, not uncommitted text")
eq(total:GetText(),"6")
local before=commits
press(step,"OnEnterPressed")
eq(commits,before+1,"Enter followed by native focus loss commits exactly once")
eq(ns.db.historySampleInterval,tonumber("0.8123456789012"),"display rounding cannot alter committed precision")
eq(step:HasFocus(),false,"successful Enter leaves edit focus")
display(tonumber("0.8123456789012"),tonumber("0.8123456789012")*12)

total:SetFocus();total:SetText("10.0000")
before=commits
press(total,"OnEnterPressed")
eq(commits,before+1,"noncanonical total text still commits only once")
eq(ns.db.historySampleInterval,10/12)
display(10/12,10)

-- Merely accepting a rounded display must preserve the underlying exact value.
step:SetFocus();before=commits
press(step,"OnEnterPressed")
eq(commits,before,"unchanged Enter is not a new assignment")
eq(ns.db.historySampleInterval,10/12,"Enter cannot round a value set through total")
step:SetFocus();before=commits;step:ClearFocus()
eq(commits,before,"unchanged focus loss is not a new assignment")
eq(ns.db.historySampleInterval,10/12)

step:SetFocus();step:SetText("1.125");before=commits
step:ClearFocus()
eq(commits,before+1,"changed focus loss commits once")
eq(ns.db.historySampleInterval,1.125)
display(1.125,13.5)
eq(S:SetHistoryValue("total","10"),true)
step:SetFocus();step:SetText("2.75");before=commits
press(step,"OnEscapePressed")
eq(commits,before,"Escape cancels without invoking the setter")
eq(step:HasFocus(),false)
eq(ns.db.historySampleInterval,10/12,"Escape does not round the saved interval")
display(10/12,10)

-- Invalid values leave their error visible and retain the previous history.
step:SetFocus();step:SetText("0.24");before=redraws
press(step,"OnEnterPressed")
eq(ns.db.historySampleInterval,10/12)
eq(step:HasFocus(),true,"invalid Enter keeps focus for correction")
contains(panel.note:GetText(),"0.25","minimum-step validation message remains visible")
eq(redraws,before,"invalid edit does not refresh live frames")
step:ClearFocus()
contains(panel.note:GetText(),"0.25","focus-loss validation error is not erased by refresh")
display(10/12,10)
total:SetFocus();total:SetText("2.99");total:ClearFocus()
eq(ns.db.historySampleInterval,10/12)
contains(panel.note:GetText(),"3 seconds","minimum-total validation message survives focus loss")
display(10/12,10)
total:SetFocus();total:SetText("not a number");total:ClearFocus()
eq(ns.db.historySampleInterval,10/12)
contains(panel.note:GetText(),"finite","malformed numeric input reports a usable validation message")
eq(S:SetHistoryValue("total","3"),true)
display(.25,3)

-- Both direct settings calls and native EditBox events respect combat locking.
ui.combat=true
before=redraws
eq(S:SetHistoryValue("step","1"),false)
eq(S:SetHistoryValue("total","12"),false)
eq(ns.db.historySampleInterval,.25)
eq(redraws,before)
step:SetFocus();step:SetText("0.5")
press(step,"OnEnterPressed")
eq(ns.db.historySampleInterval,.25)
contains(panel.note:GetText(),"combat","combat attempt gives a reason")
step:ClearFocus()
eq(ns.db.historySampleInterval,.25)
contains(panel.note:GetText(),"combat","focus loss cannot remove the combat error")
display(.25,3)
eq(#ui.violations,0,"settings do not mutate protected frames during combat")
ui.combat=false
eq(S:SetHistoryValue("total","10"),true,"editing resumes after combat")
display(10/12,10)

assert(#failures==0,table.concat(failures,"\n"))
print("history_settings_spec: "..checks.." checks passed")
