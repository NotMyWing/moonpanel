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

    points = {
        
    }

    pointStack = {}

    spacing = 40
    width = 9
    height = 9

    offsetX = (512 - (spacing * (width - 1))) / 2
    offsetY = (512 - (spacing * (width - 1))) / 2
    
    for angle = -180, 180, 10
        for r = 100, 240, 30
            point = {}
            point.canConnectTo = {}
            point.x = 256 + (math.cos math.deg angle) * r
            point.y = 256 + (math.sin math.deg angle) * r

            table.insert points, point

    table.insert pointStack, points[1]
    hasValue = (t, val) ->
        for k, v in pairs t
            if v == val
                return true
        return false

    for k, v in pairs points
        for _k, _v in pairs points
            dist = math.sqrt (_v.x - v.x)^2 + (_v.y - v.y)^2
            if (dist <= spacing)
                if not (hasValue v.canConnectTo, _v) and not (hasValue _v.canConnectTo, v)
                    table.insert v.canConnectTo, _v
                    table.insert _v.canConnectTo, v

    mouseX = 256
    mouseY = 256

    needsRedraw = true
    render.createRenderTarget "background"
    hook.add "render", "", () ->
        if needsRedraw
            needsRedraw = false
            render.selectRenderTarget "background"
            
            render.setColor Color 16, 16, 16
            for k, a in pairs points
                for k, b in pairs a.canConnectTo 
                    render.drawLine a.x, a.y, b.x, b.y

            render.setColor Color 60, 60, 60
            for k, v in pairs points
                render.drawCirclePoly v.x, v.y, 6
            render.selectRenderTarget nil

        render.clear!
        render.setColor Color 255, 255, 255
        render.setRenderTargetTexture "background"
        render.drawTexturedRect 0, 0, 1024, 1024
        render.setTexture!

        render.drawText(10, 10, "Pathfinding test")
        
        newX, newY = render.cursorPos player!
        
        mouseX = newX or mouseX
        mouseY = newY or mouseY

        while true do
            deltas = {}

            last = pointStack[#pointStack]
            localMouseX = mouseX - last.x
            localMouseY = mouseY - last.y
            mouseVector = Vector localMouseX, localMouseY, 0

            maxMDot = 0
            maxDotVector = nil
            maxPoint = nil
            for k, to in pairs last.canConnectTo

                vec = Vector to.x - last.x, to.y - last.y, 0
                vecLength = vec\getLength! 
                unitVector = vec\getNormalized!

                mDot = unitVector\dot mouseVector
                mDot = math.min mDot, vecLength

                if mDot > 0
                    dotVector = (unitVector * mDot)
                    toMouseVec = mouseVector - dotVector
                    if mDot > maxMDot
                        maxMDot = mDot
                        maxDotVector = dotVector
                        maxPoint = to
                    
                    if mDot > vecLength
                        mDot = mDot + toMouseVec\getLength!
                    else
                        mDot = mDot - toMouseVec\getLength!

                if mDot >= vecLength
                    if to == pointStack[#pointStack - 1]
                        table.remove pointStack, #pointStack
                        break
                    elseif not hasValue pointStack, to
                        table.insert pointStack, to
                        break

            if maxDotVector
                if maxPoint == pointStack[#pointStack - 1]
                    table.remove pointStack, #pointStack
                else
                    render.setColor Color 0, 255, 0
                    render.drawLine last.x, last.y, last.x + maxDotVector.x, last.y + maxDotVector.y
            break

        last = pointStack[#pointStack]

        render.setColor Color 0, 255, 0
        for i = 2, #pointStack
            a = pointStack[i]
            b = pointStack[i - 1]
            render.drawLine a.x, a.y, b.x, b.y

        for k, point in pairs pointStack
            if point ~= last
                render.drawCirclePoly point.x, point.y, 6

        render.setColor Color 255, 0, 0
        
        render.drawCirclePoly last.x, last.y, 6

        render.drawCirclePoly mouseX, mouseY, 2

