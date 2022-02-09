if not gadgetHandler:IsSyncedCode() then
    return
end

local gadgetEnabled

if Spring.GetModOptions().scoremode ~= "disabled" and Spring.GetModOptions().scoremode_chess then
    gadgetEnabled = true
else
    gadgetEnabled = false
end

ChessModeUnbalancedModoption = Spring.GetModOptions().scoremode_chess_unbalanced
ChessModePhaseTimeModoption = Spring.GetModOptions().scoremode_chess_adduptime
ChessModeSpawnPerPhaseModoption = Spring.GetModOptions().scoremode_chess_spawnsperphase

local capturePointRadius = Spring.GetModOptions().captureradius
local capturePointRadius = math.floor(capturePointRadius*0.75)

local pveEnabled = Spring.Utilities.Gametype.IsPvE()

if pveEnabled then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
	gadgetEnabled = false
end

function gadget:GetInfo()
    return {
      name      = "Control Victory Chess Mode",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = gadgetEnabled,
    }
end

local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetAllyTeamList= Spring.GetAllyTeamList
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local teams = Spring.GetTeamList()

local teamSpawnPositions = {}
local teamSpawnQueue = {}
local teamRespawnQueue = {}
local teamIsLandPlayer = {}
local resurrectedUnits = {}


local function distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local yd = pos1.z-pos2.z
	local dist = math.sqrt(xd*xd + yd*yd)
	return dist
end

function GetControlPoints()
	--if controlPoints then return controlPoints end
	controlPoints = {}
	if Script.LuaRules('ControlPoints') then
		local rawPoints = Script.LuaRules.ControlPoints() or {}
		for id = 1, #rawPoints do
			local rawPoint = rawPoints[id]
			local rawPoint = rawPoint
			local pointID = id
			local pointOwner = rawPoint.owner
			local pointPosition = {x=rawPoint.x, y=rawPoint.y, z=rawPoint.z}
			local point = {pointID=pointID, pointPosition=pointPosition, pointOwner=pointOwner}
			controlPoints[id] = point
		end
	end
	return controlPoints
end

