AddCSLuaFile!

Canvas = Moonpanel.Canvas

Canvas.SurfaceKind = {
	Flat: 0
	Pillar: 1
}

emptyEntity = (value) ->
	not istable(value) or value.Type == nil

Canvas.MakeSurfaceSpec = (kind = Canvas.SurfaceKind.Flat, continuous = false) ->
	kind = Canvas.SurfaceKind.Pillar if kind == "pillar"
	kind = Canvas.SurfaceKind.Flat if kind == "flat"
	kind = Canvas.SurfaceKind.Flat unless kind == Canvas.SurfaceKind.Pillar
	{
		:kind
		continuous: continuous == true
	}

Canvas.IsContinuousSurface = (surfaceSpec) ->
	surfaceSpec and surfaceSpec.continuous == true or false

-- A cylinder has only two physical boundaries. Continuous flat previews use
-- the same exit rules so their authored topology matches the pillar exactly:
-- exits may leave the top or bottom, never the periodic horizontal seam.
Canvas.UsesVerticalBoundaryExits = (surfaceSpec) ->
	return false unless surfaceSpec
	surfaceSpec.kind == Canvas.SurfaceKind.Pillar or
		Canvas.IsContinuousSurface surfaceSpec

Canvas.GetSeamPairs = (data) ->
	width = data and data.Meta and math.floor(tonumber(data.Meta.Width) or 0) or 0
	height = data and data.Meta and math.floor(tonumber(data.Meta.Height) or 0) or 0
	return {} if width < 1 or height < 1
	numCols = width * 2 + 1
	output = {}
	for row = 0, height * 2
		table.insert output, {
			left: 1 + row * numCols
			right: (row + 1) * numCols
			row: row + 1
		}
	output

Canvas.CanonicalSeamIndex = (index, data, surfaceSpec) ->
	return index unless Canvas.IsContinuousSurface surfaceSpec
	width = data and data.Meta and math.floor(tonumber(data.Meta.Width) or 0) or 0
	height = data and data.Meta and math.floor(tonumber(data.Meta.Height) or 0) or 0
	return index if width < 1 or height < 1 or not index
	numCols = width * 2 + 1
	column = 1 + (index - 1) % numCols
	return index unless column == numCols
	index - (numCols - 1)

Canvas.GetSurfaceCompatibility = (data, surfaceSpec) ->
	result = { playable: true, errors: {}, seamPairs: {} }
	width = data and data.Meta and math.floor(tonumber(data.Meta.Width) or 0) or 0
	height = data and data.Meta and math.floor(tonumber(data.Meta.Height) or 0) or 0
	entities = data and data.Entities or {}

	if Canvas.UsesVerticalBoundaryExits(surfaceSpec) and width > 0 and height > 0
		numCols = width * 2 + 1
		bottomRow = height * 2
		for index = 1, numCols * (bottomRow + 1)
			reference = entities[index]
			continue unless reference and reference.Type == "End"
			row = math.floor((index - 1) / numCols)
			continue if row == 0 or row == bottomRow
			result.playable = false
			table.insert result.errors, {
				code: "vertical_exit_boundary"
				socketIndex: index
				row: row + 1
			}

	return result unless Canvas.IsContinuousSurface surfaceSpec
	if width < 3
		result.playable = false
		table.insert result.errors, { code: "continuous_width", minimum: 3, actual: width }
	for pair in *Canvas.GetSeamPairs data
		left, right = entities[pair.left], entities[pair.right]
		leftEmpty, rightEmpty = emptyEntity(left), emptyEntity(right)
		if not leftEmpty and not rightEmpty
			result.playable = false
			errorInfo = {
				code: "continuous_seam_conflict"
				leftIndex: pair.left
				rightIndex: pair.right
			}
			table.insert result.errors, errorInfo
			table.insert result.seamPairs, errorInfo
	result

Canvas.CanonicalizeContinuousData = (data) ->
	return data unless data and data.Meta and data.Entities
	output = table.Copy data
	output.Entities or= {}
	for pair in *Canvas.GetSeamPairs output
		left, right = output.Entities[pair.left], output.Entities[pair.right]
		leftEmpty, rightEmpty = emptyEntity(left), emptyEntity(right)
		if leftEmpty and not rightEmpty
			output.Entities[pair.left] = table.Copy right
			output.Entities[pair.right] = {}
	output

Canvas.WrapDelta = (delta, period) ->
	return delta unless period and period > 0
	half = period * 0.5
	while delta > half
		delta -= period
	while delta < -half
		delta += period
	delta

Canvas.WrapCoordinate = (value, period) ->
	return value unless period and period > 0
	((value % period) + period) % period

Canvas.NearestPeriodicCoordinate = (value, reference, period) ->
	return value unless period and period > 0
	value + math.floor((reference - value) / period + 0.5) * period

Canvas.AngularTraceUnits = (angleDeltaDegrees, width, units = 4096) ->
	return 0 unless width and width > 0
	cellAngle = 360 / width
	value = angleDeltaDegrees / cellAngle * units
	value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)

