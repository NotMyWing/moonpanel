Moonpanel.Canvas or= {}

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

Moonpanel.Canvas.Resolution = 512

-- Shared screen-matrix construction helpers used by both client and server.
-- Monitor_Offsets maps model paths to screen transform parameters.
Moonpanel.Canvas.Monitor_Offsets = {
    ["models//cheeze/pcb/pcb4.mdl"]: {
        Name: "pcb4.mdl", RS: 0.0625, RatioX: 1,
        offset: Vector(0, 0, 0.5), rot: Angle(0, 0, 180),
        x1: -16, x2: 16, y1: -16, y2: 16, z: 0.5
    },
    ["models//cheeze/pcb/pcb5.mdl"]: {
        Name: "pcb5.mdl", RS: 0.0625, RatioX: 0.508,
        offset: Vector(-0.5, 0, 0.5), rot: Angle(0, 0, 180),
        x1: -31.5, x2: 31.5, y1: -16, y2: 16, z: 0.5
    },
    ["models//cheeze/pcb/pcb6.mdl"]: {
        Name: "pcb6.mdl", RS: 0.09375, RatioX: 0.762,
        offset: Vector(-0.5, -8, 0.5), rot: Angle(0, 0, 180),
        x1: -31.5, x2: 31.5, y1: -24, y2: 24, z: 0.5
    },
    ["models//cheeze/pcb/pcb7.mdl"]: {
        Name: "pcb7.mdl", RS: 0.125, RatioX: 1,
        offset: Vector(0, 0, 0.5), rot: Angle(0, 0, 180),
        x1: -32, x2: 32, y1: -32, y2: 32, z: 0.5
    },
    ["models//cheeze/pcb/pcb8.mdl"]: {
        Name: "pcb8.mdl", RS: 0.125, RatioX: 0.668,
        offset: Vector(15.885, 0, 0.5), rot: Angle(0, 0, 180),
        x1: -47.885, x2: 47.885, y1: -32, y2: 32, z: 0.5
    },
    ["models/cheeze/pcb2/pcb8.mdl"]: {
        Name: "pcb8.mdl", RS: 0.2475, RatioX: 0.99,
        offset: Vector(0, 0, 0.3), rot: Angle(0, 0, 180),
        x1: -64, x2: 64, y1: -63.36, y2: 63.36, z: 0.3
    },
    ["models/blacknecro/tv_plasma_4_3.mdl"]: {
        Name: "Plasma TV (4:3)", RS: 0.082, RatioX: 0.751,
        offset: Vector(0, -0.1, 0), rot: Angle(0, 0, -90),
        x1: -27.87, x2: 27.87, y1: -20.93, y2: 20.93, z: 0.1
    },
    ["models/hunter/blocks/cube1x1x1.mdl"]: {
        Name: "Cube 1x1x1", RS: 0.09, RatioX: 1,
        offset: Vector(24, 0, 0), rot: Angle(0, 90, -90),
        x1: -48, x2: 48, y1: -48, y2: 48, z: 24
    },
    ["models/hunter/plates/plate05x05.mdl"]: {
        Name: "Panel 0.5x0.5", RS: 0.045, RatioX: 1,
        offset: Vector(0, 0, 1.7), rot: Angle(0, 90, 180),
        x1: -48, x2: 48, y1: -48, y2: 48, z: 0
    },
    ["models/hunter/plates/plate1x1.mdl"]: {
        Name: "Panel 1x1", RS: 0.09, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -48, x2: 48, y1: -48, y2: 48, z: 0
    },
    ["models/hunter/plates/plate2x2.mdl"]: {
        Name: "Panel 2x2", RS: 0.182, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -48, x2: 48, y1: -48, y2: 48, z: 0
    },
    ["models/hunter/plates/plate4x4.mdl"]: {
        Name: "plate4x4.mdl", RS: 0.3707, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -94.9, x2: 94.9, y1: -94.9, y2: 94.9, z: 1.7
    },
    ["models/hunter/plates/plate8x8.mdl"]: {
        Name: "plate8x8.mdl", RS: 0.741, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -189.8, x2: 189.8, y1: -189.8, y2: 189.8, z: 1.7
    },
    ["models/hunter/plates/plate16x16.mdl"]: {
        Name: "plate16x16.mdl", RS: 1.482, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -379.6, x2: 379.6, y1: -379.6, y2: 379.6, z: 1.7
    },
    ["models/hunter/plates/plate24x24.mdl"]: {
        Name: "plate24x24.mdl", RS: 2.223, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -569.4, x2: 569.4, y1: -569.4, y2: 569.4, z: 1.7
    },
    ["models/hunter/plates/plate32x32.mdl"]: {
        Name: "plate32x32.mdl", RS: 2.964, RatioX: 1,
        offset: Vector(0, 0, 2), rot: Angle(0, 90, 180),
        x1: -759.2, x2: 759.2, y1: -759.2, y2: 759.2, z: 1.7
    },
    ["models/kobilica/wiremonitorbig.mdl"]: {
        Name: "Monitor Big", RS: 0.045, RatioX: 0.991,
        offset: Vector(0.2, -0.4, 13), rot: Angle(0, 0, -90),
        x1: -11.5, x2: 11.6, y1: 1.6, y2: 24.5, z: 0.2
    },
    ["models/kobilica/wiremonitorsmall.mdl"]: {
        Name: "Monitor Small", RS: 0.0175, RatioX: 1,
        offset: Vector(0, -0.4, 5), rot: Angle(0, 0, -90),
        x1: -4.4, x2: 4.5, y1: 0.6, y2: 9.5, z: 0.3
    },
    ["models/props/cs_assault/billboard.mdl"]: {
        Name: "Billboard", RS: 0.23, RatioX: 0.522,
        offset: Vector(2, 0, 0), rot: Angle(0, 90, -90),
        x1: -110.512, x2: 110.512, y1: -57.647, y2: 57.647, z: 1
    },
    ["models/props/cs_office/computer_monitor.mdl"]: {
        Name: "LCD Monitor (4:3)", RS: 0.031, RatioX: 0.767,
        offset: Vector(3.3, 0, 16.7), rot: Angle(0, 90, -90),
        x1: -10.5, x2: 10.5, y1: 8.6, y2: 24.7, z: 3.3
    },
    ["models/props/cs_office/tv_plasma.mdl"]: {
        Name: "Plasma TV (16:10)", RS: 0.065, RatioX: 0.5965,
        offset: Vector(6.1, 0, 18.93), rot: Angle(0, 90, -90),
        x1: -28.5, x2: 28.5, y1: 2, y2: 36, z: 6.1
    },
    ["models/props_lab/monitor01b.mdl"]: {
        Name: "Small TV", RS: 0.0185, RatioX: 1.0173,
        offset: Vector(6.53, -1, 0.45), rot: Angle(0, 90, -90),
        x1: -5.535, x2: 3.5, y1: -4.1, y2: 5.091, z: 6.53
    },
    ["models/props_lab/workspace002.mdl"]: {
        Name: "Workspace 002", RS: 0.06836, RatioX: 0.9669,
        offset: Vector(-42.133224, -42.372322, 42.110897), rot: Angle(0, 133.340, -120.317),
        x1: -18.1, x2: 18.1, y1: -17.5, y2: 17.5, z: 42.1109
    },
    ["models/props_mining/billboard001.mdl"]: {
        Name: "TF2 Red billboard", RS: 0.375, RatioX: 0.5714,
        offset: Vector(3.5, 0, 96), rot: Angle(0, 90, -90),
        x1: -168, x2: 168, y1: -96, y2: 96, z: 96
    },
    ["models/props_mining/billboard002.mdl"]: {
        Name: "TF2 Red vs Blue billboard", RS: 0.375, RatioX: 0.3137,
        offset: Vector(3.5, 0, 192), rot: Angle(0, 90, -90),
        x1: -306, x2: 306, y1: -96, y2: 96, z: 192
    },
}

