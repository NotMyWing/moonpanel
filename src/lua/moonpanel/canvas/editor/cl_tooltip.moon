return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor
C = Editor.C

CLUE_TOOLTIPS = {
	Color: {
		title: "Square"
		body: "Squares divide the panel into color groups.\n\nA region may contain any number of squares of one color, but cannot contain squares of different colors. Regions without squares are allowed."
		placeOn: "Cells"
	}
	Sun: {
		title: "Star"
		body: "For each star, its region must contain exactly two symbols of that star's color. The matching symbol may be another star or a different clue with the same rule color."
		placeOn: "Cells"
	}
	Eraser: {
		title: "Eraser"
		body: "An eraser cancels one other clue in the same region. The region is valid when one cancellation per eraser leaves all remaining clues satisfied."
		placeOn: "Cells"
	}
	Triangle: {
		title: "Triangle"
		body: "The number of pips is the exact number of this cell's edges that must be touched by the path."
		placeOn: "Cells"
	}
	Polyomino: {
		title: "Polyomino"
		body: "The polyominoes in a region must combine to match that region's cells exactly. Positive pieces add cells, negative pieces subtract them, and rotatable pieces may be turned while fitting."
		placeOn: "Cells"
	}
	Start: {
		title: "Start"
		body: "A position from which the player may begin drawing the path. A panel may contain multiple starts."
		placeOn: "Supported path nodes"
	}
	End: {
		title: "Exit"
		body: "A position where the path may finish. Reaching it attempts to solve the panel, provided all other rules are satisfied."
		placeOn: "Supported path or boundary sockets"
	}
	Hexagon: {
		title: "Dot"
		body: "A dot normally requires a path to pass through its position. It may belong to the primary path, the symmetric path, or either. Negative dots must remain untraced; invisible dots keep their rule without being shown during play."
		placeOn: "Path segments or intersections"
	}
	Disjoint: {
		title: "Gap"
		body: "A gap breaks this part of the grid, preventing the path from crossing it."
		placeOn: "Path segments"
	}
	Invisible: {
		title: "Geometry Break"
		body: "Removes geometry from the playable panel. On a path it removes that segment; on an intersection it also removes every adjacent segment; on a cell it creates a bounded hole."
		placeOn: "Paths, intersections, or cells"
	}
}

CONTROL_TOOLTIPS = {
	rule_color: "The clue's logical color. Puzzle rules use this color when comparing it with other symbols."
	tint_override: "Changes only how the clue is drawn. Its logical rule color remains unchanged."
	negative: "Uses this clue's negative variant. Negative polyominoes subtract cells; negative dots must remain untraced."
	invisible: "Hides the clue during play while keeping its rule active. It remains visible in the editor."
	rotatable: "Allows this polyomino to be rotated while fitting its region."
	primary_trace: "Only the path drawn directly by the player can satisfy this dot."
	secondary_trace: "Only the symmetric path can satisfy this dot. Panel symmetry must be enabled."
	any_trace: "Either the primary or symmetric path may satisfy this dot."
	continuity: "Joins the panel's left and right edges, so paths and regions can continue across the horizontal seam."
	symmetry_none: "Uses a single path with no mirrored counterpart."
	symmetry_vertical: "Mirrors the path across the panel's vertical axis."
	symmetry_horizontal: "Mirrors the path across the panel's horizontal axis."
	symmetry_rotational: "Creates a second path through 180-degree rotational symmetry."
}

wrapTooltip = (text, width) ->
	surface.SetFont "MoonpanelEditorBody"
	lines = {}
	for paragraph in string.gmatch "#{text or ""}\n", "(.-)\n"
		line = ""
		for word in string.gmatch paragraph, "%S+"
			candidate = line == "" and word or "#{line} #{word}"
			textWidth = surface.GetTextSize candidate
			if textWidth > width and line ~= ""
				table.insert lines, line
				line = word
			else
				line = candidate
		table.insert lines, line
	lines

tooltipTextWidth = (font, values) ->
	surface.SetFont font
	width = 0
	for value in *values
		lineWidth = surface.GetTextSize value
		width = math.max width, lineWidth
	width

