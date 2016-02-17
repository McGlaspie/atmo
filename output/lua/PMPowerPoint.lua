
local kUnsocketedSocketModelName = PrecacheAsset("models/system/editor/power_node_socket.model")
local kUnsocketedAnimationGraph = nil

local kSocketedModelName = PrecacheAsset("models/system/editor/power_node.model")
PrecacheAsset("models/marine/powerpoint_impulse/powerpoint_impulse.dds")
PrecacheAsset("models/marine/powerpoint_impulse/powerpoint_impulse.material")
PrecacheAsset("models/marine/powerpoint_impulse/powerpoint_impulse.model")

local kSocketedAnimationGraph = PrecacheAsset("models/system/editor/power_node.animation_graph")

local kDamagedEffect = PrecacheAsset("cinematics/common/powerpoint_damaged.cinematic")
local kOfflineEffect = PrecacheAsset("cinematics/common/powerpoint_offline.cinematic")

local kTakeDamageSound = PrecacheAsset("sound/NS2.fev/marine/power_node/take_damage")
local kDamagedSound = PrecacheAsset("sound/NS2.fev/marine/power_node/damaged")
local kDestroyedSound = PrecacheAsset("sound/NS2.fev/marine/power_node/destroyed")
local kDestroyedPowerDownSound = PrecacheAsset("sound/NS2.fev/marine/power_node/destroyed_powerdown")
local kAuxPowerBackupSound = PrecacheAsset("sound/NS2.fev/marine/power_node/backup")

// Re-build only possible when X seconds have passed after destruction (when aux power kicks in)
local kDestructionBuildDelay = 15

// The amount of time that must pass since the last time a PP was attacked until
// the team will be notified. This makes sure the team isn't spammed.
local kUnderAttackTeamMessageLimit = 5

// max amount of "attack" the powerpoint has suffered (?)
local kMaxAttackTime = 10

local kMinFullLightDelay = 2
local kFullPowerOnTime = 4
local kMaxFullLightDelay = 4



local netVars = 
{
    powerLevel = "float (0.0 to 1.0 by 0.005)",
    lastPowerLevel = "float (0.0 to 1.0 by 0.005)"
}


local kDefaultUpdateRange = 100

if Client then
    
    Script.Load("lua/PMPowerPoint_Client.lua")
    
    // The default update range; if the local player is inside this range from the powerpoint, the
    // lights will update. As the lights controlled by a powerpoint can be located quite far from the powerpoint,
    // and the area lit by the light even further, this needs to be set quite high.
    // The powerpoint cycling is also very efficient, so there is no need to keep it low from a performance POV.
    local kDefaultUpdateRangeSq = kDefaultUpdateRange * kDefaultUpdateRange
    
    function UpdatePowerPointLights()
        
        PROFILE("PowerPoint:UpdatePowerPointLights")
        
        // Now update the lights every frame
        local player = Client.GetLocalPlayer()
        if player then
            
            local playerPos = player:GetOrigin()
            local powerPoints = Shared.GetEntitiesWithClassname("PowerPoint")
            
            for index, powerNode in ientitylist(powerPoints) do
            // PowerPoints are always loaded but in order to avoid running the light modification stuff
            // for all of them at all times, we restrict it to powerpoints inside the updateRange. The
            // updateRange should be long enough that players can't see the lights being updated by the
            // powerpoint when outside this range, and short enough not to waste too much cpu.
                
                // Ignore range check if the player is Overhead View (Commander or Spectator) since they are high above
                // the lights in a lot of cases and see through ceilings and some walls.
                local useUpdatedLightMode = false
                
                if player:isa("Commander") then
                    
                    local nodeLocation = powerNode:GetLocation()
                    if nodeLocation then
                        useUpdatedLightMode = nodeLocation:GetIsScouted( player:GetTeamNumber() )
                    else
                        Log("ERROR: Failed to retrieve Location(%s) entity for PowerPoint(%s)", powerNode:GetLocationName(), powerNode:GetId() )
                    end
                    
                else
                    
                    local inRange = ( powerNode:GetOrigin() - playerPos ):GetLengthSquared() <= kDefaultUpdateRangeSq
                    useUpdatedLightMode = inRange or player:GetTeamNumber() == kSpectatorIndex
                    
                end
                
                powerNode:UpdatePoweredLights( useUpdatedLightMode ) 
                              
            end
            
        end
        
    end
    
