local test = dofile('tools/tests/harness.lua')

Moonpanel.Canvas.DLX = dofile('dest/lua/moonpanel/canvas/sh_dlx.lua')
dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
local flatIndex = Moonpanel.Helpers.flatIndex
dofile('dest/lua/moonpanel/canvas/sh_polyomino.lua')
local RuleEngine = dofile('dest/lua/moonpanel/canvas/sh_rule_engine.lua')

local function cellIndex(width, x, y)
  return flatIndex(width, x * 2, y * 2)
end

local function intersectionIndex(width, x, y)
  return flatIndex(width, x * 2 - 1, y * 2 - 1)
end

local function hpathIndex(width, x, y)
  return flatIndex(width, x * 2, y * 2 - 1)
end

local function vpathIndex(width, x, y)
  return flatIndex(width, x * 2 - 1, y * 2)
end

local function panel(width, height)
  local entities = {}
  for index = 1, (width * 2 + 1) * (height * 2 + 1) do entities[index] = {} end
  return {
    SchemaVersion = 3,
    Meta = {
      Width = width,
      Height = height,
      Symmetry = 0,
      SymmetryOptions = { Colorful = false, Traces = {} },
    },
    Entities = entities,
    Extensions = {},
  }
end

local function topology(nodes, edgeList)
  local value = {
    revision = 9001,
    nodes = nodes or {},
    edges = {},
  }
  for index = 1, #value.nodes do value.edges[index] = {} end
  for _, edge in ipairs(edgeList or {}) do
    local forward = { socketIndex = edge[3] }
    local reverse = { socketIndex = edge[3] }
    for key, item in pairs(edge[4] or {}) do
      forward[key] = item
      reverse[key] = item
    end
    value.edges[edge[1]][edge[2]] = forward
    value.edges[edge[2]][edge[1]] = reverse
  end
  function value:getEdge(fromId, toId)
    return self.edges[fromId] and self.edges[fromId][toId]
  end
  return value
end

local function evaluate(data, topo, stacks)
  topo = topo or topology()
  local definition = RuleEngine.Compile(data, topo)
  return RuleEngine.Evaluate(definition, {
    revision = topo.revision,
    stacks = stacks or {},
  })
end

local function popcount(value)
  local count = 0
  while value > 0 do
    count = count + value % 2
    value = math.floor(value / 2)
  end
  return count
end

local function boundaryTrace(width, mask)
  local sockets = {
    hpathIndex(width, 1, 1),
    vpathIndex(width, 2, 1),
    hpathIndex(width, 1, 2),
    vpathIndex(width, 1, 1),
  }
  local nodes, edges, stacks = {}, {}, {}
  for side = 1, 4 do
    if math.floor(mask / (2 ^ (side - 1))) % 2 == 1 then
      local first = #nodes + 1
      nodes[first] = {}
      nodes[first + 1] = {}
      edges[#edges + 1] = {first, first + 1, sockets[side]}
      stacks[#stacks + 1] = {first, first + 1}
    end
  end
  return topology(nodes, edges), stacks
end

local function setCell(data, x, typeName, attributes)
  data.Entities[cellIndex(data.Meta.Width, x, 1)] = {
    Type = typeName,
    Data = attributes,
  }
  return cellIndex(data.Meta.Width, x, 1)
end

test.test('DLX positive exact cover returns a canonical witness', function()
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}, {x = 2, y = 1}},
  }, {
    {id = 10, shape = {{1, 1}}, rotatable = false},
  })
  assert(result.status == 'solved' and result.backend == 'dlx', 'DLX did not solve domino')
  assert(#result.placements == 1 and result.placements[1].pieceId == 10,
    'DLX witness was not canonical')
end)

test.test('positive polyomino placements wrap across a continuous seam', function()
  local cells = {{x = 3, y = 1}, {x = 1, y = 1}}
  local pieces = {{id = 7, shape = {{1, 1}}, rotatable = false}}
  assert(Moonpanel.Canvas.PolyominoSolver.Solve({cells = cells}, pieces).status ==
    'unsatisfied', 'bounded solver crossed an outer boundary')
  local wrapped = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = cells, wrapWidth = 3,
  }, pieces)
  assert(wrapped.status == 'solved' and wrapped.backend == 'dlx',
    'continuous solver did not wrap a legal placement')
end)

test.test('fixed polyominoes never reflect', function()
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {
      {x = 1, y = 1}, {x = 1, y = 2}, {x = 2, y = 2},
    },
  }, {
    {id = 1, shape = {{1, 1}, {1, 0}}, rotatable = false},
  })
  assert(result.status == 'unsatisfied', 'fixed L piece was reflected')
end)

test.test('rotatable pieces rotate but never need reflection', function()
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}, {x = 1, y = 2}, {x = 2, y = 2}},
  }, {
    {id = 1, shape = {{1, 1}, {1, 0}}, rotatable = true},
  })
  assert(result.status == 'solved', 'quarter-turn rotation was rejected')
end)

