CANVAS = Moonpanel.Canvas.Canvas.__base

MAT_CIRCLE = Material "moonpanel/circle.png"
MAT_VIGNETTE = Material "moonpanel/common/vignette.png", "smooth"
MAT_TRACE = Material "vgui/white"
RING_SEGMENTS = 48
ringOuter = [{ x: 0, y: 0 } for _ = 0, RING_SEGMENTS]
ringInner = [{ x: 0, y: 0 } for _ = 0, RING_SEGMENTS]
focusTargetFrame = -1
focusTargetEntity = nil

import Rgb2Lch, Lch2Rgb from include "cl_colorutils.lua"

makeBlinkColor = (color, pct = 0.15) ->
	h, s, v = ColorToHSV color
	v = v > (1 - pct / 2) and v - pct or math.min 1, v + pct

	HSVToColor h, s, v

lerpColor = (value, cA, cB) ->
	alpha = (cA.a or 255) * (1 - value) + (cB.a or 255) * value
	cA = { Rgb2Lch cA.r / 255, cA.g / 255, cA.b / 255 }
	cB = { Rgb2Lch cB.r / 255, cB.g / 255, cB.b / 255 }

	for i = 1, 3
		cA[i] += value * (cB[i] - cA[i])

	r, g, b = Lch2Rgb cA[1], cA[2], cA[3]
	math.Round(r * 255), math.Round(g * 255), math.Round(b * 255), alpha

circleAt = (x, y, r) ->
	surface.SetMaterial MAT_CIRCLE
	surface.DrawTexturedRect math.Round(x - r), math.Round(y - r),
		math.Round(r * 2), math.Round(r * 2)

drawRingAt = (x, y, radius, thickness) ->
	innerRadius = math.max 0.1, radius - thickness
	for i = 0, RING_SEGMENTS
		angle = math.pi * 2 * i / RING_SEGMENTS
		cosAngle = math.cos angle
		sinAngle = math.sin angle
		outerVertex = ringOuter[i + 1]
		outerVertex.x = x + cosAngle * radius
		outerVertex.y = y + sinAngle * radius
		innerVertex = ringInner[i + 1]
		innerVertex.x = x + cosAngle * innerRadius
		innerVertex.y = y + sinAngle * innerRadius

	-- Use the stencil to subtract the inner disc without painting over the
	-- trace or clue geometry underneath the expanding ring.
	draw.NoTexture!
	render.ClearStencil!
	render.SetStencilEnable true
	render.SetStencilReferenceValue 1
	render.SetStencilWriteMask 1
	render.SetStencilTestMask 1
	render.SetStencilPassOperation STENCIL_KEEP
	render.SetStencilCompareFunction STENCIL_NEVER
	render.SetStencilFailOperation STENCIL_REPLACE
	render.SetStencilZFailOperation STENCIL_REPLACE
	surface.DrawPoly ringInner
	render.SetStencilFailOperation STENCIL_KEEP
	render.SetStencilZFailOperation STENCIL_KEEP
	render.SetStencilCompareFunction STENCIL_GREATER
	surface.DrawPoly ringOuter
	render.SetStencilEnable false

getLocalFocusTarget = ->
	frame = FrameNumber!
	return focusTargetEntity if focusTargetFrame == frame
	focusTargetFrame = frame
	focusTargetEntity = nil
	return unless Moonpanel.IsFocused!

	controlled = Moonpanel.GetPredictedControl! if Moonpanel.GetPredictedControl
	if IsValid controlled
		focusTargetEntity = controlled
		return focusTargetEntity

	ply = LocalPlayer!
	return unless IsValid ply
	trace = util.TraceLine
		start: ply\EyePos!
		endpos: ply\EyePos! + ply\GetAimVector! * 4096 * 8
		filter: ply
	if trace and IsValid trace.Entity
		focusTargetEntity = trace.Entity if trace.Entity.Moonpanel
	focusTargetEntity

clearRT = (rt) ->
	with render.PushRenderTarget rt
		cam.Start2D!
		render.Clear 0, 0, 0, 255, true, false
		cam.End2D!

	render.PopRenderTarget!

