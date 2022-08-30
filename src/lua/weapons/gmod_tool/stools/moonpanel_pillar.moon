TOOL.Category = "Neeve's Addons"
TOOL.Name = "The Witness - Moonpanel Pillar"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.AddToMenu = false

TOOL.ClientConVar.Radius = "48"
TOOL.ClientConVar.Height = "96"
TOOL.ClientConVar.SeamYaw = "0"
TOOL.ClientConVar.FitCells = "0"

if SERVER
	createPillar = (ply, pos, angle, radius, height, fitCells = false, tileData) ->
		-- Retained for compatibility with old references; pillar spawning is disabled.
		false

	TOOL.LeftClick = (trace) =>
		false

	TOOL.RightClick = =>
		false

	TOOL.Reload = (trace) =>
		false
else
	PREVIEW_MATERIAL = Material "models/debug/debugwhite"
	language.Add "Tool.moonpanel_pillar.name", "Moonpanel Pillar"
	language.Add "Tool.moonpanel_pillar.desc", "Spawns a stationary cylindrical Moonpanel."
	TOOL.Information = {
		{ name: "left", text: "Spawn/update a pillar" }
		{ name: "right", text: "Open the pillar editor" }
		{ name: "reload", text: "Copy pillar dimensions" }
	}
	TOOL.BuildCPanel = (panel) ->
		panel\AddControl "Header", { Text: "#Tool.moonpanel_pillar.name", Description: "#Tool.moonpanel_pillar.desc" }
		panel\NumSlider "Radius", "moonpanel_pillar_Radius", 16, 256, 0
		panel\NumSlider "Height", "moonpanel_pillar_Height", 32, 512, 0
		panel\NumSlider "Seam yaw", "moonpanel_pillar_SeamYaw", -180, 180, 0
		panel\CheckBox "Fit square cells", "moonpanel_pillar_FitCells"
	TOOL.DrawHUD = =>
		return if Moonpanel\IsFocused @GetOwner!
		trace = util.TraceLine util.GetPlayerTrace @GetOwner!
		return unless trace.Hit and Moonpanel.Canvas.GetPillarMesh
		radius = math.Clamp @GetClientNumber("Radius", 48), 16, 256
		height = math.Clamp @GetClientNumber("Height", 96), 32, 512
		if @GetClientNumber("FitCells", 0) ~= 0
			data = Moonpanel.Editor and Moonpanel.Editor.CurrentData
			if data and data.Meta and data.Meta.Width > 0
				height = math.Clamp math.pi * 2 * radius * data.Meta.Height /
					data.Meta.Width, 32, 512
		segments = if radius >= 128 then 128 elseif radius >= 48 then 64 else 32
		matrix = Matrix!
		matrix\SetTranslation trace.HitPos
		matrix\SetAngles Angle(0, @GetClientNumber("SeamYaw", 0), 0)
		matrix\Scale Vector radius, radius, height
		cam.Start3D!
		render.SetMaterial PREVIEW_MATERIAL
		render.SetColorModulation 0.28, 0.78, 1
		render.SetBlend 0.28
		cam.PushModelMatrix matrix
		Moonpanel.Canvas.GetPillarMesh(segments)\Draw!
		cam.PopModelMatrix!
		render.SetBlend 1
		render.SetColorModulation 1, 1, 1
		cam.End3D!
	TOOL.LeftClick = -> true
	TOOL.RightClick = -> true
	TOOL.Reload = -> true