-- Resolve screen info for an entity and model name.
-- Returns the model-specific offset table or a fallback computed from bounding box.
Moonpanel.Canvas.ResolveScreenInfo = (ent, modelName) ->
    info = Moonpanel.Canvas.Monitor_Offsets[modelName]
    if info
        return info

    -- Fallback: compute from entity bounding box
    -- Use explicit dot-call form to avoid MoonScript compiler bug
    -- that turns `ent:Method()` into `{ent = Method()}` table literal
    mins = ent\OBBMins!
    maxs = ent\OBBMaxs!
    size = maxs - mins

    if size.x > size.y
        aux = size.y
        size.y = size.x
        size.x = aux

    return {
        Name: modelName or ""
        RS: size.y / Moonpanel.Canvas.Resolution
        RatioX: size.y / size.x
        offset: ent.OBBCenter(ent) + Vector(0, 0, maxs.z - 0.24)
        rot: Angle(0, 90, 180)
        x1: 0
        x2: 0
        y1: 0
        y2: 0
        z: 0
    }

-- Build screen matrix from resolved info.
-- Called by both client and server for parity.
Moonpanel.Canvas.BuildScreenMatrix = (info) ->
    res = Moonpanel.Canvas.Resolution
    rotation, translation, translation2, scale = Matrix!, Matrix!, Matrix!, Matrix!
    scalefactor = 512 / res

    rotation\SetAngles          info.rot
    translation\SetTranslation  info.offset
    translation2\SetTranslation Vector -(res * 0.5) / info.RatioX, -(res * 0.5), 0
    scale\SetScale              scalefactor * Vector info.RS, info.RS, info.RS

    return translation * rotation * scale * translation2

AddCSLuaFile!
AddCSLuaFile "cl_dcanvas.lua"
AddCSLuaFile "cl_rtpool.lua"
AddCSLuaFile "cl_colorutils.lua"
AddCSLuaFile "cl_presentation.lua"
AddCSLuaFile "sh_dlx.lua"
AddCSLuaFile "sh_polyomino.lua"
AddCSLuaFile "sh_rule_engine.lua"
AddCSLuaFile "sh_canvas_fixtures.lua"
AddCSLuaFile "sh_surface.lua"
AddCSLuaFile "sh_continuous_topology.lua"
AddCSLuaFile "editor/sh_document.lua"
AddCSLuaFile "editor/cl_store.lua"
AddCSLuaFile "editor/cl_editor.lua"

Moonpanel.Canvas.DLX = include "sh_dlx.lua"
include "sh_surface.lua"
include "sh_paneldata.lua"
include "sh_polyomino.lua"
Moonpanel.Canvas.RuleEngine = include "sh_rule_engine.lua"
include "sh_pathfinder.lua"
include "sh_entities.lua"
include "sh_entitysocket.lua"
include "sh_continuous_topology.lua"
Moonpanel.EditorDocument = include "editor/sh_document.lua"

