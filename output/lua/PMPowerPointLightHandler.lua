

--FIXME All the below values should be scaled by player's gamma setting
-- - gamme updates (in-game) may prove to be a problem then...requires
--   mirroring gamma val to local...yay

local kMinCommanderLightIntensityScalar = 0.21

local kPowerDownTime = 0    --1
local kOffTime = 15

local kLowPowerCycleTime = 1
local kLowPowerMinIntensity = 0.5  -- 0.4
local kLowPowerMaxIntensity = 0.64  -- 0.81
--XXX Change above to be a factor/scalar of original light value?

local kDegradedLowPowerMinIntensity = 0.385 --0.42

local kDamagedCycleTime = 1
local kDamagedMinIntensity = 0.45  -- 0.7

local kAuxPowerCycleTime = 3
local kAuxPowerMinIntensity = 0.05
local kAuxPowerMaxIntensity = 0.25 --?  .125
local kAuxPowerMinCommanderIntensity = 3

local kMinNoPowerIntensity = 0.125
local kMaxNoPowerIntensity = 0.28


-- set the intensity and color for a light. If the renderlight is ambient, we set the color
-- the same in all directions
local function SetLight(renderLight, intensity, color)

    if intensity then
        renderLight:SetIntensity(intensity)
    end
    
    if color then
    
        renderLight:SetColor(color)
        
        if renderLight:GetType() == RenderLight.Type_AmbientVolume then
        
            renderLight:SetDirectionalColor(RenderLight.Direction_Right,    color)
            renderLight:SetDirectionalColor(RenderLight.Direction_Left,     color)
            renderLight:SetDirectionalColor(RenderLight.Direction_Up,       color)
            renderLight:SetDirectionalColor(RenderLight.Direction_Down,     color)
            renderLight:SetDirectionalColor(RenderLight.Direction_Forward,  color)
            renderLight:SetDirectionalColor(RenderLight.Direction_Backward, color)
            
        end
        
    end
    
end

class 'PowerPointLightHandler'

function PowerPointLightHandler:Init( powerPoint )
    
    self.powerPoint = powerPoint
    self.lightTable = {}
    self.probeTable = {}
    self.lastMode = nil
    
    -- all lights for this powerPoint, and filter away those that
    -- shouldn't be affected by the power changes
    for _, light in ipairs( GetLightsForLocation( powerPoint:GetLocationName() ) ) do
        
        if not light.ignorePowergrid then
            self.lightTable[light] = true
        end
        
    end
    
    for _, probe in ipairs( GetReflectionProbesForLocation( powerPoint:GetLocationName() ) ) do
        self.probeTable[probe] = true
    end
    
    self.lastWorker = nil
    self.lastTimeOfChange = nil
    
    --[[
    self.workerTable = {
        [kLightMode.Normal] = NormalLightWorker():Init( self, "normal" ),
        [kLightMode.NoPower] = NoPowerLightWorker():Init( self, "nopower" ),
        [kLightMode.LowPower] = LowPowerLightWorker():Init( self, "lowpower" ),
        [kLightMode.Degraded] = DegradedPowerLightWorker():Init( self, "degradedpower" ),
        [kLightMode.Damaged] = DamagedLightWorker():Init( self, "damaged" ),
    }
    --]]
    self.workerTable = {
        [kLightMode.Normal] = NormalLightWorker():Init( self, "normal" ),
        [kLightMode.NoPower] = DegradedPowerLightWorker():Init( self, "degradedpower" ),
        [kLightMode.LowPower] = LowPowerLightWorker():Init( self, "lowpower" ),
        [kLightMode.Degraded] = DegradedPowerLightWorker():Init( self, "degradedpower" ),
        [kLightMode.Damaged] = DamagedLightWorker():Init( self, "damaged" ),
    }
    
    return self
    
end

