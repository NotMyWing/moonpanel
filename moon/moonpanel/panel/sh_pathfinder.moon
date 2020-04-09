trunc = Moonpanel.trunc

class Moonpanel.PathFinder
    nodeStacks: {}

    -----------------------------------
    -- Constructor
    -----------------------------------
    new: (@nodeMap, @data, @updateCallback, @cursorCallback) =>
        with @data
            @barLength = .barLength
            @barWidth = .barWidth
            @screenWidth = .screenWidth
            @screenHeight = .screenHeight
            @symmetry = (.symmetry and .symmetry ~= Moonpanel.Symmetry.None) and .symmetry or false

        -- Prepare clickable nodes
        @clickableNodes = {}
        for k, node in pairs @nodeMap
            if node.clickable
                @clickableNodes[#@clickableNodes + 1] = node

        if @symmetry
            @symmetrizePathmap!

        -- Cache the nodemap IDs so we can communicate them easily.
        -- This is highly unsafe since nodemaps might end up
        -- being different on a client. To make it a bit safe,
        -- we can append the nodemap length to a message.
        -- Normally, this SHOULDN'T ever happen.
        @__nodeLength = #@nodeMap
        @nodeIds = {}
        for i, node in pairs @nodeMap
            @nodeIds[node] = i

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
        if not @symmetry or not a or not b
            return false

        rotational = (@symmetry == Moonpanel.Symmetry.Rotational) and (a.x == -b.x) and (a.y == -b.y)
        vertical = (@symmetry == Moonpanel.Symmetry.Vertical) and (a.x == b.x) and (a.y == -b.y)
        horizontal = (@symmetry == Moonpanel.Symmetry.Horizontal) and (a.x == -b.x) and (a.y == b.y)

        return rotational or vertical or horizontal

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
        return node.clickable and node or nil

    --------------------------------------------------
    -- ...gets the symmetrical node for a given node.
    --------------------------------------------------
    getSymmetricalNode: (firstNode) =>
        return @symmetricalNodes[firstNode]

    ----------------------------------------------
    -- Creates a hashmap of symmetrical nodes for
    -- faster lookups.
    ----------------------------------------------
    remapSymmetricalNodes: =>
        seen = {}
        @symmetricalNodes = {}
        for _, firstNode in pairs @nodeMap
            for _, secondNode in pairs @nodeMap
                if not seen[firstNode] and not seen[secondNode] and @checkSymmetry firstNode, secondNode
                    @symmetricalNodes[secondNode] = firstNode
                    @symmetricalNodes[firstNode]  = secondNode
                    seen[firstNode]  = true
                    seen[secondNode] = true

    --------------------------------------------------
    -- Symmetrizes the pathmap, ensuring that
    -- all nodes and paths are symmetrical.
    --
    -- Directly modifies the pathmap, so be careful.
    --
    -- This is only useful for snapping.
    --------------------------------------------------
    symmetrizePathmap: =>
        time = os.clock!
        seen = {}
        newNodes = {}

        @remapSymmetricalNodes!
        for _, node in pairs @nodeMap
            if seen[node]
                continue
            
            symmNode = @symmetricalNodes

            -- If not doesn't have any symmetrical nodes and isn't a break
            -- remove it from the map and rewire all neighbouring nodes
            if not node.break and not symmNode
                for _, neighbor in pairs node.neighbors
                    for id, otherNeighbor in pairs neighbor.neighbors
                        if otherNeighbor == node
                            table.remove neighbor.neighbors, id
                            break

                node.neighbors = {}

            -- If node is a break, then break the symmetrical node
            elseif node.break and symmNode
                seen[node] = true
                seen[node.pairedBreak] = true
                
                breakNodes = { node, node.pairedBreak }
                breakParents = {}

                for _, breakNode in pairs breakNodes
                    parent = breakNode.neighbors[1]
                    symmBreakParent = @symmetricalNodes[parent]

                    breakParents[#breakParents + 1] = symmBreakParent

                -- Rewire parents from each other
                for parentId, parent in pairs breakParents
                    otherParent = breakParents[1 + (2 - parentId)] 
                    for id, neighbor in pairs parent.neighbors
                        if otherParent == neighbor
                            table.remove parent.neighbors, id

                -- Create symmetrical breaks
                newBreaks = {}
                for id, breakNode in pairs breakNodes
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
                    table.insert newNodes, newBreak

        -- Populate the map with new nodes
        for _, newNode in pairs newNodes
            @nodeMap[#@nodeMap + 1] = newNode

        if newNodes[1]
            @remapSymmetricalNodes!

        -- Find all distinct connections
        distinctConnections = {}
        memo = {}
        for _, nodeA in pairs @nodeMap
            memo[nodeA] = true
            for _, nodeB in pairs nodeA.neighbors
                if not memo[nodeB]
                    distinctConnections[#distinctConnections + 1] = {
                        from: nodeA
                        to: nodeB
                    }

        -- Iterate through every connection
        count = #distinctConnections
        for connectionId, connection in pairs distinctConnections
            symmNodeA = @symmetricalNodes[connection.from]
            symmNodeB = @symmetricalNodes[connection.to]

            connected = false
            if symmNodeA and symmNodeB
                for _, neighbor in pairs symmNodeA.neighbors
                    if neighbor == symmNodeB
                        connected = true
                        break

            -- If there isn't a symmetrical pair of nodes
            -- rewire current pair from each other
            if not connected               
                count -= 1
                nodes = { connection.from, connection.to }
                for nodeId, nodeA in pairs nodes
                    otherNode = nodes[1 + (2 - nodeId)] 
                    for id, nodeB in pairs nodeA.neighbors
                        if otherNode == nodeB
                            table.remove nodeA.neighbors, id

    -----------------------------------
    -- Restarts the PathFinder.
    -----------------------------------
    restart: (firstNode, secondNode) =>
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
            if @symmetry == Moonpanel.Symmetry.Rotational
                @cursors[2].x = math.ceil @cursors[2].ix - dx
                @cursors[2].y = math.ceil @cursors[2].iy - dy

            if @symmetry == Moonpanel.Symmetry.Vertical
                @cursors[2].x = math.floor @cursors[2].ix + dx
                @cursors[2].y = math.ceil @cursors[2].iy - dy

            if @symmetry == Moonpanel.Symmetry.Horizontal
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
        for nodeStackId, nodeStack in pairs @nodeStacks
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
            for _, neighbor in ipairs last.neighbors
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
        if @symmetry and (@dotVectors[1].maxNode == @dotVectors[2].maxNode)
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
                for _, snapNode in ipairs snapOrigin.neighbors
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
                    maxMDot -= math.floor maxSnapDot
                else
                    maxMDot += math.floor maxSnapDot

                -- This might introduce several inaccuracies, but 
                -- floating points is why we can't have nice things.
                length = trunc math.max 0, (math.min maxVecLength, maxMDot), 3
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
            if @symmetry
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

                allNodesValid = if @symmetry == Moonpanel.Symmetry.Rotational
                    (vec_1.x == -vec_2.x) and (vec_1.y == -vec_2.y)
                elseif @symmetry == Moonpanel.Symmetry.Vertical
                    (vec_1.x ==  vec_2.x) and (vec_1.y == -vec_2.y)
                elseif @symmetry == Moonpanel.Symmetry.Horizontal
                    (vec_1.x == -vec_2.x) and (vec_1.y ==  vec_2.y)

        if allNodesValid
            -- Check for overlaps
            seen = {}
            isOverlapping = false
            for nodeStackId, nodeStack in ipairs @nodeStacks
                vector = @dotVectors[nodeStackId]
                if not @isFirst(vector.maxNode) and seen[vector.maxNode]
                    isOverlapping = true
                    break

                seen[vector.maxNode] = true

            -- If there are overlaps, clamp cursors
            if isOverlapping
                for nodeStackId, nodeStack in ipairs @nodeStacks
                    vector = @dotVectors[nodeStackId]

                    newLength = (vector.maxVecLength - @barWidth / 2)
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
