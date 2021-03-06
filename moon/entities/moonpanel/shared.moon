ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false
ENT.Moonpanel       = true

ENT.TickRate        = 20
ENT.ScreenSize      = 1024

ENT.RenderGroup     = RENDERGROUP_BOTH
ENT.Moonpanel       = true

import Rect from Moonpanel

ENT.GetTimerName = (subname) =>
    index = tostring @EntIndex!
    return "TheMP_Panel#{index}_#{subname}"

ENT.BuildPathMap = () =>
    @pathMap = {}
    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height
    barWidth = @calculatedDimensions.barWidth

    for j = 1, cellsH + 1
        translatedY = (j - 1) - (cellsH / 2)
        for i = 1, cellsW + 1
            intersection = @elements.intersections[j][i]
            if intersection.entity and intersection.entity.type == Moonpanel.EntityTypes.Invisible
                continue

            translatedX = (i - 1) - (cellsW / 2)

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
            hpath = @elements.hpaths[j][i]
            hpath\populatePathMap @pathMap

    for i = 1, cellsW + 1
        for j = 1, cellsH
            vpath = @elements.vpaths[j][i]
            vpath\populatePathMap @pathMap

    @pathMapConnections = {}
    seen = {}
    local isSeen
    for _, nodeA in pairs @pathMap
        isSeen = false
        for _, nodeB in pairs nodeA.neighbors
            if not isSeen
                seen[nodeA] = true
                isSeen = true

            if not seen[nodeB]
                @pathMapConnections[#@pathMapConnections + 1] = {
                    from: nodeA
                    to: nodeB
                }

    @pathMapDisconnectedNodes = {}
    for _, node in pairs @pathMap
        if not seen[node]
            @pathMapDisconnectedNodes[#@pathMapDisconnectedNodes + 1] = node

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

    @elements.cells = { entities: {} }
    @elements.hpaths = { entities: {} }
    @elements.vpaths = { entities: {} }
    @elements.intersections = { entities: {} }
    @elements.entities = {}

    for j = 1, cellsH + 1
        @elements.intersections[j] = {}
        if j <= cellsH + 1
            @elements.hpaths[j] = {}

        if j <= cellsH
            @elements.vpaths[j] = {}
            @elements.cells[j] = {}

        for i = 1, cellsW + 1
            if j <= cellsH and i <= cellsW
                cell = elementClasses.Cell @, i, j
                x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
                y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
                cell.bounds = Rect x, y, barLength, barLength

                @elements.cells[j][i] = cell

                if @tileData.Cells and @tileData.Cells[j] and @tileData.Cells[j][i]
                    entDef = @tileData.Cells[j][i]
                    if Moonpanel.Entities.Cell[entDef.Type]
                        cell.entity = Moonpanel.Entities.Cell[entDef.Type] cell, entDef.Attributes
                        cell.entity.type = entDef.Type

                        entities = @elements.cells.entities
                        entities[#entities + 1] = cell.entity
                        @elements.entities[#@elements.entities + 1] = cell.entity

            if j <= cellsH + 1 and i <= cellsW
                hpath = elementClasses.HPath @, i, j
                x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
                y = offsetV + (j - 1) * (barLength + barWidth)
                hpath.bounds = Rect x, y, barLength, barWidth

                @elements.hpaths[j][i] = hpath

                if @tileData.HPaths and @tileData.HPaths[j] and @tileData.HPaths[j][i]
                    entDef = @tileData.HPaths[j][i]
                    if Moonpanel.Entities.HPath[entDef.Type]
                        hpath.entity = Moonpanel.Entities.HPath[entDef.Type] hpath, entDef.Attributes
                        hpath.entity.type = entDef.Type
                        
                        entities = @elements.hpaths.entities
                        entities[#entities + 1] = hpath.entity
                        @elements.entities[#@elements.entities + 1] = hpath.entity

            if j <= cellsH and i <= cellsW + 1
                vpath = elementClasses.VPath @, i, j
                y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
                x = offsetH + (i - 1) * (barLength + barWidth)
                vpath.bounds = Rect x, y, barWidth, barLength

                @elements.vpaths[j][i] = vpath

                if @tileData.VPaths and @tileData.VPaths[j] and @tileData.VPaths[j][i]
                    entDef = @tileData.VPaths[j][i]
                    if Moonpanel.Entities.VPath[entDef.Type]
                        vpath.entity = Moonpanel.Entities.VPath[entDef.Type] vpath, entDef.Attributes
                        vpath.entity.type = entDef.Type

                        entities = @elements.vpaths.entities
                        entities[#entities + 1] = vpath.entity
                        @elements.entities[#@elements.entities + 1] = vpath.entity

            int = elementClasses.Intersection @, i, j
            x = offsetH + (i - 1) * (barLength + barWidth)
            y = offsetV + (j - 1) * (barLength + barWidth)
            int.bounds = Rect x, y, barWidth, barWidth

            @elements.intersections[j][i] = int

            if @tileData.Intersections and @tileData.Intersections[j] and @tileData.Intersections[j][i]
                entDef = @tileData.Intersections[j][i]
                if Moonpanel.Entities.Intersection[entDef.Type]
                    int.entity = Moonpanel.Entities.Intersection[entDef.Type] int, entDef.Attributes
                    int.entity.type = entDef.Type

                    entities = @elements.intersections.entities
                    entities[#entities + 1] = int.entity
                    @elements.entities[#@elements.entities + 1] = int.entity

    @BuildPathMap!

    pfData = {
        screenWidth: @ScreenSize
        screenHeight: @ScreenSize
        symmetry: @tileData.Symmetry.Type
        barLength: @calculatedDimensions.barLength
        barWidth: @calculatedDimensions.barWidth
    }

    @pathFinder = Moonpanel.PathFinder @pathMap, pfData, () ->, () ->

    if CLIENT
        @SetupDataClient data
    else
        @SetupDataServer data
        @SetNW2Bool "TheMP Errored", false
        @SetNW2Bool "TheMP Powered", true

    @isPowered = true

ENT.ApplyDeltas = (dx, dy) =>
    if IsValid(@) and @.pathFinder and (dx ~= 0 or dy ~= 0)
        dx = dx * @calculatedDimensions.barWidth * 0.035
        dy = dy * @calculatedDimensions.barWidth * 0.035

        local snapshotNodes
        local snapshotPotentialNodes

        -- Take a snapshot of node stacks and potential nodes
        snapshotNodes = {}
        snapshotPotentialNodes = {}
        for stackId, stack in ipairs @pathFinder.nodeStacks
            snapshotNodes[stackId] = #stack
            snapshotPotentialNodes[stackId] = @pathFinder.potentialNodes[stackId]

        updated = @pathFinder\applyDeltas dx, dy
        if CLIENT
            @rendertargets.trace.dirty = true

        if updated
            local activeUser
            if SERVER
                activeUser = @GetNW2Entity "ActiveUser"

            -- Compare snapshots
            local diff
            validDiff = true
            local newPotentialNodes
            local lowestDelta
            touchingExit = false

            for stackId, stack in ipairs @pathFinder.nodeStacks
                count = #stack
                potentialNode = @pathFinder.potentialNodes[stackId]

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
                        cursor = @pathFinder.cursors[stackId]

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
                    if SERVER
                        compressedDelta = math.floor lowestDelta * (2 ^ Moonpanel.TraceCursorPrecision)
                        Moonpanel\broadcastTraceCursor activeUser, @, lowestDelta
                    else
                        @UpdateTraceCursor lowestDelta

                    @__oldLowestDelta = lowestDelta

            if validDiff and diff and diff ~= 0
                -- If diff if positive, broadcast new points
                if diff > 0
                    local newPoints
                    if SERVER
                        newPoints = {}

                    for stackId, stack in ipairs @pathFinder.nodeStacks
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

                    if SERVER
                        Moonpanel\broadcastTracePush activeUser, @, newPoints

                -- otherwise broadcast pops
                else
                    pops = {}
                    for stackId, stack in ipairs @pathFinder.nodeStacks
                        if SERVER
                            table.insert pops, -diff
                        else
                            @TracePopNode stackId

                    if SERVER
                        Moonpanel\broadcastTracePop activeUser, @, pops

            if newPotentialNodes
                if SERVER
                    Moonpanel\broadcastTracePotential activeUser, @, newPotentialNodes
                else
                    for stackId, potentialNode in pairs newPotentialNodes
                        @TracePotentialNode stackId, potentialNode.screenX, potentialNode.screenY

            touchingExit = touchingExit == true
            if touchingExit ~= @__oldTouchingExit
                @__oldTouchingExit = touchingExit
                if SERVER
                    Moonpanel\broadcastTouchingExit activeUser, @, touchingExit
                else
                    @UpdateTouchingExit touchingExit
            

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