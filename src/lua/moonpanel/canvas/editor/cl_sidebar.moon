return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

C = Editor.C
MATERIALS = Editor.MATERIALS

Helpers = Moonpanel.Helpers
deepCopy = Helpers.deepCopy
clearChildren = Helpers.clearChildren
colorValue = Helpers.colorValue

COLORS = [{ definition.Name, id } for id, definition in ipairs Moonpanel.ColorDefinitions]

SYMMETRIES = {
	{ "None", Moonpanel.Canvas.Symmetry.None, "symmetry_none" }
	{ "Vertical", Moonpanel.Canvas.Symmetry.Vertical, "symmetry_vertical" }
	{ "Horizontal", Moonpanel.Canvas.Symmetry.Horizontal, "symmetry_horizontal" }
	{ "Rotational", Moonpanel.Canvas.Symmetry.Rotational, "symmetry_rotational" }
}

DOT_ROLES = {
	{ "Either", Moonpanel.Canvas.DotRole.Any, "any_trace" }
	{ "Primary", Moonpanel.Canvas.DotRole.Primary, "primary_trace" }
	{ "Secondary", Moonpanel.Canvas.DotRole.Secondary, "secondary_trace" }
}

GROUPS = {
	{
		title: "CELL CLUES"
		entries: {
			{ "Color", "Square", "cell" }, { "Sun", "Star", "cell" }, { "Eraser", "Eraser", "cell" }
			{ "Triangle", "Triangle", "cell" }, { "Polyomino", "Polyomino", "cell" }
			{ "Invisible", "Cell hole", "cell" }
		}
	}
	{
		title: "ROUTE CLUES"
		entries: {
			{ "Start", "Start", "route" }, { "End", "Exit", "route" }
			{ "Hexagon", "Dot", "route" }, { "Disjoint", "Gap", "route" }
			{ "Invisible", "Route break", "route" }
		}
	}
}

APPEARANCE = {
	{ "Background", "Background" }, { "Vignette", "Vignette" }
	{ "Grid", "Untraced" }
	{ "Error", "Errored" }, { "Cell field", "Cell" }
}

TRACE_APPEARANCE = {
	{ "Trace", "Trace1" }
	{ "Trace completed", "Trace1Completed" }
	{ "Secondary trace", "Trace2" }
	{ "Secondary completed", "Trace2Completed" }
}

colorEqual = (left, right) ->
	return left == right unless left and right
	(left.r or 255) == (right.r or 255) and
		(left.g or 255) == (right.g or 255) and
		(left.b or 255) == (right.b or 255) and
		(left.a or 255) == (right.a or 255)

presetMatches = (colors, preset) ->
	return false unless colors and preset
	for role in *Moonpanel.Canvas.ColorRoles
		return false unless colorEqual colors[role], preset[role]
	true

getTraceOptions = (data) ->
	data.Meta and data.Meta.SymmetryOptions and data.Meta.SymmetryOptions.Traces or {}

getRuleTraceColor = (data, traceId) ->
	trace = getTraceOptions(data)[traceId]
	colorId = trace and (trace.RuleColor or trace.Color)
	colorId and Moonpanel.Canvas.ColorValues[colorId]

getAppearanceColor = (data, role) ->
	if role == "Trace1" or role == "Trace2" or role == "Trace1Completed" or role == "Trace2Completed"
		symmetry = data.Meta and data.Meta.Symmetry != Moonpanel.Canvas.Symmetry.None
		if role == "Trace2" or role == "Trace2Completed"
			return getAppearanceColor(data, role == "Trace2" and "Trace1" or "Trace1Completed") unless symmetry
		if role == "Trace1Completed" or role == "Trace2Completed"
			traceId = role == "Trace1Completed" and 1 or 2
			traces = getTraceOptions data
			return traces and traces[traceId] and traces[traceId].CompletionColorValue
		traceId = role == "Trace1" and 1 or 2
		traces = getTraceOptions data
		appearance = traces[traceId] and traces[traceId].ColorValue
		if symmetry
			return appearance or getRuleTraceColor(data, traceId) or
				(traceId == 1 and data.Colors.Traced or { r: 255, g: 255, b: 116 })
		if role == "Trace1"
			return appearance or data.Colors.Traced
		return appearance
	data.Colors[role]

appearanceValue = (data, role) ->
	value = getAppearanceColor data, role
	return value if value
	if role == "Trace1Completed" or role == "Trace2Completed"
		trace = appearanceValue data, role == "Trace1Completed" and "Trace1" or "Trace2"
		return Helpers.terminalColor trace
	value or Moonpanel.Canvas.DefaultColors[role]

appearanceEnabled = (data, role) ->
	symmetry = data.Meta and data.Meta.Symmetry != Moonpanel.Canvas.Symmetry.None
	return true if (role == "Trace1" or role == "Trace2") and not symmetry
	return true unless role == "Cell" or role == "Trace1" or role == "Trace2" or role == "Trace1Completed" or role == "Trace2Completed"
	return data.Colors.Cell ~= nil if role == "Cell"
	traceId = (role == "Trace1" or role == "Trace1Completed") and 1 or 2
	traces = getTraceOptions data
	if role == "Trace1" or role == "Trace2"
		return traces[traceId] and traces[traceId].ColorValue ~= nil
	traces and traces[traceId] and traces[traceId].CompletionColorValue ~= nil

setAppearanceColor = (data, role, color) ->
	if role == "Trace1" or role == "Trace2"
		symmetry = data.Meta and data.Meta.Symmetry != Moonpanel.Canvas.Symmetry.None
		unless symmetry
			data.Colors.Traced = color
			return
		traceId = role == "Trace1" and 1 or 2
		data.Meta.SymmetryOptions.Traces[traceId].ColorValue = color
		return
	if role == "Trace1Completed" or role == "Trace2Completed"
		traceId = role == "Trace1Completed" and 1 or 2
		data.Meta.SymmetryOptions.Traces[traceId].CompletionColorValue = color
		return
	data.Colors[role] = color

sortedKeys = (source, first) ->
	names = {}
	for name in pairs source
		table.insert names, name
	table.sort names, (a, b) ->
		return true if a == first
		return false if b == first
		a < b
	names

getColorPresetNames = -> sortedKeys Moonpanel.Canvas.ColorPresets

