local test = dofile('tools/tests/harness.lua')
local fixture = dofile('tools/tests/canvas_runtime_fixture.lua')

test.test('real canvas import preserves pillartest wrapping sockets', function()
  local canvas = Moonpanel.Canvas.Canvas()
  assert(canvas.GetTraceTopology == nil,
    'Canvas still exposes the removed mutable topology accessor')
  canvas:ImportData(fixture('pillartest'))
  assert(canvas:IsContinuous(), 'real canvas discarded continuous topology')
  local pathfinder = assert(canvas:GetPillarTraceEngine(), 'real canvas did not build a pathfinder')
  local topology = pathfinder.topology
  local barWidth = canvas:GetBarWidth()
  local start = topology.nodes[10]
  assert(start and start.clickable, 'pillartest bottom seam start moved unexpectedly')
  assert(start.screenY + barWidth * 1.25 <= Moonpanel.Canvas.Resolution,
    'bottom start bulb is still clipped by the render target')
  local exit
  for _, node in ipairs(topology.nodes) do
    if node.exit then exit = node break end
  end
  assert(exit and exit.screenY - barWidth * 0.5 >= 0,
    'top exit cap is still clipped by the render target')
  local exitParent = assert(topology.nodes[exit.neighbors[1] and exit.neighbors[1].id],
    'top exit lost its parent')
  assert(exit.screenX == exitParent.screenX and exit.x == exitParent.x and
    exit.screenY < exitParent.screenY,
    'continuous corner exit is not strictly cardinal-up')

  local renderedExit
  for _, node in ipairs(canvas:GetPathNodes()) do
    if node.exit then renderedExit = node break end
  end
  local renderedParent = renderedExit and renderedExit.neighbors[1]
  assert(renderedParent and renderedExit.screenX == renderedParent.screenX and
    renderedExit.screenY < renderedParent.screenY,
    'rendered continuous exit still uses the flat diagonal formula')
  assert(topology:getClosestStart(1, start.screenY, 32) == start and
    topology:getClosestStart(Moonpanel.Canvas.Resolution - 1, start.screenY, 32) == start,
    'the two visible seam halves do not resolve to the same start')
  local expectedSockets = { 6, 20, 34, 48 }
  for y = 0, 3 do
    local seamId = y * 3 + 1
    local rightId = y * 3 + 3
    local forward = assert(topology:getEdge(rightId, seamId),
      'missing wrapping edge on row ' .. y)
    local reverse = assert(topology:getEdge(seamId, rightId),
      'missing reverse wrapping edge on row ' .. y)
    assert(forward.socketIndex == expectedSockets[y + 1] and
      reverse.socketIndex == expectedSockets[y + 1],
      'wrapping edge resolved to the wrong runtime socket on row ' .. y)
    assert(forward.unitX == 1 and reverse.unitX == -1,
      string.format('wrapping edge has the wrong runtime direction on row %d: %.3f / %.3f; x %.3f -> %.3f; wrap %s period %.3f',
        y, forward.unitX, reverse.unitX, topology.nodes[rightId].x,
        topology.nodes[seamId].x, tostring(topology.wrapX), topology.periodWidth))
  end
end)

test.test('pillar surface overrides the flat corner exit formula', function()
  local data = table.Copy(fixture('pillartest'))
  data.Meta.Continuous = false

  local pillar = Moonpanel.Canvas.Canvas()
  pillar:SetSurfaceSpec(Moonpanel.Canvas.MakeSurfaceSpec(
    Moonpanel.Canvas.SurfaceKind.Pillar, false))
  pillar:ImportData(data)
  local pillarExit
  for _, node in ipairs(pillar:GetPathNodes()) do
    if node.exit then pillarExit = node break end
  end
  local pillarParent = pillarExit and pillarExit.neighbors[1]
  assert(pillarParent and pillarExit.screenX == pillarParent.screenX and
    pillarExit.screenY < pillarParent.screenY,
    'non-wrapping pillar corner exit was diagonal')

  local flat = Moonpanel.Canvas.Canvas()
  flat:ImportData(data)
  local flatExit
  for _, node in ipairs(flat:GetPathNodes()) do
    if node.exit then flatExit = node break end
  end
  local flatParent = flatExit and flatExit.neighbors[1]
  assert(flatParent and flatExit.screenX ~= flatParent.screenX and
    flatExit.screenY ~= flatParent.screenY,
    'flat-panel corner exit behavior changed with the pillar fix')
end)

