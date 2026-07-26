AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"

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

ENT.SetData = (data, solved = false, visualResult = nil) =>
    data = Moonpanel.Canvas.SanitizeData data
    return false unless data
    controller = @__traceSession and @__traceSession.controller
    controller or= @GetController! if @GetController
    @EndTraceSession true if @__traceSession
    if IsValid(controller) and controller\IsPlayer!
        Moonpanel\SetFocused controller, false if Moonpanel.IsFocused and
            Moonpanel\IsFocused controller
    @SetController game.GetWorld! if @SetController and
        IsValid(@GetController!) and @GetController!\IsPlayer!
    @GetCanvas!\CancelSolution("panel_edit") if @GetCanvas! and
        @GetCanvas!\CancelSolution
    @SetSolvedState false if @SetSolvedState
    if @__endingTraceSession
        @GetCanvas!.__solutionCoroutine = nil
        Moonpanel.Net.BroadcastVisualResult @, {
            aborted: true
            evaluationError: "panel_edit"
        }
        @__endingTraceSession = nil
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
    Moonpanel.Net.SendControlGrant ply, @ if @__traceSession or @__endingTraceSession

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
	if @__lastVisualResult
		data.visualResult = table.Copy @__lastVisualResult
		data.visualElapsed = math.max 0, CurTime! - (@__lastVisualResultAt or CurTime!)
	data

ENT.RequestDataFromPlayer = (ply) =>
    Moonpanel.Net.PanelRequestDataFromPlayer ply, @, (data) ->
        @SetData data

ENT.RequestControl = (ply, x, y, inputSensitivity = 1,
	gamepadSensitivity = 1, gamepadDeadzone = 0.16) =>
	return if @__endingTraceSession
	controller = @GetController!
	return if IsValid(controller) and controller\IsPlayer!
	return unless IsValid(ply) and ply\Alive! and Moonpanel\IsFocused(ply)
	return unless @GetPowered!
	return if ply\EyePos!\DistToSqr(@GetPos!) > 1024 * 1024

    canvas = @GetCanvas!

    pathfinder = canvas\GetPathFinder!
    return if not pathfinder

    node = pathfinder.topology\getClosestStart x, y, 32
    return if not node

	result = @SolveStart ply, node.id
	if result
		@SetSolvedState false if @SetSolvedState
		@__lastVisualResult = nil
		@__lastVisualResultAt = nil
		Moonpanel.__nextTraceSession = ((Moonpanel.__nextTraceSession or 0) + 1) % 4294967295
		Moonpanel.__nextTraceSession = 1 if Moonpanel.__nextTraceSession == 0
		@__traceSession = {
			id: Moonpanel.__nextTraceSession
			controller: ply
			revision: pathfinder.topology.revision
			ruleRevision: canvas\GetRuleDefinition! and
				canvas\GetRuleDefinition!.ruleRevision or 0
			lastSequence: 0
			rateWindow: CurTime!
			rateSamples: 0
			lastKeyframe: CurTime!
			inputSensitivity: math.Clamp(tonumber(inputSensitivity) or 1, 0.05, 8)
			gamepadSensitivity: math.Clamp(tonumber(gamepadSensitivity) or 1, 0.05, 8)
			gamepadDeadzone: math.Clamp(tonumber(gamepadDeadzone) or 0.16, 0, 0.95)
		}
		if @MoonpanelPillar and not Moonpanel\BeginPillarOrbit(@, ply, @__traceSession.id)
			@EndTraceSession true
			return false
		canvas.__playData.sessionId = @__traceSession.id
		Moonpanel.Net.SendControlGrant nil, @

	result

ENT.StopControl = (ply) =>
	@EndTraceSession true

ENT.EndTraceSession = (forceAbort = true) =>
	session = @__traceSession
	return false unless session

	canvas = @GetCanvas!
	@__endingTraceSession = session
	ended = @SolveStop forceAbort
	unless ended
		Moonpanel.Net.BroadcastVisualResult @, {
			aborted: true
			evaluationError: "session_termination"
		}
	@__traceSession = nil
	@SetController game.GetWorld!
	controller = session.controller
	Moonpanel\EndPillarOrbit controller if @MoonpanelPillar
	if IsValid(controller) and controller\GetNW2Entity("TheMP Control") == @
		controller\SetNW2Entity "TheMP Control", game.GetWorld!
	Moonpanel.Net.BroadcastTraceResult @, session.id, forceAbort
	true

ENT.TraceSessionThink = =>
	session = @__traceSession
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
		return unless @__traceSession == session

	if CurTime! - session.lastKeyframe >= 2
		session.lastKeyframe = CurTime!
		Moonpanel.Net.SendControlGrant nil, @, true

ENT.UpdateTransmitState = =>
	TRANSMIT_ALWAYS
