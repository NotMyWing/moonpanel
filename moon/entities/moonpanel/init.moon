AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_panel.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"

DLX = include "moonpanel/sv_dlx.lua"

ENT.Initialize = () =>
    self.BaseClass.Initialize   self
    self\PhysicsInit            SOLID_VPHYSICS
    self\SetMoveType            MOVETYPE_VPHYSICS
    self\SetSolid               SOLID_VPHYSICS
    self\SetUseType             SIMPLE_USE

    @SetNW2Bool "TheMP Powered", true

    if WireLib and not @WireOutputs
        @WireInputs = WireLib.CreateInputs @, { "TurnOff" }
        @WireOutputs = WireLib.CreateOutputs @, { "Success", "Erased [ARRAY]" }

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
    @__solutionCheckMaxTime = os.clock! + timeout

    width = @tileData.Tile.Width
    height = @tileData.Tile.Height

    grayOut = {
        [Moonpanel.ObjectTypes.Cell]: {}
        [Moonpanel.ObjectTypes.Intersection]: {}
        [Moonpanel.ObjectTypes.VPath]: {}
        [Moonpanel.ObjectTypes.HPath]: {}
    }

    redOut = {
        errored: false
        [Moonpanel.ObjectTypes.Cell]: {}
        [Moonpanel.ObjectTypes.Intersection]: {}
        [Moonpanel.ObjectTypes.VPath]: {}
        [Moonpanel.ObjectTypes.HPath]: {}
    }

    paths = {}
    intersections = {}
    everything = {}
    for i = 1, width + 1
        for j = 1, height + 1
            if j <= height + 1 and i <= width
                hpath = @elements.hpaths[j][i]
                hpath.solutionData = {}
                table.insert everything, hpath
                table.insert paths, hpath

            if j <= height and i <= width + 1
                vpath = @elements.vpaths[j][i]
                vpath.solutionData = {}
                table.insert everything, vpath
                table.insert paths, vpath

            if j <= height and i <= width
                cell = @elements.cells[j][i]
                cell.solutionData = {}
                table.insert everything, cell

            intersection = @elements.intersections[j][i]
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

                elseif path.type == Moonpanel.ObjectTypes.HPath and
                    (a.intersection == path\getLeft! and b.intersection == path\getRight!) or
                    (b.intersection == path\getLeft! and a.intersection == path\getRight!)

                    path.solutionData.traced = true
                    a.intersection.solutionData.traced = true
                    b.intersection.solutionData.traced = true

                    found = true
                    break

                elseif path.type == Moonpanel.ObjectTypes.VPath and
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

    isBridge = (element, next) ->
        if element.entity and element.entity.type == Moonpanel.EntityTypes.Invisible
            if not (next) or (next.entity and next.entity == Moonpanel.EntityTypes.Invisible)
                return false
            else
                return true
        else
            return true

    traverse = (current, area) ->
        current.solutionData.area = area
        table.insert area, current

        left    = current\getLeft!
        right   = current\getRight!
        top     = current\getTop!
        bottom  = current\getBottom!

        if current.type == Moonpanel.ObjectTypes.Cell and not (current.entity and current.entity.type ~= Moonpanel.EntityTypes.Invisible)
            left    = left   and (isBridge left   , left\getLeft!    ) and left
            right   = right  and (isBridge right  , right\getRight!  ) and right
            top     = top    and (isBridge top    , top\getTop!      ) and top
            bottom  = bottom and (isBridge bottom , bottom\getBottom!) and bottom

        toTraverse = { left, right, top, bottom }

        for k, v in pairs toTraverse
            if not v or v.solutionData.area or v.solutionData.traced
                continue

            traverse v, area

    while true do
        if os.clock! >= @__solutionCheckMaxTime
            error "Moonpanel ##{@EntIndex!}: area marking timed out."

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
        if os.clock! >= @__solutionCheckMaxTime
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
                grayOut[Moonpanel.ObjectTypes.Cell][nextYSymbol.y] or= {}
                grayOut[Moonpanel.ObjectTypes.Cell][nextYSymbol.y][nextYSymbol.x] = true

                element.solutionData.inactive = true
                nextYSymbol.solutionData.inactive = true
                table.remove ySymbols, nextYSymbolID
                
                if element.entity.type == Moonpanel.EntityTypes.Eraser
                    for id, ySymbol in pairs ySymbols
                        if ySymbol == element
                            table.remove ySymbols, id
                            break

            else
                redOut.errored = true

            redOut[element.type][element.y] or= {}
            redOut[element.type][element.y][element.x] = true

        for _, element in pairs area
            if element.entity and element.entity.type == Moonpanel.EntityTypes.Eraser
                table.insert ySymbols, element

        for _, element in pairs area
            if element.entity and not element.entity\checkSolution areaData
                markAsError element
                        
        groups = {}
        for i = 1, #Moonpanel.Colors
            groups[i] = {}

        for _, element in pairs area
            if element.entity and element.entity.type == Moonpanel.EntityTypes.Color
                table.insert groups[element.entity.attributes.color], element

        table.sort groups, (a, b) ->
            #a > #b

        if #groups[2] > 0               
            for i = 2, #groups
                for _, element in pairs groups[i]
                    markAsError element

        positivePolyos = {}
        negativePolyos = {}
        for _, element in pairs area
            if element.entity and element.entity.type == Moonpanel.EntityTypes.Polyomino
                table.insert positivePolyos, element.entity.attributes.shape
                element.entity.attributes.shape.element = element

        if #positivePolyos == 0 and #negativePolyos > 0
            for _, element in pairs negativePolyos
                markAsError element
                
        if #positivePolyos > 0
            minx, miny, maxx, maxy = nil, nil, nil, nil
            countPositives = 0
            for _, v in pairs area
                if v.type == Moonpanel.ObjectTypes.Cell
                    if not maxx or v.x > maxx
                        maxx = v.x
                    if not minx or v.x < minx
                        minx = v.x
                    if not maxy or v.y > maxy
                        maxy = v.y
                    if not miny or v.y < miny
                        miny = v.y
                    
                    if v.entity and v.entity.type == Moonpanel.EntityTypes.Polyomino
                        countPositives += v.entity.attributes.shape\countOnes!

            areaMatrix = Moonpanel.BitMatrix maxx-minx + 1, maxy-miny + 1

            for _, v in pairs area
                if (v.type == Moonpanel.ObjectTypes.Cell) and not (v.entity and v.entity.type == Moonpanel.EntityTypes.Invisible)
                    areaMatrix\set v.x - minx + 1, v.y - miny + 1, 1

            negativePolyos = { areaMatrix }
            countNegatives = areaMatrix\countOnes!
            
            if countPositives < countNegatives
                for _, v in pairs area
                    if v.entity and v.entity.type == Moonpanel.EntityTypes.Polyomino
                        markAsError v

            elseif countPositives >= countNegatives
                if #positivePolyos == 1
                    if not @CheckPolySolution positivePolyos, areaMatrix  
                        markAsError positivePolyos[1].element
                shouldTestCombinations = true

                if countPositives == countNegatives
                    if @CheckPolySolution positivePolyos, areaMatrix
                        shouldTestCombinations = false

                if shouldTestCombinations
                    polyCombinations = {} 
                    findPolySolutions positivePolyos, countNegatives, polyCombinations

                    if #polyCombinations == 0
                        for k, v in pairs positivePolyos
                            markAsError v.element
                    else
                        successfulSolutions = {}
                        for k, v in pairs polyCombinations
                            if os.clock! >= @__solutionCheckMaxTime
                                error "Moonpanel ##{@EntIndex!}: polyomino solution check timed out."

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
                if not element.solutionData.inactive and element.entity and element.entity.type == Moonpanel.EntityTypes.Sun
                    count = 1
                    for _, otherElement in pairs area
                        if otherElement.type == Moonpanel.ObjectTypes.Cell and
                            element ~= otherElement and otherElement.entity and otherElement.entity.attributes and
                            not otherElement.solutionData.inactive and
                            otherElement.entity.attributes.color == element.entity.attributes.color

                            count += 1
                            if count > 2
                                break 
                    if count ~= 2
                        markAsError element

        firstCheck = true
        wasSingleYSymbol = false
        while firstCheck or #ySymbols > 0
            firstCheck = false

            if os.clock! >= @__solutionCheckMaxTime
                error "Moonpanel ##{@EntIndex!}: ySymbol elimination timed out."
            checkSuns!
            for _, ySymbol in pairs ySymbols
                markAsError ySymbol
            checkSuns!

            if wasSingleYSymbol
                break
            wasSingleYSymbol = #ySymbols == 1

    return grayOut, redOut

