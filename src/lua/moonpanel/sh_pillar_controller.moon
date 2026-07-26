AddCSLuaFile!

Controller = {}
Controller.States = {}
Controller.MaxLead = 10
Controller.MaxArcStep = 2
Controller.ContactSkin = 0.25
Controller.RadiusRecoveryTime = 0.75
Controller.RadiusQuantum = 16
Controller.RadiusSettleThreshold = 0.05
Controller.RadiusCorrectionDeadzone = 0.25
Controller.RadiusCorrectionGain = 2
Controller.RadiusCorrectionSpeed = 16
Controller.CommandRetention = 512

Moonpanel.PillarController = Controller
-- Compatibility names are read by the existing debug and focus presentation.
Moonpanel.PillarOrbits = Controller.States
Moonpanel.PillarFocusAngles or= {}

sign = (value) -> value > 0 and 1 or value < 0 and -1 or 0

tickInterval = ->
	engine and engine.TickInterval and engine.TickInterval! or 1 / 66

Controller.GetPanel = (ply) ->
	return false unless IsValid ply
	panel = if CLIENT and Moonpanel.GetPredictedControl
		Moonpanel\GetPredictedControl ply
	else
		ply\GetNW2Entity "TheMP Control"
	IsValid(panel) and panel.MoonpanelPillar == true and panel or false

Controller.GetFacingAngles = (panel, ply, pitch = nil, worldOrigin = nil) ->
	return unless IsValid(panel) and panel.MoonpanelPillar and IsValid ply
	origin = worldOrigin or ply\EyePos!
	center = panel\GetPillarAxisPoint origin
	look = center - origin
	look.z = 0
	return if look\LengthSqr! <= 0.0001
	lookAngle = look\Angle!
	Angle(pitch or math.Clamp(ply\EyeAngles!.p, -89, 89), lookAngle.y, 0)

Controller.GetState = (ply) -> Controller.States[ply]

Controller.GetDebugState = (ply) ->
	state = Controller.States[ply]
	state and state.debug or nil

Controller.IsRadiusSafe = (state, radius) ->
	Moonpanel.Canvas.GetPillarRadiusSafety radius, state.panel\GetPillarRadius!,
		state.hullRadius

Controller.MakeSeed = (panel, ply, sessionId) ->
	return unless IsValid(panel) and panel.MoonpanelPillar and IsValid ply
	position = ply\GetPos!
	mins, maxs = ply\GetHull!
	halfWidth = math.max math.abs(mins.x), math.abs(maxs.x)
	halfDepth = math.max math.abs(mins.y), math.abs(maxs.y)
	radius = position\Distance panel\GetPillarAxisPoint(position)
	pathfinder = panel\GetCanvas! and panel\GetCanvas!\GetPathFinder!
	head = pathfinder and pathfinder.cursors and pathfinder.cursors[1]
	return unless head
	{
		:sessionId
		revision: pathfinder.topology.revision
		radius: Moonpanel.Canvas.QuantizePillarRadius radius,
			Controller.RadiusQuantum
		playerAngle: panel\GetPillarAngle position
		headAngle: Moonpanel.Canvas.PillarTraceAngle head.x
		pitch: math.Clamp(ply\EyeAngles!.p, -89, 89)
		:mins
		:maxs
		hullRadius: math.sqrt(halfWidth^2 + halfDepth^2)
	}

