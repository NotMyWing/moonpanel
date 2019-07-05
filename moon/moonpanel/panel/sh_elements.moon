class Element
    new: (@tile, @x, @y, @entity) =>
    render: =>
    getClassName: =>
        return @__class.__name

    renderEntity: =>
        if @entity
            @entity\render!

class Path extends Element
    isBroken: =>
        return @entity and @entity\getClassName! == "Broken"

    render: =>
        if @entity and @entity.overridesRender
            return @entity\render!

        surface.SetDrawColor @tile.colors.untraced
        surface.DrawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height

EMPTY_TABLE = {}

class VPath extends Path
    getLeft: =>
        @cachedLeft or= (@tile.elements.cells[@x - 1] or EMPTY_TABLE)[@y]
        return @cachedLeft

    getRight: =>
        @cachedRight or= (@tile.elements.cells[@x] or EMPTY_TABLE)[@y]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.intersections[@x] or EMPTY_TABLE)[@y]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.intersections[@x] or EMPTY_TABLE)[@y + 1]
        return @cachedBottom 

class HPath extends Path
    getLeft: =>
        @cachedLeft or= (@tile.elements.intersections[@x] or EMPTY_TABLE)[@y]
        return @cachedLeft

    getRight: =>
        @cachedRight or= (@tile.elements.intersections[@x + 1] or EMPTY_TABLE)[@y]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.cells[@x] or EMPTY_TABLE)[@y - 1]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.cells[@x] or EMPTY_TABLE)[@y]
        return @cachedBottom

corners = {
    [0]: Material "moonpanel/corner64/0.png"
    [90]: Material "moonpanel/corner64/90.png"
    [180]: Material "moonpanel/corner64/180.png"
    [270]: Material "moonpanel/corner64/270.png"
}

class Intersection extends Element
    getLeft: =>
        @cachedLeft or= (@tile.elements.hpaths[@x - 1] or EMPTY_TABLE)[@y]
        return @cachedLeft

    getRight: =>
        @cachedRight or= (@tile.elements.hpaths[@x] or EMPTY_TABLE)[@y]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.vpaths[@x] or EMPTY_TABLE)[@y - 1]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.vpaths[@x] or EMPTY_TABLE)[@y]
        return @cachedBottom

    render: =>
        angle = (not @getLeft! and not @getTop!) and 0 or
            (not @getRight! and not @getTop!) and 90 or
            (not @getRight! and not @getBottom!) and 180 or
            (not @getBottom! and not @getLeft!) and 270 or -1

        surface.SetDrawColor @tile.colors.untraced
        if angle ~= -1
            surface.SetMaterial corners[angle]
            surface.DrawTexturedRect @bounds.x, @bounds.y, @bounds.width, @bounds.height
            draw.NoTexture!
        else
            surface.DrawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height

class Cell extends Element
    getLeft: =>
        @cachedLeft or= (@tile.elements.vpaths[@x] or EMPTY_TABLE)[@y]
        return @cachedLeft
        
    getRight: =>
        @cachedRight or= (@tile.elements.vpaths[@x + 1] or EMPTY_TABLE)[@y]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.hpaths[@x] or EMPTY_TABLE)[@y]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.hpaths[@x] or EMPTY_TABLE)[@y + 1]
        return @cachedBottom

    render: =>
        if @tile.colors.cell
            barw = @tile.calculatedDimensions.barWidth
            surface.SetDrawColor @tile.colors.cell
            surface.DrawRect @bounds.x - barw / 2, @bounds.y - barw / 2, @bounds.width + barw, @bounds.height + barw

Moonpanel.Elements = {
    :Cell
    :Intersection
    :VPath
    :HPath
} 