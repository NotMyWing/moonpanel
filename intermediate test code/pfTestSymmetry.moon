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

    pointStack = nil
    symmetryStack = nil

    isSymmetry = true
    verticalSymmetry = true
    horizontalSymmetry = false
    rotationalSymmetry = false

    spacing = 40
    width = 9
    height = 9

    offsetX = (512 - (spacing * (width - 1))) / 2
    offsetY = (512 - (spacing * (width - 1))) / 2
    
    for i = 1, 9
        for j = 1, 9
            point = {}
            point.canConnectTo = {}
            point.x = offsetX + (i - 1) * spacing
            point.y = offsetY + (j - 1) * spacing

            table.insert points, point
            
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

    mouseX = nil
    mouseY = nil

    needsRedraw = true
    render.createRenderTarget "background"

    inUse = false
    
    hook.add "inputPressed", "", (key) ->
        if key == 15 and mouseX and mouseY
            successful = true
            if not inUse
                successful = false
                nearest = nil
                for k, v in pairs points
                    dist = math.sqrt (mouseX - v.x)^2 + (mouseY - v.y)^2
                    if dist < 20
                        nearest = v
                        break

                if nearest
                    if isSymmetry
                        nearestSymmetrical = nil
                        for k, v in pairs points
                            if v == nearest
                                continue

                            rot = rotationalSymmetry and (v.x == (512 - nearest.x)) and (v.y == (512 - nearest.y))
                            vertical = verticalSymmetry and (v.x == nearest.x) and (v.y == (512 - nearest.y))
                            horizontal = horizontalSymmetry and (v.x == (512 - nearest.x)) and (v.y == nearest.y)

                            if rot or vertical or horizontal
                                nearestSymmetrical = v
                                break

                        if nearestSymmetrical
                            symmetryStack = { nearestSymmetrical }
                        else
                            return
                    else
                        symmetryStack = nil
                        
                    pointStack = { nearest }
                    successful = true

            if successful
                inUse = not inUse


    hook.add "render", "", () ->
        if needsRedraw
            needsRedraw = false
            render.selectRenderTarget "background"
            
            render.setColor Color 24, 24, 24
            for k, a in pairs points
                for k, b in pairs a.canConnectTo 
                    render.drawLine a.x, a.y, b.x, b.y

            render.setColor Color 24, 24, 24
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

        if inUse and pointStack
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

                    if mDot > 0
                        dotVector = (unitVector * mDot)
                        toMouseVec = mouseVector - dotVector
                        
                        if mDot > vecLength / 2
                            mDot = mDot + toMouseVec\getLength!
                        else
                            mDot = mDot - toMouseVec\getLength!

                        mDot = math.min mDot, vecLength
                        dotVector = (unitVector * mDot)
                        if mDot > maxMDot
                            maxMDot = mDot
                            maxDotVector = dotVector
                            maxPoint = to

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
                break

        if pointStack
            last = pointStack[#pointStack]
            render.setColor Color 0, 255, 0
            for i = 2, #pointStack
                a = pointStack[i]
                b = pointStack[i - 1]
                render.drawLine a.x, a.y, b.x, b.y

            render.drawCirclePoly pointStack[1].x, pointStack[1].y, 6

        if symmetryStack
            last = pointStack[#symmetryStack]
            render.setColor Color 0, 0, 255
            for i = 2, #symmetryStack
                a = symmetryStack[i]
                b = symmetryStack[i - 1]
                render.drawLine a.x, a.y, b.x, b.y

            render.drawCirclePoly symmetryStack[1].x, symmetryStack[1].y, 6
            
        render.drawCirclePoly mouseX, mouseY, 2
