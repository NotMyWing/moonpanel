--@include moonpanel/core/cl_moonpanel.txt
--@include moonpanel/core/sv_moonpanel.txt

Tile = if CLIENT
    require "moonpanel/core/cl_moonpanel.txt"
else
    require "moonpanel/core/sv_moonpanel.txt"

return Tile!