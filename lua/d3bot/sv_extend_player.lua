---@class GPlayer
---@field public D3bot_LastDamage number? -- The last time (CurTime()) the bot has caused damage.
local meta = FindMetaTable("Player")

---Get attack position for the player entity.
---Works with platform physics.
---@param fraction number? Fraction where to attack, 0: feet, 1: head. Defaults to 0.75.
---@param target GPlayer? The target player.
---@return GVector? attackPos
function meta:D3bot_GetAttackPosOrNil(fraction, target)
	local mem = self.D3bot_Mem
	local tgt = target or mem.TgtOrNil
	if not tgt or not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
end

---Linear extrapolated attack position for the player entity in the future.
---@param fraction number? Fraction where to attack, 0: feet, 1: head. Defaults to 0.75.
---@param t number Prediction time in seconds.
---@return GVector? attackPos
function meta:D3bot_GetAttackPosOrNilFuture(fraction, t)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not tgt or not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + tgt:GetVelocity()*t or tgt:WorldSpaceCenter()
end

---Linear extrapolated attack position for the player entity in the future.
---Works with platform physics.
---@param fraction number? Fraction where to attack, 0: feet, 1: head. Defaults to 0.75.
---@param t number Prediction time in seconds.
---@return GVector? attackPos
function meta:D3bot_GetAttackPosOrNilFuturePlatforms(fraction, t)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not tgt or not IsValid(tgt) then return end
	local phys = tgt:GetPhysicsObject()
	if not tgt or not IsValid(phys) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + phys:GetVelocity()*t or tgt:WorldSpaceCenter()
end

function meta:D3bot_IsLookingAt(targetPos, conditionCos)
	return self:GetAimVector():Dot((targetPos - self:EyePos()):GetNormalized()) > (conditionCos or 0.95)
end

function meta:D3bot_CanPounceToPos(pos)
	if not pos then return end

	---@type GWeapon|table
	local weapon = self:GetActiveWeapon()

	local initVel
	if weapon then
		initVel = (1 - 0.5 * (self:GetLegDamage() / GAMEMODE.MaxLegDamage)) * (weapon.PounceVelocity or 400) -- good for crabs
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
				local tr = util.TraceEntity({start = point, endpos = lastPoint, mask = CONTENTS_SOLID + CONTENTS_GRATE + CONTENTS_MOVEABLE + CONTENTS_PLAYERCLIP}, self)
				if tr.Hit and pos:DistToSqr(tr.HitPos) > 16*16 then
					-- We consider this path invalid, since the bot would hit something and end up further away from the target than about a normal hull box half width.
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

function meta:D3bot_CanSeeTargetCached(fraction, target)
	local mem = self.D3bot_Mem
	if not mem then return end
	if not mem.CanSeeTargetCache or mem.CanSeeTargetCache.ValidUntil < CurTime() then
		mem.CanSeeTargetCache = {}
		mem.CanSeeTargetCache.ValidUntil = CurTime() + 0.9 + math.random() * 0.2 -- Invalidate after a second (With some jitter)
		mem.CanSeeTargetCache.Result = self:D3bot_CanSeeTarget(fraction, target)
	end
	return mem.CanSeeTargetCache.Result
end

function meta:D3bot_CanSeeTarget(fraction, target)
	local attackPos = self:D3bot_GetAttackPosOrNil(fraction, target)
	if not attackPos then return false end
	local mem = self.D3bot_Mem
	if mem and mem.TgtNodeOrNil and mem.NodeOrNil ~= mem.TgtNodeOrNil and mem.TgtNodeOrNil.Params.See == "Disabled" then return false end
	local tr = D3bot.BotSeeTr
	tr.start = self:EyePos()
	tr.endpos = attackPos
	tr.filter = player.GetAll()
	return attackPos and not util.TraceHull(tr).Hit
end

