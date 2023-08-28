D3bot.Basics = {}

---Let the bot suicide or retarget, based on the node parameters of the current and next node.
---@param bot GPlayer
function D3bot.Basics.SuicideOrRetarget(bot)
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	if D3bot.UsingSourceNav then return end
		
	if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
		local wallParam = nextNodeOrNil.Params.Wall
		if wallParam == "Retarget" then
			local handler = FindHandler(bot:GetZombieClass(), bot:Team())
			if handler and handler.RerollTarget then handler.RerollTarget(bot) end
			return
		elseif wallParam == "Suicide" then
			bot:Kill()
			return
		end
	end
end

---Basic walking handler.
---@param bot GPlayer|table
---@param pos GVector -- Target position the bot should walk towards. Should be inside the current or next node.
---@param aimAngle GAngle? -- Target aim angle of the bot. If not set, the bot will aim to the walking direction.
---@param slowdown boolean? -- Set to true if the bot will slow down when it is close to its target.
---@param proximity number? -- The proxmimity where the bot starts to slow down.
---@return boolean valid -- True if the handler ran corrcetly.
---@return table actions -- Table with a set of actions.
---@return number? forwardSpeed -- The needed forwards speed for the bot.
---@return number? sideSpeed -- The needed side speed for the bot.
---@return number? upSpeed -- The needed upwards speed for the bot.
---@return GAngle aimAngle -- The resulting aim angle for the bot.
---@return boolean minorStuck -- True if the bot seems to be stuck on a ladder or similar.
---@return boolean majorStuck -- True if the bot seems to be stuck on props, or runs in circles.
---@return boolean facesHindrance -- True if the bot is walking slower than expected.
function D3bot.Basics.Walk(bot, pos, aimAngle, slowdown, proximity)
	local mem = bot.D3bot_Mem

	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil

	local offshootAngle = angle_zero
	local origin = bot:GetPos()
	local actions = {}

	-- Check if the bot needs to climb while being on a node or going towards a node. As maneuvering while climbing is different, this will change/override some movement actions.
	local shouldClimb
	if D3bot.UsingSourceNav then
		shouldClimb = (nodeOrNil and nodeOrNil:GetMetaData().Params.Climbing == "Needed") or (nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.Climbing == "Needed")
	else
		shouldClimb = (nodeOrNil and nodeOrNil.Params.Climbing == "Needed") or (nextNodeOrNil and nextNodeOrNil.Params.Climbing == "Needed")
	end

	-- Make bot aim straight when outside of current node area This should prevent falling down edges.
	local aimStraight = false
	local weapon = bot:GetActiveWeapon()
	if D3bot.UsingSourceNav then
		if nodeOrNil and not navmesh.GetNavArea(origin, 8) then aimStraight = true end
	else
		if nodeOrNil and not nodeOrNil:GetContains(origin, nil) then aimStraight = true end
	end
	if shouldClimb then
		---@type GWeapon|table
		if weapon and weapon.GetClimbing and weapon:GetClimbing() and weapon.GetClimbSurface then
			local tr = weapon:GetClimbSurface()
			if tr and tr.Hit then
				bot:D3bot_AngsRotateTo((-tr.HitNormal):Angle(), D3bot.BotAngLerpFactor)
			end
		else
			bot:D3bot_AngsRotateTo(Vector(pos.x-origin.x, pos.y-origin.y, 0):Angle(), 1)
		end
	else
		if mem.BarricadeAttackEntity and mem.BarricadeAttackPos and mem.BarricadeAttackEntity:IsValid() and mem.BarricadeAttackPos:DistToSqr(origin) < (mem.SpitOnPlayer and 100000 or 10000) then
			-- We have a barricade entity to attack, so we aim for this one.
			offshootAngle = bot:D3bot_GetOffshoot(mem.SpitOnPlayer and 0 or 1)
			aimAngle = aimAngle or (mem.BarricadeAttackPos - bot:GetShootPos()):Angle()
			bot:D3bot_AngsRotateTo(aimAngle + offshootAngle, 1)
			--ClDebugOverlay.Line(GetPlayerByName("D3"), bot:GetShootPos(), mem.BarricadeAttackPos, 1, Color(0,255,0), false)
		else
			-- Target is invalid or too far away, forget about it.
			-- We will either use the given aim angle, or calculate it based on the walk position.
			if not mem.SpitOnPlayer then
				offshootAngle = bot:D3bot_GetOffshoot(aimStraight and 0 or 1)
				aimAngle = aimAngle or (pos - origin):Angle()
				bot:D3bot_AngsRotateTo(aimAngle + offshootAngle, aimStraight and 1 or D3bot.BotAngLerpFactor)
				mem.BarricadeAttackPos, mem.BarricadeAttackEntity = nil, nil
			end
		end
	end

	local duckParam
	local duckToParam
	local jumpParam
	local jumpToParam

	if D3bot.UsingSourceNav then
		duckParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.JumpTo
	else
		duckParam = nodeOrNil and nodeOrNil.Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil.Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	end

	-- Set up movement vector, which is relative to the player's 2D forward direction.
	-- Positive x is forward, positive y is left and positive z is upwards.
	---@type GVector
	local movementVector = pos - origin
	-- Slow down bot when close to target (2D distance).
	local invProximity = math.Clamp((movementVector:Length2D() - (proximity or 10)) / 60, 0, 1)
	local speed = bot:GetMaxSpeed() * (slowdown and invProximity or 1)
	movementVector.z = 0
	movementVector:Normalize()
	movementVector:Mul(speed)
	movementVector:Rotate(Angle(0, offshootAngle.yaw - mem.Angs.yaw, 0))

	-- Antistuck when bot is possibly stuck crouching below something.
	if mem.AntiStuckTime and mem.AntiStuckTime > CurTime() then
		if not bot:Crouching() then
			mem.AntiStuckTime = nil
		else
			movementVector = -0.5 * movementVector
			actions.Jump = true
			actions.Attack = true
		end
	end

	local velocity = bot:GetVelocity():Length2D()
	local facesHindrance = velocity < 0.25 * speed
	local minorStuck, majorStuck = bot:D3bot_CheckStuck()

	if not facesHindrance then
		mem.lastNoHindrance = CurTime()
	end

	if duckParam == "Always" or duckToParam == "Always" then
		actions.Duck = true
	end

	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			-- If we should climb, jump while we're on the ground.
			if shouldClimb or jumpParam == "Always" or jumpToParam == "Always" then
				actions.Jump = true
			end

			-- If there is a JumpTo parameter with "Close" as the value, determine if we are close enough to jump.
			if jumpToParam == "Close" and nextNodeOrNil then
				local hullTop, _ = bot:GetHull() -- Assume the hull is symmetrical.
				local hullX, hullY, _ = hullTop:Unpack()
				local halfHullWidth = math.max(hullX, hullY) + 5 -- Just add a small margin to let the bot jump before it "touches" the next node's area.

				---@type GVector
				local closestDiff = origin - nextNodeOrNil:GetClosestPointOnArea(origin)
				local closestDistSqr = closestDiff:Length2DSqr()
				if closestDistSqr <= halfHullWidth*halfHullWidth then
					actions.Jump = true
				end
			end

			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					actions.Jump = true
				end
				if math.random(D3bot.BotDuckAntichance) == 1 then
					actions.Duck = true
				end
			end
		else
			actions.Duck = true
			if shouldClimb then
				-- If we are airborne and should be climbing, try to climb the surface.
				actions.Attack2 = true
				-- Calculate climbing speeds.
				---@type GWeapon|table
				local weapon = bot:GetActiveWeapon()
				if weapon and weapon.GetClimbing and weapon:GetClimbing() then
					local yaw1 = bot:GetForward():Angle().yaw
					local yaw2 = Vector(pos.x-origin.x, pos.y-origin.y, 0):Angle().yaw
					movementVector.y = math.AngleDifference(yaw2, yaw1)
					movementVector.x = (pos.z - origin.z + 20) * 10
					if (math.abs(movementVector.x) < 20 or bot:GetVelocity():Length() < 10) and math.abs(movementVector.y) > 1 then movementVector.x = 0 end
				end
			end
		end
	elseif minorStuck then
		-- Stuck on ladder
		actions.Jump = true
		actions.Duck = true
		actions.Use = true
	end

	if duckParam == "Disabled" or duckToParam == "Disabled" then
		actions.Duck = false
	end
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" or (not actions.Duck and bot:Crouching()) then
		actions.Jump = false
	end

	-- Check if bot is possibly stuck below something.
	-- This is basically when the bot is slowly or not moving on ground, and is crouching even it shouldn't.
	if bot:GetMoveType() ~= MOVETYPE_LADDER and bot:IsOnGround() and bot:Crouching() and not actions.Duck and (not bot.D3bot_LastDamage or bot.D3bot_LastDamage < CurTime() - 2) and (not mem.lastNoHindrance or mem.lastNoHindrance < CurTime() - 2) then
		mem.AntiStuckCounter = (mem.AntiStuckCounter or 0) + 1
		if mem.AntiStuckCounter > 30 then
			mem.AntiStuckCounter = nil
			mem.AntiStuckTime = CurTime() + 1
		end
	else
		mem.AntiStuckCounter = nil
	end

	if facesHindrance then
		local choice = math.random(0, 15)
		if choice >= 2 then actions.Attack = facesHindrance and not shouldClimb
		elseif choice >= 6 and (weapon.BattleCryDelay or 0) <= CurTime() then actions.Reload = true
		else if not bot:GetZombieClassTable().IsHeadcrab then actions.Attack2 = true actions.Attack = false end end
	end

	actions.Use = actions.Use or facesHindrance

	if movementVector.x > 0 then actions.MoveForward = true end
	if movementVector.x < 0 then actions.MoveBackward = true end
	if movementVector.y < 0 then actions.MoveRight = true end
	if movementVector.y > 0 then actions.MoveLeft = true end

	return true, actions, movementVector.x, -movementVector.y, nil, mem.Angs, minorStuck, majorStuck, facesHindrance
