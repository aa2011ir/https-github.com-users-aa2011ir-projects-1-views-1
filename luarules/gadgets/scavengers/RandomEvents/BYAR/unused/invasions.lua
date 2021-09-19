
local function invasion(currentFrame)
ScavSendNotification("scav_eventswarm")
local invasionUnitsLand = {"armflea_scav", "armfav_scav", "corfav_scav", "armbeaver_scav", "cormuskrat_scav",}
local invasionUnitsSea = {"armbeaver_scav","cormuskrat_scav",}
local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
local groupsize = groupsize*((unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.airmultiplier)*0.33)*unitSpawnerModuleConfig.t0multiplier*4
local groupsize = math.ceil(groupsize*(teamcount/2))
	for i = 1,groupsize do
		for y = 1,100 do
			local posx = math_random(150,mapsizeX-150)
			local posz = math_random(150,mapsizeZ-150)
			local posy = Spring.GetGroundHeight(posx, posz)
			local CanSpawnLand = posLandCheck(posx, posy, posz, 150)
			local CanSpawnSea = posSeaCheck(posx, posy, posz, 150)
			CanSpawnEvent = posOccupied(posx, posy, posz, 150)
			if CanSpawnEvent then
				CanSpawnEvent = posCheck(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				CanSpawnEvent = posLosCheckReversed(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				CanSpawnEvent = posMapsizeCheck(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				if CanSpawnLand == true then
					QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, currentFrame+(i))
					QueueSpawn(invasionUnitsLand[math.random(1,#invasionUnitsLand)], posx, posy, posz, math_random(0,3),GaiaTeamID, currentFrame+90+(i))
					--Spring.CreateUnit(invasionUnitsLand[pickedInvasionUnitLand], posx, posy, posz, math_random(0,3),GaiaTeamID)
				elseif CanSpawnSea == true then
					QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, currentFrame+(i))
					QueueSpawn(invasionUnitsSea[math.random(1,#invasionUnitsSea)], posx, posy, posz, math_random(0,3),GaiaTeamID, currentFrame+90+(i))
					--Spring.CreateUnit(invasionUnitsSea[pickedInvasionUnitLand], posx, posy, posz, math_random(0,3),GaiaTeamID)
				end
				break
			end
		end
	end
end


local function chickenInvasion1(currentFrame)
	Spring.Echo("Chicken Invasion Event")
	local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
	local chickens = {"chicken1_scav","chicken1b_scav","chicken1c_scav","chicken1d_scav","chicken1x_scav","chicken1y_scav","chicken1z_scav","chickens1_scav","chicken_dodo1_scav","chickenc3_scav","chickenc3b_scav","chickenc3c_scav","chickenw2_scav",}
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName == "roost_scav" then
			EventChickenSpawner = unitID
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			
			local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
			local groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
			local groupsize = math.ceil(groupsize*(teamcount/2))
			for z = 1,groupsize do
				Spring.CreateUnit(chickens[math_random(1,#chickens)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
			end
			break
		end
		if y == #scavUnits and unitName ~= "roost_scav" then
			for i = 1,1000 do
				local posx = math_random(300,mapsizeX-300)
				local posz = math_random(300,mapsizeZ-300)
				local posy = Spring.GetGroundHeight(posx, posz)
				CanSpawnEvent = posOccupied(posx, posy, posz, 300)
				if CanSpawnEvent then
					CanSpawnEvent = posCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = posLosCheckNoRadar(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = posLandCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = posMapsizeCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					Spring.CreateUnit("roost_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx+200+(math_random(-100,100)), posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx-200+(math_random(-100,100)), posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx, posy, posz+200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx, posy, posz-200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx-200+(math_random(-100,100)), posy, posz-200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx+200+(math_random(-100,100)), posy, posz-200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx-200+(math_random(-100,100)), posy, posz+200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx+200+(math_random(-100,100)), posy, posz+200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
					local groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					local groupsize = math.ceil(groupsize*(teamcount/2))*3
					for z = 1,groupsize do
						Spring.CreateUnit(chickens[math_random(1,#chickens)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					end
					break
				end
			end
		end
	end
end

return {
	-- invasion,
	-- chickenInvasion1,
}