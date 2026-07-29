AddCSLuaFile!

Canvas = Moonpanel.Canvas
Helpers = Moonpanel.Helpers
tableOrEmpty = Helpers.tableOrEmpty
num = Helpers.num
bool = Helpers.bool
copyColor = Helpers.copyColor
Canvas.SchemaVersion = 7
Canvas.DefaultDisjointLength = 0.4

DEFAULT_BAR_WIDTHS = {
	0.055
	0.05
	0.05
	0.05
	0.04
	0.03
	0.03
	0.02
	0.02
	0.02
}

Canvas.CalculateGeometry = (data, resolution = Canvas.Resolution or 512) ->
	data = data or {}
	meta = data.Meta or {}
	dim = data.Dim or {}
	width = math.max 1, math.floor tonumber(meta.Width) or 3
	height = math.max 1, math.floor tonumber(meta.Height) or 3
	maxCells = math.max width, height
	innerRatio = math.Clamp tonumber(dim.InnerScreenRatio) or 0.8, 0.1, 1
	innerSize = resolution * innerRatio

	barWidth = if dim.AutoBarWidth ~= false
		innerSize * (DEFAULT_BAR_WIDTHS[maxCells] or 0.025)
	else
		resolution * (math.Clamp(tonumber(dim.BarWidth) or 4, 1, 100) / 100)

	-- Keep an explicitly oversized line width from consuming the cells it is
	-- meant to separate. This cap is only observable for pathological manual
	-- values; ordinary authored widths pass through unchanged.
	barWidth = math.min barWidth, innerSize / (maxCells * 2 + 1)

	-- This is the donor's fitting rule: reserve every grid-line width first,
	-- divide the remaining inner screen across the dominant axis, then apply
	-- the authored maximum-spacing cap. BarLength is therefore a cap, not a
	-- literal distance that can push a large grid beyond the render target.
	cellLength = math.ceil (innerSize - barWidth * (maxCells + 1)) / maxCells
	cellLength = math.ceil cellLength - barWidth / maxCells
	maxBarLength = resolution * (math.Clamp(tonumber(dim.BarLength) or 25, 1, 100) / 100)
	cellLength = math.max 1, math.min cellLength, maxBarLength

	barWidth = math.max 1, math.floor barWidth
	cellLength = math.max 1, math.floor cellLength
	-- Current canvas geometry stores the distance between intersection
	-- centers. The donor stored the open cell length and advanced by
	-- cellLength + barWidth, so convert at this boundary exactly once.
	barLength = cellLength + barWidth
	{
		:barWidth
		:barLength
		:cellLength
		innerWidth: barWidth + barLength * width
		innerHeight: barWidth + barLength * height
		:innerSize
		:innerRatio
	}

Canvas.DotRole = {
	Any: 0
	Primary: 1
	Secondary: 2
}

Canvas.EntityTypeMap = {
	[1]: "Start"
	[2]: "End"
	[3]: "Hexagon"
	[4]: "Triangle"
	[5]: "Polyomino"
	[6]: "Sun"
	[7]: "Eraser"
	[8]: "Color"
	[9]: "Disjoint"
	[10]: "Invisible"
}

Canvas.ColorValues = [{
	r: definition.r
	g: definition.g
	b: definition.b
} for definition in *Moonpanel.ColorDefinitions]

-- These are the canonical panel-wide appearance defaults. Keep them as plain
-- tables so shared data can be serialized without depending on Color userdata.
Canvas.ColorRoles = { "Background", "Untraced", "Traced", "Finished", "Errored", "Vignette", "Cell" }
Canvas.DefaultColors = {
	Background: { r: 80, g: 80, b: 255, a: 255 }
	Untraced: { r: 31, g: 7, b: 159, a: 255 }
	Traced: { r: 224, g: 220, b: 210, a: 255 }
	Finished: { r: 226, g: 144, b: 20, a: 255 }
	Errored: { r: 0, g: 0, b: 0, a: 255 }
	Vignette: { r: 0, g: 0, b: 0, a: 80 }
	Cell: { r: 64, g: 64, b: 200, a: 255 }
}