drawLine = (x1, y1, x2, y2, width, length) ->
	dX = x2 - x1
	dY = y2 - y1
	-- Panel routes are orthogonal.  Draw those segments as filled geometry
	-- instead of relying on DrawTexturedRectRotated's current material state.
	-- This is especially important for restored terminal traces.
	if (math.abs dY) < 0.001
		x = math.min x1, x2
		y = y1 - width * 0.5
		rectWidth = math.max 1, math.ceil math.abs dX
		rectHeight = math.max 1, math.ceil width
		surface.DrawRect (math.floor x), (math.floor y), rectWidth, rectHeight
		return
	if (math.abs dX) < 0.001
		x = x1 - width * 0.5
		y = math.min y1, y2
		rectWidth = math.max 1, math.ceil width
		rectHeight = math.max 1, math.ceil math.abs dY
		surface.DrawRect (math.floor x), (math.floor y), rectWidth, rectHeight
		return

	angle = math.pi / 2 + math.atan2 dX, dY

	local posX, posY
	if not length
		length = math.sqrt dX * dX + dY * dY

		posX = 0.5 * (x1 + x2)
		posY = 0.5 * (y1 + y2)

	else
		posX = x1 - 0.5 * length * math.cos angle
		posY = y1 + 0.5 * length * math.sin angle

	surface.DrawTexturedRectRotated (math.Round posX), (math.Round posY),
		length, width, math.deg angle

CANVAS.DeallocateRT = =>
	if @__rtAlloc
		return if not Moonpanel.Canvas\IsRTAllocated @__rtAlloc

		Moonpanel.Canvas\DeallocateRT @__rtAlloc

		true

CANVAS.CanRender = => @__rtAlloc and Moonpanel.Canvas\IsRTAllocated @__rtAlloc

CANVAS.AllocateRT = =>
	return if @__rtAlloc and Moonpanel.Canvas\IsRTAllocated @__rtAlloc

	@__rtAlloc = Moonpanel.Canvas\AllocateRT!

	if @__rtAlloc
		clearRT @__rtAlloc.rt.texture
		@__rtDirty = true

		true

CANVAS.BakeImportedColors = =>
	@__clientData = {
		renderables: {}
		renderablesBelowTrace: {}
		renderablesOverTrace: {}
	}

	with @__clientData
		colors = @GetColors!
		traceOptions = @__data.Meta.SymmetryOptions and @__data.Meta.SymmetryOptions.Traces
		@__presentation\setBranches for i = 1, #colors.Trace
			{
				visible: not (traceOptions and traceOptions[i] and
					traceOptions[i].Invisible)
				color: colors.Trace[i]
				completionColor: colors.EndTrace[i]
			}

		.extraColors = {}
		.extraColors.blink = [makeBlinkColor color for color in *colors.Trace]

------------------------------
-- Rendering optimizations. --
------------------------------
CANVAS.RecalculateClient = =>
	return if not @__data

	barLength = @GetBarLength!
	barWidth = @GetBarWidth!
	@__rtDirty = true

	@__clientData.paths = {}
	@__clientData.distances = {}
	for node in *@__nodes
		@__clientData.distances[node] = {}

	seen = {}

	-- Extract paths and calculate distances.
	for nodeA in *@__nodes
		isSeen = false
		for nodeB in *nodeA.neighbors
			-- The duplicate right seam has no vertical geometry. Horizontal
			-- routes still reach the edge and remain the authored wrap paths.
			continue if @IsHiddenContinuousSocket(nodeA.socket) and
				@IsHiddenContinuousSocket(nodeB.socket)
			if not isSeen
				seen[nodeA] = true
				isSeen = true

			if not seen[nodeB]
				dx = nodeB.screenX - nodeA.screenX
				dy = nodeB.screenY - nodeA.screenY
				angle = math.atan2 dy, dx
				rawDistance = math.sqrt dx * dx + dy * dy
				dist = math.ceil rawDistance

				@__clientData.distances[nodeA][nodeB] = dist
				@__clientData.distances[nodeB][nodeA] = dist

				renderDistance = dist
				centerX = math.floor (nodeB.screenX + nodeA.screenX) * 0.5
				centerY = math.floor (nodeB.screenY + nodeA.screenY) * 0.5
				if rawDistance > 0 and (nodeA.break or nodeB.break)
					-- The pathfinder stops the round trace head at the break node.
					-- Extend the rectangular grid underneath by one head radius,
					-- matching the donor: the cap remains round but never protrudes
					-- beyond the sharp rendered lip.
					extension = barWidth * 0.5
					direction = nodeB.break and 1 or -1
					centerX = (nodeA.screenX + nodeB.screenX) * 0.5 +
						direction * dx / rawDistance * extension * 0.5
					centerY = (nodeA.screenY + nodeB.screenY) * 0.5 +
						direction * dy / rawDistance * extension * 0.5
					renderDistance = rawDistance + extension

				table.insert @__clientData.paths, {
					angle: math.Round math.deg angle
					distance: renderDistance

					screenX: centerX
					screenY: centerY
				}

	-- Test occlusion.
	@__clientData.visibleNodes = {}

	for node in *@__nodes
		continue if @IsHiddenContinuousSocket node.socket
		-- Gap lips are cuts through a rectangular bar, not junctions. Their
		-- backing segments are already rendered, so adding node circles here
		-- creates the rounded nubs absent from Witness panels.
		continue if node.break
		if node.clickable
			table.insert @__clientData.visibleNodes, node
			continue

		continue if node.invisible
		continue if 0 == table.Count node.neighbors

		ranges = {}
		for nodeB in *node.neighbors
			angle = 180 + math.deg math.atan2 nodeB.screenY - node.screenY,
				nodeB.screenX - node.screenX

			lower = angle - 90
			upper = angle + 90

			if lower < 0
				table.insert ranges, {
					360 + lower, 360
				}

				table.insert ranges, {
					0, upper
				}
			elseif upper > 360
				table.insert ranges, {
					0, upper - 360
				}

				table.insert ranges, {
					lower, 360
				}
			else
				table.insert ranges, {
					lower, upper
				}

		table.sort ranges, (a, b) -> a[1] < b[1]

		local lowerBound
		local upperBound
		for range in *ranges
			lower = range[1]
			upper = range[2]

			if not lowerBound
				lowerBound = lower

			if not upperBound
				upperBound = upper

			elseif lower <= upperBound
				upperBound = math.max upper, upperBound

		if upperBound - lowerBound < 360
			table.insert @__clientData.visibleNodes, node

