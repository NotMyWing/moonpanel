AddCSLuaFile!

local panelSensitivity, gamepadDeadzone, gamepadSensitivity, boostMultiplier

if CLIENT
	Moonpanel.PillarMouseSamples = {}
	Moonpanel.PillarMouseZero = nil

	Moonpanel.ConsumePillarMouseInput = (cmd) =>
		commandNumber = cmd\CommandNumber!
		if commandNumber == 0
			sample = @PillarMouseZero
			@PillarMouseZero = nil
			return sample and sample.x or 0, sample and sample.y or 0
		sample = @PillarMouseSamples[commandNumber]
		@PillarMouseSamples[commandNumber] = nil
		sample and sample.x or 0, sample and sample.y or 0

	panelSensitivity = CreateClientConVar "moonpanel_trace_sensitivity", "1", true, false,
		"Relative panel trace sensitivity", 0.05, 8
	gamepadDeadzone = CreateClientConVar "moonpanel_gamepad_deadzone", "0.16", true, false,
		"Trace stick deadzone", 0, 0.95
	gamepadSensitivity = CreateClientConVar "moonpanel_gamepad_sensitivity", "1", true, false,
		"Trace controller sensitivity", 0.05, 8
	boostMultiplier = CreateClientConVar "moonpanel_trace_speed_boost", "2", true, false,
		"Controller trace boost", 1, 4

	Moonpanel.InitControl = =>
		ply = LocalPlayer!
		return false unless IsValid ply
		gui.EnableScreenClicker false
		if Moonpanel.Net and Moonpanel.Net.SyncClickerState
			Moonpanel.Net.SyncClickerState!
		ply\SetNW2VarProxy "TheMP Control", (owner, _, old, new) ->
			return if old == new
			return unless IsValid owner
			if Moonpanel\IsFocused owner
				if Moonpanel.Net and Moonpanel.Net.SyncClickerState
					Moonpanel.Net.SyncClickerState!
				else
					gui.EnableScreenClicker not (IsValid(new) and new.Moonpanel)
		true

	Moonpanel.GetPredictedControl = (ply = LocalPlayer!) =>
		return unless IsValid ply
		controlled = ply\GetNW2Entity "TheMP Control"
		if IsEntity(controlled) and IsValid(controlled) and controlled.Moonpanel
			session = Moonpanel.Net.TraceSessions[controlled]
			return controlled if session and not session.terminal and
				session.controller == ply
		for panel, session in pairs Moonpanel.Net.TraceSessions or {}
			return panel if not session.terminal and session.controller == ply and
				IsValid panel

	Moonpanel.RequestControl = (entity) =>
		ply = LocalPlayer!
		return unless IsValid ply
		controlled = Moonpanel\GetPredictedControl ply
		if IsEntity(controlled) and IsValid(controlled) and controlled.Moonpanel
			Moonpanel.Net.SendTraceAction controlled, 0
			return
		x, y = entity\GetCursorPos!
		Moonpanel.Net.PanelRequestControl entity, x, y if x and y

	Moonpanel.TraceAction = (entity) =>
		pathfinder = entity\GetCanvas!\GetPathFinder!
		action = pathfinder and pathfinder\canSubmit! and 1 or 0
		Moonpanel.Net.SendTraceAction entity, action

	Moonpanel.ApplyControllerTrace = (ply, cmd) =>
		return false if Moonpanel\IsPillarControlling ply
		return false unless ANALOG_JOY_X and ANALOG_JOY_Y and input.GetAnalogValue
		x = input.GetAnalogValue(ANALOG_JOY_X) or 0
		y = input.GetAnalogValue(ANALOG_JOY_Y) or 0
		if math.abs(x) > 1 or math.abs(y) > 1
			x /= 32767
			y /= 32767
		magnitude = math.sqrt x * x + y * y
		deadzone = gamepadDeadzone\GetFloat!
		return false if magnitude <= deadzone
		scaled = math.min(1, (magnitude - deadzone) / math.max(0.001, 1 - deadzone))
		x = x / magnitude * scaled
		y = y / magnitude * scaled
		tick = engine and engine.TickInterval and engine.TickInterval! or FrameTime!
		speed = 320 * gamepadSensitivity\GetFloat! * tick
		Moonpanel\ApplyDeltas ply, x * speed, y * speed, cmd\KeyDown(IN_SPEED)

	hook.Add "InputMouseApply", "TheMP Control", (cmd, x, y) ->
		if Moonpanel\IsPillarControlling LocalPlayer!
			commandNumber = cmd\CommandNumber!
			sample = { :x, :y }
			if commandNumber == 0
				Moonpanel.PillarMouseZero = sample
			else
				Moonpanel.PillarMouseSamples[commandNumber] = sample
				for oldNumber in pairs Moonpanel.PillarMouseSamples
					if oldNumber + 512 < commandNumber
						Moonpanel.PillarMouseSamples[oldNumber] = nil
			-- Facepunch's InputMouseApply contract requires clearing the angular
			-- deltas to freeze view rotation. StartCommand later replaces these
			-- fields with the accepted fixed-unit trace sample sent to the server.
			cmd\SetMouseX 0
			cmd\SetMouseY 0
			return true
		if Moonpanel\ApplyDeltas LocalPlayer!, x, y, cmd\KeyDown(IN_SPEED)
			cmd\SetMouseX 0
			cmd\SetMouseY 0
			true