function PowerPointLightHandler:Reset()

    self.lightTable = { }
    self.probeTable = { }
    self.lastMode = nil
    
    -- all lights for this powerPoint, and filter away those that
    -- shouldn't be affected by the power changes
    for _, light in ipairs( GetLightsForLocation( self.powerPoint:GetLocationName() ) ) do
        
        if not light.ignorePowergrid then
            self.lightTable[light] = true
        end
        
    end
    
    for _, probe in ipairs( GetReflectionProbesForLocation( self.powerPoint:GetLocationName() ) ) do
        self.probeTable[probe] = true
    end
    --[[
    self.workerTable = {
        [kLightMode.Normal] = NormalLightWorker():Init( self, "normal" ),
        [kLightMode.NoPower] = NoPowerLightWorker():Init( self, "nopower" ),
        [kLightMode.LowPower] = LowPowerLightWorker():Init( self, "lowpower" ),
        [kLightMode.Degraded] = DegradedPowerLightWorker():Init( self, "degradedpower" ),
        [kLightMode.Damaged] = DamagedLightWorker():Init( self, "damaged" ),
    }
    --]]
    self.workerTable = {
        [kLightMode.Normal] = NormalLightWorker():Init( self, "normal" ),
        [kLightMode.NoPower] = DegradedPowerLightWorker():Init( self, "degradedpower" ),
        [kLightMode.LowPower] = LowPowerLightWorker():Init( self, "lowpower" ),
        [kLightMode.Degraded] = DegradedPowerLightWorker():Init( self, "degradedpower" ),
        [kLightMode.Damaged] = DamagedLightWorker():Init( self, "damaged" ),
    }
    
    self:Run( self.lastMode )   --last?

end

function PowerPointLightHandler:Run( lightMode )
    
    self.lastMode = lightMode
    
    local worker = self.workerTable[ lightMode ]
    local timeOfChange = self.powerPoint:GetTimeOfLightModeChange()
    local player = Client.GetLocalPlayer()
    
    if self.lastTimeOfChange ~= timeOfChange or player:GetIsOverhead() or self.lastWorker ~= worker then
    
        worker:Activate()
        self.lastWorker = worker
        self.lastTimeOfChange = timeOfChange
        
    end
    
    worker:Run()
    
end


-------------------------------------------------------------------------------


--
-- Base class for all LightWorkers, ie per-mode workers.
--
class 'BaseLightWorker'

function BaseLightWorker:Init( handler, name )
    
    self.handler = handler
    self.name = name
    self.activeLights = {}
    self.activeProbes = false
    
    return self
    
end

-- called whenever the mode changes so this Worker is activated
function BaseLightWorker:Activate()
    
    for light,_ in pairs( self.handler.lightTable ) do    --???? Why is this pairs()
    
        self.activeLights[light] = true
        light.randomValue = Shared.GetRandomFloat()
        light.flickering = nil
        
    end
    
    self.activeProbes = true
    
end

-- if a light should try to flicker, call with the light and the chance to flicker
function BaseLightWorker:CheckFlicker(renderLight, chance, scalar)

    if renderLight.flickering == nil then
        renderLight.flickering = math.random() < chance
    end
    
    if renderLight.flickering then
        return self:FlickerLight(scalar)
    end
    
    return 1
    
end

function BaseLightWorker:FlickerLight(scalar)

    if scalar < 0.5 then
    
        local flicker_intensity = Clamp( math.sin( math.pow( ( 1 - scalar ) * 6, 8 ) ) + 1, .8, 2 ) * 0.5 -- / 2
        return flicker_intensity * flicker_intensity
        
    end
    return 1
    
end


function BaseLightWorker:RestoreColor(renderLight)

    renderLight:SetColor(renderLight.originalColor)

    if renderLight:GetType() == RenderLight.Type_AmbientVolume then

        renderLight:SetDirectionalColor(RenderLight.Direction_Right,    renderLight.originalRight)
        renderLight:SetDirectionalColor(RenderLight.Direction_Left,     renderLight.originalLeft)
        renderLight:SetDirectionalColor(RenderLight.Direction_Up,       renderLight.originalUp)
        renderLight:SetDirectionalColor(RenderLight.Direction_Down,     renderLight.originalDown)
        renderLight:SetDirectionalColor(RenderLight.Direction_Forward,  renderLight.originalForward)
        renderLight:SetDirectionalColor(RenderLight.Direction_Backward, renderLight.originalBackward)
        
    end

