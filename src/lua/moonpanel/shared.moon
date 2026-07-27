_moonpanel = Moonpanel or {}
export Moonpanel = _moonpanel

AddCSLuaFile "canvas/sh_helpers.lua"
AddCSLuaFile "canvas/editor/cl_helpers.lua"
include "canvas/sh_helpers.lua"
include "canvas/editor/cl_helpers.lua" if CLIENT

Moonpanel.Data or= {}

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

class Rect
    new: (@x, @y, @width, @height) =>
    Contains: (x, y) =>
        return x > @x and
            y > @y and
            x < @x + @width and
            y < @y + @height

Moonpanel.Rect = Rect

include "sh_net.lua"
include "sh_trace_session.lua"
include "sh_focus.lua"
include "sh_control.lua"
include "canvas/sh_canvas.lua"
include "sh_pillar_controller.lua"
