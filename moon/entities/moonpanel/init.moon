AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
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
	@__nextscint = CurTime! + 2
	return true

ENT.FinishPuzzle = () =>
	if not IsValid @activeUser
		return false

	@activeUser = nil
	@EmitSound SOUND_PANEL_ABORT

ENT.Think = () =>
	if @activeUser
		if CurTime! >= @__nextscint
			@EmitSound SOUND_PANEL_SCINT
			@__nextscint = CurTime! + 2
		
	if @activeUser
		if @activeUser\GetNW2Entity("TheMP Controlled Panel") ~= @
			@FinishPuzzle!