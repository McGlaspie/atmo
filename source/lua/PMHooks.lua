
ModLoader.SetupFileHook( "lua/Globals.lua", "lua/PMGlobals.lua", "post" )

if Server then
    ModLoader.SetupFileHook( "lua/NS2GameRules.lua", "lua/PMNS2GameRules.lua", "post" )
end

ModLoader.SetupFileHook( "lua/ConstructMixin.lua", "lua/PMConstructMixin.lua", "post" )
ModLoader.SetupFileHook( "lua/LiveMixin.lua", "lua/PMLiveMixin.lua", "post" )
ModLoader.SetupFileHook( "lua/AlienStructureMoveMixin.lua", "lua/PMAlienStructureMoveMixin.lua", "post" )

ModLoader.SetupFileHook( "lua/Location.lua", "lua/PMLocation.lua", "post" )
--ModLoader.SetupFileHook( "lua/PowerPoint.lua", "lua/PMPowerPoint.lua", "post" )

ModLoader.SetupFileHook( "lua/Hive.lua", "lua/PMHive.lua", "post" )
ModLoader.SetupFileHook( "lua/Harvester.lua", "lua/PMHarvester.lua", "post" )
ModLoader.SetupFileHook( "lua/Cyst.lua", "lua/PMCyst.lua", "post" )
--ModLoader.SetupFileHook( "lua/Drifter.lua", "lua/PMDrifter.lua", "post" )

ModLoader.SetupFileHook( "lua/Marine.lua", "lua/PMMarine.lua", "post" )
ModLoader.SetupFileHook( "lua/Exo.lua", "lua/PMExo.lua", "post" )
--ModLoader.SetupFileHook( "lua/ARC.lua", "lua/PMARC.lua", "post" )
--ModLoader.SetupFileHook( "lua/MAC.lua", "lua/PMMAC.lua", "post" )