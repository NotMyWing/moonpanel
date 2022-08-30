if SERVER
    include "moonpanel/sv_resources.lua"

    -- AddCSLuaFile does not follow include statements. Walk the addon Lua
    -- namespaces so newly added client/shared modules cannot be omitted from
    -- the download cache merely because their parent included them.
    addClientLua = (directory) ->
        files, directories = file.Find directory .. "/*", "LUA"
        return unless files or directories

        for name in *(files or {})
            lower = string.lower name
            eligible = string.StartWith(lower, "cl_") or
                string.StartWith(lower, "sh_") or
                lower == "shared.lua" or lower == "cl_init.lua" or
                directory == "weapons/gmod_tool/stools"
            AddCSLuaFile directory .. "/" .. name if eligible and
                string.GetExtensionFromFilename(name) == "lua"

        for name in *(directories or {})
            addClientLua directory .. "/" .. name

    addClientLua "moonpanel"
    AddCSLuaFile "entities/moonpanel/cl_init.lua"
    AddCSLuaFile "entities/moonpanel/shared.lua"
    AddCSLuaFile "entities/moonpanel_pillar/cl_init.lua"
    AddCSLuaFile "entities/moonpanel_pillar/shared.lua"
    AddCSLuaFile "weapons/gmod_tool/stools/moonpanel.lua"
    AddCSLuaFile "weapons/gmod_tool/stools/moonpanel_pillar.lua"
    AddCSLuaFile!
    AddCSLuaFile "moonpanel/shared.lua"
    AddCSLuaFile "moonpanel/cl_init.lua"
    AddCSLuaFile "moonpanel/cl_debug.lua"

    include "moonpanel/shared.lua"

    return
else
    include "moonpanel/shared.lua"
    include "moonpanel/cl_init.lua"
