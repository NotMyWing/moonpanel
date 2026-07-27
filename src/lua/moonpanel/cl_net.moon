receive = Moonpanel.Net.Receive
flowTypes = Moonpanel.Net.FlowTypes
startFlow = Moonpanel.Net.StartFlow

Moonpanel.Net.PendingPanelDataRequests or= {}
-- Predicted sessions never survive addon reload. Keeping this table through
-- autoreload can make InputMouseApply consume the player's camera forever.
Moonpanel.Net.TraceSessions = {}
Moonpanel.Net.PendingTraceStarts = {}

Moonpanel.Net.SyncClickerState = ->
	ply = LocalPlayer!
	return unless IsValid ply
	focused = Moonpanel\IsFocused ply
	predictedControl = if Moonpanel.GetPredictedControl
		Moonpanel\GetPredictedControl ply
	else
		nil
	activeGame = IsEntity(predictedControl) and IsValid(predictedControl) and
		predictedControl.Moonpanel
	gui.EnableScreenClicker focused and not activeGame

serverAuthoritativeTrace = CreateClientConVar "moonpanel_server_authoritative_trace", "0", true, false,
	"Disable clientside trace prediction and display server updates only"

Moonpanel.IsServerAuthoritativeTrace = => serverAuthoritativeTrace\GetBool!

validPanel = (panel) ->
	IsValid(panel) and panel.Moonpanel and panel.GetCanvas and
	panel.IsSynchonized and panel\IsSynchonized!

Moonpanel.Net.ClearTraceSession = (panel) ->
	if session = Moonpanel.Net.TraceSessions[panel]
		if session.controller == LocalPlayer! and Moonpanel.EndPillarOrbit
			Moonpanel\EndPillarOrbit LocalPlayer!
	Moonpanel.Net.TraceSessions[panel] = nil
	Moonpanel.Net.PendingTraceStarts[panel] = nil
	if IsValid(panel)
		panel\SetController game.GetWorld! if panel.SetController
	Moonpanel.Net.SyncClickerState!
	true