----------------------------
-- Paints the trace. Duh. --
----------------------------
CANVAS.PaintTrace = (w, h) =>
	state = @__renderTraceState or @GetTraceRenderState!
	return unless state and state.routes and state.routes[1]

	frame = @__visualFrame or {
		widthScale: 1
		exitPulse: 0
		traceError: 0
		completion: 0
		flash: 0
	}
	-- A restored solution is already a completed presentation.  Do not replay
	-- the beginning-of-attempt width interpolation while drawing its terminal
	-- snapshot into the cached target.
	if @__terminalSnapshot and @__terminalSnapshotRestored
		frame = {
			widthScale: 1
			exitPulse: 0
			traceAlpha: 1
			traceError: 0
			completion: @__playData and @__playData.visualResult and
				@__playData.visualResult.success and 1 or 0
			flash: 0
			branchStyles: frame.branchStyles
		}
	widthModifier = frame.widthScale or 1
	regularRadius = widthModifier * @GetBarWidth! *
		(w / Moonpanel.Canvas.Resolution)
	firstNodeRadius = math.Round 0.5 * regularRadius * 2.5
	regularRadius = math.Round 0.5 * regularRadius

	colors = @GetColors!
	continuous = @IsContinuous!
	periodPixels = continuous and @GetBarLength! * @__data.Meta.Width or 0
	drawRouteSegment = (edge, fraction, width) ->
		fromNode = @__pathFinder.topology.nodes[edge.fromId]
		toNode = @__pathFinder.topology.nodes[edge.toId]
		return unless fromNode and toNode
		startX = edge.fromScreenX or fromNode.screenX
		startY = edge.fromScreenY or fromNode.screenY
		endX = edge.toScreenX or toNode.screenX
		endY = edge.toScreenY or toNode.screenY
		headX = startX + (endX - startX) * fraction
		headY = startY + (endY - startY) * fraction
		shifts = if continuous then { -periodPixels, 0, periodPixels } else { 0 }
		for shift in *shifts
			x1, x2 = startX + shift, headX + shift
			continue if math.max(x1, x2) < -width or math.min(x1, x2) > w + width
			surface.SetMaterial MAT_TRACE
			drawLine x1, startY, x2, headY, width
			circleAt x2, headY, width * 0.5
	for stackId, route in ipairs state.routes
		branchStyle = frame.branchStyles and frame.branchStyles[stackId]
		continue if branchStyle and branchStyle.visible == false

		traceColor = branchStyle and branchStyle.color or
			colors.Trace[stackId] or colors.Trace[1]
		if (frame.exitPulse or 0) > 0
			traceColor = Color lerpColor math.min(1, frame.exitPulse), traceColor,
				@__clientData.extraColors.blink[stackId] or
				@__clientData.extraColors.blink[1]
		if (frame.traceError or 0) > 0
			traceColor = Color lerpColor math.min(1, frame.traceError), traceColor,
				colors.Error
		if (frame.completion or 0) > 0
			traceColor = Color lerpColor math.min(1, frame.completion), traceColor,
				branchStyle and branchStyle.completionColor or
				colors.EndTrace[stackId] or colors.EndTrace[1]
		if (frame.flash or 0) > 0
			traceColor = Color lerpColor math.min(1, frame.flash * 0.65), traceColor,
				Color 255, 255, 255
		surface.SetDrawColor traceColor.r, traceColor.g, traceColor.b, 255

		first = @__pathFinder.topology.nodes[route.startId]
		continue unless first
		circleAt first.screenX, first.screenY, firstNodeRadius
		if continuous and not @GetEditorGeometryVisible! and
				math.abs(first.screenX) < firstNodeRadius
			circleAt first.screenX + periodPixels, first.screenY, firstNodeRadius

		for segment in *route.segments
			edge = @__pathFinder.topology\getEdge segment.fromId, segment.toId
			continue unless edge and segment.visibleLength > 0
			fraction = segment.fullLength > 0 and
				math.min(1, segment.visibleLength / segment.fullLength) or 0
			drawRouteSegment edge, fraction, regularRadius * 2

