AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
local SOUND_PANEL_ABORT = Sound("moonpanel/panel_abort_tracing.ogg")
local SOUND_PANEL_START = Sound("moonpanel/panel_start_tracing.ogg")
local SOUND_PANEL_SCINT = Sound("moonpanel/panel_scint.ogg")
ENT.Initialize = function(self)
  self.BaseClass.Initialize(self)
  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetMoveType(MOVETYPE_VPHYSICS)
  self:SetSolid(SOLID_VPHYSICS)
  return self:SetUseType(SIMPLE_USE)
end
ENT.Use = function(self, activator)
  return Moonpanel:setFocused(activator, true)
end
ENT.PreEntityCopy = function(self) end
ENT.PostEntityPaste = function(self, ply, ent, CreatedEntities) end
ENT.StartPuzzle = function(self, ply, x, y)
  if IsValid(self.activeUser) then
    return false
  end
  self.activeUser = ply
  self:EmitSound(SOUND_PANEL_START)
  self.__nextscint = CurTime() + 2
  return true
end
ENT.FinishPuzzle = function(self)
  if not IsValid(self.activeUser) then
    return false
  end
  self.activeUser = nil
  return self:EmitSound(SOUND_PANEL_ABORT)
end
ENT.Think = function(self)
  if self.activeUser then
    if CurTime() >= self.__nextscint then
      self:EmitSound(SOUND_PANEL_SCINT)
      self.__nextscint = CurTime() + 2
    end
  end
  if self.activeUser then
    if self.activeUser:GetNW2Entity("TheMP Controlled Panel") ~= self then
      return self:FinishPuzzle()
    end
  end
end
