Moonpanel.Debug or= {}
DEBUG = Moonpanel.Debug

enabled = CreateClientConVar "moonpanel_debug", "0", true, false,
	"Draw Moonpanel runtime diagnostics and occlusion rays"
rayLifetime = CreateClientConVar "moonpanel_debug_ray_lifetime", "0.2", true, false,
	"Lifetime of Moonpanel occlusion debug rays", 0.02, 2
maxDistance = CreateClientConVar "moonpanel_debug_distance", "4096", true, false,
	"Maximum distance for Moonpanel 3D diagnostics", 128, 16384

surface.CreateFont "MoonpanelDebug3D",
	font: "DejaVu Sans Mono"
	extended: false
	size: 18
	weight: 600

WHITE = Color 235, 243, 250
DIM = Color 155, 174, 190
GOOD = Color 90, 235, 145
WARN = Color 255, 191, 73
BAD = Color 255, 77, 90
CYAN = Color 75, 205, 255
GREEN = Color 85, 235, 130
YELLOW = Color 255, 215, 80
ORANGE = Color 255, 133, 55

phaseNames = {
	[0]: "Idle"
	[1]: "Aiming"
	[2]: "Tracing"
	[3]: "Evaluating"
	[4]: "Feedback"
}

DEBUG.Occlusion = DEBUG.Occlusion or setmetatable {}, { __mode: "k" }
DEBUG.Rays = DEBUG.Rays or {}
MAX_RAYS = 4096

DEBUG.IsEnabled = => enabled\GetBool!

DEBUG.BeginOcclusion = (panel, edge, oldProgress, candidateProgress) =>
	return unless @IsEnabled! and IsValid panel
	@Occlusion[panel] = {
		at: RealTime!
		edge: edge
		oldProgress: oldProgress
		candidateProgress: candidateProgress
		total: 0
		clear: 0
		blocked: 0
		start: 0
		fanout: 0
		refine: 0
	}

DEBUG.RecordOcclusionRay = (panel, stage, index, startPos, endPos, trace) =>
	return unless @IsEnabled! and IsValid(panel) and startPos and endPos
	state = @Occlusion[panel]
	unless state
		state = { at: RealTime!, total: 0, clear: 0, blocked: 0,
			start: 0, fanout: 0, refine: 0 }
		@Occlusion[panel] = state

	blocked = trace and (trace.StartSolid or trace.AllSolid or
		trace.Hit and (trace.Fraction or 0) < 1) or false
	state.total += 1
	state[stage] = (state[stage] or 0) + 1
	if blocked
		state.blocked += 1
		state.lastHit = Vector trace.HitPos.x, trace.HitPos.y, trace.HitPos.z
		state.lastEntity = trace.Entity
		state.lastFraction = trace.Fraction
	else
		state.clear += 1

	color = if blocked
		BAD
	elseif stage == "start"
		CYAN
	elseif stage == "refine"
		YELLOW
	else
		GREEN
	table.insert @Rays, {
		:startPos
		:endPos
		:color
		hitPos: blocked and Vector(trace.HitPos.x, trace.HitPos.y,
			trace.HitPos.z) or nil
		expiresAt: RealTime! + rayLifetime\GetFloat!
	}
	while #@Rays > MAX_RAYS
		table.remove @Rays, 1

DEBUG.EndOcclusion = (panel, fraction) =>
	return unless @IsEnabled! and IsValid panel
	state = @Occlusion[panel]
	return unless state
	state.result = fraction
	state.at = RealTime!

DEBUG.RecordPillarHullRay = (panel, startPos, endPos, trace) =>
	return unless @IsEnabled! and IsValid(panel) and startPos and endPos
	blocked = trace and (trace.StartSolid or trace.AllSolid or
		trace.Hit and (trace.Fraction or 0) < 1) or false
	table.insert @Rays, {
		:startPos
		:endPos
		color: blocked and BAD or CYAN
		hitPos: blocked and trace.HitPos and Vector(trace.HitPos.x,
			trace.HitPos.y, trace.HitPos.z) or nil
		hitNormal: blocked and trace.HitNormal and Vector(trace.HitNormal.x,
			trace.HitNormal.y, trace.HitNormal.z) or nil
		expiresAt: RealTime! + rayLifetime\GetFloat!
	}
	while #@Rays > MAX_RAYS
		table.remove @Rays, 1

