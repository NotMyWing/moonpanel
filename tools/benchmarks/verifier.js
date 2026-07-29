'use strict';

const fs = require('fs');
const { spawnSync } = require('child_process');

const sourcePath = process.argv[2] || '/tmp/moonpanel-windmill.txt';
const luaBinary = process.argv[3] || 'lua';
const caseName = process.argv[4] || 'windmill';
const maximumWork = Math.max(1, Number(process.argv[5]) || 1000);
const timeoutMs = Math.max(1000, Number(process.argv[6]) || 5000);

function luaString(value) {
  return JSON.stringify(value)
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

function toLua(value) {
  if (value === null || value === undefined) return 'nil';
  if (typeof value === 'boolean' || typeof value === 'number') return String(value);
  if (typeof value === 'string') return luaString(value);
  if (Array.isArray(value)) return `{${value.map(toLua).join(',')}}`;

  return `{${Object.keys(value).sort().map((key) => {
    const field = /^[A-Za-z_][A-Za-z0-9_]*$/.test(key)
      ? key
      : `[${luaString(key)}]`;
    return `${field}=${toLua(value[key])}`;
  }).join(',')}}`;
}

const panelData = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const script = `
dofile('tools/tests/harness.lua')
dofile('dest/lua/moonpanel/canvas/sh_dlx.lua')
dofile('dest/lua/moonpanel/canvas/sh_polyomino.lua')
local RuleEngine = dofile('dest/lua/moonpanel/canvas/sh_rule_engine.lua')
local GridTopology = dofile('tools/grid_topology.lua')
SysTime = os.clock

local function flatIndex(width, gridX, gridY)
  return 1 + (gridX - 1) + (gridY - 1) * (width * 2 + 1)
end

local function cellIndex(width, x, y)
  return flatIndex(width, x * 2, y * 2)
end

local function panel(width, height)
  local entities = {}
  for index = 1, (width * 2 + 1) * (height * 2 + 1) do entities[index] = {} end
  return {
    SchemaVersion = 7,
    Meta = {
      Width = width,
      Height = height,
      Symmetry = 0,
      Continuous = false,
      SymmetryOptions = {Colorful = false, Traces = {}},
    },
    Entities = entities,
    Extensions = {},
  }
end

local function setCell(data, x, typeName, clueData)
  data.Entities[cellIndex(data.Meta.Width, x, 1)] = {
    Type = typeName,
    Data = clueData,
  }
end

local oneEraser = panel(4, 1)
setCell(oneEraser, 1, 'Color', {RuleColor = 1})
setCell(oneEraser, 2, 'Color', {RuleColor = 1})
setCell(oneEraser, 3, 'Color', {RuleColor = 2})
setCell(oneEraser, 4, 'Eraser', {RuleColor = 2})

local noEraser = panel(2, 1)
setCell(noEraser, 1, 'Color', {RuleColor = 1})
setCell(noEraser, 2, 'Color', {RuleColor = 1})

local equivalentErasers = panel(5, 1)
for x = 1, 3 do setCell(equivalentErasers, x, 'Color', {RuleColor = x}) end
for x = 4, 5 do setCell(equivalentErasers, x, 'Eraser', {RuleColor = x}) end

local fourErasers = panel(8, 1)
for x = 1, 4 do setCell(fourErasers, x, 'Color', {RuleColor = x}) end
for x = 5, 8 do setCell(fourErasers, x, 'Eraser', {RuleColor = x}) end

local signedPoly = panel(5, 1)
setCell(signedPoly, 1, 'Polyomino', {
  RuleColor = 5, Shape = {{1, 1, 1}}, Negative = false,
})
setCell(signedPoly, 2, 'Polyomino', {
  RuleColor = 5, Shape = {{1}}, Negative = true,
})
setCell(signedPoly, 3, 'Color', {RuleColor = 1})
setCell(signedPoly, 4, 'Color', {RuleColor = 2})
setCell(signedPoly, 5, 'Eraser', {RuleColor = 3})

local cases = {
  {
    name = 'windmill',
    data = ${toLua(panelData)},
    trace = {
      {0, 5}, {0, 4}, {0, 3}, {0, 2}, {0, 1}, {0, 0},
      {1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 0},
    },
  },
  {name = 'no_eraser', data = noEraser},
  {name = 'one_eraser', data = oneEraser},
  {name = 'equivalent_erasers', data = equivalentErasers},
  {name = 'four_erasers', data = fourErasers},
  {name = 'signed_poly_eraser', data = signedPoly},
}

local function number(value)
  return string.format('%.6f', tonumber(value) or 0)
end

print(table.concat({
  'case', 'seconds', 'region_seconds', 'states', 'branches',
  'depth', 'revalidations', 'best_score', 'poly_calls', 'poly_hits', 'poly_misses', 'work',
  'remaining', 'status', 'success', 'hash',
}, '\\t'))

for _, fixture in ipairs(cases) do
  if fixture.name == ${luaString(caseName)} then
  local topo, nodeAt = GridTopology.build(fixture.data, 9001)
  local stack = {}
  for index, point in ipairs(fixture.trace or {}) do
    stack[index] = assert(nodeAt[GridTopology.key(point[1], point[2])])
  end
  local definition = RuleEngine.Compile(fixture.data, topo)
  local budget = RuleEngine.NewBudget({slice = ${maximumWork}, maximum = ${maximumWork}})
  local report = RuleEngine.Evaluate(definition, {
    revision = topo.revision,
    stacks = #stack > 0 and {stack} or {},
  }, {
    developmentProfile = true,
    checkpoint = function(amount) return budget:checkpoint(amount) end,
  })
  local profile = assert(report.developmentProfile)
  local counters = profile.counters
  local regionSeconds = 0
  for _, region in pairs(profile.regions) do
    regionSeconds = regionSeconds + (region.initialTime or 0) +
      (region.totalTime or 0)
  end
  print(table.concat({
    fixture.name,
    number(profile.timings.total),
    number(regionSeconds),
    tostring(counters.eraserStatesExplored or 0),
    tostring(counters.eraserBranches or 0),
    tostring(counters.maxRecursiveDepth or 0),
    tostring(counters.fullRegionRevalidations or 0),
    tostring(counters.bestEraserScore or 0),
    tostring(counters.polyominoSolverCalls or 0),
    tostring(counters.polyominoCacheHits or 0),
    tostring(counters.polyominoCacheMisses or 0),
    tostring(budget.total),
    tostring(#(report.remaining or {})),
    tostring(report.status),
    tostring(report.success),
    tostring(report.reportHash),
  }, '\\t'))
  end
end
`;

const result = spawnSync(luaBinary, ['-e', script], {
  cwd: process.cwd(),
  encoding: 'utf8',
  timeout: timeoutMs,
  killSignal: 'SIGKILL',
});

if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.error && result.error.code === 'ETIMEDOUT') {
  process.stderr.write(
    `benchmark timed out after ${timeoutMs} ms ` +
    `(case=${caseName}, work=${maximumWork})\n`,
  );
  process.exitCode = 124;
} else if (result.error) {
  if (result.status === null) throw result.error;
}
if (process.exitCode === undefined) {
  process.exitCode = result.status === null ? 1 : result.status;
}
