local sourcePath = assert(arg[1], 'panel data path is required')
local caseName = arg[2] or 'windmill'
local maximumWork = math.max(1, tonumber(arg[3]) or 1000)
local iterations = math.max(1, tonumber(arg[4]) or 1)
local ruleEnginePath = arg[5] or 'dest/lua/moonpanel/canvas/sh_rule_engine.lua'
local developmentProfile = arg[6] ~= 'false'
local cacheMode = arg[7] or 'warm'

dofile('tools/tests/harness.lua')
local RuleEngine = dofile(ruleEnginePath)
local GridTopology = dofile('tools/grid_topology.lua')
local Helpers = Moonpanel.Helpers
local panelData = dofile(sourcePath)

local function cellIndex(width, x, y)
  return Helpers.flatIndex(width, x * 2, y * 2)
end

local function panel(width, height)
  local entities = {}
  for index = 1, (width * 2 + 1) * (height * 2 + 1) do entities[index] = {} end
  entities[Helpers.flatIndex(width, 1, 1)] = {Type = 'Start', Data = {}}
  entities[Helpers.flatIndex(width, width * 2 + 1, 1)] = {Type = 'End', Data = {}}
  return {SchemaVersion = 7, Meta = {Width = width, Height = height, Symmetry = 0,
    Continuous = false, SymmetryOptions = {Colorful = false, Traces = {}}},
    Entities = entities, Extensions = {}}
end

local function setCell(data, x, typeName, clueData)
  data.Entities[cellIndex(data.Meta.Width, x, 1)] = {Type = typeName, Data = clueData}
end

local oneEraser = panel(4, 1)
setCell(oneEraser, 1, 'Color', {RuleColor = 1}); setCell(oneEraser, 2, 'Color', {RuleColor = 1})
setCell(oneEraser, 3, 'Color', {RuleColor = 2}); setCell(oneEraser, 4, 'Eraser', {RuleColor = 2})
local noEraser = panel(2, 1)
setCell(noEraser, 1, 'Color', {RuleColor = 1}); setCell(noEraser, 2, 'Color', {RuleColor = 1})
local equivalentErasers = panel(5, 1)
for x = 1, 3 do setCell(equivalentErasers, x, 'Color', {RuleColor = x}) end
for x = 4, 5 do setCell(equivalentErasers, x, 'Eraser', {RuleColor = x}) end
local fourErasers = panel(8, 1)
for x = 1, 4 do setCell(fourErasers, x, 'Color', {RuleColor = x}) end
for x = 5, 8 do setCell(fourErasers, x, 'Eraser', {RuleColor = x}) end
local fourStarErasers = panel(10, 1)
for x = 1, 4 do setCell(fourStarErasers, x, 'Sun', {RuleColor = x}) end
for x = 5, 6 do setCell(fourStarErasers, x, 'Color', {RuleColor = 9}) end
for x = 7, 10 do setCell(fourStarErasers, x, 'Eraser', {RuleColor = x}) end
local signedPoly = panel(5, 1)
setCell(signedPoly, 1, 'Polyomino', {RuleColor = 5, Shape = {{1, 1, 1}}, Negative = false})
setCell(signedPoly, 2, 'Polyomino', {RuleColor = 5, Shape = {{1}}, Negative = true})
setCell(signedPoly, 3, 'Color', {RuleColor = 1}); setCell(signedPoly, 4, 'Color', {RuleColor = 2})
setCell(signedPoly, 5, 'Eraser', {RuleColor = 3})
local exactPoly = panel(4, 2)
for x = 1, 4 do
  exactPoly.Entities[cellIndex(4, x, 1)] = {
    Type = 'Polyomino', Data = {RuleColor = 5, Shape = {{1, 1}}},
  }
end
local signedPolyStress = panel(4, 2)
for index = 1, 6 do
  local x, y = (index - 1) % 4 + 1, math.floor((index - 1) / 4) + 1
  signedPolyStress.Entities[cellIndex(4, x, y)] = {
    Type = 'Polyomino', Data = {
      RuleColor = 5, Shape = {{1, 1}}, Negative = index == 6,
    },
  }
end

local cases = {
  {name = 'windmill', data = panelData,
    trace = {{0,5},{0,4},{0,3},{0,2},{0,1},{0,0},{1,0},{2,0},{3,0},{4,0},{5,0}}},
  {name = 'no_eraser', data = noEraser}, {name = 'one_eraser', data = oneEraser},
  {name = 'equivalent_erasers', data = equivalentErasers},
  {name = 'four_erasers', data = fourErasers}, {name = 'signed_poly_eraser', data = signedPoly},
  {name = 'four_star_erasers', data = fourStarErasers},
  {name = 'poly_exact', data = exactPoly}, {name = 'poly_signed', data = signedPolyStress},
}

local function number(value) return string.format('%.6f', tonumber(value) or 0) end
local function topTrace(width)
  local trace = {}
  for x = 0, width do trace[#trace + 1] = {x, 0} end
  return trace
end
print(table.concat({'case','cpu_seconds','profile_seconds','region_seconds','iterations',
  'states','branches','depth','revalidations',
  'poly_calls','poly_hits','poly_misses','report_hits','fact_hits','persistent_poly_hits',
  'persistent_eraser_hits',
  'work','remaining','status','success','hash'}, '\t'))

for _, fixture in ipairs(cases) do
  if fixture.name == caseName then
    local topology, nodeAt = GridTopology.build(fixture.data, 9001)
    local stack = {}
    for index, point in ipairs(fixture.trace or topTrace(fixture.data.Meta.Width)) do
      stack[index] = assert(nodeAt[GridTopology.key(point[1], point[2])])
    end
    local definition = RuleEngine.Compile(fixture.data, topology)
    local solverCache = cacheMode ~= 'false' and RuleEngine.NewCache({ttl = 120}) or nil
    local report, budget
    local started = os.clock()
    for iteration = 1, iterations do
      if cacheMode == 'cold' then solverCache = RuleEngine.NewCache({ttl = 120}) end
      budget = RuleEngine.NewBudget({slice = maximumWork, maximum = maximumWork})
      report = RuleEngine.Evaluate(definition, {revision = topology.revision,
        stacks = #stack > 0 and {stack} or {}}, {
          cache = solverCache,
          traceHash = cacheMode == 'semantic' and iteration or nil,
          developmentProfile = developmentProfile,
          checkpoint = function(amount) return budget:checkpoint(amount) end,
        })
    end
    local cpuSeconds = (os.clock() - started) / iterations
    local profile = report.developmentProfile or {timings = {}, counters = {}, regions = {}}
    local counters = profile.counters
    local regionSeconds = 0
    for _, region in pairs(profile.regions) do
      regionSeconds = regionSeconds + (region.initialTime or 0) + (region.totalTime or 0)
    end
    print(table.concat({fixture.name, number(cpuSeconds), number(profile.timings.total),
      number(regionSeconds), iterations,
      counters.eraserStatesExplored or 0, counters.eraserBranches or 0, counters.maxRecursiveDepth or 0,
      counters.fullRegionRevalidations or 0,
      counters.polyominoSolverCalls or 0, counters.polyominoCacheHits or 0,
      counters.polyominoCacheMisses or 0, counters.exactReportCacheHits or 0,
      counters.traceFactsCacheHits or 0, counters.polyominoPersistentCacheHits or 0,
      counters.eraserPersistentCacheHits or 0,
      budget.total, #(report.remaining or {}), report.status,
      tostring(report.success), report.reportHash}, '\t'))
  end
end
