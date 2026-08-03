receive = Moonpanel.Net.Receive
flowTypes = Moonpanel.Net.FlowTypes
startFlow = Moonpanel.Net.StartFlow

applyTraceSamples = (canvas, samples, controller = nil) ->
	for sample in *samples
		canvas\ApplyTraceSample sample.xQ, sample.yQ, sample.boost,
			controller, sample.constraints

Moonpanel.Net.PendingPanelDataRequests or= {}
-- Predicted sessions never survive addon reload. Keeping this table through
-- autoreload can make InputMouseApply consume the player's camera forever.
Moonpanel.Net.TraceSessions = {}
pendingTraceStarts = {}

Moonpanel.Net.SyncClickerState = (focused = nil) ->
	ply = LocalPlayer!
	return unless IsValid ply
	focused = Moonpanel\IsFocused(ply) if focused == nil
	predictedControl = Moonpanel\GetPredictedControl ply
	activeGame = IsEntity(predictedControl) and IsValid(predictedControl) and
		predictedControl.Moonpanel
	gui.EnableScreenClicker focused and not activeGame

serverAuthoritativeTrace = CreateClientConVar "moonpanel_server_authoritative_trace", "0", true, false,
	"Disable clientside trace prediction and display server updates only"

Moonpanel.IsServerAuthoritativeTrace = => serverAuthoritativeTrace\GetBool!

validPanel = (panel) ->
	IsValid(panel) and panel.Moonpanel and panel\IsSynchronized!

localSession = (panel) ->
	session = Moonpanel.Net.TraceSessions[panel]
	return unless session and session.controller == LocalPlayer!
	session

releaseSession = (panel) ->
	session = Moonpanel.Net.TraceSessions[panel]
	Moonpanel\EndPillarOrbit LocalPlayer! if session and
		session.controller == LocalPlayer!
	Moonpanel.Net.TraceSessions[panel] = nil
	panel\SetController game.GetWorld! if IsValid panel
	Moonpanel.Net.SyncClickerState!

clearTraceSession = (panel) ->
	releaseSession panel
	pendingTraceStarts[panel] = nil
	true

predictTraceStart = (panel, x, y) ->
	return false if Moonpanel\IsServerAuthoritativeTrace!
	return false unless validPanel panel

	existingSession = Moonpanel.Net.TraceSessions[panel]
	if existingSession
		return false unless existingSession.terminal
		clearTraceSession panel

	return false if Moonpanel.Net.TraceSessions[panel] or
		pendingTraceStarts[panel]

	ply = LocalPlayer!
	canvas = panel\GetCanvas!
	return false unless IsValid(ply) and canvas
	return false unless ply\Alive! and Moonpanel\IsFocused ply
	return false unless panel\GetPowered!

	controller = panel\GetController!
	return false if controller and IsValid(controller) and controller\IsPlayer!
	return false if ply\EyePos!\DistToSqr(panel\GetPos!) > 1024 * 1024

	compatibility = canvas\GetSurfaceCompatibility!
	return false if compatibility and not compatibility.playable

	phases = Moonpanel.Canvas.TraceEngine.Phase
	phase = canvas\GetTracePhase!
	return false unless phase == phases.Idle or phase == phases.Feedback

	node = canvas\FindStartNode x, y, 32
	return false unless node

	oldSnapshot = canvas\GetTraceSnapshot!
	oldPlayData = canvas\GetPlayDataSnapshot!
	return false unless canvas\Start ply, node.id

	currentTime = RealTime!

	Moonpanel.Net.TraceSessions[panel] = {
		id: 0
		revision: canvas\GetTraceRevision!
		ruleRevision: canvas\GetRuleRevision! or 0
		controller: ply
		nextSequence: 0
		pending: {}
		unsent: {}
		observer: false
		serverSequence: 0
		presentationEvents: {}
		provisional: true
		pendingAction: nil
		nextFlush: currentTime + 0.05
	}

	pendingTraceStarts[panel] = {
		nodeId: node.id
		snapshot: oldSnapshot
		playData: oldPlayData
		startedAt: currentTime
	}

	Moonpanel.Net.SyncClickerState!
	true