-- Presets intentionally contain only historical overrides. Missing roles are
-- resolved against the current defaults, which keeps old names compatible
-- with the modern appearance baseline.
Canvas.ColorPresets = {
	Default: { Directory: "presets/default" }
	"The Challenge Triangles": {
		Background: { r: 30, g: 30, b: 30, a: 255 }
		Traced: { r: 250, g: 160, b: 10, a: 255 }
		Untraced: { r: 125, g: 110, b: 50, a: 255 }
	}
	"The Quarry Gray": {
		Background: { r: 70, g: 70, b: 70, a: 255 }
		Traced: { r: 255, g: 255, b: 255, a: 255 }
		Untraced: { r: 90, g: 140, b: 130, a: 255 }
		Cell: { r: 0, g: 0, b: 0, a: 255 }
	}
	"The Windmill": {
		Background: { r: 112, g: 128, b: 144, a: 255 }
		Traced: { r: 220, g: 220, b: 220, a: 255 }
		Untraced: { r: 0, g: 0, b: 0, a: 255 }
		Finished: { r: 230, g: 230, b: 230, a: 255 }
		Errored: { r: 220, g: 64, b: 64, a: 255 }
	}
}

Canvas.DefaultSoundPreset = "Default"
Canvas.SoundPresets = {
	Default: {}
	CRT: { Directory: "presets/crt" }
	Glass: { Directory: "presets/glass" }
	Floor: { Directory: "presets/floor" }
	Shack: { Directory: "presets/shack" }
	"End Pillars": { Directory: "presets/endpillars" }
	"Stone Pillar": { Directory: "presets/stonepillar" }
}

Canvas.ResolveSoundPreset = (name) ->
	preset = Canvas.SoundPresets[name]
	return nil unless preset

	output = {
		Preset: name
		Directory: preset.Directory or ""
	}
	output

windmillEntityTypes = {
	[3]: "Start"
	[4]: "End"
	[5]: "Disjoint"
	[6]: "Hexagon"
	[7]: "Color"
	[8]: "Sun"
	[9]: "Polyomino"
	[10]: "Eraser"
	[11]: "Triangle"
}

windmillDefaultColors = {
	Color: Moonpanel.Color.Black
	Hexagon: Moonpanel.Color.Black
	Triangle: Moonpanel.Color.Orange
	Polyomino: Moonpanel.Color.Yellow
	Eraser: Moonpanel.Color.White
	Sun: Moonpanel.Color.White
}

Canvas.ResolveColorPreset = (name) ->
	preset = Canvas.ColorPresets[name]
	return nil unless preset

	output = {}
	for role in *Canvas.ColorRoles
		output[role] = copyColor preset[role], Canvas.DefaultColors[role]
	output

colorId = (value, fallback = Moonpanel.Color.Black) ->
	math.floor math.Clamp num(value, fallback), 1, table.Count Moonpanel.Color

Canvas.GetClueTintColor = (data, fallback = Moonpanel.Color.Black) ->
	data = tableOrEmpty data
	colorId data.TintColor or data.RuleColor or data.Color, fallback

normalizeDimPercent = (value, fallback) ->
	value = num value, fallback
	if value > 0 and value <= 1
		value *= 100

	value

normalizeShape = (shape) ->
	shape = tableOrEmpty shape
	output = {}
	width = 0
	local minX, minY, maxX, maxY

	for rowIndex = 1, math.min #shape, 5
		row = tableOrEmpty shape[rowIndex]
		output[rowIndex] = {}
		width = math.max width, math.min #row, 5

		for columnIndex = 1, math.min #row, 5
			value = row[columnIndex] and row[columnIndex] ~= 0 and 1 or 0
			output[rowIndex][columnIndex] = value
			if value == 1
				minX = columnIndex if not minX or columnIndex < minX
				maxX = columnIndex if not maxX or columnIndex > maxX
				minY = rowIndex if not minY or rowIndex < minY
				maxY = rowIndex if not maxY or rowIndex > maxY

	if #output == 0 or width == 0 or not minX
		return { { 1 } }

	trimmed = {}
	for rowIndex = minY, maxY
		row = {}
		for columnIndex = minX, maxX
			table.insert row, output[rowIndex][columnIndex] or 0
		table.insert trimmed, row

	trimmed

