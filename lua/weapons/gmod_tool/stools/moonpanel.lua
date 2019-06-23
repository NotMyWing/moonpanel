TOOL.Category = "Neeve's Addons"
TOOL.Name = "The Witness - The Moonpanel"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["Model"] = "models/hunter/plates/plate2x2.mdl"
TOOL.ClientConVar["Type"] = 1
cleanup.Register("moonpanel")
if SERVER then
  CreateConVar("sbox_maxmoonpanels", 3, {
    FCVAR_REPLICATED,
    FCVAR_NOTIFY,
    FCVAR_ARCHIVE
  })
  MakeComponent = function(cl, pl, Pos, Ang, model)
    if not (pl:CheckLimit("moonpanels")) then
      return false
    end
    local sf = ents.Create(cl)
    if not IsValid(sf) then
      return false
    end
    do
      sf:SetAngles(Ang)
      sf:SetPos(Pos)
      sf:SetModel(model)
      sf:Spawn()
    end
    pl:AddCount("moonpanel", sf)
    pl:AddCleanup("moonpanel", sf)
    return sf
  end
  local fn
  fn = function(...)
    return MakeComponent("moonpanel", ...)
  end
  duplicator.RegisterEntityClass("moonpanel", fn, "Pos", "Ang", "Model")
else
  language.Add("Tool.moonpanel.name", "The Moonpanel")
  language.Add("Tool.moonpanel.desc", "Spawns a Moonpanel.")
  language.Add("sboxlimit_moonpanel", "You've hit the Moonpanel limit!")
  language.Add("undone_Moonpanel", "Undone Moonpanel")
  language.Add("Cleanup_moonpanel", "Moonpanels")
  TOOL.Information = {
    {
      name = "left",
      stage = 0,
      text = "Spawn a Moonpanel"
    },
    {
      name = "right_0",
      stage = 0,
      text = "Open the editor"
    }
  }
  for _, info in pairs(TOOL.Information) do
    language.Add("Tool.moonpanel." .. info.name, info.text)
  end
end
TOOL.LeftClick = function(self, trace)
  if not trace.HitPos then
    return false
  end
  if trace.Entity:IsPlayer() or trace.Entity:IsNPC() then
    return false
  end
  if CLIENT then
    return true
  end
  local ply = self:GetOwner()
  local Ang = trace.HitNormal:Angle()
  Ang.pitch = Ang.pitch + 90
  local model = self:GetClientInfo("Model")
  if not ((util.IsValidModel(model)) and (util.IsValidProp(model))) then
    return false
  end
  local sf = MakeComponent("moonpanel", ply, Vector(), Ang, model)
  if not sf then
    return false
  end
  local min = sf:OBBMins()
  sf:SetPos(trace.HitPos - trace.HitNormal * min.z)
  local const = nil
  local phys = sf:GetPhysicsObject()
  if trace.Entity:IsValid() then
    const = constraint.Weld(sf, trace.Entity, 0, trace.PhysicsBone, 0, true, true)
    if phys:IsValid() then
      phys:EnableCollisions(false)
      sf.nocollide = true
    end
  else
    if phys:IsValid() then
      phys:EnableMotion(false)
    end
  end
  undo.Create("Moonpanel")
  undo.AddEntity(sf)
  if const then
    undo.AddEntity(const)
  end
  undo.SetPlayer(ply)
  undo.Finish()
  return true
end
TOOL.RightClick = function(self, trace) end
TOOL.Reload = function(self, trace) end
TOOL.DrawHUD = function(self) end
TOOL.Think = function(self)
  local model = self:GetClientInfo("Model")
  if (not IsValid(self.GhostEntity) or self.GhostEntity:GetModel() ~= model) then
    self:MakeGhostEntity(model, Vector(0, 0, 0), Angle(0, 0, 0))
  end
  local trace = util.TraceLine(util.GetPlayerTrace(self:GetOwner()))
  if (not trace.Hit) then
    return 
  end
  local ent = self.GhostEntity
  if not IsValid(ent) then
    return 
  end
  local Ang = trace.HitNormal:Angle()
  Ang.pitch = Ang.pitch + 90
  local min = ent:OBBMins()
  ent:SetPos(trace.HitPos - trace.HitNormal * min.z)
  return ent:SetAngles(Ang)
end
if CLIENT then
  TOOL.BuildCPanel = function(panel)
    panel:AddControl("Header", {
      Text = "#Tool.moonpanel.name",
      Description = "#Tool.moonpanel.desc"
    })
    local modelPanel = vgui.Create("DPanelSelect", panel)
    modelPanel:EnableVerticalScrollbar()
    modelPanel:SetTall(66 * 5 + 2)
    local t = (scripted_ents.GetStored("moonpanel").t.Monitor_Offsets) or { }
    for model, v in pairs(t) do
      local icon = vgui.Create("SpawnIcon")
      icon:SetModel(model)
      icon.Model = model
      icon:SetSize(64, 64)
      icon:SetTooltip(model)
      modelPanel:AddPanel(icon, {
        ["moonpanel_Model"] = model
      })
    end
    modelPanel:SortByMember("Model", false)
    panel:AddPanel(modelPanel)
    return panel:AddControl("Label", {
      Text = ""
    })
  end
end
