receive = Moonpanel.Net.Receive
flowTypes = Moonpanel.Net.FlowTypes
startFlow = Moonpanel.Net.StartFlow

Moonpanel.Net.PendingPlayerDataRequests or= {}
-- Full panel snapshots are relatively expensive and should not be usable as
-- an unbounded request/response loop. Keep this per recipient so a player
-- who has already received a panel does not affect anyone else's sync.
panelDataSyncState = setmetatable {}, __mode: "k"
panelDataRequestCooldown = 1
Moonpanel.Net.PillarProofTimeout = 1.5
editorPayloadMaxCompressed = 128 * 1024
editorPayloadMaxDecompressed = 512 * 1024
editorPayloadMaxDepth = 16
editorPayloadMaxEntries = 20000
editorPayloadMaxString = 8192
traceMaxPacketBits = 32768
traceMaxPillarQueue = 8

markMalformedPacket = (ply) ->
	return unless IsValid(ply) and ply\IsPlayer!
	now = CurTime!
	state = ply.__moonpanelMalformed or { count: 0, window: now, until: 0 }
	if now - state.window > 5
		state.count = 0
		state.window = now
	state.count += 1
	state.until = now + 1 if state.count >= 3
	ply.__moonpanelMalformed = state

packetCooling = (ply) ->
	state = IsValid(ply) and ply.__moonpanelMalformed
	state and CurTime! < (state.until or 0)

getPanelOwner = (panel) ->
	return unless IsValid panel
	if panel.CPPIGetOwner
		owner = panel\CPPIGetOwner!
		return owner if IsValid(owner) and owner\IsPlayer!
		return
	if panel.GetCreator
		owner = panel\GetCreator!
		return owner if IsValid(owner) and owner\IsPlayer!

canEditPanel = (ply, panel) ->
	return false unless IsValid(ply) and ply\IsPlayer! and
		IsValid(panel) and panel.Moonpanel
	trace = {
		Entity: panel
		Hit: true
		HitPos: panel\GetPos!
		HitNormal: Vector 0, 0, 1
	}
	return false if hook.Run("CanTool", ply, trace, "moonpanel") == false
	return false if hook.Run("CanPlayerUse", ply, panel) == false
	return true if ply\IsAdmin! or ply\IsSuperAdmin!
	owner = getPanelOwner panel
	IsValid(owner) and owner == ply

validateEditorPayload = (value) ->
	state = { entries: 0 }
	visit = (current, depth) ->
		typeName = type current
		if typeName == "string"
			return #current <= editorPayloadMaxString
		if typeName == "number"
			return current == current and math.abs(current) <= 2147483647
		return true if typeName == "boolean"
		return false unless typeName == "table"
		return false if depth > editorPayloadMaxDepth
		state.entries += 1
		return false if state.entries > editorPayloadMaxEntries
		for key, child in pairs current
			return false unless type(key) == "string" or type(key) == "number"
			return false unless visit child, depth + 1
		true
	return false unless istable value
	visit value, 0

readEditorPayload = ->
	compressedLength = net.ReadUInt 32
	return unless compressedLength > 0 and
		compressedLength <= editorPayloadMaxCompressed
	compressed = net.ReadData compressedLength
	json = compressed and util.Decompress compressed
	return unless json and #json <= editorPayloadMaxDecompressed
	data = util.JSONToTable json
	return unless data and validateEditorPayload data
	data = Moonpanel.Canvas.SanitizeData data
	return data if data and istable data

readValidEditorPayload = (ply) ->
	data = readEditorPayload!
	return data if data
	markMalformedPacket ply


Moonpanel.Net.SendControlGrant = (recipients, panel, omitController = false) ->
	session = panel\GetTraceSession! or panel\GetEndingTraceSession!
	return unless session
	startFlow flowTypes.TraceControlGrant
	net.WriteEntity panel
	net.WriteEntity session.controller
	net.WriteUInt session.id, 32
	net.WriteUInt session.revision, 32
	net.WriteUInt session.ruleRevision or 0, 32
	net.WriteUInt session.lastSequence, 32
	net.WriteTable panel\GetCanvas!\GetTraceSnapshot!
	hasOrbitSeed = panel.MoonpanelPillar == true and istable session.orbitSeed
	net.WriteBool hasOrbitSeed
	net.WriteTable session.orbitSeed if hasOrbitSeed
	if omitController and IsValid session.controller
		net.SendOmit session.controller
	elseif recipients
		net.Send recipients
	else
		net.Broadcast!

