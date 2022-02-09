Spring.Echo("[Scavengers] Constructor Controller initialized")

local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/blueprint_tiers.lua')
local blueprintsController = VFS.Include("luarules/gadgets/scavengers/Blueprints/BYAR/blueprint_controller.lua")
local constructorTimer = scavconfig.constructorControllerModuleConfig.constructortimerstart

local voiceNotificationsCount = 2
local mapCenterX = Game.mapSizeX / 2
local mapCenterZ = Game.mapSizeZ / 2
local mapCenterY = Spring.GetGroundHeight(mapCenterX, mapCenterZ)
local mapDiagonal = math.ceil( math.sqrt((Game.mapSizeX * Game.mapSizeX) + (Game.mapSizeZ * Game.mapSizeZ)) )
local initialCommanderSpawn = true

local function generateOrderParams(unitID, orderrange)
	local posx, posy, posz = Spring.GetUnitPosition(unitID)
	local posrange = orderrange*0.75
	return { posx + math.random(-posrange, posrange), posy, posz + math.random(-posrange, posrange), orderrange}
end

local function countScavCommanders()
	return Spring.GetTeamUnitDefCount(ScavengerTeamID, UnitDefNames.corcom_scav.id) + Spring.GetTeamUnitDefCount(ScavengerTeamID, UnitDefNames.armcom_scav.id)
end

local function assistantOrders(n, unitID)
	local x,y,z = Spring.GetUnitPosition(unitID)
	Spring.GiveOrderToUnit(unitID, CMD.PATROL,generateOrderParams(unitID, 500), {"shift"})
end

-- local function assistDroneRespawn(deadDroneID, drone)
-- 	if CommanderDronesList[deadDroneID] then
-- 		local commanderID = CommanderDronesList[deadDroneID]
-- 		for i = 1,#AliveEnemyCommanders do
-- 			local commanderTest = AliveEnemyCommanders[i]
-- 			if commanderID == commanderTest then
-- 				local x,y,z = Spring.GetUnitPosition(commanderID)
-- 				local commanderTeam = Spring.GetUnitTeam(commanderID)
-- 				local posx = x+math.random(-64,64)
-- 				local posz = z+math.random(-64,64)
-- 				local unitID = Spring.CreateUnit(drone, posx, y+96, posz, 0, commanderTeam)
-- 				Spring.SpawnCEG("scav-spawnexplo", posx, y+96, posz,0,0,0)
-- 				Spring.GiveOrderToUnit(unitID, CMD.GUARD, commanderID, {})
-- 				CommanderDronesList[unitID] = commanderID
-- 				break
-- 			end
-- 		end
-- 		CommanderDronesList[deadDroneID] = nil
-- 	end
-- end

local function resurrectorOrders(n, unitID)
	Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, generateOrderParams(unitID, 500), 0)
	Spring.GiveOrderToUnit(unitID, CMD.REPAIR, generateOrderParams(unitID, 500), {"shift"})
	Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, generateOrderParams(unitID, 500), {"shift"})
	Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, generateOrderParams(unitID, 500), {"shift"})
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, generateOrderParams(unitID, 2000), {"shift"})
end

local function capturerOrders(n, unitID)
	Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, generateOrderParams(unitID, 500), 0)
	local nearestEnemy = Spring.GetUnitNearestEnemy(unitID, mapDiagonal*0.05, true)
	if nearestenemy then
		Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, { nearestEnemy }, 0)
		local x,y,z = Spring.GetUnitPosition(nearestEnemy)
		Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { x, y, z }, {"meta", "shift", "alt"})
	end
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, generateOrderParams(unitID, 2000), {"shift"})
end

local function collectorOrders(n, unitID)
	Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, generateOrderParams(unitID, 500), 0)
	Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, generateOrderParams(unitID, 500), {"shift"})
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, generateOrderParams(unitID, 2000), {"shift"})
end

