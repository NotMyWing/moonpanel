_moonpanel = Moonpanel or {}
export Moonpanel = _moonpanel

export MOONPANEL_DEFAULT_RESOLUTIONS = {
    {
        innerScreenRatio: 0.8
        barWidth: 0.055
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.05
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.05
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.05
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.04
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.03
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.03
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.02
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.02
    }
    {
        innerScreenRatio: 0.8
        barWidth: 0.02
    }
}

export MOONPANEL_DEFAULTEST_RESOLUTION = {
    innerScreenRatio: 0.875
    barWidth: 0.025
}

-------------
-- Globals --
-------------

Moonpanel.EntityTypes = {
    None:               0
    Start:              1
    End:                2
    Hexagon:            3
    Triangle:           4
    Polyomino:          5
    Sun:                6
    Eraser:             7
    Color:              8
    Disjoint:           9
    Invisible:         10
}

Moonpanel.ObjectTypes = {
    None:         0
    Cell:         1
    VPath:        2
    HPath:        3
    Intersection: 4
}

Moonpanel.Symmetry = {
    None:       0
    Rotational: 1
    Vertical:   2
    Horizontal: 3
}

Moonpanel.PanelState = {
    None:      1
    BeingUsed: 2
    Finished:  3
}

Moonpanel.Flow = {
    ApplyDeltas:    1
    PanelData:      2
    PuzzleFinish:   3
    PuzzleStart:    4
    RequestControl: 5
    RequestData:    6
    Desync:         7
}

Moonpanel.FlowSize = math.ceil(math.log(table.Count(Moonpanel.Flow), 2))

Moonpanel.Color = {
    Black:   1
    White:   2
    Cyan:    3
    Magenta: 4
    Yellow:  5
    Red:     6
    Green:   7
    Blue:    8
    Orange:  9
}

Moonpanel.TheWindmill_EntityTypes = {
    [3]:  Moonpanel.EntityTypes.Start
    [4]:  Moonpanel.EntityTypes.End
    [5]:  Moonpanel.EntityTypes.Disjoint
    [6]:  Moonpanel.EntityTypes.Hexagon
    [7]:  Moonpanel.EntityTypes.Color
    [8]:  Moonpanel.EntityTypes.Sun
    [9]:  Moonpanel.EntityTypes.Polyomino
    [10]: Moonpanel.EntityTypes.Eraser
    [11]: Moonpanel.EntityTypes.Triangle
}

Moonpanel.TheWindmill_SymmetryTypes = {
    [0]: Moonpanel.Symmetry.None
    [1]: Moonpanel.Symmetry.None
    [2]: Moonpanel.Symmetry.Horizontal
    [3]: Moonpanel.Symmetry.Vertical
    [4]: Moonpanel.Symmetry.Rotational
}

Moonpanel.DefaultEntityColors = {
    [Moonpanel.EntityTypes.Color]:     Moonpanel.Color.Black
    [Moonpanel.EntityTypes.Hexagon]:   Moonpanel.Color.Black
    [Moonpanel.EntityTypes.Triangle]:  Moonpanel.Color.Orange
    [Moonpanel.EntityTypes.Polyomino]: Moonpanel.Color.Yellow
    [Moonpanel.EntityTypes.Eraser]:    Moonpanel.Color.White
    [Moonpanel.EntityTypes.Sun]:       Moonpanel.Color.White
}

Moonpanel.Colors = {
    [Moonpanel.Color.Black]:   Color 0   , 0   , 0 
    [Moonpanel.Color.White]:   Color 255 , 255 , 255
    [Moonpanel.Color.Cyan]:    Color 0   , 255 , 255
    [Moonpanel.Color.Magenta]: Color 255 , 0   , 255
    [Moonpanel.Color.Yellow]:  Color 255 , 255 , 0
    [Moonpanel.Color.Red]:     Color 255 , 0   , 0
    [Moonpanel.Color.Green]:   Color 0   , 128 , 0
    [Moonpanel.Color.Blue]:    Color 0   , 0   , 255
    [Moonpanel.Color.Orange]:  Color 255 , 160 , 0
}

Moonpanel.DefaultColors = {
    Background: Color 80  , 77  , 255 , 255
    Untraced:   Color 40  , 22  , 186 , 255
    Traced:     Color 200 , 235 , 255 , 255
    Finished:   Color 110 , 170 , 255 , 255
    Vignette:   Color 255 , 255 , 255 , 200
    Errored:    Color 0   , 0   , 0   , 255
    Cell:       Color 0   , 0   , 0   , 0
}

Moonpanel.ColorfulSymmetryDefaultColors = {
    [1]: Moonpanel.Color.Cyan
    [2]: Moonpanel.Color.Orange
}

mulColor = (c, mod) ->
    Color math.floor(math.Clamp(c.r * mod, 0, 255)),
        math.floor(math.Clamp(c.g * mod, 0, 255)),
        math.floor(math.Clamp(c.b * mod, 0, 255)),
        c.a
        
