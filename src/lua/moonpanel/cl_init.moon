include "cl_debug.lua"

Moonpanel.Initialize = =>
	unless IsValid LocalPlayer!
		@Initialized = false
		return false
	unless @InitFocus! and @InitControl!
		@Initialized = false
		return false
	@Initialized = true

	-- Ask the server to provide info about every single panel in the game.
	for entity in *ents.GetAll!
		continue unless entity.Moonpanel and entity.GetCanvas

		canvas = entity\GetCanvas!
		if not canvas\GetData!
			Moonpanel.Net.PanelRequestData entity

	Moonpanel.Net.MaintainPanelDataRequests!
	true

hook.Add "InitPostEntity", "TheMP Initialize", ->
	Moonpanel\Initialize!

if Moonpanel.Initialized
	Moonpanel\Initialize!

timer.Create "TheMP Panel State Synchronization", 1, 0, ->
	Moonpanel\Initialize! unless Moonpanel.Initialized
	return unless Moonpanel.Initialized and Moonpanel.Net.MaintainPanelDataRequests
	Moonpanel.Net.MaintainPanelDataRequests!
