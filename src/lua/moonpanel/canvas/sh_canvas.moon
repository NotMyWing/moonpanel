Moonpanel.Canvas or= {}
Helpers = Moonpanel.Helpers

-- Lifecycle timings shared by authoritative state and client presentation.
Moonpanel.Canvas.EraserRevealDelay = 0.75

Moonpanel.Canvas.Symmetry = {
    None:       0
    Vertical:   1
    Horizontal: 2
	Rotational: 3
}

Moonpanel.Canvas.SocketType = {
	Intersection: 1
	Path: 2
	Cell: 3
}
INTERSECTION_SOCKET = Moonpanel.Canvas.SocketType.Intersection

Moonpanel.Canvas.Resolution = 512

-- Shared screen-matrix construction helpers used by both client and server.
-- The private model map feeds screen-matrix construction and tool selection.
plateInfo = (rs, offsetZ) -> {
    RS: rs, RatioX: 1
    offset: Vector(0, 0, offsetZ), rot: Angle(0, 90, 180)
}
monitorOffsets = {
    ["models//cheeze/pcb/pcb4.mdl"]: {
        RS: 0.0625, RatioX: 1,
        offset: Vector(0, 0, 0.5), rot: Angle(0, 0, 180),
    },
    ["models//cheeze/pcb/pcb5.mdl"]: {
        RS: 0.0625, RatioX: 0.508,
        offset: Vector(-0.5, 0, 0.5), rot: Angle(0, 0, 180),
    },
    ["models//cheeze/pcb/pcb6.mdl"]: {
        RS: 0.09375, RatioX: 0.762,
        offset: Vector(-0.5, -8, 0.5), rot: Angle(0, 0, 180),
    },
    ["models//cheeze/pcb/pcb7.mdl"]: {
        RS: 0.125, RatioX: 1,
        offset: Vector(0, 0, 0.5), rot: Angle(0, 0, 180),
    },
    ["models//cheeze/pcb/pcb8.mdl"]: {
        RS: 0.125, RatioX: 0.668,
        offset: Vector(15.885, 0, 0.5), rot: Angle(0, 0, 180),
    },
    ["models/cheeze/pcb2/pcb8.mdl"]: {
        RS: 0.2475, RatioX: 0.99,
        offset: Vector(0, 0, 0.3), rot: Angle(0, 0, 180),
    },
    ["models/blacknecro/tv_plasma_4_3.mdl"]: {
        RS: 0.082, RatioX: 0.751,
        offset: Vector(0, -0.1, 0), rot: Angle(0, 0, -90),
    },
    ["models/hunter/blocks/cube1x1x1.mdl"]: {
        RS: 0.09, RatioX: 1,
        offset: Vector(24, 0, 0), rot: Angle(0, 90, -90),
    },
    ["models/hunter/plates/plate05x05.mdl"]: plateInfo 0.045, 1.7
    ["models/hunter/plates/plate1x1.mdl"]: plateInfo 0.09, 2
    ["models/hunter/plates/plate2x2.mdl"]: plateInfo 0.182, 2
    ["models/hunter/plates/plate4x4.mdl"]: plateInfo 0.3707, 2
    ["models/hunter/plates/plate8x8.mdl"]: plateInfo 0.741, 2
    ["models/hunter/plates/plate16x16.mdl"]: plateInfo 1.482, 2
    ["models/hunter/plates/plate24x24.mdl"]: plateInfo 2.223, 2
    ["models/hunter/plates/plate32x32.mdl"]: plateInfo 2.964, 2
    ["models/kobilica/wiremonitorbig.mdl"]: {
        RS: 0.045, RatioX: 0.991,
        offset: Vector(0.2, -0.4, 13), rot: Angle(0, 0, -90),
    },
    ["models/kobilica/wiremonitorsmall.mdl"]: {
        RS: 0.0175, RatioX: 1,
        offset: Vector(0, -0.4, 5), rot: Angle(0, 0, -90),
    },
    ["models/props/cs_assault/billboard.mdl"]: {
        RS: 0.23, RatioX: 0.522,
        offset: Vector(2, 0, 0), rot: Angle(0, 90, -90),
    },
    ["models/props/cs_office/computer_monitor.mdl"]: {
        RS: 0.031, RatioX: 0.767,
        offset: Vector(3.3, 0, 16.7), rot: Angle(0, 90, -90),
    },
    ["models/props/cs_office/tv_plasma.mdl"]: {
        RS: 0.065, RatioX: 0.5965,
        offset: Vector(6.1, 0, 18.93), rot: Angle(0, 90, -90),
    },
    ["models/props_lab/monitor01b.mdl"]: {
        RS: 0.0185, RatioX: 1.0173,
        offset: Vector(6.53, -1, 0.45), rot: Angle(0, 90, -90),
    },
    ["models/props_lab/workspace002.mdl"]: {
        RS: 0.06836, RatioX: 0.9669,
        offset: Vector(-42.133224, -42.372322, 42.110897), rot: Angle(0, 133.340, -120.317),
    },
    ["models/props_mining/billboard001.mdl"]: {
        RS: 0.375, RatioX: 0.5714,
        offset: Vector(3.5, 0, 96), rot: Angle(0, 90, -90),
    },
    ["models/props_mining/billboard002.mdl"]: {
        RS: 0.375, RatioX: 0.3137,
        offset: Vector(3.5, 0, 192), rot: Angle(0, 90, -90),
    },
}