getActiveColorPreset = (colors, names) ->
	for presetName in *names
		return presetName if presetMatches colors, Moonpanel.Canvas.ResolveColorPreset presetName
	"Custom"

getSoundPresetNames = ->
	sortedKeys Moonpanel.Canvas.SoundPresets, Moonpanel.Canvas.DefaultSoundPreset

getActiveSoundPreset = (data, names) ->
	name = data.Sounds and data.Sounds.Preset
	for presetName in *names
		return presetName if name == presetName
	"Custom"

addLabel = (parent, text, font = "MoonpanelEditorBody", color = C.text, tall = 20) ->
	with parent\Add "DLabel"
		\Dock TOP
		\DockMargin 10, 4, 10, 2
		\SetTall tall
		\SetFont font
		\SetTextColor color
		\SetText text

addSection = (parent, text, topMargin = 12) ->
	with addLabel parent, text, "MoonpanelEditorSmall", C.muted, 18
		\DockMargin 10, topMargin, 10, 3

makePresetPicker = (parent, names, current, tooltip, apply, paintOption = nil) ->
	container = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 10, 2, 10, 5
		\SetTall 34
		\SetPaintBackgroundEnabled false
		.Paint = (_, w, h) ->
			draw.RoundedBox 0, 0, 0, w, h, C.panel

	select = with container\Add "DButton"
		\Dock TOP
		\SetTall 34
		\SetText ""
	Editor\AttachTextTooltip select, tooltip

	options = with container\Add "DPanel"
		\Dock TOP
		\SetVisible false
		\SetTall 0
		\SetPaintBackgroundEnabled false
		.Paint = (_, w, h) ->
			draw.RoundedBox 0, 0, 0, w, h, C.panel

	for presetName in *names
		option = with options\Add "DButton"
			.PresetName = presetName
			\Dock TOP
			\SetTall if paintOption then 42 else 30
			\SetText ""
			.DoClick = (_) ->
				apply _.PresetName
				options\SetVisible false
				options\SetTall 0
				container\SetTall 34
				container\InvalidateLayout true
			.Paint = (_, w, h) ->
				selected = current! == _.PresetName
				background = if selected then C.accentDim elseif _.Hovered then C.hover else C.raised
				draw.RoundedBox 0, 0, 0, w, h, background
				if selected
					draw.RoundedBox 0, 0, 0, 2, h, C.accent
				if paintOption
					paintOption _.PresetName, w, h
				else
					draw.SimpleText _.PresetName, "MoonpanelEditorBody", 10, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		Editor\AttachTextTooltip option, "Apply #{presetName}"

	select.DoClick = (_) ->
		open = not options\IsVisible!
		options\SetVisible open
		optionHeight = if paintOption then 42 else 30
		options\SetTall if open then #names * optionHeight else 0
		container\SetTall if open then 34 + #names * optionHeight else 34
		container\InvalidateLayout true
	select.Paint = (_, w, h) ->
		background = if _.Hovered then C.hover else C.raised
		draw.RoundedBox 4, 0, 0, w, h, C.border
		draw.RoundedBox 3, 1, 1, w - 2, h - 2, background
		draw.SimpleText "#{current!}  ▼", "MoonpanelEditorBody", 10, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER

	container.Refresh = ->
		container\InvalidateLayout true
		select\InvalidateLayout true
		option\InvalidateLayout true for option in *options\GetChildren!
	container

makeColorGrid = (parent, selected, callback, tooltipKey) ->
	layout = with parent\Add "DIconLayout"
		\Dock TOP
		\DockMargin 10, 2, 10, 5
		\SetTall 24
		\SetSpaceX 4
		\SetSpaceY 4
	for choice in *COLORS
		name = choice[1]
		id = choice[2]
		button = with layout\Add "DButton"
			.ColorId = id
			\SetText ""
			\SetSize 20, 20
			.DoClick = (_) -> callback _.ColorId
			.Paint = (_, w, h) ->
				isSelected = _.ColorId == selected
				border = if isSelected then C.accent elseif _.Hovered then C.text else C.border
				draw.RoundedBox 4, 0, 0, w, h, border
				draw.RoundedBox 3, 3, 3, w - 6, h - 6, colorValue _.ColorId
		if tooltipKey
			Editor\AttachControlTooltip button, tooltipKey, name
		else
			Editor\AttachTextTooltip button, name
	layout

makeCheck = (parent, text, checked, callback, tooltipKey) ->
	control = with parent\Add "DCheckBoxLabel"
		\Dock TOP
		\DockMargin 12, 3, 10, 3
		\SetTall 22
		\SetText text
		\SetTextColor C.text
		\SetFont "MoonpanelEditorBody"
		\SetValue checked and 1 or 0
	control.OnChange = (_, value) -> callback value == true or value == 1
	Editor\AttachControlTooltip control, tooltipKey if tooltipKey and Editor.AttachControlTooltip
	control