Canvas.NormalizeAngleDelta = (value) ->
	while value > 180
		value -= 360
	while value < -180
		value += 360
	value

Canvas.UnwrapPillarAngle = (angle, reference) ->
	angle = tonumber(angle) or 0
	reference = tonumber(reference) or angle
	reference + Canvas.NormalizeAngleDelta angle - reference

Canvas.PillarTraceAngle = (screenX, resolution = Canvas.Resolution) ->
	resolution = math.max 0.000001, tonumber(resolution) or 0
	Canvas.WrapCoordinate(tonumber(screenX) or 0, resolution) / resolution * 360

Canvas.PillarAlignmentError = (screenX, playerAngle,
	resolution = Canvas.Resolution) ->
	Canvas.NormalizeAngleDelta Canvas.PillarTraceAngle(screenX, resolution) -
		(tonumber(playerAngle) or 0)

Canvas.PillarArcDegrees = (traceUnits, edgeAngleDegrees, units = 4096) ->
	return 0 unless units and units > 0
	(tonumber(traceUnits) or 0) / units *
		(tonumber(edgeAngleDegrees) or 0)

Canvas.QuantizePillarRadius = (radius, quantum = 16) ->
	quantum = math.max 1, math.floor(tonumber(quantum) or 16)
	math.floor((tonumber(radius) or 0) * quantum + 0.5) / quantum

Canvas.GetPillarRadiusSafety = (radius, pillarRadius, hullRadius,
	clearance = 0.75, maximum = 1024) ->
	minimum = math.max(16, tonumber(pillarRadius) or 0) +
		math.max(0, tonumber(hullRadius) or 0) +
		math.max(0, tonumber(clearance) or 0)
	radius = tonumber(radius) or 0
	safe = radius >= minimum and
		radius <= math.max(minimum, tonumber(maximum) or 1024)
	safe, minimum

-- Return the largest angular follower step that ordinary Source movement can
-- cover this command. The caller targets the corresponding point on the
-- adopted orbit, producing a chord with the radial component needed to avoid
-- the cumulative drift of tangent-only walking.
Canvas.GetPillarFollowerAngleStep = (angleGap, radius, speed, deltaTime) ->
	angleGap = tonumber(angleGap) or 0
	radius = math.max 0.000001, tonumber(radius) or 0
	speed = math.max 0, tonumber(speed) or 0
	deltaTime = math.max 0, tonumber(deltaTime) or 0
	maximum = math.deg speed * deltaTime / radius
	math.Clamp angleGap, -maximum, maximum

-- Radius correction is deliberately slow. Player prediction can move the
-- reported origin across the adopted orbit on consecutive replays; attempting
-- to erase that error in one tick creates a violent inward/outward servo.
Canvas.GetPillarRadialCorrection = (error, deadzone = 0.25, gain = 2,
	maximum = 16) ->
	error = tonumber(error) or 0
	deadzone = math.max 0, tonumber(deadzone) or 0
	gain = math.max 0, tonumber(gain) or 0
	maximum = math.max 0, tonumber(maximum) or 0
	magnitude = math.abs error
	return 0 if magnitude <= deadzone
	value = (magnitude - deadzone) * gain
	value = -value if error < 0
	math.Clamp value, -maximum, maximum

-- Limit a horizontal ghost request to a symmetric signed lead window around
-- the physical player. Moving back toward the player is always permitted;
-- only movement that would increase the separation is shortened.
Canvas.ClampPillarLead = (currentLead, requestedUnits, arcPerUnit,
	maxLead = 10) ->
	currentLead = tonumber(currentLead) or 0
	requestedUnits = math.floor(tonumber(requestedUnits) or 0)
	arcPerUnit = math.abs(tonumber(arcPerUnit) or 0)
	maxLead = math.max 0, tonumber(maxLead) or 0
	return 0 if requestedUnits == 0 or arcPerUnit <= 0
	target = currentLead + requestedUnits * arcPerUnit
	clamped = math.Clamp target, -maxLead, maxLead
	allowed = (clamped - currentLead) / arcPerUnit
	allowed = requestedUnits > 0 and math.floor(allowed + 0.000001) or
		math.ceil(allowed - 0.000001)
	if requestedUnits > 0
		math.Clamp allowed, 0, requestedUnits
	else
		math.Clamp allowed, requestedUnits, 0

-- Find the furthest integer trace-unit position accepted by a monotonic world
-- probe. The caller supplies the coarse safe estimate from TraceHull; binary
-- refinement makes the final clamp independent of chord granularity.
Canvas.RefinePillarTravel = (requestedUnits, coarseSafeUnits, isSafe) ->
	requestedUnits = math.floor(tonumber(requestedUnits) or 0)
	return 0 if requestedUnits == 0 or type(isSafe) ~= "function"
	direction = requestedUnits > 0 and 1 or -1
	maximum = math.abs requestedUnits
	low = math.Clamp math.floor(math.abs(tonumber(coarseSafeUnits) or 0)), 0,
		maximum
	low = 0 unless isSafe direction * low
	return direction * maximum if low == maximum and isSafe requestedUnits
	high = maximum
	while low < high
		mid = math.floor((low + high + 1) / 2)
		if isSafe direction * mid
			low = mid
		else
			high = mid - 1
	direction * low

