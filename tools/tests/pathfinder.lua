local test = dofile('tools/tests/harness.lua')
dofile('dest/lua/moonpanel/canvas/sh_pathfinder.lua')

local function movementFixture(data)
  local topology = Moonpanel.Canvas.TraceTopology(data)
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  function engine:restart(node)
    return self:start(topology.nodeIds[node])
  end
  function engine:applyDeltas(x, y, boost)
    return self:applySample(
      math.floor(x / data.barLength * 4096 + (x >= 0 and 0.5 or -0.5)),
      math.floor(y / data.barLength * 4096 + (y >= 0 and 0.5 or -0.5)),
      boost
    )
  end
  return engine
end

test.test('partial movement, commit, and backtracking', function()
  local start = {
    x = 0, y = 0, screenX = 0, screenY = 0,
    clickable = true, neighbors = {},
  }
  local finish = {
    x = 1, y = 0, screenX = 100, screenY = 0, neighbors = {},
  }
  start.neighbors = { finish }
  finish.neighbors = { start }

  local engine = movementFixture({
    nodes = { start, finish }, barWidth = 10, barLength = 100,
    screenWidth = 100, screenHeight = 100, symmetry = 0,
  })
  assert(engine:restart(start), 'restart failed')
  assert(engine:applyDeltas(25, 0), 'partial movement failed')
  assert(engine.active.primary.toId == finish.id, 'active target was not preserved')
  assert(#engine.nodeStacks[1] == 1, 'target committed too early')
  assert(engine:applyDeltas(100, 0), 'commit movement failed')
  assert(engine.nodeStacks[1][2] == finish, 'target did not commit')
  engine:applyDeltas(-100, 0)
  assert(engine:applyDeltas(-25, 0), 'backtrack failed')
  assert(#engine.nodeStacks[1] == 1, 'backtrack did not pop immediately')
  assert(engine.active.primary.toId == finish.id, 'retracting edge was not retained')
  assert(engine:applyDeltas(-150, 0), 'backtrack cleanup failed')
  assert(#engine.nodeStacks[1] == 1, 'backtrack did not return to start')
end)

test.test('trace engine exposes a stable query and fork contract', function()
  local start = { x = 0, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local finish = { x = 1, y = 0, screenX = 100, screenY = 0, neighbors = {} }
  start.neighbors = { finish }
  finish.neighbors = { start }
  local engine = movementFixture({
    nodes = { start, finish }, barWidth = 10, barLength = 100, screenWidth = 100,
    screenHeight = 100, symmetry = 0,
  })
  assert(engine:start(engine.topology.nodes[1].id), 'contract fixture did not start')
  assert(engine:GetPhase() == Moonpanel.Canvas.TraceEngine.Phase.Tracing,
    'phase query returned the wrong state')
  assert(engine:GetRevision() == engine.topology.revision, 'revision query drifted')
  assert(engine:GetCursor(1), 'cursor query returned no head')
  assert(engine:applyDeltas(25, 0), 'contract fixture did not move')
  assert(engine:GetActiveAxis() == 'x', 'active-axis query lost direction')
  local debugState = engine:GetDebugState()
  assert(debugState.phase == engine:GetPhase() and debugState.topology == engine.topology,
    'debug query did not expose the engine-owned state')
  local constraint = function() return 1 end
  engine:SetOcclusionConstraint(constraint)
  local fork = engine:Fork()
  assert(fork:Hash() == engine:Hash(), 'fork did not preserve trace state')
  assert(fork.occlusionConstraint == constraint, 'fork did not preserve obstruction')
end)

test.test('continuous edges use the short wrapped direction and stable display endpoint', function()
  local left = {
    x = -2, y = 0, screenX = 0, screenY = 50,
    clickable = true, neighbors = {},
  }
  local right = {
    x = 1, y = 0, screenX = 300, screenY = 50,
    clickable = true, neighbors = {},
  }
  left.neighbors = { right }
  right.neighbors = { left }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { left, right }, barWidth = 10, barLength = 100,
    screenWidth = 400, screenHeight = 100, symmetry = 0,
    surfaceKind = 1, wrapX = true, periodWidth = 4,
  })
  local forward = topology:getEdge(topology.nodeIds[right], topology.nodeIds[left])
  local reverse = topology:getEdge(topology.nodeIds[left], topology.nodeIds[right])
  assert(forward.unitX == 1 and reverse.unitX == -1, 'wrapped direction used long chord')
  assert(forward.lengthQ == 4096 and reverse.lengthQ == 4096,
    'wrapped edge did not retain one-cell length')
  assert(forward.toScreenX == 400 and reverse.toScreenX == -100,
    'wrapped edge display endpoint was not locally unwrapped')
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(topology.nodeIds[right]))
  assert(engine:GetHorizontalTravel(1) == 4096)
  engine:applySample(2048, 0)
  assert(engine:GetHorizontalTravel(1) == 2048)

  local reverseEngine = Moonpanel.Canvas.TraceEngine(topology)
  assert(reverseEngine:start(topology.nodeIds[left]))
  assert(reverseEngine:GetHorizontalTravel(-1) == 4096,
    'leftward travel did not expose the reverse seam edge')
  assert(reverseEngine:applySample(-4096, 0),
    'leftward sample did not cross the reverse seam edge')
  assert(reverseEngine.stacks[1][2] == topology.nodeIds[right],
    'leftward seam traversal committed the wrong endpoint')
end)

test.test('horizontal travel preserves the plain occlusion callback contract', function()
  local start = {
    x = 0, y = 0, screenX = 0, screenY = 0,
    clickable = true, neighbors = {},
  }
  local finish = {
    x = 1, y = 0, screenX = 100, screenY = 0, neighbors = {},
  }
  start.neighbors = { finish }
  finish.neighbors = { start }
  local engine = movementFixture({
    nodes = { start, finish }, barWidth = 10, barLength = 100,
    screenWidth = 100, screenHeight = 100, symmetry = 0,
  })
  assert(engine:restart(start), 'travel callback engine did not start')

  local controller = {}
  engine.occlusionConstraint = function(ply, edge, oldProgress, candidateProgress)
    assert(ply == controller, 'controller argument was shifted')
    assert(type(edge) == 'table', 'edge argument was shifted')
    assert(type(oldProgress) == 'number', 'old progress argument was shifted')
    assert(type(candidateProgress) == 'number', 'candidate progress argument was shifted')
    return candidateProgress - 1024
  end

  assert(engine:GetHorizontalTravel(1, controller) == 3072,
    'travel query did not apply the occlusion constraint')
  engine:applySample(1024, 0, false)
  assert(engine:GetHorizontalTravel(1, controller) == 2048,
    'active-edge travel query did not preserve callback arguments')
end)

test.test('pillar intent and travel queries corner without mutating state', function()
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
  local engine = movementFixture({
    nodes = { start, corner, straight, down }, barWidth = 10, barLength = 100,
    screenWidth = 300, screenHeight = 200, symmetry = 0, surfaceKind = 1,
  })
  assert(engine:restart(start))
  assert(engine:applySample(3900, 0))
  local before = engine:hash()
  local intent = engine:ResolveIntent(0, 200)
  assert(engine:hash() == before, 'intent query changed canonical trace state')
  assert(intent.axis == 'x' and intent.direction == 1 and intent.cornering)
  assert(intent.pendingAxis == 'y' and intent.pendingValueQ == 200)
  assert(intent.endpointDistanceQ == 196)
  assert(engine:GetSignedTravel('x', 1, 2) >= 196)
  assert(engine:applySample(0, 196), 'perpendicular corner sample did not reach endpoint')
  assert(engine.active == nil and engine.stacks[1][2] == corner.id)
  intent = engine:ResolveIntent(0, 200)
  assert(intent.axis == 'y' and intent.direction == 1,
    'latched perpendicular intent did not select the turn')
  assert(engine:GetSignedTravel('y', 1) == 4096)
  assert(engine:applySample(0, 200))
  assert(engine.active and engine.active.primary.toId == down.id,
    'pillar turn selected the continuing horizontal edge')
end)

local function turnFixture()
  local start = { x = 0, y = 0, screenX = 0, screenY = 0, clickable = true, neighbors = {} }
  local lower = { x = 0, y = 1, screenX = 0, screenY = 100, neighbors = {} }
  local upper = { x = 0, y = 2, screenX = 0, screenY = 200, neighbors = {} }
  local right = { x = 1, y = 1, screenX = 100, screenY = 100, neighbors = {} }
  start.neighbors = { upper, lower }
  lower.neighbors = { start, upper, right }
  upper.neighbors = { lower, start }
  right.neighbors = { lower }
  return movementFixture({
    nodes = { start, lower, upper, right }, barWidth = 10, barLength = 100,
    screenWidth = 200, screenHeight = 200, symmetry = 0,
  }), start, lower, right
end

test.test('corner preloading chooses the reachable turn', function()
  local engine, start, lower, right = turnFixture()
  assert(engine:restart(start), 'restart failed')
  assert(engine:applyDeltas(0, 80), 'initial turn movement failed')
  assert(engine.active.primary.toId == lower.id, 'wrong near turn selected')
  assert(engine:applyDeltas(100, 0), 'corner movement failed')
  assert(engine.nodeStacks[1][3] == right or engine.active.primary.toId == right.id,
    'corner preload did not turn right')
end)

test.test('diagonal preload remains responsive', function()
  local engine, start, lower, right = turnFixture()
  assert(engine:restart(start), 'restart failed')
  assert(engine:applyDeltas(80, 40), 'diagonal movement failed')
  assert(engine.active.primary.toId == lower.id, 'diagonal chose wrong turn')
  assert(engine:applyDeltas(100, 0), 'diagonal followup failed')
  assert(engine.nodeStacks[1][3] == right or engine.active.primary.toId == right.id,
    'diagonal did not turn right after snapping')
end)

test.test('one input sample crosses at most two edge boundaries', function()
  local nodes = {}
  for index = 1, 4 do
    nodes[index] = {
      x = index - 1, y = 0,
      screenX = (index - 1) * 100, screenY = 0,
      clickable = index == 1, neighbors = {},
    }
  end
  for index = 1, 4 do
    if nodes[index - 1] then table.insert(nodes[index].neighbors, nodes[index - 1]) end
    if nodes[index + 1] then table.insert(nodes[index].neighbors, nodes[index + 1]) end
  end
  local engine = movementFixture({
    nodes = nodes, barWidth = 10, barLength = 100,
    screenWidth = 400, screenHeight = 100, symmetry = 0,
  })
  assert(engine:restart(nodes[1]), 'high-speed engine did not start')
  engine.occlusionConstraint = function(_, _, _, candidate)
    return candidate
  end
  engine:applySample(32767, 0, false, 'controller')
  assert(#engine.stacks[1] == 3 and engine.stacks[1][3] == 3,
    'sample did not consume exactly two reachable boundaries')
  assert(engine.stacks[1][4] == nil, 'sample teleported across a third boundary')

  local decisions = engine:GetConstraintDecisions()
  assert(#decisions == 2 and decisions[1] == 4096 and decisions[2] == 4096,
    'multi-boundary sample did not retain both constraint decisions')
  local replica = movementFixture({
    nodes = nodes, barWidth = 10, barLength = 100,
    screenWidth = 400, screenHeight = 100, symmetry = 0,
  })
  assert(replica:restart(nodes[1]), 'high-speed replica did not start')
  replica:applySample(32767, 0, false, nil, decisions)
  assert(replica:hash() == engine:hash(),
    'multi-boundary constraint transcript diverged during replay')
end)

test.test('gap endpoints clamp without becoming committed path nodes', function()
  local start = {
    x = 0, y = 0, screenX = 0, screenY = 0,
    clickable = true, neighbors = {},
  }
  local gap = {
    x = 0.4, y = 0, screenX = 40, screenY = 0,
    ['break'] = true, neighbors = {},
  }
  start.neighbors = { gap }
  gap.neighbors = { start }
  local engine = movementFixture({
    nodes = { start, gap }, barWidth = 10, barLength = 100,
    screenWidth = 100, screenHeight = 100, symmetry = 0,
  })
  assert(engine:restart(start), 'gap engine did not start')
  engine:applySample(32767, 0, false)
  assert(#engine.stacks[1] == 1, 'gap endpoint committed into the route')
  assert(engine.active and engine.active.primary.isBreak and
    engine.active.progressQ == engine.active.primary.lengthQ,
    'gap did not retain its collision-limited active head')
end)

test.test('an authored gap creates a topology-only mirrored gap', function()
  local primaryStart = {
    x = 0, y = -1, screenX = 0, screenY = 0,
    clickable = true, neighbors = {},
  }
  local primaryEnd = {
    x = 1, y = -1, screenX = 100, screenY = 0, neighbors = {},
  }
  local gapNear = {
    x = 0.4, y = -1, screenX = 40, screenY = 0,
    ['break'] = true, neighbors = { primaryStart },
  }
  local gapFar = {
    x = 0.6, y = -1, screenX = 60, screenY = 0,
    ['break'] = true, neighbors = { primaryEnd },
  }
  gapNear.pairedBreak = gapFar
  gapFar.pairedBreak = gapNear
  primaryStart.neighbors = { gapNear }
  primaryEnd.neighbors = { gapFar }

  local secondaryStart = {
    x = 0, y = 1, screenX = 0, screenY = 100,
    clickable = true, neighbors = {},
  }
  local secondaryEnd = {
    x = 1, y = 1, screenX = 100, screenY = 100, neighbors = {},
  }
  secondaryStart.neighbors = { secondaryEnd }
  secondaryEnd.neighbors = { secondaryStart }

  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = {
      primaryStart, primaryEnd, secondaryStart, secondaryEnd,
      gapNear, gapFar,
    },
    barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Horizontal,
  })

  local mirrorGapId = topology:getSymmetricalNodeId(gapNear.id)
  local mirrorGap = mirrorGapId and topology.nodes[mirrorGapId]
  assert(mirrorGap and mirrorGap['break'], 'mirrored gap endpoint was not synthesized')
  test.near(mirrorGap.screenX, 40, 0.000001,
    'mirrored gap endpoint was placed at the wrong distance')
  assert(topology:getEdge(secondaryStart.id, secondaryEnd.id) == nil,
    'mirrored path still crossed the synthesized gap')
  assert(#secondaryStart.neighbors == 1 and secondaryStart.neighbors[1] == secondaryEnd,
    'topology construction mutated authored panel nodes')

  local rebuilt = Moonpanel.Canvas.TraceTopology({
    nodes = {
      primaryStart, primaryEnd, secondaryStart, secondaryEnd,
      gapNear, gapFar,
    },
    barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Horizontal,
  })
  assert(#rebuilt.nodes == #topology.nodes and rebuilt.revision == topology.revision,
    'rebuilding topology duplicated or changed synthetic gap nodes')

  local paired = topology:getSymmetricalEdge(primaryStart.id, gapNear.id)
  assert(paired and paired.fromId == secondaryStart.id and paired.toId == mirrorGapId,
    'authored gap edge did not receive a mirrored edge')

  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(primaryStart.id), 'symmetrical gap trace did not start')
  assert(engine:applySample(4096, 0, false),
    'symmetrical trace could not advance toward gap endpoints')
  assert(engine.active and engine.active.primary.isBreak and
    engine.active.secondary and engine.active.secondary.isBreak,
    'gap pair was not retained as the active symmetry segment')
  test.near(engine.cursors[1].x, 40, 0.000001,
    'primary trace did not reach its gap lip')
  test.near(engine.cursors[2].x, 40, 0.000001,
    'secondary trace did not reach its synthesized gap lip')
