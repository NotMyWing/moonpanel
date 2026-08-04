local test = dofile('tools/tests/harness.lua')

dofile('dest/lua/moonpanel/canvas/sh_surface.lua')
dofile('dest/lua/moonpanel/canvas/sh_continuous_topology.lua')
dofile('dest/lua/moonpanel/canvas/sh_pathfinder.lua')

local function panel(width)
  return { Meta = { Width = width, Height = 2 }, Entities = {} }
end

local function continuousCanvasFixture(width, height, sourceData)
  local data = sourceData or {
    Meta = { Width = width, Height = height },
    Dim = { DisjointLength = 0.4 },
  }
  data.Dim = data.Dim or { DisjointLength = 0.4 }
  local intersections, horizontal, vertical = {}, {}, {}
  local numCols = width * 2 + 1
  local function entityAt(gridX, gridY)
    return data.Entities and data.Entities[1 + gridX + gridY * numCols]
  end
  local function socket(x, y, reference, dataIndex)
    local value = { x = x, y = y, reference = reference, dataIndex = dataIndex }
    function value:GetEntity()
      if not self.reference then return nil end
      return { ExportData = function() return table.Copy(self.reference) end }
    end
    function value:GetRenderOrigin()
      return { x = x * 100, y = y * 100 }
    end
    return value
  end
  for y = 0, height do
    intersections[y + 1] = {}
    horizontal[y + 1] = {}
    for x = 0, width do
      local index = 1 + x * 2 + y * 2 * numCols
      intersections[y + 1][x + 1] = socket(x, y, entityAt(x * 2, y * 2), index)
    end
    for x = 0, width - 1 do
      local index = 1 + (x * 2 + 1) + y * 2 * numCols
      horizontal[y + 1][x + 1] = socket(x + 0.5, y,
        entityAt(x * 2 + 1, y * 2), index)
    end
  end
  for y = 0, height - 1 do
    vertical[y + 1] = {}
    for x = 0, width do
      local index = 1 + x * 2 + (y * 2 + 1) * numCols
      vertical[y + 1][x + 1] = socket(x, y + 0.5,
        entityAt(x * 2, y * 2 + 1), index)
    end
  end
  if not sourceData then intersections[1][1].reference = { Type = 'Start' } end
  local canvas = {}
  function canvas:GetData() return data end
  function canvas:GetBarLength() return 100 end
  function canvas:GetBarWidth() return 10 end
  function canvas:GetIntersectionSocketAt(x, y) return intersections[y][x] end
  function canvas:GetHPathSocketAt(x, y) return horizontal[y][x] end
  function canvas:GetVPathSocketAt(x, y) return vertical[y][x] end
  return canvas
end

local function panelFixture(name)
  for _, fixture in ipairs(dofile('dest/test/panel_fixtures.lua')) do
    if fixture.name == name then return fixture.panel end
  end
  error('missing generated panel fixture: ' .. name)
end

test.test('continuous topology is explicit and surface-independent', function()
  assert(Moonpanel.Canvas.IsContinuousSurface(
    Moonpanel.Canvas.MakeSurfaceSpec(Moonpanel.Canvas.SurfaceKind.Flat, true)))
  assert(Moonpanel.Canvas.IsContinuousSurface(
    Moonpanel.Canvas.MakeSurfaceSpec(Moonpanel.Canvas.SurfaceKind.Pillar, true)))
end)

test.test('pillar follower angle steps stay on budget and preserve direction', function()
  local Canvas = Moonpanel.Canvas
  local step = Canvas.GetPillarFollowerAngleStep(30, 64, 200, 1 / 50)
  local expected = math.deg(200 / 50 / 64)
  assert(math.abs(step - expected) < 0.000001,
    'follower exceeded its ordinary movement budget')
  assert(Canvas.GetPillarFollowerAngleStep(-30, 64, 200, 1 / 50) == -step,
    'reverse follower step is not symmetric')
  assert(Canvas.GetPillarFollowerAngleStep(1, 64, 200, 1 / 50) == 1,
    'nearby ghost was overshot')
  assert(Canvas.GetPillarFollowerAngleStep(30, 64, 0, 1 / 50) == 0,
    'zero movement speed advanced the follower')
end)

test.test('pillar radial correction is dead-zoned and speed limited', function()
  local correct = Moonpanel.Canvas.GetPillarRadialCorrection
  assert(correct(0.2) == 0 and correct(-0.2) == 0,
    'prediction noise escaped the radial deadzone')
  assert(correct(1.25) == 2 and correct(-1.25) == -2,
    'radial correction lost its signed proportional response')
  assert(correct(100) == 16 and correct(-100) == -16,
    'radial correction can command nausea-inducing full-speed movement')
end)

