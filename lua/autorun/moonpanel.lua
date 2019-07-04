if SERVER then
  AddCSLuaFile()
  AddCSLuaFile("moonpanel/shared.lua")
  AddCSLuaFile("moonpanel/cl_init.lua")
  include("moonpanel/shared.lua")
  return include("moonpanel/sv_init.lua")
else
  include("moonpanel/shared.lua")
  include("moonpanel/cl_init.lua")
  local a = a
end
