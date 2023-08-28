D3bot.Handlers = {}

-- TODO: Make search path relative
for i, filename in pairs(file.Find("d3bot/sv_zs_bot_handler/handlers/*.lua", "LUA")) do
	include("handlers/"..filename)
end

local handlerLookup = {}

function FindHandler(zombieClass, team)
	if handlerLookup[team] and handlerLookup[team][zombieClass] then -- TODO: Put cached handler into bot object
		return handlerLookup[team][zombieClass]
	end
	
	for _, fallback in ipairs({false, true}) do
		for _, handler in pairs(D3bot.Handlers) do
			if handler.Fallback == fallback and handler.SelectorFunction(GAMEMODE.ZombieClasses[zombieClass].Name, team) then
				handlerLookup[team] = {}
				handlerLookup[team][zombieClass] = handler
				return handler
			end
		end
	end
end
local FindHandler = FindHandler

hook.Add("StartCommand", D3bot.BotHooksId, function(pl, cmd)
	if D3bot.IsEnabledCached and pl.D3bot_Mem then
		
		local handler = FindHandler(pl:GetZombieClass(), pl:Team())
		handler.UpdateBotCmdFunction(pl, cmd)
		
	end
end)

local NextSupervisor🤔 = CurTime()
local NextStorePos = CurTime()
hook.Add("Think", D3bot.BotHooksId.."🤔", function()
	if not D3bot.IsEnabledCached then return end
	
	-- General bot handler think function
	for _, bot in ipairs(D3bot.GetBots()) do
		
		if not D3bot.UseConsoleBots then
			-- Hackish method to get bots back into game. (player.CreateNextBot created bots do not trigger the StartCommand hook while they are dead)
			if not bot:OldAlive() then
				gamemode.Call("PlayerDeathThink", bot)
				if (not bot.StartSpectating or bot.StartSpectating <= CurTime()) and not (GAMEMODE.RoundEnded or bot.Revive or bot.NextSpawnTime) and bot:GetObserverMode() ~= OBS_MODE_NONE then
					if GAMEMODE:GetWaveActive() then
						bot:RefreshDynamicSpawnPoint()
						bot:UnSpectateAndSpawn()
					else
						bot:ChangeToCrow()
					end
				end
			end
		end
		
		local handler = FindHandler(bot:GetZombieClass(), bot:Team())
		handler.ThinkFunction(bot)
	end
	
	-- Supervisor think function
	if NextSupervisor🤔 < CurTime() then
		NextSupervisor🤔 = CurTime() + 0.05 + math.random() * 0.1
		D3bot.SupervisorThinkFunction()
	end
	
	-- Store history of all players (For behaviour classification, stuck checking)
	if NextStorePos < CurTime() then
		NextStorePos = CurTime() + 0.9 + math.random() * 0.2
		for _, ply in ipairs(player.GetAll()) do
			ply:D3bot_StorePos()
		end
	end
end)

hook.Add("EntityTakeDamage", D3bot.BotHooksId.."TakeDamage", function(ent, dmg)
	if D3bot.IsEnabledCached then
		if ent:IsPlayer() and ent.D3bot_Mem then
			-- Bot got damaged or damaged itself
			local handler = FindHandler(ent:GetZombieClass(), ent:Team())
			handler.OnTakeDamageFunction(ent, dmg)
		end
		local attacker = dmg:GetAttacker()
		if attacker ~= ent and attacker:IsPlayer() and attacker.D3bot_Mem then
			-- A Bot did damage something
			local handler = FindHandler(attacker:GetZombieClass(), attacker:Team())
			handler.OnDoDamageFunction(attacker, ent, dmg)
			attacker.D3bot_LastDamage = CurTime()
		end
	end
end)

hook.Add("PlayerDeath", D3bot.BotHooksId.."PlayerDeath", function(pl)
	if D3bot.IsEnabledCached and pl.D3bot_Mem then
		local handler = FindHandler(pl:GetZombieClass(), pl:Team())
		handler.OnDeathFunction(pl)
		-- Add death cost to the current link
		local mem = pl.D3bot_Mem
		local nodeOrNil = mem.NodeOrNil
		local nextNodeOrNil = mem.NextNodeOrNil
		if nodeOrNil and nextNodeOrNil then
			local link
			if D3bot.UsingSourceNav then
				link = nodeOrNil:SharesLink( nextNodeOrNil )
			else
				link = nodeOrNil.LinkByLinkedNode[nextNodeOrNil]
			end
			if link then D3bot.LinkMetadata_ZombieDeath(link, D3bot.LinkDeathCostRaise) end
		end
	end
end)

local hadBonusByPl = {}
hook.Add("PlayerSpawn", D3bot.BotHooksId.."PlayerSpawn", function(pl)
	if not D3bot.IsEnabledCached then return end
	if pl.D3bot_Mem then pl:D3bot_InitializeOrReset() end
	if D3bot.IsEnabledCached and D3bot.StartBonus and D3bot.StartBonus > 0 and pl:Team() == TEAM_SURVIVOR then
		local hadBonus = hadBonusByPl[pl]
		hadBonusByPl[pl] = true
		pl:SetPoints(hadBonus and 0 or D3bot.StartBonus)
	end
end)
hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRound", function() hadBonusByPl = {} end)