CANVAS.GetEntityVisualStyle = (socket) =>
	return unless socket and @__visualFrame and @__visualFrame.entityStyles
	index = @GetSocketDataIndex socket
	index and @__visualFrame.entityStyles[index] or nil

CANVAS.HasDynamicEntityStyle = (socket) =>
	style = @GetEntityVisualStyle socket
	return false unless style
	(style.error or 0) > 0 or
		(style.erased or 0) > 0 or
		(style.glow or 0) > 0 or
		(style.tint and (style.tintAmount or 0) > 0) or
		(style.alpha or 1) < 0.999

CANVAS.ApplyEntityVisualColor = (color, socket) =>
	style = @GetEntityVisualStyle socket
	return color.r, color.g, color.b, color.a or 255 unless style

	r, g, b, a = color.r, color.g, color.b, color.a or 255
	if style.tint
		amount = math.Clamp style.tintAmount or 1, 0, 1
		r += (style.tint.r - r) * amount
		g += (style.tint.g - g) * amount
		b += (style.tint.b - b) * amount
	error = math.Clamp style.error or 0, 0, 1
	if error > 0
		target = Color 255, 36, 36
		if r > 150 and r > g * 1.45 and r > b * 1.45
			target = Color 25, 8, 8
		r += (target.r - r) * error
		g += (target.g - g) * error
		b += (target.b - b) * error

	erased = math.Clamp style.erased or 0, 0, 1
	if erased > 0
		gray = r * 0.299 + g * 0.587 + b * 0.114
		r += (gray - r) * erased
		g += (gray - g) * erased
		b += (gray - b) * erased

	glow = math.Clamp style.glow or 0, 0, 1
	r += (255 - r) * glow
	g += (255 - g) * glow
	b += (255 - b) * glow
	a *= math.Clamp style.alpha or 1, 0, 1
	math.Round(r), math.Round(g), math.Round(b), math.Round(a)

CANVAS.PaintPresentationEffects = =>
	frame = @__visualFrame
	return unless frame and @__pathFinder
	barWidth = @GetBarWidth!
	if (frame.startRipple or 0) > 0
		surface.SetDrawColor 255, 255, 255, math.Round(frame.startRipple * 42)
		state = @__renderTraceState or @GetTraceRenderState!
		seen = {}
		for route in *(state and state.routes or {})
			continue if seen[route.startId]
			seen[route.startId] = true
			if node = @__pathFinder.topology.nodes[route.startId]
				radius = barWidth * (1.5 + frame.startRipple * 1.8)
				circleAt node.screenX, node.screenY, radius

	if (frame.scintAlpha or 0) > 0
		surface.SetDrawColor 255, 255, 255,
			math.Round math.Clamp(frame.scintAlpha, 0, 1) * 255
		radius = barWidth * (0.25 + (frame.scintProgress or 0) * 2.5)
		thickness = math.max 1, barWidth * 0.12
		seen = {}
		if frame.scintStarts
			state = @__renderTraceState or @GetTraceRenderState!
			for route in *(state and state.routes or {})
				if not seen[route.startId]
					seen[route.startId] = true
					if node = @__pathFinder.topology.nodes[route.startId]
						drawRingAt node.screenX, node.screenY, radius, thickness
			for nodeId in *@__pathFinder.topology.starts
				continue if seen[nodeId]
				if node = @__pathFinder.topology.nodes[nodeId]
					drawRingAt node.screenX, node.screenY, radius, thickness
		unless frame.scintStarts
			for node in *@__pathFinder.topology.nodes
				if node.exit and not seen[node.id]
					drawRingAt node.screenX, node.screenY, radius, thickness

