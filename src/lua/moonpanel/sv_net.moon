receive = Moonpanel.Net.Receive
flowTypes = Moonpanel.Net.FlowTypes
startFlow = Moonpanel.Net.StartFlow

Moonpanel.Net.PendingPlayerDataRequests or= {}
-- Full panel snapshots are relatively expensive and should not be usable as
-- an unbounded request/response loop. Keep this per recipient so a player
-- who has already received a panel does not affect anyone else's sync.
Moonpanel.Net.PanelDataSyncState or= setmetatable {}, __mode: "k"
Moonpanel.Net.PanelDataRequestCooldown = 1
Moonpanel.Net.PillarProofTimeout = 1.5
Moonpanel.Net.EditorPayloadMaxCompressed = 128 * 1024
Moonpanel.Net.EditorPayloadMaxDecompressed = 512 * 1024
Moonpanel.Net.EditorPayloadMaxDepth = 16
Moonpanel.Net.EditorPayloadMaxEntries = 20000
Moonpanel.Net.EditorPayloadMaxString = 8192
Moonpanel.Net.TraceMaxPacketBits = 32768
Moonpanel.Net.TraceMaxPillarQueue = 8

Moonpanel.Net.MarkMalformedPacket = (ply) ->
	return unless IsValid(ply) and ply\IsPlayer!
	now = CurTime!
	state = ply.__moonpanelMalformed or { count: 0, window: now, until: 0 }
	if now - state.window > 5
		state.count = 0
		state.window = now
	state.count += 1
	state.until = now + 1 if state.count >= 3
	ply.__moonpanelMalformed = state

Moonpanel.Net.PacketCooling = (ply) ->
	state = IsValid(ply) and ply.__moonpanelMalformed
	state and CurTime! < (state.until or 0)

Moonpanel.Net.GetPanelOwner = (panel) ->
	return unless IsValid panel
	if panel.CPPIGetOwner
		owner = panel\CPPIGetOwner!
		return owner if IsValid(owner) and owner\IsPlayer!
		return
	if panel.GetCreator
		owner = panel\GetCreator!
		return owner if IsValid(owner) and owner\IsPlayer!

Moonpanel.Net.CanEditPanel = (ply, panel) ->
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
	owner = Moonpanel.Net.GetPanelOwner panel
	IsValid(owner) and owner == ply

Moonpanel.Net.ValidateEditorPayload = (value) ->
	state = { entries: 0 }
	visit = (current, depth) ->
		typeName = type current
		if typeName == "string"
			return #current <= Moonpanel.Net.EditorPayloadMaxString
		if typeName == "number"
			return current == current and math.abs(current) <= 2147483647
		return true if typeName == "boolean"
		return false unless typeName == "table"
		return false if depth > Moonpanel.Net.EditorPayloadMaxDepth
		state.entries += 1
		return false if state.entries > Moonpanel.Net.EditorPayloadMaxEntries
		for key, child in pairs current
			return false unless type(key) == "string" or type(key) == "number"
			return false unless visit child, depth + 1
		true
	return false unless istable value
	visit value, 0

Moonpanel.Net.SendControlGrant = (recipients, panel, omitController = false) ->
	session = panel.__traceSession or panel.__endingTraceSession
	return unless session
	startFlow flowTypes.TraceControlGrant
	net.WriteEntity panel
	net.WriteEntity session.controller
	net.WriteUInt session.id, 32
	net.WriteUInt session.revision, 32
	net.WriteUInt session.ruleRevision or 0, 32
	net.WriteUInt session.lastSequence, 32
	net.WriteTable panel\GetCanvas!\GetPathFinder!\snapshot!
	hasOrbitSeed = panel.MoonpanelPillar == true and istable session.orbitSeed
	net.WriteBool hasOrbitSeed
	net.WriteTable session.orbitSeed if hasOrbitSeed
	if omitController and IsValid session.controller
		net.SendOmit session.controller
	elseif recipients
		net.Send recipients
	else
		net.Broadcast!

Moonpanel.Net.SendTraceAck = (ply, panel, session) ->
	startFlow flowTypes.TraceAck
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.lastSequence, 32
	net.WriteUInt panel\GetCanvas!\GetPathFinder!\hash!, 32
	net.Send ply

Moonpanel.Net.SendTraceResync = (ply, panel, session) ->
	pathfinder = panel\GetCanvas!\GetPathFinder!
	startFlow flowTypes.TraceResyncSnapshot
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt session.lastSequence, 32
	net.WriteUInt pathfinder\hash!, 32
	net.WriteTable pathfinder\snapshot!
	net.Send ply

