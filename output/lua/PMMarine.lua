
function Marine:OnCreate()

    InitMixin(self, BaseMoveMixin, { kGravity = Player.kGravity })
    InitMixin(self, GroundMoveMixin)
    InitMixin(self, JumpMoveMixin)
    InitMixin(self, CrouchMoveMixin)
    InitMixin(self, LadderMoveMixin)
    InitMixin(self, CameraHolderMixin, { kFov = kDefaultFov })
    InitMixin(self, MarineActionFinderMixin)
    InitMixin(self, ScoringMixin, { kMaxScore = kMaxScore })
    InitMixin(self, VortexAbleMixin)
    InitMixin(self, CombatMixin)
    InitMixin(self, SelectableMixin)
    
    Player.OnCreate(self)
    
    InitMixin(self, DissolveMixin)
    InitMixin(self, LOSMixin)
    InitMixin(self, ParasiteMixin)
    InitMixin(self, RagdollMixin)
    InitMixin(self, WebableMixin)
    InitMixin(self, CorrodeMixin)
    InitMixin(self, TunnelUserMixin)
    InitMixin(self, PhaseGateUserMixin)
    InitMixin(self, PredictedProjectileShooterMixin)
    InitMixin(self, MarineVariantMixin)
    
    if Server then
    
        self.timePoisoned = 0
        self.poisoned = false
        
        // stores welder / builder progress
        self.unitStatusPercentage = 0
        self.timeLastUnitPercentageUpdate = 0
        
    elseif Client then
    
        self.flashlight = Client.CreateRenderLight()
        
        self.flashlight:SetType( RenderLight.Type_Spot )
        self.flashlight:SetColor( Color( .8, .8, 1 ) )
        self.flashlight:SetInnerCone( math.rad(25) )    //30
        self.flashlight:SetOuterCone( math.rad(35) )    //35
        self.flashlight:SetIntensity( 10 )
        self.flashlight:SetRadius( 22 ) //15
        --FIXME STILL not working...
        --  Would self.flashlight replacement work?
        self.flashlight:SetAtmosphericDensity( 0.025 )  //TODO Use opts atmo-density //% depth auto-cutoff?
        self.flashlight:SetSpecular( false )
        --self.flashlight:SetCastsShadows( Client.GetOptionBoolean( kShadowsOptionsKey, false ) )
        self.flashlight:SetCastsShadows( false ) --Shadows are too expensive, avg 2.7Fps drop, PER flashlight
        self.flashlight:SetGoboTexture( "models/marine/flashlight.dds" )
        
        self.flashlight:SetIsVisible( false )
        
        InitMixin(self, TeamMessageMixin, { kGUIScriptName = "GUIMarineTeamMessage" })

        InitMixin(self, DisorientableMixin)
        
        --Log("Marine:OnCreate() - self.falshlight:GetAtmosphericDensity() = %f", self.flashlight:GetAtmosphericDensity() )
        
    end

end


if Client then


function Marine:OnUpdateRender()

    PROFILE("Marine:OnUpdateRender")
    
    Player.OnUpdateRender(self)
    
    local isLocal = self:GetIsLocalPlayer()
    
    -- Synchronize the state of the light representing the flash light.
    self.flashlight:SetIsVisible(self.flashlightOn and (isLocal or self:GetIsVisible()) )
    
    if self.flashlightOn then
    
        local coords = Coords(self:GetViewCoords())
        coords.origin = coords.origin + coords.zAxis * 0.75
        
        self.flashlight:SetCoords(coords)
        
        -- Only display atmospherics for third person players.
        --local density = 0.025
        --[[
        if isLocal and not self:GetIsThirdPerson() then
            density = 0
        end
        --]]
        --self.flashlight:SetAtmosphericDensity(0.025)    --TODO Tie to user's atmo density setting
        
    end
    
    local localPlayer = Client.GetLocalPlayer()
    local showHighlight = localPlayer ~= nil and localPlayer:isa("Alien") and self:GetIsAlive()
    
    /* disabled for now
    local model = self:GetRenderModel()

    if model then
    
        if showHighlight and not self.marineHighlightMaterial then
            
            self.marineHighlightMaterial = AddMaterial(model, kHighlightMaterial)
            
        elseif not showHighlight and self.marineHighlightMaterial then
        
            RemoveMaterial(model, self.marineHighlightMaterial)
            self.marineHighlightMaterial = nil
        
        end
        
        if self.marineHighlightMaterial then
            self.marineHighlightMaterial:SetParameter("distance", (localPlayer:GetEyePos() - self:GetOrigin()):GetLength())
        end
    
    end
    */

end

end --End-If Client


--Class_Reload("Marine", {})