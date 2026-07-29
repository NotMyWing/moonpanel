-- Deterministic flat-panel rule compiler and several-pass validator.
-- The compiled definition and solution facts contain only stable IDs and
-- serializable values; canvas/entity objects are confined to the adapter that
-- enriches TraceTopology with socketIndex values.

local RuleEngine = {}

local TRACE_UNITS = 4096

local function profileNow()
    if SysTime then return SysTime() end
    return os.clock()
end

local function profileAddTime(profile, key, started)
    if not profile then return end
    profile.timings[key] = (profile.timings[key] or 0) + profileNow() - started
end

local function profileCount(profile, key, amount)
    if not profile then return end
    profile.counters[key] = (profile.counters[key] or 0) + (amount or 1)
end

local function profileRegion(profile, regionId)
    if not profile then return nil end
    local region = profile.regions[regionId]
    if not region then
        region = { time = 0, revalidations = 0, eraserStates = 0 }
        profile.regions[regionId] = region
    end
    return region
end

local function beginProfile(options)
    if not options or not options.developmentProfile then return nil end
    local profile = type(options.developmentProfile) == "table" and
        options.developmentProfile or {}
    profile.timings = {}
    profile.counters = {}
    profile.regions = {}
    return profile
end

local function finishProfile(report, profile, started)
    if profile then
        profile.timings.total = profileNow() - started
        report.developmentProfile = profile
    end
    return report
end

local function finishReport(report, profile, started)
    report.reportHash = RuleEngine.HashReport(report)
    return finishProfile(report, profile, started)
end

RuleEngine.DotRole = {
    Any = 0,
    Primary = 1,
    Secondary = 2,
}

local UINT32 = 4294967296
local CRC_MASK = 4294967295
local CRC_POLYNOMIAL = 3988292384

local function bxor(a, b)
    return bit.bxor(a, b) % UINT32
end

local CRC_TABLE = {}
for byte = 0, 255 do
    local value = byte
    for _ = 1, 8 do
        if value % 2 == 1 then
            value = bxor(math.floor(value / 2), CRC_POLYNOMIAL)
        else
            value = math.floor(value / 2)
        end
    end
    CRC_TABLE[byte] = value
end

local function appendByte(crc, byte)
    local index = bxor(crc % 256, byte % 256)
    return bxor(math.floor(crc / 256), CRC_TABLE[index])
end

local function appendNumber(crc, value)
    value = math.floor(tonumber(value) or 0) % UINT32
    for _ = 1, 4 do
        crc = appendByte(crc, value % 256)
        value = math.floor(value / 256)
    end
    return crc
