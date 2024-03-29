AddCSLuaFile!

trunc = (num, n) ->
	mult = 10^(n or 0)
	math.floor(num * mult + 0.5) / mult

class Moonpanel.Canvas.PathFinder
    nodeStacks: {}

    -----------------------------------
    -- Constructor
    -----------------------------------
    new: (@data, @updateCallback, @cursorCallback) =>
        with @data
            @nodeMap = .nodes
            @barLength = .barLength
            @barWidth = .barWidth
            @screenWidth = .screenWidth
            @screenHeight = .screenHeight
            @symmetry = .symmetry or 0

        @rebuildCache!

    ---------------------------------------------------------
    -- Checks if a given node is one of the initial nodes.
    ---------------------------------------------------------
    isFirst: (node) =>
        for k, nodeStack in pairs @nodeStacks
            if nodeStack[1] == node
                return true

        return false

    --------------------------------------
    -- Checks if a given node is traced.
    --------------------------------------
    isTraced: (node) =>
        return @tracedNodes[node]

    ----------------------------------------
    -- Checks if two nodes are symmetrical.
    ----------------------------------------
    checkSymmetry: (a, b) =>
        return false if not (@symmetry > 0) or not a or not b

        switch @symmetry
            when Moonpanel.Canvas.Symmetry.Rotational
                (a.x == -b.x) and (a.y == -b.y)
            when Moonpanel.Canvas.Symmetry.Vertical
                (a.x == b.x) and (a.y == -b.y)
            when Moonpanel.Canvas.Symmetry.Horizontal
                (a.x == -b.x) and (a.y == b.y)

    --------------------------------------------------
    -- ...gets the closest CLICKABLE node to given
    -- point and radius.
    --------------------------------------------------
    getClosestNode: (x, y, radius) =>
        for k, node in pairs @clickableNodes
            dist = math.sqrt (x - node.screenX)^2 + (y - node.screenY)^2
            if dist <= radius
                return node

    --------------------------------------------------
    -- ...gets the symmetrical node for a given node.
    -- And checks if it's clickable.
    --------------------------------------------------
    getSymmetricalClickableNode: (firstNode) =>
        node = @symmetricalNodes[firstNode]
        return node and node.clickable and node or nil

    --------------------------------------------------
    -- ...gets the symmetrical node for a given node.
    --------------------------------------------------
    getSymmetricalNode: (firstNode) =>
        return @symmetricalNodes[firstNode]

    -------------------------
    -- Rebuilds the cache. --
    -------------------------
    rebuildCache: =>
        -- Prepare clickable nodes
        @clickableNodes = {}
        for node in *@nodeMap
            if node.clickable
                @clickableNodes[#@clickableNodes + 1] = node

        if @symmetry > 0
            @symmetrizePathmap!
        else
            @symmetrizedNeighbors = nil
            @symmetryMap = nil

        @nodeIds = {}
        for i, node in pairs @nodeMap
            @nodeIds[node] = i

    ----------------------------------------------
    -- Creates a hashmap of symmetrical nodes for
    -- faster lookups.
    ----------------------------------------------
    remapSymmetricalNodes: =>
        seen = {}
        @symmetricalNodes = {}
        for map in *{ @nodeMap, @symmetryMap }
            for firstNode in *map
                for secondNode in *map
                    if not seen[firstNode] and not seen[secondNode] and @checkSymmetry firstNode, secondNode
                        @symmetricalNodes[secondNode] = firstNode
                        @symmetricalNodes[firstNode]  = secondNode
                        seen[firstNode]  = true
                        seen[secondNode] = true

    createSymmetrizedNeighbors: (node) =>
        neighbors = {}
        for neighbor in *node.neighbors
            table.insert neighbors, neighbor

        @symmetrizedNeighbors[node] = neighbors

    --------------------------------------------------
    -- Symmetrizes the pathmap, ensuring that
    -- all nodes and paths are symmetrical.
    --
    -- Directly modifies the pathmap, so be careful.
    --
    -- This is only useful for snapping.
    --------------------------------------------------
    symmetrizePathmap: =>
        @symmetrizedNeighbors = {}
        @symmetryMap = {}

        time = os.clock!
        seen = {}
        shouldRemap = false

        @remapSymmetricalNodes!

        for node in *@nodeMap
            if seen[node]
                continue

            symmNode = @symmetricalNodes

            -- If node doesn't have any symmetrical nodes and isn't a break
            -- remove it from the map and rewire all neighbouring nodes
            if not node.break and not symmNode
                for neighbor in *node.neighbors
                    for id, otherNeighbor in pairs neighbor.neighbors
                        if otherNeighbor == node
                            if not @symmetrizedNeighbors neighbor
                                @createSymmetrizedNeighbors neighbor

                            table.remove @symmetrizedNeighbors[neighbor], id
                            break

                @symmetrizedNeighbors[node] = {}

            -- If node is a break, then break the symmetrical node
            elseif node.break and symmNode
                seen[node] = true
                seen[node.pairedBreak] = true

                breakNodes = { node, node.pairedBreak }
                breakParents = {}

                for breakNode in *breakNodes
                    parent = breakNode.neighbors[1]
                    symmBreakParent = @symmetricalNodes[parent]

                    breakParents[#breakParents + 1] = symmBreakParent

                -- Rewire parents from each other
                for parentId, parent in ipairs breakParents
                    otherParent = breakParents[1 + (2 - parentId)]
                    for id, neighbor in ipairs parent.neighbors
                        if otherParent == neighbor
                            table.remove parent.neighbors, id
                            break

                -- Create symmetrical breaks
                newBreaks = {}
                for id, breakNode in ipairs breakNodes
                    parent = breakNode.neighbors[1]
                    symmParent = breakParents[id]

                    dx = parent.x - breakNode.x
                    dy = parent.y - breakNode.y

                    dsx = parent.screenX - breakNode.screenX
                    dsy = parent.screenY - breakNode.screenY

                    newBreak = {
                        x: symmParent.x + dx
                        y: symmParent.y + dy
                        screenX: symmParent.screenX + dsx
                        screenY: symmParent.screenY + dsy
                        break: true
                        neighbors: { symmParent }
                    }

                    table.insert symmParent.neighbors, newBreak
                    table.insert @symmetryMap, newBreak

        @remapSymmetricalNodes!

        -- Find all distinct connections
        distinctConnections = {}
        memo = {}
        for nodeA in *@nodeMap
            memo[nodeA] = true
            for nodeB in *@getNeighbors nodeA
                if not memo[nodeB]
                    distinctConnections[#distinctConnections + 1] = {
                        from: nodeA
                        to: nodeB
                    }

        -- Iterate through every connection
        for connection in *distinctConnections
            symmNodeA = @symmetricalNodes[connection.from]
            symmNodeB = @symmetricalNodes[connection.to]

            connected = false
            if symmNodeA and symmNodeB
                for neighbor in *@getNeighbors symmNodeA
                    if neighbor == symmNodeB
                        connected = true
                        break

            -- If there isn't a symmetrical pair of nodes
            -- rewire current pair from each other
            if not connected
                nodes = { connection.from, connection.to }
                for nodeId, nodeA in ipairs nodes
                    otherNode = nodes[1 + (2 - nodeId)]

                    if not @symmetrizedNeighbors[nodeA]
                        @createSymmetrizedNeighbors nodeA

                    neighbors = @symmetrizedNeighbors[nodeA]

                    for id, nodeB in ipairs neighbors
                        if otherNode == nodeB
                            table.remove neighbors, id

    getNeighbors: (node) =>
        if @symmetrizedNeighbors
            @symmetrizedNeighbors[node] or node.neighbors
        else
            node.neighbors

    -----------------------------------
    -- Restarts the PathFinder.
    -----------------------------------
    restart: (firstNode) =>
        local secondNode

        if "number" == type firstNode
            firstNode = @nodeMap[firstNode]

        if @symmetry > 0
            secondNode = @getSymmetricalClickableNode firstNode
            return if not secondNode

        @dotVectors = {}
        @cursorOffsetNodes = {}

        @nodeStacks = { {firstNode} }
        @potentialNodes = {}
        @cursors = {
            {
                x: firstNode.screenX
                y: firstNode.screenY
                ix: firstNode.screenX
                iy: firstNode.screenY
            }
        }
        @tracedNodes = {
            [firstNode]: true
        }

        if secondNode
            @tracedNodes[secondNode] = true
            table.insert @nodeStacks, { secondNode }
            @cursors[#@cursors + 1] = {
                x: secondNode.screenX
                y: secondNode.screenY
                ix: secondNode.screenX
                iy: secondNode.screenY
            }

        true

    -------------------------------------------
    -- Applies delta movement. Returns true if there was an update.
    -------------------------------------------
    applyDeltas: (x, y) =>
        if not @dotVectors or not @nodeStacks or not @cursors
            return

        @cursors[1].x = math.floor @cursors[1].x + x
        @cursors[1].y = math.floor @cursors[1].y + y

        if @cursors[2]
            dx = @cursors[1].x - @cursors[1].ix
            dy = @cursors[1].y - @cursors[1].iy
            if @symmetry == Moonpanel.Canvas.Symmetry.Rotational
                @cursors[2].x = math.ceil @cursors[2].ix - dx
                @cursors[2].y = math.ceil @cursors[2].iy - dy

            if @symmetry == Moonpanel.Canvas.Symmetry.Vertical
                @cursors[2].x = math.floor @cursors[2].ix + dx
                @cursors[2].y = math.ceil @cursors[2].iy - dy

            if @symmetry == Moonpanel.Canvas.Symmetry.Horizontal
                @cursors[2].x = math.ceil @cursors[2].ix - dx
                @cursors[2].y = math.floor @cursors[2].iy + dy

        return @think!

    ----------------------------------------
    -- Thinks.
    -- This should not be called directly.
    -- Consider calling applyDeltas instead.
    --
    -- Danger: loads of math ahead.
    -----------------------------------------
    think: () =>
        updated = false

        -- Calculate valid nodes
        for nodeStackId, nodeStack in ipairs @nodeStacks
            if not @dotVectors[nodeStackId]
                @dotVectors[nodeStackId] = {}

            -- Prepare stuff
            @dotVectors[nodeStackId].maxNode = nil
            @dotVectors[nodeStackId].maxDotVector = nil
            @dotVectors[nodeStackId].maxMDot = nil
            @dotVectors[nodeStackId].maxVecLength = nil

            nodeCursor = @cursors[nodeStackId]
            last = nodeStack[#nodeStack]

            localMouseX = nodeCursor.x - last.screenX
            localMouseY = nodeCursor.y - last.screenY

            maxMDot = 0
            maxDotVector = nil
            maxNode = nil
            maxVecLength = nil

            -- Iterate through all neighboring nodes to find the best match
            for neighbor in *@getNeighbors last
                vec = Vector neighbor.screenX - last.screenX, neighbor.screenY - last.screenY, 0

                vecLength = vec\Length!
                if neighbor ~= nodeStack[#nodeStack - 1]
                    vecLength -= (@isFirst(neighbor) and @barWidth * 1.75) or (@isTraced(neighbor) and @barWidth) or 0

                vec\Normalize!
                mDot = vec.x * localMouseX + vec.y * localMouseY

                if mDot > 0 and mDot >= maxMDot
                    maxMDot = mDot
                    maxDotVector = vec
                    maxNode = neighbor
                    maxVecLength = vecLength

            if maxDotVector
                @dotVectors[nodeStackId].maxNode = maxNode
                @dotVectors[nodeStackId].maxDotVector = maxDotVector
                @dotVectors[nodeStackId].maxMDot = maxMDot
                @dotVectors[nodeStackId].maxVecLength = maxVecLength

        -- Snapping
        areSnapsDistinct = true
        if @symmetry > 0 and (@dotVectors[1].maxNode == @dotVectors[2].maxNode)
            areSnapsDistinct = false

        for nodeStackId, nodeStack in ipairs @nodeStacks
            maxNode = @dotVectors[nodeStackId].maxNode
            if maxNode
                maxMDot = @dotVectors[nodeStackId].maxMDot
                maxDotVector = @dotVectors[nodeStackId].maxDotVector
                maxVecLength = @dotVectors[nodeStackId].maxVecLength

                nodeCursor = @cursors[nodeStackId]

                last = nodeStack[#nodeStack]
                localMouseX = nodeCursor.x - last.screenX
                localMouseY = nodeCursor.y - last.screenY
                localMouseMag = math.sqrt localMouseX^2 + localMouseY^2

                -- Find the best suitable snap rigin
                snapOrigin = (localMouseMag > (maxVecLength / 2) and
                    areSnapsDistinct and
                    not maxNode.exit and
                    not maxNode.break and
                    not @isTraced maxNode) and maxNode or last

                -- Find perpendicular vector to vec
                px = localMouseX - (maxMDot * maxDotVector.x)
                py = localMouseY - (maxMDot * maxDotVector.y)

                -- Equality comparison tolerance
                tolerance = 0.001

                -- Find the max dotProduct of p to neighbouring lines
                maxSnapDot = 0
                for snapNode in *@getNeighbors snapOrigin
                    if snapNode == last or snapNode == maxNode
                        continue

                    dx = snapNode.screenX - snapOrigin.screenX
                    dy = snapNode.screenY - snapOrigin.screenY
                    mag = math.sqrt dx^2 + dy^2

                    modifier = 0.75

                    -- Don't prefer dead-end pathes
                    if @isTraced(snapNode)
                        modifier *= 0.8

                    dotProduct = modifier * (px * (dx/mag) + py * (dy/mag))
                    if dotProduct > 0 and math.abs(dotProduct) > tolerance and dotProduct > maxSnapDot
                        maxSnapDot = dotProduct

                if snapOrigin == last
                    maxMDot -= maxSnapDot
                else
                    maxMDot += maxSnapDot

                -- This might introduce several inaccuracies, but
                -- floating points is why we can't have nice things.
                length = math.max 0, (math.min maxVecLength, maxMDot), 3
                if length == 0
                    @dotVectors[nodeStackId].maxNode = nil
                    continue

                maxDotVector.x = trunc length * maxDotVector.x, 3
                maxDotVector.y = trunc length * maxDotVector.y, 3

                @dotVectors[nodeStackId].maxNode = maxNode
                @dotVectors[nodeStackId].maxDotVector = maxDotVector
                @dotVectors[nodeStackId].maxMDot = length
                @dotVectors[nodeStackId].maxVecLength = maxVecLength

        -- Determine the minVector and setup cursor offset nodes
        allNodesValid = true
        local minVector
        for nodeStackId, nodeStack in ipairs @nodeStacks
            @cursorOffsetNodes[nodeStackId] = nodeStack[#nodeStack]

            if allNodesValid
                vector = @dotVectors[nodeStackId]
                if not vector or not vector.maxNode or not vector.maxVecLength or vector.maxMDot == 0
                    allNodesValid = false

                if allNodesValid and (not minVector or vector.maxMDot < minVector.maxMDot)
                    minVector = vector

        if allNodesValid
            -- If symmetry, ensure that vectors are symmetrical
            if @symmetry > 0
                -- Clamp all other nodes to minVector magnitude
                for nodeStackId, nodeStack in ipairs @nodeStacks
                    vector = @dotVectors[nodeStackId]
                    dotVector = vector.maxDotVector
                    if dotVector.x ~= minVector.x or dotVector.y ~= minVector.y
                        vector = @dotVectors[nodeStackId]
                        vector.maxDotVector.x = trunc (minVector.maxMDot * (vector.maxDotVector.x / vector.maxMDot)), 3
                        vector.maxDotVector.y = trunc (minVector.maxMDot * (vector.maxDotVector.y / vector.maxMDot)), 3
                        vector.maxMDot = minVector.maxMDot

                        updated = true

                vec_1 = @dotVectors[1].maxDotVector
                vec_2 = @dotVectors[2].maxDotVector

                allNodesValid = if @symmetry == Moonpanel.Canvas.Symmetry.Rotational
                    (vec_1.x == -vec_2.x) and (vec_1.y == -vec_2.y)
                elseif @symmetry == Moonpanel.Canvas.Symmetry.Vertical
                    (vec_1.x ==  vec_2.x) and (vec_1.y == -vec_2.y)
                elseif @symmetry == Moonpanel.Canvas.Symmetry.Horizontal
                    (vec_1.x == -vec_2.x) and (vec_1.y ==  vec_2.y)

        if allNodesValid
            if @symmetry > 0
                -- Check for potential node type overlap
                overlapType = @potentialNodes[1] == @potentialNodes[2] and 1

                -- Check if traces aren't pointed towards the common point
                if not overlapType
                    lastNodes = [@nodeStacks[i][#@nodeStacks[i]] for i = 1, 2]

                    overlapType = @potentialNodes[1] == lastNodes[2] and
                        @potentialNodes[2] == lastNodes[1] and 2

                -- If there are overlaps, clamp cursors
                if overlapType
                    for nodeStackId, nodeStack in ipairs @nodeStacks
                        vector = @dotVectors[nodeStackId]

                        local newLength
                        if overlapType == 1
                            newLength = (vector.maxVecLength - @barWidth / 2)
                        else
                            newLength = vector.maxVecLength / 2

                        if vector.maxMDot > newLength
                            vector.maxDotVector.x = trunc newLength * (vector.maxDotVector.x / vector.maxMDot), 3
                            vector.maxDotVector.y = trunc newLength * (vector.maxDotVector.y / vector.maxMDot), 3
                            vector.maxMDot = newLength

                            updated = true

            toInsert = {}
            toInsertCount = 0
            toRemove = {}
            toRemoveCount = 0

            -- Determine inserts/removes for this round
            for nodeStackId, nodeStack in ipairs @nodeStacks
                nodeCursor = @cursors[nodeStackId]
                vector = @dotVectors[nodeStackId]
                to = vector.maxNode

                if not to.break and vector.maxMDot >= vector.maxVecLength
                    if to ~= nodeStack[1] and to == nodeStack[#nodeStack - 1]
                        table.insert toRemove, #nodeStack
                        toRemoveCount += 1
                        continue

                    elseif not @isTraced to
                        table.insert toInsert, to
                        toInsertCount += 1
                        continue

                elseif to and not to.break and to == nodeStack[#nodeStack - 1]
                    table.insert toRemove, #nodeStack
                    toRemoveCount += 1

            -- Prevent weird uncaught cases
            if not (toInsertCount > 0 and toRemoveCount > 0)
                -- If there are nodes to insert, insert them
                if toInsertCount == #@nodeStacks
                    allNodesValid = false
                    updated = true

                    for nodeStackId, nodeStack in ipairs @nodeStacks
                        table.insert @nodeStacks[nodeStackId], toInsert[nodeStackId]
                        @cursorOffsetNodes[nodeStackId] = toInsert[nodeStackId]
                        @tracedNodes[toInsert[nodeStackId]] = true

                -- If there are nodes to remove, remove them
                elseif toRemoveCount == #@nodeStacks
                    allNodesValid = false
                    updated = true

                    for nodeStackId, nodeStack in ipairs @nodeStacks
                        @potentialNodes[nodeStackId] = nodeStack[toRemove[nodeStackId]]

                        @tracedNodes[@potentialNodes[nodeStackId]] = nil
                        table.remove @nodeStacks[nodeStackId], toRemove[nodeStackId]

        -- Finally, determine new cursor positions
        for nodeStackId, nodeStack in ipairs @nodeStacks
            nodeCursor = @cursors[nodeStackId]
            offsetNode = @cursorOffsetNodes[nodeStackId]
            vector = @dotVectors[nodeStackId]

            -- Snap cursors to lines
            if allNodesValid
                nodeCursor.x = offsetNode.screenX + vector.maxDotVector.x
                nodeCursor.y = offsetNode.screenY + vector.maxDotVector.y

                @potentialNodes[nodeStackId] = vector.maxNode

                updated = true
            -- Snap cursors to last known nodes
            else
                oldx = nodeCursor.x
                oldy = nodeCursor.y

                nodeCursor.x = offsetNode.screenX
                nodeCursor.y = offsetNode.screenY

                if oldx ~= nodeCursor.x or oldy ~= nodeCursor.y
                    updated = true

        return updated