Moonpanel.Canvas.GetMonitorModels = =>
	models = {}
	for model in pairs monitorOffsets
		models[#models + 1] = model
	models

Moonpanel.Canvas.BuildScreenMatrix = (ent, modelName) ->
    info = monitorOffsets[modelName]
    unless info
        mins, maxs = ent\OBBMins!, ent\OBBMaxs!
        size = maxs - mins
        size.x, size.y = size.y, size.x if size.x > size.y
        info = {
            RS: size.y / Moonpanel.Canvas.Resolution
            RatioX: size.y / size.x
            offset: ent.OBBCenter(ent) + Vector(0, 0, maxs.z - 0.24)
            rot: Angle(0, 90, 180)
        }

    res = Moonpanel.Canvas.Resolution
    rotation, translation, translation2, scale = Matrix!, Matrix!, Matrix!, Matrix!
    scalefactor = 512 / res

    rotation\SetAngles          info.rot
    translation\SetTranslation  info.offset
    translation2\SetTranslation Vector -(res * 0.5) / info.RatioX, -(res * 0.5), 0
    scale\SetScale              scalefactor * Vector info.RS, info.RS, info.RS

    translation * rotation * scale * translation2, info

AddCSLuaFile!
AddCSLuaFile "cl_dcanvas.lua"
AddCSLuaFile "cl_rtpool.lua"
AddCSLuaFile "cl_colorutils.lua"
AddCSLuaFile "cl_presentation.lua"
AddCSLuaFile "sh_rule_engine.lua"
AddCSLuaFile "sh_surface.lua"
AddCSLuaFile "sh_continuous_topology.lua"
AddCSLuaFile "editor/cl_document.lua"
AddCSLuaFile "editor/cl_store.lua"
AddCSLuaFile "editor/cl_editor.lua"

include "sh_surface.lua"
include "sh_paneldata.lua"
Moonpanel.Canvas.RuleEngine = include "sh_rule_engine.lua"
include "sh_pathfinder.lua"
include "sh_entities.lua"
include "sh_entitysocket.lua"
include "sh_continuous_topology.lua"

if CLIENT
	Moonpanel.EditorDocument = include "editor/cl_document.lua"
	include "cl_dcanvas.lua"
	include "cl_rtpool.lua"
	include "cl_presentation.lua"
	include "editor/cl_store.lua"
	include "editor/cl_editor.lua"
else
	resource.AddFile "materials/moonpanel/circle.png"

PANEL_SOUNDS = {
	Scint: {"panel_scint.wav", nil, false, "panel_scint_endpoint.wav"}
	StartScint: {"panel_scint_startpoint.wav", nil, false, "panel_scint_startpoint.wav"}
	Start: {"panel_start_tracing.wav", nil, false, "panel_start_tracing.wav"}
	PathCompleteLoop: {"panel_path_complete_loop.wav", 45}
	SolvingLoop: {"panel_solving_loop.wav", 40}
	PresenceLoop: {"panel_presence_loop.wav", 40}
	FinishTracing: {"panel_finish_tracing.wav", nil, false, "panel_finish_tracing.wav"}
	AbortFinishTracing: {"panel_abort_finish_tracing.wav", nil, false, "panel_abort_finish_tracing.wav"}
	PowerOn: {"powered_on.wav", nil, true}
	PowerOff: {"powered_off.wav", nil, true}
	Failure: {"panel_failure.wav", nil, true, "panel_failure.wav"}
	PotentialFailure: {"panel_potential_failure.wav", nil, true, "panel_potential_failure.wav"}
	Success: {"panel_success.wav", nil, true, "panel_success.wav"}
	Eraser: {"eraser_apply.wav", nil, true}
	Abort: {"panel_abort_tracing.wav", nil, true, "panel_abort_tracing.wav"}
}
PRESENTATION_SOUND_CUES = {Start: true, StartScint: true, Scint: true,
	FinishTracing: true, AbortFinishTracing: true, PotentialFailure: true,
	Success: true, Failure: true, Eraser: true, Abort: true}
LOOP_SOUNDS = {PathCompleteLoop: true, SolvingLoop: true, PresenceLoop: true}
SOUND_CHANNELS = {
	Scint: 0, StartScint: 1, Start: 2, FinishTracing: 3,
	AbortFinishTracing: 4, PowerOn: 5, PowerOff: 6, Failure: 7,
	PotentialFailure: 8, Success: 9, Eraser: 10, Abort: 11
}
soundPresetName = (data) ->
	name = data and data.Sounds and data.Sounds.Preset
	Moonpanel.Canvas.SoundPresets[name] and name or Moonpanel.Canvas.DefaultSoundPreset
makeObserverFollower = (topology, snapshot, sequence = 0) ->
	follower = Moonpanel.Canvas.ObserverTraceFollower topology
	follower\reset snapshot, true, sequence
	follower

class Canvas
	new: (data, @__traceOcclusion = util.TraceLine) =>
		@__playData = {}
		@__surface = Moonpanel.Canvas.MakeSurfaceSpec!
		@__soundEnabled = true
		@__presentation = Moonpanel.Canvas.TracePresentation! if CLIENT
		@ImportData data if data

	ResetSolver: =>
		Moonpanel.Canvas.ReleaseVerifier @ if @__solutionCoroutine and Moonpanel.Canvas.ReleaseVerifier
		@__solutionCoroutine, @__lastRuleReport = nil, nil
		@__predictedVisual = nil

	ResetTraceEngine: =>
		return unless @__pathFinder
		@__pathFinder\reset!
		@BindWorldOcclusion!

	ClearPresentationState: =>
		@__visualFrame, @__observerFollower = nil, nil
		@__terminalSnapshot, @__terminalSnapshotRestored = nil, false

	ClearAttempt: =>
		@ResetSolver!
		@__playData = {}

	SetSurfaceSpec: (surfaceSpec) =>
		nextSurface = Moonpanel.Canvas.MakeSurfaceSpec surfaceSpec and surfaceSpec.kind,
			surfaceSpec and surfaceSpec.continuous
		return false if @__surface and @__surface.kind == nextSurface.kind and
			@__surface.continuous == nextSurface.continuous
		@__surface = nextSurface
		@__surfaceCompatibility = @__data and
			Moonpanel.Canvas.GetSurfaceCompatibility(@__data, @__surface) or nil
		@RebuildPathFinderCache! if @__data
		true

	GetSurfaceSpec: => @__surface or Moonpanel.Canvas.MakeSurfaceSpec!

	IsContinuous: => Moonpanel.Canvas.IsContinuousSurface @GetSurfaceSpec!

	GetSurfaceCompatibility: => @__surfaceCompatibility

	IsHiddenContinuousSocket: (socket) =>
		return false unless @IsContinuous! and socket and @__data
		return false if @__surfaceCompatibility and
			#(@__surfaceCompatibility.seamPairs or {}) > 0
		type = socket\GetSocketType!
		return false unless type == Moonpanel.Canvas.SocketType.Intersection or
			type == Moonpanel.Canvas.SocketType.Path and socket\IsVertical!
		socket\GetX! == @__data.Meta.Width + 1

	SetWorldEntity: (ent) =>
		@__worldEntity = ent
		@BindWorldOcclusion!

	-----------------------------------------------------------
	-- World-transform helpers used by occlusion checks.      --
	-----------------------------------------------------------
	GetWorldTransform: =>
		return nil, nil, nil unless @__worldEntity and IsValid @__worldEntity
		boneMatrix = @__worldEntity\GetBoneMatrix(0)
		return nil, nil, nil unless boneMatrix
		entityScreenMatrix = @__worldEntity.ScreenMatrix
		return nil, nil, nil unless entityScreenMatrix
		boneMatrix * entityScreenMatrix

	CanvasPointToWorld: (point, renderTransform = nil) =>
		return unless point and @__worldEntity and IsValid @__worldEntity
		if @__worldEntity.CanvasToWorld
			return @__worldEntity\CanvasToWorld point.x, point.y
		renderTransform or= @GetWorldTransform!
		return unless renderTransform
		renderTransform * Vector point.x, point.y, 0

	TargetFor: (point, eyePos, epsilon) =>
		dir = eyePos - point
		dist = dir\Length!
		return point if dist < 0.001
		point + dir / dist * epsilon

	_IsTraceBlocked: (trace) =>
		trace and (trace.StartSolid or trace.AllSolid or
			trace.Hit and (trace.Fraction or 0) < 1) or false

	_TraceOcclusion: (startPos, endPos, filter, stage, index) =>
		@__occlusionTrace or= { output: {} }
		trace = @__occlusionTrace
		trace.start, trace.endpos, trace.filter = startPos, endPos, filter
		traceOcclusion = @__traceOcclusion
		result = traceOcclusion trace
		if CLIENT and Moonpanel.Debug and Moonpanel.Debug.RecordOcclusionRay
			Moonpanel.Debug\RecordOcclusionRay @__worldEntity, stage, index,
				startPos, endPos, result
		result

	SampleSegmentVisibility: (eyePos, startWorld, endWorld, filter, sampleCount, epsilon) =>
		return 1 if sampleCount < 1
		startTarget = @TargetFor startWorld, eyePos, epsilon
		tr = @_TraceOcclusion eyePos, startTarget, filter, "start", 0
		return 0 if @_IsTraceBlocked tr
		for i = 1, sampleCount
			t = i / sampleCount
			sampleWorld = startWorld + (endWorld - startWorld) * t
			sampleTarget = @TargetFor sampleWorld, eyePos, epsilon
			tr = @_TraceOcclusion eyePos, sampleTarget, filter, "fanout", i
			if @_IsTraceBlocked tr
				return @BinaryRefineInT eyePos, startWorld, endWorld,
					(i - 1) / sampleCount, t, filter, epsilon
		1

	BinaryRefineInT: (eyePos, startWorld, endWorld, loT, hiT, filter, epsilon) =>
		for iteration = 1, 10
			midT = (loT + hiT) * 0.5
			midWorld = startWorld + (endWorld - startWorld) * midT
			midTarget = @TargetFor midWorld, eyePos, epsilon
			tr = @_TraceOcclusion eyePos, midTarget, filter, "refine", iteration
			if @_IsTraceBlocked tr then hiT = midT else loT = midT
		loT

	_CanvasTipOffset: (pos, edge, barWidth) =>
		return pos unless edge and edge.unitX ~= nil
		halfBar = barWidth * 0.5
		{x: pos.x + edge.unitX * halfBar, y: pos.y + edge.unitY * halfBar}

	_EdgeVisibility: (eyePos, renderTransform, edge, oldProgress,
		candidateProgress, barWidth, filter, epsilon) =>
		return 1 unless edge
		posA = @__pathFinder\positionAtProgress edge, oldProgress
		posB = @__pathFinder\positionAtProgress edge, candidateProgress
		return 1 unless posA and posB
		tipA = @_CanvasTipOffset posA, edge, barWidth
		tipB = @_CanvasTipOffset posB, edge, barWidth
		startWorld = @CanvasPointToWorld tipA, renderTransform
		endWorld = @CanvasPointToWorld tipB, renderTransform
		return 1 unless startWorld and endWorld
		@SampleSegmentVisibility eyePos, startWorld, endWorld, filter, 8, epsilon

	CheckOcclusion: (ply, primaryEdge, oldProgress, candidateProgress) =>
		return 1 unless IsValid ply
		renderTransform = @GetWorldTransform!
		return 1 unless renderTransform or @__worldEntity and @__worldEntity.CanvasToWorld
		p0 = @CanvasPointToWorld {x: 0, y: 0}, renderTransform
		barWidth = @__pathFinder and @__pathFinder.topology and
			@__pathFinder.topology.barWidth or 1
		px = @CanvasPointToWorld {x: barWidth, y: 0}, renderTransform
		return 1 unless p0 and px
		epsilon = math.Clamp p0\Distance(px) * 0.01, 0.02, 0.2
		unless @__occlusionFilter and @__occlusionFilter[1] == ply and
				@__occlusionFilter[2] == @__worldEntity
			@__occlusionFilter = {ply, @__worldEntity}
		filter = @__occlusionFilter
		if CLIENT and Moonpanel.Debug and Moonpanel.Debug.BeginOcclusion
			Moonpanel.Debug\BeginOcclusion @__worldEntity, primaryEdge,
				oldProgress, candidateProgress
		fraction = @_EdgeVisibility ply\EyePos!, renderTransform, primaryEdge,
			oldProgress, candidateProgress, barWidth, filter, epsilon
		if CLIENT and Moonpanel.Debug and Moonpanel.Debug.EndOcclusion
			Moonpanel.Debug\EndOcclusion @__worldEntity, fraction
		fraction
	BindWorldOcclusion: =>
		if not @__pathFinder
			return
		if @__worldEntity and IsValid(@__worldEntity)
			@__pathFinder.occlusionConstraint = (ply, primaryEdge, oldProgress,
				candidateProgress) ->
				fraction = math.Clamp(@CheckOcclusion(
					ply, primaryEdge, oldProgress, candidateProgress) or 1, 0, 1)
				math.floor oldProgress +
					(candidateProgress - oldProgress) * fraction
		else
			@__pathFinder.occlusionConstraint = nil

	SetEditorGeometryVisible: (visible) =>
		visible = visible == true
		return if @__editorGeometryVisible == visible
		@__editorGeometryVisible = visible
		@__rtDirty = true if CLIENT

	GetEditorGeometryVisible: => @__editorGeometryVisible == true

	SetSoundEnabled: (enabled) =>
		enabled = enabled == true
		changed = @__soundEnabled ~= enabled
		@StopSounds! if changed and not enabled
		@__soundEnabled = enabled
		@SetupSounds! if enabled and not @__sounds
		changed

	SetSoundSuppressed: (soundName, suppressed) =>
		return false unless isstring soundName
		@__suppressedSounds or= {}
		suppressed = suppressed == true
		return false if (@__suppressedSounds[soundName] == true) == suppressed
		if suppressed
			@__suppressedSounds[soundName] = true
			@StopSound soundName
		else
			@__suppressedSounds[soundName] = nil
		true

	IsSoundSuppressed: (soundName) =>
		@__suppressedSounds and @__suppressedSounds[soundName] == true

	SetupSounds: =>
		return unless @__soundEnabled
		return if @__sounds

		target = if @__worldEntity and
			((SERVER and IsValid @__worldEntity) or CLIENT)
			@__worldEntity
		elseif CLIENT
			LocalPlayer!

		return if not target
		@__sounds = {}
		@__soundFiles = {}
		@__soundLevels = {}
		@__soundTarget = target
		@__soundActivity = {}
		@__soundDurations = {}
		@__soundQueue = {}
		preset = Moonpanel.Canvas.ResolveSoundPreset soundPresetName @__data
		for name, definition in pairs PANEL_SOUNDS
			continue if definition[3] and not CLIENT
			file = definition[1]
			file = "#{preset.Directory}/#{definition[4]}" if definition[4] and preset and preset.Directory ~= ""
			file = "moonpanel/#{file}"
			@__soundFiles[name] = file
			@__soundLevels[name] = definition[2] or 65
			@__soundDurations[name] = SoundDuration(file) or 0
			if LOOP_SOUNDS[name]
				sound = CreateSound target, file
				sound\SetSoundLevel @__soundLevels[name]
				@__sounds[name] = sound

	StopSound: (sound) =>
		return if not @__sounds

		name = sound if "string" == type sound
		sound = @__sounds[sound] if name
		if sound
			sound\Stop!
		elseif name and IsValid(@__soundTarget) and @__soundFiles[name]
			@__soundTarget\StopSound @__soundFiles[name]
		@__soundActivity[name] = nil if name and @__soundActivity

	StopPathCompleteLoop: =>
		@__pathCompleteLoopActive = false
		@StopSound "PathCompleteLoop"

	StopSounds: =>
		return if not @__sounds

		@__soundQueue = {}
		@StopSound name for name in pairs @__soundFiles
		@__soundActivity = {}

	PlaySound: (name, volume = 1, pitch = 100) =>
		return unless @__soundEnabled and @__sounds
		return unless isstring(name) and not @IsSoundSuppressed(name) and
			IsValid(@__soundTarget) and @__soundFiles[name]
		table.insert @__soundQueue, {name, volume, pitch}
		return if @__soundQueued
		@__soundQueued = true
		canvas = @
		timer.Simple 0, -> canvas\PlayQueuedSound!

	PlayQueuedSound: =>
		request = @__soundQueue and table.remove @__soundQueue, 1
		unless request
			@__soundQueued = nil
			return
		name, volume, pitch = request[1], request[2], request[3]
		if @__soundEnabled and not @IsSoundSuppressed(name) and
				IsValid(@__soundTarget) and @__soundFiles[name]
			@__soundTarget\EmitSound @__soundFiles[name],
				@__soundLevels[name], pitch, volume,
				CHAN_USER_BASE + SOUND_CHANNELS[name]
			duration = @__soundDurations and @__soundDurations[name] or 0
			@__soundActivity[name] = CurTime! +
				duration * 100 / math.max(pitch, 1) if duration > 0
		if #@__soundQueue > 0
			canvas = @
			timer.Simple 0, -> canvas\PlayQueuedSound!
		else
			@__soundQueued = nil

	SetLoop: (sound, volume = 1, fade = 0.1, startVolume = nil) =>
		return unless @__soundEnabled and @__sounds
		name = sound if "string" == type sound
		if name
			return if @IsSoundSuppressed name
			sound = @__sounds[name]
		return unless sound
		wasPlaying = sound\IsPlaying!
		unless wasPlaying
			sound\PlayEx startVolume ~= nil and startVolume or volume, 100
		if wasPlaying or startVolume ~= nil
			sound\ChangeVolume volume, fade
		if name and @__soundActivity
			@__soundActivity[name] = volume > 0 or
				fade > 0 and CurTime! + fade or nil

	GetPathNodes: => @__nodes

	GetColors: =>
		dataColors = @__data and @__data.Colors or {}
		colors = {
			Background: dataColors.Background or Moonpanel.Canvas.DefaultColors.Background
			Grid: dataColors.Untraced or Moonpanel.Canvas.DefaultColors.Untraced
			Error: dataColors.Errored or Moonpanel.Canvas.DefaultColors.Errored
			Cell: dataColors.Cell
			Vignette: dataColors.Vignette or Moonpanel.Canvas.DefaultColors.Vignette
		}
		colors.Trace = {dataColors.Traced or Moonpanel.Canvas.DefaultColors.Traced, {
			r: 255, g: 255, b: 116
		}}
		colors.EndTrace = {}

		symmetryOptions = @__data and @__data.Meta and @__data.Meta.SymmetryOptions
		traces = symmetryOptions and symmetryOptions.Traces
		symmetryEnabled = @__data and @__data.Meta and
			@__data.Meta.Symmetry ~= Moonpanel.Canvas.Symmetry.None
		if traces and symmetryEnabled
			for i = 1, 2
				trace = traces[i] or {}
				ruleColor = Moonpanel.Canvas.ColorValues[trace.RuleColor or trace.Color]
				colors.Trace[i] = trace.ColorValue or ruleColor or colors.Trace[i]
				colors.EndTrace[i] = trace.CompletionColorValue or
					Helpers.terminalColor colors.Trace[i]
		colors.EndTrace[1] or= Helpers.terminalColor colors.Trace[1]
		colors.EndTrace[2] or= Helpers.terminalColor colors.Trace[2]

		colors

	------------------------------------
	-- Imports data from given table. --
	------------------------------------
	ImportData: (data) =>
		sanitized = nil
		if data ~= nil
			return false unless istable data
			local ok
			ok, sanitized = pcall Moonpanel.Canvas.SanitizeData, data
			return false unless ok and sanitized

		@ClearAttempt!

		previousSoundPreset = soundPresetName @__data
		@__data = sanitized
		if @__data and previousSoundPreset ~= soundPresetName(@__data) and @__sounds
			@StopSounds!
			@__sounds = nil
			@SetupSounds!
		rawCompatibility = nil
		if @__data
			@__surface = Moonpanel.Canvas.MakeSurfaceSpec @GetSurfaceSpec!.kind,
				@__data.Meta.Continuous
			rawCompatibility = Moonpanel.Canvas.GetSurfaceCompatibility @__data, @__surface
			if @__surface.continuous and #(rawCompatibility.seamPairs or {}) == 0
				@__data = Moonpanel.Canvas.CanonicalizeContinuousData @__data
		@__surfaceCompatibility = @__data and rawCompatibility or nil
		@__geometry = @__data and Moonpanel.Canvas.CalculateGeometry @__data,
			Moonpanel.Canvas.Resolution
		if @__geometry and @IsContinuous!
			@__geometry.barLength = Moonpanel.Canvas.Resolution /
				math.max(1, @__data.Meta.Width)
			-- Horizontal geometry occupies the complete periodic texture. Vertical
			-- geometry is not periodic and must reserve enough room for a start bulb
			-- or an outward-facing exit cap at either boundary.
			verticalPadding = math.min Moonpanel.Canvas.Resolution * 0.2,
				math.ceil(@__geometry.barWidth * 1.5) + 1
			@__geometry.verticalPadding = verticalPadding
			@__geometry.verticalBarLength = math.max 1,
				(Moonpanel.Canvas.Resolution - verticalPadding * 2) /
				math.max(1, @__data.Meta.Height)
			@__geometry.cellLength = math.max 1,
				@__geometry.barLength - @__geometry.barWidth
			@__geometry.innerWidth = Moonpanel.Canvas.Resolution
			@__geometry.innerHeight = @__geometry.barWidth +
				@__geometry.verticalBarLength * @__data.Meta.Height

		@ResetPresentation "topology-change" if CLIENT and @__presentation

		if not @__data
			@__geometry = nil
			@__pathFinder = nil
			@__clientData = nil
			@__sockets = nil
			@__nodes = nil
			@__nodeMap = nil
			return true

		ents = @__data.Entities or {}
		numCols = @__data.Meta.Width  * 2 + 1
		numRows = @__data.Meta.Height * 2 + 1

		@__sockets = {}
		@__nodes = {}
		@__nodeMap = {}
		entityInfos = {}
		intersectionId, hpathId, vpathId, cellId = 0, 0, 0, 0
		for i = 1, numCols * numRows
			row = math.ceil i / numCols
			column = 1 + (i - 1) % numCols
			rowOdd, columnOdd = row % 2 == 1, column % 2 == 1
			local socketClass, socketId, horizontal
			if rowOdd and columnOdd
				socketClass = Moonpanel.Canvas.Sockets.IntersectionSocket
				intersectionId += 1
				socketId = intersectionId
			elseif rowOdd
				socketClass = Moonpanel.Canvas.Sockets.PathSocket
				hpathId += 1
				socketId, horizontal = hpathId, true
			elseif columnOdd
				socketClass = Moonpanel.Canvas.Sockets.PathSocket
				vpathId += 1
				socketId, horizontal = vpathId, false
			else
				socketClass = Moonpanel.Canvas.Sockets.CellSocket
				cellId += 1
				socketId = cellId
			entityClass = ents[i] and Moonpanel.Canvas.GetEntityClass ents[i].Type, socketClass.SocketType
			entityClass or= socketClass.BaseEntity
			socket = socketClass @, socketId, i
			socket\SetHorizontal horizontal if horizontal ~= nil
			@__sockets[i] = socket
			entityInfos[i] = {
				socket: socket
				class: entityClass
				data: ents[i] and ents[i].Data
			}

			if socketClass == Moonpanel.Canvas.Sockets.IntersectionSocket
				intX, intY = math.floor(column / 2), math.floor(row / 2)
				x = intX - @__data.Meta.Width / 2
				y = intY - @__data.Meta.Height / 2
				node = {
					neighbors: {}
					:socket
					id: #@__nodes + 1
					:x
					:y
					screenX: math.floor Moonpanel.Canvas.Resolution * 0.5 +
						x * @GetBarLength!
					screenY: math.floor Moonpanel.Canvas.Resolution * 0.5 +
						y * @GetVerticalBarLength!
				}
				socket\SetPathNode node
				@__nodeMap[intY + 1] or= {}
				@__nodeMap[intY + 1][intX + 1] = node
				table.insert @__nodes, node

		-- Socket population links the graph incrementally. Rebuilding the
		-- pathfinder for every one of those assignments turns a large empty
		-- board into hundreds of full rule compilations. Defer that work until
		-- all authored entities and path links have been installed.
		@__bulkImporting = true

		@BakeImportedColors! if CLIENT

		for info in *entityInfos
			socket = info.socket
			entity = info.class!
			entity\ImportData info.data if info.data and entity.ImportData
			socket\SetEntity entity, false

		for info in *entityInfos
			socket = info.socket
			socket\GetEntity!\PostPopulatePathNodes @GetPathNodes!
		@__bulkImporting = nil

		@RecalculateClient! if CLIENT
		@InitPathFinder!
		true

	RebuildPathFinderCache: =>
		return unless @__data
		@InitPathFinder!

		if CLIENT
			@RecalculateClient!
			@__rtDirty = true

	GetBarWidth: => @__geometry and @__geometry.barWidth or 1

	GetBarLength: => @__geometry and @__geometry.barLength or 1
	GetVerticalBarLength: => @__geometry and (@__geometry.verticalBarLength or
		@__geometry.barLength) or 1

	socketAt = (canvas, x, y) ->
		panelWidth, panelHeight = canvas\GetDimensions!
		return if panelWidth <= 0 or panelHeight <= 0
		width = panelWidth * 2 + 1
		height = panelHeight * 2 + 1
		return if x < 1 or y < 1 or x > width or y > height
		canvas\GetSocketAtDataIndex x + (y - 1) * width

	--------------------------------------------------------
	-- Returns the first entity at given SCREEN position. --
	--------------------------------------------------------
	GetEntityAtScreen: (scrX, scrY) =>
		return unless @__sockets
		for socket in *@__sockets
			continue unless socket\GetSocketType! == INTERSECTION_SOCKET
			continue if @IsHiddenContinuousSocket socket
			return socket if socket\CanClick scrX, scrY
		for socket in *@__sockets
			continue if socket\GetSocketType! == INTERSECTION_SOCKET
			continue if @IsHiddenContinuousSocket socket
			return socket if socket\CanClick scrX, scrY

	GetIntersectionSocketAt: (x, y) =>
		socketAt @, x * 2 - 1, y * 2 - 1
	GetHPathSocketAt: (x, y) =>
		socketAt @, x * 2, y * 2 - 1
	GetVPathSocketAt: (x, y) =>
		socketAt @, x * 2 - 1, y * 2
	GetCellSocketAt: (x, y) =>
		socketAt @, x * 2, y * 2

	GetSocketAtDataIndex: (index) =>
		@__sockets and @__sockets[index]

	--------------------------------------------------
	-- Fetches the internal panel data table.       --
	-- Not guaranteed to be useful, see ExportData. --
	--------------------------------------------------
	GetData: => @__data
	GetDimensions: =>
		meta = @__data and @__data.Meta
		meta and meta.Width or 0, meta and meta.Height or 0

	SetSolvedState: (solved) =>
		@__solved = solved == true

	GetSolvedState: => @__solved == true

	--------------------------------------------------------------------
	-- Exports data for various purposes, from saving boards to files --
	-- to sending them to clients.                                    --
	--------------------------------------------------------------------
	ExportData: =>
		return if not @__data

		copy = table.Copy @__data
		copy.Entities = {}
		for index, socket in ipairs @__sockets
			entity = socket\GetEntity!
			copy.Entities[index] = entity and entity\ExportData! or {}

		Moonpanel.Canvas.SanitizeData copy

	--------------------------------------------------------------
	-- Exports play data. Intended to be called when the server --
	-- wants us to replay the game.                             --
	--------------------------------------------------------------
	ExportPlayData: =>
		return if not @__data
		return if not @__playData

		copy = table.Copy @__playData
		copy.solved = @GetSolvedState!

		if @__pathFinder and @__data and @__playData.startTime and not @__playData.wasAborted
			copy.traceSnapshot = @__pathFinder\snapshot!
			copy.traceHash = @__pathFinder\hash!
			copy.topologyRevision = @__pathFinder.topology.revision

		copy

	--------------------------------------------------------------
	-- Imports play data. Intended to be called when the server --
	-- wants us to replay the game.                             --
	--------------------------------------------------------------
	ImportPlayData: (playData = {}) =>
		@__playData = table.Copy playData
		@SetSolvedState @__playData.solved == true
		@ClearPresentationState!
		if not @__playData.startTime and not @__playData.visualResult and @__pathFinder
			@ResetSolver!
			@ResetTraceEngine!

		if @__pathFinder and @__data and @__playData.traceSnapshot
			@__pathFinder\restore @__playData.traceSnapshot
			@__terminalSnapshot = table.Copy @__playData.traceSnapshot if CLIENT
			@__terminalSnapshotRestored = CLIENT

		@__playData.traceSnapshot = nil
		if CLIENT and @__presentation
			if visualResult = @__playData.visualResult
				@BeginPresentation {
					sessionId: visualResult.sessionId
					revision: visualResult.revision
				}, true
				@ApplyVisualResult visualResult, @__playData.visualElapsed or 0,
					true, @__playData.solved == true
			elseif @__playData.startTime and not @__playData.endTime
				@BeginPresentation {
					sessionId: @__playData.sessionId or 0
					revision: @__pathFinder and @__pathFinder.topology.revision or 0
				}, true, math.max(0, CurTime! - @__playData.startTime)
				@SetPresentationExit @__pathFinder\isExitPath!, true
		@__rtDirty = true

	------------------------------------------------------------
	-- Initializes the path finder. The thing responsible for --
	-- moving the traces around and snapping them.            --
	------------------------------------------------------------
	InitPathFinder: =>
		return if not @__data
		topologyNodes = if @IsContinuous!
			Moonpanel.Canvas.BuildContinuousNodes @
		else
			@__nodes
		surfaceSpec = @GetSurfaceSpec!

		-- Initialize the path finder.
		-- This has to be done every time the data table is changed.
		topology = Moonpanel.Canvas.TraceTopology {
			nodes: topologyNodes

			barWidth: @GetBarWidth!
			barLength: @GetBarLength!

			screenWidth: Moonpanel.Canvas.Resolution
			screenHeight: Moonpanel.Canvas.Resolution
			symmetry: @__data.Meta.Symmetry
			surfaceKind: surfaceSpec.kind
			wrapX: surfaceSpec.continuous
			periodWidth: @__data.Meta.Width
		}

		-- Rule evaluation consumes stable socket IDs, never entity/socket
		-- objects. Enrich the freshly-built topology once at the canvas
		-- boundary so snapshots can be evaluated identically in either realm.
		socketIndex = (socket) -> Moonpanel.Canvas.CanonicalSeamIndex(
			socket\GetDataIndex!, @__data, surfaceSpec)
		for node in *topology.nodes
			if node.socket
				node.socketIndex = socketIndex node.socket

		resolveEdgeSocket = (fromNode, toNode) ->
			return fromNode.edgeSockets[toNode] if fromNode.edgeSockets and
				fromNode.edgeSockets[toNode]
			-- Synthetic symmetry-gap endpoints belong to the authored path
			-- between their mirrored parents even though the endpoint itself has
			-- no serialized socket.
			if toNode.symmetryGapOtherParent
				toNode = toNode.symmetryGapOtherParent
			elseif fromNode.symmetryGapOtherParent
				otherParent = fromNode.symmetryGapOtherParent
				fromNode = toNode
				toNode = otherParent
			return fromNode.socket if fromNode.socket and
				fromNode.socket\GetSocketType! == Moonpanel.Canvas.SocketType.Path
			return toNode.socket if toNode.socket and
				toNode.socket\GetSocketType! == Moonpanel.Canvas.SocketType.Path
			return unless fromNode.socket and toNode.socket
			return unless fromNode.socket\GetSocketType! == Moonpanel.Canvas.SocketType.Intersection
			return unless toNode.socket\GetSocketType! == Moonpanel.Canvas.SocketType.Intersection

			ax, ay = fromNode.socket\GetX!, fromNode.socket\GetY!
			bx, by = toNode.socket\GetX!, toNode.socket\GetY!
			if ay == by and math.abs(ax - bx) == 1
				return @GetHPathSocketAt math.min(ax, bx), ay
			if ax == bx and math.abs(ay - by) == 1
				return @GetVPathSocketAt ax, math.min(ay, by)

		for fromId, fromNode in ipairs topology.nodes
			for toId, edge in pairs topology.edges[fromId]
				if socket = resolveEdgeSocket fromNode, topology.nodes[toId]
					edge.socketIndex = socketIndex socket
		@__pathFinder = Moonpanel.Canvas.TraceEngine topology
		ruleData = if @IsContinuous! and
			#((@__surfaceCompatibility and @__surfaceCompatibility.seamPairs) or {}) == 0
			Moonpanel.Canvas.CanonicalizeContinuousData @__data
		else
			@__data
		@__ruleDefinition = Moonpanel.Canvas.RuleEngine.Compile ruleData, topology
		@__ruleCache = Moonpanel.Canvas.RuleEngine.NewCache ttl: 120
		@BindWorldOcclusion!

	GetTraceHash: => @__pathFinder and @__pathFinder\hash!
	GetPillarTraceEngine: => @__pathFinder
	GetDebugState: =>
		p = @__pathFinder
		trace = p and p\GetDebugState!
		definition = @__ruleDefinition
		geometry = @__geometry
		follower = @__observerFollower
		{
			trace: trace
			rule: definition and {revision: definition.ruleRevision, clues: #(definition.clues or {})}
			geometry: geometry and {barWidth: geometry.barWidth,
				barLength: geometry.barLength, margin: geometry.margin}
			follower: follower and {reachedSequence: follower.reachedSequence or 0,
				targetSequence: follower.targetSequence or 0,
				settled: follower\hasReached!}
			power: @__powerState == true
			dirty: @__rtDirty == true or @__rtWasDirty == true
			drawRate: @__rtDrawRate or 0
			frameRate: @__rtFrameRate or 0
			solving: @__solutionCoroutine ~= nil
			presentation: @__presentation and @__presentation\isActive! or false
			result: @__presentation and @__presentation.result ~= nil or false
			sound: @GetSoundStatus!
		}
	CanSubmitTrace: => @__pathFinder and @__pathFinder\canSubmit! or false
	GetTraceCursor: (index = 1) => @__pathFinder and @__pathFinder\GetCursor index
	GetConstraintDecisions: => @__pathFinder and @__pathFinder\GetConstraintDecisions!
	GetTraceRevision: => @__pathFinder and @__pathFinder\GetRevision! or 0
	GetTracePhase: => @__pathFinder and @__pathFinder\GetPhase!
	IsExitPath: => @__pathFinder and @__pathFinder\isExitPath! or false
	SetTraceFeedback: =>
		return unless @__pathFinder
		@__pathFinder\SetFeedback!
	BeginTraceEvaluation: => @__pathFinder and @__pathFinder\beginEvaluation!
	RestoreTraceSnapshot: (snapshot) =>
		return false unless @__pathFinder and snapshot
		@__pathFinder\restore snapshot
		@__rtDirty = true if CLIENT
		true
	ApplyObserverSnapshot: (snapshot, sequence = 0) =>
		return false unless CLIENT and @RestoreTraceSnapshot snapshot
		follower = @__observerFollower
		unless follower
			@SetObserverFollower makeObserverFollower(
				@__pathFinder.topology, snapshot, sequence)
		else
			follower\setTarget snapshot, sequence
		true

	GetRenderMaterial: => @__rtAlloc and @__rtAlloc.rt and @__rtAlloc.rt.material
	GetSoundStatus: =>
		return "off" unless @__soundEnabled
		return "enabled/uninitialized" unless @__sounds
		total, playing = 0, 0
		now = CurTime!
		for name in pairs @__soundFiles
			total += 1
			active = @__soundActivity and @__soundActivity[name]
			if active == true or isnumber(active) and active > now
				playing += 1
			elseif active
				@__soundActivity[name] = nil
		"#{playing}/#{total} playing"

	FindStartNode: (x, y, radius = 32) =>
		return unless @__pathFinder and @__pathFinder.topology
		@__pathFinder.topology\getClosestStart x, y, radius

	GetTraceSnapshot: =>
		return unless @__pathFinder
		@__pathFinder\snapshot!
	GetTracePath: (snapshot, maximum = 512) =>
		return "" unless snapshot and istable snapshot.stacks and @__pathFinder
		topology = @__pathFinder.topology
		data = @__data
		width = data and data.Meta and tonumber data.Meta.Width
		stack = snapshot.stacks[1]
		return "" unless topology and topology.nodes and istable stack
		direction = (fromNode, toNode) ->
			return "?" unless fromNode and toNode
			dx = (toNode.x or 0) - (fromNode.x or 0)
			dy = (toNode.y or 0) - (fromNode.y or 0)
			if width and width > 0
				half = width * 0.5
				while dx > half
					dx -= width
				while dx < -half
					dx += width
			return "R" if math.abs(dx) > math.abs(dy) and dx > 0.000001
			return "L" if math.abs(dx) > math.abs(dy) and dx < -0.000001
			return "D" if math.abs(dy) > 0.000001 and dy > 0
			return "U" if math.abs(dy) > 0.000001 and dy < 0
			"?"
		characters = {}
		for index = 2, #stack
			fromNode = topology.nodes[tonumber stack[index - 1]]
			toNode = topology.nodes[tonumber stack[index]]
			table.insert characters, direction fromNode, toNode
			break if #characters >= maximum
		table.concat characters

	HasRuntimeState: =>
		return true if @__solutionCoroutine
		if @__playData and (@__playData.startTime or @__playData.endTime or
			@__playData.visualResult)
			return true
		return false unless @__pathFinder
		snapshot = @__pathFinder\snapshot!
		for stack in *(snapshot and snapshot.stacks or {})
			return true if istable(stack) and #stack > 1
		false

	SetTraceSessionId: (sessionId) =>
		@__playData or= {}
		@__playData.sessionId = sessionId
		true

	GetPlayDataSnapshot: =>
		return {} unless @__playData
		table.Copy @__playData
	GetAttemptController: => @__playData and @__playData.controller
	SetPlayData: (playData = {}) =>
		@__playData = table.Copy playData
		@__rtDirty = true if CLIENT
		true

	GetLastRuleReport: => @__lastRuleReport
	GetPredictedVisual: => @__predictedVisual
	SetVisualEventSerial: (serial) => @__lastVisualSerial = serial
	GetVisualEventSerial: => @__lastVisualSerial
	StoreVisualResult: (result) =>
		@__playData or= {}
		@__playData.visualResult = table.Copy result
		@__rtDirty = true if CLIENT
		true
	IsBulkImporting: => @__bulkImporting == true

	GetRuleRevision: => @__ruleDefinition and @__ruleDefinition.ruleRevision

	BeginPresentation: (attemptKey, silent = false, elapsed = 0) =>
		return false unless CLIENT and @__presentation
		-- The donor lifecycle only tears down attempt-owned loops here.
		-- Transient patches are independent and must be allowed to finish;
		-- stopping every cue made a new attempt audibly cut the previous cue.
		@StopPathCompleteLoop!
		@StopSound "SolvingLoop"
		@__exitPath = false
		now = CurTime!
		@__presentation\beginAttempt attemptKey, now - math.max(0, elapsed or 0)
		@ClearPresentationState!
		if silent
			@__presentation\drainCues!
			@SetLoop "SolvingLoop"
			@SetLoop "PresenceLoop", 0, 0
		@__rtDirty = true
		true

	BeginResetPresentation: (snapshot, serial = 0, replay = false) =>
		return false unless CLIENT and @__presentation and snapshot
		return false if serial > 0 and serial < (@__resetPresentationSerial or 0)
		return false if serial > 0 and serial == (@__resetPresentationSerial or 0) and
			not replay
		@__resetPresentationSerial = serial if serial > 0
		@BeginPresentation {
			id: -math.abs(serial)
			revision: snapshot.revision or 0
		}, true
		@ApplyVisualResult {
			aborted: true
			snapshot: snapshot
			feedback: {
				violations: {}
				erasures: {}
				remaining: {}
			}
		}, 0, false
		transitionSerial = serial
		timer.Simple Moonpanel.Canvas.PresentationConstants.AbortFade, ->
			return unless IsValid @__worldEntity
			return if transitionSerial > 0 and
				transitionSerial ~= @__resetPresentationSerial
			@ResetRuntime "reset-complete"
		true

	ResetRuntime: (reason = "reset") =>
		@ClearAttempt!
		@ResetTraceEngine!
		@__exitPath = false
		@ResetPresentation reason if CLIENT and @__presentation
		@__rtDirty = true if CLIENT
		true

	SetPresentationExit: (state, silent = false) =>
		return false unless CLIENT and @__presentation
		state = state == true
		@__exitPath = state
		changed = @__presentation\setExitContact state
		@__visualFrame = nil if changed
		@__presentation\drainCues! if silent
		@__rtDirty = true if changed
		changed

	SetObserverFollower: (follower) =>
		return unless CLIENT
		return if @__observerFollower == follower
		@__observerFollower = follower
		@__rtDirty = true

	HasObserverReached: (sequence) =>
		@__observerFollower and @__observerFollower\hasReached sequence or false

	GetTraceRenderState: =>
		return unless CLIENT and @__pathFinder
		return unless @__presentation and
			(@__presentation\isActive! or @__presentation\isFocusHintActive!)
		-- A completion result can arrive before the accessibility follower has
		-- rendered its endpoint. Keep the in-flight follower ahead of the terminal
		-- snapshot until it settles, otherwise the trace snaps to the exit.
		if @__observerFollower and not @__observerFollower\hasReached!
			return @__observerFollower\getRenderState!
		topology = @__pathFinder.topology
		sequence = @__playData and @__playData.finalSequence or 0
		if @__terminalSnapshot
			return Moonpanel.Canvas.BuildTraceRenderState topology,
				@__terminalSnapshot, sequence
		if @__observerFollower
			return @__observerFollower\getRenderState!
		snapshot = @__pathFinder\snapshot!
		Moonpanel.Canvas.BuildTraceRenderState topology, snapshot,
			sequence

	ApplyVisualResult: (result, elapsed = 0, silent = false, restored = false) =>
		return false unless CLIENT and @__presentation and result
		@__terminalSnapshot = table.Copy result.snapshot if result.snapshot
		-- Cue suppression and historical restoration are separate: live server
		-- repairs suppress duplicate sounds but must retain settlement animation.
		@__terminalSnapshotRestored = restored == true
		@__playData or= {}
		@__playData.endTime = CurTime! - math.max(0, elapsed or 0)
		@__playData.finalSequence = result.finalSequence or 0
		@__playData.visualResult = table.Copy result
		@__presentation\applyResult result, CurTime!, elapsed, silent
		@__visualFrame = nil
		if silent
			@StopSound "SolvingLoop"
			@SetLoop "PresenceLoop", 1, 0
		@__rtDirty = true
		true

	ResetPresentation: (reason = "reset") =>
		return unless CLIENT and @__presentation
		@__presentation\reset reason
		@ClearPresentationState!
		@StopPathCompleteLoop!
		@StopSound "SolvingLoop"
		@__rtDirty = true

	HandlePresentationCue: (cue) =>
		return unless CLIENT
		if cue == "PathCompleteStart"
			return if @__pathCompleteLoopActive
			@__pathCompleteLoopActive = true
			@SetLoop "PathCompleteLoop"
		elseif cue == "PathCompleteStop"
			@StopPathCompleteLoop!
		elseif cue == "SolvingStart"
			-- Match the donor panel lifecycle: bring the solving bed in under
			-- the start transient instead of opening another full-volume patch.
			@SetLoop "SolvingLoop", 1, 0.25, 0
		elseif cue == "SolvingStop"
			@SetLoop "SolvingLoop", 0, 0.25, 1
		elseif cue == "PresenceDuck"
			@SetLoop "PresenceLoop", 0, 5, 1
		elseif cue == "PresenceResume"
			@SetLoop "PresenceLoop", 1, 1, 0
		elseif PRESENTATION_SOUND_CUES[cue]
			@PlaySound cue, (cue == "Scint" or cue == "StartScint") and
				0.25 * (@__visualFrame and @__visualFrame.scintPower or 1) or 1

	-----------------------------------------------------------
	-- Applies an already-quantized deterministic input sample. --
	-- Rendering and networking consume this same canonical     --
	-- state; no visual push/pop events are generated.          --
	-----------------------------------------------------------
	ApplyTraceSample: (xQ, yQ, boost = false, controllingPly = nil,
		constraintDecisions = nil) =>
		return false unless @__pathFinder
		changed = @__pathFinder\applySample xQ, yQ, boost, controllingPly,
			constraintDecisions
		return false unless changed

		@__rtDirty = true if CLIENT
		touchingExit = @__pathFinder.touchingExit == true
		@__playData.touchingExit = touchingExit if @__playData

		exitPath = @__pathFinder\isExitPath!
		if CLIENT and @__presentation and exitPath ~= @__exitPath
			@__exitPath = exitPath
			@__presentation\setExitContact exitPath

		true

	QuantizeDeltas: (x, y, sensitivity = 1) =>
		-- Sensitivity is a user multiplier over the original panel feel. The
		-- quarter-scale prevents one ordinary mouse sample crossing an edge.
		scale = 0.25 * Moonpanel.Canvas.TraceEngine.Units /
			math.max(@GetBarLength!, 0.000001)
		meta = @__data and @__data.Meta or {}
		largestDimension = math.max 3,
			math.floor(tonumber(meta.Width) or 3),
			math.floor(tonumber(meta.Height) or 3)
		scale *= math.Clamp math.pow(3 / largestDimension, 1.5), 0.2, 1
		math.Round(x * sensitivity * scale), math.Round(y * sensitivity * scale)

	-- Compatibility entrypoint for local/editor callers. Network play uses
	-- ApplyTraceSample so client and server receive the identical integers.
	ApplyDeltas: (x, y, boost = false) =>
		xQ, yQ = @QuantizeDeltas x, y
		@ApplyTraceSample xQ, yQ, boost

	-------------------------------------------------
	-- Starts a new game using the provided point. --
	-------------------------------------------------
	Start: (ply, node) =>
		return unless @__pathFinder
		compatibility = @GetSurfaceCompatibility!
		return if compatibility and not compatibility.playable
		nodeId = if "number" == type node then node else
			@__pathFinder.topology.nodeIds[node]
		return unless nodeId
		return unless @__pathFinder\start nodeId

		@__rtDirty = true if CLIENT

		@ResetSolver!
		@__playData = {
			startTime: CurTime!
			controller: ply
			touchingExit: false
		}
		@__exitPath = false

		@StopPathCompleteLoop!

		if CLIENT
			@__localAttemptId = (@__localAttemptId or 0) + 1
			@BeginPresentation {
				id: @__localAttemptId
				revision: @__pathFinder.topology.revision
			}

		true

	---------------------------------------------------
	-- Ends the current game if there's one going. --
	---------------------------------------------------
	End: (forceAbort) =>
		@StopPathCompleteLoop!

		return if @__playData.endTime
		return if SERVER and not IsValid @__worldEntity

		-- Keep an accessibility submit from making a partially traced exit
		-- disappear or snap to its endpoint. Seed the observer follower with the
		-- live geometry, then target the canonical post-evaluation snapshot so
		-- the rendered head travels the same short distance as the engine nudge.
		pathfinder = @__pathFinder
		nudgeExitAnimation = CLIENT and forceAbort ~= true and pathfinder and
			pathfinder\NeedsExitNudge!
		partialTraceSnapshot = pathfinder\snapshot! if nudgeExitAnimation
		if nudgeExitAnimation
			@SetObserverFollower makeObserverFollower(
				pathfinder.topology, partialTraceSnapshot)
			@SetPresentationExit true

		@__playData.endTime = CurTime!

		@__playData.wasAborted = forceAbort == true or not @__pathFinder\canSubmit!

		if @__playData.wasAborted
			@__pathFinder\SetFeedback!
			return @FinishSolution!

		@__pathFinder\beginEvaluation!
		@__observerFollower\setTarget @__pathFinder\snapshot!, 1 if nudgeExitAnimation

		crt, createError = @CreateSolutionCoroutine!
		if crt
			@__solutionCoroutine = crt

			@SolutionCoroutineThink!
			return true

		@FinishSolution {
			status: createError or "error"
			success: false
		}

	-------------
	-- Thonks. --
	-------------
	Think: =>
		Moonpanel.Canvas.RuleEngine.PruneCache @__ruleCache if @__ruleCache
		return if not @__playData and not CLIENT

		if CLIENT and @__clientData
			if @__presentation
				focusTarget = @IsLocalFocusHintTarget!
				focusHintChanged = @__presentation\setFocusHint focusTarget, CurTime!
				if focusHintChanged
					@__visualFrame = nil
					@__rtDirty = true
			if @__powerState ~= nil
				targetPower = @__powerState and 1 or 0
				if @__powerStateBuffer ~= targetPower
					@__powerStateBuffer += FrameTime! * (@__powerState and 1 or -1)
					@__powerStateBuffer = math.Clamp @__powerStateBuffer, 0, 1

			if @__observerFollower
				_, geometryChanged = @__observerFollower\update FrameTime!
				@__rtDirty = true if geometryChanged

			if @__presentation and (not @__visualFrame or
					@__visualFrame.needsSampling)
				previousFrame = @__visualFrame
				@__visualFrame, cues = @__presentation\sample CurTime!
				@HandlePresentationCue cue for cue in *cues
				-- Repaint throughout a timeline and once more when it settles so the
				-- final sampled values reach the RT without leaving it perpetually dirty.
				@__rtDirty = true if @__visualFrame.needsAnimation or
					(previousFrame and previousFrame.needsAnimation)

		if @__solutionCoroutine
			@SolutionCoroutineThink!

	FinishSolution: (solutionData) =>
		Moonpanel.Canvas.ReleaseVerifier @ if Moonpanel.Canvas.ReleaseVerifier
		@SetTraceFeedback!
		report = solutionData and solutionData.ruleReport
		result = {
			ruleRevision: report and report.ruleRevision
			reportHash: report and report.reportHash
		}
		if not solutionData or solutionData.status and solutionData.status ~= "complete"
			result.aborted = true
			result.evaluationError = solutionData and solutionData.status or nil
			result.ruleRevision or= 0
			result.reportHash or= 0
		else
			result.success = solutionData.success
			result.feedback = solutionData.feedback

		if CLIENT
			result.snapshot = @__pathFinder\snapshot! if @__pathFinder
			@__predictedVisual = {
				aborted: result.aborted == true
				ruleRevision: result.ruleRevision or 0
				reportHash: result.reportHash or 0
			}
			@ApplyVisualResult result
		else
			Moonpanel.Net.BroadcastVisualResult @__worldEntity, result

		true

Moonpanel.Canvas.Canvas = Canvas

-- Include partial class files.
if CLIENT
	include "cl_canvas.lua"
else
	AddCSLuaFile "cl_canvas.lua"
	AddCSLuaFile "cl_presentation.lua"
	AddCSLuaFile "sh_canvas_solution.lua"

include "sh_canvas_solution.lua"

Moonpanel.Canvas.RT
