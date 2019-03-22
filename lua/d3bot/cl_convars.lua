CreateClientConVar("d3bot_navmeshing_enabled", 1, true, true, "Defines if the client is in the navmeshing mode.")
CreateClientConVar("d3bot_navmeshing_mode", "", true, true, "Defines the navmeshing mode, the user is in.")
CreateClientConVar("d3bot_navmeshing_reloadmodecycle", 1, true, true, "Defines if the client is in the navmeshing mode.")

D3bot.Convar_Navmeshing_SmartDraw = CreateClientConVar("d3bot_navmeshing_smartdraw", 1, true, true, "Automatically hides obscured nodes and links.")