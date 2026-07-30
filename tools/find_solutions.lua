local panelPath = assert(arg[1], 'panel data path is required')
local maxPaths = tonumber(arg[2]) or 1000000
local displayPath = arg[3] or panelPath

dofile('tools/tests/bootstrap.lua')

dofile('dest/lua/moonpanel/sh_colors.lua')
dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
dofile('dest/lua/moonpanel/canvas/sh_paneldata.lua')
Moonpanel.Canvas.DLX = dofile('dest/lua/moonpanel/canvas/sh_dlx.lua')
dofile('dest/lua/moonpanel/canvas/sh_polyomino.lua')
local RuleEngine = dofile('dest/lua/moonpanel/canvas/sh_rule_engine.lua')
local GridTopology = dofile('tools/grid_topology.lua')
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
local topology, nodeAt, starts, exits = GridTopology.build(panel, 1)
local key = GridTopology.key

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
