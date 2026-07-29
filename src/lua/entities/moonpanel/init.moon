AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"
include "moonpanel/sh_trace_session.lua"
include "moonpanel/sv_wire.lua"

wireErased = (panel, result) ->
	values = {}
	feedback = result and result.feedback
	canvas = panel\GetCanvas!
	return values unless feedback and istable(feedback.erasures)
	for pair in *feedback.erasures
		index = tonumber(pair and pair.targetIndex)
		socket = index and canvas\GetSocketAtDataIndex index
		continue unless socket
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

ENT.GetWireState = => {
	powered: @GetPowered!
	solved: @GetSolvedState!
	errored: @GetErrored!
	path: @__wirePath or ""
}

ENT.GetPanelRevision = => @__dataRevision or 0
ENT.GetTraceSession = => Moonpanel.TraceSession.Get @
ENT.GetEndingTraceSession = => Moonpanel.TraceSession.GetEnding @
ENT.SetTraceSession = (session) => Moonpanel.TraceSession.Set @, session
ENT.SetEndingTraceSession = (session) => Moonpanel.TraceSession.SetEnding @, session
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
	Moonpanel.TraceSession.ClearEnding @, session

ENT.ClearTerminalState = (resetWire = false) =>
	timer.Remove "TheMP_SolvedState_#{@EntIndex!}"
	@__pendingSolvedResult = nil
	@__lastVisualResult = nil
	@__lastVisualResultAt = nil
	@ResetWireState! if resetWire
	@SetSolvedState false
	@SetErrored false

ENT.ResetWireState = =>
	@__wirePath = ""

ENT.HandleWireTerminalResult = (result, maximum = 512) =>
	return unless result
	@__wirePath = @GetCanvas!\GetTracePath result and result.snapshot, maximum
	{
		path: @__wirePath
		erased: wireErased @, result
		aborted: result.aborted == true
		solved: result.success == true
	}

ENT.SetData = (data, solved = false, visualResult = nil) =>
    data = Moonpanel.Canvas.SanitizeData data
    return false unless data
    activeSession = @GetTraceSession!
    endingSession = @GetEndingTraceSession!
    controller = activeSession and activeSession.controller
	controller or= @GetController!
	@EndTraceSession true if activeSession
	if IsValid(controller) and controller\IsPlayer!
		Moonpanel\SetFocused controller, false if Moonpanel\IsFocused controller
		@SetController game.GetWorld! unless activeSession
	@GetCanvas!\CancelSolution "panel_edit"
	if endingSession
		Moonpanel.Net.BroadcastVisualResult @, {
            aborted: true
            evaluationError: "panel_edit"
		}
		@ClearEndingTraceSession!
	@ClearTerminalState!
	canvas = @GetCanvas!
    canvas\ImportData data
    importedData = canvas\ExportData!
    return false unless importedData
    @TheMoonpanelTileData = importedData
    @__dataRevision = ((@__dataRevision or 0) + 1) % 4294967295
    @__dataRevision = 1 if @__dataRevision == 0
	@SetSolvedState solved, visualResult

	@SetPowered true

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
	return false, "ending" if @GetEndingTraceSession!
	controller = @GetController!
	return false, "busy" if IsValid(controller) and controller\IsPlayer!
	return false, "dead" unless IsValid(ply) and ply\Alive!
	return false, "notFocused" unless Moonpanel\IsFocused(ply)
	return false, "notPowered" unless @GetPowered!
	return false, "tooFar" if ply\EyePos!\DistToSqr(@GetPos!) > 1024 * 1024
	true

ENT.StartTraceSession = (ply, x, y, inputSensitivity = 1,
	gamepadSensitivity = 1, gamepadDeadzone = 0.16) =>
	canvas = @GetCanvas!
	node = canvas\FindStartNode x, y, 32
	return false, "invalidStart" unless node
	return false, "invalidStart" unless @SolveStart ply, node.id

	@ClearTerminalState true
	ruleDefinition = canvas\GetRuleDefinition!
	session = Moonpanel.TraceSession.Create @, {
		controller: ply
		revision: canvas\GetTraceRevision!
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
		return false, "invalidStart"
	canvas\SetTraceSessionId session.id
	Moonpanel.Wire.UpdateState @
	Moonpanel.Net.SendControlGrant nil, @
	true

ENT.RequestControl = (ply, x, y, inputSensitivity = 1,
	gamepadSensitivity = 1, gamepadDeadzone = 0.16) =>
	ok, reason = @CanRequestControl ply
	return false, reason unless ok
	@StartTraceSession ply, x, y, inputSensitivity, gamepadSensitivity,
		gamepadDeadzone

ENT.StopControl = (ply) =>
	@EndTraceSession true

ENT.ApplyTerminalResult = (envelope) =>
	return false unless SERVER and istable envelope

	timerName = "TheMP_SolvedState_#{@EntIndex!}"
	timer.Remove timerName
	feedback = envelope.feedback or {}
	erasures = feedback.erasures or {}
	hasErasures = istable(erasures) and #erasures > 0
	failed = envelope.success ~= true and envelope.aborted ~= true
	resultAt = CurTime!

	-- A successful rule evaluation is not a solved panel until its eraser
	-- feedback has completed. Keep the authoritative state and sync envelope
	-- aligned throughout that interval.
	envelope.solved = envelope.success == true and not hasErasures
	@SetSolvedState envelope.solved
	@SetErrored failed and not hasErasures
	@__lastVisualResult = table.Copy envelope
	@__lastVisualResultAt = resultAt

	return true unless hasErasures

	@__pendingSolvedResult = table.Copy envelope
	@__pendingSolvedResultAt = resultAt
	panel = @
	delay = Moonpanel.Canvas.EraserRevealDelay or 0.75
	timer.Create timerName, delay, 1, ->
		return unless IsValid panel
		return unless panel.__pendingSolvedResult
		result = panel.__pendingSolvedResult
		panel.__pendingSolvedResult = nil
		result.solved = result.success == true
		panel\SetSolvedState result.solved
		panel\SetErrored result.success ~= true and result.aborted ~= true
		Moonpanel.Wire.UpdateState panel
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
	hadRuntimeState = canvas\HasRuntimeState!
	@EndTraceSession true if @GetTraceSession!
	canvas\CancelSolution "panel_reset"
	pathfinder = canvas\GetTraceSnapshot!
	@__resetSerial = ((@__resetSerial or 0) + 1) % 4294967295
	@__resetSerial = 1 if @__resetSerial == 0
	@__resetSnapshot = pathfinder if pathfinder and hadRuntimeState
	if @__resetSnapshot
		Moonpanel.Net.BroadcastPanelResetPresentation @, @__resetSnapshot,
			@__resetSerial
	@ClearEndingTraceSession!
	@ClearTerminalState true
	canvas\ResetRuntime "panel-reset"
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
		state = Moonpanel.PillarController.GetState ply
		if state and state.abortRequested
			@EndTraceSession true
			return
		if not Moonpanel.Net.ProcessPendingPillarSession @, session
			@EndTraceSession true
			return
		return unless @GetTraceSession! == session

	if CurTime! - session.lastKeyframe >= 2
		session.lastKeyframe = CurTime!
		Moonpanel.Net.SendControlGrant nil, @, true

ENT.UpdateTransmitState = =>
	TRANSMIT_ALWAYS