test.test('real canvas retains pillar kind while panel data enables wrapping', function()
  local canvas = Moonpanel.Canvas.Canvas()
  assert(canvas:SetSurfaceSpec(Moonpanel.Canvas.MakeSurfaceSpec(
    Moonpanel.Canvas.SurfaceKind.Pillar, false)))
  canvas:ImportData(fixture('pillartest'))
  local surfaceSpec = canvas:GetSurfaceSpec()
  assert(surfaceSpec.kind == Moonpanel.Canvas.SurfaceKind.Pillar,
    'SetSurfaceSpec lost the pillar surface kind')
  assert(surfaceSpec.continuous == true,
    'panel data did not enable continuous topology on the pillar')
  local topology = canvas:GetPillarTraceEngine().topology
  assert(topology.surfaceKind == Moonpanel.Canvas.SurfaceKind.Pillar and topology.wrapX,
    'pillar surface values did not reach TraceTopology')
end)

test.test('real pillartest pathfinder traverses all four wrapping sockets', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData(fixture('pillartest'))
  local topology = canvas:GetPillarTraceEngine().topology
  for y = 0, 3 do
    local seamId = y * 3 + 1
    local rightId = y * 3 + 3
    topology.nodes[seamId].clickable = true
    local engine = Moonpanel.Canvas.TraceEngine(topology)
    assert(engine:start(seamId) and engine:applySample(-4096, 0),
      string.format('runtime pathfinder rejected third-column row %d; edge unit %.3f',
        y, topology:getEdge(seamId, rightId).unitX))
    assert(engine.stacks[1][2] == rightId,
      'runtime pathfinder committed the wrong row ' .. y .. ' endpoint')
  end
end)

test.test('replacing canvas data rebuilds topology and clears old runtime state', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData({ Meta = { Width = 1, Height = 1 }, Entities = {} })

  local oldPathfinder = assert(canvas:GetPillarTraceEngine(), 'first import did not build a pathfinder')
  canvas:SetPlayData({ startTime = 1, controller = {}, touchingExit = true })

  canvas:ImportData({ Meta = { Width = 2, Height = 1 }, Entities = {} })

  local rebuilt = assert(canvas:GetPillarTraceEngine(), 'replacement did not build a pathfinder')
  local exported = assert(canvas:ExportData(), 'replacement data was not retained')
  assert(rebuilt ~= oldPathfinder, 'replacement reused the old pathfinder')
  assert(exported.Meta.Width == 2 and exported.Meta.Height == 1,
    'canvas did not ingest the replacement dimensions')
  assert(#canvas:GetPathNodes() > #oldPathfinder.topology.nodes,
    'replacement did not rebuild the larger socket graph')
  assert(next(canvas:GetPlayDataSnapshot()) == nil and canvas:GetLastRuleReport() == nil,
    'replacement retained runtime state from the old document')
end)

test.test('canvas rejects suspicious imports without mutating live state', function()
  local canvas = Moonpanel.Canvas.Canvas()
  assert(canvas:ImportData(fixture('pillartest')))
  local revision = canvas:GetTraceRevision()
  assert(not canvas:ImportData('not a panel'), 'non-table import was accepted')
  local hostile = {
    Meta = setmetatable({}, {
      __index = function() error('hostile payload') end,
    }),
  }
  assert(not canvas:ImportData(hostile), 'throwing payload was accepted')
  assert(canvas:GetTraceRevision() == revision and canvas:IsContinuous(),
    'failed import mutated the live panel')
end)

