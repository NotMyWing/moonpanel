local test = dofile('tools/tests/harness.lua')

dofile('dest/lua/moonpanel/sh_colors.lua')
dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
dofile('dest/lua/moonpanel/canvas/sh_paneldata.lua')
local RuleEngine = dofile('dest/lua/moonpanel/canvas/sh_rule_engine.lua')
local GridTopology = dofile('tools/grid_topology.lua')

local fixtureModule = assert(arg[1], 'generated panel fixture module path is required')
local fixtures = dofile(fixtureModule)
local pointKey = GridTopology.key
local buildGridTopology = GridTopology.build

local function traceStacks(testCase, nodeAt, source, panel)
  local stacks = {}
  for branch, points in ipairs(testCase.traces or {}) do
    local stack = {}
    for index, point in ipairs(points) do
      local nodeId = nodeAt[pointKey(point[1], point[2])]
      assert(nodeId, string.format('%s trace %d point %d (%s, %s) is not an intersection',
        source, branch, index, tostring(point[1]), tostring(point[2])))
      stack[index] = nodeId
    end
    stacks[branch] = stack
  end
  local meta = panel.Meta or {}
  local symmetry = tonumber(meta.Symmetry) or Moonpanel.Canvas.Symmetry.None
  if #stacks == 1 and symmetry ~= Moonpanel.Canvas.Symmetry.None then
    local width, height = assert(meta.Width), assert(meta.Height)
    local mirrored = {}
    for index, point in ipairs(testCase.traces[1]) do
      local x, y = point[1], point[2]
      if symmetry == Moonpanel.Canvas.Symmetry.Vertical or
          symmetry == Moonpanel.Canvas.Symmetry.Rotational then
        x = width - x
      end
      if symmetry == Moonpanel.Canvas.Symmetry.Horizontal or
          symmetry == Moonpanel.Canvas.Symmetry.Rotational then
        y = height - y
      end
      mirrored[index] = assert(nodeAt[pointKey(x, y)],
        string.format('%s mirrored trace point %d (%s, %s) is not an intersection',
          source, index, tostring(x), tostring(y)))
    end
    stacks[2] = mirrored
  end
  return stacks
end

