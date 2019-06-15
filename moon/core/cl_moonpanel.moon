--@include moonpanel/core/sh_moonpanel.txt

makeCirclePoly = (r) ->
    circlePoly = {}
    for i = -180, 180, 15
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

render.drawCirclePolySeveralTimesBecauseFuckGarrysMod = (x, y, r, howManyTimes = 3) ->
    for i = 1, howManyTimes
        render.drawCirclePoly x, y, r

render.thiccLine = (a, b, width) ->
    angle = math.deg math.atan2 (b.y - a.y), (b.x - a.x)
    dist = math.sqrt (b.y - a.y)^2 + (b.x - a.x)^2

    matrix = Matrix!
    matrix\translate Vector b.x, b.y
    matrix\rotate Angle 0, angle + 90, 0
    render.pushMatrix matrix

    render.drawRectFast -width / 2, 0, width, dist

    render.popMatrix!

TileShared = require "moonpanel/core/sh_moonpanel.txt"

MATERIAL_VIGNETTE = material.load "gmod/scope"

colorGradient = (perc, ...) ->
    if perc >= 1
        r, g, b = select (select '#', ...) - 2, (...)
        return r, g, b
    elseif perc <= 0
        r, g, b = (...)
        return r, g, b
    
    num = select('#', ...) / 3

    segment, relperc = math.modf perc* (num-1)
    r1, g1, b1, r2, g2, b2 = select (segment*3)+1, ...

    return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc

