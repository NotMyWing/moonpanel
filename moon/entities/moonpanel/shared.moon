ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false
ENT.Moonpanel       = true

ENT.TickRate        = 20
ENT.RenderGroup     = RENDERGROUP_BOTH

ENT.Initialize = =>
	@.BaseClass.Initialize  @

	@__canvas = Moonpanel.Canvas.Canvas!
	if SERVER
		@__canvas\InitPathFinder!
	else
		@__canvas\SetPowerState false

	@__canvas\SetWorldEntity @
	@__canvas\SetupSounds!

	@InitializeSided!

	@SetNW2VarProxy "Powered", (_, _, old, new) ->
		if old ~= new
			canvas = @GetCanvas!

			if SERVER
				canvas\PlaySound new and "PowerOn" or "PowerOff"
			else
				@__canvas\SetPowerState new

			if not new
				@SolveStop!

ENT.SetupDataTables = =>
	@NetworkVar "Entity", 0, "Controller"
    if SERVER
        @SetController game.GetWorld!

ENT.ApplyDeltas = (ply, dX, dY) =>
	return if @GetController! ~= ply
	return if not IsValid ply

	if @__canvas\ApplyDeltas dX, dY
		true

ENT.SolveStart = (ply, nodeId) =>
	return if not @GetPowered!
	return if not @__canvas\Start ply, nodeId

	@SetController ply

	if SERVER
		Moonpanel.Net.SendSolveStart @, ply, nodeId

	true

ENT.SolveStop = (forceAbort) =>
	return if not @GetPowered!
	return if not @__canvas\End forceAbort

	if SERVER
		Moonpanel.Net.SendSolveStop @

	true

ENT.GetCanvas = => @__canvas

ENT.SetPowered = (value) =>
	return if SERVER and not @__canvas\GetData!

	controller = @GetController!
	if IsValid controller
		Moonpanel\StopControl controller

	@SetNW2Bool "Powered", value

ENT.GetPowered = => @GetNW2Bool "Powered"

ENT.OnRemove = =>
	if SERVER
    	Moonpanel\StopControl @GetController! if IsValid @GetController!

    @GetCanvas!\StopSounds!