sanitizeEntityData = (typeName, data, inputVersion = Canvas.SchemaVersion) ->
	data = tableOrEmpty data
	colors = (fallback) ->
		legacyTint = data.Color
		ruleSource = if inputVersion < 3
			legacyTint or data.RuleColor
		else
			data.RuleColor or legacyTint
		ruleColor = colorId ruleSource, fallback
		tintSource = if inputVersion >= 4 then data.TintColor else legacyTint
		tintColor = colorId tintSource, ruleColor if tintSource ~= nil
		output = { RuleColor: ruleColor }
		output.TintColor = tintColor if tintColor and tintColor ~= ruleColor
		output

	switch typeName
		when "Color", "Sun", "Eraser"
			colors Moonpanel.Color.Black

		when "Hexagon"
			output = colors Moonpanel.Color.Black
			output.TraceRole = math.floor math.Clamp num(data.TraceRole, Canvas.DotRole.Any),
				Canvas.DotRole.Any, Canvas.DotRole.Secondary
			-- Hollow was the original editor name for a dot hidden during play.
			-- Schema v6 makes visibility and inverted validation independent.
			output.Invisible = bool(data.Invisible) or (inputVersion < 6 and bool(data.Hollow))
			output.Negative = bool data.Negative
			output

		when "Triangle"
			output = colors Moonpanel.Color.Orange
			output.Count = math.floor math.Clamp num(data.Count, 1), 1, 4
			output

		when "Polyomino"
			output = colors Moonpanel.Color.Yellow
			output.Shape = normalizeShape data.Shape
			output.Rotational = bool data.Rotational
			output.Negative = bool data.Negative
			output

		else
			{}

socketTypeForIndex = (index, width) ->
	numCols = width * 2 + 1
	row = math.ceil index / numCols
	column = 1 + (index - 1) % numCols

	if row % 2 == 1 and column % 2 == 1
		Canvas.SocketType.Intersection
	elseif row % 2 == 0 and column % 2 == 0
		Canvas.SocketType.Cell
	else
		Canvas.SocketType.Path

entitySocketType = (typeName) ->
	switch typeName
		when "Start", "End"
			"PathOrIntersection"
		when "Color", "Sun", "Eraser", "Triangle", "Polyomino"
			Canvas.SocketType.Cell
		when "Disjoint"
			Canvas.SocketType.Path
		when "Invisible"
			nil
		when "Hexagon"
			"PathOrIntersection"

flatIndex = (gridX, gridY, width) ->
	Helpers.flatIndex width, gridX, gridY

legacyTypeName = (typeValue) ->
	if isstring typeValue
		typeValue
	else
		Canvas.EntityTypeMap[typeValue]

legacyEntity = (entry) ->
	entry = tableOrEmpty entry
	typeName = legacyTypeName entry.Type
	return unless typeName
	sourceData = entry.Data or entry.Attributes
	entityData = sanitizeEntityData typeName, sourceData, 1
	-- Preserve the absence of this v2 field until the colorful legacy trace
	-- migration has enough panel-level context to infer its semantic branch.
	if typeName == "Hexagon" and tableOrEmpty(sourceData).TraceRole == nil
		entityData.TraceRole = nil

	{
		Type: typeName
		Data: entityData
	}

copyLegacyGrid = (output, source, width, xCount, yCount, indexFor) ->
	source = tableOrEmpty source
	for y = 1, yCount
		row = tableOrEmpty source[y]
		for x = 1, xCount
			if entity = legacyEntity row[x]
				output.Entities[indexFor x, y, width] = entity

