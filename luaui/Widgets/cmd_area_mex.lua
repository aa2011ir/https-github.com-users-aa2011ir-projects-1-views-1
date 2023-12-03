function widget:GetInfo()
	return {
		name = "Area Mex",
		desc = "Adds a command to cap mexes in an area.",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader), Tarte (maintenance)",
		date = "Oct 23, 2010, (last update: March 3, 2022)",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 1,
		enabled = true  --  loaded by default?
	}
end

local CMD_GUARD = CMD.GUARD
local CMD_AREA_MEX = 10100

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spSendCommands = Spring.SendCommands
local spGetUnitDefID = Spring.GetUnitDefID

local toggledMetal, retoggleLos, chobbyInterface
local selectedMex = nil

local metalMap = false

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end


function widget:Update(dt)
	if chobbyInterface then return end

	--local drawUnitShape = false
	local _, cmd, _ = spGetActiveCommand()
	if cmd == CMD_AREA_MEX then
		if spGetMapDrawMode() ~= 'metal' then
			if Spring.GetMapDrawMode() == "los" then
				retoggleLos = true
			end
			spSendCommands('ShowMetalMap')
			toggledMetal = true
		end
	else
		if toggledMetal then
			spSendCommands('ShowStandard')
			if retoggleLos then
				Spring.SendCommands("togglelos")
				retoggleLos = nil
			end
			toggledMetal = false
		end
	end
end

local function areaMex(uDefID)
	selectedMex = uDefID
	Spring.Echo('setting selectedMex to ', tostring(selectedMex))
end

function widget:CommandNotify(id, params, options)
	local isGuard = (id == CMD_GUARD)
	if not (id == CMD_AREA_MEX or isGuard) then
		return
	end
	if isGuard then
		local mx, my, mb = Spring.GetMouseState()
		local type, unitID = Spring.TraceScreenRay(mx, my)
		if not (type == 'unit' and WG['resource_spot_builder'] and WG['resource_spot_builder'].GetMexBuildings()[spGetUnitDefID(unitID)] and WG['resource_spot_builder'].GetMexBuildings()[spGetUnitDefID(unitID)] < 0.002) then
			return
		end
	end

	if id == CMD_AREA_MEX then
		Spring.Echo("cmd is area mex")
		local queuedMexes = WG['resource_spot_builder'].BuildMex(params, options, isGuard, false, true, selectedMex)
		selectedMex = nil
		if moveReturn and not queuedMexes[1] then	-- used when area_mex isnt queuing a mex, to let the move cmd still pass through
			return false
		end
		return true
	end
end

function widget:CommandsChanged()
	if not metalMap then
		local selectedUnits = Spring.GetSelectedUnits()
		if #selectedUnits > 0 then
			local customCommands = widgetHandler.customCommands
			for i = 1, #selectedUnits do
				if WG['resource_spot_builder'] and WG['resource_spot_builder'].GetMexConstructors()[selectedUnits[i]] then
					customCommands[#customCommands + 1] = {
						id = CMD_AREA_MEX,
						type = CMDTYPE.ICON_AREA,
						tooltip = 'Define an area (with metal spots in it) to make metal extractors in',
						name = 'Mex',
						cursor = 'areamex',
						action = 'areamex',
					}
					return
				end
			end
		end
	end
end


function widget:Initialize()
	--widgetHandler.actionHandler:AddAction(self, "areamex", areamexActionHandler, nil, "p")
	if WG['resource_spot_finder'] and (not WG['resource_spot_finder'].metalSpotsList or (#WG['resource_spot_finder'].metalSpotsList > 0 and #WG['resource_spot_finder'].metalSpotsList <= 2)) then
		metalMap = true
	end

	WG['areamex'] = {}
	WG['areamex'].areaMex = function(uDefID)
		areaMex(uDefID)
	end
end
