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
IsValid = function(value) return value ~= nil end
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
vectorMeta.Length = function(value)
  return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
end
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

dofile('dest/lua/moonpanel/sh_colors.lua')
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
  assert(canvas.GetTraceTopology == nil,
    'Canvas still exposes the removed mutable topology accessor')
  canvas:ImportData(fixture('pillartest'))
  assert(canvas:IsContinuous(), 'real canvas discarded continuous topology')
  local pathfinder = assert(canvas:GetPillarTraceEngine(), 'real canvas did not build a pathfinder')
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
  local topology = canvas:GetPillarTraceEngine().topology
  assert(topology.surfaceKind == Moonpanel.Canvas.SurfaceKind.Pillar and topology.wrapX,
    'pillar surface values did not reach TraceTopology')
end)

test.test('real pillartest pathfinder traverses all four wrapping sockets', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData(fixture('pillartest'))
  local topology = canvas:GetPillarTraceEngine().topology
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
  canvas:ImportData({ Meta = { Width = 1, Height = 1 }, Entities = {} })

  local oldPathfinder = assert(canvas:GetPillarTraceEngine(), 'first import did not build a pathfinder')
  canvas:SetPlayData({ startTime = 1, controller = {}, touchingExit = true })

  canvas:ImportData({ Meta = { Width = 2, Height = 1 }, Entities = {} })

  local rebuilt = assert(canvas:GetPillarTraceEngine(), 'replacement did not build a pathfinder')
  local exported = assert(canvas:ExportData(), 'replacement data was not retained')
  assert(rebuilt ~= oldPathfinder, 'replacement reused the old pathfinder')
  assert(exported.Meta.Width == 2 and exported.Meta.Height == 1,
    'canvas did not ingest the replacement dimensions')
  assert(#canvas:GetPathNodes() > #oldPathfinder.topology.nodes,
    'replacement did not rebuild the larger socket graph')
  assert(next(canvas:GetPlayDataSnapshot()) == nil and canvas:GetLastRuleReport() == nil,
    'replacement retained runtime state from the old document')
end)

test.test('canvas rejects suspicious imports without mutating live state', function()
  local canvas = Moonpanel.Canvas.Canvas()
  assert(canvas:ImportData(fixture('pillartest')))
  local revision = canvas:GetTraceRevision()
  assert(not canvas:ImportData('not a panel'), 'non-table import was accepted')
  local hostile = {
    Meta = setmetatable({}, {
      __index = function() error('hostile payload') end,
    }),
  }
  assert(not canvas:ImportData(hostile), 'throwing payload was accepted')
  assert(canvas:GetTraceRevision() == revision and canvas:IsContinuous(),
    'failed import mutated the live panel')
end)

