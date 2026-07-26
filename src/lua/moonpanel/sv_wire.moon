-- Optional WireMod compatibility. This module only translates the
-- authoritative panel lifecycle into stable Wire inputs and outputs.

Moonpanel.Wire or= {}
Moonpanel.Wire.PathMaxLength = 512

timerName = (panel) -> "TheMP_WireOutput_" .. tostring panel\EntIndex!

Moonpanel.Wire.ClearTimer = (panel) ->
	return unless SERVER and IsValid panel
	timer.Remove timerName panel

Moonpanel.Wire.Trigger = (panel, name, value) ->
	return unless SERVER and IsValid(panel) and WireLib and
		WireLib.TriggerOutput and panel.WireOutputs
	WireLib.TriggerOutput panel, name, value

Moonpanel.Wire.UpdateState = (panel) ->
	return unless SERVER and IsValid(panel) and WireLib and panel.WireOutputs
	state = panel\GetWireState! if panel.GetWireState
	return unless state
	Moonpanel.Wire.Trigger panel, "Powered", state.powered and 1 or 0
	Moonpanel.Wire.Trigger panel, "Solved", state.solved and 1 or 0
	Moonpanel.Wire.Trigger panel, "Errored", state.errored and 1 or 0
	Moonpanel.Wire.Trigger panel, "Success", state.success or 0
	Moonpanel.Wire.Trigger panel, "Path", state.path or ""

Moonpanel.Wire.Initialize = (panel) ->
	return unless SERVER and IsValid panel
	panel\ResetWireState! if panel.ResetWireState
	return unless WireLib
	return Moonpanel.Wire.UpdateState panel if panel.WireOutputs
	panel.WireInputs = WireLib.CreateInputs panel, { "TurnOff", "Reset" }
	panel.WireOutputs = WireLib.CreateOutputs panel, {
		"Powered"
		"Solved"
		"Errored"
		"Success"
		"SolvedPulse"
		"FailedPulse"
		"AbortedPulse"
		"Erased [ARRAY]"
		"Path [STRING]"
	}
	-- Compatibility aliases used by old third-party tooling.
	panel.Inputs = panel.WireInputs
	panel.Outputs = panel.WireOutputs
	Moonpanel.Wire.UpdateState panel

Moonpanel.Wire.BeginTrace = (panel) ->
	return unless SERVER and IsValid panel
	Moonpanel.Wire.ClearTimer panel
	panel\BeginWireTrace! if panel.BeginWireTrace
	Moonpanel.Wire.UpdateState panel

Moonpanel.Wire.Reset = (panel) ->
	return false unless SERVER and IsValid panel
	Moonpanel.Wire.ClearTimer panel
	panel\ResetWireState! if panel.ResetWireState
	return false unless panel.ResetPanel and panel\ResetPanel!
	Moonpanel.Wire.UpdateState panel
	true

Moonpanel.Wire.HandleResult = (panel, result) ->
	return unless SERVER and IsValid(panel) and result
	Moonpanel.Wire.ClearTimer panel
	event = panel\HandleWireTerminalResult result, Moonpanel.Wire.PathMaxLength
	return unless event
	Moonpanel.Wire.Trigger panel, "Path", event.path
	Moonpanel.Wire.Trigger panel, "Erased", event.erased
	if event.aborted
		Moonpanel.Wire.Trigger panel, "AbortedPulse", 1
		Moonpanel.Wire.Trigger panel, "AbortedPulse", 0
	elseif event.solved
		Moonpanel.Wire.Trigger panel, "SolvedPulse", 1
		Moonpanel.Wire.Trigger panel, "SolvedPulse", 0
		if event.delayedSuccess
			timer.Create timerName(panel), Moonpanel.Canvas.EraserRevealDelay or 0.75, 1, ->
				return unless IsValid panel
				panel\SetWireSuccess true if panel.SetWireSuccess
				Moonpanel.Wire.UpdateState panel
		else
			panel\SetWireSuccess true if panel.SetWireSuccess
	else
		Moonpanel.Wire.Trigger panel, "FailedPulse", 1
		Moonpanel.Wire.Trigger panel, "FailedPulse", 0
	Moonpanel.Wire.UpdateState panel
