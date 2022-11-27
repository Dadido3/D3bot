AddCSLuaFile()

include("d3bot/azlib.lua")("D3bot", {
	"d3bot/1_extraprop_sv.lua",
	"d3bot/1_navmesh.lua",
	"d3bot/1_navmesh_cl.lua",
	"d3bot/1_navmesh_sv.lua",
	"d3bot/2_mapnavmeshui_cl.lua",
	"d3bot/2_mapnavmeshui_sv.lua" })

D3bot.BotHooksId = "D3bot"

-- Shared files
AddCSLuaFile("d3bot/sh_async.lua")
AddCSLuaFile("d3bot/sh_utilities.lua")
include("d3bot/sh_async.lua")
include("d3bot/sh_utilities.lua")

-- Client files
AddCSLuaFile("d3bot/cl_convars.lua")
AddCSLuaFile("d3bot/cl_ui.lua")
AddCSLuaFile("d3bot/vgui/meshing_main.lua")
if CLIENT then
	include("d3bot/cl_convars.lua")
	include("d3bot/cl_ui.lua")
	include("d3bot/vgui/meshing_main.lua")
end

-- Server files
if SERVER then
	include("d3bot/sv_config.lua")
	include("d3bot/sv_utilities.lua")
	include("d3bot/sv_names.lua")
	include("d3bot/sv_path.lua")
	include("d3bot/sv_extend_player.lua")
	include("d3bot/sv_debug.lua")
	include("d3bot/sv_navmeta.lua")
	include("d3bot/sv_navmesh_generate.lua")
	include("d3bot/sv_benchmark.lua")
	
	if engine.ActiveGamemode() == "zombiesurvival" then
		include("d3bot/sv_zs_bot_handler/node_metadata.lua")
		include("d3bot/sv_zs_bot_handler/supervisor.lua")
		include("d3bot/sv_zs_bot_handler/handle.lua")
		include("d3bot/sv_zs_bot_handler/basics.lua")
	end
end
