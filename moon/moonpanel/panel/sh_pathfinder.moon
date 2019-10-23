hasValue = (t, val) ->
    for k, v in pairs t
        if v == val
            return true
    return false

trunc = (num, n) ->
    mult = 10^(n or 0)
    return math.floor(num * mult + 0.5) / mult

class Moonpanel.PathFinder
    nodeStacks: {}
    isFirst: (node) =>
        for k, nodeStack in pairs @nodeStacks
            if nodeStack[1] == node
                return true
        return false

    hasNode: (val) =>
        for k, nodeStack in pairs @nodeStacks
            if hasValue nodeStack, val
                return true
        return false

    checkSymmetry: (a, b) =>
        if not @symmetry or not a or not b
            return false

        rotational = (@symmetry == Moonpanel.Symmetry.Rotational) and (a.x == -b.x) and (a.y == -b.y)
        vertical = (@symmetry == Moonpanel.Symmetry.Vertical) and (a.x == b.x) and (a.y == -b.y)
        horizontal = (@symmetry == Moonpanel.Symmetry.Horizontal) and (a.x == -b.x) and (a.y == b.y)

        return rotational or vertical or horizontal

    getClosestNode: (x, y, radius) =>
        for k, node in pairs @clickableNodes
            dist = math.sqrt (x - node.screenX)^2 + (y - node.screenY)^2
            if dist <= radius
                return node

    getSymmetricalNode: (firstNode) =>
        return @symmetricalNodes[firstNode]

    think: () =>
        -- Calculate valid points
        for nodeStackId, nodeStack in pairs @nodeStacks
            nodeCursor = @cursors[nodeStackId]
            last = nodeStack[#nodeStack]

            localMouseX = nodeCursor.x - last.screenX
            localMouseY = nodeCursor.y - last.screenY
            mouseVector = Vector localMouseX, localMouseY, 0

            maxMDot = 0
            maxDotVector = nil
            maxNode = nil
            maxVecLength = nil
            -- Iterate through all neighboring points to find the best match
            for _, neighbor in pairs last.neighbors
                vec = Vector neighbor.screenX - last.screenX, neighbor.screenY - last.screenY, 0

                vecLength = vec\Length!

                if neighbor ~= nodeStack[#nodeStack - 1]
                    vecLength -= (@isFirst(neighbor) and @barWidth * 1.75) or (@hasNode(neighbor) and @barWidth) or 0

                vec\Normalize!
                mDot = vec\Dot mouseVector

                if mDot > 0
                    mDot = math.min mDot, vecLength
                    if mDot >= maxMDot
                        maxMDot = mDot
                        maxDotVector = (vec * mDot)
                        maxNode = neighbor
                        maxVecLength = vecLength

            -- This might introduce several inaccuracies, but 
            -- floating points is why we can't have nice things.
            if maxDotVector
                maxDotVector.x = trunc maxDotVector.x, 3
                maxDotVector.y = trunc maxDotVector.y, 3

            if not @dotVectors[nodeStackId]
                @dotVectors[nodeStackId] = {}

            @dotVectors[nodeStackId].maxNode = maxNode
            @dotVectors[nodeStackId].maxDotVector = maxDotVector
            @dotVectors[nodeStackId].maxMDot = trunc maxMDot, 3
            @dotVectors[nodeStackId].maxVecLength = maxVecLength

        -- Determine the minVector and setup cursor offset nodes
        allPointsValid = true
        local minVector
        for nodeStackId, nodeStack in pairs @nodeStacks
            @cursorOffsetNodes[nodeStackId] = nodeStack[#nodeStack]
            
            if allPointsValid
                vector = @dotVectors[nodeStackId]
                if not vector.maxNode or not vector.maxVecLength or vector.maxMDot == 0
                    allPointsValid = false

                if not minVector or vector.maxMDot < minVector.maxMDot
                    minVector = vector

        if allPointsValid
            -- Clamp all other points to minVector magnitude
            for nodeStackId, nodeStack in pairs @nodeStacks
                vector = @dotVectors[nodeStackId]
                if vector ~= minVector
                    vector = @dotVectors[nodeStackId]
                    vector.maxDotVector.x = trunc (minVector.maxMDot * (vector.maxDotVector.x / vector.maxMDot)), 3
                    vector.maxDotVector.y = trunc (minVector.maxMDot * (vector.maxDotVector.y / vector.maxMDot)), 3
                    vector.maxMDot = minVector.maxMDot

            -- If symmetry, ensure that vectors are symmetrical
            if @symmetry
                vec_1 = @dotVectors[1].maxDotVector
                vec_2 = @dotVectors[2].maxDotVector

                allPointsValid = if @symmetry == Moonpanel.Symmetry.Rotational
                    (vec_1.x == -vec_2.x) and (vec_1.y == -vec_2.y)
                elseif @symmetry == Moonpanel.Symmetry.Vertical
                    (vec_1.x ==  vec_2.x) and (vec_1.y == -vec_2.y)
                elseif @symmetry == Moonpanel.Symmetry.Horizontal
                    (vec_1.x == -vec_2.x) and (vec_1.y ==  vec_2.y)

        if allPointsValid
            -- Check for overlaps
            seen = {}
            isOverlapping = false
            for nodeStackId, nodeStack in pairs @nodeStacks
                vector = @dotVectors[nodeStackId]
                if not @isFirst(vector.maxNode) and seen[vector.maxNode]
                    isOverlapping = true
                    break

                seen[vector.maxNode] = true

            -- If there are overlaps, clamp cursors
            if isOverlapping
                for nodeStackId, nodeStack in pairs @nodeStacks
                    vector = @dotVectors[nodeStackId]

                    newLength = (vector.maxVecLength - @barWidth / 2)
                    if vector.maxMDot > newLength
                        vector.maxDotVector.x = trunc newLength * (vector.maxDotVector.x / vector.maxMDot), 3
                        vector.maxDotVector.y = trunc newLength * (vector.maxDotVector.y / vector.maxMDot), 3
                        vector.maxMDot = newLength

            toInsert = {}
            toInsertCount = 0
            toRemove = {}
            toRemoveCount = 0

            -- Determine inserts/removes for this round
            for nodeStackId, nodeStack in pairs @nodeStacks
                nodeCursor = @cursors[nodeStackId]
                vector = @dotVectors[nodeStackId]
                to = vector.maxNode
            
                if not to.break and vector.maxMDot >= vector.maxVecLength
                    if to ~= nodeStack[1] and to == nodeStack[#nodeStack - 1]
                        table.insert toRemove, #nodeStack
                        toRemoveCount += 1
                        continue

                    elseif not @hasNode to
                        table.insert toInsert, to
                        toInsertCount += 1
                        continue

                elseif to and not to.break and to == nodeStack[#nodeStack - 1]
                    table.insert toRemove, #nodeStack
                    toRemoveCount += 1

            -- Prevent weird uncaught cases
            if not (toInsertCount > 0 and toRemoveCount > 0)
                -- If there are points to insert, insert them
                if toInsertCount == #@nodeStacks
                    allPointsValid = false

                    for nodeStackId, nodeStack in pairs @nodeStacks
                        table.insert @nodeStacks[nodeStackId], toInsert[nodeStackId]
                        @cursorOffsetNodes[nodeStackId] = toInsert[nodeStackId]

                -- If there are points to remove, remove them
                elseif toRemoveCount == #@nodeStacks
                    allPointsValid = false
                    for nodeStackId, nodeStack in pairs @nodeStacks
                        @potentialNodes[nodeStackId] = nodeStack[toRemove[nodeStackId]]

                        table.remove @nodeStacks[nodeStackId], toRemove[nodeStackId]

        -- Finally, determine new cursor positions
        for nodeStackId, nodeStack in pairs @nodeStacks
            nodeCursor = @cursors[nodeStackId]
            offsetNode = @cursorOffsetNodes[nodeStackId]
            vector = @dotVectors[nodeStackId]
            
            -- Snap cursors to lines
            if allPointsValid
                nodeCursor.x = offsetNode.screenX + vector.maxDotVector.x
                nodeCursor.y = offsetNode.screenY + vector.maxDotVector.y

                @potentialNodes[nodeStackId] = vector.maxNode
            -- Snap cursors to last known points
            else
                nodeCursor.x = offsetNode.screenX
                nodeCursor.y = offsetNode.screenY

    applyDeltas: (x, y) =>
        if not @nodeStacks or not @cursors
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

        @think!

    restart: (firstNode, secondNode) =>
        @dotVectors = {}
        @cursorOffsetNodes = {}
        @potentialOffsetNodes = {}

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

        if secondNode
            table.insert @nodeStacks, { secondNode }
            @cursors[#@cursors + 1] = {
                x: secondNode.screenX
                y: secondNode.screenY
                ix: secondNode.screenX
                iy: secondNode.screenY
            }

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

        -- Prepare symmetrical clickable nodes
        seen = {}
        @symmetricalNodes = {}
        for _, firstNode in pairs @clickableNodes
            for _, secondNode in pairs @clickableNodes
                if not seen[firstNode] and not seen[secondNode] and @checkSymmetry firstNode, secondNode
                    @symmetricalNodes[secondNode] = firstNode
                    @symmetricalNodes[firstNode]  = secondNode
                    seen[firstNode]  = true
                    seen[secondNode] = true

        -- Cache the nodemap IDs so we can communicate them easily.
        -- This is highly unsafe since nodemaps might end up
        -- being different on a client. To make it a bit safe,
        -- we can append the nodemap length to a message.
        -- Normally, this SHOULDN'T ever happen.
        @__nodeLength = #@nodeMap
        @nodeIds = {}
        for i, node in pairs @nodeMap
            @nodeIds[node] = i