end


-------------------------------------------------------------------------------


--
-- handles kLightMode.Normal
--
class 'NormalLightWorker' (BaseLightWorker)

function NormalLightWorker:Activate()
    
    BaseLightWorker.Activate(self)
    
    self.lastUpdateTimePassed = -1
    
end

-- Turning on full power. 
-- When turn on full power, the lights are never decreased in intensity.
function NormalLightWorker:Run()
    
    PROFILE("NormalLightWorker:Run")

    local timeOfChange = self.handler.powerPoint:GetTimeOfLightModeChange()
    local time = Shared.GetTime()
    local timePassed = time - timeOfChange
    
    if self.activeProbes then
    
        local startFullLightTime = PowerPoint.kMinFullLightDelay
        local fullFullLightTime = startFullLightTime + PowerPoint.kFullPowerOnTime      
        
        local probeTint = nil
        
        if timePassed < startFullLightTime then
            -- we don't change lights or color during this period        
            probeTint = nil
        else
            probeTint = Color(1, 1, 1, 1)
            self.activeProbes = false
        end

        if probeTint ~= nil then
            for probe,_ in pairs(self.handler.probeTable) do
                probe:SetTint( Color(1, 1, 1, 1) )
            end
        end
        
    end
    
    for renderLight,_ in pairs(self.activeLights) do

        local intensity = nil
        local randomValue = renderLight.randomValue
    
        local startFullLightTime = PowerPoint.kMinFullLightDelay + PowerPoint.kMaxFullLightDelay * randomValue
        -- time when full lightning is achieved
        local fullFullLightTime = startFullLightTime + PowerPoint.kFullPowerOnTime  
            
        if timePassed < startFullLightTime then
            
            -- we don't change lights or color during this period        
            intensity = nil
          
        elseif timePassed < fullFullLightTime then
            
            -- the period when lights start to come on, possibly with a little flickering
            local t = timePassed - startFullLightTime
            local scalar = math.sin( ( t / PowerPoint.kFullPowerOnTime  ) * math.pi * 0.5 )
            intensity = renderLight.originalIntensity * scalar
            
            if renderLight.flickering == nil and intensity < renderLight:GetIntensity() then
                -- don't change anything until we exceed the origin light intensity.
                intensity = nil
            else
            
                if renderLight.flickering == nil then
                    self:RestoreColor(renderLight)
                end
                intensity = intensity * self:CheckFlicker(renderLight,PowerPoint.kFullFlickerChance, scalar)
                
            end
            
        else
            
            intensity = renderLight.originalIntensity
            self:RestoreColor(renderLight)
            
            -- remove this light from processing
            self.activeLights[renderLight] = nil
            
        end
        
        -- color are only changed once during the full-power-on
        SetLight( renderLight, intensity, nil )   --renderLight, intensity, nil

    end

end


-------------------------------------------------------------------------------


class 'DegradedPowerLightWorker' (BaseLightWorker)

function DegradedPowerLightWorker:Activate()
    
    BaseLightWorker.Activate(self)
    
    self.lastUpdateTimePassed = -1
    
end

