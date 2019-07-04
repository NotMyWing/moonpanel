include("shared.lua")
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Initialize = function(self)
  self.BaseClass.Initialize(self)
  local info = self.Monitor_Offsets[self:GetModel()]
  if not info then
    local mins = self:OBBMins()
    local maxs = self:OBBMaxs()
    local size = maxs - mins
    info = {
      Name = "",
      RS = (size.y - 1) / 512,
      RatioX = size.y / size.x,
      offset = self:OBBCenter() + Vector(0, 0, maxs.z - 0.24),
      rot = Angle(0, 0, 180),
      x1 = 0,
      x2 = 0,
      y1 = 0,
      y2 = 0,
      z = 0
    }
  end
  local rotation, translation, translation2, scale = Matrix(), Matrix(), Matrix(), Matrix()
  rotation:SetAngles(info.rot)
  translation:SetTranslation(info.offset)
  translation2:SetTranslation(Vector(-256 / info.RatioX, -256, 0))
  scale:SetScale(Vector(info.RS, info.RS, info.RS))
  self.ScreenMatrix = translation * rotation * scale * translation2
  self.ScreenInfo = info
  self.Aspect = info.RatioX
  self.Scale = info.RS
  self.Origin = info.offset
  local w, h = 512 / self.Aspect, 512
  self.ScreenQuad = {
    Vector(0, 0, 0),
    Vector(w, 0, 0),
    Vector(w, h, 0),
    Vector(0, h, 0),
    Color(0, 0, 0, 255)
  }
  return self:SetBackgroundColor(80, 77, 255, 255)
end
local SetDrawColor, DrawRect
do
  local _obj_0 = surface
  SetDrawColor, DrawRect = _obj_0.SetDrawColor, _obj_0.DrawRect
end
ENT.RenderScreen = function(self)
  return SetDrawColor(0, 128, 255, 255)
end
ENT.Draw = function(self)
  return self:DrawModel()
end
ENT.SetBackgroundColor = function(self, r, g, b, a)
  self.ScreenQuad[5] = Color(r, g, b, (math.max(a, 1)))
end
local writez = Material("engine/writez")
local fn
fn = function(self)
  return self.RenderScreen()
end
ENT.DrawBackground = function(self) end
ENT.DrawTranslucent = function(self)
  self:DrawModel()
  if not self.ScreenMatrix or halo.RenderedEntity() == self then
    return 
  end
  local transform = self:GetBoneMatrix(0) * self.ScreenMatrix
  self.Transform = transform
  cam.PushModelMatrix(transform)
  render.ClearStencil()
  render.SetStencilEnable(true)
  render.SetStencilFailOperation(STENCILOPERATION_KEEP)
  render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
  render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
  render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
  render.SetStencilWriteMask(1)
  render.SetStencilReferenceValue(1)
  render.SetColorMaterial()
  render.DrawQuad(unpack(self.ScreenQuad))
  render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
  render.SetStencilTestMask(1)
  local color = self.ScreenQuad[5]
  if color.a == 255 then
    render.ClearBuffersObeyStencil(color.r, color.g, color.b, color.a, true)
  end
  render.PushFilterMag(TEXFILTER.ANISOTROPIC)
  render.PushFilterMin(TEXFILTER.ANISOTROPIC)
  xpcall(fn, print, self)
  render.PopFilterMag()
  render.PopFilterMin()
  render.SetStencilEnable(false)
  render.SetMaterial(writez)
  render.DrawQuad(unpack(self.ScreenQuad))
  return cam.PopModelMatrix()
end
ENT.GetCursorPos = function(self)
  local ply = LocalPlayer()
  local screen = self
  local Normal, Pos
  Pos = screen:LocalToWorld(screen.Origin)
  Normal = -screen.Transform:GetUp():GetNormalized()
  local Start = ply:GetShootPos()
  local Dir = ply:GetAimVector()
  local A = Normal:Dot(Dir)
  if A == 0 or A > 0 then
    return nil
  end
  local B = Normal:Dot(Pos - Start) / A
  if (B >= 0) then
    local w = 512 / screen.Aspect
    local HitPos = screen.Transform:GetInverseTR() * (Start + Dir * B)
    local x = HitPos.x / screen.Scale ^ 2
    local y = HitPos.y / screen.Scale ^ 2
    if x < 0 or x > w or y < 0 or y > 512 then
      return nil
    end
    return x, y
  end
  return nil
end
ENT.GetResolution = function(self)
  return 512 / self.Aspect, 512
