return unless CLIENT

Helpers = Moonpanel.Helpers

Helpers.clearChildren = (panel) ->
	return unless IsValid panel
	if panel.Clear
		panel\Clear!
		return
	target = panel.GetCanvas and panel\GetCanvas! or panel
	child\Remove! for child in *target\GetChildren!

Helpers.colorValue = (id) ->
	value = Moonpanel.Canvas.ColorValues[id] or Moonpanel.Canvas.ColorValues[Moonpanel.Color.White]
	Color value.r, value.g, value.b, value.a or 255

Helpers
