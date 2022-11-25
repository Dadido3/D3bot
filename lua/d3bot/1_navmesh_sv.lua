
return function(lib)
	lib.MapNavMeshDir = "d3bot/navmesh/map/"
	
	function lib.GetMapNavMeshPath(mapName)
		return lib.MapNavMeshDir .. mapName .. ".txt"
	end
	function lib.GetMapNavMeshParamsPath(mapName)
		return lib.MapNavMeshDir .. mapName .. ".params.txt"
	end
	lib.MapNavMeshPath = lib.GetMapNavMeshPath(game.GetMap())
	lib.MapNavMeshParamsPath = lib.GetMapNavMeshParamsPath(game.GetMap())
	
	function lib.CheckMapNavMesh(mapName)
		return file.Exists(lib.GetMapNavMeshPath(mapName), "DATA")
	end
	
	util.AddNetworkString(lib.MapNavMeshNetworkStr)
	function lib.UploadMapNavMesh(plOrPls)
		local co = coroutine.create(function()			
			local rawData = util.Compress(lib.MapNavMesh:Serialize()) or ""
			local dataLen = rawData:len()
			local maxChunkSize = 2^16 - 10 -- Leave 10 bytes for other stuff than the data.
	
			for i = 1, dataLen, maxChunkSize do
				local dataLeft = dataLen + 1 - i
				local chunkSize = math.min(maxChunkSize, dataLeft)
				local subDataComp = string.sub(rawData, i, i + chunkSize - 1)
	
				net.Start(lib.MapNavMeshNetworkStr, false)
				net.WriteBool(false)
				net.WriteUInt(chunkSize, 16)
				net.WriteData(subDataComp, chunkSize)
				net.Send(plOrPls)

				print(chunkSize, dataLeft)

				coroutine.yield()
			end
			
			-- Finish the transfer.
			net.Start(lib.MapNavMeshNetworkStr, false)
			net.WriteBool(true)
			net.WriteUInt(0, 16)
			net.Send(plOrPls)

			hook.Remove("Think", "d3bot.MapNavMeshUpload")
		end)

		hook.Add("Think", "d3bot.MapNavMeshUpload", function()
			coroutine.resume(co)
		end)
	end
	
	file.CreateDir(lib.MapNavMeshDir)
	function lib.SaveMapNavMesh()
		file.Write(lib.MapNavMeshPath, lib.MapNavMesh:SerializeSorted())
		file.Write(lib.MapNavMeshParamsPath, lib.MapNavMesh:ParamsSerializeSorted())
	end
	function lib.SaveMapNavMeshParams()
		file.Write(lib.MapNavMeshParamsPath, lib.MapNavMesh:ParamsSerializeSorted())
	end
	function lib.LoadMapNavMesh()
		local mapNavMesh
		lib.TryCatch(function()
			mapNavMesh = lib.DeserializeNavMesh(file.Read(lib.MapNavMeshPath) or "")
		end, function(errorMsg)
			mapNavMesh = lib.NewNavMesh()
			lib.LogError("Couldn't load " .. lib.MapNavMeshDir .. " (using empty nav mesh instead):\n" .. errorMsg)
		end)
		lib.TryCatch(function()
			mapNavMesh:DeserializeNavMeshParams(file.Read(lib.MapNavMeshParamsPath) or "")
		end, function(errorMsg)
			lib.LogError("Couldn't load params for " .. lib.MapNavMeshDir .. ":\n" .. errorMsg)
		end)
		lib.MapNavMesh = mapNavMesh
	end
	lib.LoadMapNavMesh()
end
