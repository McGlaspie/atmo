
if Server then

    //Note: Copied locals for the sake of "to hell with it" ...yup
    
    local function CanMove(self, order)
        local canMove = order and GetIsUnitActive(self) and order:GetType() == kTechId.Move

        // CQ: this is interesting ... who is responsible for this rule? Doing it like this means that
        // this mixin knows about the teleporting mixin. OTOH, the teleporting mixin could know about
        // us and implement a GetStructureMoveable() to block when teleporting. OT3H, GetStructureMovable
        // is not stackable for multiple mixins (only the first method can return a value)
        // Correct solution would be for the actual class to implement it, but that either duplicates code
        // or you move up the default to the best base class and comment that it is only used for moving
        // things.  
        canMove = canMove and (not HasMixin(self, "TeleportAble") or not self:GetIsTeleporting())

        canMove = canMove and (not self.GetStructureMoveable or self:GetStructureMoveable(self))
        
        return canMove
    end
       
    // Support for both StaticTargetMixin and TargetCacheMixin.
    // Structures implementing StaticTarget are "move rarely" structures, so we need to
    // notify the StaticTargetMixin that they have shifted position. For performance reasons,
    // we notify only when the structure has moved 1 m or when they stop moving.
    // Structures that move 
    local function HandleTargeting(self, speed, deltaTime)
        
        self.distanceMoved = self.distanceMoved + speed * deltaTime
        
        if self.distanceMoved > 1 or (self.distanceMoved > 0 and not self.moving) then
        
            if HasMixin(self, "StaticTarget") then
                self:StaticTargetMoved()
            end

            // CQ: Update TargetCacheMixin to have a required AttackerMoved method to handle a target selector user moving
            if not self.moving and self.AttackerMoved then
                self:AttackerMoved()
            end
           
            self.distanceMoved = 0
            
        end        
        
    end
        
    // Remove from mesh when we start moving and add back when we stop moving    
    local function HandleObstacle(self)
    
        if currentOrder and currentOrder:GetType() == kTechId.Move then

            self:RemoveFromMesh()

            if not self.removedMesh then            
                
                self.removedMesh = true
                self:OnObstacleChanged()
            
            end
            
        elseif self.removedMesh then

            self:AddToMesh()
            self.removedMesh = false
            
        end
    end


    function AlienStructureMoveMixin:OnUpdate(deltaTime)
      
        PROFILE("AlienStructureMoveMixin:OnUpdate")
    
        local currentOrder = self:GetCurrentOrder()
        local speed = 0

        if CanMove(self, currentOrder) then

            speed = self:GetMaxSpeed()
            
            /* CQ: remove shiftboost
            if self.shiftBoost then
                speed = speed * kShiftStructurespeedScalar
            end
            */
            self:MoveToTarget(PhysicsMask.AIMovement, currentOrder:GetLocation(), speed, deltaTime)
            
            if self:IsTargetReached(currentOrder:GetLocation(), kAIMoveOrderCompleteDistance) then
                self:CompletedCurrentOrder()
                
                //FIXME below does NOT update occupancy # correctly
                // - need to ensure that Unroot removes occupancy and Root adds it!
                GetTerritoryTracker():AddTerritoryOccupant( self:GetLocationName(), self:GetTeamNumber(), self:GetId() )
                //???? Does this method update Location for self? Is it only on next update?
                //TerritoryTracker handles "duplicate" Entity-IDs
                
                self.moving = false
            else
                self.moving = true            
            end
            
        else
            self.moving = false
        end
        
        HandleTargeting(self, speed, deltaTime)
        
        if HasMixin(self, "Obstacle") then
            HandleObstacle(self)
        end   
        
    end

end

