
if engine.ActiveGamemode() == "zombiesurvival" then
	hook.Add("PlayerSpawn", "!human info", function(pl)
		if not AzBot.IsSelfRedeemEnabled or pl:Team() ~= TEAM_UNDEAD or GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then return end
		local hint = "You can type !human before wave " .. (AzBot.SelfRedeemWaveMax + 1) .. " to play as survivor."
		pl:PrintMessage(HUD_PRINTCENTER, hint)
		pl:ChatPrint(hint)
	end)
	
	function ulx.giveHumanLoadout(pl)
		pl:Give("weapon_zs_fists")
		pl:Give("weapon_zs_peashooter")
		pl:GiveAmmo(50, "pistol")
	end
	
	function ulx.tryBringToHumans(pl)
		local potSpawnTgts = team.GetPlayers(TEAM_HUMAN)
		for i = 1, 5 do
			local potSpawnTgtOrNil = table.Random(potSpawnTgts)
			if IsValid(potSpawnTgtOrNil) and not util.TraceHull{
				start = potSpawnTgtOrNil:GetPos(),
				endpos = potSpawnTgtOrNil:GetPos(),
				mins = pl:OBBMins(),
				maxs = pl:OBBMaxs(),
				filter = potSpawnTgts,
				mask = MASK_PLAYERSOLID }.Hit then
				pl:SetPos(potSpawnTgtOrNil:GetPos())
				break
			end
		end
	end
	
	local nextByPl = {}
	local tierByPl = {}
	function ulx.human(pl)
		if not AzBot.IsSelfRedeemEnabled then
			local response = "This command is enabled on bot maps only!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then
			local response = "It's too late to self-redeem (can only be done before wave " .. (AzBot.SelfRedeemWaveMax + 1) .. ")."
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if pl:Team() == TEAM_HUMAN then
			local response = "You're already human!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local remainingTime = (nextByPl[pl] or 0) - CurTime()
		if remainingTime > 0 then
			local response = "You already self-redeemed recently. Try again in " .. remainingTime .. " seconds!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local nextTier = (tierByPl[pl] or 0) + 1
		tierByPl[pl] = nextTier
		local cooldown = nextTier * 30
		nextByPl[pl] = CurTime() + cooldown
		local response = "You self-redeemed. Your current cooldown until next self-redeem is " .. math.ceil(cooldown) .. " seconds."
		pl:ChatPrint(response)
		pl:PrintMessage(HUD_PRINTCENTER, response)
		pl:ChangeTeam(TEAM_HUMAN)
		pl:SetDeaths(0)
		pl:SetPoints(0)
		pl:DoHulls()		
		pl:UnSpectateAndSpawn()
		pl:StripWeapons()
		pl:StripAmmo()
		ulx.giveHumanLoadout(pl)
		ulx.tryBringToHumans(pl)
	end
	local cmd = ulx.command("Zombie Survival", "ulx human", ulx.human, "!human", true)
	cmd:defaultAccess(ULib.ACCESS_ALL)
	cmd:help("If you're a zombie, you can use this command to instantly respawn as a human with a default loadout.")
end

local function registerCmd(camelCaseName, access, ...)
	local func
	local params = {}
	for idx, arg in ipairs{ ... } do
		if istable(arg) then
			table.insert(params, arg)
		elseif isfunction(arg) then
			func = arg
			break
		else
			break
		end
	end
	ulx["azBot" .. camelCaseName] = func
	local cmdStr = (access == ULib.ACCESS_SUPERADMIN and "azbot " or "") .. camelCaseName:lower()
	local cmd = ulx.command("AzBot", cmdStr, func, "!" .. cmdStr)
	for k, param in pairs(params) do cmd:addParam(param) end
	cmd:defaultAccess(access)
end
local function registerSuperadminCmd(camelCaseName, ...) registerCmd(camelCaseName, ULib.ACCESS_SUPERADMIN, ...) end
local function registerAdminCmd(camelCaseName, ...) registerCmd(camelCaseName, ULib.ACCESS_ADMIN, ...) end

local plsParam = { type = ULib.cmds.PlayersArg }
local numParam = { type = ULib.cmds.NumArg }
local strParam = { type = ULib.cmds.StringArg }
local strRestParam = { type = ULib.cmds.StringArg, ULib.cmds.takeRestOfLine }
local optionalStrParam = { type = ULib.cmds.StringArg, ULib.cmds.optional }

registerAdminCmd("BotMod", numParam, function(caller, num)
	local formerZombiesCountAddition = AzBot.ZombiesCountAddition
	AzBot.ZombiesCountAddition = math.Round(num)
	local function format(num) return "[formula + (" .. num .. ")]" end
	caller:ChatPrint("Zombies count changed from " .. format(formerZombiesCountAddition) .. " to " .. format(AzBot.ZombiesCountAddition) .. ".")
end)