local function allSimpleTraces(spec, topology, nodeAt, source)
  local from = spec.from or {}
  local to = spec.to or {}
  local start = assert(nodeAt[pointKey(from[1], from[2])], source .. ': exhaustive trace start is not an intersection')
  local finish = assert(nodeAt[pointKey(to[1], to[2])], source .. ': exhaustive trace exit is not an intersection')
  local traces = {}
  local path = { start }
  local visited = { [start] = true }

  local function visit(nodeId)
    if nodeId == finish then
      local copy = {}
      for index, value in ipairs(path) do copy[index] = value end
      traces[#traces + 1] = { copy }
      return
    end
    for nextId in pairs(topology.edges[nodeId] or {}) do
      if not visited[nextId] then
        visited[nextId] = true
        path[#path + 1] = nextId
        visit(nextId)
        path[#path] = nil
        visited[nextId] = nil
      end
    end
  end

  visit(start)
  assert(#traces > 0, source .. ': exhaustive trace fixture has no start-to-exit routes')
  if spec.count then
    assert(#traces == spec.count,
      string.format('%s: expected %d simple routes, found %d', source, spec.count, #traces))
  end
  return traces
end

local function constraintKinds(report)
  local kinds = {}
  for _, constraint in ipairs(report.constraints or {}) do
    kinds[#kinds + 1] = constraint.kind
  end
  return kinds
end

local function sameValue(actual, expected)
  return RuleEngine.HashValue(actual) == RuleEngine.HashValue(expected)
end

local function polyominoBackends(report)
  local regions = {}
  for regionId in pairs((report.witnesses and report.witnesses.polyomino) or {}) do
    regions[#regions + 1] = regionId
  end
  table.sort(regions)
  local backends = {}
  for _, regionId in ipairs(regions) do
    backends[#backends + 1] = report.witnesses.polyomino[regionId].backend
  end
  return backends
end

local function checkExpected(report, expected, source, name, definition)
  local eraserTargets, nonEraserTargets = 0, 0
  for _, erasure in ipairs(report.erasures or {}) do
    local target = definition.clueById[erasure.targetIndex]
    if target and target.kind == 'eraser' then
      eraserTargets = eraserTargets + 1
    else
      nonEraserTargets = nonEraserTargets + 1
    end
  end
  local actualByName = {
    success = report.success,
    status = report.status,
    violations = report.violations,
    erasures = report.erasures,
    erasureCount = #(report.erasures or {}),
    eraserTargetCount = eraserTargets,
    nonEraserTargetCount = nonEraserTargets,
    remaining = report.remaining,
    remainingCount = #(report.remaining or {}),
    constraintKinds = constraintKinds(report),
    polyominoBackends = polyominoBackends(report),
    reportHash = report.reportHash,
    ruleRevision = report.ruleRevision,
  }
  for key, expectedValue in pairs(expected or {}) do
    assert(actualByName[key] ~= nil, source .. ': unsupported expected field ' .. key)
    assert(sameValue(actualByName[key], expectedValue),
      source .. ': ' .. name .. ': report field ' .. key .. ' did not match the fixture')
  end
end

for _, fixture in ipairs(fixtures) do
  local function normalizeLegacyKeys(value)
    if type(value) ~= 'table' then return value end
    local output = {}
    for key, child in pairs(value) do
      local numeric = type(key) == 'string' and tonumber(key) or nil
      local outputKey = key
      if numeric and numeric == math.floor(numeric) then outputKey = numeric end
      output[outputKey] = normalizeLegacyKeys(child)
    end
    return output
  end
  local panel = fixture.legacy and
    Moonpanel.Canvas.LegacyToCanvasData(normalizeLegacyKeys(fixture.panel)) or
    fixture.panel
  local topology, nodeAt = buildGridTopology(panel, fixture.topologyRevision)
  local definition = RuleEngine.Compile(panel, topology)
  for _, testCase in ipairs(fixture.tests or {}) do
    local function evaluate(stacks)
      return RuleEngine.Evaluate(definition, {
        revision = topology.revision,
        stacks = stacks,
      })
    end
    local exhaustive = testCase.allSimpleTraces and
      allSimpleTraces(testCase.allSimpleTraces, topology, nodeAt, fixture.source)
    if exhaustive and testCase.allSimpleTraces.solutions ~= nil then
      test.test(fixture.name .. ': ' .. testCase.name, function()
        local solved, solution = 0
        for _, stacks in ipairs(exhaustive) do
          local report = evaluate(stacks)
          if report.success then
            solved = solved + 1
            solution = report
          end
        end
        assert(solved == testCase.allSimpleTraces.solutions,
          string.format('%s: expected %d solutions, found %d',
            fixture.source, testCase.allSimpleTraces.solutions, solved))
        if solution then
          checkExpected(solution, testCase.expected, fixture.source, testCase.name, definition)
        end
      end)
    else
    local cases = { testCase }
    if exhaustive then
      cases = {}
      for index, stacks in ipairs(exhaustive) do
        cases[index] = {
          name = testCase.name .. ' #' .. index,
          traces = {},
          expected = testCase.expected,
          _stacks = stacks,
        }
      end
    end
    for _, case in ipairs(cases) do
      test.test(fixture.name .. ': ' .. case.name, function()
        local report = evaluate(
          case._stacks or traceStacks(case, nodeAt, fixture.source, panel))
        checkExpected(report, case.expected, fixture.source, testCase.name, definition)
      end)
    end
    end
  end
end

assert(#fixtures > 0, 'no saved-panel fixtures were discovered')
test.run()