sendTraceControlReject = (ply, panel, reason = "unknown") ->
	return unless IsValid(ply) and ply\IsPlayer! and IsValid(panel)
	startFlow flowTypes.TraceControlReject
	net.WriteEntity panel
	reasons = Moonpanel.Net.TraceControlRejectReasons
	net.WriteUInt reasons[reason] or reasons.unknown, 4
	net.Send ply

sendTraceAck = (ply, panel, session) ->
	startFlow flowTypes.TraceAck
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.lastSequence, 32
	net.WriteUInt panel\GetCanvas!\GetTraceHash!, 32
	net.Send ply

sendTraceResync = (ply, panel, session) ->
	canvas = panel\GetCanvas!
	startFlow flowTypes.TraceResyncSnapshot
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.lastSequence, 32
	net.WriteUInt canvas\GetTraceHash!, 32
	net.WriteTable canvas\GetTraceSnapshot!
	net.Send ply

Moonpanel.Net.BroadcastObserverAdvance = (controller, panel, session, firstSequence, samples) ->
	canvas = panel\GetCanvas!
	return unless canvas
	startFlow flowTypes.TraceObserverAdvance
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt firstSequence, 32
	Moonpanel.Net.WriteTraceSamples samples
	net.WriteUInt canvas\GetTraceHash!, 32
	-- Controllers normally ignore this observer stream, but the
	-- server-authoritative debug mode consumes it directly.
	net.Broadcast!

Moonpanel.Net.BroadcastTraceResult = (panel, sessionId, aborted) ->
	startFlow flowTypes.TraceResult
	net.WriteEntity panel
	net.WriteUInt sessionId, 32
	net.WriteBool aborted == true
	net.Broadcast!

hashPanelSyncData = (data) ->
	return unless istable data
	-- visualElapsed is presentation timing, not panel state. Hashing it would
	-- turn every later request for an unchanged solved panel into a new sync.
	hashData = table.Copy data
	hashData.visualElapsed = nil
	Moonpanel.Canvas.RuleEngine\HashValue hashData

Moonpanel.Net.SendPanelData = (ply, panel, data) ->
	return false unless IsValid(ply) and ply\IsPlayer! and IsValid(panel)
	startFlow flowTypes.PanelRequestData
	net.WriteEntity panel
	net.WriteTable data
	net.Send ply

	state = panelDataSyncState[ply]
	unless state
		state = setmetatable {}, __mode: "k"
		panelDataSyncState[ply] = state
	state[panel] = {
		hash: hashPanelSyncData data
		nextRequest: CurTime! + panelDataRequestCooldown
	}
	true

Moonpanel.Net.BroadcastPanelResetPresentation = (panel, snapshot, serial) ->
	return unless IsValid(panel) and istable(snapshot)
	startFlow flowTypes.PanelResetPresentation
	net.WriteEntity panel
	net.WriteUInt math.max(0, math.floor(tonumber(serial) or 0)), 32
	net.WriteTable snapshot
	net.Broadcast!

getPanelSyncState = (ply, panel) ->
	state = panelDataSyncState[ply]
	state and state[panel]

Moonpanel.Net.ClearPanelSyncState = (panel) ->
	for ply, state in pairs panelDataSyncState
		state[panel] = nil if state

