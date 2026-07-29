AddCSLuaFile!

Canvas = Moonpanel.Canvas

shapeSize = (shape) ->
	#shape, #(shape[1] or {})

trimShape = (shape) ->
	rows, cols = shapeSize shape
	return { { 1 } } if rows == 0 or cols == 0

	minX, minY, maxX, maxY = nil, nil, nil, nil
	for y = 1, rows
		for x = 1, #(shape[y] or {})
			if shape[y][x] == 1
				minX = x if not minX or x < minX
				maxX = x if not maxX or x > maxX
				minY = y if not minY or y < minY
				maxY = y if not maxY or y > maxY

	return { { 1 } } unless minX

	output = {}
	for y = minY, maxY
		row = {}
		for x = minX, maxX
			table.insert row, shape[y][x] == 1 and 1 or 0
		table.insert output, row

	output

rotateShape = (shape) ->
	rows, cols = shapeSize shape
	output = {}

	for y = 1, cols
		output[y] = {}
		for x = 1, rows
			output[y][x] = shape[rows - x + 1][y] == 1 and 1 or 0

	trimShape output

shapeKey = (shape) ->
	parts = {}
	for y = 1, #shape
		row = {}
		for x = 1, #(shape[y] or {})
			table.insert row, shape[y][x] == 1 and "1" or "0"
		table.insert parts, table.concat row, ""

	table.concat parts, "/"

shapeCells = (shape) ->
	cells = {}
	for y = 1, #shape
		for x = 1, #(shape[y] or {})
			if shape[y][x] == 1
				table.insert cells, { x: x - 1, y: y - 1 }
	cells

Canvas.GetPolyominoRotations = (shape, rotational = false) ->
	shape = trimShape shape
	rotations = {}
	seen = {}

	current = shape
	maxRotations = rotational and 4 or 1
	for _ = 1, maxRotations
		key = shapeKey current
		if not seen[key]
			seen[key] = true
			table.insert rotations, current

		current = rotateShape current

	rotations

cellKey = (x, y) -> "#{x}:#{y}"

normalizeRegion = (region) ->
	wrapWidth = math.floor tonumber(region.wrapWidth) or 0
	cells = {}
	contains = {}
	minX, minY, maxX, maxY = nil, nil, nil, nil
	for cell in *(region.cells or {})
		x, y = cell.x or cell[1], cell.y or cell[2]
		continue unless x and y
		x = ((x - 1) % wrapWidth) + 1 if wrapWidth > 0
		key = cellKey x, y
		continue if contains[key]
		contains[key] = true
		table.insert cells, { :x, :y, id: cell.id }
		minX = x if not minX or x < minX
		maxX = x if not maxX or x > maxX
		minY = y if not minY or y < minY
		maxY = y if not maxY or y > maxY

	table.sort cells, (a, b) ->
		return a.y < b.y if a.y ~= b.y
		a.x < b.x

	{
		:cells
		:contains
		:minX
		:minY
		:maxX
		:maxY
		wrapWidth: wrapWidth > 0 and wrapWidth or nil
	}

normalizePieces = (pieces) ->
	output = {}
	for index, piece in ipairs pieces or {}
		negative = piece.negative == true or piece.Negative == true or piece.sign == -1
		rotations = Canvas.GetPolyominoRotations piece.shape or piece.Shape or { { 1 } },
			piece.rotatable == true or piece.Rotational == true
		orientationData = {}
		for shape in *rotations
			table.insert orientationData, {
				shape: shape
				key: shapeKey shape
				cells: shapeCells shape
				width: #(shape[1] or {})
				height: #shape
			}
		table.sort orientationData, (a, b) -> a.key < b.key
		table.insert output, {
			id: piece.id or piece.clueId or index
			sign: negative and -1 or 1
			orientations: orientationData
		}
	table.sort output, (a, b) -> a.id < b.id
	output

placementCells = (orientation, ox, oy, wrapWidth = nil) ->
	cells = {}
	for point in *orientation.cells
		x = ox + point.x
		x = ((x - 1) % wrapWidth) + 1 if wrapWidth and wrapWidth > 0
		table.insert cells, { :x, y: oy + point.y }
	cells

spend = (checkpoint, amount = 1) ->
	not checkpoint or checkpoint(amount) ~= false