test.test('DLX covers disconnected regions and preserves holes', function()
  local disconnected = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}, {x = 3, y = 1}},
  }, {
    {id = 1, shape = {{1}}}, {id = 2, shape = {{1}}},
  })
  assert(disconnected.status == 'solved', 'disconnected exact cover failed')

  local ring = {}
  for y = 1, 3 do
    for x = 1, 3 do
      if x ~= 2 or y ~= 2 then ring[#ring + 1] = {x = x, y = y} end
    end
  end
  local hole = Moonpanel.Canvas.PolyominoSolver.Solve({cells = ring}, {{
    id = 1,
    shape = {{1, 1, 1}, {1, 0, 1}, {1, 1, 1}},
  }})
  assert(hole.status == 'solved', 'a legal hole was filled or rejected')
end)

test.test('duplicate positive pieces have deterministic placements', function()
  local input = {
    {id = 10, shape = {{1, 1}}, rotatable = true},
    {id = 20, shape = {{1, 1}}, rotatable = true},
  }
  local region = {cells = {
    {x = 1, y = 1}, {x = 2, y = 1},
    {x = 1, y = 2}, {x = 2, y = 2},
  }}
  local first = Moonpanel.Canvas.PolyominoSolver.Solve(region, input)
  local second = Moonpanel.Canvas.PolyominoSolver.Solve(region, input)
  assert(first.status == 'solved' and second.status == 'solved', 'duplicate pieces failed')
  assert(RuleEngine.HashValue(first.placements) == RuleEngine.HashValue(second.placements),
    'duplicate-piece witness changed between runs')
end)

test.test('DLX matches brute-force domino tiling on every 3x2 region', function()
  local function key(x, y) return x .. ':' .. y end
  local function brute(cells)
    local open = {}
    for _, cell in ipairs(cells) do open[key(cell.x, cell.y)] = true end
    local function search()
      local firstX, firstY
      for y = 1, 2 do
        for x = 1, 3 do
          if open[key(x, y)] then firstX, firstY = x, y break end
        end
        if firstX then break end
      end
      if not firstX then return true end
      open[key(firstX, firstY)] = nil
      for _, offset in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        local other = key(firstX + offset[1], firstY + offset[2])
        if open[other] then
          open[other] = nil
          if search() then open[key(firstX, firstY)] = true; open[other] = true; return true end
          open[other] = true
        end
      end
      open[key(firstX, firstY)] = true
      return false
    end
    return search()
  end

  for mask = 1, 63 do
    local cells = {}
    for offset = 0, 5 do
      if math.floor(mask / (2 ^ offset)) % 2 == 1 then
        cells[#cells + 1] = {x = offset % 3 + 1, y = math.floor(offset / 3) + 1}
      end
    end
    if #cells % 2 == 0 then
      local pieces = {}
      for id = 1, #cells / 2 do
        pieces[#pieces + 1] = {id = id, shape = {{1, 1}}, rotatable = true}
      end
      local solved = Moonpanel.Canvas.PolyominoSolver.Solve({cells = cells}, pieces)
      assert((solved.status == 'solved') == brute(cells),
        string.format('DLX/brute-force mismatch for region mask %d', mask))
    end
  end
end)

test.test('polyomino validity is translation invariant', function()
  local pieces = {
    {id = 1, shape = {{1, 1}}, rotatable = true},
    {id = 2, shape = {{1, 1}}, rotatable = true},
  }
  local first = {cells = {
    {x = 1, y = 1}, {x = 2, y = 1}, {x = 1, y = 2}, {x = 2, y = 2},
  }}
  local moved = {cells = {
    {x = 8, y = -3}, {x = 9, y = -3}, {x = 8, y = -2}, {x = 9, y = -2},
  }}
  assert(Moonpanel.Canvas.PolyominoSolver.Solve(first, pieces).status ==
    Moonpanel.Canvas.PolyominoSolver.Solve(moved, pieces).status,
    'translating geometry changed validity')
end)

test.test('impossible positive area is rejected before exact cover', function()
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}, {x = 2, y = 1}},
  }, {{id = 1, shape = {{1}}}})
  assert(result.status == 'unsatisfied', 'undercoverage was accepted')
end)

test.test('all triangle boundary masks count distinct physical edges', function()
  for mask = 0, 15 do
    for count = 1, 4 do
      local data = panel(1, 1)
      data.Extensions.FourTriangle = count == 4
      data.Entities[cellIndex(1, 1, 1)] = {
        Type = 'Triangle', Data = {Color = 9, RuleColor = 9, Count = count},
      }
      local topo, stacks = boundaryTrace(1, mask)
      local report = evaluate(data, topo, stacks)
      assert(report.success == (popcount(mask) == count),
        string.format('triangle mask %d/count %d was misclassified', mask, count))
    end
  end
end)

test.test('coincident symmetry branches count one triangle edge', function()
  local data = panel(1, 1)
  data.Entities[cellIndex(1, 1, 1)] = {
    Type = 'Triangle', Data = {Color = 9, RuleColor = 9, Count = 1},
  }
  local top = hpathIndex(1, 1, 1)
  local topo = topology({{}, {}}, {{1, 2, top}})
  assert(evaluate(data, topo, {{1, 2}, {1, 2}}).success,
    'coincident branches double-counted a physical boundary')
end)