ENT.Desync = () =>
    @__nextDesync or= 0
    if CurTime! >= @__nextDesync
        @lastSolution = nil
        @tileData = nil
        @pathFinder = nil

        Moonpanel\broadcastDesync @

        if WireLib
            @UpdateOutputs!

        @__nextDesync = CurTime! + 1
        return true

ENT.StartPuzzle = (ply, x, y) =>
    if not @pathFinder or not @tileData
        return false

    if IsValid @GetNW2Entity "ActiveUser"
        return false

    if @GetNW2Bool "TheMP Errored"
        return false

    shouldStart = false

    nodeA, nodeB = nil
    if @pathFinder and @GetNW2Bool "TheMP Powered"
        if IsValid ply
            nodeA = @pathFinder\getClosestNode x, y, @calculatedDimensions.barLength
            if not nodeA
                return

            if @tileData.Tile.Symmetry ~= Moonpanel.Symmetry.None
                nodeB = @pathFinder\getSymmetricalClickableNode nodeA
                if not nodeB
                    return
                    
            shouldStart = true

    if not shouldStart
        return false

    @SetNW2Entity "ActiveUser", ply
    Moonpanel\broadcastStart @, nodeA, nodeB
    @pathFinder\restart nodeA, nodeB
    @__lastSolution = nil

    if WireLib
        timer.Remove @GetTimerName("WireOutput")

    return true