boolText = (value) -> value and "yes" or "no"
numberText = (value, digits = 2) ->
	return "-" unless isnumber value
	string.format("%." .. tostring(digits) .. "f", value)

routeText = (stack) ->
	return "-" unless stack and #stack > 0
	values = {}
	limit = math.min #stack, 12
	for index = 1, limit
		table.insert values, tostring stack[index]
	table.insert values, "…" if #stack > limit
	table.concat values, ">"

pointText = (point) ->
	return "-" unless point
	"#{numberText(point.x, 1)},#{numberText(point.y, 1)}"

historyText = (history) ->
	return "-" unless history and #history > 0
	values = {}
	for sample in *history
		table.insert values, "#{sample[1]},#{sample[2]}"
	table.concat values, " | "

controllerText = (controller) ->
	return "world" if controller == game.GetWorld!
	return "none" unless IsValid controller
	if controller\IsPlayer!
		return "#{controller\Nick!} [#{controller\EntIndex!}]"
	tostring controller

panelLines = (panel) ->
	canvas = panel\GetCanvas!
	data = canvas and canvas\GetData!
	debug = canvas and canvas\GetDebugState!
	trace = debug and debug.trace
	rule = debug and debug.rule
	topology = trace and trace.topology
	session = Moonpanel.Net.TraceSessions and Moonpanel.Net.TraceSessions[panel]
	pendingSync = Moonpanel.Net.PendingPanelDataRequests and
		Moonpanel.Net.PendingPanelDataRequests[panel]
	follower = debug and debug.follower
	geometry = debug and debug.geometry
	rtAllocated = canvas and canvas\CanRender! or false
	meta = data and data.Meta or {}

	lines = {
		{ "MOONPANEL ##{panel\EntIndex!}", CYAN }
		{ "model  #{panel\GetModel! or "-"}", DIM }
		{ "distance #{numberText(LocalPlayer!\EyePos!\Distance(panel\WorldSpaceCenter!), 1)}u", DIM }
		{ "sync #{boolText(data ~= nil)}  powered #{boolText(panel\GetPowered!)}  local-power #{boolText(debug and debug.power)}", data and GOOD or BAD }
		{ "RT allocated #{boolText(rtAllocated)}  drawing #{boolText(panel\IsRendering!)}  dirty #{boolText(debug and debug.dirty)}", rtAllocated and GOOD or WARN }
		{ "DPS #{numberText(debug and debug.drawRate, 1)} / FPS #{numberText(debug and debug.frameRate, 1)}", WHITE }
		{ "grid #{meta.Width or "-"}x#{meta.Height or "-"}  symmetry #{meta.Symmetry or 0}  entities #{data and #(data.Entities or {}) or 0}", WHITE }
		{ "geometry bar #{numberText(geometry and geometry.barWidth)} / #{numberText(geometry and geometry.barLength)}  margin #{numberText(geometry and geometry.margin)}", WHITE }
	}

	if topology
		table.insert lines, { "topology rev #{topology.revision}  nodes #{topology.nodes}  edges #{topology.edges}  starts #{topology.starts}  exits #{topology.exits}  gaps #{topology.gaps}", WHITE }
	else
		table.insert lines, { "topology unavailable", BAD }

	if rule
		table.insert lines, { "rules rev #{rule.revision or 0}  clues #{rule.clues or 0}", WHITE }
	else
		table.insert lines, { "rules unavailable", BAD }

	if trace
		phase = phaseNames[trace.phase] or tostring(trace.phase)
		table.insert lines, { "trace #{phase}  hash #{trace.hash}  submit #{boolText(trace.canSubmit)}  exit #{boolText(trace.touchingExit)}", WHITE }
		table.insert lines, { "route P #{routeText(trace.stacks and trace.stacks[1])}", DIM }
		table.insert lines, { "route S #{routeText(trace.stacks and trace.stacks[2])}", DIM }
		table.insert lines, { "heads P #{pointText(trace.cursors and trace.cursors[1])}  S #{pointText(trace.cursors and trace.cursors[2])}", DIM }
		table.insert lines, { "intent #{historyText(trace.history)}  constraints #{routeText(trace.constraints)}", DIM }
		if active = trace.active
			primary = active.primary
			secondary = active.secondary
			table.insert lines, { "active P #{primary and primary.fromId or "-"}->#{primary and primary.toId or "-"} #{primary and primary.kind or "-"}  q #{active.progressQ}/#{primary and primary.lengthQ or "-"}  max #{active.maxProgressQ or "-"}", WARN }
			table.insert lines, { "active S #{secondary and secondary.fromId or "-"}->#{secondary and secondary.toId or "-"} #{secondary and secondary.kind or "-"}  retract #{boolText(active.retracting)}", WARN }
		else
			table.insert lines, { "active none", DIM }

	if panel.MoonpanelPillar
		orbit = Moonpanel.PillarController and
			Moonpanel.PillarController\GetState LocalPlayer!
		if orbit and orbit.panel == panel and trace
			head = trace.cursors and trace.cursors[1]
			playerAngle = panel\GetPillarAngle LocalPlayer!\GetPos!
			headAngle = head and Moonpanel.Canvas.PillarTraceAngle(head.x) or 0
			rawError = head and Moonpanel.Canvas.PillarAlignmentError(
				head.x, playerAngle) or 0
			couplingError = Moonpanel.Canvas.NormalizeAngleDelta headAngle - playerAngle
			table.insert lines, { "pillar angle player #{numberText(playerAngle, 3)} head #{numberText(headAngle, 3)} radial #{numberText(rawError, 4)} drift #{numberText(couplingError, 4)}", math.abs(couplingError) < 0.1 and GOOD or WARN }
			table.insert lines, { "pillar radius #{numberText(LocalPlayer!\GetPos!\Distance(panel\GetPillarAxisPoint(LocalPlayer!\GetPos!)), 3)} / #{numberText(orbit.radius, 3)}", DIM }
			if hullTrace = orbit.lastHullTrace
				table.insert lines, { "ghost hull segment #{hullTrace.segment or 0}  hit #{boolText(hullTrace.hit)}  start-solid #{boolText(hullTrace.startSolid)}  fraction #{numberText(hullTrace.fraction, 3)}", hullTrace.hit and WARN or DIM }
			if motion = orbit.debug
				table.insert lines, { "pillar cmd #{motion.commandNumber or 0} raw #{numberText(motion.rawX, 0)}/#{numberText(motion.rawY, 0)} sample #{motion.xQ or 0}/#{motion.yQ or 0} axes #{motion.motionAxis or "-"}/#{motion.sampleAxis or "-"}", WHITE }
				table.insert lines, { "pillar clamp #{motion.clampReason or "none"} limits puzzle #{motion.puzzleLimit or 0} lead #{motion.leadLimit or 0} world #{motion.worldLimit or 0} signed lead #{numberText(motion.signedLead, 3)}", motion.clampReason == "none" and GOOD or WARN }
				table.insert lines, { "pillar safe #{motion.lastSafeQ or "-"} blocked #{motion.firstBlockedQ or "-"} speed #{numberText(motion.speedLimit, 1)} walk #{numberText(motion.forwardMove, 2)}/#{numberText(motion.sideMove, 2)}", DIM }

	controller = panel\GetController!
	table.insert lines, { "controller #{controllerText controller}", session and WARN or DIM }
	if session
		role = session.controller == LocalPlayer! and "controller" or "observer"
		table.insert lines, { "session #{session.id}  role #{role}  seq #{session.nextSequence or 0}  revision #{session.revision or 0}", WHITE }
		table.insert lines, { "pending #{#(session.pending or {})}  unsent #{#(session.unsent or {})}  server-hash #{session.serverHash or "-"}  terminal #{boolText(session.terminal)}", DIM }
	else
		table.insert lines, { "session none  state-request attempts #{pendingSync and pendingSync.attempts or 0}", DIM }

	if follower
		table.insert lines, { "follower reached #{follower.reachedSequence or 0}/#{follower.targetSequence or 0}  settled #{boolText(follower.settled)}", WHITE }

	table.insert lines, { "presentation active #{boolText(debug and debug.presentation)}  result #{boolText(debug and debug.result)}  solver #{boolText(debug and debug.solving)}", DIM }
	table.insert lines, { "sound #{debug and debug.sound or "-"}", DIM }

	if state = DEBUG.Occlusion[panel]
		edge = state.edge
		age = RealTime! - (state.at or 0)
		table.insert lines, { "occlusion age #{numberText(age)}s  edge #{edge and edge.fromId or "-"}->#{edge and edge.toId or "-"}  q #{state.oldProgress or "-"}->#{state.candidateProgress or "-"}  result #{numberText(state.result, 4)}", age < 1 and WARN or DIM }
		table.insert lines, { "rays #{state.total or 0}: start #{state.start or 0}, fanout #{state.fanout or 0}, refine #{state.refine or 0}, blocked #{state.blocked or 0}", state.blocked > 0 and BAD or GOOD }
		if state.lastHit
			table.insert lines, { "last hit #{tostring(state.lastEntity)}  fraction #{numberText(state.lastFraction, 4)}  at #{tostring(state.lastHit)}", BAD }

	lines

