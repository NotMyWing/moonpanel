-- Optional WireMod compatibility. This module only translates the
-- authoritative panel lifecycle into stable Wire inputs and outputs.

Moonpanel.Wire or= {}
pathMaxLength = 512

trigger = (panel, name, value) ->
	return unless SERVER and IsValid(panel) and WireLib and
		WireLib.TriggerOutput and panel.WireOutputs
	WireLib.TriggerOutput panel, name, value

pulse = (panel, name) ->
	trigger panel, name, 1
	trigger panel, name, 0

erasedClues = (panel, result) ->
	values = {}
	erasures = result.feedback and result.feedback.erasures
	return values unless istable erasures
	canvas = panel\GetCanvas!
	for pair in *erasures
		index = tonumber pair and pair.targetIndex
		socket = index and canvas\GetSocketAtDataIndex index
		continue unless socket
		typeId = socket\GetSocketType!
		if typeId == Moonpanel.Canvas.SocketType.Path
			typeId = socket\IsHorizontal! and 3 or 2
		elseif typeId == Moonpanel.Canvas.SocketType.Intersection
			typeId = 4
		elseif typeId == Moonpanel.Canvas.SocketType.Cell
			typeId = 1
		else
			continue
		table.insert values, Vector socket\GetX!, socket\GetY!, typeId
	values

Moonpanel.Wire.UpdateState = (panel) ->
	return unless SERVER and IsValid(panel) and WireLib and panel.WireOutputs
	state = panel\GetWireState!
	return unless state
	trigger panel, "Powered", state.powered and 1 or 0
	trigger panel, "Solved", state.solved and 1 or 0
	trigger panel, "Errored", state.errored and 1 or 0
	trigger panel, "Path", state.path or ""

Moonpanel.Wire.Initialize = (panel) ->
	return unless SERVER and IsValid panel
	panel\ResetWireState!
	return unless WireLib
	return Moonpanel.Wire.UpdateState panel if panel.WireOutputs
	panel.WireInputs = WireLib.CreateInputs panel, { "TurnOff", "Reset" }
	panel.WireOutputs = WireLib.CreateOutputs panel, {
		"Powered"
		"Solved"
		"Errored"
		"SolvedPulse"
		"FailedPulse"
		"AbortedPulse"
		"Erased [ARRAY]"
		"Path [STRING]"
	}
	Moonpanel.Wire.UpdateState panel

Moonpanel.Wire.HandleResult = (panel, result) ->
	return unless SERVER and IsValid(panel) and result
	panel.__wirePath = panel\GetCanvas!\GetTracePath result.snapshot, pathMaxLength
	trigger panel, "Erased", erasedClues panel, result
	if result.aborted == true
		pulse panel, "AbortedPulse"
	elseif result.success == true
		pulse panel, "SolvedPulse"
	else
		pulse panel, "FailedPulse"
	Moonpanel.Wire.UpdateState panel
