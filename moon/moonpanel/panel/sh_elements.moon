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
        surface.SetDrawColor @tile.colors.untraced
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