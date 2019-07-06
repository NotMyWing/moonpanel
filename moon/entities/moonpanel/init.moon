include "shared.lua"

SOUND_PANEL_ABORT = Sound "moonpanel/panel_abort_tracing.ogg"
SOUND_PANEL_FAILURE = Sound "moonpanel/panel_failure.ogg"
SOUND_PANEL_SUCCESS = Sound "moonpanel/panel_success.ogg"
SOUND_PANEL_START = Sound "moonpanel/panel_start_tracing.ogg"
SOUND_PANEL_SCINT = Sound "moonpanel/panel_scint.ogg"

ENT.Initialize = () =>
	self.BaseClass.Initialize   self
	self\PhysicsInit            SOLID_VPHYSICS
	self\SetMoveType            MOVETYPE_VPHYSICS
	self\SetSolid               SOLID_VPHYSICS
	self\SetUseType             SIMPLE_USE

ENT.Use = (activator) =>
	Moonpanel\setFocused activator, true

ENT.PreEntityCopy = () =>

ENT.PostEntityPaste = (ply, ent, CreatedEntities) =>

ENT.StartPuzzle = (ply, x, y) =>
	shouldStart = false
	activeUser = @GetNW2Entity "ActiveUser"

	nodeA, nodeB = nil
	if @pathFinder -- and @isPowered
		if not IsValid(activeUser) and IsValid ply
			nodeA = @pathFinder\getClosestNode x, y, @calculatedDimensions.barLength
			if not nodeA
				return

			if @tileData.Tile.Symmetry
				nodeB = @pathFinder\getSymmetricalNode nodeA
				if not nodeB
					return
					
			shouldStart = true

	if not shouldStart
		return false

	@SetNW2Entity "ActiveUser", ply
	Moonpanel\sendStart ply, @, nodeA, nodeB
	@pathFinder\restart nodeA, nodeB

	@EmitSound SOUND_PANEL_START
	@__scintPower = 1
	@__nextscint = CurTime! + 0.75
	return true

ENT.FinishPuzzle = () =>
	activeUser = @GetNW2Entity "ActiveUser"

	if not IsValid activeUser
		return false

	@SetNW2Entity "ActiveUser", nil

	success = true
	grayOut = {}
	redOut = {}

	lastInts = {}
	for i, nodeStack in pairs @pathFinder.nodeStacks
		last = nodeStack[#nodeStack]
		if not last.exit
			success = false

	if success
		grayOut, redOut = {}, {}

		@EmitSound SOUND_PANEL_SUCCESS
	else
		@EmitSound SOUND_PANEL_ABORT

	net.Start "TheMP Finish"
	net.WriteEntity @
	net.WriteBool success
	net.WriteTable redOut or {}
	net.WriteTable grayOut or {}
	net.Broadcast!

ENT.ServerThink = () =>
	activeUser = @GetNW2Entity "ActiveUser"
	if IsValid activeUser
		if @__scintPower and @__scintPower >= 0.15 and CurTime! >= @__nextscint
			@EmitSound SOUND_PANEL_SCINT, 75, 100, @__scintPower
			@__nextscint = CurTime! + 2
			@__scintPower *= 0.75
		
		if activeUser\GetNW2Entity("TheMP Controlled Panel") ~= @
			@FinishPuzzle!

ENT.ServerTickrateThink = () =>