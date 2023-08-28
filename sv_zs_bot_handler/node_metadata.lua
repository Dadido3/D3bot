-- Metadata storage. Helps the bots and the supervisor to make decisions.
--[[
	Link metadata:
		- ZombieDeathCost: Additional cost of this link
		
	Node metadata:
		- ZombieDeathFactor: From nil to 1. Slowly generating deadliness value for zombies. Higher values expected in front of cades.
		- PlayerFactorByTeam[team]: From nil to 1. Slowly generating player population value stored per team. Higher survivor team values inside of cades. Higher undead team values in zombie spawns and nodes zombies cross a lot.
--]]

D3bot.NodeMetadata = D3bot.NodeMetadata or {}
D3bot.LinkMetadata = D3bot.LinkMetadata or {}

local nodeMetadata = D3bot.NodeMetadata
local linkMetadata = D3bot.LinkMetadata

hook.Add("PreRestartRound", D3bot.BotHooksId.."MetadataReset", function()
	D3bot.NodeMetadata = {}
	D3bot.LinkMetadata = {}
	nodeMetadata = D3bot.NodeMetadata
	linkMetadata = D3bot.LinkMetadata
end)

local nextNodeMetadataReduce = CurTime()
local nextNodeMetadataIncrease = CurTime()
hook.Add("Think", D3bot.BotHooksId.."NodeMetadataThink", function()
	-- If survivor bots are disabled, ignore capturing team metadata
	if not D3bot.SurvivorsEnabled then return end

	-- Reduce values over time
	if nextNodeMetadataReduce < CurTime() then
		nextNodeMetadataReduce = CurTime() + 5
		
		for k, v in pairs(nodeMetadata) do
			if v.ZombieDeathFactor then
				v.ZombieDeathFactor = v.ZombieDeathFactor * 0.85
				if v.ZombieDeathFactor <= 0.1 then v.ZombieDeathFactor = nil end
			end
			if v.PlayerFactorByTeam then
				for team, _ in pairs(v.PlayerFactorByTeam) do
					v.PlayerFactorByTeam[team] = v.PlayerFactorByTeam[team] * 0.85
					if v.PlayerFactorByTeam[team] <= 0.1 then v.PlayerFactorByTeam[team] = nil end
				end
				if #v.PlayerFactorByTeam == 0 then v.PlayerFactorByTeam = nil end
			end
		end
	end
	
	-- Increase counts over time -- TODO: Check if that is a ressource hog
	local mapNavMesh = D3bot.MapNavMesh
	if nextNodeMetadataIncrease < CurTime() then
		nextNodeMetadataIncrease = CurTime() + 1
		local players = D3bot.RemoveObsDeadTgts(player.GetAll())
		for _, player in pairs(players) do
			if player:Alive() then
				local team = player:Team()
				local node = mapNavMesh:GetNearestNodeOrNil(player:GetPos())
				if node then
					if not nodeMetadata[node] then nodeMetadata[node] = {} end
					local metadata = nodeMetadata[node]
					if not metadata.PlayerFactorByTeam then metadata.PlayerFactorByTeam = {} end
					metadata.PlayerFactorByTeam[team] = math.Clamp((metadata.PlayerFactorByTeam[team] or 0) + 1/15 * (player.D3bot_Mem and 0.25 or 1), 0, 1)
				end
			end
		end
		
		--D3bot.Debug.DrawNodeMetadata(GetPlayerByName("D3"), nodeMetadata)
	end
end)

function D3bot.LinkMetadata_ZombieDeath(link, raiseCost) -- TODO: Combine it with the ZombieDeathFactor and make it node based, not link based
	if not linkMetadata[link] then linkMetadata[link] = {} end
	local metadata = linkMetadata[link]
	metadata.ZombieDeathCost = (metadata.ZombieDeathCost or 0) + raiseCost
end

function D3bot.NodeMetadata_ZombieDeath(node) -- TODO: Call it from the death handler
	if not nodeMetadata[node] then nodeMetadata[node] = {} end
	local metadata = nodeMetadata[node]
	metadata.ZombieDeathFactor = math.Clamp((metadata.ZombieDeathFactor or 0) + 0.1, 0, 1)
end

if not D3bot.UsingSourceNav then return end

function D3bot.LinkMetadata_ZombieDeath( link, raiseCost ) -- TODO: Combine it with the ZombieDeathFactor and make it node based, not link based
	local metadata = link:GetMetaData()
	metadata.ZombieDeathCost = ( metadata.ZombieDeathCost or 0 ) + raiseCost
end

function D3bot.NodeMetadata_ZombieDeath( node ) -- TODO: Call it from the death handler
	local metadata = node:GetMetaData()
	metadata.ZombieDeathFactor = math.Clamp( ( metadata.ZombieDeathFactor or 0 ) + 0.1, 0, 1 )
end
