Moonpanel.Canvas or= {}

Moonpanel.Canvas.EntityTypes = {
    None:       0
    Start:      1
    End:        2
    Hexagon:    3
    Triangle:   4
    Polyomino:  5
    Sun:        6
    Eraser:     7
    Color:      8
    Disjoint:   9
    Invisible: 10
}

Moonpanel.Canvas.ObjectTypes = {
    None:         0
    Cell:         1
    VPath:        2
    HPath:        3
    Intersection: 4
}

Moonpanel.Canvas.Symmetry = {
    None:       0
    Rotational: 1
    Vertical:   2
    Horizontal: 3
}

Moonpanel.Canvas.Resolution = 512
Moonpanel.Canvas.TraceCursorPrecision = 16

AddCSLuaFile!
AddCSLuaFile "cl_dcanvas.lua"
AddCSLuaFile "cl_branchanimator.lua"
AddCSLuaFile "cl_rtpool.lua"

include "sh_paneldata.lua"
include "sh_pathfinder.lua"
if CLIENT
	include "cl_dcanvas.lua"
	include "cl_branchanimator.lua"
	include "cl_rtpool.lua"
else
	resource.AddFile "moonpanel/circle.png"

Moonpanel.Canvas.SampleData = {
	Meta: {
		Width: 5
		Height: 5
		Symmetry: Moonpanel.Canvas.Symmetry.Rotational
	}

	Dim: {
		BarLength: 17
		BarWidth: 1.8
	}

	Entities: {
		{},          {}, {}, {}, { Type: 2 },
		{},          {}, {}, {},          {},
		{},          {}, {}, {},          {},
		{},          {}, {}, {},          {},
		{ Type: 1 }, {}, {}, {},          {},
	}
}

cardinals = {
	{ x:  0, y: -1 }
	{ x:  0, y:  1 }
	{ x: -1, y:  0 }
	{ x:  1, y:  0 }
}

timePct = (startTime, duration) ->
	(math.min duration, CurTime! - startTime) / duration

local MAT_CIRCLE, circleAt, drawLine, clearRT

if CLIENT
	MAT_CIRCLE = Material "moonpanel/circle.png"

	circleAt = (x, y, r) ->
		surface.SetMaterial MAT_CIRCLE
		surface.DrawTexturedRect x - r, y - r, r * 2, r * 2

	clearRT = (rt) ->
		with render.PushRenderTarget rt
			cam.Start2D!
			render.Clear 0, 0, 0, 255, true, false
			cam.End2D!

		render.PopRenderTarget!

	drawLine = (x1, y1, x2, y2, width, length) ->
		dX = x2 - x1
		dY = y2 - y1
		angle = math.pi / 2 + math.atan2 dX, dY

		local posX, posY
		if not length
			length = math.sqrt dX * dX + dY * dY

			posX = 0.5 * (x1 + x2)
			posY = 0.5 * (y1 + y2)

		else
			posX = x1 - 0.5 * length * math.cos angle
			posY = y1 + 0.5 * length * math.sin angle

		surface.DrawTexturedRectRotated (math.Round posX), (math.Round posY),
			length, width, math.deg angle

