AddCSLuaFile!

Moonpanel.Canvas.Entities = {}

class Moonpanel.Canvas.Entities.BaseEntity
    SetSocket: (@__socket) =>
    GetSocket: => @__socket

    GetCanvas: => @__socket\GetCanvas!

    PopulatePathNodes: =>
    CleanUpPathNodes: =>

    ImportData: =>
    ExportData: =>

    CanClick: =>

    GetSocketType: => @__class.SocketType

class Moonpanel.Canvas.Entities.BaseIntersection extends Moonpanel.Canvas.Entities.BaseEntity
    @SocketType = Moonpanel.Canvas.SocketType.Intersection

    SetPathNode: (@__pathNode) =>
    GetPathNode: => @__pathNode

    ExportData: =>
        className = @__class.__name
        if className ~= "BaseIntersection"
            { Type: className }

class Moonpanel.Canvas.Entities.BaseCell extends Moonpanel.Canvas.Entities.BaseEntity
    @SocketType = Moonpanel.Canvas.SocketType.Cell

    ExportData: =>
        className = @__class.__name
        if className ~= "BaseCell"
            { Type: className }

class Moonpanel.Canvas.Entities.BasePath extends Moonpanel.Canvas.Entities.BaseEntity
    @SocketType = Moonpanel.Canvas.SocketType.Path

    ExportData: =>
        className = @__class.__name
        if className ~= "BasePath"
            { Type: className }

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

            @__link =
                nodeA: nodeB
                nodeB: nodeA

    CleanUpPathNodes: =>
        if @__link
            for node, otherNode in pairs @__link
                for i, neighbor in ipairs node.neighbors
                    if node == neighbor
                        table.remove node.neighbors, i
                        break

include "entities/sh_intersections.lua"