drawPanelDebug = (panel) ->
	return unless IsValid panel
	transform = panel\GetScreenTransform!
	return unless transform
	panelWidth = Moonpanel.Canvas.Resolution / (panel.Aspect or 1)
	baseX, baseY = panelWidth + 18, 12
	pos = transform * Vector(baseX, baseY, 0)
	return if EyePos!\DistToSqr(pos) > maxDistance\GetFloat! ^ 2
	lines = panelLines panel

	-- Use the exact screen matrix used by the panel itself. The diagnostics
	-- therefore remain coplanar and preserve panel orientation instead of
	-- billboarding toward the viewer.
	cam.PushModelMatrix transform
	surface.SetFont "MoonpanelDebug3D"
	maxWidth = 0
	for line in *lines
		width = surface.GetTextSize line[1]
		maxWidth = math.max maxWidth, width
	height = #lines * 20 + 16
	draw.RoundedBox 6, baseX - 8, baseY - 8, maxWidth + 20, height,
		Color(5, 10, 16, 225)
	surface.SetDrawColor 50, 185, 235, 220
	surface.DrawRect baseX - 8, baseY - 8, 4, height
	for index, line in ipairs lines
		draw.SimpleText line[1], "MoonpanelDebug3D", baseX + 4,
			baseY + (index - 1) * 20, line[2] or WHITE,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
	cam.PopModelMatrix!

