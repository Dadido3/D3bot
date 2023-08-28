D3bot.Handlers.Redeemer = D3bot.Handlers.Redeemer or {}
local HANDLER = D3bot.Handlers.Redeemer

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	if not TEAM_REDEEMER then return end
	return team == TEAM_REDEEMER
end

---Updates the bot move data every frame.
---@param bot GPlayer|table
---@param cmd GCUserCmd
function HANDLER.UpdateBotCmdFunction(bot, cmd)
	return D3bot.Handlers.Survivor_Fallback.UpdateBotCmdFunction(bot, cmd)
end

---Called every frame.
---@param bot GPlayer
function HANDLER.ThinkFunction(bot)
	return D3bot.Handlers.Survivor_Fallback.ThinkFunction(bot)
end

---Called when the bot takes damage.
---@param bot GPlayer
---@param dmg GCTakeDamageInfo
function HANDLER.OnTakeDamageFunction(bot, dmg)
	return D3bot.Handlers.Survivor_Fallback.OnTakeDamageFunction(bot, dmg)
end

---Called when the bot damages something.
---@param bot GPlayer -- The bot that caused the damage.
---@param ent GEntity -- The entity that took damage.
---@param dmg GCTakeDamageInfo -- Information about the damage.
function HANDLER.OnDoDamageFunction(bot, ent, dmg)
	D3bot.Handlers.Survivor_Fallback.OnDoDamageFunction(bot, ent, dmg)
end

---Called when the bot dies.
---@param bot GPlayer
function HANDLER.OnDeathFunction(bot)
	return D3bot.Handlers.Survivor_Fallback.OnDeathFunction(bot)
end

-----------------------------------
-- Custom functions and settings --
-----------------------------------
