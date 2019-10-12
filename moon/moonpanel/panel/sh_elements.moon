class Element
    new: (@tile, @x, @y, @entity) =>
    render: =>
    getClassName: =>
        return @__class.__name

    renderEntity: =>
        if @entity
            @entity\render!

    populatePathMap: (pathMap) =>
        if @entity
            @entity\populatePathMap pathMap

class Path extends Element
    isBroken: =>
        return @entity and @entity\getClassName! == "Broken"

EMPTY_TABLE = {}

class VPath extends Path
    type: Moonpanel.ObjectTypes.VPath
    populatePathMap: (pathMap) =>
        if @entity and (@entity\populatePathMap pathMap) == true
            return

        topIntersection = @getTop!
        bottomIntersection = @getBottom!

        topNode = topIntersection and topIntersection.pathMapNode
        bottomNode = bottomIntersection and bottomIntersection.pathMapNode

        if topNode and bottomNode
            table.insert topNode.neighbors, bottomNode
            table.insert bottomNode.neighbors, topNode

    getLeft: =>
        @cachedLeft or= (@tile.elements.cells[@y] or EMPTY_TABLE)[@x - 1]
        return @cachedLeft

    getRight: =>
        @cachedRight or= (@tile.elements.cells[@y] or EMPTY_TABLE)[@x]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.intersections[@y] or EMPTY_TABLE)[@x]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.intersections[@y + 1] or EMPTY_TABLE)[@x]
        return @cachedBottom 

class HPath extends Path
    type: Moonpanel.ObjectTypes.HPath
    populatePathMap: (pathMap) =>
        if @entity and (@entity\populatePathMap pathMap) == true
            return

        leftIntersection = @getLeft!
        rightIntersection = @getRight!

        leftNode = leftIntersection and leftIntersection.pathMapNode
        rightNode = rightIntersection and rightIntersection.pathMapNode

        if leftNode and rightNode
            table.insert leftNode.neighbors, rightNode
            table.insert rightNode.neighbors, leftNode

    getLeft: =>
        @cachedLeft or= (@tile.elements.intersections[@y] or EMPTY_TABLE)[@x]
        return @cachedLeft

    getRight: =>
        @cachedRight or= (@tile.elements.intersections[@y] or EMPTY_TABLE)[@x + 1]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.cells[@y - 1] or EMPTY_TABLE)[@x]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.cells[@y] or EMPTY_TABLE)[@x]
        return @cachedBottom

class Intersection extends Element
    type: Moonpanel.ObjectTypes.Intersection
    getLeft: =>
        @cachedLeft or= (@tile.elements.hpaths[@y] or EMPTY_TABLE)[@x - 1]
        return @cachedLeft

    getRight: =>
        @cachedRight or= (@tile.elements.hpaths[@y] or EMPTY_TABLE)[@x]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.vpaths[@y - 1] or EMPTY_TABLE)[@x]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.vpaths[@y] or EMPTY_TABLE)[@x]
        return @cachedBottom

class Cell extends Element
    type: Moonpanel.ObjectTypes.Cell
    getLeft: =>
        @cachedLeft or= (@tile.elements.vpaths[@y] or EMPTY_TABLE)[@x]
        return @cachedLeft
        
    getRight: =>
        @cachedRight or= (@tile.elements.vpaths[@y] or EMPTY_TABLE)[@x + 1]
        return @cachedRight

    getTop: =>
        @cachedTop or= (@tile.elements.hpaths[@y] or EMPTY_TABLE)[@x]
        return @cachedTop

    getBottom: =>
        @cachedBottom or= (@tile.elements.hpaths[@y + 1] or EMPTY_TABLE)[@x]
        return @cachedBottom

    render: =>
        if @tile.colors.cell and not (@entity and @entity.type == Moonpanel.EntityTypes.Invisible)
            barw = @tile.calculatedDimensions.barWidth
            surface.SetDrawColor @tile.colors.cell
            surface.DrawRect @bounds.x - barw / 2, @bounds.y - barw / 2, @bounds.width + barw, @bounds.height + barw

Moonpanel.Elements = {
    :Cell
    :Intersection
    :VPath
    :HPath
}

class Moonpanel.BaseEntity
    erasable: false
    render: =>
    populatePathMap: (pathMap) =>
    new: (@parent, defaults, @bounds) =>
        @attributes = {}

    renderEntity: =>
        if @entity
            @entity\render!

    getClassName: =>
        return @__class.__name

    getBounds: () =>
        return @bounds or (@parent and @parent.bounds)

    checkSolution: (@areaData) =>
        return true