Controller.Begin = (panel, ply, sessionId, seed = nil) ->
	return false unless IsValid(panel) and panel.MoonpanelPillar and IsValid ply
	return false unless ply\GetMoveType! == MOVETYPE_WALK
	seed or= Controller.MakeSeed panel, ply, sessionId
	return false unless seed and seed.sessionId == sessionId
	pathfinder = panel\GetCanvas! and panel\GetCanvas!\GetPathFinder!
	return false unless pathfinder and seed.revision == pathfinder.topology.revision
	defaultMins, defaultMaxs = ply\GetHull!
	state = {
		:panel
		:sessionId
		radius: tonumber(seed.radius) or 0
		mins: seed.mins or defaultMins
		maxs: seed.maxs or defaultMaxs
		hullRadius: tonumber(seed.hullRadius) or 23
		pitch: math.Clamp(tonumber(seed.pitch) or ply\EyeAngles!.p, -89, 89)
		ghostAngle: tonumber(seed.headAngle) or 0
		playerAngle: tonumber(seed.playerAngle) or 0
		commands: {}
		proofs: {}
		turnLatch: nil
		invalidRadiusSince: nil
		abortRequested: false
		debug: { clampReason: "none" }
	}
	return false unless Controller.IsRadiusSafe state, state.radius
	if SERVER
		state.motionPathfinder = Moonpanel.Canvas.TraceEngine pathfinder.topology
		return false unless state.motionPathfinder\restore pathfinder\snapshot!
		state.motionPathfinder.occlusionConstraint = pathfinder.occlusionConstraint
	Controller.States[ply] = state
	Moonpanel.PillarFocusAngles[ply] = Controller.GetFacingAngles panel, ply,
		state.pitch
	if SERVER
		session = panel\GetTraceSession! if panel.GetTraceSession
		if session and session.id == sessionId
			session.orbitSeed = table.Copy seed
			session.pillarProofs = state.proofs
	true

Controller.End = (ply, reason = "session_end") ->
	return unless ply
	state = Controller.States[ply]
	if state and IsValid(state.panel) and IsValid(ply)
		finalAngles = Controller.GetFacingAngles state.panel, ply, state.pitch
		if finalAngles
			Moonpanel.PillarFocusAngles[ply] = finalAngles
			ply\SetNW2Angle "TheMP FocusAngle", finalAngles if SERVER
		state.endReason = reason
	Controller.States[ply] = nil

Controller.ClearCommands = (ply) ->
	state = Controller.States[ply]
	if state
		state.commands = {}
		state.turnLatch = nil

Controller.UpdateAngles = (state, ply, pathfinder) ->
	playerAngle = state.panel\GetPillarAngle ply\GetPos!
	state.playerAngle = Moonpanel.Canvas.UnwrapPillarAngle playerAngle,
		state.playerAngle
	head = pathfinder and pathfinder.cursors and pathfinder.cursors[1]
	if head
		headAngle = Moonpanel.Canvas.PillarTraceAngle head.x
		state.ghostAngle = Moonpanel.Canvas.UnwrapPillarAngle headAngle,
			state.ghostAngle
	state.playerAngle, state.ghostAngle

Controller.ApplyCachedCommand = (state, ply, cmd, cached) ->
	cmd\ClearMovement!
	cmd\SetMouseX cached.xQ or 0
	cmd\SetMouseY cached.yQ or 0
	cmd\SetButtons cached.buttons or 0
	radiusSafe, minimumRadius = Controller.UpdateRadius state, ply
	Controller.MakeFollowerMovement state, ply, cmd, cached.maxSpeed or 1,
		radiusSafe, minimumRadius, cached.ghostAngle
	true

traceHull = (state, ply, fromPosition, toPosition, segment) ->
	trace = util.TraceHull {
		start: fromPosition
		endpos: toPosition
		mins: state.mins
		maxs: state.maxs
		filter: ply
		mask: MASK_PLAYERSOLID
		collisiongroup: COLLISION_GROUP_PLAYER_MOVEMENT
	}
	if CLIENT and Moonpanel.Debug and Moonpanel.Debug.RecordPillarHullRay
		Moonpanel.Debug\RecordPillarHullRay state.panel, fromPosition, toPosition,
			trace
	state.lastHullTrace = {
		start: fromPosition
		finish: toPosition
		hit: trace.Hit == true
		startSolid: trace.StartSolid == true
		fraction: trace.Fraction or 0
		normal: trace.HitNormal
		:segment
	}
	trace

