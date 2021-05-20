_moonpanel = Moonpanel or {}
export Moonpanel = _moonpanel

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
include "sh_focus.lua"
include "sh_control.lua"
include "canvas/sh_canvas.lua"
