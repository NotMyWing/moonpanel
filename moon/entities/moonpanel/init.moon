include "shared.lua"

SOUND_PANEL_ABORT = Sound "moonpanel/panel_abort_tracing.ogg"
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
	if IsValid @activeUser
		return false

	@activeUser = ply

	@EmitSound SOUND_PANEL_START
	@__scintPower = 1
	@__nextscint = CurTime! + 0.75
	return true

ENT.FinishPuzzle = () =>
	if not IsValid @activeUser
		return false

	@activeUser = nil
	@EmitSound SOUND_PANEL_ABORT

ENT.ServerThink = () =>
	if @activeUser
		if @__scintPower >= 0.15 and CurTime! >= @__nextscint
			@EmitSound SOUND_PANEL_SCINT, 75, 100, @__scintPower
			@__nextscint = CurTime! + 2
			@__scintPower *= 0.75
		
	if @activeUser
		if @activeUser\GetNW2Entity("TheMP Controlled Panel") ~= @
			@FinishPuzzle!

ENT.ServerTickrateThink = () =>