--@include moonpanel/core/objects/cell.txt
--@include moonpanel/core/objects/path.txt
--@include moonpanel/core/objects/intersection.txt

export CELL_OBJECTS = require "moonpanel/core/objects/cell.txt"
{ _HPATH_OBJECTS, _VPATH_OBJECTS } = require "moonpanel/core/objects/path.txt"
export INTERSECTION_OBJECTS = require "moonpanel/core/objects/intersection.txt"

-- i stg
export HPATH_OBJECTS = _HPATH_OBJECTS
export VPATH_OBJECTS = _VPATH_OBJECTS 

EMPTY_TABLE = {}

class Element
    new: (@tile, @x, @y, @objects = {}) =>
    canTrace: (_from) =>
        return false
    isTraced: =>
        return false
    populatePathMap: (pathMap) =>
        if @objects
            for k, v in pairs @objects
                v\populatePathMap pathMap
    render: =>
        
class Path extends Element
    isBroken: =>
        if type(@cachedBroken) == nil
            @cachedBroken = false
            for k, v in pairs @objects
                if v.type == "Broken"
                    @cachedBroken = true
                    break

        return @cachedBroken

export class VPath extends Path
    type: "VPath"
    populatePathMap: (pathMap) =>
        for k, v in pairs @objects
            if (v\populatePathMap pathMap) == true
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
        for k, v in pairs @objects
            if v\render! == true
                return

        render.setColor @tile.colors.untraced
        render.drawRect @bounds.x, @bounds.y, @bounds.width, @bounds.height

export class HPath extends Element
    type: "HPath"
    populatePathMap: (pathMap) =>
        for k, v in pairs @objects
            if (v\populatePathMap pathMap) == true
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
        for k, v in pairs @objects
            if v\render == true
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

        for k, v in pairs @objects
            render.setColor @tile.colors.untraced
            v\render

        render.setColor @tile.colors.untraced

        render.drawCirclePolySeveralTimesBecauseFuckGarrysMod @bounds.x + @bounds.width / 2, 
            @bounds.y + @bounds.width / 2, @bounds.width / 2

        for k, v in pairs @objects
            render.setColor @tile.colors.untraced
            v\render!

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
        for k, v in pairs @objects
            return v\render!