Controller.ProbeGhostTravel = (state, ply, startAngle, requestedQ,
	edgeAngleDegrees, worldZ) ->
	return 0, { fraction: 1, segments: 0 } if requestedQ == 0
	deltaAngle = Moonpanel.Canvas.PillarArcDegrees requestedQ, edgeAngleDegrees
	return 0, { fraction: 0, segments: 0 } if math.abs(deltaAngle) < 0.000000001
	panel, radius = state.panel, state.radius
	probeArc = (candidateQ) ->
		candidateAngle = Moonpanel.Canvas.PillarArcDegrees candidateQ,
			edgeAngleDegrees
		acceptedAngle, segments = Moonpanel.Canvas.SweepPillarArc startAngle,
			candidateAngle, Controller.MaxArcStep,
			(fromAngle, toAngle, segment) ->
				fromPosition = panel\GetPillarOrbitPosition fromAngle, radius, worldZ
				toPosition = panel\GetPillarOrbitPosition toAngle, radius, worldZ
				trace = traceHull state, ply, fromPosition, toPosition, segment
				return 0 if trace.StartSolid or trace.AllSolid
				trace.Hit and math.Clamp(trace.Fraction or 0, 0, 1) or 1
		clear = math.abs(acceptedAngle - candidateAngle) <= 0.000001
		clear, acceptedAngle, segments
	clear, acceptedAngle, segments = probeArc requestedQ
	requestedPosition = panel\GetPillarOrbitPosition startAngle + deltaAngle,
		radius, worldZ
	if clear
		return requestedQ, {
			fraction: 1
			:segments
			:requestedPosition
			acceptedPosition: requestedPosition
		}
	ratio = math.Clamp math.abs(acceptedAngle / deltaAngle), 0, 1
	coarse = math.floor math.abs(requestedQ) * ratio
	edgeArc = state.radius * math.rad(math.abs(edgeAngleDegrees))
	skinQ = edgeArc > 0.000001 and
		math.ceil(Controller.ContactSkin / edgeArc * 4096) or 1
	exact = Moonpanel.Canvas.RefinePillarTravel requestedQ,
		math.max(0, coarse - skinQ),
		(candidateQ) -> select(1, probeArc candidateQ)
	acceptedMagnitude = math.max 0, math.abs(exact) - skinQ
	accepted = sign(requestedQ) * acceptedMagnitude
	acceptedAngle = Moonpanel.Canvas.PillarArcDegrees accepted, edgeAngleDegrees
	accepted, {
		fraction: ratio
		:segments
		coarseSafeQ: sign(requestedQ) * math.max(0, coarse - skinQ)
		lastSafeQ: accepted
		firstBlockedQ: exact + sign requestedQ
		:requestedPosition
		acceptedPosition: panel\GetPillarOrbitPosition startAngle + acceptedAngle,
			radius, worldZ
	}

Controller.ReadClientInput = (state, ply, cmd, originalButtons) ->
	rawX, rawY = if Moonpanel.ConsumePillarMouseInput
		Moonpanel\ConsumePillarMouseInput cmd
	else
		cmd\GetMouseX!, cmd\GetMouseY!
	digital = bit.band(originalButtons, bit.bor(IN_FORWARD, IN_BACK,
		IN_MOVELEFT, IN_MOVERIGHT)) ~= 0
	analog = false
	if rawX == 0 and rawY == 0 and not digital
		inputMax = math.max 1, bit.band(originalButtons, IN_SPEED) ~= 0 and
			ply\GetRunSpeed! or ply\GetWalkSpeed!
		analogX = cmd\GetSideMove! / inputMax
		analogY = -cmd\GetForwardMove! / inputMax
		magnitude = math.sqrt analogX^2 + analogY^2
		deadzoneConVar = GetConVar "moonpanel_gamepad_deadzone"
		deadzone = deadzoneConVar and deadzoneConVar\GetFloat! or 0.16
		if magnitude > deadzone
			scaled = math.min(1, (magnitude - deadzone) /
				math.max(0.001, 1 - deadzone))
			rawX = analogX / magnitude * scaled * 24
			rawY = analogY / magnitude * scaled * 24
			analog = true
	sensitivityConVar = GetConVar(analog and "moonpanel_gamepad_sensitivity" or
		"moonpanel_trace_sensitivity")
	sensitivity = sensitivityConVar and sensitivityConVar\GetFloat! or 1
	xQ, yQ = state.panel\GetCanvas!\QuantizeDeltas rawX, rawY, sensitivity
	if bit.band(originalButtons, IN_SPEED) ~= 0
		boostConVar = GetConVar "moonpanel_trace_speed_boost"
		boost = boostConVar and boostConVar\GetFloat! or 2
		xQ *= boost
		yQ *= boost
	xQ = math.Clamp math.Round(xQ), -32767, 32767
	yQ = math.Clamp math.Round(yQ), -32767, 32767
	xQ, yQ, analog, rawX, rawY

