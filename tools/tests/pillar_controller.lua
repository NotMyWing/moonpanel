local test = dofile('tools/tests/harness.lua')

AddCSLuaFile = function() end
CLIENT = false
SERVER = false
Moonpanel = { Canvas = {} }

dofile('dest/lua/moonpanel/canvas/sh_pathfinder.lua')
dofile('dest/lua/moonpanel/sh_pillar_controller.lua')

local function cornerEngine()
  local start = { x = 0, y = 0, screenX = 0, screenY = 0,
    clickable = true, neighbors = {} }
  local corner = { x = 1, y = 0, screenX = 100, screenY = 0,
    neighbors = {} }
  local straight = { x = 2, y = 0, screenX = 200, screenY = 0,
    neighbors = {} }
  local down = { x = 1, y = 1, screenX = 100, screenY = 100,
    neighbors = {} }
  start.neighbors = { corner }
  corner.neighbors = { start, straight, down }
  straight.neighbors = { corner }
  down.neighbors = { corner }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { start, corner, straight, down },
    barWidth = 10, barLength = 100, surfaceKind = 1,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(topology.nodeIds[start]))
  return engine, topology, corner, down
end

test.test('controller latches a perpendicular gesture across the endpoint', function()
  local engine, topology, corner, down = cornerEngine()
  assert(engine:applySample(3900, 0))
  local state = {}
  local intent, sampleAxis, sampleDirection =
    Moonpanel.PillarController.ResolveClientSample(state, engine, 0, 200)
  assert(intent.axis == 'x' and intent.cornering)
  assert(sampleAxis == 'y' and sampleDirection == 1)
  assert(state.turnLatch and state.turnLatch.axis == 'y')
  assert(engine:applySample(0, intent.endpointDistanceQ))
  assert(engine.active == nil and engine.stacks[1][2] == topology.nodeIds[corner])

  intent, sampleAxis, sampleDirection =
    Moonpanel.PillarController.ResolveClientSample(state, engine, 0, 0)
  assert(intent.axis == 'y' and sampleAxis == 'y' and sampleDirection == 1)
  assert(state.turnLatch == nil)
  assert(engine:applySample(0, 200))
  assert(engine.active.primary.toId == topology.nodeIds[down])
end)

test.test('reversal overrides a pending pillar turn', function()
  local engine = cornerEngine()
  assert(engine:applySample(3900, 0))
  local state = {}
  local intent = Moonpanel.PillarController.ResolveClientSample(state, engine, 0, 200)
  assert(engine:applySample(0, intent.endpointDistanceQ))
  local reversed, sampleAxis, sampleDirection =
    Moonpanel.PillarController.ResolveClientSample(state, engine, -200, 0)
  assert(reversed.axis == 'x' and reversed.direction == -1)
  assert(sampleAxis == 'x' and sampleDirection == -1)
  assert(state.turnLatch == nil)
end)

test.test('server decoding derives motion from the shadow engine, not move values', function()
  local engine = cornerEngine()
  assert(engine:applySample(3900, 0))
  local intent, sampleAxis, sampleDirection =
    Moonpanel.PillarController.ResolveEncodedSample(engine, 0, 196)
  assert(intent.axis == 'x' and intent.cornering,
    'encoded perpendicular sample lost its horizontal ghost motion')
  assert(sampleAxis == 'y' and sampleDirection == 1)
end)

test.run()
