-- these are used in poschecks.lua so arent localized here
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
GaiaTeamID = Spring.GetGaiaTeamID()
GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()

local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengerAITeamID = i - 1
		_,_,_,_,_,scavengerAllyTeamID = Spring.GetTeamInfo(scavengerAITeamID)
		break
	end
end

-- if scavengerAITeamID then
-- 	GaiaTeamID = scavengerAITeamID
-- 	GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))
-- end

local ruinSpawnEnabled = false
if Spring.GetModOptions().ruins or (Spring.GetModOptions().scavonlyruins and scavengersAIEnabled) then
	ruinSpawnEnabled = true
end
Spring.Echo("[RUIN ECHO] ", Spring.GetModOptions().ruins)
Spring.Echo("[RUIN ECHO] ", Spring.GetModOptions().scavonlyruins)
Spring.Echo("[RUIN ECHO] ", scavengersAIEnabled)

function gadget:GetInfo()
    return {
      name      = "ruin spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = ruinSpawnEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

VFS.Include('luarules/gadgets/scavengers/API/init.lua')
VFS.Include('luarules/gadgets/scavengers/API/api.lua')
VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')
local blueprintController = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/blueprint_controller.lua')

--spawningStartFrame = (math.ceil( math.ceil(mapsizeX + mapsizeZ) / 750 ) + 30) * 5
local spawnCutoffFrame = (math.ceil( math.ceil(mapsizeX*mapsizeZ) / 1000000 )) * 5

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

local function spawnRuin(ruin, posx, posy, posz, blueprintTierLevel)
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
	if math.random(0,3) == 0 and (blueprintTierLevel == 0 or blueprintTierLevel == 1) and scavengersAIEnabled then
		GaiaTeamID = scavengerAITeamID
		SpawnAsNeutral = false
	else
		GaiaTeamID = Spring.GetGaiaTeamID()
		SpawnAsNeutral = true
	end	
	for _, building in ipairs(ruin.buildings) do
		if swapXandY == false then
			xOffset = building.xOffset
			zOffset = building.zOffset
		else
			xOffset = building.zOffset
			zOffset = building.xOffset
		end
		local mirrorX, mirrorZ, mirrorRotation = randomlyMirrorBlueprint(mirrored, mirroredDirection, (building.direction+rotation)%4)

		local name = UnitDefs[building.unitDefID].name
		local r = math.random(1,100)
		if r < 30 then
			
			local posy = Spring.GetGroundHeight(posx + (xOffset*flipX*mirrorX), posz + (zOffset*flipZ*mirrorZ))
			local unit = Spring.CreateUnit(building.unitDefID, posx + (xOffset*flipX*mirrorX), posy, posz + (zOffset*flipZ*mirrorZ), (building.direction+rotation+mirrorRotation)%4, GaiaTeamID)
			Spring.SpawnCEG("scav-spawnexplo", posx + (xOffset*flipX*mirrorX), posy, posz + (zOffset*flipZ*mirrorZ), 0,0,0)
			local radarRange = UnitDefs[building.unitDefID].radarRadius
			local canMove = UnitDefs[building.unitDefID].canMove
			local speed = UnitDefs[building.unitDefID].speed

			if SpawnAsNeutral then
				Spring.SetUnitNeutral(unit, true)
			end
			Spring.GiveOrderToUnit(unit, CMD.FIRE_STATE, {1}, 0)
			Spring.GiveOrderToUnit(unit, CMD.MOVE_STATE, {0}, 0)
			--Spring.SetUnitAlwaysVisible(unit, true)

			if building.patrol and canMove and speed > 0 then
				for i = 1, 6 do
					Spring.GiveOrderToUnit(unit, CMD.PATROL, { posx + (math.random(-200, 200)), posy + 100, posz + (math.random(-200, 200)) }, {"shift", "alt", "ctrl"})
				end
			end

			if radarRange and radarRange > 1000 then
				Spring.GiveOrderToUnit(unit, CMD.ONOFF, {0}, 0)
			end
		-- elseif r < 90 and FeatureDefNames[name .. "_dead"] then
		-- 	local wreck = Spring.CreateFeature(name .. "_dead", posx + (xOffset*flipX*mirrorX), posy, posz + (zOffset*flipZ*mirrorZ), (building.direction+rotation+mirrorRotation)%4, GaiaTeamID)
		-- 	Spring.SetFeatureAlwaysVisible(wreck, true)
		-- 	Spring.SetFeatureResurrect(wreck, name)
		end
	end
	mirrored = nil
	mirroredDirection = nil
end

function gadget:GameFrame(n)
	if n < 5 or n%5 ~= 0 or n > spawnCutoffFrame+5 then
		return
	end

	for i = 1, 100 do
		local landRuin, seaRuin, ruin
		local posx = math.random(0, Game.mapSizeX)
		local posz = math.random(0, Game.mapSizeZ)
		local posy = Spring.GetGroundHeight(posx, posz)
		local seaRuinChance = math.random(1, 2)
		local radius, canBuildHere

		local r = math.random(0,100)
		local blueprintTierLevel = 0
		if r > 98 then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(4)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(4)
			blueprintTierLevel = 4
		elseif r > 95 then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(3)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(3)
			blueprintTierLevel = 3
		elseif r > 85 then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(2)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(2)
			blueprintTierLevel = 2
		elseif r > 65 then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(1)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(1)
			blueprintTierLevel = 1
		elseif r > 20 then
			landRuin = blueprintController.Constructor.GetRandomLandBlueprint(0)
			seaRuin = blueprintController.Constructor.GetRandomSeaBlueprint(0)
			blueprintTierLevel = 0
		else
			landRuin = blueprintController.Ruin.GetRandomLandBlueprint()
			seaRuin = blueprintController.Ruin.GetRandomSeaBlueprint()
			blueprintTierLevel = -1
		end

		if posy > 0 then
			ruin = landRuin
		elseif posy <= 0 and seaRuinChance == 1 then
			ruin = seaRuin
		end

		if ruin ~= nil then -- Nil check because Lua does not have a "continue" statement
			radius = ruin.radius
			canBuildHere = posLosCheck(posx, posy, posz, radius)
						and posMapsizeCheck(posx, posy, posz, radius)
						and posOccupied(posx, posy, posz, radius)
						and posCheck(posx, posy, posz, radius)

			if posy > 0 then
				canBuildHere = canBuildHere and posLandCheck(posx, posy, posz, radius)
			elseif posy <= 0 then
				canBuildHere = canBuildHere and posSeaCheck(posx, posy, posz, radius)
			end

			if canBuildHere then
				spawnRuin(ruin, posx, posy, posz, blueprintTierLevel)
				break
			end
		end
	end
end
