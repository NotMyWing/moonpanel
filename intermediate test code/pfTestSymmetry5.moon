ROTATIONAL_SYMMETRY = 1
VERTICAL_SYMMETRY = 2
HORIZONTAL_SYMMETRY = 3

hasValue = (t, val) ->
    for k, v in pairs t
        if v == val
            return true
    return false

class PathFinder
    nodeStacks: {}
    hasNode: (val) =>
        for k, nodeStack in pairs @nodeStacks
            if hasValue nodeStack, val
                return true
        return false

    checkSymmetry: (a, b) =>
        if not @symmetry
            return false

        rotational = (@symmetry == ROTATIONAL_SYMMETRY) and (a.x == -b.x) and (a.y == -b.y)
        vertical = (@symmetry == VERTICAL_SYMMETRY) and (a.x == b.x) and (a.y == -b.y)
        horizontal = (@symmetry == HORIZONTAL_SYMMETRY) and (a.x == -b.x) and (a.y == b.y)

        return rotational or vertical or horizontal

    getClosestNode: (x, y, radius) =>
        for k, node in pairs @nodeMap
            dist = math.sqrt (x - node.screenX)^2 + (y - node.screenY)^2
            if dist <= radius
                return node

    getSymmetricalNode: (firstNode) =>
        for k, node in pairs @nodeMap
            if @checkSymmetry node, firstNode
                return node

    think: (mouseX, mouseY) =>
        if not @nodeStacks or not mouseX or not mouseY
            return

        toInsert = {}
        toRemove = {}
        for _, nodeStack in pairs @nodeStacks
            last = nodeStack[#nodeStack]

            if nodeStack == @nodeStacks[2]
                if @symmetry == VERTICAL_SYMMETRY
                    mouseX = @screenHeight - mouseX
                elseif @symmetry == HORIZONTAL_SYMMETRY
                    mouseX = @screenWidth - mouseX
                elseif @symmetry == ROTATIONAL_SYMMETRY
                    mouseX = @screenWidth - mouseX
                    mouseY = @screenHeight - mouseY

            localMouseX = mouseX - last.screenX
            localMouseY = mouseY - last.screenY
            mouseVector = Vector localMouseX, localMouseY, 0

            maxMDot = 0
            maxDotVector = nil
            maxNode = nil
            for k, to in pairs last.canConnectTo
                vec = Vector to.screenX - last.screenX, to.screenY - last.screenY, 0
                vecLength = vec\getLength! 

                unitVector = vec\getNormalized!

                mDot = unitVector\dot mouseVector

                if mDot > 0
                    mDot = math.min mDot, vecLength
                    
                    dotVector = (unitVector * mDot)
                    if mDot > maxMDot
                        maxMDot = mDot
                        maxNode = to

                if mDot >= vecLength
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

            if maxNode ~= nodeStack[1] and maxNode == nodeStack[#nodeStack - 1]
                if @symmetry
                    table.insert toRemove, #nodeStack
                else
                    table.remove nodeStack, #nodeStack

        if @symmetry and #toInsert > 1 and toInsert[1] ~= toInsert[2]
            a = toInsert[1]
            b = toInsert[2]               

            if a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
                b == @nodeStacks[2][1] or a == @nodeStacks[2][1]
                return

            if @checkSymmetry a, b
                table.insert @nodeStacks[1], toInsert[1]
                table.insert @nodeStacks[2], toInsert[2]

        if @symmetry and #toRemove > 1 and toRemove[1] == toRemove[2]
            a = @nodeStacks[1][toRemove[1]]
            b = @nodeStacks[2][toRemove[2]]                 

            if a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
                b == @nodeStacks[2][1] or a == @nodeStacks[2][1]
                return

            if @checkSymmetry a, b
                table.remove @nodeStacks[1], toRemove[1]
                table.remove @nodeStacks[2], toRemove[2]

    restart: (firstNode, secondNode) =>
        @nodeStacks = { {firstNode} }
        if secondNode 
            table.insert @nodeStacks, { secondNode }

    new: (@nodeMap, @screenWidth, @screenHeight, @symmetry) =>

if CLIENT
    makeCirclePoly = (r) ->
        circlePoly = {}
        for i = -180, 180, 10
            table.insert circlePoly, {
                x: r * math.cos math.rad i,
                y: r * math.sin math.rad i
            }
        return circlePoly

    polyCache = {}

    render.drawCirclePoly = (x, y, r) ->
        polyCache[r] = polyCache[r] or makeCirclePoly r
        
        matrix = Matrix!
        matrix\setTranslation Vector x, y, 0
        render.pushMatrix matrix
        render.drawPoly polyCache[r]
        render.popMatrix!

    nodeMap = {
        
    }

    spacing = 40
    width = 9
    height = 9

    offsetX = (512 - (spacing * (width - 1))) / 2
    offsetY = (512 - (spacing * (width - 1))) / 2

    for i = -math.floor(width / 2), math.floor(width / 2)
        if i == 0 and width % 2 == 0 
            continue

        for j = -math.floor(height / 2), math.floor(height / 2) 
            if j == 0 and height % 2 == 0 
                continue
            node = {}
            node.canConnectTo = {}
            node.x = i
            node.y = j
            node.screenX = 256 + (i * spacing)
            node.screenY = 256 + (j * spacing)

            table.insert nodeMap, node

            if i == -math.floor(width / 2) and j == -math.floor(width / 2)
                newNode = {}
                newNode.canConnectTo = {}
                newNode.x = i - 1
                newNode.y = j
                newNode.screenX = 256 + (i * spacing) - 40
                newNode.screenY = 256 + (j * spacing)
                newNode.canConnectTo = { node }
                node.canConnectTo = { newNode }

                table.insert nodeMap, newNode

            if i == math.floor(width / 2) and j == math.floor(width / 2)
                newNode = {}
                newNode.canConnectTo = {}
                newNode.x = i + 1
                newNode.y = j
                newNode.screenX = 256 + (i * spacing) + 40
                newNode.screenY = 256 + (j * spacing)
                newNode.canConnectTo = { node }
                node.canConnectTo = { newNode }

                table.insert nodeMap, newNode

    for k, v in pairs nodeMap
        for _k, _v in pairs nodeMap
            dist = math.sqrt (_v.x - v.x)^2 + (_v.y - v.y)^2
            if (dist <= 1)
                if not (hasValue v.canConnectTo, _v) and not (hasValue _v.canConnectTo, v)
                    table.insert v.canConnectTo, _v
                    table.insert _v.canConnectTo, v


    mouseX = nil
    mouseY = nil

    needsRedraw = true
    render.createRenderTarget "background"

    pathFinder = PathFinder nodeMap, 512, 512, ROTATIONAL_SYMMETRY

    inUse = false
    hook.add "inputPressed", "", (key) ->
        if key == 15 and mouseX and mouseY
            successful = true
            if not inUse
                firstNode = pathFinder\getClosestNode mouseX, mouseY, spacing / 2

                if firstNode
                    secondNode = if pathFinder.symmetry
                        pathFinder\getSymmetricalNode firstNode
                    
                    if (pathFinder.symmetry or 0) > 0 and not secondNode
                        return
                        
                    print firstNode
                    print secondNode 
                    pathFinder\restart firstNode, secondNode                        
                else
                    return

            inUse = not inUse

    splashText ="Pathfinding test" .. if not pathFinder.symmetry
        ""
    elseif pathFinder.symmetry == VERTICAL_SYMMETRY
        " - Vertical Symmetry"
    elseif pathFinder.symmetry == HORIZONTAL_SYMMETRY
        " - Horizontal Symmetry"
    elseif pathFinder.symmetry == ROTATIONAL_SYMMETRY
        " - Rotational Symmetry"

    hook.add "render", "", () ->
        if needsRedraw
            needsRedraw = false
            render.selectRenderTarget "background"
            
            render.setColor Color 24, 24, 24
            for k, a in pairs nodeMap
                for k, b in pairs a.canConnectTo 
                    render.drawLine a.screenX, a.screenY, b.screenX, b.screenY

            render.setColor Color 24, 24, 24
            for k, v in pairs nodeMap
                render.drawCirclePoly v.screenX, v.screenY, 6
            render.selectRenderTarget nil

        render.clear!
        render.setColor Color 255, 255, 255
        render.setRenderTargetTexture "background"
        render.drawTexturedRect 0, 0, 1024, 1024
        render.setTexture!

        render.drawText(10, 10, splashText)
        
        newX, newY = render.cursorPos player!
        
        mouseX = newX or mouseX
        mouseY = newY or localMouseY

        if inUse
            pathFinder\think mouseX, mouseY
        
        if pathFinder.nodeStacks
            for j = 0, #pathFinder.nodeStacks - 1
                nodeStack = pathFinder.nodeStacks[j + 1]
                if nodeStack
                    last = nodeStack[#nodeStack]
                    render.setColor Color 255 * (1 - j), 255 * j, 0
                    for i = 2, #nodeStack
                        a = nodeStack[i]
                        b = nodeStack[i - 1]
                        render.drawLine a.screenX, a.screenY, b.screenX, b.screenY

                    if nodeStack[1]
                        render.drawCirclePoly nodeStack[1].screenX, nodeStack[1].screenY, 6
            
        render.drawCirclePoly mouseX, mouseY, 2
