--[[=== Copyright (c) 2003-2015, Unknown Worlds Entertainment, Inc. All rights reserved. =======
    
    Any location that can act as contested "territory" should implement this mixin.
    Works in conjunction with the TerritoryTracker utility class to determine which
    team "owns" a given location. This also triggers the lighting values to change
    based on location ownership. Ownership is a simple count of built/live structures.
    
    Author: Brock Gillespie (mcglaspie@gmail.com)

========= For more information, visit us at http://www.unknownworlds.com ===================--]]


kTerritoryUpdateRate = 0.05   --20 updates a second
kDegradePowerLevelPerUpdate = 0.0025   --TODO Move to global
kScoutedTimeThreshold = 2   --10


TerritoryMixin = CreateMixin( TerritoryMixin )
TerritoryMixin.type = "Territory"

TerritoryMixin.networkVars =
{
    scoutedForTeam1 = "boolean",
    scoutedForTeam2 = "boolean",
    team1LastScoutedTime = "time",
    team2LastScoutedTime = "time",
    powerPointId = "entityid",  --needed?
    occupancyFlag = "enum TerritoryTracker.kOwnership"
}


function TerritoryMixin:__initmixin()
    assert( self:isa("Location") )
    
    self.scoutedForTeam1 = false
    self.scoutedForTeam2 = false
    self.team1LastScoutedTime = 0
    self.team2LastScoutedTime = 0
    self.powerPointId = Entity.invalidId
    
    if Server then
        self.occupancyFlag = TerritoryTracker.kOwnership.None
        self.lastUpdateTime = 0
        self.powerPoint = nil
        self:AddTimedCallback( self.UpdatePowerLevel, kTerritoryUpdateRate )
    end
    
end

function TerritoryMixin:UpdateScoutingFlag( forTeam )
    
    if forTeam == kTeam1Index then
        self.scoutedForTeam1 = true
        self.team1LastScoutedTime = Shared.GetTime()
    elseif forTeam == kTeam2Index then
        self.scoutedForTeam2 = true
        self.team2LastScoutedTime = Shared.GetTime()
    end
    
end

function TerritoryMixin:GetIsScouted( forTeam )
    assert(type(forTeam) == "number")
    local isScouted = false
    
    if forTeam == kTeam1Index and self.scoutedForTeam1 == true then
        isScouted = Shared.GetTime() + kScoutedTimeThreshold < self.team1LastScoutedTime + kScoutedTimeThreshold
        isScouted = isScouted or ( self.occupancyFlag == 1 or self.occupancyFlag == 2 )
    elseif forTeam == kTeam2Index and self.scoutedForTeam2 == true then
        isScouted = Shared.GetTime() + kScoutedTimeThreshold < self.team2LastScoutedTime + kScoutedTimeThreshold
    end
    
    return isScouted
end

function TerritoryMixin:ResetTerritory()
    --Log("TerritoryMixin:Reset() - %s", self.name)
    self.occupancyFlag = TerritoryTracker.kOwnership.None
    self.scoutedForTeam1 = false
    self.scoutedForTeam2 = false
    self.team1LastScoutedTime = 0
    self.team2LastScoutedTime = 0
    self.lastUpdateTime = 0
    self.powerPointId = Entity.invalidId
    //Destroy and recreate timed callback?
end

function TerritoryMixin:PollingUpdateScoutedFlag()
    PROFILE("TerritoryMixin:PollingUpdateScoutedFlag")
    
    local time = Shared.GetTime()
    if time + kScoutedTimeThreshold > self.lastUpdateTime then  --????
    
        local entitesInTrigger = self:GetEntitiesInTrigger()
        if entitesInTrigger then
            
            if #entitesInTrigger > 0 then
                
                for e = 1, #entitesInTrigger do
                    if HasMixin( entitesInTrigger[e], "Team" ) then
                        self.scoutedForTeam1 = self.scoutedForTeam1 or ( entitesInTrigger[e]:GetTeamNumber() == kTeam1Index )
                        self.scoutedForTeam2 = self.scoutedForTeam2 or ( entitesInTrigger[e]:GetTeamNumber() == kTeam2Index )
                    end
                    e = e + 1
                end
                
            end
            
            if self.scoutedForTeam1 then
                self.team1LastScoutedTime = time
            end
            
            if self.scoutedForTeam2 then
                self.team2LastScoutedTime = time
            end
            
        end
    end
    
end

--TODO Move powerLevels to class constants
function TerritoryMixin:UpdatePowerLevel()
    PROFILE("TerritoryMixin:UpdateTerritoryPowerLevel")
    
    --TEST: This may be introducing problems on round-reset event (fast)
    if Shared.GetTime() < 1 then    --Delay for lighting reset?
        return true --skip, but continue callback
    end
    
    self:PollingUpdateScoutedFlag() --required here?
    
    --???? Last occupancy flag useful?
    self.occupancyFlag = GetTerritoryTracker():GetLocationOccupancy( self.name )
    
    if self.powerPoint == nil or self.lastUpdateTime == 0 then
        self.powerPoint = GetPowerPointForLocation( self.name )
        self.powerPointId = self.powerPoint:GetId() --still useful?
    end
    
    if self.powerPoint ~= nil then
        
        local powerLevel = self.powerPoint:GetPowerLevel()
        
        if not self.powerPoint:GetIsBuilt() then
            
            if self.occupancyFlag == TerritoryTracker.kOwnership.Alien then
                
                if powerLevel > 0 then
                    powerLevel = Math.Clamp( powerLevel - kDegradePowerLevelPerUpdate, 0, 1 )
                end
                
            elseif self.occupancyFlag == TerritoryTracker.kOwnership.None then
                
                if powerLevel > kDegradedPowerLevel then
                    powerLevel = Math.Clamp( powerLevel - kDegradePowerLevelPerUpdate, kDegradedPowerLevel, 1 )
                elseif powerLevel < kDegradedPowerLevel then
                    powerLevel = Math.Clamp( powerLevel + kDegradePowerLevelPerUpdate, 0, kDegradedPowerLevel )
                end
                
            end
            
        else
            
            if self.powerPoint:GetIsAlive() then
                if powerLevel < kMarineOccupiedPowerLevel then
                    powerLevel = Math.Clamp( powerLevel + kDegradePowerLevelPerUpdate, 0, kMarineOccupiedPowerLevel )
                end
            else
                powerLevel = 0
            end
            
        end
        
        self.powerPoint:SetPowerLevel( powerLevel )
        
    else
        Log("ERROR: No power point found for Location: %s", self.name )
    end
    
    self.lastUpdateTime = Shared.GetTime()
    
    return true
    
end