Canvas.LegacyToCanvasData = (tileData) ->
	tileData = tableOrEmpty tileData
	tile = tableOrEmpty tileData.Tile
	dimensions = tableOrEmpty tileData.Dimensions
	symmetry = tableOrEmpty tileData.Symmetry
	-- The earliest Windmill-style files stored symmetry as a numeric field
	-- inside Tile. That enum predates the canonical ordering: 1 was
	-- rotational, 2 horizontal, and 3 vertical. Later legacy files moved it
	-- to a top-level object with a Type field.
	legacySymmetry = tileData.Tile and tileData.Tile.Symmetry
	symmetryType = if type(legacySymmetry) == "number"
		switch math.floor legacySymmetry
			when 1 then Canvas.Symmetry.Rotational
			when 2 then Canvas.Symmetry.Horizontal
			when 3 then Canvas.Symmetry.Vertical
			else Canvas.Symmetry.None
	elseif symmetry.Type ~= nil
		math.floor math.Clamp num(symmetry.Type, 0), 0, Canvas.Symmetry.Rotational
	else
		Canvas.Symmetry.None

	width = math.floor math.Clamp num(tile.Width, 3), 1, 10
	height = math.floor math.Clamp num(tile.Height, 3), 1, 10
	innerScreenRatio = math.Clamp num(dimensions.InnerScreenRatio, 0.8), 0.1, 1
	legacyBarWidth = tonumber dimensions.BarWidth
	legacyMaxBarLength = math.Clamp num(dimensions.MaxBarLength, 0.25), 0.01, 1
	legacyDisjointLength = num dimensions.DisjointLength,
		Canvas.DefaultDisjointLength
	-- In the original legacy format, 1 meant "use the default gap". It was
	-- never intended to occupy the entire path, so do not pass the sentinel
	-- through the modern fractional gap setting.
	legacyDisjointLength = Canvas.DefaultDisjointLength if legacyDisjointLength >= 1

	output = {
		SchemaVersion: 1
		Meta: {
			Width: width
			Height: height
			Symmetry: symmetryType
			SymmetryOptions: {
				Colorful: bool symmetry.Colorful
				Traces: {}
			}
		}
		Dim: {
			-- Legacy dimensions were fractions of the inner screen, while the
			-- canonical fields are percentages of the complete render target.
			BarLength: legacyMaxBarLength * innerScreenRatio * 100
			BarWidth: legacyBarWidth and legacyBarWidth * innerScreenRatio * 100 or 4
			AutoBarWidth: legacyBarWidth == nil
			InnerScreenRatio: innerScreenRatio
			DisjointLength: math.Clamp legacyDisjointLength, 0.01, 0.9
		}
		Colors: tableOrEmpty tileData.Colors
		Entities: {}
		Extensions: {}
	}

	traces = tableOrEmpty symmetry.Traces
	for i = 1, 2
		trace = tableOrEmpty traces[i]
		traceColor = colorId trace.Color, i == 1 and Moonpanel.Color.White or Moonpanel.Color.Yellow
		output.Meta.SymmetryOptions.Traces[i] = {
			Color: traceColor
			ColorValue: Canvas.ColorValues[traceColor]
			Invisible: bool trace.Invisible
		}

	copyLegacyGrid output, tileData.Cells, width, width, height,
		(x, y, w) -> flatIndex x * 2, y * 2, w

	copyLegacyGrid output, tileData.Intersections, width, width + 1, height + 1,
		(x, y, w) -> flatIndex (x - 1) * 2 + 1, (y - 1) * 2 + 1, w

	copyLegacyGrid output, tileData.HPaths, width, width, height + 1,
		(x, y, w) -> flatIndex x * 2, (y - 1) * 2 + 1, w

	copyLegacyGrid output, tileData.VPaths, width, width + 1, height,
		(x, y, w) -> flatIndex (x - 1) * 2 + 1, y * 2, w

	Canvas.SanitizeData output