local function reclaimerOrders(n, unitID)
	Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
	local nearestenemy = Spring.GetUnitNearestEnemy(unitID, mapDiagonal*0.05, true)
	if nearestenemy then
		Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { nearestenemy }, 0)
		local x,y,z = Spring.GetUnitPosition(nearestenemy)
		Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { x, y, z }, {"meta", "shift", "alt"})
	end
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, generateOrderParams(unitID, 2000), {"shift"})
end

local function spawnConstructor(n)
	local spawnOverdue = constructorTimer > scavconfig.constructorControllerModuleConfig.constructortimer or (countScavCommanders() < scavconfig.constructorControllerModuleConfig.minimumconstructors and constructorTimer > 0) 
	local exclusionPeriodExpired = constructorTimer > 0

	if spawnOverdue and numOfSpawnBeacons > 0 and exclusionPeriodExpired then
		local scavengerunits = Spring.GetTeamUnits(ScavengerTeamID)
		local spawnBeacons = {}

		for i = 1, #scavengerunits do
			local scav = scavengerunits[i]
			if scavSpawnBeacon[scav] then
				table.insert(spawnBeacons,scav)
			end
		end

		for b = 1,100 do
			local pickedBeaconTest = spawnBeacons[math_random(1,#spawnBeacons)]
			if pickedBeaconTest then
				pickedBeacon = pickedBeaconTest
			end
		end

		if pickedBeacon == 16000000 then
			return
		end

		local posx, posy, posz = Spring.GetUnitPosition(pickedBeacon)
		local nearestEnemy = Spring.GetUnitNearestEnemy(pickedBeacon, 99999, false)
		if nearestEnemy == nil then -- no enemy units left on the map, the humans are dead!
			return  -- binary solo 1111001 11111001
		end
		local nearestEnemyTeam = Spring.GetUnitTeam(nearestEnemy)
		local canSpawnCommanderHere

		if nearestEnemyTeam == bestTeam then
			canSpawnCommanderHere = true
		else
			local r = math.random(0, 4)
			if r == 0 then
				canSpawnCommanderHere = true
			else
				canSpawnCommanderHere = false
			end
		end

		if canSpawnCommanderHere then
			-- if initialCommanderSpawn then
			-- 	ScavSendNotification("scav_scavcomdetected")
			-- 	initialCommanderSpawn = false
			-- else
			-- 	local s = math.random(0, voiceNotificationsCount)
			-- 	if s == 0 then
			-- 		ScavSendNotification("scav_scavadditionalcomdetected")
			-- 	elseif s == 1 then
			-- 		ScavSendNotification("scav_scavanotherscavcomdetected")
			-- 	elseif s == 2 then
			-- 		ScavSendNotification("scav_scavnewcomentered")
			-- 	elseif s == 3 then
			-- 		ScavSendNotification("scav_scavcomspotted")
			-- 	elseif s == 4 then
			-- 		ScavSendNotification("scav_scavcomnewdetect")
			-- 	else
			-- 		ScavSendMessage("A Scavenger Commander detected")
			-- 	end

			-- 	if voiceNotificationsCount < 20 then
			-- 		voiceNotificationsCount = voiceNotificationsCount + 1
			-- 	end
			-- end

			spawnBeaconsController.SpawnBeacon(n)

			if scavconfig.constructorControllerModuleConfig.useresurrectors then
				Spring.CreateUnit("scavengerdroppod_scav", posx + 32, posy, posz, math.random(0, 3), ScavengerTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx - 32, posy, posz, math.random(0, 3), ScavengerTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz + 32, math.random(0, 3), ScavengerTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz - 32, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit("scavengerdroppod_scav", posx + 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit("scavengerdroppod_scav", posx - 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit("scavengerdroppod_scav", posx - 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID)
				-- Spring.CreateUnit("scavengerdroppod_scav", posx + 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID)

				if posy > 0 then
					local resurrector = constructorUnitList.Resurrectors[math.random(#constructorUnitList.Resurrectors)]
					spawnQueueLibrary.AddToSpawnQueue(resurrector, posx + 32, posy, posz, math.random(0, 3), ScavengerTeamID, n + 150 + 1)
					spawnQueueLibrary.AddToSpawnQueue(resurrector, posx - 32, posy, posz, math.random(0, 3), ScavengerTeamID, n + 150 + 2)
					spawnQueueLibrary.AddToSpawnQueue(resurrector, posx, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 3)
					spawnQueueLibrary.AddToSpawnQueue(resurrector, posx, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 4)
					-- spawnQueueLibrary.AddToSpawnQueue(resurrector, posx + 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 5)
					-- spawnQueueLibrary.AddToSpawnQueue(resurrector, posx - 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 6)
					-- spawnQueueLibrary.AddToSpawnQueue(resurrector, posx - 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 7)
					-- spawnQueueLibrary.AddToSpawnQueue(resurrector, posx + 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 8)
				elseif scavconfig.constructorControllerModuleConfig.searesurrectors then
					local seaResurrector = constructorUnitList.ResurrectorsSea[math.random(#constructorUnitList.ResurrectorsSea)]
					spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx + 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 1)
					spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx - 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 2)
					spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx - 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 3)
					spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx + 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 4)
					-- spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx + 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 5)
					-- spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx - 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 6)
					-- spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx - 32, posy, posz + 32, math.random(0, 3), ScavengerTeamID, n + 150 + 7)
					-- spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx + 32, posy, posz - 32, math.random(0, 3), ScavengerTeamID, n + 150 + 8)
				end
			end

			constructorTimer = 0
			local constructor = constructorUnitList.Constructors[math.random(#constructorUnitList.Constructors)]
			spawnQueueLibrary.AddToSpawnQueue(constructor, posx, posy, posz, math.random(0, 3), ScavengerTeamID, n + 150)
			Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math.random(0, 3), ScavengerTeamID)
		else
			constructorTimer = constructorTimer +  math.ceil(n / scavconfig.constructorControllerModuleConfig.constructortimerreductionframes)
		end
	else
		constructorTimer = constructorTimer +  math.ceil(n / scavconfig.constructorControllerModuleConfig.constructortimerreductionframes)
	end
end

local function randomlyRotateBlueprint()
	local randomRotation = math.random(0,3)
	if randomRotation == 0 then -- normal
		local swapXandY = false
		local flipX = 1
		local flipZ = 1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
	if randomRotation == 1 then -- 90 degrees anti-clockwise
		local swapXandY = true
		local flipX = 1
		local flipZ = -1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
	if randomRotation == 2 then -- 180 degrees anti-clockwise
		local swapXandY = false
		local flipX = -1
		local flipZ = -1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
	if randomRotation == 3 then -- 270 degrees anti-clockwise
		local swapXandY = true
		local flipX = -1
		local flipZ = 1
		local rotation = randomRotation
		return swapXandY, flipX, flipZ, rotation
	end
end

local function randomlyMirrorBlueprint(mirrored, direction, unitFacing)
	if mirrored == true then
		if direction == "h" then
			local mirrorX = -1
			local mirrorZ = 1
			if unitFacing == 1 or unitFacing == 3 then
				local mirrorRotation = 2
				return mirrorX, mirrorZ, mirrorRotation
			else
				local mirrorRotation = 0
				return mirrorX, mirrorZ, mirrorRotation
			end
		elseif direction == "v" then
			local mirrorX = 1
			local mirrorZ = -1
			if unitFacing == 0 or unitFacing == 2 then
				local mirrorRotation = 2
				return mirrorX, mirrorZ, mirrorRotation
			else
				local mirrorRotation = 0
				return mirrorX, mirrorZ, mirrorRotation
			end
		end
	else
		local mirrorX = 1
		local mirrorZ = 1
		local mirrorRotation = 0
		return mirrorX, mirrorZ, mirrorRotation
	end
end



local function ScavComGetClosestGaiaUnit(x, z, surroundingGaiaUnits)
	local bestUnit
	local bestDist = math.huge
	local gaiaUnits = surroundingGaiaUnits
	if gaiaUnits then
		for i = 1, #gaiaUnits do
			local testUnit = gaiaUnits[i]
			local testUnitDefID = Spring.GetUnitDefID(testUnit)
			local capturable = UnitDefs[testUnitDefID].capturable
			local testx, testy, testz = Spring.GetUnitPosition(testUnit)
			local dx, dz = x - testx, z - testz
			local dist = dx * dx + dz * dz
			if capturable and dist < bestDist then
				bestUnit = testUnit
				bestDist = dist
			end
		end
	end
	return bestUnit
end

ConstructorNumberOfRetries = {}
local function constructNewBlueprint(n, unitID)
	local x,y,z = Spring.GetUnitPosition(unitID)
	local surroundingGaiaUnits = Spring.GetUnitsInCylinder(x, z, 500, Spring.GetGaiaTeamID())
	if surroundingGaiaUnits then
		if #surroundingGaiaUnits > 0 then
			local target = ScavComGetClosestGaiaUnit(x, z, surroundingGaiaUnits)
			if target then
				local posx, posy, posz = Spring.GetUnitPosition(target)
				Spring.GiveOrderToUnit(unitID, CMD.MOVE, { posx + math.random(-64,64), posy, posz + math.random(-64,64) }, {})
				Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, {target}, {"shift"})
				return
			end
		end
	end
	local unitCount = Spring.GetTeamUnitCount(ScavengerTeamID)
	local unitCountBuffer = scavMaxUnits*0.1

	local landBlueprint, seaBlueprint, blueprint

	if not ConstructorNumberOfRetries[unitID] then
		ConstructorNumberOfRetries[unitID] = 0
	end
	ConstructorNumberOfRetries[unitID] = ConstructorNumberOfRetries[unitID] + 1

	local spawnTierChance = math.random(1, 100)
	local spawnTier
	if spawnTierChance <= TierSpawnChances.T0 then
		spawnTier = blueprintConfig.Tiers.T0
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
		spawnTier = blueprintConfig.Tiers.T1
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
		spawnTier = blueprintConfig.Tiers.T2
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
		spawnTier = blueprintConfig.Tiers.T3
	elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
		spawnTier = blueprintConfig.Tiers.T4
	else
		spawnTier = blueprintConfig.Tiers.T0
	end

	landBlueprint = blueprintsController.Constructor.GetRandomLandBlueprint(spawnTier)
	seaBlueprint = blueprintsController.Constructor.GetRandomSeaBlueprint(spawnTier)

	for i = 1, 100 do
		local posX = math.random( x - (50 * ConstructorNumberOfRetries[unitID]), x + (50 * ConstructorNumberOfRetries[unitID]))
		local posZ = math.random( z - (50 * ConstructorNumberOfRetries[unitID]), z + (50 * ConstructorNumberOfRetries[unitID]))
		local posY = Spring.GetGroundHeight(posX, posZ)

		if posY > 0 then
			blueprint = landBlueprint
		elseif posY <= 0 then
			blueprint = seaBlueprint
		end

		local blueprintRadiusBuffer = 64
		local blueprintRadius = blueprint.radius + blueprintRadiusBuffer
		local canConstructHere = posOccupied(posX, posY, posZ, blueprintRadius)
							 and posCheck(posX, posY, posZ, blueprintRadius)
							 and posMapsizeCheck(posX, posY, posZ, blueprintRadius)
							 and (not posStartboxCheck(posX, posY, posZ, blueprintRadius) or (not scavconfig.modules.startBoxProtection))

		if canConstructHere then
			buffConstructorBuildSpeed(unitID)
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, { posX + blueprintRadius*math.random(-1,1), posY + 500, posZ + blueprintRadius*math.random(-1,1) }, {"shift"})
			local swapXandY, flipX, flipZ, rotation = randomlyRotateBlueprint()
			if math.random(0,1) == 0 then
				if math.random(0,1) == 0 then
					mirrored = true
					mirroredDirection = "h"
				else
					mirrored = true
					mirroredDirection = "v"
				end
			else
				mirrored = false
				mirroredDirection = "null"
			end
			for _, building in ipairs(blueprint.buildings) do
				local mirrorX, mirrorZ, mirrorRotation = randomlyMirrorBlueprint(mirrored, mirroredDirection, (building.direction+rotation)%4)
				if building.unitDefID then
					if swapXandY == false then
						Spring.GiveOrderToUnit(unitID, -building.unitDefID, { posX + (building.xOffset*flipX*mirrorX), posY, posZ + (building.zOffset*flipZ*mirrorZ), (building.direction+rotation+mirrorRotation)%4 }, {"shift"})
					else
						Spring.GiveOrderToUnit(unitID, -building.unitDefID, { posX + (building.zOffset*flipX*mirrorX), posY, posZ + (building.xOffset*flipZ*mirrorZ), (building.direction+rotation+mirrorRotation)%4 }, {"shift"})
					end
				end
			end
			mirrored = nil
			mirroredDirection = nil
			ConstructorNumberOfRetries[unitID] = 0
			break
		end
	end