newerSerial = (value, previous) ->
	return true unless previous
	delta = (value - previous) % 4294967296
	delta > 0 and delta < 2147483648

Moonpanel.Net.PanelRequestControl = (entity, x = 0, y = 0) ->
	requestX = math.Clamp math.Round(x), 0, 65535
	requestY = math.Clamp math.Round(y), 0, 65535
	predictTraceStart entity, requestX, requestY
	startFlow flowTypes.PanelRequestControl
	net.WriteEntity entity
	net.WriteUInt requestX, 16
	net.WriteUInt requestY, 16
	sensitivity = GetConVar("moonpanel_trace_sensitivity")
	net.WriteUInt math.Clamp(math.Round(
		(sensitivity and sensitivity\GetFloat! or 1) * 1000), 50, 8000), 14
	gamepadSensitivity = GetConVar("moonpanel_gamepad_sensitivity")
	net.WriteUInt math.Clamp(math.Round(
		(gamepadSensitivity and gamepadSensitivity\GetFloat! or 1) * 1000), 50, 8000), 14
	deadzone = GetConVar("moonpanel_gamepad_deadzone")
	net.WriteUInt math.Clamp(math.Round(
		(deadzone and deadzone\GetFloat! or 0.16) * 1000), 0, 950), 10
	net.SendToServer!

Moonpanel.Net.PanelRequestData = (panel, callback, force = false) ->
	return false unless IsValid(panel) and panel.Moonpanel
	request = Moonpanel.Net.PendingPanelDataRequests[panel]
	unless istable request
		request = {
			callback: if isfunction(request) then request else nil
			attempts: 0
		}
	request.callback = callback if callback
	Moonpanel.Net.PendingPanelDataRequests[panel] = request

	-- ENTITY:Initialize may run before InitPostEntity. Queue the request here;
	-- the synchronization pass sends it once the client networking lifecycle is
	-- ready, and retries it only while this panel still has no runtime data.
	return false unless Moonpanel.Initialized
	now = RealTime!
	return false if not force and request.nextAttempt and now < request.nextAttempt
	request.attempts += 1
	request.nextAttempt = now + 1
	startFlow flowTypes.PanelRequestData
	net.WriteEntity panel
	net.SendToServer!
	true

Moonpanel.Net.MaintainPanelDataRequests = ->
	return unless Moonpanel.Initialized
	for panel in pairs Moonpanel.Net.PendingPanelDataRequests
		if not IsValid(panel) or not panel.Moonpanel
			Moonpanel.Net.PendingPanelDataRequests[panel] = nil
			continue
		canvas = panel\GetCanvas!
		if canvas and canvas\GetData!
			Moonpanel.Net.PendingPanelDataRequests[panel] = nil
		else
			Moonpanel.Net.PanelRequestData panel

Moonpanel.Net.QueueTraceSample = (panel, xQ, yQ, boost = false,
	constraintDecisions = {}, commandNumber = 0) ->
	session = localSession panel
	return false unless session

	session.nextSequence += 1
	constraints = {}
	for i = 1, math.min 2, #constraintDecisions
		table.insert constraints, math.Clamp(math.floor(
			constraintDecisions[i] or 0), 0, 4294967295)
	sample = {
		sequence: session.nextSequence
		xQ: math.Clamp math.Round(xQ), -32767, 32767
		yQ: math.Clamp math.Round(yQ), -32767, 32767
		boost: boost == true
		commandNumber: math.max 0, math.floor commandNumber or 0
		hash: if Moonpanel\IsServerAuthoritativeTrace! then 0 else
			panel\GetCanvas!\GetTraceHash!
		:constraints
	}
	table.insert session.pending, sample
	table.insert session.unsent, sample
	true

flushTraceSamples = (panel) ->
	session = localSession panel
	return unless session
	return if session.provisional
	return if #session.unsent == 0

	count = math.min Moonpanel.Net.TraceBatchMax, #session.unsent
	first = session.unsent[1]
	startFlow flowTypes.TraceInputBatch
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.revision, 32
	net.WriteUInt session.ruleRevision or 0, 32
	net.WriteUInt first.sequence, 32
	Moonpanel.Net.WriteTraceSamples session.unsent, count
	net.WriteUInt session.unsent[count].hash, 32
	net.SendToServer!

	for i = 1, count
		table.remove session.unsent, 1
	session.nextFlush = RealTime! + 0.05