Moonpanel.Net.BroadcastObserverAdvance = (controller, panel, session, firstSequence, samples) ->
	pathfinder = panel\GetCanvas!\GetPathFinder!
	return unless pathfinder
	startFlow flowTypes.TraceObserverAdvance
	net.WriteEntity panel
	net.WriteUInt session.id, 32
	net.WriteUInt firstSequence, 32
	net.WriteUInt #samples, 4
	for sample in *samples
		net.WriteInt sample.xQ, 16
		net.WriteInt sample.yQ, 16
		net.WriteBool sample.boost
		net.WriteUInt sample.commandNumber or 0, 32
		net.WriteUInt #sample.constraints, 2
		for decision in *sample.constraints
			net.WriteUInt decision, 32
	net.WriteUInt pathfinder\hash!, 32
	if IsValid controller
		net.SendOmit controller
	else
		net.Broadcast!

Moonpanel.Net.BroadcastTraceResult = (panel, sessionId, aborted) ->
	startFlow flowTypes.TraceResult
	net.WriteEntity panel
	net.WriteUInt sessionId, 32
	net.WriteBool aborted == true
	net.Broadcast!

Moonpanel.Net.SendPanelData = (ply, panel, data) ->
	return false unless IsValid(ply) and ply\IsPlayer! and IsValid(panel)
	startFlow flowTypes.PanelRequestData
	net.WriteEntity panel
	net.WriteTable data
	net.Send ply

	state = Moonpanel.Net.PanelDataSyncState[ply]
	unless state
		state = setmetatable {}, __mode: "k"
		Moonpanel.Net.PanelDataSyncState[ply] = state
	state[panel] = {
		hash: Moonpanel.Net.HashPanelSyncData data
		nextRequest: CurTime! + Moonpanel.Net.PanelDataRequestCooldown
	}
	true

Moonpanel.Net.HashPanelSyncData = (data) ->
	return unless istable data
	-- visualElapsed is presentation timing, not panel state. Hashing it would
	-- turn every later request for an unchanged solved panel into a new sync.
	hashData = table.Copy data
	hashData.visualElapsed = nil
	return Moonpanel.Canvas.RuleEngine\HashValue hashData if Moonpanel.Canvas.RuleEngine
	-- This fallback is only for load-order safety. Normal panel networking
	-- loads the shared rule engine before this module is used.
	json = util.TableToJSON hashData
	tonumber(util.CRC(json or "")) or 0

Moonpanel.Net.GetPanelSyncState = (ply, panel) ->
	state = Moonpanel.Net.PanelDataSyncState[ply]
	state and state[panel]

Moonpanel.Net.ClearPanelSyncState = (panel) ->
	for ply, state in pairs Moonpanel.Net.PanelDataSyncState
		state[panel] = nil if state

Moonpanel.Net.BroadcastVisualResult = (panel, data) ->
	return unless IsValid panel
	session = panel.__traceSession or panel.__endingTraceSession
	return unless session
	pathfinder = panel\GetCanvas!\GetPathFinder!
	return unless pathfinder
	panel.__visualEventSerial = ((panel.__visualEventSerial or 0) + 1) % 4294967295
	panel.__visualEventSerial = 1 if panel.__visualEventSerial == 0
	envelope = {
		sessionId: session.id
		revision: session.revision
		finalSequence: session.lastSequence
		finalHash: pathfinder\hash!
		ruleRevision: session.ruleRevision or 0
		reportHash: data.reportHash or 0
		snapshot: pathfinder\snapshot!
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
		eventSerial: panel.__visualEventSerial
	}
	panel.__lastVisualResult = table.Copy envelope
	panel.__lastVisualResultAt = CurTime!
	panel\SetSolvedState envelope.success, envelope if panel.SetSolvedState
	startFlow flowTypes.TraceVisualResult
	net.WriteEntity panel
	net.WriteTable envelope
	net.Broadcast!
	panel.__endingTraceSession = nil if panel.__endingTraceSession == session

Moonpanel.Net.SendEditorOpen = (ply, surfaceKind = Moonpanel.Canvas.SurfaceKind.Flat) ->
	startFlow flowTypes.EditorOpen
	net.WriteUInt surfaceKind, 1
	net.Send ply

Moonpanel.Net.PanelRequestDataFromPlayer = (ply, panel, callback) ->
	return false unless Moonpanel.Net.CanEditPanel ply, panel
	for current, data in pairs Moonpanel.Net.PendingPlayerDataRequests
		if not IsValid(current) or not IsValid(data.ply) or
				(data.deadline and CurTime! > data.deadline)
			Moonpanel.Net.PendingPlayerDataRequests[current] = nil
	Moonpanel.Net.PendingPlayerDataRequests[panel] = {
		:ply
		:callback
		deadline: CurTime! + 10
	}
	true

