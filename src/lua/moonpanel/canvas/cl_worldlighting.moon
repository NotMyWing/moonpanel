Canvas = Moonpanel.Canvas

LIGHT_SCALE = 0.5
PROBE_BIAS = 0.25
registered = setmetatable {}, __mode: "k"
target, targetWidth, targetHeight, renderedFrame = nil, 0, 0, -1
targetPushed = false
activeDescriptors = nil

probeMaterial = CreateMaterial "TheMP World Light Probe 2", "VertexLitGeneric",
	["$basetexture"]: "color/white"
	["$model"]: 1
	["$translucent"]: 1
	["$additive"]: 1

dynamicMaterial = CreateMaterial "TheMP Dynamic Light Probe 1", "UnlitGeneric",
	["$basetexture"]: "color/white"
	["$model"]: 1
	["$vertexcolor"]: 1

ensureTarget = ->
	width = math.max 1, math.ceil ScrW! * LIGHT_SCALE
	height = math.max 1, math.ceil ScrH! * LIGHT_SCALE
	return target if target and width == targetWidth and height == targetHeight

	targetWidth, targetHeight = width, height
	target = GetRenderTargetEx "TheMP World Light #{width}x#{height}", width,
		height, RT_SIZE_OFFSCREEN, MATERIAL_RT_DEPTH_SEPARATE, 2,
		CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_RGBA8888
	target

flatDescriptor = (entity, record, canvas) ->
	return unless entity.ScreenMatrix
	entity\SetupBones! if entity.SetupBones
	bone = entity\GetBoneMatrix 0
	return unless bone
	matrix = bone * entity.ScreenMatrix
	normal = -matrix\GetUp!\GetNormalized!
	matrix\SetTranslation matrix\GetTranslation! + normal * PROBE_BIAS
	{
		:entity
		:record
		:matrix
		meshes: { Canvas.GetFlatScreenMesh! }
	}

pillarDescriptor = (entity, record, canvas) ->
	radius = math.max 1, entity\GetPillarRadius! + PROBE_BIAS
	height = math.max 1, entity\GetPillarHeight!
	segments = if radius >= 128 then 128 elseif radius >= 48 then 64 else 32
	matrix = Matrix!
	matrix\SetTranslation entity\GetPos!
	matrix\SetAngles entity\GetAngles!
	matrix\Scale Vector radius, radius, height
	{
		:entity
		:record
		:matrix
		meshes: { Canvas.GetPillarMesh segments }
	}

