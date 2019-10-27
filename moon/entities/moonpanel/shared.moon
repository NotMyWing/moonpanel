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
        symmetry: @tileData.Tile.Symmetry
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
        dx *= @calculatedDimensions.barWidth * 0.035
        dy *= @calculatedDimensions.barWidth * 0.035

        if CLIENT
            @shouldRepaintTrace = true
            @__calculatedLineLength = nil

        else
            activeUser = @GetNW2Entity "ActiveUser"
            Moonpanel\broadcastDeltas activeUser, @, dx, dy

        @pathFinder\applyDeltas dx, dy

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