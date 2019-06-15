class PathEntity
    new: (@parent, @attributes = {}) =>
    checkSolution: =>
        true
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

class Entrance extends PathEntity
    type: "Entrance"
    getAngle: () =>
        angle = nil
        if @parent.type == "HPath"
            angle = @parent\getTop! and 90 or 270
        else
            angle = @parent\getLeft! and 0 or 180

        print angle

        if not angle
            error "Invalid exit placement"

        return angle

    populatePathMap: (pathMap) =>
        angle = @getAngle!
        dir = switch angle
            when 0
                Vector -1, 0, 0
            when 90
                Vector 0, -1, 0
            when 180
                Vector 1, 0, 0
            when 270
                Vector 0, 1, 0

        w = math.min @parent.bounds.width, @parent.bounds.height
        
        intA, intB = nil, nil
        if angle == 90 or angle == 270
            intA, intB = @parent\getLeft!, @parent\getRight!
        else
            intA, intB = @parent\getTop!, @parent\getBottom!

        nodeA, nodeB = intA.pathMapNode, intB.pathMapNode
        if not nodeA or not nodeB
            error "Invalid exit placement"

        node = {
            x: (nodeA.x + nodeB.x) / 2
            y: (nodeA.y + nodeB.y) / 2
            screenX: (nodeA.screenX + nodeB.screenX) / 2
            screenY: (nodeA.screenY + nodeB.screenY) / 2
            neighbors: { nodeA, nodeB }
            clickable: true
        }

        nodeA.neighbors = nodeA.neighbors or {}
        nodeB.neighbors = nodeB.neighbors or {}
        table.insert nodeA.neighbors, node
        table.insert nodeB.neighbors, node

        table.insert pathMap, node

        return true
    new: (@parent, @attributes = {}) =>
        super @parent, @attributes

        parentBounds = @parent.bounds
        min = math.min parentBounds.width, parentBounds.height

        w = min * 1.5
        h = min * 1.5
        x = parentBounds.x + parentBounds.width / 2
        y = parentBounds.y + parentBounds.height / 2

        @bounds = Rect x, y, w, h

    render: =>
        if @bounds
            w = math.min @bounds.width / 2, @bounds.height / 2
            h = math.max @bounds.width / 2, @bounds.height / 2
            render.drawCirclePolySeveralTimesBecauseFuckGarrysMod @bounds.x, 
                @bounds.y, w * 1.5

class Exit extends PathEntity
    type: "Exit"
    new: (@parent, @attributes = {}) =>
    getAngle: () =>
        angle = nil
        if @parent.type == "HPath"
            angle = @parent\getTop! and 90 or 270
        else
            angle = @parent\getLeft! and 0 or 180

        print angle

        if not angle
            error "Invalid exit placement"

        return angle

    populatePathMap: (pathMap) =>
        angle = @getAngle! + 180
        dir = switch angle
            when 0
                Vector -1, 0, 0
            when 90
                Vector 0, -1, 0
            when 180
                Vector 1, 0, 0
            when 270
                Vector 0, 1, 0

        w = math.min @parent.bounds.width, @parent.bounds.height
        
        intA, intB = nil, nil
        if angle == 90 or angle == 270
            intA, intB = @parent\getLeft!, @parent\getRight!
        else
            intA, intB = @parent\getTop!, @parent\getBottom!

        nodeA, nodeB = intA.pathMapNode, intB.pathMapNode
        if not nodeA or not nodeB
            error "Invalid exit placement"

        node = {
            x: (nodeA.x + nodeB.x) / 2
            y: (nodeA.y + nodeB.y) / 2
            screenX: (nodeA.screenX + nodeB.screenX) / 2
            screenY: (nodeA.screenY + nodeB.screenY) / 2
            neighbors: { nodeA, nodeB }
        }
        nodeA.neighbors = nodeA.neighbors or {}
        nodeB.neighbors = nodeB.neighbors or {}
        table.insert nodeA.neighbors, node
        table.insert nodeB.neighbors, node

        table.insert pathMap, node

        nodeExit = {
            x: node.x + (dir.x) * 0.25
            y: node.y + (dir.y) * 0.25
            screenX: node.screenX + (dir.x) * w
            screenY: node.screenY + (dir.y) * w
            neighbors: { node }
            exit: true
        }
        table.insert node.neighbors, nodeExit

        table.insert pathMap, nodeExit

        return true

    render: =>
        angle = @getAngle! + 180

        w = math.min @parent.bounds.width, @parent.bounds.height
        h = math.max @parent.bounds.width, @parent.bounds.height

        matrix = Matrix!
        matrix\translate Vector @parent.bounds.x + h / 2, @parent.bounds.y + w / 2, 0
        matrix\rotate Angle 0, angle, 0
        render.pushMatrix matrix

        render.drawRect -w, -w / 2, w, w
        render.drawCirclePolySeveralTimesBecauseFuckGarrysMod -w, 0, w / 2
    
        render.popMatrix!

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
    "Entrance": Entrance
    "Exit": Exit
    "Broken": VPathEntity_Broken
    "Disjoint": VPathEntity_Broken
    "Hexagon": VPathEntity_Hexagon
    "Dot": VPathEntity_Hexagon
}

HPATH_ENTITIES = {
    "Entrance": Entrance
    "Exit": Exit
    "Disjoint": HPathEntity_Broken
    "Broken": HPathEntity_Broken
    "Hexagon": VPathEntity_Hexagon
    "Dot": VPathEntity_Hexagon
}

return { HPATH_ENTITIES, VPATH_ENTITIES }