local test = dofile('tools/tests/harness.lua')
dofile('dest/lua/moonpanel/canvas/sh_pathfinder.lua')

local function grid(size, symmetry)
  local nodes = {}
  local function at(x, y) return nodes[y * size + x + 1] end
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      table.insert(nodes, {
        x = x - (size - 1) / 2, y = y - (size - 1) / 2,
        screenX = x * 100, screenY = y * 100,
        clickable = x == 0 and y == 0,
        exit = x == size - 1 and y == size - 1,
        neighbors = {},
      })
    end
  end
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      local node = at(x, y)
      if x > 0 then table.insert(node.neighbors, at(x - 1, y)) end
      if x + 1 < size then table.insert(node.neighbors, at(x + 1, y)) end
      if y > 0 then table.insert(node.neighbors, at(x, y - 1)) end
      if y + 1 < size then table.insert(node.neighbors, at(x, y + 1)) end
    end
  end
  return Moonpanel.Canvas.TraceTopology({
    nodes = nodes, barWidth = 10, barLength = 100, symmetry = symmetry or 0,
  }), nodes
end

local randomizedSteps = tonumber(arg[1]) or 500000
local randomizedSeed = tonumber(arg[2]) or 0x13579

test.test(randomizedSteps .. ' client/server steps remain identical', function()
  local topology = grid(4, 0)
  local client = Moonpanel.Canvas.TraceEngine(topology)
  local server = Moonpanel.Canvas.TraceEngine(topology)
  assert(client:start(1) and server:start(1), 'engines did not start')
  local seed = randomizedSeed
  local function random(limit)
    seed = (seed * 48271) % 2147483647
    return (seed % (limit * 2 + 1)) - limit
  end
  for step = 1, randomizedSteps do
    if step % 211 == 0 then
      assert(client:start(1) and server:start(1), 'restart failed at ' .. step)
    else
      local dx, dy = random(5000), random(5000)
      local boost = step % 17 == 0
      client:applySample(dx, dy, boost)
      server:applySample(dx, dy, boost)
    end
    assert(client:hash() == server:hash(), 'divergence at step ' .. step)
    if step % 997 == 0 then
      local recovered = Moonpanel.Canvas.TraceEngine(topology)
      assert(recovered:restore(client:snapshot()), 'snapshot restore failed at ' .. step)
      assert(recovered:hash() == client:hash(), 'snapshot omitted state at ' .. step)
    end
  end
end)

test.test('exit contact is sticky and evaluation commits it', function()
  local start = { x = 0, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local exit = { x = 0.5, y = 0, screenX = 50, screenY = 0, exit = true, neighbors = {} }
  start.neighbors = { exit }
  exit.neighbors = { start }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { start, exit }, barWidth = 10, barLength = 100, symmetry = 0,
  })
  assert(topology:getEdge(1, 2).lengthQ == 410,
    'canonical exit length no longer matches the short rendered stub')
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(1), 'engine did not start')
  engine:applySample(4096, 0, false)
  assert(engine:canSubmit(), 'exit was not submittable')
  assert(engine:isExitPath(), 'exact exit contact lost the exit path state')
  engine:applySample(0, 4096, false)
  assert(engine:canSubmit(), 'perpendicular noise lost exit contact')
  assert(engine:isExitPath(), 'exit contact incorrectly retriggered a separate path state')
  assert(engine:beginEvaluation(), 'evaluation failed')
  assert(engine.active == nil and engine.stacks[1][2] == 2,
    'evaluation did not commit exit')
end)

test.test('submitting an in-progress exit trace nudges it to the exit', function()
  local start = { x = 0, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local exit = { x = 0.5, y = 0, screenX = 50, screenY = 0, exit = true, neighbors = {} }
  start.neighbors = { exit }
  exit.neighbors = { start }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { start, exit }, barWidth = 10, barLength = 100, symmetry = 0,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(1), 'engine did not start')
  assert(engine:applySample(200, 0, false), 'partial exit trace failed')
  assert(engine.active and engine.active.progressQ < engine.active.primary.lengthQ,
    'test did not leave the exit partially traced')
  assert(engine:isExitPath(), 'partial exit trace did not identify the exit path')
  assert(engine:canSubmit(), 'partial exit trace was not submittable')
  assert(engine:beginEvaluation(), 'partial exit evaluation failed')
  assert(engine.active == nil and engine.stacks[1][2] == 2,
    'submitting did not nudge the trace to the exit')
end)

test.test('exact diagonal ties prefer horizontal', function()
  local up = { x = 0, y = -1, screenX = 0, screenY = -100, neighbors = {} }
  local center = { x = 0, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local right = { x = 1, y = 0, screenX = 100, screenY = 0, neighbors = {} }
  center.neighbors = { up, right }
  up.neighbors = { center }
  right.neighbors = { center }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { up, center, right }, barWidth = 10, barLength = 100, symmetry = 0,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'engine did not start')
  engine:applySample(2048, -2048, false)
  assert(engine.active.primary.toId == 3, 'horizontal did not win exact tie')
end)

