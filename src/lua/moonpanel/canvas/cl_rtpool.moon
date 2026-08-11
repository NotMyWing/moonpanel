MAX_RT_PAGES = 256
DISPLAY_MATERIAL_VERSION = 11
DISPLAY_SHEAR = 0.012
WALL_UNLIT_BRIGHTNESS = 0.42
CVars = Moonpanel.CVarNames
maxPagesConVar = CreateClientConVar CVars.RTPoolMaxPages, "32", true, false,
	"Maximum number of Moonpanel canvas render targets", 1, MAX_RT_PAGES
worldLightingConVar = CreateClientConVar CVars.ScreenWorldLighting, "1", true,
	false, "Light in-world Moonpanel screens using the surrounding world"

createDisplayMaterial = (name, texture) ->
	parameters =
		["$basetexture"]: texture\GetName!
		["$texture1"]: "color/black"
		["$pixshader"]: "moonpanel_display_v9_ps20"
		["$vertexshader"]: "moonpanel_display_v9_vs20"
		["$vertexcolor"]: 1
		["$vertexalpha"]: 1
		["$translucent"]: 1
		["$copyalpha"]: 1
		["$cull"]: 1
		["$depthtest"]: 1
		["$c0_x"]: 1
		["$c0_y"]: 0
		["$c1_x"]: 0
		["$c1_y"]: 0
		["$c1_z"]: 0
		["$c2_x"]: 0
		["$c2_y"]: 0
		["$c2_z"]: 0
	CreateMaterial "#{name} Display #{DISPLAY_MATERIAL_VERSION}",
		"screenspace_general", parameters

wallMaterial = CreateMaterial "TheMP Relief Wall Metal 2", "VertexLitGeneric",
	["$basetexture"]: "color/white"
	["$color2"]: "[0.42 0.44 0.46]"
	["$envmap"]: "env_cubemap"
	["$envmaptint"]: "[0.055 0.06 0.065]"
	["$envmapcontrast"]: 0.2
	["$envmapsaturation"]: 0.35
	["$phong"]: 1
	["$phongexponent"]: 48
	["$phongboost"]: 0.22
	["$phongfresnelranges"]: "[0.15 0.5 1]"
	["$phongtint"]: "[0.18 0.19 0.2]"
	["$halflambert"]: 1
	["$model"]: 1
	["$vertexcolor"]: 1
Moonpanel.Canvas.ReliefWallMaterial = wallMaterial

wallUnlitMaterial = CreateMaterial "TheMP Relief Wall Gray 1", "UnlitGeneric",
	["$basetexture"]: "color/white"
	["$model"]: 1
	["$vertexcolor"]: 1

screenGlassMaterial = CreateMaterial "TheMP Screen Glass 3", "VertexLitGeneric",
	["$basetexture"]: "color/black"
	["$envmap"]: "env_cubemap"
	["$envmaptint"]: "[0.26 0.3 0.36]"
	["$envmapcontrast"]: 0.5
	["$envmapsaturation"]: 1
	["$phong"]: 1
	["$phongexponent"]: 96
	["$phongboost"]: 0.5
	["$phongfresnelranges"]: "[0.04 0.2 1]"
	["$phongtint"]: "[0.8 0.9 1]"
	["$rimlight"]: 1
	["$rimlightexponent"]: 5
	["$rimlightboost"]: 0.4
	["$additive"]: 1
	["$translucent"]: 1
	["$model"]: 1

createRT = (name, worldMaterial = false) ->
	texture = GetRenderTargetEx name,
			Moonpanel.Canvas.Resolution,
			Moonpanel.Canvas.Resolution,
			RT_SIZE_OFFSCREEN,
			MATERIAL_RT_DEPTH_SHARED,
			2,
			CREATERENDERTARGETFLAGS_HDR,
			IMAGE_FORMAT_RGBA8888

	material = CreateMaterial name, "UnlitGeneric",
		["$basetexture"]: texture\GetName!
		["$translucent"]: 1
		["$vertexcolor"]: 1
		["$vertexalpha"]: 1

	displayMaterial = createDisplayMaterial(name, texture) if worldMaterial

	texture, material, displayMaterial

