AddCSLuaFile("moonpanel/cl_init.lua")
AddCSLuaFile("moonpanel/shared.lua")
AddCSLuaFile("moonpanel/editor/cl_editor.lua")
AddCSLuaFile("moonpanel/editor/vgui_panel.lua")
AddCSLuaFile("moonpanel/editor/vgui_cell.lua")
AddCSLuaFile("moonpanel/editor/vgui_vpath.lua")
AddCSLuaFile("moonpanel/editor/vgui_hpath.lua")
AddCSLuaFile("moonpanel/editor/vgui_intersection.lua")
AddCSLuaFile("moonpanel/editor/vgui_polyoeditor.lua")
AddCSLuaFile("moonpanel/editor/vgui_polyorenderer.lua")
AddCSLuaFile("moonpanel/editor/vgui_circlyslider.lua")
AddCSLuaFile("entities/moonpanel/shared.lua")
AddCSLuaFile("entities/moonpanel/cl_init.lua")
util.AddNetworkString("TheMP EditorData")
util.AddNetworkString("TheMP Editor")
util.AddNetworkString("TheMP Focus")
util.AddNetworkString("TheMP Mouse Deltas")
util.AddNetworkString("TheMP Request Control")
Moonpanel = { }
Moonpanel.setFocused = function(self, player, state, force)
  local time = player.themp_lastfocuschange or 0
  if force or (CurTime() >= time and state ~= player:GetNW2Bool("TheMP Focused")) then
    if (state ~= player:GetNW2Bool("TheMP Focused")) then
      if state then
        local weap = player:GetActiveWeapon()
        if IsValid(weap) then
          player.themp_oldweapon = weap:GetClass()
        end
        if not player:HasWeapon("none") then
          player:Give("none")
          player.themp_givenhands = true
        end
      else
        player:SetNW2Entity("TheMP Controlled Panel", nil)
        player:SelectWeapon(player.themp_oldweapon or "none")
        if player.themp_givenhands then
          player.themp_givenhands = nil
          player:StripWeapon("none")
        end
      end
    end
    player:SetNW2Bool("TheMP Focused", state)
    player.themp_lastfocuschange = CurTime() + 0.75
  end
end
Moonpanel.isFocused = function(self, ply)
  return ply:GetNW2Bool("TheMP Focused")
end
Moonpanel.getControlledPanel = function(self, ply)
  return ply:GetNW2Entity("TheMP Controlled Panel")
end
Moonpanel.requestControl = function(self, ply, ent, x, y, force)
  if (ply.themp_nextrequest or 0) > CurTime() then
    return 
  end
  if ply:GetNW2Entity("TheMP Controlled Panel") == ent then
    ply.themp_nextrequest = CurTime() + 0.25
    ent:FinishPuzzle(x, y)
    return ply:SetNW2Entity("TheMP Controlled Panel", nil)
  else
    ply.themp_nextrequest = CurTime() + 0.25
    if ent:StartPuzzle(ply, x, y) then
      return ply:SetNW2Entity("TheMP Controlled Panel", ent)
    end
  end
end
hook.Add("KeyPress", "TheMP Focus", function(ply, key)
  if key == IN_USE then
    Moonpanel:setFocused(ply, false)
  end
  if key == IN_ATTACK and (Moonpanel:isFocused(ply)) and IsValid(Moonpanel:getControlledPanel(ply)) then
    return Moonpanel:requestControl(ply, (Moonpanel:getControlledPanel(ply)), x, y)
  end
end)
hook.Add("Think", "TheMP Think", function()
  for k, v in pairs(player.GetAll()) do
    if v:GetNW2Bool("TheMP Focused") then
      v:SelectWeapon("none")
    end
  end
end)
hook.Add("PostPlayerDeath", "TheMP PlayerDeath", function(ply)
  return Moonpanel:setFocused(ply, false, true)
end)
hook.Add("PlayerSilentDeath", "TheMP PlayerDeath", function(ply)
  return Moonpanel:setFocused(ply, false, true)
end)
net.Receive("TheMP Request Control", function(len, ply)
  local ent = net.ReadEntity()
  local x = net.ReadUInt(10)
  local y = net.ReadUInt(10)
  return Moonpanel:requestControl(ply, ent, x, y)
end)
net.Receive("TheMP Mouse Deltas", function(len, ply)
  local panel = ply:GetNW2Entity("TheMP Controlled Panel")
  if IsValid(panel) then
    local x = net.ReadFloat()
    local y = net.ReadFloat()
    return panel:ApplyDeltas(x, y)
  end
end)
local pendingEditorData = { }
local counter = 1
Moonpanel.requestEditorConfig = function(self, ply, callback, errorcallback)
  local pending = {
    player = ply,
    callback = callback,
    timer = "TheMP RemovePending " .. tostring(tostring(counter))
  }
  pendingEditorData[#pendingEditorData + 1] = pending
  counter = (counter % 10000) + 1
  net.Start("TheMP EditorData")
  net.Send(ply)
  return timer.Create(pending.timer, 4, 1, function()
    errorcallback()
    for i = 1, #pendingEditorData do
      if pendingEditorData[i] == pending then
        table.remove(pendingEditorData, i)
        break
      end
    end
  end)
end
return net.Receive("TheMP EditorData", function(len, ply)
  local pending = nil
  for k, v in pairs(pendingEditorData) do
    if v.player == ply then
      pending = v
      break
    end
  end
  if not pending then
    return 
  end
  for i = 1, #pendingEditorData do
    if pendingEditorData[i] == pending then
      table.remove(pendingEditorData, i)
      break
    end
  end
  timer.Remove(pending.timer)
  local length = net.ReadUInt(32)
  local data = net.ReadData(length)
  data = util.JSONToTable((util.Decompress(data)) or "{}") or { }
  return pending.callback(data)
end)
