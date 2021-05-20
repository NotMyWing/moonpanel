AddCSLuaFile!

class Moonpanel.Canvas.Entities.Start extends Moonpanel.Canvas.Entities.BaseIntersection
	GetRadius: =>
        data = @__canvas\GetData!

        0.5 * 2.5 * Moonpanel.Canvas.Resolution * (data.Dim.BarWidth / 100)

	PopulatePathMap: =>
		@GetPathNode!.clickable = true

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

                left = @GetLeft!
                right = @GetRight!
                top = @GetAbove!
                bottom = @GetBelow!

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

				ro = @GetRenderOrigin!
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

    PopulatePathMap: (pathMap) =>
		super pathMap

        if dir = @CalculateAngle!
			ro = @GetRenderOrigin!
            currentNode = @GetPathNode!
            barWidth = @GetCanvas!\GetBarWidth!

			exitNode = {
                x: currentNode.x + (dir.x) * 0.25
                y: currentNode.y + (dir.y) * 0.25
                screenX: math.Round ro.x + dir.x * barWidth
                screenY: math.Round ro.y + dir.y * barWidth
                neighbors: { currentNode }
                intersection: @parent
                exit: true
            }

            table.insert currentNode.neighbors, exitNode
            table.insert pathMap, exitNode
