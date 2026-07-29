-- Optional WireMod compatibility. This module only translates the
-- authoritative panel lifecycle into stable Wire inputs and outputs.

Moonpanel.Wire or= {}
Moonpanel.Wire.PathMaxLength = 512

Moonpanel.Wire.Trigger = (panel, name, value) ->
	return unless SERVER and IsValid(panel) and WireLib and
		WireLib.TriggerOutput and panel.WireOutputs
	WireLib.TriggerOutput panel, name, value

Moonpanel.Wire.Pulse = (panel, name) ->
	Moonpanel.Wire.Trigger panel, name, 1
	Moonpanel.Wire.Trigger panel, name, 0

Moonpanel.Wire.UpdateState = (panel) ->
	return unless SERVER and IsValid(panel) and WireLib and panel.WireOutputs
	state = panel\GetWireState!
	return unless state
	Moonpanel.Wire.Trigger panel, "Powered", state.powered and 1 or 0
	Moonpanel.Wire.Trigger panel, "Solved", state.solved and 1 or 0
	Moonpanel.Wire.Trigger panel, "Errored", state.errored and 1 or 0
	Moonpanel.Wire.Trigger panel, "Path", state.path or ""

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
	event = panel\HandleWireTerminalResult result, Moonpanel.Wire.PathMaxLength
	return unless event
	Moonpanel.Wire.Trigger panel, "Path", event.path
	Moonpanel.Wire.Trigger panel, "Erased", event.erased
	if event.aborted
		Moonpanel.Wire.Pulse panel, "AbortedPulse"
	elseif event.solved
		Moonpanel.Wire.Pulse panel, "SolvedPulse"
	else
		Moonpanel.Wire.Pulse panel, "FailedPulse"
	Moonpanel.Wire.UpdateState panel
