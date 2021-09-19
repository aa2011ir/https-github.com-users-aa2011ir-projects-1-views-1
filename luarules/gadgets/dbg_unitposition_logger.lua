function gadget:GetInfo()
	return {
		name = "Unit Position Logger",
		desc = "logs all unit positions in intervals",
		author = "Floris",
		date = "February 2021",
		license = "GNU GPL, v2 or later",
		layer = -math.huge,
		enabled = false,
	}
end

--[[
	disabled cause there is missing data, presumingly because or rejoining specs and whatnot.
]]


--[[
	this gadget logs unit positions at intervals within the replay
	created this so a replay website service or the game-lobby could display a quick overview video of the match

	every (non lagged behind) player and spectator will send an equal part of all units available to keep the data sending load shared equally
	(parts that fail to be received are passed on to the next player/spec to re-send until everyone tried once)
]]

if not gadgetHandler:IsSyncedCode() then

	if Spring.IsReplay() then return end

	local debug = select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) == '[teh]Flow'

	local gameFramesPerSecond = 30	-- engine constant

	local pingCutoff = 1500	-- players with higher ping wont participate in sending unit positions log

	-- based on the current number of units it will adjust the amount of gameframes between each log
	local minLogRate = math.floor(gameFramesPerSecond * 6)
	local maxLogRate = math.floor(gameFramesPerSecond * 30)
	local maxLogRateUnits = 3000	-- # of units where maxLogRate gets reached

	local maxLogMemoryDuration = gameFramesPerSecond * 60

	-- verify if every part of a log has been received every X amount of gameframes, and resend parts if not
	local verifyRate = math.floor(gameFramesPerSecond * 2)

	---------------------------------------------------------------------------------------

	local logRate = minLogRate
	local pingCutoffFrames = (pingCutoff / (pingCutoff / gameFramesPerSecond))
	local lastLogFrame = 30-minLogRate
	local log = {}
	local serverFrame = 0

	local validation = SYNCED.validationLogger

	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitTeam = Spring.GetUnitTeam
	local math_floor = math.floor
	local math_ceil = math.ceil
	local myPlayerID = Spring.GetMyPlayerID()

	local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

	local allUnits = {}
	local allUnitsTotal = 0
	function gadget:Initialize()
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		allUnits[unitID] = {unitDefID, unitTeam}
		allUnitsTotal = allUnitsTotal + 1
	end

	function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
		allUnits[unitID] = {unitDefID, unitTeam}
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		allUnits[unitID] = {unitDefID, newTeam}
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		allUnits[unitID] = nil
		allUnitsTotal = allUnitsTotal - 1
	end

	-- store all unit positions (in case you're requested to send a missing part later)
	local function updateLog(frame, participants)
		local numParticipants = #participants
		log[frame] = {
			participants = participants,
			parts = {},
			attempts = 0,
		}
		local part = 1
		local i = 0
		local teamID
		for unitID, params in pairs(allUnits) do
			local px, py, pz = spGetUnitPosition(unitID)
			if px then
				i = i + 1
				part = math_ceil(i / (allUnitsTotal/numParticipants))
				if log[frame].parts[part] == nil then
					log[frame].parts[part] = {}
				end
				teamID = params[2]
				if log[frame].parts[part][teamID] == nil then
					log[frame].parts[part][teamID] = {}
				end
				local count = #log[frame].parts[part][teamID]+1
				log[frame].parts[part][teamID][count] = {unitID, params[1], math_floor(px), math_floor(pz)}--, math_floor(py)}	-- put height last so it can be left out easier
			end
		end
	end

	local function sendLog(frame, part, attempts)
		--Spring.Echo(Spring.Utilities.json.encode(log[frame].parts[part]))
		Spring.SendLuaRulesMsg('log' .. validation .. frame ..';'.. part ..';'.. (#log[frame].participants) ..';'..attempts ..';'.. VFS.ZlibCompress(Spring.Utilities.json.encode(log[frame].parts[part])))
	end

	local function receivedPart(_,frame,part,numParts,attempts)
		frame = tonumber(frame)
		part = tonumber(part)

		if log[frame] then
			log[frame].parts[part] = nil

			-- clear the logged frame when all parts have been received
			if #log[frame].parts == 0 then
				log[frame] = nil
			end
		end

		if debug and attempts ~= '0' then
			Spring.Echo('LOG frame:'..frame..' part:'..part..' numparts:'..numParts..' attempts:'..attempts)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("receivedPart", receivedPart)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("receivedPart")
	end

	--function gadget:GameOver(winningAllyTeams)
	--end

	-- happens every 150 frames
	function gadget:GameProgress(n)
		serverFrame = n
	end

	function gadget:GameFrame(gf)
		--if gf < serverFrame then
		--	return end
		--end

		-- check if all parts have been received, clear the logged frame if this is the case
		if gf % verifyRate == 0 then
			for frame, params in ipairs(log) do

				-- start checking after giving receiving the proper time
				if gf-frame-pingCutoffFrames >= verifyRate then

					log[frame].attempts = log[frame].attempts + 1
					if log[frame].attempts > #log[frame].participants then
						-- this should not happen... if so, something went wrong because we tried resending by all other participants already
						log[frame] = nil
					else
						-- loop leftover parts
						for part, _ in ipairs(params.parts) do

							-- resend part if you're the designated backup sender
							local designatedBackupParticipant = myPlayerID
							if log[frame].participants[part + log[frame].attempts] then
								-- goto next participant
								designatedBackupParticipant = log[frame].participants[part + log[frame].attempts]
							else
								-- start from first participant onwards
								local numParticipants = #log[frame].participants
								designatedBackupParticipant = log[frame].participants[ log[frame].attempts - (numParticipants-part) ]
							end
							if designatedBackupParticipant == myPlayerID then
								sendLog(frame, part, log[frame].attempts)
							end
						end
					end
				end
			end
		end

		-- save and send you part of all unit positions
		if gf >= lastLogFrame+logRate then

			-- cleanup incomplete old frames in case this has happened for some reason
			for frame, params in ipairs(log) do
				if frame < gf-maxLogMemoryDuration then
					log[frame] = nil
				end
			end

			lastLogFrame = gf

			-- adjust logRate based on number of units on the map (so earlygame log can stay frequent)
			logRate = maxLogRate * (allUnitsTotal / maxLogRateUnits)
			logRate = math.min(maxLogRate, math.max(minLogRate, logRate))

			-- find out which players/specs aren't lagged behind and available to send a part of all unit position data
			local participants = {}
			local myPart
			for _,playerID in ipairs(Spring.GetPlayerList()) do
				local name,_,_,teamID,_,ping = Spring.GetPlayerInfo(playerID,false)

				--if name == '[teh]Flow' and playerID == myPlayerID then
				--	Spring.Echo('gameframe: '..gf..'  serverframe: '..serverFrame..'  ping: '..ping)
				--end

				-- exclude lagged out players and AI
				-- NOTE: ping is 0 when player is catching up or playing local (local can be slightly above 0 when low fps 0.033)
				if (ping > 0.01 or isSinglePlayer) and ping < pingCutoff/1000 and not Spring.GetTeamLuaAI(teamID) and not select(4, Spring.GetTeamInfo(teamID)) then
					participants[#participants+1] = playerID
					if playerID == myPlayerID then
						myPart = #participants
					end
				end
			end

			-- send log when you're included as participant
			if myPart then
				updateLog(gf, participants)
				sendLog(gf, myPart, 0)
			end
		end
	end


else	-- SYNCED


	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end

	local function randomString(length)
		if not length or length <= 0 then return '' end
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end

	local validation = randomString(2)
	_G.validationLogger = validation

	local function explode(div,str) -- credit: http://richard.warburton.it
		if (div=='') then return false end
		local pos,arr = 0,{}
		-- for each divider found
		for st,sp in function() return string.find(str,div,pos,true) end do
			table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
			pos = sp + 1 -- Jump past current divider
		end
		table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
		return arr
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,3)=="log" and msg:sub(4,5)==validation then
			local params = explode(';', msg:sub(6, 40))	-- 1=frame, 2=part, 3=numParts, 4=attempts, 5=gzipped-json
			SendToUnsynced("receivedPart", params[1], params[2], params[3], params[4])
			return true
		end
	end

end
