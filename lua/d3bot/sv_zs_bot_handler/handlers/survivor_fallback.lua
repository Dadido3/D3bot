D3bot.Handlers.Survivor_Fallback = D3bot.Handlers.Survivor_Fallback or {}
local HANDLER = D3bot.Handlers.Survivor_Fallback

HANDLER.angOffshoot = 20

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_SURVIVOR
end

function HANDLER.UpdateBotCmdFunction(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	-- Fix knocked down bots from sliding around. (Workaround for the NoxiousNet codebase, as ply:Freeze() got removed from status_knockdown, status_revive, ...)
	if bot.KnockedDown and IsValid(bot.KnockedDown) or bot.Revive and IsValid(bot.Revive) then
		return
	end
	
	bot:D3bot_UpdatePathProgress()
	local mem = bot.D3bot_Mem
	local botPos = bot:GetPos()
	
	local result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle, minorStuck, majorStuck, facesHindrance = D3bot.Basics.WalkAttackAuto(bot)
	if result and math.abs(forwardSpeed) > 30 then
		actions.Attack = false
	else
		result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle = D3bot.Basics.AimAndShoot(bot, mem.AttackTgtOrNil, mem.maxShootingDistance) -- TODO: Make bots walk backwards while shooting
		if not result then
			result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle = D3bot.Basics.LookAround(bot)
			if not result then return end
		end
	end
	
	actions = actions or {}
	
	if bot:WaterLevel() == 3 and not mem.NextNodeOrNil then
		actions.Jump = true
	end
	
	if facesHindrance and HANDLER.FacesBarricade(bot) then
		mem.PhaseTime = CurTime()
	end
	if mem.PhaseTime and mem.PhaseTime > CurTime() - 1 and math.random(2) == 1 then
		if not mem.TgtOrNil and not mem.PosTgtOrNil and not mem.NodeTgtOrNil then
			-- If ghosting but there is no target, set nearby player as target
			local friends = D3bot.From(player.GetHumans()):Where(function(k, v) return HANDLER.IsFriend(bot, v) and botPos:Distance(v:GetPos()) < 500 end).R
			bot:D3bot_SetTgtOrNil(table.Random(friends), true, nil)
		end
		actions.Phase = true
	end
	
	local buttons
	if actions then
		buttons = bit.bor(actions.MoveForward and IN_FORWARD or 0, actions.MoveBackward and IN_BACK or 0, actions.MoveLeft and IN_MOVELEFT or 0, actions.MoveRight and IN_MOVERIGHT or 0, actions.Attack and IN_ATTACK or 0, actions.Attack2 and IN_ATTACK2 or 0, actions.Reload and IN_RELOAD or 0, actions.Duck and IN_DUCK or 0, actions.Jump and IN_JUMP or 0, actions.Use and IN_USE or 0, actions.Phase and IN_ZOOM or 0)
	end
	
	if aimAngle then bot:SetEyeAngles(aimAngle)	cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	if sideSpeed then cmd:SetSideMove(sideSpeed) end
	if upSpeed then cmd:SetUpMove(upSpeed) end
	if buttons then cmd:SetButtons(buttons) end
end

function HANDLER.ThinkFunction(bot)
	local mem = bot.D3bot_Mem
	local botPos = bot:GetPos()
	
	if not HANDLER.IsEnemy(bot, mem.AttackTgtOrNil) then mem.AttackTgtOrNil = nil end
	
	if mem.nextUpdateSurroundingPlayers and mem.nextUpdateSurroundingPlayers < CurTime() or not mem.nextUpdateSurroundingPlayers then
		mem.nextUpdateSurroundingPlayers = CurTime() + 0.5
		local enemies = D3bot.From(player.GetAll()):Where(function(k, v) return HANDLER.IsEnemy(bot, v) end).R
		local closeEnemies = D3bot.From(enemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 1000 end).R -- TODO: Constant for the distance
		local closerEnemies = D3bot.From(closeEnemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 600 end).R -- TODO: Constant for the distance
		local dangerouscloseEnemies = D3bot.From(closerEnemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 300 end).R -- TODO: Constant for the distance
		local newAttackTarget = table.Random(closerEnemies) or table.Random(closeEnemies) or table.Random(enemies)
		if HANDLER.CanShootTarget(bot, newAttackTarget) then mem.AttackTgtOrNil = newAttackTarget end
		if table.Count(dangerouscloseEnemies) > 0 then
			mem.AttackTgtOrNil = table.Random(dangerouscloseEnemies)
			-- Check if undead can see/walk to bot, and then calculate escape path.
			if mem.AttackTgtOrNil:D3bot_CanSeeTarget(nil, bot) and (not mem.NextNodeOrNil or (mem.lastEscapePath or 0) < CurTime() - 2) then
				mem.lastEscapePath = CurTime()
				escapePath = HANDLER.FindEscapePath(bot, D3bot.MapNavMesh:GetNearestNodeOrNil(botPos), closerEnemies)
				if escapePath then
					--D3bot.Debug.DrawPath(GetPlayerByName("D3"), escapePath, nil, nil, true)
					mem.holdPathTime = CurTime() + 2
					bot:D3bot_SetPath(escapePath, false)
				end
			end
		else
			if not mem.holdPathTime or mem.holdPathTime < CurTime() then
				bot:D3bot_ResetTgt()
			end
			if not mem.NextNodeOrNil and ((mem.nextHumanPath or 0) < CurTime() or bot:WaterLevel() == 3) then
				mem.nextHumanPath = CurTime() + 10 + math.random() * 20
				path = HANDLER.FindPathToHuman(D3bot.MapNavMesh:GetNearestNodeOrNil(botPos))
				if path then
					--D3bot.Debug.DrawPath(GetPlayerByName("D3"), path, nil, Color(0, 0, 255), true)
					mem.holdPathTime = CurTime() + 20
					bot:D3bot_SetPath(path, false)
				end
			end
		end
	end
	
	if mem.nextUpdateOffshoot and mem.nextUpdateOffshoot < CurTime() or not mem.nextUpdateOffshoot then
		mem.nextUpdateOffshoot = CurTime() + 0.4 + math.random() * 0.2
		bot:D3bot_UpdateAngsOffshoot(HANDLER.angOffshoot)
	end
	
	local function pathCostFunction(node, linkedNode, link)
		local nodeMetadata = D3bot.NodeMetadata[linkedNode]
		local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		return playerFactorByUndead * 3000 - playerFactorBySurvivors * 4000
	end
	if mem.nextUpdatePath and mem.nextUpdatePath < CurTime() or not mem.nextUpdatePath then
		mem.nextUpdatePath = CurTime() + 0.9 + math.random() * 0.2
		bot:D3bot_UpdatePath(pathCostFunction, nil) -- This will not do anything as long as there is no target set (TgtOrNil, PosTgtOrNil, NodeTgtOrNil), the real magic happens in this handlers think function.
	end
	
	-- Change held weapon based on target distance
	if mem.nextHeldWeaponUpdate and mem.nextHeldWeaponUpdate < CurTime() or not mem.nextHeldWeaponUpdate then
		mem.nextHeldWeaponUpdate = CurTime() + 1 + math.random() * 1
		local weapons = bot:GetWeapons()
		local filteredWeapons = {}
		local bestRating, bestWeapon = 0, nil
		local enemyDistance = mem.AttackTgtOrNil and mem.AttackTgtOrNil:GetPos():Distance(bot:GetPos()) or 300
		for _, v in pairs(weapons) do
			local weaponType, rating, maxDistance = HANDLER.WeaponRatingFunction(v, enemyDistance)
			local ammoType = v:GetPrimaryAmmoType()
			local ammo = v:Clip1() + bot:GetAmmoCount(ammoType)
			-- Silly cheat to prevent bots from running out of ammo TODO: Add buy logic
			if ammo == 0 then
				bot:SetAmmo(50, ammoType)
			end
			
			if ammo > 0 and enemyDistance < maxDistance and bestRating < rating and weaponType == HANDLER.Weapon_Types.RANGED then
				bestRating, bestWeapon, bestMaxDistance = rating, v.ClassName, maxDistance
			end
		end
		if bestWeapon then
			bot:SelectWeapon(bestWeapon)
			mem.maxShootingDistance = bestMaxDistance
		end
	end
	
	-- Win the game by escaping via sigil doors
	if GAMEMODE:GetWave() >= GAMEMODE:GetNumberOfWaves() then
		if mem.nextEscapeUpdate and mem.nextEscapeUpdate < CurTime() or not mem.nextEscapeUpdate then
			mem.nextEscapeUpdate = CurTime() + 4 + math.random() * 2
			
			local escapeDoors = D3bot.GetEntsOfClss({"prop_obj_exit"})
			local closestDoor, bestDistance = nil, math.huge
			for k, v in pairs(escapeDoors) do
				local dist = v:GetPos():Distance(botPos)
				if bestDistance > dist then
					closestDoor, bestDistance = v, dist
				end
			end
			if closestDoor then
				bot:D3bot_SetTgtOrNil(closestDoor, true, 0)
			end
		end
	end
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	local attacker = dmg:GetAttacker()
	if not HANDLER.CanBeAttackTgt(bot, attacker) then return end
	local mem = bot.D3bot_Mem
	--if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(bot:GetPos()) <= D3bot.BotTgtFixationDistMin then return end
	mem.AttackTgtOrNil = attacker
	--bot:Say("Stop That! I'm gonna shoot you, "..attacker:GetName().."!")
	--bot:Say("help")
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	--bot:Say("Gotcha!")
end

function HANDLER.OnDeathFunction(bot)
	--bot:Say("rip me!")
end

-----------------------------------
-- Custom functions and settings --
-----------------------------------

HANDLER.Weapon_Types = {}
HANDLER.Weapon_Types.RANGED = 1
HANDLER.Weapon_Types.MELEE = 2

function HANDLER.WeaponRatingFunction(weapon, targetDistance)
	local sweptable = weapons.GetStored(weapon.ClassName)
	local weaponType = HANDLER.Weapon_Types.MELEE
	if weapon.Base == "weapon_zs_base" then
		weaponType = HANDLER.Weapon_Types.RANGED
	end
	
	local targetDiameter = 6
	local targetArea = math.pi * math.pow(targetDiameter / 2, 2)
	
	local numShots = sweptable.Primary.NumShots or 1
	local damage = (sweptable.Damage or sweptable.Primary.Damage or 0)
	local delay = sweptable.Primary.Delay or 1
	local cone = weapon.GetCone and weapon:GetCone() or ((weapon.ConeMax or 45) + (weapon.ConeMin or 45)*6) / 7
	
	local dmgPerSec = damage * numShots / delay -- TODO: Use more parameters like reload time.
	local maxDistance = targetDiameter / math.tan(math.rad(cone)) / 2
	local spreadArea = math.pi * math.pow(math.tan(math.rad(cone)) * targetDistance, 2)
	
	local areaIntersection = math.min(targetArea, spreadArea) / spreadArea
	
	local rating = dmgPerSec * areaIntersection
	
	return weaponType, rating, maxDistance
end

function HANDLER.FindEscapePath(bot, startNode, enemies)
	local tempNodePenalty = {}
	local escapeDirection = Vector()
	for _, enemy in pairs(enemies) do
		tempNodePenalty = D3bot.NeighbourNodeFalloff(D3bot.MapNavMesh:GetNearestNodeOrNil(enemy:GetPos()), 2, 1, 0.5, tempNodePenalty)
		escapeDirection:Add(bot:GetPos() - enemy:GetPos())
	end
	escapeDirection:Normalize()
	
	for _, enemy in pairs(enemies) do
		tempNodePenalty = D3bot.NeighbourNodeFalloff(D3bot.MapNavMesh:GetNearestNodeOrNil(enemy:GetPos()), 2, 1, 0.5, tempNodePenalty)
	end
	
	local function pathCostFunction(node, linkedNode, link)
		local directionPenalty
		if node == startNode then
			local direction = (linkedNode.Pos - node.Pos)
			directionPenalty = (1 - direction:Dot(escapeDirection)) * 1000
			--clDebugOverlay.Line(GetPlayerByName("D3"), node.Pos, linkedNode.Pos, nil, Color(directionPenalty/2000*255, 0, 0), true)
		end
		local nodeMetadata = D3bot.NodeMetadata[linkedNode]
		local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		local cost = -playerFactorBySurvivors * 50 + playerFactorByUndead * 150 + (tempNodePenalty[linkedNode] or 0) * 500 + (directionPenalty or 0)
		--for _, enemy in pairs(enemies) do
		--	cost = cost + 100 / (LerpVector(0.5, node.Pos, linkedNode.Pos):Distance(enemy:GetPos()) + 100) * 0.1 * node.Pos:Distance(linkedNode.Pos) -- Weight by link length
		--end
		return cost-- + node.Pos:Distance(linkedNode.Pos) * 2
	end
	local function heuristicCostFunction(node)
		local nodeMetadata = D3bot.NodeMetadata[node]
		--local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		return playerFactorByUndead * 150 + (tempNodePenalty[node] or 0) * 10
	end
	return D3bot.GetEscapeMeshPathOrNil(startNode, 50, pathCostFunction, heuristicCostFunction, {Walk = true})
end

function HANDLER.FindPathToHuman(node)
	local function pathCostFunction(node, linkedNode, link)
		return node.Pos:Distance(linkedNode.Pos) * 0.1
	end
	local function heuristicCostFunction(node)
		local nodeMetadata = D3bot.NodeMetadata[node]
		local playerFactorBySurvivors = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_SURVIVOR] or 0
		local playerFactorByUndead = nodeMetadata and nodeMetadata.PlayerFactorByTeam and nodeMetadata.PlayerFactorByTeam[TEAM_UNDEAD] or 0
		return -playerFactorBySurvivors * 1600000 + playerFactorByUndead * 500000
	end
	--D3bot.Debug.DrawNodeMetadata(GetPlayerByName("D3"), D3bot.NodeMetadata, 5)
	--D3bot.Debug.DrawPath(GetPlayerByName("D3"), D3bot.GetEscapeMeshPathOrNil(node, 400, pathCostFunction, heuristicCostFunction, {Walk = true}), 5, Color(255, 0, 0), true)
	return D3bot.GetEscapeMeshPathOrNil(node, 400, pathCostFunction, heuristicCostFunction, {Walk = true})
