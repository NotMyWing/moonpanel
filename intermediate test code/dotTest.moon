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

    vecs = {
        {
            p2: {x: 256 + 64, y: 256 + 64}
            p1: {x: 256, y: 256}
        }
        {
            p2: {x: 256 + 64, y: 256 - 64}
            p1: {x: 256, y: 256}
        }
        {
            p2: {x: 256 - 64, y: 256 + 64}
            p1: {x: 256, y: 256}
        }
        {
            p2: {x: 256 - 64, y: 256 - 64}
            p1: {x: 256, y: 256}
        }
    }

    hook.add "render", "", () ->
        render.clear!

        mx, my = render.cursorPos player!

        render.drawCirclePoly mx, my, 2
        
        if mx and my
            for k, v in pairs vecs
                render.setColor Color 255, 255, 255
                render.drawCirclePoly v.p1.x, v.p1.y, 2
                render.drawCirclePoly v.p2.x, v.p2.y, 2
                render.drawLine v.p1.x, v.p1.y, v.p2.x, v.p2.y

                V = Vector v.p2.x - v.p1.x, v.p2.y - v.p1.y, 0
                unitV = V\getNormalized!

                locmx = mx - v.p1.x
                locmy = my - v.p1.y
                
                mV = Vector locmx, locmy, 0

                mDot = unitV\dot mV

                if mDot > 0
                    dotV = (unitV * mDot)
                    render.setColor Color 255, 0, 0
                    render.drawLine v.p1.x, v.p1.y, v.p1.x + dotV.x, v.p1.y + dotV.y

                    render.drawLine v.p1.x + dotV.x, v.p1.y + dotV.y, mx, my
