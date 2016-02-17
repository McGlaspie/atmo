
function ConstructMixin:OnConstructionComplete(builder)

    local team = HasMixin(self, "Team") and self:GetTeam()
    
    if team then

        if self.GetCompleteAlertId then
            team:TriggerAlert(self:GetCompleteAlertId(), self)
            
        elseif GetIsMarineUnit(self) then

            if builder and builder:isa("MAC") then    
                team:TriggerAlert(kTechId.MACAlertConstructionComplete, self)
            else            
                team:TriggerAlert(kTechId.MarineAlertConstructionComplete, self)
            end
            
        end
        
        team:OnConstructionComplete(self)
        
        //Note: below REQUIRES implementing entity derives from a ScriptActor
        //???? What doesn't inherent from ScriptActor? Check.
        GetTerritoryTracker():AddTerritoryOccupant( self:GetLocationName(), self:GetTeamNumber(), self:GetId() )
        
    end     

    self:TriggerEffects("construction_complete")
    
end

