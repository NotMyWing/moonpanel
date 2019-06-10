--@include moonpanel/core/sh_moonpanel.txt

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

render.drawCirclePolySeveralTimesBecauseFuckGarrysMod = (x, y, r, howManyTimes = 10) ->
    for i = 1, howManyTimes
        render.drawCirclePoly x, y, r

TileShared = require "moonpanel/core/sh_moonpanel.txt"

return class Tile extends TileShared
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

        if @backgroundNeedsRendering
            @backgroundNeedsRendering = false
            print "Re-rendering the background"
            render.selectRenderTarget "background"
            render.setColor @colors.background

            --matrix = Matrix!
            --matrix\translate Vector 8, 8
            --render.pushMatrix matrix
            render.drawRect 0, 0, @tileData.dimensions.screenWidth, @tileData.dimensions.screenHeight
            
            @renderBackground!

            --for k, v in pairs @pathMap
            --    render.setColor Color 255, 0, 0
            --    render.drawCirclePolySeveralTimesBecauseFuckGarrysMod v.screenX, v.screenY, v.clickable and 16 or 4
            --    for _k, _v in pairs v.neighbors
            --        render.drawLine v.screenX, v.screenY, _v.screenX, _v.screenY

            --render.popMatrix!
            render.selectRenderTarget nil

        render.clear!

        @lastPoweredUpdate or= timer.systime!
        poweredTimespan = math.min timer.systime! - @lastPoweredUpdate, 2
        if not @isPowered and poweredTimespan >= 2
            return

        render.setColor Color 255, 255, 255
        render.setRenderTargetTexture "background"
        render.drawTexturedRectFast 0, 0, 512, 512
        render.setTexture!

        if @isPowered and poweredTimespan <= 2
            render.setColor Color 0, 0, 0, 255 * (1 - (poweredTimespan / 2))
            render.drawRectFast 0, 0, @tileData.dimensions.screenWidth, @tileData.dimensions.screenHeight
        elseif not @isPowered
            render.setColor Color 0, 0, 0, 255 * (poweredTimespan / 2)
            render.drawRectFast 0, 0, @tileData.dimensions.screenWidth, @tileData.dimensions.screenHeight

    initNetHooks: () => 
        net.receive "ClearTileData", () ->
            @tileData = nil
            @lastPoweredUpdate = timer.systime!

        net.receive "UpdatePowered", () ->
            val = net.readInt 2
            @isPowered = val == 1 and true or false
            @lastPoweredUpdate = timer.systime!
            print "IsPowered = " .. tostring(@isPowered) .. "(" .. tostring(val) .. "):"

        net.receive "UpdateTileData", () ->
            print "Received data, reading..."
            length = net.readInt 32
            data = json.decode fastlz.decompress net.readData length

            @processTileData data

    processTileData: (tileData) =>
        @colors = tileData.colors
        
        -- Hackity hack
        for k, v in pairs @colors
            @colors[k] = Color v.r, v.g, v.b, v.a

        @penColor = @colors.traced
        @backgroundNeedsRendering = true

        @tileData = tileData
        @processElements!

    netUpdateCursorIOS: (isOnScreen) =>
        net.start "UpdateCursorIOS"
        net.writeUInt (isOnScreen) and 1 or 0, 2
        net.send!

    netUpdateCursorPos: (x, y) =>
        net.start "UpdateCursorPos"
        net.writeUInt x, 9
        net.writeUInt y, 9
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
                @netUpdateCursorPos newX, newY
                @cursorData.cursorPos.x = newX
                @cursorData.cursorPos.y = newY

    new: () =>
        render.createRenderTarget "background"
        hook.add "render", "", () ->
            @render!

        @cursorData = {}
        timer.create "updateCursorData", 0.05, 0, () ->
            @updateCursorData!

        @initNetHooks!
        super!