Moonpanel.Net.BroadcastVisualResult = (panel, data) ->
	return unless IsValid panel
	session = panel\GetTraceSession! or panel\GetEndingTraceSession!
	return unless session
	canvas = panel\GetCanvas!
	return unless canvas
	visualEventSerial = panel\NextVisualEventSerial!
	envelope = {
		sessionId: session.id
		revision: session.revision
		finalSequence: session.lastSequence
		finalHash: canvas\GetTraceHash!
		ruleRevision: session.ruleRevision or 0
		reportHash: data.reportHash or 0
		snapshot: canvas\GetTraceSnapshot!
		aborted: data.aborted == true
		success: data.success == true
		outcome: if data.aborted
			"abort"
		elseif data.success
			"success"
		else
			"failure"
		feedback: data.feedback or {
			violations: {}
			erasures: {}
			remaining: {}
			success: data.success == true
		}
		evaluationStatus: data.evaluationError or "complete"
		solved: data.success == true
		eventSerial: visualEventSerial
	}
	panel\ApplyTerminalResult envelope
	startFlow flowTypes.TraceVisualResult
	net.WriteEntity panel
	net.WriteTable envelope
	net.Broadcast!
	panel\ClearEndingTraceSession session

relayEditorState = (ply, open, surfaceKind = Moonpanel.Canvas.SurfaceKind.Flat) ->
	return unless IsValid(ply) and ply\IsPlayer!
	startFlow open and flowTypes.EditorOpen or flowTypes.EditorStatus
	net.WriteEntity ply
	net.WriteUInt surfaceKind, 1 if open
	net.Broadcast!
	true

Moonpanel.Net.SendEditorOpen = (ply, surfaceKind) ->
	relayEditorState ply, true, surfaceKind

receive flowTypes.EditorStatus, (_, ply) ->
	relayEditorState ply, false

receive flowTypes.EditorOpen, (_, ply) ->
	relayEditorState ply, true, net.ReadUInt(1)

Moonpanel.Net.SendPanelDataFromPlayerRequest = (ply, panel) ->
	return false unless IsValid(ply) and ply\IsPlayer! and
		IsValid(panel) and panel.Moonpanel
	startFlow flowTypes.PanelRequestDataFromPlayer
	net.WriteEntity panel
	net.Send ply
	true

Moonpanel.Net.PanelRequestDataFromPlayer = (ply, panel, callback) ->
	return false unless canEditPanel ply, panel
	for current, data in pairs Moonpanel.Net.PendingPlayerDataRequests
		if not IsValid(current) or not IsValid(data.ply) or
				(data.deadline and CurTime! > data.deadline)
			Moonpanel.Net.PendingPlayerDataRequests[current] = nil
	Moonpanel.Net.PendingPlayerDataRequests[panel] = {
		:ply
		:callback
		deadline: CurTime! + 10
	}
	Moonpanel.Net.SendPanelDataFromPlayerRequest ply, panel

receive flowTypes.PanelRequestControl, (len, ply) ->
	panel = net.ReadEntity!
	accepted, reason = Moonpanel\RequestControl ply, panel, net.ReadUInt(16), net.ReadUInt(16),
		net.ReadUInt(14) / 1000, net.ReadUInt(14) / 1000,
		net.ReadUInt(10) / 1000
	sendTraceControlReject ply, panel, reason unless accepted

receive flowTypes.FocusExit, (len, ply) ->
	Moonpanel\SetFocused ply, false if Moonpanel\IsFocused ply

hook.Add "PlayerDisconnected", "Moonpanel Multiplayer Safeguards", (ply) ->
	for panel, request in pairs Moonpanel.Net.PendingPlayerDataRequests
		Moonpanel.Net.PendingPlayerDataRequests[panel] = nil if request.ply == ply
	state = Moonpanel.Canvas.VerifierState
	canvas = state and state.activeByPlayer[ply]
	canvas\CancelSolution "player_disconnect" if canvas
	ply.__moonpanelMalformed = nil
	panelDataSyncState[ply] = nil

queuedFinalSequence = (session) ->
	sequence = session.lastSequence
	for batch in *(session.pendingPillarBatches or {})
		sequence += #batch.samples
	sequence

