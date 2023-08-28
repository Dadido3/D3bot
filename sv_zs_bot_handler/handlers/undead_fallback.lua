D3bot.Handlers.Undead_Fallback = D3bot.Handlers.Undead_Fallback or {}
local HANDLER = D3bot.Handlers.Undead_Fallback

HANDLER.AngOffshoot = 45
HANDLER.BotTgtFixationDistMin = 250
HANDLER.BotClasses = {
	"Zombie", "Agile Dead Bot", "Gore Blaster Zombie", "Agile Dead Bot",
	"Ghoul", "Chem Zombie", "Chem Zombie", "Agile Dead Bot", "Charger",
	"Wraith", "Headcrab", "Frigid Ghoul", "Fast Zombie", "Charger",
	"Bloated Zombie", "Skeletal Crawler", "Skeletal Walker", "Zombine",
	"Fast Zombie", "Shadow Lurker", "Shadow Walker", "Fast Headcrab",
	"Poison Zombie", "Poison Headcrab", "Elder Ghoul", "Fast Zombie",
	"Bloated Zombie", "Slingshot Zombie", "Charger", "Flesh Creeper", "Eradicator"
}
HANDLER.RandomSecondaryAttack = {
	["Ghoul"] = {MinTime = 3, MaxTime = 5},
	["Frigid Ghoul"] = {MinTime = 3, MaxTime = 5},
	["Frigid Revenant"] = {MinTime = 3, MaxTime = 5},
	["Elder Ghoul"] = {MinTime = 3, MaxTime = 5},
	["Zombine"] = {MinTime = 5, MaxTime = 10},
	["Poison Zombie"] = {MinTime = 5, MaxTime = 7},
	["Wild Poison Zombie"] = {MinTime = 5, MaxTime = 7},
	["Bloated Zombie"] = {MinTime = 5, MaxTime = 7},
	["Vile Bloated Zombie"] = {MinTime = 4, MaxTime = 6},
	["Charger"] = {MinTime = 2, MaxTime = 3},
	["Zombie"] = {MinTime = 5, MaxTime = 7},
	["Agile Dead Bot"] = {MinTime = 5, MaxTime = 7},
	["Fresh Dead"] = {MinTime = 5, MaxTime = 7},
	["Gore Blaster Zombie"] = {MinTime = 5, MaxTime = 7},
	["Wraith"] = {MinTime = 10, MaxTime = 15},
	["Tormented Wraith"] = {MinTime = 1, MaxTime = 2},
	["Noxious Ghoul"] = {MinTime = 3, MaxTime = 5},
	["Poison Headcrab"] = {MinTime = 3, MaxTime = 5},
	["Barbed Headcrab"] = {MinTime = 3, MaxTime = 5},
	["Eradicator"] = {MinTime = 5, MaxTime = 7},
	["Ass Kicker"] = {MinTime = 2, MaxTime = 4},
	["The Tank"] = {MinTime = 5, MaxTime = 15},
	["Nightmare"] = {MinTime = 5, MaxTime = 7},
	["Red Marrow"] = {MinTime = 5, MaxTime = 7},
	["Howler"] = {MinTime = 10, MaxTime = 10},
	["Nightmare"] = {MinTime = 5, MaxTime = 7},
	["The Tickle Monster"] = {MinTime = 5, MaxTime = 7},
	["Giga Shadow Child"] = {MinTime = 2, MaxTime = 4},
	["Bonemesh"] = {MinTime = 2, MaxTime = 4},
	["Ancient Nightmare"] = {MinTime = 5, MaxTime = 7},
	["Giga Gore Child"] = {MinTime = 2, MaxTime = 4},
	--["Doom Crab"] = {MinTime = 5, MaxTime = 6},
	["Puke Pus"] = {MinTime = 5, MaxTime = 6},
	["Devourer"] = {MinTime = 2, MaxTime = 4},
	["Flesh Creeper"] = {MinTime = 3, MaxTime = 5},
	--["Extinction Crab"] = {MinTime = 4, MaxTime = 6}
	--["Poison Zombie"] = {MinTime = 5, MaxTime = 7} -- Slows them too much
}