Canvas.WindmillToCanvasData = (storage) ->
	contents = tableOrEmpty(storage).contents
	contents = tableOrEmpty contents
	entries = contents.entity
	rawWidth = math.floor tonumber(contents.width) or 0
	return nil, "Windmill data is missing its entity grid." unless istable(entries) and rawWidth > 0

	expanded = {}
	for _, entry in ipairs entries
		entry = tableOrEmpty entry
		if entry.shape and tableOrEmpty(entry.shape).negative
			return nil, "Negative polyominoes are not supported by the Windmill importer."
		count = math.floor math.Clamp tonumber(entry.count) or 1, 1, 1000
		table.insert expanded, entry for _ = 1, count

	return nil, "Windmill data has an invalid grid width." if rawWidth < 3 or rawWidth % 2 == 0
	return nil, "Windmill data has an incomplete entity grid." if #expanded % rawWidth ~= 0

	rawHeight = #expanded / rawWidth
	return nil, "Windmill data has an invalid grid height." if rawHeight < 3 or rawHeight % 2 == 0

	width = math.floor rawWidth / 2
	height = math.floor rawHeight / 2
	return nil, "Windmill panels are limited to 10x10 in the editor." if width > 10 or height > 10

	storeWidth = rawWidth
	toIndex = (x, y) -> 1 + x + storeWidth * y

	colorFor = (entry, typeName, forceWhite = false) ->
		return Moonpanel.Color.White if forceWhite
		math.floor tonumber(entry.color) or windmillDefaultColors[typeName] or Moonpanel.Color.Black

	entityData = (entry, typeName, forceWhite = false) ->
		color = colorFor entry, typeName, forceWhite
		switch typeName
			when "Triangle"
				{
					RuleColor: color
					Count: math.floor math.Clamp tonumber(entry.triangleCount) or 1, 1, 3
				}
			when "Polyomino"
				shape = tableOrEmpty entry.shape
				shapeWidth = math.floor tonumber(shape.width) or 0
				grid = tableOrEmpty shape.grid
				return nil if shapeWidth < 1 or #grid == 0 or #grid % shapeWidth ~= 0
				shapeHeight = #grid / shapeWidth
				return nil if shapeHeight > 5 or shapeWidth > 5
				matrix = {}
				for y = 1, shapeHeight
					row = {}
					for x = 1, shapeWidth
						value = grid[(y - 1) * shapeWidth + x]
						row[x] = (value == true or value == 1 or value == "1") and 1 or 0
					table.insert matrix, row
				{
					RuleColor: color
					Shape: matrix
					Rotational: shape.free == true
					Negative: false
				}
			when "Hexagon"
				{
					RuleColor: color
					TraceRole: Canvas.DotRole.Any
					Negative: false
					Invisible: false
				}
			else
				{ RuleColor: color }

	output = nil
	put = (entry, gridX, gridY, forceWhite = false) ->
		entry = tableOrEmpty entry
		typeName = windmillEntityTypes[tonumber entry.type]
		return unless typeName
		data = entityData entry, typeName, forceWhite and typeName == "Hexagon"
		return if data == nil
		output.Entities[toIndex(gridX, gridY)] = {
			Type: typeName
			Data: data
		}

	output = {
		SchemaVersion: Canvas.SchemaVersion
		Meta: {
			Width: width
			Height: height
			Symmetry: Canvas.Symmetry.None
			Continuous: false
			SymmetryOptions: { Colorful: false, Traces: {} }
		}
		Dim: {
			BarLength: 25
			BarWidth: 4
			AutoBarWidth: true
			InnerScreenRatio: 0.8
			DisjointLength: Canvas.DefaultDisjointLength
		}
		Colors: Canvas.ResolveColorPreset "The Windmill"
		Entities: {}
		Extensions: {}
	}

	for x = 0, width - 1
		for y = 0, height - 1
			put expanded[toIndex x * 2 + 1, y * 2 + 1], x * 2 + 1, y * 2 + 1

	for x = 0, width
		for y = 0, height
			put expanded[toIndex x * 2, y * 2], x * 2, y * 2, true

	for x = 0, width
		for y = 0, height - 1
			put expanded[toIndex x * 2, y * 2 + 1], x * 2, y * 2 + 1, true

	for x = 0, width - 1
		for y = 0, height
			put expanded[toIndex x * 2 + 1, y * 2], x * 2 + 1, y * 2, true

	Canvas.SanitizeData output