return class Tile extends TileShared
    pathFinderData: nil
    renderBackground: () =>
        screenWidth = @tileData.dimensions.screenWidth
        screenHeight = @tileData.dimensions.screenHeight

        vignetteStretch = 200
        render.setColor @tileData.colors.vignette
        render.setMaterial MATERIAL_VIGNETTE
        render.drawTexturedRect -vignetteStretch * 2, -vignetteStretch, 
            screenWidth + vignetteStretch * 4, screenHeight + vignetteStretch * 1.8
        render.setMaterial!

        width = @tileData.dimensions.width
        height = @tileData.dimensions.height

        for j = 1, height
            for i = 1, width
                cell = @elements.cells[i][j]
                if cell
                    cell\render!
                    if @grayOut.Cell and @grayOut.Cell[j] and @grayOut.Cell[j][i]
                        render.setColor Color 0, 0, 0, @fade
                        render.drawRect cell.bounds.x, cell.bounds.y, cell.bounds.width, cell.bounds.height

        for j = 1, height + 1
            for i = 1, width
                hpath = @elements.hpaths[i][j]
                if hpath
                    hpath\render!

        for j = 1, height
            for i = 1, width + 1
                vpath = @elements.vpaths[i][j]
                if vpath
                    vpath\render!

        for j = 1, height + 1
            for i = 1, width + 1
                intersection = @elements.intersections[i][j]
                if intersection
                    intersection\render!

    render: () =>
        if not @tileData and not @elements
            return

        @lastPoweredUpdate or= timer.systime!
        poweredTimespan = math.min timer.systime! - @lastPoweredUpdate, 1
        if not @isPowered and poweredTimespan >= 1
            return

        if @foregroundNeedsRendering
            @foregroundNeedsRendering = false
            
            if @backgroundNeedsRendering
                @backgroundNeedsRendering = false
                render.selectRenderTarget "background"
                render.setColor @colors.background

                render.drawRect 0, 0, @tileData.dimensions.screenWidth, @tileData.dimensions.screenHeight
                
                @renderBackground!

                --for k, v in pairs @pathMap
                --    render.setColor Color 255, 0, 0
                --    render.drawCirclePolySeveralTimesBecauseFuckGarrysMod v.screenX, v.screenY, v.clickable and 16 or 4
                --    for _k, _v in pairs v.neighbors
                --        render.drawLine v.screenX, v.screenY, _v.screenX, _v.screenY

                render.selectRenderTarget nil

            render.clear!
            render.selectRenderTarget "foreground"
            render.setColor Color 255, 255, 255
            render.setRenderTargetTexture "background"
            render.drawTexturedRect 0, 0, 1024, 1024
            render.setTexture!

            render.setColor @penColor
            if @pathFinderData
                barWidth = @tileData.dimensions.barWidth
                barLength = @tileData.dimensions.barLength
                symmVector = nil
                cursors = {}

                for stackId, stack in pairs @pathFinderData
                    for k, v in pairs stack
                        render.drawCirclePoly v.x, v.y, (k == 1) and barWidth * 1.5 or barWidth / 2

                        if k > 1
                            prev = stack[k - 1]
                            render.thiccLine prev, v, barWidth
                        
                        if @pathFinderCursors and 
                            k == #stack and @pathFinderCursors[stackId] and @pathFinderCursors[stackId][k]
                            
                            cur = @pathFinderCursors[stackId][k]

                            vec = (Vector cur.dx, cur.dy, 0)
                            table.insert cursors, {
                                vec: vec\getNormalized!
                                prev: v
                                length: vec\getLength!
                            }

                if #cursors > 0
                    minLength = nil
                    for k, v in pairs cursors
                        if (minLength or v.length + 1) > v.length
                            minLength = v.length

                    for k, v in pairs cursors
                        target = (v.vec * minLength) + (Vector v.prev.x, v.prev.y, 0)
                        render.thiccLine v.prev, target, barWidth
                        render.drawCirclePoly target.x, target.y, barWidth / 2                

            width = @tileData.dimensions.width
            height = @tileData.dimensions.height
            for j = 1, height
                for i = 1, width
                    cell = @elements.cells[i][j]
                    if cell and @redOut.Cell and @redOut.Cell[j] and @redOut.Cell[j][i]
                        render.setColor Color 160, 0, 0, math.abs(190 * (math.sin math.rad (@red)))
                        render.drawRectFast cell.bounds.x, cell.bounds.y, cell.bounds.width, cell.bounds.height
            render.selectRenderTarget nil

        render.setColor Color 255, 255, 255
        render.setRenderTargetTexture "foreground"
        render.drawTexturedRect 0, 0, 512, 512
        render.setTexture!

        if @isPowered and poweredTimespan <= 1
            render.setColor Color 0, 0, 0, 255 * (1 - poweredTimespan)
            render.drawRectFast 0, 0, @tileData.dimensions.screenWidth, @tileData.dimensions.screenHeight
        elseif not @isPowered
            render.setColor Color 0, 0, 0, 255 * poweredTimespan
            render.drawRectFast 0, 0, @tileData.dimensions.screenWidth, @tileData.dimensions.screenHeight

    netUpdatePoweredState: (state) =>
        oldIsPowered = @isPowered
        @isPowered = state
        
        if (oldIsPowered ~= @isPowered)
            @lastPoweredUpdate = timer.systime!

    initNetHooks: () => 
        net.receive "ClearTileData", () ->
            @tileData = nil
            @lastPoweredUpdate = timer.systime!

        net.receive "UpdatePowered", () ->
            state = net.readUInt 2
            @netUpdatePoweredState (state == 1 and true or false)

        net.receive "UpdateTileData", () ->
            @pathFinderCursors = {}

            state = net.readUInt 2
            @netUpdatePoweredState (state == 1 and true or false)
            length = net.readUInt 32
            data = json.decode fastlz.decompress net.readData length

            @processTileData data

        net.receive "PathFinderCursor", (len) ->
            @foregroundNeedsRendering = true
            stack = net.readUInt 8
            
            @pathFinderCursors = @pathFinderCursors or {}
            @pathFinderCursors[stack] = @pathFinderCursors[stack] or {}
            pointId = net.readUInt 8

            @pathFinderCursors[stack][pointId] or= {}
            @pathFinderCursors[stack][pointId].dx = net.readFloat!
            @pathFinderCursors[stack][pointId].dy = net.readFloat!

        net.receive "PathFinderData", (len) ->
            @foregroundNeedsRendering = true
            @pathFinderData = {}
            stackCount = net.readUInt 4

            for i = 1, stackCount
                pointCount = net.readUInt 10
                stack = {}
                for j = 1, pointCount
                    table.insert stack, {
                        x: net.readUInt 10
                        y: net.readUInt 10
                    }

                table.insert @pathFinderData, stack

        net.receive "PuzzleStart", () ->
            @penColor = Color @colors.traced[1], @colors.traced[2], @colors.traced[3]
            @pathFinderCursors = {}
            @grayOut = {}
            @redOut = {}
            @fade = 0
            @red = 0

            @backgroundNeedsRendering = true

            timer.remove "penFade"
            timer.remove "grayOut"

        net.receive "PuzzleEnd", (len) ->
            timer.remove "penFade"
            timer.remove "grayOut"
            success = (net.readUInt 2) == 1 and true or false
            @redOut = net.readTable!
            @grayOut = net.readTable!

            colors = @tileData.colors

            if @grayOut
                -- This is intentionally slow.
                -- Background renderer is quite expensive.
                @fade = 140
                @backgroundNeedsRendering = true
                @foregroundNeedsRendering = true
                        
            if success and not @redOut.errored
                @penColor[1] = 0
                @penColor[2] = 255
                @penColor[3] = 0
                @foregroundNeedsRendering = true

            elseif success and @redOut.errored
                @penColor[1] = 255
                @penColor[2] = 0
                @penColor[3] = 0

                @foregroundNeedsRendering = true

                fadePct = 1
                timer.create "penFade", 0.02, 100, () ->
                    r1, g1, b1 = 255, 0, 0
                    r2, g2, b2 = colors.untraced[1], colors.untraced[2], colors.untraced[3]

                    r, g, b = colorGradient fadePct, r2, g2, b2, r1, g1, b1

                    @penColor[1] = r
                    @penColor[2] = g
                    @penColor[3] = b

                    fadePct -= 0.01
                    @foregroundNeedsRendering = true
                    if fadePct <= 0
                        @pathFinderData = {}
                        @foregroundNeedsRendering = true

                        timer.remove "penFade"

                @red = 0
                timer.create "redOut", 0.05, (360/15) * 3, () ->
                    @red += 15
                    @foregroundNeedsRendering = true

            elseif not success
                @penColor[1] = colors.untraced[1]
                @penColor[2] = colors.untraced[2]
                @penColor[3] = colors.untraced[3]

                @foregroundNeedsRendering = true

                fadePct = 1
                timer.create "penFade", 0.01, 100, () ->
                    r1, g1, b1 = colors.traced[1], colors.traced[2], colors.traced[3]
                    r2, g2, b2 = colors.untraced[1], colors.untraced[2], colors.untraced[3]

                    r, g, b = colorGradient fadePct, r2, g2, b2, r1, g1, b1

                    @penColor[1] = r
                    @penColor[2] = g
                    @penColor[3] = b

                    @foregroundNeedsRendering = true
                    fadePct -= 0.025
                    if fadePct <= 0
                        @pathFinderData = {}
                        @foregroundNeedsRendering = true

                        timer.remove "penFade"

    processTileData: (tileData) =>
        timer.remove "penFade"
        timer.remove "grayOut"
        timer.remove "redOut"

        @colors = tileData.colors
        @penColor = Color @colors.traced[1], @colors.traced[2], @colors.traced[3]
        @grayOut = {}
        @redOut = {}
        @fade = 0
        @red = 0

        -- Hackity hack
        for k, v in pairs @colors
            @colors[k] = Color v.r, v.g, v.b, v.a

        @backgroundNeedsRendering = true

        @tileData = tileData
        @processElements!
        @foregroundNeedsRendering = true

    netUpdateCursorIOS: (isOnScreen) =>
        net.start "UpdateCursorIOS"
        net.writeUInt (isOnScreen) and 1 or 0, 2
        net.send!

    netUpdateCursorPos: (x, y) =>
        net.start "UpdateCursorPos"
        net.writeUInt x, 10
        net.writeUInt y, 10
        net.send nil, false

    updateCursorData: () =>
        oldIsOnScreen = @cursorData.isOnScreen
        @cursorData.cursorPos or= { x: 0, y: 0 }
        
        newX, newY = render.cursorPos player!
        if not newX or not newY
            @cursorData.isOnScreen = false
        else
            @cursorData.isOnScreen = true

        if @cursorData.isOnScreen ~= oldIsOnScreen
            @netUpdateCursorIOS @cursorData.isOnScreen 

        if @cursorData.isOnScreen
            if newX ~= @cursorData.cursorPos.x or newY ~= @cursorData.cursorPos.y
                @netUpdateCursorPos newX * 2, newY * 2
                @cursorData.cursorPos.x = newX * 2
                @cursorData.cursorPos.y = newY * 2

    new: () =>
        render.createRenderTarget "foreground"
        render.createRenderTarget "background"
        hook.add "render", "", () ->
            @render!

        @cursorData = {}
        timer.create "updateCursorData", 0.05, 0, () ->
            @updateCursorData!

        @initNetHooks!
        super!

        net.start "FetchData"
        net.send!