Moonpanel.ColorfulSymmetryEndColors = {}
for i = 1, table.Count Moonpanel.Color
    h, s, v = Moonpanel.Colors[i]\ToHSV!
    Moonpanel.ColorfulSymmetryEndColors[i] = HSVToColor h, s, v * 0.8

Moonpanel.Presets = {
    ["Default"]: {
        Background: Moonpanel.DefaultColors.Background
        Untraced:   Moonpanel.DefaultColors.Untraced
        Traced:     Moonpanel.DefaultColors.Traced
        Finished:   Moonpanel.DefaultColors.Finished
        Vignette:   Moonpanel.DefaultColors.Vignette
        Errored:    Moonpanel.DefaultColors.Errored
        Cell:       Moonpanel.DefaultColors.Cell
    }
    ["The Challenge Triangles"]: {
        Background: Color 30  , 30  , 30 , 255
        Traced:     Color 250 , 160 , 10 , 255
        Untraced:   Color 125 , 110 , 50 , 255
    }
    ["The Quarry Gray"]: {
        Background: Color 70  , 70  , 70  , 255
        Traced:     Color 255 , 255 , 255 , 255
        Untraced:   Color 90  , 140 , 130 , 255
        Cell:       Color 0   , 0   , 0   , 255
    }
    ["The Windmill"]: {
        Background: Color 112 , 128 , 144 , 255
        Traced:     Color 220 , 220 , 220 , 255
        Untraced:   Color 0   , 0   , 0   , 255
        Finished:   Color 230 , 230 , 230 , 255
        Errored:    Color 220 , 64  , 64  , 255
    }
}

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

import rshift, lshift, band, bor, bnot from (bit or bit32 or require "bit")

class BitMatrix
    new: (@w, @h) =>
        @rows = {}
        for j = 1, @h
            @rows[j] = 0

    popcount: (x) =>
        x = band(x, 0x55555555) + band(rshift(x, 1),  0x55555555)
        x = band(x, 0x33333333) + band(rshift(x, 2),  0x33333333)
        x = band(x, 0x0F0F0F0F) + band(rshift(x, 4),  0x0F0F0F0F)
        x = band(x, 0x00FF00FF) + band(rshift(x, 8),  0x00FF00FF)
        x = band(x, 0x0000FFFF) + band(rshift(x, 16), 0x0000FFFF)
        return x

    compare: (other) =>
        if other.w ~= @w or other.h ~= @h
            return false

        for row = 1, @h
            if other.rows[row] ~= @rows[row]
                return false
        
        return true

    set: (i, j, value) =>
        mask = lshift 1, i - 1
        if value ~= 0 and value ~= false
            @rows[j] = bor @rows[j], mask
        else
            @rows[j] = band @rows[j], bnot mask

    get: (i, j) =>
        return band(@rows[j], (lshift 1, i - 1)) ~= 0

    print: () =>
        print "---"
        
        for j, row in pairs @rows
            str = "["
            for i = 1, @w
                str ..= (band(row, (lshift 1, i - 1)) ~= 0) and 1 or 0
                if i ~= @w
                    str ..= ", "
            print str .. "]"

    fromNested: (nested) ->
        w = #nested[1]
        h = #nested
        m = BitMatrix w, h
        for j = 1, h
            for i = 1, w
                m\set i, j, nested[j][i]
        return m

    countOnes: () =>
        count = 0
        for j, row in pairs @rows
            count += @popcount row
        return count

    isZero: () =>
        for k, v in pairs @rows
            if v ~= 0
                return false
        return true

    rotate: (n) =>
        n = n % 4
        if n == 0
            return @
        
        w = (n == 2) and @w or @h
        h = (n == 2) and @h or @w

        newMatrix = BitMatrix w, h
        for y = 1, h
            for x = 1, w
                if n == 1
                    newMatrix\set x, y, @get y, w + 1 - x
                if n == 2
                    newMatrix\set x, y, @get w + 1 - x, h + 1 - y
                if n == 3
                    newMatrix\set x, y, @get h + 1 - y, x

        return newMatrix

Moonpanel.BitMatrix = BitMatrix

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
        screenWidth:  w
        screenHeight: h
        barWidth:     math.floor barWidth
        barLength:    math.floor barLength
        innerWidth:   math.floor innerWidth
        innerHeight:  math.floor innerHeight

        barCircle: if CLIENT
            with circle = draw.NewCircle CIRCLE_FILLED
                \SetPos 0, 0
                \SetRadius math.floor barWidth / 2

        startCircle: if CLIENT
            with circle = draw.NewCircle CIRCLE_FILLED
                \SetPos 0, 0
                \SetRadius math.floor barWidth * 1.25 
    }

Moonpanel.trunc = (num, n) ->
    mult = 10^(n or 0)
    return math.floor(num * mult + 0.5) / mult

--------------
-- Includes --
--------------

if CLIENT
    include "moonpanel/cl_circles.lua"

include "moonpanel/panel/sh_pathfinder.lua"
include "moonpanel/panel/sh_elements.lua"
include "moonpanel/panel/ents/sh_cell.lua"
include "moonpanel/panel/ents/sh_intersection.lua"
include "moonpanel/panel/ents/sh_path.lua"