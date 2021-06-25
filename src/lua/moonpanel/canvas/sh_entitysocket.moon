AddCSLuaFile!

Moonpanel.Canvas.Sockets = {}

class Moonpanel.Canvas.Sockets.BaseSocket
    new: (@__canvas, @__id) =>

    __setCoordinates: (width) =>
        data = @__canvas\GetData!

        @__x = ((@__id - 1) % width) + 1
        @__y = math.floor((@__id - 1) / width) + 1

	SetEntity: (entity, postPopulate = true) =>
        pathNodes = @__canvas\GetPathNodes!

        if @__entity
            dirty = true
            @__entity\CleanUpPathNodes pathNodes
            if CLIENT and @__entity.Render
                @__canvas\RemoveRenderable @__entity

        with @__entity = entity or @__class.BaseEntity
            \SetSocket @
            \PopulatePathNodes pathNodes
            \PostPopulatePathNodes pathNodes if postPopulate
            if CLIENT and .Render
                @__canvas\AddRenderable @__entity

        @__canvas\RebuildPathFinderCache!

	GetEntity: => @__entity

    GetCanvas: => @__canvas

    SetY: (@__y) =>
    GetY: => @__y

    SetX: (@__x) =>
    GetX: => @__x

    GetSocketType: => @__class.SocketType

    IsTraced: => @__canvas\IsTraced @

class Moonpanel.Canvas.Sockets.IntersectionSocket extends Moonpanel.Canvas.Sockets.BaseSocket
    @SocketType = Moonpanel.Canvas.SocketType.Intersection
    @BaseEntity = Moonpanel.Canvas.Entities.BaseIntersection

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

    GetAbove: => @__canvas\GetVPathSocketAt @__x     , @__y - 1
    GetBelow: => @__canvas\GetVPathSocketAt @__x     , @__y
    GetLeft:  => @__canvas\GetHPathSocketAt @__x - 1 , @__y
    GetRight: => @__canvas\GetHPathSocketAt @__x     , @__y

    GetRadius: =>
        data = @__canvas\GetData!

        return 0.5 * 1.5 * Moonpanel.Canvas.Resolution * (data.Dim.BarWidth / 100)

    CanClick: (x, y) =>
        ro = @GetRenderOrigin!
        distSqr = (x - ro.x)^2 + (y - ro.y)^2

        radius = @GetRadius!

        return radius * radius > distSqr

class Moonpanel.Canvas.Sockets.CellSocket extends Moonpanel.Canvas.Sockets.BaseSocket
    @SocketType = Moonpanel.Canvas.SocketType.Cell
    @BaseEntity = Moonpanel.Canvas.Entities.BaseCell

    new: (canvas, id) =>
        super canvas, id

        data = canvas\GetData!
        @__setCoordinates data.Meta.Width

    GetRenderOrigin: =>
        return @__cachedRenderOrigin if @__cachedRenderOrigin

        left = @GetLeft!\GetRenderOrigin!
        right = @GetRight!\GetRenderOrigin!

        @__cachedRenderOrigin = (left + right) / 2
        @__cachedRenderOrigin

    GetAbove: => @__canvas\GetHPathSocketAt @__x     , @__y
    GetBelow: => @__canvas\GetHPathSocketAt @__x     , @__y + 1
    GetLeft:  => @__canvas\GetVPathSocketAt @__x     , @__y
    GetRight: => @__canvas\GetVPathSocketAt @__x + 1 , @__y

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

class Moonpanel.Canvas.Sockets.PathSocket extends Moonpanel.Canvas.Sockets.BaseSocket
    @SocketType = Moonpanel.Canvas.SocketType.Path
    @BaseEntity = Moonpanel.Canvas.Entities.BasePath

    SetHorizontal: (@__horizontal) =>
        data = @__canvas\GetData!
        @__setCoordinates data.Meta.Width + (@__horizontal and 0 or 1)

    IsHorizontal: => @__horizontal
    IsVertical: => not @__horizontal

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
            @__canvas\GetCellSocketAt @__x, @__y - 1
        else
            @__canvas\GetIntersectionSocketAt @__x, @__y

    GetBelow: =>
        if @__horizontal
            @__canvas\GetCellSocketAt @__x, @__y
        else
            @__canvas\GetIntersectionSocketAt @__x, @__y + 1

    GetLeft: =>
        if @__horizontal
            @__canvas\GetIntersectionSocketAt @__x, @__y
        else
            @__canvas\GetCellSocketAt @__x - 1, @__y

    GetRight: =>
        if @__horizontal
            @__canvas\GetIntersectionSocketAt @__x + 1, @__y
        else
            @__canvas\GetCellSocketAt @__x, @__y

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
