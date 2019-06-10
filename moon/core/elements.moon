--@include moonpanel/core/entities/cell.txt
--@include moonpanel/core/entities/path.txt
--@include moonpanel/core/entities/intersection.txt

export CELL_ENTITIES = require "moonpanel/core/entities/cell.txt"
{ _HPATH_ENTITIES, _VPATH_ENTITIES } = require "moonpanel/core/entities/path.txt"
export INTERSECTION_ENTITIES = require "moonpanel/core/entities/intersection.txt"

-- i stg
export HPATH_ENTITIES = _HPATH_ENTITIES
export VPATH_ENTITIES = _VPATH_ENTITIES

EMPTY_TABLE = {}

class Element
    new: (@tile, @x, @y, @entity) =>
    canTrace: (_from) =>
        return false

    isTraced: =>
        return false

    populatePathMap: (pathMap) =>
        if @entity
            @entity\populatePathMap pathMap

    render: =>
        
class Path extends Element
    isBroken: =>
        return @entity and @entity.type == "Broken"

export class VPath extends Path
    type: "VPath"
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
        @cachedLeft = @cachedLeft or (@tile.elements.cells[@x] or EMPTY_TABLE)[@y - 1]
        @cachedLeft
    getRight: =>
        @cachedRight = @cachedRight or (@tile.elements.cells[@x] or EMPTY_TABLE)[@y]
        @cachedRight
    getTop: =>
        @cachedTop = @cachedTop or (@tile.elements.intersections[@x] or EMPTY_TABLE)[@y]
        @cachedTop
    getBottom: =>
        @cachedBottom = @cachedBottom or (@tile.elements.intersections[@x] or EMPTY_TABLE)[@y + 1]
        @cachedBottom 
    render: =>
        if @entity and (@entity\render!) == true
            return

        render.setColor @tile.colors.untraced
        render.drawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height

export class HPath extends Element
    type: "HPath"
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
        @cachedLeft = @cachedLeft or (@tile.elements.intersections[@x] or EMPTY_TABLE)[@y]
        @cachedLeft
    getRight: =>
        @cachedRight = @cachedRight or (@tile.elements.intersections[@x + 1] or EMPTY_TABLE)[@y]
        @cachedRight
    getTop: =>
        @cachedTop = @cachedTop or (@tile.elements.cells[@x] or EMPTY_TABLE)[@y - 1]
        @cachedTop
    getBottom: =>
        @cachedBottom = @cachedBottom or (@tile.elements.cells[@x] or EMPTY_TABLE)[@y]
        @cachedBottom
    render: =>
        if @entity and (@entity\render!) == true
            return

        render.setColor @tile.colors.untraced
        render.drawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height
    
export class Intersection extends Element
    type: "Intersection"
    getLeft: =>
        @cachedLeft = @cachedLeft or (@tile.elements.hpaths[@x - 1] or EMPTY_TABLE)[@y]
        @cachedLeft

    getRight: =>
        @cachedRight = @cachedRight or (@tile.elements.hpaths[@x] or EMPTY_TABLE)[@y]
        @cachedRight

    getTop: =>
        @cachedTop = @cachedTop or (@tile.elements.vpaths[@x] or EMPTY_TABLE)[@y - 1]
        @cachedTop

    getBottom: =>
        @cachedBottom = @cachedBottom or (@tile.elements.vpaths[@x] or EMPTY_TABLE)[@y]
        @cachedBottom

    render: =>
        corners = {}
            
        if corners
            for i = 1, 2
                corners[i] = {}
                for j = 1, 2
                    corners[i][j] = false
                    
            if not @getLeft! and not @getTop!
                corners[1][1] = -1
            if not @getRight! and not @getTop!
                corners[2][1] = -1
            if not @getLeft! and not @getBottom!
                corners[1][2] = -1
            if not @getRight! and not @getBottom!
                corners[2][2] = -1

        for i = 1, 2
            for j = 1, 2
                corner = corners[i][j]
                if type(corner) == "boolean"
                    render.setColor @tile.colors.untraced

                    render.drawRect @bounds.x + (i - 1) * (@bounds.width / 2), 
                        @bounds.y + (j - 1) * (@bounds.height / 2), 
                        @bounds.width / 2, 
                        @bounds.height / 2

        render.setColor @tile.colors.untraced

        render.drawCirclePolySeveralTimesBecauseFuckGarrysMod @bounds.x + @bounds.width / 2, 
            @bounds.y + @bounds.width / 2, @bounds.width / 2

        if @entity
            render.setColor @tile.colors.untraced
            @entity\render!

        corners = nil

export class Cell extends Element
    type: "Cell"
    getLeft: =>
        @cachedLeft = @cachedLeft or (@tile.elements.vpaths[@x] or EMPTY_TABLE)[@y]
        @cachedLeft
    getRight: =>
        @cachedRight = @cachedRight or (@tile.elements.vpaths[@x + 1] or EMPTY_TABLE)[@y]
        @cachedRight
    getTop: =>
        @cachedTop = @cachedTop or (@tile.elements.hpaths[@x] or EMPTY_TABLE)[@y]
        @cachedTop
    getBottom: =>
        @cachedBottom = @cachedBottom or (@tile.elements.hpaths[@x] or EMPTY_TABLE)[@y + 1]
        @cachedBottom
    traverse: (x, y) =>
        pathToCheck = nil
        if x == -1
            pathToCheck = @getLeft!
        if x == 1
            pathToCheck = @getRight!
        if y == -1
            pathToCheck = @getTop!
        if y == 1
            pathToCheck = @getBottom!
            
        if pathToCheck and pathToCheck\isTraced!
            return

        return (@tile.elements.cells[@x + x] or EMPTY_TABLE)[@y + y]

    render: =>
        if @entity
            @entity\render!