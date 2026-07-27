-- Presentation is deliberately engine-blind. It samples absolute time into a
-- visual frame and emits transition cues; it never reads or writes TraceEngine.
Moonpanel.Canvas.PresentationConstants = {
	StartGrow: 0.15
	ExitBlend: 0.12
	SuccessTransition: 0.35
	FailureHold: 0.15
	FailureFade: 0.8
	AbortFade: 0.5
	EraserReveal: Moonpanel.Canvas.EraserRevealDelay or 0.75
	EraserFade: 0.45
	ErrorLifetime: 4.5
	ErrorFadeOut: 1

	FollowerMinSpeed: 96
	FollowerDistanceGain: 10
	FollowerMaxSpeed: 1600
	FollowerRetractMultiplier: 1.25
	FollowerMaxFrameTime: 1 / 15
	FollowerSettleDistance: 0.25
}

CONSTANTS = Moonpanel.Canvas.PresentationConstants
Helpers = Moonpanel.Helpers
copyArray = Helpers.copyArray

clamp01 = (value) -> Helpers.clamp value, 0, 1
smoothstep = (value) ->
	value = clamp01 value
	value * value * (3 - 2 * value)

copyAttemptKey = (key = {}) ->
	{
		sessionId: key.sessionId or key.id or 0
		revision: key.revision or 0
	}

copyFeedback = (feedback = {}) ->
	erasures = {}
	for erasure in *(feedback.erasures or {})
		table.insert erasures, {
			eraserIndex: erasure.eraserIndex or erasure[1] or 0
			targetIndex: erasure.targetIndex or erasure[2] or 0
		}

	{
		violations: copyArray feedback.violations
		:erasures
		remaining: copyArray feedback.remaining
		success: feedback.success == true
	}

