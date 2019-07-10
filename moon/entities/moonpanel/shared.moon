ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false

ENT.TickRate        = 20
ENT.ScreenSize      = 1024


hasValue = (t, val) ->
    for k, v in pairs t
        if v == val
            return true
    return false

class PathFinder
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

        for _, nodeStack in pairs @nodeStacks
            nodeCursor = @cursors[_]
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

                otherStack = @nodeStacks[1 - (_ - 1) + 1]
                if @symmetry and otherStack and to == otherStack[#otherStack]
                    vecLength /= 2
                    vecLength -= @barWidth / 2

                elseif to ~= nodeStack[#nodeStack - 1]
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
                    
                    mDot = math.min mDot, vecLength

                    dotVector = (unitVector * mDot)
                    if mDot >= maxMDot
                        maxVecLength = vecLength
                        maxMDot = mDot
                        maxDotVector = dotVector
                        maxNode = to

                if not to.lowPriority and mDot >= vecLength
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

            if maxNode and not maxNode.lowPriority and maxNode == nodeStack[#nodeStack - 1]
                if @symmetry
                    table.insert toRemove, #nodeStack
                else
                    table.remove nodeStack, #nodeStack

        if @symmetry and #toInsert > 1 and toInsert[1] ~= toInsert[2]
            a = toInsert[1]
            b = toInsert[2]               

            if not (a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
                b == @nodeStacks[2][1] or a == @nodeStacks[2][1]) and @checkSymmetry a, b

                table.insert @nodeStacks[1], toInsert[1]
                table.insert @nodeStacks[2], toInsert[2]

        if @symmetry and #toRemove > 1 and toRemove[1] == toRemove[2]
            a = @nodeStacks[1][toRemove[1]]
            b = @nodeStacks[2][toRemove[2]]                 

            if not (a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
                b == @nodeStacks[2][1] or a == @nodeStacks[2][1]) and @checkSymmetry a, b

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

import Rect from Moonpanel

ENT.BuildPathMap = () =>
    @pathMap = {}
    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height
    barWidth = @calculatedDimensions.barWidth

    for i = 1, cellsW + 1
        translatedX = (i - 1) - (cellsW / 2)
        for j = 1, cellsH + 1
            translatedY = (j - 1) - (cellsH / 2)
            intersection = @elements.intersections[i][j]
            
            clickable = (intersection.entity and intersection.entity.type == Moonpanel.EntityTypes.Start) and true or false
            node = {
                x: translatedX
                y: translatedY
                :intersection
                :clickable
                radius: (clickable and barWidth or (barWidth * 2.5)) / 2
                screenX: intersection.bounds.x + intersection.bounds.width / 2
                screenY: intersection.bounds.y + intersection.bounds.height / 2
                neighbors: {}
            }

            table.insert @pathMap, node

            intersection.pathMapNode = node
            intersection\populatePathMap @pathMap

    for i = 1, cellsW
        for j = 1, cellsH + 1
            hpath = @elements.hpaths[i][j]
            hpath\populatePathMap @pathMap

    for i = 1, cellsW + 1
        for j = 1, cellsH
            vpath = @elements.vpaths[i][j]
            vpath\populatePathMap @pathMap

ENT.SetupData = (data) =>
    elementClasses = Moonpanel.Elements
    if CLIENT
        @tileData = data.tileData
    else
        @tileData = data

    if not elementClasses
        return

    @calculatedDimensions = Moonpanel\calculateDimensionsShared {
        screenW: @ScreenSize
        screenH: @ScreenSize
        cellsW: @tileData.Tile.Width
        cellsH: @tileData.Tile.Height
        innerScreenRatio: @tileData.Dimensions.InnerScreenRatio
        maxBarLength: @tileData.Dimensions.MaxBarLength
        barWidth: @tileData.Dimensions.BarWidth
    }

    barWidth = @calculatedDimensions.barWidth
    barLength = @calculatedDimensions.barLength

    offsetH = (@ScreenSize / 2) - (@calculatedDimensions.innerWidth / 2)
    offsetV = (@ScreenSize / 2) - (@calculatedDimensions.innerHeight / 2)

    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height

    @elements = {}

    @elements.cells = {}
    for i = 1, cellsW
        @elements.cells[i] = {}
        for j = 1, cellsH
            cell = elementClasses.Cell @, i, j
            x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
            y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
            cell.bounds = Rect x, y, barLength, barLength

            @elements.cells[i][j] = cell

            if @tileData.Cells and @tileData.Cells[j] and @tileData.Cells[j][i]
                entDef = @tileData.Cells[j][i]
                if Moonpanel.Entities.Cell[entDef.Type]
                    cell.entity = Moonpanel.Entities.Cell[entDef.Type] cell, entDef.Attributes
                    cell.entity.type = entDef.Type

    @elements.hpaths = {}
    for i = 1, cellsW
        @elements.hpaths[i] = {}
        for j = 1, cellsH + 1
            hpath = elementClasses.HPath @, i, j
            x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
            y = offsetV + (j - 1) * (barLength + barWidth)
            hpath.bounds = Rect x, y, barLength, barWidth

            @elements.hpaths[i][j] = hpath

            if @tileData.HPaths and @tileData.HPaths[j] and @tileData.HPaths[j][i]
                entDef = @tileData.HPaths[j][i]
                if Moonpanel.Entities.HPath[entDef.Type]
                    hpath.entity = Moonpanel.Entities.HPath[entDef.Type] hpath, entDef.Attributes
                    hpath.entity.type = entDef.Type

    @elements.vpaths = {}
    for i = 1, cellsW + 1
        @elements.vpaths[i] = {}
        for j = 1, cellsH
            vpath = elementClasses.VPath @, i, j
            y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
            x = offsetH + (i - 1) * (barLength + barWidth)
            vpath.bounds = Rect x, y, barWidth, barLength

            @elements.vpaths[i][j] = vpath

            if @tileData.VPaths and @tileData.VPaths[j] and @tileData.VPaths[j][i]
                entDef = @tileData.VPaths[j][i]
                if Moonpanel.Entities.VPath[entDef.Type]
                    vpath.entity = Moonpanel.Entities.VPath[entDef.Type] vpath, entDef.Attributes
                    vpath.entity.type = entDef.Type

    @elements.intersections = {}
    for i = 1, cellsW + 1
        @elements.intersections[i] = {}
        for j = 1, cellsH + 1
            int = elementClasses.Intersection @, i, j
            x = offsetH + (i - 1) * (barLength + barWidth)
            y = offsetV + (j - 1) * (barLength + barWidth)
            int.bounds = Rect x, y, barWidth, barWidth

            @elements.intersections[i][j] = int

            if @tileData.Intersections and @tileData.Intersections[j] and @tileData.Intersections[j][i]
                entDef = @tileData.Intersections[j][i]
                if Moonpanel.Entities.Intersection[entDef.Type]
                    int.entity = Moonpanel.Entities.Intersection[entDef.Type] int, entDef.Attributes
                    int.entity.type = entDef.Type

    @BuildPathMap!

    pfData = {
        screenWidth: @ScreenSize
        screenHeight: @ScreenSize
        symmetry: @tileData.Tile.Symmetry
        barLength: @calculatedDimensions.barLength
        barWidth: @calculatedDimensions.barWidth
    }

    @pathFinder = PathFinder @pathMap, pfData, () ->, () ->

    if CLIENT
        @SetupDataClient data

    @isPowered = true

ENT.ApplyDeltas = (x, y) =>
    if IsValid(@) and @.pathFinder and (x ~= 0 or y ~= 0)
        if CLIENT
            @shouldRepaintTrace = true
        else
            activeUser = @GetNW2Entity "ActiveUser"
            Moonpanel\broadcastDeltas activeUser, @, x, y

        @pathFinder\applyDeltas x, y

ENT.Think = () =>
    if SERVER
        @ServerThink!
    else
        @ClientThink!

    if CurTime! >= (@__nextTRThink or 0)
        @__nextTRThink = CurTime! + (1 / @TickRate)

        if SERVER
            @ServerTickrateThink!
        else
            @ClientTickrateThink!