end




local kPMDamagedPercentage = 0.5  //.4

local function SetupWithInitialSettings(self)
    --Log("\t SetupWithInitialSettings(self)")
    if self.startSocketed then
    
        self:SetInternalPowerState( PowerPoint.kPowerState.socketed )
        self:SetConstructionComplete()
        self:SetLightMode( kLightMode.Normal )
        self:SetPoweringState(true)
        self.powerLevel = kFullPowerLevel
        self.lastPowerLevel = kFullPowerLevel
        
    else
    
        self:SetModel( kUnsocketedSocketModelName, kUnsocketedAnimationGraph )
        self:SetLightMode( kLightMode.Degraded )    
        self.powerState = PowerPoint.kPowerState.unsocketed
        self.timeOfDestruction = 0
        self.powerLevel = kDegradedPowerLevel
        self.lastPowerLevel = kDegradedPowerLevel
        
        if Server then
            self.startsBuilt = false
            self.attackTime = 0.0
        end
        
    end
end

local orgPowerCreate = PowerPoint.OnCreate
function PowerPoint:OnCreate()
    orgPowerCreate(self)
    
    self.location = nil
    
    SetupWithInitialSettings(self)
end

function PowerPoint:OnInitialized()
    --Log("PowerPoint:OnInitialized()")
    ScriptActor.OnInitialized(self)
    
    if Server then
    
        -- PowerPoints always belong to the Marine team.
        self:SetTeamNumber(kTeam1Index)
        
        -- extend relevancy range as the powerpoint plays with lights around itself, so
        -- the effects of a powerpoint are visible far beyond the normal relevancy range
        self:SetRelevancyDistance(kDefaultUpdateRange + 20) --Update range may be causing update flooding (i.e. Red Plug)
        
        self:SetPropagate(Entity.Propagate_Always)  --Required for Aliens to Query Location power levels (Commanders)
        --FIXME Above is causing nodes to stay sighted for aliens
        
        -- This Mixin must be inited inside this OnInitialized() function.
        if not HasMixin(self, "MapBlip") then
            InitMixin(self, MapBlipMixin)
        end
        
        InitMixin(self, StaticTargetMixin)
        InitMixin(self, InfestationTrackerMixin)
        
    elseif Client then
    
        InitMixin(self, UnitStatusMixin)
        InitMixin(self, HiveVisionMixin)
        
    end
    
    InitMixin(self, IdleMixin)
    
end

function PowerPoint:GetLocation()
    if self.location == nil then
        local location = GetLocationForPoint( self:GetOrigin() )
        if location and location:isa("Location") then
            self.location = location
        end
    end
    
    return self.location
end

function PowerPoint:OverrideVisionRadius()
    if self:GetIsBuilt() and self:GetIsSocketed() then
        return 1    --????
    end
    
    return 0
end

function PowerPoint:SetLightMode( lightMode )
    
    if self:GetIsDisabled() then
        lightMode = kLightMode.NoPower
    elseif not self:GetIsSocketed() then
        lightMode = kLightMode.Degraded --??? Ehhh
    end
    
    local time = Shared.GetTime()
    
    if self.lastLightMode == kLightMode.NoPower and lightMode == kLightMode.Damaged then
        local fullFullLightTime = self.timeOfLightModeChange + kMinFullLightDelay + kMaxFullLightDelay + kFullPowerOnTime    
        if time < fullFullLightTime then
            -- Don't allow the light mode to change to damaged until after the power is fully restored
            return
        end
    end
    
    -- Don't change light mode too often or lights will change too much
    if self.lightMode ~= lightMode or (not self.timeOfLightModeChange or (time > (self.timeOfLightModeChange + 1.0))) then
        self.lastLightMode, self.lightMode = self.lightMode, lightMode        
        self.timeOfLightModeChange = time
    end
    
