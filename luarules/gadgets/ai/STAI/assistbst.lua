local CMD_GUARD = 25
local CMD_PATROL = 15

AssistBST = class(Behaviour)

function AssistBST:Name()
	return "AssistBST"
end

AssistBST.DebugEnabled = false

function AssistBST:DoIAssist()
	if self.ai.nonAssistant[self.id] ~= true or self.isNanoTurret then
		return true
	else
		return false
	end
end

function AssistBST:Init()
	self.active = false
	self.target = nil
	-- keeping track of how many of each type of unit
	local uname = self.unit:Internal():Name()
	self.name = uname
	if UnitiesHST.nanoTurretList[uname] then self.isNanoTurret = true end
	if UnitiesHST.commanderList[uname] then self.isCommander = true end
	self.id = self.unit:Internal():ID()
	self.ai.assisthst:AssignIDByName(self)
	-- game:SendToConsole("assistbst:init", ai, ai.id, self.ai, self.ai.id)
	self:EchoDebug(uname .. " " .. self.ai.IDByName[self.id])
	self:EchoDebug("added to unit "..uname)
end

function AssistBST:OwnerIdle()
	self.patroling = false
	self.assisting = nil
end

function AssistBST:Update()
	-- nano turrets don't need updating, they already have a patrol order
	if self.isNanoTurret then return end

	local f = self.game:Frame()

	if f % 180 == 0 then
		local unit = self.unit:Internal()
		local uname = self.name
		if self.isCommander then
			-- turn commander into build assister if you control more than half the mexes or if it's damaged
			if self.ai.nonAssistant[self.id] then
				if ( self.ai.overviewhst.keepCommanderSafe or self.ai.overviewhst.needSiege or unit:GetHealth() < unit:GetMaxHealth() * 0.9) and self.ai.factories ~= 0 and self.ai.conCount > 2 then
					self:EchoDebug("turn commander into assistant")
					self.ai.nonAssistant[self.id] = nil
					self.unit:ElectBehaviour()
				end
			else
				-- switch commander back to building
				if (not self.ai.overviewhst.keepCommanderSafe and not self.ai.overviewhst.needSiege and unit:GetHealth() >= unit:GetMaxHealth() * 0.9) or self.ai.factories == 0 or self.ai.conCount <= 2 then
					self:EchoDebug("turn commander into builder")
					self.ai.nonAssistant[self.id] = true
					self.unit:ElectBehaviour()
				end
			end
		else
			-- fill empty spots after con units die
			-- if not self.ai.IDByName[self.id] or not self.ai.nameCount[uname] then game:SendToConsole(self.id, uname, self.ai.IDByName[self.id], self.ai.nameCount[uname]) end
			if self.ai.IDByName[self.id] > self.ai.nameCount[uname] then
				self:EchoDebug("filling empty spots with " .. uname .. " " .. self.ai.IDByName[self.id])
				self.ai.assisthst:AssignIDByName(self)
				self:EchoDebug("ID now: " .. self.ai.IDByName[self.id])
				self.unit:ElectBehaviour()
			end
		end
	end

	if f % 60 == 0 then
		if self.active then
			if self.target ~= nil then
				if self.assisting ~= self.target then
					local floats = api.vectorFloat()
					floats:push_back(self.target)
					self.unit:Internal():ExecuteCustomCommand(CMD_GUARD, floats)
					self.assisting = self.target
					self.patroling = false
				end
			elseif not self.patroling then
				local patrolPos = self.fallbackPos or self.unit:Internal():GetPosition()
				local pos = RandomAway(self.ai, patrolPos, 200)
				local floats = api.vectorFloat()
				-- populate with x, y, z of the position
				floats:push_back(pos.x)
				floats:push_back(pos.y)
				floats:push_back(pos.z)
				self.unit:Internal():ExecuteCustomCommand(CMD_PATROL, floats)
				self.ai.assisthst:AddFree(self)
				self.patroling = true
			end
		end
	end
end

function AssistBST:Activate()
	self:EchoDebug("activated on unit "..self.name)
	if self:DoIAssist() then
		self.ai.assisthst:Release(self.unit:Internal())
		self.ai.assisthst:AddFree(self)
	end
	if self.isNanoTurret then
		-- set nano turrets to patrol
		local upos = RandomAway(self.ai, self.unit:Internal():GetPosition(), 50)
		local floats = api.vectorFloat()
		-- populate with x, y, z of the position
		floats:push_back(upos.x)
		floats:push_back(upos.y)
		floats:push_back(upos.z)
		self.unit:Internal():ExecuteCustomCommand(CMD_PATROL, floats)
	end
	self.active = true
	self.target = nil
end

function AssistBST:Deactivate()
	self:EchoDebug("deactivated on unit "..self.name)
	self.ai.assisthst:RemoveWorking(self)
	self.ai.assisthst:RemoveFree(self)
	self.active = false
	self.target = nil
	self.assisting = nil
end

function AssistBST:Priority()
	if self:DoIAssist() then
		return 100
	else
		return 0
	end
end

function AssistBST:OwnerDead()
	self.ai.assisthst:RemoveAssistant(self)
end

function AssistBST:Assign(builderID)
	self.target = builderID
	self.lastAssignFrame = self.game:Frame()
end

function AssistBST:SetFallback(position)
	self.fallbackPos = position
end

-- assign if not busy (used by factories to occupy idle assistants)
function AssistBST:SoftAssign(builderID)
	if self.target == nil then
		self.target = builderID
	else
		if self.lastAssignFrame == nil then
			self.target = builderID
		else
			local f = self.game:Frame()
			if f > self.lastAssignFrame + 900 then
				self.target = builderID
			end
		end
	end
end