Controller.ResolveClientSample = (state, pathfinder, xQ, yQ) ->
	if state.turnLatch
		state.turnLatch.remaining -= 1
		state.turnLatch = nil if state.turnLatch.remaining <= 0
	unless pathfinder.active
		if latch = state.turnLatch
			sourceValue = latch.sourceAxis == "x" and xQ or yQ
			reversing = sourceValue ~= 0 and
				sign(sourceValue) == -latch.sourceDirection
			if reversing
				state.turnLatch = nil
			else
				if latch.axis == "x"
					xQ, yQ = latch.value, 0
				else
					xQ, yQ = 0, latch.value
				state.turnLatch = nil
	intent = pathfinder\ResolveIntent xQ, yQ
	if intent.cornering and intent.pendingAxis and intent.pendingValueQ ~= 0
		state.turnLatch = {
			axis: intent.pendingAxis
			value: intent.pendingValueQ
			remaining: 3
			sourceAxis: intent.axis
			sourceDirection: intent.direction
		}
	elseif pathfinder.active and state.turnLatch
		activeHorizontal = math.abs(pathfinder.active.primary.unitX) >
			math.abs(pathfinder.active.primary.unitY)
		activeValue = activeHorizontal and xQ or yQ
		state.turnLatch = nil if activeValue ~= 0
	sampleAxis = intent.cornering and intent.pendingAxis or intent.axis
	sampleValue = sampleAxis == "x" and xQ or yQ
	sampleDirection = intent.cornering and sign(sampleValue) or intent.direction
	intent, sampleAxis, sampleDirection

Controller.ResolveEncodedSample = (pathfinder, xQ, yQ) ->
	intent = pathfinder\ResolveIntent xQ, yQ
	sampleAxis = xQ ~= 0 and "x" or "y"
	sampleValue = sampleAxis == "x" and xQ or yQ
	intent, sampleAxis, sign(sampleValue)

Controller.UpdateRadius = (state, ply) ->
	position = ply\GetPos!
	radius = position\Distance state.panel\GetPillarAxisPoint(position)
	radius = Moonpanel.Canvas.QuantizePillarRadius radius,
		Controller.RadiusQuantum
	state.measuredRadius = radius
	safe, minimum = Controller.IsRadiusSafe state, radius
	if safe
		state.invalidRadiusSince = nil
		return true, minimum
	state.invalidRadiusSince or= CurTime!
	state.abortRequested = true if CurTime! - state.invalidRadiusSince >=
		Controller.RadiusRecoveryTime
	false, minimum