class Moonpanel.Canvas.TracePresentation
	new: =>
		@branches = {}
		@reset "initialize"

	isActive: => @attemptKey ~= nil

	isFocusHintActive: => @focusHint == true and @attemptKey == nil

	setFocusHint: (focused, now = CurTime!) =>
		focused = focused == true
		return false if @focusHint == focused
		@focusHint = focused
		if focused
			@hintStartedAt = now
			@lastScintCycle = -1
		else
			@hintStartedAt = 0
		true

	setBranches: (branches = {}) =>
		@branches = {}
		for branch in *branches
			table.insert @branches, {
				visible: branch.visible ~= false
				color: branch.color
				completionColor: branch.completionColor
			}

	reset: (reason = "reset") =>
		@attemptKey = nil
		@startedAt = 0
		@result = nil
		@resultAt = 0
		@exitState = false
		@exitFrom = 0
		@exitTarget = 0
		@exitChangedAt = 0
		@queuedCues = {}
		@firedCues = {}
		@lastScintCycle = -1
		@focusHint = false
		@hintStartedAt = 0
		@lastResetReason = reason
		true

	queueCue: (name, key = name) =>
		return if @firedCues[key]
		@firedCues[key] = true
		table.insert @queuedCues, name

	drainCues: =>
		cues = @queuedCues
		@queuedCues = {}
		cues

	beginAttempt: (attemptKey, now = CurTime!) =>
		@reset "new-attempt"
		@attemptKey = copyAttemptKey attemptKey
		@startedAt = now
		@exitChangedAt = now
		@queueCue "Start"
		@queueCue "SolvingStart"
		@queueCue "PresenceDuck"
		true

	getExitBlend: (now) =>
		duration = math.max CONSTANTS.ExitBlend, 0.000001
		@exitFrom + (@exitTarget - @exitFrom) *
			smoothstep((now - @exitChangedAt) / duration)

	setExitContact: (state, now = CurTime!) =>
		state = state == true
		return false if state == @exitState
		@exitFrom = @getExitBlend now
		@exitTarget = state and 1 or 0
		@exitChangedAt = now
		@exitState = state
		if state
			table.insert @queuedCues, "FinishTracing"
			table.insert @queuedCues, "PathCompleteStart"
		else
			table.insert @queuedCues, "AbortFinishTracing"
			table.insert @queuedCues, "PathCompleteStop"
		true

	applyResult: (result = {}, now = CurTime!, elapsed = 0, silent = false) =>
		@result = {
			aborted: result.aborted == true
			success: result.success == true
			feedback: copyFeedback result.feedback
			eventSerial: result.eventSerial or 0
		}
		@resultAt = now - math.max(0, elapsed or 0)
		if @exitState
			@exitFrom = @getExitBlend now
			@exitTarget = 0
			@exitChangedAt = now
			@exitState = false
			table.insert @queuedCues, "PathCompleteStop"
		@queueCue "SolvingStop"
		@queueCue "PresenceResume"
		@queuedCues = {} if silent

		hasEraser = #@result.feedback.erasures > 0
		if @result.aborted
			@queueCue "Abort" unless silent
		elseif hasEraser
			@queueCue "PotentialFailure" unless silent
		else
			@queueCue(@result.success and "Success" or "Failure") unless silent

		if silent
			@firedCues.Eraser = true if hasEraser and elapsed >= CONSTANTS.EraserReveal
			@firedCues.Success = true if @result.success
			@firedCues.Failure = true unless @result.success or @result.aborted
		true

	addEntityStyle: (styles, index, values = {}) =>
		return unless index and index > 0
		style = styles[index] or {
			tint: nil
			tintAmount: 0
			error: 0
			erased: 0
			alpha: 1
			glow: 0
		}
		style.error = math.max style.error, values.error or 0
		if values.tint
			style.tint = values.tint
			style.tintAmount = math.max style.tintAmount, values.tintAmount or 1
		style.erased = math.max style.erased, values.erased or 0
		style.alpha = math.min style.alpha, values.alpha or 1
		style.glow = math.max style.glow, values.glow or 0
		styles[index] = style

	sample: (now = CurTime!) =>
		frame = {
			active: @attemptKey ~= nil
			widthScale: 1
			exitPulse: 0
			traceAlpha: 1
			traceError: 0
			completion: 0
			flash: 0
			branchStyles: @branches
			startRipple: 0
			scint: 0
			scintProgress: 0
			scintAlpha: 0
			scintPower: 0
			scintStarts: false
			entityStyles: {}
			needsAnimation: false
			needsSampling: false
		}

		startElapsed = 0
		unless @attemptKey
			return frame, @drainCues! unless @focusHint
			startElapsed = math.max 0, now - @hintStartedAt
		else
			startElapsed = math.max 0, now - @startedAt
			frame.widthScale = smoothstep startElapsed / CONSTANTS.StartGrow
			frame.needsAnimation = true if frame.widthScale < 1
			if startElapsed < 0.45
				frame.startRipple = math.sin(math.pi * clamp01(startElapsed / 0.45))
				frame.needsAnimation = true

		scintPending = not @result and startElapsed < 0.5
		if not @result and startElapsed >= 0.5
			scintTime = startElapsed - 0.5
			cycle = math.floor scintTime / 2
			cycleTime = scintTime - cycle * 2
			scintPower = 0.75^cycle
			scintPending = scintPower >= 0.15
			if scintPower >= 0.15
				frame.scint = scintPower
				frame.scintPower = scintPower
				frame.scintStarts = not @attemptKey
				frame.scintProgress = cycleTime / 2
				frame.scintAlpha = (1 - frame.scintProgress) * scintPower
				frame.needsAnimation = true
				if cycle ~= @lastScintCycle
					@lastScintCycle = cycle
					table.insert @queuedCues, frame.scintStarts and "StartScint" or "Scint"

		exitBlend = @getExitBlend now
		if exitBlend > 0
			frame.exitPulse = exitBlend * (0.5 + 0.5 * math.sin(now * 18))
			frame.needsAnimation = true

		unless @result
			-- Keep sampling through quiet gaps between the finite scint pulses.
			-- Exit and result transitions explicitly invalidate the cached frame,
			-- so a fully settled attempt can otherwise remain quiescent.
			frame.needsSampling = frame.needsAnimation or scintPending
			return frame, @drainCues!

		elapsed = math.max 0, now - @resultAt
		feedback = @result.feedback
		hasEraser = #feedback.erasures > 0
		errorPulse = (index) ->
			0.5 + 0.5 * math.cos(now * 9 + index * 0.71)

		if @result.aborted
			frame.traceAlpha = 1 - smoothstep(elapsed / CONSTANTS.AbortFade)
			frame.needsAnimation = elapsed < CONSTANTS.AbortFade
			frame.needsSampling = frame.needsAnimation
			return frame, @drainCues!

		if hasEraser
			reveal = CONSTANTS.EraserReveal
			if elapsed < reveal
				frame.traceError = smoothstep elapsed / 0.12
				frame.traceAlpha = 1 - 0.25 * smoothstep(elapsed / reveal)
				for index in *feedback.violations
					@addEntityStyle frame.entityStyles, index, error: errorPulse index
				frame.needsAnimation = true
			else
				eraseElapsed = elapsed - reveal
				erased = smoothstep eraseElapsed / CONSTANTS.EraserFade
				for erasure in *feedback.erasures
					@addEntityStyle frame.entityStyles, erasure.eraserIndex,
						erased: erased, alpha: 1 - erased * 0.75
					@addEntityStyle frame.entityStyles, erasure.targetIndex,
						erased: erased, alpha: 1 - erased * 0.75

				unless @firedCues.Eraser
					@queueCue "Eraser"
					@queueCue @result.success and "Success" or "Failure"

				if @result.success
					frame.traceError = 1 - smoothstep(eraseElapsed / CONSTANTS.SuccessTransition)
					frame.completion = smoothstep eraseElapsed / CONSTANTS.SuccessTransition
					frame.flash = math.sin(math.pi * clamp01(eraseElapsed / 0.18))
					frame.needsAnimation = eraseElapsed < math.max(CONSTANTS.SuccessTransition,
						CONSTANTS.EraserFade)
				else
					frame.traceError = 1
					fadeElapsed = math.max 0, eraseElapsed - CONSTANTS.FailureHold
					frame.traceAlpha = 1 - smoothstep(fadeElapsed / CONSTANTS.FailureFade)
					errorVisibility = 1 - smoothstep(
						(eraseElapsed - CONSTANTS.ErrorLifetime +
							CONSTANTS.ErrorFadeOut) / CONSTANTS.ErrorFadeOut)
					for index in *feedback.remaining
						@addEntityStyle frame.entityStyles, index,
							error: errorPulse(index) * errorVisibility
					frame.needsAnimation = eraseElapsed < CONSTANTS.ErrorLifetime
		else
			if @result.success
				frame.completion = smoothstep elapsed / CONSTANTS.SuccessTransition
				frame.flash = math.sin(math.pi * clamp01(elapsed / 0.18))
				frame.needsAnimation = elapsed < CONSTANTS.SuccessTransition
			else
				frame.traceError = smoothstep elapsed / 0.12
				fadeElapsed = math.max 0, elapsed - CONSTANTS.FailureHold
				frame.traceAlpha = 1 - smoothstep(fadeElapsed / CONSTANTS.FailureFade)
				errorVisibility = 1 - smoothstep(
					(elapsed - CONSTANTS.ErrorLifetime +
						CONSTANTS.ErrorFadeOut) / CONSTANTS.ErrorFadeOut)
				for index in *feedback.remaining
					@addEntityStyle frame.entityStyles, index,
						error: errorPulse(index) * errorVisibility
				frame.needsAnimation = elapsed < CONSTANTS.ErrorLifetime

		frame.needsSampling = frame.needsAnimation
		frame, @drainCues!

	getEntityStyle: (index, frame) =>
		(frame and frame.entityStyles and frame.entityStyles[index]) or nil