end

---Basic walk and attack handler.
---@param bot GPlayer|table
---@return boolean valid -- True if the handler ran corrcetly.
---@return table actions -- Table with a set of actions.
---@return number? forwardSpeed -- The needed forwards speed for the bot.
---@return number? sideSpeed -- The needed side speed for the bot.
---@return number? upSpeed -- The needed upwards speed for the bot.
---@return GAngle aimDirection -- The wanted aim direction for the bot.
---@return boolean minorStuck -- True if the bot seems to be stuck on a ladder or similar.
---@return boolean majorStuck -- True if the bot seems to be stuck on props, or runs in circles.
---@return boolean facesHindrance -- True if the bot is walking slower than expected.
function D3bot.Basics.WalkAttackAuto(bot)
	local mem = bot.D3bot_Mem

	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil

	local actions = {}

	-- Check if the bot needs to climb while being on a node or going towards a node.
	-- If so, ignore everything else, and use Basics.WalkAuto, which will handle everything fine.
	-- TODO: Put everything into its own basics function
	local shouldClimb
	if D3bot.UsingSourceNav then
		shouldClimb = ( nodeOrNil and nodeOrNil:GetMetaData().Params.Climbing == "Needed" ) or ( nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.Climbing == "Needed" )
	else
		shouldClimb = ( nodeOrNil and nodeOrNil.Params.Climbing == "Needed" ) or ( nextNodeOrNil and nextNodeOrNil.Params.Climbing == "Needed" )
	end

	-- Fall back to normal walking behavior if possible.
	if shouldClimb and nextNodeOrNil then
		-- Use walk handler for climing.
		-- Unless we don't have a next node, so the target is near a wall we need to climb.
		if D3bot.UsingSourceNav then
			return D3bot.Basics.Walk(bot, nextNodeOrNil:GetCenter(), nil)
		else
			return D3bot.Basics.Walk(bot, nextNodeOrNil.Pos, nil)
		end
	elseif not bot:D3bot_CanSeeTargetCached() and nextNodeOrNil then
		-- Target not visible, walk towards next node.
		if D3bot.UsingSourceNav then
			return D3bot.Basics.Walk(bot, nextNodeOrNil:GetCenter(), nil)
		else
			return D3bot.Basics.Walk(bot, nextNodeOrNil.Pos, nil)
		end
	elseif mem.TgtOrNil and mem.DontAttackTgt then
		-- There is a target entity, but the bot shouldn't attack it.
		return D3bot.Basics.Walk(bot, mem.TgtOrNil:GetPos(), nil, true, mem.TgtProximity)
	elseif mem.PosTgtOrNil then
		-- Go straight to position target, if there is one.
		return D3bot.Basics.Walk(bot, mem.PosTgtOrNil, nil, true, mem.PosTgtProximity)
	end

	---@type GWeapon|table
	local weapon = bot:GetActiveWeapon()
	local range = (weapon and weapon.MeleeReach or 90) + 50 -- Either MeleeReach + 25, or 140.

	-- We don't have a case that can be handled by the basic walk handler.
	-- So we just attack something directly.
	local facesTgt = false -- True if bot is close enough for attacks.
	local origin = bot:GetShootPos() -- Attack origin of the bot.
	local attackPos = bot:D3bot_GetAttackPosOrNilFuture(nil, math.Rand(0, D3bot.BotAimPosVelocityOffshoot)) -- Target attack position, for aiming.
	local movePos = attackPos or bot:GetPos() -- Target movement position.

	if attackPos and attackPos:DistToSqr(origin) <= math.pow(range, 2) then
		--ClDebugOverlay.Line(GetPlayerByName("D3"), bot:GetShootPos(), attackPos, 1, Color(255,255,0), false)

		-- We are within attack range.
		facesTgt = true
		if attackPos.z < bot:GetPos().z + bot:GetViewOffsetDucked().z then
			actions.Duck = true
		end
	elseif mem.BarricadeAttackEntity and mem.BarricadeAttackPos then
		-- We are not within attack range, but we have a barricade entity to attack.
		-- So we aim for this one, instead.
		if mem.BarricadeAttackEntity:IsValid() and mem.BarricadeAttackPos:DistToSqr(origin) < math.pow(range, 2) and not mem.BotShouldIgnoreCade then
			attackPos = mem.BarricadeAttackPos
			facesTgt = true
			--ClDebugOverlay.Line(GetPlayerByName("D3"), bot:GetShootPos(), attackPos, 1, Color(0,0,255), false)
		else
			-- Target is invalid or too far away, forget about it.
			mem.BarricadeAttackPos, mem.BarricadeAttackEntity = nil, nil
		end
	end

	local offshootAngle = bot:D3bot_GetOffshoot(facesTgt and D3bot.FaceTargetOffshootFactor or 1)
	if attackPos then
		bot:D3bot_AngsRotateTo((attackPos - origin):Angle() + offshootAngle, D3bot.BotAttackAngLerpFactor)
	end

	local duckParam, duckToParam, jumpParam, jumpToParam

	if D3bot.UsingSourceNav then
		duckParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil:GetMetaData().Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.JumpTo
	else
		duckParam = nodeOrNil and nodeOrNil.Params.Duck
		duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
		jumpParam = nodeOrNil and nodeOrNil.Params.Jump
		jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	end

	-- Set up movement vector, which is relative to the player's 2D forward direction.
	-- Positive x is forward, positive y is left and positive z is upwards.
	---@type GVector
	local movementVector = movePos - origin
	-- Slow down bot when close to target (2D distance).
	local invProximity = math.Clamp((movementVector:Length2D() - 10) / 60, 0.01, 1)
	local speed = bot:GetMaxSpeed() * invProximity
	movementVector.z = 0
	movementVector:Normalize()
	movementVector:Mul(speed)
	movementVector:Rotate(Angle(0, offshootAngle.yaw - mem.Angs.yaw, 0))

	-- Antistuck when bot is possibly stuck crouching below something.
	if mem.AntiStuckTime and mem.AntiStuckTime > CurTime() then
		if not bot:Crouching() then
			mem.AntiStuckTime = nil
		else
			movementVector = -0.5 * movementVector
			actions.Jump = true
			actions.Attack = true
		end
	end

	local velocity = bot:GetVelocity():Length2D()
	local facesHindrance = velocity < 0.25 * speed
	local minorStuck, majorStuck = bot:D3bot_CheckStuck()

	if not facesHindrance then
		mem.lastNoHindrance = CurTime()
	end

	if duckParam == "Always" or duckToParam == "Always" then
		actions.Duck = true
	end

	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				actions.Jump = true
			end

			-- If there is a JumpTo parameter with "Close" as the value, determine if we are close enough to jump.
			if jumpToParam == "Close" and nextNodeOrNil then
				local hullTop, _ = bot:GetHull() -- Assume the hull is symmetrical.
				local hullX, hullY, _ = hullTop:Unpack()
				local halfHullWidth = math.max(hullX, hullY) + 5 -- Just add a small margin to let the bot jump before it "touches" the next node's area.

				---@type GVector
				local closestDiff = origin - nextNodeOrNil:GetClosestPointOnArea(origin)
				local closestDistSqr = closestDiff:Length2DSqr()
				if closestDistSqr <= halfHullWidth*halfHullWidth then
					actions.Jump = true
				end
			end

			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					actions.Jump = true
				end
				if math.random(D3bot.BotDuckAntichance) == 1 then
					actions.Duck = true
				end
			end
		else
			actions.Duck = true
		end
	elseif minorStuck then
		-- Stuck on ladder
		actions.Jump = true
		actions.Duck = true
		actions.Use = true
	end

	if duckParam == "Disabled" or duckToParam == "Disabled" then
		actions.Duck = false
	end
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" or (not actions.Duck and bot:Crouching()) then
		actions.Jump = false
	end

	-- Check if bot is possibly stuck below something.
	-- This is basically when the bot is slowly or not moving on ground, and is crouching even it shouldn't.
	if bot:GetMoveType() ~= MOVETYPE_LADDER and bot:IsOnGround() and bot:Crouching() and not actions.Duck and (not bot.D3bot_LastDamage or bot.D3bot_LastDamage < CurTime() - 2) and (not mem.lastNoHindrance or mem.lastNoHindrance < CurTime() - 2) then
		mem.AntiStuckCounter = (mem.AntiStuckCounter or 0) + 1
		if mem.AntiStuckCounter > 30 then
			mem.AntiStuckCounter = nil
			mem.AntiStuckTime = CurTime() + 1
		end
	else
		mem.AntiStuckCounter = nil
	end

	if facesHindrance then
		local choice = math.random(0, 3)
		if choice == 1 then actions.Attack = true
		elseif choice == 3 then actions.Reload = true
		else actions.Attack2 = true end
	end

	actions.Attack = facesTgt and not shouldClimb
	actions.Use = actions.Use or facesHindrance

	if movementVector.x > 0 then actions.MoveForward = true end
	if movementVector.x < 0 then actions.MoveBackward = true end
	if movementVector.y < 0 then actions.MoveRight = true end
	if movementVector.y > 0 then actions.MoveLeft = true end

	return true, actions, movementVector.x, -movementVector.y, nil, mem.Angs, minorStuck, majorStuck, facesHindrance