end

-- local function spawnResurrectorGroup(n)
-- 	local resurrectorSpawnCount

-- 	if ScavSafeAreaExist then 
-- 		local spawnTierChance = math.random(1, 100)
-- 		if spawnTierChance <= TierSpawnChances.T0 then
-- 			resurrectorSpawnCount = 1
-- 		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
-- 			resurrectorSpawnCount = math.random(1, 2)
-- 		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
-- 			resurrectorSpawnCount = math.random(3, 5)
-- 		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
-- 			resurrectorSpawnCount = math.random(6, 10)
-- 		elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
-- 			resurrectorSpawnCount = math.random(11, 20)
-- 		else
-- 			resurrectorSpawnCount = 0
-- 		end

-- 		if resurrectorSpawnCount == 0 then
-- 			return
-- 		end

-- 		local posx = math.random(ScavSafeAreaMinX, ScavSafeAreaMaxX)
-- 		local posz = math.random(ScavSafeAreaMinZ, ScavSafeAreaMaxZ)
-- 		local posy = Spring.GetGroundHeight(posx, posz)
-- 		local radius = 32
-- 		local canSpawnHere

-- 		for i = 1, 100 do
-- 			canSpawnHere = posCheck(posx, posy, posz, radius) and posOccupied(posx, posy, posz, radius)