---Slowly (lerpFactor) rotates the bot (mem.Angs) towards the given angle.
---@param angle GAngle -- Destination angle.
---@param lerpFactor number -- Ratio of progress through for every iteration.
function meta:D3bot_AngsRotateTo(angle, lerpFactor)
	local mem = self.D3bot_Mem
	mem.Angs = LerpAngle(lerpFactor, mem.Angs, angle)
end

---Returns the current offshoot angle scaled by a factor.
---@param offshootFactor number -- Randomness factor between 0: No randomness and 1: 100% mem.AngsOffshoot. Defaults to 100%.
---@return GAngle offshootAngle
function meta:D3bot_GetOffshoot(offshootFactor)
	local mem = self.D3bot_Mem

	-- Small optimization. As it's costly to generate angle objects.
	if (offshootFactor or 1) == 1 then return mem.AngsOffshoot end
	if (offshootFactor or 1) == 0 then return angle_zero end

	return mem.AngsOffshoot * (offshootFactor or 1)
end

--[[timer.Create("Debug", 0.1, 0, function ()
	for _, player in ipairs(player.GetAll()) do
		if not player:IsBot() then
			player:D3bot_FindBarricadeEntity(1)
		end
	end
end)]]

---Finds a (nailed) barricade entity nearby.
---This randomly traces/samples from the player's shoot position and looks for nailed barricade entities.
---@param samples integer -- Maximum number of traces.
---@return GEntity? foundBarricadeEntity -- A random nearby barricade entity. Or nil if there was nothing found.
---@return GVector? foundBarricadePos -- The trace position of that nearby entity. Or nil if there was nothing found.
function meta:D3bot_FindBarricadeEntity(samples)
	local traceData = {
		filter = self,
		mask = MASK_SOLID,
		collisiongroup = COLLISION_GROUP_DEBRIS_TRIGGER,
		ignoreworld = true,
	}

	-- Get values from the players weapon to use for the trace.
	---@type GWeapon|table
	local weapon = self:GetActiveWeapon() or {}
	traceData.start = self:GetShootPos()
	local dir = self:GetAimVector()
	local reach = weapon.MeleeReach or 30

	for _ = 1, samples do
		traceData.endpos = traceData.start + (dir + VectorRand(-1, 1)):GetNormalized() * reach

		local tr = util.TraceLine(traceData)
		---@type GEntity
		local trEntity = tr.Entity
		  if tr.Hit and trEntity and trEntity:IsValid() and trEntity:D3bot_IsBarricade() then
			--ClDebugOverlay.Line(GetPlayerByName("D3"), traceData.start, traceData.endpos, 10, Color(255, 0, 0), true)
			return trEntity, tr.HitPos
		end
	end

	return nil, nil
end