function DegradedPowerLightWorker:LerpLightColor( renderLight, targetColor, byPercent )
    
    renderLight:SetColor( LerpColor( renderLight:GetColor(), targetColor, byPercent ) )
    
    if renderLight:GetType() == RenderLight.Type_AmbientVolume then
        local directions = {}
        directions.Direction_Right = LerpColor( renderLight.originalRight, targetColor, byPercent )
        directions.Direction_Left = LerpColor( renderLight.originalLeft, targetColor, byPercent )
        directions.Direction_Up = LerpColor( renderLight.originalUp, targetColor, byPercent )
        directions.Direction_Down = LerpColor( renderLight.originalDown, targetColor, byPercent )
        directions.Direction_Forward = LerpColor( renderLight.originalForward, targetColor, byPercent )
        directions.Direction_Backward = LerpColor( renderLight.originalBackward, targetColor, byPercent )
        
        renderLight:SetDirectionalColor( RenderLight.Direction_Right,    directions.Direction_Right )
        renderLight:SetDirectionalColor( RenderLight.Direction_Left,     directions.Direction_Left )
        renderLight:SetDirectionalColor( RenderLight.Direction_Up,       directions.Direction_Up )
        renderLight:SetDirectionalColor( RenderLight.Direction_Down,     directions.Direction_Down )
        renderLight:SetDirectionalColor( RenderLight.Direction_Forward,  directions.Direction_Forward )
        renderLight:SetDirectionalColor( RenderLight.Direction_Backward, directions.Direction_Backward )
    end

end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function DegradedPowerLightWorker:Run()
    
    PROFILE("DegradedPowerLightWorker:Run")
    
    local timeOfChange = self.handler.powerPoint:GetTimeOfLightModeChange()
    local time = Shared.GetTime()
    local timePassed = time - timeOfChange    
    local powerLevel = self.handler.powerPoint:GetPowerLevel()
    local player = Client.GetLocalPlayer()
    local previousPowerLevel = self.handler.powerPoint:GetPreviousPowerLevel()
    
    if self.activeProbes then
        
        self.activeProbes = false
        
        local probeScalar = Math.Clamp( powerLevel * 0.5, 0, 1 )
        local normTint = Color(1,1,1,1)
        local noPowerTint = Color(0.1, 0.1, 0.1, 1)
        --Log("DegradedPowerLightWorker.handler.probeTable# = %d", tablelength(self.handler.probeTable))
        --FIXME Perform tinting OUTSIDE of loop
        
        for probe,_ in pairs(self.handler.probeTable) do
            
            if powerLevel == kFullPowerLevel then
                --Log("\t RESET ReflectionProbe")
                probe:SetStrength( probe.values.strength )
                probe:SetTint( normTint )
            else
                local probeTint = probe:GetTint()
                local tintScalar = 1
                --Log("\t probeTint = (%f, %f, %f, %f)", probeTint.r, probeTint.g, probeTint.b, probeTint.a)
                if previousPowerLevel > powerLevel then
                    tintScalar = 0.05
                elseif powerLevel > previousPowerLevel then
                    tintScalar = -0.075
                end
                
                probeTint = Color(
                    math.abs(probeTint.r * tintScalar), 
                    math.abs(probeTint.g * tintScalar), 
                    math.abs(probeTint.b * tintScalar), 
                    1
                )
                probe:SetTint(probeTint)
                --Log("\t NEW probeTint = (%f, %f, %f, 1.0)", probeTint.r, probeTint.g, probeTint.b)
                
                --Log("\t probe.values.strength: %s", probe.values.strength)
                local origStrVal = probe.values.strength
                local minStrVal = math.min( origStrVal, kDegradedLowPowerMinIntensity )
                local probeStrength = Math.Clamp( origStrVal * Math.Clamp( powerLevel + probeScalar, 0, 1 ), minStrVal, origStrVal )
                --Log("\t probe NEW strength: %f", probeStrength)
                probe:SetStrength( probeStrength ) --probeStrength
            end
            
        end
        
    end
    
    --XXX shared time int check?
    for renderLight,_ in pairs( self.activeLights ) do  --FIXME using pairs is bad...no point

        local intensity = nil
        local newLightColor = nil
        --local randomValue = renderLight.randomValue
        
        intensity = renderLight.originalIntensity
        local scalar = Math.Clamp( powerLevel * 0.5, 0, 1 )
        local powerLevelIntensity = Math.Clamp( intensity * Math.Clamp(powerLevel + scalar, 0, 1), kDegradedLowPowerMinIntensity, intensity )
        
        if player and player:GetIsOverhead() then
            local minCommIntensity = intensity * kMinCommanderLightIntensityScalar
            intensity = math.max( minCommIntensity, powerLevelIntensity )
        else
            intensity = powerLevelIntensity
        end
        --[[
        --Desaturate light color when sloping to very low intensities
        if powerLevel > 0 and powerLevel < kDegradedPowerLevel and previousPowerLevel > powerLevel then
            newLightColor = self:LerpLightColor( renderLight, PowerPoint.kDisabledCommanderColor, 0.0175 )
        elseif powerLevel < kDegradedPowerLevel and powerLevel >= 0 and previousPowerLevel < powerLevel then
            newLightColor = self:LerpLightColor( renderLight, renderLight.originalColor, 0.125 )
        end
        
        --FIXME Below solves "leftover grey" but transition is to abrupt
        if powerLevel >= kDegradedPowerLevel then
            newLightColor = renderLight.originalColor
        end
        --]]
        
        SetLight( renderLight, intensity, newLightColor )
        
        if previousPowerLevel == powerLevel then
        --remove this light from processing
            --self.activeLights[renderLight] = nil
        end
        
    end

