local setDrawColor = surface.SetDrawColor
local setScissor = render.SetScissorRect
local drawRect = surface.DrawRect
local white = Color(255, 255, 255, 255)
local setAlpha = surface.SetAlphaMultiplier
local clamp = math.Clamp
local SOUND_FOCUS_ON = Sound("moonpanel/focus_on.ogg")
local SOUND_FOCUS_OFF = Sound("moonpanel/focus_off.ogg")
local FOCUSING_TIME = 0.6
local Moonpanel = Moonpanel or { }
Moonpanel.sendMouseDeltas = function(self, x, y)
  net.Start("TheMP Mouse Deltas")
  net.WriteFloat(x)
  net.WriteFloat(y)
  return net.SendToServer()
end
Moonpanel.requestControl = function(self, ent, x, y)
  net.Start("TheMP Request Control")
  net.WriteEntity(ent)
  net.WriteUInt(x, 10)
  net.WriteUInt(y, 10)
  return net.SendToServer()
end
Moonpanel.getControlledPanel = function(self)
  return LocalPlayer():GetNW2Entity("TheMP Controlled Panel")
end
Moonpanel.init = function(self)
  self.__initialized = true
  LocalPlayer():SetNW2VarProxy("TheMP Controlled Panel", function(_, _, _, new)
    if self:isFocused() then
      gui.EnableScreenClicker(not IsValid(new))
      return vgui.GetWorldPanel():SetWorldClicker(not IsValid(new))
    end
  end)
  return LocalPlayer():SetNW2VarProxy("TheMP Focused", function(_, _, _, new)
    surface.PlaySound(new and SOUND_FOCUS_ON or SOUND_FOCUS_OFF)
    gui.EnableScreenClicker(new)
    vgui.GetWorldPanel():SetWorldClicker(new)
    self.__focustime = CurTime()
  end)
end
Moonpanel.isFocused = function(self)
  return LocalPlayer():GetNW2Bool("TheMP Focused")
end
hook.Add("CreateMove", "TheMP Control", function(cmd)
  if Moonpanel:isFocused() then
    local lastclick = Moonpanel.__nextclick or 0
    if CurTime() >= lastclick and input.WasMousePressed(MOUSE_LEFT) then
      Moonpanel.__nextclick = CurTime() + 0.05
      local ent = LocalPlayer():GetEyeTrace().Entity
      if IsValid(ent) and ent:GetClass() == "moonpanel" then
        local x, y = ent:GetCursorPos()
        if x and y then
          Moonpanel:requestControl(ent, x, y)
        end
      end
    end
    cmd:ClearMovement()
    local use = cmd:KeyDown(IN_USE)
    cmd:ClearButtons()
    return cmd:SetButtons(use and IN_USE or 0)
  end
end)
hook.Add("InputMouseApply", "TheMP FocusMode", function(cmd, x, y)
  if Moonpanel:isFocused() then
    if Moonpanel:getControlledPanel() then
      if x ~= 0 or y ~= 0 then
        Moonpanel:sendMouseDeltas(x, y)
      end
      cmd:SetMouseX(0)
      cmd:SetMouseY(0)
      return true
    end
  end
end)
hook.Add("HUDPaint", "TheMP Focus Draw", function()
  if not Moonpanel.__focustime then
    return 
  end
  local scrh, scrw = ScrH(), ScrW()
  local width = math.min(scrw, scrh)
  width = width * 0.03
  local focus = Moonpanel:isFocused()
  local alpha = clamp(((CurTime() - Moonpanel.__focustime) / FOCUSING_TIME), 0, 1)
  if not focus then
    alpha = 1 - alpha
  end
  alpha = math.tanh((alpha * 8) - 4)
  if alpha <= -0.99 then
    return 
  end
  setAlpha(((alpha + 1) / 2) * 0.2)
  setDrawColor(white)
  drawRect(0, 0, width, scrh)
  drawRect(scrw - width, 0, width, scrh)
  drawRect(width, 0, scrw - width * 2, width)
  drawRect(width, scrh - width, scrw - width * 2, width)
  return setAlpha(1)
end)
hook.Add("Initialize", "TheMP Init", function()
  return Moonpanel:init()
end)
if Moonpanel.__initialized then
  return Moonpanel:init()
end
