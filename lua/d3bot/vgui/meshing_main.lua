local PANEL = {}

function PANEL:Init()
	local scroll = vgui.Create("DScrollPanel", self) -- Create the Scroll panel
	scroll:Dock(FILL)
	self.DScrollPanel = scroll
	
	local item = vgui.Create("DCheckBoxLabel", scroll)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetTextColor(Color(0, 0, 0))
	item:SetText("Enable")
	item:SetConVar("d3bot_navmeshing_enabled")
	
	local item = vgui.Create("DCheckBoxLabel", scroll)
	item:Dock(TOP)
	item:DockMargin(5, 5, 5, 5)
	item:SetTextColor(Color(0, 0, 0))
	item:SetText("Cycle mode with RELOAD")
	item:SetConVar("d3bot_navmeshing_reloadmodecycle")
	
	local list = vgui.Create("DListView", scroll)
	list:SetSize(nil, 200)
	list:Dock(TOP)
	list:SetMultiSelect(false)
	list:AddColumn("Mode")
	list:AddLine("Create Node")
	list:AddLine("Link Nodes")
	list:AddLine("Reposition Node")
	list:AddLine("Resize Node Area")
	list:AddLine("Copy Nodes")
	list:AddLine("Set/Unset Last Parameter")
	list:AddLine("Delete Item or Area")
	
	list.OnRowSelected = function(lst, index, pnl)
		print("Selected " .. pnl:GetColumnText( 1 ) .. " ( " .. pnl:GetColumnText( 2 ) .. " ) at index " .. index)
	end
	
	self:InvalidateLayout()
end

function PANEL:PerformLayout()
end

function PANEL:Think()
	
end

vgui.Register("D3bot_MeshingMain", PANEL, "DPanel")