function meta:D3bot_RerollClass(classes)
	if not GAMEMODE:GetWaveActive() then return end
	--if self:GetZombieClassTable().Name == "Zombie Torso" then return end -- ???
	if GAMEMODE.ZombieEscape or GAMEMODE.PantsMode or GAMEMODE:IsClassicMode() or GAMEMODE:IsBabyMode() then return end
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
	---@class D3bot_Mem
	---@field public TgtOrNil GEntity? -- The target entity if not nil.
	---@field public PosTgtOrNil GVector? -- The target position if not nil.
	---@field public NodeTgtOrNil D3NavmeshNode|GCNavArea? -- The target node if not nil. Don't confuse this with TgtNodeOrNil.
	---@field public TgtNodeOrNil D3NavmeshNode|GCNavArea? -- The node where the current target is located on. Don't confuse this with NodeTgtOrNil.
	---@field public NodeOrNil D3NavmeshNode|GCNavArea? -- The node the bot is in right now.
	---@field public NextNodeOrNil D3NavmeshNode|GCNavArea? -- The next node of the path, or nil.
	---@field public RemainingNodes D3NavmeshNode[]|GCNavArea[] -- A list of the remaining nodes in the path (excluding the current and next node).
	---@field public ConsidersPathLethality boolean -- If true, the bot will consider lethality metadata when generating paths.
	---@field public Angs GAngle -- Current angle, used to smooth out movement.
	---@field public AngsOffshoot GAngle -- Offshoot angle, to make bots movement more random.
	---@field public DontAttackTgt boolean -- If set to true, the bot will not attack the given target, but only walk towards it.
	---@field public NextPounce number? -- Point in time when to start the next pounce. Based on CurTime().
	---@field public nextUpdateSurroundingPlayers number? -- Point in time when to check the surrounding for other players to attack. Based on CurTime().
	---@field public PounceActive number? -- If non nil, the bot will pounce. Internally this contains a CurTime() timestamp.
	---@field public nextCheckTarget number? -- Point in time when to check the current target for validity. Based on CurTime().
	---@field public nextUpdateOffshoot number? -- Point in time when to recalculate the angle offshoot. Based on CurTime().
	---@field public nextUpdatePath number? -- Point in time when to recalculate the path to the current target. Based on CurTime().
	---@field public pounceFlightTime number? -- Estimated point in time when the pounce trajectory hits something. Based on CurTime().
	---@field public pouncingStartTime number? -- Point in time when the bot starts to pounce. This is after weapon.PounceStartDelay has passed. Based on CurTime().
	---@field public pouncing boolean? -- False (or nil) when the bot isn't pouncing.
	---@field public pouncingTimer number? -- Point in time when to check pounce process. TODO: This seems to be obsolete
	---@field public AimHeightFactor number? -- Factor of where to aim (From 0: Feet to 1: Head).
	---@field public WasPressingAttack boolean? -- If neither nil nor false, the bot has pressed primary attack in the last frame.
	---@field public LookTarget GPlayer? -- The player to look at. This is used in survivor bots.
	---@field public IsCrab boolean? -- True when this bot is a (head?)crab.
	---@field public TgtProximity number?
	---@field public PosTgtProximity number?
	---@field public NextCheckStuck number?
	---@field public MajorStuckCounter integer?
	---@field public BarricadeAttackEntity GEntity? -- A nearby attackable barricade entity. If non nil, the bot tries to attack it if close enough.
	---@field public BarricadeAttackPos GVector? -- The position of an attackable barricade entity. If non nil, the bot tries to attack it if close enough.
	---@field public AntiStuckCounter number?
	---@field public AntiStuckTime number?
	---@field public AttackTgtOrNil GPlayer? -- Specific to survivor bots: The target player to attack.
	---@field public MaxShootingDistance number? -- Specific to survivor bots: Maximum shooting distance.
	---@field public JumpHeight number -- The possible (non crouch) jump height of this bot. This is achieved just by jumping.
	---@field public JumpCrouchHeight number -- The possible jump-crouch height of this bot. This is achieved by jumping and then crouching while being in the air.
	---@field public CrouchJumpHeight number -- The possible crouch-jump height of this bot. This is achieved by crouching and then instantly jumping.
	---@field public Height number -- The cached "standing" height of the bot.
	---@field public CrouchHeight number -- The cached crouching height of the bot.
	---@field public CanSeeTargetCache table?
	---@field public BlockMovementUntil number? -- Blocks bot handlers from issuing any CUserCmd action until this point in time (CurTime()) has passed. Used by ladder handling logic (func_useableladder).
	---@field public BlockedOnNode D3NavmeshNode? -- Blocks bot handlers from issuing any CUserCmd action until they leave the specified node. Used by ladder handling logic (func_useableladder).
	---@field public IsOnLadder boolean -- When true, we are on a path that is defined as "ladder" according to the navmesh. This is used to make the bot issue special commands to leave the ladder when necessary.
	self.D3bot_Mem = self.D3bot_Mem or {}
	local mem = self.D3bot_Mem

	local considerPathLethality = math.random(1, D3bot.BotConsideringDeathCostAntichance) == 1

	mem.TgtOrNil = nil										-- Target entity to walk to and attack.
	mem.PosTgtOrNil = nil									-- Target position to walk to.
	mem.NodeTgtOrNil = nil									-- Target node.
	mem.TgtNodeOrNil = nil									-- Node of the target entity or position.
	mem.NodeOrNil = nil										-- The node the bot is inside of, or nearest to.
	mem.NextNodeOrNil = nil									-- Next node of the current path.
	mem.RemainingNodes = {}									-- All remaining nodes of the current path.
	mem.ConsidersPathLethality = considerPathLethality		-- If true, the bot will consider lethality of the paths.
	mem.Angs = angle_zero									-- Current angle, used to smooth out movement.
	mem.AngsOffshoot = angle_zero							-- Offshoot angle, to make bots movement more random.
	mem.CanSeeTargetCache = nil								-- Cached result of visibility trace to current target.

	mem.DontAttackTgt = nil									-- 
	mem.TgtProximity = nil									-- 
	mem.PosTgtProximity = nil								-- 
	mem.NextCheckStuck = nil								-- 
	mem.MajorStuckCounter = nil								-- 

	mem.IsCrab = false

	mem.JumpHeight = 30
	mem.JumpCrouchHeight = 68
	mem.CrouchJumpHeight = 70

	mem.IsOnLadder = false

	timer.Simple(0, function()
		if not IsValid(self) then return end -- also make sure bot still exists

		-- Find Handler and check if bot is crab tick after spawn, otherwise it'll fail.

		---@type GWeapon
		local weapon = self:GetActiveWeapon()
		mem.IsCrab = (weapon.HitRecovery or weapon.SpitWindUp) and true or false

		-- Calculate hull heights.

		-- TODO: We could query the hulls and the jump power directly from the player entity instead of the zombie class table
		local myClass = self:GetZombieClassTable()
		mem.Height = (myClass.Hull and myClass.Hull[2].z or 72) * self:GetModelScale()
		mem.CrouchHeight = (myClass.HullDuck and myClass.HullDuck[2].z or 36) * self:GetModelScale()

		-- Calculate jump heights.

		-- Gravitational acceleration in source units/s².
		local g = physenv.GetGravity().z * (self:GetGravity() ~= 0 and self:GetGravity() or 1)

		mem.JumpHeight = D3bot.CalculateJumpHeight(myClass.JumpPower or DEFAULT_JUMP_POWER, g, false)
		mem.JumpCrouchHeight = D3bot.CalculateJumpHeight(myClass.JumpPower or DEFAULT_JUMP_POWER, g, false) + (mem.Height - mem.CrouchHeight)
		mem.CrouchJumpHeight = D3bot.CalculateJumpHeight(myClass.JumpPower or DEFAULT_JUMP_POWER, g, true) + (mem.Height - mem.CrouchHeight)
	end)
