class PathEntity
    new: (@parent, @attributes = {}) =>
    checkSolution: (areaData) =>
    render: =>
    populatePathMap: (pathMap) =>

class Hexagon extends PathEntity
    type: "Hexagon"
    buildPoly: (bounds) =>
        shrink = (math.min bounds.width, bounds.height) * 0.9

        poly = {}
        for i = -180, 180, 360 / 6
            table.insert poly, {
                x: bounds.x + bounds.width / 2 + (math.cos math.rad i) * shrink / 2
                y: bounds.y + bounds.height / 2 + (math.sin math.rad i) * shrink / 2
            }

        return poly
        
    checkSolution: (areaData) =>
        return @parent.solutionData.traced

    render: =>
        bounds = @parent.bounds
        if bounds
            @colorCache = @colorCache or COLORS[COLOR_BLACK]
            @poly = @poly or @buildPoly bounds
            render.setColor @colorCache
            for i = 1, 10
                render.drawPoly @poly

class HPathEntity_Hexagon extends Hexagon
class VPathEntity_Hexagon extends Hexagon

class VPathEntity_Broken extends PathEntity
    type: "Broken"
    populatePathMap: (pathMap) =>
        gap = @parent.bounds.height / 3
        height = @parent.bounds.height / 2 - gap / 2

        topIntersection = @parent\getTop!
        bottomIntersection = @parent\getBottom!

        topNode = topIntersection and topIntersection.pathMapNode
        bottomNode = bottomIntersection and bottomIntersection.pathMapNode

        if topNode and bottomNode
            nodeA = {
                x: topNode.x
                y: topNode.y + 0.25
                screenX: topNode.screenX
                screenY: topNode.screenY + height
                lowPriority: true
                neighbors: { topNode }
            }
            table.insert topNode.neighbors, nodeA
            table.insert pathMap, nodeA

            nodeB = {
                x: bottomNode.x
                y: bottomNode.y - 0.25
                screenX: bottomNode.screenX
                screenY: bottomNode.screenY - height
                lowPriority: true
                neighbors: { bottomNode }
            }
            table.insert bottomNode.neighbors, nodeB
            table.insert pathMap, nodeB
        return true

    render: =>
        gap = @parent.bounds.height / 3
        height = @parent.bounds.height / 2 - gap / 2
        
        render.setColor @parent.tile.colors.untraced
        render.drawRect @parent.bounds.x, @parent.bounds.y, @parent.bounds.width, height
        render.drawRect @parent.bounds.x, @parent.bounds.y + gap + height, @parent.bounds.width, height

        return true

class HPathEntity_Broken extends PathEntity
    type: "Broken"
    populatePathMap: (pathMap) =>
        gap = @parent.bounds.width / 3
        width = @parent.bounds.width / 2 - gap / 2

        leftIntersection = @parent\getLeft!
        rightIntersection = @parent\getRight!

        leftNode = leftIntersection and leftIntersection.pathMapNode
        rightNode = rightIntersection and rightIntersection.pathMapNode

        if leftNode and rightNode
            nodeA = {
                x: leftNode.x + 0.25
                y: leftNode.y
                screenX: leftNode.screenX + width
                screenY: leftNode.screenY
                lowPriority: true
                neighbors: { leftNode }
            }
            table.insert leftNode.neighbors, nodeA
            table.insert pathMap, nodeA

            nodeB = {
                x: rightNode.x - 0.25
                y: rightNode.y
                screenX: rightNode.screenX - width
                screenY: rightNode.screenY
                lowPriority: true
                neighbors: { rightNode }
            }
            table.insert rightNode.neighbors, nodeB
            table.insert pathMap, nodeB

        return true

    render: =>
        gap = @parent.bounds.width / 3
        width = @parent.bounds.width / 2 - gap / 2
        
        render.setColor @parent.tile.colors.untraced
        render.drawRect @parent.bounds.x, @parent.bounds.y, width, @parent.bounds.height
        render.drawRect @parent.bounds.x + gap + width, @parent.bounds.y, width, @parent.bounds.height
        
        return true

VPATH_ENTITIES = {
    "Broken": VPathEntity_Broken
    "Disjoint": VPathEntity_Broken
    "Hexagon": VPathEntity_Hexagon
    "Dot": VPathEntity_Hexagon
}

HPATH_ENTITIES = {
    "Disjoint": HPathEntity_Broken
    "Broken": HPathEntity_Broken
    "Hexagon": VPathEntity_Hexagon
    "Dot": VPathEntity_Hexagon
}

return { HPATH_ENTITIES, VPATH_ENTITIES }