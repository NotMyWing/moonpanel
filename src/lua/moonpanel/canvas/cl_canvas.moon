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
		cosAngle, sinAngle = math.cos(angle), math.sin(angle)
		ringOuter[i + 1].x = x + cosAngle * radius
		ringOuter[i + 1].y = y + sinAngle * radius
		ringInner[i + 1].x = x + cosAngle * innerRadius
		ringInner[i + 1].y = y + sinAngle * innerRadius
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

	controlled = Moonpanel\GetPredictedControl!
	if IsValid(controlled) and controlled.Moonpanel
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

drawToRT = (rt, callback, context) ->
	render.PushRenderTarget rt
	cam.Start2D!
	ok, err = xpcall (-> callback context), debug.traceback
	cam.End2D!
	render.PopRenderTarget!
	error err, 0 unless ok

clearRT = (rt) ->
	drawToRT rt, -> render.Clear 0, 0, 0, 255, true, false

drawLine = (x1, y1, x2, y2, width) ->
	dX = x2 - x1
	dY = y2 - y1
	if (math.abs dY) < 0.001
		surface.DrawRect math.floor(math.min x1, x2),
			math.floor(y1 - width * 0.5), math.max(1, math.ceil math.abs dX),
			math.max(1, math.ceil width)
		return
	if (math.abs dX) < 0.001
		surface.DrawRect math.floor(x1 - width * 0.5), math.floor(math.min y1, y2),
			math.max(1, math.ceil width), math.max(1, math.ceil math.abs dY)
		return
	length = math.sqrt dX * dX + dY * dY
	surface.DrawTexturedRectRotated math.Round((x1 + x2) * 0.5),
		math.Round((y1 + y2) * 0.5), length, width,
		math.deg(math.pi / 2 + math.atan2 dX, dY)

CANVAS.DeallocateRT = =>
	return unless @__rtAlloc and Moonpanel.Canvas\IsRTAllocated @__rtAlloc
	Moonpanel.Canvas\DeallocateRT @__rtAlloc
	true

CANVAS.CanRender = => @__rtAlloc and Moonpanel.Canvas\IsRTAllocated @__rtAlloc

CANVAS.AllocateRT = (forceEvict = false) =>
	return if @__rtAlloc and Moonpanel.Canvas\IsRTAllocated @__rtAlloc

	@__rtAlloc = Moonpanel.Canvas\AllocateRT forceEvict, @

	if @__rtAlloc
		clearRT @__rtAlloc.rt.texture
		@__rtDirty = true

		true