Controller.MakeFollowerMovement = (state, ply, cmd, maxSpeed, radiusSafe,
	minimumRadius, targetGhostAngle = nil) ->
	panel = state.panel
	position = ply\GetPos!
	playerAngle = panel\GetPillarAngle position
	viewAngles = Controller.GetFacingAngles panel, ply, state.pitch
	viewAngles or= cmd\GetViewAngles!
	cmd\SetViewAngles viewAngles
	Moonpanel.PillarFocusAngles[ply] = viewAngles
	desired = Vector 0, 0, 0
	if radiusSafe
		local unwrappedPlayer, unwrappedHead
		if targetGhostAngle ~= nil
			unwrappedPlayer = Moonpanel.Canvas.UnwrapPillarAngle playerAngle,
				state.playerAngle
			state.playerAngle = unwrappedPlayer
			unwrappedHead = targetGhostAngle
		else
			pathfinder = if SERVER then state.motionPathfinder else
				panel\GetCanvas!\GetPathFinder!
			unwrappedPlayer, unwrappedHead = Controller.UpdateAngles state, ply,
				pathfinder
		if unwrappedHead
			angleGap = unwrappedHead - unwrappedPlayer
			deltaTime = math.max tickInterval!, 0.001
			angleStep = Moonpanel.Canvas.GetPillarFollowerAngleStep angleGap,
				state.radius, maxSpeed, deltaTime
			axisPoint = panel\GetPillarAxisPoint position
			radial = position - axisPoint
			radial.z = 0
			if radial\LengthSqr! > 0.0001
				measuredRadius = radial\Length!
				radial /= measuredRadius
				tangent = Vector -radial.y, radial.x, 0
				tangent *= -1 if angleStep < 0
				tangentialSpeed = math.min maxSpeed,
					math.abs(state.radius * math.rad(angleGap)) / deltaTime
				-- A chord needs a small inward component even at the correct
				-- radius. Radius error itself is corrected gently and with a
				-- deadzone so prediction never becomes a high-gain servo.
				feedForward = tangentialSpeed *
					math.sin(math.abs(math.rad(angleStep)) * 0.5)
				radialCorrection = Moonpanel.Canvas.GetPillarRadialCorrection(
					state.radius - measuredRadius,
					Controller.RadiusCorrectionDeadzone,
					Controller.RadiusCorrectionGain,
					Controller.RadiusCorrectionSpeed)
				desired = tangent * tangentialSpeed + radial *
					(radialCorrection - feedForward)
				if desired\LengthSqr! > maxSpeed^2
					desired\Normalize!
					desired *= maxSpeed
	else
		axis = panel\GetPillarAxisPoint position
		radial = position - axis
		radial.z = 0
		if radial\LengthSqr! > 0.0001
			radial\Normalize!
			direction = state.measuredRadius < minimumRadius and 1 or -1
			-- Unsafe-radius recovery uses the same bounded radial authority as
			-- normal following. It must never become a second full-speed servo
			-- when prediction alternates across the safety boundary.
			desired = radial * direction * math.min(maxSpeed,
				Controller.RadiusCorrectionSpeed)
	forward, right = viewAngles\Forward!, viewAngles\Right!
	forward.z, right.z = 0, 0
	forward\Normalize!
	right\Normalize!
	forwardMove, sideMove = desired\Dot(forward), desired\Dot(right)
	cmd\SetForwardMove forwardMove
	cmd\SetSideMove sideMove
	viewAngles, forwardMove, sideMove, playerAngle

