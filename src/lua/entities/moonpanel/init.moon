AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"
include "moonpanel/sh_trace_session.lua"
include "moonpanel/sv_wire.lua"

wireDirection = (fromNode, toNode, width) ->
	return "?" unless fromNode and toNode
	dx = (toNode.x or 0) - (fromNode.x or 0)
	dy = (toNode.y or 0) - (fromNode.y or 0)
	if width and width > 0
		half = width * 0.5
		while dx > half
			dx -= width
		while dx < -half
			dx += width
	return "R" if math.abs(dx) > math.abs(dy) and dx > 0.000001
	return "L" if math.abs(dx) > math.abs(dy) and dx < -0.000001
	return "D" if math.abs(dy) > 0.000001 and dy > 0
	return "U" if math.abs(dy) > 0.000001 and dy < 0
	"?"

wirePath = (panel, result, maximum = 512) ->
	return "" unless result and result.snapshot and
		istable(result.snapshot.stacks)
	canvas = panel\GetCanvas!
	pathfinder = canvas and canvas\GetPathFinder!
	topology = pathfinder and pathfinder.topology
	return "" unless topology and topology.nodes
	data = canvas\GetData! if canvas
	width = data and data.Meta and tonumber(data.Meta.Width)
	stack = result.snapshot.stacks[1]
	return "" unless istable stack
	characters = {}
	for index = 2, #stack
		fromNode = topology.nodes[tonumber stack[index - 1]]
		toNode = topology.nodes[tonumber stack[index]]
		table.insert characters, wireDirection fromNode, toNode, width
		break if #characters >= maximum
	table.concat characters

wireErased = (panel, result) ->
	values = {}
	feedback = result and result.feedback
	canvas = panel\GetCanvas! if panel and panel.GetCanvas
	return values unless canvas and feedback and istable(feedback.erasures)
	for pair in *feedback.erasures
		index = tonumber(pair and pair.targetIndex)
		socket = index and canvas\GetSocketAtDataIndex index
		continue unless socket and socket.GetSocketType
		typeId = socket\GetSocketType!
		x, y = socket\GetX!, socket\GetY!
		if typeId == Moonpanel.Canvas.SocketType.Path
			typeId = socket\IsHorizontal! and 3 or 2
		elseif typeId == Moonpanel.Canvas.SocketType.Intersection
			typeId = 4
		elseif typeId == Moonpanel.Canvas.SocketType.Cell
			typeId = 1
		else
			continue
		table.insert values, Vector x, y, typeId
	values

ENT.InitializeSided = =>
    @PhysicsInit            SOLID_VPHYSICS
    @SetMoveType            MOVETYPE_VPHYSICS
    @SetSolid               SOLID_VPHYSICS
    @SetUseType             SIMPLE_USE
    @AddEFlags              EFL_FORCE_CHECK_TRANSMIT

    @__syncedPlayers = {}
    @__pendingSyncs = {}
	@__dataRevision = 0

    -- Server-side screen matrix for occlusion checks.
    info = Moonpanel.Canvas.ResolveScreenInfo @, @GetModel!
    @ScreenMatrix = Moonpanel.Canvas.BuildScreenMatrix info
    @ScreenInfo = info

ENT.GetWireState = => {
	powered: @GetPowered!
	solved: @GetSolvedState!
	errored: @GetErrored!
	success: @__wireSuccess or 0
	path: @__wirePath or ""
}

ENT.GetPanelRevision = => @__dataRevision or 0
ENT.GetTraceSession = =>
	return Moonpanel.TraceSession.Get(@) if Moonpanel.TraceSession and
		Moonpanel.TraceSession.Get
	@__traceSession
ENT.GetEndingTraceSession = =>
	return Moonpanel.TraceSession.GetEnding(@) if Moonpanel.TraceSession and
		Moonpanel.TraceSession.GetEnding
	@__endingTraceSession

ENT.SetTraceSession = (session) =>
	if Moonpanel.TraceSession and Moonpanel.TraceSession.Set
		return Moonpanel.TraceSession.Set @, session
	@__traceSession = session
	session

ENT.SetEndingTraceSession = (session) =>
	if Moonpanel.TraceSession and Moonpanel.TraceSession.SetEnding
		return Moonpanel.TraceSession.SetEnding @, session
	@__endingTraceSession = session
	session
ENT.SetVisualResult = (result, at = CurTime!) =>
	@__lastVisualResult = table.Copy result if istable result
	@__lastVisualResultAt = at if istable result
	true

ENT.NextVisualEventSerial = =>
	@__visualEventSerial = ((@__visualEventSerial or 0) + 1) % 4294967295
	@__visualEventSerial = 1 if @__visualEventSerial == 0
	@__visualEventSerial