DEBUG.panelLines = panelLines

drawRays = ->
	now = RealTime!
	writeIndex = 1
	for readIndex = 1, #DEBUG.Rays
		ray = DEBUG.Rays[readIndex]
		continue unless ray and ray.expiresAt > now
		DEBUG.Rays[writeIndex] = ray
		writeIndex += 1
		render.DrawLine ray.startPos, ray.endPos, ray.color, false
		if hit = ray.hitPos
			size = 2.5
			render.DrawLine hit - Vector(size, 0, 0), hit + Vector(size, 0, 0), ORANGE, false
			render.DrawLine hit - Vector(0, size, 0), hit + Vector(0, size, 0), ORANGE, false
			render.DrawLine hit - Vector(0, 0, size), hit + Vector(0, 0, size), ORANGE, false
			if normal = ray.hitNormal
				render.DrawLine hit, hit + normal * 12, YELLOW, false
	for index = #DEBUG.Rays, writeIndex, -1
		DEBUG.Rays[index] = nil

drawAll = (drawingDepth, drawingSkybox) ->
	return if drawingDepth or drawingSkybox
	return unless IsValid LocalPlayer!
	drawRays!
	drawPanelDebug panel for panel in *ents.FindByClass "moonpanel"
	drawPanelDebug panel for panel in *ents.FindByClass "moonpanel_pillar"

setEnabled = (state) ->
	state = state == true
	if state
		hook.Add "PostDrawTranslucentRenderables", "Moonpanel Runtime Debug", drawAll
	else
		hook.Remove "PostDrawTranslucentRenderables", "Moonpanel Runtime Debug"
		DEBUG.Occlusion = setmetatable {}, { __mode: "k" }
		DEBUG.Rays = {}

cvars.AddChangeCallback "moonpanel_debug", ((_, _, value) ->
	setEnabled tonumber(value) ~= 0), "Moonpanel Runtime Debug"

concommand.Add "moonpanel_debug_toggle", ->
	RunConsoleCommand "moonpanel_debug", enabled\GetBool! and "0" or "1"

timer.Simple 0, -> setEnabled enabled\GetBool!