-- function GetRandomAllyPoint(teamID, unitName)
--     local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(teamID)
--     local unitDefID = UnitDefNames[unitName].id
-- 	for i = 1,1000 do 
-- 		local r = math.random(1,#controlPoints)
-- 		local point = controlPoints[r]
-- 		local pointAlly = controlPoints[r].pointOwner
-- 		local pointPos = controlPoints[r].pointPosition
-- 		local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
--         local unreachable = true
--         if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
--             unreachable = false
--         end
--         if unreachable == false and pointAlly == allyTeamID then
-- 			pos = pointPos
-- 			break
-- 		end
-- 	end
-- 	return pos
-- end

-- function GetClosestEnemyPoint(unitID)
-- 	local pos
-- 	local bestDistance
-- 	local controlPoints = controlPointsList
-- 	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
-- 	local unitDefID = Spring.GetUnitDefID(unitID)
-- 	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
-- 	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
-- 	for i = 1, #controlPoints do
-- 		local point = controlPoints[i]
-- 		local pointAlly = controlPoints[i].pointOwner
-- 		if pointAlly ~= unitAllyTeam then
-- 			local pointPos = controlPoints[i].pointPosition
-- 			local dist = distance(position, pointPos)
-- 			local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
-- 			local unreachable = true
-- 			if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
-- 				unreachable = false
-- 			end
-- 			if unreachable == false and (not bestDistance or dist < bestDistance) then
-- 				bestDistance = dist
-- 				pos = pointPos
-- 			end
-- 		end
-- 	end
-- 	return pos
-- end


local function pickRandomUnit(list, quantity)
    if #list > 1 then
        r = math.random(1,#list)
    else
        r = 1
    end
    pickedTable = {}
    for i = 1,quantity do
        table.insert(pickedTable, list[r])
    end
    r = nil
    return pickedTable
end


local starterLandUnitsList = {
    [1] = {
        [1] = {    
            table = {
                --bots
                "armpw", 
                "corak",
                --vehicles
                "armflash",
                "corfav",
            },                           
            quantity = 10,
        },
        [2] = {    
            table = {
                "armflea", 
                "armfav",
                "corfav" ,
            },                           
            quantity = 5,
        },
        [3] = {    
            table = {
                "armassistdrone", 
                "corassistdrone", 
            },                           
            quantity = 1,
        },
        [4] = {    
            table = {
                "armmlv", 
                "cormlv", 
            },                           
            quantity = 2,
        },
        [5] = {    
            table = {
                "armjeth",
                "corcrash",
                "armah",
                "corah",
                "armsam",
                "cormist",
            },                           
            quantity = 1,
        },
    },
}
    
local landUnitsList = {
    [1] = {
        [1] = {    
            table = {
                -- bots
                "armpw", 
                "corak",
                "armrock",
                "armham",
                "armwar",
                "corstorm",
                "corthud",

                -- tanks
                "armflash",
                "corgator",
                "armstump",
                "corraid",
                "armpincer",
                "corgarp",
                "armsam",
                "cormist",
                "armjanus",
                "corlevlr",
                "corwolv",

                -- hover
                "armsh",
                "corsh",
                "armmh",
                "cormh",
                "armanac",
                "corsnap",
            },                           
            quantity = 10,
        },
        [2] = {    
            table = {
                "armassistdrone", 
                "corassistdrone", 
            },                           
            quantity = 1,
        },
        [3] = {    
            table = {
                "armjeth",
                "corcrash",
                "armah",
                "corah",
            },                           
            quantity = 1,
        },
    },
}

local starterSeaUnitsList = {
    [1] = {
        [1] = { 
            table = {
                "armpt", 
                "corpt",
            },                          
            quantity = 10,
        },
        [2] = {    
            table = {
                "armassistdrone", 
                "corassistdrone", 
            },                           
            quantity = 1,
        },
    },
}

local seaUnitsList = {
    [1] = {
        [1] = {
            table = {
                "armpt", 
                "corpt",
            },                          
            quantity = 10,
        },
    },
}



local maxPhases = #landUnitsList
local phaseSpawns = 0
local spawnsPerPhase = ChessModeSpawnPerPhaseModoption
local addUpFrequency = ChessModePhaseTimeModoption*1800
local spawnTimer = 9000
local respawnTimer = 9000
local phase
local canResurrect = {}

-- Functions to hide commanders
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.canResurrect then
        canResurrect[unitDefID] = true
    end
end

local function disableUnit(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetNoBlocking(unitID, true)
    Spring.MoveCtrl.SetPosition(unitID, Game.mapSizeX+1900, 2000, Game.mapSizeZ+1900)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitCloak(unitID, true)
	--Spring.SetUnitHealth(unitID, {paralyze=99999999})
	Spring.SetUnitMaxHealth(unitID, 10000000)
	Spring.SetUnitHealth(unitID, 10000000)
	Spring.SetUnitNoDraw(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
end

local function introSetUp()
    for i = 1,#teams do
        local teamID = teams[i]
        local teamUnits = Spring.GetTeamUnits(teamID)
        if spGetGaiaTeamID() ~= teamID then
            for _, unitID in ipairs(teamUnits) do
                local x,y,z = Spring.GetUnitPosition(unitID)
                teamSpawnPositions[teamID] = { x = x, y = y, z = z}
                if teamSpawnPositions[teamID].y > 0 then
                    teamIsLandPlayer[teamID] = true
                else
                    teamIsLandPlayer[teamID] = false
                end
				teamSpawnQueue[teamID] = {}
				teamRespawnQueue[teamID] = {}
                disableUnit(unitID)
            end
        end
    end
    phase = 1
end

local function addInfiniteResources()
    for i = 1,#teams do
        local teamID = teams[i]
        Spring.SetTeamResource(teamID, "ms", 1000000)
        Spring.SetTeamResource(teamID, "es", 1000000)
        Spring.SetTeamResource(teamID, "m", 500000)
        Spring.SetTeamResource(teamID, "e", 500000)
    end
end

-- local function spawnUnitsFromQueue(teamID)
--     if teamSpawnQueue[teamID] then
--         if teamSpawnQueue[teamID][1] then
--             local pos = GetRandomAllyPoint(teamID, teamSpawnQueue[teamID][1])
--             local spawnedUnit
--             if pos and pos.x then
--                 local x = pos.x+math.random(-50,50)
--                 local z = pos.z+math.random(-50,50)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamSpawnQueue[teamID], 1)
--             else
--                 local x = teamSpawnPositions[teamID].x + math.random(-64,64)
--                 local z = teamSpawnPositions[teamID].z + math.random(-64,64)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamSpawnQueue[teamID], 1)
--             end
--             local rawPos = GetClosestEnemyPoint(spawnedUnit)
--             if rawPos then
--                 local posx = rawPos.x
--                 local posz = rawPos.z
--                 local posy = Spring.GetGroundHeight(posx, posz)
--                 if posx then
--                     Spring.GiveOrderToUnit(spawnedUnit, CMD.FIGHT,  {posx+math.random(-capturePointRadius,capturePointRadius), posy, posz+math.random(-capturePointRadius,capturePointRadius)}, {"alt", "ctrl"})
--                 end
--             end
--         end
--     end
-- end

-- local function respawnUnitsFromQueue(teamID)
--     if teamRespawnQueue[teamID] then
--         if teamRespawnQueue[teamID][1] then
--             local pos = GetRandomAllyPoint(teamID, teamRespawnQueue[teamID][1])
--             local spawnedUnit
--             if pos and pos.x then
--                 local x = pos.x+math.random(-50,50)
--                 local z = pos.z+math.random(-50,50)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamRespawnQueue[teamID], 1)
--             else
--                 local x = teamSpawnPositions[teamID].x + math.random(-64,64)
--                 local z = teamSpawnPositions[teamID].z + math.random(-64,64)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamRespawnQueue[teamID], 1)
--             end
--             local rawPos = GetClosestEnemyPoint(spawnedUnit)
--             if rawPos then
--                 local posx = rawPos.x
--                 local posz = rawPos.z
--                 local posy = Spring.GetGroundHeight(posx, posz)
--                 if posx then
--                     Spring.GiveOrderToUnit(spawnedUnit,CMD.MOVE_STATE,{0},0)
--                     Spring.GiveOrderToUnit(spawnedUnit, CMD.FIGHT,  {posx+math.random(-capturePointRadius,capturePointRadius), posy, posz+math.random(-capturePointRadius,capturePointRadius)}, {"alt", "ctrl"})
--                 end
--             end
--         end
--     end
-- end

