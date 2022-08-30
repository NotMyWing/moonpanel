AddCSLuaFile!

Canvas = Moonpanel.Canvas

entityReference = (socket) ->
	return unless socket
	entity = socket\GetEntity!
	entity and entity\ExportData! or nil

referenceType = (reference) -> reference and reference.Type

chooseSeamSocket = (left, right) ->
	leftRef = entityReference left
	rightRef = entityReference right
	if referenceType leftRef
		return left, leftRef
	if referenceType rightRef
		return right, rightRef
	left or right, nil

addNeighbor = (first, second) ->
	return unless first and second and first ~= second
	for neighbor in *first.neighbors
		return if neighbor == second
	table.insert first.neighbors, second

connect = (first, second, socket = nil) ->
	addNeighbor first, second
	addNeighbor second, first
	if socket
		first.edgeSockets or= {}
		second.edgeSockets or= {}
		first.edgeSockets[second] = socket
		second.edgeSockets[first] = socket

disconnect = (node) ->
	for neighbor in *table.Copy node.neighbors
		for index = #neighbor.neighbors, 1, -1
			table.remove neighbor.neighbors, index if neighbor.neighbors[index] == node
	node.neighbors = {}

Canvas.BuildContinuousNodes = (canvas) ->
	data = canvas\GetData!
	return {} unless data and data.Meta
	width = math.floor tonumber(data.Meta.Width) or 0
	height = math.floor tonumber(data.Meta.Height) or 0
	return {} if width < 1 or height < 1
	barLength = canvas\GetBarLength!
	barWidth = canvas\GetBarWidth!
	resolution = Canvas.Resolution
	nodes, nodeMap = {}, {}

	insertNode = (node) ->
		node.id = #nodes + 1
		node.neighbors or= {}
		table.insert nodes, node
		node

	for y = 0, height
		nodeMap[y] = {}
		for x = 0, width - 1
			socket = canvas\GetIntersectionSocketAt x + 1, y + 1
			origin = socket\GetRenderOrigin!
			nodeMap[y][x] = insertNode {
				x: x - width / 2
				y: y - height / 2
				screenX: origin.x
				screenY: origin.y
				:socket
			}

	pathNode = (socket, nodeA, nodeB, horizontal, pathX, pathY) ->
		return unless socket and nodeA and nodeB
		reference = entityReference socket
		typeName = referenceType reference
		return if typeName == "Invisible"
		dx = if horizontal then 1 else 0
		dy = if horizontal then 0 else 1
		fromScreenX, fromScreenY = nodeA.screenX, nodeA.screenY
		toScreenX = if horizontal and pathX == width - 1
			nodeA.screenX + barLength
		else
			nodeB.screenX
		toScreenY = nodeB.screenY
		midpoint = ->
			insertNode {
				x: nodeA.x + dx * 0.5
				y: nodeA.y + dy * 0.5
				screenX: (fromScreenX + toScreenX) * 0.5
				screenY: (fromScreenY + toScreenY) * 0.5
				:socket
			}

		if typeName == "Disjoint"
			gap = (data.Dim.DisjointLength or Canvas.DefaultDisjointLength or 0.4) * 0.5
			firstFraction, secondFraction = 0.5 - gap, 0.5 + gap
			first = insertNode {
				x: nodeA.x + dx * firstFraction
				y: nodeA.y + dy * firstFraction
				screenX: fromScreenX + (toScreenX - fromScreenX) * firstFraction
				screenY: fromScreenY + (toScreenY - fromScreenY) * firstFraction
				break: true
				:socket
			}
			second = insertNode {
				x: nodeA.x + dx * secondFraction
				y: nodeA.y + dy * secondFraction
				screenX: fromScreenX + (toScreenX - fromScreenX) * secondFraction
				screenY: fromScreenY + (toScreenY - fromScreenY) * secondFraction
				break: true
				:socket
			}
			first.pairedBreak, second.pairedBreak = second, first
			connect nodeA, first, socket
			connect nodeB, second, socket
			return

		if typeName == "Start" or typeName == "End"
			middle = midpoint!
			middle.clickable = true if typeName == "Start"
			connect nodeA, middle, socket
			connect middle, nodeB, socket
			if typeName == "End"
				-- There is no left or right edge on a periodic surface. Only a
				-- horizontal boundary path can host an exit, and its stub is
				-- strictly vertical even at the authored seam corners.
				if horizontal and (pathY == 0 or pathY == height)
					exitDY = pathY == 0 and -0.25 or 0.25
					exitNode = insertNode {
						x: middle.x
						y: middle.y + exitDY
						screenX: middle.screenX
						screenY: middle.screenY + exitDY * barWidth * 4
						exit: true
						:socket
					}
					connect middle, exitNode, socket
			return

		connect nodeA, nodeB, socket

	-- Horizontal paths include the seam edge as their final authored column.
	for y = 0, height
		for x = 0, width - 1
			pathNode canvas\GetHPathSocketAt(x + 1, y + 1), nodeMap[y][x],
				nodeMap[y][(x + 1) % width], true, x, y

	-- The two authored vertical boundary columns alias one physical seam.
	for y = 0, height - 1
		for x = 0, width - 1
			local socket
			if x == 0
				socket = chooseSeamSocket canvas\GetVPathSocketAt(1, y + 1),
					canvas\GetVPathSocketAt(width + 1, y + 1)
			else
				socket = canvas\GetVPathSocketAt x + 1, y + 1
			pathNode socket, nodeMap[y][x], nodeMap[y + 1][x], false, x, y

	-- Intersection clues on both authored seam columns also alias.
	for y = 0, height
		for x = 0, width - 1
			node = nodeMap[y][x]
			local socket, reference
			if x == 0
				socket, reference = chooseSeamSocket canvas\GetIntersectionSocketAt(1, y + 1),
					canvas\GetIntersectionSocketAt(width + 1, y + 1)
				node.socket = socket
			else
				socket = canvas\GetIntersectionSocketAt x + 1, y + 1
				reference = entityReference socket
			typeName = referenceType reference
			if typeName == "Start"
				node.clickable = true
			elseif typeName == "Invisible"
				node.invisible = true
				disconnect node
			elseif typeName == "End"
				exitY = y == 0 and -0.25 or y == height and 0.25 or nil
				if exitY
					exitNode = insertNode {
						x: node.x
						y: node.y + exitY
						screenX: node.screenX
						screenY: node.screenY + exitY * barWidth * 4
						exit: true
						:socket
					}
					connect node, exitNode, socket

	nodes