test.test('four-triangle data requires its explicit extension flag', function()
  local data = panel(1, 1)
  data.Entities[cellIndex(1, 1, 1)] = {
    Type = 'Triangle', Data = {Color = 9, RuleColor = 9, Count = 4},
  }
  local report = evaluate(data)
  assert(report.status == 'data_error', 'strict four-triangle was silently accepted')
end)

test.test('malformed trace snapshots return a data error', function()
  local data = panel(1, 1)
  local topo = topology({{}}, {})
  local report = evaluate(data, topo, {{1, 99}})
  assert(report.status == 'data_error' and not report.success,
    'unknown canonical trace IDs were silently ignored')
end)

test.test('square conflicts mark every participating square', function()
  local data = panel(2, 1)
  data.Entities[cellIndex(2, 1, 1)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}
  data.Entities[cellIndex(2, 2, 1)] = {Type = 'Color', Data = {Color = 2, RuleColor = 2}}
  local report = evaluate(data)
  assert(not report.success and #report.violations == 2, 'square conflict was hidden')
end)

test.test('a traced boundary separates square colors', function()
  local data = panel(2, 1)
  data.Entities[cellIndex(2, 1, 1)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}
  data.Entities[cellIndex(2, 2, 1)] = {Type = 'Color', Data = {Color = 2, RuleColor = 2}}
  local boundary = vpathIndex(2, 2, 1)
  local topo = topology({
    {socketIndex = intersectionIndex(2, 2, 1)},
    {socketIndex = intersectionIndex(2, 2, 2)},
  }, {{1, 2, boundary}})
  assert(evaluate(data, topo, {{1, 2}}).success, 'square regions were not separated')
end)

test.test('continuous region construction joins the first and last columns', function()
  local data = panel(3, 1)
  data.Meta.Continuous = true
  data.Entities[cellIndex(3, 1, 1)] = {Type = 'Color', Data = {RuleColor = 1}}
  data.Entities[cellIndex(3, 3, 1)] = {Type = 'Color', Data = {RuleColor = 2}}
  local leftBoundary = vpathIndex(3, 2, 1)
  local rightBoundary = vpathIndex(3, 3, 1)
  local topo = topology({{}, {}, {}, {}}, {
    {1, 2, leftBoundary}, {3, 4, rightBoundary},
  })
  local stacks = {{1, 2}, {3, 4}}
  assert(evaluate(data, topo, stacks).success,
    'bounded control fixture did not separate the edge cells')
  topo.wrapX = true
  topo.revision = topo.revision + 1
  local wrappedReport = evaluate(data, topo, stacks)
  assert(not wrappedReport.success,
    'continuous seam failed to reconnect the first and last cells')
end)

test.test('one traced half of a midpoint boundary does not separate square colors', function()
  local data = panel(1, 2)
  data.Entities[cellIndex(1, 1, 1)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}
  data.Entities[cellIndex(1, 1, 2)] = {Type = 'Color', Data = {Color = 2, RuleColor = 2}}
  local boundary = hpathIndex(1, 1, 2)
  local topo = topology({
    {x = -0.5, y = 0, socketIndex = intersectionIndex(1, 1, 2)},
    {x = 0, y = 0, socketIndex = boundary, clickable = true},
    {x = 0.5, y = 0, socketIndex = intersectionIndex(1, 2, 2)},
  }, {
    {1, 2, boundary, {lengthQ = 2048}},
    {2, 3, boundary, {lengthQ = 2048}},
  })

  assert(not evaluate(data, topo, {{2, 1}}).success,
    'a midpoint start incorrectly closed its untraced boundary half')
  assert(evaluate(data, topo, {{1, 2, 3}}).success,
    'tracing both midpoint halves did not close the complete boundary')
end)

test.test('midpoint-start route around one square leaves its other half open', function()
  local data = panel(3, 3)
  data.SchemaVersion = 2
  -- This is the exact stale pairing authored by the v2 palette: the symbol is
  -- visibly white, but its hidden rule color was left at the black default.
  data.Entities[cellIndex(3, 1, 2)] = {Type = 'Color', Data = {Color = 2, RuleColor = 1}}
  data.Entities[cellIndex(3, 1, 3)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}

  local startBoundary = hpathIndex(3, 1, 3)
  local topo = topology({
    {x = -1, y = 0.5, socketIndex = startBoundary, clickable = true},
    {x = -1.5, y = 0.5, socketIndex = intersectionIndex(3, 1, 3)},
    {x = -1.5, y = -0.5, socketIndex = intersectionIndex(3, 1, 2)},
    {x = -0.5, y = -0.5, socketIndex = intersectionIndex(3, 2, 2)},
    {x = -0.5, y = 0.5, socketIndex = intersectionIndex(3, 2, 3)},
    {x = -0.5, y = 1.5, socketIndex = intersectionIndex(3, 2, 4)},
    {x = 0.5, y = 1.5, socketIndex = intersectionIndex(3, 3, 4)},
    {x = 1.5, y = 1.5, socketIndex = intersectionIndex(3, 4, 4)},
    {x = 1.5, y = 0.5, socketIndex = intersectionIndex(3, 4, 3)},
    {x = 1.5, y = -0.5, socketIndex = intersectionIndex(3, 4, 2)},
    {x = 1.5, y = -1.5, socketIndex = intersectionIndex(3, 4, 1)},
    {x = 1.5, y = -1.75, exit = true},
  }, {
    {1, 2, startBoundary, {lengthQ = 2048}},
    {1, 5, startBoundary, {lengthQ = 2048}},
    {2, 3, vpathIndex(3, 1, 2), {lengthQ = 4096}},
    {3, 4, hpathIndex(3, 1, 2), {lengthQ = 4096}},
    {4, 5, vpathIndex(3, 2, 2), {lengthQ = 4096}},
    {5, 6, vpathIndex(3, 2, 3), {lengthQ = 4096}},
    {6, 7, hpathIndex(3, 2, 4), {lengthQ = 4096}},
    {7, 8, hpathIndex(3, 3, 4), {lengthQ = 4096}},
    {8, 9, vpathIndex(3, 4, 3), {lengthQ = 4096}},
    {9, 10, vpathIndex(3, 4, 2), {lengthQ = 4096}},
    {10, 11, vpathIndex(3, 4, 1), {lengthQ = 4096}},
    {11, 12, intersectionIndex(3, 4, 1), {lengthQ = 1024}},
  })

  local report = evaluate(data, topo, {{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}})
  assert(not report.success,
    'the screenshot route incorrectly isolated the white and black squares')
end)

test.test('stars count another colored cell clue as their partner', function()
  local data = panel(2, 1)
  data.Entities[cellIndex(2, 1, 1)] = {Type = 'Sun', Data = {Color = 9, RuleColor = 9}}
  data.Entities[cellIndex(2, 2, 1)] = {
    Type = 'Triangle', Data = {Color = 9, RuleColor = 9, Count = 1},
  }
  local top = hpathIndex(2, 2, 1)
  local topo = topology({
    {socketIndex = intersectionIndex(2, 2, 1)},
    {socketIndex = intersectionIndex(2, 3, 1)},
  }, {{1, 2, top}})
  assert(evaluate(data, topo, {{1, 2}}).success, 'colored triangle did not partner star')
end)

test.test('semantic rule colors are independent from rendered tint', function()
  local data = panel(2, 1)
  setCell(data, 1, 'Color', {Color = 1, RuleColor = 3})
  setCell(data, 2, 'Color', {Color = 1, RuleColor = 4})
  assert(not evaluate(data).success, 'matching tints merged distinct rule colors')
end)

test.test('stars exclude route dots from colored partner counts', function()
  local data = panel(1, 1)
  setCell(data, 1, 'Sun', {Color = 5, RuleColor = 5})
  local dot = hpathIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon', Data = {Color = 5, RuleColor = 5, TraceRole = 0},
  }
  local topo = topology({{}, {}}, {{1, 2, dot}})
  local report = evaluate(data, topo, {{1, 2}})
  assert(not report.success and report.remaining[1] == cellIndex(1, 1, 1),
    'route dot incorrectly partnered a star')
end)