Moonpanel.Net.PredictTraceStart = (panel, x, y) ->
	return false if Moonpanel\IsServerAuthoritativeTrace!
	return false unless validPanel panel

	existingSession = Moonpanel.Net.TraceSessions[panel]
	if existingSession
		return false unless existingSession.terminal
		Moonpanel.Net.ClearTraceSession panel

	return false if Moonpanel.Net.TraceSessions[panel] or
		Moonpanel.Net.PendingTraceStarts[panel]

	ply = LocalPlayer!
	canvas = panel\GetCanvas!
	pathfinder = canvas and canvas\GetPathFinder!

	return false unless IsValid(ply) and canvas and pathfinder
	return false unless ply\Alive! and Moonpanel\IsFocused ply
	return false unless panel\GetPowered!

	controller = panel\GetController!
	return false if controller and IsValid(controller) and controller\IsPlayer!
	return false if ply\EyePos!\DistToSqr(panel\GetPos!) > 1024 * 1024

	compatibility = canvas\GetSurfaceCompatibility!
	return false if compatibility and not compatibility.playable

	phases = Moonpanel.Canvas.TraceEngine.Phase
	return false unless pathfinder.phase == phases.Idle or
		pathfinder.phase == phases.Feedback

	node = canvas\FindStartNode x, y, 32
	return false unless node

	oldSnapshot = pathfinder\snapshot!
	oldPlayData = canvas\GetPlayDataSnapshot!
	return false unless canvas\Start ply, node.id

	pathfinder = canvas\GetPathFinder!
	return false unless pathfinder

	ruleDefinition = canvas\GetRuleDefinition!
	currentTime = RealTime!

	Moonpanel.Net.TraceSessions[panel] = {
		id: 0
		revision: pathfinder.topology.revision
		ruleRevision: ruleDefinition and ruleDefinition.ruleRevision or 0
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

	Moonpanel.Net.PendingTraceStarts[panel] = {
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
	Moonpanel.Net.PredictTraceStart entity, requestX, requestY
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
	return false unless IsValid(panel) and panel.Moonpanel and panel.GetCanvas
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
		if not IsValid(panel) or not panel.Moonpanel or not panel.GetCanvas
			Moonpanel.Net.PendingPanelDataRequests[panel] = nil
			continue
		canvas = panel\GetCanvas!
		if canvas and canvas\GetData!
			Moonpanel.Net.PendingPanelDataRequests[panel] = nil
		else
			Moonpanel.Net.PanelRequestData panel

Moonpanel.Net.QueueTraceSample = (panel, xQ, yQ, boost = false,
	constraintDecisions = {}, commandNumber = 0) ->
	session = Moonpanel.Net.TraceSessions[panel]
	return false unless session and session.controller == LocalPlayer!

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
			panel\GetCanvas!\GetPathFinder!\hash!
		:constraints
	}
	table.insert session.pending, sample
	table.insert session.unsent, sample
	true

Moonpanel.Net.FlushTraceSamples = (panel) ->
	session = Moonpanel.Net.TraceSessions[panel]
	return unless session and session.controller == LocalPlayer!
	return if session.provisional
	return if #session.unsent == 0

	count = math.min 12, #session.unsent
	first = session.unsent[1]
	startFlow flowTypes.TraceInputBatch
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.revision, 32
	net.WriteUInt session.ruleRevision or 0, 32
	net.WriteUInt first.sequence, 32
	net.WriteUInt count, 4
	for i = 1, count
		sample = session.unsent[i]
		net.WriteInt sample.xQ, 16
		net.WriteInt sample.yQ, 16
		net.WriteBool sample.boost
		net.WriteUInt sample.commandNumber or 0, 32
		net.WriteUInt #sample.constraints, 2
		for decision in *sample.constraints
			net.WriteUInt decision, 32
	net.WriteUInt session.unsent[count].hash, 32
	net.SendToServer!

	for i = 1, count
		table.remove session.unsent, 1
	session.nextFlush = RealTime! + 0.05

Moonpanel.Net.SendTraceAction = (panel, action) ->
	session = Moonpanel.Net.TraceSessions[panel]
	return false unless session and session.controller == LocalPlayer!
	if session.provisional
		session.pendingAction = action
		Moonpanel.Net.SyncClickerState!
		return true
	if session.controller == LocalPlayer! and not session.terminal
		session.terminal = true
		session.visualApplied = true
		session.aborted = action == 0
	Moonpanel.Net.SyncClickerState!
	while #session.unsent > 0
		Moonpanel.Net.FlushTraceSamples panel
	startFlow flowTypes.TraceAction
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.revision, 32
	net.WriteUInt session.ruleRevision or 0, 32
	net.WriteUInt session.nextSequence, 32
	net.WriteUInt action, 2
	net.SendToServer!
	unless Moonpanel\IsServerAuthoritativeTrace!
		if action == 1
			panel\GetCanvas!\End false
		else
			panel\GetCanvas!\End true
	true

Moonpanel.Net.SendFocusExit = ->
	startFlow flowTypes.FocusExit
	net.SendToServer!

hook.Add "Think", "TheMP Trace Network", ->
	now = RealTime!
	for panel, session in pairs Moonpanel.Net.TraceSessions
		unless validPanel panel
			if session.controller == LocalPlayer! and Moonpanel.EndPillarOrbit
				Moonpanel\EndPillarOrbit LocalPlayer!
			Moonpanel.Net.TraceSessions[panel] = nil
			continue

		if session.controller == LocalPlayer! and not session.provisional and
				#session.unsent > 0 and
				now >= session.nextFlush
			Moonpanel.Net.FlushTraceSamples panel

		if session.observer
			canvas = panel\GetCanvas!
			follower = canvas\GetObserverFollower!
			while session.presentationEvents[1] and follower and
					follower\hasReached session.presentationEvents[1].sequence
				event = table.remove session.presentationEvents, 1
				canvas\SetPresentationExit event.exitPath
			if session.visualResult and follower and
					follower\hasReached session.visualResult.finalSequence
				canvas\ApplyVisualResult session.visualResult
				session.visualApplied = true
				session.visualResult = nil
			if session.terminal and session.visualApplied
				pathfinder = canvas\GetPathFinder!
				pathfinder.phase = Moonpanel.Canvas.TraceEngine.Phase.Feedback if pathfinder
				canvas\SetObserverFollower nil
				Moonpanel.Net.SyncClickerState!
				Moonpanel.Net.TraceSessions[panel] = nil
				panel\SetController game.GetWorld!
		elseif session.controller == LocalPlayer! and session.terminal and session.visualApplied
			Moonpanel.Net.TraceSessions[panel] = nil
			panel\SetController game.GetWorld!
			Moonpanel.Net.SyncClickerState!

	Moonpanel.Net.SyncClickerState!

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
	pathfinder = panel\GetCanvas!\GetPathFinder!
	definition = panel\GetCanvas!\GetRuleDefinition!
	return unless pathfinder and revision == pathfinder.topology.revision
	return unless definition and ruleRevision == definition.ruleRevision
	existing = Moonpanel.Net.TraceSessions[panel]
	provisional = existing and existing.provisional and existing.controller == LocalPlayer!
	provisionalSamples = provisional and existing.unsent or nil
	provisionalAction = provisional and existing.pendingAction or nil
	if existing and existing.id == sessionId
		if controller ~= LocalPlayer! or Moonpanel\IsServerAuthoritativeTrace!
			oldExitPath = pathfinder\isExitPath!
			pathfinder\restore snapshot
			follower = panel\GetCanvas!\GetObserverFollower!
			unless follower
				follower = Moonpanel.Canvas.ObserverTraceFollower pathfinder.topology
				follower\reset snapshot, true, lastSequence
				panel\GetCanvas!\SetObserverFollower follower
			else
				follower\setTarget snapshot, lastSequence
			existing.serverSequence = lastSequence
			existing.serverHash = pathfinder\hash!
			if oldExitPath ~= pathfinder\isExitPath!
				table.insert existing.presentationEvents, {
					sequence: lastSequence
					exitPath: pathfinder\isExitPath!
				}
		return
	if existing and not provisional and existing.controller == LocalPlayer! and Moonpanel.EndPillarOrbit
		Moonpanel\EndPillarOrbit LocalPlayer!
	return unless pathfinder\restore snapshot
	canvas = panel\GetCanvas!
	importedPlay = canvas\GetPlayDataSnapshot!
	lateJoin = lastSequence > 0 or importedPlay and
		importedPlay.sessionId == sessionId
	canvas\SetPlayData {
		startTime: lateJoin and importedPlay and importedPlay.startTime or CurTime!
		endTime: lateJoin and importedPlay and importedPlay.endTime or nil
		:controller
		touchingExit: snapshot.touchingExit == true
		sessionId: sessionId
	}
	unless provisional
		canvas\BeginPresentation { :sessionId, :revision }, lateJoin
	canvas\SetPresentationExit pathfinder\isExitPath!, lateJoin

	local follower
	if controller ~= LocalPlayer! or Moonpanel\IsServerAuthoritativeTrace!
		follower = Moonpanel.Canvas.ObserverTraceFollower pathfinder.topology
		follower\reset snapshot, true, lastSequence
		canvas\SetObserverFollower follower
	else
		canvas\SetObserverFollower nil

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
		:follower
		nextFlush: RealTime! + 0.05
	}
	if panel.MoonpanelPillar and controller == LocalPlayer!
		unless Moonpanel\BeginPillarOrbit panel, controller, sessionId, orbitSeed
			Moonpanel.Net.TraceSessions[panel] = nil
			panel\SetController game.GetWorld!
			Moonpanel.Net.SendFocusExit!
			return
	elseif controller == LocalPlayer! and Moonpanel.PillarFocusAngles
		Moonpanel.PillarFocusAngles[controller] = nil
	panel\SetController controller
	Moonpanel.Net.SyncClickerState!
	playData = canvas\GetPlayDataSnapshot!
	playData.controller = controller
	canvas\SetPlayData playData
	Moonpanel.Net.SyncClickerState!
	if provisional
		for sample in *provisionalSamples
			canvas\ApplyTraceSample sample.xQ, sample.yQ, sample.boost,
				controller, sample.constraints
		sequenceIndex = 1
		for sample in *Moonpanel.Net.TraceSessions[panel].unsent
			sample.hash = pathfinder\hash!
			Moonpanel.Net.TraceSessions[panel].pending[sequenceIndex].hash = sample.hash
			sequenceIndex += 1
		Moonpanel.Net.PendingTraceStarts[panel] = nil
		if provisionalAction
			Moonpanel.Net.TraceSessions[panel].pendingAction = nil
			Moonpanel.Net.SendTraceAction panel, provisionalAction

