-- Public native-boundary double: never evaluates protected sample numbers.
return function(state)
    Enum = Enum or {}
    Enum.LuaCurveType = {Linear=1}
    CreateColor = function(r,g,b,a)
        return {GetRGBA=function() return r,g,b,a end,GetRGB=function() return r,g,b end}
    end
    C_CurveUtil = {CreateColorCurve=function()
        local curve = {points={}}
        function curve:SetType(value) self.type=value end
        function curve:AddPoint(x,color) self.points[#self.points+1]={x,color} end
        state.historyCurve=curve
        return curve
    end}
    UnitHealthPercent = function(unit,predicted,curve)
        assert(predicted==false and curve==state.historyCurve)
        state.historyColorCalls=(state.historyColorCalls or 0)+1
        return state.historyColor or CreateColor(.25,.75,.38,1)
    end
end