positiveSolve = (region, pieces, checkpoint) ->
	total = 0
	for piece in *pieces
		total += #piece.orientations[1].cells
	return { status: "unsatisfied", backend: "dlx" } if total ~= #region.cells

	items = {}
	for piece in *pieces
		table.insert items, "p:#{piece.id}"
	for cell in *region.cells
		table.insert items, "c:#{cell.x}:#{cell.y}"

	options = {}
	rowId = 0
	generationSteps = 0
	for piece in *pieces
		for orientationIndex, orientation in ipairs piece.orientations
			for oy = region.minY, region.maxY - orientation.height + 1
				startX = region.wrapWidth and 1 or region.minX
				endX = region.wrapWidth or (region.maxX - orientation.width + 1)
				for ox = startX, endX
					generationSteps += 1
					unless spend checkpoint
						return {
							status: "complexity"
							backend: "dlx"
							steps: generationSteps
						}
					covered = placementCells orientation, ox, oy, region.wrapWidth
					fits = true
					seenCells = {}
					for cell in *covered
						key = cellKey cell.x, cell.y
						if seenCells[key] or not region.contains[key]
							fits = false
							break
						seenCells[key] = true
					continue unless fits
					rowId += 1
					rowItems = { "p:#{piece.id}" }
					for cell in *covered
						table.insert rowItems, "c:#{cell.x}:#{cell.y}"
					table.sort rowItems, (a, b) -> a < b
					table.insert options, {
						id: rowId
						items: rowItems
						payload: {
							pieceId: piece.id
							:orientationIndex
							:ox
							:oy
							cells: covered
						}
					}

	result = Canvas.DLX.Solve items, options, checkpoint
	result.backend = "dlx"
	result.steps = (result.steps or 0) + generationSteps
	if result.status == "solved"
		result.placements = [row.payload for row in *result.rows]
	result

coverageKey = (coverage, domainCells, target, checkpoint) ->
	if target == 0
		occupied = {}
		local minX, minY
		for cell in *domainCells
			return unless spend checkpoint
			value = coverage[cell.key] or 0
			if value ~= 0
				minX = cell.x if not minX or cell.x < minX
				minY = cell.y if not minY or cell.y < minY
				table.insert occupied, { x: cell.x, y: cell.y, :value }
		return "empty" unless minX
		parts = ["#{cell.x - minX}:#{cell.y - minY}:#{cell.value}" for cell in *occupied]
		return table.concat parts, ";"

	parts = {}
	for cell in *domainCells
		return unless spend checkpoint
		value = coverage[cell.key] or 0
		table.insert parts, tostring value - cell.target
	table.concat parts, ","