end


-------------------------------------------------------------------------------


--
-- Handles Damaged. In damaged state, all lights cycle once whenever they are damaged 
-- then and the go back to steady state. Whenever we are damaged anew, we are reset and
-- start over
--
class 'DamagedLightWorker' (BaseLightWorker)

function DamagedLightWorker:Run()   --FIXME LowPower damage is lost
    
    PROFILE("DamagedLightWorker:Run")

    local timeOfChange = self.handler.powerPoint:GetTimeOfLightModeChange()
    local time = Shared.GetTime()
    local timePassed = time - timeOfChange
    
    local scalar = math.sin( Clamp(timePassed / kDamagedCycleTime, 0, 1 ) * math.pi )
    
    for renderLight, _ in pairs(self.activeLights) do
        
        local intensity = renderLight.originalIntensity * (1 - scalar * (1 - kDamagedMinIntensity))
        SetLight(renderLight, intensity, nil)
        
    end
    
    if timePassed > kDamagedCycleTime then
        self.activeLights = { }
        self.activeProbes = false
    end
    
end

-- Handles LowPower warning.
-- This cycles the light constantly 
class 'LowPowerLightWorker' (BaseLightWorker)

function LowPowerLightWorker:Run()
    
    PROFILE("LowPowerLightWorker:Run")
    
    local timeOfChange = self.handler.powerPoint:GetTimeOfLightModeChange()
    local time = Shared.GetTime()
    local timePassed = time - timeOfChange 
    
    local scalar = math.cos( ( timePassed / ( kLowPowerCycleTime * 0.5 ) ) * math.pi * 0.5 )
    local minIntensity = kLowPowerMinIntensity
    local halfIntensity = ( 1 - minIntensity ) * 0.5
    
    for renderLight,_ in pairs(self.activeLights) do
        
        -- Cycle lights up and down telling everyone that there's an imminent threat
        local intensity = renderLight.originalIntensity * minIntensity + halfIntensity + scalar * halfIntensity
        SetLight(renderLight, intensity, nil)
        
    end
    
end


-- Handles NoPower. This is a bit complex, as we end up in a continouosly varying light
-- state, where the auxilary light cycles now and then. To 
class 'NoPowerLightWorker' (BaseLightWorker)

NoPowerLightWorker.kNumGroups = 10

function NoPowerLightWorker:Init(handler, name)

    BaseLightWorker.Init(self, handler, name)
    
    self.lightGroups = {}
    
    for i = 0, NoPowerLightWorker.kNumGroups, 1 do
        self.lightGroups[i] = LightGroup():Init()
    end
    
    return self
    
end

function NoPowerLightWorker:Activate()
    
    BaseLightWorker.Activate(self)
    for i = 0, NoPowerLightWorker.kNumGroups, 1 do
        self.lightGroups[i].lights = {}
    end
    
