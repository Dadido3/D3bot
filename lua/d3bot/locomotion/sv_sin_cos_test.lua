-- Copyright (C) 2020 David Vogel
-- 
-- This file is part of D3bot.
-- 
-- D3bot is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- D3bot is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with D3bot.  If not, see <http://www.gnu.org/licenses/>.

local D3bot = D3bot
local LOCOMOTION = D3bot.Locomotion

-- Add new locomotion controller
function LOCOMOTION.SinCosTest(bot, mem, duration)
	-- Init
	mem.Locomotion = {}

	-- Add control callback to bot
	mem.Locomotion.Callback = function(bot, mem, cUserCmd)
		cUserCmd:ClearButtons()
		cUserCmd:ClearMovement()
		cUserCmd:SetForwardMove(math.sin(CurTime()) * 100)
		cUserCmd:SetSideMove(math.cos(CurTime()) * 100)
	end

	-- Wait for x amount of time
	coroutine.wait(duration)

	-- Cleanup
	mem.Locomotion = nil
end