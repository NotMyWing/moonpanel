if SERVER
    AddCSLuaFile!
    AddCSLuaFile "moonpanel/cl_init.lua"

    include "moonpanel/sv_init.lua"

    util.AddNetworkString "TheMP Focus"
    util.AddNetworkString "TheMP Mouse Deltas"
    util.AddNetworkString "TheMP Request Control"
else
    include "moonpanel/cl_init.lua"