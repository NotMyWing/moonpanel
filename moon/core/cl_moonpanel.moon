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

render.drawCirclePolySeveralTimesBecauseFuckGarrysMod = (x, y, r, howManyTimes = 10) ->
    for i = 1, howManyTimes
        render.drawCirclePoly x, y, r

TileShared = require "moonpanel/core/sh_moonpanel.txt"

return class Tile extends TileShared
    pathFinderData: nil
    renderBackground: () =>
        width = @tileData.dimensions.width
        height = @tileData.dimensions.height

        for j = 1, height
            for i = 1, width
                cell = @elements.cells[i][j]
                if cell
                    cell\render!

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

            if @pathFinderData
                barWidth = @tileData.dimensions.barWidth
                for k, stack in pairs @pathFinderData
                    for k, v in pairs stack
                        render.drawCirclePoly v.sx, v.sy, (k == 1) and barWidth * 1.5 or barWidth / 2

                        if k > 1
                            prev = stack[k - 1]
                            angle = math.deg math.atan2 (prev.sy - v.sy), (prev.sx - v.sx)
                            dist = math.sqrt (v.sy - prev.sy)^2 + (v.sx - prev.sx)^2

                            matrix = Matrix!
                            matrix\translate Vector prev.sx, prev.sy
                            matrix\rotate Angle 0, angle + 90, 0
                            render.pushMatrix matrix

                            render.drawRectFast -barWidth / 2, 0, barWidth, dist
                        
                            render.popMatrix!
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
            state = net.readUInt 2
            @netUpdatePoweredState (state == 1 and true or false)
            length = net.readUInt 32
            data = json.decode fastlz.decompress net.readData length

            @processTileData data

        net.receive "PathFinderData", (len) ->
            @foregroundNeedsRendering = true
            @pathFinderData = {}
            stackCount = net.readUInt 4

            for i = 1, stackCount
                pointCount = net.readUInt 10
                stack = {}
                for j = 1, pointCount
                    table.insert stack, {
                        sx: net.readUInt 10
                        sy: net.readUInt 10
                    }

                table.insert @pathFinderData, stack

        net.receive "PuzzleStart", () ->

        net.receive "PuzzleEnd", () ->
            -- length = net.readUInt 32
            -- data = json.decode fastlz.decompress net.readData length

    processTileData: (tileData) =>
        @colors = tileData.colors
        
        -- Hackity hack
        for k, v in pairs @colors
            @colors[k] = Color v.r, v.g, v.b, v.a

        @penColor = @colors.traced
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