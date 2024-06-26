function widget:GetInfo()
   return {
      name      = "Unit Idle Builder Icons",
      desc      = "Shows the sleeping icon above workers that are idle",
      author    = "Floris, Beherith",
      date      = "June 2024",
      license   = "GNU GPL, v2 or later",
      layer     = -40,
      enabled   = true
   }
end

local idleUnitDelay = 8	-- how long a unit must be idle before the icon shows up

local iconSequenceImages = 'Luaui/Images/idleicon/idlecon_' 	-- must be png's
local iconSequenceNum = 59	-- always starts at 1
local iconSequenceFrametime = 0.02	-- duration per frame

local unitConf = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1]) and not unitDef.customParams.isairbase then
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 3.3 * ( (xsize+2)^2 + (zsize+2)^2 )^0.5
		unitConf[unitDefID] = {7.5 +(scale/2.2), unitDef.height-0.1, unitDef.isFactory}
	end
end

local teamUnits = {} -- table of teamid to table of stallable unitID : unitDefID
local teamList = {} -- {team1, team2, team3....}
local idleUnitList = {}

local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitTeam = Spring.GetUnitTeam
local spec, fullview = Spring.GetSpectatingState()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- GL4 Backend stuff:
local waitIconVBO = nil
local energyIconShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 0.75
	shaderConfig.ANIMATION = 1
	shaderConfig.FULL_ROTATION = 0
	shaderConfig.CLIPTOLERANCE = 1.2
	shaderConfig.INITIALSIZE = 0.22
	shaderConfig.BREATHESIZE = 0--0.1
  -- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.POST_GEOMETRY = " gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	waitIconVBO, energyIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "energy icons")
	if waitIconVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	spec, fullview = Spring.GetSpectatingState()
	if spec then
		fullview = select(2,Spring.GetSpectatingState())
	end
	if not fullview then
		teamList = Spring.GetTeamList(Spring.GetMyAllyTeamID())
	else
		teamList = Spring.GetTeamList()
	end

	clearInstanceTable(waitIconVBO) -- clear all instances
	teamUnits = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
	end
	uploadAllElements(waitIconVBO) -- upload them all
end


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then return end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

local function updateIcons()
	local gf = Spring.GetGameFrame()
	for teamID, units in pairs(teamUnits) do
		for unitID, unitDefID in pairs(units) do
			local queue = unitConf[unitDefID][3] and Spring.GetFactoryCommands(unitID, 1) or spGetCommandQueue(unitID, 1)
			if not (queue and queue[1]) then
				if not Spring.GetUnitIsBeingBuilt(unitID) and waitIconVBO.instanceIDtoIndex[unitID] == nil then -- not already being drawn
					if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
						if not idleUnitList[unitID] then
							idleUnitList[unitID] = os.clock()
						elseif idleUnitList[unitID] < os.clock() - idleUnitDelay then
							pushElementInstance(
								waitIconVBO, -- push into this Instance VBO Table
								{unitConf[unitDefID][1], unitConf[unitDefID][1], 0, unitConf[unitDefID][2],  -- lengthwidthcornerheight
								 0, --Spring.GetUnitTeam(featureID), -- teamID
								 4, -- how many vertices should we make ( 2 is a quad)
								 gf, 0, 0.8 , 0, -- the gameFrame (for animations), and any other parameters one might want to add
								 1,0,1,0, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
								 0, 0, 0, 0}, -- these are just padding zeros, that will get filled in
								unitID, -- this is the key inside the VBO Table, should be unique per unit
								false, -- update existing element
								true, -- noupload, dont use unless you know what you want to batch push/pop
								unitID) -- last one should be featureID!
						end
					end
				end
			else
				if waitIconVBO.instanceIDtoIndex[unitID] then
					popElementInstance(waitIconVBO, unitID, true)
				end
				idleUnitList[unitID] = nil
			end
		end
	end
	if waitIconVBO.dirty then
		uploadAllElements(waitIconVBO)
	end
end

function widget:GameFrame(n)
	if Spring.GetGameFrame() % 14 == 0 then
		updateIcons()
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam) -- remove the corresponding ground plate if it exists
	if unitConf[unitDefID] and not Spring.GetUnitIsBeingBuilt(unitID) then
		if teamUnits[unitTeam] == nil then teamUnits[unitTeam] = {} end
		teamUnits[unitTeam][unitID] = unitDefID
	end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	local unitTeam = spGetUnitTeam(unitID)
	if teamUnits[unitTeam] then
		teamUnits[unitTeam][unitID] = nil
	end
	if waitIconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(waitIconVBO, unitID)
	end
	idleUnitList[unitID] = nil
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end

	if waitIconVBO.usedElements > 0 then
		local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
		gl.DepthTest(true)
		gl.DepthMask(false)
		local clock = os.clock() * (1*(iconSequenceFrametime*iconSequenceNum))	-- adjust speed relative to anim frame speed of 0.02sec per frame (59 frames in total)
		local animFrame = math.max(1, math.ceil(iconSequenceNum * (clock - math.floor(clock))))
		gl.Texture(iconSequenceImages .. (animFrame < 100 and '0' or '') .. (animFrame < 10 and '0' or '') .. animFrame .. '.png')
		energyIconShader:Activate()
		energyIconShader:SetUniform("iconDistance",disticon)
		energyIconShader:SetUniform("addRadius",0)
		waitIconVBO.VAO:DrawArrays(GL.POINTS,waitIconVBO.usedElements)
		energyIconShader:Deactivate()
		gl.Texture(false)
		gl.DepthTest(false)
		gl.DepthMask(true)
	end
end