ensureDisplayMaterial = (rt) ->
	return rt.displayMaterial if rt.displayMaterial and
		rt.displayMaterialVersion == DISPLAY_MATERIAL_VERSION
	name = rt.texture\GetName!
	rt.displayMaterial = createDisplayMaterial name, rt.texture
	rt.displayMaterialVersion = DISPLAY_MATERIAL_VERSION
	rt.displayMaterial

initializePool = (canvas) ->
	return if canvas.__freeRTs

	canvas.__allocatedRTs = {}
	canvas.__freeRTs = util.Stack!
	canvas.__rtTokens = {}
	canvas.__rtPageCount = 0

getPageLimit = ->
	value = maxPagesConVar and maxPagesConVar\GetInt! or MAX_RT_PAGES
	math.max 1, math.min MAX_RT_PAGES, math.floor value

growPool = (canvas) ->
	initializePool canvas
	limit = getPageLimit!
	current = canvas.__rtPageCount
	return false if current >= limit

	target = math.min limit, math.max 1, current * 2
	for page = current + 1, target
		texture, material, displayMaterial = createRT "TheMP RT #{page}", true
		canvas.__freeRTs\Push {
			:texture
			:material
			:displayMaterial
			displayMaterialVersion: DISPLAY_MATERIAL_VERSION
		}

	canvas.__rtPageCount = target
	true

evictOldest = (canvas) ->
	oldest = table.remove canvas.__allocatedRTs, 1
	return false unless oldest

	canvas.__rtTokens[oldest.token] = nil
	canvas.__freeRTs\Push oldest.rt
	true

Moonpanel.Canvas.BakeAuxiliaryRT = =>
	return @__auxiliaryRT if @__auxiliaryRT

	texture, material = createRT "TheMP RT Aux"
	@__auxiliaryRT = {
		:texture
		:material
	}

	@__auxiliaryRT

Moonpanel.Canvas.BakePages = =>
	initializePool @


Moonpanel.Canvas.GetAuxiliaryRT = =>
	@BakeAuxiliaryRT!

