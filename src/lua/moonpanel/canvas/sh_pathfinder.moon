AddCSLuaFile!

TRACE_UNITS = 4096
UINT32 = 4294967296
CRC_MASK = 4294967295
CRC_POLYNOMIAL = 3988292384

round = (value) ->
	value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)

clamp = (value, minimum, maximum) ->
	math.max minimum, math.min maximum, value

fallbackXor = (left, right) ->
	left %= UINT32
	right %= UINT32
	result = 0
	place = 1
	for i = 1, 32
		leftBit = left % 2
		rightBit = right % 2
		result += place if leftBit ~= rightBit
		left = math.floor left / 2
		right = math.floor right / 2
		place *= 2
	result

bxor = if bit and bit.bxor
	(left, right) -> bit.bxor(left, right) % UINT32
elseif bit32 and bit32.bxor
	(left, right) -> bit32.bxor(left, right) % UINT32
else
	fallbackXor

CRC_TABLE = {}
for byte = 0, 255
	value = byte
	for i = 1, 8
		value = if value % 2 == 1
			bxor math.floor(value / 2), CRC_POLYNOMIAL
		else
			math.floor value / 2
	CRC_TABLE[byte] = value

appendHash = (crc, value) ->
	value = if "boolean" == type value
		value and 1 or 0
	elseif "number" == type value
		math.floor(value) % UINT32
	else
		0

	for i = 1, 4
		byte = value % 256
		index = bxor(crc % 256, byte)
		crc = bxor math.floor(crc / 256), CRC_TABLE[index]
		value = math.floor value / 256
	crc

finishHash = (crc) -> bxor crc, CRC_MASK

logicalDelta = (a, b, wrapX, periodWidth) ->
	dx = b.x - a.x
	if wrapX and periodWidth and periodWidth > 0
		half = periodWidth * 0.5
		while dx > half
			dx -= periodWidth
		while dx < -half
			dx += periodWidth
	dx, b.y - a.y

canonicalDistance = (a, b, barLength, barWidth, wrapX, periodWidth) ->
	-- Exit nodes use a logical quarter-step only to establish direction. Their
	-- actual control distance has always matched the short rendered stub.
	return barWidth / barLength if a.exit or b.exit

	dx, dy = logicalDelta a, b, wrapX, periodWidth
	distance = math.sqrt dx * dx + dy * dy
	return distance if distance > 0.000001

	-- Compatibility fallback for malformed extension nodes. Normal authored
	-- topology never derives simulation length from rounded render pixels.
	dx = b.screenX - a.screenX
	dy = b.screenY - a.screenY
	math.sqrt(dx * dx + dy * dy) / barLength

logicalDirection = (a, b, wrapX, periodWidth) ->
	dx, dy = logicalDelta a, b, wrapX, periodWidth
	length = math.sqrt dx * dx + dy * dy

	if length <= 0.000001
		dx = b.screenX - a.screenX
		dy = b.screenY - a.screenY
		length = math.sqrt dx * dx + dy * dy

	return 0, 0 if length <= 0.000001
	dx / length, dy / length

