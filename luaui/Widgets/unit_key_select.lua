---@diagnostic disable-next-line: duplicate-set-field
function widget:GetInfo()
	return {
		name = "KeySelect",
		desc = "Selects units on keypress.",
		author = "woss (Tyson Buzza)",
		date = "Aug 24, 2024",
		license = "Public Domain",
		layer = -999999,
		enabled = true
	}
end

local selectApi = VFS.Include("luaui/Widgets/Include/select_api.lua")

local function handleSetCommand(_, commandDef)
	local command = selectApi.getCommand(commandDef)
	command()
end

---@diagnostic disable-next-line: duplicate-set-field
function widget:Initialize()
	widgetHandler:AddAction("select", handleSetCommand, nil, "p")
end

---@diagnostic disable-next-line: duplicate-set-field
function widget:Shutdown()
	WG['keyselect'] = nil
end