end

--
-- handles lights when the powerpoint has no power. This involves a time with no lights,
-- and then a period when lights are coming on line into aux power setting. Once the aux light
-- has stabilized, the lights will stay mostly steady, but will sometimes cycle a bit.
--
-- Performance wise, we shift lights from the activeLights table over to lightgroups. Each group
-- of lights stay fixed for a while, then starts to cycle as one for another span of time. Done
-- this way so that we can avoid running the lights most of the time.
--
function NoPowerLightWorker:Run()

    PROFILE("NoPowerLightWorker:Run")

    local timeOfChange = self.handler.powerPoint:GetTimeOfLightModeChange()
    local time = Shared.GetTime()
    local timePassed = time - timeOfChange    
    
    local startAuxLightTime = kPowerDownTime + kOffTime
    local fullAuxLightTime = startAuxLightTime + kAuxPowerCycleTime
    local startAuxLightFailTime = fullAuxLightTime + PowerPoint.kAuxLightSafeTime
    local totalAuxLightFailTime = startAuxLightFailTime + PowerPoint.kAuxLightDyingTime
    
    local probeTint
    
    if timePassed < kPowerDownTime then
        local intensity = math.sin(Clamp(timePassed / kPowerDownTime, 0, 1) * math.pi / 2)
        probeTint = Color(intensity, intensity, intensity, 1)
    elseif timePassed < startAuxLightTime then
        probeTint = Color(0, 0, 0, 1)
    elseif timePassed < fullAuxLightTime then
    
        -- Fade red in smoothly. t will stay at zero during the individual delay time
        local t = timePassed - startAuxLightTime
        -- angle goes from zero to 90 degres in one kAuxPowerCycleTime
        local angleRad = (t / kAuxPowerCycleTime) * math.pi / 2
        -- and scalar goes 0->1
        local scalar = math.sin(angleRad)

        probeTint = Color(PowerPoint.kDisabledColor.r * scalar,
                          PowerPoint.kDisabledColor.g * scalar,
                          PowerPoint.kDisabledColor.b * scalar,
                          1)
 
    else
        self.activeProbes = false
    end

    if self.activeProbes then    
        for probe,_ in pairs(self.handler.probeTable) do
            probe:SetTint( probeTint )
        end
    end

    
    for renderLight,_ in pairs(self.activeLights) do
        
        local randomValue = renderLight.randomValue
        -- aux light starting to come on
        local startAuxLightTime = kPowerDownTime + kOffTime + randomValue * PowerPoint.kMaxAuxLightDelay 
        -- ... fully on
        local fullAuxLightTime = startAuxLightTime + kAuxPowerCycleTime
        -- aux lights starts to fade
        local startAuxLightFailTime = fullAuxLightTime + PowerPoint.kAuxLightSafeTime + randomValue * PowerPoint.kAuxLightFailTime
        -- ... and dies completly
        local totalAuxLightFailTime = startAuxLightFailTime + PowerPoint.kAuxLightDyingTime
        
        local intensity = nil
        local color = nil
        
        local showCommanderLight = false
        
        local player = Client.GetLocalPlayer()
        if player and player:isa("Commander") then
            showCommanderLight = true
        end
        
        if timePassed < kPowerDownTime then
            
            local scalar = math.sin( Clamp( timePassed / kPowerDownTime, 0, 1 ) * math.pi * 0.5 )
            scalar = (1 - scalar)
            if showCommanderLight then
                scalar = math.max(kMinCommanderLightIntensityScalar, scalar)
            end
            intensity = renderLight.originalIntensity * (1 - scalar)

        elseif timePassed < startAuxLightTime then
        
            if showCommanderLight then
                intensity = renderLight.originalIntensity * kMinCommanderLightIntensityScalar
            else
                intensity = 0  
            end     
            
        elseif timePassed < fullAuxLightTime then
        
            -- Fade red in smoothly. t will stay at zero during the individual delay time
            local t = timePassed - startAuxLightTime
            -- angle goes from zero to 90 degres in one kAuxPowerCycleTime
            local angleRad = ( t / kAuxPowerCycleTime ) * math.pi * 0.5
            -- and scalar goes 0->1
            local scalar = math.sin(angleRad)
            
            if showCommanderLight then
                scalar = math.max( kMinCommanderLightIntensityScalar, scalar )
            end
            
            --intensity = scalar * renderLight.originalIntensity
            intensity = Math.Clamp( scalar * renderLight.originalIntensity, kMinNoPowerIntensity, kMaxNoPowerIntensity )
            intensity = intensity * self:CheckFlicker(renderLight,PowerPoint.kAuxFlickerChance, scalar)
            
            if showCommanderLight then
                color = PowerPoint.kDisabledCommanderColor
            else
                color = PowerPoint.kDisabledColor
            end
     
        else
        
            -- Deactivate from initial state
            self.activeLights[renderLight] = nil
            
            -- in steady state, we shift lights between a constant state and a varying state.
            -- We assign each light to one of several groups, and then randomly start/stop cycling for each group. 
            local lightGroupIndex = math.floor(math.random() * NoPowerLightWorker.kNumGroups)
            self.lightGroups[lightGroupIndex].lights[renderLight] = true

        end
        
        SetLight(renderLight, intensity, color)
        
    end

    -- handle the light-cycling groups.
    for _,lightGroup in pairs(self.lightGroups) do
        lightGroup:Run(timePassed)
    end

