AddCSLuaFile!

class Moonpanel.Canvas.Entities.Start extends Moonpanel.Canvas.Entities.BaseIntersection
	GetRadius: =>
        data = @__canvas\GetData!

        0.5 * 2.5 * Moonpanel.Canvas.Resolution * (data.Dim.BarWidth / 100)

	PopulatePathNodes: =>
        socket = @GetSocket!
        socketType = socket\GetSocketType!

        if socketType == Moonpanel.Canvas.SocketType.Intersection
		    @GetSocket!\GetPathNode!.clickable = true

    CleanUpPathNodes: =>
        socket = @GetSocket!
        socketType = socket\GetSocketType!

        if socketType == Moonpanel.Canvas.SocketType.Intersection
		    @GetSocket!\GetPathNode!.clickable = nil

trunc = (num, n) ->
	mult = 10^(n or 0)
	math.floor(num * mult + 0.5) / mult

unitVector = (angle) ->
    angle = math.rad angle + 90
    x = trunc (math.cos angle), 3
    y = trunc (math.sin angle), 3

    return { :x, :y }

class Moonpanel.Canvas.Entities.End extends Moonpanel.Canvas.Entities.BaseIntersection
    GetAngle: => @__angle

    CalculateAngle: =>
        if @__angle == nil
            @__angle = (->
                --invis = Moonpanel.EntityTypes.Invisible

                socket = @GetSocket!
				canvas = socket\GetCanvas!
				if Moonpanel.Canvas.UsesVerticalBoundaryExits(canvas\GetSurfaceSpec!)
					height = canvas\GetData!.Meta.Height
					return { x: 0, y: -1 } if socket\GetY! == 1
					return { x: 0, y: 1 } if socket\GetY! == height + 1
					return false

                left = socket\GetLeft!
                right = socket\GetRight!
                top = socket\GetAbove!
                bottom = socket\GetBelow!

                --left   = left   and not (left.entity   and left.entity.type   == invis) and left
                --right  = right  and not (right.entity  and right.entity.type  == invis) and right
                --top    = top    and not (top.entity    and top.entity.type    == invis) and top
                --bottom = bottom and not (bottom.entity and bottom.entity.type == invis) and bottom
                left   = left   and not (left.entity  ) and left
                right  = right  and not (right.entity ) and right
                top    = top    and not (top.entity   ) and top
                bottom = bottom and not (bottom.entity) and bottom

                screenWidth  = Moonpanel.Canvas.Resolution
                screenHeight = Moonpanel.Canvas.Resolution

				ro = socket\GetRenderOrigin!
                isLeftMost = ro.x <= screenWidth  / 2
                isTopMost  = ro.y <= screenHeight / 2

                numNeighbours = (left and 1 or 0) +
                    (right and 1 or 0) +
                    (top and 1 or 0) +
                    (bottom and 1 or 0)

                if numNeighbours == 3
                    if not top
                        return unitVector 180

                    if not bottom
                        return unitVector 0

                    if not left
                        return unitVector 90

                    if not right
                        return unitVector 270

                    return false

                if numNeighbours == 2
                    if top and right
                        return unitVector 45

                    if bottom and right
                        return unitVector 135

                    if left and bottom
                        return unitVector 225

                    if left and top
                        return unitVector 315

                    if left and right
                        return unitVector isTopMost and 180 or 0

                    if top and bottom
                        return unitVector isLeftMost and 90 or 270

                if numNeighbours == 1
                    if bottom
                        return unitVector 180

                    if top
                        return unitVector 0

                    if right
                        return unitVector 270

                    if left
                        return unitVector 90

                return false
            )!

        @__angle

    PopulatePathNodes: (pathNodes) =>
		super pathNodes

        if dir = @CalculateAngle!
            socket = @GetSocket!

			ro = socket\GetRenderOrigin!
            parentNode = socket\GetPathNode!
            barWidth = socket\GetCanvas!\GetBarWidth!

			exitNode = {
                x: parentNode.x + (dir.x) * 0.25
                y: parentNode.y + (dir.y) * 0.25
                screenX: math.Round ro.x + dir.x * barWidth
                screenY: math.Round ro.y + dir.y * barWidth
                neighbors: { parentNode }
                intersection: @parent
                exit: true
            }

            table.insert parentNode.neighbors, exitNode
            exitNode.id = #pathNodes + 1
            table.insert pathNodes, exitNode

            @__exitNode = exitNode

    CleanUpPathNodes: (pathNodes) =>
        if @__exitNode
            socket = @GetSocket!
            parentNode = socket\GetPathNode!

            for i, neighbor in ipairs parentNode.neighbors
                if @__exitNode == neighbor
                    table.remove parentNode.neighbors, i
                    break

            for i, node in ipairs pathNodes
                if node == @__exitNode
                    table.remove pathNodes, i
                    break

class Moonpanel.Canvas.Entities.IntersectionHexagon extends Moonpanel.Canvas.Entities.BaseIntersection
    @CanonicalType = "Hexagon"

    RenderHexagon: (overlay = false) =>
        canvas = @GetCanvas!
        Moonpanel.Canvas.RenderHexagonEntity @,
            Moonpanel.Canvas.GetHexagonSize(canvas), overlay

    RenderBelowTrace: => @RenderHexagon false
    RenderOverlay: => @RenderHexagon true

class Moonpanel.Canvas.Entities.IntersectionInvisible extends Moonpanel.Canvas.Entities.BaseIntersection
    @CanonicalType = "Invisible"

    Render: =>
        return unless CLIENT and @GetCanvas!\GetEditorGeometryVisible!
        socket = @GetSocket!
        origin = socket\GetRenderOrigin!
        size = math.max socket\GetRadius! * 2, 6
        surface.SetDrawColor 0, 0, 0, 80
        surface.DrawRect origin.x - size / 2, origin.y - size / 2, size, size

    PostPopulatePathNodes: =>
        node = @GetSocket!\GetPathNode!
        return unless node

        node.invisible = true
        for neighbor in *node.neighbors
            for i = #neighbor.neighbors, 1, -1
                table.remove neighbor.neighbors, i if neighbor.neighbors[i] == node

        node.neighbors = {}

    CleanUpPathNodes: =>
        node = @GetSocket!\GetPathNode!
        node.invisible = nil if node