test.test('branch-specific dots use semantic trace roles', function()
  local data = panel(1, 1)
  data.Meta.Symmetry = 1
  local dot = intersectionIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon',
    Data = {Color = 7, RuleColor = 7, TraceRole = RuleEngine.DotRole.Secondary},
  }
  local topo = topology({
    {socketIndex = intersectionIndex(1, 2, 2)},
    {socketIndex = dot},
  })
  assert(evaluate(data, topo, {{1}, {2}}).success, 'secondary dot rejected secondary trace')
  assert(not evaluate(data, topo, {{2}, {1}}).success,
    'secondary dot accepted primary trace')
end)

test.test('negative dots invert only their selected trace role', function()
  local data = panel(1, 1)
  data.Meta.Symmetry = 1
  local dot = intersectionIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon',
    Data = {
      Color = 7,
      RuleColor = 7,
      TraceRole = RuleEngine.DotRole.Primary,
      Negative = true,
    },
  }
  local topo = topology({
    {socketIndex = dot},
    {socketIndex = intersectionIndex(1, 2, 2)},
  })
  assert(not evaluate(data, topo, {{1}, {2}}).success,
    'negative primary dot accepted the primary trace')
  assert(evaluate(data, topo, {{2}, {1}}).success,
    'negative primary dot rejected an unrelated secondary trace')
end)

