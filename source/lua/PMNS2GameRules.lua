
local originalReset = NS2Gamerules.ResetGame
function NS2Gamerules:ResetGame()
    GetTerritoryTracker():Reset()   --Dammit, this is annoying
    
    originalReset(self)
end


Class_Reload( "NS2Gamerules", {} )