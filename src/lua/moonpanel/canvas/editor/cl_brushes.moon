return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

-- The editor keeps one independent brush for cell clues and one for route
-- clues. The most recently focused brush is shown in the sticky settings
-- panel. Right-clicking a clue replaces its remembered preset in full.

CLUE_FAMILIES = {
	Color: "cell"
	Sun: "cell"
	Eraser: "cell"
	Triangle: "cell"
	Polyomino: "cell"
	Start: "route"
	End: "route"
	Hexagon: "route"
	Disjoint: "route"
	Invisible: "route"
}

CLUE_TYPES = {
	"Color", "Sun", "Eraser", "Triangle", "Polyomino"
	"Start", "End", "Hexagon", "Disjoint", "Invisible"
}

Helpers = Moonpanel.Helpers
deepCopy = Helpers.deepCopy

Editor.GetClueFamily = (typeName) -> CLUE_FAMILIES[typeName]

Editor.GetBrushKey = (family, typeName) -> "#{family}:#{typeName}"

Editor.DefaultClueData = (typeName) ->
	switch typeName
		when "Color", "Sun", "Eraser"
			{ RuleColor: Moonpanel.Color.Black }
		when "Triangle"
			{ RuleColor: Moonpanel.Color.Orange, Count: 1 }
		when "Polyomino"
			{
				RuleColor: Moonpanel.Color.Yellow
				Shape: { { 1 } }
				Rotational: false
				Negative: false
			}
		when "Hexagon"
			{
				RuleColor: Moonpanel.Color.Black
				TraceRole: Moonpanel.Canvas.DotRole.Any
				Invisible: false
				Negative: false
			}
		when "Start", "End", "Disjoint"
			{ RuleColor: Moonpanel.Color.Black }
		when "Invisible"
			{}
		else
			{}

Editor.ClueSupportsRuleColor = (typeName, data) ->
	return false if typeName == "Invisible"
	data = data or Editor.DefaultClueData typeName
	data.RuleColor ~= nil

Editor.ClueSupportsTint = (typeName, data) ->
	-- Invisible geometry is itself an appearance operation rather than a
	-- normally rendered clue.
	return false if typeName == "Invisible"
	data = data or Editor.DefaultClueData typeName
	data.RuleColor ~= nil or data.TintColor ~= nil or data.Color ~= nil

Editor.ValidateClueData = (typeName, data, panelData) ->
	data or= {}
	if typeName == "Polyomino"
		cells = 0
		for row in *(data.Shape or {})
			cells += 1 for value in *row when value == 1
		return false, "A polyomino must contain at least one cell." if cells == 0
	elseif typeName == "Triangle"
		count = math.floor tonumber(data.Count) or 0
		return false, "Triangles require one, two, or three pips." unless 1 <= count and count <= 3
	elseif typeName == "Hexagon" and data.TraceRole == Moonpanel.Canvas.DotRole.Secondary
		symmetry = panelData and panelData.Meta and panelData.Meta.Symmetry
		if symmetry == nil or symmetry == Moonpanel.Canvas.Symmetry.None
			return false, "Secondary-only dots require panel symmetry."
	true, nil

makeBrush = (typeName, data) ->
	family = Editor.GetClueFamily(typeName) or "cell"
	{
		:typeName
		data: deepCopy(data or Editor.DefaultClueData(typeName))
		:family
		valid: true
		warning: nil
	}

Editor.InitBrushes = =>
	@cluePresets = {}
	for typeName in *CLUE_TYPES
		family = Editor.GetClueFamily typeName
		@cluePresets[Editor.GetBrushKey family, typeName] = {
			:family
			data: deepCopy Editor.DefaultClueData typeName
		}
	-- Invisible geometry may target either family; retain separate presets.
	@cluePresets[Editor.GetBrushKey("cell", "Invisible")] = {
		family: "cell"
		data: deepCopy Editor.DefaultClueData "Invisible"
	}

	@cellBrush = makeBrush "Color", @cluePresets[Editor.GetBrushKey("cell", "Color")].data
	@routeBrush = makeBrush "Hexagon", @cluePresets[Editor.GetBrushKey("route", "Hexagon")].data
	@focusedBrush = "cell"
	@activeMode = "place"
	@RefreshBrushValidity!