ENT.GetVisualEventSerial = => @__visualEventSerial or 0
ENT.ClearEndingTraceSession = (session) =>
	if Moonpanel.TraceSession and Moonpanel.TraceSession.ClearEnding
		Moonpanel.TraceSession.ClearEnding @, session
	else
		@__endingTraceSession = nil if not session or @__endingTraceSession == session

ENT.BeginWireTrace = =>
	@__wireSuccess = 0
	@__wirePath = ""

ENT.ResetWireState = =>
	@__wireSuccess = 0
	@__wirePath = ""

ENT.SetWireSuccess = (value) =>
	@__wireSuccess = value == true and 1 or 0

ENT.HandleWireTerminalResult = (result, maximum = 512) =>
	return unless result
	@__wirePath = wirePath @, result, maximum
	@__wireSuccess = 0
	@SetErrored result.aborted ~= true and
		result.evaluationStatus ~= "complete"
	{
		path: @__wirePath
		erased: wireErased @, result
		aborted: result.aborted == true
		solved: result.success == true
		delayedSuccess: result.success == true and result.feedback and
			result.feedback.erasures and #result.feedback.erasures > 0
	}

ENT.SetData = (data, solved = false, visualResult = nil) =>
    data = Moonpanel.Canvas.SanitizeData data
    return false unless data
    activeSession = @GetTraceSession!
    endingSession = @GetEndingTraceSession!
    controller = activeSession and activeSession.controller
    controller or= @GetController! if @GetController
    @EndTraceSession true if activeSession
    if IsValid(controller) and controller\IsPlayer!
        Moonpanel\SetFocused controller, false if Moonpanel.IsFocused and
            Moonpanel\IsFocused controller
    @SetController game.GetWorld! if @SetController and
        IsValid(@GetController!) and @GetController!\IsPlayer!
    @GetCanvas!\CancelSolution("panel_edit") if @GetCanvas! and
        @GetCanvas!\CancelSolution
    timer.Remove "TheMP_SolvedState_#{@EntIndex!}" if timer and timer.Remove
    @__pendingSolvedResult = nil
    @SetSolvedState false if @SetSolvedState
    if endingSession
		Moonpanel.Net.BroadcastVisualResult @, {
            aborted: true
            evaluationError: "panel_edit"
        }
		@ClearEndingTraceSession!
    @__lastVisualResult = nil
    @__lastVisualResultAt = nil
    canvas = @GetCanvas!
    canvas\ImportData data
    importedData = canvas\ExportData!
    return false unless importedData
    @TheMoonpanelTileData = importedData
    @__dataRevision = ((@__dataRevision or 0) + 1) % 4294967295
    @__dataRevision = 1 if @__dataRevision == 0
    @SetSolvedState solved, visualResult if @SetSolvedState

	@SetPowered true
	@SetErrored false if @SetErrored

    @ExecutePendingSyncs!
    true

ENT.ExecutePendingSyncs = =>
    recipients = {}
    for ply in pairs @__syncedPlayers or {}
        recipients[ply] = true
    for ply in pairs @__pendingSyncs or {}
        recipients[ply] = true

    @__pendingSyncs = {}
    for ply in pairs recipients
        if IsValid(ply) and ply\IsPlayer!
            @SyncPlayer ply
        else
            @__syncedPlayers[ply] = nil

ENT.SyncPlayer = (ply) =>
    data = @BuildPanelSyncData!
    if not data
        @__pendingSyncs or= {}
        @__pendingSyncs[ply] = true
        return
    @__syncedPlayers or= {}
    @__syncedPlayers[ply] = true
    @__pendingSyncs[ply] = nil if @__pendingSyncs
    Moonpanel.Net.SendPanelData ply, @, data
	Moonpanel.Net.SendControlGrant ply, @ if @GetTraceSession! or
		@GetEndingTraceSession!

ENT.BuildPanelSyncData = =>
	canvas = @GetCanvas!
	return unless canvas and canvas\GetData!
	data = {
		panelData: canvas\ExportData!
		playData: canvas\ExportPlayData!
		powered: @GetPowered!
		solved: @GetSolvedState!
		dataRevision: @__dataRevision or 0
	}
	if @__resetSnapshot
		data.resetSerial = @__resetSerial or 0
		data.resetSnapshot = table.Copy @__resetSnapshot
	if @__lastVisualResult
		data.visualResult = table.Copy @__lastVisualResult
		data.visualElapsed = math.max 0, CurTime! - (@__lastVisualResultAt or CurTime!)
	data

