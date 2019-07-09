if SERVER
    AddCSLuaFile!
    AddCSLuaFile "moonpanel/shared.lua"
    AddCSLuaFile "moonpanel/cl_init.lua"

    include "moonpanel/shared.lua"
    include "moonpanel/sv_init.lua"

    return
else
    include "moonpanel/shared.lua"
    include "moonpanel/cl_init.lua"

    return