-- 			if canSpawnHere then
-- 				for y = 1, resurrectorSpawnCount do
-- 					if posy > -20 then
-- 						local resurrector = constructorUnitList.Resurrectors[math.random(#constructorUnitList.Resurrectors)]
-- 						Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math.random(0, 3), ScavengerTeamID)
-- 						spawnQueueLibrary.AddToSpawnQueue(resurrector, posx, posy, posz, math.random(0, 3), ScavengerTeamID, n + (y * 1) + 150)
-- 					else
-- 						local seaResurrector = constructorUnitList.ResurrectorsSea[math.random(#constructorUnitList.ResurrectorsSea)]
-- 						Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math.random(0, 3), ScavengerTeamID)
-- 						spawnQueueLibrary.AddToSpawnQueue(seaResurrector, posx, posy, posz, math.random(0, 3), ScavengerTeamID, n + (y * 1) + 150)
-- 					end
-- 				end

-- 				break
-- 			end
-- 		end
-- 	end
-- end

return {
	AssistantOrders = assistantOrders,
	AssistDroneRespawn = assistDroneRespawn,
	ResurrectorOrders = resurrectorOrders,
	CapturerOrders = capturerOrders,
	CollectorOrders = collectorOrders,
	ReclaimerOrders = reclaimerOrders,
	SpawnConstructor = spawnConstructor,
	ConstructNewBlueprint = constructNewBlueprint,
	SpawnResurrectorGroup = spawnResurrectorGroup,
}