test.test('symmetry commits atomically and heads cannot cross', function()
  local left = { x = -1, y = 0, screenX = 0, screenY = 0, neighbors = {} }
  local center = { x = 0, y = 0, screenX = 100, screenY = 0, clickable = true, neighbors = {} }
  local right = { x = 1, y = 0, screenX = 200, screenY = 0, neighbors = {} }
  left.neighbors = { center }
  center.neighbors = { left, right }
  right.neighbors = { center }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { left, center, right }, barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Rotational,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'shared start failed')
  engine:applySample(4096, 0, false)
  assert(engine.stacks[1][2] == 3 and engine.stacks[2][2] == 1,
    'branches did not commit atomically')

  local a = { x = -1, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local b = { x = 1, y = 0, screenX = 100, screenY = 0, clickable = true, neighbors = {} }
  a.neighbors = { b }
  b.neighbors = { a }
  topology = Moonpanel.Canvas.TraceTopology({
    nodes = { a, b }, barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Rotational,
  })
  engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(1), 'collision engine did not start')
  engine:applySample(4096, 0, false)
  assert(#engine.stacks[1] == 1 and #engine.stacks[2] == 1,
    'mirrored heads crossed')
  assert(engine.active.progressQ < engine.active.primary.lengthQ / 2,
    'mirrored collision limit was not applied')
end)

test.test('symmetry starts require a clickable mirrored start', function()
  local left = { x = -1, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local right = { x = 1, y = 0, screenX = 100, screenY = 0, neighbors = {} }
  left.neighbors = { right }
  right.neighbors = { left }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { left, right }, barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Rotational,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(#topology.starts == 0 and #topology.invalidStarts == 1,
    'unpaired start remained selectable')
  assert(not topology:getClosestStart(0, 0, 20),
    'start targeting exposed an unpaired symmetry start')
  assert(not engine:start(1), 'engine accepted a non-start mirrored node')
  assert(#engine.stacks == 0 and engine.phase == Moonpanel.Canvas.TraceEngine.Phase.Idle,
    'rejected symmetry start partially mutated engine state')

  right.clickable = true
  topology = Moonpanel.Canvas.TraceTopology({
    nodes = { left, right }, barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Rotational,
  })
  engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(#topology.starts == 2 and engine:start(1),
    'paired clickable starts were rejected')
end)

test.test('symmetry skips an unpaired edge instead of blocking a valid edge', function()
  local primary = { x = -1, y = 0, screenX = 100, screenY = 200, clickable = true, neighbors = {} }
  local secondary = { x = 1, y = 0, screenX = 300, screenY = 200, clickable = true, neighbors = {} }
  local invalid = { x = -1, y = -1, screenX = 100, screenY = 100, neighbors = {} }
  local invalidMirror = { x = 1, y = 1, screenX = 300, screenY = 300, neighbors = {} }
  local valid = { x = -2, y = 0, screenX = 0, screenY = 200, neighbors = {} }
  local validMirror = { x = 2, y = 0, screenX = 400, screenY = 200, neighbors = {} }
  primary.neighbors = { invalid, valid }
  secondary.neighbors = { validMirror }
  invalid.neighbors = { primary }
  valid.neighbors = { primary }
  validMirror.neighbors = { secondary }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { primary, secondary, invalid, invalidMirror, valid, validMirror },
    barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Rotational,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(1), 'paired edge fixture did not start')
  assert(engine:applySample(-1024, -4096, false),
    'unpaired higher-scoring edge blocked all symmetric movement')
  assert(engine.stacks[1][2] == 5 and engine.stacks[2][2] == 6,
    'engine did not choose the valid mirrored edge pair')
end)

test.test('logical lengths keep subpixel symmetry edges atomic', function()
  local left = { x = -1, y = 0, screenX = 128, screenY = 0, neighbors = {} }
  local center = { x = 0, y = 0, screenX = 256, screenY = 0, clickable = true, neighbors = {} }
  local right = { x = 1, y = 0, screenX = 383, screenY = 0, neighbors = {} }
  left.neighbors = { center }
  center.neighbors = { left, right }
  right.neighbors = { center }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { left, center, right }, barWidth = 10, barLength = 127.5,
    symmetry = Moonpanel.Canvas.Symmetry.Rotational,
  })
  assert(topology:getEdge(2, 1).lengthQ == 4096 and
    topology:getEdge(2, 3).lengthQ == 4096,
    'rounded screen pixels leaked into canonical edge lengths')
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'subpixel shared start failed')
  engine:applySample(-4096, 0, false)
  assert(engine.stacks[1][2] == 1 and engine.stacks[2][2] == 3,
    'mirrored heads did not reach symmetric points atomically')
end)

test.test('every symmetry transform derives the paired target', function()
  local cases = {
    { Moonpanel.Canvas.Symmetry.Rotational, 5 },
    { Moonpanel.Canvas.Symmetry.Vertical, 3 },
    { Moonpanel.Canvas.Symmetry.Horizontal, 4 },
  }
  for _, case in ipairs(cases) do
    local center = { x = 0, y = 0, screenX = 100, screenY = 100,
      clickable = true, neighbors = {} }
    local positive = { x = 1, y = 1, screenX = 200, screenY = 200, neighbors = {} }
    local horizontal = { x = -1, y = 1, screenX = 0, screenY = 200, neighbors = {} }
    local vertical = { x = 1, y = -1, screenX = 200, screenY = 0, neighbors = {} }
    local rotational = { x = -1, y = -1, screenX = 0, screenY = 0, neighbors = {} }
    local nodes = { center, positive, horizontal, vertical, rotational }
    for index = 2, #nodes do
      center.neighbors[#center.neighbors + 1] = nodes[index]
      nodes[index].neighbors = { center }
    end
    local topology = Moonpanel.Canvas.TraceTopology({
      nodes = nodes, barWidth = 10, barLength = 100, symmetry = case[1],
    })
    local engine = Moonpanel.Canvas.TraceEngine(topology)
    assert(engine:start(1), 'shared transform start failed for mode ' .. case[1])
    engine:applySample(4096, 4096, false)
    assert(engine.active and engine.active.primary.toId == 2 and
      engine.active.secondary.toId == case[2],
      'wrong paired target for symmetry mode ' .. case[1])
  end
end)

test.run()
