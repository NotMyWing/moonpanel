TOOL.Category = "Neeve's Addons"
TOOL.Name = "The Witness - Moonpanel Pillar"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.AddToMenu = false

TOOL.ClientConVar.radius = "48"
TOOL.ClientConVar.height = "96"
TOOL.ClientConVar.seam_yaw = "0"
TOOL.ClientConVar.fit_cells = "0"

if SERVER
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
		panel\NumSlider "Radius", "moonpanel_pillar_radius", 16, 256, 0
		panel\NumSlider "Height", "moonpanel_pillar_height", 32, 512, 0
		panel\NumSlider "Seam yaw", "moonpanel_pillar_seam_yaw", -180, 180, 0
		panel\CheckBox "Fit square cells", "moonpanel_pillar_fit_cells"
	TOOL.DrawHUD = =>
		return if Moonpanel\IsFocused @GetOwner!
		trace = util.TraceLine util.GetPlayerTrace @GetOwner!
		return unless trace.Hit and Moonpanel.Canvas.GetPillarMesh
		radius = math.Clamp @GetClientNumber("radius", 48), 16, 256
		height = math.Clamp @GetClientNumber("height", 96), 32, 512
		if @GetClientNumber("fit_cells", 0) ~= 0
			data = Moonpanel.Editor and Moonpanel.Editor.CurrentData
			if data and data.Meta and data.Meta.Width > 0
				height = math.Clamp math.pi * 2 * radius * data.Meta.Height /
					data.Meta.Width, 32, 512
		segments = if radius >= 128 then 128 elseif radius >= 48 then 64 else 32
		matrix = Matrix!
		matrix\SetTranslation trace.HitPos
		matrix\SetAngles Angle(0, @GetClientNumber("seam_yaw", 0), 0)
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