end

function meta:D3bot_Deinitialize()
	self.D3bot_Mem = nil
end

function meta:D3bot_UpdateAngsOffshoot(angOffshoot)
	local mem = self.D3bot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	if (nodeOrNil and nodeOrNil.Params.Aim == "Straight") or (nextNodeOrNil and nextNodeOrNil.Params.AimTo == "Straight")
		or (nextNodeOrNil and nodeOrNil and nextNodeOrNil.LinkByLinkedNode[nodeOrNil].Params.CrabPouncing == "Needed") then
		mem.AngsOffshoot = angle_zero
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
	local abilities = {Walk = true, Jump = mem.CrouchJumpHeight, Height = mem.CrouchHeight, Crab = mem.IsCrab}
	---@type GWeapon|table
	local weapon = self:GetActiveWeapon()
	if weapon then
		if weapon.PounceVelocity then abilities.Pounce = true end
		if weapon.GetClimbing then abilities.Climb = true end
	end
	local path = D3bot.GetBestMeshPathOrNil(node, mem.TgtNodeOrNil, pathCostFunction, heuristicCostFunction, abilities)
	if not path then
		local handler = FindHandler(self:GetZombieClass(), self:Team())
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

---Returns if and how a bot may be stuck.
---This depends on movement and time data.
---@return boolean minorStuck
---@return boolean majorStuck
function meta:D3bot_CheckStuck()
	local mem = self.D3bot_Mem
	if mem.NextCheckStuck and mem.NextCheckStuck < CurTime() or not mem.NextCheckStuck then
		mem.NextCheckStuck = CurTime() + 0.9 + math.random() * 0.2
	else
		return false, false
	end
	
	local posList = self.D3bot_PosList
	if not posList then return false, false end
	
	local pos_1, pos_2, pos_10 = posList[1], posList[2], posList[10]
	
	local minorStuck = pos_1 and pos_2 and pos_1:DistToSqr(pos_2) < 1*1				-- Stuck on ladder
	local preMajorStuck = pos_1 and pos_10 and pos_1:DistToSqr(pos_10) < 300*300	-- Running circles, some obstacles in the way, ...
	local majorStuck = false

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

