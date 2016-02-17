

--TODO Add functor filter param
--TODO Add caching mechanism
function GetEntitiesByLocation( location, entityType )

	assert( location:isa("Location") )
	
	if location and entityType then
		
		local locationEnts = location:GetEntitiesInTrigger()
		local foundEntities = {}
		
		for _, entity in ipairs( locationEnts ) do
			
			if entityType ~= nil then
				if entity:isa( entityType ) then
					table.insert( foundEntities, entity )
				end
			else
				table.insert( foundEntities, entity )
			end
			
		end
		
		return foundEntities
	
	end
	
	return nil

end


