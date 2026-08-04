MAX_RT_PAGES = 32
CVars = Moonpanel.CVarNames
maxPagesConVar = CreateClientConVar CVars.RTPoolMaxPages, "16", true, false,
	"Maximum number of Moonpanel canvas render targets", 1, MAX_RT_PAGES

createRT = (name) ->
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

	texture, material

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
		texture, material = createRT "TheMP RT #{page}"
		canvas.__freeRTs\Push {
			:texture
			:material
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
