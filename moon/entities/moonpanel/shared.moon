ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false

ENT.TickRate        = 20
ENT.ScreenSize      = 512

import Rect from Moonpanel

ENT.SetupData = (@tileData) =>
    elementClasses = Moonpanel.Elements

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

    @elements.hpaths = {}
    for i = 1, cellsW
        @elements.hpaths[i] = {}
        for j = 1, cellsH + 1
            hpath = elementClasses.HPath @, i, j
            x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
            y = offsetV + (j - 1) * (barLength + barWidth)
            hpath.bounds = Rect x, y, barLength, barWidth

            @elements.hpaths[i][j] = hpath

    @elements.vpaths = {}
    for i = 1, cellsW + 1
        @elements.vpaths[i] = {}
        for j = 1, cellsH
            vpath = elementClasses.VPath @, i, j
            y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
            x = offsetH + (i - 1) * (barLength + barWidth)
            vpath.bounds = Rect x, y, barWidth, barLength

            @elements.vpaths[i][j] = vpath

    @elements.intersections = {}
    for i = 1, cellsW + 1
        @elements.intersections[i] = {}
        for j = 1, cellsH + 1
            int = elementClasses.Intersection @, i, j
            x = offsetH + (i - 1) * (barLength + barWidth)
            y = offsetV + (j - 1) * (barLength + barWidth)
            int.bounds = Rect x, y, barWidth, barWidth

            @elements.intersections[i][j] = int

    if CLIENT
        @SetupDataClient!

ENT.ApplyDeltas = (x, y) =>

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