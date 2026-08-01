-- Deterministic flat-panel rule compiler and several-pass validator.
-- The compiled definition and solution facts contain only stable IDs and
-- serializable values; canvas/entity objects are confined to the adapter that
-- enriches TraceTopology with socketIndex values.

local RuleEngine = {}
local hashReport
local flatIndex = Moonpanel.Helpers.flatIndex
local arrayCopy = Moonpanel.Helpers.copyArray

local TRACE_UNITS = 4096
local CACHE_TTL = 120
local CACHE_LIMITS = { reports = 8, facts = 16, erasers = 32, polyominoes = 64 }

local function canonicalSocketIndex(index, width, continuous)
    if not continuous or width < 1 or not index then return index end
    local columns = width * 2 + 1
    if 1 + (index - 1) % columns == columns then
        return index - (columns - 1)
    end
    return index
end

local function authoredEntity(value)
    return type(value) == "table" and value.Type ~= nil
end

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

local function copyTree(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local output = {}
    seen[value] = output
    for key, child in pairs(value) do
        output[key] = copyTree(child, seen)
    end
    return output
end

local function cacheBucket(cache, name)
    local bucket = cache[name]
    if not bucket then
        bucket = { count = 0 }
        cache[name] = bucket
    end
    return bucket
end

local function pruneBucket(bucket, now)
    for key, entry in pairs(bucket) do
        if key ~= "count" and entry.expiresAt <= now then
            bucket[key] = nil
            bucket.count = bucket.count - 1
        end
    end
end

function RuleEngine.NewCache(options)
    options = options or {}
    return {
        ttl = math.max(1, tonumber(options.ttl) or CACHE_TTL),
        clock = options.clock or profileNow,
        nextPrune = 0,
    }
end

function RuleEngine.PruneCache(cache, force)
    if type(cache) ~= "table" or type(cache.clock) ~= "function" then return end
    local now = cache.clock()
    if not force and now < cache.nextPrune then return end
    for name in pairs(CACHE_LIMITS) do
        local bucket = cache[name]
        if bucket then pruneBucket(bucket, now) end
    end
    cache.nextPrune = now + 5
end

local function cacheGet(cache, name, key)
    if type(cache) ~= "table" or type(cache.clock) ~= "function" or not key then
        return nil
    end
    local bucket = cache[name]
    local entry = bucket and bucket[key]
    if not entry then return nil end
    if entry.expiresAt <= cache.clock() then
        bucket[key] = nil
        bucket.count = bucket.count - 1
        return nil
    end
    return entry.value
end

local function cachePut(cache, name, key, value)
    if type(cache) ~= "table" or type(cache.clock) ~= "function" or
            not key or value == nil then return end
    local now = cache.clock()
    local bucket = cacheBucket(cache, name)
    pruneBucket(bucket, now)
    if not bucket[key] and bucket.count >= CACHE_LIMITS[name] then
        local oldestKey, oldestAt
        for candidateKey, entry in pairs(bucket) do
            if candidateKey ~= "count" and
                    (oldestAt == nil or entry.createdAt < oldestAt) then
                oldestKey, oldestAt = candidateKey, entry.createdAt
            end
        end
        if oldestKey then
            bucket[oldestKey] = nil
            bucket.count = bucket.count - 1
        end
    end
    if not bucket[key] then bucket.count = bucket.count + 1 end
    bucket[key] = {
        value = value,
        createdAt = now,
        expiresAt = now + cache.ttl,
    }
    cache.nextPrune = math.min(cache.nextPrune or 0, now + 5)
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

local DOT_ANY, DOT_PRIMARY, DOT_SECONDARY = 0, 1, 2

local CRC_MASK = Moonpanel.Helpers.CRC32Begin
local appendByte = Moonpanel.Helpers.CRC32AppendByte
local appendNumber = Moonpanel.Helpers.CRC32AppendNumber

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
    return Moonpanel.Helpers.CRC32Finish(appendValue(CRC_MASK, value))
end

local function trimPolyShape(shape)
    local rows, columns = #shape, #(shape[1] or {})
    if rows == 0 or columns == 0 then return {{1}} end
    local minX, minY, maxX, maxY
    for y = 1, rows do
        for x = 1, #(shape[y] or {}) do
            if shape[y][x] == 1 then
                minX = not minX and x or math.min(minX, x)
                maxX = not maxX and x or math.max(maxX, x)
                minY = not minY and y or math.min(minY, y)
                maxY = not maxY and y or math.max(maxY, y)
            end
        end
    end
    if not minX then return {{1}} end
    local output = {}
    for y = minY, maxY do
        local row = {}
        for x = minX, maxX do row[#row + 1] = shape[y][x] == 1 and 1 or 0 end
        output[#output + 1] = row
    end
    return output
end

local function rotatePolyShape(shape)
    local rows, columns = #shape, #(shape[1] or {})
    local output = {}
    for y = 1, columns do
        output[y] = {}
        for x = 1, rows do
            output[y][x] = shape[rows - x + 1][y] == 1 and 1 or 0
        end
    end
    return trimPolyShape(output)
end

local function polyShapeKey(shape)
    local parts = {}
    for y = 1, #shape do
        local row = {}
        for x = 1, #(shape[y] or {}) do
            row[x] = shape[y][x] == 1 and "1" or "0"
        end
        parts[y] = table.concat(row)
    end
    return table.concat(parts, "/")
end

local function polyShapeCells(shape)
    local cells = {}
    for y = 1, #shape do
        for x = 1, #(shape[y] or {}) do
            if shape[y][x] == 1 then cells[#cells + 1] = { x = x - 1, y = y - 1 } end
        end
    end
    return cells
end

local function polyOrientations(shape, rotatable)
    local current = trimPolyShape(shape)
    local output, seen = {}, {}
    for _ = 1, rotatable and 4 or 1 do
        local key = polyShapeKey(current)
        if not seen[key] then
            seen[key] = true
            output[#output + 1] = {
                key = key,
                cells = polyShapeCells(current),
                width = #(current[1] or {}),
                height = #current,
            }
        end
        current = rotatePolyShape(current)
    end
    table.sort(output, function(a, b) return a.key < b.key end)
    return output
end

local function polyCellKey(x, y)
    return string.format("%d:%d", x, y)
end

local function normalizePolyRegion(input)
    input = input or {}
    local wrapWidth = math.floor(tonumber(input.wrapWidth) or 0)
    local region = { cells = {}, contains = {} }
    for _, cell in ipairs(input.cells or {}) do
        local x, y = tonumber(cell.x or cell[1]), tonumber(cell.y or cell[2])
        if x and y then
            if wrapWidth > 0 then x = ((x - 1) % wrapWidth) + 1 end
            local key = polyCellKey(x, y)
            if not region.contains[key] then
                region.contains[key] = true
                region.cells[#region.cells + 1] = { x = x, y = y, id = cell.id }
                region.minX = not region.minX and x or math.min(region.minX, x)
                region.maxX = not region.maxX and x or math.max(region.maxX, x)
                region.minY = not region.minY and y or math.min(region.minY, y)
                region.maxY = not region.maxY and y or math.max(region.maxY, y)
            end
        end
    end
    table.sort(region.cells, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    region.wrapWidth = wrapWidth > 0 and wrapWidth or nil
    return region
end

local function normalizePolyPieces(input)
    local pieces = {}
    for index, piece in ipairs(input or {}) do
        pieces[#pieces + 1] = {
            id = piece.id or index,
            sign = piece.negative == true and -1 or 1,
            orientations = piece.orientations or
                polyOrientations(piece.shape or {{1}}, piece.rotatable == true),
        }
    end
    table.sort(pieces, function(a, b) return a.id < b.id end)
    return pieces
end

local function polyPlacementCells(orientation, offsets, originX, originY,
        wrapWidth, minX, minY, domainWidth)
    local cells = {}
    if not wrapWidth then
        local originIndex = (originY - minY) * domainWidth + originX - minX + 1
        for index, offset in ipairs(offsets) do cells[index] = originIndex + offset end
        return cells
    end
    local seen = {}
    for _, point in ipairs(orientation.cells) do
        local x = originX + point.x
        if wrapWidth then x = ((x - 1) % wrapWidth) + 1 end
        local cellIndex = (originY + point.y - minY) * domainWidth + x - minX + 1
        if seen[cellIndex] then return nil end
        seen[cellIndex] = true
        cells[#cells + 1] = cellIndex
    end
    return cells
end

local function polyCoverageKey(coverage, activeCells, targets, target, spend,
        minX, minY, domainWidth, tokens)
    if target == 0 then
        local occupied, occupiedMinX, occupiedMinY = {}
        for _, cellIndex in ipairs(activeCells) do
            if not spend() then return nil end
            local value = coverage[cellIndex] or 0
            if value ~= 0 then
                local offset = cellIndex - 1
                local x = offset % domainWidth + minX
                local y = math.floor(offset / domainWidth) + minY
                occupiedMinX = not occupiedMinX and x or math.min(occupiedMinX, x)
                occupiedMinY = not occupiedMinY and y or math.min(occupiedMinY, y)
                occupied[#occupied + 1] = { x = x, y = y, value = value }
            end
        end
        if not occupiedMinX then return "empty" end
        local parts = {}
        for _, cell in ipairs(occupied) do
            parts[#parts + 1] = string.format(
                "%d:%d:%d", cell.x - occupiedMinX,
                cell.y - occupiedMinY, cell.value)
        end
        return table.concat(parts, ";")
    end
    local parts = {}
    for _, cellIndex in ipairs(activeCells) do
        if not spend() then return nil end
        local value = (coverage[cellIndex] or 0) - targets[cellIndex]
        parts[#parts + 1] = tokens and tokens[value] or tostring(value)
    end
    return table.concat(parts, ",")
end

local function solvePolyominoPlacements(region, pieces, target, checkpoint)
    local pendingWork, searchCheckpoints = 0, 0
    local function spend(force)
        if not checkpoint then return true end
        if not force then pendingWork = pendingWork + 1 end
        local batchSize = searchCheckpoints < 4 and 16 or 256
        if not force and pendingWork < batchSize then return true end
        if pendingWork == 0 then return true end
        local amount = pendingWork
        pendingWork = 0
        searchCheckpoints = searchCheckpoints + 1
        return checkpoint(amount) ~= false
    end
    local margin, negativeArea = 0, 0
    for _, piece in ipairs(pieces) do
        local maximum = 1
        for _, orientation in ipairs(piece.orientations) do
            maximum = math.max(maximum, orientation.width, orientation.height)
        end
        margin = margin + maximum - 1
        if piece.sign < 0 then negativeArea = negativeArea + #piece.orientations[1].cells end
    end
    if target == 1 and negativeArea == 0 then margin = 0 end

    local minX = region.wrapWidth and 1 or region.minX - margin
    local maxX = region.wrapWidth or region.maxX + margin
    local minY, maxY = region.minY - margin, region.maxY + margin
    local domainWidth = maxX - minX + 1
    local targets, activeCells, generationSteps = {}, {}, 0
    for y = minY, maxY do
        for x = minX, maxX do
            generationSteps = generationSteps + 1
            if not spend() then
                return { status = "complexity", backend = "signed", steps = generationSteps }
            end
            local cellIndex = #activeCells + 1
            activeCells[cellIndex] = cellIndex
            targets[cellIndex] = region.contains[polyCellKey(x, y)] and target or 0
        end
    end

    local placements, positiveSupport = {}, {}
    if target == 1 then
        for _, cellIndex in ipairs(activeCells) do
            if targets[cellIndex] == 1 then positiveSupport[cellIndex] = true end
        end
    end
    for pieceIndex, piece in ipairs(pieces) do
        local candidates = {}
        for orientationIndex, orientation in ipairs(piece.orientations) do
            local offsets = {}
            for index, point in ipairs(orientation.cells) do
                offsets[index] = point.y * domainWidth + point.x
            end
            local startY, endY = minY, maxY - orientation.height + 1
            local startX = region.wrapWidth and 1 or minX
            local endX = region.wrapWidth or maxX - orientation.width + 1
            if target == 0 and pieceIndex == 1 then
                startX, endX, startY, endY =
                    region.minX, region.minX, region.minY, region.minY
            end
            for originY = startY, endY do
                for originX = startX, endX do
                    generationSteps = generationSteps + 1
                    if not spend() then
                        return { status = "complexity", backend = "signed", steps = generationSteps }
                    end
                    local cells = polyPlacementCells(
                        orientation, offsets, originX, originY, region.wrapWidth,
                        minX, minY, domainWidth)
                    if cells then
                        cells.orientationIndex = orientationIndex
                        cells.ox, cells.oy = originX, originY
                        local outside = 0
                        if target == 1 and piece.sign > 0 then
                            for _, cellIndex in ipairs(cells) do
                                if targets[cellIndex] ~= 1 then
                                    outside = outside + 1
                                end
                            end
                        end
                        if outside <= negativeArea then
                            candidates[#candidates + 1] = cells
                            if target == 1 and piece.sign > 0 then
                                for _, cellIndex in ipairs(cells) do
                                    positiveSupport[cellIndex] = true
                                end
                            end
                        end
                    end
                end
            end
        end
        placements[pieceIndex] = candidates
    end

    if target == 1 then
        local supported = {}
        for _, cellIndex in ipairs(activeCells) do
            if positiveSupport[cellIndex] then supported[#supported + 1] = cellIndex end
        end
        activeCells = supported
        for pieceIndex, piece in ipairs(pieces) do
            if piece.sign < 0 then
                local filtered = {}
                for _, placement in ipairs(placements[pieceIndex]) do
                    local fits = true
                    for _, cellIndex in ipairs(placement) do
                        if not positiveSupport[cellIndex] then
                            fits = false
                            break
                        end
                    end
                    if fits then filtered[#filtered + 1] = placement end
                end
                placements[pieceIndex] = filtered
            end
        end
    end

    local touches, supportKeys = {}, {}
    local remainingPositiveSupport, remainingNegativeSupport = {}, {}
    local remainingPositiveCandidates, remainingNegativeCandidates = {}, {}
    local positivePiecesByCell, negativePiecesByCell = {}, {}
    for pieceIndex, candidates in ipairs(placements) do
        local pieceTouches, keys = {}, {}
        local remainingSupport = pieces[pieceIndex].sign > 0 and
            remainingPositiveSupport or remainingNegativeSupport
        local remainingCandidates = pieces[pieceIndex].sign > 0 and
            remainingPositiveCandidates or remainingNegativeCandidates
        local piecesByCell = pieces[pieceIndex].sign > 0 and
            positivePiecesByCell or negativePiecesByCell
        for placementIndex, placement in ipairs(candidates) do
            for _, cellIndex in ipairs(placement) do
                local cellPlacements = pieceTouches[cellIndex]
                if not cellPlacements then
                    cellPlacements = {}
                    pieceTouches[cellIndex] = cellPlacements
                    keys[#keys + 1] = cellIndex
                    remainingSupport[cellIndex] =
                        (remainingSupport[cellIndex] or 0) + 1
                    local cellPieces = piecesByCell[cellIndex] or {}
                    cellPieces[#cellPieces + 1] = pieceIndex
                    piecesByCell[cellIndex] = cellPieces
                end
                cellPlacements[#cellPlacements + 1] = placementIndex
                remainingCandidates[cellIndex] =
                    (remainingCandidates[cellIndex] or 0) + 1
            end
        end
        touches[pieceIndex] = pieceTouches
        supportKeys[pieceIndex] = keys
    end

    local coverage, chosen, seen = {}, {}, {}
    local remaining, remainingCount = {}, #pieces
    for index = 1, #pieces do remaining[index] = true end
    local coverageTokens
    if negativeArea > 0 and #pieces <= 126 then
        coverageTokens = {}
        for value = -#pieces - 1, #pieces do
            coverageTokens[value] = string.char(value + #pieces + 1)
        end
    end
    local steps, aborted = generationSteps, false

    local function withinRemainingBounds()
        for _, cellIndex in ipairs(activeCells) do
            if not spend() then aborted = true return false end
            local value = coverage[cellIndex] or 0
            if value - (remainingNegativeSupport[cellIndex] or 0) > targets[cellIndex] or
                    value + (remainingPositiveSupport[cellIndex] or 0) < targets[cellIndex] then
                return false
            end
        end
        return true
    end

    local function adjustSupport(pieceIndex, amount)
        local remainingSupport = pieces[pieceIndex].sign > 0 and
            remainingPositiveSupport or remainingNegativeSupport
        local remainingCandidates = pieces[pieceIndex].sign > 0 and
            remainingPositiveCandidates or remainingNegativeCandidates
        for _, key in ipairs(supportKeys[pieceIndex]) do
            remainingSupport[key] = remainingSupport[key] + amount
            remainingCandidates[key] = remainingCandidates[key] +
                amount * #touches[pieceIndex][key]
        end
    end

    local function remainingKey()
        local ids = {}
        for index, piece in ipairs(pieces) do
            if remaining[index] then ids[#ids + 1] = piece.id end
        end
        return table.concat(ids, ",")
    end

    local function selectCandidates()
        local bestKey, bestSign, bestCount
        for _, cellIndex in ipairs(activeCells) do
            if not spend() then aborted = true return nil end
            local value = coverage[cellIndex] or 0
            if value ~= targets[cellIndex] then
                local requiredSign = value < targets[cellIndex] and 1 or -1
                local counts = requiredSign > 0 and
                    remainingPositiveCandidates or remainingNegativeCandidates
                local count = counts[cellIndex] or 0
                if count == 0 then return {} end
                if not bestCount or count < bestCount then
                    bestKey, bestSign, bestCount = cellIndex, requiredSign, count
                end
            end
        end
        if bestKey then
            local candidates = {}
            local cellPieces = bestSign > 0 and
                positivePiecesByCell[bestKey] or negativePiecesByCell[bestKey]
            for _, pieceIndex in ipairs(cellPieces or {}) do
                if remaining[pieceIndex] then
                    for _, placementIndex in ipairs(touches[pieceIndex][bestKey] or {}) do
                        candidates[#candidates + 1] = pieceIndex
                        candidates[#candidates + 1] = placementIndex
                    end
                end
            end
            return candidates
        end
        for pieceIndex = 1, #pieces do
            if remaining[pieceIndex] then
                local anchored = {}
                for placementIndex, placement in ipairs(placements[pieceIndex]) do
                    if placement.ox == region.minX and placement.oy == region.minY then
                        anchored[#anchored + 1] = pieceIndex
                        anchored[#anchored + 1] = placementIndex
                    end
                end
                return anchored
            end
        end
        return {}
    end

    local function search()
        if remainingCount == 0 then
            for _, cellIndex in ipairs(activeCells) do
                if (coverage[cellIndex] or 0) ~= targets[cellIndex] then return false end
            end
            return true
        end
        local fieldKey = polyCoverageKey(coverage, activeCells, targets, target,
            spend, minX, minY, domainWidth, coverageTokens)
        if not fieldKey then aborted = true return false end
        local memoKey = remainingKey() .. "|" .. fieldKey
        if seen[memoKey] then return false end
        seen[memoKey] = true

        local candidates = selectCandidates()
        if aborted then return false end
        for index = 1, #candidates, 2 do
            steps = steps + 1
            if not spend() then aborted = true return false end
            local pieceIndex = candidates[index]
            local placement = placements[pieceIndex][candidates[index + 1]]
            for _, cellIndex in ipairs(placement) do
                coverage[cellIndex] = (coverage[cellIndex] or 0) + pieces[pieceIndex].sign
            end
            chosen[pieceIndex] = placement
            remaining[pieceIndex] = false
            remainingCount = remainingCount - 1
            adjustSupport(pieceIndex, -1)
            if withinRemainingBounds() and search() then return true end
            adjustSupport(pieceIndex, 1)
            remaining[pieceIndex] = true
            remainingCount = remainingCount + 1
            for _, cellIndex in ipairs(placement) do
                local value = (coverage[cellIndex] or 0) - pieces[pieceIndex].sign
                coverage[cellIndex] = value ~= 0 and value or nil
            end
            chosen[pieceIndex] = nil
            if aborted then return false end
        end
        return false
    end

    local solved = search()
    if not aborted and not spend(true) then aborted, solved = true, false end
    if not solved then
        return {
            status = aborted and "complexity" or "unsatisfied",
            backend = "signed",
            steps = steps,
        }
    end
    local result = {
        status = "solved", backend = "signed", steps = steps,
        target = target, placements = {},
    }
    for index, piece in ipairs(pieces) do
        local selected = chosen[index]
        local cells = {}
        for cellIndex, point in ipairs(
                piece.orientations[selected.orientationIndex].cells) do
            local x = selected.ox + point.x
            if region.wrapWidth then x = ((x - 1) % region.wrapWidth) + 1 end
            cells[cellIndex] = { x = x, y = selected.oy + point.y }
        end
        result.placements[index] = {
            pieceId = piece.id,
            sign = piece.sign,
            orientationIndex = selected.orientationIndex,
            ox = selected.ox,
            oy = selected.oy,
            cells = cells,
        }
    end
    return result
end

local function solveNormalizedPolyomino(region, pieces, options)
    if #region.cells == 0 or #pieces == 0 then return { status = "unsatisfied" } end
    local hasNegative, signedArea = false, 0
    for _, piece in ipairs(pieces) do
        local area = #piece.orientations[1].cells
        hasNegative = hasNegative or piece.sign < 0
        signedArea = signedArea + piece.sign * area
    end
    local checkpoint = options and options.checkpoint
    if not hasNegative then
        if signedArea ~= #region.cells then return { status = "unsatisfied", backend = "exact" } end
        local result = solvePolyominoPlacements(region, pieces, 1, checkpoint)
        result.backend = "exact"
        return result
    end
    if signedArea ~= #region.cells and signedArea ~= 0 then
        return { status = "unsatisfied", backend = "signed" }
    end
    return solvePolyominoPlacements(
        region, pieces, signedArea == #region.cells and 1 or 0, checkpoint)
end

function RuleEngine.SolvePolyomino(regionInput, pieceInput, options)
    return solveNormalizedPolyomino(
        normalizePolyRegion(regionInput), normalizePolyPieces(pieceInput), options)
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
    if tintColor == nil or tintColor == 1 then return DOT_ANY end

    local options = meta.SymmetryOptions or {}
    if not options.Colorful then return DOT_ANY end
    local traces = options.Traces or {}
    if traces[1] and traces[1].Color == tintColor then return DOT_PRIMARY end
    if traces[2] and traces[2].Color == tintColor then return DOT_SECONDARY end
    return DOT_ANY
end

local function edgeToken(fromId, toId)
    if fromId > toId then fromId, toId = toId, fromId end
    return tostring(fromId) .. ":" .. tostring(toId)
end

local function compileBoundarySegments(definition, topology)
    local requirements = {}
    local nodes = topology and topology.nodes or {}
    local edges = topology and topology.edges or {}
    local visited = {}

    -- A path socket can be subdivided by midpoint starts and exits. Socket IDs
    -- remain useful for route clues, but region separation must retain those
    -- subdivisions: touching one half of an authored edge does not close the
    -- other half. Exit stubs and gap endpoints never contribute coverage.
    for fromId, adjacent in pairs(edges) do
        for toId, edge in pairs(adjacent) do
            local token = edgeToken(fromId, toId)
            if not visited[token] then
                visited[token] = true
                local reverse = edges[toId] and edges[toId][fromId]
                local socketIndex = edge and canonicalSocketIndex(
                    edge.socketIndex, definition.width, definition.continuous)
                local socketKind = socketIndex and socketInfo(socketIndex, definition.width)
                if socketKind == "path" then
                    local fromNode, toNode = nodes[fromId] or {}, nodes[toId] or {}
                    local isStub = fromNode.exit == true or toNode.exit == true or
                        fromNode["break"] == true or toNode["break"] == true
                    if not isStub then
                        local requirement = requirements[socketIndex]
                        if not requirement then
                            requirement = {
                                segments = {},
                                coverageQ = 0,
                            }
                            requirements[socketIndex] = requirement
                        end
                        requirement.segments[#requirement.segments + 1] = token
                        local lengthQ = tonumber(edge.lengthQ or
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
    end

    for _, requirement in pairs(requirements) do
        table.sort(requirement.segments)
        requirement.complete = requirement.hasUnknownCoverage or
            requirement.coverageQ >= TRACE_UNITS
    end
    return requirements
end

function RuleEngine.Compile(panelData, topology)
    panelData = panelData or {}
    local meta = panelData.Meta or {}
    local schemaVersion = math.floor(tonumber(panelData.SchemaVersion) or 1)
    local extensions = panelData.Extensions or {}
    local width = math.floor(tonumber(meta.Width) or 0)
    local height = math.floor(tonumber(meta.Height) or 0)
    local continuous = topology and topology.wrapX == true
    local function canonicalSocket(index)
        return canonicalSocketIndex(index, width, continuous)
    end
    local definition = {
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
    if continuous and width > 0 and height > 0 then
        local columns = width * 2 + 1
        for row = 0, height * 2 do
            local leftIndex = 1 + row * columns
            local rightIndex = (row + 1) * columns
            if authoredEntity(entities[leftIndex]) and authoredEntity(entities[rightIndex]) then
                definition.dataErrors[#definition.dataErrors + 1] = {
                    code = "continuous_seam_duplicate",
                    clueId = leftIndex,
                    socketIndex = leftIndex,
                    leftIndex = leftIndex,
                    rightIndex = rightIndex,
                    details = { leftIndex = leftIndex, rightIndex = rightIndex },
                }
            end
        end
    end
    for index = 1, count do
        local reference = entities[index] or {}
        local physicalIndex = canonicalSocket(index)
        if physicalIndex ~= index and authoredEntity(reference) and
                authoredEntity(entities[physicalIndex]) then
            reference = {}
        end
        local typeName = reference.Type
        local kind = KIND[typeName]
        local socketKind, x, y, horizontal = socketInfo(physicalIndex, width)

        -- Invisible path sockets are authored barriers, not merely paths with
        -- no renderable entity. They must divide regions before any trace is
        -- applied, matching the legacy verifier's disconnected-area behavior.
        if socketKind == "path" and typeName == "Invisible" then
            definition.permanentBoundaries[physicalIndex] = true
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
                x = x,
                y = y,
                boundaries = {
                    canonicalSocket(flatIndex(width, x * 2, y * 2 - 1)),
                    canonicalSocket(flatIndex(width, x * 2 + 1, y * 2)),
                    canonicalSocket(flatIndex(width, x * 2, y * 2 + 1)),
                    canonicalSocket(flatIndex(width, x * 2 - 1, y * 2)),
                },
            }
            definition.faces[#definition.faces + 1] = face
            definition.faceBySocket[index] = face.id
            for _, socketIndex in ipairs(face.boundaries) do
                local adjacent = definition.incidentFaces[socketIndex] or {}
                adjacent[#adjacent + 1] = face.id
                definition.incidentFaces[socketIndex] = adjacent
            end
            local corners = {
                canonicalSocket(flatIndex(width, x * 2 - 1, y * 2 - 1)),
                canonicalSocket(flatIndex(width, x * 2 + 1, y * 2 - 1)),
                canonicalSocket(flatIndex(width, x * 2 + 1, y * 2 + 1)),
                canonicalSocket(flatIndex(width, x * 2 - 1, y * 2 + 1)),
            }
            for _, socketIndex in ipairs(corners) do
                local adjacent = definition.incidentFaces[socketIndex] or {}
                adjacent[#adjacent + 1] = face.id
                definition.incidentFaces[socketIndex] = adjacent
            end
        end

        if kind then
            local data = reference.Data or {}
            local clue = {
                id = physicalIndex,
                socketIndex = physicalIndex,
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
                clue.orientations = polyOrientations(clue.shape, clue.rotatable)
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
            if kind == "dot" and clue.traceRole == DOT_SECONDARY and
                    definition.symmetry == 0 then
                definition.dataErrors[#definition.dataErrors + 1] = {
                    code = "invalid_dot_role", clueId = clue.id,
                }
            end
            if kind == "triangle" and (clue.count < 1 or clue.count > 3) and
                    not (clue.count == 4 and extensions.FourTriangle == true) then
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

    definition.boundarySegments = compileBoundarySegments(definition, topology)

    local hashable = {
        schemaVersion = schemaVersion,
        width = width,
        height = height,
        symmetry = definition.symmetry,
        topologyRevision = definition.topologyRevision,
        clues = definition.clues,
        faces = definition.faces,
        permanentBoundaries = definition.permanentBoundaries,
        boundarySegments = definition.boundarySegments,
        extensions = extensions,
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

local TRACE_ERROR_FIELDS = {
    "branch", "index", "code", "nodeId", "fromId", "toId",
}

local function sortTraceErrors(errors)
    table.sort(errors, function(left, right)
        for _, key in ipairs(TRACE_ERROR_FIELDS) do
            local a, b = left[key], right[key]
            if a ~= b then
                if a == nil then return true end
                if b == nil then return false end
                if type(a) == type(b) and
                        (type(a) == "number" or type(a) == "string") then
                    return a < b
                end
                return type(a) .. ":" .. tostring(a) < type(b) .. ":" .. tostring(b)
            end
        end
        return false
    end)
end

local function validateCompletedTrace(definition, snapshot)
    local errors = {}
    local topology = definition.topology or {}
    local nodes, stacks = topology.nodes or {}, snapshot.stacks
    local traced, tracedSegments = {}, {}
    if type(stacks) ~= "table" then stacks = {} end
    local expectedBranches = definition.symmetry == 0 and 1 or 2
    local branchCount = 0
    for key, stack in pairs(stacks) do
        if type(key) == "number" and key >= 1 and key == math.floor(key) and
                type(stack) == "table" then
            branchCount = branchCount + 1
        end
    end
    if branchCount ~= expectedBranches then
        errors[#errors + 1] = {
            code = "trace_branch_count", clueId = 0,
            expected = expectedBranches, actual = branchCount,
        }
    end

    local branchNodes, branchEdges = {}, {}
    local function getEdge(fromId, toId)
        if topology.getEdge then return topology:getEdge(fromId, toId) end
        return topology.edges and topology.edges[fromId] and topology.edges[fromId][toId]
    end
    local function validStart(nodeId)
        if topology.isValidStart then return topology:isValidStart(nodeId) end
        local node = nodes[nodeId]
        if node and node.clickable == true then return true end
        for _, id in ipairs(topology.starts or {}) do
            if id == nodeId then return true end
        end
        return false
    end
    local function validExit(nodeId)
        local node = nodes[nodeId]
        if node and node.exit == true then return true end
        for _, id in ipairs(topology.exits or {}) do
            if id == nodeId then return true end
        end
        return false
    end

    for branch = 1, expectedBranches do
        local stack = stacks[branch]
        branchNodes[branch], branchEdges[branch] = {}, {}
        if type(stack) ~= "table" or #stack == 0 then
            errors[#errors + 1] = {
                code = "trace_empty_branch", clueId = 0, branch = branch,
            }
        else
            if not validStart(stack[1]) then
                errors[#errors + 1] = {
                    code = "trace_start", clueId = 0, branch = branch,
                    index = 1, nodeId = stack[1],
                }
            end
            if not validExit(stack[#stack]) then
                errors[#errors + 1] = {
                    code = "trace_exit", clueId = 0, branch = branch,
                    index = #stack, nodeId = stack[#stack],
                }
            end
            for index, nodeId in ipairs(stack) do
                local node = type(nodeId) == "number" and
                    nodeId == math.floor(nodeId) and nodes[nodeId] or nil
                if not node then
                    errors[#errors + 1] = {
                        code = "trace_node", clueId = 0, branch = branch,
                        index = index, nodeId = nodeId,
                    }
                elseif branchNodes[branch][nodeId] then
                    errors[#errors + 1] = {
                        code = "trace_repeated_node", clueId = 0, branch = branch,
                        index = index, nodeId = nodeId,
                    }
                else
                    branchNodes[branch][nodeId] = true
                    if node.socketIndex then
                        local socketIndex = canonicalSocketIndex(
                            node.socketIndex, definition.width, definition.continuous)
                        traced[socketIndex] = addMask(traced[socketIndex], branch)
                    end
                end
                local nextId = stack[index + 1]
                if nextId ~= nil then
                    local edge = node and getEdge(nodeId, nextId) or nil
                    if not edge then
                        errors[#errors + 1] = {
                            code = "trace_adjacency", clueId = 0, branch = branch,
                            index = index, fromId = nodeId, toId = nextId,
                        }
                    else
                        local token = edgeToken(nodeId, nextId)
                        if edge.socketIndex then
                            local socketIndex = canonicalSocketIndex(
                                edge.socketIndex, definition.width, definition.continuous)
                            traced[socketIndex] = addMask(traced[socketIndex], branch)
                        end
                        tracedSegments[token] = addMask(tracedSegments[token], branch)
                        if branchEdges[branch][token] then
                            errors[#errors + 1] = {
                                code = "trace_repeated_edge", clueId = 0,
                                branch = branch, index = index,
                                fromId = nodeId, toId = nextId,
                            }
                        else
                            branchEdges[branch][token] = true
                        end
                    end
                end
            end
        end
    end

    if expectedBranches == 2 and type(stacks[1]) == "table" and
            type(stacks[2]) == "table" then
        if #stacks[1] ~= #stacks[2] then
            errors[#errors + 1] = {
                code = "trace_symmetry", clueId = 0,
                expected = #stacks[1], actual = #stacks[2],
            }
        end
        local limit = math.min(#stacks[1], #stacks[2])
        for index = 1, limit do
            local primary, secondary = stacks[1][index], stacks[2][index]
            local mirror = topology.getSymmetricalNodeId and
                topology:getSymmetricalNodeId(primary) or
                topology.symmetryNodes and topology.symmetryNodes[primary]
            if mirror ~= secondary then
                errors[#errors + 1] = {
                    code = "trace_symmetry", clueId = 0, branch = 2,
                    index = index, nodeId = secondary, expectedNodeId = mirror,
                }
            end
            if index < limit then
                local nextPrimary, nextSecondary = stacks[1][index + 1], stacks[2][index + 1]
                local mirrorEdge = topology.getSymmetricalEdge and
                    topology:getSymmetricalEdge(primary, nextPrimary) or
                    topology.symmetryEdges and topology.symmetryEdges[primary] and
                    topology.symmetryEdges[primary][nextPrimary]
                local mirrorNext = topology.getSymmetricalNodeId and
                    topology:getSymmetricalNodeId(nextPrimary) or
                    topology.symmetryNodes and topology.symmetryNodes[nextPrimary]
                local expectedToken = mirrorEdge and mirrorEdge.fromId and
                    edgeToken(mirrorEdge.fromId, mirrorEdge.toId) or
                    mirror and mirrorNext and edgeToken(mirror, mirrorNext)
                local actualToken = type(secondary) == "number" and
                    type(nextSecondary) == "number" and edgeToken(secondary, nextSecondary)
                if not mirrorEdge or expectedToken ~= actualToken then
                    errors[#errors + 1] = {
                        code = "trace_symmetry_edge", clueId = 0, branch = 2,
                        index = index, fromId = secondary, toId = nextSecondary,
                    }
                end
            end
        end
        for nodeId in pairs(branchNodes[1]) do
            if branchNodes[2][nodeId] then
                errors[#errors + 1] = {
                    code = "trace_shared_node", clueId = 0, nodeId = nodeId,
                }
            end
        end
        for token in pairs(branchEdges[1]) do
            if branchEdges[2][token] then
                errors[#errors + 1] = {
                    code = "trace_shared_edge", clueId = 0, segment = token,
                }
            end
        end
    end
    return errors, traced, tracedSegments
end

local function buildFacts(definition, traceSnapshot, profile, suppliedTraceHash)
    local pathStarted = profile and profileNow()
    traceSnapshot = traceSnapshot or {}
    local topology = definition.topology or {}
    local traceErrors, traced, tracedSegments =
        validateCompletedTrace(definition, traceSnapshot)
    if traceSnapshot.revision ~= nil and
            traceSnapshot.revision ~= definition.topologyRevision then
        traceErrors[#traceErrors + 1] = {
            code = "trace_revision", clueId = 0,
            expected = definition.topologyRevision,
            actual = traceSnapshot.revision,
        }
    end
    sortTraceErrors(traceErrors)
    local closedBoundaries = {}
    for socketIndex in pairs(definition.permanentBoundaries or {}) do
        closedBoundaries[socketIndex] = true
    end
    for socketIndex, requirement in pairs(definition.boundarySegments or {}) do
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

    for _, face in ipairs(definition.faces) do
        parent[face.id] = face.id
    end
    local function faceAt(x, y)
        if x < 1 or x > definition.width or y < 1 or y > definition.height then return nil end
        return definition.faceBySocket[flatIndex(definition.width, x * 2, y * 2)]
    end
    for _, face in ipairs(definition.faces) do
        local right = faceAt(face.x + 1, face.y)
        if right and not closedBoundaries[face.boundaries[2]] then union(face.id, right) end
        local below = faceAt(face.x, face.y + 1)
        if below and not closedBoundaries[face.boundaries[3]] then union(face.id, below) end
        if definition.continuous and face.x == definition.width then
            local wrapped = faceAt(1, face.y)
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
        regions[index] = {
            id = index, faces = {}, cells = {}, clues = {}, erasers = {}, targets = {},
            squares = {}, squareColorSet = {}, stars = {}, starByColor = {},
            colored = {}, dots = {}, triangles = {}, polyominoes = {},
        }
    end

    local regionByFace = {}
    for _, face in ipairs(definition.faces) do
        local regionId = regionByRoot[find(face.id)]
        regionByFace[face.id] = regionId
        regions[regionId].faces[#regions[regionId].faces + 1] = face.id
        regions[regionId].cells[#regions[regionId].cells + 1] = {
            id = face.id, x = face.x, y = face.y,
        }
    end
    for _, region in ipairs(regions) do
        region.cacheKey = table.concat(region.faces, ",")
    end
    if profile then profileAddTime(profile, "regionConstruction", regionStarted) end

    local groupingStarted = profile and profileNow()
    local globalClues = {}
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
        regionId = regionId or 0
        if regionId == 0 then
            globalClues[#globalClues + 1] = clue
        else
            local region = regions[regionId]
            region.clues[#region.clues + 1] = clue
            local group = clue.kind == "eraser" and region.erasers or region.targets
            group[#group + 1] = clue.id
            if clue.kind == "square" then
                region.squares[#region.squares + 1] = clue
                region.squareColorSet[clue.ruleColor] = true
            elseif clue.kind == "star" then
                region.stars[#region.stars + 1] = clue
                local stars = region.starByColor[clue.ruleColor] or {}
                stars[#stars + 1] = clue
                region.starByColor[clue.ruleColor] = stars
            elseif clue.kind == "polyomino" then
                region.polyominoes[#region.polyominoes + 1] = {
                    id = clue.id,
                    sign = clue.negative == true and -1 or 1,
                    orientations = clue.orientations,
                }
            elseif clue.kind == "dot" then
                region.dots[#region.dots + 1] = clue
            elseif clue.kind == "triangle" then
                region.triangles[#region.triangles + 1] = clue
            end
            if clue.socketKind == "cell" and clue.ruleColor then
                region.colored[#region.colored + 1] = clue
            end
        end
    end

    for _, region in ipairs(regions) do
        region.squareColorOrder = sortedKeys(region.squareColorSet)
        region.squareColorSet = nil
        region.starGroups = {}
        for _, color in ipairs(sortedKeys(region.starByColor)) do
            region.starGroups[#region.starGroups + 1] = {
                color = color, clues = region.starByColor[color],
            }
        end
        region.starByColor = nil
    end

    if profile then profileAddTime(profile, "clueGrouping", groupingStarted) end

    return {
        definition = definition,
        traced = traced,
        regions = regions,
        globalClues = globalClues,
        traceErrors = traceErrors,
        traceHash = suppliedTraceHash ~= nil and suppliedTraceHash or
            RuleEngine.HashValue({
                revision = traceSnapshot.revision,
                stacks = traceSnapshot.stacks,
            }),
    }
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
    if clue.traceRole == DOT_PRIMARY then
        covered = mask % 2 == 1
    elseif clue.traceRole == DOT_SECONDARY then
        covered = math.floor(mask / 2) % 2 == 1
    else
        covered = mask > 0
    end
    return clue.negative and not covered or not clue.negative and covered
end

local function addConstraint(report, kind, regionId, participants, details)
    local constraint = {
        kind = kind,
        regionId = regionId or 0,
        participants = participants,
        details = details,
    }
    report.constraints[#report.constraints + 1] = constraint
    for _, id in ipairs(participants) do report.violations[#report.violations + 1] = id end
end

local function evaluateRegion(facts, regionId, removed, options, removalGeneration,
        suppliedRegionProfile)
    local definition = facts.definition
    local profile = options and options.__profile
    local region = regionId > 0 and facts.regions[regionId] or nil
    local regionStarted = profile and profileNow()
    local regionProfile = suppliedRegionProfile or region and profileRegion(profile, regionId)
    removalGeneration = removalGeneration or 0
    local report = {
        status = "complete",
        constraints = {},
        violations = {},
        witnesses = { polyomino = {} },
    }
    if regionProfile then
        regionProfile.revalidations = regionProfile.revalidations + 1
        profileCount(profile, "fullRegionRevalidations")
    end

    local clues = region and region.clues or facts.globalClues
    for _, clue in ipairs(clues) do
        local clueId = clue.id
        local isRemoved = removed[clueId] == removalGeneration
        if not isRemoved then
            if clue.kind == "dot" and
                    not dotSatisfied(clue, facts.traced[clue.socketIndex]) then
                addConstraint(report, "dot", regionId, {clue.id}, {
                    traceRole = clue.traceRole,
                    negative = clue.negative == true,
                })
            elseif clue.kind == "triangle" then
                local faceId = definition.faceBySocket[clue.socketIndex]
                local face = faceId and definition.faces[faceId]
                local count = 0
                for _, boundary in ipairs(face and face.boundaries or {}) do
                    if facts.traced[boundary] then count = count + 1 end
                end
                if count ~= clue.count then
                    addConstraint(report, "triangle", regionId, {clue.id}, {
                        expected = clue.count,
                        actual = count,
                    })
                end
            end

        end
    end

    if region then
        if #region.squares > 1 then
            local squareColors, participants = {}, {}
            for _, clue in ipairs(region.squares) do
                local clueId = clue.id
                local isRemoved = removed[clueId] == removalGeneration
                if not isRemoved then
                    squareColors[clue.ruleColor] = true
                    participants[#participants + 1] = clueId
                end
            end
            local squareColorIds = {}
            for _, color in ipairs(region.squareColorOrder) do
                if squareColors[color] then squareColorIds[#squareColorIds + 1] = color end
            end
            if #squareColorIds > 1 then
                addConstraint(report, "squares", regionId, participants,
                    { colors = squareColorIds })
            end
        end

        if #region.stars > 0 then
            local coloredCellCount = {}
            for _, clue in ipairs(region.colored) do
                local clueId = clue.id
                local isRemoved = removed[clueId] == removalGeneration
                if not isRemoved then
                    coloredCellCount[clue.ruleColor] =
                        (coloredCellCount[clue.ruleColor] or 0) + 1
                end
            end
            for _, group in ipairs(region.starGroups) do
                local participants = {}
                for _, clue in ipairs(group.clues) do
                    if removed[clue.id] ~= removalGeneration then
                        participants[#participants + 1] = clue.id
                    end
                end
                local actual = coloredCellCount[group.color] or 0
                if #participants > 0 and actual ~= 2 then
                    addConstraint(report, "stars", regionId,
                        participants, {
                        color = group.color,
                        actual = actual,
                        expected = 2,
                    })
                end
            end
        end

        if #region.polyominoes > 0 then
            local polyominoes = {}
            for _, clue in ipairs(region.polyominoes) do
                local clueId = clue.id
                local isRemoved = removed[clueId] == removalGeneration
                if not isRemoved then polyominoes[#polyominoes + 1] = clue end
            end
        if #polyominoes > 0 then
            local keyParts = {}
            for _, piece in ipairs(polyominoes) do keyParts[#keyParts + 1] = piece.id end
            local localCache = options and options.__polyominoCache
            local solverCache = options and options.cache
            local cacheKey = definition.ruleRevision .. ":" .. region.cacheKey ..
                ":" .. table.concat(keyParts, ",")
            local solve = localCache and localCache[cacheKey]
            if solve then
                profileCount(profile, "polyominoCacheHits")
            else
                solve = cacheGet(solverCache, "polyominoes", cacheKey)
                if solve then
                    profileCount(profile, "polyominoCacheHits")
                    profileCount(profile, "polyominoPersistentCacheHits")
                else
                    profileCount(profile, "polyominoSolverCalls")
                    profileCount(profile, "polyominoCacheMisses")
                    region.polyRegion = region.polyRegion or normalizePolyRegion({
                        cells = region.cells,
                        wrapWidth = definition.continuous and definition.width or nil,
                    })
                    solve = solveNormalizedPolyomino(region.polyRegion, polyominoes, {
                        checkpoint = options and options.checkpoint,
                    })
                    if solve.status ~= "complexity" then
                        cachePut(solverCache, "polyominoes", cacheKey, solve)
                    end
                end
                if localCache then localCache[cacheKey] = solve end
            end
            if solve.status == "complexity" then
                report.status = "complexity"
                report.complexity = {
                    kind = "polyomino", regionId = regionId, steps = solve.steps,
                }
            elseif solve.status ~= "solved" then
                local participants = {}
                for _, piece in ipairs(polyominoes) do
                    participants[#participants + 1] = piece.id
                end
                addConstraint(report, "polyomino", regionId, participants,
                    { backend = solve.backend })
            else
                report.witnesses.polyomino[regionId] = {
                    backend = solve.backend,
                    target = solve.target,
                    placements = copyTree(solve.placements),
                }
            end
        end
        end
    end

    if regionProfile then
        regionProfile.time = regionProfile.time + profileNow() - regionStarted
    end
    table.sort(report.violations)
    report.success = report.status == "complete" and #report.violations == 0
    return report
end

local function forEachCombination(values, count, checkpoint, callback, profile,
        depthBase)
    local current = {}
    local function visit(start, depth)
        if profile then
            local combinedDepth = (depthBase or 0) + depth
            profile.counters.maxRecursiveDepth = math.max(
                profile.counters.maxRecursiveDepth or 0, combinedDepth)
        end
        if checkpoint and checkpoint(1) == false then return false, "complexity" end
        if depth > count then
            if callback(current) == false then return false, "stopped" end
            return true
        end
        local maximum = #values - (count - depth)
        for index = start, maximum do
            current[depth] = values[index]
            local complete, reason = visit(index + 1, depth + 1)
            if not complete then return false, reason end
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

local function solveEraserRegion(facts, region, erasers, targets, options, baseline)
    if baseline.status ~= "complete" then return { status = baseline.status, report = baseline } end
    local profile = options and options.__profile
    local regionProfile = profileRegion(profile, region.id)
    local pendingSearchWork = 0
    local searchCheckpoints = 0
    local candidateCache = {}
    local removed, removalGeneration = {}, 0
    local summaryOnly = #region.polyominoes == 0
    local validSummary = { status = "complete", success = true }
    local invalidSummary = { status = "complete", success = false }
    local compactKeys = #erasers <= 52 and #targets <= 52
    local flatKeys = compactKeys and #erasers + #targets <= 52
    local eraserKeyRange = flatKeys and 2 ^ #erasers
    local eraserBits, targetBits = {}, {}
    if compactKeys then
        for index, id in ipairs(erasers) do eraserBits[id] = 2 ^ (index - 1) end
        for index, id in ipairs(targets) do targetBits[id] = 2 ^ (index - 1) end
    end
    local function selectionKey(eraserSet, targetSet)
        if compactKeys then
            local eraserKey, targetKey = 0, 0
            for _, id in ipairs(eraserSet) do eraserKey = eraserKey + eraserBits[id] end
            for _, id in ipairs(targetSet) do targetKey = targetKey + targetBits[id] end
            return eraserKey, targetKey
        end
        local eraserKey, targetKey = arrayCopy(eraserSet), arrayCopy(targetSet)
        table.sort(eraserKey)
        table.sort(targetKey)
        return table.concat(eraserKey, ",") .. "|" .. table.concat(targetKey, ",")
    end
    local function cached(cache, key, subkey)
        if not compactKeys then return cache[key] end
        if flatKeys then return cache[key + subkey * eraserKeyRange] end
        local bucket = cache[key]
        return bucket and bucket[subkey]
    end
    local function cache(cacheTable, key, subkey, value)
        if not compactKeys then
            cacheTable[key] = value
            return
        end
        if flatKeys then
            cacheTable[key + subkey * eraserKeyRange] = value
            return
        end
        local bucket = cacheTable[key]
        if not bucket then
            bucket = {}
            cacheTable[key] = bucket
        end
        bucket[subkey] = value
    end
    local function checkpointSearch(force)
        pendingSearchWork = pendingSearchWork + 1
        local batchSize = searchCheckpoints < 4 and 16 or 64
        if not force and pendingSearchWork < batchSize then return true end
        pendingSearchWork = 0
        searchCheckpoints = searchCheckpoints + 1
        return not options or not options.checkpoint or options.checkpoint(1) ~= false
    end
    local function scoreCandidate(eraserSet, targetSet, key, subkey)
        profileCount(profile, "eraserBranches")
        if key == nil then key, subkey = selectionKey(eraserSet, targetSet) end
        local previous = cached(candidateCache, key, subkey)
        if previous then
            profileCount(profile, "eraserCacheHits")
            return previous
        end
        profileCount(profile, "eraserStatesExplored")
        if regionProfile then regionProfile.eraserStates = regionProfile.eraserStates + 1 end
        local previousRegionTime = regionProfile and regionProfile.time or 0
        removalGeneration = removalGeneration + 1
        for _, id in ipairs(eraserSet) do removed[id] = removalGeneration end
        for _, id in ipairs(targetSet) do removed[id] = removalGeneration end
        local candidate
        if summaryOnly then
            local started = profile and profileNow()
            local color, success
            success = true
            for _, clue in ipairs(region.squares) do
                if removed[clue.id] ~= removalGeneration then
                    if color == nil then
                        color = clue.ruleColor
                    elseif color ~= clue.ruleColor then
                        success = false
                        break
                    end
                end
            end
            if success and #region.stars > 0 then
                local coloredCellCount = {}
                for _, clue in ipairs(region.colored) do
                    if removed[clue.id] ~= removalGeneration then
                        coloredCellCount[clue.ruleColor] =
                            (coloredCellCount[clue.ruleColor] or 0) + 1
                    end
                end
                for _, group in ipairs(region.starGroups) do
                    local active = false
                    for _, clue in ipairs(group.clues) do
                        if removed[clue.id] ~= removalGeneration then
                            active = true
                            break
                        end
                    end
                    if active and (coloredCellCount[group.color] or 0) ~= 2 then
                        success = false
                        break
                    end
                end
            end
            if success then
                for _, clue in ipairs(region.dots) do
                    if removed[clue.id] ~= removalGeneration and
                            not dotSatisfied(clue, facts.traced[clue.socketIndex]) then
                        success = false
                        break
                    end
                end
            end
            if success then
                for _, clue in ipairs(region.triangles) do
                    if removed[clue.id] ~= removalGeneration then
                        local faceId = facts.definition.faceBySocket[clue.socketIndex]
                        local face = faceId and facts.definition.faces[faceId]
                        local count = 0
                        for _, boundary in ipairs(face and face.boundaries or {}) do
                            if facts.traced[boundary] then count = count + 1 end
                        end
                        if count ~= clue.count then
                            success = false
                            break
                        end
                    end
                end
            end
            candidate = success and validSummary or invalidSummary
            if regionProfile then
                regionProfile.revalidations = regionProfile.revalidations + 1
                profileCount(profile, "fullRegionRevalidations")
                regionProfile.time = regionProfile.time + profileNow() - started
            end
        else
            candidate = evaluateRegion(
                facts, region.id, removed, options, removalGeneration, regionProfile)
        end
        cache(candidateCache, key, subkey, candidate)
        if profile then
            profile.timings.eraserScoring = (profile.timings.eraserScoring or 0) +
                regionProfile.time - previousRegionTime
        end
        return candidate
    end

    local function lexLess(left, right)
        for index = 1, math.min(#left, #right) do
            if left[index] ~= right[index] then return left[index] < right[index] end
        end
        return #left < #right
    end
    local function constraintCoverage(targetSet)
        local selected, covered = {}, 0
        for _, clueId in ipairs(targetSet) do selected[clueId] = true end
        for _, constraint in ipairs(baseline.constraints or {}) do
            for _, clueId in ipairs(constraint.participants or {}) do
                if selected[clueId] then
                    covered = covered + 1
                    break
                end
            end
        end
        return covered
    end
    local fullValid, fullValidCoverage
    local failedStatus, smaller, orderFailure
    local function recordImproper(candidate, eraserSet, targetSet, fullTargets)
        local nextValue = {
            report = candidate,
            erasers = arrayCopy(eraserSet),
            targets = arrayCopy(targetSet),
            fullTargets = arrayCopy(fullTargets),
        }
        if not smaller or #nextValue.erasers < #smaller.erasers or
                #nextValue.erasers == #smaller.erasers and
                (lexLess(nextValue.erasers, smaller.erasers) or
                    not lexLess(smaller.erasers, nextValue.erasers) and
                    lexLess(nextValue.targets, smaller.targets)) then
            smaller = nextValue
        end
    end
    local function orderedAssignment(targetSet, fullReport)
        if baseline.success then
            recordImproper(baseline, {}, {}, targetSet)
            return nil
        end
        local usedErasers, usedTargets = {}, {}
        local orderedErasers, orderedTargets = {}, {}
        local visited = {}
        local function visit(depth, eraserKey, targetKey)
            if profile then
                profile.counters.maxRecursiveDepth = math.max(
                    profile.counters.maxRecursiveDepth or 0, depth)
            end
            for _, eraserId in ipairs(erasers) do
                if not usedErasers[eraserId] then
                    usedErasers[eraserId] = true
                    orderedErasers[depth] = eraserId
                    for _, targetId in ipairs(targetSet) do
                        if not usedTargets[targetId] then
                            usedTargets[targetId] = true
                            orderedTargets[depth] = targetId
                            local key, subkey
                            if compactKeys then
                                key = eraserKey + eraserBits[eraserId]
                                subkey = targetKey + targetBits[targetId]
                            else
                                key = selectionKey(orderedErasers, orderedTargets)
                            end
                            if not cached(visited, key, subkey) then
                                cache(visited, key, subkey, true)
                                if not checkpointSearch(false) then return nil, "complexity" end
                                local candidate = depth == #erasers and fullReport or
                                    scoreCandidate(orderedErasers, orderedTargets, key, subkey)
                                if candidate.status ~= "complete" then
                                    failedStatus = candidate
                                    return nil, "failed"
                                end
                                if depth == #erasers then
                                    return {
                                        report = candidate,
                                        erasers = arrayCopy(orderedErasers),
                                        targets = arrayCopy(orderedTargets),
                                        pairs = mapping(orderedErasers, orderedTargets),
                                    }
                                elseif candidate.success then
                                    recordImproper(candidate, orderedErasers,
                                        orderedTargets, targetSet)
                                else
                                    local found, reason = visit(depth + 1,
                                        compactKeys and key or 0,
                                        compactKeys and subkey or 0)
                                    if found or reason then return found, reason end
                                end
                            end
                            usedTargets[targetId] = nil
                            orderedTargets[depth] = nil
                        end
                    end
                    usedErasers[eraserId] = nil
                    orderedErasers[depth] = nil
                end
            end
            return nil
        end
        return visit(1, 0, 0)
    end
    local _, fullReason = forEachCombination(
        targets, #erasers, function() return checkpointSearch(false) end,
        function(targetSet)
            local candidate = scoreCandidate(erasers, targetSet)
            if candidate.status ~= "complete" then
                failedStatus = candidate
                return false
            end
            if candidate.success then
                local ordered, reason = orderedAssignment(targetSet, candidate)
                if reason then
                    orderFailure = reason
                    return false
                end
                if ordered then
                    local coverage = constraintCoverage(targetSet)
                    if fullValidCoverage == nil or coverage > fullValidCoverage then
                        fullValidCoverage = coverage
                        fullValid = ordered
                    end
                end
            end
            return true
        end, profile, #erasers)
    if fullReason == "complexity" or orderFailure == "complexity" or
            pendingSearchWork > 0 and
            not checkpointSearch(true) then
        return {
            status = "complexity",
            complexity = { kind = "eraser", regionId = region.id },
        }
    end
    if failedStatus then
        return { status = failedStatus.status, report = failedStatus }
    end
    if not fullValid and not smaller then
        return {
            status = "complete",
            success = false,
            selected = baseline,
            erasures = {},
            invalidErasers = arrayCopy(erasers),
            proof = {
                minimumUsed = false,
                erasers = {},
                targets = {},
            },
        }
    end

    if not fullValid and smaller then
        local used = {}
        for _, eraserId in ipairs(smaller.erasers) do used[eraserId] = true end
        local unused = {}
        for _, eraserId in ipairs(erasers) do
            if not used[eraserId] then unused[#unused + 1] = eraserId end
        end
        local improperPairs = mapping(smaller.erasers, smaller.targets)
        return {
            status = "complete",
            success = false,
            selected = smaller.report,
            erasures = improperPairs,
            unnecessary = unused,
            proof = {
                minimumUsed = #smaller.erasers,
                fullAssignment = {
                    erasers = arrayCopy(erasers),
                    targets = arrayCopy(smaller.fullTargets),
                    pairs = mapping(erasers, smaller.fullTargets),
                },
                improperAssignment = {
                    erasers = arrayCopy(smaller.erasers),
                    targets = arrayCopy(smaller.targets),
                    pairs = improperPairs,
                    unusedErasers = arrayCopy(unused),
                },
            },
        }
    end
    return {
        status = "complete",
        success = true,
        selected = fullValid.report,
        erasures = fullValid.pairs,
        proof = {
            minimumUsed = #erasers,
            fullAssignment = {
                erasers = arrayCopy(fullValid.erasers),
                targets = arrayCopy(fullValid.targets),
                pairs = fullValid.pairs,
            },
        },
    }
end

local function eraserRegionCacheKey(facts, region)
    local definition = facts.definition
    local parts = {
        definition.ruleRevision, region.id, region.cacheKey,
    }
    for _, clue in ipairs(region.dots) do
        parts[#parts + 1] = clue.id
        parts[#parts + 1] = facts.traced[clue.socketIndex] or 0
    end
    for _, clue in ipairs(region.triangles) do
        local faceId = definition.faceBySocket[clue.socketIndex]
        local face = faceId and definition.faces[faceId]
        local count = 0
        for _, boundary in ipairs(face and face.boundaries or {}) do
            if facts.traced[boundary] then count = count + 1 end
        end
        parts[#parts + 1] = clue.id
        parts[#parts + 1] = count
    end
    return table.concat(parts, ":")
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

local function makeReport(definition, facts, status, fields)
    local report = fields or {}
    report.status = status
    report.success = status == "complete" and report.success == true
    report.violations = report.violations or {}
    report.erasures = report.erasures or {}
    report.remaining = report.remaining or arrayCopy(report.violations)
    report.constraints = report.constraints or {}
    report.witnesses = report.witnesses or {}
    report.ruleRevision = definition.ruleRevision
    report.traceHash = facts.traceHash
    return report
end

local function traceCacheKey(traceSnapshot, suppliedTraceHash)
    if type(traceSnapshot) ~= "table" or type(traceSnapshot.stacks) ~= "table" then
        return nil
    end
    local revision = traceSnapshot.revision
    if revision ~= nil and (type(revision) ~= "number" or revision ~= revision) then
        return nil
    end
    local stacks = traceSnapshot.stacks
    local parts = {
        "r", tostring(revision), "h", type(suppliedTraceHash),
        tostring(suppliedTraceHash), "b", tostring(#stacks),
    }
    for key in pairs(stacks) do
        if type(key) ~= "number" or key < 1 or key > #stacks or key % 1 ~= 0 then
            return nil
        end
    end
    for branch = 1, #stacks do
        local stack = stacks[branch]
        if type(stack) ~= "table" then return nil end
        parts[#parts + 1] = "s"
        parts[#parts + 1] = tostring(#stack)
        for key in pairs(stack) do
            if type(key) ~= "number" or key < 1 or key > #stack or key % 1 ~= 0 then
                return nil
            end
        end
        for index = 1, #stack do
            local nodeId = stack[index]
            if type(nodeId) ~= "number" or nodeId ~= nodeId or nodeId % 1 ~= 0 then
                return nil
            end
            parts[#parts + 1] = tostring(nodeId)
        end
    end
    return table.concat(parts, ":")
end

function RuleEngine.Evaluate(definition, traceSnapshot, options)
    options = options or {}
    local profile = beginProfile(options)
    local evaluationStarted = profile and profileNow()
    local solverCache = options.cache
    local traceKey = traceCacheKey(traceSnapshot, options.traceHash)
    local exactKey = traceKey and definition.ruleRevision .. ":" .. traceKey
    local cachedReport = cacheGet(solverCache, "reports", exactKey)
    if cachedReport then
        profileCount(profile, "exactReportCacheHits")
        return finishProfile(copyTree(cachedReport), profile, evaluationStarted)
    end
    if exactKey then profileCount(profile, "exactReportCacheMisses") end
    local runtimeOptions = {}
    for key, value in pairs(options) do runtimeOptions[key] = value end
    runtimeOptions.__profile = profile
    runtimeOptions.__polyominoCache = {}
    options = runtimeOptions
    local function complete(report)
        report.reportHash = hashReport(report)
        if report.status ~= "complexity" then
            cachePut(solverCache, "reports", exactKey, copyTree(report))
        end
        return finishProfile(report, profile, evaluationStarted)
    end
    local facts = cacheGet(solverCache, "facts", exactKey)
    if facts then
        profileCount(profile, "traceFactsCacheHits")
    else
        if exactKey then profileCount(profile, "traceFactsCacheMisses") end
        facts = buildFacts(definition, traceSnapshot, profile, options.traceHash)
        cachePut(solverCache, "facts", exactKey, facts)
    end
    local dataErrors = {}
    for _, failure in ipairs(definition.dataErrors) do dataErrors[#dataErrors + 1] = failure end
    for _, failure in ipairs(facts.traceErrors) do dataErrors[#dataErrors + 1] = failure end
    if #dataErrors > 0 then
        local violationSet = {}
        for _, failure in ipairs(dataErrors) do
            if failure.clueId > 0 then violationSet[failure.clueId] = true end
        end
        local violations = sortedSet(violationSet)
        local report = makeReport(definition, facts, "data_error", {
            violations = violations,
            constraints = {{
                kind = "data",
                regionId = 0,
                participants = arrayCopy(violations),
                details = { errors = dataErrors },
            }},
        })
        return complete(report)
    end
    local initialStarted = profile and profileNow()
    local baselines = {}
    local noRemoved = {}
    local initialStatus, initialComplexity = "complete"
    local initialViolationSet, initialConstraints = {}, {}
    local initialWitnesses = { polyomino = {} }
    local function collectBaseline(baseline)
        for _, id in ipairs(baseline.violations or {}) do initialViolationSet[id] = true end
        for _, constraint in ipairs(baseline.constraints or {}) do
            initialConstraints[#initialConstraints + 1] = constraint
        end
        for regionId, witness in pairs((baseline.witnesses or {}).polyomino or {}) do
            initialWitnesses.polyomino[regionId] = witness
        end
        if baseline.status ~= "complete" then
            initialStatus = baseline.status
            initialComplexity = baseline.complexity
        end
    end
    local globalBaseline = evaluateRegion(facts, 0, noRemoved, options)
    collectBaseline(globalBaseline)
    for _, region in ipairs(facts.regions) do
        if initialStatus ~= "complete" then break end
        local baseline = evaluateRegion(facts, region.id, noRemoved, options)
        baselines[region.id] = baseline
        collectBaseline(baseline)
    end
    local initialViolations = sortedSet(initialViolationSet)
    if profile then
        profileAddTime(profile, "initialValidation", initialStarted)
        for _, regionProfile in pairs(profile.regions) do
            regionProfile.initialTime = regionProfile.time
        end
    end
    if initialStatus ~= "complete" then
        local report = makeReport(definition, facts, initialStatus, {
            violations = initialViolations,
            constraints = initialConstraints,
            witnesses = initialWitnesses,
            complexity = initialComplexity,
        })
        return complete(report)
    end

    local violationSet, remainingSet = {}, {}
    local constraints, erasures = {}, {}
    local witnesses = { polyomino = {}, erasers = {} }
    for _, id in ipairs(initialViolations) do violationSet[id] = true end

    -- Route clues normally inherit one adjacent region. Malformed/extension
    -- topology can leave a clue regionless; keep those constraints global so
    -- they cannot disappear merely because eraser evaluation is regional.
    for _, constraint in ipairs(globalBaseline.constraints) do
        constraints[#constraints + 1] = constraint
    end
    for _, id in ipairs(globalBaseline.violations) do remainingSet[id] = true end

    for _, region in ipairs(facts.regions) do
        local regionEvaluationStarted = profile and profileNow()
        local baseline = baselines[region.id]
        local solved
        if #region.erasers > 0 then
            local eraserKey = eraserRegionCacheKey(facts, region)
            solved = cacheGet(solverCache, "erasers", eraserKey)
            if solved then
                solved = copyTree(solved)
                profileCount(profile, "eraserPersistentCacheHits")
            else
                solved = solveEraserRegion(
                    facts, region, region.erasers, region.targets, options, baseline)
                if solved.status ~= "complexity" then
                    cachePut(solverCache, "erasers", eraserKey, copyTree(solved))
                end
            end
        else
            solved = {
                status = baseline.status,
                success = baseline.success,
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
            local report = makeReport(definition, facts, solved.status, {
                violations = initialViolations,
                erasures = erasures,
                constraints = initialConstraints,
                witnesses = witnesses,
                complexity = solved.complexity or
                    (solved.report and solved.report.complexity),
            })
            return complete(report)
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

    local report = makeReport(definition, facts, "complete", {
        success = next(remainingSet) == nil,
        violations = sortedSet(violationSet),
        erasures = erasures,
        remaining = sortedSet(remainingSet),
        constraints = constraints,
        witnesses = witnesses,
    })
    if profile then profileAddTime(profile, "finalReporting", reportingStarted) end
    return complete(report)
end

hashReport = function(report)
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