Moonpanel.Net.SendTraceAction = (panel, action) ->
	session = localSession panel
	return false unless session
	if session.provisional
		session.pendingAction = action
		Moonpanel.Net.SyncClickerState!
		return true
	if not session.terminal
		session.terminal = true
		session.visualApplied = true
		session.aborted = action == 0
	Moonpanel.Net.SyncClickerState!
	while #session.unsent > 0
		flushTraceSamples panel
	startFlow flowTypes.TraceAction
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.revision, 32
	net.WriteUInt session.ruleRevision or 0, 32
	net.WriteUInt session.nextSequence, 32
	net.WriteUInt action, 2
	net.SendToServer!
	unless Moonpanel\IsServerAuthoritativeTrace!
		panel\GetCanvas!\End action ~= 1
	true

Moonpanel.Net.SendFocusExit = ->
	startFlow flowTypes.FocusExit
	net.SendToServer!

hook.Add "Think", "TheMP Trace Network", ->
	now = RealTime!
	for panel, session in pairs Moonpanel.Net.TraceSessions
		unless validPanel panel
			releaseSession panel
			continue
		canvas = nil
		if session.observer
			canvas = panel\GetCanvas!
			unless canvas
				releaseSession panel
				continue

		if session.controller == LocalPlayer! and not session.provisional and
				#session.unsent > 0 and
				now >= session.nextFlush
			flushTraceSamples panel

		if session.observer
			while session.presentationEvents[1] and
					canvas\HasObserverReached session.presentationEvents[1].sequence
				event = table.remove session.presentationEvents, 1
				canvas\SetPresentationExit event.exitPath
			if session.visualResult and
					canvas\HasObserverReached session.visualResult.finalSequence
				canvas\ApplyVisualResult session.visualResult
				session.visualApplied = true
				session.visualResult = nil
		if session.terminal and session.visualApplied
			if session.observer
				canvas\SetTraceFeedback!
				canvas\SetObserverFollower nil
			releaseSession panel

