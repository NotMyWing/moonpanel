if SERVER then
  AddCSLuaFile()
  AddCSLuaFile("moonpanel/cl_init.lua")
  include("moonpanel/sv_init.lua")
  util.AddNetworkString("TheMP Focus")
  util.AddNetworkString("TheMP Mouse Deltas")
  return util.AddNetworkString("TheMP Request Control")
else
  return include("moonpanel/cl_init.lua")
end