CANVAS.BakeImportedColors = =>
	@__clientData = {
		renderables: {}
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

	barWidth = @GetBarWidth!
	@__rtDirty = true

	@__clientData.paths = {}
	@__clientData.cells = {}
	seen = {}
	meta = @__data.Meta or {}
	width, height = tonumber(meta.Width) or 1, tonumber(meta.Height) or 1
	barLength = @GetBarLength!
	verticalLength = @GetVerticalBarLength!
	resolution = Moonpanel.Canvas.Resolution
	for y = 1, height
		for x = 1, width
			entityIndex = (y * 2 - 1) * (width * 2 + 1) + x * 2
			entity = @__data.Entities and @__data.Entities[entityIndex]
			continue if entity and entity.Type == "Invisible"
			table.insert @__clientData.cells, {
				x: resolution * 0.5 + (x - 0.5 - width * 0.5) * barLength - (barLength - barWidth) * 0.5
				y: resolution * 0.5 + (y - 0.5 - height * 0.5) * verticalLength - (verticalLength - barWidth) * 0.5
				width: math.max 1, barLength - barWidth
				height: math.max 1, verticalLength - barWidth
			}

	-- Extract paths and calculate distances.
	for nodeA in *@__nodes
		continue if seen[nodeA]
		seen[nodeA] = true
		for nodeB in *nodeA.neighbors
			-- The duplicate right seam has no vertical geometry. Horizontal
			-- routes still reach the edge and remain the authored wrap paths.
			continue if @IsHiddenContinuousSocket(nodeA.socket) and
				@IsHiddenContinuousSocket(nodeB.socket)
			if not seen[nodeB]
				dx = nodeB.screenX - nodeA.screenX
				dy = nodeB.screenY - nodeA.screenY
				angle = math.atan2 dy, dx
				rawDistance = math.sqrt dx * dx + dy * dy
				renderDistance = math.ceil rawDistance
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

	-- A node needs a visible dot only at a branch, endpoint, gap, or start.
	@__clientData.visibleNodes = {}
	for node in *@__nodes
		continue if node.break or node.invisible or
			@IsHiddenContinuousSocket node.socket
		neighborCount = table.Count node.neighbors
		if node.clickable or neighborCount > 0 and neighborCount < 4
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
		frame = table.Copy frame
		frame.widthScale, frame.exitPulse, frame.traceAlpha = 1, 0, 1
		frame.traceError, frame.flash = 0, 0
		frame.completion = @__playData and @__playData.visualResult and
			@__playData.visualResult.success and 1 or 0
	widthModifier = frame.widthScale or 1
	regularRadius = widthModifier * @GetBarWidth! *
		(w / Moonpanel.Canvas.Resolution)
	firstNodeRadius = math.Round 0.5 * regularRadius * 2.5
	regularRadius = math.Round 0.5 * regularRadius

	colors = @GetColors!
	topology = @__pathFinder.topology
	continuous = @IsContinuous!
	periodPixels = continuous and @GetBarLength! * @__data.Meta.Width or 0
	drawRouteSegment = (edge, fraction) ->
		fromNode = topology.nodes[edge.fromId]
		toNode = topology.nodes[edge.toId]
		return unless fromNode and toNode
		startX = edge.fromScreenX or fromNode.screenX
		startY = edge.fromScreenY or fromNode.screenY
		endX = edge.toScreenX or toNode.screenX
		endY = edge.toScreenY or toNode.screenY
		headX = startX + (endX - startX) * fraction
		headY = startY + (endY - startY) * fraction
		width = regularRadius * 2
		surface.SetMaterial MAT_TRACE
		shifts = if continuous then { -periodPixels, 0, periodPixels } else { 0 }
		for shift in *shifts
			x1, x2 = startX + shift, headX + shift
			continue if math.max(x1, x2) < -width or math.min(x1, x2) > w + width
			drawLine x1, startY, x2, headY, width
			circleAt x2, headY, width * 0.5
	for stackId, route in ipairs state.routes
		branchStyle = frame.branchStyles and frame.branchStyles[stackId]
		continue if branchStyle and branchStyle.visible == false

		traceColor = branchStyle and branchStyle.color or
			colors.Trace[stackId] or colors.Trace[1]
		blend = (amount, target) ->
			traceColor = Color lerpColor math.min(1, amount), traceColor, target
		if (frame.exitPulse or 0) > 0
			blend frame.exitPulse,
				@__clientData.extraColors.blink[stackId] or
				@__clientData.extraColors.blink[1]
		if (frame.traceError or 0) > 0
			blend frame.traceError, colors.Error
		if (frame.completion or 0) > 0
			blend frame.completion,
				branchStyle and branchStyle.completionColor or
				colors.EndTrace[stackId] or colors.EndTrace[1]
		-- Completion should transition directly from the active trace color to
		-- the terminal color; suppress the generic white success flash while the
		-- terminal blend is active.
		if (frame.flash or 0) > 0 and (frame.completion or 0) <= 0
			blend frame.flash * 0.65, Color 255, 255, 255
		surface.SetDrawColor traceColor.r, traceColor.g, traceColor.b, 255

		first = topology.nodes[route.startId]
		continue unless first
		circleAt first.screenX, first.screenY, firstNodeRadius
		if continuous and not @GetEditorGeometryVisible! and
				math.abs(first.screenX) < firstNodeRadius
			circleAt first.screenX + periodPixels, first.screenY, firstNodeRadius

		for segment in *route.segments
			edge = topology\getEdge segment.fromId, segment.toId
			continue unless edge and segment.visibleLength > 0
			fraction = segment.fullLength > 0 and
				math.min(1, segment.visibleLength / segment.fullLength) or 0
			drawRouteSegment edge, fraction

CANVAS.GetEntityVisualStyle = (socket) =>
	return unless socket and @__visualFrame and @__visualFrame.entityStyles
	index = socket\GetDataIndex!
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
	mix = (target, amount) ->
		r += (target.r - r) * amount
		g += (target.g - g) * amount
		b += (target.b - b) * amount
	if style.tint
		amount = math.Clamp style.tintAmount or 1, 0, 1
		mix style.tint, amount
	error = math.Clamp style.error or 0, 0, 1
	if error > 0
		target = Color 255, 36, 36
		if r > 150 and r > g * 1.45 and r > b * 1.45
			target = Color 25, 8, 8
		mix target, error

	erased = math.Clamp style.erased or 0, 0, 1
	if erased > 0
		gray = r * 0.299 + g * 0.587 + b * 0.114
		r += (gray - r) * erased
		g += (gray - g) * erased
		b += (gray - b) * erased

	glow = math.Clamp style.glow or 0, 0, 1
	mix Color(255, 255, 255), glow
	a *= math.Clamp style.alpha or 1, 0, 1
	math.Round(r), math.Round(g), math.Round(b), math.Round(a)

drawRouteStarts = (topology, routes, radius, colors, branchStyles, alpha) ->
	seen = {}
	for routeIndex, route in ipairs routes
		continue if seen[route.startId]
		seen[route.startId] = true
		if node = topology.nodes[route.startId]
			if colors
				color = branchStyles and branchStyles[routeIndex] and
					branchStyles[routeIndex].color or colors.Trace[routeIndex] or colors.Trace[1]
				surface.SetDrawColor color.r, color.g, color.b, alpha
			circleAt node.screenX, node.screenY, radius
	seen

CANVAS.PaintPresentationEffects = =>
	frame = @__visualFrame
	return unless frame

	ripple = frame.startRipple or 0
	scintAlpha = math.Clamp frame.scintAlpha or 0, 0, 1
	return if ripple <= 0 and scintAlpha <= 0
	return unless @__pathFinder

	topology = @__pathFinder.topology
	barWidth = @GetBarWidth!
	local routes
	colors = @GetColors! if ripple > 0
	if ripple > 0 or frame.scintStarts
		state = @__renderTraceState or @GetTraceRenderState!
		routes = state and state.routes or {}

	if ripple > 0
		trace = colors.Trace[1] or colors.Trace[2]
		surface.SetDrawColor trace.r, trace.g, trace.b, math.Round(ripple * 42)
		drawRouteStarts topology, routes, barWidth * (1.5 + ripple * 1.8),
			colors, frame.branchStyles, math.Round(ripple * 42)
	return if scintAlpha <= 0

	surface.SetDrawColor 255, 255, 255,
		math.Round scintAlpha * 255 * 0.5
	radius = barWidth * (0.25 + (frame.scintProgress or 0) * 2.5)
	thickness = math.max 1, barWidth * 0.12
	if frame.scintStarts
		seen = drawRouteStarts topology, routes, radius
		for nodeId in *topology.starts
			continue if seen[nodeId]
			if node = topology.nodes[nodeId]
				drawRingAt node.screenX, node.screenY, radius, thickness
	else
		for node in *topology.nodes
			if node.exit
				drawRingAt node.screenX, node.screenY, radius, thickness

-----------------------------
-- Paints the canvas. Duh. --
-----------------------------
CANVAS.Paint = (w, h) =>
	return if not @CanRender!

	surface.SetMaterial @__rtAlloc.rt.material

	color = if @__powerState ~= nil and @__powerStateBuffer
		math.Round 255 * math.EaseInOut @__powerStateBuffer, 0.25, 0.25
	else 255
	surface.SetDrawColor color, color, color

	surface.DrawTexturedRect 0, 0, w, h

--------------------------------------------------
-- Renders the RT. Decoupled from Paint so that --
-- HDR has no effect on this.                   --
--------------------------------------------------
CANVAS.RenderRT = =>
	return if not @CanRender!

	now = RealTime!
	@__rtRateStartedAt or= now
	elapsed = now - @__rtRateStartedAt
	if elapsed >= 1
		@__rtDrawRate = (@__rtDrawCount or 0) / elapsed
		@__rtFrameRate = (@__rtFrameCount or 0) / elapsed
		@__rtDrawCount, @__rtFrameCount = 0, 0
		@__rtRateStartedAt = now
	@__rtFrameCount = (@__rtFrameCount or 0) + 1
	@__rtWasDirty = @__rtDirty == true
	if @__rtDirty
		@__rtDrawCount = (@__rtDrawCount or 0) + 1
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
			drawToRT auxrt.texture, (=>
				render.Clear 0, 0, 0, 0, true, false
				@PaintTrace w, h), @

		-- Draw the rest of the panel in a dedicated rendertarget.
		-- "How do we get one?", you might ask. The answer is...
		-- out of this function scope.
		drawToRT @__rtAlloc.rt.texture, (=>
			render.Clear 0, 0, 0, 0, true, false
			colors = @GetColors!
			visible = (item) -> not @IsHiddenContinuousSocket item\GetSocket!
			renderables = @__clientData.renderables

			surface.SetDrawColor colors.Background
			surface.DrawRect 0, 0, w, h
			if colors.Cell
				surface.SetDrawColor colors.Cell
				for cell in *@__clientData.cells
					surface.DrawRect cell.x, cell.y, cell.width, cell.height

			barWidth = @GetBarWidth!
			wrap = @IsContinuous! and not @GetEditorGeometryVisible!

			surface.SetDrawColor colors.Grid

			-- Draw visible paths.
			draw.NoTexture!
			for path in *@__clientData.paths
				-- they see me rounding, they hating
				surface.DrawTexturedRectRotated math.Round(path.screenX), math.Round(path.screenY),
					math.Round(path.distance), math.Round(barWidth), math.Round(path.angle)
				if wrap and
						math.abs(path.screenX) < barWidth and math.abs(path.angle) == 90
					surface.DrawTexturedRectRotated Moonpanel.Canvas.Resolution,
						math.Round(path.screenY), math.Round(path.distance),
						math.Round(barWidth), math.Round(path.angle)

			-- Draw all visible nodes.
			-- Clickable nodes are nearly twice as big.
			for node in *@__clientData.visibleNodes
				size = node.clickable and barWidth * 2.5 or barWidth
				circleAt node.screenX, node.screenY, size / 2
				if wrap and
						math.abs(node.screenX) < size * 0.5
					circleAt Moonpanel.Canvas.Resolution, node.screenY, size / 2

			for renderable, layers in pairs renderables
				continue unless visible renderable
				renderable\RenderBelowTrace! if layers.below

			if hasPresentation
				alpha = @__visualFrame and @__visualFrame.traceAlpha or 1
				if alpha > 0
					auxrt = Moonpanel.Canvas\GetAuxiliaryRT!
					surface.SetMaterial auxrt.material
					surface.SetDrawColor 255, 255, 255, math.Round(alpha * 255)
					surface.DrawTexturedRect 0, 0, w, h

			for renderable, layers in pairs renderables
				continue unless visible renderable
				renderable\Render! if layers.main

			for renderable, layers in pairs renderables
				continue unless visible renderable
				renderable\RenderOverlay! if layers.over

			@PaintPresentationEffects! unless @__terminalSnapshotRestored

			vignette = colors.Vignette
			surface.SetMaterial MAT_VIGNETTE
			surface.SetDrawColor vignette.r, vignette.g, vignette.b, vignette.a or 80
			surface.DrawTexturedRect 0, 0, w, h), @
		@__renderTraceState = nil

CANVAS.AddRenderable = (entity) =>
	layers = @__clientData.renderables[entity] or {}
	layers.below = entity.RenderBelowTrace
	layers.main = entity.Render
	layers.over = entity.RenderOverlay
	@__clientData.renderables[entity] = layers

CANVAS.RemoveRenderable = (entity) =>
	@__clientData.renderables[entity] = nil

CANVAS.SetPowerState = (state) =>
	@__powerState = state
	@__powerStateBuffer or= state and 1 or 0
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
		@__visualFrame, @__rtDirty = nil, true
	true

CANVAS.IsLocalFocusHintTarget = =>
	return false unless CLIENT
	return true if @__focusHintOverride
	return false unless IsValid @__worldEntity
	getLocalFocusTarget! == @__worldEntity

CANVAS.ImportTraceSession = (controller, sessionId, revision, snapshot,
	lastSequence, lateJoin = false, observer = false, importedPlay = {},
	startPresentation = true) =>
	return false unless @__pathFinder and snapshot
	if observer
		@SetObserverFollower nil
		return false unless @ApplyObserverSnapshot snapshot, lastSequence
	else
		return false unless @RestoreTraceSnapshot snapshot
		@SetObserverFollower nil
	playData = table.Copy importedPlay
	playData.startTime = CurTime! unless lateJoin and playData.startTime
	playData.endTime = nil unless lateJoin
	playData.controller = controller
	playData.touchingExit = snapshot.touchingExit == true
	playData.sessionId = sessionId
	@SetPlayData playData
	if startPresentation
		@BeginPresentation {sessionId: sessionId, revision: revision}, lateJoin
	@SetPresentationExit @IsExitPath!, lateJoin
	true

CANVAS.ImportNetworkState = (panel, data = {}) =>
	resetSerial = math.max 0, math.floor tonumber(data.resetSerial) or 0
	resetRequested = resetSerial > (@__resetPresentationSerial or 0) or
		resetSerial == (@__resetPresentationSerial or 0) and resetSerial > 0
	resetSnapshot = data.resetSnapshot
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
	pathfinder = @__pathFinder
	if session = Moonpanel.Net.TraceSessions and Moonpanel.Net.TraceSessions[panel]
		if not pathfinder or session.revision ~= @GetTraceRevision! or
				session.ruleRevision ~= @GetRuleRevision!
			Moonpanel.Net.TraceSessions[panel] = nil
	@ImportPlayData data.playData
	@SetSolvedState data.solved == true
	visualResult = data.visualResult
	ruleRevision = @GetRuleRevision!
	revisionMatches = visualResult and pathfinder and ruleRevision and
		visualResult.revision == @GetTraceRevision! and
		visualResult.ruleRevision == ruleRevision
	restoredSolvedSnapshot = data.solved == true and visualResult and
		istable(visualResult.snapshot) and pathfinder and ruleRevision
	if revisionMatches or restoredSolvedSnapshot
		if restoredSolvedSnapshot and not revisionMatches
			visualResult = table.Copy visualResult
			visualResult.revision = @GetTraceRevision!
			visualResult.ruleRevision = ruleRevision
		@__lastVisualSerial = visualResult.eventSerial or @__lastVisualSerial
		@BeginPresentation {
			sessionId: visualResult.sessionId
			revision: visualResult.revision
		}, true
		@ApplyVisualResult visualResult, data.visualElapsed or 0, true,
			data.solved == true
	elseif data.solved ~= true and not resetRequested
		@ResetPresentation "network-state"
	powered = if data.powered ~= nil
		data.powered == true
	elseif IsValid panel
		panel\GetPowered!
	else
		false
	@SetPowerState powered
	@BeginResetPresentation resetSnapshot, resetSerial, true if resetRequested and
		resetSnapshot and @BeginResetPresentation