receive flowTypes.PanelRequestControl, (len, ply) ->
	Moonpanel\RequestControl ply, net.ReadEntity!, net.ReadUInt(16), net.ReadUInt(16),
		net.ReadUInt(14) / 1000, net.ReadUInt(14) / 1000,
		net.ReadUInt(10) / 1000

receive flowTypes.FocusExit, (len, ply) ->
	Moonpanel\SetFocused ply, false if Moonpanel\IsFocused ply

hook.Add "PlayerDisconnected", "Moonpanel Multiplayer Safeguards", (ply) ->
	for panel, request in pairs Moonpanel.Net.PendingPlayerDataRequests
		Moonpanel.Net.PendingPlayerDataRequests[panel] = nil if request.ply == ply
	state = Moonpanel.Canvas.VerifierState
	canvas = state and state.activeByPlayer[ply]
	canvas\CancelSolution("player_disconnect") if canvas and canvas.CancelSolution
	ply.__moonpanelMalformed = nil
	Moonpanel.Net.PanelDataSyncState[ply] = nil

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

	pathfinder = panel\GetCanvas!\GetPathFinder!
	return "invalid" unless pathfinder
	pillarCorrection = false
	proofRecords = {}
	for sample in *batch.samples
		proof = nil
		original = {
			xQ: sample.xQ
			yQ: sample.yQ
			commandNumber: sample.commandNumber
		}
		actualStart = pathfinder\hash!
		if panel.MoonpanelPillar
			proof = session.pillarProofs[sample.commandNumber]
			session.pillarProofs[sample.commandNumber] = nil
			if sample.xQ ~= proof.acceptedXQ or sample.yQ ~= proof.acceptedYQ
				sample.xQ = proof.acceptedXQ
				sample.yQ = proof.acceptedYQ
				pillarCorrection = true
		context = if panel.MoonpanelPillar and proof and
			proof.motionAxis == "x" then nil else ply
		panel\GetCanvas!\ApplyTraceSample sample.xQ, sample.yQ, sample.boost,
			context, sample.constraints
		session.lastSequence += 1
		if proof
			table.insert proofRecords, {
				sample: original
				:proof
				:actualStart
				actualEnd: pathfinder\hash!
			}

	serverHash = pathfinder\hash!
	Moonpanel.Net.BroadcastObserverAdvance ply, panel, session,
		batch.firstSequence, batch.samples
	Moonpanel.Net.SendTraceAck ply, panel, session
	if pillarCorrection or serverHash ~= batch.predictedHash
		for record in *proofRecords
			logPillarProof session, record.sample, record.proof,
				record.actualStart, record.actualEnd
		MsgC Color(255, 120, 40), "[Moonpanel] trace desync session ",
			tostring(session.id), " sequence ", tostring(session.lastSequence),
			" client ", tostring(batch.predictedHash), " server ",
			tostring(serverHash), " revision ", tostring(session.revision), "\n"
		Moonpanel.Net.SendTraceResync ply, panel, session
	"applied"

Moonpanel.Net.ProcessPendingPillarBatches = (panel, session) ->
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

finishTraceAction = (panel, session, action) ->
	if action == 1 and panel\GetCanvas!\GetPathFinder!\canSubmit!
		panel\EndTraceSession false
	else
		panel\EndTraceSession true

Moonpanel.Net.ProcessPendingPillarSession = (panel, session) ->
	return false unless Moonpanel.Net.ProcessPendingPillarBatches panel, session
	action = session.pendingPillarAction
	return true unless action
	if action.finalSequence == session.lastSequence
		session.pendingPillarAction = nil
		finishTraceAction panel, session, action.action
		return true
	return false if CurTime! > action.deadline
	true

