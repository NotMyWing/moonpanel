ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "The Moonpanel"
ENT.Author = "Notmywing"
ENT.Contact = "winwyv@gmail.com"
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Spawnable = false
ENT.TickRate = 20
ENT.ApplyDeltas = function(self, x, y)
  return print(x, y)
end
ENT.Think = function(self)
  if SERVER then
    self:ServerThink()
  else
    self:ClientThink()
  end
  if CurTime() >= (self.__nextTRThink or 0) then
    self.__nextTRThink = CurTime() + (1 / self.TickRate)
    if SERVER then
      return self:ServerTickrateThink()
    else
      return self:ClientTickrateThink()
    end
  end
end
