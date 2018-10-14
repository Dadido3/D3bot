D3bot.IsEnabled = engine.ActiveGamemode() == "zombiesurvival" and table.Count(D3bot.MapNavMesh.ItemById) > 0

D3bot.BotSeeTr = {
	mins = Vector(-15, -15, -15),
	maxs = Vector(15, 15, 15),
	mask = MASK_PLAYERSOLID
}
D3bot.NodeBlocking = {
	mins = Vector(-1, -1, -1),
	maxs = Vector(1, 1, 1),
	classes = {func_breakable = true, prop_physics = true, prop_dynamic = true, prop_door_rotating = true, func_door = true, func_physbox = true, func_physbox_multiplayer = true, func_movelinear = true}
}

D3bot.NodeDamageEnts = {"prop_*turret", "prop_arsenalcrate", "prop_resupply", "prop_drone*", "prop_remantler"}

D3bot.BotAttackDistMin = 100
D3bot.LinkDeathCostRaise = 300
D3bot.BotConsideringDeathCostAntichance = 3
D3bot.BotAngLerpFactor = 0.125
D3bot.BotAttackAngLerpFactor = 0.125--0.5
D3bot.BotAimAngLerpFactor = 0.5
D3bot.BotAimPosVelocityOffshoot = 0.4
D3bot.BotJumpAntichance = 25
D3bot.BotDuckAntichance = 25

D3bot.ZombiesPerPlayer = 0.3
D3bot.ZombiesPerPlayerMax = 2.0			-- Limits amount of zombies to this zombie/player ratio. (ZombiesCountAddition is not calculated in)
D3bot.ZombiesPerPlayerWave = 0.20
D3bot.ZombiesPerMinute = 0
D3bot.ZombiesPerWave = 0.4
D3bot.ZombiesCountAddition = 0			-- BotMod
D3bot.SurvivorsPerPlayer = 0--1.2		-- Survivor bots per total player (non bot) amount. They will only spawn pre round.
D3bot.SurvivorCountAddition = 0			-- BotMod for survivor bots

-- Survivor (human) bots are currently not production ready.
D3bot.SurvivorsEnabled = false			-- If true, survivor bots are allowed to exists by spawning at the beginning of a round (See SurvivorsPerPlayer and SurvivorCountAddition parameters) or by redeeming.

D3bot.IsSelfRedeemEnabled = false		-- Enable or disable the !human command
D3bot.SelfRedeemWaveMax = 1				-- The maximum wave a player can respawn (Setting it to 2 would allow the players to redeem in the first and second wave)
D3bot.StartBonus = nil					-- Number of additional points, that players get at the start of a round.

-- Uncomment the name file you want to use. If you comment out all of the name files, standard names will be used (Bot, Bot(2), Bot(3), ...)
D3bot.BotNameFile = "fng_usernames"
--D3bot.BotNameFile = "bottish"

D3bot.BotKickReason = "I did my job. :)"