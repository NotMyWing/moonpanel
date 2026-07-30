local data = {Meta = {Width = 3, Height = 3, Symmetry = 0}, Entities = {}}
local canvas = {
  __powerState = true, __rtAlloc = {}, __rtDirty = false,
  __geometry = {barWidth = 12, barLength = 100, margin = 20},
  GetData = function() return data end,
  GetPillarTraceEngine = function() return nil end,
  GetTraceDiagnostics = function() return nil end,
  GetDebugState = function()
    return {trace = nil, geometry = {barWidth = 12, barLength = 100, margin = 20},
      power = true, dirty = false, solving = false, presentation = false,
      result = false, sound = 'off'}
  end,
  GetObserverFollower = function() return nil end,
  GetGeometry = function() return {barWidth = 12, barLength = 100, margin = 20} end,
  CanRender = function() return true end, IsPowerState = function() return true end,
  IsRenderDirty = function() return false end, IsPresentationActive = function() return false end,
  HasVisualResult = function() return false end, IsSolving = function() return false end,
  GetSoundStatus = function() return 'off' end,
}
local world = _G.TEST_WORLD
local panel = {
  __rendering = true, IsRendering = function() return true end,
  EntIndex = function() return 42 end, GetModel = function() return 'models/test.mdl' end,
  GetCanvas = function() return canvas end, GetPowered = function() return true end,
  GetController = function() return world end, WorldSpaceCenter = function() return {} end,
}

return data, canvas, panel, world