end

-- used to cycle lights periodically in groups
class 'LightGroup'

function LightGroup:Init()

    self.lights = {}
    self.cycleUsedTime = 0
    self.cycleEndTime = 0
    self.cycleStartTime = 0
    self.nextThinkTime = 0
    self.stateFunction = LightGroup.RunFixed
    
    return self
    
end

function LightGroup:Run(time)

    if time >= self.nextThinkTime then
        self:stateFunction(time)
    end
    
end

function LightGroup:RunFixed(time)

    -- shift this group from fixed to cycling
    self.stateFunction = LightGroup.RunCycle
    self.cycleBaseTime = time
    self.cycleStartTime = time
    self.cycleEndTime = time + math.random(10)
    self.nextThinkTime = time
    
end

function LightGroup:RunCycle(time)  --FIXME Toggling Low/High lights causes script spam

    if time > self.cycleEndTime then
    
        -- end varying cycle and fix things for a while. Note that the intensity will
        -- stay a bit random, which is all to the good.
        self.stateFunction = LightGroup.RunFixed
        self.nextThinkTime = time + math.random(10)
        self.cycleUsedTime = self.cycleUsedTime + (time - self.cycleStartTime)
        
    else
    
        -- this is the time used to calc intensity. This is calculated so that when
        -- we restart after a pause, we continue where we left off.
        local t = time - self.cycleStartTime + self.cycleUsedTime 
        
        local showCommanderLight = false
        local player = Client.GetLocalPlayer()
        if player and player:isa("Commander") then
            showCommanderLight = true
        end
        
        for renderLight,_ in pairs(self.lights) do
        
            -- Fade disabled color in and out to make it very clear that the power is out        
            local scalar = math.cos((t / (kAuxPowerCycleTime / 2)) * math.pi / 2)
            local halfAmplitude = (1 - kAuxPowerMinIntensity) / 2
            
            local minIntensity = kAuxPowerMinIntensity
            color = PowerPoint.kDisabledColor
            
            if showCommanderLight then
            
                minIntensity = kAuxPowerMinCommanderIntensity
                color = PowerPoint.kDisabledCommanderColor
                
            end
            
            local disabledIntensity = ( kAuxPowerMinIntensity + halfAmplitude + scalar * halfAmplitude )
            intensity = renderLight.originalIntensity * disabledIntensity
            
            SetLight( renderLight, intensity, color )
            
        end
        
    end
    
end