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
        for k, node in pairs @nodeMap
            if node.clickable
                dist = math.sqrt (x - node.screenX)^2 + (y - node.screenY)^2
                if dist <= radius
                    return node

    getSymmetricalNode: (firstNode) =>
        for k, node in pairs @nodeMap
            if node.clickable and @checkSymmetry node, firstNode
                return node

    think: () =>
        if not @nodeStacks or not @cursors
            return

        toInsert = {}
        toRemove = {}

        for nodeStackId, nodeStack in pairs @nodeStacks
            nodeCursor = @cursors[nodeStackId]
            mouseX = nodeCursor.x
            mouseY = nodeCursor.y

            last = nodeStack[#nodeStack]

            localMouseX = mouseX - last.screenX
            localMouseY = mouseY - last.screenY
            mouseVector = Vector localMouseX, localMouseY, 0

            maxMDot = 0
            maxDotVector = nil
            maxNode = nil
            maxVecLength = nil
            for k, to in pairs last.neighbors
                vec = Vector to.screenX - last.screenX, to.screenY - last.screenY, 0

                vecLength = vec\Length!

                otherStack = @nodeStacks[1 - (nodeStackId - 1) + 1]
                if @symmetry and otherStack
                    otherLast = otherStack[#otherStack]
                    
                    if to == otherLast
                        vecLength /= 2
                        vecLength += @barWidth / 2

                if to ~= nodeStack[#nodeStack - 1]
                    vecLength -= (@isFirst(to) and @barWidth * 1.75) or (@hasNode(to) and @barWidth) or 0

                unitVector = vec\GetNormalized!

                mDot = unitVector\Dot mouseVector

                if mDot > 0
                    mDot = math.min mDot, vecLength
            
                    dotVector = (unitVector * mDot)
                    toMouseVec = mouseVector - dotVector

                    tx, ty = last.screenX + dotVector.x, last.screenY + dotVector.y
                    angle = math.atan2 (last.screenY - ty), (last.screenX - tx)

                    -- 1 back, 3 front, 2 left, 4 right
                    corrDotProducts = {}
                    for i = 1, 4
                        sx = math.cos angle
                        sy = math.sin angle

                        corrDotProducts[#corrDotProducts + 1] = toMouseVec\Dot Vector sx, sy, 0
                        angle += math.pi / 2

                    mainAxis = 8 * math.max corrDotProducts[3], corrDotProducts[1]

                    if corrDotProducts[2] >= mainAxis or corrDotProducts[4] >= mainAxis
                        if mDot > (@barLength or vecLength) / 2
                            mDot = mDot + toMouseVec\Length! * 0.25
                        else
                            mDot = mDot - toMouseVec\Length! * 0.25

                    mDot = math.min trunc(mDot, 3), vecLength

                    dotVector = (unitVector * mDot)
                    if mDot >= maxMDot
                        maxMDot = mDot
                        maxDotVector = dotVector
                        maxNode = to

                if not to.break and mDot >= vecLength
                    if to ~= nodeStack[1] and to == nodeStack[#nodeStack - 1]
                        if @symmetry
                            table.insert toRemove, #nodeStack
                        else
                            table.remove nodeStack, #nodeStack
                        break

                    elseif not @hasNode to
                        if @symmetry 
                            table.insert toInsert, to
                        else
                            table.insert nodeStack, to
                        break
      
            if maxNode and nodeStack[#nodeStack] == last
                nodeCursor.x = nodeStack[#nodeStack].screenX + maxDotVector.x
                nodeCursor.y = nodeStack[#nodeStack].screenY + maxDotVector.y

            else
                nodeCursor.x = nodeStack[#nodeStack].screenX
                nodeCursor.y = nodeStack[#nodeStack].screenY

            if maxNode and not maxNode.break and maxNode == nodeStack[#nodeStack - 1]
                if @symmetry
                    table.insert toRemove, #nodeStack
                else
                    table.remove nodeStack, #nodeStack

            if maxNode
                @potentialNodes[nodeStackId] = maxNode

        if @symmetry and #toInsert > 1 and toInsert[1] ~= toInsert[2]
            a = toInsert[1]
            b = toInsert[2]               

            --if not (a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
            --    b == @nodeStacks[2][1] or a == @nodeStacks[2][1]) and @checkSymmetry a, b

            table.insert @nodeStacks[1], toInsert[1]
            table.insert @nodeStacks[2], toInsert[2]

        if @symmetry and #toRemove > 1 and toRemove[1] == toRemove[2]
            a = @nodeStacks[1][toRemove[1]]
            b = @nodeStacks[2][toRemove[2]]                 

            --if not (a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
            --    b == @nodeStacks[2][1] or a == @nodeStacks[2][1]) and @checkSymmetry a, b

            table.remove @nodeStacks[1], toRemove[1]
            table.remove @nodeStacks[2], toRemove[2]

    applyDeltas: (x, y) =>
        if not @cursors
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

        -- Cache the nodemap IDs so we can communicate them easily.
        -- This is highly unsafe since nodemaps might end up
        -- being different on a client. To make it a bit safe,
        -- we can append the nodemap length to a message.
        -- Normally, this SHOULDN'T ever happen.
        @__nodeLength = #@nodeMap
        @nodeIds = {}
        for i, node in pairs @nodeMap
            @nodeIds[node] = i