test.test('invisible intersections and paths are topology cuts', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData(fixture('core clue family coverage'))
  local engine = assert(canvas:GetPillarTraceEngine())
  local invisible
  for _, node in ipairs(canvas:GetPathNodes()) do
    if node.invisible then invisible = node break end
  end
  assert(invisible, 'core clues invisible intersection was not imported')
  assert(#invisible.neighbors == 0, 'invisible intersection retained adjacency')
  for _, node in ipairs(canvas:GetPathNodes()) do
    for _, neighbor in ipairs(node.neighbors) do
      assert(neighbor ~= invisible,
        'invisible intersection left stale inbound adjacency')
    end
  end
  assert(engine.topology.nodeIds[invisible] == nil,
    'invisible intersection remained in trace topology')
  for _, node in ipairs(engine.topology.nodes) do
    assert(not node.invisible, 'trace topology retained an invisible node')
  end
  local redundantPath = table.Copy(fixture('core clue family coverage'))
  redundantPath.Entities[16] = {}
  local redundantCanvas = Moonpanel.Canvas.Canvas()
  redundantCanvas:ImportData(redundantPath)
  assert(redundantCanvas:GetTraceRevision() == engine:GetRevision(),
    'path marker beside an invisible intersection changed topology')

  local pathData = {
    Meta = { Width = 1, Height = 1 },
    Entities = {
      { Type = 'Start' }, { Type = 'Invisible' }, { Type = 'End' },
    },
  }
  local pathCanvas = Moonpanel.Canvas.Canvas()
  pathCanvas:ImportData(pathData)
  local pathTopology = pathCanvas:GetPillarTraceEngine().topology
  assert(not pathTopology:getEdge(1, 2) and not pathTopology:getEdge(2, 1),
    'invisible path created a topology edge')
end)

test.test('transient sound scheduler keeps exactly one deferred timer', function()
  CHAN_USER_BASE = 136
  local timerState = TEST_TIMER
  timerState.callbacks, timerState.pending, timerState.peak, timerState.assertZero = {}, 0, 0, true
  local emitted = {}
  local canvas = Moonpanel.Canvas.Canvas()
  local target = { EmitSound = function(_, file)
    emitted[#emitted + 1] = file
    if file == 'start.wav' then canvas:PlaySound('Eraser') end
  end }
  canvas.__sounds, canvas.__soundEnabled = {}, true
  canvas.__soundTarget = target
  canvas.__soundFiles = { Start = 'start.wav', Eraser = 'eraser.wav' }
  canvas.__soundLevels = { Start = 65, Eraser = 65 }
  canvas.__soundDurations, canvas.__soundActivity, canvas.__soundQueue = {}, {}, {}

  canvas:PlaySound('Start')
  assert(#emitted == 0 and timerState.pending == 1,
    'first transient was not exclusively timer-backed')
  while #timerState.callbacks > 0 do
    local callback = table.remove(timerState.callbacks, 1)
    timerState.pending = timerState.pending - 1
    callback()
  end
  assert(timerState.peak == 1, 'sound scheduler created overlapping timers')
  assert(emitted[1] == 'start.wav' and emitted[2] == 'eraser.wav',
    'sound scheduler lost or reordered a reentrant cue')
end)

test.test('canvas obstruction fanout and refinement preserve visibility fraction', function()
  local traceLine = TestTraceLine()
  local canvas = Moonpanel.Canvas.Canvas(nil, traceLine)
  local rays = 0
  traceLine:set(function()
    rays = rays + 1
    return { Hit = false, Fraction = 1 }
  end)
  assert(canvas:SampleSegmentVisibility(
    Vector(0, 0, 10), Vector(0, 0, 0), Vector(10, 0, 0), {}, 8, 0) == 1,
    'clear segment did not remain completely visible')
  assert(rays == 9,
    'clear segment did not perform one start and eight fanout rays: ' .. rays)

  rays = 0
  traceLine:set(function(trace)
    rays = rays + 1
    return { Hit = trace.endpos.x >= 5, Fraction = trace.endpos.x >= 5 and 0.5 or 1 }
  end)

  local fraction = canvas:SampleSegmentVisibility(
    Vector(0, 0, 10), Vector(0, 0, 0), Vector(10, 0, 0), {}, 8, 0)
  assert(math.abs(fraction - 0.5) < 0.001,
    'binary obstruction refinement changed its convergence point')
  assert(rays == 15,
    'obstruction did not perform one start, four fanout, and ten refinement rays')

  rays = 0
  traceLine:set(function()
    rays = rays + 1
    return { Hit = true, Fraction = 0.25, Entity = { class = 'prop_physics' } }
  end)
  assert(canvas:SampleSegmentVisibility(
    Vector(0, 0, 10), Vector(0, 0, 0), Vector(10, 0, 0), {}, 8, 0) == 0,
    'blocked start ray did not reject the complete segment')
  assert(rays == 1, 'blocked start ray incorrectly entered fanout/refinement')
  traceLine:set(nil)
end)

test.run()