-----------------------------
-- Paints the canvas. Duh. --
-----------------------------
CANVAS.Paint = (w, h) =>
	return if not @CanRender!

	surface.SetMaterial @__rtAlloc.rt.material

	-- Determine whether the screen should be tinted black
	-- based on the power state value.
	if @__powerState ~= nil and @__powerStateBuffer
		color = math.Round 255 * math.EaseInOut @__powerStateBuffer,
			0.25, 0.25

		surface.SetDrawColor color, color, color

	else
		surface.SetDrawColor 255, 255, 255

	surface.DrawTexturedRect 0, 0, w, h

--------------------------------------------------
-- Renders the RT. Decoupled from Paint so that --
-- HDR has no effect on this.                   --
--------------------------------------------------
CANVAS.RenderRT = =>
	return if not @CanRender!

	if @__rtDirty
		w = Moonpanel.Canvas.Resolution
		h = w

		@__rtDirty = false

		-- Draw black square if no data.
		if not @__data or
				not @__clientData or
				not @__clientData.visibleNodes or
				not @__clientData.paths
				clearRT @__rtAlloc.rt.texture
				return

		hasPresentation = @__presentation and
			(@__presentation\isActive! or @__presentation\isFocusHintActive!)
		if hasPresentation
			@__renderTraceState = @GetTraceRenderState!
			-- Always render traces fully opaque into the auxiliary target.
			-- Presentation alpha belongs to the whole trace image, never to
			-- individual segments.
			auxrt = Moonpanel.Canvas\GetAuxiliaryRT!
			with render.PushRenderTarget auxrt.texture
				cam.Start2D!
				render.Clear 0, 0, 0, 0, true, false
				@PaintTrace w, h
				cam.End2D!

			render.PopRenderTarget!

		-- Draw the rest of the panel in a dedicated rendertarget.
		-- "How do we get one?", you might ask. The answer is...
		-- out of this function scope.
		with render.PushRenderTarget @__rtAlloc.rt.texture
			cam.Start2D!
			render.Clear 0, 0, 0, 0, true, false

			surface.SetDrawColor @GetColors!.Background
			surface.DrawRect 0, 0, w, h

			barWidth = @GetBarWidth!

			surface.SetDrawColor @GetColors!.Grid

			-- Draw visible paths.
			draw.NoTexture!
			for path in *@__clientData.paths
				-- they see me rounding, they hating
				surface.DrawTexturedRectRotated math.Round(path.screenX), math.Round(path.screenY),
					math.Round(path.distance), math.Round(barWidth), math.Round(path.angle)
				if @IsContinuous! and not @GetEditorGeometryVisible! and
						math.abs(path.screenX) < barWidth and math.abs(path.angle) == 90
					surface.DrawTexturedRectRotated Moonpanel.Canvas.Resolution,
						math.Round(path.screenY), math.Round(path.distance),
						math.Round(barWidth), math.Round(path.angle)

			-- Draw all visible nodes.
			-- Clickable nodes are nearly twice as big.
			for node in *@__clientData.visibleNodes
				size = node.clickable and barWidth * 2.5 or barWidth
				circleAt node.screenX, node.screenY, size / 2
				if @IsContinuous! and not @GetEditorGeometryVisible! and
						math.abs(node.screenX) < size * 0.5
					circleAt Moonpanel.Canvas.Resolution, node.screenY, size / 2

			for renderable in pairs @__clientData.renderablesBelowTrace
				continue if @IsHiddenContinuousSocket renderable\GetSocket!
				renderable\RenderBelowTrace!

			if hasPresentation
				alpha = @__visualFrame and @__visualFrame.traceAlpha or 1
				if alpha > 0
					auxrt = Moonpanel.Canvas\GetAuxiliaryRT!
					surface.SetMaterial auxrt.material
					surface.SetDrawColor 255, 255, 255, math.Round(alpha * 255)
					surface.DrawTexturedRect 0, 0, w, h

			for renderable in pairs @__clientData.renderables
				continue if @IsHiddenContinuousSocket renderable\GetSocket!
				renderable\Render!

			for renderable in pairs @__clientData.renderablesOverTrace
				continue if @IsHiddenContinuousSocket renderable\GetSocket!
				renderable\RenderOverlay!

			@PaintPresentationEffects! unless @__terminalSnapshotRestored

			vignette = @GetColors!.Vignette
			surface.SetMaterial MAT_VIGNETTE
			surface.SetDrawColor vignette.r, vignette.g, vignette.b, vignette.a or 80
			surface.DrawTexturedRect 0, 0, w, h

			cam.End2D!

		render.PopRenderTarget!
		@__renderTraceState = nil