logPillarProof = (session, sample, proof, actualStart, actualEnd) ->
	-- A diagnostic must never be able to interrupt ordered session processing.
	sample or= {}
	proof or= {}
	MsgC Color(255, 120, 40), "[Moonpanel] pillar command proof session ",
		tostring(session.id), " command ", tostring(sample.commandNumber),
		" sample ", tostring(sample.xQ), "/", tostring(sample.yQ),
		" proof ", tostring(proof.acceptedXQ), "/",
		tostring(proof.acceptedYQ), " shadow ", tostring(proof.startHash),
		"->", tostring(proof.endHash), " canonical ", tostring(actualStart),
		"->", tostring(actualEnd), " radius ", tostring(proof.radius),
		" limits(p/l/w) ", tostring(proof.puzzleLimit), "/",
		tostring(proof.leadLimit), "/", tostring(proof.worldLimit), "\n"

processTraceBatch = (ply, panel, session, batch) ->
	return "invalid" unless batch.firstSequence == session.lastSequence + 1
	if panel.MoonpanelPillar
		for sample in *batch.samples
			return "invalid" if sample.commandNumber == 0 or
				(sample.xQ ~= 0 and sample.yQ ~= 0)
			return "wait" unless session.pillarProofs and
				session.pillarProofs[sample.commandNumber]

	canvas = panel\GetCanvas!
	return "invalid" unless canvas
	pillarCorrection = false
	proofRecords = {}
	for sample in *batch.samples
		proof = nil
		original = {
			xQ: sample.xQ
			yQ: sample.yQ
			commandNumber: sample.commandNumber
		}
		actualStart = canvas\GetTraceHash!
		if panel.MoonpanelPillar
			proof = session.pillarProofs[sample.commandNumber]
			session.pillarProofs[sample.commandNumber] = nil
			if sample.xQ ~= proof.acceptedXQ or sample.yQ ~= proof.acceptedYQ
				sample.xQ = proof.acceptedXQ
				sample.yQ = proof.acceptedYQ
				pillarCorrection = true
		context = if panel.MoonpanelPillar and proof and
			proof.motionAxis == "x" then nil else ply
		canvas\ApplyTraceSample sample.xQ, sample.yQ, sample.boost,
			context, sample.constraints
		session.lastSequence += 1
		if proof
			table.insert proofRecords, {
				sample: original
				:proof
				:actualStart
				actualEnd: canvas\GetTraceHash!
			}

	serverHash = canvas\GetTraceHash!
	Moonpanel.Net.BroadcastObserverAdvance ply, panel, session,
		batch.firstSequence, batch.samples
	sendTraceAck ply, panel, session
	if pillarCorrection or batch.predictedHash ~= 0 and
		serverHash ~= batch.predictedHash
		for record in *proofRecords
			logPillarProof session, record.sample, record.proof,
				record.actualStart, record.actualEnd
		MsgC Color(255, 120, 40), "[Moonpanel] trace desync session ",
			tostring(session.id), " sequence ", tostring(session.lastSequence),
			" client ", tostring(batch.predictedHash), " server ",
			tostring(serverHash), " revision ", tostring(session.revision), "\n"
		sendTraceResync ply, panel, session
	"applied"

processPendingPillarBatches = (panel, session) ->
	queue = session and session.pendingPillarBatches
	return true unless queue and queue[1]
	while queue[1]
		batch = queue[1]
		if CurTime! > batch.deadline
			MsgC Color(255, 100, 80),
				"[Moonpanel] pillar proof timed out for session ",
				tostring(session.id), " sequence ",
				tostring(batch.firstSequence), "\n"
			return false
		status = processTraceBatch session.controller, panel, session, batch
		return true if status == "wait"
		return false unless status == "applied"
		table.remove queue, 1
	true

finishTraceAction = (panel, action) ->
	if action == 1 and panel\GetCanvas!\CanSubmitTrace!
		panel\EndTraceSession false
	else
		panel\EndTraceSession true

validTraceSession = (panel, ply, sessionId, revision, ruleRevision) ->
	return unless IsValid(panel) and panel.Moonpanel
	session = panel\GetTraceSession!
	return unless session and session.controller == ply and session.id == sessionId
	return unless revision == session.revision and ruleRevision == session.ruleRevision
	session

