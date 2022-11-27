local D3bot = D3bot
D3bot.Async = {}
local ASYNC = D3bot.Async

---Runs the given function asynchronously.
---This can be used to run blocking functions *seemingly* parallel to other code.
---There is no parallelism, so ASYNC.Run has to be called until it returns false, which means the function has ended, or has panicked.
---@param worker table @Contains the coroutine and its state. Use a table created with D3bot.CreateWorker()
---@param func function @The function to call asynchronously.
---@return boolean running
---@return string | nil err @The error message, if there was any error.
function ASYNC.Run(worker, func)
	-- Start coroutine on the first call.
	local cr = worker:GetCoroutine()
	if not cr then
		cr = coroutine.create(function(used_worker)
			local graceful, _ = pcall(func, used_worker)
			if graceful then
				worker:SetFinished(true)
			end
		end)
		worker:SetCoroutine(cr)
	end

	-- Resume coroutine, catch and print any error.
	local succ, msg = coroutine.resume(cr, worker)
	if not succ and not worker:GetFinished() then
		-- Coroutine ended unexpectedly.
		worker = nil
		return false, string.format("%s failed: %s", cr, msg)
	end

	-- Check if the coroutine finished. We will never encounter "running", as we don't call coroutine.status from inside the coroutine.
	if coroutine.status(cr) ~= "suspended" or worker:GetFinished() then
		worker = nil
		return false, nil
	end

	worker:SetActive(true)

	return true, nil
end

---Defers the given function to be later run asynchronously. This does not immediately start running
---This can be used to run blocking functions *seemingly* parallel to other code.
---There is no parallelism, so ASYNC.Run has to be called until it returns false, which means the function has ended, or has panicked.
---@param worker table @Contains the coroutine and its state. Use a table created with D3bot.CreateWorker()
---@param func function @The function to call asynchronously.
---@return boolean created
function ASYNC.Defer(worker, func)
	-- Start coroutine on the first call.
	local cr = worker:GetCoroutine()
	if not cr then
		cr = coroutine.create(function(used_worker)
			local graceful, err = pcall(func, used_worker)
			if graceful then
				worker:SetFinished(true)
			elseif err then
				print(err)
			end
		end)
		worker:SetCoroutine(cr)
	end

	-- Check if the coroutine finished. We will never encounter "running", as we don't call coroutine.status from inside the coroutine.
	if coroutine.status(cr) ~= "suspended" or worker:GetFinished() then
		worker = nil
		return false
	end

	return true
end

local WORKER = {}
WORKER.__index = WORKER
AccessorFunc(WORKER, "cr", "Coroutine")
AccessorFunc(WORKER, "active", "Active")
AccessorFunc(WORKER, "finished", "Finished")
AccessorFunc(WORKER, "data", "Data")

---Creates a new worker structure for use with 
---@return table worker
function ASYNC.CreateWorker()
	-- cr			the coroutine
	-- active		shows if the worker has started, it will be set to nil when finished by ASYNC.Run
	-- finished		shows if the worker has finished, it will be true if the couroutine finishes successfully
	-- data			ambiguous persistent data (for organization)
	local newWorker = { cr = nil, active = false, finished = false, data = nil }
	return setmetatable(newWorker, WORKER)
end
