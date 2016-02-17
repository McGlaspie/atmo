
function LiveMixin:Kill( attacker, doer, point, direction )

    // Do this first to make sure death message is sent
    if self:GetIsAlive() and self:GetCanDie() then
    
        if self.PreOnKill then
            self:PreOnKill(attacker, doer, point, direction)
        end
    
        self.health = 0
        self.armor = 0
        self.alive = false
        
        if Server then
            GetGamerules():OnEntityKilled(self, attacker, doer, point, direction)
        end
        
        //Removes entity as an occupant of a given Location
        //NOTE! This _requires_ an entity derives from ScriptActor type
        GetTerritoryTracker():RemoveTerritoryOccupant( self:GetLocationName(), self:GetTeamNumber(), self:GetId() )
        
        if self.OnKill then
            self:OnKill(attacker, doer, point, direction)
        end
        
    end
    
end