HANDLER.Phrases = {
	[0] = "voicechat/zs_mge/16_0.mp3";
	[1] = "voicechat/zs_mge/bonus_01.mp3";
	[2] = "voicechat/zs_mge/bonus_02.mp3";
	[3] = "voicechat/zs_mge/bro_nado_trenirovatsa.mp3";
	[4] = "voicechat/zs_mge/ebanoe.mp3";
	[5] = "voicechat/zs_mge/EZ!.mp3";
	[6] = "voicechat/zs_mge/ez.mp3";
	[7] = "voicechat/zs_mge/fatty.mp3";
	[8] = "voicechat/zs_mge/garbage.mp3";
	[9] = "voicechat/zs_mge/kulak.mp3";
	[10] = "voicechat/zs_mge/na_legkih.mp3";
	[11] = "voicechat/zs_mge/perhot.mp3";
	[12] = "voicechat/zs_mge/ubivat_vseh!.mp3";
	[13] = "voicechat/zs_mge/bro_nado_trenirovatsa.mp3";
	[14] = "voicechat/zs_mge/locker02.mp3";
}

HANDLER.PhrasesDamage = {
	[0] = "voicechat/zs_mge/breakingmonitor.mp3";
	[1] = "voicechat/zs_mge/destroyed.mp3";
	[2] = "voicechat/zs_mge/getup_02.mp3";
	[3] = "voicechat/zs_mge/invis.mp3";
	[4] = "voicechat/zs_mge/v_shkafu_prachus.mp3";
	[5] = "voicechat/zs_mge/locker02.mp3";
	[6] = "voicechat/zs_mge/maloi.mp3";
	[7] = "voicechat/zs_mge/rage.mp3";
	[8] = "voicechat/zs_mge/what are you doing.mp3";
	[9] = "voicechat/zs_mge/wtfhesdoin.mp3";
	[10] = "voicechat/zs_mge/viebali.mp3";
}
HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_UNDEAD
end

