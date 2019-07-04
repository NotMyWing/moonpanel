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
ENT.SetupData = function(self, data)
  return PrintTable(data)
end
ENT.StartPuzzle = function(self, ply, x, y)
  if IsValid(self.activeUser) then
    return false
  end
  self.activeUser = ply
  self:EmitSound(SOUND_PANEL_START)
  self.__scintPower = 1
  self.__nextscint = CurTime() + 0.75
  return true
end
ENT.FinishPuzzle = function(self)
  if not IsValid(self.activeUser) then
    return false
  end
  self.activeUser = nil
  return self:EmitSound(SOUND_PANEL_ABORT)
end
ENT.ServerThink = function(self)
  if self.activeUser then
    if self.__scintPower >= 0.15 and CurTime() >= self.__nextscint then
      self:EmitSound(SOUND_PANEL_SCINT, 75, 100, self.__scintPower)
      self.__nextscint = CurTime() + 2
      self.__scintPower = self.__scintPower * 0.75
    end
  end
  if self.activeUser then
    if self.activeUser:GetNW2Entity("TheMP Controlled Panel") ~= self then
      return self:FinishPuzzle()
    end
  end
end
ENT.ServerTickrateThink = function(self) end
