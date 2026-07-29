AddCSLuaFile!

pathIntersectionPair = (socket) ->
	if socket\IsHorizontal!
		socket\GetLeft!, socket\GetRight!
	else
		socket\GetAbove!, socket\GetBelow!

pathMidpointNode = (socket, attrs = {}) ->
	intA, intB = pathIntersectionPair socket
	return unless intA and intB

	nodeA = intA\GetPathNode!
	nodeB = intB\GetPathNode!
	return unless nodeA and nodeB

	ro = socket\GetRenderOrigin!
	node = {
		x: (nodeA.x + nodeB.x) / 2
		y: (nodeA.y + nodeB.y) / 2
		screenX: ro.x
		screenY: ro.y
		socket: socket
		neighbors: { nodeA, nodeB }
	}

	for key, value in pairs attrs
		node[key] = value

	node, nodeA, nodeB

insertPathNode = (pathNodes, node) ->
	node.id = #pathNodes + 1
	table.insert pathNodes, node
	node

pathEndExitNode = (socket, midpoint) ->
	canvas = socket\GetCanvas!
	barWidth = canvas\GetBarWidth!
	resolution = Moonpanel.Canvas.Resolution

	if Moonpanel.Canvas.UsesVerticalBoundaryExits(canvas\GetSurfaceSpec!)
		return unless socket\IsHorizontal!
		height = canvas\GetData!.Meta.Height
		return unless socket\GetY! == 1 or socket\GetY! == height + 1
		sign = socket\GetY! == 1 and -1 or 1
		return {
			x: midpoint.x
			y: midpoint.y + sign * 0.25
			screenX: midpoint.screenX
			screenY: midpoint.screenY + sign * barWidth
			socket: socket
			exit: true
			neighbors: { midpoint }
		}

	if socket\IsHorizontal!
		sign = midpoint.screenY <= resolution * 0.5 and -1 or 1
		{
			x: midpoint.x
			y: midpoint.y + sign * 0.25
			screenX: midpoint.screenX
			screenY: midpoint.screenY + sign * barWidth
			socket: socket
			exit: true
			neighbors: { midpoint }
		}
	else
		sign = midpoint.screenX <= resolution * 0.5 and -1 or 1
		{
			x: midpoint.x + sign * 0.25
			y: midpoint.y
			screenX: midpoint.screenX + sign * barWidth
			screenY: midpoint.screenY
			socket: socket
			exit: true
			neighbors: { midpoint }
		}

pathBounds = (entity) ->
	socket = entity\GetSocket!
	ro = socket\GetRenderOrigin!
	barLength = if socket\IsHorizontal!
		socket\GetCanvas!\GetBarLength!
	else
		socket\GetCanvas!\GetVerticalBarLength!
	barWidth = socket\GetCanvas!\GetBarWidth!

	if socket\IsHorizontal!
		ro.x - barLength / 2, ro.y - barWidth / 2, barLength, barWidth
	else
		ro.x - barWidth / 2, ro.y - barLength / 2, barWidth, barLength

class Moonpanel.Canvas.Entities.PathStart extends Moonpanel.Canvas.Entities.BasePath
	@CanonicalType = "Start"

	PopulatePathNodes: (pathNodes) =>
		node, nodeA, nodeB = pathMidpointNode @GetSocket!, { clickable: true }
		return unless node

		table.insert nodeA.neighbors, node
		table.insert nodeB.neighbors, node
		insertPathNode pathNodes, node

		@__pathNode = node
		@__parents = { nodeA, nodeB }

	CleanUpPathNodes: (pathNodes) =>
		return unless @__pathNode

		for parent in *@__parents
			for i, neighbor in ipairs parent.neighbors
				if neighbor == @__pathNode
					table.remove parent.neighbors, i
					break

		for i, node in ipairs pathNodes
			if node == @__pathNode
				table.remove pathNodes, i
				break

class Moonpanel.Canvas.Entities.PathEnd extends Moonpanel.Canvas.Entities.BasePath
	@CanonicalType = "End"

	PopulatePathNodes: (pathNodes) =>
		midpoint, nodeA, nodeB = pathMidpointNode @GetSocket!
		return unless midpoint

		exitNode = pathEndExitNode @GetSocket!, midpoint

		if exitNode
			table.insert midpoint.neighbors, exitNode
		table.insert nodeA.neighbors, midpoint
		table.insert nodeB.neighbors, midpoint
		insertPathNode pathNodes, midpoint
		if exitNode
			insertPathNode pathNodes, exitNode

		@__pathNode = midpoint
		@__exitNode = exitNode
		@__parents = { nodeA, nodeB }

	CleanUpPathNodes: (pathNodes) =>
		return unless @__pathNode

		for parent in *@__parents
			for i, neighbor in ipairs parent.neighbors
				if neighbor == @__pathNode
					table.remove parent.neighbors, i
					break

		if @__exitNode
			for i, neighbor in ipairs @__pathNode.neighbors
				if neighbor == @__exitNode
					table.remove @__pathNode.neighbors, i
					break

		removeNodes = { @__pathNode }
		if @__exitNode
			table.insert removeNodes, @__exitNode
		for removeNode in *removeNodes
			for i, node in ipairs pathNodes
				if node == removeNode
					table.remove pathNodes, i
					break