test.test('continuous canvas builder connects both directions through the seam', function()
  local canvas = continuousCanvasFixture(3, 2)
  local nodes = Moonpanel.Canvas.BuildContinuousNodes(canvas)
  assert(nodes[1].edgeSockets[nodes[3]] == canvas:GetHPathSocketAt(3, 1),
    'wrapping edge lost its authored path-socket identity')
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = nodes, barWidth = 10, barLength = 100,
    wrapX = true, periodWidth = 3, surfaceKind = 1,
  })
  local startId = assert(topology.starts[1], 'authored seam start was not compiled')
  local start = topology.nodes[startId]
  local leftEdge, rightEdge
  for toId = 1, #topology.nodes do
    local edge = topology:getEdge(startId, toId)
    if edge and edge.unitX < 0 then leftEdge = edge end
    if edge and edge.unitX > 0 then rightEdge = edge end
  end
  assert(leftEdge and rightEdge,
    'compiled seam node does not expose both wrapping connectors')
  local leftEngine = Moonpanel.Canvas.TraceEngine(topology)
  assert(leftEngine:start(startId) and leftEngine:applySample(-4096, 0),
    'compiled left wrapping connector is not traceable')
  local rightEngine = Moonpanel.Canvas.TraceEngine(topology)
  assert(rightEngine:start(startId) and rightEngine:applySample(4096, 0),
    'compiled right wrapping connector is not traceable')
end)

test.test('continuous travel crosses the seam without a synthetic stop', function()
  local nodes = Moonpanel.Canvas.BuildContinuousNodes(continuousCanvasFixture(3, 2))
  -- Start one column away from the seam so a two-edge sample must commit the
  -- last ordinary connector and then the wrapping connector.
  nodes[2].clickable = true
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = nodes, barWidth = 10, barLength = 100,
    wrapX = true, periodWidth = 3, surfaceKind = 1,
  })
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'interior continuous start was not accepted')
  local beforeQuery = engine:hash()
  assert(engine:GetHorizontalTravel(1, nil, 2) == 8192,
    'physical travel stopped at the seam vertex')
  assert(engine:hash() == beforeQuery,
    'look-ahead travel query mutated canonical trace state')
  assert(engine:applySample(8192, 0),
    'two-edge sample did not traverse the wrapping connector')
  assert(#engine.stacks[1] == 3 and engine.stacks[1][3] == 1,
    'wrapping connector did not commit the canonical seam node')

  local reverse = Moonpanel.Canvas.TraceEngine(topology)
  assert(reverse:start(2), 'reverse interior continuous start was not accepted')
  assert(reverse:GetHorizontalTravel(-1, nil, 2) == 8192,
    'reverse physical travel stopped at the seam vertex')
  assert(reverse:applySample(-8192, 0),
    'reverse sample did not traverse the wrapping connector')
  assert(#reverse.stacks[1] == 3 and reverse.stacks[1][3] == 3,
    'reverse wrapping connector did not leave the canonical seam node')
end)

test.test('pillartest compiles every third-column connector as a wrapping edge', function()
  local data = panelFixture('pillartest')
  assert(data.Meta.Width == 3 and data.Meta.Height == 3 and data.Meta.Continuous,
    'pillartest fixture metadata changed')
  local canvas = continuousCanvasFixture(3, 3, data)
  local nodes = Moonpanel.Canvas.BuildContinuousNodes(canvas)
  for y = 0, 3 do
    nodes[y * 3 + 1].clickable = true
  end
  local topology = Moonpanel.Canvas.TraceTopology({
    nodes = nodes, barWidth = 10, barLength = 100,
    wrapX = true, periodWidth = 3, surfaceKind = 1,
  })

  local expectedSockets = { 6, 20, 34, 48 }
  for y = 0, 3 do
    local seamId = y * 3 + 1
    local rightId = y * 3 + 3
    local edge = topology:getEdge(seamId, rightId)
    assert(edge and edge.unitX == -1 and edge.lengthQ == 4096,
      'third-column connector row ' .. y .. ' was not compiled as a wrapping edge')
    local socket = nodes[seamId].edgeSockets[nodes[rightId]]
    assert(socket and socket.dataIndex == expectedSockets[y + 1],
      'third-column connector row ' .. y .. ' resolved to the wrong authored socket')
    local engine = Moonpanel.Canvas.TraceEngine(topology)
    assert(engine:start(seamId) and engine:applySample(-4096, 0),
      'third-column connector row ' .. y .. ' rejected a leftward trace')
    assert(engine.stacks[1][2] == rightId,
      'third-column connector row ' .. y .. ' committed the wrong endpoint')
  end
end)