end

---Pouncing handler.
---@param bot GPlayer|table
---@return boolean valid -- True if the handler ran corrcetly.
---@return table actions -- Table with a set of actions.
---@return number? speed -- The needed forwards speed for the bot.
---@return number? sideSpeed -- The needed side speed for the bot.
---@return number? upSpeed -- The needed upwards speed for the bot.
---@return GAngle aimDirection -- The wanted aim direction for the bot.
---@return boolean minorStuck -- True if the bot seems to be stuck on a ladder or similar.
---@return boolean majorStuck -- True if the bot seems to be stuck on props, or runs in circles.
---@return boolean facesHindrance -- True if the bot is walking slower than expected.
function D3bot.Basics.PounceAuto(bot)
	local mem = bot.D3bot_Mem

	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil

	if not bot:IsOnGround() or bot:GetMoveType() == MOVETYPE_LADDER then return false, {}, nil, nil, nil, angle_zero, false, false, false end

	---@type GWeapon|table
	local weapon = bot:GetActiveWeapon()
	if not weapon and not weapon.PounceVelocity then return false, {}, nil, nil, nil, angle_zero, false, false, false end

	-- Fill table with possible pounce target positions, ordered with increasing priority.

	local tempPos = bot:GetPos() -- Current position of the bot or a node.
	local tempDist = 0           -- Approximates the walking distance with the help of tempPos.
	local pounceTargetPositions = {}
	if nextNodeOrNil and D3bot.UsingSourceNav then
		tempDist = tempDist + tempPos:Distance(nextNodeOrNil:GetCenter())
		tempPos = nextNodeOrNil:GetCenter()
		table.insert(pounceTargetPositions, {
			Pos = nextNodeOrNil:GetCenter() + Vector(0, 0, 1),
			Dist = tempDist,
			TimeFactor = 1.1,
			ForcePounce = (nextNodeOrNil:SharesLink(nodeOrNil) and nextNodeOrNil:SharesLink(nodeOrNil):GetMetaData().Params.Pouncing == "Needed")
		})
	elseif nextNodeOrNil then
		tempDist = tempDist + tempPos:Distance(nextNodeOrNil.Pos)
		tempPos = nextNodeOrNil.Pos
		table.insert(pounceTargetPositions, {
			Pos = nextNodeOrNil.Pos + Vector(0, 0, 1),
			Dist = tempDist,
			TimeFactor = 1.1,
			ForcePounce = (nextNodeOrNil.LinkByLinkedNode[nodeOrNil] and nextNodeOrNil.LinkByLinkedNode[nodeOrNil].Params.Pouncing == "Needed")
		})
	end
	if D3bot.UsingSourceNav then
		for i, v in ipairs(mem.RemainingNodes) do -- TODO: Check if it behaves as expected
			tempDist = tempDist + tempPos:Distance(v:GetCenter())
			tempPos = v:GetCenter()
			table.insert(pounceTargetPositions, { Pos = v:GetCenter() + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.1 })
			if i >= 2 then break end
		end
	else
		for i, v in ipairs(mem.RemainingNodes) do -- TODO: Check if it behaves as expected
			tempDist = tempDist + tempPos:Distance(v.Pos)
			tempPos = v.Pos
			table.insert(pounceTargetPositions, { Pos = v.Pos + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.1 })
			if i >= 2 then break end
		end
	end
	local tempAttackPosOrNil = bot:D3bot_GetAttackPosOrNilFuturePlatforms(0, mem.pounceFlightTime or 0)
	if tempAttackPosOrNil then
		tempDist = tempDist + bot:GetPos():Distance(tempAttackPosOrNil)
		table.insert(pounceTargetPositions, { Pos = tempAttackPosOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 0.8, HeightDiff = 100 }) -- TODO: Global bot 'IQ' level influences TimeFactor, the lower the more likely they will cut off the players path
	elseif mem.PosTgtOrNil then
		tempDist = tempDist + bot:GetPos():Distance(mem.PosTgtOrNil)
		table.insert(pounceTargetPositions, { Pos = mem.PosTgtOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 0.8, HeightDiff = 100 })
	end

	-- Find best trajectory
	local trajectory
	for _, pounceTargetPos in ipairs(table.Reverse(pounceTargetPositions)) do
		local trajectories = bot:D3bot_CanPounceToPos(pounceTargetPos.Pos)
		local timeToTarget = pounceTargetPos.Dist / bot:GetMaxSpeed()
		if trajectories and (pounceTargetPos.ForcePounce or (pounceTargetPos.HeightDiff and pounceTargetPos.Pos.z - bot:GetPos().z > pounceTargetPos.HeightDiff) or timeToTarget > (trajectories[1].t1 + weapon.PounceStartDelay) * pounceTargetPos.TimeFactor) then
			trajectory = trajectories[1]
			break
		end
	end

	local actions = {}

	if (trajectory and CurTime() >= weapon:GetNextPrimaryFire() and CurTime() >= weapon:GetNextSecondaryFire() and CurTime() >= weapon.NextAllowPounce) or mem.pouncing then
		if trajectory then
			mem.Angs = Angle(-math.deg(trajectory.pitch), math.deg(trajectory.yaw), 0)
			mem.pounceFlightTime = math.Clamp(trajectory.t1 + (mem.pouncingStartTime or CurTime()) - CurTime(), 0, 1) -- Store flight time, and use it to iteratively get close to the correct intersection point.
		end
		if not mem.pouncing then
			-- Started pouncing
			actions.Attack2 = true
			mem.pouncingTimer = CurTime() + 0.9 + math.random() * 0.2
			mem.pouncingStartTime = CurTime() + weapon.PounceStartDelay
			mem.pouncing = true
		elseif mem.pouncingTimer and mem.pouncingTimer < CurTime() and (CurTime() - mem.pouncingTimer > 5 or bot:WaterLevel() >= 2 or bot:IsOnGround()) then
			-- Ended pouncing
			mem.pouncing = false
			mem.pounceFlightTime = nil
			bot:D3bot_UpdatePathProgress()
		end

		return true, actions, 0, nil, nil, mem.Angs, false, false, false
	end

	return false, {}, nil, nil, nil, angle_zero, false, false, false
