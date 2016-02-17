
--Script.Load("lua/Cyst.lua")
--if Server then
--    Script.Load("lua/Cyst_Server.lua")
--end
--Script.Load("lua/CystUtility.lua")
Script.Load("lua/BacteriumZoneNodeMixin.lua")


local origCystOnCreate = Cyst.OnCreate
function Cyst:OnCreate()
    origCystOnCreate(self)
    
    if Client then
        InitMixin( self, BacteriumZoneNodeMixin )
    end
end