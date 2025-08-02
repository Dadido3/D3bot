
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
	local selectedNodeIDs = {} -- Contains the same information as `isHighlightedById`, but is sorted by selection order.
	function lib.HighlightInMapNavMeshView(id) isHighlightedById[id] = true table.insert(selectedNodeIDs, id) end
	function lib.ClearMapNavMeshViewHighlights() isHighlightedById, selectedNodeIDs = {}, {} end
	
	local function getItemColor(item) return lib.Color[isHighlightedById[item.Id] and "Green" or (item == cursoredItemOrNil and "Orange" or (isPathPieceById[item.Id] and "Yellow" or "Red"))] end
	local function getOutlineColor(item) return lib.Color[isHighlightedById[item.Id] and "Green" or (item == cursoredItemOrNil and "Orange" or "Black")] end
	
	local isHiddenParamByParamName = from((" "):Explode("X Y Z AreaXMin AreaYMin AreaXMax AreaYMax")):VsSet().R
	
	local nodeVisualProperties = {}
	local nodeVisualPropertiesQueue = {}
	
	local function isNodeIdHighlightedOrSelected(id) return isHighlightedById[id] or (cursoredItemOrNil and cursoredItemOrNil.Id == id) end
	local function isNodeIdVisible(id) return isNodeIdHighlightedOrSelected(id) or nodeVisualProperties[id] and not nodeVisualProperties[id].ShouldHide end
	
	---Returns the position that the local player is looking at.
	---@param pl GPlayer
	---@return GVector|nil
	local function getCursoredPosOrNil(pl)
		local trR = pl:GetEyeTrace()
		if not trR.Hit then return nil end
		return trR.HitPos
	end

	local function getCursoredDirection(ang) return math.Round(math.abs(math.abs(ang) - 90) / 90) end
	local function getCursoredAxisName(pl, excludeZOrNil)
		local angs = pl:EyeAngles()
		if not excludeZOrNil and getCursoredDirection(angs.p) == 0 then return "Z" end
		return getCursoredDirection(angs.y) == 1 and "X" or "Y"
	end

	local function round(num) return math.Round(num * 10) / 10 end

	-- Client side list of edit modes.
	-- Any edits have to be in sync with the server side list of edit modes.
	local editModes = {
		{ Name = "Create Node" },
		{ Name = "Link Nodes" },
		{ Name = "Merge/Split/Extend Nodes" },
		{ Name = "Reposition Node" },
		{ Name = "Resize Node Area" },
		{ Name = "Copy Nodes" },
		{ Name = "Set/Unset Last Parameter" },
		{ Name = "Delete Item or Area" },
	}

	function lib.SetIsMapNavMeshViewEnabled(bool)
		local forceDrawInSkybox = false
		local forceDrawInSkyboxCounter = 0
		if isEnabled == bool then return end
		isEnabled = bool
		if isEnabled then
			nodeVisualProperties = {}
			hook.Add("Think", hooksId, function()
				if not lib.MapNavMesh then return end
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
				if not lib.MapNavMesh then return end
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
				local previewDraw = D3bot.Convar_Navmeshing_PreviewTool:GetBool()
				local maxDrawingDistanceSqr = math.pow(D3bot.Convar_Navmeshing_DrawDistance:GetInt(), 2)
				local eyePos = EyePos()
				render.SetColorMaterial()
				if not smartDraw then
					cam.IgnoreZ(true)
				end

				local inViewRange = true
				for id, node in pairs(lib.MapNavMesh.NodeById) do
					if maxDrawingDistanceSqr > 0 then
						inViewRange = node.Pos:DistToSqr(eyePos) <= maxDrawingDistanceSqr
					end

					if inViewRange or isNodeIdHighlightedOrSelected(id) then
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
				end

				local inViewRange = true
				for id, link in pairs(lib.MapNavMesh.LinkById) do
					local nodeA, nodeB = unpack(link.Nodes)
					if maxDrawingDistanceSqr > 0 then
						inViewRange = link:GetFocusPos():DistToSqr(eyePos) <= maxDrawingDistanceSqr
					end

					if inViewRange or isNodeIdHighlightedOrSelected(id) then
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
				end
				
				if previewDraw then
					local editmodeid = lib.MapNavMeshEditMode
					local hitPos = getCursoredPosOrNil(LocalPlayer())
					if hitPos then
						local pos = hitPos
						if editmodeid == 1 or editmodeid == 4 then -- Create Node / Reposition Node
							render.DrawSphere(pos, 2, 8, 8, lib.Color["Red"])
							if editmodeid == 4 then
								for nodeID in pairs(isHighlightedById) do
									local node = lib.MapNavMesh.NodeById[nodeID]
									if node then

										local area = getCursoredAxisName(LocalPlayer())

										if area == "X" then
											render.DrawSphere(Vector(pos.x, node.Pos.y, node.Pos.z), 2, 8, 8, lib.Color["Red"].HalfAlpha)
										elseif area == "Y" then
											render.DrawSphere(Vector(node.Pos.x, pos.y, node.Pos.z), 2, 8, 8, lib.Color["Red"].HalfAlpha)
										elseif area == "Z" then
											render.DrawSphere(Vector(node.Pos.x, node.Pos.y, pos.z), 2, 8, 8, lib.Color["Red"].HalfAlpha)

											if node.HasArea then
												for _, cullMode in ipairs{MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW} do
													render.CullMode(cullMode)
													render.DrawQuad(
														Vector(node.Params.AreaXMin, node.Params.AreaYMin, pos.z + 0.4),
														Vector(node.Params.AreaXMin, node.Params.AreaYMax, pos.z + 0.4),
														Vector(node.Params.AreaXMax, node.Params.AreaYMax, pos.z + 0.4),
														Vector(node.Params.AreaXMax, node.Params.AreaYMin, pos.z + 0.4),
														lib.Color["Red"].HalfAlpha)
												end
											end
										end

									end
								end
							end
						elseif editmodeid == 2 then -- Link Node
							for nodeid, _ in pairs(isHighlightedById) do
								if lib.MapNavMesh.NodeById[nodeid] then
									if cursoredItemOrNil then
										pos = cursoredItemOrNil.Pos
									else
										pos = hitPos
									end

									render.DrawBeam(lib.MapNavMesh.NodeById[nodeid].Pos + Vector(0, 0, 1), pos + Vector(0, 0, 1), 1, 0, 1, lib.Color["Red"])
								end
							end
						elseif ( editmodeid == 3 or editmodeid == 5 ) then -- Merge/Split/Extend Nodes / Resize Node Area
							for nodeid, _ in pairs(isHighlightedById) do
								local node = lib.MapNavMesh.NodeById[nodeid]
								if node and node.HasArea then
									if not (smartDraw and isNodeIdHighlightedOrSelected(nodeid)) then
										cam.IgnoreZ(true)
									end

									local z = node.Pos.z + 0.4
									local params = node.Params

									local area = getCursoredAxisName(LocalPlayer(), true)

									pos = hitPos

									local xmin, ymin = params.AreaXMin, params.AreaYMin
									local xmax, ymax = params.AreaXMax, params.AreaYMax

									local ext = false
									if area == "X" then
										if params.AreaXMax > pos.x and params.AreaXMin < pos.x then
											xmin = params.AreaXMin
											xmax = params.AreaXMax
											ymin = params.AreaYMin
											ymax = params.AreaYMax

											ext = true
										else
											ext = false
										end

										if not ext then
											if xmin < pos.x then
												xmin = pos.x
											end

											if xmax > pos.x then
												xmax = pos.x
											end
										end
									else
										if params.AreaYMax > pos.y and params.AreaYMin < pos.y then
											xmin = params.AreaXMin
											xmax = params.AreaXMax
											ymin = params.AreaYMin
											ymax = params.AreaYMax

											ext = true
										else
											ext = false
										end

										if not ext then
											if ymin < pos.y then
												ymin = pos.y
											end

											if ymax > pos.y then
												ymax = pos.y
											end
										end
									end

									if not cursoredItemOrNil then
										if not smartDraw or isNodeIdVisible(nodeid) then
											if ext then
												pos = hitPos

												local vec2, vec3, vec4
												if area == "X" then
													vec2 = Vector(xmin, ymax, z)
													vec3 = Vector(pos.x, ymax, z)
													vec4 = Vector(pos.x, ymin, z)
												else
													vec2 = Vector(xmin, pos.y, z)
													vec3 = Vector(xmax, pos.y, z)
													vec4 = Vector(xmax, ymin, z)
												end

												if area == "X" then
													render.DrawLine(vec3, vec4, lib.Color["Red"], true)

													if editmodeid ~= 5 then
														render.DrawSphere(Vector(((xmax + xmin) / 2), node.Pos.y, z) + Vector((pos.x - xmin) / 2, 0, 0), 2, 8, 8, lib.Color["Red"])
														render.DrawSphere(Vector(((xmax + xmin) / 2), node.Pos.y, z) + Vector((pos.x - xmax) / 2, 0, 0), 2, 8, 8, lib.Color["Red"])
													end
												else
													render.DrawLine(vec2, vec3, lib.Color["Red"], true)

													if editmodeid ~= 5 then
														render.DrawSphere(Vector(node.Pos.x, (ymax + ymin) / 2, z) + Vector(0, (pos.y - ymin) / 2, 0), 2, 8, 8, lib.Color["Red"])
														render.DrawSphere(Vector(node.Pos.x, (ymax + ymin) / 2, z) + Vector(0, (pos.y - ymax) / 2, 0), 2, 8, 8, lib.Color["Red"])
													end
												end
											else
												for _, cullMode in ipairs{MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW} do
													render.CullMode(cullMode)
													render.DrawQuad(
														Vector(xmin, ymin, z),
														Vector(xmin, ymax, z),
														Vector(xmax, ymax, z),
														Vector(xmax, ymin, z),
														lib.Color["Red"].EightAlpha)
												end

												if editmodeid ~= 5 then
													if area == "X" then
														render.DrawSphere(Vector((xmax + xmin) / 2, node.Pos.y, z), 2, 8, 8, lib.Color["Red"])
													else
														render.DrawSphere(Vector(node.Pos.x, (ymax + ymin) / 2, z), 2, 8, 8, lib.Color["Red"])
													end
												end
											end
										end
									end

									if not (smartDraw and isNodeIdHighlightedOrSelected(nodeid)) then
										cam.IgnoreZ(false)
									end
								end
							end
						elseif editmodeid == 6 then -- Copy Node

							local cursoredPos = getCursoredPosOrNil(LocalPlayer())
							if cursoredPos then
								local cursoredAxisName = getCursoredAxisName(LocalPlayer())
								local axisOffset
								for _, nodeID in ipairs(selectedNodeIDs) do
									local node = lib.MapNavMesh.NodeById[nodeID]
									if node then
										if not axisOffset then axisOffset = round(cursoredPos[cursoredAxisName] - node.Pos[cursoredAxisName]) end

										local xMin, yMin = node.Params.AreaXMin or node.Pos.x, node.Params.AreaYMin or node.Pos.y
										local xMax, yMax = node.Params.AreaXMax or node.Pos.x, node.Params.AreaYMax or node.Pos.y
										local x, y, z = node.Pos.x, node.Pos.y, node.Pos.z + 0.4

										if cursoredAxisName == "X" then
											xMin, xMax, x = xMin + axisOffset, xMax + axisOffset, x + axisOffset
										elseif cursoredAxisName == "Y" then
											yMin, yMax, y = yMin + axisOffset, yMax + axisOffset, y + axisOffset
										elseif cursoredAxisName == "Z" then
											z = z + axisOffset
										end

										for _, cullMode in ipairs{MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW} do
											render.CullMode(cullMode)

											render.DrawQuad(
												Vector(xMin, yMin, z),
												Vector(xMin, yMax, z),
												Vector(xMax, yMax, z),
												Vector(xMax, yMin, z),
												lib.Color["Red"].HalfAlpha
											)
										end
										render.DrawSphere(Vector(x, y, z), 2, 8, 8, lib.Color["Red"].HalfAlpha)
									end
								end
							end
						end

					end
				end

				if not smartDraw then
					cam.IgnoreZ(false)
				end

				local maxDrawingDistanceSqr = math.pow(math.min(D3bot.Convar_Navmeshing_DrawDistance:GetInt(), 500), 2)
				if maxDrawingDistanceSqr <= 0 then maxDrawingDistanceSqr = 500*500 end
				for id, node in pairs(lib.MapNavMesh.NodeById) do
					if node.Pos:DistToSqr(eyePos) <= maxDrawingDistanceSqr and (not smartDraw or isNodeIdVisible(id)) then
						if node.HasArea then
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
						if node.Params.MaxHeight then
							local color = getOutlineColor(node)
							local vec1 = node.Pos
							local vec2 = vec1 + Vector(0, 0, node.Params.MaxHeight)
							render.DrawLine(vec1, vec2, color, true)
						end
					end
				end
			end)
			hook.Add("HUDPaint", hooksId, function()
				if not lib.MapNavMesh then return end
				local smartDraw = D3bot.Convar_Navmeshing_SmartDraw:GetBool()
				local maxDrawingDistanceSqr = math.pow(math.min(D3bot.Convar_Navmeshing_DrawDistance:GetInt(), 500), 2)
				if maxDrawingDistanceSqr <= 0 then maxDrawingDistanceSqr = 500*500 end
				surface.SetFont("Default")
				local eyePos = EyePos()
				for id, item in pairs(lib.MapNavMesh.ItemById) do
					local isCursored = item == cursoredItemOrNil
					local itemPos = item:GetFocusPos()
					if isCursored or itemPos:DistToSqr(eyePos) <= maxDrawingDistanceSqr then
						local pos = itemPos:ToScreen()
						if pos.visible and (not smartDraw or isNodeIdVisible(id)) then
							local paramsQuery = from(item.Params)
							if not isCursored then paramsQuery:Where(function(name) return not isHiddenParamByParamName[name] end) end
							local txt = item.Id .. ":\n" .. paramsQuery:Sel(function(name, v) return nil, name .. " = " .. v end):Sort():Join("\n").R
							local txtW, txtH = surface.GetTextSize(txt)
							local w = txtW + 10
							local h = txtH + 10
							surface.SetDrawColor(lib.Color.White.HalfAlpha:Unpack())
							surface.DrawRect(pos.x, pos.y, w, h)
							surface.SetDrawColor(lib.Color.Black:Unpack())
							surface.DrawOutlinedRect(pos.x, pos.y, w, h)
							draw.DrawText(txt, "Default", pos.x + 5, pos.y + 5, lib.Color.Black)
						end
					end
				end

				local editmodeid = lib.MapNavMeshEditMode
				for i, mod in ipairs(editModes) do
					draw.SimpleText(string.format("[%s] %s", i, mod.Name), "HudDefault", 100, ScrH()/2+(i*20), editmodeid == i and lib.Color.Red or lib.Color.White)
				end
			end)
		else
			hook.Remove("Think", hooksId)
			hook.Remove("PostDrawOpaqueRenderables", hooksId)
			hook.Remove("HUDPaint", hooksId)
		end
	end
end