receive flowTypes.TraceControlGrant, ->
	panel = net.ReadEntity!
	return unless validPanel panel
	controller = net.ReadEntity!
	sessionId = net.ReadUInt 32
	revision = net.ReadUInt 32
	ruleRevision = net.ReadUInt 32
	lastSequence = net.ReadUInt 32
	snapshot = net.ReadTable!
	orbitSeed = net.ReadBool! and net.ReadTable! or nil
	canvas = panel\GetCanvas!
	return unless revision == canvas\GetTraceRevision!
	return unless ruleRevision == canvas\GetRuleRevision!
	existing = Moonpanel.Net.TraceSessions[panel]
	provisional = existing and existing.provisional and existing.controller == LocalPlayer!
	provisionalSamples = provisional and existing.unsent or nil
	provisionalAction = provisional and existing.pendingAction or nil
	if existing and existing.id == sessionId
		if controller ~= LocalPlayer! or Moonpanel\IsServerAuthoritativeTrace!
			oldExitPath = canvas\IsExitPath!
			canvas\ApplyObserverSnapshot snapshot, lastSequence
			existing.serverSequence = lastSequence
			existing.serverHash = canvas\GetTraceHash!
			if oldExitPath ~= canvas\IsExitPath!
				table.insert existing.presentationEvents, {
					sequence: lastSequence
					exitPath: canvas\IsExitPath!
				}
		return
	if existing and not provisional and existing.controller == LocalPlayer!
		Moonpanel\EndPillarOrbit LocalPlayer!
	importedPlay = canvas\GetPlayDataSnapshot!
	lateJoin = lastSequence > 0 or importedPlay and
		importedPlay.sessionId == sessionId
	observer = controller ~= LocalPlayer! or Moonpanel\IsServerAuthoritativeTrace!
	canvas\ImportTraceSession controller, sessionId, revision, snapshot,
		lastSequence, lateJoin, observer, importedPlay, not provisional

	Moonpanel.Net.TraceSessions[panel] = {
		id: sessionId
		:revision
		:ruleRevision
		:controller
		nextSequence: lastSequence + (provisionalSamples and #provisionalSamples or 0)
		pending: provisional and table.Copy(provisionalSamples) or {}
		unsent: provisional and table.Copy(provisionalSamples) or {}
		observer: controller ~= LocalPlayer! or Moonpanel\IsServerAuthoritativeTrace!
		serverSequence: lastSequence
		presentationEvents: {}
		nextFlush: RealTime! + 0.05
	}
	if panel.MoonpanelPillar and controller == LocalPlayer!
		unless Moonpanel\BeginPillarOrbit panel, controller, sessionId, orbitSeed
			releaseSession panel
			Moonpanel.Net.SendFocusExit!
			return
	elseif controller == LocalPlayer! and Moonpanel.PillarFocusAngles
		Moonpanel.PillarFocusAngles[controller] = nil
	panel\SetController controller
	Moonpanel.Net.SyncClickerState!
	if provisional
		applyTraceSamples canvas, provisionalSamples, controller
		sequenceIndex = 1
		for sample in *Moonpanel.Net.TraceSessions[panel].unsent
			sample.hash = canvas\GetTraceHash!
			Moonpanel.Net.TraceSessions[panel].pending[sequenceIndex].hash = sample.hash
			sequenceIndex += 1
		pendingTraceStarts[panel] = nil
		if provisionalAction
			Moonpanel.Net.TraceSessions[panel].pendingAction = nil
			Moonpanel.Net.SendTraceAction panel, provisionalAction

receive flowTypes.TraceControlReject, ->
	panel = net.ReadEntity!
	reason = net.ReadUInt 4
	return unless IsValid(panel) and panel.Moonpanel
	session = Moonpanel.Net.TraceSessions[panel]
	pending = pendingTraceStarts[panel]
	return unless pending
	if session and not session.provisional
		pendingTraceStarts[panel] = nil
		return
	return unless session and session.provisional
	canvas = panel\GetCanvas!
	canvas\ResetRuntime "start-rejected"
	canvas\RestoreTraceSnapshot pending.snapshot if pending.snapshot
	canvas\SetPlayData pending.playData or {}
	canvas\SetPresentationExit canvas\IsExitPath!, true
	clearTraceSession panel
	MsgC Color(255, 150, 80), "[Moonpanel] predicted trace start rejected (reason ",
		tostring(reason), ")\n"

receive flowTypes.TraceObserverAdvance, ->
	panel = net.ReadEntity!
	return unless validPanel panel
	session = Moonpanel.Net.TraceSessions[panel]
	sessionId = net.ReadUInt 32
	firstSequence = net.ReadUInt 32
	samples, count, malformed = Moonpanel.Net.ReadTraceSamples!
	serverHash = net.ReadUInt 32
	return unless session and session.id == sessionId
	isLocalController = session.controller == LocalPlayer!
	return if isLocalController and not Moonpanel\IsServerAuthoritativeTrace!
	return if malformed
	return unless firstSequence == session.serverSequence + 1

	canvas = panel\GetCanvas!
	oldExitPath = canvas\IsExitPath!
	applyTraceSamples canvas, samples, nil
	finalSequence = firstSequence + count - 1
	session.serverSequence = finalSequence
	session.serverHash = serverHash
	if isLocalController
		while session.pending[1] and session.pending[1].sequence <= finalSequence
			table.remove session.pending, 1
		unless Moonpanel\IsServerAuthoritativeTrace!
			return unless canvas\GetTraceHash! == serverHash
			return
	else
		clientHash = canvas\GetTraceHash!
		if clientHash ~= serverHash
			MsgC Color(255, 120, 40),
				"[Moonpanel] observer trace desync: session ",
				tostring(sessionId), " sequence ", tostring(finalSequence),
				" client ", tostring(clientHash), " server ",
				tostring(serverHash), " revision ", tostring(session.revision), "\n"
			return
	if oldExitPath ~= canvas\IsExitPath!
		table.insert session.presentationEvents, {
			sequence: finalSequence
			exitPath: canvas\IsExitPath!
		}
	canvas\ApplyObserverSnapshot canvas\GetTraceSnapshot!, finalSequence

receive flowTypes.TraceAck, ->
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	sequence = net.ReadUInt 32
	serverHash = net.ReadUInt 32
	session = Moonpanel.Net.TraceSessions[panel]
	return unless session and session.id == sessionId
	while session.pending[1] and session.pending[1].sequence <= sequence
		table.remove session.pending, 1
	session.serverHash = serverHash

receive flowTypes.TraceResyncSnapshot, ->
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	lastSequence = net.ReadUInt 32
	serverHash = net.ReadUInt 32
	snapshot = net.ReadTable!
	session = Moonpanel.Net.TraceSessions[panel]
	return unless session and session.id == sessionId and validPanel(panel)
	canvas = panel\GetCanvas!
	clientHash = canvas\GetTraceHash!
	return unless canvas\RestoreTraceSnapshot snapshot
	session.serverSequence = lastSequence
	if session.controller == LocalPlayer!
		Moonpanel.PillarController.ClearCommands LocalPlayer!

	if Moonpanel\IsServerAuthoritativeTrace! and session.controller == LocalPlayer!
		while session.pending[1] and session.pending[1].sequence <= lastSequence
			table.remove session.pending, 1
	else
		replay = {}
		for sample in *session.pending
			if sample.sequence > lastSequence
				table.insert replay, sample
		for sample in *replay
			canvas\ApplyTraceSample sample.xQ, sample.yQ, sample.boost,
				session.controller, sample.constraints
			sample.hash = canvas\GetTraceHash!
		session.pending = replay
	MsgC Color(255, 160, 40), "[Moonpanel] prediction recovery: session ",
		tostring(sessionId), " sequence ", tostring(lastSequence), " client ",
		tostring(clientHash), " server ", tostring(serverHash), " revision ",
		tostring(session.revision), "\n"

receive flowTypes.TraceResult, ->
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	aborted = net.ReadBool!
	if session = Moonpanel.Net.TraceSessions[panel]
			if session.id == sessionId
				Moonpanel\EndPillarOrbit LocalPlayer! if session.controller == LocalPlayer!
				canvas = panel\GetCanvas! if validPanel panel
			if canvas
				if aborted
					canvas\SetTraceFeedback!
				elseif not Moonpanel\IsServerAuthoritativeTrace! and
					canvas\GetTracePhase! == Moonpanel.Canvas.TraceEngine.Phase.Tracing
					canvas\BeginTraceEvaluation!
				pendingTraceStarts[panel] = nil
				session.terminal = true
				session.aborted = aborted
				session.visualApplied = true if session.controller == LocalPlayer!
	Moonpanel.Net.SyncClickerState!

receive flowTypes.PanelRequestDataFromPlayer, ->
	entity = net.ReadEntity!
	return unless IsValid(entity) and entity.Moonpanel
	data = if Moonpanel.Editor and Moonpanel.Editor.GetCurrentData
		Moonpanel.Editor\GetCurrentData!
	else
		Moonpanel.EditorDocument.FreshPanel!
	json = Moonpanel.Canvas.SerializeData data
	compressed = util.Compress json
	return unless compressed
	startFlow flowTypes.PanelRequestDataFromPlayer
	net.WriteEntity entity
	net.WriteUInt #compressed, 32
	net.WriteData compressed, #compressed
	net.SendToServer!

receive flowTypes.PanelRequestData, ->
	panel = net.ReadEntity!
	return unless IsValid panel
	data = net.ReadTable!
	return unless istable data
	request = Moonpanel.Net.PendingPanelDataRequests[panel]
	Moonpanel.Net.PendingPanelDataRequests[panel] = nil
	return unless panel.Moonpanel
	canvas = panel\GetCanvas!
	canvas\ImportNetworkState panel, data
	request.callback panel, data if istable(request) and isfunction(request.callback)

receive flowTypes.PanelResetPresentation, ->
	panel = net.ReadEntity!
	serial = net.ReadUInt 32
	snapshot = net.ReadTable!
	return unless IsValid(panel) and panel.Moonpanel and istable(snapshot)
	canvas = panel\GetCanvas!
	canvas\BeginResetPresentation snapshot, serial

receive flowTypes.TraceVisualResult, ->
	panel = net.ReadEntity!
	return unless validPanel panel
	result = net.ReadTable!
	return unless istable(result) and isnumber(result.sessionId) and
		isnumber(result.revision) and isnumber(result.finalSequence) and
		isnumber(result.finalHash) and isnumber(result.eventSerial) and
		isnumber(result.ruleRevision) and isnumber(result.reportHash) and
		istable(result.snapshot) and istable(result.feedback)
	canvas = panel\GetCanvas!
	return unless result.revision == canvas\GetTraceRevision!
	return unless newerSerial result.eventSerial, canvas\GetVisualEventSerial!
	session = Moonpanel.Net.TraceSessions[panel]
	return unless session and session.id == result.sessionId and
		session.revision == result.revision and
		session.ruleRevision == result.ruleRevision
	canvas\SetSolvedState result.solved == true
	canvas\SetVisualEventSerial result.eventSerial
	session.terminal = true
	unless panel\GetPowered!
		canvas\ResetPresentation "power-loss"
		session.visualApplied = true
		Moonpanel.Net.SyncClickerState!
		return
	if session.controller == LocalPlayer! and not Moonpanel\IsServerAuthoritativeTrace!
		canvas\SetTraceFeedback!
		localHash = canvas\GetTraceHash!
		localReport = canvas\GetLastRuleReport!
		reportMatches = localReport and localReport.status == "complete" and
			localReport.ruleRevision == result.ruleRevision and
			localReport.reportHash == result.reportHash
		predicted = canvas\GetPredictedVisual!
		visualMatches = reportMatches or result.aborted and predicted and
			predicted.aborted == true
		local geometryMatches
		if localHash == result.finalHash
			geometryMatches = true
			result.snapshot = canvas\GetTraceSnapshot!
		else
			geometryMatches = false
			MsgC Color(255, 160, 40),
				"[Moonpanel] presentation geometry repair: session ",
				tostring(result.sessionId), " sequence ",
				tostring(result.finalSequence), " client ", tostring(localHash),
				" server ", tostring(result.finalHash), " revision ",
				tostring(result.revision), "\n"
		if visualMatches and geometryMatches
			canvas\StoreVisualResult result
		else
			if localReport and not reportMatches
				MsgC Color(255, 120, 40),
					"[Moonpanel] rule prediction mismatch: session ",
					tostring(result.sessionId), " client ",
					tostring(localReport.reportHash), " server ",
					tostring(result.reportHash), " client revision ",
					tostring(localReport.ruleRevision), " server revision ",
					tostring(result.ruleRevision), " client status ",
					tostring(localReport.status), "\n"
			canvas\CancelSolution "server-result"
			canvas\ApplyVisualResult result, 0,
				localReport ~= nil or predicted ~= nil, false
			session.visualApplied = true
	else
		session.visualResult = result
	Moonpanel.Net.SyncClickerState!

receive flowTypes.EditorOpen, ->
	ply, surfaceKind = net.ReadEntity!, net.ReadUInt(1)
	Moonpanel.Editor\SetPresence ply, true if Moonpanel.Editor and
		Moonpanel.Editor.SetPresence
	if ply == LocalPlayer!
		Moonpanel.Editor\Open surfaceKind if Moonpanel.Editor and Moonpanel.Editor.Open

Moonpanel.Net.RequestEditorOpen = (surfaceKind = Moonpanel.Canvas.SurfaceKind.Flat) ->
	startFlow flowTypes.EditorOpen
	net.WriteUInt surfaceKind, 1
	net.SendToServer!

Moonpanel.Net.SendEditorClosed = ->
	startFlow flowTypes.EditorStatus
	net.SendToServer!

receive flowTypes.EditorStatus, ->
	ply = net.ReadEntity!
	Moonpanel.Editor\SetPresence ply, false if Moonpanel.Editor and
		Moonpanel.Editor.SetPresence
