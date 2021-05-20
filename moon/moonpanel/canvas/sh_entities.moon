AddCSLuaFile!

Moonpanel.Canvas.Entities = {}

class Moonpanel.Canvas.Entities.BaseEntity
    new: (@__canvas, @__id) =>

    __setCoordinates: (width) =>
        data = @__canvas\GetData!

        @__x = ((@__id - 1) % width) + 1
        @__y = math.floor((@__id - 1) / width) + 1

    PopulatePathMap: =>

    GetCanvas: => @__canvas

    GetAbove: =>
    GetBelow: =>
    GetLeft: =>
    GetRight: =>

    SetY: (@__y) =>
    GetY: => @__y

    SetX: (@__x) =>
    GetX: => @__x

    ImportData: =>
    ExportData: =>

    CanClick: =>

    GetHandlerType: => @__class.HandlerType

class Moonpanel.Canvas.Entities.BaseIntersection extends Moonpanel.Canvas.Entities.BaseEntity
    @HandlerType = Moonpanel.Canvas.HandlerType.Intersection

    new: (canvas, id) =>
        super canvas, id

        data = canvas\GetData!
        @__setCoordinates data.Meta.Width + 1

    SetPathNode: (@__pathNode) =>
    GetPathNode: => @__pathNode

    ExportData: =>
        className = @__class.__name
        if className ~= "BaseIntersection"
            { Type: className }

    GetRenderOrigin: =>
        return @__cachedRenderOrigin if @__cachedRenderOrigin

        node = @GetPathNode!

        @__cachedRenderOrigin = Vector node.screenX, node.screenY
        @__cachedRenderOrigin

    GetAbove: => @__canvas\GetVPathAt @__x     , @__y - 1
    GetBelow: => @__canvas\GetVPathAt @__x     , @__y
    GetLeft:  => @__canvas\GetHPathAt @__x - 1 , @__y
    GetRight: => @__canvas\GetHPathAt @__x     , @__y

    GetRadius: =>
        data = @__canvas\GetData!

        return 0.5 * 1.5 * Moonpanel.Canvas.Resolution * (data.Dim.BarWidth / 100)

    CanClick: (x, y) =>
        ro = @GetRenderOrigin!
        distSqr = (x - ro.x)^2 + (y - ro.y)^2

        radius = @GetRadius!

        return radius * radius > distSqr

class Moonpanel.Canvas.Entities.BaseCell extends Moonpanel.Canvas.Entities.BaseEntity
    @HandlerType = Moonpanel.Canvas.HandlerType.Cell

    new: (canvas, id) =>
        super canvas, id

        data = canvas\GetData!
        @__setCoordinates data.Meta.Width

    ExportData: =>
        className = @__class.__name
        if className ~= "BaseCell"
            { Type: className }

    GetRenderOrigin: =>
        return @__cachedRenderOrigin if @__cachedRenderOrigin

        left = @GetLeft!\GetRenderOrigin!
        right = @GetRight!\GetRenderOrigin!

        @__cachedRenderOrigin = (left + right) / 2
        @__cachedRenderOrigin

    GetAbove: => @__canvas\GetHPathAt @__x     , @__y
    GetBelow: => @__canvas\GetHPathAt @__x     , @__y + 1
    GetLeft:  => @__canvas\GetVPathAt @__x     , @__y
    GetRight: => @__canvas\GetVPathAt @__x + 1 , @__y

    GetHitBox: =>
        return @__cachedHitBox if @__cachedHitBox

        ro = @GetRenderOrigin!
        data = @__canvas\GetData!

        barLength = @GetCanvas!\GetBarLength!
        barWidth = @GetCanvas!\GetBarWidth!

        size = barLength - barWidth
        @__cachedHitBox = Moonpanel.Rect ro.x - size/2, ro.y - size/2,
            size, size

        @__cachedHitBox

    CanClick: (x, y) =>
        return @GetHitBox!\Contains x, y

class Moonpanel.Canvas.Entities.BasePath extends Moonpanel.Canvas.Entities.BaseEntity
    @HandlerType = Moonpanel.Canvas.HandlerType.Path

    ExportData: =>
        className = @__class.__name
        if className ~= "BasePath"
            { Type: className }

    SetHorizontal: (@__horizontal) =>
        data = @__canvas\GetData!
        @__setCoordinates data.Meta.Width + (@__horizontal and 0 or 1)

    IsHorizontal: => @__horizontal
    IsVertical: => not @__horizontal

    PopulatePathMap: =>
        local intA, intB
        if @__horizontal
            intA = @GetLeft!
            intB = @GetRight!
        else
            intA = @GetAbove!
            intB = @GetBelow!

        if intA and intB
            nodeA = intA\GetPathNode!
            nodeB = intB\GetPathNode!

            table.insert nodeA.neighbors, nodeB
            table.insert nodeB.neighbors, nodeA

    GetRenderOrigin: =>
        return @__cachedRenderOrigin if @__cachedRenderOrigin

        nodeA, nodeB = if @__horizontal
            @GetLeft!, @GetRight!
        else
            @GetAbove!, @GetBelow!

        @__cachedRenderOrigin = (nodeA\GetRenderOrigin! + nodeB\GetRenderOrigin!) / 2
        @__cachedRenderOrigin

    GetAbove: =>
        if @__horizontal
            @__canvas\GetCellAt @__x, @__y - 1
        else
            @__canvas\GetIntersectionAt @__x, @__y

    GetBelow: =>
        if @__horizontal
            @__canvas\GetCellAt @__x, @__y
        else
            @__canvas\GetIntersectionAt @__x, @__y + 1

    GetLeft: =>
        if @__horizontal
            @__canvas\GetIntersectionAt @__x, @__y
        else
            @__canvas\GetCellAt @__x, @__y

    GetRight: =>
        if @__horizontal
            @__canvas\GetIntersectionAt @__x + 1, @__y
        else
            @__canvas\GetCellAt @__x + 1, @__y

    GetHitBox: =>
        return @__cachedHitBox if @__cachedHitBox

        ro = @GetRenderOrigin!
        data = @__canvas\GetData!

        barLength = @GetCanvas!\GetBarLength!
        barWidth = @GetCanvas!\GetBarWidth!

        @__cachedHitBox = Moonpanel.Rect if @__horizontal
            ro.x - barLength/2, ro.y - barWidth/2, barLength, barWidth
        else
            ro.x - barWidth/2, ro.y - barLength/2, barWidth, barLength

        @__cachedHitBox

    CanClick: (x, y) =>
        return @GetHitBox!\Contains x, y

include "entities/sh_intersections.lua"
