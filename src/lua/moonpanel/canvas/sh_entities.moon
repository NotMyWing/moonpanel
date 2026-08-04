AddCSLuaFile!

Moonpanel.Canvas.Entities = {}

class Moonpanel.Canvas.Entities.BaseEntity
    SetSocket: (@__socket) =>
    GetSocket: => @__socket

    GetCanvas: => @__socket\GetCanvas!

	PostPopulatePathNodes: =>
	PopulatePathNodes: =>
	CleanUpPathNodes: =>

	ImportData: (data = {}) =>
		@__data = table.Copy data

	GetData: => @__data or {}

	ExportEntityData: =>
		table.Copy @GetData!

	ExportData: =>
		return if @IsBase!

		data = @ExportEntityData!
		out = { Type: @__class.CanonicalType or @__class.__name }
		out.Data = data if data and table.Count(data) > 0
		out

	CanClick: =>

	GetSocketType: => @__class.SocketType
	IsBase: => @__class.__name == "BaseEntity"

class Moonpanel.Canvas.Entities.BaseIntersection extends Moonpanel.Canvas.Entities.BaseEntity
    @SocketType = Moonpanel.Canvas.SocketType.Intersection

    SetPathNode: (@__pathNode) =>
    GetPathNode: => @__pathNode

	IsBase: => @__class.__name == "BaseIntersection"

class Moonpanel.Canvas.Entities.BaseCell extends Moonpanel.Canvas.Entities.BaseEntity
    @SocketType = Moonpanel.Canvas.SocketType.Cell

	IsBase: => @__class.__name == "BaseCell"

class Moonpanel.Canvas.Entities.BasePath extends Moonpanel.Canvas.Entities.BaseEntity
    @SocketType = Moonpanel.Canvas.SocketType.Path

	IsHorizontal: => @__socket\IsHorizontal!

    PopulatePathNodes: =>
        socket = @GetSocket!

        local intA, intB
        if @IsHorizontal!
            intA = socket\GetLeft!
            intB = socket\GetRight!
        else
            intA = socket\GetAbove!
            intB = socket\GetBelow!

        if intA and intB
            nodeA = intA\GetPathNode!
            nodeB = intB\GetPathNode!

            table.insert nodeA.neighbors, nodeB
            table.insert nodeB.neighbors, nodeA

            @__link = {
                { nodeA, nodeB }
                { nodeB, nodeA }
            }

	CleanUpPathNodes: =>
		if @__link
			for link in *@__link
				node, otherNode = link[1], link[2]
				continue unless node and node.neighbors

				for i, neighbor in ipairs node.neighbors
					if otherNode == neighbor
						table.remove node.neighbors, i
						break

	IsBase: => @__class.__name == "BasePath"

MAT_HEXAGON = nil
MAT_HEXAGON_HOLLOW = nil
if CLIENT
	MAT_HEXAGON = Material "moonpanel/common/hexagon.png"
	MAT_HEXAGON_HOLLOW = Material "moonpanel/common/hexagon_hollow.png"

Moonpanel.Canvas.GetHexagonSize = (canvas) ->
	-- Use the resolved geometry width, not the authored percentage. Auto-sized
	-- panels and manually-sized panels must produce the same dot proportions,
	-- and both path/intersection hexagons must share this single measurement.
	canvas\GetBarWidth! * 0.95

Moonpanel.Canvas.RenderHexagonEntity = (entity, size, overlay = false) ->
	return unless CLIENT

	socket = entity\GetSocket!
	canvas = socket\GetCanvas!
	data = entity\GetData!
	return if data.Invisible and not canvas\GetEditorGeometryVisible!
	dynamic = canvas\HasDynamicEntityStyle socket
	return if dynamic ~= overlay
	ro = socket\GetRenderOrigin!
	colorId = Moonpanel.Canvas.GetClueTintColor data, Moonpanel.Color.Black
	color = Moonpanel.Canvas.ColorValues[colorId] or
		Moonpanel.Canvas.ColorValues[Moonpanel.Color.Black]

	r, g, b, a = canvas\ApplyEntityVisualColor color, socket
	surface.SetDrawColor r, g, b, a
	surface.SetMaterial data.Negative and MAT_HEXAGON_HOLLOW or MAT_HEXAGON
	surface.DrawTexturedRect ro.x - size / 2, ro.y - size / 2, size, size
	if data.Invisible
		Moonpanel.Canvas.DrawEditorInvisibleMarker ro.x, ro.y,
			math.max(28, size * 0.62), size