ensureTooltip = ->
	return Editor.TooltipPanel if IsValid Editor.TooltipPanel
	panel = with vgui.Create "DPanel"
		\SetVisible false
		\SetMouseInputEnabled false
		\SetKeyboardInputEnabled false
		\SetZPos 32767
		\SetDrawOnTop true if .SetDrawOnTop
	panel.Paint = (_, w, h) ->
		draw.RoundedBox 5, 0, 0, w, h, C.border
		draw.RoundedBox 4, 1, 1, w - 2, h - 2, C.window
		y = 10
		if _.Title
			draw.SimpleText _.Title, "MoonpanelEditorHeading", 12, y,
				C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
			y += 25
		for line in *(_.Lines or {})
			draw.SimpleText line, "MoonpanelEditorBody", 12, y,
				C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
			y += 17
		if _.PlaceOn
			y += 5
			draw.RoundedBox 3, 10, y, w - 20, 22, C.inset
			draw.SimpleText "PLACE ON", "MoonpanelEditorSmall", 17, y + 11,
				C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
			draw.SimpleText _.PlaceOn, "MoonpanelEditorSmall",
				17 + _.PlaceLabelWidth + 8, y + 11,
				C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	panel.Think = (_) ->
		owner = _.Owner
		unless IsValid(owner) and owner\IsHovered!
			_\SetVisible false
			return
		x, y = gui.MouseX! + 16, gui.MouseY! + 18
		_\SetPos math.min(x, ScrW! - _\GetWide! - 8),
			math.min(y, ScrH! - _\GetTall! - 8)
	Editor.TooltipPanel = panel
	panel

Editor.ShowTooltip = (owner) =>
	info = owner and owner.MoonpanelTooltip
	return unless info
	panel = ensureTooltip!
	panel.Owner = owner
	panel.Title = info.title
	panel.PlaceOn = info.placeOn
	panel.PlaceLabelWidth = tooltipTextWidth "MoonpanelEditorSmall", {"PLACE ON"}
	panel.Lines = wrapTooltip info.body, 336
	titleWidth = info.title and tooltipTextWidth(
		"MoonpanelEditorHeading", {info.title}) or 0
	bodyWidth = tooltipTextWidth "MoonpanelEditorBody", panel.Lines
	placeWidth = info.placeOn and tooltipTextWidth(
		"MoonpanelEditorSmall", {"PLACE ON    #{info.placeOn}"}) + 14 or 0
	panel\SetWide math.Clamp(math.max(titleWidth, bodyWidth, placeWidth) + 24,
		80, 360)
	panel\SetTall (info.title and 43 or 18) + #panel.Lines * 17 +
		(info.placeOn and 31 or 0)
	panel\SetVisible true
	panel\MoveToFront!

Editor.HideTooltip = (owner) =>
	panel = @TooltipPanel
	panel\SetVisible false if IsValid(panel) and panel.Owner == owner

Editor.AttachTextTooltip = (panel, body, title = nil, placeOn = nil) =>
	return unless IsValid(panel) and body
	attach = (target) ->
		return unless IsValid target
		target.MoonpanelTooltip = { :title, :body, :placeOn }
		entered, exited = target.OnCursorEntered, target.OnCursorExited
		target.OnCursorEntered = (_) ->
			entered _ if entered
			Editor\ShowTooltip _
		target.OnCursorExited = (_) ->
			exited _ if exited
			Editor\HideTooltip _
		if target.GetChildren
			attach child for child in *target\GetChildren!
	attach panel

Editor.GetClueDisplayName = (typeName) ->
	definition = CLUE_TOOLTIPS[typeName]
	definition and definition.title or typeName

Editor.AttachTooltip = (panel, typeName) =>
	return unless IsValid panel
	definition = CLUE_TOOLTIPS[typeName]
	return unless definition
	@AttachTextTooltip panel, definition.body, definition.title,
		definition.placeOn

Editor.AttachControlTooltip = (panel, key, title = nil) =>
	return unless IsValid panel
	text = CONTROL_TOOLTIPS[key]
	@AttachTextTooltip panel, text, title if text
