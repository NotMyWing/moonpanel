local GridTopology = {}

function GridTopology.key(x, y)
  return tostring(x) .. ':' .. tostring(y)
end

local function flatIndex(width, gridX, gridY)
  return 1 + (gridX - 1) + (gridY - 1) * (width * 2 + 1)
end

local function entityType(data, socketIndex)
  local entity = data.Entities and data.Entities[socketIndex]
  return type(entity) == 'table' and entity.Type or nil
end

function GridTopology.build(data, revision)
  local width = assert(data.Meta and data.Meta.Width, 'panel width is missing')
  local height = assert(data.Meta and data.Meta.Height, 'panel height is missing')
  local topology = {revision = revision or 1, nodes = {}, edges = {}}
  local nodeAt, starts, exits = {}, {}, {}

  for y = 0, height do
    for x = 0, width do
      local socketIndex = flatIndex(width, x * 2 + 1, y * 2 + 1)
      local kind = entityType(data, socketIndex)
      local node = {
        id = #topology.nodes + 1,
        x = x,
        y = y,
        socketIndex = socketIndex,
        invisible = kind == 'Invisible',
      }
      topology.nodes[node.id] = node
      topology.edges[node.id] = {}
      nodeAt[GridTopology.key(x, y)] = node.id
      if kind == 'Start' then starts[#starts + 1] = node.id end
      if kind == 'End' then exits[#exits + 1] = node.id end
    end
  end

  local function connect(fromId, toId, socketIndex)
    if topology.nodes[fromId].invisible or topology.nodes[toId].invisible then return end
    local kind = entityType(data, socketIndex)
    if kind == 'Disjoint' or kind == 'Invisible' then return end
    topology.edges[fromId][toId] = {socketIndex = socketIndex, lengthQ = 4096}
    topology.edges[toId][fromId] = {socketIndex = socketIndex, lengthQ = 4096}
  end

  for y = 0, height do
    for x = 0, width - 1 do
      connect(nodeAt[GridTopology.key(x, y)], nodeAt[GridTopology.key(x + 1, y)],
        flatIndex(width, x * 2 + 2, y * 2 + 1))
    end
  end
  for y = 0, height - 1 do
    for x = 0, width do
      connect(nodeAt[GridTopology.key(x, y)], nodeAt[GridTopology.key(x, y + 1)],
        flatIndex(width, x * 2 + 1, y * 2 + 2))
    end
  end

  function topology:getEdge(fromId, toId)
    return self.edges[fromId] and self.edges[fromId][toId]
  end

  return topology, nodeAt, starts, exits
end

return GridTopology