local function spawnUnitsFromQueue(teamID)
    if teamSpawnQueue[teamID] then
        if teamSpawnQueue[teamID][1] then
            local spawnedUnit
            local x = teamSpawnPositions[teamID].x + math.random(-64,64)
            local z = teamSpawnPositions[teamID].z + math.random(-64,64)
            local y = Spring.GetGroundHeight(x,z)
            spawnedUnit = Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
            Spring.GiveOrderToUnit(spawnedUnit,CMD.MOVE_STATE,{0},0)
            Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
            table.remove(teamSpawnQueue[teamID], 1)
        end
    end
end

local function respawnUnitsFromQueue(teamID)
    if teamRespawnQueue[teamID] then
        if teamRespawnQueue[teamID][1] then
            local spawnedUnit
            local x = teamSpawnPositions[teamID].x + math.random(-64,64)
            local z = teamSpawnPositions[teamID].z + math.random(-64,64)
            local y = Spring.GetGroundHeight(x,z)
            spawnedUnit = Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
            Spring.GiveOrderToUnit(spawnedUnit,CMD.MOVE_STATE,{0},0)
            Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
            table.remove(teamRespawnQueue[teamID], 1)
        end
    end
end

local function chooseNewUnits(starter)
    if starter then
        landPhase = starterLandUnitsList[1]
        landPhaseQuantity = #starterLandUnitsList[1]

        seaPhase = starterSeaUnitsList[1]
        seaPhaseQuantity = #starterSeaUnitsList[1]
    else
        landPhase = landUnitsList[phase]
        landPhaseQuantity = #landUnitsList[phase]

        seaPhase = seaUnitsList[phase]
        seaPhaseQuantity = #seaUnitsList[phase]
    end

    landUnit = {}
    seaUnit = {}
    for j = 1,landPhaseQuantity do
        landUnit[j] = pickRandomUnit(landPhase[j].table, landPhase[j].quantity)
    end
    for j = 1,seaPhaseQuantity do
        seaUnit[j] = pickRandomUnit(seaPhase[j].table, seaPhase[j].quantity)
    end