end
ENT.ClientThink = function(self) end
ENT.ClientTickrateThink = function(self) end
ENT.Monitor_Offsets = {
  ["models//cheeze/pcb/pcb4.mdl"] = {
    Name = "pcb4.mdl",
    RS = 0.0625,
    RatioX = 1,
    offset = Vector(0, 0, 0.5),
    rot = Angle(0, 0, 180),
    x1 = -16,
    x2 = 16,
    y1 = -16,
    y2 = 16,
    z = 0.5
  },
  ["models//cheeze/pcb/pcb5.mdl"] = {
    Name = "pcb5.mdl",
    RS = 0.0625,
    RatioX = 0.508,
    offset = Vector(-0.5, 0, 0.5),
    rot = Angle(0, 0, 180),
    x1 = -31.5,
    x2 = 31.5,
    y1 = -16,
    y2 = 16,
    z = 0.5
  },
  ["models//cheeze/pcb/pcb6.mdl"] = {
    Name = "pcb6.mdl",
    RS = 0.09375,
    RatioX = 0.762,
    offset = Vector(-0.5, -8, 0.5),
    rot = Angle(0, 0, 180),
    x1 = -31.5,
    x2 = 31.5,
    y1 = -24,
    y2 = 24,
    z = 0.5
  },
  ["models//cheeze/pcb/pcb7.mdl"] = {
    Name = "pcb7.mdl",
    RS = 0.125,
    RatioX = 1,
    offset = Vector(0, 0, 0.5),
    rot = Angle(0, 0, 180),
    x1 = -32,
    x2 = 32,
    y1 = -32,
    y2 = 32,
    z = 0.5
  },
  ["models//cheeze/pcb/pcb8.mdl"] = {
    Name = "pcb8.mdl",
    RS = 0.125,
    RatioX = 0.668,
    offset = Vector(15.885, 0, 0.5),
    rot = Angle(0, 0, 180),
    x1 = -47.885,
    x2 = 47.885,
    y1 = -32,
    y2 = 32,
    z = 0.5
  },
  ["models/cheeze/pcb2/pcb8.mdl"] = {
    Name = "pcb8.mdl",
    RS = 0.2475,
    RatioX = 0.99,
    offset = Vector(0, 0, 0.3),
    rot = Angle(0, 0, 180),
    x1 = -64,
    x2 = 64,
    y1 = -63.36,
    y2 = 63.36,
    z = 0.3
  },
  ["models/blacknecro/tv_plasma_4_3.mdl"] = {
    Name = "Plasma TV (4:3)",
    RS = 0.082,
    RatioX = 0.751,
    offset = Vector(0, -0.1, 0),
    rot = Angle(0, 0, -90),
    x1 = -27.87,
    x2 = 27.87,
    y1 = -20.93,
    y2 = 20.93,
    z = 0.1
  },
  ["models/hunter/blocks/cube1x1x1.mdl"] = {
    Name = "Cube 1x1x1",
    RS = 0.09,
    RatioX = 1,
    offset = Vector(24, 0, 0),
    rot = Angle(0, 90, -90),
    x1 = -48,
    x2 = 48,
    y1 = -48,
    y2 = 48,
    z = 24
  },
  ["models/hunter/plates/plate05x05.mdl"] = {
    Name = "Panel 0.5x0.5",
    RS = 0.045,
    RatioX = 1,
    offset = Vector(0, 0, 1.7),
    rot = Angle(0, 90, 180),
    x1 = -48,
    x2 = 48,
    y1 = -48,
    y2 = 48,
    z = 0
  },
  ["models/hunter/plates/plate1x1.mdl"] = {
    Name = "Panel 1x1",
    RS = 0.09,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -48,
    x2 = 48,
    y1 = -48,
    y2 = 48,
    z = 0
  },
  ["models/hunter/plates/plate2x2.mdl"] = {
    Name = "Panel 2x2",
    RS = 0.182,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -48,
    x2 = 48,
    y1 = -48,
    y2 = 48,
    z = 0
  },
  ["models/hunter/plates/plate4x4.mdl"] = {
    Name = "plate4x4.mdl",
    RS = 0.3707,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -94.9,
    x2 = 94.9,
    y1 = -94.9,
    y2 = 94.9,
    z = 1.7
  },
  ["models/hunter/plates/plate8x8.mdl"] = {
    Name = "plate8x8.mdl",
    RS = 0.741,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -189.8,
    x2 = 189.8,
    y1 = -189.8,
    y2 = 189.8,
    z = 1.7
  },
  ["models/hunter/plates/plate16x16.mdl"] = {
    Name = "plate16x16.mdl",
    RS = 1.482,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -379.6,
    x2 = 379.6,
    y1 = -379.6,
    y2 = 379.6,
    z = 1.7
  },
  ["models/hunter/plates/plate24x24.mdl"] = {
    Name = "plate24x24.mdl",
    RS = 2.223,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -569.4,
    x2 = 569.4,
    y1 = -569.4,
    y2 = 569.4,
    z = 1.7
  },
  ["models/hunter/plates/plate32x32.mdl"] = {
    Name = "plate32x32.mdl",
    RS = 2.964,
    RatioX = 1,
    offset = Vector(0, 0, 2),
    rot = Angle(0, 90, 180),
    x1 = -759.2,
    x2 = 759.2,
    y1 = -759.2,
    y2 = 759.2,
    z = 1.7
  },
  ["models/kobilica/wiremonitorbig.mdl"] = {
    Name = "Monitor Big",
    RS = 0.045,
    RatioX = 0.991,
    offset = Vector(0.2, -0.4, 13),
    rot = Angle(0, 0, -90),
    x1 = -11.5,
    x2 = 11.6,
    y1 = 1.6,
    y2 = 24.5,
    z = 0.2
  },
  ["models/kobilica/wiremonitorsmall.mdl"] = {
    Name = "Monitor Small",
    RS = 0.0175,
    RatioX = 1,
    offset = Vector(0, -0.4, 5),
    rot = Angle(0, 0, -90),
    x1 = -4.4,
    x2 = 4.5,
    y1 = 0.6,
    y2 = 9.5,
    z = 0.3
  },
  ["models/props/cs_assault/billboard.mdl"] = {
    Name = "Billboard",
    RS = 0.23,
    RatioX = 0.522,
    offset = Vector(2, 0, 0),
    rot = Angle(0, 90, -90),
    x1 = -110.512,
    x2 = 110.512,
    y1 = -57.647,
    y2 = 57.647,
    z = 1
  },
  ["models/props/cs_militia/reload_bullet_tray.mdl"] = {
    Name = "Tray",
    RS = 0,
    RatioX = 0.6,
    offset = Vector(0, 0, 0.8),
    rot = Angle(0, 90, 180),
    x1 = 0,
    x2 = 100,
    y1 = 0,
    y2 = 60,
    z = 0
  },
  ["models/props/cs_office/computer_monitor.mdl"] = {
    Name = "LCD Monitor (4:3)",
    RS = 0.031,
    RatioX = 0.767,
    offset = Vector(3.3, 0, 16.7),
    rot = Angle(0, 90, -90),
    x1 = -10.5,
    x2 = 10.5,
    y1 = 8.6,
    y2 = 24.7,
    z = 3.3
  },
  ["models/props/cs_office/tv_plasma.mdl"] = {
    Name = "Plasma TV (16:10)",
    RS = 0.065,
    RatioX = 0.5965,
    offset = Vector(6.1, 0, 18.93),
    rot = Angle(0, 90, -90),
    x1 = -28.5,
    x2 = 28.5,
    y1 = 2,
    y2 = 36,
    z = 6.1
  },
  ["models/props_lab/monitor01b.mdl"] = {
    Name = "Small TV",
    RS = 0.0185,
    RatioX = 1.0173,
    offset = Vector(6.53, -1, 0.45),
    rot = Angle(0, 90, -90),
    x1 = -5.535,
    x2 = 3.5,
    y1 = -4.1,
    y2 = 5.091,
    z = 6.53
  },
  ["models/props_lab/workspace002.mdl"] = {
    Name = "Workspace 002",
    RS = 0.06836,
    RatioX = 0.9669,
    offset = Vector(-42.133224, -42.372322, 42.110897),
    rot = Angle(0, 133.340, -120.317),
    x1 = -18.1,
    x2 = 18.1,
    y1 = -17.5,
    y2 = 17.5,
    z = 42.1109
  },
  ["models/props_mining/billboard001.mdl"] = {
    Name = "TF2 Red billboard",
    RS = 0.375,
    RatioX = 0.5714,
    offset = Vector(3.5, 0, 96),
    rot = Angle(0, 90, -90),
    x1 = -168,
    x2 = 168,
    y1 = -96,
    y2 = 96,
    z = 96
  },
  ["models/props_mining/billboard002.mdl"] = {
    Name = "TF2 Red vs Blue billboard",
    RS = 0.375,
    RatioX = 0.3137,
    offset = Vector(3.5, 0, 192),
    rot = Angle(0, 90, -90),
    x1 = -306,
    x2 = 306,
    y1 = -96,
    y2 = 96,
    z = 192
  }
}