ENT.RequestDataFromPlayer = (ply) =>
    Moonpanel.Net.PanelRequestDataFromPlayer ply, @, (data) ->
        @SetData data

ENT.CanRequestControl = (ply) =>
	return false if @GetEndingTraceSession!
	controller = @GetController!
	return false if IsValid(controller) and controller\IsPlayer!
	return false unless IsValid(ply) and ply\Alive! and Moonpanel\IsFocused(ply)
	return false unless @GetPowered!
	return false if ply\EyePos!\DistToSqr(@GetPos!) > 1024 * 1024
	true

ENT.StartTraceSession = (ply, x, y, inputSensitivity = 1,
	gamepadSensitivity = 1, gamepadDeadzone = 0.16) =>
	canvas = @GetCanvas!
	node = canvas\FindStartNode x, y, 32 if canvas and canvas.FindStartNode
	return false unless node
	return false unless @SolveStart ply, node.id

	timer.Remove "TheMP_SolvedState_#{@EntIndex!}" if timer and timer.Remove
	@__pendingSolvedResult = nil
	@ResetWireState! if @ResetWireState
	@SetSolvedState false if @SetSolvedState
	@__lastVisualResult = nil
	@__lastVisualResultAt = nil
	pathfinder = canvas\GetPathFinder!
	ruleDefinition = canvas\GetRuleDefinition!
	session = Moonpanel.TraceSession.Create @, {
		controller: ply
		revision: pathfinder.topology.revision
		ruleRevision: ruleDefinition and ruleDefinition.ruleRevision or 0
		lastSequence: 0
		rateWindow: CurTime!
		rateSamples: 0
		lastKeyframe: CurTime!
		inputSensitivity: math.Clamp(tonumber(inputSensitivity) or 1, 0.05, 8)
		gamepadSensitivity: math.Clamp(tonumber(gamepadSensitivity) or 1, 0.05, 8)
		gamepadDeadzone: math.Clamp(tonumber(gamepadDeadzone) or 0.16, 0, 0.95)
	}
	@SetTraceSession session
	if @MoonpanelPillar and not Moonpanel\BeginPillarOrbit(@, ply, session.id)
		@EndTraceSession true
		return false
	canvas\SetTraceSessionId session.id if canvas.SetTraceSessionId
	@BeginWireTrace! if @BeginWireTrace
	Moonpanel.Wire.UpdateState @ if Moonpanel.Wire and Moonpanel.Wire.UpdateState
	Moonpanel.Net.SendControlGrant nil, @
	true

ENT.RequestControl = (ply, x, y, inputSensitivity = 1,
	gamepadSensitivity = 1, gamepadDeadzone = 0.16) =>
	return false unless @CanRequestControl ply
	@StartTraceSession ply, x, y, inputSensitivity, gamepadSensitivity,
		gamepadDeadzone

ENT.StopControl = (ply) =>
	@EndTraceSession true

ENT.ApplyTerminalResult = (envelope) =>
	return false unless SERVER and istable envelope

	timerName = "TheMP_SolvedState_#{@EntIndex!}"
	timer.Remove timerName if timer and timer.Remove
	feedback = envelope.feedback or {}
	erasures = feedback.erasures or {}
	hasErasures = istable(erasures) and #erasures > 0
	resultAt = CurTime!

	-- A successful rule evaluation is not a solved panel until its eraser
	-- feedback has completed. Keep the authoritative state and sync envelope
	-- aligned throughout that interval.
	envelope.solved = envelope.success == true and not hasErasures
	@SetSolvedState envelope.solved
	@__lastVisualResult = table.Copy envelope
	@__lastVisualResultAt = resultAt

	return true unless envelope.success == true and hasErasures

	@__pendingSolvedResult = table.Copy envelope
	@__pendingSolvedResultAt = resultAt
	panel = @
	delay = Moonpanel.Canvas.EraserRevealDelay or 0.75
	return true unless timer and timer.Create
	timer.Create timerName, delay, 1, ->
		return unless IsValid panel
		return unless panel.__pendingSolvedResult
		result = panel.__pendingSolvedResult
		panel.__pendingSolvedResult = nil
		result.solved = true
		panel\SetSolvedState true
		panel.__lastVisualResult = table.Copy result
		panel.__lastVisualResultAt = panel.__pendingSolvedResultAt or CurTime!
		panel\ExecutePendingSyncs!
	true

