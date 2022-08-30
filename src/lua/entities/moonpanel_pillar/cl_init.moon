include "shared.lua"

ENT.InitializeSided = =>
	@SetCustomCollisionCheck true
	@GetCanvas!\SetSurfaceSpec @GetSurfaceSpec!
	@__lastFrameNumber = 0
	@OnPillarDimensionsChanged!
	Moonpanel.Net.PanelRequestData @

ENT.OnPillarDimensionsChanged = =>
	radius = math.max 1, @GetPillarRadius!
	height = math.max 1, @GetPillarHeight!
	@__renderRadius, @__renderHeight = radius, height
	@SetCollisionBounds Vector(-radius, -radius, 0), Vector(radius, radius, height)
	@SetRenderBounds Vector(-radius, -radius, 0), Vector(radius, radius, height)

ENT.Draw = =>

ENT.DrawTranslucent = =>
	canvas = @GetCanvas!
	return unless canvas
	unless canvas\CanRender!
		@__rendering = false
	if not @__rendering and canvas\AllocateRT!
		@__rendering = true
	return unless @__rendering and canvas.__rtAlloc
	@__lastFrameNumber = FrameNumber!
	radius = math.max 1, @GetPillarRadius!
	height = math.max 1, @GetPillarHeight!
	@OnPillarDimensionsChanged! if @__renderRadius ~= radius or
		@__renderHeight ~= height
	segments = if radius >= 128 then 128 elseif radius >= 48 then 64 else 32
	matrix = Matrix!
	matrix\SetTranslation @GetPos!
	matrix\SetAngles @GetAngles!
	matrix\Scale Vector radius, radius, height
	render.SetMaterial canvas.__rtAlloc.rt.material
	cam.PushModelMatrix matrix
	Moonpanel.Canvas.GetPillarMesh(segments)\Draw!
	cam.PopModelMatrix!

ENT.GetCursorPos = =>
	ply = LocalPlayer!
	return unless IsValid ply
	startPos = ply\EyePos!
	direction = if Moonpanel\IsFocused ply
		x, y = input.GetCursorPos!
		gui.ScreenToVector x, y
	else
		ply\GetAimVector!
	localStart = @WorldToLocal startPos
	localEnd = @WorldToLocal startPos + direction * 32768
	localDirection = (localEnd - localStart)\GetNormalized!
	radius = math.max 1, @GetPillarRadius!
	a = localDirection.x^2 + localDirection.y^2
	return if a <= 0.000001
	b = 2 * (localStart.x * localDirection.x + localStart.y * localDirection.y)
	c = localStart.x^2 + localStart.y^2 - radius^2
	discriminant = b^2 - 4 * a * c
	return if discriminant < 0
	root = math.sqrt discriminant
	t0, t1 = (-b - root) / (2 * a), (-b + root) / (2 * a)
	distance = t0 >= 0 and t0 or t1
	return if distance < 0
	hit = localStart + localDirection * distance
	height = math.max 1, @GetPillarHeight!
	return if hit.z < 0 or hit.z > height
	angle = math.atan2 hit.y, hit.x
	u = (angle / (math.pi * 2)) % 1
	return u * Moonpanel.Canvas.Resolution, (1 - hit.z / height) * Moonpanel.Canvas.Resolution

ENT.TransformInputDeltas = (dX = 0, dY = 0) => dX, dY

ENT.GetScreenTransform = => nil

ENT.IsSynchonized = => @GetCanvas!\GetData! ~= nil