-- Numerically sweep an angular path in short chords. The callback performs the
-- realm-specific hull trace and returns the unobstructed fraction of each
-- chord. The numeric traversal itself stays shared and testable.
Canvas.SweepPillarArc = (startAngle, deltaAngle, maxStepDegrees = 2,
	traceSegment = nil) ->
	current = tonumber(startAngle) or 0
	remaining = tonumber(deltaAngle) or 0
	maxStepDegrees = math.max 0.01, math.abs(tonumber(maxStepDegrees) or 2)
	accepted = 0
	segments = 0
	while math.abs(remaining) > 0.000000001
		step = math.min math.abs(remaining), maxStepDegrees
		step = -step if remaining < 0
		fraction = traceSegment and traceSegment(current, current + step,
			segments + 1) or 1
		fraction = math.Clamp tonumber(fraction) or 0, 0, 1
		acceptedStep = step * fraction
		accepted += acceptedStep
		current += acceptedStep
		segments += 1
		break if fraction < 0.999999
		remaining -= step
	accepted, segments

-- Returns the earliest line hit against a finite, local-space cylinder as
-- fraction and local normal components. Keeping the numeric kernel here makes
-- the entity collision hook deterministic and directly testable outside GMod.
Canvas.RaycastFiniteCylinder = (sx, sy, sz, dx, dy, dz, radius, height) ->
	radius = math.max 0, tonumber(radius) or 0
	height = math.max 0, tonumber(height) or 0
	return if radius == 0 or height == 0
	local best, normalX, normalY, normalZ
	accept = (fraction, nx, ny, nz) ->
		return unless fraction and fraction >= 0 and fraction <= 1
		return if best and fraction >= best
		best, normalX, normalY, normalZ = fraction, nx, ny, nz

	a = dx * dx + dy * dy
	if a > 0.000000001
		b = 2 * (sx * dx + sy * dy)
		c = sx * sx + sy * sy - radius * radius
		discriminant = b * b - 4 * a * c
		if discriminant >= 0
			root = math.sqrt discriminant
			for fraction in *{(-b - root) / (2 * a), (-b + root) / (2 * a)}
				z = sz + dz * fraction
				if z >= 0 and z <= height
					x, y = sx + dx * fraction, sy + dy * fraction
					accept fraction, x / radius, y / radius, 0

	if math.abs(dz) > 0.000000001
		for cap in *{0, height}
			fraction = (cap - sz) / dz
			x, y = sx + dx * fraction, sy + dy * fraction
			if x * x + y * y <= radius * radius
				accept fraction, 0, 0, cap == 0 and -1 or 1

	best, normalX, normalY, normalZ if best

Canvas.CylinderClearsBox = (offsetX, offsetY, radius, halfWidth,
	halfDepth, tolerance = 0) ->
	nearestX = math.max 0, math.abs(offsetX) - math.max(0, halfWidth)
	nearestY = math.max 0, math.abs(offsetY) - math.max(0, halfDepth)
	required = math.max 0, radius - math.max(0, tolerance)
	nearestX * nearestX + nearestY * nearestY >= required * required - 0.000001


if CLIENT
	if Canvas.PillarMeshes
		for _, meshObject in pairs Canvas.PillarMeshes
			meshObject\Destroy! if meshObject.Destroy
	Canvas.PillarMeshes = {}

	Canvas.GetPillarMesh = (segments) ->
		segments = math.Clamp math.floor(tonumber(segments) or 32), 3, 128
		return Canvas.PillarMeshes[segments] if Canvas.PillarMeshes[segments]
		triangles = {}
		vertex = (angle, z, u, v) -> {
			pos: Vector math.cos(angle), math.sin(angle), z
			normal: Vector math.cos(angle), math.sin(angle), 0
			:u, :v
		}
		for index = 0, segments - 1
			a0 = math.pi * 2 * index / segments
			a1 = math.pi * 2 * (index + 1) / segments
			u0, u1 = index / segments, (index + 1) / segments
			bottom0, bottom1 = vertex(a0, 0, u0, 1), vertex(a1, 0, u1, 1)
			top0, top1 = vertex(a0, 1, u0, 0), vertex(a1, 1, u1, 0)
			-- Source considers this winding front-facing from outside the pillar.
			for item in *{ bottom0, top0, top1, bottom0, top1, bottom1 }
				table.insert triangles, item
		meshObject = Mesh!
		meshObject\BuildFromTriangles triangles
		Canvas.PillarMeshes[segments] = meshObject
		meshObject

	hook.Add "ShutDown", "Moonpanel Pillar Mesh Cleanup", ->
		for _, meshObject in pairs Canvas.PillarMeshes
			meshObject\Destroy! if meshObject.Destroy
		Canvas.PillarMeshes = {}
