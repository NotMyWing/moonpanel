local test = dofile('tools/tests/harness.lua')

dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
local flatIndex = Moonpanel.Helpers.flatIndex
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

local function topology(nodes, edgeList, symmetryNodes)
  local value = {
    revision = 9001,
    nodes = nodes or {{clickable = true, exit = true}},
    edges = {},
    starts = {},
    exits = {},
    symmetryNodes = symmetryNodes or {},
    symmetryEdges = {},
  }
  for index, node in ipairs(value.nodes) do
    value.edges[index] = {}
    value.symmetryEdges[index] = {}
    if node.clickable then value.starts[#value.starts + 1] = index end
    if node.exit then value.exits[#value.exits + 1] = index end
  end
  for _, edge in ipairs(edgeList or {}) do
    local forward = {fromId = edge[1], toId = edge[2], socketIndex = edge[3]}
    local reverse = {fromId = edge[2], toId = edge[1], socketIndex = edge[3]}
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
  for fromId, edges in ipairs(value.edges) do
    for toId in pairs(edges) do
      local mirrorFrom, mirrorTo = value.symmetryNodes[fromId], value.symmetryNodes[toId]
      value.symmetryEdges[fromId][toId] = mirrorFrom and mirrorTo and
        value.edges[mirrorFrom] and value.edges[mirrorFrom][mirrorTo] or nil
    end
  end
  function value:getSymmetricalNodeId(nodeId) return self.symmetryNodes[nodeId] end
  function value:getSymmetricalEdge(fromId, toId)
    return self.symmetryEdges[fromId] and self.symmetryEdges[fromId][toId]
  end
  function value:isValidStart(nodeId)
    local node = self.nodes[nodeId]
    if not node or not node.clickable then return false end
    if #self.symmetryNodes == 0 then return true end
    local mirror = self.symmetryNodes[nodeId]
    return mirror and self.nodes[mirror] and self.nodes[mirror].clickable or false
  end
  return value
end

local function evaluate(data, topo, stacks)
  topo = topo or topology()
  local definition = RuleEngine.Compile(data, topo)
  return RuleEngine.Evaluate(definition, {
    revision = topo.revision,
    stacks = stacks or {{1}},
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
  local nodes, edges, stack = {{clickable = true}}, {}, {1}
  for side = 1, 4 do
    if math.floor(mask / (2 ^ (side - 1))) % 2 == 1 then
      local nextId = #nodes + 1
      nodes[nextId] = {}
      edges[#edges + 1] = {stack[#stack], nextId, sockets[side]}
      stack[#stack + 1] = nextId
    end
  end
  nodes[#nodes].exit = true
  return topology(nodes, edges), {stack}
end

local function setCell(data, x, typeName, attributes)
  data.Entities[cellIndex(data.Meta.Width, x, 1)] = {
    Type = typeName,
    Data = attributes,
  }
  return cellIndex(data.Meta.Width, x, 1)
end

test.test('positive exact cover returns a canonical witness', function()
  local result = RuleEngine.SolvePolyomino({
    cells = {{x = 1, y = 1}, {x = 2, y = 1}},
  }, {
    {id = 10, shape = {{1, 1}}, rotatable = false},
  })
  assert(result.status == 'solved' and result.backend == 'exact',
    'exact search did not solve domino')
  assert(#result.placements == 1 and result.placements[1].pieceId == 10,
    'exact-cover witness was not canonical')
end)

test.test('positive polyomino placements wrap across a continuous seam', function()
  local cells = {{x = 3, y = 1}, {x = 1, y = 1}}
  local pieces = {{id = 7, shape = {{1, 1}}, rotatable = false}}
  assert(RuleEngine.SolvePolyomino({cells = cells}, pieces).status ==
    'unsatisfied', 'bounded solver crossed an outer boundary')
  local wrapped = RuleEngine.SolvePolyomino({
    cells = cells, wrapWidth = 3,
  }, pieces)
  assert(wrapped.status == 'solved' and wrapped.backend == 'exact',
    'continuous solver did not wrap a legal placement')
end)

test.test('signed polyominoes cannot overlap themselves across a seam', function()
  local result = RuleEngine.SolvePolyomino({
    wrapWidth = 3,
    cells = {{x = 1, y = 1}, {x = 2, y = 1}, {x = 3, y = 1}},
  }, {
    {id = 1, shape = {{1, 1, 1, 1}}},
    {id = 2, shape = {{1}}, negative = true},
  })
  assert(result.status == 'unsatisfied',
    'a wrapped piece erased its own overlapping cell')
end)

test.test('fixed polyominoes never reflect', function()
  local result = RuleEngine.SolvePolyomino({
    cells = {
      {x = 1, y = 1}, {x = 1, y = 2}, {x = 2, y = 2},
    },
  }, {
    {id = 1, shape = {{1, 1}, {1, 0}}, rotatable = false},
  })
  assert(result.status == 'unsatisfied', 'fixed L piece was reflected')
end)

test.test('rotatable pieces rotate but never need reflection', function()
  local result = RuleEngine.SolvePolyomino({
    cells = {{x = 1, y = 1}, {x = 1, y = 2}, {x = 2, y = 2}},
  }, {
    {id = 1, shape = {{1, 1}, {1, 0}}, rotatable = true},
  })
  assert(result.status == 'solved', 'quarter-turn rotation was rejected')
end)

test.test('exact cover handles disconnected regions and holes', function()
  local disconnected = RuleEngine.SolvePolyomino({
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
  local hole = RuleEngine.SolvePolyomino({cells = ring}, {{
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
  local first = RuleEngine.SolvePolyomino(region, input)
  local second = RuleEngine.SolvePolyomino(region, input)
  assert(first.status == 'solved' and second.status == 'solved', 'duplicate pieces failed')
  assert(RuleEngine.HashValue(first.placements) == RuleEngine.HashValue(second.placements),
    'duplicate-piece witness changed between runs')
end)

test.test('exact search matches brute-force domino tiling on every 3x2 region', function()
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
      local solved = RuleEngine.SolvePolyomino({cells = cells}, pieces)
      assert((solved.status == 'solved') == brute(cells),
        string.format('exact/brute-force mismatch for region mask %d', mask))
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
  assert(RuleEngine.SolvePolyomino(first, pieces).status ==
    RuleEngine.SolvePolyomino(moved, pieces).status,
    'translating geometry changed validity')
end)

test.test('impossible positive area is rejected before exact cover', function()
  local result = RuleEngine.SolvePolyomino({
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

test.test('coincident symmetry branches are malformed', function()
  local data = panel(1, 1)
  data.Meta.Symmetry = 1
  data.Entities[cellIndex(1, 1, 1)] = {
    Type = 'Triangle', Data = {Color = 9, RuleColor = 9, Count = 1},
  }
  local top = hpathIndex(1, 1, 1)
  local topo = topology({
    {clickable = true}, {exit = true},
  }, {{1, 2, top}}, {1, 2})
  assert(evaluate(data, topo, {{1, 2}, {1, 2}}).status == 'data_error',
    'coincident symmetry branches were accepted')
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

test.test('completed trace validation rejects malformed paths deterministically', function()
  local data = panel(1, 1)
  local topo = topology({{clickable = true}, {}, {exit = true}}, {
    {1, 2, hpathIndex(1, 1, 1)},
    {2, 3, vpathIndex(1, 2, 1)},
  })
  local cases = {
    {}, {{1, 2}}, {{2, 3}}, {{1, 3}}, {{1, 2, 1, 2, 3}},
  }
  for index, stacks in ipairs(cases) do
    local first = evaluate(data, topo, stacks)
    local second = evaluate(data, topo, stacks)
    assert(first.status == 'data_error' and first.reportHash == second.reportHash,
      'malformed trace case ' .. index .. ' was accepted or unstable')
  end
end)

test.test('completed trace validation rejects non-array snapshot metadata', function()
  local data = panel(1, 1)
  local topo = topology({{clickable = true}, {exit = true}}, {
    {1, 2, hpathIndex(1, 1, 1)},
  })
  local cases = {
    {{1, 2}, note = true},
    {{1, 2, note = true}},
    {{1, 2}, [0] = {}},
    {{1, 2}, [2] = 'not a branch'},
  }
  for index, stacks in ipairs(cases) do
    local report = evaluate(data, topo, stacks)
    assert(report.status == 'data_error' and not report.success,
      'non-array trace snapshot case ' .. index .. ' was accepted')
  end
end)

test.test('symmetry traces require the physical topology transformation', function()
  local data = panel(2, 1)
  data.Meta.Symmetry = 1
  local topo = topology({
    {clickable = true}, {exit = true}, {clickable = true}, {exit = true},
  }, {
    {1, 2, hpathIndex(2, 1, 1)}, {3, 4, hpathIndex(2, 2, 1)},
  }, {3, 4, 1, 2})
  assert(evaluate(data, topo, {{1, 2}, {3, 4}}).status == 'complete')
  assert(evaluate(data, topo, {{1, 2}, {4, 3}}).status == 'data_error',
    'a reversed symmetry branch was accepted')
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
    {socketIndex = intersectionIndex(2, 2, 1), clickable = true},
    {socketIndex = intersectionIndex(2, 2, 2)},
    {exit = true},
  }, {{1, 2, boundary}, {2, 3, intersectionIndex(2, 2, 2)}})
  assert(evaluate(data, topo, {{1, 2, 3}}).success,
    'square regions were not separated')
end)

test.test('continuous region construction joins the first and last columns', function()
  local data = panel(3, 1)
  data.Meta.Continuous = true
  data.Entities[cellIndex(3, 1, 1)] = {Type = 'Color', Data = {RuleColor = 1}}
  data.Entities[cellIndex(3, 3, 1)] = {Type = 'Color', Data = {RuleColor = 2}}
  local leftBoundary = vpathIndex(3, 2, 1)
  local rightBoundary = vpathIndex(3, 3, 1)
  local topo = topology({{clickable = true}, {}, {}, {exit = true}}, {
    {1, 2, leftBoundary}, {2, 3, intersectionIndex(3, 2, 1)},
    {3, 4, rightBoundary},
  })
  local stacks = {{1, 2, 3, 4}}
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
    {x = -0.5, y = 0, socketIndex = intersectionIndex(1, 1, 2), clickable = true},
    {x = 0, y = 0, socketIndex = boundary, clickable = true},
    {x = 0.5, y = 0, socketIndex = intersectionIndex(1, 2, 2)},
    {exit = true},
    {exit = true},
  }, {
    {1, 2, boundary, {lengthQ = 2048}},
    {2, 3, boundary, {lengthQ = 2048}},
    {1, 4, intersectionIndex(1, 1, 2)},
    {3, 5, intersectionIndex(1, 2, 2)},
  })

  assert(not evaluate(data, topo, {{2, 1, 4}}).success,
    'a midpoint start incorrectly closed its untraced boundary half')
  assert(evaluate(data, topo, {{1, 2, 3, 5}}).success,
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
    {socketIndex = intersectionIndex(2, 2, 1), clickable = true},
    {socketIndex = intersectionIndex(2, 3, 1), exit = true},
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
  local topo = topology({{clickable = true}, {exit = true}}, {{1, 2, dot}})
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
    Data = {Color = 7, RuleColor = 7, TraceRole = 2},
  }
  local topo = topology({
    {socketIndex = intersectionIndex(1, 2, 2), clickable = true, exit = true},
    {socketIndex = dot, clickable = true, exit = true},
  }, nil, {2, 1})
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
      TraceRole = 1,
      Negative = true,
    },
  }
  local topo = topology({
    {socketIndex = dot, clickable = true, exit = true},
    {socketIndex = intersectionIndex(1, 2, 2), clickable = true, exit = true},
  }, nil, {2, 1})
  assert(not evaluate(data, topo, {{1}, {2}}).success,
    'negative primary dot accepted the primary trace')
  assert(evaluate(data, topo, {{2}, {1}}).success,
    'negative primary dot rejected an unrelated secondary trace')
end)

test.test('invalid clues in either mirrored region are evaluated', function()
  local data = panel(4, 1)
  data.Meta.Symmetry = 1
  data.Entities[cellIndex(4, 1, 1)] = {
    Type = 'Polyomino',
    Data = {RuleColor = 5, Shape = {{1, 1}}, Negative = false},
  }
  local leftBoundary, rightBoundary = vpathIndex(4, 2, 1), vpathIndex(4, 4, 1)
  local topo = topology({
    {clickable = true}, {}, {exit = true},
    {clickable = true}, {}, {exit = true},
  }, {
    {1, 2, leftBoundary}, {2, 3, intersectionIndex(4, 2, 1)},
    {4, 5, rightBoundary}, {5, 6, intersectionIndex(4, 4, 1)},
  }, {4, 5, 6, 1, 2, 3})
  local report = evaluate(data, topo, {{1, 2, 3}, {4, 5, 6}})
  assert(not report.success and report.constraints[1].kind == 'polyomino',
    'the non-canonical mirrored region was skipped')
end)

test.test('negative any-trace dots reject vertex and edge coverage', function()
  local vertexData = panel(1, 1)
  local vertex = intersectionIndex(1, 1, 1)
  vertexData.Entities[vertex] = {
    Type = 'Hexagon',
    Data = {Color = 1, RuleColor = 1, TraceRole = 0, Negative = true},
  }
  local vertexTopology = topology({{clickable = true, exit = true}}, {})
  assert(evaluate(vertexData, vertexTopology, {{1}}).success,
    'uncovered negative vertex dot was rejected')
  vertexTopology.nodes[1].socketIndex = vertex
  assert(not evaluate(vertexData, vertexTopology, {{1}}).success,
    'covered negative vertex dot was accepted')

  local edgeData = panel(1, 1)
  local edge = hpathIndex(1, 1, 1)
  edgeData.Entities[edge] = {
    Type = 'Hexagon',
    Data = {Color = 1, RuleColor = 1, TraceRole = 0, Negative = true},
  }
  local edgeTopology = topology()
  assert(evaluate(edgeData, edgeTopology, {{1}}).success,
    'uncovered negative edge dot was rejected')
  edgeTopology = topology({{clickable = true}, {exit = true}}, {{1, 2, edge}})
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
  local topo = topology()
  assert(not evaluate(data, topo, {{1}}).success,
    'uncovered invisible dot was accepted')
  topo.nodes[1].socketIndex = dot
  assert(evaluate(data, topo, {{1}}).success,
    'covered invisible dot was rejected')
end)

test.test('invisible paths permanently separate rule regions', function()
  local data = panel(2, 1)
  local barrier = vpathIndex(2, 2, 1)
  data.Entities[barrier] = {Type = 'Invisible', Data = {}}
  data.Entities[cellIndex(2, 1, 1)] = {
    Type = 'Color', Data = {RuleColor = 1},
  }
  data.Entities[cellIndex(2, 2, 1)] = {
    Type = 'Color', Data = {RuleColor = 2},
  }
  assert(evaluate(data).success,
    'invisible path did not keep conflicting colors in separate regions')
end)

test.test('continuous seam aliases compile to one physical socket', function()
  local width = 3
  local leftNode, rightNode = intersectionIndex(width, 1, 1),
    intersectionIndex(width, width + 1, 1)
  for _, authored in ipairs({leftNode, rightNode}) do
    local data = panel(width, 1)
    data.Meta.Continuous = true
    data.Entities[authored] = {
      Type = 'Hexagon', Data = {RuleColor = 1, TraceRole = 0},
    }
    local topo = topology({{
      clickable = true, exit = true,
      socketIndex = authored == leftNode and rightNode or leftNode,
    }})
    topo.wrapX = true
    local definition = RuleEngine.Compile(data, topo)
    local report = RuleEngine.Evaluate(definition, {revision = 9001, stacks = {{1}}})
    assert(report.success and definition.clues[1].id == leftNode,
      'a seam clue depended on its authored alias')
  end

  local left = vpathIndex(width, 1, 1)
  local right = vpathIndex(width, width + 1, 1)
  for _, authored in ipairs({left, right}) do
    local data = panel(width, 1)
    data.Meta.Continuous = true
    data.Entities[authored] = {Type = 'Invisible', Data = {}}
    local topo = topology()
    topo.wrapX = true
    local definition = RuleEngine.Compile(data, topo)
    assert(definition.permanentBoundaries[left] and not definition.permanentBoundaries[right],
      'invisible seam boundary retained an alias identity')
  end

  local data = panel(width, 1)
  data.Meta.Continuous = true
  data.Entities[vpathIndex(width, 2, 1)] = {Type = 'Invisible', Data = {}}
  data.Entities[cellIndex(width, 1, 1)] = {
    Type = 'Color', Data = {RuleColor = 1},
  }
  data.Entities[cellIndex(width, 2, 1)] = {
    Type = 'Color', Data = {RuleColor = 2},
  }
  local topo = topology({{clickable = true}, {}, {exit = true}}, {
    {1, 2, right}, {2, 3, intersectionIndex(width, 1, 1)},
  })
  topo.wrapX = true
  local definition = RuleEngine.Compile(data, topo)
  local report = RuleEngine.Evaluate(definition, {revision = 9001, stacks = {{1, 2, 3}}})
  assert(report.success,
    'traced seam alias did not close the canonical physical boundary')
end)

test.test('the compiler rejects duplicate continuous seam aliases directly', function()
  local data = panel(3, 1)
  data.Meta.Continuous = true
  data.Entities[1] = {Type = 'Hexagon', Data = {RuleColor = 1}}
  data.Entities[7] = {Type = 'Hexagon', Data = {RuleColor = 1}}
  local topo = topology()
  topo.wrapX = true
  local report = evaluate(data, topo, {{1}})
  local details = report.constraints[1].details.errors[1]
  assert(report.status == 'data_error' and details.code == 'continuous_seam_duplicate' and
    details.leftIndex == 1 and details.rightIndex == 7,
    'direct compilation normalized a duplicate seam entity')
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
  local result = RuleEngine.SolvePolyomino({
    cells = {{x = 1, y = 1}},
  }, {
    {id = 1, shape = {{1, 1}}, rotatable = false},
    {id = 2, shape = {{1}}, rotatable = false, negative = true},
  })
  assert(result.status == 'solved' and result.backend == 'signed',
    'signed outside-region cancellation failed')
end)

test.test('equal signed area may cancel completely', function()
  local result = RuleEngine.SolvePolyomino({
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
  local negativeOnly = RuleEngine.SolvePolyomino(region, {
    {id = 1, shape = {{1}}, negative = true},
  })
  assert(negativeOnly.status == 'unsatisfied', 'negative-only set was accepted')
  local wrongArea = RuleEngine.SolvePolyomino(region, {
    {id = 1, shape = {{1, 1, 1}}},
    {id = 2, shape = {{1}}, negative = true},
  })
  assert(wrongArea.status == 'unsatisfied', 'impossible signed area was searched as valid')
end)

test.test('rotatable negative pieces rotate without reflecting', function()
  local region = {cells = {{x = 1, y = 1}}}
  local fixed = RuleEngine.SolvePolyomino(region, {
    {id = 1, shape = {{1, 1, 1}}},
    {id = 2, shape = {{1}, {1}}, negative = true, rotatable = false},
  })
  local rotated = RuleEngine.SolvePolyomino(region, {
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

test.test('every eraser is necessary for an accepted full assignment', function()
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
  local firstTarget = setCell(subsetValid, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(subsetValid, 2, 'Color', {Color = 2, RuleColor = 2})
  local firstEraser = setCell(subsetValid, 3, 'Eraser', {Color = 3, RuleColor = 3})
  local secondEraser = setCell(subsetValid, 4, 'Eraser', {Color = 4, RuleColor = 4})
  local complete = evaluate(subsetValid)
  assert(not complete.success and #complete.erasures == 1 and
    complete.erasures[1].eraserIndex == firstEraser and
    complete.erasures[1].targetIndex == firstTarget and
    complete.remaining[1] == secondEraser and
    complete.constraints[1].kind == 'eraser_unnecessary',
    'the minimal improper assignment was not exposed')
end)

test.test('erasers can target every clue family but never another eraser', function()
  local function erased(typeName, attributes, setup)
    local data = panel(2, 1)
    local target = setCell(data, 1, typeName, attributes)
    setCell(data, 2, 'Eraser', {Color = 8, RuleColor = 8})
    local topo, stacks = setup and setup(data) or topology(), {{1}}
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
  assert(not eraserReport.success and #eraserReport.erasures == 0 and
    eraserReport.remaining[1] == firstEraser and
    eraserReport.remaining[2] == secondEraser,
    'erasers targeted each other')
end)

test.test('a satisfied star and eraser pair leaves the eraser unnecessary', function()
  local data = panel(2, 1)
  setCell(data, 1, 'Sun', {Color = 3, RuleColor = 3})
  local eraser = setCell(data, 2, 'Eraser', {Color = 3, RuleColor = 3})
  local report = evaluate(data)
  assert(not report.success and #report.erasures == 0 and
    report.remaining[1] == eraser and
    report.constraints[1].kind == 'eraser_unnecessary',
    'a satisfied star pair invented work for its eraser')
end)

test.test('premature cancellation witnesses are deterministic', function()
  local data = panel(4, 1)
  local firstTarget = setCell(data, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 2, 'Color', {Color = 2, RuleColor = 2})
  local firstEraser = setCell(data, 3, 'Eraser', {Color = 3, RuleColor = 3})
  local secondEraser = setCell(data, 4, 'Eraser', {Color = 4, RuleColor = 4})
  local report = evaluate(data)
  local proof = report.witnesses.erasers[1]
  assert(not report.success and #report.erasures == 1 and
    report.erasures[1].eraserIndex == firstEraser and
    report.erasures[1].targetIndex == firstTarget and
    report.remaining[1] == secondEraser and proof.minimumUsed == 1 and
    proof.improperAssignment.erasers[1] == firstEraser and
    #proof.fullAssignment.erasers == 2,
    'premature witness ordering was unstable')
end)

test.test('sequential necessity accepts a star-first full assignment', function()
  local data = panel(6, 1)
  setCell(data, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 2, 'Color', {Color = 1, RuleColor = 1})
  local square = setCell(data, 3, 'Color', {Color = 2, RuleColor = 2})
  local star = setCell(data, 4, 'Sun', {Color = 2, RuleColor = 2})
  local firstEraser = setCell(data, 5, 'Eraser', {Color = 2, RuleColor = 2})
  local secondEraser = setCell(data, 6, 'Eraser', {Color = 2, RuleColor = 2})
  local report = evaluate(data)
  assert(report.success and #report.erasures == 2 and
    report.erasures[1].eraserIndex == firstEraser and
    report.erasures[1].targetIndex == star and
    report.erasures[2].eraserIndex == secondEraser and
    report.erasures[2].targetIndex == square,
    'the solver rejected the necessary star-first cancellation order')
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
    local snapshot = {revision = topo.revision, stacks = {{1}}}
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
    stacks = {{1}},
  }, {
    developmentProfile = true,
  })
  local counters = report.developmentProfile.counters
  assert((counters.polyominoCacheHits or 0) > 0,
    'equivalent remaining polyomino sets were solved repeatedly')
  assert((counters.polyominoSolverCalls or 0) ==
    (counters.polyominoCacheMisses or 0), 'polyomino cache counters diverged')
end)

test.test('canvas-owned solver caches are exact, isolated, and expiring', function()
  local data = panel(1, 1)
  setCell(data, 1, 'Polyomino', {
    Color = 5, RuleColor = 5, Shape = {{1}}, Negative = false,
  })
  local topo = topology()
  local definition = RuleEngine.Compile(data, topo)
  local now = 10
  local cache = RuleEngine.NewCache({ttl = 120, clock = function() return now end})
  local snapshot = {revision = topo.revision, stacks = {{1}}}
  local function run(traceHash)
    return RuleEngine.Evaluate(definition, snapshot, {
      cache = cache,
      traceHash = traceHash,
      developmentProfile = true,
    })
  end

  local first = run(101)
  local repeated = run(101)
  local sameRegion = run(102)
  repeated.witnesses.polyomino[1].placements[1].pieceId = -1
  local isolated = run(101)
  now = 131
  RuleEngine.PruneCache(cache, true)
  local physicallyExpired = (cache.reports.count or 0) == 0 and
    (cache.facts.count or 0) == 0 and (cache.polyominoes.count or 0) == 0
  local expired = run(102)

  assert((first.developmentProfile.counters.polyominoSolverCalls or 0) == 1,
    'the cold cache skipped the polyomino solver')
  assert((repeated.developmentProfile.counters.exactReportCacheHits or 0) == 1,
    'an identical trace did not reuse its complete report')
  assert((sameRegion.developmentProfile.counters.polyominoPersistentCacheHits or 0) == 1,
    'a different trace identity did not reuse the same physical polyomino region')
  assert(isolated.witnesses.polyomino[1].placements[1].pieceId ~= -1,
    'a returned report mutated the cached solver proof')
  assert(physicallyExpired and
    (expired.developmentProfile.counters.exactReportCacheMisses or 0) == 1 and
    (expired.developmentProfile.counters.polyominoSolverCalls or 0) == 1,
    'a solver cache entry survived beyond its absolute TTL')
end)

test.test('canvas-owned cache reuses equivalent eraser regions', function()
  local data = panel(3, 1)
  setCell(data, 1, 'Color', {Color = 1, RuleColor = 1})
  setCell(data, 2, 'Color', {Color = 2, RuleColor = 2})
  setCell(data, 3, 'Eraser', {Color = 3, RuleColor = 3})
  local topo = topology()
  local definition = RuleEngine.Compile(data, topo)
  local cache = RuleEngine.NewCache()
  local snapshot = {revision = topo.revision, stacks = {{1}}}
  local function run(traceHash)
    return RuleEngine.Evaluate(definition, snapshot, {
      cache = cache,
      traceHash = traceHash,
      developmentProfile = true,
    })
  end
  local first = run(201)
  local equivalent = run(202)
  assert(first.success and equivalent.success and
    (equivalent.developmentProfile.counters.eraserPersistentCacheHits or 0) == 1,
    'an equivalent physical eraser region repeated its assignment search')
end)

test.test('solver cache never retains interrupted results', function()
  local data = panel(1, 1)
  setCell(data, 1, 'Polyomino', {
    Color = 5, RuleColor = 5, Shape = {{1}}, Negative = false,
  })
  local topo = topology()
  local definition = RuleEngine.Compile(data, topo)
  local cache = RuleEngine.NewCache()
  local snapshot = {revision = topo.revision, stacks = {{1}}}
  local function run(maximum)
    local budget = RuleEngine.NewBudget({slice = maximum, maximum = maximum})
    return RuleEngine.Evaluate(definition, snapshot, {
      cache = cache,
      developmentProfile = true,
      checkpoint = function(amount) return budget:checkpoint(amount) end,
    })
  end
  local interrupted = run(1)
  local completed = run(10000)
  assert(interrupted.status == 'complexity' and completed.status == 'complete' and
    (completed.developmentProfile.counters.exactReportCacheHits or 0) == 0 and
    (completed.developmentProfile.counters.polyominoSolverCalls or 0) == 1,
    'an interrupted proof contaminated the semantic solver cache')
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
    local result = RuleEngine.SolvePolyomino({
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
    assert(result.status == 'solved', 'yielded exact solve did not complete')
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
  local result = RuleEngine.SolvePolyomino({
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
  local report = RuleEngine.Evaluate(definition, {revision = 9001, stacks = {{1}}}, {
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
  local snapshot = {revision = 9001, stacks = {{1}}}

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