activeTraceSession = (panel, ply, sessionId, revision, ruleRevision) ->
	session = validTraceSession panel, ply, sessionId, revision, ruleRevision
	return unless session and ply\Alive! and Moonpanel\IsFocused(ply) and
		panel\GetPowered! and panel\GetController! == ply
	return if ply\EyePos!\DistToSqr(panel\GetPos!) > 1024 * 1024
	session

Moonpanel.Net.ProcessPendingPillarSession = (panel, session) ->
	return false unless processPendingPillarBatches panel, session
	action = session.pendingPillarAction
	return true unless action
	if action.finalSequence == session.lastSequence
		session.pendingPillarAction = nil
		finishTraceAction panel, action.action
		return true
	return false if CurTime! > action.deadline
	true

receive flowTypes.TraceInputBatch, (len, ply) ->
	return if len > traceMaxPacketBits or packetCooling ply
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	revision = net.ReadUInt 32
	ruleRevision = net.ReadUInt 32
	firstSequence = net.ReadUInt 32
	samples, count, malformed = Moonpanel.Net.ReadTraceSamples!
	predictedHash = net.ReadUInt 32

	session = activeTraceSession panel, ply, sessionId, revision, ruleRevision
	return unless session
	if malformed
		markMalformedPacket ply
		return
	return unless firstSequence == queuedFinalSequence(session) + 1
	now = CurTime!
	if now - session.rateWindow >= 1
		session.rateWindow = now
		session.rateSamples = 0
	session.rateSamples += count
	if session.rateSamples > 480
		panel\EndTraceSession true
		return

	batch = {
		:firstSequence
		:samples
		:predictedHash
		deadline: CurTime! + Moonpanel.Net.PillarProofTimeout
	}
	if panel.MoonpanelPillar
		if #(session.pendingPillarBatches or {}) >= traceMaxPillarQueue
			markMalformedPacket ply
			return
		session.pendingPillarBatches or= {}
		table.insert session.pendingPillarBatches, batch
		unless processPendingPillarBatches panel, session
			panel\EndTraceSession true
	else
		unless processTraceBatch(ply, panel, session, batch) == "applied"
			panel\EndTraceSession true

receive flowTypes.TraceAction, (len, ply) ->
	return if len > 1024 or packetCooling ply
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	revision = net.ReadUInt 32
	ruleRevision = net.ReadUInt 32
	finalSequence = net.ReadUInt 32
	action = net.ReadUInt 2
	session = activeTraceSession panel, ply, sessionId, revision, ruleRevision
	return unless session
	if panel.MoonpanelPillar
		unless processPendingPillarBatches panel, session
			panel\EndTraceSession true
			return
		if finalSequence ~= session.lastSequence
			return unless finalSequence == queuedFinalSequence session
			session.pendingPillarAction = {
				:finalSequence
				:action
				deadline: CurTime! + Moonpanel.Net.PillarProofTimeout
			}
			return
	else
		return unless finalSequence == session.lastSequence
	finishTraceAction panel, action

receive flowTypes.PanelRequestData, (len, ply) ->
	entity = net.ReadEntity!
	return unless IsValid(entity) and entity.Moonpanel
	now = CurTime!
	syncState = getPanelSyncState ply, entity
	if syncState
		return if syncState.nextRequest and now < syncState.nextRequest
		currentData = entity\BuildPanelSyncData!
		return if currentData and
			hashPanelSyncData(currentData) == syncState.hash
	request = Moonpanel.Net.PendingPlayerDataRequests[entity]
	if request and request.ply == ply
		Moonpanel.Net.SendPanelDataFromPlayerRequest ply, entity
	entity\SyncPlayer ply

receive flowTypes.PanelRequestDataFromPlayer, (len, ply) ->
	entity = net.ReadEntity!
	request = Moonpanel.Net.PendingPlayerDataRequests[entity]
	return unless request and request.ply == ply
	return unless IsValid(entity) and entity.Moonpanel
	unless canEditPanel ply, entity
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		return
	if request.deadline and CurTime! > request.deadline
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		return
	Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
	data = readValidEditorPayload ply
	return unless data
	request.callback data
