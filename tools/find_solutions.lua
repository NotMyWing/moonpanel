local panelPath = assert(arg[1], 'panel data path is required')
local maxPaths = tonumber(arg[2]) or 1000000
local displayPath = arg[3] or panelPath

AddCSLuaFile = function() end
Moonpanel = { Canvas = { Symmetry = {
    None = 0, Vertical = 1, Horizontal = 2, Rotational = 3,
} } }
Moonpanel.Color = {
    Black = 1, White = 2, Cyan = 3, Magenta = 4, Yellow = 5,
    Red = 6, Green = 7, Blue = 8, Orange = 9,
}
Moonpanel.Canvas.SocketType = { Intersection = 1, Cell = 2, Path = 3 }
istable = function(value) return type(value) == 'table' end
isstring = function(value) return type(value) == 'string' end
table.Count = table.Count or function(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end
math.Clamp = math.Clamp or function(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end
util = util or { JSONToTable = function() return nil end }

dofile('dest/lua/moonpanel/canvas/sh_paneldata.lua')
local RuleEngine = dofile('dest/lua/moonpanel/canvas/sh_rule_engine.lua')
local input = dofile(panelPath)

local function normalizeKeys(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do
        local numeric = type(key) == 'string' and tonumber(key) or nil
        if numeric and numeric == math.floor(numeric) then key = numeric end
        result[key] = normalizeKeys(child)
    end
    return result
end

local panel = input.Tile and Moonpanel.Canvas.LegacyToCanvasData(normalizeKeys(input)) or input
local width = assert(panel.Meta and panel.Meta.Width, 'panel width is missing')
local height = assert(panel.Meta and panel.Meta.Height, 'panel height is missing')

local function flatIndex(gridX, gridY)
    return 1 + (gridX - 1) + (gridY - 1) * (width * 2 + 1)
end
local function intersectionIndex(x, y)
    return flatIndex(x * 2 + 1, y * 2 + 1)
end
local function hpathIndex(x, y)
    return flatIndex(x * 2 + 2, y * 2 + 1)
end
local function vpathIndex(x, y)
    return flatIndex(x * 2 + 1, y * 2 + 2)
end
local function key(x, y) return x .. ':' .. y end

local topology = { revision = 1, nodes = {}, edges = {} }
local nodeAt, starts, exits = {}, {}, {}
for y = 0, height do
    for x = 0, width do
        local socket = intersectionIndex(x, y)
        local node = { id = #topology.nodes + 1, x = x, y = y, socketIndex = socket }
        topology.nodes[node.id] = node
        topology.edges[node.id] = {}
        nodeAt[key(x, y)] = node.id
        local entity = panel.Entities and panel.Entities[socket]
        local typeName = entity and entity.Type
        if typeName == 'Start' then starts[#starts + 1] = node.id end
        if typeName == 'End' then exits[#exits + 1] = node.id end
    end
end

local function connect(fromId, toId, socket)
    local from, to = topology.nodes[fromId], topology.nodes[toId]
    if from.invisible or to.invisible then return end
    local entity = panel.Entities and panel.Entities[socket]
    local typeName = entity and entity.Type
    if typeName == 'Disjoint' or typeName == 'Invisible' then return end
    topology.edges[fromId][toId] = { socketIndex = socket, lengthQ = 4096 }
    topology.edges[toId][fromId] = { socketIndex = socket, lengthQ = 4096 }
end
for y = 0, height do
    for x = 0, width - 1 do
        connect(nodeAt[key(x, y)], nodeAt[key(x + 1, y)], hpathIndex(x, y))
    end
end
for y = 0, height - 1 do
    for x = 0, width do
        connect(nodeAt[key(x, y)], nodeAt[key(x, y + 1)], vpathIndex(x, y))
    end
end
function topology:getEdge(fromId, toId)
    return self.edges[fromId] and self.edges[fromId][toId]
end

assert(#starts > 0, 'panel has no Start intersection')
assert(#exits > 0, 'panel has no End intersection')
local definition = RuleEngine.Compile(panel, topology)
local solutions, explored = {}, 0
local symmetry = tonumber(panel.Meta.Symmetry) or 0

local function stackFor(path)
    local stack = {}
    for index, nodeId in ipairs(path) do stack[index] = nodeId end
    return stack
end
local function mirrored(path)
    local result = {}
    for index, nodeId in ipairs(path) do
        local node = topology.nodes[nodeId]
        local x, y = node.x, node.y
        if symmetry == 1 or symmetry == 3 then x = width - x end
        if symmetry == 2 or symmetry == 3 then y = height - y end
        result[index] = assert(nodeAt[key(x, y)])
    end
    return result
end
local function coordinates(path)
    local result = {}
    for index, nodeId in ipairs(path) do
        local node = topology.nodes[nodeId]
        result[index] = { node.x, node.y }
    end
    return result
end

local function evaluate(path)
    local stacks = { stackFor(path) }
    if symmetry ~= 0 then stacks[2] = mirrored(path) end
    local report = RuleEngine.Evaluate(definition, { revision = topology.revision, stacks = stacks })
    explored = explored + 1
    if report.success then solutions[#solutions + 1] = coordinates(path) end
end

local path = {}
local visited = {}
local function search(current, finish)
    if explored >= maxPaths then error('path limit exceeded; rerun with a larger --max-paths value') end
    path[#path + 1] = current
    visited[current] = true
    if current == finish then
        evaluate(path)
    else
        for nextId in pairs(topology.edges[current] or {}) do
            if not visited[nextId] then search(nextId, finish) end
        end
    end
    visited[current] = nil
    path[#path] = nil
end

for _, start in ipairs(starts) do
    for _, finish in ipairs(exits) do search(start, finish) end
end

io.write(string.format('panel=%s starts=%d exits=%d paths=%d solutions=%d\n',
    displayPath, #starts, #exits, explored, #solutions))
for index, solution in ipairs(solutions) do
    io.write(string.format('solution %d: ', index))
    for pointIndex, point in ipairs(solution) do
        if pointIndex > 1 then io.write(' ') end
        io.write(string.format('(%d,%d)', point[1], point[2]))
    end
    io.write('\n')
end