Moonpanel.Canvas.DrawEditorInvisibleMarker = (x, y, size, anchorSize) ->
	return unless CLIENT
	if anchorSize
		direction = x <= (Moonpanel.Canvas.Resolution or 512) / 2 and 1 or -1
		x += direction * (anchorSize / 2 + size / 2 + 3)
	radius = size * 0.48
	segments = {
		{ x - radius, y, x, y - radius * 0.62 }
		{ x, y - radius * 0.62, x + radius, y }
		{ x + radius, y, x, y + radius * 0.62 }
		{ x, y + radius * 0.62, x - radius, y }
		{ x - radius * 0.88, y + radius * 0.88,
			x + radius * 0.88, y - radius * 0.88 }
	}
	drawSegments = (color, width) ->
		surface.SetDrawColor color
		for segment in *segments
			for offset = -math.floor(width / 2), math.floor(width / 2)
				surface.DrawLine segment[1] + offset, segment[2],
					segment[3] + offset, segment[4]
	drawSegments Color(12, 16, 22, 245), 5
	drawSegments Color(71, 192, 235, 255), 2

include "entities/sh_intersections.lua"
include "entities/sh_cells.lua"
include "entities/sh_paths.lua"

Moonpanel.Canvas.EntityRegistry = {
	Start: {
		[Moonpanel.Canvas.SocketType.Intersection]: Moonpanel.Canvas.Entities.Start
		[Moonpanel.Canvas.SocketType.Path]: Moonpanel.Canvas.Entities.PathStart
	}
	End: {
		[Moonpanel.Canvas.SocketType.Intersection]: Moonpanel.Canvas.Entities.End
		[Moonpanel.Canvas.SocketType.Path]: Moonpanel.Canvas.Entities.PathEnd
	}
	Color: {
		[Moonpanel.Canvas.SocketType.Cell]: Moonpanel.Canvas.Entities.Color
	}
	Sun: {
		[Moonpanel.Canvas.SocketType.Cell]: Moonpanel.Canvas.Entities.Sun
	}
	Eraser: {
		[Moonpanel.Canvas.SocketType.Cell]: Moonpanel.Canvas.Entities.Eraser
	}
	Triangle: {
		[Moonpanel.Canvas.SocketType.Cell]: Moonpanel.Canvas.Entities.Triangle
	}
	Polyomino: {
		[Moonpanel.Canvas.SocketType.Cell]: Moonpanel.Canvas.Entities.Polyomino
	}
	Hexagon: {
		[Moonpanel.Canvas.SocketType.Intersection]: Moonpanel.Canvas.Entities.IntersectionHexagon
		[Moonpanel.Canvas.SocketType.Path]: Moonpanel.Canvas.Entities.PathHexagon
	}
	Disjoint: {
		[Moonpanel.Canvas.SocketType.Path]: Moonpanel.Canvas.Entities.Disjoint
	}
	Invisible: {
		[Moonpanel.Canvas.SocketType.Intersection]: Moonpanel.Canvas.Entities.IntersectionInvisible
		[Moonpanel.Canvas.SocketType.Path]: Moonpanel.Canvas.Entities.InvisiblePath
		[Moonpanel.Canvas.SocketType.Cell]: Moonpanel.Canvas.Entities.CellInvisible
	}
}

Moonpanel.Canvas.GetEntityClass = (typeName, socketType) ->
	return unless typeName and socketType

	bySocket = Moonpanel.Canvas.EntityRegistry[typeName]
	bySocket and bySocket[socketType]

Moonpanel.Canvas.SetSocketEntityData = (socket, typeName, data = {}) ->
	return unless socket

	entityClass = Moonpanel.Canvas.GetEntityClass typeName, socket\GetSocketType!
	if not entityClass
		return false

	entity = entityClass!
	entity\ImportData data
	socket\SetEntity entity
	true