---Updates the bot move data every frame.
---@param bot GPlayer|table
---@param cmd GCUserCmd
function HANDLER.UpdateBotCmdFunction(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()

	-- Fix knocked down bots from sliding around. (Workaround for the NoxiousNet codebase, as ply:Freeze() got removed from status_knockdown, status_revive, ...)
	if bot.KnockedDown and IsValid(bot.KnockedDown) or bot.Revive and IsValid(bot.Revive) then
		return
	end

	if not bot:Alive() then
		-- Get back into the game.
		cmd:SetButtons(IN_ATTACK)
		return
	end

	local mem = bot.D3bot_Mem

	bot:D3bot_UpdatePathProgress()
	D3bot.Basics.SuicideOrRetarget(bot)

	local result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle, minorStuck, majorStuck, facesHindrance = D3bot.Basics.PounceAuto(bot)
	if not result then
		result, actions, forwardSpeed, sideSpeed, upSpeed, aimAngle, minorStuck, majorStuck, facesHindrance = D3bot.Basics.WalkAttackAuto(bot)
		if not result then
			return
		end
	end

	if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetClass() ~= "player" then
		local prevEnt = mem.TgtOrNil
		local botPos = bot:WorldSpaceCenter()
		for _, ent in pairs(ents.FindInSphere(botPos, 600)) do
			if ent:IsValidLivingHuman() and (TrueVisible(ent:WorldSpaceCenter(), botPos) or TrueVisible(ent:GetShootPos(), bot:GetShootPos())) then
				mem.TgtOrNil = ent
				break
			end
		end
	end

	-- If facesHindrance is true, let the bot search for nearby barricade objects.
	-- But only if the bot didn't do damage for some time.
	if facesHindrance and CurTime() - (bot.D3bot_LastDamage or 0) > 2 then
		local entity, entityPos = bot:D3bot_FindBarricadeEntity(1) -- One random line trace per frame.
		if entity and entityPos then
			mem.BarricadeAttackEntity, mem.BarricadeAttackPos = entity, entityPos
		end
	end

	if IsValid(mem.TgtOrNil) and mem.TgtOrNil:IsPlayer() and (WorldVisible(bot:WorldSpaceCenter(), mem.TgtOrNil:WorldSpaceCenter()) or WorldVisible(bot:GetShootPos(), mem.TgtOrNil:GetShootPos())) and bot:D3bot_GetAttackPosOrNilFuture(0.75, 0.5):DistToSqr(bot:WorldSpaceCenter()) <= math.pow((bot:GetActiveWeapon().MeleeReach or 48), 2) then
		mem.BarricadeAttackEntity = mem.TgtOrNil
		mem.BarricadeAttackPos = bot:D3bot_GetAttackPosOrNilFuture(0.75, 0.5)
		mem.BotShouldIgnoreCade = true
	else
		mem.BotShouldIgnoreCade = false
	end

	-- Simple hack for throwing poison randomly TODO: Only throw if possible target is close enough. Aiming. Timing.
	-- yeah its not good but it works lol
	-- ok now its good, should be

	local secAttack = HANDLER.RandomSecondaryAttack[GAMEMODE.ZombieClasses[bot:GetZombieClass()].Name]
	if secAttack then
		if (not mem.NextThrowPoisonTime or mem.NextThrowPoisonTime <= CurTime()) and mem.TgtOrNil and mem.TgtOrNil:IsValid() and mem.TgtOrNil:IsPlayer()
		and (TrueVisible(bot:GetShootPos(), mem.TgtOrNil:WorldSpaceCenter()) or TrueVisible(bot:GetShootPos(), mem.TgtOrNil:GetShootPos())) then

			local botclass = bot:GetZombieClassTable()

			if botclass.Boss then
				mem.DontAttackTgt = true
				HANDLER.AngOffshoot = 5

				actions.Attack2 = true
				actions.Attack = true
				if math.random(0, 1) == 1 then
					actions.Attack2 = true
					mem.NextThrowPoisonTime = CurTime() + secAttack.MinTime + math.random() * (secAttack.MaxTime - secAttack.MinTime)
				else
					actions.Reload = true
				end

				timer.Simple(0.5, function() if IsValid(bot) then mem.DontAttackTgt = false end end)
				timer.Simple(1.5, function() if IsValid(bot) then HANDLER.AngOffshoot = 15 end end)
			else
				if botclass.Name ~= "Charger" and mem.TgtOrNil:WorldSpaceCenter():DistToSqr(bot:GetShootPos() or bot:GetPos()) <= math.pow(D3bot.BotAttackDistMin, 2) * 7 then
					mem.NextThrowPoisonTime = CurTime() + secAttack.MinTime + math.random() * (secAttack.MaxTime - secAttack.MinTime)
					HANDLER.AngOffshoot = 0

					if botclass.Name == "Tormented Wraith" then 
						if math.random(0, 1) == 1 then 
							actions.Attack2 = true 
						else 
							actions.Reload = true 
						end
					else actions.Attack2 = true end

					mem.SpitOnPlayer = true

					mem.BarricadeAttackEntity = mem.TgtOrNil
					mem.BarricadeAttackPos = mem.TgtOrNil:GetShootPos()

					timer.Simple(1.75, function() if IsValid(bot) then HANDLER.AngOffshoot = 45 mem.SpitOnPlayer = false end end)
				else
					if botclass.Name == "Charger" then
						mem.NextThrowPoisonTime = CurTime() + secAttack.MinTime + math.random() * (secAttack.MaxTime - secAttack.MinTime)
						HANDLER.AngOffshoot = 15

						actions.Attack2 = true
						actions.Attack = false

						timer.Simple(2, function() if IsValid(bot) then HANDLER.AngOffshoot = 45 end end)
					end
				end
			end
		end
	end

	if bot:GetZombieClassTable().Name == "Flesh Creeper" and not bot.IgnoreNesting then
    		local botPos = bot:WorldSpaceCenter()
    		local endpos = botPos + bot:EyeAngles():Forward() * 32
    		local allzombies = team.GetPlayers(TEAM_UNDEAD)
    		local human = false
    		local cade = false
    		local canbuild = true
    		local isbuilding = false
    		local spawnpositions = {
				Vector(17, 17, 0),
				Vector(-17, -17, 0),
				Vector(17, 17, 64),
				Vector(-17, -17, 64)
			}

			local tr = util.TraceLine({start = botPos, endpos = endpos, filter = allzombies, mask = MASK_PLAYERSOLID})
			local trent = tr.Entity

			if trent and trent:IsValid() and trent.ZombieConstruction and not trent:GetNestBuilt() or (bot.LastTimeNestBuild or 0) >= CurTime() then
				human = true
				cade = true
				isbuilding = true
				if trent.ZombieConstruction and not trent:GetNestBuilt() then
					bot.LastTimeNestBuild = CurTime() + 0.5
					timer.Remove(bot:Name() .. "nest")
				end
			end

			for _, spos in pairs(spawnpositions) do
				if bit.band(util.PointContents(botPos + spos), CONTENTS_SOLID) == CONTENTS_SOLID then
					canbuild = false
					break
				end
			end

			if canbuild then
    			for _, ent in pairs(ents.FindInSphere(botPos, 800)) do
       				if ent:IsValidLivingHuman() then
       					if util.SkewedDistance(ent:GetPos(), botPos, 1.5) <= (not isbuilding and GAMEMODE.CreeperNestDistBuild or 100) or not isbuilding and WorldVisible(botPos, ent:GetPos() + Vector(0, 0, 32)) then human = false break
       					else human = true end
        			elseif ent:GetClass() == "zombiegasses" and util.SkewedDistance(ent:GetPos(), botPos, 1.5) <= 800 then human = false break
        			elseif ent:GetClass() == "prop_creepernest" and ent:GetNestBuilt() and util.SkewedDistance(ent:GetPos(), botPos, 1.5) <= GAMEMODE.CreeperNestDistBuildNest * 1.25 then human = false break
        			elseif ent:GetClass() == "prop_creepernest" and not ent:GetNestBuilt() and ent:GetPos():DistToSqr(botPos) <= 2500 then human = true cade = true break
       	   			elseif ent:GetClass() == "prop_obj_sigil" and not ent:GetSigilCorrupted() and util.SkewedDistance(ent:GetPos(), botPos, 1.5) <= GAMEMODE.CreeperNestDistBuildNest then human = false break
       	   			elseif ent:IsNailed() and util.SkewedDistance(ent:GetPos(), botPos, 5) <= 600 then cade = true end
    			end
    		end

    		if cade and human then
        		actions.Attack2 = true
        		actions.Jump = false
        		actions.Duck = false
        		actions.Use = false
        		actions.Attack = false
        		actions.MoveForward = false
        		actions.MoveLeft = false
        		actions.MoveRight = false
        		actions.MoveBackward = false
        		aimAngle = nil
        		forwardSpeed = nil
        		sideSpeed = nil
        		upSpeed = nil
        		bot.BuildingNest = true
        		if not timer.Exists(bot:Name() .. "nest") then
        			timer.Create(bot:Name() .. "nest", 1.75, 1, function() 
        				if not IsValid(bot) then return end
        				local failure = true
        				for _, ent in pairs(ents.FindInSphere(bot:WorldSpaceCenter(), 50)) do
        					if ent:GetClass() == "prop_creepernest" and not ent:GetNestBuilt() then failure = false end
        				end
        				if failure then
        					bot.IgnoreNesting = true
        					timer.Simple(0.3, function() if IsValid(bot) then bot.IgnoreNesting = false end end)
        				end
        			end)
        		end
    		else
    			bot.BuildingNest = false
    		end
	end

	local buttons
	if actions then
		buttons = bit.bor(actions.MoveForward and IN_FORWARD or 0, actions.MoveBackward and IN_BACK or 0, actions.MoveLeft and IN_MOVELEFT or 0, actions.MoveRight and IN_MOVERIGHT or 0, actions.Attack2 and IN_ATTACK2 or 0, actions.Reload and not bot:GetZombieClassTable().Name == "Flesh Creeper" and IN_RELOAD or 0, actions.Attack and not bot.BuildingNest and IN_ATTACK or 0, actions.Duck and IN_DUCK or 0, actions.Jump and IN_JUMP or 0, actions.Use and IN_USE or 0)
	end

	if majorStuck and GAMEMODE:GetWaveActive() and not GAMEMODE.ZombieClasses[bot:GetZombieClass()].Boss then bot:Kill() end

	if aimAngle then bot:SetEyeAngles(aimAngle)	cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	if sideSpeed then cmd:SetSideMove(sideSpeed) end
	if upSpeed then cmd:SetUpMove(upSpeed) end
	cmd:SetButtons(buttons)
end

---Called every frame.
---@param bot GPlayer
function HANDLER.ThinkFunction(bot)
	local mem = bot.D3bot_Mem

	local botPos = bot:GetPos()

	if mem.nextUpdateSurroundingPlayers and mem.nextUpdateSurroundingPlayers < CurTime() or not mem.nextUpdateSurroundingPlayers then
		if not mem.TgtOrNil or IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(botPos) >= HANDLER.BotTgtFixationDistMin then
			mem.nextUpdateSurroundingPlayers = CurTime() + 0.9 + math.random() * 0.2
			local targets = player.GetAll() -- TODO: Filter targets before sorting
			table.sort(targets, function(a, b) return botPos:DistToSqr(a:GetPos()) < botPos:DistToSqr(b:GetPos()) end)
			for k, v in ipairs(targets) do
				if IsValid(v) and botPos:DistToSqr(v:GetPos()) < 500*500 and HANDLER.CanBeTgt(bot, v) and bot:D3bot_CanSeeTarget(nil, v) then
					bot:D3bot_SetTgtOrNil(v, false, nil)
					mem.nextUpdateSurroundingPlayers = CurTime() + 3
					break
				end
				if k > 3 then break end
			end
		end
	end

	if mem.nextCheckTarget and mem.nextCheckTarget < CurTime() or not mem.nextCheckTarget then
		mem.nextCheckTarget = CurTime() + 0.9 + math.random() * 0.2
		if not HANDLER.CanBeTgt(bot, mem.TgtOrNil) then
			HANDLER.RerollTarget(bot)
		end
	end

	if mem.nextUpdateOffshoot and mem.nextUpdateOffshoot < CurTime() or not mem.nextUpdateOffshoot then
		mem.nextUpdateOffshoot = CurTime() + 0.4 + math.random() * 0.2
		bot:D3bot_UpdateAngsOffshoot(HANDLER.AngOffshoot * (bot:GetStatus("frightened") and math.random(1, 5) or 1))
	end

	local pathCostFunction

	if D3bot.UsingSourceNav then
		if not pathCostFunction then
			pathCostFunction = function( cArea, nArea, link )
				local linkMetaData = link:GetMetaData()
				local linkPenalty = linkMetaData and linkMetaData.ZombieDeathCost or 0
				return linkPenalty * ( mem.ConsidersPathLethality and 1 or 0 )
			end
		end
	else
		if not pathCostFunction then
			pathCostFunction = function( node, linkedNode, link )
				local linkMetadata = D3bot.LinkMetadata[link]
				local linkPenalty = linkMetadata and linkMetadata.ZombieDeathCost or 0
				return linkPenalty * (mem.ConsidersPathLethality and 1 or 0)
			end
		end
	end

	if mem.nextUpdatePath and mem.nextUpdatePath < CurTime() or not mem.nextUpdatePath then
		mem.nextUpdatePath = CurTime() + 0.9 + math.random() * 0.2
		bot:D3bot_UpdatePath( pathCostFunction, nil )
	end
end

---Called when the bot takes damage.
---@param bot GPlayer
---@param dmg GCTakeDamageInfo
function HANDLER.OnTakeDamageFunction(bot, dmg)
	if math.random(0, 150) == 150 then
		bot:EmitSound(HANDLER.PhrasesDamage[math.random(0, #HANDLER.PhrasesDamage)])
	end

	local attacker = dmg:GetAttacker()
	if not HANDLER.CanBeTgt(bot, attacker) then return end
	local mem = bot.D3bot_Mem
	if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():DistToSqr(bot:GetPos()) > math.pow(HANDLER.BotTgtFixationDistMin, 2) then return end
	mem.TgtOrNil = attacker
	--bot:Say("Ouch! Fuck you "..attacker:GetName().."! I'm gonna kill you!")
end

---Called when the bot damages something.
---@param bot GPlayer -- The bot that caused the damage.
---@param ent GEntity -- The entity that took damage.
---@param dmg GCTakeDamageInfo -- Information about the damage.
function HANDLER.OnDoDamageFunction(bot, ent, dmg)
	local mem = bot.D3bot_Mem

	-- If the zombie hits a barricade prop, store that hit position for the next attack.
	  if ent and ent:IsValid() and ent:D3bot_IsBarricade() then
		mem.BarricadeAttackEntity, mem.BarricadeAttackPos = ent, dmg:GetDamagePosition()
	end

	if math.random(0, 75) == 75 then
		bot:EmitSound(HANDLER.Phrases[math.random(0, #HANDLER.Phrases)])
	end

	--ClDebugOverlay.Sphere(GetPlayerByName("D3"), dmg:GetDamagePosition(), 2, 1, Color(255,255,255), false)
	--bot:Say("Gotcha!")
end

---Called when the bot dies.
---@param bot GPlayer
function HANDLER.OnDeathFunction(bot)
	--bot:Say("rip me!")
	bot:D3bot_RerollClass(HANDLER.BotClasses) -- TODO: Situation depending reroll of the zombie class
	HANDLER.RerollTarget(bot)
end

-----------------------------------
-- Custom functions and settings --
-----------------------------------

local potTargetEntClasses = {"prop_*turret", "prop_arsenalcrate", "prop_manhack*", "prop_rollermine*", "prop_obj_sigil"}
local potEntTargets = nil

---Returns whether a target is valid.
---@param bot GPlayer
---@param target GPlayer|GEntity|any
function HANDLER.CanBeTgt(bot, target)
	if not target or not IsValid(target) then return end
	if target:IsPlayer() and target ~= bot and target:Team() ~= TEAM_UNDEAD and target:GetObserverMode() == OBS_MODE_NONE and not target:IsFlagSet(FL_NOTARGET) and target:Alive() then return true end
	if target:GetClass() == "prop_obj_sigil" and (target:GetSigilCorrupted() or bot:GetZombieClassTable().Name == "Puke Pus" or GAMEMODE.TheLastHuman) then return false end -- Special case to ignore corrupted sigils.
	if potEntTargets and table.HasValue(potEntTargets, target) then return true end

	return false
end

---Rerolls the bot's target.
---@param bot GPlayer
function HANDLER.RerollTarget(bot)
	-- Get humans or non zombie players or any players in this order.
	local players = D3bot.RemoveObsDeadTgts(team.GetPlayers(TEAM_HUMAN))
	if #players == 0 and TEAM_UNDEAD then
		players = D3bot.RemoveObsDeadTgts(player.GetAll())
		players = D3bot.From(players):Where(function(k, v) return v:Team() ~= TEAM_UNDEAD end).R
	end
	if #players == 0 then
		players = D3bot.RemoveObsDeadTgts(player.GetAll())
	end
	potEntTargets = D3bot.GetEntsOfClss(potTargetEntClasses)
	local potTargets = table.Add(players, potEntTargets)
	bot:D3bot_SetTgtOrNil(table.Random(potTargets), false, nil)
end