end

local function addNewUnitsToQueue(starter)
	--local landRandom, landUnit, landUnitCount
	--local seaRandom, seaUnit, seaUnitCount
    chooseNewUnits(starter)
    
    for i = 1,#teams do
        local teamID = teams[i]
        if ChessModeUnbalancedModoption then
            chooseNewUnits(starter)
        end
        if teamIsLandPlayer[teamID] then
            for j = 1,landPhaseQuantity do
                for k = 1, #landUnit[j] do
                    if teamSpawnQueue[teamID] then
                        if teamSpawnQueue[teamID][1] then
                            teamSpawnQueue[teamID][#teamSpawnQueue[teamID]+1] = landUnit[j][k]
                        else
                            teamSpawnQueue[teamID][1] = landUnit[j][k]
                        end
                    end
                end
            end
        else
            for j = 1,seaPhaseQuantity do
                for k = 1, #seaUnit[j] do
                    if teamSpawnQueue[teamID] then
                        if teamSpawnQueue[teamID][1] then
                            teamSpawnQueue[teamID][#teamSpawnQueue[teamID]+1] = seaUnit[j][k]
                        else
                            teamSpawnQueue[teamID][1] = seaUnit[j][k]
                        end
                    end
                end
            end
        end
    end
    
    if not starter then
        phaseSpawns = phaseSpawns + 1
        if phaseSpawns == spawnsPerPhase then
            phaseSpawns = 0
            phase = phase + 1
        end
        if phase > maxPhases then
            phase = 1
        end
    end

    landUnit = nil
    landUnitCount = nil
    seaUnit = nil
    seaUnitCount = nil
end

local function respawnDeadUnit(unitName, unitTeam)
    if teamRespawnQueue[unitTeam] then
        if teamRespawnQueue[unitTeam][1] then
            teamRespawnQueue[unitTeam][#teamRespawnQueue[unitTeam]+1] = unitName
        else
            teamRespawnQueue[unitTeam][1] = unitName
        end
    end
end

function gadget:GameFrame(n)
    if n%30 == 0 then
		controlPointsList = GetControlPoints()
	end
    if n == 20 then
        introSetUp()
    end
    if n == 25 then
        addNewUnitsToQueue(true)
    end
    if n%900 == 1 then
        addInfiniteResources()
    end
    if n > 25 and n%addUpFrequency == 1 then
        addNewUnitsToQueue(false)
    end
    for i = 1,#teams do
        local teamID = teams[i]
        if n == 30 then
            for i = 1,100 do
                spawnUnitsFromQueue(teamID)
                respawnUnitsFromQueue(teamID)
            end
        end
        
        if teamSpawnQueue[teamID] and #teamSpawnQueue[teamID] > 0 then
            if teamRespawnQueue[teamID] and #teamRespawnQueue[teamID] > 0 then
                if n > 25 and n%math.ceil(spawnTimer/(#teamRespawnQueue[teamID]+#teamSpawnQueue[teamID])) == 1 then
                    spawnUnitsFromQueue(teamID)
                end
            else
                if n > 25 and n%spawnTimer == 1 then
                    spawnUnitsFromQueue(teamID)
                end
            end
        else
            if teamRespawnQueue[teamID] and #teamRespawnQueue[teamID] > 0 then
                if n > 25 and n%math.ceil(respawnTimer/(#teamRespawnQueue[teamID])) == 1 then
                    respawnUnitsFromQueue(teamID)
                end
            end
        end
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if builderID then-- and canResurrect[Spring.GetUnitDefID(builderID)] then
        resurrectedUnits[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if resurrectedUnits[unitID] then
        resurrectedUnits[unitID] = nil
    else
        local UnitName = UnitDefs[unitDefID].name
        respawnDeadUnit(UnitName, unitTeam)
    end
end
