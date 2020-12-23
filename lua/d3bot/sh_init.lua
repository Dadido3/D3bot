AddCSLuaFile()

------------------------------------------------------
--						Init						--
------------------------------------------------------

-- Init namespaces
D3bot = D3bot or {}
D3bot.Version = {1, 0, 0} -- TODO: Create SemVer object or something
D3bot.Config = D3bot.Config or {} -- General configuration table
D3bot.Util = D3bot.Util or {} -- Utility functions
D3bot.ConCommands = D3bot.ConCommands or {} -- List of commands that can be run from the console
D3bot.NavMain = D3bot.NavMain or {} -- Container for the main navmesh instance for both the server and client
D3bot.NavFile = D3bot.NavFile or {} -- Navmesh file functions
D3bot.NavPubSub = D3bot.NavPubSub or {} -- Navmesh pub/sub functions
D3bot.NavEdit = D3bot.NavEdit or {} -- Functions to edit the main navmesh instance on the server. The functions are available on the client realm, too
D3bot.Locomotion = D3bot.Locomotion or {} -- Locomotion handlers
D3bot.Brains = D3bot.Brains or {} -- Brain handlers

-- Init default values
D3bot.PrintPrefix = "D3bot:"
D3bot.HookPrefix = "D3bot_"
D3bot.AddonRoot = "d3bot/"

-- Init class namespaces
D3bot.CONCOMMAND = D3bot.CONCOMMAND or {} -- Console command class, to replicate and parse client side commands
D3bot.NAV_MESH = D3bot.NAV_MESH or {} -- NAV_MESH Class
D3bot.NAV_EDGE = D3bot.NAV_EDGE or {} -- NAV_EDGE Class
D3bot.NAV_TRIANGLE = D3bot.NAV_TRIANGLE or {} -- NAV_TRIANGLE Class

------------------------------------------------------
--						Includes					--
------------------------------------------------------

-- General stuff
include("sh_util.lua")
local UTIL = D3bot.Util -- From here on UTIL.IncludeRealm can be used
UTIL.IncludeRealm("sv_control.lua", UTIL.REALM_SERVER)
UTIL.IncludeRealm("sv_ulx_fix.lua", UTIL.REALM_SERVER)
UTIL.IncludeRealm("sh_concommand.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("sh_concommands.lua", UTIL.REALM_SHARED)

-- Navmesh stuff
UTIL.IncludeRealm("navmesh/sh_main.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("navmesh/sh_navmesh.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("navmesh/sh_edge.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("navmesh/sh_triangle.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("navmesh/sh_pubsub.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("navmesh/sh_edit.lua", UTIL.REALM_SHARED)
UTIL.IncludeRealm("navmesh/sv_file.lua", UTIL.REALM_SERVER)

-- Load bot naming script (default, and any optional override)
UTIL.IncludeRealm("names/sv_default.lua", UTIL.REALM_SERVER)
if D3bot.Config.NameScript then
	UTIL.IncludeRealm("names/sv_" .. D3bot.Config.NameScript .. ".lua", UTIL.REALM_SERVER)
end

-- Load any gamemode specific logic
UTIL.IncludeRealm("gamemodes/" .. engine.ActiveGamemode() .. "/sh_init.lua", UTIL.REALM_SHARED)

-- Load brains (General and gamemode specific)
UTIL.IncludeDirectory(D3bot.AddonRoot .. "brains/", "*.lua", UTIL.REALM_SERVER)
UTIL.IncludeDirectory(D3bot.AddonRoot .. "gamemodes/" .. engine.ActiveGamemode() .. "/brains/", "*.lua", UTIL.REALM_SERVER)

-- Load general locomotion controllers (General and gamemode specific)
UTIL.IncludeDirectory(D3bot.AddonRoot .. "locomotion/", "*.lua", UTIL.REALM_SERVER)
UTIL.IncludeDirectory(D3bot.AddonRoot .. "gamemodes/" .. engine.ActiveGamemode() .. "/locomotion/", "*.lua", UTIL.REALM_SERVER)
