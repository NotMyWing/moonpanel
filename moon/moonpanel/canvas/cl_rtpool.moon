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

Moonpanel.Canvas.BakePages = =>
	@__allocatedRTs = {}
	@__freeRTs = util.Stack!
	@__rtTokens = {}

	for page = 1, 100
		texture, material = createRT "TheMP RT #{page}"
		@__freeRTs\Push {
			:texture
			:material
		}

	texture, material = createRT "TheMP RT Aux"
	@__auxiliaryRT = {
		:texture
		:material
	}


Moonpanel.Canvas.GetAuxiliaryRT = =>
	@BakePages! if not @__auxiliaryRT

	@__auxiliaryRT

Moonpanel.Canvas.AllocateRT = =>
	@BakePages! if not @__freeRTs

	return if 0 >= @__freeRTs\Size!

	rt = @__freeRTs\Pop!
	@__allocatedRTs[rt] = rt

	proxy = newproxy true
	token = tostring proxy

	@__rtTokens[token] = true

	alloc = {
		:token
		:proxy
		:rt
	}

	with getmetatable proxy
		.__gc = ->
			@DeallocateRT alloc

	alloc

Moonpanel.Canvas.DeallocateRT = (alloc) =>
	if @__rtTokens[alloc.token]
		@__rtTokens[alloc.token] = nil
		@__allocatedRTs[alloc.rt] = nil
		@__freeRTs\Push alloc.rt

Moonpanel.Canvas.IsRTAllocated = (alloc) => @__rtTokens[alloc.token] or false
