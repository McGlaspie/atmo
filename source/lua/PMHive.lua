
Script.Load("lua/BacteriumZoneNodeMixin.lua")


local orgOnCreate = Hive.OnCreate
function Hive:OnCreate()
    orgOnCreate(self)
    
    if Client then
        InitMixin( self, BacteriumZoneNodeMixin )
    end
end