routeLength = (route) ->
	length = 0
	for segment in *(route and route.segments or {})
		length += segment.visibleLength
	length

cloneRoute = (route) ->
	return { startId: 0, segments: {} } unless route
	segments = {}
	for segment in *route.segments
		table.insert segments, {
			token: segment.token
			fromId: segment.fromId
			toId: segment.toId
			fullLength: segment.fullLength
			visibleLength: segment.visibleLength
		}
	{
		startId: route.startId
		:segments
	}

trimRoute = (route, wantedLength) ->
	output = { startId: route and route.startId or 0, segments: {} }
	remaining = math.max 0, wantedLength
	for segment in *(route and route.segments or {})
		break if remaining <= 0
		visible = math.min segment.visibleLength, remaining
		table.insert output.segments, {
			token: segment.token
			fromId: segment.fromId
			toId: segment.toId
			fullLength: segment.fullLength
			visibleLength: visible
		}
		remaining -= visible
	output

commonRouteLength = (displayed, target) ->
	return 0 unless displayed and target and displayed.startId == target.startId
	common = 0
	limit = math.min #displayed.segments, #target.segments
	for i = 1, limit
		a = displayed.segments[i]
		b = target.segments[i]
		break unless a.token == b.token
		shared = math.min a.visibleLength, b.visibleLength
		common += shared
		break if math.abs(a.visibleLength - b.visibleLength) > 0.000001
	common