class Moonpanel.Canvas.TraceTopology
	new: (data = {}) =>
		-- Keep authored node storage untouched. Symmetry may add logical gap
		-- endpoints, but rebuilding a topology must never append them back into
		-- the canvas node array and duplicate them on the next rebuild.
		@nodes = [node for node in *(data.nodes or {})]
		@barLength = math.max data.barLength or 1, 0.000001
		@barWidth = math.max data.barWidth or 0, 0
		@symmetry = data.symmetry or 0
		@surfaceKind = data.surfaceKind or 0
		@wrapX = data.wrapX == true
		@periodWidth = @wrapX and math.max(tonumber(data.periodWidth) or 0, 0) or 0
		@nodeIds = {}
		@edges = {}
		@starts = {}
		@invalidStarts = {}
		@exits = {}
		@gaps = {}
		@symmetryNodes = {}
		@symmetryEdges = {}
		adjacency = {}
		for node in *@nodes
			adjacency[node] = [neighbor for neighbor in *(node.neighbors or {})]

		@symmetrizeGaps adjacency if @symmetry > 0

		for id, node in ipairs @nodes
			node.id = id
			@nodeIds[node] = id
			@edges[id] = {}
			table.insert @exits, id if node.exit
			table.insert @gaps, id if node.break

		for fromId, node in ipairs @nodes
			neighbors = {}
			for neighbor in *(adjacency[node] or {})
				toId = @nodeIds[neighbor]
				table.insert neighbors, toId if toId

			table.sort neighbors
			for toId in *neighbors
				other = @nodes[toId]
				lengthQ = math.max 1, round canonicalDistance(node, other,
					@barLength, @barWidth, @wrapX, @periodWidth) * TRACE_UNITS
				ux, uy = logicalDirection node, other, @wrapX, @periodWidth
				toScreenX = other.screenX
				if @wrapX and math.abs(other.x - node.x) > @periodWidth * 0.5
					toScreenX = node.screenX + ux * @barLength
				@edges[fromId][toId] = {
					fromId: fromId
					toId: toId
					lengthQ: lengthQ
					unitX: ux
					unitY: uy
					fromScreenX: node.screenX
					fromScreenY: node.screenY
					toScreenX: toScreenX
					toScreenY: other.screenY
					isExit: other.exit == true
					isBreak: other.break == true
					kind: if other.exit
						"exit"
					elseif other.break
						"gap"
					else
						"normal"
				}

		@rebuildSymmetry!
		@rebuildSymmetryEdges!
		@rebuildStarts!
		@revision = @calculateRevision!

	checkSymmetry: (a, b) =>
		return false unless @symmetry > 0 and a and b

		wrapX, periodWidth = @wrapX, @periodWidth
		xMatches = (left, right) ->
			return left == right unless wrapX
			delta = left - right
			half = periodWidth * 0.5
			while delta > half
				delta -= periodWidth
			while delta < -half
				delta += periodWidth
			math.abs(delta) <= 0.000001

		switch @symmetry
			when Moonpanel.Canvas.Symmetry.Rotational
				xMatches(a.x, -b.x) and a.y == -b.y
			when Moonpanel.Canvas.Symmetry.Vertical
				xMatches(a.x, -b.x) and a.y == b.y
			when Moonpanel.Canvas.Symmetry.Horizontal
				a.x == b.x and a.y == -b.y
			else
				false

	_mirrorDelta: (dx, dy) =>
		switch @symmetry
			when Moonpanel.Canvas.Symmetry.Rotational
				-dx, -dy
			when Moonpanel.Canvas.Symmetry.Vertical
				-dx, dy
			when Moonpanel.Canvas.Symmetry.Horizontal
				dx, -dy
			else
				dx, dy

	_findSymmetricalNode: (node, allowBreaks = false) =>
		for candidate in *@nodes
			continue if not allowBreaks and candidate.break
			return candidate if @checkSymmetry node, candidate

	_findBreakAt: (neighbors, x, y) =>
		for candidate in *(neighbors or {})
			continue unless candidate.break
			return candidate if math.abs(candidate.x - x) <= 0.000001 and
				math.abs(candidate.y - y) <= 0.000001

	_removeAdjacency: (adjacency, first, second) =>
		for i = #(adjacency[first] or {}), 1, -1
			table.remove adjacency[first], i if adjacency[first][i] == second

	_hasAdjacency: (adjacency, first, second) =>
		for neighbor in *(adjacency[first] or {})
			return true if neighbor == second
		false

	_addAdjacency: (adjacency, first, second) =>
		for neighbor in *(adjacency[first] or {})
			return if neighbor == second
		adjacency[first] or= {}
		table.insert adjacency[first], second

	-- An authored disjoint is also a disjoint for the mirrored head. The
	-- counterpart path need not contain an authored gap: synthesize topology-
	-- only endpoints there, exactly as the donor path-map symmetrization did.
	-- Rendering therefore reaches both gap lips while serialization stays
	-- unchanged and the authored counterpart remains visually intact.
	symmetrizeGaps: (adjacency) =>
		originalCount = #@nodes
		seen = {}
		for index = 1, originalCount
			firstBreak = @nodes[index]
			continue unless firstBreak.break and not seen[firstBreak]
			secondBreak = firstBreak.pairedBreak
			continue unless secondBreak and adjacency[secondBreak]
			seen[firstBreak] = true
			seen[secondBreak] = true

			firstParent = adjacency[firstBreak] and adjacency[firstBreak][1]
			secondParent = adjacency[secondBreak] and adjacency[secondBreak][1]
			continue unless firstParent and secondParent
			mirrorFirstParent = @_findSymmetricalNode firstParent
			mirrorSecondParent = @_findSymmetricalNode secondParent
			continue unless mirrorFirstParent and mirrorSecondParent

			mirrorBreakAt = (sourceBreak, sourceParent, mirrorParent) ->
				dx, dy = @_mirrorDelta sourceBreak.x - sourceParent.x,
					sourceBreak.y - sourceParent.y
				@_findBreakAt adjacency[mirrorParent], mirrorParent.x + dx,
					mirrorParent.y + dy

			existingFirst = mirrorBreakAt firstBreak, firstParent, mirrorFirstParent
			existingSecond = mirrorBreakAt secondBreak, secondParent, mirrorSecondParent
			directMirror = @_hasAdjacency(adjacency, mirrorFirstParent,
				mirrorSecondParent) and @_hasAdjacency(adjacency,
				mirrorSecondParent, mirrorFirstParent)
			-- Never resurrect an absent/void counterpart path. A mirrored gap may
			-- replace a real edge or reuse a complete authored gap, nothing else.
			continue unless directMirror or existingFirst and existingSecond
			seen[existingFirst] = true if existingFirst
			seen[existingSecond] = true if existingSecond

			if directMirror
				@_removeAdjacency adjacency, mirrorFirstParent, mirrorSecondParent
				@_removeAdjacency adjacency, mirrorSecondParent, mirrorFirstParent

			makeMirror = (sourceBreak, sourceParent, mirrorParent, otherParent) ->
				dx, dy = @_mirrorDelta sourceBreak.x - sourceParent.x,
					sourceBreak.y - sourceParent.y
				dsx, dsy = @_mirrorDelta sourceBreak.screenX - sourceParent.screenX,
					sourceBreak.screenY - sourceParent.screenY
				x = mirrorParent.x + dx
				y = mirrorParent.y + dy
				if existing = @_findBreakAt adjacency[mirrorParent], x, y
					seen[existing] = true
					return existing

				synthetic = {
					:x
					:y
					screenX: mirrorParent.screenX + dsx
					screenY: mirrorParent.screenY + dsy
					break: true
					neighbors: { mirrorParent }
					symmetryGapOtherParent: otherParent
					syntheticSymmetryGap: true
				}
				table.insert @nodes, synthetic
				adjacency[synthetic] = { mirrorParent }
				@_addAdjacency adjacency, mirrorParent, synthetic
				synthetic

			mirrorFirst = existingFirst or makeMirror firstBreak, firstParent,
				mirrorFirstParent, mirrorSecondParent
			mirrorSecond = existingSecond or makeMirror secondBreak, secondParent,
				mirrorSecondParent, mirrorFirstParent
			if mirrorFirst and mirrorSecond
				if mirrorFirst.syntheticSymmetryGap
					mirrorFirst.pairedBreak = mirrorSecond
				if mirrorSecond.syntheticSymmetryGap
					mirrorSecond.pairedBreak = mirrorFirst

	rebuildSymmetry: =>
		return unless @symmetry > 0

		for firstId, first in ipairs @nodes
			continue if @symmetryNodes[firstId]

			for secondId, second in ipairs @nodes
				if @checkSymmetry first, second
					@symmetryNodes[firstId] = secondId
					@symmetryNodes[secondId] = firstId
					break

	rebuildSymmetryEdges: =>
		@symmetryEdges = [{} for i = 1, #@nodes]
		return unless @symmetry > 0

		for fromId = 1, #@nodes
			mirrorFromId = @symmetryNodes[fromId]
			continue unless mirrorFromId
			for toId = 1, #@nodes
				edge = @getEdge fromId, toId
				continue unless edge
				mirrorToId = @symmetryNodes[toId]
				continue unless mirrorToId
				mirror = @getEdge mirrorFromId, mirrorToId
				continue unless mirror
				-- Both heads consume one fixed progress value. An asymmetric
				-- connection is unusable instead of becoming a permanent partial
				-- segment or committing one branch ahead of the other.
				continue unless edge.lengthQ == mirror.lengthQ and
					edge.isExit == mirror.isExit and edge.isBreak == mirror.isBreak
				@symmetryEdges[fromId][toId] = mirror

	rebuildStarts: =>
		@starts = {}
		@invalidStarts = {}
		for id, node in ipairs @nodes
			continue unless node.clickable
			if @symmetry <= 0
				table.insert @starts, id
				continue

			mirrorId = @symmetryNodes[id]
			if mirrorId and @nodes[mirrorId] and @nodes[mirrorId].clickable
				table.insert @starts, id
			else
				table.insert @invalidStarts, id

	getEdge: (fromId, toId) =>
		@edges[fromId] and @edges[fromId][toId]

	getSymmetricalNodeId: (nodeId) =>
		@symmetryNodes[nodeId]

	getSymmetricalEdge: (fromId, toId) =>
		@symmetryEdges[fromId] and @symmetryEdges[fromId][toId]

	isValidStart: (nodeId) =>
		node = @nodes[nodeId]
		return false unless node and node.clickable
		return true unless @symmetry > 0
		mirrorId = @symmetryNodes[nodeId]
		mirrorId and @nodes[mirrorId] and @nodes[mirrorId].clickable == true or false

	getClosestStart: (x, y, radius) =>
		local closest, closestDistance
		periodPixels = @wrapX and @periodWidth * @barLength or 0
		for nodeId in *@starts
			node = @nodes[nodeId]
			dx = math.abs x - node.screenX
			if periodPixels > 0
				dx %= periodPixels
				dx = math.min dx, periodPixels - dx
			distance = math.sqrt dx^2 + (y - node.screenY)^2
			if distance <= radius and (not closestDistance or distance < closestDistance)
				closest = node
				closestDistance = distance

		closest

	calculateRevision: =>
		hash = appendHash CRC_MASK, 17
		hash = appendHash hash, @surfaceKind
		hash = appendHash hash, @wrapX
		hash = appendHash hash, round(@periodWidth * TRACE_UNITS)
		hash = appendHash hash, @symmetry
		hash = appendHash hash, round(@barWidth / @barLength * TRACE_UNITS)
		hash = appendHash hash, #@nodes
		for id, node in ipairs @nodes
			hash = appendHash hash, id
			hash = appendHash hash, round node.x * TRACE_UNITS
			hash = appendHash hash, round node.y * TRACE_UNITS
			hash = appendHash hash, node.clickable == true
			hash = appendHash hash, node.exit == true
			hash = appendHash hash, node.break == true

			for toId = 1, #@nodes
				edge = @getEdge id, toId
				if edge
					hash = appendHash hash, toId
					hash = appendHash hash, edge.lengthQ

		finishHash hash

-- Canonical, serializable trace state. It deliberately contains only fixed
-- integers, stable IDs, booleans, and the explicit lifecycle phase.
class Moonpanel.Canvas.TraceState
	new: (values = {}) =>
		@phase = values.phase or 0
		@stacks = values.stacks or {}
		@active = values.active or false
		@history = values.history or {}
		@touchingExit = values.touchingExit == true
		@revision = values.revision or 0

class Moonpanel.Canvas.TraceEngine
	@Units = TRACE_UNITS
	@Phase = {
		Idle: 0
		Aiming: 1
		Tracing: 2
		Evaluating: 3
		Feedback: 4
	}

	new: (@topology) =>
		@reset!

	reset: =>
		@phase = @@Phase.Idle
		@stacks = {}
		@active = nil
		@history = {}
		@touchingExit = false
		@occlusionConstraint = nil
		@lastConstraintDecisions = {}
		@syncCompatibility!

	beginAiming: =>
		return false unless @phase == @@Phase.Idle or @phase == @@Phase.Feedback
		@phase = @@Phase.Aiming
		true

	start: (startNodeId) =>
		if "table" == type startNodeId
			startNodeId = @topology.nodeIds[startNodeId]

		return false unless startNodeId and @topology\isValidStart startNodeId

		stacks = { { startNodeId } }
		if @topology.symmetry > 0
			secondId = @topology\getSymmetricalNodeId startNodeId
			return false unless secondId and @topology.nodes[secondId].clickable
			table.insert stacks, { secondId }

		@stacks = stacks

		@phase = @@Phase.Tracing
		@active = nil
		@history = {}
		@touchingExit = false
		@syncCompatibility!
		true

	getHistoryIntent: (dx, dy) =>
		table.insert @history, { dx, dy }
		while #@history > 3
			table.remove @history, 1

		hx, hy = 0, 0
		for sample in *@history
			hx += sample[1]
			hy += sample[2]

		if math.abs(hx) * 5 < math.abs(hy)
			hx = 0
		elseif math.abs(hy) * 5 < math.abs(hx)
			hy = 0

		hx, hy

	previewHistoryIntent: (dx, dy) =>
		history = [{ sample[1], sample[2] } for sample in *@history]
		table.insert history, { dx, dy }
		while #history > 3
			table.remove history, 1
		hx, hy = 0, 0
		for sample in *history
			hx += sample[1]
			hy += sample[2]
		if math.abs(hx) * 5 < math.abs(hy)
			hx = 0
		elseif math.abs(hy) * 5 < math.abs(hx)
			hy = 0
		hx, hy

	motionIntent: (dx, dy, hx, hy) =>
		return hx, hy unless @topology.surfaceKind == 1
		return dx, dy unless @active and @active.primary
		edge = @active.primary
		rawAlong = dx * edge.unitX + dy * edge.unitY
		rawPerpendicular = -dx * edge.unitY + dy * edge.unitX
		if math.abs(rawAlong) * 5 < math.abs(rawPerpendicular)
			return dx, dy
		hx, hy

	resolveIntent: (dx, dy) =>
		dx, dy = round(dx or 0), round(dy or 0)
		hx, hy = @previewHistoryIntent dx, dy
		intentX, intentY = @motionIntent dx, dy, hx, hy
		budget = math.max math.abs(dx), math.abs(dy)
		result = { :hx, :hy, :intentX, :intentY, :budget, axis: nil, direction: 0,
			endpointDistanceQ: nil, cornering: false, pendingAxis: nil,
			pendingValueQ: 0 }
		return result if budget == 0
		if @active and @active.primary
			edge = @active.primary
			horizontal = math.abs(edge.unitX) > math.abs(edge.unitY)
			along = intentX * edge.unitX + intentY * edge.unitY
			perpendicular = -intentX * edge.unitY + intentY * edge.unitX
			movement = @movementAlongActive intentX, intentY, budget
			result.axis = horizontal and "x" or "y"
			axisUnit = horizontal and edge.unitX or edge.unitY
			physicalMovement = movement * axisUnit
			result.direction = physicalMovement > 0 and 1 or
				physicalMovement < 0 and -1 or 0
			result.endpointDistanceQ = movement >= 0 and
				math.max(0, @active.maxProgressQ - @active.progressQ) or
				math.max(0, @active.progressQ)
			if movement ~= 0 and math.abs(along) * 5 < math.abs(perpendicular) and
					not edge.isExit and @active.maxProgressQ >= edge.lengthQ
				result.cornering = true
				result.pendingAxis = horizontal and "y" or "x"
				result.pendingValueQ = horizontal and dy or dx
		else
			result.axis = math.abs(intentX) >= math.abs(intentY) and "x" or "y"
			component = result.axis == "x" and intentX or intentY
			result.direction = component > 0 and 1 or component < 0 and -1 or 0
		result

	isNodeTraced: (nodeId, ignoreLast = false) =>
		for stack in *@stacks
			limit = #stack - (ignoreLast and 1 or 0)
			for i = 1, limit
				return true if stack[i] == nodeId

		false

	calculateMaxProgress: (edge, stackId) =>
		return edge.lengthQ if edge.isExit or edge.isBreak

		stack = @stacks[stackId]
		previous = stack[#stack - 1]
		return edge.lengthQ if edge.toId == previous

		if @isNodeTraced edge.toId
			clearance = round(@topology.barWidth / @topology.barLength * TRACE_UNITS)
			target = @topology.nodes[edge.toId]
			if target and target.clickable
				clearance = round clearance * 1.75

			return math.max 0, edge.lengthQ - clearance

		edge.lengthQ

	calculatePairMaxProgress: (primary, secondary, maximum) =>
		return maximum unless secondary
		clearance = math.max 1, round(@topology.barWidth /
			@topology.barLength * TRACE_UNITS)

		-- Mirrored heads may approach the same junction or traverse the same
		-- corridor in opposite directions. Clamp their shared progress before
		-- the rendered capsules touch.
		if primary.toId == secondary.toId
			return math.min maximum, math.max(0,
				math.min(primary.lengthQ, secondary.lengthQ) - round(clearance / 2))

		if primary.fromId == secondary.toId and primary.toId == secondary.fromId
			return math.min maximum, math.max(0,
				round((math.min(primary.lengthQ, secondary.lengthQ) - clearance) / 2))

		maximum

	selectTarget: (dx, dy) =>
		return false if dx == 0 and dy == 0

		primary = @stacks[1]
		currentId = primary[#primary]
		previousId = primary[#primary - 1]
		secondary = @stacks[2]
		secondaryCurrentId = secondary and secondary[#secondary]
		local best, bestSecondary, bestScore

		for toId = 1, #@topology.nodes
			edge = @topology\getEdge currentId, toId
			continue unless edge

			pairedEdge = nil
			if secondary
				continue unless @topology\getSymmetricalNodeId(currentId) ==
					secondaryCurrentId
				pairedEdge = @topology\getSymmetricalEdge currentId, toId
				continue unless pairedEdge and pairedEdge.fromId == secondaryCurrentId

			score = dx * edge.unitX + dy * edge.unitY
			continue unless score > 0
			horizontal = math.abs(edge.unitX) > math.abs(edge.unitY)
			bestHorizontal = best and math.abs(best.unitX) > math.abs(best.unitY)

			if not best or score > bestScore or
					score == bestScore and horizontal and not bestHorizontal or
					score == bestScore and horizontal == bestHorizontal and edge.lengthQ < best.lengthQ or
					score == bestScore and horizontal == bestHorizontal and
					edge.lengthQ == best.lengthQ and toId < best.toId
				best = edge
				bestSecondary = pairedEdge
				bestScore = score

		return false unless best

		secondaryEdge = bestSecondary

		backtracking = best.toId == previousId
		if backtracking
			removedPrimary = table.remove primary
			activePrimary = @topology\getEdge primary[#primary], removedPrimary
			return false unless activePrimary

			activeSecondary = nil
			if @stacks[2]
				secondary = @stacks[2]
				removedSecondary = table.remove secondary
				activeSecondary = @topology\getEdge secondary[#secondary], removedSecondary
				return false unless activeSecondary

			@active = {
				primary: activePrimary
				secondary: activeSecondary
				progressQ: activePrimary.lengthQ
				maxProgressQ: activePrimary.lengthQ
				retracting: true
			}
		else
			maxProgress = @calculateMaxProgress best, 1
			if secondaryEdge
				maxProgress = math.min maxProgress, @calculateMaxProgress(secondaryEdge, 2)
			maxProgress = @calculatePairMaxProgress best, secondaryEdge, maxProgress

			@active = {
				primary: best
				secondary: secondaryEdge
				progressQ: 0
				maxProgressQ: math.min maxProgress, best.lengthQ
				retracting: false
			}

		true

	movementAlongActive: (dx, dy, budget) =>
		edge = @active.primary
		along = dx * edge.unitX + dy * edge.unitY
		perpendicular = -dx * edge.unitY + dy * edge.unitX

		-- Windmill-style junction magnetism: dominant perpendicular intent
		-- moves toward the nearest endpoint. It does not add movement to the
		-- sample, so crossing a junction can never create a negative residual.
		if math.abs(along) * 5 < math.abs(perpendicular)
			return 0 if edge.isExit or @active.maxProgressQ < edge.lengthQ
			return @active.progressQ >= edge.lengthQ / 2 and budget or -budget

		return budget if along > 0
		return -budget if along < 0
		0

	positionAtProgress: (edge, progressQ) =>
		-- Returns {x, y} in canvas coordinates for a given progress along an edge.
		-- Exact same calculation as syncCompatibility; this is the single authoritative
		-- mapping from edge progress to canvas position.
		fromNode = @topology.nodes[edge.fromId]
		toNode = @topology.nodes[edge.toId]
		unless fromNode and toNode
			return nil

		fraction = edge.lengthQ > 0 and progressQ / edge.lengthQ or 0
		fromX = edge.fromScreenX or fromNode.screenX
		fromY = edge.fromScreenY or fromNode.screenY
		toX = edge.toScreenX or toNode.screenX
		toY = edge.toScreenY or toNode.screenY
		{x: fromX + (toX - fromX) * fraction,
		 y: fromY + (toY - fromY) * fraction}

	findHorizontalTravel: (currentId, direction) =>
		return 0 unless currentId and direction ~= 0
		best, bestEdge, bestSecondary = 0, nil, nil
		for toId = 1, #@topology.nodes
			edge = @topology\getEdge currentId, toId
			continue unless edge and direction * edge.unitX > 0 and
				math.abs(edge.unitX) > math.abs(edge.unitY)
			maximum = @calculateMaxProgress edge, 1
			mirror = nil
			if @stacks[2]
				mirror = @topology\getSymmetricalEdge currentId, toId
				continue unless mirror
				maximum = math.min maximum, @calculateMaxProgress(mirror, 2)
				maximum = @calculatePairMaxProgress edge, mirror, maximum
			if maximum > best or maximum == best and bestEdge and
					toId < bestEdge.toId
				best, bestEdge, bestSecondary = maximum, edge, mirror
		best, bestEdge, bestSecondary

	-- Querying physical pillar travel must see through a normal junction. A
	-- one-edge query decelerates the player to zero at every vertex; at the RT
	-- seam that made two correctly aliased sockets behave like disconnected
	-- endpoints. Temporarily expose the committed endpoint to the ordinary
	-- collision calculation, then restore the canonical engine state.
	continuationHorizontalTravel: (edge, secondaryEdge, direction) =>
		return 0 unless edge and not edge.isExit and not edge.isBreak
		return 0 unless edge.lengthQ > 0
		table.insert @stacks[1], edge.toId
		if @stacks[2] and secondaryEdge
			table.insert @stacks[2], secondaryEdge.toId
		travel = @findHorizontalTravel edge.toId, direction
		table.remove @stacks[1]
		table.remove @stacks[2] if @stacks[2] and secondaryEdge
		travel

	getHorizontalTravel: (direction, controllingPly = nil, boundaryLimit = 1) =>
		@horizontalConstraintBase = nil
		return 0 unless @phase == @@Phase.Tracing and direction ~= 0
		boundaryLimit = math.max 1, math.min(2, math.floor(boundaryLimit or 1))
		if @active
			return 0 if math.abs(@active.primary.unitX) <= math.abs(@active.primary.unitY)
			along = direction * @active.primary.unitX
			return 0 if along == 0
			if along > 0
				maximum = @active.maxProgressQ
				if @occlusionConstraint and controllingPly ~= nil
					maximum = clamp math.floor(@.occlusionConstraint(controllingPly,
						@active.primary, @active.progressQ, maximum) or maximum),
						@active.progressQ, maximum
					@horizontalConstraintBase = @active.progressQ
				travel = math.max 0, maximum - @active.progressQ
				if boundaryLimit > 1 and controllingPly == nil and
						maximum >= @active.primary.lengthQ and
						@active.progressQ < @active.primary.lengthQ
					travel += @continuationHorizontalTravel @active.primary,
						@active.secondary, direction
				return travel
			return math.max 0, @active.progressQ
		stack = @stacks[1]
		return 0 unless stack and stack[#stack]
		currentId = stack[#stack]
		best, bestEdge, bestSecondary = @findHorizontalTravel currentId, direction
		if best > 0 and bestEdge and @occlusionConstraint and controllingPly ~= nil
			best = clamp math.floor(@.occlusionConstraint(controllingPly, bestEdge,
				0, best) or best), 0, best
			@horizontalConstraintBase = 0
		if boundaryLimit > 1 and controllingPly == nil and bestEdge and
				best >= bestEdge.lengthQ
			best += @continuationHorizontalTravel bestEdge, bestSecondary, direction
		best

	commitActive: =>
		return false unless @active

		edge = @active.primary
		return false if edge.isExit or edge.isBreak
		return false if @active.maxProgressQ < edge.lengthQ

		table.insert @stacks[1], edge.toId
		if @stacks[2]
			table.insert @stacks[2], @active.secondary.toId

		@active = nil
		true

	restoreRetractedEndpoint: =>
		return false unless @active and @active.retracting
		table.insert @stacks[1], @active.primary.toId
		if @stacks[2]
			table.insert @stacks[2], @active.secondary.toId
		@active = nil
		true

	applySample: (dx, dy, boost = false, controllingPly = nil,
		constraintDecisions = nil) =>
		return false unless @phase == @@Phase.Tracing
		@lastConstraintDecisions = {}
		constraintIndex = 0

		dx = round dx
		dy = round dy
		return false if dx == 0 and dy == 0

		if boost
			dx *= 2
			dy *= 2

		hx, hy = @getHistoryIntent dx, dy
		budget = math.max math.abs(dx), math.abs(dy)
		remainingBudget = budget
		changed = false
		boundaries = 0

		while boundaries < 2 and remainingBudget > 0
			intentX, intentY = @motionIntent dx, dy, hx, hy
			unless @active
				break unless @selectTarget intentX, intentY
				changed = true
				intentX, intentY = @motionIntent dx, dy, hx, hy

			movement = @movementAlongActive intentX, intentY, remainingBudget
			break if movement == 0

			oldProgress = @active.progressQ
			candidate = clamp oldProgress + movement, 0, @active.maxProgressQ
			actual = candidate - oldProgress
			break if actual == 0

			-- World visibility is not deterministic between Lua realms. The
			-- predicting controller records the exact integer outcome; authority
			-- and prediction replay consume that same decision transcript.
			if actual > 0
				if constraintDecisions ~= nil
					constraintIndex += 1
					if constrained = constraintDecisions[constraintIndex]
						candidate = clamp math.floor(constrained), oldProgress, candidate
						table.insert @lastConstraintDecisions, candidate
				elseif @occlusionConstraint and controllingPly ~= nil
					candidate = clamp math.floor(
						@.occlusionConstraint(
							controllingPly,
							@active.primary,
							oldProgress,
							candidate
						) or candidate
					), oldProgress, candidate
					table.insert @lastConstraintDecisions, candidate

				actual = candidate - oldProgress
				break if actual <= 0

			@active.progressQ = candidate
			changed = true

			edge = @active.primary
			remainingBudget -= math.abs actual

			if candidate <= 0 and actual < 0
				@active = nil
				boundaries += 1
				continue

			if @active.retracting and candidate >= edge.lengthQ and actual > 0 and
					@restoreRetractedEndpoint!
				boundaries += 1
				continue

			if not @active.retracting and candidate >= edge.lengthQ and @commitActive!
				boundaries += 1
				continue

			break

		@touchingExit = @active and @active.primary.isExit and
			(not @active.secondary or @active.secondary.isExit) and
			@active.progressQ >= @active.primary.lengthQ and
			(not @active.secondary or @active.progressQ >= @active.secondary.lengthQ) or false
		@syncCompatibility!
		changed

	canSubmit: =>
		@phase == @@Phase.Tracing and @touchingExit == true

	beginEvaluation: =>
		return false unless @canSubmit!
		if @active and @active.primary.isExit
			table.insert @stacks[1], @active.primary.toId
			if @stacks[2] and @active.secondary
				table.insert @stacks[2], @active.secondary.toId
			@active = nil
		@phase = @@Phase.Evaluating
		@touchingExit = false
		@syncCompatibility!
		true

	snapshot: =>
		copyStacks = {}
		for stack in *@stacks
			table.insert copyStacks, [nodeId for nodeId in *stack]

		active = if @active
			{
				primaryFrom: @active.primary.fromId
				primaryTo: @active.primary.toId
				secondaryFrom: @active.secondary and @active.secondary.fromId or 0
				secondaryTo: @active.secondary and @active.secondary.toId or 0
				progressQ: @active.progressQ
				maxProgressQ: @active.maxProgressQ
				retracting: @active.retracting
			}
		else
			false

		history = {}
		for sample in *@history
			table.insert history, { sample[1], sample[2] }

		Moonpanel.Canvas.TraceState {
			phase: @phase
			stacks: copyStacks
			active: active
			history: history
			touchingExit: @touchingExit
			revision: @topology.revision
		}

	restore: (snapshot) =>
		return false unless snapshot and snapshot.revision == @topology.revision

		@phase = snapshot.phase or @@Phase.Idle
		@stacks = {}
		for stack in *(snapshot.stacks or {})
			table.insert @stacks, [nodeId for nodeId in *stack]

		if snapshot.active
			primary = @topology\getEdge snapshot.active.primaryFrom, snapshot.active.primaryTo
			return false unless primary

			secondary = nil
			if snapshot.active.secondaryFrom and snapshot.active.secondaryFrom > 0
				secondary = @topology\getEdge snapshot.active.secondaryFrom, snapshot.active.secondaryTo
				return false unless secondary

			@active = {
				:primary
				:secondary
				progressQ: snapshot.active.progressQ
				maxProgressQ: snapshot.active.maxProgressQ
				retracting: snapshot.active.retracting == true
			}
		else
			@active = nil

		@touchingExit = snapshot.touchingExit == true
		@history = {}
		for sample in *(snapshot.history or {})
			dx = round(sample[1] or 0)
			dy = round(sample[2] or 0)
			table.insert @history, { dx, dy }
		while #@history > 3
			table.remove @history, 1
		@syncCompatibility!
		true

	hash: =>
		hash = appendHash CRC_MASK, 23
		hash = appendHash hash, @topology.revision
		hash = appendHash hash, @phase
		hash = appendHash hash, #@stacks
		for stack in *@stacks
			hash = appendHash hash, #stack
			for nodeId in *stack
				hash = appendHash hash, nodeId

		if @active
			hash = appendHash hash, @active.primary.fromId
			hash = appendHash hash, @active.primary.toId
			hash = appendHash hash, @active.secondary and @active.secondary.fromId or 0
			hash = appendHash hash, @active.secondary and @active.secondary.toId or 0
			hash = appendHash hash, @active.progressQ
			hash = appendHash hash, @active.maxProgressQ
			hash = appendHash hash, @active.retracting
		else
			hash = appendHash hash, 0

		hash = appendHash hash, #@history
		for sample in *@history
			hash = appendHash hash, sample[1]
			hash = appendHash hash, sample[2]

		hash = appendHash hash, @touchingExit
		finishHash hash

	syncCompatibility: =>
		@nodeStacks = {}
		@cursors = {}

		for stackId, stackIds in ipairs @stacks
			stack = {}
			for nodeId in *stackIds
				node = @topology.nodes[nodeId]
				table.insert stack, node

			@nodeStacks[stackId] = stack
			last = stack[#stack]
			if last
				@cursors[stackId] = { x: last.screenX, y: last.screenY }

		if @active
			for stackId, edge in ipairs { @active.primary, @active.secondary }
				continue unless edge
				pos = @positionAtProgress(edge, @active.progressQ)
				@cursors[stackId] = pos if pos else nil

	-- Public API names used by networking/tests. Lower-case forms remain the
	-- idiomatic internal calls, while these make the engine contract explicit.
	Start: (startNodeId) => @start startNodeId
	ApplySample: (dxQ, dyQ, boost = false, controllingPly = nil,
		constraintDecisions = nil) =>
		@applySample dxQ, dyQ, boost, controllingPly, constraintDecisions
	GetConstraintDecisions: => [value for value in *@lastConstraintDecisions]
	GetHorizontalTravel: (direction, controllingPly = nil, boundaryLimit = 1) =>
		@getHorizontalTravel direction, controllingPly, boundaryLimit
	ResolveIntent: (dxQ, dyQ) => @resolveIntent dxQ, dyQ
	GetSignedTravel: (axis, direction, boundaryLimit = 1) =>
		direction = direction > 0 and 1 or direction < 0 and -1 or 0
		return 0 if direction == 0
		if axis == "x" or axis == 1
			return direction * @getHorizontalTravel(direction, nil, boundaryLimit)
		return 0 unless @phase == @@Phase.Tracing
		if @active and @active.primary
			return 0 if math.abs(@active.primary.unitY) <
				math.abs(@active.primary.unitX)
			along = direction * @active.primary.unitY
			return 0 if along == 0
			travel = along > 0 and
				math.max(0, @active.maxProgressQ - @active.progressQ) or
				math.max(0, @active.progressQ)
			return direction * travel
		stack = @stacks[1]
		return 0 unless stack and stack[#stack]
		currentId = stack[#stack]
		best, bestEdge = 0, nil
		for toId = 1, #@topology.nodes
			edge = @topology\getEdge currentId, toId
			continue unless edge and direction * edge.unitY > 0 and
				math.abs(edge.unitY) >= math.abs(edge.unitX)
			maximum = @calculateMaxProgress edge, 1
			if @stacks[2]
				mirror = @topology\getSymmetricalEdge currentId, toId
				continue unless mirror
				maximum = math.min maximum, @calculateMaxProgress(mirror, 2)
				maximum = @calculatePairMaxProgress edge, mirror, maximum
			if maximum > best or maximum == best and bestEdge and toId < bestEdge.toId
				best, bestEdge = maximum, edge
		direction * best
	CanSubmit: => @canSubmit!
	Snapshot: => @snapshot!
	Restore: (snapshot) => @restore snapshot
	Hash: => @hash!
