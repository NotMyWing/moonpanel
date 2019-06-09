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

    pointStacks = nil

    isSymmetry = true
    verticalSymmetry = true
    horizontalSymmetry = false
    rotationalSymmetry = false

    spacing = 40
    width = 8
    height = 8

    doSymmetryCheck = (a, b) ->
        rot = rotationalSymmetry and (a.x == ((width + 1) - b.x)) and (a.y == ((height + 1) - b.y))
        vertical = verticalSymmetry and (a.x == b.x) and (a.y == ((height + 1) - b.y))
        horizontal = horizontalSymmetry and (a.x == ((width + 1) - b.x)) and (a.y == b.y)

        return rot or vertical or horizontal

    offsetX = (512 - (spacing * (width - 1))) / 2
    offsetY = (512 - (spacing * (width - 1))) / 2
     
    for i = 1, width
        for j = 1, height 
            point = {}
            point.canConnectTo = {}
            point.x = i
            point.y = j
            point.screenX = offsetX + (i - 1) * spacing
            point.screenY = offsetY + (j - 1) * spacing

            table.insert points, point
        

    hasValue = (t, val) ->
        for k, v in pairs t
            if v == val
                return true
        return false

    hasPoint = (t, val) ->
        for k, pointStack in pairs pointStacks
            if hasValue pointStack, val
                return true
        return false

    for k, v in pairs points
        for _k, _v in pairs points
            dist = math.sqrt (_v.x - v.x)^2 + (_v.y - v.y)^2
            if (dist <= 1)
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
                nearest = nil
                for k, v in pairs points
                    dist = math.sqrt (mouseX - v.screenX)^2 + (mouseY - v.screenY)^2
                    if dist < spacing / 2
                        nearest = v
                        break

                if nearest
                    nearestSymmetrical = nil
                    if isSymmetry
                        for k, v in pairs points
                            if v == nearest
                                continue

                            if doSymmetryCheck nearest, v
                                nearestSymmetrical = v
                                break

                        if nearestSymmetrical
                            symmetryStack = { nearestSymmetrical }
                        else
                            return
                    else
                        symmetryStack = nil
                        
                    pointStacks = {}
                    table.insert pointStacks, { nearest }
                    if nearestSymmetrical
                        table.insert pointStacks, { nearestSymmetrical }
                else
                    return

            inUse = not inUse


    splashText ="Pathfinding test" .. if not isSymmetry
        ""
    elseif verticalSymmetry
        " - Vertical Symmetry"
    elseif horizontalSymmetry
        " - Horizontal Symmetry"
    elseif rotationalSymmetry
        " - Rotational Symmetry"

    hook.add "render", "", () ->
        if needsRedraw
            needsRedraw = false
            render.selectRenderTarget "background"
            
            render.setColor Color 24, 24, 24
            for k, a in pairs points
                for k, b in pairs a.canConnectTo 
                    render.drawLine a.screenX, a.screenY, b.screenX, b.screenY

            render.setColor Color 24, 24, 24
            for k, v in pairs points
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
        mouseY = newY or mouseY

        if inUse and pointStacks
            toInsert = {}
            toRemove = {}
            for _, pointStack in pairs pointStacks
                deltas = {}

                last = pointStack[#pointStack]

                mx = mouseX
                my = mouseY
                if pointStack == pointStacks[2]
                    if verticalSymmetry
                        my = 512 - my
                    if horizontalSymmetry
                        mx = 512 - mx
                    if rotationalSymmetry
                        mx = 512 - mx
                        my = 512 - my

                mx = (mx / 512)
                my = (my / 512)

                localMouseX = mx - last.x
                localMouseY = my - last.x
                mouseVector = Vector localMouseX, localMouseY, 0

                render.drawText(10, 30 + 15 * _, tostring mouseVector)

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
                            if isSymmetry
                                table.insert toRemove, #pointStack
                            else
                                table.remove pointStack, #pointStack
                            break
                        elseif not hasPoint pointStack, to
                            if isSymmetry 
                                table.insert toInsert, to
                            else
                                table.insert pointStack, to
                            break

                if maxDotVector
                    if maxPoint == pointStack[#pointStack - 1]
                        if isSymmetry
                            table.insert toRemove, #pointStack
                        else
                            table.remove pointStack, #pointStack

            if isSymmetry and #toInsert > 1 and toInsert[1] ~= toInsert[2]
                a = toInsert[1]
                b = toInsert[2]               

                if doSymmetryCheck a, b
                    table.insert pointStacks[1], toInsert[1]
                    table.insert pointStacks[2], toInsert[2]

            if isSymmetry and #toRemove > 1 and toRemove[1] == toRemove[2]
                a = pointStacks[1][toRemove[1]]
                b = pointStacks[2][toRemove[2]]                 

                if doSymmetryCheck a, b
                    table.remove pointStacks[1], toRemove[1]
                    table.remove pointStacks[2], toRemove[2]
        
        if pointStacks
            for j = 0, #pointStacks - 1
                pointStack = pointStacks[j + 1]
                if pointStack
                    last = pointStack[#pointStack]
                    render.setColor Color 255 * (1 - j), 255 * j, 0
                    for i = 2, #pointStack
                        a = pointStack[i]
                        b = pointStack[i - 1]
                        render.drawLine a.screenX, a.screenY, b.screenX, b.screenY

                    render.drawCirclePoly pointStack[1].screenX, pointStack[1].screenY, 6
            
        render.drawCirclePoly mouseX, mouseY, 2
