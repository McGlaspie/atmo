--[[=== Copyright (c) 2003-2015, Unknown Worlds Entertainment, Inc. All rights reserved. =======

    Environmental SFX/VFX for Kharaa Territory. Originally based on work from Samus
    but with heavy modifications to fit into the concept/framework of Territories.
    
    Author: Brock 'McGlaspie' Gillespie (mcglaspie@gmail.com)
    Contributions: Brian 'Samus' Arneson (samusdroid@gmail.com) 
    
===== For more information, visit us at http://www.unknownworlds.com =======================--]]

BacteriumZoneNodeMixin = CreateMixin( BacteriumZoneNodeMixin )
BacteriumZoneNodeMixin.type = "BacteriumZoneNode"

--XXX Add required mixins?

--TODO Find sound for "full" occupancy visualization(s)
-- - would need to be dynamic ambient sound, an position an average of "infested-sources"

--Use maturity level to denote more "dense" speck cloud? Biomass?
--Add fog/haze/mist like fx? Sounds?
local kBateriumCinematics = {}
kBateriumCinematics["Small"] = PrecacheAsset("cinematics/alien/common/bacterium_sml.cinematic")
kBateriumCinematics["SmallLight"] = PrecacheAsset("cinematics/alien/common/bacterium_sml_light.cinematic")
kBateriumCinematics["Medium"] = PrecacheAsset("cinematics/alien/common/bacterium_med.cinematic")
kBateriumCinematics["Large"] = PrecacheAsset("cinematics/alien/common/bacterium_large.cinematic")

--TODO Tie to client option(s)
-- - Change cinematic based on infestation setting (not Rich, no glowies...or Particle FX level?)
-- - Tie to atmospherics and add "extra" atomospheric light(s) as additional cinematic
--Note: above would require separating lighting from glowies cinematic, thus two cins per source (bad!)
function BacteriumZoneNodeMixin:__initmixin()
    
    if Client then
        //local lightsEnabled = Client.GetOptionBoolean("graphics/structureLights", true)
        //TODO Tie to Infestation detail settings (for bacterium whisps/things), or particle VFX setting instead?
        self:InitCinematic()
        
        self:SetUpdates(true)
    end
    
end

if Client then
    
    function BacteriumZoneNodeMixin:InitCinematic()
        
        local className = self:GetClassName()
        
        self.bacteriumCinematic = nil
        self.bacteriumCinematicSecondary = nil
        
        self.bacteriumCinematic = Client.CreateCinematic( RenderScene.Zone_Default )
        self.bacteriumCinematic:SetCinematic( self:GetCinematicByClass(className, false) )
        self.bacteriumCinematic:SetRepeatStyle( Cinematic.Repeat_Endless )
        self.bacteriumCinematic:SetIsActive( false )
        self.bacteriumCinematic:SetIsVisible( false )
        self.bacteriumCinematic:SetParent( self )   //required for relavancy/sighting
        self.bacteriumCinematic:SetCoords( self:GetCinematicOffset(className) )
        
        if className == "Cyst" then   --handle via optional mixin-callback?
            self.bacteriumCinematicSecondary = Client.CreateCinematic( RenderScene.Zone_Default )
            self.bacteriumCinematicSecondary:SetCinematic( self:GetCinematicByClass(className, true) )
            self.bacteriumCinematicSecondary:SetRepeatStyle( Cinematic.Repeat_Endless )
            self.bacteriumCinematicSecondary:SetIsActive( false )
            self.bacteriumCinematicSecondary:SetIsVisible( false )
            self.bacteriumCinematicSecondary:SetParent( self )   //required for relavancy/sighting
            self.bacteriumCinematicSecondary:SetCoords( self:GetCinematicOffset(className) )
        end
    end
    
    function BacteriumZoneNodeMixin:GetCinematicOffset(className)
        local coords = self:GetCoords()
        
        if className == "Harvester" then
            coords.origin = coords.origin + coords.yAxis * 0.36
        elseif className == "Cyst" then
            coords.origin = coords.origin + coords.yAxis * 0.18
        elseif className == "Hive" then
            coords.origin = coords.origin + coords.yAxis * -0.285     //-0.125
        else
            Log("ERROR: BacteriumZoneNodeMixin:GetCinematicOffset() - unknown className passed: %s", className)
        end
        
        return coords
    end
    
    function BacteriumZoneNodeMixin:GetCinematicByClass( className, includeSecondary )  
        if includeSecondary and className == "Cyst" then
            return kBateriumCinematics["SmallLight"]
        end
        
        if className == "Cyst" then
            return kBateriumCinematics["Small"]
        elseif className == "Harvester" then
            return kBateriumCinematics["Medium"]
        elseif className == "Hive" then
            return kBateriumCinematics["Large"]
        else
            Log( "ERROR: BacteriumZoneNodeMixin:GetCinematicByClass() - unknown classname passed[%s]", className )
        end
        
        return kBateriumCinematics["Small"]
    end
    
    --XXX If hive and taking damage (much like powernodes, pulsate lights?)
    function BacteriumZoneNodeMixin:OnUpdate( deltaTime )   //Render?
        
        local localPlayer = Client.GetLocalPlayer()
        if localPlayer then
            
            local showCinematic = false
            
            if self.bacteriumCinematic ~= nil then
                if self:GetIsBuilt() and HasMixin( self, "Live" ) and self:GetIsAlive() then
                    showCinematic = not HasMixin(self, "Cloakable") or not self:GetIsCloaked() or not GetAreEnemies( self, localPlayer )
                end
                
                self.bacteriumCinematic:SetIsActive( showCinematic )
                self.bacteriumCinematic:SetIsVisible( showCinematic )
            end
            
            if self.bacteriumCinematicSecondary ~= nil and self:GetClassName() == "Cyst" then
                showCinematic = showCinematic and self:GetIsConnected()
                self.bacteriumCinematicSecondary:SetIsActive( showCinematic )
                self.bacteriumCinematicSecondary:SetIsVisible( showCinematic )
            end
        end
        
    end


end --If-Client


function BacteriumZoneNodeMixin:OnDestroy()
    
    if Client then    
            
        if self.bacteriumCinematic ~= nil then
            Client.DestroyCinematic( self.bacteriumCinematic )
            self.bacteriumCinematic = nil
        end
        
        if self.bacteriumCinematicSecondary ~= nil then
            Client.DestroyCinematic( self.bacteriumCinematicSecondary )
            self.bacteriumCinematicSecondary = nil
        end
        
    end
    
end

