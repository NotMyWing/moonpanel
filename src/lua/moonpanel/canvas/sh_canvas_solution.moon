CANVAS = Moonpanel.Canvas.Canvas.__base

VERIFIER_PROFILE = if CreateConVar
	CreateConVar(
		"moonpanel_verifier_profile",
		"0",
		FCVAR_ARCHIVE,
		"Print Moonpanel verifier timings and Eraser search counters.",
		0,
		1
	)
else
	GetBool: -> false

VERIFIER_SLICE_MS = if CreateConVar
	CreateConVar(
		"moonpanel_verifier_slice_ms",
		"1",
		FCVAR_ARCHIVE,
		"Maximum verifier CPU time per coroutine slice in milliseconds.",
		0.25,
		10
	)
else
	GetFloat: -> 1

VERIFIER_MAX_MS = if CreateConVar
	CreateConVar(
		"moonpanel_verifier_max_ms",
		"500",
		FCVAR_ARCHIVE,
		"Maximum total server CPU time allowed for one verifier evaluation.",
		25,
		5000
	)
else
	GetFloat: -> 500

VERIFIER_MAX_WORK = if CreateConVar
	CreateConVar(
		"moonpanel_verifier_max_work",
		"250000",
		FCVAR_ARCHIVE,
		"Maximum logical work units allowed for one verifier evaluation.",
		1000,
		2000000
	)
else
	GetInt: -> 250000

Moonpanel.Canvas.VerifierState or= {
	activeByCanvas: {}
	activeByPlayer: {}
	total: 0
}

acquireVerifier = (canvas) ->
	return true unless SERVER
	state = Moonpanel.Canvas.VerifierState
	player = canvas\GetAttemptController!
	return false unless IsValid(player) and player\IsPlayer!
	return false if state.activeByCanvas[canvas] or state.activeByPlayer[player]
	return false if state.total >= 2
	state.activeByCanvas[canvas] = player
	state.activeByPlayer[player] = canvas
	state.total += 1
	true

releaseVerifier = (canvas) ->
	return unless SERVER
	state = Moonpanel.Canvas.VerifierState
	player = state.activeByCanvas[canvas]
	return unless player
	state.activeByCanvas[canvas] = nil
	state.activeByPlayer[player] = nil if state.activeByPlayer[player] == canvas
	state.total = math.max 0, state.total - 1

Moonpanel.Canvas.ReleaseVerifier = releaseVerifier

CANVAS.CancelSolution = (reason = "cancelled") =>
	return false unless @__solutionCoroutine
	@__solutionCoroutine = nil
	releaseVerifier @
	@FinishSolution {
		status: reason
		success: false
	}
	true

verifierProfilingEnabled = ->
	VERIFIER_PROFILE and VERIFIER_PROFILE\GetBool!

milliseconds = (seconds) ->
	string.format "%.3f", (tonumber(seconds) or 0) * 1000