receive flowTypes.TraceControlReject, ->
	panel = net.ReadEntity!
	reason = net.ReadUInt 4
	return unless panel and panel.Moonpanel and panel\GetCanvas!
	session = Moonpanel.Net.TraceSessions[panel]
	pending = Moonpanel.Net.PendingTraceStarts[panel]
	return unless pending
	if session and not session.provisional
		Moonpanel.Net.PendingTraceStarts[panel] = nil
		return
	return unless session and session.provisional
	canvas = panel\GetCanvas!
	pathfinder = canvas\GetPathFinder!
	canvas\ResetRuntime "start-rejected"
	pathfinder\restore pending.snapshot if pending.snapshot
	canvas\SetPlayData pending.playData or {}
	canvas\SetPresentationExit pathfinder\isExitPath!, true
	Moonpanel.Net.ClearTraceSession panel
	Moonpanel.Net.SyncClickerState!
	MsgC Color(255, 150, 80), "[Moonpanel] predicted trace start rejected (reason ",
		tostring(reason), ")\n"

receive flowTypes.TraceObserverAdvance, ->
	panel = net.ReadEntity!
	return unless validPanel panel
	session = Moonpanel.Net.TraceSessions[panel]
	sessionId = net.ReadUInt 32
	firstSequence = net.ReadUInt 32
	count = net.ReadUInt 4
	samples = {}
	invalidConstraints = false
	for i = 1, count
		xQ = net.ReadInt 16
		yQ = net.ReadInt 16
		boost = net.ReadBool!
		commandNumber = net.ReadUInt 32
		constraintCount = net.ReadUInt 2
		invalidConstraints = true if constraintCount > 2
		constraints = {}
		for decision = 1, constraintCount
			table.insert constraints, net.ReadUInt 32
		table.insert samples, { :xQ, :yQ, :boost, :commandNumber, :constraints }
	serverHash = net.ReadUInt 32
	return unless session and session.id == sessionId
	isLocalController = session.controller == LocalPlayer!
	return if isLocalController and not Moonpanel\IsServerAuthoritativeTrace!
	return unless count > 0 and count <= 12
	return if invalidConstraints
	return unless firstSequence == session.serverSequence + 1

	canvas = panel\GetCanvas!
	pathfinder = canvas\GetPathFinder!
	oldExitPath = pathfinder\isExitPath!
	for sample in *samples
		if isLocalController and not Moonpanel\IsServerAuthoritativeTrace!
			canvas\ApplyTraceSample sample.xQ, sample.yQ, sample.boost,
				nil, sample.constraints
		else
			pathfinder\applySample sample.xQ, sample.yQ, sample.boost,
				nil, sample.constraints
	finalSequence = firstSequence + count - 1
	session.serverSequence = finalSequence
	session.serverHash = serverHash
	if isLocalController
		while session.pending[1] and session.pending[1].sequence <= finalSequence
			table.remove session.pending, 1
		unless Moonpanel\IsServerAuthoritativeTrace!
			return unless pathfinder\hash! == serverHash
			return
	else
		clientHash = pathfinder\hash!
		if clientHash ~= serverHash
			MsgC Color(255, 120, 40),
				"[Moonpanel] observer trace desync: session ",
				tostring(sessionId), " sequence ", tostring(finalSequence),
				" client ", tostring(clientHash), " server ",
				tostring(serverHash), " revision ", tostring(session.revision), "\n"
			return
	if oldExitPath ~= pathfinder\isExitPath!
		table.insert session.presentationEvents, {
			sequence: finalSequence
			exitPath: pathfinder\isExitPath!
		}
	if follower = canvas\GetObserverFollower!
		follower\setTarget pathfinder\snapshot!, finalSequence

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
	pathfinder = panel\GetCanvas!\GetPathFinder!
	clientHash = pathfinder\hash!
	return unless pathfinder\restore snapshot
	session.serverSequence = lastSequence
	if Moonpanel.PillarController and Moonpanel.PillarController.ClearCommands and
			session.controller == LocalPlayer!
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
			pathfinder\applySample sample.xQ, sample.yQ, sample.boost,
				session.controller, sample.constraints
			sample.hash = pathfinder\hash!
		session.pending = replay
	panel\GetCanvas!\MarkRenderDirty! if panel\GetCanvas!\MarkRenderDirty
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
			if session.controller == LocalPlayer!
				Moonpanel\EndPillarOrbit LocalPlayer! if Moonpanel.EndPillarOrbit
				pathfinder = panel\GetCanvas!\GetPathFinder! if validPanel panel
				if pathfinder
					if aborted
						pathfinder.phase = Moonpanel.Canvas.TraceEngine.Phase.Feedback
					elseif not Moonpanel\IsServerAuthoritativeTrace! and
						pathfinder.phase == Moonpanel.Canvas.TraceEngine.Phase.Tracing
						pathfinder\beginEvaluation!
				panel\SetController game.GetWorld! if validPanel panel
				Moonpanel.Net.SyncClickerState!
			Moonpanel.Net.PendingTraceStarts[panel] = nil
			session.terminal = true
			session.aborted = aborted
			session.visualApplied = true if session.controller == LocalPlayer!
			if session.controller ~= LocalPlayer!
				session.terminal = true
				session.aborted = aborted
	Moonpanel.Net.SyncClickerState!

