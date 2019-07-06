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
            surface.SetMaterial sun
            surface.DrawTexturedRect bounds.x, bounds.y, bounds.width, bounds.height
            draw.NoTexture!

eraser = Material "moonpanel/eraser.png" 
class Y extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color
        }
    render: =>
        bounds = @parent.bounds
        if bounds
            surface.SetMaterial eraser
            surface.DrawTexturedRect bounds.x, bounds.y, bounds.width, bounds.height
            draw.NoTexture!

poly = Material "moonpanel/polyomino_cell.png"
class Polyomino extends CellEntity
    new: (@parent, defs) =>
        @attributes = {
            color: defs.Color or Moonpanel.Color.Yellow
        }

        maxw = 0
        for _, row in pairs defs.Shape
            if #row > maxw
                maxw = #row

        @attributes.shape = Moonpanel.BitMatrix maxw, #defs.Shape
        for j, row in pairs defs.Shape
            for i = 1, maxw
                @attributes.shape\set i, j, defs.Shape[j] and defs.Shape[j][i] == 1

        @attributes.rotational = defs.Rotational

    render: =>
        bounds = @parent.bounds

        @polyheight = @attributes.shape.h
        @polywidth = @attributes.shape.w

        maxDim = math.max @polyheight, @polywidth
        shrink = bounds.width * 0.7

        spacing = shrink * 0.05
        if @attributes.rotational
            shrink *= 0.7

        squareWidth = math.min shrink / maxDim, bounds.width * 0.2

        offsetX = (bounds.width  / 2) - ((squareWidth * @polywidth ) + ((@polywidth  - 1) * spacing)) / 2
        offsetY = (bounds.height / 2) - ((squareWidth * @polyheight) + ((@polyheight - 1) * spacing)) / 2

        v = Vector bounds.x + bounds.width / 2, bounds.y + bounds.height / 2, 0

        if @attributes.rotational
            matrix = Matrix!
            matrix\Translate v
            matrix\Rotate Angle 0, -15, 0
            matrix\Translate -v

            cam.PushModelMatrix matrix

        surface.SetMaterial poly
        for j = 1, @polyheight
            for i = 1, @polywidth
                if (@attributes.shape\get i, j)
                    x = offsetX + bounds.x + (i - 1) * spacing + (i - 1) * squareWidth 
                    y = offsetY + bounds.y + (j - 1) * spacing + (j - 1) * squareWidth 
                    --draw.RoundedBox 4, x, y, squareWidth, squareWidth, @attributes.color
                   
                    surface.DrawTexturedRect x, y, squareWidth, squareWidth
        draw.NoTexture!
        
        if @attributes.rotational
            cam.PopModelMatrix!

triangle = Material "moonpanel/triangle.png"

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
            shrink = bounds.width * 0.8

            triangleWidth = bounds.width * 0.2
            spacing = bounds.width * 0.05
            offset = if @attributes.count == 1
                0
            else
                (((@attributes.count - 1) * triangleWidth) + ((@attributes.count - 1) * spacing)) / 2

            matrix = Matrix!
            matrix\Translate Vector bounds.x + bounds.width / 2 - offset - triangleWidth / 2, 
                bounds.y + bounds.height / 2 - triangleWidth / 2, 0
            
            surface.SetMaterial triangle
            for i = 1, @attributes.count do
                if i > 1
                    cam.PopModelMatrix!
                    matrix\Translate Vector triangleWidth + spacing, 0, 0

                cam.PushModelMatrix matrix
                for j = 1, 10
                    surface.DrawTexturedRect 0, 0, triangleWidth, triangleWidth

            cam.PopModelMatrix!

Moonpanel.Entities or= {}

Moonpanel.Entities.Cell = {
    [MOONPANEL_ENTITY_TYPES.COLOR]: Color
    [MOONPANEL_ENTITY_TYPES.POLYOMINO]: Polyomino
    [MOONPANEL_ENTITY_TYPES.SUN]: Sun
    [MOONPANEL_ENTITY_TYPES.ERASER]: Y
    [MOONPANEL_ENTITY_TYPES.TRIANGLE]: Triangle
}