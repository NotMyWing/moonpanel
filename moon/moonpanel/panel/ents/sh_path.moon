import Rect from Moonpanel

circ = Material "moonpanel/common/circ256.png"
hexagon = Material "moonpanel/common/hexagon.png"

class Invisible extends Moonpanel.BaseEntity
    background: true
    overridesRender: true
    populatePathMap: () =>
        return true

class Hexagon extends Moonpanel.BaseEntity
    erasable: true
    new: (parent, defs, ...) =>
        super parent, defs, ...
        @attributes.color =  defs.Color or Moonpanel.Color.Black

    checkSolution: (areaData) =>
        return @parent.solutionData.traced
 
    render: =>
        bounds = @getBounds!

        w = math.min bounds.width, bounds.height

        surface.SetMaterial hexagon
        surface.DrawTexturedRect bounds.x + (bounds.width / 2) - (w / 2), 
            bounds.y + (bounds.height / 2) - (w / 2), w, w
        draw.NoTexture!

class VBroken extends Moonpanel.BaseEntity
    overridesRender: true
    background: true
    populatePathMap: (pathMap) =>
        bounds = @getBounds!
        
        gap = math.ceil bounds.height * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        height = math.ceil bounds.height / 2 - gap / 2

        topIntersection = @parent\getTop!
        bottomIntersection = @parent\getBottom!

        topNode = topIntersection and topIntersection.pathMapNode
        bottomNode = bottomIntersection and bottomIntersection.pathMapNode

        if topNode
            nodeA = {
                x: topNode.x
                y: topNode.y + 0.25
                screenX: topNode.screenX
                screenY: topNode.screenY + height
                break: true
                neighbors: { topNode }
            }

            table.insert topNode.neighbors, nodeA
            table.insert pathMap, nodeA
        
        if bottomNode
            nodeB = {
                x: bottomNode.x
                y: bottomNode.y - 0.25
                screenX: bottomNode.screenX
                screenY: bottomNode.screenY - height
                break: true
                neighbors: { bottomNode }
            }

            table.insert bottomNode.neighbors, nodeB
            table.insert pathMap, nodeB

        return true

    render: =>
        bounds = @getBounds!

        gap = math.ceil bounds.height * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        height = math.ceil bounds.height / 2 - gap / 2
        
        surface.SetDrawColor @parent.tile.colors.untraced
        top = @parent\getTop!
        bottom = @parent\getBottom!

        if top and not (top and top.entity and top.entity.type == Moonpanel.EntityTypes.Invisible) 
            surface.DrawRect bounds.x, bounds.y, bounds.width, height

        if bottom and not (bottom and bottom.entity and bottom.entity.type == Moonpanel.EntityTypes.Invisible) 
            surface.DrawRect bounds.x, bounds.y + gap + height, bounds.width, height

        return true

class HBroken extends Moonpanel.BaseEntity
    overridesRender: true
    background: true
    populatePathMap: (pathMap) =>
        bounds = @getBounds!

        gap = math.ceil bounds.width * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        width = math.ceil bounds.width / 2 - gap / 2

        leftIntersection = @parent\getLeft!
        rightIntersection = @parent\getRight!

        leftNode = leftIntersection and leftIntersection.pathMapNode
        rightNode = rightIntersection and rightIntersection.pathMapNode

        if leftNode
            nodeA = {
                x: leftNode.x + 0.25
                y: leftNode.y
                screenX: leftNode.screenX + width
                screenY: leftNode.screenY
                break: true
                neighbors: { leftNode }
            }
            table.insert leftNode.neighbors, nodeA
            table.insert pathMap, nodeA

        if rightNode
            nodeB = {
                x: rightNode.x - 0.25
                y: rightNode.y
                screenX: rightNode.screenX - width
                screenY: rightNode.screenY
                break: true
                neighbors: { rightNode }
            }
            table.insert rightNode.neighbors, nodeB
            table.insert pathMap, nodeB

        return true

    render: =>
        bounds = @getBounds!

        gap = math.ceil bounds.width * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        width = math.ceil bounds.width / 2 - gap / 2
        
        surface.SetDrawColor @parent.tile.colors.untraced
        left = @parent\getLeft!
        right = @parent\getRight!

        if left and not (left and left.entity and left.entity.type == Moonpanel.EntityTypes.Invisible) 
            surface.DrawRect bounds.x, bounds.y, width, bounds.height

        if right and not (right and right.entity and right.entity.type == Moonpanel.EntityTypes.Invisible) 
            surface.DrawRect bounds.x + gap + width, bounds.y, width, bounds.height
        
        return true

Moonpanel.Entities or= {}

Moonpanel.Entities.HPath = {
    [Moonpanel.EntityTypes.Hexagon]: Hexagon
    [Moonpanel.EntityTypes.Disjoint]: HBroken
    [Moonpanel.EntityTypes.Invisible]: Invisible
}

Moonpanel.Entities.VPath = {
    [Moonpanel.EntityTypes.Hexagon]: Hexagon
    [Moonpanel.EntityTypes.Disjoint]: VBroken
    [Moonpanel.EntityTypes.Invisible]: Invisible
}