end)

test.test('gap symmetry never resurrects an absent counterpart path', function()
  local primaryStart = {
    x = 0, y = -1, screenX = 0, screenY = 0,
    clickable = true, neighbors = {},
  }
  local primaryEnd = {
    x = 1, y = -1, screenX = 100, screenY = 0, neighbors = {},
  }
  local gapNear = {
    x = 0.4, y = -1, screenX = 40, screenY = 0,
    ['break'] = true, neighbors = { primaryStart },
  }
  local gapFar = {
    x = 0.6, y = -1, screenX = 60, screenY = 0,
    ['break'] = true, neighbors = { primaryEnd },
  }
  gapNear.pairedBreak = gapFar
  gapFar.pairedBreak = gapNear
  primaryStart.neighbors = { gapNear }
  primaryEnd.neighbors = { gapFar }

  local secondaryStart = {
    x = 0, y = 1, screenX = 0, screenY = 100,
    clickable = true, neighbors = {},
  }
  local secondaryEnd = {
    x = 1, y = 1, screenX = 100, screenY = 100, neighbors = {},
  }

  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = {
      primaryStart, primaryEnd, secondaryStart, secondaryEnd,
      gapNear, gapFar,
    },
    barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Horizontal,
  })

  assert(#topology.nodes == 6,
    'gap symmetrization created nodes on an absent counterpart path')
  assert(topology:getSymmetricalEdge(primaryStart.id, gapNear.id) == nil,
    'gap edge was paired with an absent counterpart path')

  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(primaryStart.id), 'paired starts were rejected unexpectedly')
  assert(not engine:applySample(4096, 0, false),
    'symmetry trace entered a gap whose counterpart path is absent')
