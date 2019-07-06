class CellEntity
    new: (@parent) =>
    checkSolution: (@areaData) =>
        return true

    render: =>
    renderEntity: =>
        if @entity
            @entity\render!

    getClassName: =>
        return @__class.__name

    populatePathMap: (pathMap) =>

_color = Material "moonpanel/color.png" 
class Color extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color
        }
    render: =>
        bounds = @parent.bounds
        if bounds
            surface.SetDrawColor Moonpanel.Colors[@attributes.color]
            surface.SetMaterial _color
            surface.DrawTexturedRect bounds.x, bounds.y, bounds.width, bounds.height
            draw.NoTexture!

sun = Material "moonpanel/sun.png" 
class Sun extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color
        }
    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or Moonpanel.Colors[@attributes.color]
            surface.SetDrawColor @colorCache
            surface.SetMaterial color
            surface.DrawTexturedRect bounds.x, bounds.y, bounds.width, bounds.height
            draw.NoTexture!

class Y extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color
        }
    render: =>
        bounds = @parent.bounds
        if bounds
            render.setColor Moonpanel.Colors[@attributes.color]
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

class Polyomino extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color
        }

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or Moonpanel.Colors[COLOR_YELLOW]

            surface.SetDrawColor @colorCache

            @polyheight = @attributes.shape.h
            @polywidth = @attributes.shape.w

            maxDim = math.max @polyheight, @polywidth
            shrink = bounds.width * 0.7

            if @attributes.rotational
                shrink *= 0.7

            squareWidth = math.min shrink / maxDim, bounds.width * 0.2
            spacing = shrink * 0.1

            offsetX = (bounds.width  / 2) - ((squareWidth * @polywidth ) + ((@polywidth  - 1) * spacing)) / 2
            offsetY = (bounds.height / 2) - ((squareWidth * @polyheight) + ((@polyheight - 1) * spacing)) / 2

            v = Vector bounds.x + bounds.width / 2, bounds.y + bounds.height / 2, 0

            if @attributes.rotational
                matrix = Matrix!
                matrix\translate v
                matrix\rotate Angle 0, -15, 0
                matrix\translate -v

                render.pushMatrix matrix
                
            for j = 1, @polyheight
                for i = 1, @polywidth
                    if (@attributes.shape\get i, j)
                        x = offsetX + bounds.x + (i - 1) * spacing + (i - 1) * squareWidth 
                        y = offsetY + bounds.y + (j - 1) * spacing + (j - 1) * squareWidth 
                        render.drawRoundedBox 4, x, y, squareWidth, squareWidth
            
            if @attributes.rotational
                render.popMatrix!

class Triangle extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color
            count: defs.Count
        }

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
            @trianglePoly = @trianglePoly or @buildPoly bounds
            render.setColor Moonpanel.Colors[@attributes.color]
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

Moonpanel.Entities or= {}

Moonpanel.Entities.Cell = {
    [MOONPANEL_ENTITY_TYPES.COLOR]: Color
    [MOONPANEL_ENTITY_TYPES.POLYOMINO]: Polyomino
    [MOONPANEL_ENTITY_TYPES.SUN]: Sun
    [MOONPANEL_ENTITY_TYPES.ERASER]: Y
    [MOONPANEL_ENTITY_TYPES.TRIANGLE]: Triangle
}