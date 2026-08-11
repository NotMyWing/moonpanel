MAX_RT_PAGES = 256
CVars = Moonpanel.CVarNames
maxPagesConVar = CreateClientConVar CVars.RTPoolMaxPages, "32", true, false,
	"Maximum number of Moonpanel canvas render targets", 1, MAX_RT_PAGES
worldLightingConVar = CreateClientConVar CVars.ScreenWorldLighting, "1", true,
	false, "Light in-world Moonpanel screens using the surrounding world"
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

	displayMaterial = if worldMaterial
		CreateMaterial "#{name} Display 4", "screenspace_general",
			["$basetexture"]: texture\GetName!
			["$texture1"]: "color/black"
			["$pixshader"]: "moonpanel_display_v3_ps20"
			["$vertexshader"]: "moonpanel_display_v3_vs20"
			["$vertexcolor"]: 1
			["$copyalpha"]: 1
			["$cull"]: 1
			["$depthtest"]: 1

	texture, material, displayMaterial

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
drawWorldRT = (rt, meshObject, power, lit) ->
	if not lit or not rt.displayMaterial
		render.SetColorModulation power, power, power
		render.SetMaterial rt.material
		render.SetBlend 1
		meshObject\Draw!
		return

	rt.displayMaterial\SetFloat "$c0_x", power
	getLightTexture = Moonpanel.Canvas.GetWorldLightTexture
	if lightTexture = getLightTexture and getLightTexture!
		rt.displayMaterial\SetTexture "$texture1", lightTexture
	render.SetColorModulation 1, 1, 1
	render.SetMaterial rt.displayMaterial
	render.SetBlend 1
	meshObject\Draw!

Moonpanel.Canvas.DrawWorldRT = (rt, meshObject, power = 1) ->
	return unless rt and meshObject
	power = math.Clamp tonumber(power) or 1, 0, 1
	red, green, blue = render.GetColorModulation!
	blend = render.GetBlend!
	ok, err = xpcall drawWorldRT, debug.traceback, rt, meshObject, power,
		Moonpanel.Canvas.IsWorldLightingEnabled!
	render.SetColorModulation red, green, blue
	render.SetBlend blend
	error err, 0 unless ok
	true