receive flowTypes.TraceInputBatch, (len, ply) ->
	return if len > Moonpanel.Net.TraceMaxPacketBits or
		Moonpanel.Net.PacketCooling ply
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	revision = net.ReadUInt 32
	ruleRevision = net.ReadUInt 32
	firstSequence = net.ReadUInt 32
	count = net.ReadUInt 4
	samples = {}
	invalidConstraints = false
	invalidSample = false
	for i = 1, count
		xQ = net.ReadInt 16
		yQ = net.ReadInt 16
		invalidSample = true if math.abs(xQ) > 32767 or math.abs(yQ) > 32767
		boost = net.ReadBool!
		commandNumber = net.ReadUInt 32
		constraintCount = net.ReadUInt 2
		invalidConstraints = true if constraintCount > 2
		constraints = {}
		for decision = 1, constraintCount
			table.insert constraints, net.ReadUInt 32
		table.insert samples, {
			:xQ
			:yQ
			:boost
			:commandNumber
			:constraints
		}
	predictedHash = net.ReadUInt 32

	return unless IsValid(panel) and panel.Moonpanel and panel.GetCanvas
	session = panel.__traceSession
	return unless session and session.controller == ply and session.id == sessionId
	return unless revision == session.revision
	return unless ruleRevision == session.ruleRevision
	return unless count > 0 and count <= 12
	if invalidSample or invalidConstraints
		Moonpanel.Net.MarkMalformedPacket ply
		return
	return unless firstSequence == queuedFinalSequence(session) + 1
	return unless ply\Alive! and Moonpanel\IsFocused(ply) and panel\GetPowered!
	return unless panel\GetController! == ply
	return if ply\EyePos!\DistToSqr(panel\GetPos!) > 1024 * 1024

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
		if #(session.pendingPillarBatches or {}) >= Moonpanel.Net.TraceMaxPillarQueue
			Moonpanel.Net.MarkMalformedPacket ply
			return
		session.pendingPillarBatches or= {}
		table.insert session.pendingPillarBatches, batch
		unless Moonpanel.Net.ProcessPendingPillarBatches panel, session
			panel\EndTraceSession true
	else
		unless processTraceBatch(ply, panel, session, batch) == "applied"
			panel\EndTraceSession true

receive flowTypes.TraceAction, (len, ply) ->
	return if len > 1024 or Moonpanel.Net.PacketCooling ply
	panel = net.ReadEntity!
	sessionId = net.ReadUInt 32
	revision = net.ReadUInt 32
	ruleRevision = net.ReadUInt 32
	finalSequence = net.ReadUInt 32
	action = net.ReadUInt 2
	return unless IsValid(panel) and panel.__traceSession
	session = panel.__traceSession
	return unless session.id == sessionId and session.controller == ply
	return unless revision == session.revision and ruleRevision == session.ruleRevision
	return unless ply\Alive! and Moonpanel\IsFocused(ply) and panel\GetPowered!
	return unless panel\GetController! == ply
	return if ply\EyePos!\DistToSqr(panel\GetPos!) > 1024 * 1024
	if panel.MoonpanelPillar
		unless Moonpanel.Net.ProcessPendingPillarBatches panel, session
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
	finishTraceAction panel, session, action

receive flowTypes.PanelRequestData, (len, ply) ->
	entity = net.ReadEntity!
	return unless IsValid(entity) and entity.Moonpanel and entity.GetCanvas
	now = CurTime!
	syncState = Moonpanel.Net.GetPanelSyncState ply, entity
	if syncState
		return if syncState.nextRequest and now < syncState.nextRequest
		currentData = entity\BuildPanelSyncData! if entity.BuildPanelSyncData
		return if currentData and
			Moonpanel.Net.HashPanelSyncData(currentData) == syncState.hash
	request = Moonpanel.Net.PendingPlayerDataRequests[entity]
	if request and request.ply == ply
		startFlow flowTypes.PanelRequestDataFromPlayer
		net.WriteEntity entity
		net.Send ply
	entity\SyncPlayer ply

receive flowTypes.PanelRequestDataFromPlayer, (len, ply) ->
	entity = net.ReadEntity!
	request = Moonpanel.Net.PendingPlayerDataRequests[entity]
	return unless request and request.ply == ply
	return unless IsValid(entity) and entity.Moonpanel and entity.GetCanvas
	unless Moonpanel.Net.CanEditPanel ply, entity
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		return
	if request.deadline and CurTime! > request.deadline
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		return
	compressedLength = net.ReadUInt 32
	if compressedLength <= 0 or
		compressedLength > Moonpanel.Net.EditorPayloadMaxCompressed
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		Moonpanel.Net.MarkMalformedPacket ply
		return
	compressed = net.ReadData compressedLength
	unless compressed
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		Moonpanel.Net.MarkMalformedPacket ply
		return
	json = util.Decompress compressed
	unless json
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		Moonpanel.Net.MarkMalformedPacket ply
		return
	if #json > Moonpanel.Net.EditorPayloadMaxDecompressed
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		Moonpanel.Net.MarkMalformedPacket ply
		return
	data = util.JSONToTable json
	unless data and Moonpanel.Net.ValidateEditorPayload data
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		Moonpanel.Net.MarkMalformedPacket ply
		return
	data = Moonpanel.Canvas.SanitizeData data
	unless data and istable data
		Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
		Moonpanel.Net.MarkMalformedPacket ply
		return
	Moonpanel.Net.PendingPlayerDataRequests[entity] = nil
	request.callback data