makeSegmented = (parent, choices, selected, callback) ->
	row = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 10, 2, 10, 6
		\SetTall 30
		.Paint = nil
	for choice in *choices
		label = choice[1]
		value = choice[2]
		tooltipKey = choice[3]
		button = with row\Add "DButton"
			.Value = value
			.Label = label
			\Dock LEFT
			\DockMargin 0, 0, 4, 0
			\SetWide math.floor((236 - (#choices - 1) * 4) / #choices)
			\SetText ""
			.DoClick = (_) -> callback _.Value
			.Paint = (_, w, h) ->
				background = if _.Value == selected then C.accentDim elseif _.Hovered then C.hover else C.raised
				draw.RoundedBox 4, 0, 0, w, h, background
				draw.SimpleText _.Label, "MoonpanelEditorSmall", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		Editor\AttachControlTooltip button, tooltipKey if tooltipKey and Editor.AttachControlTooltip
	row

styledSmallButton = (parent, text, callback, width = 72) ->
	with parent\Add "DButton"
		\SetText ""
		\SetWide width
		\SetTall 28
		.DoClick = callback
		.Paint = (_, w, h) ->
			background = if _.Depressed then C.accentDim elseif _.Hovered then C.hover else C.raised
			draw.RoundedBox 4, 0, 0, w, h, background
			draw.SimpleText text, "MoonpanelEditorSmall", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER

----
-- Clue tools
----

Editor.BuildToolModeBar = (parent) =>
	parent.Paint = (_, w, h) ->
		surface.SetDrawColor C.border
		surface.DrawRect 6, 0, w - 12, 1
	for index, entry in ipairs { { "place", "Place" }, { "erase", "Erase" }, { "recolor", "Recolor" } }
		mode = entry[1]
		label = entry[2]
		with parent\Add "DButton"
			.Mode = mode
			.Label = label
			\Dock LEFT
			\DockMargin index == 1 and 6 or 0, 6, 4, 4
			\SetWide 75
			\SetText ""
			.DoClick = (_) -> Editor\SetActiveMode _.Mode
			.Paint = (_, w, h) ->
				active = Editor.activeMode == _.Mode
				draw.RoundedBox 4, 0, 0, w, h,
					_.Hovered and C.hover or C.raised
				draw.RoundedBox 1, 5, h - 3, w - 10, 2, C.accent if active
				draw.SimpleText _.Label, "MoonpanelEditorSmall", w / 2, h / 2,
					C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER

Editor.BuildClueCatalogue = (parent) =>
	for group in *GROUPS
		addSection parent, group.title
		for entry in *group.entries
			typeName = entry[1]
			displayName = entry[2]
			family = entry[3] or Editor.GetClueFamily(typeName) or "cell"
			button = with parent\Add "DButton"
				.EntityType = typeName
				.DisplayName = displayName
				.Family = family
				\Dock TOP
				\DockMargin 8, 2, 8, 2
				\SetTall 38
				\SetText ""
			button.DoClick = (_) -> Editor\FocusClue _.EntityType, _.Family
			button.Paint = (_, w, h) ->
				cellBrush = Editor.cellBrush
				routeBrush = Editor.routeBrush
				focused = Editor\GetFocusedBrush!
				active = (_.Family == "cell" and cellBrush and _.EntityType == cellBrush.typeName) or
					(_.Family == "route" and routeBrush and _.EntityType == routeBrush.typeName)
				isFocused = focused and _.Family == focused.family and _.EntityType == focused.typeName
				background = if isFocused then C.accentDim elseif active then C.raised elseif _.Hovered then C.hover else C.inset
				draw.RoundedBox 4, 0, 0, w, h, background
				if active
					draw.RoundedBox 2, 0, 0, 3, h, C.accent

				preset = Editor\GetCluePreset _.EntityType, _.Family
				previewData = preset and preset.data or Editor.DefaultClueData(_.EntityType)
				material = MATERIALS[_.EntityType]
				if _.EntityType == "Hexagon" and previewData.Negative
					material = MATERIALS.HexagonNegative or material
				if material
					previewColorId = previewData.TintColor or previewData.Color or previewData.RuleColor or Moonpanel.Color.White
					previewColor = colorValue previewColorId
					if previewColor.r + previewColor.g + previewColor.b < 180
						draw.RoundedBox 4, 7, 5, 28, 28, Color(96, 105, 118)
						surface.SetDrawColor C.border
						surface.DrawOutlinedRect 7, 5, 28, 28
					surface.SetMaterial material
					surface.SetDrawColor previewColor
					rotational = _.EntityType == "Polyomino" and previewData.Rotational == true
					if rotational
						matrix = Matrix!
						screenX, screenY = _\LocalToScreen 0, 0
						origin = Vector screenX, screenY, 0
						center = Vector 21, 19, 0
						matrix\Translate origin
						matrix\Translate center
						matrix\Rotate Angle 0, -20, 0
						matrix\Translate -center
						matrix\Translate -origin
						cam.PushModelMatrix matrix
					surface.DrawTexturedRect 9, 7, 24, 24
					cam.PopModelMatrix! if rotational

				label = _.DisplayName
				label ..= " #{math.Clamp(math.floor(previewData.Count or 1), 1, 3)}" if _.EntityType == "Triangle"
				draw.SimpleText label, "MoonpanelEditorBody", 42, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
			Editor\AttachTooltip button, typeName if Editor.AttachTooltip

Editor.RefreshBrushUI = =>
	return unless IsValid @StickySettings
	oldFocus = vgui.GetKeyboardFocus!
	oldScroll = if IsValid(@ClueCatalogue) and @ClueCatalogue.GetVBar
		@ClueCatalogue\GetVBar!\GetScroll!

	clearChildren @StickySettings
	@BuildStickySettings @StickySettings
	@ResizeStickySettings @StickySettings

	if IsValid @ClueCatalogue
		@ClueCatalogue\InvalidateLayout true

	timer.Simple 0, ->
		return unless IsValid @StickySettings
		@ClueCatalogue\GetVBar!\SetScroll oldScroll if IsValid(@ClueCatalogue) and @ClueCatalogue.GetVBar
		oldFocus\RequestFocus! if IsValid oldFocus

----
-- Sticky settings panel
----

Editor.BuildStickySettings = (parent) =>
	brush = @GetFocusedBrush!

	unless brush
		parent\SetTall 0
		parent\InvalidateParent true
		return

	typeName = brush.typeName
	data = brush.data or {}

	displayName = if Editor.GetClueDisplayName
		Editor.GetClueDisplayName typeName
	else
		typeName

	----
	-- Brush header
	----

	headerHeight = if brush.valid then 42 else 62

	with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 8, 8, 8, 4
		\SetTall headerHeight

		.Paint = (_, w, h) ->
			draw.RoundedBox 4, 0, 0, w, h, C.raised

			familyText = if brush.family == "cell"
				"Cell brush"
			else
				"Route brush"

			draw.SimpleText(
				displayName,
				"MoonpanelEditorBody",
				10,
				13,
				C.text,
				TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER
			)

			draw.SimpleText(
				familyText,
				"MoonpanelEditorSmall",
				10,
				30,
				C.muted,
				TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER
			)

			unless brush.valid
				draw.SimpleText(
					brush.warning or "Invalid configuration",
					"MoonpanelEditorSmall",
					10,
					48,
					C.danger,
					TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER
				)

	----
	-- Clue-specific settings
	----

	switch typeName
		when "Triangle"
			addSection parent, "PIP COUNT", 4

			makeSegmented(
				parent,
				{
					{ "1", 1 }
					{ "2", 2 }
					{ "3", 3 }
				},
				data.Count or 1,
				(value) ->
					Editor\UpdateFocusedBrushData (nextData) ->
						nextData.Count = value
			)

		when "Polyomino"
			@BuildPolyominoEditor parent, brush

		when "Hexagon"
			addSection parent, "TRACE", 4

			makeSegmented(
				parent,
				DOT_ROLES,
				data.TraceRole or Moonpanel.Canvas.DotRole.Any,
				(value) ->
					Editor\UpdateFocusedBrushData (nextData) ->
						nextData.TraceRole = value
			)

			makeCheck(
				parent,
				"Negative: must remain untraced",
				data.Negative,
				(enabled) ->
					Editor\UpdateFocusedBrushData (nextData) ->
						nextData.Negative = enabled,
				"negative"
			)

			makeCheck(
				parent,
				"Invisible during play",
				data.Invisible,
				(enabled) ->
					Editor\UpdateFocusedBrushData (nextData) ->
						nextData.Invisible = enabled,
				"invisible"
			)

	----
	-- Common brush settings
	----

	supportsRule = Editor.ClueSupportsRuleColor typeName, data
	supportsTint = Editor.ClueSupportsTint typeName, data

	tintEnabled = data.TintColor ~= nil or
		data.Color ~= nil

	if supportsRule or supportsTint
		with parent\Add "DPanel"
			\Dock TOP
			\DockMargin 8, 5, 8, 1
			\SetTall 1

			.Paint = (_, w, h) ->
				surface.SetDrawColor C.border
				surface.DrawRect 0, 0, w, 1

	if supportsRule
		addSection parent, "RULE COLOR", 7

		ruleGrid = makeColorGrid(
			parent,
			data.RuleColor or Moonpanel.Color.Black,
			(id) ->
				Editor\UpdateFocusedBrushData (nextData) ->
					nextData.RuleColor = id,
			"rule_color"
		)

	if supportsTint
		addSection(
			parent,
			"APPEARANCE",
			supportsRule and 4 or 7
		)

		makeCheck(
			parent,
			"Override rendered tint",
			tintEnabled,
			(enabled) ->
				Editor\UpdateFocusedBrushData (nextData) ->
					if enabled
						nextData.TintColor = nextData.TintColor or
							nextData.Color or
							nextData.RuleColor or
							Moonpanel.Color.White

						nextData.Color = nil
					else
						nextData.TintColor = nil
						nextData.Color = nil,
			"tint_override"
		)

		if tintEnabled
			tintId = data.TintColor or
				data.Color or
				data.RuleColor or
				Moonpanel.Color.White

			tintGrid = makeColorGrid(
				parent,
				tintId,
				(id) ->
					Editor\UpdateFocusedBrushData (nextData) ->
						nextData.TintColor = id
						nextData.Color = nil,
				"tint_override"
			)

	----
	-- Bottom spacing
	----

	with parent\Add "DPanel"
		\Dock TOP
		\SetTall 8
		.Paint = nil

	-- Do not measure or set the height here.
	-- Dock positions are not reliable until the next layout pass.
	parent\InvalidateLayout true

Editor.BuildPolyominoEditor = (parent, brush) =>
	data = brush.data or {}
	shape = data.Shape or { { 1 } }

	-- Copy the stored matrix directly into the editor grid.
	-- Do not center it and do not trim it.
	draft = [ { 0, 0, 0, 0, 0 } for y = 1, 5 ]

	for y = 1, math.min #shape, 5
		row = shape[y]

		if type(row) == "table"
			for x = 1, math.min #row, 5
				draft[y][x] = row[x] == 1 and 1 or 0

	addSection parent, "SHAPE", 4

	grid = with parent\Add "DIconLayout"
		\Dock TOP
		\DockMargin 42, 2, 42, 7
		\SetTall 146
		\SetSpaceX 3
		\SetSpaceY 3

	commitDraft = ->
		hasCell = false

		for y = 1, 5
			for x = 1, 5
				if draft[y][x] == 1
					hasCell = true
					break

			break if hasCell

		unless hasCell
			Editor\SetStatus "A polyomino must contain at least one cell.", C.danger
			return false

		-- Preserve the complete 5×5 matrix exactly as shown.
		-- Empty outer rows and columns are intentional editor state.
		Editor\UpdateFocusedBrushData (nextData) ->
			nextData.Shape = deepCopy draft

		true

	for y = 1, 5
		for x = 1, 5
			cellY = y
			cellX = x

			button = with grid\Add "DButton"
				.CellX = cellX
				.CellY = cellY
				\SetText ""
				\SetSize 26, 26

			button.DoClick = (_) ->
				oldValue = draft[_.CellY][_.CellX]
				draft[_.CellY][_.CellX] = oldValue == 1 and 0 or 1

				unless commitDraft!
					draft[_.CellY][_.CellX] = oldValue

			button.Paint = (_, w, h) ->
				active = draft[_.CellY][_.CellX] == 1
				background = if active
					C.warning
				elseif _.Hovered
					C.hover
				else
					C.inset

				draw.RoundedBox 3, 0, 0, w, h, background

				surface.SetDrawColor active and C.text or C.border
				surface.DrawOutlinedRect 0, 0, w, h

	actions = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 10, 0, 10, 6
		\SetTall 28
		.Paint = nil

	applyAction = (mode) ->
		if mode == "rotate"
			nextDraft = [ { 0, 0, 0, 0, 0 } for i = 1, 5 ]

			for y = 1, 5
				for x = 1, 5
					nextDraft[x][6 - y] = draft[y][x]

			draft = nextDraft

		elseif mode == "reset"
			draft = [ { 0, 0, 0, 0, 0 } for i = 1, 5 ]
			draft[3][3] = 1

		elseif mode == "center"
			local minX, minY, maxX, maxY

			for y = 1, 5
				for x = 1, 5
					if draft[y][x] == 1
						minX = minX and math.min(minX, x) or x
						maxX = maxX and math.max(maxX, x) or x
						minY = minY and math.min(minY, y) or y
						maxY = maxY and math.max(maxY, y) or y

			if minX
				nextDraft = [ { 0, 0, 0, 0, 0 } for i = 1, 5 ]

				shapeWidth = maxX - minX + 1
				shapeHeight = maxY - minY + 1
				offsetX = math.floor((5 - shapeWidth) / 2) + 1
				offsetY = math.floor((5 - shapeHeight) / 2) + 1

				for y = minY, maxY
					for x = minX, maxX
						nextDraft[offsetY + y - minY][offsetX + x - minX] = draft[y][x]

				draft = nextDraft

		commitDraft!

	for entry in *{
		{ "Reset", "reset" }
		{ "Center", "center" }
		{ "Rotate", "rotate" }
	}
		label = entry[1]
		mode = entry[2]

		button = styledSmallButton actions, label, nil, 72
		button.ActionMode = mode
		button.DoClick = (_) -> applyAction _.ActionMode
		button\Dock LEFT
		button\DockMargin 0, 0, 5, 0

	makeCheck parent,
		"Rotatable",
		data.Rotational,
		(enabled) ->
			Editor\UpdateFocusedBrushData (nextData) ->
				nextData.Rotational = enabled,
		"rotatable"

	makeCheck parent,
		"Negative: subtractive",
		data.Negative,
		(enabled) ->
			Editor\UpdateFocusedBrushData (nextData) ->
				nextData.Negative = enabled,
		"negative"

Editor.ResizeStickySettings = (panel = @StickySettings) =>
	return unless IsValid panel

	@StickyResizeSerial = (@StickyResizeSerial or 0) + 1

	serial = @StickyResizeSerial
	editor = @

	-- Let newly created docked controls receive their final positions first.
	panel\InvalidateLayout true

	timer.Simple 0, ->
		return unless IsValid panel
		return unless editor.StickySettings == panel
		return unless editor.StickyResizeSerial == serial

		-- Force the latest set of children through Dock layout before measuring.
		panel\InvalidateLayout true

		requiredHeight = 1

		for child in *panel\GetChildren!
			if IsValid(child) and child\IsVisible!
				requiredHeight = math.max(
					requiredHeight,
					child\GetY! + child\GetTall!
				)

		requiredHeight = math.ceil requiredHeight

		if panel\GetTall! ~= requiredHeight
			panel\SetTall requiredHeight

		panel\InvalidateLayout true

		if IsValid editor.SidebarContent
			editor.SidebarContent\InvalidateLayout true

		if IsValid editor.ClueCatalogue
			editor.ClueCatalogue\InvalidateLayout true
			editor.ClueCatalogue\InvalidateParent true

----
-- Panel settings
----

resizeData = (data, width, height) ->
	oldCols = data.Meta.Width * 2 + 1
	newCols = width * 2 + 1
	newRows = height * 2 + 1
	entities = {}
	lost = 0
	for index, entry in pairs data.Entities or {}
		if type(index) == "number"
			row = math.floor((index - 1) / oldCols) + 1
			column = (index - 1) % oldCols + 1
			if row <= newRows and column <= newCols
				entities[(row - 1) * newCols + column] = deepCopy entry
			elseif entry and entry.Type
				lost += 1
	entities[index] or= {} for index = 1, newCols * newRows
	data.Meta.Width = width
	data.Meta.Height = height
	data.Entities = entities
	data, lost

humanCompatibilityError = (error) ->
	switch error.code
		when "continuous_width" then "Horizontal wrapping needs a panel at least three cells wide."
		when "vertical_exit_boundary" then "An exit is no longer on a valid outer boundary."
		when "seam_conflict" then "Two incompatible clues occupy the same wrapped seam position."
		else "Panel compatibility issue: #{error.code or 'unknown'}."

Editor.RefreshCompatibility = (data = nil) =>
	return unless IsValid @CompatibilityLabel
	data or= @Document\GetData!
	compatibility = Moonpanel.Canvas.GetSurfaceCompatibility data, @GetEffectiveSurfaceSpec(data)
	if compatibility and compatibility.playable
		@CompatibilityLabel\SetText "✓ Panel is valid"
		@CompatibilityLabel\SetTextColor C.success
	else
		messages = {}
		for error in *(compatibility and compatibility.errors or {})
			messages[#messages + 1] = "✗ #{humanCompatibilityError error}"
		@CompatibilityLabel\SetText #messages > 0 and table.concat(messages, "\n") or "Unable to validate this panel."
		@CompatibilityLabel\SetTextColor #messages > 0 and C.danger or C.warning
	@CompatibilityLabel\SetAutoStretchVertical true
	@CompatibilityLabel\InvalidateLayout true
	@SidebarContent\InvalidateLayout true if IsValid @SidebarContent

Editor.BuildPanelSettings = (parent) =>
	data = @Document\GetData!
	addLabel parent, "PANEL", "MoonpanelEditorHeading", C.text, 28
	addLabel parent, "Grid, symmetry and topology", "MoonpanelEditorSmall", C.muted, 18

	addSection parent, "GRID SIZE"
	row = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 10, 2, 10, 6
		\SetTall 56
		.Paint = nil

	widthInput = with row\Add "DNumberWang"
		\SetPos 0, 20
		\SetSize 72, 28
		\SetMinMax 1, 10
		\SetDecimals 0
		\SetValue data.Meta.Width
	heightInput = with row\Add "DNumberWang"
		\SetPos 82, 20
		\SetSize 72, 28
		\SetMinMax 1, 10
		\SetDecimals 0
		\SetValue data.Meta.Height
	with row\Add "DLabel"
		\SetPos 0, 0
		\SetSize 72, 18
		\SetText "Width"
		\SetTextColor C.muted
	with row\Add "DLabel"
		\SetPos 82, 0
		\SetSize 72, 18
		\SetText "Height"
		\SetTextColor C.muted

	applyResize = ->
		width = math.Clamp math.floor(widthInput\GetValue!), 1, 10
		height = math.Clamp math.floor(heightInput\GetValue!), 1, 10
		return if width == data.Meta.Width and height == data.Meta.Height
		resized, lost = resizeData deepCopy(data), width, height
		commit = -> Editor\CommitData "Resize panel", resized
		if lost > 0
			confirmResize = ->
				commit!
				Editor\SetStatus "Resize removed #{lost} clue#{lost == 1 and "" or "s"}.", C.warning
			Derma_Query "This resize removes #{lost} clue#{lost == 1 and "" or "s"}. The change remains undoable.", "Resize panel", "Resize", confirmResize, "Cancel"
		else
			commit!

	applyButton = styledSmallButton row, "Apply", applyResize, 72
	applyButton\SetPos 164, 20
	widthInput.OnEnter = applyResize
	heightInput.OnEnter = applyResize

	addSection parent, "SYMMETRY"
	symmetryNames, symmetryValues = {}, {}
	for entry in *SYMMETRIES
		table.insert symmetryNames, entry[1]
		symmetryValues[entry[1]] = entry[2]
	symmetryCurrent = ->
		value = Editor.Document\GetData!.Meta.Symmetry
		for name in *symmetryNames
			return name if symmetryValues[name] == value
		"None"
	applySymmetry = (name) ->
		return if symmetryCurrent! == name
		nextData = Editor.Document\GetData!
		nextSymmetry = symmetryValues[name]
		if nextSymmetry != Moonpanel.Canvas.Symmetry.None and
			nextData.Meta.Symmetry == Moonpanel.Canvas.Symmetry.None
			for trace in *nextData.Meta.SymmetryOptions.Traces
				trace.ColorValue = nil
				trace.CompletionColorValue = nil
		nextData.Meta.Symmetry = nextSymmetry
		Editor\CommitData "Change symmetry", nextData
	makePresetPicker parent, symmetryNames, symmetryCurrent,
		"Choose the panel's trace symmetry", applySymmetry

	if data.Meta.Symmetry != Moonpanel.Canvas.Symmetry.None
		addSection parent, "TRACE RULE COLORS"
		traces = data.Meta.SymmetryOptions.Traces
		for traceId, label in ipairs { "Primary rule color", "Secondary rule color" }
			trace = traces[traceId]
			enabled = trace.RuleColor ~= nil or trace.Color ~= nil
			ruleColorTooltip = traceId == 1 and "primary_trace_rule_color" or "secondary_trace_rule_color"
			makeCheck(
				parent,
				label,
				enabled,
				(checked) ->
					nextData = Editor.Document\GetData!
					nextTrace = nextData.Meta.SymmetryOptions.Traces[traceId]
					if checked
						nextTrace.RuleColor = nextTrace.RuleColor or nextTrace.Color or
							(traceId == 1 and Moonpanel.Color.Cyan or Moonpanel.Color.Magenta)
					else
						nextTrace.RuleColor = nil
						nextTrace.Color = nil
					Editor\CommitData "Toggle #{string.lower label}", nextData,
				ruleColorTooltip
			)
			if enabled
				makeColorGrid(
					parent,
					trace.RuleColor or trace.Color,
					(color) ->
						nextData = Editor.Document\GetData!
						nextData.Meta.SymmetryOptions.Traces[traceId].RuleColor = color
						Editor\CommitData "Change #{string.lower label}", nextData,
					(traceId == 1 and "primary_trace_rule_color" or "secondary_trace_rule_color")
				)
			traceLabel = traceId == 1 and "Primary trace invisible" or "Secondary trace invisible"
			invisibleTooltip = traceId == 1 and "primary_trace_invisible" or "secondary_trace_invisible"
			makeCheck(
				parent,
				traceLabel,
				trace.Invisible,
				(checked) ->
					nextData = Editor.Document\GetData!
					nextData.Meta.SymmetryOptions.Traces[traceId].Invisible = checked
					Editor\CommitData "Toggle #{string.lower label} visibility", nextData,
				invisibleTooltip
			)
			if traceId == 1
				with parent\Add "DPanel"
					\Dock TOP
					\DockMargin 10, 4, 10, 4
					\SetTall 1
					.Paint = (_, w, h) ->
						surface.SetDrawColor C.border
						surface.DrawRect 0, 0, w, h

	addSection parent, "TOPOLOGY"
	onContinuity = (enabled) ->
		nextData = Editor.Document\GetData!
		nextData.Meta.Continuous = enabled
		Editor\CommitData "Change horizontal wrapping", nextData
	makeCheck parent, "Wrap left and right edges", data.Meta.Continuous, onContinuity, "continuity"

	addSection parent, "COMPATIBILITY"
	@CompatibilityLabel = addLabel parent, "", "MoonpanelEditorSmall", C.muted, 22
	@CompatibilityLabel\SetWrap true
	@RefreshCompatibility data

	advanced = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 8, 10, 8, 8
		\SetTall 34
		.Paint = nil

	advancedHeader = with advanced\Add "DButton"
		\Dock TOP
		\SetTall 34
		\SetText ""
		.DoClick = ->
			Editor.AdvancedGeometryExpanded = not Editor.AdvancedGeometryExpanded
			advanced\InvalidateLayout true
			parent\InvalidateLayout true
		.Paint = (_, w, h) ->
			expanded = Editor.AdvancedGeometryExpanded == true
			background = if expanded then C.accentDim elseif _.Hovered then C.hover else C.raised
			draw.RoundedBox 4, 0, 0, w, h, background
			draw.SimpleText expanded and "▾" or "▸", "MoonpanelEditorBody", 12, h / 2, C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			draw.SimpleText "Advanced geometry", "MoonpanelEditorBody", 28, h / 2 - 1, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	Editor\AttachTextTooltip advancedHeader,
		"Optional geometry controls for line width, cell size, and gaps."

	geometry = with advanced\Add "DPanel"
		\SetTall 190
		.Paint = (_, w, h) ->
			surface.SetDrawColor C.border
			surface.DrawRect 0, 0, w, 1

	advanced.PerformLayout = (_, w, h) ->
		expanded = Editor.AdvancedGeometryExpanded == true
		geometry\SetVisible expanded
		geometry\SetPos 0, 34
		geometry\SetSize w, expanded and 190 or 0
		advanced\SetTall expanded and 224 or 34

	autoBarWidth = data.Dim.AutoBarWidth ~= false
	makeCheck geometry, "Automatic line width", autoBarWidth, (enabled) ->
		nextData = Editor.Document\GetData!
		nextData.Dim.AutoBarWidth = enabled
		Editor\CommitData "Change automatic line width", nextData

	for setting in *{ { "Line width", "BarWidth", 1, 12, 1 }, { "Maximum cell size", "BarLength", 8, 45, 1 }, { "Gap size", "DisjointLength", 5, 70, 100 } }
		label = setting[1]
		key = setting[2]
		minimum = setting[3]
		maximum = setting[4]
		scale = setting[5]
		with geometry\Add "DNumSlider"
			.SettingKey = key
			.SettingLabel = label
			.SettingScale = scale
			\Dock TOP
			\DockMargin 8, 2, 8, 2
			\SetText label
			\SetMin minimum
			\SetMax maximum
			\SetDecimals 0
			\SetValue (data.Dim[key] or minimum) * scale
			\SetEnabled false if key == "BarWidth" and autoBarWidth
			.OnValueChanged = (_, value) ->
				nextData = Editor.Document\GetData!
				nextData.Dim[_.SettingKey] = value / _.SettingScale
				Editor\CommitData "Change #{string.lower _.SettingLabel}", nextData, "panel-#{_.SettingKey}", false
				Editor\RefreshCompatibility nextData

----
-- Appearance
----

Editor.SelectAppearanceRole = (role) =>
	@appearanceRole = role
	data = @Document\GetData!
	current = appearanceValue data, role
	if IsValid @AppearanceEditLabel
		@AppearanceEditLabel\SetText "EDIT #{string.upper role}"
	if IsValid(@AppearanceMixer) and current
		@AppearanceUpdating = true
		@AppearanceMixer\SetColor Color current.r, current.g, current.b, current.a or 255
		@AppearanceMixer\SetEnabled appearanceEnabled data, role
		@AppearanceUpdating = nil

Editor.RefreshAppearanceControls = =>
	data = @Document\GetData!
	if IsValid @AppearancePresetState
		@AppearancePresetState\Refresh!
	if IsValid(@AppearanceMixer)
		current = appearanceValue data, @appearanceRole
		if current
			@AppearanceUpdating = true
			@AppearanceMixer\SetColor Color current.r, current.g, current.b, current.a or 255
			@AppearanceMixer\SetEnabled appearanceEnabled data, @appearanceRole
			@AppearanceUpdating = nil
	for role, toggle in pairs @AppearanceToggles or {}
		if IsValid toggle
			@AppearanceToggleUpdating = true
			toggle\SetValue appearanceEnabled data, role
			@AppearanceToggleUpdating = nil
	@AppearanceEditLabel\SetText "EDIT #{string.upper @appearanceRole}" if IsValid @AppearanceEditLabel
	if IsValid @SoundPresetState
		@SoundPresetState\Refresh!

Editor.BuildAppearanceSettings = (parent) =>
	data = @Document\GetData!
	@appearanceRole or= "Background"
	addLabel parent, "APPEARANCE", "MoonpanelEditorHeading", C.text, 28
	addLabel parent, "Panel-wide display colors", "MoonpanelEditorSmall", C.muted, 18
	presetNames = getColorPresetNames!
	@AppearancePresetNames = presetNames

	addSection parent, "COLOR PRESETS", 10
	colorCurrent = -> getActiveColorPreset Editor.Document\GetData!.Colors, presetNames
	applyColorPreset = (presetName) ->
		if colorCurrent! == presetName
			Editor\SetStatus "#{presetName} is already active.", C.muted
			return
		nextData = Editor.Document\GetData!
		nextData.Colors = deepCopy Moonpanel.Canvas.ResolveColorPreset presetName
		Editor\CommitData "Apply color preset", nextData, nil, false
		Editor\RefreshAppearanceControls!
		Editor\SetStatus "Applied #{presetName} color preset.", C.success
	paintColorPreset = (name, w, h) ->
		resolved = Moonpanel.Canvas.ResolveColorPreset name
		roleCount = #Moonpanel.Canvas.ColorRoles
		step = 14
		startX = math.max 10, w - roleCount * step - 10
		for index, role in ipairs Moonpanel.Canvas.ColorRoles
			value = resolved[role]
			if value
				x = startX + (index - 1) * step
				draw.RoundedBox 1, x, h - 17, math.max(8, step - 2), 12,
					Color value.r, value.g, value.b, value.a or 255
		draw.SimpleText name, "MoonpanelEditorBody", 10, 11, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	colorPicker = makePresetPicker parent, presetNames, colorCurrent,
		"Choose a complete panel appearance preset", applyColorPreset, paintColorPreset
	@AppearancePresetState = colorPicker

	soundPresetNames = getSoundPresetNames!
	@SoundPresetNames = soundPresetNames
	addSection parent, "SOUND PRESETS", 10
	soundCurrent = -> getActiveSoundPreset Editor.Document\GetData!, soundPresetNames
	applySoundPreset = (presetName) ->
		if soundCurrent! == presetName
			Editor\SetStatus "#{presetName} is already active.", C.muted
			return
		nextData = Editor.Document\GetData!
		nextData.Sounds = { Preset: presetName }
		Editor\CommitData "Apply sound preset", nextData, nil, false
		Editor\RefreshAppearanceControls!
		Editor\SetStatus "Applied #{presetName} sound preset.", C.success
	soundPicker = makePresetPicker parent, soundPresetNames, soundCurrent,
		"Choose the panel's cue sound family", applySoundPreset
	@SoundPresetState = soundPicker

	addAppearanceButtons = (title, entries) ->
		addSection parent, title
		for entry in *entries
			name = entry[1]
			key = entry[2]
			symmetry = data.Meta.Symmetry != Moonpanel.Canvas.Symmetry.None
			optional = key == "Cell" or key == "Trace1Completed" or key == "Trace2Completed" or
				(symmetry and (key == "Trace1" or key == "Trace2"))
			row = parent\Add "DButton"
			with row
				.RoleKey = key
				.RoleName = name
				\Dock TOP
				\DockMargin 10, 2, 10, 2
				\SetTall 32
				\SetText ""
				.DoClick = (_) -> Editor\SelectAppearanceRole _.RoleKey
				.Paint = (_, w, h) ->
					background = if _.RoleKey == Editor.appearanceRole then C.accentDim elseif _.Hovered then C.hover else C.raised
					draw.RoundedBox 4, 0, 0, w, h, background
					data = Editor.Document\GetData!
					value = appearanceValue data, _.RoleKey
					muted = optional and not appearanceEnabled(data, _.RoleKey)
					textColor = muted and C.muted or C.text
					swatch = muted and C.muted or Color(value.r, value.g, value.b, value.a or 255)
					draw.RoundedBox 3, 8, 7, 18, 18, swatch
					draw.SimpleText _.RoleName, "MoonpanelEditorBody", 34, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
				if optional
					toggle = row\Add "DCheckBox"
					toggle\Dock RIGHT
					toggle\DockMargin 0, 8, 8, 8
					toggle\SetValue appearanceEnabled Editor.Document\GetData!, key
					toggle.OnChange = (_, enabled) ->
						return if Editor.AppearanceToggleUpdating
						nextData = Editor.Document\GetData!
						if enabled
							if key == "Cell"
								nextData.Colors.Cell = deepCopy Moonpanel.Canvas.DefaultColors.Cell
							else
								setAppearanceColor nextData, key, deepCopy appearanceValue nextData, key
						else
							if key == "Cell"
								nextData.Colors.Cell = nil
							elseif key == "Trace1" or key == "Trace2"
								traceId = key == "Trace1" and 1 or 2
								nextData.Meta.SymmetryOptions.Traces[traceId].ColorValue = nil
							else
								traceId = key == "Trace1Completed" and 1 or 2
								nextData.Meta.SymmetryOptions.Traces[traceId].CompletionColorValue = nil
						Editor\CommitData "Toggle #{string.lower name}", nextData, "appearance-#{key}-toggle", false
						Editor\RefreshAppearanceControls!
						Editor.AppearanceToggles or= {}
						Editor.AppearanceToggles[key] = toggle
					appearanceTooltip = switch key
						when "Cell" then "cell_field"
						when "Trace1" then "primary_trace_color"
						when "Trace2" then "secondary_trace_color"
						when "Trace1Completed" then "primary_trace_completed_color"
						when "Trace2Completed" then "secondary_trace_completed_color"
					Editor\AttachControlTooltip row, appearanceTooltip if appearanceTooltip

	addAppearanceButtons "COLOR ROLE", APPEARANCE
	addAppearanceButtons "TRACE COLORS", TRACE_APPEARANCE

	@AppearanceEditLabel = addSection parent, "EDIT #{string.upper @appearanceRole}"
	current = appearanceValue data, @appearanceRole
	@AppearanceMixer = with parent\Add "DColorMixer"
		\Dock TOP
		\DockMargin 10, 2, 10, 10
		\SetTall 180
		\SetPalette false
		\SetColor Color current.r, current.g, current.b, current.a or 255
		\SetEnabled @appearanceRole != "Cell" or data.Colors.Cell != nil
	@AppearanceMixer.ValueChanged = (_, color) ->
		return if Editor.AppearanceUpdating
		nextData = Editor.Document\GetData!
		setAppearanceColor nextData, Editor.appearanceRole,
			{ r: color.r, g: color.g, b: color.b, a: color.a or 255 }
		Editor\CommitData "Change panel appearance", nextData, "appearance-#{Editor.appearanceRole}", false
		Editor\RefreshAppearanceControls!

----
-- Main sidebar
----

Editor.RebuildSidebar = =>
	return unless IsValid @SidebarContent

	-- Invalidate any queued resize belonging to the old sidebar contents.
	@StickyResizeSerial = (@StickyResizeSerial or 0) + 1
	@StickySettings = nil
	@ClueCatalogue = nil

	clearChildren @SidebarContent

	tab = @sidebarTab or "clues"
	@ToolModeBar = nil

	if tab == "clues"
		@ToolModeBar = with @SidebarContent\Add "DPanel"
			\Dock TOP
			\DockMargin 2, 0, 2, 6
			\SetTall 38
		@BuildToolModeBar @ToolModeBar

		@StickySettings = with @SidebarContent\Add "DPanel"
			\Dock BOTTOM

			-- Temporary height until the first deferred measurement.
			\SetTall 1

			.Paint = (_, w, h) ->
				draw.RoundedBox 0, 0, 0, w, h, C.panel

				surface.SetDrawColor C.border
				surface.DrawRect 8, 0, w - 16, 1

		@BuildStickySettings @StickySettings

		@ClueCatalogue = with @SidebarContent\Add "DScrollPanel"
			\Dock FILL
			\SetPaintBackgroundEnabled false

		hint = addLabel(
			@ClueCatalogue,
			"Left-click applies or replaces. An exact match is removed. Right-click picks a clue up.",
			"MoonpanelEditorSmall",
			C.muted,
			46
		)

		hint\SetWrap true
		hint\DockMargin 10, 2, 10, 2

		@BuildClueCatalogue @ClueCatalogue
		@ResizeStickySettings @StickySettings

	elseif tab == "panel"
		panelScroll = with @SidebarContent\Add "DScrollPanel"
			\Dock FILL
			\SetPaintBackgroundEnabled false

		@BuildPanelSettings panelScroll

	else
		appearanceScroll = with @SidebarContent\Add "DScrollPanel"
			\Dock FILL
			\SetPaintBackgroundEnabled false

		@BuildAppearanceSettings appearanceScroll

	@SidebarContent\InvalidateLayout true

Editor.SwitchSidebarTab = (tab) =>
	return if @sidebarTab == tab
	@sidebarTab = tab
	@RebuildSidebar!

Editor.BuildSidebar = (parent) =>
	tabs = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 6, 6, 6, 4
		\SetTall 32
		.Paint = nil

	for entry in *{ { "clues", "Clues", 72 }, { "panel", "Panel", 72 }, { "appearance", "Appearance", 92 } }
		tab = entry[1]
		label = entry[2]
		width = entry[3]
		with tabs\Add "DButton"
			.TabName = tab
			.Label = label
			\Dock LEFT
			\DockMargin 0, 0, 4, 0
			\SetWide width
			\SetText ""
			.DoClick = (_) -> Editor\SwitchSidebarTab _.TabName
			.Paint = (_, w, h) ->
				selected = (Editor.sidebarTab or "clues") == _.TabName
				background = if selected then C.accentDim elseif _.Hovered then C.hover else C.raised
				draw.RoundedBox 4, 0, 0, w, h, background
				draw.SimpleText _.Label, "MoonpanelEditorSmall", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER

	@SidebarContent = with parent\Add "DPanel"
		\Dock FILL
		\DockMargin 4, 0, 4, 4
		.Paint = nil
	@sidebarTab = "clues"
	@RebuildSidebar!
