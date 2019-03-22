local meta = FindMetaTable("Player")

function meta:D3bot_GetAttackPosOrNil(fraction, target)
	local mem = self.D3bot_Mem
	local tgt = target or mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
end

-- Linear extrapolated position of the player entity
function meta:D3bot_GetAttackPosOrNilFuture(fraction, t)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + tgt:GetVelocity()*t or tgt:WorldSpaceCenter()
end

-- Linear extrapolated position of the player entity. (Works with platform physics)
function meta:D3bot_GetAttackPosOrNilFuturePlatforms(fraction, t)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	local phys = tgt:GetPhysicsObject()
	if not IsValid(phys) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + phys:GetVelocity()*t or tgt:WorldSpaceCenter()
end

function meta:D3bot_GetViewCenter()
	return self:GetPos() + (self:Crouching() and self:GetViewOffsetDucked() or self:GetViewOffset())
end

function meta:D3bot_IsLookingAt(targetPos, conditionCos)
	return self:GetAimVector():Dot((targetPos - self:D3bot_GetViewCenter()):GetNormalized()) > (conditionCos or 0.95)
end

function meta:D3bot_CanPounceToPos(pos)
	if not pos then return end
	
	local initVel
	if self:GetActiveWeapon() and self:GetActiveWeapon().PounceVelocity then
		initVel = (1 - 0.5 * (self:GetLegDamage() / GAMEMODE.MaxLegDamage)) * self:GetActiveWeapon().PounceVelocity
	else
		return
	end
	
	local selfPos = self:GetPos()--LerpVector(0.75, self:GetPos(), self:EyePos())
	local trajectories = D3bot.GetTrajectories(initVel, selfPos, pos, 8)
	local resultTrajectories = {}
	for _, trajectory in ipairs(trajectories) do
		local lastPoint = nil
		local hit = false
		for _, point in ipairs(trajectory.points) do
			if lastPoint then
				local tr = util.TraceEntity({start = point, endpos = lastPoint, filter = player.GetAll()}, self)
				if tr.Hit then
					hit = true
					break
				end
			end
			lastPoint = point
		end
		if not hit then
			table.insert(resultTrajectories, trajectory)
		end
	end
	if #resultTrajectories == 0 then resultTrajectories = nil end
	return resultTrajectories
end

function meta:D3bot_CanSeeTarget(fraction, target)
	local attackPos = self:D3bot_GetAttackPosOrNil(fraction, target)
	if not attackPos then return false end
	local mem = self.D3bot_Mem
	if mem and mem.TgtNodeOrNil and mem.NodeOrNil ~= mem.TgtNodeOrNil and mem.TgtNodeOrNil.Params.See == "Disabled" then return false end
	local tr = D3bot.BotSeeTr
	tr.start = self:D3bot_GetViewCenter()
	tr.endpos = attackPos
	tr.filter = player.GetAll()
	return attackPos and not util.TraceHull(tr).Hit
end

function meta:D3bot_FaceTo(pos, origin, lerpFactor, offshootFactor)
	local mem = self.D3bot_Mem
	mem.Angs = LerpAngle(lerpFactor, mem.Angs, (pos - origin):Angle() + mem.AngsOffshoot * (offshootFactor or 1))
end

function meta:D3bot_RerollClass(classes)
	if not GAMEMODE:GetWaveActive() then return end
	if self:GetZombieClassTable().Name == "Zombie Torso" then return end
	if GAMEMODE.ZombieEscape then return end
	local zombieClasses = {}
	for _, class in ipairs(classes) do
		local zombieClass = GAMEMODE.ZombieClasses[class]
		if zombieClass then
			if not zombieClass.Locked and (zombieClass.Unlocked or zombieClass.Wave <= GAMEMODE:GetWave()) then
				table.insert(zombieClasses, zombieClass)
			end
		end
	end
	local zombieClass = table.Random(zombieClasses)
	if not zombieClass then zombieClass = GAMEMODE.ZombieClasses[GAMEMODE.DefaultZombieClass] end
	--self:SetZombieClass(zombieClass.Index)
	self.DeathClass = zombieClass.Index
end

function meta:D3bot_ResetTgt() -- Reset all kind of targets
	local mem = self.D3bot_Mem
	mem.TgtOrNil, mem.DontAttackTgt, mem.TgtProximity = nil, nil, nil
	mem.PosTgtOrNil, mem.PosTgtProximity = nil, nil
	mem.NodeTgtOrNil = nil
	mem.NodeOrNil = nil
	mem.NextNodeOrNil = nil
	mem.RemainingNodes = {}
end

function meta:D3bot_SetTgtOrNil(target, dontAttack, proximity) -- Set the entity or player as target, bot will move to and attack. TODO: Add proximity parameter.
	local mem = self.D3bot_Mem
	mem.TgtOrNil, mem.DontAttackTgt, mem.TgtProximity = target, dontAttack, proximity
	mem.PosTgtOrNil, mem.PosTgtProximity = nil, nil
	mem.NodeTgtOrNil = nil
end

function meta:D3bot_SetPosTgtOrNil(targetPos, proximity) -- Set the position as target, bot will then move to it
	local mem = self.D3bot_Mem
	mem.TgtOrNil, mem.DontAttackTgt, mem.TgtProximity = nil, nil, nil
	mem.PosTgtOrNil, mem.PosTgtProximity = targetPos, proximity
	mem.NodeTgtOrNil = nil
end

function meta:D3bot_SetNodeTgtOrNil(targetNode) -- Set the node as target, bot will then move to it
	local mem = self.D3bot_Mem
	mem.TgtOrNil, mem.DontAttackTgt, mem.TgtProximity = nil, nil, nil
	mem.PosTgtOrNil, mem.PosTgtProximity = nil, nil
	mem.NodeTgtOrNil = targetNode
