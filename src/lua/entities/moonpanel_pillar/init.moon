AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"

buildHull = (radius, height, sides = 24) ->
	pieces = {}
	for index = 0, sides - 1
		angle0 = math.pi * 2 * index / sides
		angle1 = math.pi * 2 * (index + 1) / sides
		x0, y0 = math.cos(angle0) * radius, math.sin(angle0) * radius
		x1, y1 = math.cos(angle1) * radius, math.sin(angle1) * radius
		table.insert pieces, {
			Vector(0, 0, 0), Vector(0, 0, height)
			Vector(x0, y0, 0), Vector(x0, y0, height)
			Vector(x1, y1, 0), Vector(x1, y1, height)
		}
	pieces

ENT.RebuildPillarPhysics = =>
	radius = math.Clamp @GetPillarRadius!, 16, 256
	height = math.Clamp @GetPillarHeight!, 32, 512
	success = @PhysicsInitMultiConvex buildHull radius, height
	unless success
		-- Keep the entity interactable and solid even if VPhysics exhausts its
		-- convex budget. Line targeting still uses the exact cylinder above.
		@PhysicsInitBox Vector(-radius, -radius, 0), Vector(radius, radius, height)
		unless @__pillarPhysicsWarned
			ErrorNoHalt "[Moonpanel] Failed to create pillar convex physics; using box fallback.\n"
			@__pillarPhysicsWarned = true
	@SetMoveType MOVETYPE_VPHYSICS
	@SetSolid success and SOLID_VPHYSICS or SOLID_BBOX
	-- Procedural physics meshes need the custom ray/box-test flags or traces can
	-- continue using the tiny backing model's collision at the pillar base.
	@EnableCustomCollisions!
	@SetCollisionBounds Vector(-radius, -radius, 0), Vector(radius, radius, height)
	@SetSurroundingBoundsType BOUNDS_COLLISION
	phys = @GetPhysicsObject!
	if IsValid phys
		phys\EnableMotion false
		phys\Sleep!

ENT.InitializeSided = =>
	@SetModel "models/hunter/blocks/cube025x025x025.mdl"
	@SetUseType SIMPLE_USE
	@SetCustomCollisionCheck true
	@AddEFlags EFL_FORCE_CHECK_TRANSMIT
	@__syncedPlayers = {}
	@__pendingSyncs = {}
	@__dataRevision = 0
	@GetCanvas!\SetSurfaceSpec @GetSurfaceSpec!
	@RebuildPillarPhysics!

ENT.OnPillarDimensionsChanged = =>
	@RebuildPillarPhysics! if @__syncedPlayers

ENT.ApplyPillarCellFit = =>
	return unless @GetPillarFitCells!
	data = @GetCanvas!\GetData!
	return unless data and data.Meta and data.Meta.Width > 0
	fitted = math.pi * 2 * @GetPillarRadius! * data.Meta.Height / data.Meta.Width
	@SetPillarHeight math.Clamp fitted, 32, 512

ENT.SetPillarDimensions = (radius, height, fitCells = false) =>
	@EndTraceSession true if @GetTraceSession!
	@SetPillarFitCells fitCells == true
	@SetPillarRadius math.Clamp tonumber(radius) or 48, 16, 256
	@SetPillarHeight math.Clamp tonumber(height) or 96, 32, 512
	@ApplyPillarCellFit!
	@PillarRadius = @GetPillarRadius!
	@PillarHeight = @GetPillarHeight!
	@PillarFitCells = @GetPillarFitCells!
	@RebuildPillarPhysics!

ENT.SetData = (data) =>
	return false unless @.BaseClass.SetData @, data
	@ApplyPillarCellFit!
	@PillarHeight = @GetPillarHeight!
	@RebuildPillarPhysics!
	true

-- Auto-refresh does not re-run ENTITY:Initialize on existing pillars.
timer.Simple 0, ->
	for pillar in *ents.FindByClass "moonpanel_pillar"
		pillar\RebuildPillarPhysics! if IsValid pillar