Canvas.SanitizeData = (data) ->
	input = tableOrEmpty data
	if input.Tile or input.Cells or input.Intersections or input.HPaths or input.VPaths
		return Canvas.LegacyToCanvasData input

	inputVersion = math.floor num input.SchemaVersion, 1
	meta = tableOrEmpty input.Meta
	dim = tableOrEmpty input.Dim
	colors = tableOrEmpty input.Colors

	output = {}
	output.SchemaVersion = Canvas.SchemaVersion

	output.Meta = {
		Width: math.floor math.Clamp num(meta.Width, 3), 1, 10
		Height: math.floor math.Clamp num(meta.Height, 3), 1, 10
		Continuous: bool meta.Continuous
		Symmetry: math.floor math.Clamp num(meta.Symmetry, 0), 0, Canvas.Symmetry.Rotational
		SymmetryOptions: {
			Colorful: bool (tableOrEmpty meta.SymmetryOptions).Colorful
			Traces: {}
		}
	}

	traceInput = tableOrEmpty (tableOrEmpty meta.SymmetryOptions).Traces
	for i = 1, 2
		trace = tableOrEmpty traceInput[i]
		traceColor = colorId trace.Color, i == 1 and Moonpanel.Color.White or Moonpanel.Color.Yellow
		output.Meta.SymmetryOptions.Traces[i] = {
			Color: traceColor
			ColorValue: copyColor trace.ColorValue, Canvas.ColorValues[traceColor]
			Invisible: bool trace.Invisible
		}

	output.Dim = {
		BarLength: math.Clamp normalizeDimPercent(dim.BarLength, 25), 1, 100
		BarWidth: math.Clamp normalizeDimPercent(dim.BarWidth, 4), 1, 100
		AutoBarWidth: if dim.AutoBarWidth == nil
			inputVersion < 5 and math.abs(normalizeDimPercent(dim.BarWidth, 4) - 4) < 0.0001
		else
			bool dim.AutoBarWidth
		InnerScreenRatio: math.Clamp num(dim.InnerScreenRatio, 0.8), 0.1, 1
		DisjointLength: math.Clamp num(dim.DisjointLength,
			Canvas.DefaultDisjointLength), 0.01, 0.9
	}

	output.Colors = {
		Untraced: copyColor colors.Untraced, Canvas.DefaultColors.Untraced
		Traced: copyColor colors.Traced, Canvas.DefaultColors.Traced
		Finished: copyColor colors.Finished, Canvas.DefaultColors.Finished
		Errored: copyColor colors.Errored, Canvas.DefaultColors.Errored
		Background: copyColor colors.Background, Canvas.DefaultColors.Background
		Vignette: copyColor colors.Vignette, Canvas.DefaultColors.Vignette
		Cell: copyColor colors.Cell, Canvas.DefaultColors.Cell
	}

	sounds = tableOrEmpty input.Sounds
	soundPreset = tostring sounds.Preset or Canvas.DefaultSoundPreset
	soundPreset = Canvas.DefaultSoundPreset unless Canvas.SoundPresets[soundPreset]
	output.Sounds = { Preset: soundPreset }

	entities = tableOrEmpty input.Entities
	output.Entities = {}
	output.Extensions = {}
	extensions = tableOrEmpty input.Extensions
	for extensionName in *{
			"FourTriangle", "MidpointTerminals", "VoidTopology",
			"InvisibleDot", "NegativeDot"
		}
		output.Extensions[extensionName] = true if extensions[extensionName] == true

	count = (output.Meta.Width * 2 + 1) * (output.Meta.Height * 2 + 1)
	for i = 1, count
		entity = {}
		reference = tableOrEmpty entities[i]
		typeName = legacyTypeName reference.Type

		if typeName and Canvas.EntityTypeMap
			socketType = socketTypeForIndex i, output.Meta.Width
			requiredSocketType = entitySocketType typeName

			if (not requiredSocketType) or requiredSocketType == socketType or
					(requiredSocketType == "PathOrIntersection" and
						(socketType == Canvas.SocketType.Path or socketType == Canvas.SocketType.Intersection))
				entity.Type = typeName
				-- Schema v2 introduced semantic colors, but its editor palette only
				-- changed the rendered tint. That silently authored mismatched square
				-- identities. Schema v3 preserved deliberate separation under the
				-- ambiguous Color name. Schema v4 canonizes that override as TintColor
				-- and omits it whenever it matches RuleColor.
				entity.Data = sanitizeEntityData typeName,
					reference.Data or reference.Attributes, inputVersion
				if typeName == "Hexagon" and inputVersion < 2 and
						(tableOrEmpty(reference.Data or reference.Attributes)).TraceRole == nil
					entity.Data.TraceRole = Canvas.DotRole.Any
					if output.Meta.SymmetryOptions.Colorful and
							entity.Data.RuleColor ~= Moonpanel.Color.Black
						for traceId = 1, 2
							trace = output.Meta.SymmetryOptions.Traces[traceId]
							if trace and trace.Color == entity.Data.RuleColor
								entity.Data.TraceRole = traceId
								break
				if typeName == "Triangle" and entity.Data.Count == 4
					output.Extensions.FourTriangle = true
				if (typeName == "Start" or typeName == "End") and
						socketType == Canvas.SocketType.Path
					output.Extensions.MidpointTerminals = true
				if typeName == "Invisible"
					output.Extensions.VoidTopology = true
				if typeName == "Hexagon" and entity.Data.Invisible
					output.Extensions.InvisibleDot = true
				if typeName == "Hexagon" and entity.Data.Negative
					output.Extensions.NegativeDot = true

		output.Entities[i] = entity

	output

Canvas.DeserializeData = (data) ->
	Canvas.SanitizeData util.JSONToTable data

Canvas.SerializeData = (tableData) ->
	util.TableToJSON Canvas.SanitizeData tableData
