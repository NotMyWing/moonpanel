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
          player.themp_givenhands = false
          player:StripWeapon("none")
        end
      end
    end
    player:SetNW2Bool("TheMP Focused", state)
    player.themp_lastfocuschange = CurTime() + 0.75
  end
end
Moonpanel.requestControl = function(self, ply, ent, x, y)
  if ply:GetNW2Entity("TheMP Controlled Panel") == ent then
    ent:FinishPuzzle(x, y)
    return ply:SetNW2Entity("TheMP Controlled Panel", nil)
  else
    if ent:StartPuzzle(ply, x, y) then
      return ply:SetNW2Entity("TheMP Controlled Panel", ent)
    end
  end
end
hook.Add("KeyPress", "TheMP Focus", function(ply, key)
  if key == IN_USE then
    return Moonpanel:setFocused(ply, false)
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
return net.Receive("TheMP Mouse Deltas", function(len, ply)
  if IsValid(ply:GetNW2Entity("TheMP Controlled Panel")) then
    local x = net.ReadFloat()
    local y = net.ReadFloat()
    return print(x, y)
  end
end)