test.test('seam pairs cover intersection and vertical path rows', function()
  local pairs = Moonpanel.Canvas.GetSeamPairs(panel(3))
  assert(#pairs == 5)
  assert(pairs[1].left == 1 and pairs[1].right == 7)
  assert(pairs[5].left == 29 and pairs[5].right == 35)
end)

test.test('one-sided seam clues are compatible', function()
  local data = panel(3)
  data.Entities[1] = { Type = 'Start' }
  data.Entities[7] = {}
  local result = Moonpanel.Canvas.GetSurfaceCompatibility(data,
    Moonpanel.Canvas.MakeSurfaceSpec('pillar', true))
  assert(result.playable and #result.errors == 0)
end)

test.test('identical duplicate seam clues are rejected', function()
  local data = panel(3)
  data.Entities[8] = { Type = 'Disjoint', Data = { Gap = 1 } }
  data.Entities[14] = { Type = 'Disjoint', Data = { Gap = 1 } }
  local result = Moonpanel.Canvas.GetSurfaceCompatibility(data,
    Moonpanel.Canvas.MakeSurfaceSpec('pillar', true))
  assert(not result.playable and result.errors[1].code == 'continuous_seam_conflict')
end)

test.test('conflicting seam clues block without mutation', function()
  local data = panel(3)
  data.Entities[1] = { Type = 'Start' }
  data.Entities[7] = { Type = 'End' }
  local result = Moonpanel.Canvas.GetSurfaceCompatibility(data,
    Moonpanel.Canvas.MakeSurfaceSpec('pillar', true))
  assert(not result.playable)
  assert(result.errors[1].code == 'continuous_seam_conflict')
  assert(data.Entities[1].Type == 'Start' and data.Entities[7].Type == 'End')
end)

test.test('pillar exits are restricted to the physical top and bottom', function()
  local data = panel(3)
  data.Entities[17] = { Type = 'End' }
  local result = Moonpanel.Canvas.GetSurfaceCompatibility(data,
    Moonpanel.Canvas.MakeSurfaceSpec('pillar', false))
  assert(not result.playable and result.errors[1].code == 'vertical_exit_boundary')
  assert(result.errors[1].socketIndex == 17)

  data.Entities[17] = {}
  data.Entities[1] = { Type = 'End' }
  result = Moonpanel.Canvas.GetSurfaceCompatibility(data,
    Moonpanel.Canvas.MakeSurfaceSpec('pillar', false))
  assert(result.playable, 'top boundary pillar exit was rejected')
end)

test.test('canonicalization moves right-only clues without hiding duplicates', function()
  local data = panel(3)
  data.Entities[7] = { Type = 'Start' }
  data.Entities[8] = { Type = 'Hexagon', Data = { RuleColor = 1 } }
  data.Entities[14] = { Type = 'Hexagon', Data = { RuleColor = 1 } }
  local output = Moonpanel.Canvas.CanonicalizeContinuousData(data)
  assert(output.Entities[1].Type == 'Start' and output.Entities[7].Type == nil)
  assert(output.Entities[8].Type == 'Hexagon' and output.Entities[14].Type == 'Hexagon')
  assert(data.Entities[7].Type == 'Start', 'input was mutated')
end)

test.test('wrapped deltas and angular fixed units are stable', function()
  assert(Moonpanel.Canvas.WrapDelta(-3, 4) == 1)
  assert(Moonpanel.Canvas.WrapDelta(3, 4) == -1)
  assert(Moonpanel.Canvas.AngularTraceUnits(90, 4) == 4096)
  assert(Moonpanel.Canvas.AngularTraceUnits(-45, 4) == -2048)
  assert(Moonpanel.Canvas.NormalizeAngleDelta(359) == -1)
  assert(Moonpanel.Canvas.NormalizeAngleDelta(-359) == 1)
  assert(Moonpanel.Canvas.UnwrapPillarAngle(1, 359) == 361)
  assert(Moonpanel.Canvas.UnwrapPillarAngle(359, 1) == -1)
  assert(Moonpanel.Canvas.NearestPeriodicCoordinate(0, 490, 512) == 512)
  assert(Moonpanel.Canvas.NearestPeriodicCoordinate(-170, 360, 512) == 342)
  test.near(Moonpanel.Canvas.PillarTraceAngle(-128, 512), 270)
  test.near(Moonpanel.Canvas.PillarAlignmentError(-128, -90, 512), 0)
end)

test.test('pillar arc conversion and radius safety are deterministic', function()
  test.near(Moonpanel.Canvas.PillarArcDegrees(2048, 120), 60)
  assert(Moonpanel.Canvas.QuantizePillarRadius(64.04, 16) == 64.0625)
  local safe, minimum = Moonpanel.Canvas.GetPillarRadiusSafety(87, 48, 32)
  assert(safe and minimum == 80.75)
  safe = Moonpanel.Canvas.GetPillarRadiusSafety(80.5, 48, 32)
  assert(not safe, 'unsafe player/pillar hull overlap was accepted')
end)

test.test('pillar lead clamp permits recovery but caps separation', function()
  local arc = 0.01
  assert(Moonpanel.Canvas.ClampPillarLead(8, 1000, arc, 10) == 200)
  assert(Moonpanel.Canvas.ClampPillarLead(12, -500, arc, 10) == -500,
    'movement back toward the player was blocked')
  assert(Moonpanel.Canvas.ClampPillarLead(-8, -1000, arc, 10) == -200)
  assert(Moonpanel.Canvas.ClampPillarLead(0, 0, arc, 10) == 0)
end)

test.test('pillar world clamp refines to the furthest safe integer', function()
  local probes = 0
  local accepted = Moonpanel.Canvas.RefinePillarTravel(4096, 2500,
    function(value)
      probes = probes + 1
      return value <= 2713
    end)
  assert(accepted == 2713 and probes < 20)
  accepted = Moonpanel.Canvas.RefinePillarTravel(-4096, 2000,
    function(value) return value >= -2333 end)
  assert(accepted == -2333)
end)

test.test('pillar ghost arc sweep clips at the first obstructed hull chord', function()
  local accepted, segments = Moonpanel.Canvas.SweepPillarArc(10, 5, 2)
  test.near(accepted, 5)
  assert(segments == 3, 'clear sweep did not consume every bounded chord')

  local visited = {}
  accepted, segments = Moonpanel.Canvas.SweepPillarArc(10, 5, 2,
    function(fromAngle, toAngle, index)
      visited[index] = {fromAngle, toAngle}
      if index == 2 then return 0.25 end
      return 1
    end)
  test.near(accepted, 2.5)
  assert(segments == 2 and #visited == 2)
  test.near(visited[1][1], 10)
  test.near(visited[1][2], 12)
  test.near(visited[2][1], 12)
  test.near(visited[2][2], 14)

  accepted, segments = Moonpanel.Canvas.SweepPillarArc(10, -5, 2,
    function(_, _, index) return index == 2 and 0 or 1 end)
  test.near(accepted, -2)
  assert(segments == 2, 'reverse sweep did not stop on its first obstruction')
end)

test.test('finite cylinder raycast hits sides and caps without false positives', function()
  local fraction, nx, ny, nz = Moonpanel.Canvas.RaycastFiniteCylinder(
    20, 0, 5, -40, 0, 0, 10, 20)
  test.near(fraction, 0.25)
  assert(nx == 1 and ny == 0 and nz == 0)

  fraction, nx, ny, nz = Moonpanel.Canvas.RaycastFiniteCylinder(
    0, 0, 30, 0, 0, -40, 10, 20)
  test.near(fraction, 0.25)
  assert(nx == 0 and ny == 0 and nz == 1)

  assert(Moonpanel.Canvas.RaycastFiniteCylinder(
    20, 0, 30, -40, 0, 0, 10, 20) == nil,
    'ray above the cylinder produced a side hit')
  assert(Moonpanel.Canvas.RaycastFiniteCylinder(
    20, 20, 5, 0, 10, 0, 10, 20) == nil,
    'ray moving away from the cylinder produced a hit')
end)

test.test('pillar orbit clearance accounts for the angular player hull extent', function()
  assert(Moonpanel.Canvas.CylinderClearsBox(64, 0, 48, 16, 16, 0),
    'flush cardinal player hull was rejected')
  assert(not Moonpanel.Canvas.CylinderClearsBox(63, 0, 48, 16, 16, 0),
    'overlapping cardinal player hull was accepted')
  local diagonalContact = 48 + math.sqrt(16 * 16 + 16 * 16)
  local component = diagonalContact / math.sqrt(2)
  assert(Moonpanel.Canvas.CylinderClearsBox(
    component, component, 48, 16, 16, 0),
    'flush diagonal player hull was rejected')
  assert(not Moonpanel.Canvas.CylinderClearsBox(
    component - 1, component - 1, 48, 16, 16, 0),
    'overlapping diagonal player hull was accepted')
end)

test.run()