Controller.ProcessCommand = (ply, cmd, retainedButtons = 0,
	originalButtons = 0) ->
	panel = Controller.GetPanel ply
	return false unless panel
	state = Controller.States[ply]
	session = if CLIENT then Moonpanel.Net.TraceSessions[panel]
	else panel\GetTraceSession! if panel.GetTraceSession
	return false unless state and session and state.panel == panel and
		state.sessionId == session.id
	if ply\GetMoveType! ~= MOVETYPE_WALK
		state.abortRequested = true
		cmd\ClearMovement!
		cmd\ClearButtons!
		cmd\SetMouseX 0
		cmd\SetMouseY 0
		viewAngles = Controller.GetFacingAngles panel, ply, state.pitch
		cmd\SetViewAngles viewAngles if viewAngles
		return true
	pathfinder = if SERVER then state.motionPathfinder else
		panel\GetCanvas!\GetPathFinder!
	return false unless pathfinder and pathfinder.phase ==
		Moonpanel.Canvas.TraceEngine.Phase.Tracing
	commandNumber = cmd\CommandNumber!
	if commandNumber ~= 0 and state.commands[commandNumber]
		return Controller.ApplyCachedCommand state, ply, cmd,
			state.commands[commandNumber]

	xQ, yQ, rawX, rawY = 0, 0, 0, 0
	codecAnalog = SERVER and bit.band(originalButtons, IN_SPEED) == 0
	if CLIENT
		xQ, yQ, codecAnalog, rawX, rawY = Controller.ReadClientInput state,
			ply, cmd, originalButtons
	else
		xQ = math.Clamp cmd\GetMouseX!, -32767, 32767
		yQ = math.Clamp cmd\GetMouseY!, -32767, 32767
		rawX, rawY = xQ, yQ
	if commandNumber == 0 or SERVER and cmd.IsForced and cmd\IsForced!
		xQ, yQ = 0, 0

	radiusSafe, minimumRadius = Controller.UpdateRadius state, ply
	Controller.UpdateAngles state, ply, pathfinder
	beforeHash = pathfinder\hash!
	requestedXQ, requestedYQ = 0, 0
	puzzleLimit, leadLimit, worldLimit = 0, 0, 0
	clampReason = "none"
	worldInfo = { fraction: 1, segments: 0 }
	signedLead = 0
	axis, direction, budget, intentLimit = nil, 0, 0, nil
	sampleAxis, sampleDirection = nil, 0
	intent = nil
	if CLIENT
		intent, sampleAxis, sampleDirection = Controller.ResolveClientSample state,
			pathfinder, xQ, yQ
	else
		intent, sampleAxis, sampleDirection = Controller.ResolveEncodedSample pathfinder,
			xQ, yQ
	axis = intent and intent.axis
	direction = intent and intent.direction or 0
	budget = intent and intent.budget or 0
	intentLimit = intent and intent.cornering and intent.endpointDistanceQ or nil

	acceptedMagnitude = 0
	if radiusSafe and budget > 0 and direction ~= 0
		if axis == "x"
			puzzleLimit = math.abs pathfinder\GetSignedTravel "x", direction, 2
			puzzleLimit = math.min(puzzleLimit, intentLimit) if intentLimit
			if puzzleLimit > 0
				physicalRequestQ = direction * math.min(budget, puzzleLimit)
				canvas = panel\GetCanvas!
				edgeAngle = canvas\GetBarLength! /
					Moonpanel.Canvas.Resolution * 360
				head = pathfinder.cursors and pathfinder.cursors[1]
				if head
					startAngle = state.ghostAngle
					leadWorld = state.radius * math.rad(
						state.ghostAngle - state.playerAngle)
					signedLead = leadWorld
					arcPerQ = state.radius * math.rad(math.abs(edgeAngle)) / 4096
					leadQ = Moonpanel.Canvas.ClampPillarLead leadWorld,
						physicalRequestQ, arcPerQ, Controller.MaxLead
					leadLimit = math.abs leadQ
					clampReason = "lead" if leadQ ~= physicalRequestQ
					if leadQ ~= 0
						accepted, worldInfo = Controller.ProbeGhostTravel state,
							ply, startAngle, leadQ, edgeAngle, ply\GetPos!.z
						worldLimit = math.abs accepted
						clampReason = "ghost_world" if accepted ~= leadQ
						acceptedMagnitude = math.abs accepted
			else
				clampReason = "puzzle"
		else
			puzzleLimit = math.abs pathfinder\GetSignedTravel "y", direction, 2
			puzzleLimit = math.min(puzzleLimit, intentLimit) if intentLimit
			if puzzleLimit > 0
				acceptedMagnitude = math.min budget, puzzleLimit
			else
				clampReason = "puzzle"
	else
		clampReason = "unsafe_radius" unless radiusSafe
	if acceptedMagnitude > 0 and sampleDirection ~= 0
		if sampleAxis == "x"
			requestedXQ = sampleDirection * acceptedMagnitude
		else
			requestedYQ = sampleDirection * acceptedMagnitude

	changed = false
	constraints = {}
	if requestedXQ ~= 0 or requestedYQ ~= 0
		context = axis == "y" and ply or nil
		if CLIENT
			changed = panel\GetCanvas!\ApplyTraceSample requestedXQ,
				requestedYQ, false, context
			constraints = panel\GetCanvas!\GetPathFinder!\GetConstraintDecisions!
		else
			changed = pathfinder\applySample requestedXQ, requestedYQ, false,
				context
			constraints = pathfinder\GetConstraintDecisions!
	unless changed
		requestedXQ, requestedYQ = 0, 0
		clampReason = "puzzle" if budget > 0 and clampReason == "none"
	afterHash = pathfinder\hash!

	if CLIENT and changed
		Moonpanel.Net.QueueTraceSample panel, requestedXQ, requestedYQ, false,
			constraints, commandNumber
	elseif SERVER and commandNumber ~= 0 and (xQ ~= 0 or yQ ~= 0)
		proof = {
			:commandNumber
			requestedXQ: xQ
			requestedYQ: yQ
			acceptedXQ: requestedXQ
			acceptedYQ: requestedYQ
			startHash: beforeHash
			endHash: afterHash
			radius: state.radius
			:puzzleLimit
			:leadLimit
			worldLimit: worldLimit
			worldFraction: worldInfo.fraction
			motionAxis: axis
		}
		state.proofs[commandNumber] = proof
		for oldNumber in pairs state.proofs
			state.proofs[oldNumber] = nil if oldNumber + 512 < commandNumber

	maxSpeed = math.max 1, codecAnalog and bit.band(originalButtons, IN_SPEED) == 0 and
		ply\GetWalkSpeed! or ply\GetRunSpeed!
	cmd\ClearMovement!
	viewAngles, forwardMove, sideMove, playerAngle = Controller.MakeFollowerMovement(
		state, ply, cmd, maxSpeed, radiusSafe, minimumRadius)
	buttons = retainedButtons
	buttons = bit.bor(buttons, IN_SPEED) unless codecAnalog and
		bit.band(originalButtons, IN_SPEED) == 0
	cmd\SetButtons buttons
	cmd\SetMouseX requestedXQ
	cmd\SetMouseY requestedYQ

	state.debug = {
		:commandNumber
		:rawX
		:rawY
		xQ: requestedXQ
		yQ: requestedYQ
		:puzzleLimit
		:leadLimit
		:worldLimit
		:clampReason
		:signedLead
		motionAxis: axis
		sampleAxis: sampleAxis
		worldFraction: worldInfo.fraction
		worldSegments: worldInfo.segments
		lastSafeQ: worldInfo.lastSafeQ
		firstBlockedQ: worldInfo.firstBlockedQ
		requestedGhost: worldInfo.requestedPosition
		acceptedGhost: worldInfo.acceptedPosition
		contactNormal: state.lastHullTrace and state.lastHullTrace.normal
		playerAngle: playerAngle
		headAngle: pathfinder.cursors and pathfinder.cursors[1] and
			Moonpanel.Canvas.PillarTraceAngle(pathfinder.cursors[1].x) or 0
		radius: state.radius
		speedLimit: maxSpeed
		:forwardMove
		:sideMove
		startHash: beforeHash
		endHash: afterHash
	}

	if commandNumber ~= 0
		state.commands[commandNumber] = {
			xQ: requestedXQ
			yQ: requestedYQ
			:codecAnalog
			:buttons
			:maxSpeed
			ghostAngle: state.ghostAngle
		}
		for oldNumber in pairs state.commands
			state.commands[oldNumber] = nil if oldNumber > 0 and
				oldNumber + Controller.CommandRetention < commandNumber
	true

Moonpanel.IsPillarControlling = (ply) => Controller.GetPanel ply
Moonpanel.GetPillarFacingAngles = (panel, ply, pitch = nil, worldOrigin = nil) =>
	Controller.GetFacingAngles panel, ply, pitch, worldOrigin
Moonpanel.BeginPillarOrbit = (panel, ply, sessionId, seed = nil) =>
	Controller.Begin panel, ply, sessionId, seed
Moonpanel.EndPillarOrbit = (ply, reason = "session_end") =>
	Controller.End ply, reason

if CLIENT
	hook.Add "CalcView", "Moonpanel Pillar View", (ply, origin, angles, fov,
		zNear, zFar) ->
		state = Controller.States[ply]
		return unless state and IsValid state.panel
		viewAngles = Controller.GetFacingAngles state.panel, ply, state.pitch,
			origin
		return unless viewAngles
		{
			:origin
			angles: viewAngles
			:fov
			znear: zNear
			zfar: zFar
			drawviewer: false
		}