routeNeed = (displayed, target) ->
	return routeLength(target), false unless displayed and displayed.startId == target.startId
	common = commonRouteLength displayed, target
	displayedLength = routeLength displayed
	if displayedLength > common + 0.000001
		return displayedLength - common, true
	math.max(0, routeLength(target) - common), false

advanceRoute = (displayed, target, fraction) ->
	return cloneRoute target if fraction >= 1
	unless displayed and displayed.startId == target.startId
		return trimRoute target, routeLength(target) * fraction

	common = commonRouteLength displayed, target
	displayedLength = routeLength displayed
	if displayedLength > common + 0.000001
		trimRoute displayed, displayedLength - (displayedLength - common) * fraction
	else
		targetLength = routeLength target
		trimRoute target, common + (targetLength - common) * fraction

buildRoute = (topology, snapshot, branchId) ->
	ids = snapshot and snapshot.stacks and snapshot.stacks[branchId] or {}
	route = {
		startId: ids[1] or 0
		segments: {}
	}
	append = (fromId, toId, fraction = 1) ->
		fromNode = topology.nodes[fromId]
		toNode = topology.nodes[toId]
		return unless fromNode and toNode
		dx = toNode.screenX - fromNode.screenX
		dy = toNode.screenY - fromNode.screenY
		length = math.sqrt dx * dx + dy * dy
		table.insert route.segments, {
			token: "#{fromId}:#{toId}"
			:fromId
			:toId
			fullLength: length
			visibleLength: length * clamp01 fraction
		}

	for i = 1, #ids - 1
		append ids[i], ids[i + 1]

	if snapshot and snapshot.active
		fromKey = branchId == 1 and "primaryFrom" or "secondaryFrom"
		toKey = branchId == 1 and "primaryTo" or "secondaryTo"
		fromId = snapshot.active[fromKey]
		toId = snapshot.active[toKey]
		if fromId and fromId > 0 and toId and toId > 0
			edge = topology\getEdge fromId, toId
			fraction = edge and edge.lengthQ > 0 and
				snapshot.active.progressQ / edge.lengthQ or 0
			append fromId, toId, fraction
	route

Moonpanel.Canvas.BuildTraceRenderState = (topology, snapshot, sequence = 0) ->
	state = {
		routes: {}
		touchingExit: snapshot and snapshot.touchingExit == true
		:sequence
	}
	branchCount = snapshot and snapshot.stacks and #snapshot.stacks or 0
	for branchId = 1, branchCount
		state.routes[branchId] = buildRoute topology, snapshot, branchId
	state

