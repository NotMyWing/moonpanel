RELIEF_CIRCLE_SEGMENTS = 48
RELIEF_MESH_VERTICES = 60000
Moonpanel.Canvas.ReliefMeshVersion = 8

reliefPrimitives = (topology) ->
	paths, nodes = {}, {}
	barWidth = topology.barWidth
	resolution = topology.resolution
	wrap = topology.wrap == true
	visible = {}
	for node in *topology.visibleNodes
		visible[node] = true
	addNode = (node, screenX = node.screenX) ->
		feedsExit = false
		for neighbor in *node.neighbors
			feedsExit = true if neighbor.exit
		nodes[#nodes + 1] = {
			:screenX
			screenY: node.screenY
			radius: (node.clickable and 1.25 or 0.5) * barWidth
			drawCircle: visible[node] == true
			clickable: node.clickable == true
			exit: node.exit == true
			:feedsExit
			incidents: {}
		}
	for node in *topology.nodes
		continue if node.break or node.invisible or
			topology.hiddenNodes[node]
		addNode node
		if wrap and math.abs(node.screenX) < barWidth * 1.25
			addNode node, resolution
	addPath = (path, screenX = path.screenX) ->
		angle = math.rad path.angle
		paths[#paths + 1] = {
			:screenX
			screenY: path.screenY
			distance: path.distance
			startBreak: path.startBreak == true
			endBreak: path.endBreak == true
			halfDistance: path.distance * 0.5
			angle: path.angle
			cosine: math.cos angle
			sine: math.sin angle
		}
	for path in *topology.paths
		addPath path
		if wrap and math.abs(path.screenX) < barWidth and
				math.abs(path.angle) == 90
			addPath path, resolution
	toleranceSquared = math.max(4, barWidth * 0.25)^2
	for path in *paths
		for side in *{-1, 1}
			x = path.screenX + path.cosine * path.halfDistance * side
			y = path.screenY + path.sine * path.halfDistance * side
			local closest, closestDistance
			for node in *nodes
				dx, dy = node.screenX - x, node.screenY - y
				distance = dx^2 + dy^2
				if distance <= toleranceSquared and
						(not closestDistance or distance < closestDistance)
					closest, closestDistance = node, distance
			if closest
				direction = side < 0 and path.angle or path.angle + 180
				closest.incidents[#closest.incidents + 1] = math.rad direction
				if side < 0 then path.startNode = closest else path.endNode = closest
	for node in *nodes
		corner = #node.incidents == 2 and
			math.abs(math.sin(node.incidents[1] - node.incidents[2])) > 0.5
		node.hasDiagonal = false
		for incident in *node.incidents
			node.hasDiagonal = true if math.abs(math.sin(incident) *
				math.cos(incident)) > 0.1
		node.roundWall = node.clickable or node.exit or
			#node.incidents == 1 or corner
	for path in *paths
		continue unless path.startNode and path.endNode and
			(path.startNode.exit or path.endNode.exit)
		dx = path.endNode.screenX - path.startNode.screenX
		dy = path.endNode.screenY - path.startNode.screenY
		distance = math.sqrt dx^2 + dy^2
		continue if distance <= 0
		path.screenX = (path.startNode.screenX + path.endNode.screenX) * 0.5
		path.screenY = (path.startNode.screenY + path.endNode.screenY) * 0.5
		path.distance, path.halfDistance = distance, distance * 0.5
		path.cosine, path.sine = dx / distance, dy / distance
		path.angle = math.deg math.atan2 dy, dx
		if path.startNode.exit
			path.startNode.incidents[1] = math.rad path.angle
		else
			path.endNode.incidents[1] = math.rad(path.angle + 180)
	paths, nodes, barWidth

buildReliefMeshes = (topology, pillar) ->
	resolution = topology.resolution
	paths, nodes, barWidth = reliefPrimitives topology
	halfWidth = barWidth * 0.5
	rimWidth = math.max 1.5, barWidth * 0.12
	faceHeight = barWidth * 0.24
	wallHeight = barWidth * 0.38
	innerWidth = halfWidth
	outerWidth = halfWidth + rimWidth
	faceTriangles, wallTriangles = {}, {}

	vertex = (x, y, height, normalX, normalY, shade = 1) ->
		u, v = x / resolution, y / resolution
		local position, normal
		if pillar
			angle = u * math.pi * 2
			radius = 1 + height * math.pi * 2 / resolution
			position = Vector math.cos(angle) * radius,
				math.sin(angle) * radius, 1 - v
			if normalX
				normal = Vector -math.sin(angle) * normalX,
					math.cos(angle) * normalX, -normalY
				normal\Normalize!
			else
				normal = Vector math.cos(angle), math.sin(angle), 0
		else
			position = Vector x, y, -height
			normal = if normalX
				Vector normalX, normalY, 0
			else
				Vector 0, 0, -1
		{
			pos: position
			:normal, :u, :v
			color: Color shade * 255, shade * 255, shade * 255
		}

	triangle = (triangles, a, b, c) ->
		triangles[#triangles + 1] = a
		triangles[#triangles + 1] = b
		triangles[#triangles + 1] = c
	quad = (triangles, a, b, c, d, reverse = false) ->
		if reverse
			triangle triangles, a, d, c
			triangle triangles, a, c, b
		else
			triangle triangles, a, b, c
			triangle triangles, a, c, d

	pathPoint = (path, along, across, height, normalX, normalY, shade) ->
		x = path.screenX + path.cosine * along - path.sine * across
		y = path.screenY + path.sine * along + path.cosine * across
		vertex x, y, height, normalX, normalY, shade

	endpointTrim = (node, pathAngle, outer, lateralSide) ->
		return 0 unless node
		width = outer and outerWidth or innerWidth
		trim = 0
		if node.drawCircle and node.roundWall
			radius = node.radius + (outer and rimWidth or 0)
			trim = math.sqrt math.max 0, radius^2 - width^2
			return trim if node.clickable or node.exit or #node.incidents ~= 2
		pathRadians = math.rad pathAngle
		if #node.incidents == 3 and not node.feedsExit
			lateralAngle = pathRadians + lateralSide * math.pi * 0.5
			lateralMissing = true
			for incident in *node.incidents
				if math.cos(lateralAngle - incident) > 0.9
					lateralMissing = false
					break
			trim = width if lateralMissing
		for incident in *node.incidents
			delta = math.atan2 math.sin(incident - pathRadians),
				math.cos(incident - pathRadians)
			if delta * lateralSide > 0.0001
				miter = width / math.tan(math.abs(delta) * 0.5)
				trim = math.max trim, miter
		trim

	for path in *paths
		faceStart = -path.halfDistance +
			((path.startNode or path.startBreak) and 0 or rimWidth)
		faceEnd = path.halfDistance -
			((path.endNode or path.endBreak) and 0 or rimWidth)
		face = {
			pathPoint path, faceStart, -innerWidth, faceHeight
			pathPoint path, faceEnd, -innerWidth, faceHeight
			pathPoint path, faceEnd, innerWidth, faceHeight
			pathPoint path, faceStart, innerWidth, faceHeight
		}
		quad faceTriangles, face[1], face[2], face[3], face[4]

		for side in *{-1, 1}
			startOuterTrim = endpointTrim path.startNode, path.angle, true, side
			endOuterTrim = endpointTrim path.endNode, path.angle + 180, true, -side
			startInnerTrim = endpointTrim path.startNode, path.angle, false, side
			endInnerTrim = endpointTrim path.endNode, path.angle + 180, false, -side
			outerStart = -path.halfDistance + startOuterTrim
			outerEnd = path.halfDistance - endOuterTrim
			innerStart = -path.halfDistance + startInnerTrim
			innerEnd = path.halfDistance - endInnerTrim
			continue if outerEnd <= outerStart or innerEnd <= innerStart
			nx, ny = -path.sine * side, path.cosine * side
			outerBottom = pathPoint path, outerStart, outerWidth * side, 0, nx, ny
			outerBottomEnd = pathPoint path, outerEnd, outerWidth * side, 0, nx, ny
			outerTopEnd = pathPoint path, outerEnd, outerWidth * side, wallHeight, nx, ny
			outerTop = pathPoint path, outerStart, outerWidth * side, wallHeight, nx, ny
			quad wallTriangles, outerBottom, outerBottomEnd, outerTopEnd,
				outerTop, side > 0
			rimOuter = pathPoint path, outerStart, outerWidth * side, wallHeight,
				nil, nil
			rimOuterEnd = pathPoint path, outerEnd, outerWidth * side, wallHeight,
				nil, nil
			rimInner = pathPoint path, innerStart, innerWidth * side, wallHeight
			rimInnerEnd = pathPoint path, innerEnd, innerWidth * side, wallHeight
			quad wallTriangles, rimInner, rimInnerEnd, rimOuterEnd, rimOuter,
				side < 0
			innerBottom = pathPoint path, innerStart, innerWidth * side, faceHeight, -nx, -ny
			innerBottomEnd = pathPoint path, innerEnd, innerWidth * side, faceHeight, -nx, -ny
			innerTop = pathPoint path, innerStart, innerWidth * side, wallHeight,
				-nx, -ny
			innerTopEnd = pathPoint path, innerEnd, innerWidth * side, wallHeight,
				-nx, -ny
			quad wallTriangles, innerBottom, innerBottomEnd, innerTopEnd,
				innerTop, side < 0

		for side in *{-1, 1}
			node = if side < 0 then path.startNode else path.endNode
			continue if node
			isBreak = if side < 0 then path.startBreak else path.endBreak
			alongInner = side * (path.halfDistance - rimWidth)
			if isBreak
				alongInner = side * path.halfDistance
				alongLip = side * (path.halfDistance + rimWidth)
				nx, ny = path.cosine * side, path.sine * side
				outerA = pathPoint path, alongLip, -outerWidth, 0, nx, ny
				outerB = pathPoint path, alongLip, outerWidth, 0, nx, ny
				outerTopB = pathPoint path, alongLip, outerWidth,
					wallHeight, nx, ny
				outerTopA = pathPoint path, alongLip, -outerWidth,
					wallHeight, nx, ny
				quad wallTriangles, outerA, outerB, outerTopB, outerTopA,
					side < 0

				topInnerA = pathPoint path, alongInner, -outerWidth, wallHeight
				topOuterA = pathPoint path, alongLip, -outerWidth, wallHeight
				topOuterB = pathPoint path, alongLip, outerWidth, wallHeight
				topInnerB = pathPoint path, alongInner, outerWidth, wallHeight
				quad wallTriangles, topInnerA, topOuterA, topOuterB,
					topInnerB, side < 0

				innerBottomA = pathPoint path, alongInner, -innerWidth,
					faceHeight, -nx, -ny
				innerBottomB = pathPoint path, alongInner, innerWidth,
					faceHeight, -nx, -ny
				innerTopB = pathPoint path, alongInner, innerWidth,
					wallHeight, -nx, -ny
				innerTopA = pathPoint path, alongInner, -innerWidth,
					wallHeight, -nx, -ny
				quad wallTriangles, innerBottomA, innerBottomB, innerTopB,
					innerTopA, side > 0

				for lateral in *{-1, 1}
					wallNX = -path.sine * lateral
					wallNY = path.cosine * lateral
					sideInnerBottom = pathPoint path, alongInner,
						outerWidth * lateral, 0, wallNX, wallNY
					sideOuterBottom = pathPoint path, alongLip,
						outerWidth * lateral, 0, wallNX, wallNY
					sideOuterTop = pathPoint path, alongLip,
						outerWidth * lateral, wallHeight, wallNX, wallNY
					sideInnerTop = pathPoint path, alongInner,
						outerWidth * lateral, wallHeight, wallNX, wallNY
					quad wallTriangles, sideInnerBottom, sideOuterBottom,
						sideOuterTop, sideInnerTop, side * lateral > 0
				continue

			alongOuter = side * (path.halfDistance + rimWidth)
			nx, ny = path.cosine * side, path.sine * side
			outerA = pathPoint path, alongOuter, -outerWidth, 0, nx, ny
			outerB = pathPoint path, alongOuter, outerWidth, 0, nx, ny
			outerC = pathPoint path, alongOuter, outerWidth, wallHeight, nx, ny
			outerD = pathPoint path, alongOuter, -outerWidth, wallHeight, nx, ny
			quad wallTriangles, outerA, outerB, outerC, outerD, side < 0
			innerA = pathPoint path, alongInner, -innerWidth, wallHeight
			innerB = pathPoint path, alongInner, innerWidth, wallHeight
			rimOuterA = pathPoint path, alongOuter, -outerWidth, wallHeight,
				nil, nil
			rimOuterB = pathPoint path, alongOuter, outerWidth, wallHeight,
				nil, nil
			quad wallTriangles, innerA, innerB, rimOuterB, rimOuterA, side < 0

	hasDirection = (node, angle) ->
		for incident in *node.incidents
			return true if math.cos(angle - incident) > 0.9
		false

	nodePoint = (node, angle, along, across, height, normalX, normalY) ->
		cosine, sine = math.cos(angle), math.sin(angle)
		x = node.screenX + cosine * along - sine * across
		y = node.screenY + sine * along + cosine * across
		vertex x, y, height, normalX, normalY

	for node in *nodes
		continue if node.roundWall or node.feedsExit or node.hasDiagonal or
			#node.incidents < 2
		for angle in *{ 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
			continue if hasDirection node, angle
			continue unless hasDirection node, angle + math.pi
			cosine, sine = math.cos(angle), math.sin(angle)
			outerA = nodePoint node, angle, outerWidth, -outerWidth, 0,
				cosine, sine
			outerB = nodePoint node, angle, outerWidth, outerWidth, 0,
				cosine, sine
			outerTopB = nodePoint node, angle, outerWidth, outerWidth,
				wallHeight, cosine, sine
			outerTopA = nodePoint node, angle, outerWidth, -outerWidth,
				wallHeight, cosine, sine
			quad wallTriangles, outerA, outerB, outerTopB, outerTopA
			rimOuterA = nodePoint node, angle, outerWidth, -outerWidth,
				wallHeight
			rimOuterB = nodePoint node, angle, outerWidth, outerWidth,
				wallHeight
			rimInnerA = nodePoint node, angle, innerWidth, -innerWidth,
				wallHeight
			rimInnerB = nodePoint node, angle, innerWidth, innerWidth,
				wallHeight
			quad wallTriangles, rimOuterA, rimOuterB, rimInnerB, rimInnerA
			innerBottomA = nodePoint node, angle, innerWidth, -innerWidth,
				faceHeight, -cosine, -sine
			innerBottomB = nodePoint node, angle, innerWidth, innerWidth,
				faceHeight, -cosine, -sine
			innerTopB = nodePoint node, angle, innerWidth, innerWidth,
				wallHeight, -cosine, -sine
			innerTopA = nodePoint node, angle, innerWidth, -innerWidth,
				wallHeight, -cosine, -sine
			quad wallTriangles, innerBottomA, innerBottomB, innerTopB,
				innerTopA, true

	arcCovered = (node, angle) ->
		for incident in *node.incidents
			delta = math.atan2 math.sin(angle - incident), math.cos(angle - incident)
			halfArc = math.asin math.min(1, outerWidth / (node.radius + rimWidth))
			return true if math.abs(delta) <= halfArc
		false

	emitCircleWall = (node, innerRadius, outerRadius, outerAngle0,
		outerAngle1, innerAngle0 = outerAngle0, innerAngle1 = outerAngle1) ->
		cos0, sin0 = math.cos(outerAngle0), math.sin(outerAngle0)
		cos1, sin1 = math.cos(outerAngle1), math.sin(outerAngle1)
		innerCos0, innerSin0 = math.cos(innerAngle0), math.sin(innerAngle0)
		innerCos1, innerSin1 = math.cos(innerAngle1), math.sin(innerAngle1)
		outer0 = vertex node.screenX + cos0 * outerRadius,
			node.screenY + sin0 * outerRadius, wallHeight, cos0, sin0
		outer1 = vertex node.screenX + cos1 * outerRadius,
			node.screenY + sin1 * outerRadius, wallHeight, cos1, sin1
		outerBottom0 = vertex node.screenX + cos0 * outerRadius,
			node.screenY + sin0 * outerRadius, 0, cos0, sin0
		outerBottom1 = vertex node.screenX + cos1 * outerRadius,
			node.screenY + sin1 * outerRadius, 0, cos1, sin1
		quad wallTriangles, outerBottom1, outerBottom0, outer0, outer1, true
		rimOuter0 = vertex node.screenX + cos0 * outerRadius,
			node.screenY + sin0 * outerRadius, wallHeight
		rimOuter1 = vertex node.screenX + cos1 * outerRadius,
			node.screenY + sin1 * outerRadius, wallHeight
		inner0 = vertex node.screenX + innerCos0 * innerRadius,
			node.screenY + innerSin0 * innerRadius, wallHeight
		inner1 = vertex node.screenX + innerCos1 * innerRadius,
			node.screenY + innerSin1 * innerRadius, wallHeight
		quad wallTriangles, inner0, rimOuter0, rimOuter1, inner1
		innerBottom0 = vertex node.screenX + innerCos0 * innerRadius,
			node.screenY + innerSin0 * innerRadius, faceHeight,
			-innerCos0, -innerSin0
		innerBottom1 = vertex node.screenX + innerCos1 * innerRadius,
			node.screenY + innerSin1 * innerRadius, faceHeight,
			-innerCos1, -innerSin1
		innerTop0 = vertex node.screenX + innerCos0 * innerRadius,
			node.screenY + innerSin0 * innerRadius, wallHeight,
			-innerCos0, -innerSin0
		innerTop1 = vertex node.screenX + innerCos1 * innerRadius,
			node.screenY + innerSin1 * innerRadius, wallHeight,
			-innerCos1, -innerSin1
		quad wallTriangles, innerBottom1, innerBottom0, innerTop0, innerTop1

	for node in *nodes
		continue unless node.drawCircle
		innerRadius = node.radius
		outerRadius = node.radius + rimWidth
		center = vertex node.screenX, node.screenY, faceHeight
		if node.roundWall and #node.incidents == 1 and not node.clickable
			startAngle = node.incidents[1] + math.pi * 0.5
			steps = math.ceil RELIEF_CIRCLE_SEGMENTS * 0.5
			for step = 0, steps - 1
				a0 = startAngle + math.pi * step / steps
				a1 = startAngle + math.pi * (step + 1) / steps
				emitCircleWall node, innerRadius, outerRadius, a0, a1
		elseif node.roundWall
			circle = math.pi * 2
			cuts = {
				{ outer: 0, inner: 0 }
				{ outer: circle, inner: circle }
			}
			outerHalfArc = math.asin math.min(1, outerWidth / outerRadius)
			innerHalfArc = math.asin math.min(1, innerWidth / innerRadius)
			for incident in *node.incidents
				for side in *{-1, 1}
					rawOuter = incident + outerHalfArc * side
					rawInner = incident + innerHalfArc * side
					shift = -math.floor(rawOuter / circle) * circle
					cut = rawOuter + shift
					if cut > 0.000001 and cut < circle - 0.000001
						cuts[#cuts + 1] = {
							outer: cut
							inner: rawInner + shift
						}
			table.sort cuts, (a, b) -> a.outer < b.outer
			maximumArc = circle / RELIEF_CIRCLE_SEGMENTS
			for index = 1, #cuts - 1
				first, last = cuts[index], cuts[index + 1]
				continue if arcCovered node, (first.outer + last.outer) * 0.5
				steps = math.max 1,
					math.ceil((last.outer - first.outer) / maximumArc)
				for step = 0, steps - 1
					t0, t1 = step / steps, (step + 1) / steps
					outer0 = first.outer + (last.outer - first.outer) * t0
					outer1 = first.outer + (last.outer - first.outer) * t1
					inner0 = first.inner + (last.inner - first.inner) * t0
					inner1 = first.inner + (last.inner - first.inner) * t1
					emitCircleWall node, innerRadius, outerRadius, outer0,
						outer1, inner0, inner1
		for index = 0, RELIEF_CIRCLE_SEGMENTS - 1
			a0 = math.pi * 2 * index / RELIEF_CIRCLE_SEGMENTS
			a1 = math.pi * 2 * (index + 1) / RELIEF_CIRCLE_SEGMENTS
			face0 = vertex node.screenX + math.cos(a0) * innerRadius,
				node.screenY + math.sin(a0) * innerRadius, faceHeight
			face1 = vertex node.screenX + math.cos(a1) * innerRadius,
				node.screenY + math.sin(a1) * innerRadius, faceHeight
			triangle faceTriangles, center, face0, face1

	buildMeshes = (triangles, material) ->
		meshes = {}
		for first = 1, #triangles, RELIEF_MESH_VERTICES
			chunk = {}
			last = math.min #triangles, first + RELIEF_MESH_VERTICES - 1
			for index = first, last
				chunk[#chunk + 1] = triangles[index]
			meshObject = Mesh material
			meshObject\BuildFromTriangles chunk
			meshes[#meshes + 1] = meshObject
		meshes
	faces = buildMeshes faceTriangles
	walls = buildMeshes wallTriangles, Moonpanel.Canvas.ReliefWallMaterial
	faces, walls

Moonpanel.Canvas.BuildReliefMeshes = buildReliefMeshes