end

--TODO Reset power level on X events (construct, destroy, etc)

if Server then
    
    function PowerPoint:Reset()
        --Log("PowerPoint:Reset()")
        --Log("\t (before) powerLevel=%d", self.powerLevel)
        SetupWithInitialSettings(self)
        ScriptActor.Reset(self)
        self:MarkBlipDirty()
        --Log("\t (after) powerLevel=%d", self.powerLevel)
    end
    
    local function PowerUp(self)
    
        self:SetInternalPowerState( PowerPoint.kPowerState.socketed )
        self:SetLightMode( kLightMode.Normal )
        self:StopSound( kAuxPowerBackupSound )
        self:TriggerEffects("fixed_power_up")
        self:SetPoweringState( true )
        
    end
    
    -- Repaired by marine with welder or MAC 
    function PowerPoint:OnWeldOverride(entity, elapsedTime)
    
        local welded = false
        
        -- Marines can repair power points
        if entity:isa("Welder") then

            local amount = kWelderPowerRepairRate * elapsedTime
            welded = (self:AddHealth(amount) > 0)            
            
        elseif entity:isa("MAC") then
        
            welded = self:AddHealth(MAC.kRepairHealthPerSecond * elapsedTime) > 0 
            
        else
        
            local amount = kBuilderPowerRepairRate * elapsedTime
            welded = (self:AddHealth(amount) > 0)
        
        end
        
        if self:GetHealthScalar() > kPMDamagedPercentage then
        
            self:StopDamagedSound()
            
            if self:GetLightMode() == kLightMode.LowPower and self:GetIsPowering() then
                self:SetLightMode( kLightMode.Normal )
            end
            
        end
        
        if self:GetHealthScalar() == 1 and self:GetPowerState() == PowerPoint.kPowerState.destroyed then
        
            self:StopDamagedSound()
            
            self.health = kPowerPointHealth
            self.armor = kPowerPointArmor
            
            self:SetMaxHealth(kPowerPointHealth)
            self:SetMaxArmor(kPowerPointArmor)
            
            self.alive = true
            
            PowerUp(self)
            
        end
        
        if welded then
            self:AddAttackTime(-0.1)
        end
        
    end
    
    function PowerPoint:OnUpdate(deltaTime)

        self:AddAttackTime(-0.1)
        
        if self:GetLightMode() == kLightMode.Damaged and self:GetAttackTime() == 0 then
            self:SetLightMode(kLightMode.Normal)
        end
                
    end
    
    function PowerPoint:OnTakeDamage(damage, attacker, doer, direction, damageType, preventAlert)

        if self.powerState == PowerPoint.kPowerState.socketed and damage > 0 then

            self:PlaySound(kTakeDamageSound)
            
            local healthScalar = self:GetHealthScalar()
            
            if healthScalar <= kPMDamagedPercentage then
            
                self:SetLightMode(kLightMode.LowPower)
                
                if not self.playingLoopedDamaged then
                
                    self:PlaySound(kDamagedSound)
                    self.playingLoopedDamaged = true
                    
                end
                
            else
                self:SetLightMode(kLightMode.Damaged)
            end
            
            if not preventAlert then
                CheckSendDamageTeamMessage(self)
            end
            
        end
        
        self:AddAttackTime(0.9)
        
    end

end

function PowerPoint:GetPowerLevel()
    return self.powerLevel
end

function PowerPoint:GetPreviousPowerLevel()
    return self.lastPowerLevel
end

function PowerPoint:SetPowerLevel( powerLevel )
    assert( type(powerLevel) == "number" )
    self.lastPowerLevel = self.powerLevel
    --XXX Light mode change?
    self.powerLevel = Math.Clamp( powerLevel, 0.0, 1.0 )
end

if Server then
    --ReplaceLocals( PowerPoint.OnTakeDamage, { kDamagedPercentage = kPMDamagedPercentage } )
end


Class_Reload( "PowerPoint", netVars )
