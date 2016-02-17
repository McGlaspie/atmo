
local kSmashEggRange = 1.5

local function SmashNearbyEggs(self)

    assert(Server)
    
    if not GetIsVortexed(self) then
    
        local nearbyEggs = GetEntitiesWithinRange("Egg", self:GetOrigin(), kSmashEggRange)
        for e = 1, #nearbyEggs do
            nearbyEggs[e]:Kill(self, self, self:GetOrigin(), Vector(0, -1, 0))
        end
        
        local nearbyEmbryos = GetEntitiesWithinRange("Embryo", self:GetOrigin(), kSmashEggRange)
        for e = 1, #nearbyEmbryos do
            nearbyEmbryos[e]:Kill(self, self, self:GetOrigin(), Vector(0, -1, 0))
        end
        
    end
    
    // Keep on killing those nasty eggs forever.
    return true
    
end

local kIdle2D = PrecacheAsset("sound/NS2.fev/marine/heavy/idle_2D")



function Exo:OnCreate()

    Player.OnCreate(self)
    
    InitMixin(self, BaseMoveMixin, { kGravity = Player.kGravity })
    InitMixin(self, GroundMoveMixin)
    InitMixin(self, VortexAbleMixin)
    InitMixin(self, LOSMixin)
    InitMixin(self, CameraHolderMixin, { kFov = kExoFov })
    InitMixin(self, ScoringMixin, { kMaxScore = kMaxScore })
    InitMixin(self, WeldableMixin)
    InitMixin(self, CombatMixin)
    InitMixin(self, SelectableMixin)
    InitMixin(self, CorrodeMixin)
    InitMixin(self, TunnelUserMixin)
    InitMixin(self, ParasiteMixin)
    InitMixin(self, MarineActionFinderMixin)
    InitMixin(self, WebableMixin)
    InitMixin(self, MarineVariantMixin)
    InitMixin(self, ExoVariantMixin)
    
    self:SetIgnoreHealth(true)
    
    if Server then
        self:AddTimedCallback(SmashNearbyEggs, 0.1)
    end
    
    self.deployed = false
    
    self.flashlightOn = false
    self.flashlightLastFrame = false
    self.idleSound2DId = Entity.invalidId
    self.timeThrustersEnded = 0
    self.timeThrustersStarted = 0
    self.inventoryWeight = 0
    self.thrusterMode = kExoThrusterMode.Vertical
    self.catpackboost = false
    self.timeCatpackboost = 0
    self.ejecting = false
    
    self.creationTime = Shared.GetTime()
    
    if Server then
    
        self.idleSound2D = Server.CreateEntity(SoundEffect.kMapName)
        self.idleSound2D:SetAsset(kIdle2D)
        self.idleSound2D:SetParent(self)
        self.idleSound2D:Start()
        
        // Only sync 2D sound with this Exo player.
        self.idleSound2D:SetPropagate(Entity.Propagate_PlayerOwner)
        
        self.idleSound2DId = self.idleSound2D:GetId()
        
    elseif Client then
        
        //TODO Change to two lights that are spots with wide cone, one for each "headlight"?
        self.flashlight = Client.CreateRenderLight()
        
        self.flashlight:SetType(RenderLight.Type_Spot)
        self.flashlight:SetColor(Color(.8, .8, 1))
        self.flashlight:SetInnerCone(math.rad(35))  //30
        self.flashlight:SetOuterCone(math.rad(48))  //45
        self.flashlight:SetIntensity(12)    //10
        self.flashlight:SetRadius(28)   //25
        self.flashlight:SetAtmosphericDensity( 0.025 )  //TODO Use opts atmo-density //% depth auto-cutoff?
        self.flashlight:SetSpecular( false )
        --self.flashlight:SetCastsShadows( Client.GetOptionBoolean( kShadowsOptionsKey, false ) )
        self.flashlight:SetCastsShadows( false ) --Shadows are too expensive, avg 2.7Fps drop, PER flashlight
        self.flashlight:SetGoboTexture("models/marine/male/flashlight.dds")
        
        self.flashlight:SetIsVisible(false)
        
        self.idleSound2DId = Entity.invalidId

    end
    
end


if Client then


function Exo:OnUpdateRender()
    
        PROFILE("Exo:OnUpdateRender")
        
        Player.OnUpdateRender(self)
        
        local localPlayer = Client.GetLocalPlayer()
        local showHighlight = localPlayer ~= nil and localPlayer:isa("Alien") and self:GetIsAlive()
        
        /* disabled for now
        local model = self:GetRenderModel()
        
        if model then
        
            if showHighlight and not self.marineHighlightMaterial then
                
                self.marineHighlightMaterial = AddMaterial(model, "cinematics/vfx_materials/marine_highlight.material")
                
            elseif not showHighlight and self.marineHighlightMaterial then
            
                RemoveMaterial(model, self.marineHighlightMaterial)
                self.marineHighlightMaterial = nil
            
            end
            
            if self.marineHighlightMaterial then
                self.marineHighlightMaterial:SetParameter("distance", (localPlayer:GetEyePos() - self:GetOrigin()):GetLength())
            end
        
        end
        */
        
        local isLocal = self:GetIsLocalPlayer()
        local flashLightVisible = self.flashlightOn and (isLocal or self:GetIsVisible()) and self:GetIsAlive()
        local flaresVisible = flashLightVisible and (not isLocal or self:GetIsThirdPerson())
        
        // Synchronize the state of the light representing the flash light.
        self.flashlight:SetIsVisible(flashLightVisible)
        self.flares:SetIsVisible(flaresVisible)
        
        if self.flashlightOn then
        
            local coords = Coords(self:GetViewCoords())
            coords.origin = coords.origin + coords.zAxis * 0.75
            
            self.flashlight:SetCoords(coords)
            --[[
            // Only display atmospherics for third person players.
            local density = 0.2
            if isLocal and not self:GetIsThirdPerson() then
                density = 0
            end
            self.flashlight:SetAtmosphericDensity(density)
            --]]
        end
        
        if self:GetIsLocalPlayer() then
        
            local armorDisplay = self.armorDisplay
            if not armorDisplay then

                armorDisplay = Client.CreateGUIView(256, 256, true)
                armorDisplay:Load("lua/GUIExoArmorDisplay.lua")
                armorDisplay:SetTargetTexture("*exo_armor")
                self.armorDisplay = armorDisplay

            end
            
            local armorAmount = self:GetIsAlive() and math.ceil(math.max(1, self:GetArmor())) or 0
            armorDisplay:SetGlobal("armorAmount", armorAmount)
            
            // damaged effects for view model. triggers when under 60% and a stronger effect under 30%. every 3 seconds and non looping, so the effects fade out when healed up
            if not self.timeLastDamagedEffect or self.timeLastDamagedEffect + 3 < Shared.GetTime() then
            
                local healthScalar = self:GetHealthScalar()
                
                if healthScalar < .7 then
                
                    gHurtCinematic = Client.CreateCinematic(RenderScene.Zone_ViewModel)
                    local cinematicName = kExoViewDamaged
                    
                    if healthScalar < .4 then
                        cinematicName = kExoViewHeavilyDamaged
                    end
                    
                    gHurtCinematic:SetCinematic(cinematicName)
                
                end
                
                self.timeLastDamagedEffect = Shared.GetTime()
                
            end
            
        elseif self.armorDisplay then
        
            Client.DestroyGUIView(self.armorDisplay)
            self.armorDisplay = nil
            
        end
        
    end


end --End-If Client


--Class_Reload("Exo", {})