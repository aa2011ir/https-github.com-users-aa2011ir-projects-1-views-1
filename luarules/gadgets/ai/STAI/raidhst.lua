RaidHST = class(Module)

function RaidHST:Name()
	return "RaidHST"
end

function RaidHST:internalName()
	return "raidhst"
end

local mCeil = math.ceil

-- these local variables are the same for all AI teams, in fact having them the same saves memory and processing

function RaidHST:Init()
	self.DebugEnabled = false

	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}
	self.pathValidFuncs = {}
end

function RaidHST:NeedMore(mtype, add)
	if add == nil then add = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = UnitiesHST.baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] + add
			self.counter[mtype] = math.min(self.counter[mtype], UnitiesHST.maxRaidCounter)
			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = UnitiesHST.baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] + add
		self.counter[mtype] = math.min(self.counter[mtype], UnitiesHST.maxRaidCounter)
		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHST:NeedLess(mtype)
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = UnitiesHST.baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] - 0.5
			self.counter[mtype] = math.max(self.counter[mtype], UnitiesHST.minRaidCounter)
			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = UnitiesHST.baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] - 0.5
		self.counter[mtype] = math.max(self.counter[mtype], UnitiesHST.minRaidCounter)
		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHST:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return UnitiesHST.baseRaidCounter
	else
		return self.counter[mtype]
	end
end

function RaidHST:IDsWeAreRaiding(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = mtype
	end
end

function RaidHST:IDsWeAreNotRaiding(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = nil
	end
end

function RaidHST:TargetDied(mtype)
	self:EchoDebug("target died")
	self:NeedMore(mtype, 0.35)
end

function RaidHST:GetPathValidFunc(unitName)
	if self.pathValidFuncs[unitName] then
		return self.pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return self.ai.targethst:IsSafePosition(node.position, unitName, 1)
	end
	self.pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end
