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

    render: =>
        if @entity and @entity.overridesRender
            return @entity\render!

        surface.SetDrawColor @tile.colors.untraced
        surface.DrawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height

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

corners = {
    [0]: Material "moonpanel/corner64/0.png"
    [90]: Material "moonpanel/corner64/90.png"
    [180]: Material "moonpanel/corner64/180.png"
    [270]: Material "moonpanel/corner64/270.png"
}

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

    render: =>
        if not @angle
            dsjZero = @tile and @tile.tileData and @tile.tileData.Dimensions and (@tile.tileData.Dimensions.DisjointLength == 1)

            dsj = Moonpanel.EntityTypes.Disjoint

            notLeft   = (not @getLeft!)   or ((@getLeft!   and @getLeft!.entity   and @getLeft!.entity.type   == dsj) and dsjZero)
            notRight  = (not @getRight!)  or ((@getRight!  and @getRight!.entity  and @getRight!.entity.type  == dsj) and dsjZero)
            notTop    = (not @getTop!)    or ((@getTop!    and @getTop!.entity    and @getTop!.entity.type    == dsj) and dsjZero)
            notBottom = (not @getBottom!) or ((@getBottom! and @getBottom!.entity and @getBottom!.entity.type == dsj) and dsjZero)

            @angle = (notLeft and notTop) and 0 or
                (notRight and notTop) and 90 or
                (notRight and notBottom) and 180 or
                (notBottom and notLeft) and 270 or -1

        surface.SetDrawColor @tile.colors.untraced
        if @angle ~= -1
            surface.SetMaterial corners[@angle]
            surface.DrawTexturedRect @bounds.x, @bounds.y, @bounds.width, @bounds.height
            draw.NoTexture!
        else
            surface.DrawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height

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