class IntersectionEntity
    new: (@parent, @attributes = {}) =>
    render: =>
    populatePathMap: (pathMap) =>
    checkSolution: =>
        true

class IntersectionEntity_Entrance extends IntersectionEntity
    type: "Entrance"
    new: (@parent, @attributes = {}) =>
        super @parent, @attributes

        parentBounds = @parent.bounds
        w = parentBounds.width * 1.5
        h = parentBounds.height * 1.5
        x = parentBounds.x + (parentBounds.width / 2) - w / 2
        y = parentBounds.y + (parentBounds.width / 2) - h / 2

        @bounds = Rect x, y, w, h

    render: =>
        if @bounds
            render.drawCirclePolySeveralTimesBecauseFuckGarrysMod @bounds.x + @bounds.width / 2, 
                @bounds.y + @bounds.width / 2, @bounds.width
            return true

class IntersectionEntity_Hexagon extends IntersectionEntity
    type: "Hexagon"
    buildPoly: (bounds) =>
        shrink = (math.min bounds.width, bounds.height) * 0.9

        poly = {}
        for i = -180, 180, 360 / 6
            table.insert poly, {
                x: bounds.x + bounds.width / 2 + (math.cos math.rad i) * shrink / 2
                y: bounds.y + bounds.height / 2 + (math.sin math.rad i) * shrink / 2
            }

        return poly
        
    checkSolution: (areaData) =>
        return @parent.solutionData.traced

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or COLORS[COLOR_BLACK]
            @poly = @poly or @buildPoly bounds
            render.setColor @colorCache
            for i = 1, 10
                render.drawPoly @poly

class IntersectionEntity_Exit extends IntersectionEntity
    type: "Exit"
    new: (@parent, @attributes = {}) =>
    getAngle: () =>
        angle = (not @parent\getLeft! and 0) or 
            (not @parent\getRight! and 180) or
            (not @parent\getTop! and 90) or
            (not @parent\getBottom! and 270)

        if not angle
            error "Invalid exit placement"

        return angle

    populatePathMap: (pathMap) =>
        angle = @getAngle!
        dir = switch angle
            when 0
                Vector -1, 0, 0
            when 90
                Vector 0, -1, 0
            when 180
                Vector 1, 0, 0
            when 270
                Vector 0, 1, 0

        w = @parent.bounds.width
        parentNode = @parent.pathMapNode
        node = {
            x: parentNode.x + (dir.x) * 0.25
            y: parentNode.y + (dir.y) * 0.25
            screenX: parentNode.screenX + (dir.x) * w
            screenY: parentNode.screenY + (dir.y) * w
            neighbors: { parentNode }
            intersection: @parent
            exit: true
        }
        parentNode.neighbors = parentNode.neighbors or {}
        
        table.insert parentNode.neighbors, node

        table.insert pathMap, node

    render: =>
        angle = @getAngle!

        matrix = Matrix!
        matrix\translate Vector @parent.bounds.x + @parent.bounds.width / 2, @parent.bounds.y + @parent.bounds.width / 2, 0
        matrix\rotate Angle 0, angle, 0
        render.pushMatrix matrix

        render.drawRect -@parent.bounds.width, -@parent.bounds.width / 2, @parent.bounds.width, @parent.bounds.width
        render.drawCirclePolySeveralTimesBecauseFuckGarrysMod -@parent.bounds.width, 0, @parent.bounds.width / 2
    
        render.popMatrix!

return {
    "Entrance": IntersectionEntity_Entrance
    "Exit": IntersectionEntity_Exit
    "Hexagon": IntersectionEntity_Hexagon
    "Dot": IntersectionEntity_Hexagon
}