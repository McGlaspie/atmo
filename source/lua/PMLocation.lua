
Script.Load("lua/TerritoryMixin.lua")
Script.Load("lua/BacteriumZoneMixin.lua")


local networkVars = {}

AddMixinNetworkVars( TerritoryMixin, networkVars )


function Location:OnCreate()
    
    Trigger.OnCreate(self)
    
    InitMixin( self, TerritoryMixin )

end

function Location:OnInitialized()

    Trigger.OnInitialized(self)
    
    --Precache name so we can use string index in entities
    Shared.PrecacheString(self.name)
    
    --Default to show.
    if self.showOnMinimap == nil then
        self.showOnMinimap = true
    end
    
    self:SetTriggerCollisionEnabled(true)
    
    self:SetPropagate(Entity.Propagate_Always)
    
    InitMixin( self, BacteriumZoneMixin )
    
end

--TODO Handle things like Scans
--  Will need some sort of callback into SetIsScouted for Location

if Server then
    
    function Location:Reset()
        self:ResetTerritory()
    end
    
    local orgTrigEnter = Location.OnTriggerEntered
    function Location:OnTriggerEntered( entity, triggerEnt )
        orgTrigEnter( self, entity, triggerEnt )
        
        if HasMixin( entity, "Team" ) then
            local entityTeam = entity:GetTeamNumber()
            self:UpdateScoutingFlag( entityTeam )
            --XXX Add occupancy update?
        end
        
    end
    
end