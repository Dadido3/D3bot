function D3bot.OpenMeshingWindow()
	if IsValid(D3bot.MeshingWindow) then
		D3bot.MeshingWindow:Close()
	--	local dFrame = D3bot.MeshingWindow
	--	dFrame:SetVisible(true)
	--	--dFrame:MakePopup()
	--	return
	end
	
	local dFrame = vgui.Create("DFrame")
	dFrame:SetCookieName("d3bot_meshingwindow")
	local frameX, frameY, frameWidth, frameHeight = dFrame:GetCookieNumber("x", 50), dFrame:GetCookieNumber("y", 50), dFrame:GetCookieNumber("width", 300), dFrame:GetCookieNumber("height", 400)
	dFrame:SetSkin("Default")
	dFrame:SetPos(frameX, frameY)
	dFrame:SetSize(frameWidth, frameHeight)
	dFrame:SetTitle("D3bot Navmeshing")
	dFrame:SetVisible(true)
	dFrame:SetSizable(true)
	dFrame:SetDraggable(true)
	dFrame:ShowCloseButton(false)
	--dFrame:MakePopup()
	D3bot.MeshingWindow = dFrame
	
	-- Store window position every now and then
	timer.Remove(D3bot.BotHooksId.."MeshingWindowTimer")
	timer.Create(D3bot.BotHooksId.."MeshingWindowTimer", 10, 0, function()
		if not IsValid(dFrame) then
			timer.Remove(D3bot.BotHooksId.."MeshingWindowTimer")
			return
		end
		local x, y, width, height = dFrame:GetBounds()
		dFrame:SetCookie("x", tostring(x))
		dFrame:SetCookie("y", tostring(y))
		dFrame:SetCookie("width", tostring(width))
		dFrame:SetCookie("height", tostring(height))
	end)
	
	local propertySheet = vgui.Create("DPropertySheet", dFrame)
	propertySheet:Dock(FILL)
	
	local dPanel = vgui.Create("D3bot_MeshingMain", propertySheet)
	propertySheet:AddSheet("Main", dPanel, nil, false, false, "blaaaaaa")
	
	propertySheet:AddSheet("View", dPanel, nil, false, false, "blaaaaaa")
	
	propertySheet:AddSheet("Help", dPanel, nil, false, false, "blaaaaaa")
	
end