end

function HANDLER.CanShootTarget(bot, target)
	if not IsValid(target) then return end
	local origin = bot:D3bot_GetViewCenter()
	local targetPos = target:D3bot_GetViewCenter()
	local tr = util.TraceLine({
		start = origin,
		endpos = targetPos,
		filter = player.GetAll(),
		mask = MASK_SHOT_HULL
	})
	return not tr.Hit
end

function HANDLER.FacesBarricade(bot)
	local tr = bot:GetEyeTrace()
	local entity = tr.Entity
	local distance = bot:D3bot_GetViewCenter():Distance(tr.HitPos)
	if not IsValid(entity) or not entity:IsNailed() then return end
	return distance < 100
end

function HANDLER.IsEnemy(bot, ply)
	local ownTeam = bot:Team()
	if IsValid(ply) and bot ~= ply and ply:IsPlayer() and ply:Team() ~= ownTeam and ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() then return true end
end

function HANDLER.IsFriend(bot, ply)
	local ownTeam = bot:Team()
	if IsValid(ply) and bot ~= ply and ply:IsPlayer() and ply:Team() == ownTeam and ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() then return true end
end

function HANDLER.CanBeAttackTgt(bot, target)
	if not target or not IsValid(target) then return end
	local ownTeam = bot:Team()
	if target:IsPlayer() and target ~= bot and target:Team() ~= ownTeam and target:GetObserverMode() == OBS_MODE_NONE and target:Alive() then return true end
end