local GridTopology = {}

dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
local flatIndex = Moonpanel.Helpers.flatIndex

function GridTopology.key(x, y)
  return tostring(x) .. ':' .. tostring(y)
end

local function entityType(data, socketIndex)
  local entity = data.Entities and data.Entities[socketIndex]
  return type(entity) == 'table' and entity.Type or nil
end

function GridTopology.build(data, revision)
  local width = assert(data.Meta and data.Meta.Width, 'panel width is missing')
  local height = assert(data.Meta and data.Meta.Height, 'panel height is missing')
  local continuous = data.Meta.Continuous == true
  local topology = {
    revision = revision or 1, nodes = {}, edges = {}, starts = {}, exits = {},
    symmetryNodes = {}, symmetryEdges = {}, wrapX = continuous,
  }
  local nodeAt, starts, exits = {}, {}, {}

  local function seamEntity(leftIndex, rightIndex)
    local left = data.Entities and data.Entities[leftIndex]
    if type(left) == 'table' and left.Type ~= nil then return left, leftIndex end
    local right = data.Entities and data.Entities[rightIndex]
    if type(right) == 'table' and right.Type ~= nil then return right, leftIndex end
    return left or right, leftIndex
  end

  for y = 0, height do
    for x = 0, continuous and width - 1 or width do
      local socketIndex = flatIndex(width, x * 2 + 1, y * 2 + 1)
      local reference
      if continuous and x == 0 then
        reference, socketIndex = seamEntity(socketIndex,
          flatIndex(width, width * 2 + 1, y * 2 + 1))
      end
      local kind = reference and reference.Type or entityType(data, socketIndex)
      local node = {
        id = #topology.nodes + 1,
        x = x,
        y = y,
        socketIndex = socketIndex,
        invisible = kind == 'Invisible',
        clickable = kind == 'Start',
        exit = kind == 'End',
      }
      topology.nodes[node.id] = node
      topology.edges[node.id] = {}
      nodeAt[GridTopology.key(x, y)] = node.id
      if kind == 'Start' then starts[#starts + 1] = node.id end
      if kind == 'End' then exits[#exits + 1] = node.id end
    end
    if continuous then nodeAt[GridTopology.key(width, y)] = nodeAt[GridTopology.key(0, y)] end
  end

  local function connect(fromId, toId, socketIndex)
    if topology.nodes[fromId].invisible or topology.nodes[toId].invisible then return end
    local kind = entityType(data, socketIndex)
    if kind == 'Disjoint' or kind == 'Invisible' then return end
    topology.edges[fromId][toId] = {
      fromId = fromId, toId = toId, socketIndex = socketIndex, lengthQ = 4096,
    }
    topology.edges[toId][fromId] = {
      fromId = toId, toId = fromId, socketIndex = socketIndex, lengthQ = 4096,
    }
  end

  for y = 0, height do
    for x = 0, width - 1 do
      local nextX = continuous and (x + 1) % width or x + 1
      connect(nodeAt[GridTopology.key(x, y)], nodeAt[GridTopology.key(nextX, y)],
        flatIndex(width, x * 2 + 2, y * 2 + 1))
    end
  end
  for y = 0, height - 1 do
    for x = 0, continuous and width - 1 or width do
      local socketIndex = flatIndex(width, x * 2 + 1, y * 2 + 2)
      local blocked = false
      if continuous and x == 0 then
        local reference
        reference, socketIndex = seamEntity(socketIndex,
          flatIndex(width, width * 2 + 1, y * 2 + 2))
        if reference and (reference.Type == 'Disjoint' or reference.Type == 'Invisible') then
          blocked = true
        end
      end
      if not blocked then
        connect(nodeAt[GridTopology.key(x, y)], nodeAt[GridTopology.key(x, y + 1)], socketIndex)
      end
    end
  end

  topology.starts, topology.exits = starts, exits
  local symmetry = tonumber(data.Meta.Symmetry) or 0
  if symmetry ~= 0 then
    for id, node in ipairs(topology.nodes) do
      local mirrorX, mirrorY = node.x, node.y
      if symmetry == 1 or symmetry == 3 then
        mirrorX = width - mirrorX
        if continuous then mirrorX = mirrorX % width end
      end
      if symmetry == 2 or symmetry == 3 then mirrorY = height - mirrorY end
      topology.symmetryNodes[id] = nodeAt[GridTopology.key(mirrorX, mirrorY)]
    end
    for fromId, edges in ipairs(topology.edges) do
      topology.symmetryEdges[fromId] = {}
      for toId in pairs(edges) do
        local mirrorFrom = topology.symmetryNodes[fromId]
        local mirrorTo = topology.symmetryNodes[toId]
        topology.symmetryEdges[fromId][toId] = mirrorFrom and mirrorTo and
          topology.edges[mirrorFrom] and topology.edges[mirrorFrom][mirrorTo] or nil
      end
    end
  end

  function topology:getEdge(fromId, toId)
    return self.edges[fromId] and self.edges[fromId][toId]
  end
  function topology:getSymmetricalNodeId(nodeId) return self.symmetryNodes[nodeId] end
  function topology:getSymmetricalEdge(fromId, toId)
    return self.symmetryEdges[fromId] and self.symmetryEdges[fromId][toId]
  end
  function topology:isValidStart(nodeId)
    local node = self.nodes[nodeId]
    if not node or node.clickable ~= true then return false end
    if symmetry == 0 then return true end
    local mirror = self.symmetryNodes[nodeId]
    return mirror and self.nodes[mirror] and self.nodes[mirror].clickable == true or false
  end

  return topology, nodeAt, starts, exits
end

return GridTopology