end

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "number" or ta == "string" then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function appendValue(crc, value, seen)
    local kind = type(value)
    if kind == "nil" then
        return appendByte(crc, 0)
    elseif kind == "boolean" then
        crc = appendByte(crc, 1)
        return appendByte(crc, value and 1 or 0)
    elseif kind == "number" then
        crc = appendByte(crc, 2)
        return appendNumber(crc, value)
    elseif kind == "string" then
        crc = appendByte(crc, 3)
        crc = appendNumber(crc, #value)
        for index = 1, #value do crc = appendByte(crc, string.byte(value, index)) end
        return crc
    elseif kind ~= "table" then
        return appendValue(crc, tostring(value), seen)
    end

    seen = seen or {}
    if seen[value] then error("cyclic value cannot be hashed", 2) end
    seen[value] = true
    crc = appendByte(crc, 4)
    local keys = sortedKeys(value)
    crc = appendNumber(crc, #keys)
    for _, key in ipairs(keys) do
        crc = appendValue(crc, key, seen)
        crc = appendValue(crc, value[key], seen)
    end
    seen[value] = nil
    return crc
end

function RuleEngine.HashValue(value)
    return bxor(appendValue(CRC_MASK, value), CRC_MASK)
end

local function flatIndex(width, gridX, gridY)
    return 1 + (gridX - 1) + (gridY - 1) * (width * 2 + 1)
end

local function socketInfo(index, width)
    local numCols = width * 2 + 1
    local row = math.floor((index - 1) / numCols) + 1
    local column = (index - 1) % numCols + 1
    if row % 2 == 1 and column % 2 == 1 then
        return "intersection", math.floor(column / 2) + 1, math.floor(row / 2) + 1
    elseif row % 2 == 0 and column % 2 == 0 then
        return "cell", column / 2, row / 2
    elseif row % 2 == 1 then
        return "path", column / 2, math.floor(row / 2) + 1, true
    else
        return "path", math.floor(column / 2) + 1, row / 2, false
    end
end

local KIND = {
    Hexagon = "dot",
    Color = "square",
    Sun = "star",
    Eraser = "eraser",
    Triangle = "triangle",
    Polyomino = "polyomino",
}

local function inferDotRole(data, meta)
    local explicit = math.floor(tonumber(data.TraceRole) or -1)
    if explicit >= 0 and explicit <= 2 then return explicit end
    local tintColor = data.TintColor or data.RuleColor or data.Color
    if tintColor == nil or tintColor == 1 then return RuleEngine.DotRole.Any end

    local options = meta.SymmetryOptions or {}
    if not options.Colorful then return RuleEngine.DotRole.Any end
    local traces = options.Traces or {}
    if traces[1] and traces[1].Color == tintColor then return RuleEngine.DotRole.Primary end
    if traces[2] and traces[2].Color == tintColor then return RuleEngine.DotRole.Secondary end
    return RuleEngine.DotRole.Any
end

local function edgeToken(fromId, toId)
    if fromId > toId then fromId, toId = toId, fromId end
    return tostring(fromId) .. ":" .. tostring(toId)
end

local function compileBoundarySegments(definition, topology)
    local requirements = {}
    local nodes = topology and topology.nodes or {}
    local edges = topology and topology.edges or {}

    -- A path socket can be subdivided by midpoint starts and exits. Socket IDs
    -- remain useful for route clues, but region separation must retain those
    -- subdivisions: touching one half of an authored edge does not close the
    -- other half. Exit stubs and gap endpoints never contribute coverage.
    for fromId = 1, #nodes do
        for toId = fromId + 1, #nodes do
            local forward = edges[fromId] and edges[fromId][toId]
            local reverse = edges[toId] and edges[toId][fromId]
            local edge = forward or reverse
            local socketIndex = edge and edge.socketIndex
            local socketKind = socketIndex and socketInfo(socketIndex, definition.width)
            if socketKind == "path" then
                local fromNode, toNode = nodes[fromId], nodes[toId]
                local isStub = fromNode.exit == true or toNode.exit == true or
                    fromNode["break"] == true or toNode["break"] == true
                if not isStub then
                    local requirement = requirements[socketIndex]
                    if not requirement then
                        requirement = {
                            socketIndex = socketIndex,
                            segments = {},
                            coverageQ = 0,
                            hasUnknownCoverage = false,
                        }
                        requirements[socketIndex] = requirement
                    end
                    requirement.segments[#requirement.segments + 1] =
                        edgeToken(fromId, toId)
                    local lengthQ = tonumber((forward and forward.lengthQ) or
                        (reverse and reverse.lengthQ))
                    if lengthQ then
                        requirement.coverageQ = requirement.coverageQ + lengthQ
                    else
                        -- Lightweight test/adaptor topologies historically did
                        -- not carry fixed lengths. Requiring all of their parts
                        -- preserves the safe behavior without rejecting them.
                        requirement.hasUnknownCoverage = true
                    end
                end
            end
        end
    end

    local ordered = {}
    for socketIndex, requirement in pairs(requirements) do
        table.sort(requirement.segments)
        requirement.complete = requirement.hasUnknownCoverage or
            requirement.coverageQ >= TRACE_UNITS
        ordered[#ordered + 1] = socketIndex
    end
    table.sort(ordered)
    return requirements, ordered
end

function RuleEngine.Compile(panelData, topology)
    panelData = panelData or {}
    local meta = panelData.Meta or {}
    local schemaVersion = math.floor(tonumber(panelData.SchemaVersion) or 1)
    local width = math.floor(tonumber(meta.Width) or 0)
    local height = math.floor(tonumber(meta.Height) or 0)
    local continuous = topology and topology.wrapX == true
    local function canonicalSocket(index)
        if not continuous or width < 1 then return index end
        local columns = width * 2 + 1
        if 1 + (index - 1) % columns == columns then
            return index - (columns - 1)
        end
        return index
    end
    local definition = {
        schemaVersion = schemaVersion,
        width = width,
        height = height,
        symmetry = math.floor(tonumber(meta.Symmetry) or 0),
        topologyRevision = topology and topology.revision or 0,
        topology = topology,
        clues = {},
        clueById = {},
        faces = {},
        faceBySocket = {},
        incidentFaces = {},
        permanentBoundaries = {},
        extensions = panelData.Extensions or {},
        continuous = continuous,
        dataErrors = {},
    }

    if width < 1 or height < 1 then
        definition.dataErrors[#definition.dataErrors + 1] = {
            code = "invalid_dimensions", clueId = 0,
        }
    end

    local entities = panelData.Entities or {}
    local count = (width * 2 + 1) * (height * 2 + 1)
    for index = 1, count do
        local reference = entities[index] or {}
        local typeName = reference.Type
        local kind = KIND[typeName]
        local socketKind, x, y, horizontal = socketInfo(index, width)

        -- Invisible path sockets are authored barriers, not merely paths with
        -- no renderable entity. They must divide regions before any trace is
        -- applied, matching the legacy verifier's disconnected-area behavior.
        if socketKind == "path" and typeName == "Invisible" then
            definition.permanentBoundaries[index] = true
        end

        -- An invisible cell is an authored hole in the region graph. Since it
        -- does not become a face below, retain its four surrounding edges as
        -- permanent boundaries so regions cannot flow through the omitted
        -- cell.
        if socketKind == "cell" and typeName == "Invisible" then
            definition.permanentBoundaries[canonicalSocket(
                flatIndex(width, x * 2, y * 2 - 1))] = true
            definition.permanentBoundaries[canonicalSocket(
                flatIndex(width, x * 2 + 1, y * 2))] = true
            definition.permanentBoundaries[canonicalSocket(
                flatIndex(width, x * 2, y * 2 + 1))] = true
            definition.permanentBoundaries[canonicalSocket(
                flatIndex(width, x * 2 - 1, y * 2))] = true
        end

        if socketKind == "cell" and typeName ~= "Invisible" then
            local face = {
                id = #definition.faces + 1,
                socketIndex = index,
                x = x,
                y = y,
                boundaries = {
                    canonicalSocket(flatIndex(width, x * 2, y * 2 - 1)),
                    canonicalSocket(flatIndex(width, x * 2 + 1, y * 2)),
                    canonicalSocket(flatIndex(width, x * 2, y * 2 + 1)),
                    canonicalSocket(flatIndex(width, x * 2 - 1, y * 2)),
                },
                corners = {
                    canonicalSocket(flatIndex(width, x * 2 - 1, y * 2 - 1)),
                    canonicalSocket(flatIndex(width, x * 2 + 1, y * 2 - 1)),
                    canonicalSocket(flatIndex(width, x * 2 + 1, y * 2 + 1)),
                    canonicalSocket(flatIndex(width, x * 2 - 1, y * 2 + 1)),
                },
            }
            definition.faces[#definition.faces + 1] = face
            definition.faceBySocket[index] = face.id
            for _, socketIndex in ipairs(face.boundaries) do
                local adjacent = definition.incidentFaces[socketIndex] or {}
                adjacent[#adjacent + 1] = face.id
                definition.incidentFaces[socketIndex] = adjacent
            end
            for _, socketIndex in ipairs(face.corners) do
                local adjacent = definition.incidentFaces[socketIndex] or {}
                adjacent[#adjacent + 1] = face.id
                definition.incidentFaces[socketIndex] = adjacent
            end
        end

        if kind then
            local data = reference.Data or {}
            local clue = {
                id = index,
                socketIndex = index,
                socketKind = socketKind,
                x = x,
                y = y,
                horizontal = horizontal == true,
                kind = kind,
                -- Schema v2's palette left stale RuleColor values. Schema v3+
                -- has canonical semantic identity; Color/TintColor is visual.
                ruleColor = tonumber(schemaVersion >= 3 and
                    (data.RuleColor or data.Color) or (data.Color or data.RuleColor)),
            }
            if kind == "dot" then
                clue.traceRole = inferDotRole(data, meta)
                clue.negative = data.Negative == true
            elseif kind == "triangle" then
                clue.count = math.floor(tonumber(data.Count) or 1)
            elseif kind == "polyomino" then
                clue.shape = {}
                for y, inputRow in ipairs(data.Shape or {{1}}) do
                    clue.shape[y] = {}
                    for x, value in ipairs(inputRow) do
                        clue.shape[y][x] = value == 1 and 1 or 0
                    end
                end
                clue.rotatable = data.Rotational == true
                clue.negative = data.Negative == true
            end
            definition.clues[#definition.clues + 1] = clue
            definition.clueById[clue.id] = clue

            local expectedCell = kind ~= "dot"
            if (expectedCell and socketKind ~= "cell") or
                    (kind == "dot" and socketKind == "cell") then
                definition.dataErrors[#definition.dataErrors + 1] = {
                    code = "invalid_socket", clueId = clue.id,
                }
            end
            if clue.ruleColor == nil and kind ~= "dot" then
                definition.dataErrors[#definition.dataErrors + 1] = {
                    code = "missing_rule_color", clueId = clue.id,
                }
            end
            if kind == "dot" and clue.traceRole == RuleEngine.DotRole.Secondary and
                    definition.symmetry == 0 then
                definition.dataErrors[#definition.dataErrors + 1] = {
                    code = "invalid_dot_role", clueId = clue.id,
                }
            end
            if kind == "triangle" and (clue.count < 1 or clue.count > 3) and
                    not (clue.count == 4 and definition.extensions.FourTriangle == true) then
                definition.dataErrors[#definition.dataErrors + 1] = {
                    code = "invalid_triangle", clueId = clue.id,
                }
            elseif kind == "polyomino" then
                local cells = 0
                for _, row in ipairs(clue.shape) do
                    for _, value in ipairs(row) do
                        if value == 1 then cells = cells + 1 end
                    end
                end
                if cells == 0 then
                    definition.dataErrors[#definition.dataErrors + 1] = {
                        code = "empty_polyomino", clueId = clue.id,
                    }
                end
            end
        end
    end

    table.sort(definition.clues, function(a, b) return a.id < b.id end)
    table.sort(definition.dataErrors, function(a, b)
        if a.clueId ~= b.clueId then return a.clueId < b.clueId end
        return a.code < b.code
    end)
    for _, faces in pairs(definition.incidentFaces) do table.sort(faces) end

    definition.boundarySegments, definition.boundarySegmentOrder =
        compileBoundarySegments(definition, topology)

    local hashable = {
        schemaVersion = definition.schemaVersion,
        width = width,
        height = height,
        symmetry = definition.symmetry,
        topologyRevision = definition.topologyRevision,
        clues = definition.clues,
        faces = definition.faces,
        permanentBoundaries = definition.permanentBoundaries,
        boundarySegments = definition.boundarySegments,
        boundarySegmentOrder = definition.boundarySegmentOrder,
        extensions = definition.extensions,
        dataErrors = definition.dataErrors,
    }
    definition.ruleRevision = RuleEngine.HashValue(hashable)
    return definition
end

local function addMask(current, branch)
    local bitValue = branch == 1 and 1 or 2
    current = current or 0
    if branch == 1 and current % 2 == 0 then return current + bitValue end
    if branch == 2 and math.floor(current / 2) % 2 == 0 then return current + bitValue end
    return current
end

local function coordKey(x, y)
    -- Socket coordinates are integral, but Lua 5.3 preserves an integer/float
    -- distinction in tostring ("1" versus "1.0"). Canonical formatting keeps
    -- topology joins identical under LuaJIT and the standalone test runtime.
    return string.format("%d:%d", x, y)
end

function RuleEngine.BuildFacts(definition, traceSnapshot, profile)
    local pathStarted = profile and profileNow()
    traceSnapshot = traceSnapshot or {}
    local topology = definition.topology or {}
    local traced = {}
    local tracedSegments = {}
    local traceErrors = {}
    if traceSnapshot.revision ~= nil and
            traceSnapshot.revision ~= definition.topologyRevision then
        traceErrors[#traceErrors + 1] = {
            code = "trace_revision", clueId = 0,
            expected = definition.topologyRevision,
            actual = traceSnapshot.revision,
        }
    end
    for branch, stack in ipairs(traceSnapshot.stacks or {}) do
        for index, nodeId in ipairs(stack) do
            local node = topology.nodes and topology.nodes[nodeId]
            if node and node.socketIndex then
                traced[node.socketIndex] = addMask(traced[node.socketIndex], branch)
            elseif not node then
                traceErrors[#traceErrors + 1] = {
                    code = "trace_node", clueId = 0,
                    branch = branch, index = index, nodeId = nodeId,
                }
            end
            local nextId = stack[index + 1]
            local edge
            if nextId and topology.getEdge then
                edge = topology:getEdge(nodeId, nextId)
                if edge and edge.socketIndex then
                    traced[edge.socketIndex] = addMask(traced[edge.socketIndex], branch)
                end
            elseif nextId and topology.edges and topology.edges[nodeId] then
                edge = topology.edges[nodeId][nextId]
                if edge and edge.socketIndex then
                    traced[edge.socketIndex] = addMask(traced[edge.socketIndex], branch)
                end
            end
            if nextId and not edge then
                traceErrors[#traceErrors + 1] = {
                    code = "trace_edge", clueId = 0,
                    branch = branch, index = index,
                    fromId = nodeId, toId = nextId,
                }
            elseif nextId and edge then
                local token = edgeToken(nodeId, nextId)
                tracedSegments[token] = addMask(tracedSegments[token], branch)
            end
        end
    end
    local closedBoundaries = {}
    for socketIndex in pairs(definition.permanentBoundaries or {}) do
        closedBoundaries[socketIndex] = true
    end
    for _, socketIndex in ipairs(definition.boundarySegmentOrder or {}) do
        local requirement = definition.boundarySegments[socketIndex]
        local closed = requirement.complete == true and #requirement.segments > 0
        for _, token in ipairs(requirement.segments) do
            if not tracedSegments[token] then
                closed = false
                break
            end
        end
        if closed then closedBoundaries[socketIndex] = true end
    end
    if profile then profileAddTime(profile, "pathConstruction", pathStarted) end

    local regionStarted = profile and profileNow()
    local parent = {}
    local function find(id)
        local root = id
        while parent[root] ~= root do root = parent[root] end
        while parent[id] ~= id do
            local nextId = parent[id]
            parent[id] = root
            id = nextId
        end
        return root
    end
    local function union(a, b)
        a, b = find(a), find(b)
        if a == b then return end
        if a < b then parent[b] = a else parent[a] = b end
    end

    local faceAt = {}
    for _, face in ipairs(definition.faces) do
        parent[face.id] = face.id
        faceAt[coordKey(face.x, face.y)] = face.id
    end
    for _, face in ipairs(definition.faces) do
        local right = faceAt[coordKey(face.x + 1, face.y)]
        if right and not closedBoundaries[face.boundaries[2]] then union(face.id, right) end
        local below = faceAt[coordKey(face.x, face.y + 1)]
        if below and not closedBoundaries[face.boundaries[3]] then union(face.id, below) end
        if definition.continuous and face.x == definition.width then
            local wrapped = faceAt[coordKey(1, face.y)]
            if wrapped and not closedBoundaries[face.boundaries[2]] then
                union(face.id, wrapped)
            end
        end
    end

    local roots = {}
    for _, face in ipairs(definition.faces) do roots[find(face.id)] = true end
    local orderedRoots = {}
    for root in pairs(roots) do orderedRoots[#orderedRoots + 1] = root end
    table.sort(orderedRoots)
    local regionByRoot = {}
    local regions = {}
    for index, root in ipairs(orderedRoots) do
        regionByRoot[root] = index
        regions[index] = { id = index, faces = {}, clues = {} }
    end

    local regionByFace = {}
    for _, face in ipairs(definition.faces) do
        local regionId = regionByRoot[find(face.id)]
        regionByFace[face.id] = regionId
        regions[regionId].faces[#regions[regionId].faces + 1] = face.id
    end
    if profile then profileAddTime(profile, "regionConstruction", regionStarted) end

    local groupingStarted = profile and profileNow()
    local clueRegions = {}
    for _, clue in ipairs(definition.clues) do
        local regionId
        if clue.socketKind == "cell" then
            local faceId = definition.faceBySocket[clue.socketIndex]
            regionId = faceId and regionByFace[faceId]
        else
            local incident = definition.incidentFaces[clue.socketIndex] or {}
            for _, faceId in ipairs(incident) do
                local candidate = regionByFace[faceId]
                if candidate and (not regionId or candidate < regionId) then regionId = candidate end
            end
        end
        clueRegions[clue.id] = regionId
        if regionId then regions[regionId].clues[#regions[regionId].clues + 1] = clue.id end
    end
    for _, region in ipairs(regions) do table.sort(region.clues) end

    local mirrorRegion = {}
    local ignoredClues = {}
    for _, region in ipairs(regions) do
        local face = region.faces[1] and definition.faces[region.faces[1]]
        if face then
            local mirrorX, mirrorY = face.x, face.y
            if definition.symmetry == 1 or definition.symmetry == 3 then
                mirrorX = definition.width + 1 - mirrorX
            end
            if definition.symmetry == 2 or definition.symmetry == 3 then
                mirrorY = definition.height + 1 - mirrorY
            end
            local mirrorFace = faceAt[coordKey(mirrorX, mirrorY)]
            mirrorRegion[region.id] = mirrorFace and regionByFace[mirrorFace]
        end
    end
    local canonicalRegion = {}
    for regionId, mirrorId in pairs(mirrorRegion) do
        if mirrorId and mirrorId ~= regionId then
            local canonical = regionId
            local ownFace = definition.faces[regions[regionId].faces[1]]
            local mirrorFace = definition.faces[regions[mirrorId].faces[1]]
            local preferMirror = false
            if definition.symmetry == 1 then
                preferMirror = mirrorFace.x > ownFace.x
            elseif definition.symmetry == 2 then
                preferMirror = mirrorFace.y > ownFace.y
            elseif definition.symmetry == 3 then
                preferMirror = mirrorFace.x > ownFace.x or
                    (mirrorFace.x == ownFace.x and mirrorFace.y > ownFace.y)
            end
            if preferMirror then
                canonical = mirrorId
            end
            canonicalRegion[regionId] = canonical
            canonicalRegion[mirrorId] = canonical
        end
    end
    local evaluationRegions = {}
    for _, region in ipairs(regions) do
        local canonical = canonicalRegion[region.id] or region.id
        if canonical == region.id then
            evaluationRegions[#evaluationRegions + 1] = region
        else
            for _, clueId in ipairs(region.clues) do
                ignoredClues[clueId] = true
            end
        end
    end
    regions = evaluationRegions
    if profile then profileAddTime(profile, "clueGrouping", groupingStarted) end

    return {
        definition = definition,
        snapshot = traceSnapshot,
        traced = traced,
        tracedSegments = tracedSegments,
        closedBoundaries = closedBoundaries,
        regions = regions,
        regionByFace = regionByFace,
        clueRegions = clueRegions,
        ignoredClues = ignoredClues,
        traceErrors = traceErrors,
        traceHash = RuleEngine.HashValue({
            revision = traceSnapshot.revision,
            stacks = traceSnapshot.stacks,
        }),
    }
end

local function arrayCopy(input)
    local output = {}
    for index, value in ipairs(input or {}) do output[index] = value end
    return output
end

local function sortedSet(set)
    local output = {}
    for value in pairs(set) do output[#output + 1] = value end
    table.sort(output)
    return output
end

local function dotSatisfied(clue, mask)
    mask = mask or 0
    local covered
    if clue.traceRole == RuleEngine.DotRole.Primary then
        covered = mask % 2 == 1
    elseif clue.traceRole == RuleEngine.DotRole.Secondary then
        covered = math.floor(mask / 2) % 2 == 1
    else
        covered = mask > 0
    end
    return clue.negative and not covered or not clue.negative and covered
end

local function addConstraint(report, kind, regionId, participants, details)
    table.sort(participants)
    local constraint = {
        kind = kind,
        regionId = regionId or 0,
        participants = participants,
        details = details,
    }
    report.constraints[#report.constraints + 1] = constraint
    for _, id in ipairs(participants) do report.violationSet[id] = true end
end

local function evaluateActiveSet(facts, active, options, onlyRegion)
    local definition = facts.definition
    local profile = options and options.__profile
    local report = {
        status = "complete",
        constraints = {},
        violationSet = {},
        witnesses = { polyomino = {} },
    }

    for _, clue in ipairs(definition.clues) do
        if active[clue.id] and not facts.ignoredClues[clue.id] and
                clue.kind == "dot" and
                (not onlyRegion or facts.clueRegions[clue.id] == onlyRegion) and
                not dotSatisfied(clue, facts.traced[clue.socketIndex]) then
            addConstraint(report, "dot", facts.clueRegions[clue.id], {clue.id}, {
                traceRole = clue.traceRole,
                negative = clue.negative == true,
            })
        end
    end

    for _, clue in ipairs(definition.clues) do
        if active[clue.id] and not facts.ignoredClues[clue.id] and
                clue.kind == "triangle" and
                (not onlyRegion or facts.clueRegions[clue.id] == onlyRegion) then
            local faceId = definition.faceBySocket[clue.socketIndex]
            local face = faceId and definition.faces[faceId]
            local count = 0
            for _, boundary in ipairs(face and face.boundaries or {}) do
                if facts.traced[boundary] then count = count + 1 end
            end
            if count ~= clue.count then
                addConstraint(report, "triangle", facts.clueRegions[clue.id], {clue.id}, {
                    expected = clue.count,
                    actual = count,
                })
            end
        end
    end

    for _, region in ipairs(facts.regions) do
        if not onlyRegion or region.id == onlyRegion then
            local regionStarted = profile and profileNow()
            local regionProfile = profileRegion(profile, region.id)
            if regionProfile then
                regionProfile.revalidations = regionProfile.revalidations + 1
                profileCount(profile, "fullRegionRevalidations")
            end
            local squareColors = {}
            local starsByColor = {}
            local coloredCellCount = {}
            local polyominoes = {}
            for _, clueId in ipairs(region.clues) do
                local clue = definition.clueById[clueId]
                if active[clueId] then
                    if clue.socketKind == "cell" and clue.ruleColor then
                        coloredCellCount[clue.ruleColor] = (coloredCellCount[clue.ruleColor] or 0) + 1
                    end
                    if clue.kind == "square" then
                        local group = squareColors[clue.ruleColor] or {}
                        group[#group + 1] = clue.id
                        squareColors[clue.ruleColor] = group
                    elseif clue.kind == "star" then
                        local group = starsByColor[clue.ruleColor] or {}
                        group[#group + 1] = clue.id
                        starsByColor[clue.ruleColor] = group
                    elseif clue.kind == "polyomino" then
                        polyominoes[#polyominoes + 1] = {
                            id = clue.id,
                            shape = clue.shape,
                            rotatable = clue.rotatable,
                            negative = clue.negative,
                        }
                    end
                end
            end

            local squareColorIds = sortedKeys(squareColors)
            if #squareColorIds > 1 then
                local participants = {}
                for _, color in ipairs(squareColorIds) do
                    for _, id in ipairs(squareColors[color]) do participants[#participants + 1] = id end
                end
                addConstraint(report, "squares", region.id, participants, { colors = squareColorIds })
            end

            for _, color in ipairs(sortedKeys(starsByColor)) do
                local actual = coloredCellCount[color] or 0
                if actual ~= 2 then
                    addConstraint(report, "stars", region.id, arrayCopy(starsByColor[color]), {
                        color = color,
                        actual = actual,
                        expected = 2,
                    })
                end
            end

            if #polyominoes > 0 then
                local regionCells = {}
                for _, faceId in ipairs(region.faces) do
                    local face = definition.faces[faceId]
                    regionCells[#regionCells + 1] = { id = face.id, x = face.x, y = face.y }
                end
                local keyParts = {}
                for _, piece in ipairs(polyominoes) do keyParts[#keyParts + 1] = piece.id end
                local cache = options and options.__polyominoCache
                local cacheKey = region.id .. ":" .. table.concat(keyParts, ",")
                local solve = cache and cache[cacheKey]
                if solve then
                    profileCount(profile, "polyominoCacheHits")
                else
                    profileCount(profile, "polyominoSolverCalls")
                    profileCount(profile, "polyominoCacheMisses")
                    solve = Moonpanel.Canvas.PolyominoSolver.Solve({
                        cells = regionCells,
                        wrapWidth = definition.continuous and definition.width or nil,
                    }, polyominoes, {
                        checkpoint = options and options.checkpoint,
                    })
                    if cache then cache[cacheKey] = solve end
                end
                if solve.status == "complexity" then
                    report.status = "complexity"
                    report.complexity = { kind = "polyomino", regionId = region.id, steps = solve.steps }
                    if regionProfile then
                        regionProfile.time = regionProfile.time + profileNow() - regionStarted
                    end
                    return report
                elseif solve.status ~= "solved" then
                    local participants = {}
                    for _, piece in ipairs(polyominoes) do participants[#participants + 1] = piece.id end
                    addConstraint(report, "polyomino", region.id, participants, { backend = solve.backend })
                else
                    report.witnesses.polyomino[region.id] = {
                        backend = solve.backend,
                        target = solve.target,
                        placements = solve.placements,
                    }
                end
            end
            if regionProfile then
                regionProfile.time = regionProfile.time + profileNow() - regionStarted
            end
        end
    end

    report.violations = sortedSet(report.violationSet)
    report.violationSet = nil
    report.success = report.status == "complete" and #report.violations == 0
    return report
end

local function forEachCombination(values, count, checkpoint, callback, profile,
        depthBase, copyResult, branchCallback)
    local current = {}
    local function visit(start, depth)
        if profile then
            local combinedDepth = (depthBase or 0) + depth
            profile.counters.maxRecursiveDepth = math.max(
                profile.counters.maxRecursiveDepth or 0, combinedDepth)
        end
        if checkpoint and checkpoint(1) == false then return false, "complexity" end
        if depth > count then
            local result = copyResult == false and current or arrayCopy(current)
            if callback(result) == false then return false, "stopped" end
            return true
        end
        local maximum = #values - (count - depth)
        for index = start, maximum do
            current[depth] = values[index]
            local branchResult = branchCallback and branchCallback(current, depth)
            if branchResult == "stop" then return false, "stopped" end
            if branchResult ~= false then
                local complete, reason = visit(index + 1, depth + 1)
                if not complete then return false, reason end
            end
        end
        current[depth] = nil
        return true
    end
    if count > #values then return true end
    return visit(1, 1)
end

local function mapping(erasers, targets)
    local output = {}
    for index = 1, #erasers do
        output[index] = { eraserIndex = erasers[index], targetIndex = targets[index] }
    end
    return output
end

local function evaluateRegionWithRemoved(facts, baseActive, regionId, usedErasers, targets, options)
    local active = {}
    for key, value in pairs(baseActive) do active[key] = value end
    for _, id in ipairs(usedErasers) do active[id] = nil end
    for _, id in ipairs(targets) do active[id] = nil end
    return evaluateActiveSet(facts, active, options, regionId)
end

local function sliceRegionReport(report, regionId)
    local constraints = {}
    local violationSet = {}
    for _, constraint in ipairs(report.constraints or {}) do
        if constraint.regionId == regionId then
            constraints[#constraints + 1] = constraint
            for _, id in ipairs(constraint.participants or {}) do violationSet[id] = true end
        end
    end
    local witnesses = { polyomino = {} }
    local poly = report.witnesses and report.witnesses.polyomino
    if poly and poly[regionId] then witnesses.polyomino[regionId] = poly[regionId] end
    local violations = sortedSet(violationSet)
    return {
        status = report.status,
        success = report.status == "complete" and #violations == 0,
        constraints = constraints,
        violations = violations,
        witnesses = witnesses,
    }
end

local function solveEraserRegion(facts, baseActive, region, erasers, targets, options, baseline)
    if baseline.status ~= "complete" then return { status = baseline.status, report = baseline } end

    local fullValid
    local bestFull
    local bestFullScore
    local bestFullTargets
    local profile = options and options.__profile
    local regionProfile = profileRegion(profile, region.id)
    local pendingSearchWork = 0
    local searchCheckpoints = 0
    local function checkpointSearch(force)
        pendingSearchWork = pendingSearchWork + 1
        local batchSize = searchCheckpoints < 4 and 16 or 64
        if not force and pendingSearchWork < batchSize then return true end
        pendingSearchWork = 0
        searchCheckpoints = searchCheckpoints + 1
        return not options or not options.checkpoint or options.checkpoint(1) ~= false
    end
    -- Without other targets, the largest even set of Erasers consumes itself.
    -- An odd survivor remains an unsatisfied clue.
    if #targets == 0 and #erasers > 1 then
        local usedCount = #erasers - #erasers % 2
        local used, retained = {}, {}
        for index, eraserIndex in ipairs(erasers) do
            local destination = index <= usedCount and used or retained
            destination[#destination + 1] = eraserIndex
        end
        local candidate = evaluateRegionWithRemoved(
            facts, baseActive, region.id, used, {}, options)
        if candidate.status ~= "complete" then
            return { status = candidate.status, report = candidate }
        end
        if candidate.success or #retained == 1 and #(candidate.violations or {}) == 1 then
            local assignments = {}
            for index, eraserIndex in ipairs(used) do
                assignments[#assignments + 1] = {
                    eraserIndex = eraserIndex,
                    targetIndex = used[index % #used + 1],
                }
            end
            return {
                status = "complete",
                success = candidate.success,
                baseline = baseline,
                selected = candidate,
                erasures = assignments,
                invalidErasers = #retained > 0 and retained or nil,
                proof = { minimumUsed = usedCount, targets = {} },
            }
        end
    end
    -- Find the smallest set of non-Eraser clues that makes the region valid;
    -- any remaining Erasers can only cancel in pairs, with an odd survivor
    -- reported as the remaining error.
    if #targets > 0 and #targets <= #erasers then
        local solution
        for targetCount = 1, #targets do
            local failedStatus
            local _, reason = forEachCombination(
                targets, targetCount, function() return checkpointSearch(false) end,
                function(targetSet)
                local candidate = evaluateRegionWithRemoved(
                    facts, baseActive, region.id, erasers, targetSet, options)
                if candidate.status ~= "complete" then
                    failedStatus = candidate
                    return false
                end
                if candidate.success then
                    solution = { report = candidate, targets = arrayCopy(targetSet) }
                    return false
                end
                return true
            end, profile, 0, false)
            if reason == "complexity" then return { status = "complexity" } end
            if failedStatus then
                return { status = failedStatus.status, report = failedStatus }
            end
            if solution then break end
        end
        if solution then
            local targetCount = #solution.targets
            local remainder = #erasers - targetCount
            local cycleCount = remainder - remainder % 2
            local assignments = {}
            for index, targetIndex in ipairs(solution.targets) do
                assignments[#assignments + 1] = {
                    eraserIndex = erasers[index],
                    targetIndex = targetIndex,
                }
            end
            local cycleStart = targetCount + 1
            local cycleEnd = targetCount + cycleCount
            for index = cycleStart, cycleEnd do
                assignments[#assignments + 1] = {
                    eraserIndex = erasers[index],
                    targetIndex = erasers[index < cycleEnd and index + 1 or cycleStart],
                }
            end
            local retained = {}
            for index = cycleEnd + 1, #erasers do retained[#retained + 1] = erasers[index] end
            local used = {}
            for index = 1, cycleEnd do used[index] = erasers[index] end
            local selected = evaluateRegionWithRemoved(
                facts, baseActive, region.id, used, solution.targets, options)
            return {
                status = "complete",
                success = #retained == 0 and selected.success,
                baseline = baseline,
                selected = selected,
                erasures = assignments,
                invalidErasers = #retained > 0 and retained or nil,
                proof = { minimumUsed = cycleEnd, targets = solution.targets },
            }
        end
    end
    -- Every authored Eraser must consume one non-Eraser clue. A temporarily
    -- valid state reached with only a subset does not make the remaining
    -- Erasers optional; the complete assignment is the puzzle state that must
    -- be validated.
    if profile and #erasers > 0 then
        local function combinations(count, selected)
            if selected < 0 or selected > count then return 0 end
            selected = math.min(selected, count - selected)
            local result = 1
            for index = 1, selected do
                result = result * (count - selected + index) / index
            end
            return result
        end
        local pruned = 0
        for usedCount = 0, #erasers - 1 do
            pruned = pruned + combinations(#erasers, usedCount) *
                combinations(#targets, usedCount)
        end
        profileCount(profile, "prunedEraserStates", pruned)
    end
    local usedCount = #erasers
    local failedStatus
    local function targetBranch()
        profileCount(profile, "eraserBranches")
        return true
    end
    local _, targetReason = forEachCombination(
                targets, usedCount, function() return checkpointSearch(false) end,
                function(targetSet)
                profileCount(profile, "eraserStatesExplored")
                if regionProfile then
                    regionProfile.eraserStates = regionProfile.eraserStates + 1
                end
                local scoreStarted = profile and profileNow()
                local candidate = evaluateRegionWithRemoved(
                    facts, baseActive, region.id, erasers, targetSet, options)
                if profile then profileAddTime(profile, "eraserScoring", scoreStarted) end
                if candidate.status ~= "complete" then
                    failedStatus = { status = candidate.status, report = candidate }
                    return false
                end
                local score = #(candidate.violations or {})
                if bestFullScore == nil or score < bestFullScore or
                        score == bestFullScore and not bestFullTargets then
                    bestFullScore = score
                    bestFullTargets = arrayCopy(targetSet)
                end
                if score == 0 then
                    if not fullValid then
                        fullValid = { report = candidate, targets = arrayCopy(targetSet) }
                    end
                    return false
                end
                return true
            end, profile, usedCount, false, targetBranch)
    if targetReason == "complexity" then
        failedStatus = { status = "complexity" }
    end
    if failedStatus then return failedStatus end

    if pendingSearchWork > 0 and not checkpointSearch(true) then
        return {
            status = "complexity",
            complexity = { kind = "eraser", regionId = region.id },
        }
    end

    if not fullValid and bestFullTargets then
        if profile then profileCount(profile, "bestEraserScore", bestFullScore or 0) end
        bestFull = evaluateRegionWithRemoved(
            facts, baseActive, region.id, erasers, bestFullTargets, options)
        if bestFull.status ~= "complete" then
            return { status = bestFull.status, report = bestFull }
        end
    end

    if fullValid then
        return {
            status = "complete",
            success = true,
            baseline = baseline,
            selected = fullValid.report,
            erasures = mapping(erasers, fullValid.targets),
            proof = { minimumUsed = usedCount, targets = fullValid.targets },
        }
    end

    return {
        status = "complete",
        success = false,
        baseline = baseline,
        selected = bestFull or baseline,
        erasures = bestFullTargets and mapping(erasers, bestFullTargets) or {},
        invalidErasers = bestFullTargets and {} or arrayCopy(erasers),
        proof = { minimumUsed = false, targets = bestFullTargets or {} },
    }
end

function RuleEngine.NewBudget(options)
    options = options or {}
    local budget = {
        slice = math.max(1, math.floor(options.slice or 2000)),
        sliceSeconds = math.max(0, tonumber(options.sliceSeconds) or 0),
        maximum = math.max(1, math.floor(options.maximum or 2000000)),
        maximumSeconds = math.max(0, tonumber(options.maximumSeconds) or 0),
        maximumWallSeconds = math.max(0, tonumber(options.maximumWallSeconds) or 0),
        total = 0,
        current = 0,
        yields = 0,
        activeSeconds = 0,
        yieldFn = options.yieldFn,
        clock = options.clock or profileNow,
    }
    budget.sliceStarted = budget.clock()
    budget.startedAt = budget.sliceStarted
    budget.activeStarted = budget.sliceStarted
    function budget:activeTime()
        return self.activeSeconds + math.max(0, self.clock() - self.activeStarted)
    end
    function budget:checkpoint(amount)
        amount = amount or 1
        self.total = self.total + amount
        self.current = self.current + amount
        local now = self.clock()
        self.activeSeconds = self.activeSeconds +
            math.max(0, now - self.activeStarted)
        self.activeStarted = now
        if self.total > self.maximum then
            self.exhausted = "work"
            return false
        end
        if self.maximumSeconds > 0 and
                self.activeSeconds >= self.maximumSeconds then
            self.exhausted = "time"
            return false
        end
        if self.maximumWallSeconds > 0 and
                now - self.startedAt >= self.maximumWallSeconds then
            self.exhausted = "lifetime"
            return false
        end
        local timeExpired = self.sliceSeconds > 0 and
            now - self.sliceStarted >= self.sliceSeconds
        if self.yieldFn and (self.current >= self.slice or timeExpired) then
            self.current = 0
            self.yields = self.yields + 1
            self.yieldFn(self.total)
            self.sliceStarted = self.clock()
            -- A coroutine may remain suspended for many frames. That delay is
            -- scheduler latency, not verifier CPU time, so begin the next
            -- active interval only after the coroutine has actually resumed.
            self.activeStarted = self.sliceStarted
        end
        return true
    end
    return budget
end

function RuleEngine.Evaluate(definition, traceSnapshot, options)
    options = options or {}
    local evaluationStarted = profileNow()
    local profile = beginProfile(options)
    if profile then
        local runtimeOptions = {}
        for key, value in pairs(options) do runtimeOptions[key] = value end
        runtimeOptions.__profile = profile
        options = runtimeOptions
    end
    options.__polyominoCache = {}
    local facts = RuleEngine.BuildFacts(definition, traceSnapshot, profile)
    if options.traceHash then facts.traceHash = options.traceHash end
    local dataErrors = {}
    for _, failure in ipairs(definition.dataErrors) do dataErrors[#dataErrors + 1] = failure end
    for _, failure in ipairs(facts.traceErrors) do dataErrors[#dataErrors + 1] = failure end
    if #dataErrors > 0 then
        local violationSet = {}
        for _, failure in ipairs(dataErrors) do
            if failure.clueId > 0 then violationSet[failure.clueId] = true end
        end
        local violations = sortedSet(violationSet)
        local report = {
            status = "data_error",
            success = false,
            violations = violations,
            erasures = {},
            remaining = arrayCopy(violations),
            constraints = {{
                kind = "data",
                regionId = 0,
                participants = arrayCopy(violations),
                details = { errors = dataErrors },
            }},
            witnesses = {},
            ruleRevision = definition.ruleRevision,
            traceHash = facts.traceHash,
        }
        return finishReport(report, profile, evaluationStarted)
    end
    local baseActive = {}
    for _, clue in ipairs(definition.clues) do baseActive[clue.id] = true end

    local initialStarted = profile and profileNow()
    local initial = evaluateActiveSet(facts, baseActive, options)
    if profile then
        profileAddTime(profile, "initialValidation", initialStarted)
        for _, regionProfile in pairs(profile.regions) do
            regionProfile.initialTime = regionProfile.time
        end
    end
    if initial.status ~= "complete" then
        local report = {
            status = initial.status,
            success = false,
            violations = initial.violations or {},
            erasures = {},
            remaining = initial.violations or {},
            constraints = initial.constraints or {},
            witnesses = initial.witnesses or {},
            complexity = initial.complexity,
            ruleRevision = definition.ruleRevision,
            traceHash = facts.traceHash,
        }
        return finishReport(report, profile, evaluationStarted)
    end

    local violationSet, remainingSet = {}, {}
    local constraints, erasures = {}, {}
    local witnesses = { polyomino = {}, erasers = {} }
    for _, id in ipairs(initial.violations) do violationSet[id] = true end

    -- Route clues normally inherit one adjacent region. Malformed/extension
    -- topology can leave a clue regionless; keep those constraints global so
    -- they cannot disappear merely because eraser evaluation is regional.
    local overallSuccess = true
    for _, constraint in ipairs(initial.constraints) do
        if constraint.regionId == 0 then
            constraints[#constraints + 1] = constraint
            for _, id in ipairs(constraint.participants or {}) do remainingSet[id] = true end
            overallSuccess = false
        end
    end

    for _, region in ipairs(facts.regions) do
        local regionEvaluationStarted = profile and profileNow()
        local baseline = sliceRegionReport(initial, region.id)
        local violating = {}
        for _, clueId in ipairs(baseline.violations or {}) do
            violating[clueId] = true
        end
        local erasersInRegion, targets = {}, {}
        for _, clueId in ipairs(region.clues) do
            local clue = definition.clueById[clueId]
            if clue.kind == "eraser" then
                erasersInRegion[#erasersInRegion + 1] = clue.id
            elseif violating[clue.id] then
                targets[#targets + 1] = clue.id
            end
        end

        local solved
        if #erasersInRegion > 0 then
            solved = solveEraserRegion(
                facts, baseActive, region, erasersInRegion, targets, options, baseline)
        else
            solved = {
                status = baseline.status,
                success = baseline.success,
                baseline = baseline,
                selected = baseline,
                erasures = {},
            }
        end
        if profile then
            local currentRegionProfile = profileRegion(profile, region.id)
            currentRegionProfile.totalTime =
                (currentRegionProfile.totalTime or 0) +
                profileNow() - regionEvaluationStarted
        end

        if solved.status ~= "complete" then
            local report = {
                status = solved.status,
                success = false,
                violations = initial.violations,
                erasures = erasures,
                remaining = initial.violations,
                constraints = initial.constraints,
                witnesses = witnesses,
                complexity = solved.complexity or
                    (solved.report and solved.report.complexity),
                ruleRevision = definition.ruleRevision,
                traceHash = facts.traceHash,
            }
            return finishReport(report, profile, evaluationStarted)
        end

        for _, id in ipairs(solved.unnecessary or {}) do violationSet[id] = true end
        for _, id in ipairs(solved.invalidErasers or {}) do violationSet[id] = true end
        for _, pair in ipairs(solved.erasures or {}) do erasures[#erasures + 1] = pair end
        for _, id in ipairs(solved.selected.violations or {}) do remainingSet[id] = true end
        for _, id in ipairs(solved.unnecessary or {}) do remainingSet[id] = true end
        for _, id in ipairs(solved.invalidErasers or {}) do remainingSet[id] = true end
        for _, constraint in ipairs(solved.selected.constraints or {}) do constraints[#constraints + 1] = constraint end
        if solved.unnecessary and #solved.unnecessary > 0 then
            constraints[#constraints + 1] = {
                kind = "eraser_unnecessary",
                regionId = region.id,
                participants = arrayCopy(solved.unnecessary),
                details = { minimumUsed = solved.proof and solved.proof.minimumUsed or 0 },
            }
        elseif solved.invalidErasers and #solved.invalidErasers > 0 then
            constraints[#constraints + 1] = {
                kind = "eraser_unsatisfied",
                regionId = region.id,
                participants = arrayCopy(solved.invalidErasers),
                details = { targets = solved.proof and solved.proof.targets or {} },
            }
        end
        for regionId, witness in pairs((solved.selected.witnesses or {}).polyomino or {}) do
            witnesses.polyomino[regionId] = witness
        end
        if solved.proof then witnesses.erasers[region.id] = solved.proof end
        if not solved.success then overallSuccess = false end
    end

    if overallSuccess then
        for clueId in pairs(facts.ignoredClues or {}) do
            local clue = definition.clueById[clueId]
            if clue and clue.kind == "dot" and
                    not dotSatisfied(clue, facts.traced[clue.socketIndex]) then
                violationSet[clueId] = true
                remainingSet[clueId] = true
                constraints[#constraints + 1] = {
                    kind = "dot",
                    regionId = facts.clueRegions[clueId] or 0,
                    participants = { clueId },
                    details = {
                        traceRole = clue.traceRole,
                        negative = clue.negative == true,
                    },
                }
                overallSuccess = false
            end
        end
    end

    local reportingStarted = profile and profileNow()
    table.sort(erasures, function(a, b)
        if a.eraserIndex ~= b.eraserIndex then return a.eraserIndex < b.eraserIndex end
        return a.targetIndex < b.targetIndex
    end)
    table.sort(constraints, function(a, b)
        if a.regionId ~= b.regionId then return a.regionId < b.regionId end
        if a.kind ~= b.kind then return a.kind < b.kind end
        return (a.participants[1] or 0) < (b.participants[1] or 0)
    end)

    local report = {
        status = "complete",
        success = overallSuccess and next(remainingSet) == nil,
        violations = sortedSet(violationSet),
        erasures = erasures,
        remaining = sortedSet(remainingSet),
        constraints = constraints,
        witnesses = witnesses,
        ruleRevision = definition.ruleRevision,
        traceHash = facts.traceHash,
    }
    report.reportHash = RuleEngine.HashReport(report)
    if profile then profileAddTime(profile, "finalReporting", reportingStarted) end
    return finishProfile(report, profile, evaluationStarted)
end

function RuleEngine.HashReport(report)
    return RuleEngine.HashValue({
        status = report.status,
        success = report.success,
        violations = report.violations,
        erasures = report.erasures,
        remaining = report.remaining,
        constraints = report.constraints,
        witnesses = report.witnesses,
        complexity = report.complexity,
        ruleRevision = report.ruleRevision,
        traceHash = report.traceHash,
    })
end

function RuleEngine.FeedbackManifest(report)
    local erasures = {}
    for _, pair in ipairs(report.erasures or {}) do
        erasures[#erasures + 1] = {
            eraserIndex = pair.eraserIndex,
            targetIndex = pair.targetIndex,
        }
    end
    return {
        violations = arrayCopy(report.violations),
        erasures = erasures,
        remaining = arrayCopy(report.remaining),
        success = report.status == "complete" and report.success == true,
    }
end

return RuleEngine
