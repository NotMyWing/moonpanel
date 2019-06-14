if CLIENT
    render.createRenderTarget "1"
    render.createRenderTarget "2"

    prefabs = {}

    makeQuarter = (r) ->
        poly = {}
        table.insert poly, {
            x: 0
            y: 0
        }
        for i = 0, 90, 10
            table.insert poly, {
                x: r * math.cos math.rad i,
                y: r * math.sin math.rad i
            }
            
        return poly

    makeQuarter = (r) ->
        poly = {}
        table.insert poly, {
            x: 0
            y: 0
        }
        for i = 0, 90, 10
            table.insert poly, {
                x: r * math.cos math.rad i,
                y: r * math.sin math.rad i
            }
            
        return poly

    prefabs.quarter = makeQuarter 25

    hook.add "render", "", () ->
        render.setColor Color 255, 255, 255, 255

        render.drawPoly prefabs.quarter


        