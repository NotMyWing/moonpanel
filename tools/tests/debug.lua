local test = dofile('tools/tests/harness.lua')

isnumber = function(value) return type(value) == 'number' end
istable = function(value) return type(value) == 'table' end
isfunction = function(value) return type(value) == 'function' end
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
Vector = function(x, y, z) return { x = x, y = y, z = z } end

local disabledConVar = {
  GetBool = function() return false end,
  GetFloat = function() return 4096 end,
  GetInt = function() return 1 end,
}
CreateClientConVar = function() return disabledConVar end
GetConVar = function() return disabledConVar end
RunConsoleCommand = function() end
MsgC = function() end

surface = {
  CreateFont = function() end,
  SetFont = function() end,
  GetTextSize = function(text) return #text * 8, 18 end,
  SetDrawColor = function() end,
  DrawRect = function() end,
}
draw = { RoundedBox = function() end, SimpleText = function() end }
render = { DrawLine = function() end }
hook = { Add = function() end, Remove = function() end }
cvars = { AddChangeCallback = function() end }
concommand = { Add = function() end }
timer = { Simple = function() end }
ents = { FindByClass = function() return {} end }
cam = { Start3D2D = function() end, End3D2D = function() end }
TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP = 0, 0
EyePos = function() return { DistToSqr = function() return 0 end } end

local world = {}
game = { GetWorld = function() return world end }
IsValid = function(value) return value ~= nil and value ~= world end

local playerPosition = {
  Distance = function() return 128 end,
}
local localPlayer = { EyePos = function() return playerPosition end }
LocalPlayer = function() return localPlayer end

Moonpanel.Net = {
  TraceSessions = {},
  PendingPanelDataRequests = {},
}
Moonpanel.Canvas.IsRTAllocated = function() return true end

dofile('dest/lua/moonpanel/cl_debug.lua')

local data = {
  Meta = { Width = 3, Height = 3, Symmetry = 0 },
  Entities = {},
}
local canvas = {
  __powerState = true,
  __rtAlloc = {},
  __rtDirty = false,
  __geometry = { barWidth = 12, barLength = 100, margin = 20 },
  GetData = function() return data end,
  GetPillarTraceEngine = function() return nil end,
  GetTraceDiagnostics = function() return nil end,
  GetDebugState = function()
    return { trace = nil, geometry = { barWidth = 12, barLength = 100, margin = 20 },
      power = true, dirty = false, solving = false, presentation = false,
      result = false, sound = 'off' }
  end,
  GetRuleDefinition = function() return nil end,
  GetObserverFollower = function() return nil end,
  GetGeometry = function() return { barWidth = 12, barLength = 100, margin = 20 } end,
  CanRender = function() return true end,
  IsPowerState = function() return true end,
  IsRenderDirty = function() return false end,
  IsPresentationActive = function() return false end,
  HasVisualResult = function() return false end,
  IsSolving = function() return false end,
  GetSoundStatus = function() return 'off' end,
}
local panel = {
  __rendering = true,
  IsRendering = function() return true end,
  EntIndex = function() return 42 end,
  GetModel = function() return 'models/test.mdl' end,
  GetCanvas = function() return canvas end,
  GetPowered = function() return true end,
  GetController = function() return world end,
  WorldSpaceCenter = function() return {} end,
}

local function joined(lines)
  local values = {}
  for _, line in ipairs(lines) do values[#values + 1] = line[1] end
  return table.concat(values, '\n')
end

test.test('idle panel diagnostics tolerate unavailable runtime layers', function()
  local output = joined(Moonpanel.Debug.panelLines(panel))
  assert(output:find('MOONPANEL #42', 1, true), 'panel identity was omitted')
  assert(output:find('sync yes', 1, true), 'synchronization state was omitted')
  assert(output:find('topology unavailable', 1, true), 'missing topology was not diagnosed')
  assert(output:find('controller world', 1, true), 'world controller was misreported')
end)

test.test('active observer diagnostics cover trace, follower, and occlusion state', function()
  local topology = {
    revision = 123, symmetry = 0,
    nodes = { {}, {} }, edges = { { [2] = {} }, { [1] = {} } },
    starts = { 1 }, exits = { 2 }, gaps = {},
  }
  local pathfinder = {
    topology = topology,
    phase = 2,
    stacks = { { 1 }, { 2 } },
    cursors = { { x = 10, y = 20 }, { x = 30, y = 40 } },
    history = { { 50, -10 } },
    touchingExit = false,
    active = {
      primary = { fromId = 1, toId = 2, kind = 'normal', lengthQ = 4096 },
      progressQ = 1024, maxProgressQ = 4096, retracting = false,
    },
    hash = function() return 987 end,
    canSubmit = function() return false end,
    GetConstraintDecisions = function() return { 1024 } end,
  }
  canvas.GetPillarTraceEngine = function() return pathfinder end
  canvas.GetTraceDiagnostics = function()
    return {
      phase = pathfinder.phase, hash = pathfinder:hash(), canSubmit = pathfinder:canSubmit(),
      touchingExit = pathfinder.touchingExit, topology = topology,
      stacks = pathfinder.stacks, cursors = pathfinder.cursors, history = pathfinder.history,
      constraints = pathfinder:GetConstraintDecisions(), active = pathfinder.active,
    }
  end
  canvas.GetDebugState = function()
    return { trace = canvas.GetTraceDiagnostics(), geometry = { barWidth = 4, barLength = 25, margin = 0 },
      power = true, dirty = false, solving = false, presentation = true,
      result = false, sound = '0/0 playing' }
  end
  canvas.GetRuleDefinition = function()
    return { ruleRevision = 456, clues = { {} } }
  end
  canvas.GetObserverFollower = function()
    return {
      reachedSequence = 8, targetSequence = 10,
      hasReached = function() return false end,
    }
  end
  canvas.IsPresentationActive = function() return true end
  canvas.HasVisualResult = function() return false end
  canvas.IsSolving = function() return false end
  canvas.GetGeometry = function() return { barWidth = 4, barLength = 25, margin = 0 } end
  canvas.IsPowerState = function() return true end
  canvas.IsRenderDirty = function() return false end
  canvas.CanRender = function() return true end
  canvas.GetSoundStatus = function() return '0/0 playing' end
  Moonpanel.Net.TraceSessions[panel] = {
    id = 7, controller = {}, nextSequence = 10, revision = 123,
    pending = {}, unsent = {}, serverHash = 987,
  }
  Moonpanel.Debug.Occlusion[panel] = {
    at = 0, edge = pathfinder.active.primary,
    oldProgress = 0, candidateProgress = 2048, result = 0.5,
    total = 19, start = 1, fanout = 8, refine = 10, blocked = 11,
  }

  local output = joined(Moonpanel.Debug.panelLines(panel))
  assert(output:find('trace Tracing  hash 987', 1, true), 'trace state was omitted')
  assert(output:find('follower reached 8/10', 1, true), 'follower state was omitted')
  assert(output:find('rays 19: start 1, fanout 8, refine 10', 1, true),
    'occlusion fanout counts were omitted')
end)

test.run()
