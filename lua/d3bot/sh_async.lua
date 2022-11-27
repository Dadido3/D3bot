local D3bot = D3bot
D3bot.Async = {}
local ASYNC = D3bot.Async

---Runs the given function asynchronously.
---This can be used to run blocking functions *seemingly* parallel to other code.
---There is no parallelism, so ASYNC.Run has to be called until it returns false, which means the function has ended, or has panicked.
---@param state table @Contains the coroutine and its state. Initialize and reuse an empty table for this.
---@param func function @The function to call asynchronously.
---@return boolean running
---@return string | nil err @The error message, if there was any error.
function ASYNC.Run(state, func)
	-- Start coroutine on the first call.
	local cr = state[1]
	if not cr then
		cr = coroutine.create(func)
		state[1] = cr
	end

	-- Resume coroutine, catch and print any error.
	local succ, msg = coroutine.resume(cr)
	if not succ then
		-- Coroutine ended unexpectedly.
		print(string.format("D3bot: %s failed: %s.", cr, msg))
		return false, string.format("%s failed: %s", cr, msg)
	end

	-- Check if the coroutine finished. We will never encounter "running", as we don't call coroutine.status from inside the coroutine.
	if coroutine.status(cr) ~= "suspended" then
		return false, nil
	end

	return true, nil
end