CANVAS.AddRenderable = (entity) =>
	if entity.RenderBelowTrace
		@__clientData.renderablesBelowTrace[entity] = true
	if entity.Render
		@__clientData.renderables[entity] = true
	if entity.RenderOverlay
		@__clientData.renderablesOverTrace[entity] = true

CANVAS.RemoveRenderable = (entity) =>
	@__clientData.renderables[entity] = nil
	@__clientData.renderablesBelowTrace[entity] = nil
	@__clientData.renderablesOverTrace[entity] = nil

CANVAS.SetPowerState = (state) =>
	@__powerState = state
	if not @__powerStateBuffer
		@__powerStateBuffer = state and 1 or 0
	if state
		@SetLoop "PresenceLoop"
	else
		@StopSound "PresenceLoop"
		@ResetPresentation "power-loss" unless @GetSolvedState!

CANVAS.SetFocusHintOverride = (enabled) =>
	enabled = enabled == true
	return false if @__focusHintOverride == enabled
	@__focusHintOverride = enabled
	if @__presentation and @__presentation\setFocusHint enabled, CurTime!
		@__visualFrame = nil
		@__rtDirty = true
	true

CANVAS.IsLocalFocusHintTarget = =>
	return false unless CLIENT
	return true if @__focusHintOverride
	return false unless IsValid @__worldEntity
	getLocalFocusTarget! == @__worldEntity

CANVAS.ImportNetworkState = (panel, data = {}) =>
	dataRevision = math.max 0, math.floor tonumber(data.dataRevision) or 0
	dataChanged = @__dataRevision ~= nil and @__dataRevision ~= dataRevision
	@__dataRevision = dataRevision
	if dataChanged and Moonpanel.Net.TraceSessions
		if session = Moonpanel.Net.TraceSessions[panel]
			if session.controller == LocalPlayer! and Moonpanel.EndPillarOrbit
				Moonpanel\EndPillarOrbit LocalPlayer!
			Moonpanel.Net.TraceSessions[panel] = nil
			panel\SetController game.GetWorld! if IsValid panel
			gui.EnableScreenClicker true if Moonpanel\IsFocused!
	@ImportData data.panelData
	if session = Moonpanel.Net.TraceSessions and Moonpanel.Net.TraceSessions[panel]
		definition = @GetRuleDefinition!
		pathfinder = @GetPathFinder!
		if not pathfinder or session.revision ~= pathfinder.topology.revision or
				not definition or session.ruleRevision ~= definition.ruleRevision
			Moonpanel.Net.TraceSessions[panel] = nil
	@ImportPlayData data.playData
	@SetSolvedState data.solved == true
	visualResult = data.visualResult
	definition = @GetRuleDefinition!
	pathfinder = @GetPathFinder!
	revisionMatches = visualResult and pathfinder and definition and
		visualResult.revision == pathfinder.topology.revision and
		visualResult.ruleRevision == definition.ruleRevision
	restoredSolvedSnapshot = data.solved == true and visualResult and
		istable(visualResult.snapshot) and pathfinder and definition
	if revisionMatches or restoredSolvedSnapshot
		if restoredSolvedSnapshot and not revisionMatches
			visualResult = table.Copy visualResult
			visualResult.revision = pathfinder.topology.revision
			visualResult.ruleRevision = definition.ruleRevision
		@__lastVisualSerial = visualResult.eventSerial or @__lastVisualSerial
		@BeginPresentation {
			sessionId: visualResult.sessionId
			revision: visualResult.revision
		}, true
		@ApplyVisualResult visualResult, data.visualElapsed or 0, true
	elseif data.solved ~= true
		@ResetPresentation "network-state"
	powered = if data.powered ~= nil
		data.powered == true
	elseif IsValid panel
		panel\GetPowered!
	else
		false
	@SetPowerState powered

CANVAS.GetPowerStateBuffer = => @__powerStateBuffer or 1
