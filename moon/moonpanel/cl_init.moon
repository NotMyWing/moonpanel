Moonpanel.Initialize = =>
	@Initialized = true
	@InitFocus!
	@InitControl!

	-- Ask the server to provide info about every single panel in the game.
	for entity in *ents.GetAll!
		continue unless entity.Moonpanel and entity.GetCanvas

		canvas = entity\GetCanvas!
		if not canvas\GetData!
			Moonpanel.Net.PanelRequestData entity, (panel, data) ->
				canvas\ImportData data.panelData
				canvas\ImportPlayData data.playData

hook.Add "InitPostEntity", "TheMP Initialize", ->
	Moonpanel\Initialize!

if Moonpanel.Initialized
	Moonpanel\Initialize!