test.test('negative any-trace dots reject vertex and edge coverage', function()
  local vertexData = panel(1, 1)
  local vertex = intersectionIndex(1, 1, 1)
  vertexData.Entities[vertex] = {
    Type = 'Hexagon',
    Data = {Color = 1, RuleColor = 1, TraceRole = 0, Negative = true},
  }
  local vertexTopology = topology({{socketIndex = vertex}}, {})
  assert(evaluate(vertexData, vertexTopology, {}).success,
    'uncovered negative vertex dot was rejected')
  assert(not evaluate(vertexData, vertexTopology, {{1}}).success,
    'covered negative vertex dot was accepted')

  local edgeData = panel(1, 1)
  local edge = hpathIndex(1, 1, 1)
  edgeData.Entities[edge] = {
    Type = 'Hexagon',
    Data = {Color = 1, RuleColor = 1, TraceRole = 0, Negative = true},
  }
  local edgeTopology = topology({{}, {}}, {{1, 2, edge}})
  assert(evaluate(edgeData, edgeTopology, {}).success,
    'uncovered negative edge dot was rejected')
  assert(not evaluate(edgeData, edgeTopology, {{1, 2}}).success,
    'covered negative edge dot was accepted')
end)

test.test('invisible dots retain ordinary validation semantics', function()
  local data = panel(1, 1)
  local dot = intersectionIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon',
    Data = {Color = 1, RuleColor = 1, TraceRole = 0, Invisible = true},
  }
  local topo = topology({{socketIndex = dot}}, {})
  assert(not evaluate(data, topo, {}).success,
    'uncovered invisible dot was accepted')
  assert(evaluate(data, topo, {{1}}).success,
    'covered invisible dot was rejected')
end)

test.test('invisible paths permanently separate rule regions', function()
  local data = panel(2, 1)
  local barrier = vpathIndex(2, 2, 1)
  data.Entities[barrier] = {Type = 'Invisible', Data = {}}
  local definition = RuleEngine.Compile(data, topology())
  local facts = RuleEngine.BuildFacts(definition, {revision = 9001, stacks = {}})
  assert(definition.permanentBoundaries[barrier] == true,
    'invisible path was not compiled as a permanent boundary')
  assert(#facts.regions == 2,
    'invisible path did not keep adjacent cell areas separate')
end)

test.test('secondary dots reject panels without a symmetry branch', function()
  local data = panel(1, 1)
  local dot = intersectionIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon', Data = {Color = 7, RuleColor = 7, TraceRole = 2},
  }
  assert(evaluate(data).status == 'data_error',
    'impossible secondary-only dot was accepted')
end)

test.test('signed polyomino can cancel outside the region', function()
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}},
  }, {
    {id = 1, shape = {{1, 1}}, rotatable = false},
    {id = 2, shape = {{1}}, rotatable = false, negative = true},
  })
  assert(result.status == 'solved' and result.backend == 'signed',
    'signed outside-region cancellation failed')
end)

test.test('equal signed area may cancel completely', function()
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}, {x = 2, y = 1}},
  }, {
    {id = 1, shape = {{1}}, rotatable = false},
    {id = 2, shape = {{1}}, rotatable = false, negative = true},
  })
  assert(result.status == 'solved' and result.target == 0,
    'zero-layer signed cancellation failed')
end)

test.test('negative-only and signed-area-impossible sets fail explicitly', function()
  local region = {cells = {{x = 1, y = 1}}}
  local negativeOnly = Moonpanel.Canvas.PolyominoSolver.Solve(region, {
    {id = 1, shape = {{1}}, negative = true},
  })
  assert(negativeOnly.status == 'unsatisfied', 'negative-only set was accepted')
  local wrongArea = Moonpanel.Canvas.PolyominoSolver.Solve(region, {
    {id = 1, shape = {{1, 1, 1}}},
    {id = 2, shape = {{1}}, negative = true},
  })
  assert(wrongArea.status == 'unsatisfied', 'impossible signed area was searched as valid')
end)

test.test('rotatable negative pieces rotate without reflecting', function()
  local region = {cells = {{x = 1, y = 1}}}
  local fixed = Moonpanel.Canvas.PolyominoSolver.Solve(region, {
    {id = 1, shape = {{1, 1, 1}}},
    {id = 2, shape = {{1}, {1}}, negative = true, rotatable = false},
  })
  local rotated = Moonpanel.Canvas.PolyominoSolver.Solve(region, {
    {id = 1, shape = {{1, 1, 1}}},
    {id = 2, shape = {{1}, {1}}, negative = true, rotatable = true},
  })
  assert(fixed.status == 'unsatisfied' and rotated.status == 'solved',
    'negative rotation semantics are incorrect')
end)

test.test('eraser removes a conflicting square deterministically', function()
  local data = panel(4, 1)
  data.Entities[cellIndex(4, 1, 1)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}
  data.Entities[cellIndex(4, 2, 1)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}
  local target = cellIndex(4, 3, 1)
  local eraser = cellIndex(4, 4, 1)
  data.Entities[target] = {Type = 'Color', Data = {Color = 2, RuleColor = 2}}
  data.Entities[eraser] = {Type = 'Eraser', Data = {Color = 2, RuleColor = 2}}
  local report = evaluate(data)
  assert(report.success, 'eraser did not repair square conflict')
  assert(#report.erasures == 1 and report.erasures[1].eraserIndex == eraser and
    report.erasures[1].targetIndex == target, 'eraser mapping was unstable')
end)