test.test('invisible intersections and paths are topology cuts', function()
  local canvas = Moonpanel.Canvas.Canvas()
  canvas:ImportData(fixture('core clue family coverage'))
  local engine = assert(canvas:GetPillarTraceEngine())
  local invisible
  for _, node in ipairs(canvas:GetPathNodes()) do
    if node.invisible then invisible = node break end
  end
  assert(invisible, 'core clues invisible intersection was not imported')
  assert(#invisible.neighbors == 0, 'invisible intersection retained adjacency')
  for _, node in ipairs(canvas:GetPathNodes()) do
    for _, neighbor in ipairs(node.neighbors) do
      assert(neighbor ~= invisible,
        'invisible intersection left stale inbound adjacency')
    end
  end
  assert(engine.topology.nodeIds[invisible] == nil,
    'invisible intersection remained in trace topology')
  for _, node in ipairs(engine.topology.nodes) do
    assert(not node.invisible, 'trace topology retained an invisible node')
  end
  local redundantPath = table.Copy(fixture('core clue family coverage'))
  redundantPath.Entities[16] = {}
  local redundantCanvas = Moonpanel.Canvas.Canvas()
  redundantCanvas:ImportData(redundantPath)
  assert(redundantCanvas:GetTraceRevision() == engine:GetRevision(),
    'path marker beside an invisible intersection changed topology')

  local pathData = {
    Meta = { Width = 1, Height = 1 },
    Entities = {
      { Type = 'Start' }, { Type = 'Invisible' }, { Type = 'End' },
    },
  }
  local pathCanvas = Moonpanel.Canvas.Canvas()
  pathCanvas:ImportData(pathData)
  local pathTopology = pathCanvas:GetPillarTraceEngine().topology
  assert(not pathTopology:getEdge(1, 2) and not pathTopology:getEdge(2, 1),
    'invisible path created a topology edge')
end)

test.test('transient sound scheduler keeps exactly one deferred timer', function()
  CHAN_USER_BASE = 136
  local callbacks, pending, peak, emitted = {}, 0, 0, {}
  timer = { Simple = function(delay, callback)
    assert(delay == 0, 'transient sound used a non-zero timer')
    pending = pending + 1
    peak = math.max(peak, pending)
    callbacks[#callbacks + 1] = callback
  end }
  local canvas = Moonpanel.Canvas.Canvas()
  local target = { EmitSound = function(_, file)
    emitted[#emitted + 1] = file
    if file == 'start.wav' then canvas:PlaySound('Eraser') end
  end }
  canvas.__sounds, canvas.__soundEnabled = {}, true
  canvas.__soundTarget = target
  canvas.__soundFiles = { Start = 'start.wav', Eraser = 'eraser.wav' }
  canvas.__soundLevels = { Start = 65, Eraser = 65 }
  canvas.__soundDurations, canvas.__soundActivity, canvas.__soundQueue = {}, {}, {}

  canvas:PlaySound('Start')
  assert(#emitted == 0 and pending == 1,
    'first transient was not exclusively timer-backed')
  while #callbacks > 0 do
    local callback = table.remove(callbacks, 1)
    pending = pending - 1
    callback()
  end
  assert(peak == 1, 'sound scheduler created overlapping timers')
  assert(emitted[1] == 'start.wav' and emitted[2] == 'eraser.wav',
    'sound scheduler lost or reordered a reentrant cue')
end)

test.test('canvas obstruction fanout and refinement preserve visibility fraction', function()
  local traceLine = function() return { Hit = false, Fraction = 1 } end
  local canvas = Moonpanel.Canvas.Canvas(nil, function(trace) return traceLine(trace) end)
  local rays = 0
  traceLine = function()
    rays = rays + 1
    return { Hit = false, Fraction = 1 }
  end
  assert(canvas:SampleSegmentVisibility(
    Vector(0, 0, 10), Vector(0, 0, 0), Vector(10, 0, 0), {}, 8, 0) == 1,
    'clear segment did not remain completely visible')
  assert(rays == 9,
    'clear segment did not perform one start and eight fanout rays: ' .. rays)

  rays = 0
  traceLine = function(trace)
    rays = rays + 1
    return { Hit = trace.endpos.x >= 5, Fraction = trace.endpos.x >= 5 and 0.5 or 1 }
  end

  local fraction = canvas:SampleSegmentVisibility(
    Vector(0, 0, 10), Vector(0, 0, 0), Vector(10, 0, 0), {}, 8, 0)
  assert(math.abs(fraction - 0.5) < 0.001,
    'binary obstruction refinement changed its convergence point')
  assert(rays == 15,
    'obstruction did not perform one start, four fanout, and ten refinement rays')

  rays = 0
  traceLine = function()
    rays = rays + 1
    return { Hit = true, Fraction = 0.25, Entity = { class = 'prop_physics' } }
  end
  assert(canvas:SampleSegmentVisibility(
    Vector(0, 0, 10), Vector(0, 0, 0), Vector(10, 0, 0), {}, 8, 0) == 0,
    'blocked start ray did not reject the complete segment')
  assert(rays == 1, 'blocked start ray incorrectly entered fanout/refinement')
  traceLine = function() return { Hit = false, Fraction = 1 } end
end)

test.run()
