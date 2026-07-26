ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false
ENT.Moonpanel       = true

-- Retain the public model table used by the toolgun and third-party tooling.
-- Screen transform construction itself lives in the shared canvas module so
-- the client and server consume the exact same data.
ENT.Monitor_Offsets = Moonpanel.Canvas.Monitor_Offsets

ENT.GetSurfaceSpec = => Moonpanel.Canvas.MakeSurfaceSpec Moonpanel.Canvas.SurfaceKind.Flat, false

-- The Sandbox duplicator and map saver collect ENT:GetTable before serializing
-- it. Keep runtime canvas/session state out of that table and expose only the
-- canonical panel document as the registered duplicator argument.
ENT.OnEntityCopyTableFinish = (data) =>
	return unless istable data
	for key in pairs data
		data[key] = nil if isstring(key) and string.StartWith(key, "__")
	canvas = @GetCanvas! if @GetCanvas
	data.TheMoonpanelTileData = canvas\ExportData! if canvas and canvas\GetData!
	data.TheMoonpanelSolved = @GetSolvedState!
	data.TheMoonpanelVisualResult = nil
	if @GetSolvedState! and istable @__lastVisualResult
		data.TheMoonpanelVisualResult = table.Copy @__lastVisualResult

ENT.TickRate        = 20
ENT.RenderGroup     = RENDERGROUP_BOTH

ENT.Initialize = =>
	-- Resolve the actual framework base explicitly. Using self.BaseClass here
	-- recurses when a surface entity derives from moonpanel.
	frameworkBase = baseclass.Get "base_gmodentity"
	frameworkBase.Initialize @ if frameworkBase and frameworkBase.Initialize

	@__canvas = Moonpanel.Canvas.Canvas!
	@__canvas\SetSurfaceSpec @GetSurfaceSpec!
	if SERVER
		@__canvas\InitPathFinder!
	else
		@__canvas\SetPowerState false

	@__canvas\SetWorldEntity @
	@__canvas\SetupSounds!

	@InitializeSided!
	Moonpanel.Wire.Initialize @ if SERVER and Moonpanel.Wire and
		Moonpanel.Wire.Initialize

ENT.SetupDataTables = =>
	@NetworkVar "Entity", 0, "Controller"
	@NetworkVar "Bool", 0, "Errored"
	@NetworkVar "Bool", 1, "PoweredNetworkState"
	@NetworkVar "Bool", 2, "SolvedNetworkState"
	@NetworkVarNotify "PoweredNetworkState", (owner, _, old, new) ->
		if old ~= new
			return unless IsValid owner
			canvas = owner\GetCanvas!

			if CLIENT
				canvas\PlaySound new and "PowerOn" or "PowerOff"
				canvas\SetPowerState new

			if not new
				owner\SolveStop true
			if SERVER and Moonpanel.Wire and Moonpanel.Wire.UpdateState
				Moonpanel.Wire.UpdateState owner
	if SERVER
        @SetController game.GetWorld!
		@SetErrored false

ENT.SolveStart = (ply, nodeId) =>
	return if not @GetPowered!

	return if not @__canvas\Start ply, nodeId

	@SetController ply

	true

ENT.SolveStop = (forceAbort) =>
	return if not @GetPowered!
	return if not @__canvas\End forceAbort

	true

ENT.GetCanvas = => @__canvas

ENT.SetSolvedState = (solved, visualResult = nil) =>
	@TheMoonpanelSolved = solved == true
	@__canvas\SetSolvedState @TheMoonpanelSolved if @__canvas and
		@__canvas.SetSolvedState
	if @TheMoonpanelSolved and istable visualResult
		@__lastVisualResult = table.Copy visualResult
		@__lastVisualResultAt = CurTime! - 60
	else
		@__lastVisualResult = nil unless @TheMoonpanelSolved
		@__lastVisualResultAt = nil unless @TheMoonpanelSolved
	@SetSolvedNetworkState @TheMoonpanelSolved
	Moonpanel.Wire.UpdateState @ if SERVER and Moonpanel.Wire and
		Moonpanel.Wire.UpdateState

ENT.GetSolvedState = => @TheMoonpanelSolved == true or
	@GetSolvedNetworkState! == true

ENT.SetPowered = (value) =>
	value = value == true

	if SERVER and not value
		if @ResetPanel and @__canvas and @__canvas\GetData!
			@ResetPanel false
		else
			controller = @GetController!
			Moonpanel\StopControl controller if IsValid(controller) and
				controller\IsPlayer!
	else
		controller = @GetController!
		Moonpanel\StopControl controller if IsValid(controller) and
			controller\IsPlayer!

	@SetPoweredNetworkState value
	Moonpanel.Wire.UpdateState @ if SERVER and Moonpanel.Wire and
		Moonpanel.Wire.UpdateState
	@ExecutePendingSyncs! if SERVER and @ExecutePendingSyncs

ENT.GetPowered = => @GetPoweredNetworkState!

ENT.OnRemove = =>
	if SERVER
		WireLib.Remove @ if WireLib and WireLib.Remove
		Moonpanel.Wire.ClearTimer @ if Moonpanel.Wire and Moonpanel.Wire.ClearTimer
		@GetCanvas!\CancelSolution("panel_removed") if @GetCanvas! and
			@GetCanvas!\CancelSolution
		panel = @
		if Moonpanel.Net.PendingPlayerDataRequests
			Moonpanel.Net.PendingPlayerDataRequests[panel] = nil
		if Moonpanel.Net.ClearPanelSyncState
			Moonpanel.Net.ClearPanelSyncState panel
		controller = @GetController!
		Moonpanel\StopControl controller if IsValid(controller) and controller\IsPlayer!

	canvas = @GetCanvas! if @GetCanvas
	return unless canvas
	canvas\DeallocateRT! if CLIENT and canvas.DeallocateRT
	canvas\StopSounds! if canvas.StopSounds

ENT.Think = =>
    @__canvas\Think! if @__canvas
	@TraceSessionThink! if SERVER and @TraceSessionThink

	if CLIENT
		if @__rendering and FrameNumber! - @__lastFrameNumber > 10
			@__rendering = false
			@__canvas\DeallocateRT!

		-- Keep RT rendering outside the 3D draw pass so HDR state cannot leak
		-- into it. ENTITY:Think already runs every client frame; a separate
		-- global Think hook per panel only duplicated scheduling overhead.
		@__canvas\RenderRT! if @__rendering and @__canvas