class Canvas
	new: (data) =>
		@SetData data if data

		@__playData = {}

	SetWorldEntity: (ent) =>
		@__worldEntity = ent

	AllocateRT: =>
		if @__rtAlloc
			return if Moonpanel.Canvas\IsRTAllocated @__rtAlloc

		@__rtAlloc = Moonpanel.Canvas\AllocateRT!

		if @__rtAlloc
			clearRT @__rtAlloc.rt.texture
			@__rtDirty = true

			true

	DeallocateRT: =>
		if @__rtAlloc
			return if not Moonpanel.Canvas\IsRTAllocated @__rtAlloc

			Moonpanel.Canvas\DeallocateRT @__rtAlloc

			true

	CanRender: => @__rtAlloc and Moonpanel.Canvas\IsRTAllocated @__rtAlloc

	--------------------------------------------------------------------
	-- Exports data for various purposes, from saving boards to files --
	-- to sending them to clients.                                    --
	--------------------------------------------------------------------
	SetData: (@__data) =>
		@OnSetData @__data if @OnSetData ~= nil

		if not @__data
			@__data = nil
			@__pathFinder = nil
			@__clientData = nil

			return

		ents = @__data.Entities or {}

		numCols = @__data.Meta.Width  * 2 + 1
		numRows = @__data.Meta.Height * 2 + 1

		return if true

		-- Initialize the node map.
		for i = 1, numCols * numRows
			row = math.ceil i / numCols
			column = 1 + (i - 1) % numCols

			if row % 2 == 1
				-- Intersection.
				if column % 2 == 1
					print "Intersection"

				-- Horizontal line.
				else
					print "HBar"
			else
				-- Vertical line.
				if column % 2 == 1
					print "VBar"

				-- Cell
				else
					print "Cell"

	--------------------------------------------------
	-- Fetches the internal panel data table.       --
	-- Not guaranteed to be useful, see ExportData. --
	--------------------------------------------------
	GetData: => @__data

	--------------------------------------------------------------------
	-- Exports data for various purposes, from saving boards to files --
	-- to sending them to clients.                                    --
	--------------------------------------------------------------------
	ExportData: =>
		return if not @__data

		-- Copy the data table without entities.
		ents = @__data.Entities
		@__data.Entities = nil

		copy = table.Copy @__data
		@__data.Entities = ents

		-- Serialize entities by type.

		copy

	--------------------------------------------------------------
	-- Exports play data. Intended to be called when the server --
	-- wants us to replay the game.                             --
	--------------------------------------------------------------
	ExportPlayData: =>
		return if not @__data
		return if not @__playData

		copy = table.Copy @__playData

		if @__pathFinder and @__data and @__playData.startTime and not @__playData.endTime
			-- Serialize branch animator stuff.
			for i = 1, #@__pathFinder.nodeStacks
				copy.traces or= {}

				stack = @__pathFinder.nodeStacks[i]
				potential = @__pathFinder.potentialNodes[i]

				trace = {}

				if #stack > 0
					trace.stack = {}

					for node in *stack
						table.insert trace.stack, node.id

				if potential
					trace.potential = potential.id

				table.insert copy.traces, trace

		copy

	--------------------------------------------------------------
	-- Imports play data. Intended to be called when the server --
	-- wants us to replay the game.                             --
	--------------------------------------------------------------
	ImportPlayData: (playData = {}) =>
		@__playData = table.Copy playData

		if @__pathFinder and @__data and @__playData.traces
			startingNodes = {}

			-- Deserialize branch animator stuff.
			for stackId, trace in ipairs @__playData.traces
				table.insert startingNodes, @__nodes[trace.stack[1]]

			nodeA, nodeB = unpack startingNodes
			@InitBranchAnimators nodeA, nodeB, @__playData.controller

			for stackId, trace in ipairs @__playData.traces
				for i, nodeId in ipairs trace.stack
					continue if i == 1
					node = @__nodes[nodeId]

					@TracePushNode stackId, node.screenX, node.screenY

				if trace.potential
					potential = @__nodes[trace.potential]

					@TracePotentialNode stackId, potential.screenX,
						potential.screenY

		@__playData.traces = nil
		@__rtDirty = true

	--------------------------------------------------------
	-- Recalculates things such as node screen positions, --
	-- path lengths and intersection occlusion.           --
	--------------------------------------------------------
	Recalculate: =>
		return if not @__data

		@__clientData = {}

		barWidth = Moonpanel.Canvas.Resolution *
			(@__data.Dim.BarWidth / 100)

		barLength  = Moonpanel.Canvas.Resolution *
			(@__data.Dim.BarLength  / 100)

		-- Calculate positions.
		for node in *@__nodes
			node.screenX = Moonpanel.Canvas.Resolution * 0.5 - node.x * barLength
			node.screenY = Moonpanel.Canvas.Resolution * 0.5 - node.y * barLength

		-- Rendering optimizations.
		return if SERVER

		@__rtDirty = true

		@__clientData.__paths = {}
		@__clientData.__distances = {}
		for node in *@__nodes
			@__clientData.__distances[node] = {}

		seen = {}

		-- Extract paths and calculate distances.
		for nodeA in *@__nodes
			isSeen = false
			for nodeB in *nodeA.neighbors
				if not isSeen
					seen[nodeA] = true
					isSeen = true

				if not seen[nodeB]
					angle = math.atan2 nodeA.screenY - nodeB.screenY,
						nodeA.screenX - nodeB.screenX

					dist = math.ceil math.sqrt (nodeA.screenX - nodeB.screenX)^2 +
						(nodeA.screenY - nodeB.screenY)^2

					@__clientData.__distances[nodeA][nodeB] = dist
					@__clientData.__distances[nodeB][nodeA] = dist

					table.insert @__clientData.__paths, {
						angle: math.Round math.deg angle
						distance: dist

						screenX: math.floor (nodeB.screenX + nodeA.screenX) * 0.5
						screenY: math.floor (nodeB.screenY + nodeA.screenY) * 0.5
					}

		-- Test occlusion.
		@__clientData.__visibleNodes = {}

		for node in *@__nodes
			if node.clickable
				table.insert @__clientData.__visibleNodes, node
				continue

			continue if node.invisible
			continue if 0 == table.Count node.neighbors

			ranges = {}
			for nodeB in *node.neighbors
				angle = 180 + math.deg math.atan2 nodeB.screenY - node.screenY,
					nodeB.screenX - node.screenX

				lower = angle - 90
				upper = angle + 90

				if lower < 0
					table.insert ranges, {
						360 + lower, 360
					}

					table.insert ranges, {
						0, upper
					}
				elseif upper > 360
					table.insert ranges, {
						0, upper - 360
					}

					table.insert ranges, {
						lower, 360
					}
				else
					table.insert ranges, {
						lower, upper
					}

			table.sort ranges, (a, b) -> a[1] < b[1]

			local lowerBound
			local upperBound
			for range in *ranges
				lower = range[1]
				upper = range[2]

				if not lowerBound
					lowerBound = lower

				if not upperBound
					upperBound = upper

				elseif lower <= upperBound
					upperBound = math.max upper, upperBound

			if upperBound - lowerBound < 360
				table.insert @__clientData.__visibleNodes, node

	---------------------
	-- Rebuilds nodes. --
	---------------------
	RebuildNodes: =>
		return if not @__data

		@pathMap = {}

		numCols = @__data.Meta.Width  * 2 + 1
		numRows = @__data.Meta.Height * 2 + 1

		@__nodeMap = {}
		@__nodes = {}

		-- Initialize the node map.
		for i = 1, numCols * numRows
			row = math.ceil i / numCols
			column = 1 + (i - 1) % numCols

			if row % 2 == 1 and column % 2 == 1
				intX = math.floor column / 2
				intY = math.floor row / 2

				node = {
					neighbors: {}

					id: #@__nodes + 1
					x: intX - @__data.Meta.Width  / 2
					y: intY - @__data.Meta.Height / 2
				}

				@__nodeMap[intY + 1] or= {}
				@__nodeMap[intY + 1][intX + 1] = node

				table.insert @__nodes, node

		@__nodeMap[3][3].clickable = true
		@__nodeMap[4][4].clickable = true

		-- Wire stuff together.
		for j = 1, @__data.Meta.Width + 1
			for i = 1, @__data.Meta.Height + 1
				node = @__nodeMap[j][i]

				for cardinal in *cardinals
					if row = @__nodeMap[j + cardinal.y]
						if otherNode = row[i + cardinal.x]
							table.insert node.neighbors, otherNode
							table.insert otherNode.neighbors, node

		@Recalculate!

	------------------------------------------------------------
	-- Initializes the path finder. The thing responsible for --
	-- moving the traces around and snapping them.            --
	------------------------------------------------------------
	InitPathFinder: =>
		return if not @__data

		-- Initialize the path finder.
		-- This has to be done every time the data table is changed.
		@__pathFinder = Moonpanel.Canvas.PathFinder {
			nodes: @__nodes

			barWidth: Moonpanel.Canvas.Resolution *
				(@__data.Dim.BarWidth / 100)

			barLength: Moonpanel.Canvas.Resolution *
				(@__data.Dim.BarLength / 100)

			screenWidth: Moonpanel.Canvas.Resolution
			screenHeight: Moonpanel.Canvas.Resolution
			symmetry: @__data.Meta.Symmetry
		}

	GetPathFinder: => @__pathFinder

	------------------------------------------------------
	-- The core of all things traces. Sends new deltas  --
	-- to the pathfinder instance, checks modifications --
	-- and broadcasts stuff to players.                 --
	------------------------------------------------------
	ApplyDeltas: (x, y) =>
		return if not @__pathFinder

		-- Take a snapshot of node stacks and potential nodes
        snapshotNodes = {}
        snapshotPotentialNodes = {}
        for stackId, stack in ipairs @__pathFinder.nodeStacks
            snapshotNodes[stackId] = #stack
            snapshotPotentialNodes[stackId] = @__pathFinder.potentialNodes[stackId]

		if result = @__pathFinder\applyDeltas x * 0.25, y * 0.25
			@__rtDirty = true if CLIENT

			-- Compare snapshots
            local diff
            validDiff = true
            local newPotentialNodes
            local lowestDelta
            touchingExit = false

            for stackId, stack in ipairs @__pathFinder.nodeStacks
                count = #stack
                potentialNode = @__pathFinder.potentialNodes[stackId]

                if not touchingExit
                    touchingExit = stack[count].exit or (potentialNode and potentialNode.exit)

                if snapshotPotentialNodes[stackId] ~= potentialNode
                    if not newPotentialNodes
                        newPotentialNodes = {}

                    table.insert newPotentialNodes, {
                        screenX: potentialNode.screenX
                        screenY: potentialNode.screenY
                    }

                if potentialNode
                    last = stack[count]

                    deltaNodesX = math.abs last.screenX - potentialNode.screenX
                    deltaNodesY = math.abs last.screenY - potentialNode.screenY
                    deltaNodes = deltaNodesX + deltaNodesY

                    delta = if (deltaNodes >= 0.01)
                        cursor = @__pathFinder.cursors[stackId]

                        deltaCursorX = math.abs potentialNode.screenX - cursor.x
                        deltaCursorY = math.abs potentialNode.screenY - cursor.y

                        1 - ((deltaCursorX+deltaCursorY)/deltaNodes)
                    else
                        0.99

                    if not lowestDelta
                        lowestDelta = delta
                    else
                        lowestDelta = math.min lowestDelta, delta

                if validDiff
                    newDiff = count - snapshotNodes[stackId]

                    if snapshotNodes[stackId] ~= count
                        if not diff
                            diff = newDiff
                        elseif diff ~= newDiff
                            validDiff = false

            if lowestDelta
                if lowestDelta ~= @__oldLowestDelta
                    if SERVER and IsValid @__worldEntity
						user = @__worldEntity\GetController!
                    	compressedDelta = math.floor lowestDelta * (2 ^ Moonpanel.Canvas.TraceCursorPrecision)

                    	Moonpanel.Net.BroadcastTraceUpdateCursor user, @__worldEntity, compressedDelta

                    elseif CLIENT
                        @UpdateTraceCursor lowestDelta

                    @__oldLowestDelta = lowestDelta

            if validDiff and diff and diff ~= 0
                -- If diff if positive, broadcast new points
                if diff > 0
                    local newPoints
                    if SERVER
                        newPoints = {}

                    for stackId, stack in ipairs @__pathFinder.nodeStacks
                        if SERVER
                            table.insert newPoints, {}

                        for i = snapshotNodes[stackId] + 1, snapshotNodes[stackId] + diff
                            if SERVER
                                table.insert newPoints[stackId], {
                                    screenX: stack[i].screenX
                                    screenY: stack[i].screenY
                                }
                            else
                                @TracePushNode stackId, stack[i].screenX, stack[i].screenY

                    if SERVER and IsValid @__worldEntity
						user = @__worldEntity\GetController!

                        Moonpanel.Net.BroadcastTracePushNodes user, @__worldEntity, newPoints

                -- otherwise broadcast pops
                else
                    pops = {}
                    for stackId, stack in ipairs @__pathFinder.nodeStacks
                        if SERVER
                            table.insert pops, -diff
                        else
                            @TracePopNode stackId

					if SERVER and IsValid @__worldEntity
						user = @__worldEntity\GetController!

                    	Moonpanel.Net.BroadcastTracePopNodes user, @__worldEntity, pops

            if newPotentialNodes
                if SERVER and IsValid @__worldEntity
					user = @__worldEntity\GetController!

                    Moonpanel.Net.BroadcastTraceUpdatePotential user,
						@__worldEntity, newPotentialNodes

                elseif CLIENT
                    for stackId, potentialNode in pairs newPotentialNodes
                        @TracePotentialNode stackId, potentialNode.screenX, potentialNode.screenY

			return result

	-------------------------------------------------
	-- Starts a new game using the provided point. --
	-------------------------------------------------
	Start: (nodeId, ply) =>
		return if not @__pathFinder
		return if @__playData.startTime and not @__playData.endTime

		result = @__pathFinder\restart nodeId

		if result and CLIENT
			nodeA = @__nodes[nodeId]

			local nodeB
			if @__data.Meta.Symmetry > 0
				nodeB = @__pathFinder\getSymmetricalClickableNode nodeA

			@InitBranchAnimators nodeA, nodeB, ply

			@__rtDirty = true

		if result
			@__playData = {
				startTime: CurTime!
				controller: ply
			}

		@OnStart! if result and @OnStart ~= nil

		result

	---------------------------------------------------
	-- Ends the current "game" if there's one going. --
	---------------------------------------------------
	End: =>
		return if not @__pathFinder
		return if @__playData.endTime

		@OnEnd! if @OnEnd ~= nil

		@__rtDirty = true
		@__playData.endTime = CurTime!
		@__playData.wasAborted = true

		true

	-------------
	-- Thonks. --
	-------------
	Think: =>
		return if not @__playData

		if @__powerState ~= nil
			@__powerStateBuffer += FrameTime! * (@__powerState and 1 or -1)
			@__powerStateBuffer = math.Clamp @__powerStateBuffer, 0, 1

		if @__branchAnimators and not @__playData.wasAborted
			for animator in *@__branchAnimators
				@__rtDirty = true if animator\think!

	----------------------
	-- CLIENTSIDE AREA. --
	-- CLIENTSIDE AREA. --
	-- CLIENTSIDE AREA. --
	-- CLIENTSIDE AREA. --
	-- CLIENTSIDE AREA. --
	----------------------

	SetPowerState: CLIENT and (state) =>
		@__powerState = state
		if not @__powerStateBuffer
			@__powerStateBuffer = state and 1 or 0

	------------------------------------------------------------------
	-- Tells a branch animator about the length of the last segment --
	------------------------------------------------------------------
	UpdateTraceCursor: CLIENT and (cursor) =>
		return unless @__branchAnimators

		for _, animator in ipairs @__branchAnimators
			animator\setCursor cursor

		@__rtDirty = true

	----------------------------------------------------------
	-- Tells a branch animator about the new potential node --
	----------------------------------------------------------
	TracePotentialNode: CLIENT and (id, screenX, screenY) =>
		return unless @__branchAnimators

		animator = @__branchAnimators[id]
		if animator
			if animator.__ignoreNextPotential
				animator.__ignoreNextPotential = false
				return

			last = animator\getLastNode!

			if last.x ~= screenX or last.y ~= screenY
				if animator\getLastNode!.__potential
					animator\popNode!

				with animator\pushNode screenX, screenY
					.__potential = true

	---------------------------------------------------------
	-- Pushes a new node on top of a branchanimator stack. --
	---------------------------------------------------------
	TracePushNode: CLIENT and (id, screenX, screenY) =>
		return unless @__branchAnimators

		animator = @__branchAnimators[id]
		if animator
			last = animator\getLastNode!
			if last and last.__potential
				if last.x == screenX and last.y == screenY
					last.__potential = false
				else
					animator\popNode!
					animator\pushNode screenX, screenY
			else
				animator\pushNode screenX, screenY

			animator\setCursor 1

			@__rtDirty = true

	----------------------------------------------
	-- Pops a node from a branchanimator stack. --
	----------------------------------------------
	TracePopNode: CLIENT and (id) =>
		return unless @__branchAnimators

		animator = @__branchAnimators[id]
		if animator
			last = animator\getLastNode!
			if last.__potential
				animator\popNode!
				animator.__ignoreNextPotential = true

			animator\getLastNode!.__potential = true

			@__rtDirty = true

	--------------------------------------------------------------
	-- Initializes branch animators. The things responsible for --
	-- trace interpolation.                                     --
	--------------------------------------------------------------
	InitBranchAnimators: CLIENT and (nodeA, nodeB, ply) =>
		@__branchAnimators = {}

		for stackId, node in ipairs { nodeA, nodeB }
			if node
				animator = Moonpanel.Canvas.BranchAnimator node.screenX, node.screenY
				@__branchAnimators[stackId] = animator

				@__branchAnimators[stackId]\setSpeedModifier ply == LocalPlayer! and 14 or 3


	----------------------------
	-- Paints the trace. Duh. --
	----------------------------
	PaintTrace: CLIENT and (w, h) =>
		return if not @__branchAnimators

		widthModifier = math.EaseInOut (timePct @__playData.startTime, 0.15),
			0.25, 0.25

		regularRadius = widthModifier * w * (@__data.Dim.BarWidth / 100)
		firstNodeRadius = math.Round 0.5 * regularRadius * 3.25
		regularRadius = math.Round 0.5 * regularRadius

		if widthModifier < 1
			@__rtDirty = true

		surface.SetDrawColor 255, 255, 255
		for stackId, animator in ipairs @__branchAnimators
		    buffer = animator\getPosition!

			--
			-- Draw the starting node.
			--
			first = animator.__nodeStack[1]

			circleAt first.x, first.y, firstNodeRadius

			--
			-- While the buffer is more than zero, draw the trace.
			--
			if buffer > 0
				target = animator\getBranchNode! or animator\getLastNode!

				for i = 1, target.id - 1
					current = animator.__nodeStack[i]
					next    = animator.__nodeStack[i + 1]

					mag = math.min buffer, next.totalLength and current.totalLength and (next.totalLength - current.totalLength) or 0

					buffer -= mag

					draw.NoTexture!
					drawLine current.x, current.y, next.x, next.y, regularRadius * 2, mag

					-- Draw the circly circle.
					do
						dx = next.x - current.x
						dy = next.y - current.y

						_mag = math.sqrt dx^2 + dy^2
						dx = dx / _mag * mag
						dy = dy / _mag * mag

						circleAt (math.Round current.x + dx),
								(math.Round current.y + dy), regularRadius

					if buffer <= 0
						break

				--
				-- Draw the auxiliary trace. The one that backtracks.
				--
				if buffer > 0 and animator.__auxiliaryStack[1]
					branchnode = animator\getBranchNode! or animator.__nodeStack[#animator.__nodeStack]

					for i = 1, #animator.__auxiliaryStack
						current = animator.__auxiliaryStack[i - 1] or branchnode
						next    = animator.__auxiliaryStack[i]

						mag = math.min buffer, next.totalLength and current.totalLength and (next.totalLength - current.totalLength) or 0

						buffer -= mag

						draw.NoTexture!
						drawLine current.x, current.y, next.x, next.y, regularRadius * 2, mag

						-- Circle 2: Electric Boogaloo.
						do
							dx = next.x - current.x
							dy = next.y - current.y

							_mag = math.sqrt dx^2 + dy^2
							dx = dx / _mag * mag
							dy = dy / _mag * mag

							circleAt (math.Round current.x + dx),
								(math.Round current.y + dy), regularRadius

						if buffer <= 0
							break

	-----------------------------
	-- Paints the canvas. Duh. --
	-----------------------------
	Paint: CLIENT and (w, h) =>
		return if not @CanRender!

		surface.SetMaterial @__rtAlloc.rt.material

		-- Determine whether the screen should be tinted black
		-- based on the power state value.
		if @__powerState ~= nil and @__powerStateBuffer
			color = math.Round 255 * math.EaseInOut @__powerStateBuffer,
				0.25, 0.25

			surface.SetDrawColor color, color, color

		else
			surface.SetDrawColor 255, 255, 255

		surface.DrawTexturedRect 0, 0, w, h

	--------------------------------------------------
	-- Renders the RT. Decoupled from Paint so that --
	-- HDR has no effect on this.                   --
	--------------------------------------------------
	RenderRT: CLIENT and =>
		return if not @CanRender!

		if @__rtDirty
			w = Moonpanel.Canvas.Resolution
			h = w

			@__rtDirty = false

			-- Draw black square if no data.
			if not @__data or
				not @__clientData or
				not @__clientData.__visibleNodes or
				not @__clientData.__paths
					clearRT @__rtAlloc.rt.texture
					return

			oldw, oldh = ScrW!, ScrH!

			-- Draw traces in a temporary render target,
			-- so that we can adjust their alpha values without
			-- making them look ugly as satan's face.
			auxrt = Moonpanel.Canvas\GetAuxiliaryRT!
			with render.PushRenderTarget auxrt.texture
				cam.Start2D!
				render.Clear 0, 0, 0, 0, true, false
				@PaintTrace w, h if @__playData
				cam.End2D!

			render.PopRenderTarget!

			-- Draw the rest of the panel in a dedicated rendertarget.
			-- "How do we get one?", you might ask. The answer is...
			-- out of this function scope.
			with render.PushRenderTarget @__rtAlloc.rt.texture
				cam.Start2D!
				render.Clear 0, 0, 0, 0, true, false

				surface.SetDrawColor 80, 80, 255
				surface.DrawRect 0, 0, w, h

				barWidth = w * (@__data.Dim.BarWidth / 100)

				surface.SetDrawColor 32, 24, 180

				-- Draw visible paths.
				draw.NoTexture!
				for path in *@__clientData.__paths
					surface.DrawTexturedRectRotated path.screenX, path.screenY,
						path.distance, barWidth, path.angle

				-- Draw all visible nodes.
				-- Clickable nodes are nearly twice as big.
				for node in *@__clientData.__visibleNodes
					size = node.clickable and barWidth * 3.25 or barWidth
					circleAt node.screenX, node.screenY, size / 2

				-- Determine whether traces should be
				local fade
				if @__playData.endTime
					fade = 1 - (math.EaseInOut (timePct @__playData.endTime, 0.5),
						0.25, 0.25)

					@__rtDirty = true if fade > 0

				if not @__playData.endTime or (fade and fade > 0)
					surface.SetMaterial auxrt.material
					surface.SetDrawColor 255, 255, 255, fade and fade * 255 or 255
					surface.DrawTexturedRect 0, 0, w, h

				cam.End2D!

			render.PopRenderTarget!

Moonpanel.Canvas.Canvas = Canvas

Moonpanel.Canvas.RT
