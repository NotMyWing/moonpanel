class PathObject
    new: (@parent, @attributes = {}) =>
    render: =>
    generatePath: (nodeList) =>

class VPathObject_Broken extends PathObject
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
                neighbors: { topNode }
            }
            table.insert topNode.neighbors, nodeA
            table.insert pathMap, nodeA

            nodeB = {
                x: bottomNode.x
                y: bottomNode.y - 0.25
                screenX: bottomNode.screenX
                screenY: bottomNode.screenY - height
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

class HPathObject_Broken extends PathObject
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
                neighbors: { leftNode }
            }
            table.insert leftNode.neighbors, nodeA
            table.insert pathMap, nodeA

            nodeB = {
                x: rightNode.x - 0.25
                y: rightNode.y
                screenX: rightNode.screenX - width
                screenY: rightNode.screenY
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

VPATH_OBJECTS = {
    "Broken": VPathObject_Broken
}

HPATH_OBJECTS = {
    "Broken": HPathObject_Broken
}

return { HPATH_OBJECTS, VPATH_OBJECTS }