test.test('unnecessary erasers fail without inventing a target', function()
  local data = panel(1, 1)
  local eraser = cellIndex(1, 1, 1)
  data.Entities[eraser] = {Type = 'Eraser', Data = {Color = 1, RuleColor = 1}}
  local report = evaluate(data)
  assert(not report.success and report.remaining[1] == eraser,
    'unused eraser was not reported')
  assert(#report.erasures == 0, 'unused eraser invented an erasure')
end)

test.test('equivalent eraser targets choose the lowest stable socket', function()
  local data = panel(3, 1)
  local first = setCell(data, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 2, 'Color', {Color = 2, RuleColor = 2})
  setCell(data, 3, 'Eraser', {Color = 3, RuleColor = 3})
  local report = evaluate(data)
  assert(report.success and report.erasures[1].targetIndex == first,
    'equivalent eraser mapping was not lexicographically minimal')
end)

test.test('only necessary erasers receive clues before pair cancellation', function()
  local data = panel(5, 1)
  setCell(data, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 2, 'Color', {Color = 2, RuleColor = 2})
  setCell(data, 3, 'Color', {Color = 3, RuleColor = 3})
  setCell(data, 4, 'Eraser', {Color = 4, RuleColor = 4})
  setCell(data, 5, 'Eraser', {Color = 5, RuleColor = 5})
  local report = evaluate(data)
  assert(report.success and #report.erasures == 2,
    'a necessary simultaneous two-eraser assignment failed')

  local subsetValid = panel(4, 1)
  setCell(subsetValid, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(subsetValid, 2, 'Color', {Color = 2, RuleColor = 2})
  setCell(subsetValid, 3, 'Eraser', {Color = 3, RuleColor = 3})
  setCell(subsetValid, 4, 'Eraser', {Color = 4, RuleColor = 4})
  local complete = evaluate(subsetValid)
  assert(not complete.success and #complete.erasures == 1 and
    #complete.remaining == 1,
    'the solver did not preserve the unnecessary eraser as an error')
end)

test.test('erasers can target every clue family but never another eraser', function()
  local function erased(typeName, attributes, setup)
    local data = panel(2, 1)
    local target = setCell(data, 1, typeName, attributes)
    setCell(data, 2, 'Eraser', {Color = 8, RuleColor = 8})
    local topo, stacks = setup and setup(data) or topology(), {}
    local report = evaluate(data, topo, stacks)
    assert(report.success and report.erasures[1].targetIndex == target,
      typeName .. ' was not erasable')
  end

  erased('Sun', {Color = 1, RuleColor = 1})
  erased('Triangle', {Color = 9, RuleColor = 9, Count = 1})
  erased('Polyomino', {Color = 5, RuleColor = 5, Shape = {{1}}, Negative = false})

  local dots = panel(1, 1)
  local dot = hpathIndex(1, 1, 1)
  dots.Entities[dot] = {
    Type = 'Hexagon', Data = {Color = 1, RuleColor = 1, TraceRole = 0},
  }
  setCell(dots, 1, 'Eraser', {Color = 2, RuleColor = 2})
  local dotReport = evaluate(dots)
  assert(dotReport.success and dotReport.erasures[1].targetIndex == dot,
    'missed route clue did not inherit an eraser region')

  local two = panel(2, 1)
  local firstEraser = setCell(two, 1, 'Eraser', {Color = 1, RuleColor = 1})
  local secondEraser = setCell(two, 2, 'Eraser', {Color = 2, RuleColor = 2})
  local eraserReport = evaluate(two)
  assert(eraserReport.success and #eraserReport.erasures == 2 and
    eraserReport.erasures[1].eraserIndex == firstEraser and
    eraserReport.erasures[1].targetIndex == secondEraser and
    eraserReport.erasures[2].eraserIndex == secondEraser and
    eraserReport.erasures[2].targetIndex == firstEraser,
    'erasers did not mutually consume without self-targeting')
end)

test.test('an eraser cannot consume satisfied stars', function()
  local data = panel(2, 1)
  setCell(data, 1, 'Sun', {Color = 3, RuleColor = 3})
  local eraser = setCell(data, 2, 'Eraser', {Color = 3, RuleColor = 3})
  local report = evaluate(data)
  assert(not report.success and #report.erasures == 0 and
    report.remaining[1] == eraser,
    'an eraser manufactured work by deleting satisfied Suns')
end)

test.test('profiled eraser scoring preserves input data', function()
  local fixtures = {}

  local noEraser = panel(2, 1)
  setCell(noEraser, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(noEraser, 2, 'Color', {Color = 2, RuleColor = 2})
  fixtures[#fixtures + 1] = noEraser

  local oneEraser = panel(4, 1)
  setCell(oneEraser, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(oneEraser, 2, 'Color', {Color = 1, RuleColor = 1})
  setCell(oneEraser, 3, 'Color', {Color = 2, RuleColor = 2})
  setCell(oneEraser, 4, 'Eraser', {Color = 3, RuleColor = 3})
  fixtures[#fixtures + 1] = oneEraser

  local equivalent = panel(5, 1)
  setCell(equivalent, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(equivalent, 2, 'Color', {Color = 2, RuleColor = 2})
  setCell(equivalent, 3, 'Color', {Color = 3, RuleColor = 3})
  setCell(equivalent, 4, 'Eraser', {Color = 4, RuleColor = 4})
  setCell(equivalent, 5, 'Eraser', {Color = 5, RuleColor = 5})
  fixtures[#fixtures + 1] = equivalent

  local signed = panel(5, 1)
  setCell(signed, 1, 'Polyomino', {
    Color = 5, RuleColor = 5, Shape = {{1, 1, 1}}, Negative = false,
  })
  setCell(signed, 2, 'Polyomino', {
    Color = 5, RuleColor = 5, Shape = {{1}}, Negative = true,
  })
  setCell(signed, 3, 'Color', {Color = 1, RuleColor = 1})
  setCell(signed, 4, 'Color', {Color = 2, RuleColor = 2})
  setCell(signed, 5, 'Eraser', {Color = 3, RuleColor = 3})
  fixtures[#fixtures + 1] = signed

  for index, data in ipairs(fixtures) do
    local inputHash = RuleEngine.HashValue(data)
    local topo = topology()
    local definition = RuleEngine.Compile(data, topo)
    local snapshot = {revision = topo.revision, stacks = {}}
    local report = RuleEngine.Evaluate(definition, snapshot, {
      developmentProfile = true,
    })
    assert(report.reportHash and report.developmentProfile,
      string.format('profiled eraser report was incomplete for fixture %d', index))
    assert(RuleEngine.HashValue(data) == inputHash,
      string.format('verification mutated fixture %d', index))
  end
end)

test.test('eraser scoring reuses identical polyomino solves', function()
  local data = panel(4, 1)
  setCell(data, 1, 'Polyomino', {
    Color = 5, RuleColor = 5, Shape = {{1, 1, 1, 1, 1}}, Negative = false,
  })
  setCell(data, 2, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 3, 'Color', {Color = 2, RuleColor = 2})
  setCell(data, 4, 'Eraser', {Color = 3, RuleColor = 3})
  local topo = topology()
  local definition = RuleEngine.Compile(data, topo)
  local report = RuleEngine.Evaluate(definition, {
    revision = topo.revision,
    stacks = {},
  }, {
    developmentProfile = true,
  })
  local counters = report.developmentProfile.counters
  assert((counters.polyominoCacheHits or 0) > 0,
    'equivalent remaining polyomino sets were solved repeatedly')
  assert((counters.polyominoSolverCalls or 0) ==
    (counters.polyominoCacheMisses or 0), 'polyomino cache counters diverged')
end)

test.test('rule report hashes ignore insertion order', function()
  local data = panel(2, 1)
  data.Entities[cellIndex(2, 1, 1)] = {Type = 'Color', Data = {Color = 1, RuleColor = 1}}
  data.Entities[cellIndex(2, 2, 1)] = {Type = 'Color', Data = {Color = 2, RuleColor = 2}}
  local first = evaluate(data)
  local second = evaluate(data)
  assert(first.reportHash == second.reportHash, 'rule report hash was unstable')
end)

test.test('feedback manifests are pure and deterministic', function()
  local data = panel(3, 1)
  setCell(data, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 2, 'Color', {Color = 2, RuleColor = 2})
  setCell(data, 3, 'Eraser', {Color = 3, RuleColor = 3})
  local report = evaluate(data)
  local first = RuleEngine.FeedbackManifest(report)
  local second = RuleEngine.FeedbackManifest(report)
  assert(RuleEngine.HashValue(first) == RuleEngine.HashValue(second),
    'feedback manifest was nondeterministic')
  first.violations[1], first.remaining[1] = -1, -1
  if first.erasures[1] then first.erasures[1].targetIndex = -1 end
  assert(RuleEngine.HashValue(second) ==
    RuleEngine.HashValue(RuleEngine.FeedbackManifest(report)),
    'feedback manifest mutated its report')
end)

test.test('solver work yields through a coroutine budget', function()
  local yielded = 0
  local completed = false
  local worker = coroutine.create(function()
    local budget = RuleEngine.NewBudget({
      slice = 1,
      maximum = 100000,
      yieldFn = function() coroutine.yield('budget') end,
    })
    local result = Moonpanel.Canvas.PolyominoSolver.Solve({
      cells = {
        {x = 1, y = 1}, {x = 2, y = 1},
        {x = 1, y = 2}, {x = 2, y = 2},
      },
    }, {
      {id = 1, shape = {{1, 1}}, rotatable = true},
      {id = 2, shape = {{1, 1}}, rotatable = true},
    }, {
      checkpoint = function(amount) return budget:checkpoint(amount) end,
    })
    assert(result.status == 'solved', 'yielded DLX solve did not complete')
    completed = true
  end)
  while coroutine.status(worker) ~= 'dead' do
    local ok, reason = coroutine.resume(worker)
    assert(ok, reason)
    if reason == 'budget' then yielded = yielded + 1 end
  end
  assert(completed and yielded > 0, 'solver did not cooperatively yield')
end)

test.test('time budget yields before the logical work slice', function()
  local now = 0
  local yielded = 0
  local budget = RuleEngine.NewBudget({
    slice = 1000,
    sliceSeconds = 0.002,
    maximum = 1000,
    clock = function() return now end,
    yieldFn = function() yielded = yielded + 1 end,
  })
  for _ = 1, 5 do
    now = now + 0.001
    assert(budget:checkpoint(1))
  end
  assert(yielded == 2 and budget.yields == 2,
    'time deadline did not split verifier work predictably')
end)

test.test('verifier budget stops at its active-time limit', function()
  local now = 0
  local budget = RuleEngine.NewBudget({
    slice = 100000,
    maximum = 100000,
    maximumSeconds = 0.003,
    clock = function() return now end,
  })
  assert(budget:checkpoint(1), 'initial budget checkpoint was rejected')
  now = 0.003
  assert(not budget:checkpoint(1), 'active-time budget was not enforced')
  assert(budget.exhausted == 'time', 'active-time exhaustion reason was not recorded')
end)

test.test('verifier active-time budget excludes coroutine suspension', function()
  local now = 0
  local budget = RuleEngine.NewBudget({
    slice = 1,
    maximum = 100,
    maximumSeconds = 0.003,
    maximumWallSeconds = 5,
    clock = function() return now end,
    yieldFn = function() now = now + 1 end,
  })
  for _ = 1, 3 do
    now = now + 0.0005
    assert(budget:checkpoint(1),
      'scheduler suspension consumed the active verifier budget')
  end
  assert(budget:activeTime() < 0.003,
    'active verifier time included suspended intervals')
end)

test.test('verifier lifetime still bounds suspended coroutines', function()
  local now = 0
  local budget = RuleEngine.NewBudget({
    slice = 1,
    maximum = 100,
    maximumSeconds = 1,
    maximumWallSeconds = 0.5,
    clock = function() return now end,
    yieldFn = function() now = now + 0.6 end,
  })
  assert(budget:checkpoint(1), 'first verifier slice was rejected')
  assert(not budget:checkpoint(1), 'verifier lifetime ignored suspension')
  assert(budget.exhausted == 'lifetime',
    'lifetime exhaustion reason was not recorded')
end)

test.test('candidate generation is complexity-bounded', function()
  local budget = RuleEngine.NewBudget({slice = 100, maximum = 2})
  local result = Moonpanel.Canvas.PolyominoSolver.Solve({
    cells = {{x = 1, y = 1}},
  }, {
    {id = 1, shape = {{1, 1}}},
    {id = 2, shape = {{1}}, negative = true},
  }, {
    checkpoint = function(amount) return budget:checkpoint(amount) end,
  })
  assert(result.status == 'complexity', 'generation overran its explicit work limit')
end)

test.test('multi-eraser assignments stream through the work budget', function()
  local data = panel(12, 1)
  for x = 1, 8 do
    setCell(data, x, 'Color', {Color = x, RuleColor = x})
  end
  for x = 9, 12 do
    setCell(data, x, 'Eraser', {Color = x, RuleColor = x})
  end
  local definition = RuleEngine.Compile(data, topology())
  local budget = RuleEngine.NewBudget({slice = 100, maximum = 3})
  local report = RuleEngine.Evaluate(definition, {revision = 9001, stacks = {}}, {
    checkpoint = function(amount) return budget:checkpoint(amount) end,
  })
  assert(report.status == 'complexity',
    'eraser assignment generation ignored the cooperative work limit')
end)

test.test('coroutine slice size cannot change the report', function()
  local data = panel(4, 1)
  setCell(data, 1, 'Polyomino', {Color = 5, RuleColor = 5, Shape = {{1, 1}}})
  setCell(data, 2, 'Polyomino', {Color = 5, RuleColor = 5, Shape = {{1, 1}}, Rotational = true})
  local definition = RuleEngine.Compile(data, topology())
  local snapshot = {revision = 9001, stacks = {}}

  local function scheduled(slice)
    local result
    local worker = coroutine.create(function()
      local budget = RuleEngine.NewBudget({
        slice = slice,
        maximum = 100000,
        yieldFn = function() coroutine.yield('budget') end,
      })
      result = RuleEngine.Evaluate(definition, snapshot, {
        checkpoint = function(amount) return budget:checkpoint(amount) end,
      })
    end)
    while coroutine.status(worker) ~= 'dead' do
      local ok, reason = coroutine.resume(worker)
      assert(ok, reason)
    end
    return result
  end

  assert(scheduled(1).reportHash == scheduled(37).reportHash,
    'resume schedule changed the deterministic report')
end)

test.run()