else
	Moonpanel.RequestControl = (ply, entity, x, y, sensitivity = 1,
		gamepadSensitivity = 1, gamepadDeadzone = 0.16) =>
		controlled = ply\GetNW2Entity "TheMP Control"
		if IsEntity(controlled) and IsValid(controlled) and controlled.Moonpanel
			session = controlled\GetTraceSession! if controlled.GetTraceSession
			if session and session.controller == ply
				Moonpanel\StopControl ply
				return
			ply\SetNW2Entity "TheMP Control", game.GetWorld!
		if IsEntity(entity) and IsValid(entity)
			if entity.Moonpanel and entity.RequestControl
				accepted, reason = entity\RequestControl(ply, x, y, sensitivity,
					gamepadSensitivity, gamepadDeadzone)
				if accepted
					ply\SetNW2Entity "TheMP Control", entity
					return true
				return false, reason
		return false, "unknown"

	Moonpanel.StopControl = (ply) =>
		controlled = ply\GetNW2Entity "TheMP Control"
		if IsEntity(controlled) and IsValid(controlled) and controlled.Moonpanel
			controlled\StopControl ply
		ply\SetNW2Entity "TheMP Control", game.GetWorld!

Moonpanel.ApplyDeltas = (ply, dX = 0, dY = 0, boost = false) =>
	return false if dX == 0 and dY == 0
	return false unless IsValid ply
	return false if CLIENT and not Moonpanel\IsFocused(ply)
	controlled = ply\GetNW2Entity "TheMP Control"
	controlled = Moonpanel\GetPredictedControl(ply) if CLIENT and Moonpanel.GetPredictedControl
	return false unless IsEntity(controlled) and IsValid(controlled) and controlled.Moonpanel
	return false unless controlled\GetController! == ply

	if CLIENT
		session = Moonpanel.Net.TraceSessions[controlled]
		return false unless session and session.controller == ply
		dX, dY = controlled\TransformInputDeltas(dX, dY) if controlled.TransformInputDeltas
		canvas = controlled\GetCanvas!
		pathfinder = canvas\GetPathFinder!
		return false unless pathfinder and
			pathfinder.phase == Moonpanel.Canvas.TraceEngine.Phase.Tracing
		xQ, yQ = canvas\QuantizeDeltas dX, dY, panelSensitivity\GetFloat!
		xQ = math.Clamp xQ, -32767, 32767
		yQ = math.Clamp yQ, -32767, 32767
		return false if xQ == 0 and yQ == 0
		if boost
			factor = boostMultiplier\GetFloat! / 2
			xQ = math.Round xQ * factor
			yQ = math.Round yQ * factor
		xQ = math.Clamp xQ, -32767, 32767
		yQ = math.Clamp yQ, -32767, 32767
		unless CLIENT and Moonpanel\IsServerAuthoritativeTrace!
			canvas\ApplyTraceSample xQ, yQ, boost, ply
		Moonpanel.Net.QueueTraceSample controlled, xQ, yQ, boost,
			pathfinder\GetConstraintDecisions!
		return true

	false
