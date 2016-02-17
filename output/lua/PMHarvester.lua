
Script.Load("lua/BacteriumZoneNodeMixin.lua")

local orgCreate = Harvester.OnCreate
function Harvester:OnCreate()
    orgCreate(self)
    
    if Client then
        InitMixin( self, BacteriumZoneNodeMixin )
    end
end