signedSolveTarget = (region, pieces, target, checkpoint) ->
	margin = 0
	negativeArea = 0
	for piece in *pieces
		maxDim = 1
		for orientation in *piece.orientations
			maxDim = math.max maxDim, orientation.width, orientation.height
		margin += maxDim - 1
		negativeArea += #piece.orientations[1].cells if piece.sign < 0

	minX = region.wrapWidth and 1 or region.minX - margin
	maxX = region.wrapWidth or region.maxX + margin
	minY = region.minY - margin
	maxY = region.maxY + margin
	domainCells = {}
	generationSteps = 0
	for y = minY, maxY
		for x = minX, maxX
			generationSteps += 1
			unless spend checkpoint
				return {
					status: "complexity"
					backend: "signed"
					steps: generationSteps
				}
			key = cellKey x, y
			table.insert domainCells, {
				:x
				:y
				:key
				target: region.contains[key] and target or 0
			}

	placements = {}
	touches = {}
	positiveSupport = {}
	if target == 1
		positiveSupport[cell.key] = true for cell in *domainCells when cell.target == 1
	for pieceIndex, piece in ipairs pieces
		piecePlacements = {}
		pieceTouches = {}
		for orientationIndex, orientation in ipairs piece.orientations
			startY, endY = minY, maxY - orientation.height + 1
			startX = region.wrapWidth and 1 or minX
			endX = region.wrapWidth or (maxX - orientation.width + 1)
			if target == 0 and pieceIndex == 1
				startX, endX = region.minX, region.minX
				startY, endY = region.minY, region.minY
			for oy = startY, endY
				for ox = startX, endX
					generationSteps += 1
					unless spend checkpoint
						return {
							status: "complexity"
							backend: "signed"
							steps: generationSteps
						}
					placement = {
						pieceId: piece.id
						sign: piece.sign
						:orientationIndex
						:ox
						:oy
						cells: placementCells orientation, ox, oy, region.wrapWidth
					}
					if target == 1 and piece.sign > 0
						outside = 0
						for cell in *placement.cells
							outside += 1 unless region.contains[cellKey cell.x, cell.y]
						-- Every positive unit outside the target region needs
						-- a negative unit to cancel it. Reject placements that
						-- exceed the complete negative area before search.
						continue if outside > negativeArea
					table.insert piecePlacements, placement
					placementIndex = #piecePlacements
					for cell in *placement.cells
						key = cellKey cell.x, cell.y
						positiveSupport[key] = true if target == 1 and piece.sign > 0
						pieceTouches[key] or= {}
						table.insert pieceTouches[key], placementIndex
		placements[pieceIndex] = piecePlacements
		touches[pieceIndex] = pieceTouches

	if target == 1
		-- Negative coverage can only occur where the region itself or at least
		-- one viable positive placement can supply coverage. Filtering that
		-- impossible exterior removes a large empty search halo while
		-- preserving every signed solution.
		domainCells = [cell for cell in *domainCells when positiveSupport[cell.key]]
		for pieceIndex, piece in ipairs pieces
			if piece.sign < 0
				filtered = {}
				for placement in *placements[pieceIndex]
					fitsSupport = true
					for cell in *placement.cells
						unless positiveSupport[cellKey cell.x, cell.y]
							fitsSupport = false
							break
					table.insert filtered, placement if fitsSupport
				placements[pieceIndex] = filtered

		-- Placement indices changed during filtering, so rebuild the sparse
		-- cell-to-placement index once from the compact candidate sets.
		touches = {}
		for pieceIndex, piecePlacements in ipairs placements
			pieceTouches = {}
			for placementIndex, placement in ipairs piecePlacements
				for cell in *placement.cells
					key = cellKey cell.x, cell.y
					pieceTouches[key] or= {}
					table.insert pieceTouches[key], placementIndex
			touches[pieceIndex] = pieceTouches

	coverage = {}
	chosen = {}
	remaining = [true for _ = 1, #pieces]
	remainingCount = #pieces
	seen = {}
	steps = generationSteps
	aborted = false

	withinRemainingBounds = ->
		for cell in *domainCells
			unless spend checkpoint
				aborted = true
				return false
			value = coverage[cell.key] or 0
			positive, negative = 0, 0
			for pieceIndex, piece in ipairs pieces
				unless spend checkpoint
					aborted = true
					return false
				if remaining[pieceIndex] and touches[pieceIndex][cell.key]
					if piece.sign > 0
						positive += 1
					else
						negative += 1
			return false if value - negative > cell.target
			return false if value + positive < cell.target
		true

	remainingKey = ->
		ids = [pieces[index].id for index = 1, #pieces when remaining[index]]
		table.concat ids, ","

	selectCandidates = ->
		local best
		for cell in *domainCells
			unless spend checkpoint
				aborted = true
				return
			value = coverage[cell.key] or 0
			continue if value == cell.target
			requiredSign = value < cell.target and 1 or -1
			candidates = {}
			for pieceIndex, piece in ipairs pieces
				unless spend checkpoint
					aborted = true
					return
				continue unless remaining[pieceIndex] and piece.sign == requiredSign
				for placementIndex in *(touches[pieceIndex][cell.key] or {})
					unless spend checkpoint
						aborted = true
						return
					table.insert candidates, { :pieceIndex, :placementIndex }
			return {} if #candidates == 0
			best = candidates if not best or #candidates < #best

		return best if best

		-- If the current coverage is already exact, remaining pieces must
		-- cancel as a group. Fixing the lowest stable piece's turn loses no
		-- solutions because all placement effects commute.
		for pieceIndex = 1, #pieces
			if remaining[pieceIndex]
				anchored = {}
				for index, placement in ipairs placements[pieceIndex]
					if placement.ox == region.minX and placement.oy == region.minY
						table.insert anchored, { :pieceIndex, placementIndex: index }
				return anchored
		{}

	search = ->
		if remainingCount == 0
			for cell in *domainCells
				return false if (coverage[cell.key] or 0) ~= cell.target
			return true

		fieldKey = coverageKey coverage, domainCells, target, checkpoint
		unless fieldKey
			aborted = true
			return false
		memoKey = "#{remainingKey!}|#{fieldKey}"
		return false if seen[memoKey]
		seen[memoKey] = true

		candidates = selectCandidates!
		return false if aborted
		for candidate in *candidates
			steps += 1
			unless spend checkpoint
				aborted = true
				return false

			pieceIndex = candidate.pieceIndex
			placement = placements[pieceIndex][candidate.placementIndex]
			for cell in *placement.cells
				key = cellKey cell.x, cell.y
				coverage[key] = (coverage[key] or 0) + placement.sign
			chosen[pieceIndex] = placement
			remaining[pieceIndex] = false
			remainingCount -= 1

			if withinRemainingBounds! and search!
				return true

			remaining[pieceIndex] = true
			remainingCount += 1
			for cell in *placement.cells
				key = cellKey cell.x, cell.y
				value = (coverage[key] or 0) - placement.sign
				coverage[key] = value ~= 0 and value or nil
			chosen[pieceIndex] = nil
			return false if aborted

		false

	solved = search!
	return { status: "complexity", backend: "signed", :steps } if aborted
	return { status: "unsatisfied", backend: "signed", :steps } unless solved
	{
		status: "solved"
		backend: "signed"
		:steps
		target: target
		placements: [chosen[index] for index = 1, #pieces]
	}

Canvas.PolyominoSolver = {}

Canvas.PolyominoSolver.Solve = (regionInput, pieceInput, options = {}) ->
	region = normalizeRegion regionInput or {}
	pieces = normalizePieces pieceInput or {}
	return { status: "unsatisfied" } if #region.cells == 0 or #pieces == 0

	checkpoint = options.checkpoint
	hasNegative = false
	signedArea = 0
	for piece in *pieces
		count = #piece.orientations[1].cells
		hasNegative = true if piece.sign < 0
		signedArea += piece.sign * count

	unless hasNegative
		return positiveSolve region, pieces, checkpoint

	unless signedArea == #region.cells or signedArea == 0
		return { status: "unsatisfied", backend: "signed" }

	targets = if signedArea == #region.cells then { 1 } else { 0 }
	for target in *targets
		result = signedSolveTarget region, pieces, target, checkpoint
		return result if result.status == "solved" or result.status == "complexity"

	{ status: "unsatisfied", backend: "signed" }
