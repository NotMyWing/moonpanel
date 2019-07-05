_moonpanel = Moonpanel or {}
export Moonpanel = _moonpanel

export MOONPANEL_ENTITY_TYPES = {
    NONE: 0
    START: 1
    END: 2
    HEXAGON: 3
    TRIANGLE: 4
    POLYOMINO: 5
    SUN: 6
    ERASER: 7
    COLOR: 8
    DISJOINT: 9
}

export MOONPANEL_OBJECT_TYPES = {
    NONE: 0
    CELL: 1
    VPATH: 2
    HPATH: 3
    INTERSECTION: 4
}

export MOONPANEL_DEFAULT_RESOLUTIONS = {
    {
        innerScreenRatio: 1
        barWidth: 0.05
    }
    {
        innerScreenRatio: 0.95
        barWidth: 0.04
    }
    {
        innerScreenRatio: 0.925
        barWidth: 0.04
    }
    {
        innerScreenRatio: 0.9
        barWidth: 0.04
    }
    {
        innerScreenRatio: 0.9
        barWidth: 0.04
    }
    {
        innerScreenRatio: 0.95
        barWidth: 0.03
    }
    {
        innerScreenRatio: 0.97
        barWidth: 0.03
    }
    {
        innerScreenRatio: 0.98
        barWidth: 0.02
    }
    {
        innerScreenRatio: 0.98
        barWidth: 0.02
    }
    {
        innerScreenRatio: 0.98
        barWidth: 0.02
    }
}

export MOONPANEL_DEFAULTEST_RESOLUTION = {
    innerScreenRatio: 0.875
    barWidth: 0.025
}

net.Receive "TheMP EditorData", (len, ply) ->
    pending = nil
    if SERVER
        pendingEditorData = Moonpanel.pendingEditorData

        for k, v in pairs pendingEditorData
            if v.player == ply
                pending = v
                break

        if not pending
            return

        for i = 1, #pendingEditorData
            if pendingEditorData[i] == pending
                table.remove pendingEditorData, i
                break

        timer.Remove pending.timer

    length = net.ReadUInt 32
    raw = net.ReadData length

    if SERVER
        pending.callback raw, length
    else
        data = util.JSONToTable((util.Decompress raw) or "{}") or {}

        ent = net.ReadEntity!

        if (IsValid ent) and ent.SetupData
            ent\SetupData data

-------------
-- Globals --
-------------

Moonpanel.Color = {
    Black: 1
    White: 2
    Cyan: 3
    Magenta: 4
    Yellow: 5
    Red: 6
    Green: 7
    Blue: 8
    Orange: 9
}

Moonpanel.Colors = {
    [Moonpanel.Color.Black]: Color 0, 0, 0 
    [Moonpanel.Color.White]: Color 255, 255, 255
    [Moonpanel.Color.Cyan]: Color 0, 255, 255
    [Moonpanel.Color.Magenta]: Color 255, 0, 255
    [Moonpanel.Color.Yellow]: Color 255, 255, 0
    [Moonpanel.Color.Red]: Color 255, 0, 0
    [Moonpanel.Color.Green]: Color 0, 128, 0
    [Moonpanel.Color.Blue]: Color 0, 0, 255
    [Moonpanel.Color.Orange]: Color 255, 160, 0
}

Moonpanel.DefaultColors = {
    Background: Color 80, 77, 255, 255
    Untraced: Color 40, 22, 186
    Traced: Color 255, 255, 255, 255
    Vignette: Color 0, 0, 0, 92
}

--------------
-- Includes --
--------------

include "moonpanel/panel/sh_elements.lua"
include "moonpanel/panel/ents/sh_cell.lua"
include "moonpanel/panel/ents/sh_intersection.lua"
include "moonpanel/panel/ents/sh_path.lua"
 
---------------------------
-- Moonpanel definitions --
---------------------------

class Rect
    new: (@x, @y, @width, @height) =>
    contains: (x, y) =>
        return x > @x and
            y > @y and
            x < @x + @width and
            y < @y + @height

Moonpanel.Rect = Rect

Moonpanel.calculateDimensionsShared = (data) =>
    cellsW = data.cellsW or 2
    cellsH = data.cellsH or 2

    w, h = data.screenW, data.screenH

    maxCellDimension = math.max cellsW, cellsH
    minCellDimension = math.min cellsW, cellsH

    resolution = MOONPANEL_DEFAULT_RESOLUTIONS[maxCellDimension] or MOONPANEL_DEFAULTEST_RESOLUTION

    minPanelDimension = (math.min w, h) * (data.innerScreenRatio or resolution.innerScreenRatio)

    barWidth = (data.barWidth or resolution.barWidth) * minPanelDimension

    barLength = math.ceil (minPanelDimension - (barWidth * (maxCellDimension + 1))) / maxCellDimension
    barLength = math.ceil barLength - (barWidth / (math.max cellsW, cellsH))
    barLength = math.min barLength, minPanelDimension * (data.maxBarLength or 0.25)

    innerHeight = barWidth * (cellsH + 1) + barLength * (cellsH)
    innerWidth = barWidth * (cellsW + 1) + barLength * (cellsW)

    return {
        barWidth: math.floor barWidth
        barLength: math.floor barLength
        innerWidth: math.floor innerWidth
        innerHeight: math.floor innerHeight
    }