Moonpanel.Canvas.AllocateRT = (forceEvict = false) =>
	@BakePages! unless @__freeRTs
	growPool @ unless @__freeRTs\Size! > 0
	evictOldest @ if forceEvict and @__freeRTs\Size! == 0

	return unless @__freeRTs\Size! > 0

	rt = @__freeRTs\Pop!

	proxy = newproxy true
	token = tostring proxy

	@__rtTokens[token] = true

	alloc = {
		:token
		:proxy
		:rt
	}
	@__allocatedRTs[#@__allocatedRTs + 1] = alloc

	with getmetatable proxy
		.__gc = ->
			@DeallocateRT alloc

	alloc

Moonpanel.Canvas.DeallocateRT = (alloc) =>
	if @__rtTokens[alloc.token]
		@__rtTokens[alloc.token] = nil
		for index, active in ipairs @__allocatedRTs
			if active == alloc
				table.remove @__allocatedRTs, index
				break
		@__freeRTs\Push alloc.rt

Moonpanel.Canvas.IsRTAllocated = (alloc) => @__rtTokens[alloc.token] or false
Moonpanel.Canvas.IsWorldLightingEnabled = -> worldLightingConVar\GetBool!
drawMeshes = (meshObjects) ->
	if meshObjects.Draw
		meshObjects\Draw!
	else
		for meshObject in *meshObjects
			meshObject\Draw!

drawWorldRT = (rt, meshObjects, power, lit, matrixResponse, shear,
	viewPosition, pillar) ->
	displayMaterial = ensureDisplayMaterial(rt) if lit or matrixResponse or shear
	if not displayMaterial
		render.SetColorModulation power, power, power
		render.SetMaterial rt.material
		render.SetBlend 1
		drawMeshes meshObjects
		return

	displayMaterial\SetFloat "$c0_x", power
	displayMaterial\SetFloat "$c0_y", lit and 1 or 0
	displayMaterial\SetFloat "$c2_x", shear and DISPLAY_SHEAR or 0
	displayMaterial\SetFloat "$c2_y", pillar and 1 or 0
	displayMaterial\SetFloat "$c2_z", matrixResponse and 1 or 0
	if viewPosition
		displayMaterial\SetFloat "$c1_x", viewPosition.x
		displayMaterial\SetFloat "$c1_y", viewPosition.y
		displayMaterial\SetFloat "$c1_z", viewPosition.z
	getLightTexture = Moonpanel.Canvas.GetWorldLightTexture
	if lightTexture = getLightTexture and getLightTexture!
		displayMaterial\SetTexture "$texture1", lightTexture
	render.SetColorModulation 1, 1, 1
	render.SetMaterial displayMaterial
	render.SetBlend 1
	render.OverrideBlend true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA,
		BLENDFUNC_ADD, BLEND_ONE, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD
	drawMeshes meshObjects

Moonpanel.Canvas.DrawWorldRT = (rt, meshObjects, power = 1,
	coloredLighting = true, matrixResponse = false, shear = false,
	viewPosition, pillar = false) ->
	return unless rt and meshObjects
	power = math.Clamp tonumber(power) or 1, 0, 1
	red, green, blue = render.GetColorModulation!
	blend = render.GetBlend!
	worldEffects = Moonpanel.Canvas.IsWorldLightingEnabled!
	ok, err = xpcall drawWorldRT, debug.traceback, rt, meshObjects, power,
		coloredLighting and worldEffects,
		matrixResponse and worldEffects and viewPosition ~= nil,
		shear and worldEffects and viewPosition ~= nil, viewPosition, pillar
	render.OverrideBlend false
	render.SetColorModulation red, green, blue
	render.SetBlend blend
	error err, 0 unless ok
	true

drawUniqueMeshes = (meshObjects) ->
	render.ClearStencil!
	render.SetStencilEnable true
	render.SetStencilReferenceValue 1
	render.SetStencilWriteMask 1
	render.SetStencilTestMask 1
	render.SetStencilPassOperation STENCIL_REPLACE
	render.SetStencilFailOperation STENCIL_KEEP
	render.SetStencilZFailOperation STENCIL_KEEP
	render.SetStencilCompareFunction STENCIL_GREATER
	drawMeshes meshObjects
	render.SetStencilEnable false

drawWorldGlass = (meshObjects, lightingOrigin) ->
	render.SetLightingOrigin lightingOrigin if lightingOrigin
	render.SetColorModulation 1, 1, 1
	render.SetBlend 1
	render.SetMaterial screenGlassMaterial
	drawUniqueMeshes meshObjects
	if render.RenderFlashlights
		render.RenderFlashlights ->
			render.SetMaterial screenGlassMaterial
			drawUniqueMeshes meshObjects

Moonpanel.Canvas.DrawWorldGlass = (meshObjects, lightingOrigin) ->
	return unless Moonpanel.Canvas.IsWorldLightingEnabled! and meshObjects and
		meshObjects[1]
	red, green, blue = render.GetColorModulation!
	blend = render.GetBlend!
	ok, err = xpcall drawWorldGlass, debug.traceback, meshObjects,
		lightingOrigin
	render.SetStencilEnable false
	render.SetColorModulation red, green, blue
	render.SetBlend blend
	error err, 0 unless ok
	true

drawWorldWalls = (meshObjects, lit, lightingOrigin) ->
	render.SetLightingOrigin lightingOrigin if lightingOrigin
	if lit
		render.SetColorModulation 1, 1, 1
		render.SetMaterial wallMaterial
	else
		render.SetColorModulation WALL_UNLIT_BRIGHTNESS, WALL_UNLIT_BRIGHTNESS,
			WALL_UNLIT_BRIGHTNESS
		render.SetMaterial wallUnlitMaterial
	render.SetBlend 1
	drawMeshes meshObjects
	if lit and render.RenderFlashlights
		render.RenderFlashlights ->
			render.SetMaterial wallMaterial
			drawMeshes meshObjects

Moonpanel.Canvas.DrawWorldWalls = (meshObjects, lightingOrigin) ->
	return unless meshObjects and meshObjects[1]
	red, green, blue = render.GetColorModulation!
	blend = render.GetBlend!
	ok, err = xpcall drawWorldWalls, debug.traceback, meshObjects,
		Moonpanel.Canvas.IsWorldLightingEnabled!, lightingOrigin
	render.SetColorModulation red, green, blue
	render.SetBlend blend
	error err, 0 unless ok
	true