if CLIENT
	include "cl_dcanvas.lua"
	include "cl_rtpool.lua"
	include "cl_presentation.lua"
	include "editor/cl_store.lua"
	include "editor/cl_editor.lua"
else
	resource.AddFile "materials/moonpanel/circle.png"

ST = { Type: "Start" }
EN = { Type: "End" }
CL = { Type: "Color" }

Moonpanel.Canvas.SampleData = {
	Meta: {
		Width: 3
		Height: 3
		Symmetry: 0
	}

	Dim: {
		BarLength: 25
		BarWidth: 4
		AutoBarWidth: true
	}

	Entities: {
		{}, {}, {}, {}, {}, {}, EN,
		{}, {}, {}, {}, {}, CL, {},
		{}, {}, {}, {}, {}, {}, {},
		{}, {}, {}, {}, {}, {}, {},
		{}, {}, {}, {}, {}, {}, {},
		{}, CL, {}, {}, {}, {}, {},
		ST, {}, {}, ST, {}, {}, {}
	}
}

PANEL_SOUNDS_LEVEL = 65
PANEL_SOUNDS = {
	Scint: {
		Path: "moonpanel/panel_scint.ogg"
	}
	StartScint: {
		Path: "moonpanel/panel_scint_startpoint.ogg"
	}
	Start: {
		Path: "moonpanel/panel_start_tracing.ogg"
	}
	PathCompleteLoop: {
		Path: "moonpanel/panel_path_complete_loop.wav"
		SoundLevel: 45
	}
	SolvingLoop: {
		Path: "moonpanel/panel_solving_loop.wav"
		SoundLevel: 40
	}
	PresenceLoop: {
		Path: "moonpanel/panel_presence_loop.wav"
		SoundLevel: 40
	}
	FinishTracing: {
		Path: "moonpanel/panel_finish_tracing.ogg"
	}
	AbortFinishTracing: {
		Path: "moonpanel/panel_abort_finish_tracing.ogg"
	}
}

PANEL_CSOUNDS = {
	PowerOn: {
		Path: "moonpanel/powered_on.ogg"
	}
	PowerOff: {
		Path: "moonpanel/powered_off.ogg"
	}
	Failure: {
		Path: "moonpanel/panel_failure.ogg"
	}
	PotentialFailure: {
		Path: "moonpanel/panel_potential_failure.ogg"
	}
	Success: {
		Path: "moonpanel/panel_success.ogg"
	}
	Eraser: {
		Path: "moonpanel/eraser_apply.ogg"
	}
	Abort: {
		Path: "moonpanel/panel_abort_tracing.ogg"
	}
}

PANEL_PRESET_FILES = {
	Start: "panel_start_tracing.ogg"
	StartScint: "panel_scint_startpoint.ogg"
	Scint: "panel_scint_endpoint.ogg"
	FinishTracing: "panel_finish_tracing.ogg"
	AbortFinishTracing: "panel_abort_finish_tracing.ogg"
	Failure: "panel_failure.ogg"
	PotentialFailure: "panel_potential_failure.ogg"
	Success: "panel_success.ogg"
	Abort: "panel_abort_tracing.ogg"
}