end

---Basic aim and shoot handler for survivor bots.
---(Or anything that can hold a gun)
---@param bot GPlayer|table
---@param target GEntity
---@param maxDistance number
---@return boolean valid -- True if the handler ran corrcetly.
---@return table actions -- Table with a set of actions.
---@return number? speed -- The needed forwards speed for the bot.
---@return number? sideSpeed -- The needed side speed for the bot.
---@return number? upSpeed -- The needed upwards speed for the bot.
---@return GAngle aimDirection -- The wanted aim direction for the bot.
---@return boolean minorStuck -- True if the bot seems to be stuck on a ladder or similar.
---@return boolean majorStuck -- True if the bot seems to be stuck on props, or runs in circles.
---@return boolean facesHindrance -- True if the bot is walking slower than expected.
function D3bot.Basics.AimAndShoot(bot, target, maxDistance)
	local mem = bot.D3bot_Mem

	local actions = {}
	local reloading

	if not IsValid(target) then return false, {}, nil, nil, nil, angle_zero, false, false, false end

	---@type GWeapon|table
	local weapon = bot:GetActiveWeapon()
	if not IsValid(weapon) then return false, {}, nil, nil, nil, angle_zero, false, false, false end
	if weapon:Clip1() == 0 then reloading = true end
	if (weapon.GetNextReload and weapon:GetNextReload() or 0) > CurTime() - 0.5 then -- Subtract half a second, so it will re-trigger reloading if possible
		reloading = true
	end
	actions.Reload = reloading and math.random(5) == 1

	local origin = bot:GetShootPos()
	local targetPos = LerpVector(mem.AimHeightFactor or 1, target:GetPos(), target:EyePos())

	if maxDistance and origin:DistToSqr(targetPos) > math.pow(maxDistance, 2) then return false, {}, nil, nil, nil, angle_zero, false, false, false end

	-- TODO: Use fewer traces, cache result for a few frames
	local tr = util.TraceLine({
		start = origin,
		endpos = targetPos,
		filter = player.GetAll(),
		mask = MASK_SHOT_HULL
	})
	local canShootTarget = not tr.Hit

	if not canShootTarget then mem.AimHeightFactor = math.Rand(0.5, 1) end

	actions.Attack = not reloading and bot:D3bot_IsLookingAt(targetPos, 0.8) and canShootTarget and not mem.WasPressingAttack
	mem.WasPressingAttack = actions.Attack

	if targetPos and canShootTarget then
		bot:D3bot_AngsRotateTo((targetPos - origin):Angle(), D3bot.BotAimAngLerpFactor)
	end

	return true, actions, 0, nil, nil, mem.Angs, false, false, false
