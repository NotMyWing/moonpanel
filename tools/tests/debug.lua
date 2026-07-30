local test = dofile('tools/tests/harness.lua')
local data, canvas, panel, world = dofile('tools/tests/debug_fixture.lua')

dofile('dest/lua/moonpanel/cl_debug.lua')

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
      touchingExit = pathfinder.touchingExit,
      topology = { revision = topology.revision, nodes = #topology.nodes, edges = 2,
        starts = #topology.starts, exits = #topology.exits, gaps = #topology.gaps },
      stacks = pathfinder.stacks, cursors = pathfinder.cursors, history = pathfinder.history,
      constraints = pathfinder:GetConstraintDecisions(), active = pathfinder.active,
    }
  end
  canvas.GetDebugState = function()
    return { trace = canvas.GetTraceDiagnostics(), rule = { revision = 456, clues = 1 },
      geometry = { barWidth = 4, barLength = 25, margin = 0 },
      follower = { reachedSequence = 8, targetSequence = 10, settled = false },
      power = true, dirty = false, solving = false, presentation = true,
      result = false, sound = '0/0 playing' }
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
