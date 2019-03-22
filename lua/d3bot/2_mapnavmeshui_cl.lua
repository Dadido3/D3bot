
return function(lib)
	local from = lib.From

	local isEnabled = false
	local hooksId = tostring({})
	
	local cursoredItemOrNil
	
	local isPathPieceById = {}
	function lib.SetShownMapNavMeshPath(ids)
		isPathPieceById = {}
		local previousId
		for k, id in ipairs(ids) do
			isPathPieceById[id] = true
			if previousId then
				isPathPieceById[previousId .. lib.NavMeshLinkNodesSeparator .. id] = true
				isPathPieceById[id .. lib.NavMeshLinkNodesSeparator .. previousId] = true
			end
			previousId = id
		end
	end
	
	local isHighlightedById = {}
	function lib.HighlightInMapNavMeshView(id) isHighlightedById[id] = true end
	function lib.ClearMapNavMeshViewHighlights() isHighlightedById = {} end
	
	local function getItemColor(item) return lib.Color[isHighlightedById[item.Id] and "Green" or (item == cursoredItemOrNil and "Orange" or (isPathPieceById[item.Id] and "Yellow" or "Red"))] end
	local function getOutlineColor(item) return lib.Color[isHighlightedById[item.Id] and "Green" or (item == cursoredItemOrNil and "Orange" or "Black")] end
	
	local isHiddenParamByParamName = from((" "):Explode("X Y Z AreaXMin AreaYMin AreaXMax AreaYMax")):VsSet().R
	
	local nodeVisualProperties = {}
	local nodeVisualPropertiesQueue = {}
	
	local function isNodeIdHighlightedOrSelected(id) return isHighlightedById[id] or (cursoredItemOrNil and cursoredItemOrNil.Id == id) end
	local function isNodeIdVisible(id) return isNodeIdHighlightedOrSelected(id) or nodeVisualProperties[id] and not nodeVisualProperties[id].ShouldHide end
	
	function lib.SetIsMapNavMeshViewEnabled(bool)
		local forceDrawInSkybox = false
		local forceDrawInSkyboxCounter = 0
		if isEnabled == bool then return end
		isEnabled = bool
		if isEnabled then
			nodeVisualProperties = {}
			hook.Add("Think", hooksId, function()
				cursoredItemOrNil = lib.MapNavMesh:GetCursoredItemOrNil(LocalPlayer())
				
				local smartDraw = D3bot.Convar_Navmeshing_SmartDraw:GetBool()
				if smartDraw then
					-- Add nodes to visual property queue
					if #nodeVisualPropertiesQueue == 0 then
						for id, node in pairs(lib.MapNavMesh.NodeById) do
							table.insert(nodeVisualPropertiesQueue, {Id = id})
						end
					end
					-- Check visibility of the queue elements
					local eyePos = EyePos()
					for i = 1, 20 do
						local queueElement = table.remove(nodeVisualPropertiesQueue)
						if not queueElement then break end
						local id = queueElement.Id
						local node = lib.MapNavMesh.NodeById[id]
						if node then
							local visualProperty = {}
							if node:IsViewBlocked(eyePos) then
								visualProperty.TraceBlocked = true
								visualProperty.ShouldHide = true
								for node, link in pairs(node.LinkByLinkedNode) do
									if nodeVisualProperties[node.Id] and not nodeVisualProperties[node.Id].TraceBlocked then
										visualProperty.ShouldHide = false
										break
									end
								end
							end
							nodeVisualProperties[id] = visualProperty
						end
					end
				end
				
			end)
			hook.Add("PostDrawOpaqueRenderables", hooksId, function(bDrawingDepth, bDrawingSkybox)
				if forceDrawInSkyboxCounter > 1 then
					forceDrawInSkybox = true
					print("D3bot: Force drawing of navmesh in skybox, it won't draw correctly otherwise.")
				end
				if not forceDrawInSkybox and bDrawingSkybox then
					forceDrawInSkyboxCounter = forceDrawInSkyboxCounter + 1
					return
				end
				forceDrawInSkyboxCounter = 0
				local smartDraw = D3bot.Convar_Navmeshing_SmartDraw:GetBool()
				local eyePos = EyePos()
				render.SetColorMaterial()
				if not smartDraw then
					cam.IgnoreZ(true)
				end
				for id, node in pairs(lib.MapNavMesh.NodeById) do
					if smartDraw and isNodeIdHighlightedOrSelected(id) then
						cam.IgnoreZ(true)
					end
					if not smartDraw or isNodeIdVisible(id) then
						if node.HasArea then
							local z = node.Pos.z + 0.2
							local params = node.Params
							for k, cullMode in ipairs{ MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW } do
								render.CullMode(cullMode)
								render.DrawQuad(
									Vector(params.AreaXMin, params.AreaYMin, z),
									Vector(params.AreaXMin, params.AreaYMax, z),
									Vector(params.AreaXMax, params.AreaYMax, z),
									Vector(params.AreaXMax, params.AreaYMin, z),
									getItemColor(node).EightAlpha)
							end
						end
						render.DrawSphere(node.Pos, 2, 8, 8, getItemColor(node))
					end
					if smartDraw and isNodeIdHighlightedOrSelected(id) then
						cam.IgnoreZ(false)
					end
				end
				for id, link in pairs(lib.MapNavMesh.LinkById) do
					local nodeA, nodeB = unpack(link.Nodes)
					if smartDraw and isNodeIdHighlightedOrSelected(id) then
						cam.IgnoreZ(true)
					end
					if not smartDraw or isNodeIdVisible(nodeA.Id) and isNodeIdVisible(nodeB.Id) then
						render.DrawBeam(nodeA.Pos + Vector(0, 0, 1), nodeB.Pos + Vector(0, 0, 1), 1, 0, 1, getItemColor(link))
					end
					if smartDraw and isNodeIdHighlightedOrSelected(id) then
						cam.IgnoreZ(false)
					end
				end
				if not smartDraw then
					cam.IgnoreZ(false)
				end
				for id, node in pairs(lib.MapNavMesh.NodeById) do
					if node.HasArea and node.Pos:Distance(eyePos) < 500 and (not smartDraw or isNodeIdVisible(id)) then
						local z = node.Pos.z + 0.2
						local params = node.Params
						local color = getOutlineColor(node)
						local vec1 = Vector(params.AreaXMin, params.AreaYMin, z)
						local vec2 = Vector(params.AreaXMin, params.AreaYMax, z)
						local vec3 = Vector(params.AreaXMax, params.AreaYMax, z)
						local vec4 = Vector(params.AreaXMax, params.AreaYMin, z)
						render.DrawLine(vec1, vec2, color, true)
						render.DrawLine(vec2, vec3, color, true)
						render.DrawLine(vec3, vec4, color, true)
						render.DrawLine(vec4, vec1, color, true)
						render.DrawLine(vec1, vec1 + Vector(0, 0, 10), color, true)
						render.DrawLine(vec2, vec2 + Vector(0, 0, 10), color, true)
						render.DrawLine(vec3, vec3 + Vector(0, 0, 10), color, true)
						render.DrawLine(vec4, vec4 + Vector(0, 0, 10), color, true)
						render.DrawLine(vec1, node.Pos + Vector(0, 0, 0.2), color, true)
						render.DrawLine(vec2, node.Pos + Vector(0, 0, 0.2), color, true)
						render.DrawLine(vec3, node.Pos + Vector(0, 0, 0.2), color, true)
						render.DrawLine(vec4, node.Pos + Vector(0, 0, 0.2), color, true)
					end
				end
			end)
			hook.Add("HUDPaint", hooksId, function()
				local smartDraw = D3bot.Convar_Navmeshing_SmartDraw:GetBool()
				surface.SetFont("Default")
				local eyePos = EyePos()
				for id, item in pairs(lib.MapNavMesh.ItemById) do
					local isCursored = item == cursoredItemOrNil
					local itemPos = item:GetFocusPos()
					if isCursored or itemPos:Distance(eyePos) <= 500 then
						local pos = itemPos:ToScreen()
						if pos.visible and (not smartDraw or isNodeIdVisible(id)) then
							local paramsQuery = from(item.Params)
							if not isCursored then paramsQuery:Where(function(name) return not isHiddenParamByParamName[name] end) end
							local txt = item.Id .. ":\n" .. paramsQuery:Sel(function(name, v) return nil, name .. " = " .. v end):Sort():Join("\n").R
							local txtW, txtH = surface.GetTextSize(txt)
							local w = txtW + 10
							local h = txtH + 10
							surface.SetDrawColor(lib.Color.White.HalfAlpha)
							surface.DrawRect(pos.x, pos.y, w, h)
							surface.SetDrawColor(lib.Color.Black)
							surface.DrawOutlinedRect(pos.x, pos.y, w, h)
							draw.DrawText(txt, "Default", pos.x + 5, pos.y + 5, lib.Color.Black)
						end
					end
				end
			end)
		else
			hook.Remove("Think", hooksId)
			hook.Remove("PostDrawOpaqueRenderables", hooksId)
			hook.Remove("HUDPaint", hooksId)
		end
	end
end