cloneRenderState = (state) ->
	{
		routes: [cloneRoute route for route in *(state and state.routes or {})]
		touchingExit: state and state.touchingExit == true
		sequence: state and state.sequence or 0
	}

sameRenderGeometry = (a, b) ->
	return false unless a and b
	return false unless a.touchingExit == b.touchingExit
	return false unless #a.routes == #b.routes
	for branchId = 1, #a.routes
		aRoute = a.routes[branchId]
		bRoute = b.routes[branchId]
		return false unless aRoute and bRoute and aRoute.startId == bRoute.startId
		return false unless #aRoute.segments == #bRoute.segments
		for segmentId = 1, #aRoute.segments
			aSegment = aRoute.segments[segmentId]
			bSegment = bRoute.segments[segmentId]
			return false unless aSegment.token == bSegment.token and
				math.abs(aSegment.visibleLength - bSegment.visibleLength) <= 0.000001
	true

-- The follower owns only rendered route lengths. Its targets are immutable
-- canonical snapshots produced by the observer engine.
class Moonpanel.Canvas.ObserverTraceFollower
	new: (@topology) =>
		@displayed = { routes: {}, touchingExit: false, sequence: 0 }
		@target = cloneRenderState @displayed
		@targetSequence = 0
		@reachedSequence = 0
		@settled = true

	reset: (snapshot, seedImmediately = true, sequence = 0) =>
		@target = Moonpanel.Canvas.BuildTraceRenderState @topology, snapshot, sequence
		@targetSequence = sequence
		if seedImmediately
			@displayed = cloneRenderState @target
			@reachedSequence = sequence
		@settled = seedImmediately
		true

	setTarget: (snapshot, finalSequence = 0) =>
		@target = Moonpanel.Canvas.BuildTraceRenderState @topology, snapshot, finalSequence
		@targetSequence = finalSequence
		@settled = false
		true

	update: (frameTime) =>
		return @displayed, false if @settled and
			@reachedSequence >= @targetSequence

		dt = math.max 0, math.min(frameTime or 0, CONSTANTS.FollowerMaxFrameTime)
		maxNeed = 0
		anyRetracting = false
		branchCount = math.max #@displayed.routes, #@target.routes
		for branchId = 1, branchCount
			need, retracting = routeNeed @displayed.routes[branchId],
				@target.routes[branchId] or { startId: 0, segments: {} }
			maxNeed = math.max maxNeed, need
			anyRetracting = true if retracting

		if maxNeed <= CONSTANTS.FollowerSettleDistance
			changed = not sameRenderGeometry @displayed, @target
			@displayed = cloneRenderState(@target) if changed
			-- Sequence advancement is canonical bookkeeping, not visible geometry.
			-- Preserve the render-state table when already settled so idle panels
			-- do not invalidate their render target forever.
			@displayed.sequence = @target.sequence unless changed
			@reachedSequence = @targetSequence
			@settled = true
			return @displayed, changed

		speed = math.Clamp CONSTANTS.FollowerMinSpeed +
			CONSTANTS.FollowerDistanceGain * maxNeed,
			CONSTANTS.FollowerMinSpeed, CONSTANTS.FollowerMaxSpeed
		speed *= CONSTANTS.FollowerRetractMultiplier if anyRetracting
		fraction = math.min 1, speed * dt / math.max(maxNeed, 0.000001)
		newRoutes = {}
		for branchId = 1, branchCount
			target = @target.routes[branchId] or { startId: 0, segments: {} }
			newRoutes[branchId] = advanceRoute @displayed.routes[branchId], target, fraction
		@displayed.routes = newRoutes
		@displayed.touchingExit = @target.touchingExit and fraction >= 1
		@displayed.sequence = @reachedSequence
		@displayed, true

	hasReached: (finalSequence) =>
		@reachedSequence >= (finalSequence or @targetSequence)

	getRenderState: => @displayed
