--@include moonpanel/core/sh_moonpanel.txt

getters = (cls, getters) ->
  cls.__base.__index = (key) =>
    if getter = getters[key]
      getter @
    else
      cls.__base[key]

setters = (cls, setters) ->
  cls.__base.__newindex = (key, val) =>
    if setter = setters[key]
      setter @, val
    else
      rawset @, key, val

hasValue = (t, val) ->
    for k, v in pairs t
        if v == val
            return true
    return false

class PathFinder
    nodeStacks: {}
    hasNode: (val) =>
        for k, nodeStack in pairs @nodeStacks
            if hasValue nodeStack, val
                return true
        return false

    checkSymmetry: (a, b) =>
        if not @symmetry or not a or not b
            return false

        rotational = (@symmetry == ROTATIONAL_SYMMETRY) and (a.x == -b.x) and (a.y == -b.y)
        vertical = (@symmetry == VERTICAL_SYMMETRY) and (a.x == b.x) and (a.y == -b.y)
        horizontal = (@symmetry == HORIZONTAL_SYMMETRY) and (a.x == -b.x) and (a.y == b.y)

        return rotational or vertical or horizontal

    getClosestNode: (x, y, radius) =>
        for k, node in pairs @nodeMap
            if node.clickable
                dist = math.sqrt (x - node.screenX)^2 + (y - node.screenY)^2
                if dist <= radius
                    return node

    getSymmetricalNode: (firstNode) =>
        for k, node in pairs @nodeMap
            if node.clickable and @checkSymmetry node, firstNode
                return node

    packAndCallback: () =>
        if @callback
            packed = {}
            for k, nodeStack in pairs @nodeStacks
                nodeTable = {}
                for _, node in pairs nodeStack
                    table.insert nodeTable, {
                        sx: node.screenX
                        sy: node.screenY
                    }

                table.insert packed, nodeTable
        
            @callback packed

    think: (mouseX, mouseY) =>
        if not @nodeStacks or not mouseX or not mouseY
            return

        toInsert = {}
        toRemove = {}
        for _, nodeStack in pairs @nodeStacks
            last = nodeStack[#nodeStack]

            if nodeStack == @nodeStacks[2]
                if @symmetry == VERTICAL_SYMMETRY
                    mouseX = @screenHeight - mouseX
                elseif @symmetry == HORIZONTAL_SYMMETRY
                    mouseX = @screenWidth - mouseX
                elseif @symmetry == ROTATIONAL_SYMMETRY
                    mouseX = @screenWidth - mouseX
                    mouseY = @screenHeight - mouseY

            localMouseX = mouseX - last.screenX
            localMouseY = mouseY - last.screenY
            mouseVector = Vector localMouseX, localMouseY, 0

            maxMDot = 0
            maxDotVector = nil
            maxNode = nil
            for k, to in pairs last.neighbors
                vec = Vector to.screenX - last.screenX, to.screenY - last.screenY, 0
                vecLength = vec\getLength! 

                unitVector = vec\getNormalized!

                mDot = unitVector\dot mouseVector

                if mDot > 0
                    mDot = math.min mDot, vecLength
                    
                    dotVector = (unitVector * mDot)
                    if mDot > maxMDot
                        maxMDot = mDot
                        maxNode = to

                if mDot >= vecLength
                    if to ~= nodeStack[1] and to == nodeStack[#nodeStack - 1]
                        if @symmetry
                            table.insert toRemove, #nodeStack
                        else
                            table.remove nodeStack, #nodeStack
                        
                        @packAndCallback!
                        break
                    elseif not @hasNode to
                        if @symmetry 
                            table.insert toInsert, to
                        else
                            table.insert nodeStack, to

                        @packAndCallback!
                        break

            if maxNode ~= nodeStack[1] and maxNode == nodeStack[#nodeStack - 1]
                if @symmetry
                    table.insert toRemove, #nodeStack
                else
                    table.remove nodeStack, #nodeStack
                @packAndCallback!

        if @symmetry and #toInsert > 1 and toInsert[1] ~= toInsert[2]
            a = toInsert[1]
            b = toInsert[2]               

            if a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
                b == @nodeStacks[2][1] or a == @nodeStacks[2][1]
                return

            if @checkSymmetry a, b
                table.insert @nodeStacks[1], toInsert[1]
                table.insert @nodeStacks[2], toInsert[2]
                @packAndCallback!

        if @symmetry and #toRemove > 1 and toRemove[1] == toRemove[2]
            a = @nodeStacks[1][toRemove[1]]
            b = @nodeStacks[2][toRemove[2]]                 

            if a == @nodeStacks[1][1] or b == @nodeStacks[1][1] or
                b == @nodeStacks[2][1] or a == @nodeStacks[2][1]
                return

            if @checkSymmetry a, b
                table.remove @nodeStacks[1], toRemove[1]
                table.remove @nodeStacks[2], toRemove[2]
                @packAndCallback!

    restart: (firstNode, secondNode) =>
        @nodeStacks = { {firstNode} }
        if secondNode 
            table.insert @nodeStacks, { secondNode }
        @packAndCallback!

    new: (@nodeMap, @screenWidth, @screenHeight, @symmetry, @callback) =>

TileShared = require "moonpanel/core/sh_moonpanel.txt"

COLOR_BG = Color 80, 77, 255, 255
COLOR_UNTRACED = Color 40, 22, 186
COLOR_TRACED = Color 255, 255, 255, 255
COLOR_VIGNETTE = Color 0, 0, 0, 92

SOUND_UICLICK = sounds.create chip!, "garrysmod/ui_click.wav"
SOUND_BLIP    = sounds.create chip!, "buttons/blip1.wav"
SOUND_ERROR   = sounds.create chip!, "buttons/button11.wav"
SOUND_GOOD    = sounds.create chip!, "buttons/button17.wav"

DEFAULT_RESOLUTIONS = {
    {
        innerScreenRatio: 0.4
        barWidth: 40
    }
    {
        innerScreenRatio: 0.5
        barWidth: 35
    }
    {
        innerScreenRatio: 0.6
        barWidth: 30
    }
    {
        innerScreenRatio: 0.7
        barWidth: 25
    }
    {
        innerScreenRatio: 0.8
        barWidth: 25
    }
    {
        innerScreenRatio: 0.85
        barWidth: 22
    }
    {
        innerScreenRatio: 0.875
        barWidth: 20
    }
    {
        innerScreenRatio: 0.875
        barWidth: 18
    }
    {
        innerScreenRatio: 0.875
        barWidth: 17
    }
    {
        innerScreenRatio: 0.875
        barWidth: 15
    }
}

DEFAULTEST_RESOLUTION = {
    innerScreenRatio: 0.875
    barWidth: 12
}

return class Tile extends TileShared
    __internal: {}
    getters @,
        isPowered: =>
            return @__internal.isPowered
    
    setters @,
        isPowered: (value) =>
            oldIsPowered = @__internal.isPowered
            @__internal.isPowered = value

            if value ~= oldIsPowered
                net.start "UpdatePowered"
                net.writeUInt value and 1 or 0, 2
                net.send!

    cursors: {}

    wireInputs: {
        {
            name: "TurnOff"
            type: "Number"
            callback: (value) =>
                value = if value == 0
                    false
                else
                    true

                @isPowered = not value
        }
    }

    pathFinderCallback: (data) =>
        net.start "PathFinderData"
        net.writeUInt #data, 4
        for _, stack in pairs data
            net.writeUInt #stack, 10
            for _, point in pairs stack
                net.writeUInt point.sx, 10
                net.writeUInt point.sy, 10

        net.send!

    playSound: (sound) =>
        sound\stop!
        timer.simple 0.15, () ->
            sound\play!

    puzzleEnd: () =>
        @panelUser = nil

    puzzleStart: (ply, node, symmNode) =>
        @panelUser = ply
        @activeCursor = @cursors[@panelUser]

        @pathFinder\restart node, symmNode

        @playSound SOUND_UICLICK

        net.start "PuzzleStart"
        net.send!

    use: (ply, ent) =>
        shouldUse = false
        for k, v in pairs chip!\getLinkedComponents!
            if v == ent
                shouldUse = true

        if shouldUse and @isPowered
            @nextUse = @nextUse or 0

            if timer.systime! > @nextUse
                if ply == @panelUser
                    @puzzleEnd!

                if not @panelUser and ply and @cursors[ply]
                    cur = @cursors[ply]
                    nodeA = @pathFinder\getClosestNode cur.x, cur.y, @tileData.dimensions.barLength
                    if not nodeA
                        return

                    nodeB = nil
                    if @tileData.tile.symmetry
                        nodeB = @pathFinder\getSymmetricalNode nodeA
                        if not nodeB
                            return

                    @puzzleStart ply, nodeA, nodeB
                    @nextUse = timer.systime! + 0.5

    adjustInputs: () =>
        names, types = {}, {}
        for k, v in pairs @wireInputs
            table.insert names, v.name
            table.insert types, v.type 

        wire.adjustInputs names, types        

    setup: (@tileData) =>
        -- Init coloures
        @tileData.colors            or= {}
        @tileData.colors.background or= COLOR_BG
        @tileData.colors.untraced   or= COLOR_UNTRACED
        @tileData.colors.traced     or= COLOR_TRACED
        @tileData.colors.vignette   or= COLOR_VIGNETTE

        -- Init tile defaults
        @tileData.tile        or= {}
        @tileData.tile.width  or= 2
        @tileData.tile.height or= 2

        width  = @tileData.tile.width
        height = @tileData.tile.height

        screenWidth = 1024 -- why? because for some reason RT contexts are 1024.
        -- it's also good to keep in mind that tileData.dimensions.screenWidth
        -- should only be used for rendering in RT context.

        -- Calculate dimensions        
        maxDim          = math.max width, height
        resolution      = DEFAULT_RESOLUTIONS[maxDim] or DEFAULTEST_RESOLUTION
        barWidth        = resolution.barWidth
        innerZoneLength = math.ceil screenWidth * resolution.innerScreenRatio
        barLength       = math.floor (innerZoneLength - (barWidth * (maxDim + 1))) / maxDim

        tileData.dimensions = {
            offsetH: math.ceil (screenWidth - (barWidth * (width + 1)) - (barLength * width)) / 2
            offsetV: math.ceil (screenWidth - (barWidth * (height + 1)) - (barLength * height)) / 2

            innerZoneLength: innerZoneLength
            barWidth: barWidth
            barLength: barLength
            width: width
            height: height

            screenWidth: screenWidth
            screenHeight: screenWidth
        }

        @compressedTileData = fastlz.compress json.encode @tileData

        @processElements!
        
        @pathFinder = PathFinder @pathMap, SCREEN_WIDTH, SCREEN_HEIGHT, tileData.tile.symmetry,
            @pathFinderCallback

        @isPowered = true

    think: () =>
        if @pathFinder and @panelUser and @cursors[@panelUser]
            @pathFinder\think @cursors[@panelUser].x, @cursors[@panelUser].y

    new: () =>
        @adjustInputs!

        hook.add "PlayerUse", "", (ply, ent) ->
            @use ply, ent

        timer.create "think", 0.05, 0, () ->
            @think!

        hook.add "input", "", (name, value) ->
            for k, v in pairs @wireInputs
                if v.callback and v.name == name
                    v.callback @, value

        net.receive "UpdateCursorIOS", (len, ply) ->
            isOnScreen = (net.readUInt 2) == 1 and true or false
            if isOnScreen
                @cursors[ply] = {}        
            else
                if ply == @panelUser
                    @puzzleEnd!

                @cursors[ply] = nil

        net.receive "UpdateCursorPos", (len, ply) ->
            if @cursors[ply]
                @cursors[ply].x = net.readUInt 9
                @cursors[ply].y = net.readUInt 9

        net.receive "FetchData", (len, ply) ->
            if @compressedTileData
                net.start "UpdateTileData"
                net.writeUInt @isPowered and 1 or 0, 2
                net.writeUInt #@compressedTileData, 32
                net.writeData @compressedTileData, #@compressedTileData
                net.send!

        super!