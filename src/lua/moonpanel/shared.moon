_moonpanel = Moonpanel or {}
export Moonpanel = _moonpanel

AddCSLuaFile "canvas/sh_helpers.lua"
AddCSLuaFile "canvas/editor/cl_helpers.lua"
AddCSLuaFile "sh_colors.lua"
include "sh_colors.lua"
include "canvas/sh_helpers.lua"
include "canvas/editor/cl_helpers.lua" if CLIENT

Moonpanel.Data or= {}

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