Editor.GetBrushForSocket = (socket) =>
	return nil unless socket
	if socket\GetSocketType! == Moonpanel.Canvas.SocketType.Cell
		@cellBrush
	else
		@routeBrush

Editor.GetFocusedBrush = =>
	if @focusedBrush == "route" then @routeBrush else @cellBrush

Editor.GetCluePreset = (typeName, family) =>
	family or= Editor.GetClueFamily typeName or "cell"
	preset = @cluePresets and @cluePresets[Editor.GetBrushKey family, typeName]
	return preset if preset
	{
		:family
		data: deepCopy Editor.DefaultClueData typeName
	}

Editor.RefreshBrushValidity = =>
	panelData = @Document and @Document\GetData! or nil
	for brush in *{ @cellBrush, @routeBrush }
		if brush
			valid, warning = Editor.ValidateClueData brush.typeName, brush.data, panelData
			brush.valid = valid
			brush.warning = warning

Editor.SetBrush = (family, typeName, data) =>
	family = family or Editor.GetClueFamily(typeName) or "cell"
	data = deepCopy(data or Editor.DefaultClueData(typeName))
	brush = if family == "route" then @routeBrush else @cellBrush
	brush or= makeBrush typeName, data
	brush.typeName = typeName
	brush.data = data
	brush.family = family

	panelData = @Document and @Document\GetData! or nil
	brush.valid, brush.warning = Editor.ValidateClueData typeName, data, panelData

	if family == "route" then @routeBrush = brush else @cellBrush = brush
	@focusedBrush = family
	@cluePresets or= {}
	@cluePresets[Editor.GetBrushKey family, typeName] = { :family, data: deepCopy(data) }
	@RefreshBrushUI! if @RefreshBrushUI
	brush

Editor.FocusClue = (typeName, family) =>
	family or= Editor.GetClueFamily typeName or "cell"
	preset = @GetCluePreset typeName, family
	@activeMode = "place"
	@SetBrush family, typeName, preset.data

Editor.UpdateFocusedBrushData = (mutator) =>
	brush = @GetFocusedBrush!
	return unless brush
	data = deepCopy brush.data or {}
	mutator data
	@SetBrush brush.family, brush.typeName, data

Editor.PickupClue = (socket) =>
	entity = socket and socket\GetEntity!
	return false unless entity and not entity\IsBase!
	exported = entity\ExportData!
	return false unless exported and exported.Type
	family = if socket\GetSocketType! == Moonpanel.Canvas.SocketType.Cell then "cell" else "route"
	@activeMode = "place"
	@SetBrush family, exported.Type, exported.Data or {}
	label = Editor.GetClueDisplayName and Editor.GetClueDisplayName(exported.Type) or exported.Type
	@SetStatus "Picked up #{label}", Editor.C and Editor.C.text or Color(232, 238, 244)
	true

Editor.BrushMatchesEntity = (brush, socket) =>
	return false unless brush and socket
	entity = socket\GetEntity!
	return false unless entity and not entity\IsBase!
	exported = entity\ExportData!
	return false unless exported
	Moonpanel.EditorDocument.SemanticEqual {
		Type: brush.typeName
		Data: brush.data
	}, exported

Editor.SetActiveMode = (mode) =>
	return unless mode == "place" or mode == "erase" or mode == "recolor"
	@activeMode = mode
	@Document\SetActiveTool mode if @Document
	@RefreshBrushUI! if @RefreshBrushUI
	message = switch mode
		when "erase" then "Erase clues: click or drag to remove"
		when "recolor" then "Recolor clues: click or drag to change logical color"
		else "Place clues: left-click to apply, right-click to pick up"
	@SetStatus message, Editor.C and Editor.C.text or Color(232, 238, 244)
