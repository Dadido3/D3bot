D3bot.Handlers.Undead_Crow = D3bot.Handlers.Undead_Crow or {}
local HANDLER = D3bot.Handlers.Undead_Crow

HANDLER.angOffshoot = 10

HANDLER.Fallback = false
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_UNDEAD and zombieClassName == "Crow"
end

---Updates the bot move data every frame.
---@param bot GPlayer|table
---@param cmd GCUserCmd
function HANDLER.UpdateBotCmdFunction(bot, cmd)
	if D3bot.DisableBotCrows then return end

	cmd:ClearButtons()
	cmd:ClearMovement()

	-- Fix knocked down bots from sliding around. (Workaround for the NoxiousNet codebase, as ply:Freeze() got removed from status_knockdown, status_revive, ...)
	if bot.KnockedDown and IsValid(bot.KnockedDown) or bot.Revive and IsValid(bot.Revive) then
		return
	end

	if not bot:Alive() and math.random(1, 50) == 1 then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end

	bot:D3bot_UpdatePathProgress()
	local mem = bot.D3bot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil

	local result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle, minorStuck, majorStuck, facesHindrance

	forwardSpeed = 0.0
	if nextNodeOrNil and D3bot.UsingSourceNav then
		local pos = nextNodeOrNil:GetCenter() + Vector(0, 0, 64)
		result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle, minorStuck, majorStuck, facesHindrance = D3bot.Basics.Walk(bot, pos, nil)
	elseif nextNodeOrNil then
		local pos = nextNodeOrNil.Pos + Vector(0, 0, 64)
		result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle, minorStuck, majorStuck, facesHindrance = D3bot.Basics.Walk(bot, pos, nil)
	end

	local buttons = 0
	if actions then
		buttons = bit.bor(IN_FORWARD, actions.Attack and IN_ATTACK or 0, actions.Attack2 and IN_ATTACK2 or 0, actions.Duck and IN_DUCK or 0, actions.Jump and IN_JUMP or 0, actions.Use and IN_USE or 0)
	end

	buttons = bit.band(buttons, bit.bnot(IN_USE)) -- Prevent crow bots from pressing USE
	buttons = bit.bor(buttons or 0, (math.random(1, 2) == 1) and result and IN_JUMP or 0)

	if aimAngle then bot:SetEyeAngles(aimAngle) cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	cmd:SetButtons(buttons)
end

---Called every frame.
---@param bot GPlayer
function HANDLER.ThinkFunction(bot)
	if D3bot.DisableBotCrows then return end

	local mem = bot.D3bot_Mem

	if mem.nextCheckTarget and mem.nextCheckTarget < CurTime() or not mem.nextCheckTarget then
		mem.nextCheckTarget = CurTime() + 0.9 + math.random() * 0.2
		if not HANDLER.CanBeTgt(bot, mem.TgtOrNil) or math.random(60) == 1 then
			HANDLER.RerollTarget(bot)
		end
	end

	if mem.nextUpdateOffshoot and mem.nextUpdateOffshoot < CurTime() or not mem.nextUpdateOffshoot then
		mem.nextUpdateOffshoot = CurTime() + 0.4 + math.random() * 0.2
		bot:D3bot_UpdateAngsOffshoot(HANDLER.angOffshoot)
	end

	if mem.nextUpdatePath and mem.nextUpdatePath < CurTime() or not mem.nextUpdatePath then
		mem.nextUpdatePath = CurTime() + 0.9 + math.random() * 0.2
		bot:D3bot_UpdatePath(nil, nil)
	end
end

---Called when the bot takes damage.
---@param bot GPlayer
---@param dmg GCTakeDamageInfo
function HANDLER.OnTakeDamageFunction(bot, dmg)
	--bot:Say("ouch!")
end

---Called when the bot damages something.
---@param bot GPlayer -- The bot that caused the damage.
---@param ent GEntity -- The entity that took damage.
---@param dmg GCTakeDamageInfo -- Information about the damage.
function HANDLER.OnDoDamageFunction(bot, ent, dmg)
	--bot:Say("Gotcha!")
end

---Called when the bot dies.
---@param bot GPlayer
function HANDLER.OnDeathFunction(bot)
	--bot:Say("rip me!")
	HANDLER.RerollTarget(bot)
end

-----------------------------------
-- Custom functions and settings --
-----------------------------------

---Returns whether a target is valid.
---@param bot GPlayer
---@param target GPlayer|GEntity|any
function HANDLER.CanBeTgt(bot, target)
	if not target or not IsValid(target) then return end
	if target:IsPlayer() and not target.D3bot_Mem and target ~= bot and target:GetObserverMode() == OBS_MODE_NONE and target:Alive() then return true end
end

---Rerolls the bot's target.
---@param bot GPlayer
function HANDLER.RerollTarget(bot)
	local players = D3bot.RemoveObsDeadTgts(player.GetHumans())
	bot:D3bot_SetTgtOrNil(table.Random(players), false, nil)
end