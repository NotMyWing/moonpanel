return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

CLUE_TOOLTIPS = {
	Color: {
		title: "Square"
		body: "Squares divide the panel into color groups.\n\nA region may contain any number of squares of one color, but cannot contain squares of different colors. Regions without squares are allowed.\n\nPlace on: cells."
	}
	Sun: {
		title: "Star"
		body: "For each star, its region must contain exactly two symbols of that star's color. The matching symbol may be another star or a different clue with the same rule color.\n\nPlace on: cells."
	}
	Eraser: {
		title: "Eraser"
		body: "An eraser cancels one other clue in the same region. The region is valid when one cancellation per eraser leaves all remaining clues satisfied.\n\nPlace on: cells."
	}
	Triangle: {
		title: "Triangle"
		body: "The number of pips is the exact number of this cell's edges that must be touched by the path.\n\nPlace on: cells."
	}
	Polyomino: {
		title: "Polyomino"
		body: "The polyominoes in a region must combine to match that region's cells exactly. Positive pieces add cells, negative pieces subtract them, and rotatable pieces may be turned while fitting.\n\nPlace on: cells."
	}
	Start: {
		title: "Start"
		body: "A position from which the player may begin drawing the path. A panel may contain multiple starts.\n\nPlace on: supported path nodes."
	}
	End: {
		title: "Exit"
		body: "A position where the path may finish. Reaching it attempts to solve the panel, provided all other rules are satisfied.\n\nPlace on: supported path or boundary sockets."
	}
	Hexagon: {
		title: "Dot"
		body: "A dot normally requires a path to pass through its position. It may belong to the primary path, the symmetric path, or either. Negative dots must remain untraced; invisible dots keep their rule without being shown during play.\n\nPlace on: path segments or intersections."
	}
	Disjoint: {
		title: "Gap"
		body: "A gap breaks this part of the grid, preventing the path from crossing it.\n\nPlace on: path segments."
	}
	Invisible: {
		title: "Invisible Geometry"
		body: "Hides a supported grid element during play without removing it from the panel's topology.\n\nPlace on: supported grid elements."
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

Editor.GetClueDisplayName = (typeName) ->
	definition = CLUE_TOOLTIPS[typeName]
	definition and definition.title or typeName

Editor.AttachTooltip = (panel, typeName) =>
	return unless IsValid panel
	definition = CLUE_TOOLTIPS[typeName]
	return unless definition
	panel\SetTooltip "#{definition.title}\n\n#{definition.body}"

Editor.AttachControlTooltip = (panel, key) =>
	return unless IsValid panel
	text = CONTROL_TOOLTIPS[key]
	panel\SetTooltip text if text
