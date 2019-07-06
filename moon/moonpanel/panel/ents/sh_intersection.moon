import Rect from Moonpanel

class IntersectionEntity
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

circ = Material "moonpanel/circ128.png"
hexagon = Material "moonpanel/hexagon.png"

class Entrance extends IntersectionEntity
    background: true
    overridesRender: true
    new: (@parent) =>
        if CLIENT
            parentBounds = @parent.bounds
            w = parentBounds.width * 2.5
            h = parentBounds.height * 2.5
            x = parentBounds.x + (parentBounds.width / 2) - w / 2
            y = parentBounds.y + (parentBounds.width / 2) - h / 2

            @bounds = Rect x, y, w, h

            @ripple = Moonpanel.render.createRipple x + w/2, y + h/2, w * 3

    render: =>
        surface.SetDrawColor @parent.tile.colors.untraced
        render.SetMaterial circ
        Moonpanel.render.drawTexturedRect @bounds.x, @bounds.y, @bounds.width, @bounds.height, @parent.tile.colors.untraced
        render.SetColorMaterial!

class Hexagon extends IntersectionEntity
    new: (@parent, defs) =>
        @attributes = {
            color: Moonpanel.Color.Black
        }

    checkSolution: (areaData) =>
        return @parent.solutionData.traced

    render: =>
        bounds = @parent.bounds

        w = math.min bounds.width, bounds.height

        surface.SetMaterial hexagon
        surface.DrawTexturedRect bounds.x + (bounds.width / 2) - (w / 2), 
            bounds.y + (bounds.height / 2) - (w / 2), w, w
        draw.NoTexture!

class Exit extends IntersectionEntity
    circ: Material "moonpanel/circ128.png"
    background: true
    overridesRender: true
    dirs: {
        [90]:   {x: -1, y:  0}
        [270]:  {x:  1, y:  0}
        [180]:  {x:  0, y: -1}
        [0]:    {x:  0, y:  1}
    }
    getAngle: (x, y, w, h) =>
        if (x == 1)
            return 90
        if (x == w)
            return 270
        if (y == 1)
            return 180
        if (y == h)
            return 0

        return -1

    new: (@parent) =>
        if CLIENT
            bounds = @parent.bounds

            td = @parent.tile.tileData.Tile
            x, y, w, h = @parent.x, @parent.y, td.Width + 1, td.Height + 1

            dir = @dirs[@getAngle x, y, w, h]

            if dir
                x = bounds.x + bounds.width * dir.x + bounds.width / 2
                y = bounds.y + bounds.height * dir.y + bounds.height / 2
                w = @parent.bounds.width

                @ripple = Moonpanel.render.createRipple x, y, w

    populatePathMap: (pathMap) =>
        bounds = @parent.bounds

        td = @parent.tile.tileData.Tile
        x, y, w, h = @parent.x, @parent.y, td.Width + 1, td.Height + 1

        dir = @dirs[@getAngle x, y, w, h]

        if dir
            x = bounds.x + bounds.width * dir.x + bounds.width / 2
            y = bounds.y + bounds.height * dir.y + bounds.height / 2

            w = @parent.bounds.width
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
        surface.SetDrawColor @parent.tile.colors.untraced
        bounds = @parent.bounds

        td = @parent.tile.tileData.Tile
        x, y, w, h = @parent.x, @parent.y, td.Width + 1, td.Height + 1

        dir = @dirs[@getAngle x, y, w, h]

        if dir
            w = bounds.width + math.ceil(math.abs(dir.x) * bounds.width * 0.5)
            h = bounds.height + math.ceil(math.abs(dir.y) * bounds.height * 0.5)
            x = (dir.x == -1 and -1 or 0) * bounds.width * 0.5
            y = (dir.y == -1 and -1 or 0) * bounds.width * 0.5

            render.SetMaterial circ
            Moonpanel.render.drawTexturedRect bounds.x + bounds.width * dir.x, bounds.y + bounds.height * dir.y, 
                bounds.width, bounds.height, @parent.tile.colors.untraced
            render.SetColorMaterial!

            surface.DrawRect bounds.x + x, bounds.y + y, w, h

Moonpanel.Entities or= {}

Moonpanel.Entities.Intersection = {
    [MOONPANEL_ENTITY_TYPES.START]: Entrance
    [MOONPANEL_ENTITY_TYPES.END]: Exit
    [MOONPANEL_ENTITY_TYPES.HEXAGON]: Hexagon
}