receive flowTypes.PanelRequestDataFromPlayer, ->
	entity = net.ReadEntity!
	return unless IsValid(entity) and entity.Moonpanel and entity.GetCanvas
	data = if Moonpanel.Editor and Moonpanel.Editor.GetCurrentData
		Moonpanel.Editor\GetCurrentData!
	else
		Moonpanel.Canvas.SampleData
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
	canvas = panel\GetCanvas! if panel.Moonpanel and panel.GetCanvas
	return unless canvas and canvas.ImportNetworkState
	canvas\ImportNetworkState panel, data
	request.callback panel, data if istable(request) and isfunction(request.callback)

receive flowTypes.PanelResetPresentation, ->
	panel = net.ReadEntity!
	serial = net.ReadUInt 32
	snapshot = net.ReadTable!
	return unless IsValid(panel) and panel.Moonpanel and panel.GetCanvas and
		istable(snapshot)
	canvas = panel\GetCanvas!
	canvas\BeginResetPresentation snapshot, serial if canvas and
		canvas.BeginResetPresentation

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
	pathfinder = canvas\GetPathFinder!
	return unless pathfinder and result.revision == pathfinder.topology.revision
	return unless newerSerial result.eventSerial, canvas\GetVisualEventSerial!
	canvas\SetSolvedState result.solved == true if canvas.SetSolvedState
	session = Moonpanel.Net.TraceSessions[panel]
	return unless session and session.id == result.sessionId and
		session.revision == result.revision and
		session.ruleRevision == result.ruleRevision
	canvas\SetVisualEventSerial result.eventSerial
	session.terminal = true
	unless panel\GetPowered!
		canvas\ResetPresentation "power-loss"
		session.visualApplied = true
		Moonpanel.Net.SyncClickerState!
		return
	if session.controller == LocalPlayer! and not Moonpanel\IsServerAuthoritativeTrace!
		pathfinder.phase = Moonpanel.Canvas.TraceEngine.Phase.Feedback
		localHash = pathfinder\hash!
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
			result.snapshot = pathfinder\snapshot!
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
			canvas\CancelSolution "server-result" if canvas.CancelSolution
			canvas\ApplyVisualResult result, 0, localReport ~= nil or
				canvas\GetPredictedVisual! ~= nil
			session.visualApplied = true
	elseif session.controller == LocalPlayer! and Moonpanel\IsServerAuthoritativeTrace!
		session.visualResult = result
	else
		session.visualResult = result
	Moonpanel.Net.SyncClickerState!

receive flowTypes.EditorOpen, ->
	surfaceKind = net.ReadUInt 1
	Moonpanel.Editor\Open surfaceKind if Moonpanel.Editor and Moonpanel.Editor.Open
