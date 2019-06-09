class CellObject
    new: (@parent, @attributes = {}) =>
    render: =>

class CellObject_Color extends CellObject
    type: "Color"
    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or Color @attributes.r, @attributes.g, @attributes.b
            render.setColor @colorCache
            shrink = bounds.width * 0.6
            render.drawRoundedBox 8, bounds.x + shrink / 2, bounds.y + shrink / 2, bounds.width - shrink, bounds.height - shrink

class CellObject_Sun extends CellObject
    type: "Sun"
    buildPoly: (bounds) =>
        shrink = bounds.width * 0.7
        newBounds = Rect bounds.x + shrink / 2, bounds.y + shrink / 2, bounds.width - shrink, bounds.height - shrink     

        halfW = newBounds.width / 2
        quarterW = newBounds.width / 4
        poly = {
            { x: newBounds.x - quarterW, y: newBounds.y + halfW },
            { x: newBounds.x + halfW, y: newBounds.y - quarterW },
            { x: newBounds.x + newBounds.width + quarterW, y: newBounds.y + halfW },
            { x: newBounds.x + halfW, y: newBounds.y + newBounds.width + quarterW },
        }
        return poly
        
    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or Color @attributes.r, @attributes.g, @attributes.b
            @sunPoly = @sunPoly or @buildPoly bounds
            render.setColor @colorCache
            shrink = bounds.width * 0.7
            render.drawRect bounds.x + shrink / 2, bounds.y + shrink / 2, bounds.width - shrink, bounds.height - shrink
            render.drawPoly @sunPoly

class CellObject_Triangle extends CellObject
    type: "Triangle"
    buildPoly: (bounds) =>
        w = (bounds.width * 0.2) / 2
        poly = {
            { x: 0, y: -w }
            { x: w, y: w }
            { x: -w, y: w }
        }

        return poly
        
    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or Color 250, 190, 0
            @trianglePoly = @trianglePoly or @buildPoly bounds
            render.setColor @colorCache
            shrink = bounds.width * 0.8

            triangleWidth = bounds.width * 0.2
            spacing = bounds.width * 0.05
            offset = if @attributes.count == 1
                0
            else
                (((@attributes.count - 1) * triangleWidth) + ((@attributes.count - 1) * spacing)) / 2

            matrix = Matrix!
            matrix\translate Vector bounds.x + (bounds.width / 2) - offset, bounds.y + bounds.height / 2, 0
                
            for i = 1, @attributes.count do
                if i > 1
                    render.popMatrix!
                    matrix\translate Vector triangleWidth + spacing, 0, 0

                render.pushMatrix matrix
                render.drawPoly @trianglePoly

            render.popMatrix!

return {
    "Color": CellObject_Color
    "Sun": CellObject_Sun
    "Triangle": CellObject_Triangle
}