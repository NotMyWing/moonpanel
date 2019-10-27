import Rect from Moonpanel

hexagon = Material "moonpanel/common/hexagon.png"

class Invisible extends Moonpanel.BaseEntity
    background: true
    overridesRender: true
    populatePathMap: () =>
        return true

class Entrance extends Moonpanel.BaseEntity
    background: true
    overridesRender: true
    new: (...) =>
        super ...
        if CLIENT
            parentBounds = @getBounds!
            w = parentBounds.width * 2.5
            h = parentBounds.height * 2.5
            x = parentBounds.x + (parentBounds.width / 2) - w / 2
            y = parentBounds.y + (parentBounds.width / 2) - h / 2

            if not bounds
                @ripple = Moonpanel.render.createRipple x + w/2, y + h/2, w * 3

            @bounds = Rect x, y, w, h

class Hexagon extends Moonpanel.BaseEntity
    erasable: true
    new: (parent, defs, ...) =>
        super parent, defs, ...

        @attributes.color = defs.Color or Moonpanel.Color.Black
        @attributes.hollow = defs.Hollow or false

    checkSolution: (areaData) =>
        return @parent.solutionData.traced

    render: =>
        if @attributes.hollow
            return

        bounds = @getBounds!

        w = math.min bounds.width, bounds.height

        surface.SetMaterial hexagon
        surface.DrawTexturedRect bounds.x + (bounds.width / 2) - (w / 2), 
            bounds.y + (bounds.height / 2) - (w / 2), w, w
        draw.NoTexture!

trunc = Moonpanel.trunc
unitVector = (angle) ->
    angle = math.rad angle + 90
    x = trunc (math.cos angle), 3
    y = trunc (math.sin angle), 3

    return { :x, :y }

class Exit extends Moonpanel.BaseEntity
    background: true
    getAngle: =>
        return @__angle

    calculateAngle: =>
        if @__angle == nil
            @__angle = (->
                invis = Moonpanel.EntityTypes.Invisible

                left = @parent\getLeft!
                right = @parent\getRight!
                top = @parent\getTop!
                bottom = @parent\getBottom!

                left   = left   and not (left.entity   and left.entity.type   == invis) and left
                right  = right  and not (right.entity  and right.entity.type  == invis) and right
                top    = top    and not (top.entity    and top.entity.type    == invis) and top
                bottom = bottom and not (bottom.entity and bottom.entity.type == invis) and bottom

                screenWidth  = @parent.tile.calculatedDimensions.screenWidth
                screenHeight = @parent.tile.calculatedDimensions.screenHeight

                isLeftMost = @parent.bounds.x <= screenWidth  / 2
                isTopMost  = @parent.bounds.y <= screenHeight / 2

                numNeighbours = (left and 1 or 0) +
                    (right and 1 or 0) +
                    (top and 1 or 0) +
                    (bottom and 1 or 0)

                if numNeighbours == 3
                    if not top
                        return unitVector 180

                    if not bottom
                        return unitVector 0

                    if not left
                        return unitVector 90

                    if not right
                        return unitVector 270

                    return false

                if numNeighbours == 2
                    if top and right
                        return unitVector 45

                    if bottom and right
                        return unitVector 135

                    if left and bottom
                        return unitVector 225

                    if left and top
                        return unitVector 315

                    if left and right
                        return unitVector isTopMost and 180 or 0

                    if top and bottom
                        return unitVector isLeftMost and 90 or 270

                if numNeighbours == 1
                    if bottom
                        return unitVector 180

                    if top
                        return unitVector 0

                    if right
                        return unitVector 270

                    if left
                        return unitVector 90

                return false
            )!

        @__angle

    new: (parent, defs, ...) =>
        super parent, defs, ...

        @calculateAngle!

        if CLIENT
            dir = @getAngle!

            if dir
                bounds = @getBounds!
                x = bounds.x + bounds.width * dir.x + bounds.width / 2
                y = bounds.y + bounds.height * dir.y + bounds.height / 2
                w = bounds.width

                if not @bounds
                    @ripple = Moonpanel.render.createRipple x, y, w

    populatePathMap: (pathMap) =>
        dir = @getAngle!

        if dir
            bounds = @getBounds!
            x = bounds.x + bounds.width * dir.x + bounds.width / 2
            y = bounds.y + bounds.height * dir.y + bounds.height / 2

            w = bounds.width
            parentNode = @parent.pathMapNode
            node = {
                x: parentNode.x + (dir.x) * 0.25
                y: parentNode.y + (dir.y) * 0.25
                screenX: x
                screenY: y
                neighbors: { parentNode }
                intersection: @parent
                exit: true
            }
            parentNode.neighbors = parentNode.neighbors or {}
            
            table.insert parentNode.neighbors, node

            table.insert pathMap, node

Moonpanel.Entities or= {}

Moonpanel.Entities.Intersection = {
    [Moonpanel.EntityTypes.Start]: Entrance
    [Moonpanel.EntityTypes.End]: Exit
    [Moonpanel.EntityTypes.Hexagon]: Hexagon
    [Moonpanel.EntityTypes.Invisible]: Invisible
}