if not D3bot.UsingSourceNav then return end

function meta:D3bot_CanSeeTarget( fraction, target )
	local attackPos = self:D3bot_GetAttackPosOrNil( fraction, target )
	if not attackPos then return false end
	local mem = self.D3bot_Mem
	if mem and mem.TgtNodeOrNil and mem.NodeOrNil ~= mem.TgtNodeOrNil and mem.TgtNodeOrNil:GetMetaData().Params.See == "Disabled" then return false end
	local tr = D3bot.BotSeeTr
	tr.start = self:EyePos()
	tr.endpos = attackPos
	tr.filter = player.GetAll()
	return attackPos and not util.TraceHull( tr ).Hit
end

function meta:D3bot_UpdateAngsOffshoot( angOffshoot )
	local mem = self.D3bot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	if ( nodeOrNil and nodeOrNil:GetMetaData().Params.Aim == "Straight" ) or ( nextNodeOrNil and nextNodeOrNil:GetMetaData().Params.AimTo == "Straight" )
		or ( nextNodeOrNil and nodeOrNil and nextNodeOrNil:SharesLink(nodeOrNil):GetMetaData().Params.CrabPouncing == "Needed" ) then
		mem.AngsOffshoot = angle_zero
		return
	end
	mem.AngsOffshoot = Angle(math.random( -angOffshoot, angOffshoot ), math.random( -angOffshoot, angOffshoot ), 0 )
end

function meta:D3bot_UpdatePath( pathCostFunction, heuristicCostFunction )
	local mem = self.D3bot_Mem
	if not IsValid( mem.TgtOrNil ) and not mem.PosTgtOrNil and not mem.NodeTgtOrNil then return end

	local area = navmesh.GetNearestNavArea( self:GetPos() )

	mem.TgtNodeOrNil = mem.NodeTgtOrNil or navmesh.GetNearestNavArea( mem.TgtOrNil and mem.TgtOrNil:GetPos() or mem.PosTgtOrNil )
	
	if not area or not mem.TgtNodeOrNil then return end
	local abilities = {Walk = true, Jump = mem.CrouchJumpHeight, Height = mem.CrouchHeight, Crab = mem.IsCrab}

	---@type GWeapon|table
	local weapon = self:GetActiveWeapon()
	if weapon then
		if weapon.PounceVelocity then abilities.Pounce = true end
		if weapon.GetClimbing then abilities.Climb = true end
	end
	local path = D3bot.GetBestValveMeshPathOrNil( area, mem.TgtNodeOrNil, pathCostFunction, heuristicCostFunction, abilities )
	if not path then
		local handler = FindHandler( self:GetZombieClass(), self:Team() )
		if handler and handler.RerollTarget then handler.RerollTarget( self ) end
		return
	end
	self:D3bot_SetPath( path, true )
end

function meta:D3bot_UpdatePathProgress()
	local mem = self.D3bot_Mem
	while mem.NextNodeOrNil do
		if mem.NextNodeOrNil == navmesh.GetNavArea( self:GetPos(), 100 ) then
			mem.NodeOrNil = mem.NextNodeOrNil
			mem.NextNodeOrNil = table.remove( mem.RemainingNodes, 1 )
		else
			break
		end
	end
end