collectDescriptors = ->
	descriptors = {}
	for entity, record in pairs registered
		continue unless IsValid entity
		canvas = entity\GetCanvas!
		continue unless canvas and canvas\CanRender!
		continue if canvas.ReactsToColoredLight and
			not canvas\ReactsToColoredLight!
		descriptor = if entity.MoonpanelPillar
			pillarDescriptor entity, record, canvas
		else
			flatDescriptor entity, record, canvas
		descriptors[#descriptors + 1] = descriptor if descriptor
	descriptors

makeVertex = (position, normal) ->
	{
		pos: position
		:normal
		u: 0
		v: 0
		color: color_white
	}

buildFlatLightMesh = (record, divisions = 6) ->
	resolution = Canvas.Resolution
	record.samples = {}
	grid = {}
	normal = Vector 0, 0, -1
	for row = 0, divisions
		grid[row] = {}
		for column = 0, divisions
			position = Vector resolution * column / divisions,
				resolution * row / divisions, 0
			record.samples[#record.samples + 1] = { :position, :normal }
			grid[row][column] = #record.samples

	record.vertices = {}
	record.vertexSamples = {}
	add = (row, column) ->
		sampleIndex = grid[row][column]
		sample = record.samples[sampleIndex]
		record.vertices[#record.vertices + 1] = makeVertex sample.position,
			sample.normal
		record.vertexSamples[#record.vertexSamples + 1] = sampleIndex
	for row = 0, divisions - 1
		for column = 0, divisions - 1
			add row, column
			add row + 1, column + 1
			add row + 1, column
			add row, column
			add row, column + 1
			add row + 1, column + 1

buildPillarLightMesh = (record, segments = 24, rows = 6) ->
	record.samples = {}
	grid = {}
	for row = 0, rows
		grid[row] = {}
		for column = 0, segments
			angle = math.pi * 2 * column / segments
			normal = Vector math.cos(angle), math.sin(angle), 0
			position = Vector normal.x, normal.y, row / rows
			record.samples[#record.samples + 1] = { :position, :normal }
			grid[row][column] = #record.samples

	record.vertices = {}
	record.vertexSamples = {}
	add = (row, column) ->
		sampleIndex = grid[row][column]
		sample = record.samples[sampleIndex]
		record.vertices[#record.vertices + 1] = makeVertex sample.position,
			sample.normal
		record.vertexSamples[#record.vertexSamples + 1] = sampleIndex
	for column = 0, segments - 1
		for row = 0, rows - 1
			add row, column
			add row + 1, column
			add row + 1, column + 1
			add row, column
			add row + 1, column + 1
			add row, column + 1

prepareDynamicMesh = (descriptor) ->
	record = descriptor.record
	unless record.samples
		if descriptor.entity.MoonpanelPillar
			buildPillarLightMesh record
		else
			buildFlatLightMesh record
		record.dynamicMesh = Mesh!

	colors = {}
	for index, sample in ipairs record.samples
		position = descriptor.matrix * sample.position
		normal = if descriptor.entity.MoonpanelPillar
			descriptor.entity\LocalToWorldVector(sample.normal)\GetNormalized!
		else
			-descriptor.matrix\GetUp!\GetNormalized!
		light = render.ComputeDynamicLighting position, normal
		colors[index] = Color math.Clamp(light.x * 255, 0, 255),
			math.Clamp(light.y * 255, 0, 255),
			math.Clamp(light.z * 255, 0, 255), 255

	for index, vertex in ipairs record.vertices
		vertex.color = colors[record.vertexSamples[index]]
	record.dynamicMesh\BuildFromTriangles record.vertices
	record.dynamicMesh

drawDynamicDescriptors = (descriptors) ->
	return unless render.ComputeDynamicLighting
	render.SetMaterial dynamicMaterial
	for descriptor in *descriptors
		meshObject = prepareDynamicMesh descriptor
		cam.PushModelMatrix descriptor.matrix
		ok, err = xpcall meshObject.Draw, debug.traceback, meshObject
		cam.PopModelMatrix!
		error err, 0 unless ok

drawDescriptors = (descriptors) ->
	render.SetMaterial probeMaterial
	for descriptor in *descriptors
		cam.PushModelMatrix descriptor.matrix
		ok, err = xpcall (->
			for meshObject in *descriptor.meshes
				meshObject\Draw!), debug.traceback
		cam.PopModelMatrix!
		error err, 0 unless ok

drawActiveDescriptors = -> drawDescriptors activeDescriptors

renderField = (descriptors) ->
	texture = ensureTarget!
	render.PushRenderTarget texture
	targetPushed = true
	render.Clear 0, 0, 0, 0, true, true
	drawDynamicDescriptors descriptors
	render.ClearDepth false
	activeDescriptors = descriptors
	render.RenderFlashlights drawActiveDescriptors if render.RenderFlashlights
	activeDescriptors = nil
	render.PopRenderTarget!
	targetPushed = false
	renderedFrame = FrameNumber!

Canvas.RegisterWorldPanel = (entity) -> registered[entity] or= {}
Canvas.UnregisterWorldPanel = (entity) ->
	if record = registered[entity]
		record.dynamicMesh\Destroy! if record.dynamicMesh and
			record.dynamicMesh.Destroy
	registered[entity] = nil
Canvas.GetWorldLightTexture = ->
	return unless renderedFrame == FrameNumber!
	target

hook.Add "PreDrawTranslucentRenderables", "Moonpanel World Light Field",
	(isDepth, isSkybox, is3DSkybox) ->
		return if isDepth or isSkybox or is3DSkybox
		return unless Canvas.IsWorldLightingEnabled!
		descriptors = collectDescriptors!
		return if #descriptors == 0

		ok, err = xpcall renderField, debug.traceback, descriptors
		unless ok
			activeDescriptors = nil
			if targetPushed
				render.PopRenderTarget!
				targetPushed = false
			ErrorNoHalt "[moonpanel] World light field failed:\n#{err}\n"

hook.Add "ShutDown", "Moonpanel World Light Cleanup", ->
	for entity in pairs registered
		Canvas.UnregisterWorldPanel entity