class Moonpanel.Canvas.Entities.PathHexagon extends Moonpanel.Canvas.Entities.BasePath
	@CanonicalType = "Hexagon"

	RenderHexagon: (overlay = false) =>
		canvas = @GetCanvas!
		Moonpanel.Canvas.RenderHexagonEntity @,
			Moonpanel.Canvas.GetHexagonSize(canvas), overlay

	RenderBelowTrace: => @RenderHexagon false
	RenderOverlay: => @RenderHexagon true

class Moonpanel.Canvas.Entities.Disjoint extends Moonpanel.Canvas.Entities.BasePath
	PopulatePathNodes: (pathNodes) =>
		socket = @GetSocket!

		local intA, intB
		if socket\IsHorizontal!
			intA = socket\GetLeft!
			intB = socket\GetRight!
		else
			intA = socket\GetAbove!
			intB = socket\GetBelow!

		return unless intA and intB

		nodeA = intA\GetPathNode!
		nodeB = intB\GetPathNode!
		return unless nodeA and nodeB

		dx = nodeB.x - nodeA.x
		dy = nodeB.y - nodeA.y
		dsx = nodeB.screenX - nodeA.screenX
		dsy = nodeB.screenY - nodeA.screenY
		gap = (@GetCanvas!\GetData!.Dim.DisjointLength or
			Moonpanel.Canvas.DefaultDisjointLength or 0.4) / 2

		breakA = {
			x: nodeA.x + dx * (0.5 - gap)
			y: nodeA.y + dy * (0.5 - gap)
			screenX: nodeA.screenX + dsx * (0.5 - gap)
			screenY: nodeA.screenY + dsy * (0.5 - gap)
			break: true
			socket: socket
			neighbors: { nodeA }
		}

		breakB = {
			x: nodeB.x - dx * (0.5 - gap)
			y: nodeB.y - dy * (0.5 - gap)
			screenX: nodeB.screenX - dsx * (0.5 - gap)
			screenY: nodeB.screenY - dsy * (0.5 - gap)
			break: true
			socket: socket
			neighbors: { nodeB }
		}

		breakA.pairedBreak = breakB
		breakB.pairedBreak = breakA

		table.insert nodeA.neighbors, breakA
		table.insert nodeB.neighbors, breakB
		insertPathNode pathNodes, breakA
		insertPathNode pathNodes, breakB

		@__breaks = { breakA, breakB }
		@__breakParents = { nodeA, nodeB }

	CleanUpPathNodes: (pathNodes) =>
		return unless @__breaks

		for breakNode in *@__breaks
			for parent in *@__breakParents
				for i, neighbor in ipairs parent.neighbors
					if neighbor == breakNode
						table.remove parent.neighbors, i
						break

			for i, node in ipairs pathNodes
				if node == breakNode
					table.remove pathNodes, i
					break

	RenderBelowTrace: =>
		return unless CLIENT

		x, y, w, h = pathBounds @
		socket = @GetSocket!
		colors = @GetCanvas!\GetColors!
		surface.SetDrawColor colors.Grid

		gapPct = @GetCanvas!\GetData!.Dim.DisjointLength or
			Moonpanel.Canvas.DefaultDisjointLength or 0.4
		if socket\IsHorizontal!
			gap = w * gapPct
			seg = (w - gap) / 2
			surface.DrawRect x, y, seg, h
			surface.DrawRect x + seg + gap, y, seg, h
		else
			gap = h * gapPct
			seg = (h - gap) / 2
			surface.DrawRect x, y, w, seg
			surface.DrawRect x, y + seg + gap, w, seg

class Moonpanel.Canvas.Entities.InvisiblePath extends Moonpanel.Canvas.Entities.BasePath
	@CanonicalType = "Invisible"

	PopulatePathNodes: =>

	Render: =>
		return unless CLIENT
		return unless @GetCanvas!\GetEditorGeometryVisible!

		x, y, w, h = pathBounds @
		surface.SetDrawColor 0, 0, 0, 80
		surface.DrawRect x, y, w, h
