ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false
ENT.Moonpanel       = true

ENT.GetSurfaceSpec = => Moonpanel.Canvas.MakeSurfaceSpec Moonpanel.Canvas.SurfaceKind.Flat, false

-- The Sandbox duplicator and map saver collect ENT:GetTable before serializing
-- it. Keep runtime canvas/session state out of that table and expose only the
-- canonical panel document as the registered duplicator argument.
ENT.OnEntityCopyTableFinish = (data) =>
	return unless istable data
	for key in pairs data
		data[key] = nil if isstring(key) and string.StartWith(key, "__")
	canvas = @GetCanvas!
	data.TheMoonpanelTileData = canvas\ExportData! if canvas\GetData!
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
	Moonpanel.Wire.Initialize @ if SERVER

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
			Moonpanel.Wire.UpdateState owner if SERVER
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
ENT.IsRendering = => @__rendering == true

ENT.SetSolvedState = (solved, visualResult = nil) =>
	@TheMoonpanelSolved = solved == true
	@__canvas\SetSolvedState @TheMoonpanelSolved
	if @TheMoonpanelSolved and istable visualResult
		@__lastVisualResult = table.Copy visualResult
		@__lastVisualResultAt = CurTime! - 60
	else
		@__lastVisualResult = nil unless @TheMoonpanelSolved
		@__lastVisualResultAt = nil unless @TheMoonpanelSolved
	@SetSolvedNetworkState @TheMoonpanelSolved
	Moonpanel.Wire.UpdateState @ if SERVER

ENT.GetSolvedState = => @TheMoonpanelSolved == true or
	@GetSolvedNetworkState! == true

ENT.SetPowered = (value) =>
	value = value == true

	if SERVER and not value and @ResetPanel and @__canvas\GetData!
		@ResetPanel false
	else
		controller = @GetController!
		Moonpanel\StopControl controller if IsValid(controller) and
			controller\IsPlayer!

	@SetPoweredNetworkState value
	Moonpanel.Wire.UpdateState @ if SERVER
	@ExecutePendingSyncs! if SERVER

ENT.GetPowered = => @GetPoweredNetworkState!

ENT.OnRemove = =>
	if SERVER
		WireLib.Remove @ if WireLib and WireLib.Remove
		@GetCanvas!\CancelSolution "panel_removed"
		Moonpanel.Net.PendingPlayerDataRequests[@] = nil
		Moonpanel.Net.ClearPanelSyncState @
		controller = @GetController!
		Moonpanel\StopControl controller if IsValid(controller) and controller\IsPlayer!

	canvas = @GetCanvas!
	canvas\DeallocateRT! if CLIENT
	canvas\StopSounds!

ENT.Think = =>
    @__canvas\Think!
	@TraceSessionThink! if SERVER

	if CLIENT
		if @__rendering and FrameNumber! - @__lastFrameNumber > 10
			@__rendering = false
			@__canvas\DeallocateRT!

		-- Keep RT rendering outside the 3D draw pass so HDR state cannot leak
		-- into it. ENTITY:Think already runs every client frame; a separate
		-- global Think hook per panel only duplicated scheduling overhead.
		@__canvas\RenderRT! if @__rendering
