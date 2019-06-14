class CellEntity
    new: (@parent, @attributes = {}) =>
    checkSolution: (@areaData) =>
        return true

    render: =>

class CellEntity_Color extends CellEntity
    type: "Color"
    checkSolution: (@areaData) =>
        for k, v in pairs @parent.solutionData.area
            if v.type == "Cell" and v.entity and v.entity.attributes.color ~= @attributes.color and
                not v.entity.attributes.disabled
                
                return false
        return true

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or COLORS[@attributes.color]
            render.setColor @colorCache
            shrink = bounds.width * 0.6
            render.drawRoundedBox 8, bounds.x + shrink / 2, bounds.y + shrink / 2, bounds.width - shrink, bounds.height - shrink

class CellEntity_Sun extends CellEntity
    type: "Sun"
    checkSolution: (@areaData) =>
        sum = 0
        for k, v in pairs @parent.solutionData.area
            if v.type == "Cell" and v.entity and
                v.entity.attributes.color == @attributes.color and not v.entity.attributes.disabled

                sum +=1
                if sum > 2
                    return false

        return sum == 2

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
            @colorCache = @colorCache or COLORS[@attributes.color]
            @sunPoly = @sunPoly or @buildPoly bounds
            render.setColor @colorCache
            shrink = bounds.width * 0.7
            render.drawRect bounds.x + shrink / 2, bounds.y + shrink / 2, bounds.width - shrink, bounds.height - shrink
            for i = 1, 10
                render.drawPoly @sunPoly

class CellEntity_Y extends CellEntity
    type: "Y"
    render: =>
        bounds = @parent.bounds
        if bounds
            render.setColor COLORS[COLOR_WHITE]
            shrink = bounds.width * 0.25

            width = shrink * 0.45
            
            matrix = Matrix!
            matrix\translate Vector bounds.x + bounds.width / 2, bounds.y + bounds.height / 2, 0
            for i = 1, 3
                render.pushMatrix matrix
                render.drawRect -width / 2, -shrink, width, shrink
                render.popMatrix!
                if i ~= 3
                    matrix\rotate Angle 0, 120, 0

class CellEntity_Polyomino extends CellEntity
    type: "Polyomino"
    new: (@parent, @attributes = {}) =>
        @attributes.color = COLOR_YELLOW

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or COLORS[COLOR_YELLOW]

            render.setColor @colorCache

            @polyheight = #@attributes.shape
            @polywidth = @polywidth or nil
            if not @polywidth
                max = 0
                for k, row in pairs @attributes.shape
                    max = math.max #row
                @polywidth = max

            maxDim = math.max @polyheight, @polywidth
            shrink = bounds.width * 0.7

            if not @attributes.fixed
                shrink *= 0.7

            squareWidth = math.min shrink / maxDim, bounds.width * 0.2
            spacing = shrink * 0.1

            offsetX = (bounds.width  / 2) - ((squareWidth * @polywidth ) + ((@polywidth  - 1) * spacing)) / 2
            offsetY = (bounds.height / 2) - ((squareWidth * @polyheight) + ((@polyheight - 1) * spacing)) / 2

            v = Vector bounds.x + bounds.width / 2, bounds.y + bounds.height / 2, 0

            if not @attributes.fixed
                matrix = Matrix!
                matrix\translate v
                matrix\rotate Angle 0, -15, 0
                matrix\translate -v

                render.pushMatrix matrix

            for j = 1, @polyheight
                for i = 1, @polywidth
                    if @attributes.shape[j][i] == 1
                        x = offsetX + bounds.x + (i - 1) * spacing + (i - 1) * squareWidth 
                        y = offsetY + bounds.y + (j - 1) * spacing + (j - 1) * squareWidth 
                        render.drawRoundedBox 4, x, y, squareWidth, squareWidth
            
            if not @attributes.fixed
                render.popMatrix!

class CellEntity_BluePolyomino extends CellEntity
    type: "Blue Polyomino"
    new: (@parent, @attributes = {}) =>
        @attributes.color = COLOR_BLUE

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or COLORS[COLOR_BLUE]

            render.setColor @colorCache

            @polyheight = #@attributes.shape
            @polywidth = @polywidth or nil
            if not @polywidth
                max = 0
                for k, row in pairs @attributes.shape
                    max = math.max #row
                @polywidth = max

            maxDim = math.max @polyheight, @polywidth
            shrink = bounds.width * 0.7

            if not @attributes.fixed
                shrink *= 0.7

            squareWidth = math.min shrink / maxDim, bounds.width * 0.2
            spacing = shrink * 0.1

            offsetX = (bounds.width  / 2) - ((squareWidth * @polywidth ) + ((@polywidth  - 1) * spacing)) / 2
            offsetY = (bounds.height / 2) - ((squareWidth * @polyheight) + ((@polyheight - 1) * spacing)) / 2

            v = Vector bounds.x + bounds.width / 2, bounds.y + bounds.height / 2, 0

            if not @attributes.fixed
                matrix = Matrix!
                matrix\translate v
                matrix\rotate Angle 0, -15, 0
                matrix\translate -v

                render.pushMatrix matrix

            for j = 1, @polyheight
                for i = 1, @polywidth
                    if @attributes.shape[j][i] == 1
                        x = offsetX + bounds.x + (i - 1) * spacing + (i - 1) * squareWidth 
                        y = offsetY + bounds.y + (j - 1) * spacing + (j - 1) * squareWidth

                        cutout = squareWidth * 0.15
                        
                        render.drawRoundedBoxEx 4, x, y, squareWidth, cutout, true, true, false, false
                        render.drawRoundedBoxEx 4, x, y + squareWidth - cutout, squareWidth, cutout, false, false, true, true
                        render.drawRect x, y + cutout * 0.5, cutout, squareWidth - cutout * 1.5
                        render.drawRect x + squareWidth - cutout, y + cutout * 0.5, cutout, squareWidth - cutout * 1.5
                        
            
            if not @attributes.fixed
                render.popMatrix!

class CellEntity_Triangle extends CellEntity
    type: "Triangle"
    buildPoly: (bounds) =>
        w = (bounds.width * 0.2) / 2
        poly = {
            { x: 0, y: -w }
            { x: w, y: w }
            { x: -w, y: w }
        }

        return poly
        
    checkSolution: (@areaData) =>
        sum = (@parent\getLeft!.solutionData.traced and 1 or 0) + 
            (@parent\getRight!.solutionData.traced and 1 or 0) + 
            (@parent\getTop!.solutionData.traced and 1 or 0) + 
            (@parent\getBottom!.solutionData.traced and 1 or 0)

        return sum == @attributes.count

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or COLORS[COLOR_ORANGE]
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
                for j = 1, 10
                    render.drawPoly @trianglePoly

            render.popMatrix!

return {
    "Color": CellEntity_Color
    "Polyomino": CellEntity_Polyomino
    "Blue Polyomino": CellEntity_BluePolyomino
    "Sun": CellEntity_Sun
    "Y": CellEntity_Y
    "Triangle": CellEntity_Triangle
}