ENT.FinishPuzzle = (forceFail) =>
    @SetNW2Entity "ActiveUser", nil

    cursors = @pathFinder.cursors

    success, aborted = true, false
    grayOut = {}
    redOut = {}

    lastInts = {}
    for i, nodeStack in pairs @pathFinder.nodeStacks
        potentialNode = @pathFinder.potentialNodes[i]
        if not nodeStack[#nodeStack].exit and potentialNode and potentialNode.exit
            table.insert nodeStack, potentialNode

        elseif not nodeStack[#nodeStack].exit
            success = false

    -- Serialize them stacks.
    stacks = {}
    for _, nodeStack in pairs @pathFinder.nodeStacks
        stack = {}
        stacks[#stacks + 1] = stack

        for _, node in pairs nodeStack
            stack[#stack + 1] = @pathFinder.nodeIds[node]

    if success
        func = () ->
            @CheckSolution!

        catch = (err) ->
            print err

        status, grayOut, redOut = xpcall func, catch 

        if not status
            @SetNW2Bool "TheMP Errored", true
            @SetNW2Bool "TheMP Powered", false
            return

        if not redOut or redOut.errored
            success = false
    else
        aborted = true

    if WireLib
        if not aborted
            @UpdateOutputs success, redOut, grayOut

    Moonpanel\broadcastFinish @, {
        :success
        :aborted
        :redOut
        :grayOut
        :stacks
        :cursors
        :forceFail
    }

    @lastSolution = {
        :success
        :aborted
        :redOut
        :grayOut
        :forceFail
    }

ENT.ServerThink = () =>
    activeUser = @GetNW2Entity "ActiveUser"
    if IsValid activeUser		
        if activeUser\GetNW2Entity("TheMP Controlled Panel") ~= @
            @FinishPuzzle!

ENT.ServerTickrateThink = () =>

ENT.SetupDataServer = (data) =>

if WireLib
    ENT.UpdateOutputs = (success = false, redOut = {}, grayOut = {}) =>
        if success == nil
            return -- noop
 
        if success
            if grayOut.grayedOut
                WireLib.TriggerOutput @, "Success", 0
                WireLib.TriggerOutput @, "Erased", {}

                timer.Create @GetTimerName("WireOutput"), 0.75, 1, () ->
                    if not IsValid @
                        return

                    WireLib.TriggerOutput @, "Success", 1
                    erased = {}
                    for k, types in pairs grayOut
                        if type(types) == "table"
                            for j, row in pairs types
                                for i, state in pairs row
                                    if state
                                        erased[#erased + 1] = Vector i, j, k

                    WireLib.TriggerOutput @, "Erased", erased
            else
                WireLib.TriggerOutput @, "Success", 1

        else
            WireLib.TriggerOutput @, "Success", 0

    ENT.TriggerInput = (input, value) =>
        if input == "TurnOff"
            if (value == 1)
                @SetNW2Entity "ActiveUser", nil

            @SetNW2Bool "TheMP Powered", (value ~= 1) and true or false