printVerifierProfile = (report, budget = nil) ->
	profile = report and report.developmentProfile
	return unless profile
	timings = profile.timings or {}
	counters = profile.counters or {}
	realm = SERVER and "server" or "client"
	print table.concat {
		"[moonpanel verifier] realm=", realm
		" status=", tostring report.status
		" success=", tostring report.success == true
		" total_ms=", milliseconds timings.total
		" path_ms=", milliseconds timings.pathConstruction
		" regions_ms=", milliseconds timings.regionConstruction
		" grouping_ms=", milliseconds timings.clueGrouping
		" initial_ms=", milliseconds timings.initialValidation
		" eraser_ms=", milliseconds timings.eraserScoring
		" reporting_ms=", milliseconds timings.finalReporting
		" states=", tostring counters.eraserStatesExplored or 0
		" pruned=", tostring counters.prunedEraserStates or 0
		" branches=", tostring counters.eraserBranches or 0
		" depth=", tostring counters.maxRecursiveDepth or 0
		" revalidations=", tostring counters.fullRegionRevalidations or 0
		" poly_calls=", tostring counters.polyominoSolverCalls or 0
		" poly_hits=", tostring counters.polyominoCacheHits or 0
		" poly_misses=", tostring counters.polyominoCacheMisses or 0
		" report_cache=", tostring counters.exactReportCacheHits or 0
		" facts_cache=", tostring counters.traceFactsCacheHits or 0
		" persistent_poly=", tostring counters.polyominoPersistentCacheHits or 0
		" persistent_eraser=", tostring counters.eraserPersistentCacheHits or 0
		" work=", tostring(budget and budget.total or 0)
		" yields=", tostring(budget and budget.yields or 0)
		" slice_ms=", milliseconds(budget and budget.sliceSeconds or 0)
		" active_ms=", milliseconds(budget and budget\activeTime! or 0)
		" limit=", tostring(budget and budget.exhausted or "none")
	}

	regionIds = [regionId for regionId in pairs profile.regions or {}]
	table.sort regionIds
	for regionId in *regionIds
		region = profile.regions[regionId]
		total = (region.initialTime or 0) + (region.totalTime or 0)
		print table.concat {
			"[moonpanel verifier] region=", tostring regionId
			" total_ms=", milliseconds total
			" validation_ms=", milliseconds region.time
			" states=", tostring region.eraserStates or 0
			" revalidations=", tostring region.revalidations or 0
		}

CANVAS.SolutionCoroutineThink = =>
	return unless @__solutionCoroutine
	status, result = coroutine.resume @__solutionCoroutine

	unless status
		ErrorNoHalt "[Moonpanel] solution coroutine failed: #{tostring result}\n"
		@__solutionCoroutine = nil
		@FinishSolution {
			status: "error"
			success: false
			feedback: {
				violations: {}
				erasures: {}
				remaining: {}
				success: false
			}
		}
		return

	if coroutine.status(@__solutionCoroutine) == "dead"
		@__solutionCoroutine = nil

CANVAS.CreateSolutionCoroutine = =>
	return if not @__playData or not @__playData.endTime
	return unless @__pathFinder and @__ruleDefinition
	return nil, "verifier_busy" unless acquireVerifier @

	snapshot = @__pathFinder\snapshot!
	traceHash = @__pathFinder\hash!
	return coroutine.create ->
		profile = verifierProfilingEnabled!
		sliceSeconds = math.Clamp(VERIFIER_SLICE_MS\GetFloat!, 0.25, 10) / 1000
		maximumSeconds = if SERVER
			math.Clamp(VERIFIER_MAX_MS\GetFloat!, 25, 5000) / 1000
		else 0
		budget = Moonpanel.Canvas.RuleEngine.NewBudget {
			slice: 2000
			:sliceSeconds
			maximum: math.Clamp(VERIFIER_MAX_WORK\GetInt!, 1000, 2000000)
			:maximumSeconds
			-- Keep a separate lifecycle ceiling. It prevents a starved or
			-- abandoned coroutine from retaining a global verifier slot while
			-- allowing ordinary scheduler delay between cooperative slices.
			maximumWallSeconds: if SERVER
				math.max 5, maximumSeconds * 10
			else 0
			yieldFn: -> coroutine.yield "budget"
		}
		report = Moonpanel.Canvas.RuleEngine.Evaluate @__ruleDefinition, snapshot, {
			:traceHash
			cache: @__ruleCache
			checkpoint: (amount) -> budget\checkpoint amount
			developmentProfile: profile
		}
		printVerifierProfile report, budget if profile
		if report.status ~= "complete"
			message = "[Moonpanel] rule evaluation #{report.status}; rule revision " ..
				tostring(report.ruleRevision) .. ", trace hash " ..
				tostring(report.traceHash) .. "\n"
			if ErrorNoHalt
				ErrorNoHalt message
			else
				print message
		@__lastRuleReport = report

		feedback = Moonpanel.Canvas.RuleEngine.FeedbackManifest report

		@FinishSolution {
			status: report.status
			success: report.success == true
			:feedback
			ruleReport: report
		}