end

---Basic aim and shoot handler for survivor bots.
---(Or anything that can hold a gun)
---@param bot GPlayer|table
---@return boolean valid -- True if the handler ran corrcetly.
---@return table actions -- Table with a set of actions.
---@return number? speed -- The needed forwards speed for the bot.
---@return number? sideSpeed -- The needed side speed for the bot.
---@return number? upSpeed -- The needed upwards speed for the bot.
---@return GAngle aimDirection -- The wanted aim direction for the bot.
---@return boolean minorStuck -- True if the bot seems to be stuck on a ladder or similar.
---@return boolean majorStuck -- True if the bot seems to be stuck on props, or runs in circles.
---@return boolean facesHindrance -- True if the bot is walking slower than expected.
function D3bot.Basics.LookAround(bot)
	local mem = bot.D3bot_Mem

	if math.random(200) == 1 then mem.LookTarget = table.Random(player.GetAll()) end

	if not IsValid(mem.LookTarget) then return false, {}, nil, nil, nil, angle_zero, false, false, false end

	local origin = bot:EyePos()

	bot:D3bot_AngsRotateTo((mem.LookTarget:EyePos()- origin):Angle(), D3bot.BotAngLerpFactor * 0.3)

	return true, {}, 0, nil, nil, mem.Angs, false, false, false
end