class Canvas
	new: (data) =>
		@__playData = {}
		@__surface = Moonpanel.Canvas.MakeSurfaceSpec!
		@__soundEnabled = true
		@__presentation = Moonpanel.Canvas.TracePresentation! if CLIENT
		@ImportData data if data

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

	-- A continuous board has one physical seam column. The authored right
	-- boundary remains an import slot, but valid boards render and target the
	-- canonical left slot. Conflicts keep both sides visible for repair.
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

	-- Offset a canvas-world point toward the eye position so the trace
	-- hull clears the panel back-face by a scale-aware epsilon.
	TargetFor: (point, eyePos, epsilon) =>
		dir = eyePos - point
		dist = dir\Length!
		return point if dist < 0.001
		return point + dir / dist * epsilon

	_IsTraceBlocked: (trace) =>
		trace and (trace.StartSolid or trace.AllSolid or
			trace.Hit and (trace.Fraction or 0) < 1) or false

	_TraceOcclusionLine: (startPos, endPos, filter) =>
		-- This runs for every forward input sample. Reuse both the trace config
		-- and its documented output table instead of allocating one result table
		-- per fanout/refinement ray.
		@__occlusionTrace or= { output: {} }
		trace = @__occlusionTrace
		trace.start = startPos
		trace.endpos = endPos
		trace.filter = filter
		util.TraceLine trace

	_DebugOcclusionRay: (stage, index, startPos, endPos, trace) =>
		return unless CLIENT and Moonpanel.Debug and
			Moonpanel.Debug.RecordOcclusionRay
		Moonpanel.Debug\RecordOcclusionRay @__worldEntity, stage, index,
			startPos, endPos, trace

	-- Coarse-sample a segment for occlusion, then refine the first
	-- blocked interval in parameter space. Returns the progress fraction
	-- in [0, 1] where 1 means fully visible.
	SampleSegmentVisibility: (eyePos, startWorld, endWorld, filter, sampleCount, epsilon) =>
		if sampleCount < 1
			return 1

		-- Trace the starting point first: if the current position is
		-- already hidden, the edge must stop here.
		startTarget = @TargetFor startWorld, eyePos, epsilon
		tr = @_TraceOcclusionLine eyePos, startTarget, filter
		@_DebugOcclusionRay "start", 0, eyePos, startTarget, tr

		if @_IsTraceBlocked tr
			return 0

		-- Endpoint-inclusive sampling: t = i / sampleCount ensures the
		-- very tip of the segment is always tested.
		for i = 1, sampleCount
			t = i / sampleCount
			sampleWorld = startWorld + (endWorld - startWorld) * t
			sampleTarget = @TargetFor sampleWorld, eyePos, epsilon
			tr = @_TraceOcclusionLine eyePos, sampleTarget, filter
			@_DebugOcclusionRay "fanout", i, eyePos, sampleTarget, tr

			if @_IsTraceBlocked tr
				-- Binary refine between previous clear and this blocked sample.
				loT = (i - 1) / sampleCount
				hiT = t
				return @BinaryRefineInT eyePos, startWorld, endWorld,
					loT, hiT, filter, epsilon

		-- All samples passed; nothing to refine.
		return 1

	-- Bounded binary search in parameter space between loT (clear) and
	-- hiT (blocked). Return the absolute last-clear fraction. Returning an
	-- interval length here loses the location of every interval after the
	-- first one and makes mirrored heads clamp at unrelated positions.
	BinaryRefineInT: (eyePos, startWorld, endWorld, loT, hiT, filter, epsilon) =>
		for iteration = 1, 10
			midT = (loT + hiT) * 0.5
			midWorld = startWorld + (endWorld - startWorld) * midT
			midTarget = @TargetFor midWorld, eyePos, epsilon
			tr = @_TraceOcclusionLine eyePos, midTarget, filter
			@_DebugOcclusionRay "refine", iteration, eyePos, midTarget, tr

			if @_IsTraceBlocked tr
				hiT = midT
			else
				loT = midT

		loT

	-- Offset a canvas position to the leading edge of the round trace head.
	-- Testing the centre (or the trailing edge) permits half a bar of visible
	-- trace to enter an obstacle before movement is constrained.
	_CanvasTipOffset: (pos, edge, barWidth) =>
		return pos unless edge and edge.unitX ~= nil
		halfBar = barWidth * 0.5
		{x: pos.x + edge.unitX * halfBar,
		y: pos.y + edge.unitY * halfBar}

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

	-- Main occlusion check. Returns a visibility fraction in [0, 1] for
	-- the forward direction only; retraction is never clamped.
	CheckOcclusion: (ply, primaryEdge, oldProgress, candidateProgress) =>
		return 1 unless IsValid ply

		renderTransform = @GetWorldTransform!
		return 1 unless renderTransform or @__worldEntity and
			@__worldEntity.CanvasToWorld

		-- Compute scale-aware epsilon from the transform itself: how far
		-- does one panel bar-width extend in world space?
		p0 = @CanvasPointToWorld { x: 0, y: 0 }, renderTransform
		barWidthWorld = @__pathFinder and @__pathFinder.topology and @__pathFinder.topology.barWidth or 1
		px = @CanvasPointToWorld { x: barWidthWorld, y: 0 }, renderTransform
		return 1 unless p0 and px
		epsilon = math.Clamp(p0\Distance(px) * 0.01, 0.02, 0.2)
		eyePos = ply\EyePos!
		-- Environmental occlusion belongs to the controlled primary head only.
		-- The secondary branch still follows the resulting shared progress, but
		-- its own line of sight never constrains that progress.
		unless @__occlusionFilter and @__occlusionFilter[1] == ply and
				@__occlusionFilter[2] == @__worldEntity
			@__occlusionFilter = { ply, @__worldEntity }
		filter = @__occlusionFilter
		barWidth = @__pathFinder.topology.barWidth
		if CLIENT and Moonpanel.Debug and Moonpanel.Debug.BeginOcclusion
			Moonpanel.Debug\BeginOcclusion @__worldEntity, primaryEdge,
				oldProgress, candidateProgress
		fraction = @_EdgeVisibility eyePos, renderTransform, primaryEdge, oldProgress,
			candidateProgress, barWidth, filter, epsilon
		if CLIENT and Moonpanel.Debug and Moonpanel.Debug.EndOcclusion
			Moonpanel.Debug\EndOcclusion @__worldEntity, fraction
		fraction

	-- Lifecycle helper: bind/unbind the occlusion constraint on the
	-- pathfinder. Called from InitPathFinder and SetWorldEntity so the
	-- constraint follows the panel's world-entity lifecycle.
	BindWorldOcclusion: =>
		if not @__pathFinder
			return
		if @__worldEntity and IsValid(@__worldEntity)
			@__pathFinder.occlusionConstraint = @__occlusionCheck or (
				(ply, primaryEdge, oldProgress, candidateProgress) ->
					fraction = math.Clamp(@CheckOcclusion(
						ply, primaryEdge, oldProgress, candidateProgress) or 1, 0, 1)
					math.floor(oldProgress +
						(candidateProgress - oldProgress) * fraction)
			)
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
		if @__soundEnabled == enabled
			@SetupSounds! if enabled and not @__sounds
			return false
		@StopSounds! unless enabled
		@__soundEnabled = enabled
		@SetupSounds! if enabled and not @__sounds
		true

	GetSoundEnabled: => @__soundEnabled == true

	GetSoundPreset: =>
		name = @__data and @__data.Sounds and @__data.Sounds.Preset
		if not name or not Moonpanel.Canvas.SoundPresets[name]
			return Moonpanel.Canvas.DefaultSoundPreset
		name

	GetSoundDefinitions: =>
		definitions = {}
		for soundName, soundData in pairs PANEL_SOUNDS
			definitions[soundName] = {
				Path: soundData.Path
				SoundLevel: soundData.SoundLevel
			}
		if CLIENT
			for soundName, soundData in pairs PANEL_CSOUNDS
				definitions[soundName] = {
					Path: soundData.Path
					SoundLevel: soundData.SoundLevel
				}

		preset = Moonpanel.Canvas.ResolveSoundPreset @GetSoundPreset!
		if preset and preset.Directory ~= ""
			for cue in *Moonpanel.Canvas.SoundCueRoles
				fileName = PANEL_PRESET_FILES[cue]
				if fileName and definitions[cue]
					definitions[cue].Path = "moonpanel/#{preset.Directory}/#{fileName}"
		definitions

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
		@__sounds = {}

		target = if SERVER and IsValid @__worldEntity
			@__worldEntity
		elseif CLIENT and @__worldEntity
			@__worldEntity
		elseif CLIENT and not IsValid @__worldEntity
			LocalPlayer!

		return if not target
		definitions = @GetSoundDefinitions!
		for soundName, soundData in pairs definitions
			sound = CreateSound target, soundData.Path
			sound\SetSoundLevel soundData.SoundLevel or PANEL_SOUNDS_LEVEL

			@__sounds[soundName] = sound

	ReconfigureSounds: =>
		return unless @__sounds
		@StopSounds!
		@__sounds = nil
		@SetupSounds! if @__soundEnabled

	StopSound: (sound) =>
		return if not @__sounds

		sound = @__sounds[sound] if "string" == type sound
		return if not sound

		sound\Stop! if sound\IsPlaying!
		sound\Stop!

	StopPathCompleteLoop: =>
		@__pathCompleteLoopActive = false
		@StopSound "PathCompleteLoop"

	StopSounds: =>
		return if not @__sounds

		for _, sound in pairs @__sounds
		    sound\Stop!

	PlaySound: (sound, volume = 1, pitch = 100) =>
		return unless @__soundEnabled and @__sounds

		if "string" == type sound
			return if @IsSoundSuppressed sound
			sound = @__sounds[sound]
		return if not sound

		sound\Stop! if sound\IsPlaying!
		sound\PlayEx volume, pitch

	SetLoop: (sound, volume = 1, fade = 0.1, startVolume = nil) =>
		return unless @__soundEnabled and @__sounds
		if "string" == type sound
			return if @IsSoundSuppressed sound
			sound = @__sounds[sound]
		return unless sound
		wasPlaying = sound\IsPlaying!
		unless wasPlaying
			sound\PlayEx startVolume ~= nil and startVolume or volume, 100
		if wasPlaying or startVolume ~= nil
			sound\ChangeVolume volume, fade

	IsLocalController: (ply = LocalPlayer!) =>
		if SERVER
			return false
		else
			return true if @__worldEntity == nil
			if IsValid @__worldEntity
				return LocalPlayer! == ply

			return false

	SetSymmetryType: (type) =>
		return if not @__data

		@__data.Meta.Symmetry = type

		@RebuildPathFinderCache!

	GetSymmetryType: =>
		return if not @__data

		@__data.Meta.Symmetry

	GetPathNodes: => @__nodes

	GetColors: =>
		dataColors = @__data and @__data.Colors or {}

		colors = {
			Background: dataColors.Background or Canvas.DefaultColors.Background
			Grid: dataColors.Untraced or Canvas.DefaultColors.Untraced
			Error: dataColors.Errored or Canvas.DefaultColors.Errored
			Cell: dataColors.Cell or Canvas.DefaultColors.Cell
			Vignette: dataColors.Vignette or Canvas.DefaultColors.Vignette
			Trace: {
				dataColors.Traced or Canvas.DefaultColors.Traced, {
					r: 255
					g: 255
					b: 116
				}
			}
			EndTrace: {
				dataColors.Finished or Canvas.DefaultColors.Finished, {
					r: 0
					g: 255
					b: 0
				}
			}
		}

		symmetryOptions = @__data and @__data.Meta and @__data.Meta.SymmetryOptions
		traces = symmetryOptions and symmetryOptions.Traces
		if traces
			for i = 1, 2
				if traces[i] and traces[i].ColorValue
					colors.Trace[i] = traces[i].ColorValue

		if symmetryOptions and symmetryOptions.Colorful
			for i = 1, 2
				trace = colors.Trace[i]
				colors.EndTrace[i] = {
					r: math.Round trace.r * 0.72
					g: math.Round trace.g * 0.72
					b: math.Round trace.b * 0.72
					a: trace.a or 255
				}
		else
			colors.EndTrace[2] = colors.EndTrace[1]

		colors

	------------------------------------
	-- Imports data from given table. --
	------------------------------------
	ImportData: (data) =>
		Moonpanel.Canvas.ReleaseVerifier @ if @__solutionCoroutine and
			Moonpanel.Canvas.ReleaseVerifier
		@__solutionCoroutine = nil
		@__solutionData = nil
		@__lastRuleReport = nil
		@__predictedVisual = nil
		@__playData = {}
		@__observerFollower = nil
		@__terminalSnapshot = nil
		@__terminalSnapshotRestored = false

		previousSoundPreset = @GetSoundPreset!
		@__data = data and Moonpanel.Canvas.SanitizeData data
		if @__data and previousSoundPreset ~= @GetSoundPreset! and @__sounds
			@ReconfigureSounds!
		if @__data
			@__surface = Moonpanel.Canvas.MakeSurfaceSpec @GetSurfaceSpec!.kind,
				@__data.Meta.Continuous
			if @__surface.continuous
				@__data = Moonpanel.Canvas.CanonicalizeContinuousData @__data
		@__surfaceCompatibility = @__data and
			Moonpanel.Canvas.GetSurfaceCompatibility(@__data, @GetSurfaceSpec!) or nil
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

		@OnImportData @__data if @OnImportData ~= nil

		@ResetPresentation "topology-change" if CLIENT and @__presentation

		if not @__data
			@__data = nil
			@__geometry = nil
			@__pathFinder = nil
			@__clientData = nil
			@__socketArrays = nil

			return

		ents = @__data.Entities or {}

		numCols = @__data.Meta.Width  * 2 + 1
		numRows = @__data.Meta.Height * 2 + 1

		@__sockets = {}
		with @__socketArrays = {}
			.cells = {}
			.vpaths = {}
			.hpaths = {}
			.intersections = {}

		entityInfos = {}

		orderedSocketArrays = {
			@__socketArrays.intersections
			@__socketArrays.hpaths
			@__socketArrays.vpaths
			@__socketArrays.cells
		}

		for t in *orderedSocketArrays
			table.insert @__sockets, t

		-- Initialize the node map.
		for i = 1, numCols * numRows
			row = math.ceil i / numCols
			column = 1 + (i - 1) % numCols

			local socketClass, dest, isHorizontalPath

			if row % 2 == 1
				-- Intersection
				if column % 2 == 1
					dest = @__socketArrays.intersections
					socketClass = Moonpanel.Canvas.Sockets.IntersectionSocket
				-- HBar
				else
					isHorizontalPath = true

					dest = @__socketArrays.hpaths
					socketClass = Moonpanel.Canvas.Sockets.PathSocket
			else
				-- VBar
				if column % 2 == 1
					isHorizontalPath = false

					dest = @__socketArrays.vpaths
					socketClass = Moonpanel.Canvas.Sockets.PathSocket
				-- Cell
				else
					dest = @__socketArrays.cells
					socketClass = Moonpanel.Canvas.Sockets.CellSocket

			entityClass = ents[i] and Moonpanel.Canvas.GetEntityClass ents[i].Type, socketClass.SocketType
			entityClass or= socketClass.BaseEntity

			socket = socketClass @, #dest + 1
			if isHorizontalPath ~= nil
				socket\SetHorizontal isHorizontalPath

			table.insert entityInfos, {
				socket: socket
				class: entityClass
				data: ents[i] and ents[i].Data
			}

			table.insert dest, socket

		@RebuildNodes!
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

	RebuildPathFinderCache: =>
		return unless @__data
		@InitPathFinder!

		if CLIENT
			@RecalculateClient!
			@__rtDirty = true

	GetBarWidth: => @__geometry and @__geometry.barWidth or 1

	GetBarLength: => @__geometry and @__geometry.barLength or 1
	GetVerticalBarLength: => @__geometry and
		(@__geometry.verticalBarLength or @__geometry.barLength) or 1

	noop = ->
	GetSocketIterator: =>
		return noop if not @__sockets

		curTable = 1
		curLength = #@__sockets[1]
		curIndex = 1

		->
			if @__sockets[curTable]
				while curIndex > curLength
					curTable += 1
					return if not @__sockets[curTable]

					curLength = #@__sockets[curTable]
					curIndex = 1

				curIndex += 1
				return @__sockets[curTable][curIndex - 1]

	translateXY = (table, x, y, width, height, socket) ->
		return if x > width or y > height or x <= 0 or y <= 0

		index = 1 + (x - 1) + (y - 1) * width

		if socket
			table[index] = socket
		else
			return table[index]

	--------------------------------------------------------
	-- Returns the first entity at given SCREEN position. --
	--------------------------------------------------------
	GetEntityAtScreen: (scrX, scrY) =>
		return if not @__socketArrays
		return if not @__data

		for entity in @GetSocketIterator!
			continue if @IsHiddenContinuousSocket entity
			return entity if entity\CanClick scrX, scrY

	------------------------------------------
	-- Gets intersection at given position. --
	------------------------------------------
	GetIntersectionSocketAt: (x, y) =>
		return if not @__data
		translateXY @__socketArrays.intersections, x, y,
			@__data.Meta.Width + 1,
			@__data.Meta.Height + 1

	----------------------------------
	-- Gets hpath at given position. --
	----------------------------------
	GetHPathSocketAt: (x, y) =>
		return if not @__data
		translateXY @__socketArrays.hpaths, x, y,
			@__data.Meta.Width,
			@__data.Meta.Height + 1

	----------------------------------
	-- Gets vpath at given position. --
	----------------------------------
	GetVPathSocketAt: (x, y) =>
		return if not @__data
		translateXY @__socketArrays.vpaths, x, y,
			@__data.Meta.Width + 1,
			@__data.Meta.Height

	---------------------------------------
	-- Gets/sets cell at given position. --
	---------------------------------------
	GetCellSocketAt: (x, y) =>
		return if not @__data
		translateXY @__socketArrays.cells, x, y,
			@__data.Meta.Width,
			@__data.Meta.Height

	GetSocketDataIndex: (socket, numCols = nil) =>
		return unless socket and @__data

		numCols or= @__data.Meta.Width * 2 + 1
		socketType = socket\GetSocketType!
		local gridX, gridY

		if socketType == Moonpanel.Canvas.SocketType.Intersection
			gridX = (socket\GetX! - 1) * 2 + 1
			gridY = (socket\GetY! - 1) * 2 + 1

		elseif socketType == Moonpanel.Canvas.SocketType.Cell
			gridX = socket\GetX! * 2
			gridY = socket\GetY! * 2

		elseif socketType == Moonpanel.Canvas.SocketType.Path
			if socket\IsHorizontal!
				gridX = socket\GetX! * 2
				gridY = (socket\GetY! - 1) * 2 + 1
			else
				gridX = (socket\GetX! - 1) * 2 + 1
				gridY = socket\GetY! * 2
		else
			return

		1 + (gridX - 1) + (gridY - 1) * numCols

	GetSocketAtDataIndex: (index) =>
		return unless @__data and index

		numCols = @__data.Meta.Width * 2 + 1
		row = math.ceil index / numCols
		column = 1 + (index - 1) % numCols

		if row % 2 == 1
			if column % 2 == 1
				return @GetIntersectionSocketAt math.floor(column / 2) + 1,
					math.floor(row / 2) + 1

			return @GetHPathSocketAt column / 2,
				math.floor(row / 2) + 1

		if column % 2 == 1
			return @GetVPathSocketAt math.floor(column / 2) + 1,
				row / 2

		@GetCellSocketAt column / 2, row / 2

	--------------------------------------------------
	-- Fetches the internal panel data table.       --
	-- Not guaranteed to be useful, see ExportData. --
	--------------------------------------------------
	GetData: => @__data

	SetSolvedState: (solved) =>
		@__solved = solved == true

	GetSolvedState: => @__solved == true

	--------------------------------------------------------------------
	-- Exports data for various purposes, from saving boards to files --
	-- to sending them to clients.                                    --
	--------------------------------------------------------------------
	ExportData: =>
		return if not @__data

		numCols = @__data.Meta.Width * 2 + 1
		copy = table.Copy @__data
		copy.Entities = {}

		for socket in @GetSocketIterator!
			index = @GetSocketDataIndex socket, numCols
			if index
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
		@__observerFollower = nil
		@__terminalSnapshot = nil
		if not @__playData.startTime and not @__playData.visualResult and @__pathFinder
			@__pathFinder\reset!
			@__solutionData = nil
			@__lastRuleReport = nil
			@__predictedVisual = nil

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
				@ApplyVisualResult visualResult, @__playData.visualElapsed or 0, true
			elseif @__playData.startTime and not @__playData.endTime
				@BeginPresentation {
					sessionId: @__playData.sessionId or 0
					revision: @__pathFinder and @__pathFinder.topology.revision or 0
				}, true, math.max(0, CurTime! - @__playData.startTime)
				@SetPresentationExit @__pathFinder\isExitPath!, true
		@__rtDirty = true

	---------------------
	-- Rebuilds nodes. --
	---------------------
	RebuildNodes: =>
		return if not @__data

		numCols = @__data.Meta.Width  * 2 + 1
		numRows = @__data.Meta.Height * 2 + 1

		@__nodeMap = {}
		@__nodes = {}

		horizontalBarLength = @GetBarLength!
		verticalBarLength = @GetVerticalBarLength!

		-- Initialize the node map.
		for i = 1, numCols * numRows
			row = math.ceil i / numCols
			column = 1 + (i - 1) % numCols

			if row % 2 == 1 and column % 2 == 1
				intX = math.floor column / 2
				intY = math.floor row / 2

				socket = @GetIntersectionSocketAt intX + 1, intY + 1

				x = intX - @__data.Meta.Width  / 2
				y = intY - @__data.Meta.Height / 2
				node = {
					neighbors: {}
					socket: socket

					id: #@__nodes + 1
					:x
					:y

					screenX: math.floor Moonpanel.Canvas.Resolution * 0.5 +
						x * horizontalBarLength
					screenY: math.floor Moonpanel.Canvas.Resolution * 0.5 +
						y * verticalBarLength
				}

				socket\SetPathNode node

				@__nodeMap[intY + 1] or= {}
				@__nodeMap[intY + 1][intX + 1] = node

				table.insert @__nodes, node

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
		for node in *topology.nodes
			if node.socket
				node.socketIndex = Moonpanel.Canvas.CanonicalSeamIndex(
					@GetSocketDataIndex(node.socket), @__data, surfaceSpec)

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
					edge.socketIndex = Moonpanel.Canvas.CanonicalSeamIndex(
						@GetSocketDataIndex(socket), @__data, surfaceSpec)
		@__pathFinder = Moonpanel.Canvas.TraceEngine topology
		ruleData = if @IsContinuous!
			Moonpanel.Canvas.CanonicalizeContinuousData @__data
		else
			@__data
		@__ruleDefinition = Moonpanel.Canvas.RuleEngine.Compile ruleData, topology
		@BindWorldOcclusion!

	GetPathFinder: => @__pathFinder
	GetRuleDefinition: => @__ruleDefinition

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
		@__visualFrame = nil
		@__observerFollower = nil
		if silent
			@__presentation\drainCues!
			@SetLoop "SolvingLoop"
			@SetLoop "PresenceLoop", 0, 0
		@__terminalSnapshot = nil
		@__terminalSnapshotRestored = false
		@__rtDirty = true
		true

	BeginResetPresentation: (snapshot, serial = 0) =>
		return false unless CLIENT and @__presentation and snapshot
		return false if serial > 0 and serial <= (@__resetPresentationSerial or 0)
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
			@ResetPresentation "reset-complete"
			@__playData = {}
			@__pathFinder\reset! if @__pathFinder
			@__rtDirty = true
		true

	ResetRuntime: (reason = "reset") =>
		@__pathFinder\reset! if @__pathFinder
		@__playData = {}
		@__solutionData = nil
		@__lastRuleReport = nil
		@__predictedVisual = nil
		@__observerFollower = nil
		@__terminalSnapshot = nil
		@__terminalSnapshotRestored = false
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

	GetObserverFollower: => @__observerFollower

	GetTraceRenderState: =>
		return unless CLIENT and @__pathFinder
		return unless @__presentation and
			(@__presentation\isActive! or @__presentation\isFocusHintActive!)
		-- A completion result can arrive before the accessibility follower has
		-- rendered its endpoint. Keep the in-flight follower ahead of the terminal
		-- snapshot until it settles, otherwise the trace snaps to the exit.
		if @__observerFollower and not @__observerFollower\hasReached!
			return @__observerFollower\getRenderState!
		if @__terminalSnapshot
			return Moonpanel.Canvas.BuildTraceRenderState @__pathFinder.topology,
				@__terminalSnapshot, @__playData and @__playData.finalSequence or 0
		if @__observerFollower
			return @__observerFollower\getRenderState!
		snapshot = @__pathFinder\snapshot!
		Moonpanel.Canvas.BuildTraceRenderState @__pathFinder.topology, snapshot,
			@__playData and @__playData.finalSequence or 0

	ApplyVisualResult: (result, elapsed = 0, silent = false) =>
		return false unless CLIENT and @__presentation and result
		@__terminalSnapshot = table.Copy result.snapshot if result.snapshot
		-- Silent results are imported terminal state.  A normal completion must
		-- retain the live settlement animation even though it also has a snapshot.
		@__terminalSnapshotRestored = silent == true
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
		@__visualFrame = nil
		@__observerFollower = nil
		@__terminalSnapshot = nil
		@__terminalSnapshotRestored = false
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
		elseif cue == "Start" or cue == "StartScint" or cue == "FinishTracing" or
				cue == "AbortFinishTracing" or cue == "PotentialFailure" or
				cue == "Success" or cue == "Failure" or cue == "Eraser" or
				cue == "Abort" or cue == "Scint"
			@PlaySound cue, (cue == "Scint" or cue == "StartScint") and
				(@__visualFrame and @__visualFrame.scintPower or 1) or 1

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

	GetTracePrecisionScale: =>
		data = @GetData!
		meta = data and data.Meta or {}
		largestDimension = math.max 3,
			math.floor(tonumber(meta.Width) or 3),
			math.floor(tonumber(meta.Height) or 3)
		-- Keep the established 3x3 feel, while large boards become easier to
		-- trace precisely. The exponent makes the reduction win over the
		-- smaller physical cells on large boards. The floor prevents extreme
		-- dimensions from making input unusably slow, and the player's
		-- sensitivity convar remains an explicit override on top of this
		-- accessibility adjustment.
		math.Clamp math.pow(3 / largestDimension, 1.5), 0.2, 1

	QuantizeDeltas: (x, y, sensitivity = 1) =>
		-- Sensitivity is a user multiplier over the original panel feel. The
		-- quarter-scale prevents one ordinary mouse sample crossing an edge.
		scale = 0.25 * Moonpanel.Canvas.TraceEngine.Units /
			math.max(@GetBarLength!, 0.000001)
		scale *= @GetTracePrecisionScale!
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

		@__solutionData = nil
		@__lastRuleReport = nil
		@__predictedVisual = nil
		Moonpanel.Canvas.ReleaseVerifier @ if @__solutionCoroutine and
			Moonpanel.Canvas.ReleaseVerifier
		@__solutionCoroutine = nil
		@__playData = {
			startTime: CurTime!
			controller: ply
			touchingExit: false
		}
		@__exitPath = false

		@OnStart! if @OnStart ~= nil
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
			pathfinder\canSubmit! and pathfinder.active and
			pathfinder.active.primary and pathfinder.active.primary.isExit and
			(not pathfinder.active.secondary or pathfinder.active.secondary.isExit) and
			not pathfinder.touchingExit
		partialTraceSnapshot = pathfinder\snapshot! if nudgeExitAnimation
		if nudgeExitAnimation
			follower = Moonpanel.Canvas.ObserverTraceFollower pathfinder.topology
			follower\reset partialTraceSnapshot, true, 0
			@SetObserverFollower follower
			@SetPresentationExit true

		@__playData.endTime = CurTime!

		@__playData.wasAborted = forceAbort == true or not @__pathFinder\canSubmit!

		if @__playData.wasAborted
			@__pathFinder.phase = Moonpanel.Canvas.TraceEngine.Phase.Feedback
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
		if @__pathFinder
			@__pathFinder.phase = Moonpanel.Canvas.TraceEngine.Phase.Feedback
		local result
		if not solutionData or solutionData.status and solutionData.status ~= "complete"
			result = {
				aborted: true
				evaluationError: solutionData and solutionData.status or nil
				ruleRevision: solutionData and solutionData.ruleReport and
					solutionData.ruleReport.ruleRevision or 0
				reportHash: solutionData and solutionData.ruleReport and
					solutionData.ruleReport.reportHash or 0
			}
		else
			result = {
				success: solutionData.success
				feedback: solutionData.feedback
				ruleRevision: solutionData.ruleReport and solutionData.ruleReport.ruleRevision
				reportHash: solutionData.ruleReport and solutionData.ruleReport.reportHash
			}

		if result
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
include "sh_canvas_fixtures.lua"

Moonpanel.Canvas.RT
