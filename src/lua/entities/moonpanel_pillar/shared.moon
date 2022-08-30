ENT.Type = "anim"
ENT.Base = "moonpanel"

ENT.PrintName = "The Moonpanel Pillar"
ENT.Author = "Notmywing"
ENT.Spawnable = false
ENT.Moonpanel = true
ENT.MoonpanelPillar = true
ENT.Disabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.GetSurfaceSpec = =>
	Moonpanel.Canvas.MakeSurfaceSpec Moonpanel.Canvas.SurfaceKind.Pillar, false

-- Line traces use the exact rendered cylinder. Hull traces continue through
-- the generated VPhysics prism so player and prop collision stays native.
ENT.TestCollision = (startPos, delta, isBox) =>
	return true if isBox
	localStart = @WorldToLocal startPos
	localEnd = @WorldToLocal startPos + delta
	localDelta = localEnd - localStart
	fraction, nx, ny, nz = Moonpanel.Canvas.RaycastFiniteCylinder localStart.x,
		localStart.y, localStart.z, localDelta.x, localDelta.y, localDelta.z,
		math.max(1, @GetPillarRadius!), math.max(1, @GetPillarHeight!)
	return unless fraction
	localHit = localStart + localDelta * fraction
	hitPos = @LocalToWorld localHit
	normalPoint = @LocalToWorld localHit + Vector(nx, ny, nz)
	{
		HitPos: hitPos
		Fraction: fraction
		Normal: (normalPoint - hitPos)\GetNormalized!
	}

ENT.SetupDataTables = =>
	@.BaseClass.SetupDataTables @
	@NetworkVar "Float", 0, "PillarRadius"
	@NetworkVar "Float", 1, "PillarHeight"
	@NetworkVar "Bool", 0, "PillarFitCells"
	@NetworkVarNotify "PillarRadius", (owner) ->
		owner\OnPillarDimensionsChanged! if owner.OnPillarDimensionsChanged
	@NetworkVarNotify "PillarHeight", (owner) ->
		owner\OnPillarDimensionsChanged! if owner.OnPillarDimensionsChanged
	if SERVER
		@SetPillarRadius 48
		@SetPillarHeight 96
		@SetPillarFitCells false

ENT.GetPillarCenter = =>
	@GetPos! + Vector(0, 0, math.max(1, @GetPillarHeight!) * 0.5)

ENT.GetPillarAxisPoint = (worldPos) =>
	base = @GetPos!
	Vector base.x, base.y, worldPos and worldPos.z or base.z

ENT.GetPillarAngle = (worldPos) =>
	localPos = @WorldToLocal worldPos
	math.deg math.atan2 localPos.y, localPos.x

ENT.GetPillarOrbitPosition = (angleDegrees, radius, worldZ) =>
	angle = math.rad(tonumber(angleDegrees) or 0)
	radius = tonumber(radius) or 0
	localPoint = Vector math.cos(angle) * radius, math.sin(angle) * radius, 0
	worldPoint = @LocalToWorld localPoint
	worldPoint.z = worldZ if worldZ ~= nil
	worldPoint

ENT.CanvasToWorld = (x, y) =>
	resolution = Moonpanel.Canvas.Resolution
	angle = (tonumber(x) or 0) / resolution * math.pi * 2
	radius = math.max 1, @GetPillarRadius!
	height = math.max 1, @GetPillarHeight!
	@LocalToWorld Vector math.cos(angle) * radius, math.sin(angle) * radius,
		height * (1 - (tonumber(y) or 0) / resolution)
