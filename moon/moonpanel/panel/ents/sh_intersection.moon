import Rect from Moonpanel

circ = Material "moonpanel/circ128.png"
hexagon = Material "moonpanel/hexagon.png"

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

    render: =>
        surface.SetDrawColor @parent.tile.colors.untraced
        render.SetMaterial circ
        Moonpanel.render.drawTexturedRect @bounds.x, @bounds.y, @bounds.width, @bounds.height, @parent.tile.colors.untraced
        render.SetColorMaterial!

class Hexagon extends Moonpanel.BaseEntity
    erasable: true
    new: (parent, defs, ...) =>
        super parent, defs, ...

        @attributes.color = defs.Color or Moonpanel.Color.Black

    checkSolution: (areaData) =>
        return @parent.solutionData.traced

    render: =>
        bounds = @getBounds!

        w = math.min bounds.width, bounds.height

        surface.SetMaterial hexagon
        surface.DrawTexturedRect bounds.x + (bounds.width / 2) - (w / 2), 
            bounds.y + (bounds.height / 2) - (w / 2), w, w
        draw.NoTexture!

unitVector = (angle) ->
    angle = math.rad angle + 90
    x = math.cos angle
    y = math.sin angle

    return { :x, :y }

class Exit extends Moonpanel.BaseEntity
    background: true
    getAngle: =>
        return @__angle

    calculateAngle: =>
        @__angle or= do
            invis = Moonpanel.EntityTypes.Invisible

            left = @parent\getLeft!
            right = @parent\getRight!
            top = @parent\getTop!
            bottom = @parent\getBottom!

            left   = left   and not (left.entity   and left.entity.type   == invis) and left
            right  = right  and not (right.entity  and right.entity.type  == invis) and right
            top    = top    and not (top.entity    and top.entity.type    == invis) and top
            bottom = bottom and not (bottom.entity and bottom.entity.type == invis) and bottom

            @overridesRender = ((left and 1 or 0) +
                (right and 1 or 0) +
                (top and 1 or 0) +
                (bottom and 1 or 0)) == 1

            -- Corner cases.
            if top and right and not bottom and not left
                return unitVector 45
            
            if right and bottom and not left and not top
                return unitVector 135

            if left and bottom and not right and not top
                return unitVector 225

            if left and top and not right and not bottom
                return unitVector 315

            td = @parent.tile.tileData.Tile
            x, y, w, h = @parent.x, @parent.y, td.Width + 1, td.Height + 1

            -- "Edge" cases.
            if y == 1 and x ~= 1 and x ~= w
                return unitVector 180

            if y == h and x ~= 1 and x ~= w
                return unitVector 0

            if x == w and y ~= 1 and y ~= h
                return unitVector 270

            if x == 1 and y ~= 1 and y ~= h
                return unitVector 90

            -- Inside-out cases.
            if y <= (h / 2) --and x ~= 1 and x ~= w
                return unitVector 180

            if y > (h / 2) --and x ~= 1 and x ~= w
                return unitVector 0

            if x <= (w / 2) --and y ~= 1 and y ~= h
                return unitVector 270

            if x > (w / 2) --and y ~= 1 and y ~= h
                return unitVector 90

            -- The rest.
            if not bottom
                return unitVector 0

            if not top
                return unitVector 180

            if not left
                return unitVector 90
            
            if not right
                return unitVector 270

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
        
    render: =>
        dir = @getAngle!

        if dir
            bounds = @getBounds!

            surface.SetDrawColor @parent.tile.colors.untraced
            render.SetMaterial circ
            Moonpanel.render.drawTexturedRect bounds.x + bounds.width * dir.x, bounds.y + bounds.height * dir.y, 
                bounds.width, bounds.height, @parent.tile.colors.untraced
            render.SetColorMaterial!

            surface.SetDrawColor Color 255, 0, 0

            if x ~=0 and y == 0 or y ~= 0 and x == 0
                x = (dir.x == -1 and -1 or 0) * bounds.width * 0.5
                y = (dir.y == -1 and -1 or 0) * bounds.width * 0.5
                w = bounds.width + math.ceil(math.abs(dir.x) * bounds.width * 0.5)
                h = bounds.height + math.ceil(math.abs(dir.y) * bounds.height * 0.5)
                surface.DrawRect bounds.x + x, bounds.y + y, w, h
            else
                cx, cy = bounds.x + bounds.width / 2, bounds.y + bounds.height / 2
                ex, ey = bounds.x + bounds.width * dir.x + bounds.width / 2, bounds.y + bounds.height * dir.y + bounds.width / 2
                Moonpanel.render.drawThickLine cx, cy, ex, ey, bounds.width

Moonpanel.Entities or= {}

Moonpanel.Entities.Intersection = {
    [Moonpanel.EntityTypes.Start]: Entrance
    [Moonpanel.EntityTypes.End]: Exit
    [Moonpanel.EntityTypes.Hexagon]: Hexagon
    [Moonpanel.EntityTypes.Invisible]: Invisible
}