ENT.EndTraceSession = (forceAbort = true) =>
	session = @GetTraceSession!
	return false unless session

	canvas = @GetCanvas!
	@SetEndingTraceSession session
	ended = @SolveStop forceAbort
	unless ended
		Moonpanel.Net.BroadcastVisualResult @, {
			aborted: true
			evaluationError: "session_termination"
		}
	@SetTraceSession nil
	@SetController game.GetWorld!
	controller = session.controller
	Moonpanel\EndPillarOrbit controller if @MoonpanelPillar
	if IsValid(controller) and controller\GetNW2Entity("TheMP Control") == @
		controller\SetNW2Entity "TheMP Control", game.GetWorld!
	Moonpanel.Net.BroadcastTraceResult @, session.id, forceAbort
	true

ENT.ResetPanel = (restorePower = true) =>
	canvas = @GetCanvas!
	return false unless canvas and canvas\GetData!
	hadRuntimeState = canvas\HasRuntimeState! if canvas.HasRuntimeState
	@EndTraceSession true if @GetTraceSession!
	canvas\CancelSolution "panel_reset" if canvas\CancelSolution
	pathfinder = canvas\GetTraceSnapshot! if canvas.GetTraceSnapshot
	@__resetSerial = ((@__resetSerial or 0) + 1) % 4294967295
	@__resetSerial = 1 if @__resetSerial == 0
	@__resetSnapshot = pathfinder if pathfinder and hadRuntimeState
	if @__resetSnapshot and Moonpanel.Net.BroadcastPanelResetPresentation
		Moonpanel.Net.BroadcastPanelResetPresentation @, @__resetSnapshot,
			@__resetSerial
	@ClearEndingTraceSession!
	@__lastVisualResult = nil
	@__lastVisualResultAt = nil
	@__pendingSolvedResult = nil
	@ResetWireState! if @ResetWireState
	timer.Remove "TheMP_SolvedState_#{@EntIndex!}" if timer and timer.Remove
	canvas\ResetRuntime "panel-reset" if canvas.ResetRuntime
	@SetSolvedState false
	@SetErrored false if @SetErrored
	@SetPowered true if restorePower
	@ExecutePendingSyncs!
	@__resetSnapshot = nil
	true

ENT.TriggerInput = (input, value) =>
	return unless SERVER and WireLib
	if input == "TurnOff"
		@SetPowered value ~= 1
	elseif input == "Reset" and value == 1
		@ResetPanel!

-- WireLib stores links and port configuration separately from the panel
-- document. Keep that metadata in the normal duplicator entity modifier so
-- Sandbox dupes and map saves restore connected wires as well as the puzzle.
ENT.BuildDupeInfo = =>
	return unless SERVER and WireLib and WireLib.BuildDupeInfo
	WireLib.BuildDupeInfo @

ENT.ApplyDupeInfo = (ply, ent, info, getEntByID) =>
	return unless SERVER and WireLib and WireLib.ApplyDupeInfo and info
	WireLib.ApplyDupeInfo ply, ent, info, getEntByID

ENT.PreEntityCopy = =>
	return unless SERVER and WireLib
	duplicator.ClearEntityModifier @, "WireDupeInfo"
	info = @BuildDupeInfo!
	duplicator.StoreEntityModifier @, "WireDupeInfo", info if info

ENT.PostEntityPaste = (ply, ent, createdEntities) =>
	return unless SERVER and WireLib
	info = ent and ent.EntityMods and ent.EntityMods.WireDupeInfo
	return unless info
	getEntByID = (id, default) ->
		return game.GetWorld! if id == 0
		candidate = createdEntities and createdEntities[id]
		IsValid(candidate) and candidate or default
	@ApplyDupeInfo ply, @, info, getEntByID

ENT.OnRestore = =>
	WireLib.Restored @ if SERVER and WireLib and WireLib.Restored

ENT.TraceSessionThink = =>
	session = @GetTraceSession!
	return unless session
	ply = session.controller
	unless IsValid(ply) and ply\Alive! and Moonpanel\IsFocused(ply) and
			@GetPowered! and ply\EyePos!\DistToSqr(@GetPos!) <= 1024 * 1024
		@EndTraceSession true
		return
	if @MoonpanelPillar
		state = Moonpanel.PillarController and
			Moonpanel.PillarController.GetState(ply)
		if state and state.abortRequested
			@EndTraceSession true
			return
		if Moonpanel.Net.ProcessPendingPillarSession and
				not Moonpanel.Net.ProcessPendingPillarSession(@, session)
			@EndTraceSession true
			return
		return unless @GetTraceSession! == session

	if CurTime! - session.lastKeyframe >= 2
		session.lastKeyframe = CurTime!
		Moonpanel.Net.SendControlGrant nil, @, true

ENT.UpdateTransmitState = =>
	TRANSMIT_ALWAYS
