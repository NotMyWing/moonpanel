include "shared.lua"
DLX = include "moonpanel/sv_dlx.lua"

ENT.Initialize = () =>
	self.BaseClass.Initialize   self
	self\PhysicsInit            SOLID_VPHYSICS
	self\SetMoveType            MOVETYPE_VPHYSICS
	self\SetSolid               SOLID_VPHYSICS
	self\SetUseType             SIMPLE_USE

ENT.Use = (activator) =>
	Moonpanel\setFocused activator, true

ENT.PreEntityCopy = () =>
	duplicator.StoreEntityModifier @, "TheMoonpanelTileData", @tileData

ENT.PostEntityPaste = (ply, ent, CreatedEntities) =>

import rshift, lshift, band, bor, bnot from (bit or bit32 or require "bit")

hasValue = (t, val) ->
    for k, v in pairs t
        if v == val
            return true
    return false

findPolySolutions = (polyos, maxArea, result, currentPoly = 1, solution = {}, currentArea = 0) ->
    if currentPoly == #polyos + 1
        sol = { unpack(solution) }
        sol[#sol + 1] = currentArea
        table.insert result, sol
        return

	if #result > 3000
		return

    findPolySolutions polyos, maxArea, result, currentPoly + 1, { unpack (solution) }, currentArea

    if currentArea + polyos[currentPoly]\countOnes! <= maxArea
        currentArea += polyos[currentPoly]\countOnes!

        table.insert solution, polyos[currentPoly]
        findPolySolutions polyos, maxArea, result, currentPoly + 1, solution, currentArea

ENT.PopulateWithPositions = (positions, id, poly, area) =>
	-- Bit matrices are right-to-left.
	-- Exact cover is normal Cartesian.
	-- Nested matrices are Cartesian, but Y is reversed.
	-- ...good god.
	for rotation = 0, poly.rotational and 3 or 0
		rotatedPoly = poly\rotate rotation

		if rotatedPoly.w > area.w or rotatedPoly.h > area.h
			continue

		for j = 0, area.h - rotatedPoly.h
			for i = 0, area.w - rotatedPoly.w
				fits = true
				for polyj = 1, rotatedPoly.h
					row = area.rows[j + polyj]
					polyRow = lshift rotatedPoly.rows[polyj], i

					if row ~= bor polyRow, row
						fits = false
						break
				
				if fits
					pos = { id }
					for polyj = 1, rotatedPoly.h
						polyRow = rotatedPoly.rows[polyj]
						for polyi = 1, rotatedPoly.w
							if band(polyRow, (lshift 1, polyi - 1)) ~= 0
								table.insert pos, tostring(polyi + i - 1) .. "x" .. tostring(polyj + j - 1)
					table.insert positions, pos

ENT.CheckPolySolution = (polys, area) =>
	names = {}
	for i = 1, area.w
		for j = 1, area.h
			row = area.rows[j]
			if band(row, lshift 1, i - 1) ~= 0
				names[#names + 1] = tostring(i - 1) .. "x" .. tostring(j - 1)

	for i = 1, #polys
		names[#names + 1] = i

	data = { names }

	for i = 1, #polys
		@PopulateWithPositions data, i, polys[i], area

	numRows = area.h
	numColumns = area.w

	xcc, err = DLX\new data
	if not xcc
		return false

	for sol in xcc\dance()
		return true

	return false

timeout = 0.5
ENT.CheckSolution = (errors) =>
	@__solutionCheckMaxTime = CurTime! + timeout

	paths = {}
	cells = {}
	intersections = {}
	everything = {}
    width = @tileData.Tile.Width
    height = @tileData.Tile.Height

	grayOut = {
		[MOONPANEL_OBJECT_TYPES.CELL]: {}
		[MOONPANEL_OBJECT_TYPES.INTERSECTION]: {}
		[MOONPANEL_OBJECT_TYPES.VPATH]: {}
		[MOONPANEL_OBJECT_TYPES.HPATH]: {}
	}

	redOut = {
		errored: false
		[MOONPANEL_OBJECT_TYPES.CELL]: {}
		[MOONPANEL_OBJECT_TYPES.INTERSECTION]: {}
		[MOONPANEL_OBJECT_TYPES.VPATH]: {}
		[MOONPANEL_OBJECT_TYPES.HPATH]: {}
	}

	for i = 1, width
		for j = 1, height + 1
			hpath = @elements.hpaths[i][j]
			hpath.solutionData = {}
			table.insert everything, hpath
			table.insert paths, hpath

	for i = 1, width + 1
		for j = 1, height
			vpath = @elements.vpaths[i][j]
			vpath.solutionData = {}
			table.insert everything, vpath
			table.insert paths, vpath

	for i = 1, width
		for j = 1, height
			cell = @elements.cells[i][j]
			cell.solutionData = {}
			table.insert cells, cell
			table.insert everything, cell

	for i = 1, width + 1
		for j = 1, height + 1
			intersection = @elements.intersections[i][j]
			intersection.solutionData = {}
			table.insert intersections, intersection
			table.insert everything, intersection

	for i, stack in pairs @pathFinder.nodeStacks
		for j = 2, #stack - 1
			a = stack[j - 1]
			b = stack[j]

			found = false
			for _, path in pairs paths
				if not a.intersection or not b.intersection
					return
				elseif path\getClassName! == "HPath" and 
					(a.intersection == path\getLeft! and b.intersection == path\getRight!) or
					(b.intersection == path\getLeft! and a.intersection == path\getRight!)

					path.solutionData.traced = true
					a.intersection.solutionData.traced = true
					b.intersection.solutionData.traced = true

					found = true
					break

				elseif path\getClassName! == "VPath" and
					(a.intersection == path\getTop! and b.intersection == path\getBottom!) or
					(b.intersection == path\getTop! and a.intersection == path\getBottom!)

					path.solutionData.traced = true
					a.intersection.solutionData.traced = true
					b.intersection.solutionData.traced = true

					found = true
					break

			if not found
				return

	areas = {}

	traverse = (current, area) ->
        current.solutionData.area = area
        table.insert area, current

        toTraverse = {
            current\getLeft!
            current\getRight!
            current\getTop!
            current\getBottom!
        }

        for k, v in pairs toTraverse
            if not v or v.solutionData.area or v.solutionData.traced
                continue

            traverse v, area

	while true do
		unmarked = {}
		area = {}
		for k, v in pairs everything
			if not v.solutionData.area and not v.solutionData.traced
				table.insert unmarked, v

		if #unmarked == 0
			break                

		traverse unmarked[1], area
		
		table.insert areas, area

	totalErrors = {}
	for _, area in pairs areas
		if CurTime! >= @__solutionCheckMaxTime
			error "Moonpanel ##{@EntIndex!}: solution check timed out."

		areaData = {}
		ySymbols = {}

		markAsError = (element) ->
			nextYSymbol = nil
			nextYSymbolID = nil
			for id, ySymbol in pairs ySymbols
				if ySymbol ~= element and not ySymbol.solutionData.inactive
					nextYSymbol = ySymbol
					nextYSymbolID = id
					break

			if nextYSymbol
				grayOut.grayedOut = true
				
				grayOut[element.type][element.y] or= {}
				grayOut[element.type][element.y][element.x] = true
				grayOut[MOONPANEL_OBJECT_TYPES.CELL][nextYSymbol.y] or= {}
				grayOut[MOONPANEL_OBJECT_TYPES.CELL][nextYSymbol.y][nextYSymbol.x] = true

				element.solutionData.inactive = true
				nextYSymbol.solutionData.inactive = true
				table.remove ySymbols, nextYSymbolID
				
				if element.entity\getClassName! == "Y"
					for id, ySymbol in pairs ySymbols
						if ySymbol == element
							table.remove ySymbols, id
							break

			else
				redOut.errored = true

			redOut[element.type][element.y] or= {}
			redOut[element.type][element.y][element.x] = true

		for _, element in pairs area
			if element.entity
				if element.entity\getClassName! == "Y"
					table.insert ySymbols, element

		for _, element in pairs area
			if element.entity
				if not element.entity\checkSolution areaData
					markAsError element
						
		-- Check colors! The plain old functional way.
		groups = {}
		for i = 1, #Moonpanel.Colors
			groups[i] = {}

		for _, element in pairs area
			if element.entity
				if element.entity\getClassName! == "Color"
					table.insert groups[element.entity.attributes.color], element

		table.sort groups, (a, b) ->
			#a > #b

		if #groups[2] > 0               
			for i = 2, #groups
				for _, element in pairs groups[i]
					markAsError element

		-- pepehands
		positivePolyos = {}
		negativePolyos = {}
		for _, element in pairs area
			if element.entity and element.entity\getClassName! == "Polyomino"
				table.insert positivePolyos, element.entity.attributes.shape
				element.entity.attributes.shape.element = element

		if #positivePolyos == 0 and #negativePolyos > 0
			for _, element in pairs negativePolyos
				markAsError element
				
		if #positivePolyos > 0
			minx, miny, maxx, maxy = nil, nil, nil, nil
			countPositives = 0
			for _, v in pairs area
				if v.type == MOONPANEL_OBJECT_TYPES.CELL
					if not maxx or v.x > maxx
						maxx = v.x
					if not minx or v.x < minx
						minx = v.x
					if not maxy or v.y > maxy
						maxy = v.y
					if not miny or v.y < miny
						miny = v.y
					
					if v.entity and v.entity\getClassName! == "Polyomino"
						countPositives += v.entity.attributes.shape\countOnes!

			areaMatrix = Moonpanel.BitMatrix maxx-minx + 1, maxy-miny + 1

			for _, v in pairs area
				if v.type == MOONPANEL_OBJECT_TYPES.CELL
					areaMatrix\set v.x - minx + 1, v.y - miny + 1, 1

			negativePolyos = { areaMatrix }
			countNegatives = areaMatrix\countOnes!
			
			if countPositives < countNegatives
				for _, v in pairs area
					if v.entity and v.entity\getClassName! == "Polyomino"
						markAsError v

			elseif countPositives >= countNegatives
				if #positivePolyos == 1
					if not @CheckPolySolution positivePolyos, areaMatrix  
						markAsError positivePolyos[1].element
				shouldDepthTest = true

				if countPositives == countNegatives
					if @CheckPolySolution positivePolyos, areaMatrix
						shouldDepthTest = false

				if shouldDepthTest
					polyCombinations = {} 
					findPolySolutions positivePolyos, countNegatives, polyCombinations

					if #polyCombinations == 0
						for k, v in pairs positivePolyos
							markAsError v.element
					else
						successfulSolutions = {}
						for k, v in pairs polyCombinations
							if CurTime! >= @__solutionCheckMaxTime
								error "Moonpanel ##{@EntIndex!}: solution check timed out."

							if v[#v] == countNegatives
								table.remove v, #v
								success = @CheckPolySolution v, areaMatrix
								if success
									table.insert successfulSolutions, v

						if #successfulSolutions > 0
							table.sort successfulSolutions, (a, b) ->
								#a > #b
							for k, v in pairs positivePolyos
								if not hasValue successfulSolutions[1], v
									markAsError v.element
						else
							for k, v in pairs positivePolyos
								markAsError v.element

		-- It could've been great if I could just handle suns the OO way as well,
		-- but... well, this is just easier overall.
		checkSuns = () ->
			for _, element in pairs area
				if not element.solutionData.inactive and element.entity and element.entity\getClassName! == "Sun"
					count = 1
					for _, otherElement in pairs area
						if otherElement.type == MOONPANEL_OBJECT_TYPES.CELL and
							element ~= otherElement and otherElement.entity and otherElement.entity.attributes and
							not otherElement.solutionData.inactive and
							otherElement.entity.attributes.color == element.entity.attributes.color

							count += 1
							if count > 2
								break 
					if count ~= 2
						markAsError element

		checkSuns!
		for _, ySymbol in pairs ySymbols
			markAsError ySymbol
		checkSuns!

	return grayOut, redOut

ENT.StartPuzzle = (ply, x, y) =>
	shouldStart = false
	activeUser = @GetNW2Entity "ActiveUser"

	nodeA, nodeB = nil
	if @pathFinder -- and @isPowered
		if not IsValid(activeUser) and IsValid ply
			nodeA = @pathFinder\getClosestNode x, y, @calculatedDimensions.barLength
			if not nodeA
				return

			if @tileData.Tile.Symmetry
				nodeB = @pathFinder\getSymmetricalNode nodeA
				if not nodeB
					return
					
			shouldStart = true

	if not shouldStart
		return false

	@SetNW2Entity "ActiveUser", ply
	Moonpanel\broadcastStart @, nodeA, nodeB
	@pathFinder\restart nodeA, nodeB
	@__lastSolution = nil

	return true

ENT.FinishPuzzle = () =>
	activeUser = @GetNW2Entity "ActiveUser"

	if not IsValid activeUser
		return false

	@SetNW2Entity "ActiveUser", nil

	success, aborted = true, false
	grayOut = {}
	redOut = {}

	lastInts = {}
	for i, nodeStack in pairs @pathFinder.nodeStacks
		last = nodeStack[#nodeStack]
		if not last.exit
			success = false

	if success
		grayOut, redOut = @CheckSolution!

		if redOut.errored
			success = false
	else
		aborted = true

	-- Serialize them stacks.
	stacks = {}
	for _, nodeStack in pairs @pathFinder.nodeStacks
		stack = {}
		stacks[#stacks + 1] = stack

		for _, node in pairs nodeStack
			stack[#stack + 1] = @pathFinder.nodeIds[node]

	cursors = @pathFinder.cursors

	Moonpanel\broadcastFinish @, {
		:success
		:aborted
		:redOut
		:grayOut
		:stacks
		:cursors
	}

	@lastSolution = {
		:success
		:aborted
		:redOut
		:grayOut
	}

ENT.ServerThink = () =>
	activeUser = @GetNW2Entity "ActiveUser"
	if IsValid activeUser		
		if activeUser\GetNW2Entity("TheMP Controlled Panel") ~= @
			@FinishPuzzle!

ENT.ServerTickrateThink = () =>