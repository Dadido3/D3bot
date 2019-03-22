
return function(lib)
	local from = lib.From
	
	lib.NavMeshMeta = { __index = {} }
	lib.NavMeshItemMeta = { __index = {} }
	lib.NavMeshNodeMeta = {
		__index = setmetatable({ Type = "node" }, lib.NavMeshItemMeta),
		__tostring = function(node) return "N" .. node.Id end }
	lib.NavMeshLinkMeta = {
		__index = setmetatable({ Type = "link" }, lib.NavMeshItemMeta),
		__tostring = function(link) return link.Id end }
	
	local fallback = lib.NavMeshMeta.__index
	local itemFallback = lib.NavMeshItemMeta.__index
	local nodeFallback = lib.NavMeshNodeMeta.__index
	local linkFallback = lib.NavMeshLinkMeta.__index
	
	lib.BotNodeMinProximity = 40
	
	lib.MapNavMeshNetworkStr = "D3bot Map NavMesh"
	
	lib.NavMeshItemsSeparator = "\n"
	lib.NavMeshItemsSeparatorOld = ";"
	lib.NavMeshItemIdParamsPairSeparator = ":"
	lib.NavMeshItemParamsSeparator = ","
	lib.NavMeshItemParamNameNumPairSeparator = "="
	lib.NavMeshLinkNodesSeparator = "-"
	
	lib.Params = {
		Correct = {
			Jump = {"Disabled", "Always"},
			JumpTo = {"Disabled", "Always"},
			Duck = {"Disabled", "Always"},
			DuckTo = {"Disabled", "Always"},
			Wall = {"Suicide", "Retarget"},
			See = {"Disabled"},
			Aim = {"Straight"},
			AimTo = {"Straight"},
			Cost = {},
			Condition = {"Unblocked", "Blocked"},
			Direction = {"Forward", "Backward"},
			Walking = {"Needed"},
			Pouncing = {"Needed"},
			Climbing = {"Needed"},
			DMGPerSecond = {},
			BotMod = {} },
		Replace = {
			Unidir = "Direction"} }
	
	lib.NavmeshParams = {
		Correct = {
			BotMod = {},
			ZPP = {},
			ZPPM = {},
			ZPPW = {},
			ZPM = {},
			ZPW = {},
			SPP = {},
			SCA = {} },
		Replace = {} }
	
	function lib.NormalizeParam(name, numOrSerializedNumOrStrOrEmpty)
		-- Replace
		for k, v in pairs(lib.Params.Replace) do
			if k:lower() == name:lower() then
				name = v
				break
			end
		end
		-- Correct
		for k, v in pairs(lib.Params.Correct) do
			if k:lower() == name:lower() then
				name = k
				if type(numOrSerializedNumOrStrOrEmpty) == "string" then
					for _, v2 in pairs(v) do
						if v2:lower() == numOrSerializedNumOrStrOrEmpty:lower() then
							numOrSerializedNumOrStrOrEmpty = v2
							break
						end
					end
				end
				break
			end
		end
		return name, numOrSerializedNumOrStrOrEmpty
	end
	
	function lib.NormalizeNavmeshParam(name, numOrSerializedNumOrStrOrEmpty)
		-- Replace
		for k, v in pairs(lib.NavmeshParams.Replace) do
			if k:lower() == name:lower() then
				name = v
				break
			end
		end
		-- Correct
		for k, v in pairs(lib.NavmeshParams.Correct) do
			if k:lower() == name:lower() then
				name = k
				if type(numOrSerializedNumOrStrOrEmpty) == "string" then
					for _, v2 in pairs(v) do
						if v2:lower() == numOrSerializedNumOrStrOrEmpty:lower() then
							numOrSerializedNumOrStrOrEmpty = v2
							break
						end
					end
				end
				break
			end
		end
		return name, numOrSerializedNumOrStrOrEmpty
	end
	
	function lib.NewNavMesh() return setmetatable({
		ItemById = {},
		NodeById = {},
		LinkById = {},
		Params = {} }, lib.NavMeshMeta) end
	local function newItem(navMesh, id)
		local r = {
			NavMesh = navMesh,
			Id = id,
			Pos = Vector(),
			AreaVertices = {},
			Params = {} }
		navMesh.ItemById[id] = r
		return r
	end
	
	function fallback:ForceGetItem(id) return isnumber(id) and self:ForceGetNode(id) or self:ForceGetLink(id) end
	function fallback:NewNode() return self:ForceGetNode(#self.ItemById + 1) end
	function fallback:ForceGetNode(id)
		local r = self.NodeById[id]
		if r then return r end
		r = setmetatable(newItem(self, id), lib.NavMeshNodeMeta)
		r.LinkByLinkedNode = {}
		self.NodeById[id] = r
		return r
	end
	function fallback:ForceGetLink(idOrNodeA, nilOrNodeB)
		local nodeA, nodeB
		if nilOrNodeB == nil then
			local id = idOrNodeA
			local serializedNodeIds = id:Split(lib.NavMeshLinkNodesSeparator)
			if #serializedNodeIds != 2 then error("Link must have exactly 2 nodes to link.", 2) end
			local nodeIds = from(serializedNodeIds):SelV(tonumber).R
			if from(nodeIds):Len().R != 2 then error("Invalid node ID.", 2) end
			nodeA, nodeB = unpack(from(nodeIds):SelV(function(nodeId) return self:ForceGetNode(nodeId) end).R)
		else
			nodeA = idOrNodeA
			nodeB = nilOrNodeB
		end
		if nodeA == nodeB then return nil end
		local r = nodeA.LinkByLinkedNode[nodeB]
		if r then return r end
		local id = nodeA.Id .. lib.NavMeshLinkNodesSeparator .. nodeB.Id
		r = setmetatable(newItem(self, id), lib.NavMeshLinkMeta)
		r.Nodes = { nodeA, nodeB }
		lib.TwoWay(nodeA, nodeB, function(node, linkedNode) node.LinkByLinkedNode[linkedNode] = r end)
		self.LinkById[id] = r
		return r
	end
	function fallback:SetParam(name, numOrSerializedNumOrStrOrEmpty)
		if name == "" then error("Name is empty.", 2) end
		name, numOrSerializedNumOrStrOrEmpty = lib.NormalizeNavmeshParam(name, numOrSerializedNumOrStrOrEmpty)
		if numOrSerializedNumOrStrOrEmpty == "" then
			self.Params[name] = nil
			return
		end
		local numOrStr = tonumber(numOrSerializedNumOrStrOrEmpty) or numOrSerializedNumOrStrOrEmpty
		if (name .. (isstring(numOrStr) and numOrStr or "")):find("[^%w_]") then error("Only alphanumeric letters and underscore allowed in name and string values.", 2) end
		self.Params[name] = numOrStr
	end
	
	local function itemParamChanged(item, paramName)
		local params = item.Params
		if item.Pos then item.Pos = Vector(params.X or 0, params.Y or 0, params.Z or 0) end
		item.HasArea = not not (params.AreaXMin and params.AreaXMax and params.AreaYMin and params.AreaYMax)
	end
	function itemFallback:SetParam(name, numOrSerializedNumOrStrOrEmpty)
		if name == "" then error("Name is empty.", 2) end
		name, numOrSerializedNumOrStrOrEmpty = lib.NormalizeParam(name, numOrSerializedNumOrStrOrEmpty)
		if numOrSerializedNumOrStrOrEmpty == "" then
			self.Params[name] = nil
			itemParamChanged(self, name)
			return
		end
		local numOrStr = tonumber(numOrSerializedNumOrStrOrEmpty) or numOrSerializedNumOrStrOrEmpty
		if (name .. (isstring(numOrStr) and numOrStr or "")):find("[^%w_]") then error("Only alphanumeric letters and underscore allowed in name and string values.", 2) end
		self.Params[name] = numOrStr
		itemParamChanged(self, name)
	end
	
	function nodeFallback:GetFocusPos() return self.Pos end
	function linkFallback:GetFocusPos() return LerpVector(0.5, self.Nodes[1].Pos, self.Nodes[2].Pos) end
	
	function linkFallback:GetParam(name) return self.Params[name] or self.Nodes[1].Params[name] or self.Nodes[2].Params[name] end
	
	function nodeFallback:GetContains(pos, verticalLimit)
		local z = verticalLimit and math.Clamp(self.Pos.z, pos.z - verticalLimit, pos.z + verticalLimit) or self.Pos.z
		local pos = Vector(pos.x, pos.y, z)
		if not self.HasArea then return pos:Distance(self.Pos) < lib.BotNodeMinProximity end
		local params = self.Params
		return math.abs(pos.z - self.Pos.z) <= (1) and pos.x >= params.AreaXMin and pos.x <= params.AreaXMax and pos.y >= params.AreaYMin and pos.y <= params.AreaYMax
	end
	
	function nodeFallback:IsViewBlocked(eyePos)
		local tr = util.TraceLine({
			start = eyePos,
			endpos = self.Pos,
			mask = MASK_SOLID_BRUSHONLY
		})
		return tr and tr.Fraction <= 0.98 or false
	end
	function nodeFallback:ShouldDraw(eyePos)
		if not self:IsViewBlocked(eyePos) then return true end
		for node, link in pairs(self.LinkByLinkedNode) do
			if not node:IsViewBlocked(eyePos) then return true end
		end
		return false
	end
	function linkFallback:ShouldDraw(eyePos)
		for i, node in ipairs(self.Nodes) do
			if not node:ShouldDraw(eyePos) then return false end
		end
		return true
	end
	
	function fallback:GetCursoredItemOrNil(pl)
		local oldDraw = pl:GetInfoNum("d3bot_navmeshing_smartdraw", 1) == 0
		local relAngMin = 5
		local cursoredItemOrNil
		local eyePos, eyeAngs = pl:EyePos(), pl:EyeAngles()
		for id, item in pairs(self.ItemById) do
			local angs = (item:GetFocusPos() - eyePos):Angle()
			local relP = math.AngleDifference(eyeAngs.p, angs.p)
			local relY = math.AngleDifference(eyeAngs.y, angs.y)
			local relAng = math.sqrt(relP * relP + relY * relY)
			if relAng < relAngMin and (oldDraw or item:ShouldDraw(eyePos)) then
				cursoredItemOrNil = item
				relAngMin = relAng
			end
		end
		return cursoredItemOrNil
	end
	
	function fallback:GetNearestNodeOrNil(pos)
		local nearestNodeOrNil
		local distMin = math.huge
		for id, node in pairs(self.NodeById) do
			local nodePos = node.Pos
			if node.HasArea then
				local params = node.Params
				nodePos = Vector(math.Clamp(pos.x, params.AreaXMin, params.AreaXMax), math.Clamp(pos.y, params.AreaYMin, params.AreaYMax), nodePos.z)
			end
			local dist = pos:Distance(nodePos)
			if dist < distMin then
				nearestNodeOrNil = node
				distMin = dist
			end
		end
		return nearestNodeOrNil
	end
	
	local isIgnoreParameter = from((" "):Explode("X Y Z AreaXMin AreaYMin AreaXMax AreaYMax")):VsSet().R
	
	function nodeFallback:MergeWithNode(node)
		if not node then return end
		
		local function round(num) return math.Round(num * 10) / 10 end
		
		-- Store linked nodes. TODO: Store and restore link parameters. Directional links are problematic!
		local tempLinkedNodes = {}
		for linkedNode, link in pairs(node.LinkByLinkedNode) do table.insert(tempLinkedNodes, linkedNode) end
		
		-- Store parameters
		local tempParameters = {}
		for paramKey, paramValue in pairs(node.Params) do
			if not isIgnoreParameter[paramKey] then
				tempParameters[paramKey] = paramValue
			end
		end
		
		-- Calculate Area
		local selfArea = ((self.Params.AreaXMax or self.Pos.x) - (self.Params.AreaXMin or self.Pos.x)) * ((self.Params.AreaYMax or self.Pos.y) - (self.Params.AreaYMin or self.Pos.y))
		local nodeArea = ((node.Params.AreaXMax or node.Pos.x) - (node.Params.AreaXMin or node.Pos.x)) * ((node.Params.AreaYMax or node.Pos.y) - (node.Params.AreaYMin or node.Pos.y))
		
		-- Create new node, that is as large as self and node together. Weighted mean
		local pos
		if selfArea + nodeArea > 1 then
			pos = (self.Pos * selfArea + node.Pos * nodeArea) / (selfArea + nodeArea)
		else
			pos = (self.Pos + node.Pos) / 2
		end
		
		self:SetParam("AreaXMax", math.max(self.Params.AreaXMax or self.Pos.x, node.Params.AreaXMax or node.Pos.x))
		self:SetParam("AreaXMin", math.min(self.Params.AreaXMin or self.Pos.x, node.Params.AreaXMin or node.Pos.x))
		
		self:SetParam("AreaYMax", math.max(self.Params.AreaYMax or self.Pos.y, node.Params.AreaYMax or node.Pos.y))
		self:SetParam("AreaYMin", math.min(self.Params.AreaYMin or self.Pos.y, node.Params.AreaYMin or node.Pos.y))
		
		self:SetParam("X", round(pos.x))
		self:SetParam("Y", round(pos.y))
		self:SetParam("Z", round(pos.z))
		
		-- Restore the links TODO: Restore parameters
		for _, linkedNode in pairs(tempLinkedNodes) do
			lib.MapNavMesh:ForceGetLink(self, linkedNode)
		end
		
		-- Restore the parameters
		for paramKey, paramValue in pairs(tempParameters) do
			self:SetParam(paramKey, paramValue)
		end
		
		node:Remove()
		
		return true
	end
	
	function nodeFallback:Split(splitPos, axisName)
		if not splitPos then return end
		if axisName ~= "X" and axisName ~= "Y" then return end
		
		local function round(num) return math.Round(num * 10) / 10 end
		
		local posKey = axisName:lower()
		local splitCoord = round(splitPos[posKey])
		
		-- Check if split position is inside the node area
		if round(self.Params["Area"..axisName.."Min"] or self.Pos[posKey]) > splitCoord or round(self.Params["Area"..axisName.."Max"] or self.Pos[posKey]) < splitCoord then return end
		
		-- Store linked nodes
		local tempLinkedNodes = {}
		for linkedNode, link in pairs(self.LinkByLinkedNode) do table.insert(tempLinkedNodes, linkedNode) end
		
		-- Make second half first (and it is essentially a copy)
		local newNode = lib.MapNavMesh:NewNode()
		
		-- Replicate all parameters
		for name, v in pairs(self.Params) do
			newNode:SetParam(name, v)
		end
		
		-- Shrink this node
		self:SetParam(axisName, round(((self.Params["Area"..axisName.."Min"] or self.Pos[posKey]) + splitCoord) / 2))
		self:SetParam("Area"..axisName.."Max", splitCoord)
		
		-- Shrink new node
		newNode:SetParam(axisName, round(((newNode.Params["Area"..axisName.."Max"] or newNode.Pos[posKey]) + splitCoord) / 2))
		newNode:SetParam("Area"..axisName.."Min", splitCoord)
		
		-- Restore the links TODO: Restore link parameters. Directional links are problematic!
		for _, linkedNode in pairs(tempLinkedNodes) do
			if round(linkedNode.Params["Area"..axisName.."Min"] or linkedNode.Pos[posKey]) < splitCoord then
				-- It should already be linked, so ignore
				-- lib.MapNavMesh:ForceGetLink(self, linkedNode)
			else
				local link = self.LinkByLinkedNode[linkedNode]
				if link then link:Remove() end
			end
			if round(linkedNode.Params["Area"..axisName.."Max"] or linkedNode.Pos[posKey]) > splitCoord then
				lib.MapNavMesh:ForceGetLink(newNode, linkedNode)
			end
		end
		
		-- Connect new nodes as well
		lib.MapNavMesh:ForceGetLink(self, newNode)
		
		return newNode
	end
	
	function nodeFallback:Extend(extendPos, axisName)
		if not extendPos then return end
		if axisName ~= "X" and axisName ~= "Y" then return end
		
		local function round(num) return math.Round(num * 10) / 10 end
		
		local posKey = axisName:lower()
		local extendCoord = round(extendPos[posKey])
		
		-- Check on what side to place the new node
		if not self.HasArea then return end
		local minCoord, maxCoord
		if extendCoord > round(self.Params["Area"..axisName.."Max"]) then
			minCoord, maxCoord = round(self.Params["Area"..axisName.."Max"]), extendCoord
		elseif extendCoord < round(self.Params["Area"..axisName.."Min"]) then
			minCoord, maxCoord = extendCoord, round(self.Params["Area"..axisName.."Min"])
		else
			return -- Position is not outside of the area
		end
		
		-- Make new node that extends the current node until extendPos
		local newNode = lib.MapNavMesh:NewNode()
		newNode:SetParam("X", self.Params.X)
		newNode:SetParam("Y", self.Params.Y)
		newNode:SetParam("Z", self.Params.Z)
		newNode:SetParam("AreaXMax", self.Params.AreaXMax)
		newNode:SetParam("AreaXMin", self.Params.AreaXMin)
		newNode:SetParam("AreaYMax", self.Params.AreaYMax)
		newNode:SetParam("AreaYMin", self.Params.AreaYMin)
		
		-- Resize new node
		newNode:SetParam(axisName, round((minCoord + maxCoord) / 2))
		newNode:SetParam("Area"..axisName.."Min", minCoord)
		newNode:SetParam("Area"..axisName.."Max", maxCoord)
		
		-- Connect old and new node
		lib.MapNavMesh:ForceGetLink(self, newNode)
		
		return newNode
	end
	
	local function removeItem(item)
		item.NavMesh.ItemById[item.Id] = nil
		item.NavMesh = nil
	end
	function nodeFallback:Remove()
		for linkedNode, link in pairs(from(self.LinkByLinkedNode):ShallowCopy().R) do link:Remove() end
		self.NavMesh.NodeById[self.Id] = nil
		removeItem(self)
	end
	function linkFallback:Remove()
		local nodeA, nodeB = unpack(self.Nodes)
		self.Nodes = {}
		lib.TwoWay(nodeA, nodeB, function(node, linkedNode) node.LinkByLinkedNode[linkedNode] = nil end)
		self.NavMesh.LinkById[self.Id] = nil
		removeItem(self)
	end
	
	function fallback:Serialize()
		return from(self.ItemById):Sel(function(id, item)
			return nil, id .. lib.NavMeshItemIdParamsPairSeparator .. from(item.Params):Sel(function(name, numOrStr)
				return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
			end):Join(lib.NavMeshItemParamsSeparator).R
		end):Join(lib.NavMeshItemsSeparator).R
	end
	function fallback:SerializeSorted()
		return from(self.ItemById):SelSort(function(id, item)
			return nil, id .. lib.NavMeshItemIdParamsPairSeparator .. from(item.Params):SelSort(function(name, numOrStr)
				return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
			end, function(a,b) return tostring(a)<tostring(b) end):Join(lib.NavMeshItemParamsSeparator).R
		end, function(a,b) return tostring(a)<tostring(b) end):Join(lib.NavMeshItemsSeparator).R
	end
	function fallback:ParamsSerializeSorted()
		return from(self.Params):SelSort(function(name, numOrStr)
			return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
		end, function(a,b) return tostring(a)<tostring(b) end):Join(lib.NavMeshItemsSeparator).R
	end
	function lib.DeserializeNavMesh(serialized)
		serialized = serialized:gsub("\r\n", "\n")
		serialized = serialized:gsub("\r", "\n")
		serialized = serialized:gsub(lib.NavMeshItemsSeparatorOld, lib.NavMeshItemsSeparator)
		local navMesh = lib.NewNavMesh()
		for idx, serializedItem in ipairs(lib.GetSplitStr(serialized, lib.NavMeshItemsSeparator)) do
			local serializedId, serializedParams = unpack(serializedItem:Split(lib.NavMeshItemIdParamsPairSeparator))
			local item = navMesh:ForceGetItem(lib.DeserializeNavMeshItemId(serializedId))
			for idx, serializedParam in ipairs(lib.GetSplitStr(serializedParams, lib.NavMeshItemParamsSeparator)) do
				item:SetParam(unpack(serializedParam:Split(lib.NavMeshItemParamNameNumPairSeparator)))
			end
		end
		return navMesh
	end
	function fallback:DeserializeNavMeshParams(serialized)
		for idx, serializedItem in ipairs(lib.GetSplitStr(serialized, lib.NavMeshItemsSeparator)) do
			local serializedName, serializedNumOrStr = unpack(serializedItem:Split(lib.NavMeshItemParamNameNumPairSeparator))
			self:SetParam(serializedName, serializedNumOrStr)
		end
	end
	function lib.DeserializeNavMeshItemId(serializedId) return tonumber(serializedId) or serializedId end
end