registerSuperadminCmd("ViewMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "view") end end)
registerSuperadminCmd("EditMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "edit") end end)
registerSuperadminCmd("HideMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, nil) end end)

registerSuperadminCmd("SaveMesh", function(caller)
	AzBot.SaveMapNavMesh()
	caller:ChatPrint("Saved.")
end)
registerSuperadminCmd("ReloadMesh", function(caller)
	AzBot.LoadMapNavMesh()
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Reloaded.")
end)
registerSuperadminCmd("RefreshMeshView", function(caller)
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Refreshed.")
end)

registerSuperadminCmd("SetParam", strParam, strParam, optionalStrParam, function(caller, id, name, serializedNumOrStrOrEmpty)
	AzBot.TryCatch(function()
		AzBot.MapNavMesh.ItemById[AzBot.DeserializeNavMeshItemId(id)]:SetParam(name, serializedNumOrStrOrEmpty)
		AzBot.UpdateMapNavMeshUiSubscribers()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerSuperadminCmd("SetMapParam", strParam, optionalStrParam, function(caller, name, serializedNumOrStrOrEmpty)
	AzBot.TryCatch(function()
		AzBot.MapNavMesh:SetParam(name, serializedNumOrStrOrEmpty)
		AzBot.SaveMapNavMeshParams()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerSuperadminCmd("ViewPath", plsParam, strParam, strParam, function(caller, pls, startNodeId, endNodeId)
	local nodeById = AzBot.MapNavMesh.NodeById
	local startNode = nodeById[AzBot.DeserializeNavMeshItemId(startNodeId)]
	local endNode = nodeById[AzBot.DeserializeNavMeshItemId(endNodeId)]
	if not startNode or not endNode then
		caller:ChatPrint("Not all specified nodes exist.")
		return
	end
	local path = AzBot.GetBestMeshPathOrNil(startNode, endNode)
	if not path then
		caller:ChatPrint("Couldn't find any path for the two specified nodes.")
		return
	end
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, path) end
end)
registerSuperadminCmd("DebugPath", plsParam, optionalStrParam, function(caller, pls, serializedEntIdxOrEmpty)
	local ent = serializedEntIdxOrEmpty == "" and caller:GetEyeTrace().Entity or Entity(tonumber(serializedEntIdxOrEmpty) or -1)
	if not IsValid(ent) then
		caller:ChatPrint("No entity cursored or invalid entity index specified.")
		return
	end
	caller:ChatPrint("Debugging path from player to " .. tostring(ent) .. ".")
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, pl, ent) end
end)
registerSuperadminCmd("ResetPath", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.HideMapNavMeshPath(pl) end end)

local modelOrNilByShortModel = {
	pole = "models/props_c17/signpole001.mdl",
	crate = "models/props_junk/wood_crate001a.mdl",
	barrel = "models/props_c17/oildrum001.mdl",
	oil = "models/props_c17/oildrum001_explosive.mdl",
	chair = "models/props_wasteland/controlroom_chair001a.mdl",
	couch = "models/props_c17/FurnitureCouch001a.mdl",
	bench = "models/props_c17/bench01a.mdl",
	cart = "models/props_junk/PushCart01a.mdl",
	bomb = "models/Combine_Helicopter/helicopter_bomb01.mdl",
	propane = "models/props_junk/propane_tank001a.mdl",
	saw = "models/props_junk/sawblade001a.mdl",
	bin = "models/props_junk/TrashBin01a.mdl",
	soda = "models/props_interiors/VendingMachineSoda01a.mdl",
	bucket = "models/props_junk/MetalBucket01a.mdl",
	paint = "models/props_junk/metal_paintcan001a.mdl",
	cabinet = "models/props_wasteland/controlroom_filecabinet002a.mdl",
	longbench = "models/props_wasteland/cafeteria_bench001a.mdl",
	longtable = "models/props_wasteland/cafeteria_table001a.mdl",
	container = "models/props_wasteland/cargo_container01.mdl",
	opencontainer = "models/props_wasteland/cargo_container01b.mdl",
	tub = "models/props_wasteland/laundry_cart001.mdl",
	ushelf = "models/props_wasteland/kitchen_shelf002a.mdl",
	shelf = "models/props_wasteland/kitchen_shelf001a.mdl",
	gas = "models/props_junk/gascan001a.mdl",
	skull = "models/Gibs/HGIBS.mdl",
	hula = "models/props_lab/huladoll.mdl",
	sign = "models/props_lab/bewaredog.mdl",
	ravenholm = "models/props_junk/ravenholmsign.mdl",
	can = "models/props_junk/PopCan01a.mdl",
	plasticcrate = "models/props_junk/PlasticCrate01a.mdl",
	tire = "models/props_vehicles/carparts_tire01a.mdl",
	register = "models/props_c17/cashregister01a.mdl",
	horse = "models/props_c17/statue_horse.mdl",
	bust = "models/props_combine/breenbust.mdl",
	battery = "models/items/car_battery01.mdl",
	desk = "models/props_interiors/Furniture_Desk01a.mdl",
	ovalbucket = "models/props_junk/MetalBucket02a.mdl",
	blastdoor = "models/props_lab/blastdoor001a.mdl",
	board = "models/props_junk/TrashDumpster02b.mdl",
	bed = "models/props_wasteland/prison_bedframe001b.mdl",
	door = "models/props_doors/door03_slotted_left.mdl",
	pallet = "models/props_junk/wood_pallet001a.mdl",
	square = "models/props_phx/construct/metal_plate1.mdl",
	rectangle = "models/props_phx/construct/metal_plate1x2.mdl",
	beam = "models/hunter/blocks/cube025x2x025.mdl",
	cube = "models/hunter/blocks/cube05x05x05.mdl",
	ball = "models/XQM/Rails/trackball_1.mdl",
	mine = "models/Roller.mdl",
	why = "models/props_c17/furniturearmchair001a.mdl",
	grate = "models/props_wasteland/prison_celldoor001b.mdl",
	fence = "models/props_c17/fence01b.mdl",
	laundry = "models/props_wasteland/laundry_cart002.mdl",
	heavy = "models/props_c17/Lockers001a.mdl",
	fridge = "models/props_c17/FurnitureFridge001a.mdl",
	wood = "models/props_debris/wood_board07a.mdl",
	shoe = "models/props_junk/Shoe001a.mdl",
	post = "models/props_trainstation/trainstation_post001.mdl" }
registerAdminCmd("SpawnProp", strParam, function(caller, modelOrShortModel)
	local prop = ents.Create("prop_physics")
	prop:SetModel(modelOrNilByShortModel[modelOrShortModel:lower()] or modelOrShortModel)
	local cursoredPosOrNil = caller:GetEyeTrace().HitPos
	if cursoredPosOrNil then prop:SetPos(cursoredPosOrNil + Vector(0, 0, 10)) end
	prop:SetAngles(Angle(0, caller:EyeAngles().y, 0))
	prop:Spawn()
	if GAMEMODE.SetupProps then gamemode.Call("SetupProps") end
end)
local function getEyeEntity(pl) return pl:GetEyeTrace().Entity end
local function getNiceName(ent) return IsValid(ent) and "entity #" .. ent:EntIndex() .. " '" .. (ent:GetClass() == "prop_physics" and ent:GetModel() or ent:GetClass()) .. "'" or "invalid entity" end
registerAdminCmd("GetModel", function(caller) caller:ChatPrint(getNiceName(getEyeEntity(caller))) end)
local removeeByPl = {}
registerAdminCmd("Remove", function(caller)
	local ent = getEyeEntity(caller)
	removeeByPl[caller] = ent
	caller:ChatPrint("Are you sure you want to remove " .. getNiceName(ent) .. "? Use ConfirmRemove (WARNING: some may break game) to remove it or use Remove to change entity.")
end)
registerAdminCmd("ConfirmRemove", function(caller) removeeByPl[caller]:Remove() end)
registerAdminCmd("PropList", function(caller) for shortModel, model in pairs(modelOrNilByShortModel) do caller:ChatPrint(shortModel .. ": " .. model) end end)
registerAdminCmd("IsExtraProp", function(caller)
	local ent = getEyeEntity(caller)
	caller:ChatPrint(tostring(AzBot.GetIsExtraProp(ent)) .. " (" .. getNiceName(ent) .. ")")
end)
registerAdminCmd("ExtraProp", function(caller)
	local ent = getEyeEntity(caller)
	caller:ChatPrint(getNiceName(ent) .. ":")
	if AzBot.GetIsExtraProp(ent) then
		caller:ChatPrint("It's already an extra prop.")
		return
	end
	caller:ChatPrint(AzBot.TrySetExtraProp(ent) and "It's an extra prop now." or "Failed to make it an extra prop.")
end)
registerAdminCmd("UnextraProp", function(caller)
	local ent = getEyeEntity(caller)
	caller:ChatPrint(getNiceName(ent) .. ":")
	caller:ChatPrint(AzBot.TryUnsetExtraProp(ent) and "It's not an extra prop anymore." or "Wasn't an extra prop anyway.")
end)
registerAdminCmd("SaveExtraProps", function(caller)
	AzBot.SaveExtraProps()
	caller:ChatPrint("Saved.")
end)
registerAdminCmd("ReloadExtraProps", function(caller)
	AzBot.ReloadExtraProps()
	caller:ChatPrint("Reloaded.")
end)

if engine.ActiveGamemode() == "zombiesurvival" then
	registerAdminCmd("ForceClass", strRestParam, function(caller, className)
		for classKey, class in ipairs(GAMEMODE.ZombieClasses) do
			if class.Name:lower() == className:lower() then
				for _, bot in ipairs(player.GetBots()) do
					if bot:GetZombieClassTable().Index ~= class.Index then
						bot.DeathClass = class.Index
						bot:Kill()
					end
				end
				break
			end
		end
	end)
end