end)

test.test('wrong-revision snapshots are rejected without mutation', function()
  local engine, start = turnFixture()
  assert(engine:restart(start), 'snapshot engine did not start')
  engine:applyDeltas(0, 50)
  local before = engine:hash()
  local snapshot = engine:snapshot()
  snapshot.revision = snapshot.revision + 1
  assert(not engine:restore(snapshot), 'wrong-revision snapshot was accepted')
  assert(engine:hash() == before, 'rejected snapshot mutated canonical state')
end)

test.test('a primary constraint preserves shared symmetry progress', function()
  local primaryStart = {
    x = 0, y = -1, screenX = 0, screenY = 0,
    clickable = true, neighbors = {},
  }
  local primaryEnd = {
    x = 1, y = -1, screenX = 100, screenY = 0, neighbors = {},
  }
  local secondaryStart = {
    x = 0, y = 1, screenX = 0, screenY = 100,
    clickable = true, neighbors = {},
  }
  local secondaryEnd = {
    x = 1, y = 1, screenX = 100, screenY = 100, neighbors = {},
  }
  primaryStart.neighbors = { primaryEnd }
  primaryEnd.neighbors = { primaryStart }
  secondaryStart.neighbors = { secondaryEnd }
  secondaryEnd.neighbors = { secondaryStart }

  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = { primaryStart, primaryEnd, secondaryStart, secondaryEnd },
    barWidth = 10, barLength = 100,
    symmetry = Moonpanel.Canvas.Symmetry.Horizontal,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(1), 'symmetry engine did not start')

  local calls = 0
  engine.occlusionConstraint = function(context, primary, oldProgress, candidate)
    calls = calls + 1
    assert(context == 'controller', 'constraint context was not forwarded')
    assert(primary, 'primary edge was omitted from constraint')
    assert(oldProgress == 0 and candidate == 4096, 'constraint received wrong interval')
    return 1024
  end

  assert(engine:applySample(4096, 0, false, 'controller'),
    'constrained symmetry sample made no progress')
  assert(calls == 1, 'symmetry pair was not constrained as one movement')
  assert(engine.active and engine.active.progressQ == 1024,
    'stricter branch limit did not clamp shared progress')
  test.near(engine.cursors[1].x, 25, 0.000001,
    'primary head did not use shared constrained progress')
  test.near(engine.cursors[2].x, 25, 0.000001,
    'secondary head did not use shared constrained progress')

  local decisions = engine:GetConstraintDecisions()
  assert(#decisions == 1 and decisions[1] == 1024,
    'predicting engine did not expose its integer constraint decision')

  local replica = Moonpanel.Canvas.TraceEngine(topology)
  assert(replica:start(1), 'replica symmetry engine did not start')
  assert(replica:applySample(4096, 0, false, nil, decisions),
    'replica did not apply the constrained sample')
  assert(replica:hash() == engine:hash(),
    'replaying the quantized constraint decision diverged')
end)

test.test('continuous seam starts are targetable from either texture edge', function()
  local start = {
    x = -1.5, y = 0, screenX = 0, screenY = 50,
    clickable = true, neighbors = {},
  }
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = {start}, barWidth = 10, barLength = 100,
    wrapX = true, periodWidth = 3,
  })
  assert(topology:getClosestStart(298, 50, 8) == start,
    'the aliased side of a seam start was not clickable')
end)

test.test('surface kind participates in topology revision', function()
  local node = {x = 0, y = 0, screenX = 0, screenY = 0, neighbors = {}}
  local flat = Moonpanel.Canvas.TraceTopology({nodes = {node}, surfaceKind = 0})
  local pillar = Moonpanel.Canvas.TraceTopology({nodes = {node}, surfaceKind = 1})
  assert(flat.revision ~= pillar.revision,
    'flat and pillar topology snapshots shared a revision')
end)

test.run()
