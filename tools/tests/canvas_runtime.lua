local test = dofile('tools/tests/harness.lua')

CLIENT = false
SERVER = false
resource = { AddFile = function() end }
util = { TraceLine = function() return { Hit = false, Fraction = 1 } end }
Material = function(path) return { path = path } end
Sound = function(path) return path end
isstring = function(value) return type(value) == 'string' end
isnumber = function(value) return type(value) == 'number' end
istable = function(value) return type(value) == 'table' end
math.Round = math.Round or function(value)
  return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end
table.Count = table.Count or function(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end
table.Copy = table.Copy or function(value, seen)
  if type(value) ~= 'table' then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local output = {}
  seen[value] = output
  for key, child in pairs(value) do
    output[table.Copy(key, seen)] = table.Copy(child, seen)
  end
  return output
end

local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
vectorMeta.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
vectorMeta.__mul = function(a, b)
  if type(a) == 'number' then return Vector(a * b.x, a * b.y, a * b.z) end
  if type(b) == 'number' then return Vector(a.x * b, a.y * b, a.z * b) end
  return Vector(a.x * b.x, a.y * b.y, a.z * b.z)
end
vectorMeta.__div = function(a, b) return Vector(a.x / b, a.y / b, a.z / b) end
function Vector(x, y, z)
  if type(x) == 'table' then return setmetatable({x = x.x, y = x.y, z = x.z}, vectorMeta) end
  return setmetatable({x = x or 0, y = y or 0, z = z or 0}, vectorMeta)
end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end
function Matrix()
  return setmetatable({
    SetAngles = function() end,
    SetTranslation = function() end,
    SetScale = function() end,
  }, { __mul = function() return Matrix() end })
end

Moonpanel.Color = {
  Black = 1, White = 2, Cyan = 3, Magenta = 4, Yellow = 5,
  Red = 6, Green = 7, Blue = 8, Orange = 9,
}
Moonpanel.Rect = function(x, y, width, height)
  return { x = x, y = y, width = width, height = height }
end

local canvasRoot = 'dest/lua/moonpanel/canvas/'
include = function(path)
  return dofile(canvasRoot .. path)
end
dofile(canvasRoot .. 'sh_helpers.lua')
dofile(canvasRoot .. 'sh_canvas.lua')

local function fixture(name)
  for _, entry in ipairs(dofile('dest/test/panel_fixtures.lua')) do
    if entry.name == name then return entry.panel end
  end
  error('missing generated panel fixture: ' .. name)
end

test.test('real canvas import preserves pillartest wrapping sockets', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData(fixture('pillartest'))
  assert(canvas:IsContinuous(), 'real canvas discarded continuous topology')
  local pathfinder = assert(canvas:GetPathFinder(), 'real canvas did not build a pathfinder')
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
  local topology = canvas:GetPathFinder().topology
  assert(topology.surfaceKind == Moonpanel.Canvas.SurfaceKind.Pillar and topology.wrapX,
    'pillar surface values did not reach TraceTopology')
end)

test.test('real pillartest pathfinder traverses all four wrapping sockets', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData(fixture('pillartest'))
  local topology = canvas:GetPathFinder().topology
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
  local first = table.Copy(Moonpanel.Canvas.SampleData)
  first.Meta.Width = 1
  first.Meta.Height = 1
  first.Meta.Continuous = false
  first.Entities = {}
  canvas:ImportData(first)

  local oldPathfinder = assert(canvas:GetPathFinder(), 'first import did not build a pathfinder')
  canvas.__playData = { startTime = 1, controller = {}, touchingExit = true }
  canvas.__solutionData = { stale = true }
  canvas.__lastRuleReport = { stale = true }

  local replacement = table.Copy(Moonpanel.Canvas.SampleData)
  replacement.Meta.Width = 2
  replacement.Meta.Height = 1
  replacement.Meta.Continuous = false
  replacement.Entities = {}
  canvas:ImportData(replacement)

  local rebuilt = assert(canvas:GetPathFinder(), 'replacement did not build a pathfinder')
  local exported = assert(canvas:ExportData(), 'replacement data was not retained')
  assert(rebuilt ~= oldPathfinder, 'replacement reused the old pathfinder')
  assert(exported.Meta.Width == 2 and exported.Meta.Height == 1,
    'canvas did not ingest the replacement dimensions')
  assert(#canvas:GetPathNodes() > #oldPathfinder.topology.nodes,
    'replacement did not rebuild the larger socket graph')
  assert(next(canvas.__playData) == nil and canvas.__solutionData == nil and
    canvas.__lastRuleReport == nil,
    'replacement retained runtime state from the old document')
end)

test.run()