end

function meta:D3bot_InitializeOrReset()
	self.D3bot_Mem = self.D3bot_Mem or {}
	local mem = self.D3bot_Mem
	
	local considerPathLethality = math.random(1, D3bot.BotConsideringDeathCostAntichance) == 1
	
	mem.TgtOrNil = nil										-- Target entity to walk to and attack
	mem.PosTgtOrNil = nil									-- Target position to walk to
	mem.NodeTgtOrNil = nil									-- Target node
	mem.TgtNodeOrNil = nil									-- Node of the target entity or position
	mem.NodeOrNil = nil										-- The node the bot is inside of (or nearest to)
	mem.NextNodeOrNil = nil									-- Next node of the current path
	mem.RemainingNodes = {}									-- All remaining nodes of the current path
	mem.ConsidersPathLethality = considerPathLethality		-- If true, the bot will consider lethality of the paths
	mem.Angs = Angle()										-- Current angle, used to smooth out movement
	mem.AngsOffshoot = Angle()								-- Offshoot angle, to make bots movement more random
	
	mem.DontAttackTgt = nil									-- 
	mem.TgtProximity = nil									-- 
	mem.PosTgtProximity = nil								-- 
	mem.NextCheckStuck = nil								-- 
	mem.MajorStuckCounter = nil								-- 
end

function meta:D3bot_Deinitialize()
	self.D3bot_Mem = nil
end

function meta:D3bot_UpdateAngsOffshoot(angOffshoot)
	local mem = self.D3bot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	if (nodeOrNil and nodeOrNil.Params.Aim == "Straight") or (nextNodeOrNil and nextNodeOrNil.Params.AimTo == "Straight") then
		mem.AngsOffshoot = Angle()
		return
	end
	mem.AngsOffshoot = Angle(math.random(-angOffshoot, angOffshoot), math.random(-angOffshoot, angOffshoot), 0)
end

function meta:D3bot_SetPath(path, noReset)
	if not noReset then self:D3bot_ResetTgt() end
	local mem = self.D3bot_Mem
	if mem.NextNodeOrNil and mem.NextNodeOrNil == path[1] then table.insert(path, 1, mem.NodeOrNil) end -- Preserve current node if the path starts with the next node
	mem.NodeOrNil = table.remove(path, 1)
	mem.NextNodeOrNil = table.remove(path, 1)
	mem.RemainingNodes = path
end

function meta:D3bot_UpdatePath(pathCostFunction, heuristicCostFunction)
	local mem = self.D3bot_Mem
	if not IsValid(mem.TgtOrNil) and not mem.PosTgtOrNil and not mem.NodeTgtOrNil then return end
	local mapNavMesh = D3bot.MapNavMesh
	local node = mapNavMesh:GetNearestNodeOrNil(self:GetPos())
	mem.TgtNodeOrNil = mem.NodeTgtOrNil or mapNavMesh:GetNearestNodeOrNil(mem.TgtOrNil and mem.TgtOrNil:GetPos() or mem.PosTgtOrNil)
	if not node or not mem.TgtNodeOrNil then return end
	local abilities = {Walk = true}
	if self:GetActiveWeapon() then
		if self:GetActiveWeapon().PounceVelocity then abilities.Pounce = true end
		if self:GetActiveWeapon().GetClimbing then abilities.Climb = true end
	end
	local path = D3bot.GetBestMeshPathOrNil(node, mem.TgtNodeOrNil, pathCostFunction, heuristicCostFunction, abilities)
	if not path then
		local handler = findHandler(self:GetZombieClass(), self:Team())
		if handler and handler.RerollTarget then handler.RerollTarget(self) end
		return
	end
	self:D3bot_SetPath(path, true)
end

function meta:D3bot_UpdatePathProgress()
	local mem = self.D3bot_Mem
	while mem.NextNodeOrNil do
		if mem.NextNodeOrNil:GetContains(self:GetPos(), 100) then
			mem.NodeOrNil = mem.NextNodeOrNil
			mem.NextNodeOrNil = table.remove(mem.RemainingNodes, 1)
		else
			break
		end
	end
end

-- Add to last positions list. Used to check bots being stuck, or to determine the current situation (runners, spawnkillers, caders)
function meta:D3bot_StorePos()
	self.D3bot_PosList = self.D3bot_PosList or {}
	local posList = self.D3bot_PosList
	table.insert(posList, 1, self:GetPos())
	while #posList > 30 do
		table.remove(posList)
	end
end

function meta:D3bot_CheckStuck()
	local mem = self.D3bot_Mem
	if mem.NextCheckStuck and mem.NextCheckStuck < CurTime() or not mem.NextCheckStuck then
		mem.NextCheckStuck = CurTime() + 1
	else
		return
	end
	
	local posList = self.D3bot_PosList
	if not posList then return end
	
	local pos_1, pos_2, pos_10 = posList[1], posList[2], posList[10]
	
	local minorStuck = pos_1 and pos_2 and pos_1:Distance(pos_2) < 1		-- Stuck on ladder
	local preMajorStuck = pos_1 and pos_10 and pos_1:Distance(pos_10) < 300	-- Running circles, some obstacles in the way, ...
	local majorStuck
	
	if preMajorStuck and (not self.D3bot_LastDamage or self.D3bot_LastDamage < CurTime() - 5) then
		mem.MajorStuckCounter = mem.MajorStuckCounter and mem.MajorStuckCounter + 1 or 1
		if mem.MajorStuckCounter > 15 then
			majorStuck, mem.MajorStuckCounter = true, nil
		end
	else
		mem.MajorStuckCounter = nil
	end
	
	return minorStuck, majorStuck
end