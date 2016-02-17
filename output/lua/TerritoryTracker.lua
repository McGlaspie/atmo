--[[=== Copyright (c) 2003-2016, Unknown Worlds Entertainment, Inc. All rights reserved. =======
    
    TODO Add Usage/Description
    
    Author: Brock Gillespie (mcglaspie@gmail.com)

========= For more information, visit us at http://www.unknownworlds.com ===================--]]


gTerritoryTracker = nil


class 'TerritoryTracker'

TerritoryTracker.initialized = false
TerritoryTracker.locations = {}
TerritoryTracker.territoryOccupancyFlags = {}
TerritoryTracker.dirtyLocations = {}
TerritoryTracker.kOwnership = enum({ 'Alien', 'Marine', 'Contested', 'None' })

function TerritoryTracker:Init()
    PROFILE("TerritoryTracker:GetIsEntityInLocation")
    if not self.initialized then
    
        local locations = GetLocations()
        
        for _, locationEnt in ipairs(locations) do
        --Maps can have multiple location entities per Location Name
            local locationName = locationEnt:GetName()
            
            if not self.locations[locationName] then
                locationEnt:Reset()
                self.locations[locationName] = {}
                self.locations[locationName][kTeam1Index] = {}
                self.locations[locationName][kTeam2Index] = {}
                self.territoryOccupancyFlags[locationName] = self.kOwnership.None
                self.dirtyLocations[locationName] = false
            end
        end
        
        self.initialized = true
    end
end

function TerritoryTracker:Reset()
    Log("TerritoryTracker:Reset()")
    self.locations = {}
    self.territoryOccupancyFlags = {}
    self.dirtyLocations = {}
    self.initialized = false
    self:Init()
end

function TerritoryTracker:GetIsEntityInLocation( entity, locationName )
    PROFILE("TerritoryTracker:GetIsEntityInLocation")
    
    assert( entity ~= nil )
    assert( type(locationName) == "string" )
    if locationName == "" then
        return false --nil?
    end
    
    local isInLocation = false
    if #TerritoryTracker.locations[locationName] > 0 then
        for loc = 1, #TerritoryTracker.locations[locationName] do
            isInLocation = self.locations[locationName][loc]:GetIsPointInside( entity:GetOrigin() )
            if isInLocation then
                break
            end
            loc = loc + 1
        end
    else
        isInLocation = self.locations[locationName]:GetIsPointInside( entity:GetOrigin() )
    end
    
    return isInLocation
end

function TerritoryTracker:AddTerritoryOccupant( locationName, forTeam, entityId )
    PROFILE("TerritoryTracker:AddTerritoryOccupant")
    
    assert( type(locationName) == "string" )
    if locationName == "" then
        return --pointless to proceed with "empty" Location-Name
    end
    
    assert( type(forTeam) == "number" )
    assert( forTeam ~= kTeamReadyRoom or forTeam ~= kSpectatorIndex )
    assert( type(entityId) == "number" )
    
    self.dirtyLocations[locationName] = self.dirtyLocations[locationName] 
        or table.insertunique( self.locations[locationName][forTeam], entityId )
end

function TerritoryTracker:RemoveTerritoryOccupant( locationName, forTeam, entityId )
    PROFILE("TerritoryTracker:RemoveTerritoryOccupant")
    
    assert( type(locationName) == "string" )
    if locationName == "" then
        return --pointless to proceed with "empty" Location-Name
    end
    
    assert( type(forTeam) == "number" )
    assert( forTeam ~= kTeamReadyRoom or forTeam ~= kSpectatorIndex )
    assert( type(entityId) == "number" )
    
    for idx = 1, #self.locations[locationName][forTeam] do
        if self.locations[locationName][forTeam][idx] == entityId then
            table.remove( self.locations[locationName][forTeam], idx )
            Log("\t Removed %s from location cache of team %s", entityId, forTeam )
        end
    end
end

function TerritoryTracker:GetLocationOccupancy( locationName, forceUpdate )
    PROFILE("TerritoryTracker:GetLocationOccupancy")
    
    assert( type(locationName) == "string" )
    if locationName == "" then
        return --pointless to proceed with "empty" Location-Name
    end
    
    if forceUpdate ~= nil then
        assert( type(forceUpdate) == "boolean" )
    end
    
    --TODO Add support for dirtyFlag and forcedUpdate
    
    local countMarine = #self.locations[locationName][kTeam1Index]
    local countAlien = #self.locations[locationName][kTeam2Index]
    local occupancyFlag = self.kOwnership.None
    
    local locationPower = GetPowerPointForLocation( locationName ) //fixme - expensive
    if not locationPower:GetIsBuilt() then
        countMarine = Math.Clamp( countMarine - 1, 0, countMarine )
    end
    
    if countAlien > 0 and countMarine == 0 then
        occupancyFlag = self.kOwnership.Alien
    elseif countMarine > 0 and countAlien > 0 then
        occupancyFlag = self.kOwnership.Contested
    elseif countMarine > 0 and countAlien == 0 then
        occupancyFlag = self.kOwnership.Marine
    end
    
    self.dirtyLocations[locationName] = false
    self.territoryOccupancyFlags[locationName] = occupancyFlag
    
    return occupancyFlag
    
end

function TerritoryTracker:GetIsLocationOccupiedBy( locationName, forTeam )
    assert( type(locationName) == "string" )
    if locationName == "" then
        return --pointless to proceed with "empty" Location-Name
    end
    assert( type(forTeam) == "number" )
    assert( forTeam ~= kTeamReadyRoom or forTeam ~= kSpectatorIndex )
    
    return ##self.locations[locationName][forTeam] > 0
end


-------------------------------------------------------------------------------


if Server then

    function GetTerritoryTracker()
        if gTerritoryTracker == nil then
            gTerritoryTracker = TerritoryTracker()
            gTerritoryTracker:Init()
        end
        
        return gTerritoryTracker
    end

    function Debug_DumpTerritoryOccupancy()
        Log("Territory Occupancies...")
        local territories = GetTerritoryTracker()
        Log("%s", territories)
        for location, data in pairs(territories.locations) do
            Log("\t Location: %s", location )
            Log("\t\t Marine Occupants: %d", #territories.locations[location][kTeam1Index] )
            Log("\t\t Alien Occupants: %d", #territories.locations[location][kTeam2Index] )
            Log("\t\t Occupied Flag: %d", territories:GetLocationOccupancy( location ) )
        end
    end
    Event.Hook("Console_dumpterritories", Debug_DumpTerritoryOccupancy)
    
end
